#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
生成「纯沙漠底」贴图（16x16，可无缝平铺）。

为什么需要这个脚本：
    Ninja Adventure 那批素材里**没有纯沙漠底纹**。仅有的两张沙漠图
    （desert_light_01/02）各自带一块橙黄色斑块，它们是**地形过渡贴图**，
    设计上放在沙漠与别的地形的交界处做装饰。

    把它们当整张地图的底纹平铺（40x22 = 880 次）会得到墙纸效果 ——
    斑块等距重复，一眼就看得出是贴图而不是沙地。实机截图确认过。

    所以这里按 ART_STYLE.md 的 32 色板程序化生成几张，
    既保证配色合规，又能随时重新生成 / 调参。

设计原则（平铺底纹的通用要求）：
    · 低对比：整块 90% 以上是基色，只点少量 1px 细点
    · 无明显特征：不能有任何占面积 5% 以上的色块，否则平铺后必然形成规律
    · 多张变体：随机混用，进一步打散规律感

输出目录：assets/tiles/terrain/
用法：
    .venv\\Scripts\\python.exe scripts\\pipeline\\make_sand.py
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

# 色板里的沙色梯度（由亮到暗），全部来自 ART_STYLE.md 的 32 色
SAND_LIGHT = "#E8C79A"
SAND_MID = "#DFC398"
SAND_DARK = "#D9B382"
SAND_DEEP = "#C9A277"


def _rgb(hex_s: str) -> tuple[int, int, int]:
    h = hex_s.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]


def _blank(color: str) -> Image.Image:
    return Image.new("RGB", (TILE, TILE), _rgb(color))


def _speckle(img: Image.Image, colors: list[str], count: int,
             rng: random.Random) -> None:
    """点少量 1px 细点。数量刻意控制在个位数 —— 多了就又变成规律纹样。"""
    px = img.load()
    for _ in range(count):
        x = rng.randrange(TILE)
        y = rng.randrange(TILE)
        px[x, y] = _rgb(rng.choice(colors))


def _ripple(img: Image.Image, color: str, rng: random.Random,
            rows: int = 2) -> None:
    """加几段 1px 横向波浪线，模拟风吹沙脊。分段而非通长，避免形成直线规律。"""
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
            # 偶尔向下错一格，做出斜度
            if rng.random() < 0.25:
                px[x, min(TILE - 1, y + 1)] = _rgb(color)


VARIANTS: list[tuple[str, str, list[str], int, int]] = [
    # (文件名, 基色, 细点色, 细点数, 波浪行数)
    ("sand_base_01.png", SAND_LIGHT, [SAND_MID, SAND_DARK], 7, 0),
    ("sand_base_02.png", SAND_LIGHT, [SAND_MID, SAND_DEEP], 11, 0),
    ("sand_base_03.png", SAND_MID, [SAND_DARK, SAND_DEEP], 9, 1),
    ("sand_ripple_01.png", SAND_LIGHT, [SAND_MID], 5, 2),
]


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    palette = {c.upper() for c in PALETTE_HEX}
    print(f"  色板 {len(PALETTE_HEX)} 色，输出目录 {OUT}")

    made = 0
    for i, (name, base, flecks, count, ripples) in enumerate(VARIANTS):
        rng = random.Random(20261005 + i)  # 固定种子：可复现，不因重跑而变
        img = _blank(base)
        if ripples:
            _ripple(img, flecks[0], rng, rows=ripples)
        _speckle(img, flecks, count, rng)

        # 自检：所有用到的颜色都必须在 32 色板内
        used = {f"#{r:02X}{g:02X}{b:02X}" for r, g, b in img.getdata()}
        off = used - palette
        if off:
            print(f"  [X] {name} 用了色板外的颜色：{sorted(off)}")
            return 1

        path = OUT / name
        img.save(path)
        made += 1
        print(f"  [OK] {name:<20} 用了 {len(used)} 色  全部合规")

    print(f"  共生成 {made} 张")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
