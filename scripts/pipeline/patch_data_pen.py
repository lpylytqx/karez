#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""补一个专门的畜栏建筑（yangjuan）。

为什么必须补：目标里写的是「**畜栏建筑**」，而此前只有 `majiu`（马厩）顺带提供
`livestock_capacity`。马厩是给商队换马的地方，把"养羊"这件事整个挂在它身上，
玩家想扩群时看到的是"马厩"而不是"羊圈"，概念上就是错位的。

畜栏的定位：**便宜、快、专门用来扩存栏**（马厩贵、慢、但有 trade_range）。
两个建筑各有用处，不是重复。

用法：.venv\\Scripts\\python.exe scripts\\pipeline\\patch_data_pen.py
"""
import sys as _sys
from pathlib import Path as _Path
_sys.path.insert(0, str(_Path(__file__).resolve().parent))
from _root import ROOT  # 路径唯一解析处，不再写死盘符
import json
from pathlib import Path

P = ROOT / "data" / "numbers.json"
d = json.loads(P.read_text(encoding="utf-8"))

pen = {
    "id": "yangjuan", "display": "畜栏",
    "labor": 20, "materials": {"wood": 16, "earth": 6}, "days": 1,
    "effect": {"livestock_capacity": 10},
    "upkeep_labor_per_day": 0,
    "note": ("圈住牲畜的地方。**便宜、一天就好、专门用来扩存栏**；"
             "马厩更贵也更慢，但多给 trade_range。存栏到顶就不再繁殖，"
             "所以想扩群就得先盖栏。"),
    "unlocks": ["畜牧扩群"],
}

# 幂等：已存在就替换
lst = d["buildings"]["list"]
for i, b in enumerate(lst):
    if b["id"] == "yangjuan":
        lst[i] = pen
        break
else:
    # 插在马厩后面：两个畜牧建筑挨着，玩家读建造列表时能对上
    idx = next((i for i, b in enumerate(lst) if b["id"] == "majiu"), len(lst) - 1)
    lst.insert(idx + 1, pen)

P.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

chk = json.loads(P.read_text(encoding="utf-8"))
print("  建筑表共 %d 个：" % len(chk["buildings"]["list"]))
for b in chk["buildings"]["list"]:
    cap = b.get("effect", {}).get("livestock_capacity")
    mark = "  <== 畜栏" if b["id"] == "yangjuan" else ("  存栏+%d" % cap if cap else "")
    print("    %-12s %-8s%s" % (b["id"], b["display"], mark))
