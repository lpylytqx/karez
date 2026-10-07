#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""把三张动物道具从「水系蓝」改成暖色系。

问题：animal_sheep_01 / animal_donkey_01 / animal_chicken_01 三张图
**整身用了色板里的水系蓝**（#8FC7D6 / #5A9CB0 / #3A7086）。
干沙地上的蓝色羊看起来像故障色块 —— 这是本项目**第 9 次**同一类问题
（前两次是 rock_small_01 / rock_pile_01，散在沙地上像蓝色补丁）。

成因（推测）：这三张是从 tiny-farm 素材包转过来的，原图是白/灰色调的羊和鸡；
转换时按"最接近的调色板颜色"映射，而这个 34 色板里最接近白灰的恰好是
偏蓝的那一段（#E8EEF2 / #D5E0E9 / #AFC2D2 本身就带蓝），
更亮的部位就落到了真正的水系蓝上。

修法：**按明度映射**到暖色段（和当初修石头用的是同一招）——
保留明暗关系，只换色相，形状不会被改坏。

用法：.venv\\Scripts\\python.exe scripts\\pipeline\\recolor_animals.py
原图备份到 assets/_wip/_originals/*.blue_orig
"""
from __future__ import annotations

import shutil
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image  # noqa: E402

from postprocess import PALETTE_HEX  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
PROPS = ROOT / "assets" / "tiles" / "props"
BACKUP = ROOT / "assets" / "_wip" / "_originals"
PAL = {c.upper() for c in PALETTE_HEX}

# 水系蓝 → 暖色段。**按明度一一对应**，明暗关系原样保留。
REMAP = {
    "#E8EEF2": "#F0E4D0",   # 最亮 → 奶白
    "#D5E0E9": "#E8C79A",   # 亮   → 浅驼
    "#AFC2D2": "#B5A48C",   # 中亮 → 灰褐
    "#8FC7D6": "#DFC398",   # 中   → 浅金
    "#5A9CB0": "#C9A277",   # 中暗 → 驼褐
    "#3A7086": "#8B6B47",   # 最暗 → 深棕
}
TARGETS = ["animal_sheep_01.png", "animal_donkey_01.png", "animal_chicken_01.png"]


def main() -> None:
    BACKUP.mkdir(parents=True, exist_ok=True)
    made: list[Image.Image] = []
    for name in TARGETS:
        src = PROPS / name
        im = Image.open(src).convert("RGBA")
        # 备份（只在第一次；重复运行不会把已修好的图当原图备份）
        bak = BACKUP / (src.stem + ".blue_orig.png")
        if not bak.exists():
            shutil.copy2(src, bak)
        px = im.load()
        changed = 0
        for y in range(im.height):
            for x in range(im.width):
                r, g, b, a = px[x, y]
                if a == 0:
                    continue
                h = "#%02X%02X%02X" % (r, g, b)
                if h in REMAP:
                    nh = REMAP[h]
                    px[x, y] = (int(nh[1:3], 16), int(nh[3:5], 16), int(nh[5:7], 16), a)
                    changed += 1
        im.save(src)
        print("  %-26s 改了 %3d 个像素" % (name, changed))
        made.append(im)

    # 复检：不该再有水系蓝
    water = {"#8FC7D6", "#5A9CB0", "#3A7086"}
    bad = []
    for name in TARGETS:
        im = Image.open(PROPS / name).convert("RGBA")
        cols = {"#%02X%02X%02X" % (c[0], c[1], c[2])
                for c in im.getdata() if c[3] > 0}
        left = cols & water
        off = cols - PAL
        if left:
            bad.append((name, "水系蓝残留 " + " ".join(sorted(left))))
        if off:
            bad.append((name, "色板外 " + " ".join(sorted(off))))
    print()
    if bad:
        for n, why in bad:
            print("  [FAIL] %-26s %s" % (n, why))
    else:
        print("  [OK] 三张图已无水系蓝，且全部落在色板内")

    # 对照图（放大 10 倍）：修改前后并排看。这个项目里"看图"是唯一可靠的验收手段。
    Z = 10
    pad = 4
    rows = []
    for name in TARGETS:
        a = Image.open(BACKUP / (Path(name).stem + ".blue_orig.png")).convert("RGBA")
        b = Image.open(PROPS / name).convert("RGBA")
        rows.append((a, b))
    w = sum(im.width * Z + pad for im in rows[0]) + pad * 3
    h = sum(max(a.height, b.height) * Z + pad for a, b in rows) + pad
    sheet = Image.new("RGBA", (w, h), (40, 34, 26, 255))
    y = pad
    for a, b in rows:
        x = pad
        for im in (a, b):
            big = im.resize((im.width * Z, im.height * Z), Image.NEAREST)
            sheet.alpha_composite(big, (x, y))
            x += im.width * Z + pad * 3
        y += max(a.height, b.height) * Z + pad
    out = ROOT / "assets" / "_wip" / "_check_animal_recolor.png"
    sheet.save(out)
    print("  对照图（左=原图 右=修改后，各放大 %d 倍）-> %s" % (Z, out))


if __name__ == "__main__":
    main()
