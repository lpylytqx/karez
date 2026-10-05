"""
M1 闭环自检。不需要 API Key 也能跑（走 demo 模式验证管道）。

用法：
    <venv>\\Scripts\\python.exe ai_backend\\smoke_test.py

它验证 M1 验收标准里的四条：
  1. 服务能启动（这里直接测内部逻辑，不起 HTTP）
  2. 拼出的 prompt 结构正确、静态前缀稳定（缓存友好）
  3. delta 校验能挡住越权与荒谬数值
  4. 无 Key 时走 demo 兜底而不是崩溃
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from ai_backend.ai import characters as charmod  # noqa: E402
from ai_backend.ai import demo  # noqa: E402
from ai_backend.ai.client import AIConfig, parse_json_content  # noqa: E402
from ai_backend.ai.validate import apply_deltas, validate_deltas  # noqa: E402

PASS, FAIL = "[PASS]", "[FAIL]"
failures: list[str] = []


def check(name: str, condition: bool, detail: str = "") -> None:
    if condition:
        print(f"{PASS} {name}")
    else:
        print(f"{FAIL} {name}" + (f"  → {detail}" if detail else ""))
        failures.append(name)


def section(title: str) -> None:
    print(f"\n{'─' * 58}\n{title}\n{'─' * 58}")


# ---------------------------------------------------------------------------
section("1. 角色卡加载")

chars = charmod.list_characters()
check("7 名核心角色齐备", len(chars) == 7, f"实际 {len(chars)}")
print(f"     {', '.join(c['name'] for c in chars)}")

for cid in [c["id"] for c in chars]:
    sp = charmod.build_system_prompt(cid)
    check(f"  {cid} 的 system prompt 非空", len(sp) > 500, f"长度 {len(sp)}")


# ---------------------------------------------------------------------------
section("2. 静态前缀稳定性（上下文缓存的前提）")

sp_a = charmod.build_system_prompt("lao_kanjiang")
sp_b = charmod.build_system_prompt("lao_kanjiang")
check("同一角色两次拼装逐字一致", sp_a == sp_b)

sp_m = charmod.build_system_prompt("muqam_yiren")
core = charmod._static_core()
check("世界观段落是两角色 prompt 的公共前缀", sp_a.startswith(core) and sp_m.startswith(core))
check("输出契约出现在 prompt 末尾部分", charmod._static_contract() in sp_a)

# 动态部分必须与静态部分分离（否则缓存全失效）
user_prompt = charmod.build_user_prompt(
    scene="karez_work",
    player_input="先看看第三口竖井",
    context={
        "day": 3, "season": "spring",
        "resources": {"water": 120, "water_capacity": 300, "silver": 30,
                      "food": {"naan": 20, "grain": 15}},
        "karez": {"sections": 1, "flow_per_day": 55},
        "population": 6,
        "stats": {"prosperity": 5, "reputation": 10, "morale": 60, "security": 40},
    },
    memory=["第2天 玩家答应给他找好木料修井架，尚未兑现"],
    recent=["玩家：先看看第三口竖井"],
)
check("动态 prompt 含玩家输入", "先看看第三口竖井" in user_prompt)
check("动态 prompt 含状态摘要", "坎儿井" in user_prompt and "第 3 天" in user_prompt)
check("动态 prompt 含记忆", "尚未兑现" in user_prompt)
check("动态内容未混入静态前缀", "先看看第三口竖井" not in sp_a)

print("\n  ── 动态 prompt 实际内容 ──")
for line in user_prompt.splitlines():
    print(f"     {line}")


# ---------------------------------------------------------------------------
section("3. AI 输出的 JSON 解析容错")

cases = [
    ('{"narration":"甲"}', True, "纯 json"),
    ('```json\n{"narration":"乙"}\n```', True, "被 markdown 包裹"),
    ('好的，这是回复：{"narration":"丙"} 希望有用', True, "前后有废话"),
    ('{"narration": broken}', False, "语法错误"),
    ('完全不是 json', False, "非 json"),
    ('', False, "空串"),
    ('[1,2,3]', False, "数组而非对象"),
]
for raw, should_ok, label in cases:
    parsed, err = parse_json_content(raw)
    check(f"  {label}", (parsed is not None) == should_ok, f"err={err}")


# ---------------------------------------------------------------------------
section("4. state_delta 白名单校验（防模型幻觉）")

raw_deltas = [
    {"op": "add", "path": "resources.silver", "value": 5},              # 合法
    {"op": "add", "path": "resources.food.grain", "value": -3},          # 合法
    {"op": "set", "path": "characters.lao_kanjiang.affinity", "value": 10},  # 合法
    {"op": "add", "path": "resources.silver", "value": 9999},            # 超幅度→截断
    {"op": "set", "path": "resources.water.current", "value": 99999},    # 合法但会夹紧
    {"op": "add", "path": "stats.reputation", "value": 999},             # 超幅度+夹紧
    {"op": "set", "path": "stats.morale", "value": -500},                # 夹紧到 0
    {"op": "add", "path": "resources.silver; DROP", "value": 1},         # 非法路径
    {"op": "add", "path": "player.hp", "value": 100},                    # 非白名单
    {"op": "delete", "path": "resources.silver", "value": 1},            # 非法 op
    {"op": "add", "path": "resources.silver", "value": float("nan")},    # NaN
    {"op": "add", "path": "resources.silver", "value": "很多"},           # 非数值
    "我不是对象",                                                          # 类型错误
    {"op": "add", "path": "resources.water.stolen", "value": 5},         # 近似但不合法
]

clean, dropped = validate_deltas(raw_deltas)
print(f"     通过 {len(clean)} 条，丢弃 {len(dropped)} 条\n")
for d in clean:
    print(f"     ✓ {d['op']:<4} {d['path']:<40} {d['value']}")
print()
for d in dropped:
    print(f"     ✗ {d['reason']}")

check("越权路径被拦截", not any("player.hp" in str(d.get("path")) for d in clean))
check("非法 op 被拦截", all(d["op"] in {"add", "sub", "set", "mul"} for d in clean))
check("NaN 被拦截", not any(d["value"] != d["value"] for d in clean))
check("超幅度被截断到 25", all(abs(d["value"]) <= 25 for d in clean if d["op"] != "set"))
check("保留了一定数量的合法 delta", len(clean) >= 5, f"实际 {len(clean)}")

# 应用效果验证
state = {
    "resources": {"silver": 40, "water": {"current": 60}, "food": {"grain": 30}},
    "stats": {"reputation": 10, "morale": 55},
    "characters": {"lao_kanjiang": {"affinity": 0}},
}
apply_deltas(state, clean)
print(f"\n     应用后状态: {state}")
check("silver 被修改", state["resources"]["silver"] != 40)
check("morale 未越界", 0 <= state["stats"]["morale"] <= 100)
check("reputation 未越界", 0 <= state["stats"]["reputation"] <= 100)


# ---------------------------------------------------------------------------
section("5. 无 Key 时的降级（demo 模式）")

cfg = AIConfig(api_key="", force_demo=False)
check("无 Key 时 is_live 为 False", cfg.is_live is False)
check("FORCE_DEMO=1 时即使有 Key 也不调 API",
      AIConfig(api_key="sk-test", force_demo=True).is_live is False)
check("有 Key 且未强制 demo 时为 live",
      AIConfig(api_key="sk-test", force_demo=False).is_live is True)

for cid in [c["id"] for c in chars]:
    fb = demo.get_fallback(cid, "karez_work")
    check(
        f"  {cid} 有兜底台词",
        bool(fb["narration"]) and fb["state_delta"] == [] and len(fb["suggestions"]) == 3,
    )

generic = demo.get_fallback(None, "battle")
check("未知角色也有兜底", bool(generic["narration"]))
check("兜底不改任何数值", generic["state_delta"] == [])
check("兜底不写记忆", generic["memory_append"] == [])


# ---------------------------------------------------------------------------
section("结果")

if failures:
    print(f"{FAIL} {len(failures)} 项未通过：")
    for f in failures:
        print(f"       - {f}")
    sys.exit(1)

print(f"{PASS} 全部通过。M1 管道就绪。")
print()
print("下一步：")
print("  1. 复制 ai_backend/.env.example → ai_backend/.env，填入 DEEPSEEK_API_KEY")
print("  2. 运行 python ai_backend/main.py，浏览器打开 http://127.0.0.1:8787/health")
print("  3. 用 curl 或 API 文档页的 Try it out 发一次 /narrate")
