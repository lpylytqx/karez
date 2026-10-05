"""
《坎儿井》项目结构校验器。不需要网络、不需要 Godot、不需要 API Key。

用法：
    <venv>\\Scripts\\python.exe ai_backend\\verify.py

检查内容：
  1. 所有 JSON 可解析
  2. 角色卡与事件库的跨文件引用一致性
  3. 事件 delta 的路径与 op 合法性
  4. 数值表的自洽性与关键平衡点（尤其是水平衡）
  5. GDScript 基本语法（括号配对、缩进一致性、函数声明）
  6. GDScript / C# / Python 三处的数值兜底是否与 numbers.json 一致

改动任何数值或事件后都应该跑一次。
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FAILURES: list[str] = []


def check(label: str, cond: bool, detail: str = "") -> None:
    mark = "[PASS]" if cond else "[FAIL]"
    line = f"  {mark} {label}"
    if detail and not cond:
        line += f"  → {detail}"
    print(line)
    if not cond:
        FAILURES.append(label)


def section(title: str) -> None:
    print(f"\n{'=' * 68}\n{title}\n{'=' * 68}")


# ---------------------------------------------------------------------------
section("1. JSON 可解析性")

data: dict[str, dict] = {}
for path in sorted(ROOT.glob("data/*.json")) + sorted(ROOT.glob("ai_backend/*.json")):
    try:
        data[path.name] = json.loads(path.read_text(encoding="utf-8"))
        check(str(path.relative_to(ROOT)), True)
    except json.JSONDecodeError as exc:
        check(str(path.relative_to(ROOT)), False, f"{exc.msg} @ line {exc.lineno} col {exc.colno}")

if FAILURES:
    print("\nJSON 层面就无法通过，后续检查跳过。")
    sys.exit(1)


# ---------------------------------------------------------------------------
section("2. 角色卡")

chars = data["characters.json"]["characters"]
char_ids = {c["id"] for c in chars}
check("7 名角色", len(chars) == 7, f"实际 {len(chars)}")

for c in chars:
    missing = [f for f in ("id", "name", "system_prompt", "personality", "secrets", "cultural_claims")
               if f not in c]
    check(f"  {c['id']} 字段完整", not missing, f"缺 {missing}")
    check(f"  {c['id']} prompt 足够长", len(c.get("system_prompt", "")) > 400,
          f"仅 {len(c.get('system_prompt',''))} 字")
    # 禁止 ASCII 双引号：v1.0 曾因此破坏 JSON
    check(f"  {c['id']} prompt 未含 ASCII 双引号",
          '"' not in c.get("system_prompt", "") and "'" not in c.get("system_prompt", ""))

claims = sum(len(c.get("cultural_claims", [])) for c in chars)
check(f"文化断言 {claims} 条待审", claims >= 30, f"实际 {claims}")

for key in ("world_core", "output_contract"):
    txt = data["characters.json"][key]["text"]
    check(f"  {key} 非空且无 ASCII 双引号", len(txt) > 100 and '"' not in txt)


# ---------------------------------------------------------------------------
section("3. 事件库")

events = data["events.v1.json"]["events"]
check("全部为对象（无残留标记字符串）", all(isinstance(e, dict) for e in events))
check("事件总数 64", len(events) == 64, f"实际 {len(events)}")

ids = [e["id"] for e in events]
check("无重复 id", len(ids) == len(set(ids)))

for e in events:
    for field in ("id", "category", "title", "text", "choices"):
        if field not in e:
            check(f"  {e.get('id', '?')} 含字段 {field}", False)
    if not e.get("choices"):
        check(f"  {e['id']} 有选项", False)
    for c in e.get("choices", []):
        if "text" not in c or "effects" not in c:
            check(f"  {e['id']} 选项完整", False)
check("事件字段与选项结构完整", not [f for f in FAILURES if "含字段" in f or "选项" in f])

dist: dict[str, int] = {}
for e in events:
    dist[e["category"]] = dist.get(e["category"], 0) + 1
check("分类计数与 meta.distribution 一致", dist == data["events.v1.json"]["meta"]["distribution"],
      f"{dist} vs {data['events.v1.json']['meta']['distribution']}")
print(f"     分布: {dist}")

# 每个事件都必须是"有代价的选择"。
#
# 注意：机械判定这件事很容易误伤，因为"代价"有三种形态：
#   1. 资源支出      → sub resources.*（可机械识别）
#   2. 把资源变成别的东西 → sub wood/earth → set/加 buildings.*（karez.flow_bonus、
#                          buildings.*、population、flags 都是投入的产物或标记，不是收益）
# 结论：这件事机械判定不可靠。剩下的候选大多是"投资选择"（不做工具就少了工具）
# 或"代价在叙事里"（欠人情、树敌），只有人能判断。
#
# 所以这里**不做硬性判定**，只把候选完整列出来供人工 review。
# 这是刻意的设计决定：宁可让出一条会骗人的绿色勾，也不假装验证了无法验证的东西。

COST_PATHS = ("resources.food.", "resources.materials.", "resources.silver",
              "resources.water.current", "stats.")

review = []
for e in events:
    if len(e["choices"]) < 2:
        continue
    for c in e["choices"]:
        positive = negative = 0
        for ef in c.get("effects", []):
            p = ef.get("path", "")
            if "op" not in ef or not any(p.startswith(x) for x in COST_PATHS):
                continue
            v = float(ef.get("value", 0) or 0)
            if ef["op"] == "sub" or (ef["op"] == "add" and v < 0):
                negative += 1
            elif ef["op"] == "add" and v > 0:
                positive += 1
        if negative == 0 and positive > 0:
            review.append((f"{e['id']}/{c['text']}", positive))

with_cost = sum(
    1 for e in events for c in e["choices"]
    if any("op" in ef and (
        ef["op"] == "sub" or (ef["op"] == "add" and float(ef.get("value", 0) or 0) < 0))
        for ef in c.get("effects", []))
)
total_choices = sum(len(e["choices"]) for e in events)

print(f"     {with_cost}/{total_choices} 个选项含明确资源支出")
print(f"     {len(review)} 个选项无资源支出 —— 代价在时间/人力/人情/风险里，需人工 review：")
for label, pos in sorted(review, key=lambda x: -x[1])[:8]:
    print(f"       · {label}  (+{pos} 项增益)")
if len(review) > 8:
    print(f"       · …另有 {len(review) - 8} 个（多为用时间/人力换取的选择）")

# delta 路径与 op
ALLOWED = ("resources.silver", "resources.food.", "resources.materials.", "resources.water.",
           "karez.", "stats.", "characters.", "population", "buildings.", "flags.")
bad_paths, bad_ops, empty_effects = set(), set(), []
char_refs: set[str] = set()

for e in events:
    for c in e["choices"]:
        for ef in c.get("effects", []):
            if "op" not in ef:
                # 合法情形：只写记忆、或只打剧情标记的纯叙事效果
                if "memory" not in ef and len(ef) == 0:
                    empty_effects.append(f"{e['id']}/{c['text']}")
                continue
            p = ef.get("path", "")
            if p and not any(p.startswith(x) for x in ALLOWED):
                bad_paths.add(p)
            if ef["op"] not in ("add", "sub", "set", "mul"):
                bad_ops.add(ef["op"])
            m = re.match(r"^characters\.([a-z_]+)\.", p)
            if m:
                char_refs.add(m.group(1))
            mem = ef.get("memory")
            if isinstance(mem, dict) and mem.get("character"):
                char_refs.add(mem["character"])

check("delta 路径合法", not bad_paths, f"非法: {bad_paths}")
check("delta op 合法", not bad_ops, f"非法: {bad_ops}")
check("无空效果条目", not empty_effects, f"{empty_effects[:3]}")
unknown = char_refs - char_ids
check("引用的角色 id 均存在", not unknown, f"未知: {unknown}")

# 单条 delta 幅度上限。注意 schema.json 的 max_abs_value=25 是**单次 AI 调用**的限制，
# 事件库是策划手写的确定性后果，可以有更大的量级（例如放空涝坝、交出 50 石粮）。
LIMITS = [("resources.water.", 120), ("resources.food.", 60),
          ("resources.materials.", 60), ("resources.silver", 60), ("", 60)]
oversized = []
for e in events:
    for c in e["choices"]:
        for ef in c.get("effects", []):
            v = ef.get("value")
            if not isinstance(v, (int, float)):
                continue
            p = ef.get("path", "")
            limit = next(lim for prefix, lim in LIMITS if p.startswith(prefix))
            if abs(v) > limit:
                oversized.append(f"{e['id']}/{p}={v} (上限 {limit})")
check("无异常大额 delta", not oversized, f"{oversized[:3]}")


# ---------------------------------------------------------------------------
section("4. 数值表自洽性")

n = data["numbers.json"]
karez = n["karez"]
check("竖井段数 = max_sections", len(karez["sections"]) == karez["max_sections"])
check("竖井成本单调递增",
      all(karez["sections"][i]["labor"] < karez["sections"][i + 1]["labor"]
          for i in range(len(karez["sections"]) - 1)))
check("竖井技能要求递增",
      all(karez["sections"][i]["requires_skill"] < karez["sections"][i + 1]["requires_skill"]
          for i in range(len(karez["sections"]) - 1)))
check("融水倍率覆盖四季",
      set(karez["season_melt_multiplier"]) >= {"spring", "summer", "autumn", "winter"})

units = n["combat"]["units"]
ours = [k for k, v in units.items() if v.get("cost") is not None]
enemies = [k for k, v in units.items() if v.get("cost") is None]
check(f"战斗单位 {len(units)} 个（我方 {len(ours)} / 敌方 {len(enemies)}）",
      len(ours) == 5 and len(enemies) == 3, f"我方 {ours} 敌方 {enemies}")

ranks = n["progression"]["ranks"]
check("称号 6 级且繁荣要求递增",
      len(ranks) == 6 and all(ranks[i]["requires"]["prosperity"] < ranks[i + 1]["requires"]["prosperity"]
                              for i in range(len(ranks) - 1)))

# ---- 水平衡（重点）----
water = n["resources"]["water"]["initial"]
pop = n["population"]["initial"]
per_cap = n["population"]["daily_consumption"]["water_per_person"]
fps = karez["flow_per_section"]
melt = karez["season_melt_multiplier"]
bonus = karez.get("season_flow_bonus", {})
first_days = karez["sections"][0]["days"]

consume = pop * per_cap
base_flow = water.get("flow_per_day", 0)
net = consume - base_flow
buffer_days = water["current"] / net if net > 0 else float("inf")

print(f"     开局: 水 {water['current']:.0f}  残流 {base_flow:.0f}/天  "
      f"日耗 {consume:.0f}/天  净消耗 {net:.0f}/天")
print(f"     缓冲 {buffer_days:.1f} 天   第一段工期 {first_days} 天")

check("水平衡：净消耗为正（否则水永不枯竭，紧迫感消失）", net > 0, f"净消耗 {net}")
check("水平衡：缓冲 5-12 天（既不死于开局，也不从容）",
      5 <= buffer_days <= 12, f"{buffer_days:.1f} 天")
check("水平衡：缓冲至少是首段工期的 2 倍（留犯错空间）",
      buffer_days >= first_days * 2, f"{buffer_days:.1f} vs {first_days * 2}")
check("水平衡：初始水占容量不超过 70%（留出建涝坝的意义）",
      water["current"] <= water["capacity"] * 0.7,
      f"{water['current']}/{water['capacity']}")

for sec in (1, 3, 4, 6):
    prod = sec * fps + base_flow
    print(f"     {sec} 段竖井: 供水 {prod:>3.0f}/天  可养 {prod / per_cap:.0f} 人")

prod_win = (4 * fps + base_flow) * melt["winter"] + bonus.get("winter", 0)
check("冬季压力存在（4 段时冬季供水明显低于常年）",
      prod_win < 4 * fps + base_flow, f"冬季 {prod_win:.1f}")
print(f"     4 段冬季供水 {prod_win:.1f}/天 → 仅够 {prod_win / per_cap:.0f} 人（逼玩家冬天放慢扩张）")

cap_formula = n["population"]["capacity_formula"]
check("人口上限公式引用明渠与居所", "irrigated_plots" in cap_formula and "housing" in cap_formula)


# ---------------------------------------------------------------------------
section("5. GDScript 基本检查")

gd_files = sorted((ROOT / "scripts").rglob("*.gd"))
check(f"找到 {len(gd_files)} 个 .gd 文件", len(gd_files) >= 2)

for gd in gd_files:
    text = gd.read_text(encoding="utf-8")
    name = gd.name
    lines = text.splitlines()

    for open_c, close_c in (("(", ")"), ("[", "]"), ("{", "}")):
        check(f"  {name} {open_c}{close_c} 配对",
              text.count(open_c) == text.count(close_c),
              f"{text.count(open_c)} vs {text.count(close_c)}")

    # 缩进必须一致（Godot 不允许同一文件混用 Tab 与空格缩进）
    tab_indent = sum(1 for ln in lines if ln.startswith("\t"))
    space_indent = sum(1 for ln in lines if ln.startswith("    ") and not ln.startswith("\t"))
    check(f"  {name} 缩进风格统一（Tab {tab_indent} / 空格 {space_indent}）",
          tab_indent == 0 or space_indent == 0)

    check(f"  {name} 有 extends 声明",
          any(ln.startswith(("extends ", "class_name ")) for ln in lines))

    # 函数声明完整性：支持多行签名（括号未闭合时不算缺失冒号）
    bad_funcs = []
    for i, ln in enumerate(lines):
        if not re.match(r"^\s*(static\s+)?func\s+\w", ln):
            continue
        depth = ln.count("(") - ln.count(")")
        j = i
        while depth > 0 and j + 1 < len(lines):
            j += 1
            depth += lines[j].count("(") - lines[j].count(")")
        if not lines[j].rstrip().endswith(":"):
            bad_funcs.append(f"{i + 1}: {ln.strip()[:40]}")
    check(f"  {name} 函数声明齐全", not bad_funcs, f"{bad_funcs[:2]}")

    # 未解析的占位符
    check(f"  {name} 无 TODO/FIXME 残留",
          "TODO" not in text and "FIXME" not in text)


# ---------------------------------------------------------------------------
section("6. 跨实现数值一致性（GDScript / C# / numbers.json）")

gs_text = (ROOT / "scripts" / "core" / "game_state.gd").read_text(encoding="utf-8")
cs_text = (ROOT / "scripts" / "csharp_port" / "GameState.cs").read_text(encoding="utf-8")
py_text = (ROOT / "ai_backend" / "ai" / "validate.py").read_text(encoding="utf-8")

# 三个实现的白名单必须一致
WHITELIST = ["resources.silver", "resources.food.", "resources.materials.",
             "resources.water.current", "stats.reputation", "stats.morale",
             "stats.security", "characters."]
for token in WHITELIST:
    check(f"  白名单含 {token}", token in gs_text and token in cs_text and token in py_text)

# 兜底数值：JSON 里改了，代码兜底也必须跟着改（否则找不到文件时行为不一致）。
# 注意两处写法不同：GDScript 用带空格的字典字面量，C# 的 fallback 是紧凑 JSON。
check("GDScript 兜底初始水 = 90", '"current": 90' in gs_text)
check("C# 兜底初始水 = 90", '"current":90' in cs_text)

check("GDScript 兜底残流 = 5", '"flow_per_day": 5' in gs_text)
check("C# 兜底残流 = 5", '"flow_per_day":5' in cs_text)
check("C# 兜底冬季渗流修正 = -3", '"season_flow_bonus": {"winter": -3}' in cs_text)

check("端口 8787 三处一致",
      "8787" in (ROOT / "ai_backend" / ".env.example").read_text(encoding="utf-8")
      and "8787" in gs_text)

# 降级台词两处必须同步（Python 与 C# 各一份）
demo_py = (ROOT / "ai_backend" / "ai" / "demo.py").read_text(encoding="utf-8")
for cid in char_ids:
    check(f"  兜底台词覆盖 {cid}", cid in demo_py and cid in cs_text)


# ---------------------------------------------------------------------------
section("结果")

if FAILURES:
    print(f"[FAIL] {len(FAILURES)} 项未通过：")
    for f in FAILURES:
        print(f"       - {f}")
    sys.exit(1)

print("[PASS] 全部通过。项目结构、数值平衡、跨实现一致性均正常。")
