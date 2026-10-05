#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
生成树木贴图（按 ART_STYLE.md 的 32 色板，可重新生成 / 调参）。

为什么需要这个脚本：
    手上的树木素材严重不足，而且第一版用错了：
      · tree_green_01(48x48) / tree_orange_01(48x48) 是**图块碎片** ——
        它们其实是"一棵大树树冠的四分之一"（左上角叶、右上角棕、左下土坡…），
        我却当成独立的树来摆。绿洲里那坨看不出形状的绿团就是这么来的。
      · tree_pink_01 / tree_small_02 是**完全空的**（0% 不透明像素）。
    真正能用的完整树只剩 tree_dead_01、tree_palm_01、tree_small_01
    和 tiny-town 的四张 16x16。

题材考量：
    新疆最标志性的两种树是**白杨（新疆杨）**和**胡杨**。
    胡杨尤其贴题 ——「生而千年不死，死而千年不倒，倒而千年不朽」，
    是塔里木盆地荒漠河岸的标志树种，正好长在坎儿井这种绿洲边上。
    用胡杨替代通用的绿色圆树，既更好认，也更符合地域。

输出目录：assets/tiles/nature/
用法：
    .venv\\Scripts\\python.exe scripts\\pipeline\\make_trees.py
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw  # noqa: E402

sys.path.insert(0, str(Path(__file__).resolve().parent))

from postprocess import PALETTE_HEX  # noqa: E402

OUT = Path(__file__).resolve().parents[2] / "assets" / "tiles" / "nature"

# 全部取自 ART_STYLE.md 的 32 色
OUTLINE = "#2B2118"
TRUNK_DARK = "#6B4F33"
TRUNK = "#8B6B47"

GREEN_DARK = "#3F6B4C"
GREEN_MID = "#6E8F55"
GREEN = "#7FA34A"
GREEN_LIGHT = "#8A9B62"

GOLD_DARK = "#B8935F"
GOLD_MID = "#D4A93C"
GOLD = "#E0A43C"
GOLD_LIGHT = "#B5B04E"

PALE = "#F0E4D0"


def _rgb(s: str) -> tuple[int, int, int]:
    h = s.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]


def _blob(img: Image.Image, cx: float, cy: float, rx: float, ry: float, color: str) -> None:
    d = ImageDraw.Draw(img)
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=_rgb(color))


def _outline(img: Image.Image, color: str = OUTLINE) -> Image.Image:
    """给不透明区域描 1px 边 —— 这套像素素材整体是深色描边风格，不描边会显得飘。"""
    w, h = img.size
    src = img.load()
    out = img.copy()
    dst = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3] > 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] > 0:
                    dst[x, y] = (*_rgb(color), 255)
                    break
    return out


def _highlights(img: Image.Image, spots: list[tuple[int, int, str]]) -> None:
    px = img.load()
    for x, y, c in spots:
        if 0 <= x < img.width and 0 <= y < img.height and px[x, y][3] > 0:
            px[x, y] = (*_rgb(c), 255)


def make_oak(w: int = 32, h: int = 32, *, autumn: bool = False) -> Image.Image:
    """圆冠阔叶树。冠用几个椭圆叠加成不规则形状，避免看起来像个球。"""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    trunk_top = h - 9
    # 树干
    d = ImageDraw.Draw(img)
    d.rectangle([w // 2 - 2, trunk_top, w // 2 + 1, h - 2], fill=_rgb(TRUNK))
    d.rectangle([w // 2 - 2, trunk_top, w // 2 - 1, h - 2], fill=_rgb(TRUNK_DARK))

    dark, mid, light = (GOLD_DARK, GOLD_MID, GOLD) if autumn else (GREEN_DARK, GREEN_MID, GREEN)
    _blob(img, w * 0.50, h * 0.36, w * 0.36, h * 0.28, dark)
    _blob(img, w * 0.34, h * 0.30, w * 0.24, h * 0.20, mid)
    _blob(img, w * 0.66, h * 0.32, w * 0.22, h * 0.19, mid)
    _blob(img, w * 0.50, h * 0.22, w * 0.24, h * 0.16, mid)
    _blob(img, w * 0.42, h * 0.26, w * 0.16, h * 0.12, light)

    img = _outline(img)
    _highlights(img, [(int(w * 0.38), int(h * 0.22), PALE),
                      (int(w * 0.44), int(h * 0.20), PALE)])
    return img


def make_poplar(w: int = 16, h: int = 40) -> Image.Image:
    """白杨（新疆杨）：细高的塔形冠，新疆防风林到处都是这个轮廓。"""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([w // 2 - 1, h - 8, w // 2, h - 2], fill=_rgb(TRUNK_DARK))

    # 塔形冠：上窄下宽，用一串横向椭圆堆出来
    steps = 9
    for i in range(steps):
        t = i / (steps - 1)
        cy = h * 0.10 + t * (h * 0.72)
        half = 1.2 + t * (w * 0.34)
        color = GREEN_DARK if t > 0.72 else (GREEN_MID if i % 2 else GREEN)
        _blob(img, w / 2.0, cy, half, h * 0.055, color)

    img = _outline(img)
    _highlights(img, [(w // 2 - 2, int(h * 0.22), GREEN_LIGHT),
                      (w // 2 - 1, int(h * 0.18), GREEN_LIGHT)])
    return img


def make_euphrates(w: int = 32, h: int = 40, *, seed: int = 0) -> Image.Image:
    """胡杨：枝干虬曲、冠层金黄色。荒漠河岸的标志树种。"""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # 虬曲的枝干：主干 + 两根斜伸的侧枝
    d.rectangle([w // 2 - 2, h - 16, w // 2 + 1, h - 2], fill=_rgb(TRUNK))
    d.rectangle([w // 2 - 2, h - 16, w // 2 - 1, h - 2], fill=_rgb(TRUNK_DARK))
    if seed % 2 == 0:
        d.line([(w // 2, h - 14), (w // 2 - 8, h - 20)], fill=_rgb(TRUNK_DARK))
        d.line([(w // 2 - 8, h - 20), (w // 2 - 10, h - 24)], fill=_rgb(TRUNK_DARK))
        d.line([(w // 2 + 1, h - 15), (w // 2 + 7, h - 21)], fill=_rgb(TRUNK_DARK))
    else:
        d.line([(w // 2, h - 14), (w // 2 + 8, h - 19)], fill=_rgb(TRUNK_DARK))
        d.line([(w // 2 + 1, h - 16), (w // 2 - 6, h - 22)], fill=_rgb(TRUNK_DARK))

    # 金黄的冠：散成几团而不是整块，做出胡杨稀疏的枝叶感
    clusters = [
        (0.30, 0.30, 0.20, 0.15), (0.54, 0.22, 0.22, 0.14),
        (0.74, 0.34, 0.18, 0.14), (0.44, 0.42, 0.20, 0.13),
        (0.62, 0.48, 0.16, 0.11),
    ]
    for i, (fx, fy, frx, fry) in enumerate(clusters):
        c = GOLD_DARK if i % 3 == 0 else (GOLD_MID if i % 2 else GOLD)
        _blob(img, w * fx, h * fy, w * frx, h * fry, c)
    _blob(img, w * 0.42, h * 0.26, w * 0.12, h * 0.08, GOLD_LIGHT)

    img = _outline(img)
    _highlights(img, [(int(w * 0.36), int(h * 0.22), PALE),
                      (int(w * 0.58), int(h * 0.18), PALE)])
    return img


VARIANTS = [
    ("tree_oak_01.png", lambda: make_oak(32, 32)),
    ("tree_oak_02.png", lambda: make_oak(32, 36, autumn=True)),
    ("tree_poplar_01.png", lambda: make_poplar(16, 40)),
    ("tree_poplar_02.png", lambda: make_poplar(20, 44)),
    ("tree_euphrates_01.png", lambda: make_euphrates(32, 40, seed=0)),
    ("tree_euphrates_02.png", lambda: make_euphrates(36, 44, seed=1)),
]


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    palette = {c.upper() for c in PALETTE_HEX}
    print(f"  色板 {len(PALETTE_HEX)} 色   输出 {OUT}")

    for name, fn in VARIANTS:
        img = fn()
        used = {f"#{r:02X}{g:02X}{b:02X}" for r, g, b, a in img.getdata() if a > 0}
        off = used - palette
        if off:
            print(f"  [X] {name} 用了色板外的颜色：{sorted(off)}")
            return 1
        img.save(OUT / name)
        opaque = sum(1 for _, _, _, a in img.getdata() if a > 0)
        print(f"  [OK] {name:<26} {img.width:>2}x{img.height:<3} "
              f"不透明 {opaque:>4}px  用了 {len(used)} 色  全部合规")

    print(f"\n  共生成 {len(VARIANTS)} 张（其中胡杨与白杨是新疆标志树种）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
