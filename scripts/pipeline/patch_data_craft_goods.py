#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""给 crafts 段补一张成品名表（goods）。

为什么需要：加工产出的 id 是英文（raisin / rug / instrument），
而这些物产不在 food / materials / livestock.products 任何一张现成的名字表里，
代码要显示「葡萄干」就得再写一份对照表 —— 那正是这个项目反复出错的地方
（「两处各写一套」）。所以名字跟配方放一起，只此一份。
"""
import sys as _sys
from pathlib import Path as _Path
_sys.path.insert(0, str(_Path(__file__).resolve().parent))
from _root import ROOT  # 路径唯一解析处，不再写死盘符
import json
from pathlib import Path

P = ROOT / "data" / "numbers.json"
d = json.loads(P.read_text(encoding="utf-8"))

d["crafts"]["goods"] = {
    "raisin": {"display": "葡萄干", "note": "晾房出品，能放到明年。"},
    "felt": {"display": "毡子", "note": "擀出来的，铺炕搭帐篷都行。"},
    "rug": {"display": "地毯", "note": "本地最值钱的手工。"},
    "instrument": {"display": "热瓦普", "note": "商队最认的货，一把顶十几袋粮。"},
}

P.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
chk = json.loads(P.read_text(encoding="utf-8"))
print("  成品名表：")
for k, v in chk["crafts"]["goods"].items():
    print(f"    {k:<12} {v['display']}")
print(f"  顶层键 {len(chk)} 个，JSON 有效")
