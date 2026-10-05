"""
演示降级内容（demo 模式）。

存在的唯一理由：**演示现场不能冷场。**
无 Key、断网、API 故障、连续重试失败 —— 任何一种情况下，
游戏都要继续说人话，而不是弹一个红色报错。

对应 GDD 10.3「演示容错」。
"""

from __future__ import annotations

import json
import random
from functools import lru_cache
from pathlib import Path
from typing import Any

DATA_DIR = Path(__file__).resolve().parents[2] / "data"
CHARACTERS_FILE = DATA_DIR / "characters.json"


@lru_cache(maxsize=1)
def _characters_by_id() -> dict[str, dict[str, Any]]:
    with open(CHARACTERS_FILE, encoding="utf-8") as fh:
        data = json.load(fh)
    return {c["id"]: c for c in data["characters"]}


# 每个角色预置的兜底台词。要求：
#   1. 符合人设语气（读起来不像模板）
#   2. 不推进任何剧情，不给出任何具体数值
#   3. 不带承诺，避免污染记忆系统
FALLBACK_LINES: dict[str, list[str]] = {
    "lao_kanjiang": [
        "（他蹲在井口，捻起一把土在指间搓开）……土是干的。你等我想想。",
        "（他哼了一声，没抬头）你先别急着挖。让我看看这井壁。",
        "水不是喊出来的。你要么等，要么下去看看。",
    ],
    "muqam_yiren": [
        "（他拨了两下弦，又停下）哎，今天嗓子不行，改天给你弹。",
        "你这话说得像没调的歌。……先说别的，让我缓缓。",
        "（他望着远处）这事啊，我在别处听过另一个说法，可不一定对。",
    ],
    "hasake_qishou": [
        "（他把马鞭往腰带上一插）骑马去，两天就到。——不过得看天气。",
        "这个我能行。……你别这么看我，我真能行。",
        "你们这儿的人都蹲在墙里，不难受吗？",
    ],
    "hanshang_zhanggui": [
        "（他摸了摸算袋，没说话）……账要算清，情分才长久。先看看货。",
        "这个价，我不能做。你要是愿意，我们坐下慢慢谈。",
        "我走这条道三十年，什么没见过。——话别说满，先看天色。",
    ],
    "chuniang": [
        "（她把手在围裙上擦了擦）先吃饭，饿着肚子说什么都白搭。",
        "哎哟，你瘦了。……行了行了，锅里还有，自己盛去。",
        "这事儿我不管——（她顿了一下）你先去把柴抱进来。",
    ],
    "shenmi_lvren": [
        "（他没有立刻回答，手指在书箱边缘敲了两下）……未必。",
        "我见过类似的事。在别处。",
        "这要看你问的是哪一个。",
    ],
    "mafei_toumu": [
        "（他上下打量你，没说话，手按在刀柄上）……你可以不给。",
        "我不喜欢走两趟。你最好想清楚。",
        "（他忽然笑了一下）你是个明白人。",
    ],
}

GENERIC_LINES = [
    "（对方沉默了一下，似乎在斟酌）……今天先这样吧。",
    "（他看了看天色）天不早了，这事回头再说。",
    "（对方没有接话，只是点了点头）",
]


def get_fallback(character_id: str | None, scene: str = "idle") -> dict[str, Any]:
    """返回一条结构完整的降级响应。state_delta 永远为空——降级时不改数值。"""
    pool = FALLBACK_LINES.get(character_id or "", GENERIC_LINES)
    if not pool:
        pool = GENERIC_LINES

    return {
        "narration": random.choice(pool),
        "emotion": "平静",
        "intent": {"type": "none", "detail": ""},
        "state_delta": [],
        "memory_append": [],
        "suggestions": _scene_suggestions(scene),
        "_degraded": True,
    }


def _scene_suggestions(scene: str) -> list[str]:
    return {
        "karez_work": ["继续下挖", "加固井壁", "问暗渠走向"],
        "bazaar": ["招呼客人", "问价钱", "打听消息"],
        "battle": ["列阵防御", "派人迂回", "喊话"],
        "exploration": ["继续前行", "就地扎营", "原路返回"],
        "negotiation": ["报出底价", "试探对方", "暂缓谈判"],
        "idle": ["聊点别的", "询问近况", "先去做事"],
    }.get(scene, ["继续", "换个话题", "先等等"])


def demo_health_note() -> str:
    return (
        "当前处于 demo 模式：不会调用 API，所有回复来自本地预设内容。"
        "检查 ai_backend/.env 是否已配置 DEEPSEEK_API_KEY，且 FORCE_DEMO 不为 1。"
    )
