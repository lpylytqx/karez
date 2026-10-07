#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""补几个申报书要用的精确数字（色板去重、探索地点、岗位全表）。"""
import sys as _sys
from pathlib import Path as _Path
_sys.path.insert(0, str(_Path(__file__).resolve().parent))
from _root import ROOT  # 路径唯一解析处，不再写死盘符
import json
import re
from pathlib import Path

R = ROOT
d = json.loads((R / "data/numbers.json").read_text(encoding="utf-8"))
src = (R / "scripts/pipeline/postprocess.py").read_text(encoding="utf-8")
m = re.search(r"PALETTE_HEX\s*=\s*\[(.*?)\]", src, re.S)
cols = re.findall(r"#[0-9A-Fa-f]{6}", m.group(1))
print("  色板：列出 %d 个，去重后 %d 色" % (len(cols), len({c.upper() for c in cols})))

locs = d["exploration"].get("locations", [])
print("  探索地点 %d 处：%s" % (
    len(locs),
    "、".join(str(x.get("display", x)) if isinstance(x, dict) else str(x) for x in locs)))
nodes = d["exploration"].get("resource_nodes", [])
print("  资源节点 %d 个" % len(nodes))

print("  岗位全表：%s" % "、".join(
    "%s(%s)" % (j["display"], j["id"]) for j in d["population"]["jobs"]["list"]))

print()
print("  数值表顶层键 %d 个：" % len(d))
print("   " + "、".join(d.keys()))

# 战斗与 AI 的关键参数，申报书要引用
b = d["battle"]
print()
print("  战斗：每拍 %.2fs，移动 %.1f，射程（近战）%.0f，来敌上限 %d" % (
    b.get("step_seconds", 0.62), b.get("move_per_step", 11.0),
    b.get("attack_range", 20.0), b.get("max_enemies", 8)))
print("  战斗：来犯人数 = 上阵人数 %+d + 天数/%d，clamp %d~%d" % (
    b["raid"]["offset"], b["raid"]["per_days"], b["raid"]["clamp_min"], b["raid"]["clamp_max"]))

k = d["karez"]
print()
print("  坎儿井：flow_per_section %.0f 方/段，max_sections %d" % (
    k.get("flow_per_section", 55), k.get("max_sections", 6)))
print("  涝坝：容量档 %s" % [lv.get("capacity") for lv in k.get("reservoir", {}).get("levels", [])])
print("  季节：一年 %d 天，%d 季，每季 %d 天" % (
    d["calendar"]["days_per_season"] * len(d["calendar"]["seasons"]),
    len(d["calendar"]["seasons"]), d["calendar"]["days_per_season"]))
print("  时段：%s" % "、".join(d["calendar"]["phases_per_day"]))
print("  AI 预算：" + json.dumps(d["ai_budget"], ensure_ascii=False)[:220])
