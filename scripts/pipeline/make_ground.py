#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
生成可平铺的地面贴图（16x16，纯色 + 稀疏细点）。

为什么需要：
    Ninja Adventure 那批素材里**没有"纯地面底纹"**。能当底纹用的两张
    （desert_light_01/02）其实带明显装饰斑块，是**地形过渡贴图**；
    草地那几张（grass_sparse/medium/lush）则带着等距重复的浅色弧线。
    16x16 的小块平铺 880 次之后，这些特征就会形成肉眼可见的**墙纸效果**
    —— 一眼看出是贴图而不是地面（实机截图确认过）。

设计原则（平铺底纹的通用要求）：
    · 低对比：整块 90% 以上是基色，只点少量 1px 细点
    · 无明显特征：不能有占面积 5% 以上的色块，否则平铺后必然形成规律
    · 多张变体：随机混用，进一步打散规律感
    · 颜色全部取自 ART_STYLE.md 的 32 色板

输出目录：assets/tiles/terrain/
用法：
    .venv\\Scripts\\python.exe scripts\\pipeline\\make_ground.py
"""

from __future__ import annotations

import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image  # noqa: E402

from postprocess import PALETTE_HEX  # noqa: E402  单一色源，避免两处色板漂移

TILE = 16
OUT = Path(__file__).resolve().parents[2] / "assets" / "tiles" / "terrain"

# 沙色梯度（亮 → 暗）
SAND_LIGHT = "#E8C79A"
SAND_MID = "#DFC398"
SAND_DARK = "#D9B382"
SAND_DEEP = "#C9A277"
# 草色梯度（干 → 润）
GRASS_DRY = "#B5B04E"
GRASS_MID = "#8A9B62"
GRASS_LUSH = "#7FA34A"
GRASS_DEEP = "#6E8F55"
GRASS_TEAL = "#5A8F6B"
GRASS_FRESH = "#6E9E5A"


def _rgb(h: str) -> tuple[int, int, int]:
    s = h.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]


def _speckle(img: Image.Image, colors: list[str], count: int, rng: random.Random) -> None:
    """点少量 1px 细点。数量刻意控制在个位数到十几 —— 多了就又变成规律纹样。"""
    px = img.load()
    for _ in range(count):
        px[rng.randrange(TILE), rng.randrange(TILE)] = _rgb(rng.choice(colors))


def _ripple(img: Image.Image, color: str, rng: random.Random, rows: int) -> None:
    """几段 1px 横向波浪。分段而非通长，避免形成直线规律。"""
    px = img.load()
    used: set[int] = set()
    for _ in range(rows):
        y = rng.randrange(2, TILE - 2)
        if y in used:
            continue
        used.add(y)
        start = rng.randrange(0, TILE)
        length = rng.randrange(4, TILE - 2)
        for i in range(length):
            x = (start + i) % TILE
            px[x, y] = _rgb(color)
            if rng.random() < 0.25:
                px[x, min(TILE - 1, y + 1)] = _rgb(color)


# (文件名, 基色, 细点色, 细点数, 波浪行数)
GROUND: list[tuple[str, str, list[str], int, int]] = [
    # 沙地
    # ⚠ 五张**必须同基色**（都用 SAND_LIGHT）。原来 sand_base_03 用的 SAND_MID，
    #   比其余几张系统性地暗一档 —— 平铺 880 次后，这一档色差就变成沙地上一块块
    #   等距的浅色/深色矩形，也就是「墙纸感」的来源（实机截图确认）。
    #   变体之间的差别只应该来自**细点数量**，不能来自基色。
    ("sand_base_01.png", SAND_LIGHT, [SAND_MID], 6, 0),
    ("sand_base_02.png", SAND_LIGHT, [SAND_MID, SAND_DARK], 9, 0),
    ("sand_base_03.png", SAND_LIGHT, [SAND_DEEP], 7, 0),
    ("sand_base_04.png", SAND_LIGHT, [SAND_MID], 12, 0),
    ("sand_base_05.png", SAND_LIGHT, [SAND_DARK], 8, 0),
    # 带一道风纹的沙地。只作**地表点缀**用，不参与地形平铺 ——
    # 它那道横向纹是「有特征」的，当地形底纹平铺会形成规律。
    ("sand_ripple_01.png", SAND_LIGHT, [SAND_MID], 4, 1),
    # 稀疏草（干黄绿）
    ("grass_sparse_base_01.png", GRASS_DRY, [GRASS_MID, SAND_DARK], 8, 0),
    ("grass_sparse_base_02.png", GRASS_DRY, [GRASS_MID], 12, 0),
    # 中草
    ("grass_medium_base_01.png", GRASS_MID, [GRASS_DEEP, GRASS_DRY], 8, 0),
    ("grass_medium_base_02.png", GRASS_MID, [GRASS_LUSH], 11, 0),
    # 茂盛草
    ("grass_lush_base_01.png", GRASS_LUSH, [GRASS_DEEP, GRASS_FRESH], 8, 0),
    ("grass_lush_base_02.png", GRASS_LUSH, [GRASS_TEAL], 11, 0),
]


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    palette = {c.upper() for c in PALETTE_HEX}
    print(f"  色板 {len(PALETTE_HEX)} 色   输出 {OUT}")

    for i, (name, base, flecks, count, ripples) in enumerate(GROUND):
        rng = random.Random(20261005 + i)   # 固定种子：可复现，重跑结果不变
        img = Image.new("RGB", (TILE, TILE), _rgb(base))
        if ripples:
            _ripple(img, flecks[0], rng, rows=ripples)
        _speckle(img, flecks, count, rng)

        used = {f"#{r:02X}{g:02X}{b:02X}" for r, g, b in img.get_flattened_data()}
        off = used - palette
        if off:
            print(f"  [X] {name} 用了色板外的颜色：{sorted(off)}")
            return 1
        img.save(OUT / name)
        print(f"  [OK] {name:<26} 用了 {len(used)} 色  全部合规")

    print(f"\n  共生成 {len(GROUND)} 张（5 沙 + 1 风纹 + 6 草）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
