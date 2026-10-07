#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
生成地表点缀（小石子 / 砾石 / 土斑），**带透明通道**。

背景：为什么需要
    map_view 的地表撒物池原来引用了 gravel_01 / dirt_patch_01 / grass_pebble_01。
    核对后发现这三张**名字和内容对不上**（贴图提取时挑错编号，与之前「树其实是
    tileset 碎片」是同一类错误）：

        gravel_01.png        实际是「绿→棕」的地形交界块，不是砾石
        dirt_patch_01.png    实际是「沙→棕」的地形交界块，不是土斑
        grass_pebble_01.png  实际是青蓝色斑块，不是卵石  ← 草地上那些突兀的青色方块就是它

    而且三张都是**整块不透明**的地形图。作为「撒在地上的点缀」被平铺时，
    等于在沙地上贴满小方块 —— 画面能跑、不报错，只是看着怪。

设计原则
    · 带 alpha：点缀要能盖在地形上，不能是整块方块
    · 光源来自左上（与 ART_STYLE.md 一致）：顶面亮、右下暗
    · 尺寸小（2~5px 一个石子），撒下去才是「地面细节」而不是「地上的图标」
    · 颜色全部取自色板，且用**暖灰褐**而不是蓝灰 —— 沙地上的石头不该是蓝的

输出目录：assets/tiles/props/
用法：
    .venv\\Scripts\\python.exe scripts\\pipeline\\make_props.py
"""

from __future__ import annotations

import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image  # noqa: E402

from postprocess import PALETTE_HEX  # noqa: E402  单一色源，避免两处色板漂移

TILE = 16
OUT = Path(__file__).resolve().parents[2] / "assets" / "tiles" / "props"

# 石头的三级明暗（亮 / 中 / 暗）—— 取自色板的戈壁与生土色系
STONE_HI = "#C9A277"
STONE_MID = "#A88E6B"
STONE_LOW = "#8B6B47"
STONE_DEEP = "#6B4F33"
# 土斑
DIRT_HI = "#B8935F"
DIRT_MID = "#9E7C55"
DIRT_LOW = "#8B6B47"


def _rgb(h: str) -> tuple[int, int, int, int]:
    s = h.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)  # type: ignore[return-value]


def _stone(px, cx: int, cy: int, w: int, h: int, rng: random.Random) -> None:
    """
    一颗小石子。用「椭圆 + 顶面高光 + 右下阴影」三步 —— 光源统一来自左上，
    否则满地的石头会有互相矛盾的光影，非常明显。
    """
    for y in range(cy, cy + h):
        for x in range(cx, cx + w):
            if x < 0 or y < 0 or x >= TILE or y >= TILE:
                continue
            # 椭圆近似：离中心太远的角不要
            nx = (x - cx + 0.5) / w - 0.5
            ny = (y - cy + 0.5) / h - 0.5
            if nx * nx + ny * ny > 0.26:
                continue
            if y == cy or (x == cx and rng.random() < 0.7):
                px[x, y] = _rgb(STONE_HI)       # 左上受光
            elif y == cy + h - 1 or x == cx + w - 1:
                px[x, y] = _rgb(STONE_LOW)      # 右下背光
            else:
                px[x, y] = _rgb(STONE_MID)


def _patch(px, cx: int, cy: int, radius: float, rng: random.Random,
           hi: str, mid: str, low: str) -> None:
    """一块不规则的土斑/砾石堆。用随机半径做边缘，避免出现标准圆形。"""
    for y in range(TILE):
        for x in range(TILE):
            dx = x - cx
            dy = y - cy
            d = (dx * dx + dy * dy) ** 0.5
            edge = radius + rng.uniform(-0.9, 0.9)
            if d > edge:
                continue
            if d > edge - 1.0:
                px[x, y] = _rgb(low)            # 边缘压暗，贴地
            elif dx + dy < 0:
                px[x, y] = _rgb(hi)             # 左上受光
            else:
                px[x, y] = _rgb(mid)


def pebbles(seed: int, count: int) -> Image.Image:
    rng = random.Random(seed)
    img = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    px = img.load()
    # 撒点位置带最小间距，避免石头叠成一坨
    placed: list[tuple[int, int]] = []
    for _ in range(count * 6):
        if len(placed) >= count:
            break
        cx = rng.randrange(1, TILE - 4)
        cy = rng.randrange(1, TILE - 4)
        if any(abs(cx - ox) < 5 and abs(cy - oy) < 5 for ox, oy in placed):
            continue
        placed.append((cx, cy))
        _stone(px, cx, cy, rng.choice([3, 4]), rng.choice([2, 3]), rng)
    return img


def gravel(seed: int) -> Image.Image:
    rng = random.Random(seed)
    img = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    px = img.load()
    _patch(px, TILE // 2 + rng.randrange(-1, 2), TILE // 2 + rng.randrange(-1, 2),
           4.6, rng, STONE_HI, STONE_MID, STONE_LOW)
    # 补几颗散落的小石子
    for _ in range(2):
        _stone(px, rng.randrange(0, TILE - 3), rng.randrange(0, TILE - 3), 2, 2, rng)
    return img


def dirt(seed: int) -> Image.Image:
    rng = random.Random(seed)
    img = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    px = img.load()
    _patch(px, TILE // 2 + rng.randrange(-2, 3), TILE // 2 + rng.randrange(-2, 3),
           5.4, rng, DIRT_HI, DIRT_MID, DIRT_LOW)
    return img


# 文件名 -> 生成函数
PROPS: list[tuple[str, object]] = [
    ("pebble_01.png", lambda: pebbles(20261006, 3)),
    ("pebble_02.png", lambda: pebbles(20261007, 4)),
    ("pebble_03.png", lambda: pebbles(20261008, 2)),
    ("gravel_scatter_01.png", lambda: gravel(20261009)),
    ("gravel_scatter_02.png", lambda: gravel(20261010)),
    ("dirt_scatter_01.png", lambda: dirt(20261011)),
    ("dirt_scatter_02.png", lambda: dirt(20261012)),
]


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    palette = {c.upper() for c in PALETTE_HEX}
    print(f"  色板 {len(PALETTE_HEX)} 色   输出 {OUT}\n")

    for name, fn in PROPS:  # type: ignore[assignment]
        img = fn()  # type: ignore[operator]
        used = set()
        opaque = 0
        for r, g, b, a in img.get_flattened_data():
            if a < 128:
                continue
            opaque += 1
            used.add("#{:02X}{:02X}{:02X}".format(r, g, b))

        off = used - palette
        if off:
            print(f"  [X] {name} 用了色板外的颜色：{sorted(off)}")
            return 1
        if opaque == 0:
            print(f"  [X] {name} 是全透明的空图")
            return 1
        if opaque > TILE * TILE * 0.6:
            print(f"  [X] {name} 不透明像素占 {opaque / (TILE * TILE):.0%}，"
                  f"像是整块地形图而不是点缀（应 < 60%）")
            return 1

        img.save(OUT / name)
        print(f"  [OK] {name:<24} 不透明 {opaque:>3}/{TILE * TILE} 像素"
              f"  用 {len(used)} 色  全部合规")

    print(f"\n  共生成 {len(PROPS)} 张点缀，全部带透明通道、在色板内")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
