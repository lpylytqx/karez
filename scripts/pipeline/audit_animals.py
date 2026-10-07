#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""查每个动物道具用了哪些颜色，并标出跑出色板 / 误用「水系蓝」的。

为什么要单写这个检查：这个项目里已经有过 **两次** 素材整张用了水系蓝
（rock_small_01 / rock_pile_01 散在干沙地上像故障色块）。
动物的颜色太多样，肉眼在游戏里分不出"这只羊本来就是蓝的"还是"它跑色了"，
所以要按像素统计颜色来看。
"""
from __future__ import annotations

import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image  # noqa: E402

from postprocess import PALETTE_HEX  # noqa: E402

PROPS = Path(__file__).resolve().parents[2] / "assets" / "tiles" / "props"
PAL = {c.upper() for c in PALETTE_HEX}
WATER = {"#8FC7D6", "#5A9CB0", "#3A7086"}
NAMES = ["animal_sheep_01.png", "animal_donkey_01.png", "animal_chicken_01.png",
         "animal_goat_01.png", "animal_camel_01.png"]

bad = 0
for n in NAMES:
    p = PROPS / n
    if not p.exists():
        print(f"  {n:<26} 不存在")
        continue
    im = Image.open(p).convert("RGBA")
    cnt = Counter(im.getdata())
    hexes = ["#%02X%02X%02X" % (c[0], c[1], c[2])
             for c, k in cnt.most_common() if c[3] > 0]
    off = [h for h in hexes if h not in PAL]
    water = [h for h in hexes if h in WATER]
    print("  %-26s 用色 %d 种" % (n, len(hexes)))
    print("      " + " ".join(hexes))
    if off:
        print("      色板外：%s" % " ".join(off))
        bad += 1
    if water:
        print("      误用水系蓝：%s" % " ".join(water))
        bad += 1

print()
print("  结论：%s" % ("全部合规" if bad == 0 else "有 %d 处需要处理" % bad))
