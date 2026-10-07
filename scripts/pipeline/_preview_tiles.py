#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
（临时工具）把一批贴图拼成带序号的接触表，用来核对「这张图到底是什么」。

为什么需要：贴图提取时挑错编号是**隐蔽错误** —— 名字叫 pebble 的图里可能是青蓝斑块，
画面能跑、不报错，只是看着怪。靠肉眼逐张 open 太慢，拼成一张表一次看完。

用法：
    .venv\\Scripts\\python.exe scripts\\pipeline\\_preview_tiles.py <组名>
组名：scatter（地表撒物池） / sand（沙地底纹）
输出：assets/_wip/_preview_<组名>.png
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets"
OUT_DIR = ASSETS / "_wip"

SCALE = 10
GAP = 8
COLS = 5

GROUPS: dict[str, list[str]] = {
    # 与 map_view.gd 的 _scatter_ground() 里两个池子一致
    "scatter": [
        "tiles/props/rock_small_01.png",
        "tiles/props/rock_pile_01.png",
        "tiles/terrain/sand_ripple_01.png",
        "tiles/terrain/gravel_01.png",
        "tiles/terrain/dirt_patch_01.png",
        "tiles/props/herb_green_01.png",
        "tiles/props/bush_berry_01.png",
        "tiles/terrain/grass_flower_01.png",
        "tiles/terrain/grass_pebble_01.png",
        "tiles/props/mushroom_01.png",
    ],
    # 沙地底纹：墙纸感就出在这几张之间色调不一致
    "sand": [
        "tiles/terrain/sand_base_01.png",
        "tiles/terrain/sand_base_02.png",
        "tiles/terrain/sand_base_03.png",
        "tiles/terrain/sand_ripple_01.png",
        "tiles/terrain/gravel_01.png",
        "tiles/terrain/dirt_patch_01.png",
        "tiles/terrain/grass_sparse_base_01.png",
        "tiles/terrain/grass_medium_base_01.png",
        "tiles/terrain/grass_lush_base_01.png",
        "tiles/terrain/grass_flower_01.png",
    ],
}


def main() -> int:
    group = sys.argv[1] if len(sys.argv) > 1 else "scatter"
    names = GROUPS.get(group)
    if not names:
        print(f"未知组：{group}；可选 {list(GROUPS)}")
        return 1

    cell = 16 * SCALE
    rows = (len(names) + COLS - 1) // COLS
    W = COLS * cell + (COLS + 1) * GAP
    H = rows * cell + (rows + 1) * GAP
    sheet = Image.new("RGB", (W, H), (26, 20, 16))

    print(f"  {group} 组，{len(names)} 张，按行从左到右编号 1..{len(names)}\n")
    for i, rel in enumerate(names):
        p = ASSETS / rel
        mark = " " if p.exists() else "!"
        print(f"   {mark}{i + 1:>2}. {rel}")
        if not p.exists():
            continue
        img = Image.open(p).convert("RGB")
        # 尺寸不一的也贴，但保持原始比例放大到格子内
        w, h = img.size
        k = max(1, min(cell // w, cell // h))
        big = img.resize((w * k, h * k), Image.NEAREST)
        cx = GAP + (i % COLS) * (cell + GAP) + (cell - big.width) // 2
        cy = GAP + (i // COLS) * (cell + GAP) + (cell - big.height) // 2
        sheet.paste(big, (cx, cy))

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out = OUT_DIR / f"_preview_{group}.png"
    sheet.save(out)
    print(f"\n  接触表：{out}  ({W}x{H})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
