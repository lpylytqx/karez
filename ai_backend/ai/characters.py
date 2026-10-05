"""
角色卡加载与 prompt 拼装。

关键设计：prompt 分两段。
  [静态前缀] 世界观 + 输出契约 + 角色卡  —— 逐字不变，放最前，命中上下文缓存
  [动态后缀] 运行时状态块（资源/记忆/最近对话） —— 每次变化，放最后

缓存命中的输入单价是未命中的 1/50（flash：0.04 vs 2 元/百万 token）。
单机游戏里单局会调用几十上百次，这个分层能省下大部分成本。
所以：**绝不要把会变的内容混进静态前缀。**
"""

from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path
from typing import Any

DATA_DIR = Path(__file__).resolve().parents[2] / "data"
CHARACTERS_FILE = DATA_DIR / "characters.json"

EMOTIONS = ["平静", "高兴", "不满", "愤怒", "忧虑", "兴奋", "戒备", "悲伤"]

SCENE_LABELS = {
    "karez_work": "坎儿井施工",
    "bazaar": "巴扎/驿站日常",
    "battle": "战斗",
    "exploration": "探索途中",
    "negotiation": "谈判",
    "idle": "闲谈",
}


@lru_cache(maxsize=1)
def load_data() -> dict[str, Any]:
    with open(CHARACTERS_FILE, encoding="utf-8") as fh:
        return json.load(fh)


@lru_cache(maxsize=1)
def get_characters() -> dict[str, dict[str, Any]]:
    data = load_data()
    return {c["id"]: c for c in data["characters"]}


def get_character(character_id: str) -> dict[str, Any] | None:
    return get_characters().get(character_id)


def list_characters() -> list[dict[str, str]]:
    return [
        {"id": c["id"], "name": c["name"], "identity": c["identity"]}
        for c in load_data()["characters"]
    ]


# ---------------------------------------------------------------------------
# 静态前缀（缓存友好：必须逐字稳定）
# ---------------------------------------------------------------------------

@lru_cache(maxsize=1)
def _static_core() -> str:
    data = load_data()
    return data["world_core"]["text"]


@lru_cache(maxsize=1)
def _static_contract() -> str:
    return load_data()["output_contract"]["text"]


@lru_cache(maxsize=32)
def build_system_prompt(character_id: str) -> str:
    """
    拼装 system prompt。前两段全局一致（跨角色共享缓存前缀），
    第三段是该角色专属（同一角色反复对话时命中缓存）。
    """
    data = load_data()
    char = get_character(character_id)

    if char is None:
        # 临时角色：用 npc_pool 模板
        npc = data.get("npc_pool", {})
        return (
            _static_core()
            + "\n\n"
            + npc.get("template", "你是一个路过的旅人。用一两句话说清你的意思。")
            + "\n\n"
            + _static_contract()
        )

    safety = data.get("safety_rules", {})
    blocked = "；".join(safety.get("blocked_topics", []))

    parts = [
        _static_core(),
        f"【你扮演的角色】\n{char['system_prompt']}",
    ]

    if blocked:
        parts.append(
            "【严禁涉及的内容】\n"
            f"{blocked}。\n"
            "若玩家问及这些，用符合你性格的方式回避（转移话题、说不知道、说这事不该问），"
            "不要解释你为什么要回避。"
        )

    parts.append(_static_contract())
    return "\n\n".join(parts)


# ---------------------------------------------------------------------------
# 动态后缀（每次都变，放最后）
# ---------------------------------------------------------------------------

def build_user_prompt(
    *,
    scene: str,
    player_input: str,
    context: dict[str, Any] | None = None,
    memory: list[str] | None = None,
    recent: list[str] | None = None,
    promises: list[str] | None = None,
) -> str:
    blocks: list[str] = []

    blocks.append(f"【当前场景】{SCENE_LABELS.get(scene, scene)}")

    if context:
        blocks.append("【当前状态】\n" + _format_context(context))

    # 承诺单独成块，放在记忆之前：混在大列表里模型容易忽略，
    # 而「认得自己许下过的话」是判断 AI 角色是否真的活着的核心指标。
    if promises:
        blocks.append(
            "【你亲口答应过玩家的事】\n"
            "这些是你自己许下的，必须记得并遵守。玩家若提起，你要认得，不得装作没说过；\n"
            "若要反悔，须用符合你性格的方式说明理由。\n"
            + "\n".join(f"- {p}" for p in promises)
        )

    if memory:
        mem_lines = "\n".join(f"- {m}" for m in memory[:13])
        blocks.append(f"【你记得的事】（按重要程度排序）\n{mem_lines}")
    else:
        blocks.append("【你记得的事】\n（暂无）")

    if recent:
        rec_lines = "\n".join(f"- {r}" for r in recent[-8:])
        blocks.append(f"【刚才发生的事】\n{rec_lines}")

    blocks.append(f"【玩家现在说】{player_input}")
    blocks.append(
        "请以你的角色身份作出回应，严格按 json 格式输出。"
        "记住：你不自行编造数值，拿不准就让 state_delta 为空数组。"
    )

    return "\n\n".join(blocks)


def _format_context(ctx: dict[str, Any]) -> str:
    """把状态摘要格式化成紧凑文本。省 token 且便于模型理解。"""
    lines: list[str] = []

    if "day" in ctx or "season" in ctx:
        season_cn = {
            "spring": "春", "summer": "夏", "autumn": "秋", "winter": "冬",
        }.get(str(ctx.get("season")), str(ctx.get("season", "")))
        lines.append(f"第 {ctx.get('day', '?')} 天（{season_cn}季）")

    res = ctx.get("resources") or {}
    res_bits: list[str] = []
    if "water" in res:
        cap = res.get("water_capacity")
        res_bits.append(
            f"水 {res['water']}" + (f"/{cap}" if cap else "")
        )
    if "silver" in res:
        res_bits.append(f"银两 {res['silver']}")
    food = res.get("food") or {}
    if food:
        food_bits = "、".join(
            f"{k}{v}" for k, v in food.items() if isinstance(v, (int, float)) and v
        )
        if food_bits:
            res_bits.append(f"食物 {food_bits}")
    if res_bits:
        lines.append("资源：" + "；".join(res_bits))

    karez = ctx.get("karez") or {}
    if karez:
        lines.append(
            f"坎儿井：共 {karez.get('sections', 0)} 段，日出水 {karez.get('flow_per_day', 0)} 方"
        )

    pop = ctx.get("population")
    if pop is not None:
        lines.append(f"人口：{pop}")

    stats = ctx.get("stats") or {}
    stat_bits: list[str] = []
    for key, label in (
        ("prosperity", "繁荣"), ("reputation", "声望"),
        ("morale", "士气"), ("security", "安全"),
    ):
        if key in stats:
            stat_bits.append(f"{label}{stats[key]}")
    if stat_bits:
        lines.append("指标：" + "；".join(stat_bits))

    if ctx.get("speaker_affinity") is not None:
        lines.append(f"你对玩家的好感度：{ctx['speaker_affinity']}（-100 敌视 ~ 100 亲密）")

    extra = ctx.get("extra_note")
    if extra:
        lines.append(f"补充：{extra}")

    return "\n".join(lines) if lines else "（无特别状态）"
