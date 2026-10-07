#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
（临时验证）测试「SDXL 大图 → 整数最近邻降采样 → 降色到色板」能否产出可用的像素贴图。

为什么值得测：
    扩散模型不遵守 1px 网格，直接要 16x16 只会得到糊团。但如果
    ① 让模型出 1024x1024，再 ② 用**最近邻**按整数倍降采样（如 1024/16=64），
    就会强制生成一个真实的像素网格 —— 每 16 个源像素取 1 个，边缘是硬的。
    这一步是「AI 图能不能进像素游戏」的关键，先用一张图验证。

用法：
    .venv\\Scripts\\python.exe scripts\\pipeline\\_test_ai_pixelize.py
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image, ImageDraw

from postprocess import nearest  # noqa: E402  色板最近色

ROOT = Path(__file__).resolve().parents[2]
GEN = ROOT / "dsh-image-gen"
OUT = ROOT / "assets" / "_wip" / "_test_ai_pixelize.png"

# (源文件, 裁剪框(左,上,右,下), 目标边长)
# 裁剪框是手工估的：取画面里一个独立的物件
CASES = [
    ("image-aa618a38.png", (60, 40, 260, 240), 48, "SDXL 农舍 → 48px"),
    ("image-aa618a38.png", (500, 620, 780, 850), 48, "SDXL 大屋 → 48px"),
    ("image-69099f2b.png", (300, 340, 720, 700), 64, "SDXL 井亭 → 64px"),
]


def pixelize(src: Image.Image, size: int, box=None) -> Image.Image:
    """裁剪 → 最近邻降采样到 size（强制像素网格）→ 降色到色板。"""
    if box:
        src = src.crop(box)
    # 先缩到目标尺寸，用 NEAREST：这会产生真实的硬边像素网格
    small = src.resize((size, size), Image.NEAREST)
    # 降色到色板
    px = small.convert("RGB").load()
    for y in range(size):
        for x in range(size):
            px[x, y] = nearest(px[x, y])
    return small


def main() -> int:
    SCALE = 5
    GAP = 12

    tiles = []
    for name, box, size, label in CASES:
        p = GEN / name
        if not p.exists():
            print(f"  [X] 缺 {name}")
            return 1
        src = Image.open(p).convert("RGB")
        print(f"  {label:<22} 源 {src.size}  裁剪 {box}  目标 {size}x{size}")
        tiles.append((pixelize(src, size, box), size, label))

    # 拼一张对比表：上排原图裁剪（放大到同格），下排像素化结果
    cell = 260
    W = len(tiles) * cell + (len(tiles) + 1) * GAP
    H = cell * 2 + GAP * 3 + 20 * 2
    sheet = Image.new("RGB", (W, H), (26, 20, 16))
    draw = ImageDraw.Draw(sheet)

    for i, (_small, _size, label) in enumerate(tiles):
        name, box, _sz, _lb = CASES[i]
        src = Image.open(GEN / name).convert("RGB").crop(box)
        src = src.resize((cell, cell), Image.LANCZOS)
        x = GAP + i * (cell + GAP)
        sheet.paste(src, (x, GAP + 18))
        draw.text((x + 2, GAP + 2), "ORIGINAL (smooth)", fill=(200, 190, 175))

        small, _size2, _l2 = tiles[i]
        big = small.resize((cell, cell), Image.NEAREST)
        y = GAP * 2 + 18 + cell
        sheet.paste(big, (x, y + 18))
        draw.text((x + 2, y + 2), f"PIXELIZED {label}", fill=(240, 228, 208))

    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT)
    print(f"\n  对比表：{OUT}  ({sheet.width}x{sheet.height})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
