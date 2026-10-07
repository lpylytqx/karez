#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
（临时工具）把过渡贴图拼成一张放大预览，用来**亲眼确认抖动效果**再进游戏渲染。

为什么需要：16x16 的贴图在 Godot 里平铺后会是什么观感，光看代码猜不出来。
先放大 12 倍看清楚像素结构，比反复跑游戏截图快得多。

输出：assets/_wip/_preview_transitions.png
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
TERRAIN = ROOT / "assets" / "tiles" / "terrain"
OUT = ROOT / "assets" / "_wip" / "_preview_transitions.png"

SCALE = 12
GAP = 6

# 每一行：一组「底纹 → 三档密度 → 内层底纹」，看清渐变是否连续
# 文件名规则：trans_{外层材质}_{内层材质}_d{密度}_{变体}.png
ROWS = [
    ("沙地 → 稀疏草", "sand", "sparse",
     ["sand_base_01.png", "trans_sand_sparse_d26_1.png", "trans_sand_sparse_d46_1.png",
      "trans_sand_sparse_d72_1.png", "grass_sparse_base_01.png"]),
    ("沙地 → 中草", "sand", "medium",
     ["sand_base_02.png", "trans_sand_medium_d26_2.png", "trans_sand_medium_d46_2.png",
      "trans_sand_medium_d72_2.png", "grass_medium_base_01.png"]),
    ("沙地 → 茂草", "sand", "lush",
     ["sand_base_03.png", "trans_sand_lush_d26_3.png", "trans_sand_lush_d46_3.png",
      "trans_sand_lush_d72_3.png", "grass_lush_base_01.png"]),
    ("稀疏 → 中草（草地内部）", "sparse", "medium",
     ["grass_sparse_base_01.png", "trans_sparse_medium_d26_1.png",
      "trans_sparse_medium_d46_1.png", "trans_sparse_medium_d72_1.png",
      "grass_medium_base_01.png"]),
    ("中 → 茂草（草地内部）", "medium", "lush",
     ["grass_medium_base_01.png", "trans_medium_lush_d26_2.png",
      "trans_medium_lush_d46_2.png", "trans_medium_lush_d72_2.png",
      "grass_lush_base_01.png"]),
    ("雪地 → 稀疏草", "snow", "snow_sparse",
     ["snow_desert_01.png", "trans_snow_snow_sparse_d26_1.png",
      "trans_snow_snow_sparse_d46_1.png", "trans_snow_snow_sparse_d72_1.png",
      "snow_sparse_01.png"]),
    ("雪地 → 茂草", "snow", "snow_lush",
     ["snow_desert_02.png", "trans_snow_snow_lush_d26_2.png",
      "trans_snow_snow_lush_d46_2.png", "trans_snow_snow_lush_d72_2.png",
      "snow_lush_01.png"]),
]

# 另外拼一条「连续边界」：模拟真实地图上 沙|草|d72|d46|d26|沙 的横切
EDGE_ROWS = [
    ["sand_base_01.png", "grass_sparse_base_01.png", "trans_sand_sparse_d72_1.png",
     "trans_sand_sparse_d46_2.png", "trans_sand_sparse_d26_3.png", "sand_base_02.png"],
]


def load(name: str) -> Image.Image:
    p = TERRAIN / name
    if not p.exists():
        raise FileNotFoundError(p)
    return Image.open(p).convert("RGB")


def up(img: Image.Image) -> Image.Image:
    return img.resize((16 * SCALE, 16 * SCALE), Image.NEAREST)


def main() -> int:
    cell = 16 * SCALE
    ncols = max(len(r[2]) for r in ROWS)
    nrows = len(ROWS) + len(EDGE_ROWS) + 2

    W = ncols * cell + (ncols + 1) * GAP
    H = nrows * cell + (nrows + 1) * GAP
    sheet = Image.new("RGB", (W, H), (26, 20, 16))   # 色板 #1A1410 附近，非纯黑

    y = GAP
    for _label, _g, _lvl, names in ROWS:
        x = GAP
        for name in names:
            sheet.paste(up(load(name)), (x, y))
            x += cell + GAP
        y += cell + GAP

    y += GAP * 2
    for names in EDGE_ROWS:
        x = GAP
        for name in names:
            sheet.paste(up(load(name)), (x, y))
            x += cell + GAP
        y += cell + GAP

    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT)
    print(f"  预览已生成：{OUT}")
    print(f"  尺寸 {W}x{H}，每格放大 {SCALE}x")
    print()
    print("  行的含义（从左到右）：")
    for label, _g, _lvl, names in ROWS:
        print(f"    {label:<14} 底纹 → d26 → d46 → d72 → 草底纹")
    print("    横切示意        沙 → 草 → d72 → d46 → d26 → 沙")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
