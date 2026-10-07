#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
生成冬季雪地贴图（16x16），替换原来那批**跑出色板**的雪地底纹。

为什么重做：
    原来那批雪地贴图（snow_desert_01/02/03、snow_sparse/medium/lush…）不是走
    这条管线生成的，直接写文件、没过 postprocess，因此用了 8 个色板外的灰蓝
    （#CDD2DF ~ #DDE3F0）。后果有两层：

    1. **违反色板** —— 色板是风格统一的唯一保障，跑出去就等于埋了颗雷。
       由 scripts/pipeline/audit_palette.py 扫出来的。
    2. **看着发灰** —— 那 8 个颜色全挤在 16 个色阶内，明度几乎一样。
       地面没有明暗，冬天就是一块平板的灰紫色（实机截图确认）。

    第 2 点才是肉眼可见的那个问题。所以这一版不是「把颜色换合规」而已，
    而是**用有明暗差的梯度重建**：迎光面 #F2F7FA → 中调 #E8EEF2 →
    背光 #D5E0E9 → 沟壑 #AFC2D2，四个色阶拉开，雪才有体积。

设计原则（与 make_ground.py 一致，保持四季节贴图质感统一）：
    · 低对比、无明显特征 —— 否则 16x16 平铺 880 次会变成墙纸
    · 多张变体随机混用
    · 颜色全部取自 ART_STYLE.md 的色板（含新增的冬季雪地档）
    · 雪的纹理走向与其余季节一致，换季不会像换了一套美术

输出目录：assets/tiles/terrain/
用法：
    .venv\\Scripts\\python.exe scripts\\pipeline\\make_snow.py
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

# 雪色梯度（亮 → 影）—— 明度必须拉开，这是本次重做的核心
SNOW_HI = "#F2F7FA"      # 迎光面
SNOW_MID = "#E8EEF2"     # 中调（与「雪水白」同色）
SNOW_SHADE = "#D5E0E9"   # 背光坡
SNOW_DEEP = "#AFC2D2"    # 沟壑、踩踏痕
# 冬枯草：复用色板里的暖灰，雪下露出的秸秆
WINTER_DRY = "#B5A48C"


def _rgb(h: str) -> tuple[int, int, int]:
    s = h.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]


def _speckle(img: Image.Image, colors: list[str], count: int, rng: random.Random) -> None:
    """点少量 1px 细点。数量控制在个位数到十几，多了又变成规律纹样。"""
    px = img.load()
    for _ in range(count):
        px[rng.randrange(TILE), rng.randrange(TILE)] = _rgb(rng.choice(colors))


def _drift(img: Image.Image, color: str, rng: random.Random, rows: int) -> None:
    """
    几段 1px 横向波浪 —— 表现风吹雪的雪脊。分段而非通长，避免形成直线规律。
    与 make_ground._ripple 同一套做法，只换了颜色，所以四季纹理走向一致。
    """
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


def _patch(img: Image.Image, color: str, cells: int, rng: random.Random) -> None:
    """
    一两处 2x2 的小色块 —— 雪面不是均匀的，总有被踩过或化过的地方。
    刻意小且少：单块面积远低于 5%，平铺后不会形成规律。
    """
    px = img.load()
    for _ in range(cells):
        x = rng.randrange(0, TILE - 1)
        y = rng.randrange(0, TILE - 1)
        for dy in range(2):
            for dx in range(2):
                px[x + dx, y + dy] = _rgb(color)


# (文件名, 基色, 细点色, 细点数, 雪脊行数, 2x2 色块数)
#
# ⚠ 两条硬规则（都是从「沙地墙纸」那次错误里学来的）：
#   1. **同一档地形的所有变体必须同基色**，变体差别只能来自细点数量与颜色。
#      上一版 snow_desert_03 用了 SNOW_SHADE 当基色，比其余两张暗一档 ——
#      平铺 880 次后就成了满地等距的浅色/深色矩形（四季对比图上一眼可见）。
#   2. 基色之间**只在档位之间**不同（沙漠档 vs 草档），不是变体之间。
#      档位色差是层级区分，是设计；变体色差是失误。
SNOW: list[tuple[str, str, list[str], int, int, int]] = [
    # 雪覆沙漠：5 变体，全部 SNOW_MID 基色
    ("snow_desert_01.png", SNOW_MID, [SNOW_SHADE], 6, 0, 0),
    ("snow_desert_02.png", SNOW_MID, [SNOW_SHADE, SNOW_DEEP], 9, 0, 0),
    ("snow_desert_03.png", SNOW_MID, [SNOW_HI], 7, 0, 0),
    ("snow_desert_04.png", SNOW_MID, [SNOW_DEEP], 5, 0, 0),
    ("snow_desert_05.png", SNOW_MID, [SNOW_SHADE], 11, 0, 0),
    # 带一道风纹的雪地。只作地表点缀，不参与地形平铺
    ("snow_ripple_01.png", SNOW_MID, [SNOW_SHADE], 4, 1, 0),
    # 雪覆草：基色随**档位**变化（这是层级区别所在），同级变体同基色。
    # 差异主要靠露出的枯草密度 —— 雪盖住了一切，能看见的就是雪下的植被多少。
    ("snow_sparse_01.png", SNOW_MID, [WINTER_DRY], 8, 0, 0),
    ("snow_sparse_02.png", SNOW_MID, [WINTER_DRY], 12, 0, 0),
    ("snow_medium_01.png", SNOW_MID, [WINTER_DRY, SNOW_SHADE], 15, 0, 0),
    ("snow_medium_02.png", SNOW_MID, [WINTER_DRY], 18, 0, 0),
    ("snow_lush_01.png", SNOW_SHADE, [WINTER_DRY], 22, 0, 0),
    ("snow_lush_02.png", SNOW_SHADE, [WINTER_DRY, SNOW_DEEP], 26, 0, 0),
    # 通用雪地底（备用）
    ("snow_ground_01.png", SNOW_MID, [SNOW_SHADE, SNOW_HI], 9, 1, 0),
]


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    palette = {c.upper() for c in PALETTE_HEX}
    print(f"  色板 {len(PALETTE_HEX)} 色   输出 {OUT}")

    # 明度检查：雪色梯度必须真的拉开，否则又回到「一块灰布」
    lums = []
    for name, hexv in [("亮", SNOW_HI), ("中", SNOW_MID), ("暗", SNOW_SHADE), ("深", SNOW_DEEP)]:
        r, g, b = _rgb(hexv)
        lum = 0.299 * r + 0.587 * g + 0.114 * b
        lums.append((name, hexv, lum))
    spread = max(l for _n, _h, l in lums) - min(l for _n, _h, l in lums)
    print("  雪色梯度明度：", "  ".join(f"{n}{l:.0f}" for n, _h, l in lums))
    print(f"  明度跨度 {spread:.0f}（旧版那批只有约 16，是发灰的根因）")
    if spread < 30:
        print("  [X] 雪色明度跨度不足 30，会重新变得平板")
        return 1

    # ---- 回归护栏：同一档地形的变体必须同基色 ----
    # 这正是「沙地墙纸」和「雪地墙纸」两次错误的成因。做成硬检查，
    # 免得以后加变体时又手滑给某一张换个基色。
    by_level: dict[str, set[str]] = {}
    for name, base, _f, _c, _d, _p in SNOW:
        if name == "snow_ground_01.png":
            continue
        level = name.replace("snow_", "").rsplit("_", 1)[0]   # desert / ripple / sparse / medium / lush
        if level == "ripple":
            continue
        by_level.setdefault(level, set()).add(base.upper())

    bad = {lvl: bases for lvl, bases in by_level.items() if len(bases) > 1}
    if bad:
        print("  [X] 同一档地形的变体用了不同基色（会造成平铺后的墙纸感）：")
        for lvl, bases in bad.items():
            print(f"      {lvl}: {sorted(bases)}")
        return 1
    print("  基色一致性：", "  ".join(
        f"{lvl}={sorted(b)[0]}" for lvl, b in sorted(by_level.items())))

    for i, (name, base, flecks, count, drifts, cells) in enumerate(SNOW):
        rng = random.Random(20261006 + i)   # 固定种子：可复现
        img = Image.new("RGB", (TILE, TILE), _rgb(base))
        if drifts:
            _drift(img, flecks[0], rng, rows=drifts)
        if cells:
            _patch(img, flecks[-1], cells, rng)
        _speckle(img, flecks, count, rng)

        used = {f"#{r:02X}{g:02X}{b:02X}" for r, g, b in img.get_flattened_data()}
        off = used - palette
        if off:
            print(f"  [X] {name} 用了色板外的颜色：{sorted(off)}")
            return 1
        img.save(OUT / name)
        print(f"  [OK] {name:<24} 用了 {len(used)} 色  全部合规")

    print(f"\n  共重做 {len(SNOW)} 张雪地贴图，全部落在 {len(PALETTE_HEX)} 色板内")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
