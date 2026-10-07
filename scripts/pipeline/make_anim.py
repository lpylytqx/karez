#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
生成小尺寸**动画序列图**（横向排列的帧带），用于地图上的动态效果。

为什么自己生成，而不直接用 assets/fx/ 里那批现成的
    那批（fx_water_splash 440x33、fx_water_pillar 270x41、fx_grass 72x13…）
    帧宽都不规整，得先反推每帧多少像素、再去数帧数，猜错就是「动画错位」。
    而且它们是别的美术包的调子，颜色不在我们的色板里。
    自己生成的好处：**帧尺寸完全可控**、颜色全部落在色板内、要几帧就几帧。

产出三组（都是横向帧带，RGBA，透明底）：
    fx_ripple  4 帧 x 16x16   水面闪烁的小光点，铺在涝坝与明渠上
    fx_flag    6 帧 x 12x16   旗子飘动，插在驿馆/巴扎屋顶上
    fx_flame   4 帧 x  9x12   火苗跳动，放在灶与营火处

设计要点
    · 光源仍来自左上，与 ART_STYLE.md 一致
    · 像素画不要抗锯齿：所有像素要么全不透明要么全透明
    · 帧与帧之间要有**可读的变化**，否则动画看起来是静止的

输出：assets/fx/
用法：
    .venv\\Scripts\\python.exe scripts\\pipeline\\make_anim.py
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image  # noqa: E402

from postprocess import PALETTE_HEX  # noqa: E402  单一色源

OUT = Path(__file__).resolve().parents[2] / "assets" / "fx"

# ── 用色（全部取自 34 色板）──
W_HI = "#E8EEF2"     # 雪水白：最亮的水光
W_MID = "#8FC7D6"    # 水面亮
W_LOW = "#5A9CB0"    # 水面主
F_RED = "#A8522F"    # 赭红主（旗面）
F_RED_HI = "#C9704A"  # 赭红亮
F_GOLD = "#E0A43C"   # 强调金
F_POLE = "#6B4F33"   # 木暗部（旗杆）
F_POLE_HI = "#8B6B47"  # 木（旗杆受光面）
L_CORE = "#E8C79A"   # 火心（最亮）
L_MID = "#E0A43C"    # 火中
L_OUT = "#C9704A"    # 火外


def _rgb(h: str) -> tuple[int, int, int, int]:
    s = h.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)  # type: ignore[return-value]


def _blank(fw: int, fh: int, n: int) -> Image.Image:
    return Image.new("RGBA", (fw * n, fh), (0, 0, 0, 0))


# ---------------------------------------------------------------------------
# 水面光点
# ---------------------------------------------------------------------------

def make_ripple(frames: int = 4, fw: int = 16, fh: int = 16) -> Image.Image:
    """
    一帧里几条 1px 的短横光，逐帧换位置与长度 —— 像水面上闪的光。
    刻意**不画成波纹线条**：16px 的格子里画完整波纹会变成一圈圈盘子纹，
    反而是零星的光点更像「水在动」。
    """
    img = _blank(fw, fh, frames)
    # 固定的光点轨迹表（不随机：随机会让重跑结果不一样，也不好调）
    GLINTS = [
        [(3, 4, 3), (9, 8, 2), (5, 12, 2)],
        [(6, 3, 2), (11, 7, 3), (2, 10, 2), (8, 13, 2)],
        [(4, 6, 4), (10, 11, 2), (7, 2, 2)],
        [(2, 5, 2), (8, 9, 3), (12, 13, 2), (5, 3, 2)],
    ]
    for f in range(frames):
        px = img.load()
        ox = f * fw
        for i, (x, y, ln) in enumerate(GLINTS[f % len(GLINTS)]):
            col = W_HI if i == 0 else W_MID
            for k in range(ln):
                xx = x + k
                if 0 <= xx < fw and 0 <= y < fh:
                    px[ox + xx, y] = _rgb(col)
            # 光点正下方压一档更暗的蓝，做出「浮在水上」的厚度
            if y + 1 < fh:
                for k in range(ln):
                    xx = x + k
                    if 0 <= xx < fw and px[ox + xx, y + 1][3] == 0:
                        px[ox + xx, y + 1] = _rgb(W_LOW)
    return img


# ---------------------------------------------------------------------------
# 旗子
# ---------------------------------------------------------------------------

def make_flag(frames: int = 6, fw: int = 12, fh: int = 16) -> Image.Image:
    """
    一根旗杆 + 一面三角旗。整面旗随相位上下摆动，尖端摆动幅度更大
    （旗子是软的：靠近杆的地方几乎不动，越往外越飘）。
    """
    img = _blank(fw, fh, frames)
    for f in range(frames):
        px = img.load()
        ox = f * fw
        phase = f / float(frames) * math.tau

        # ── 旗杆：左侧 2px，顶上带个球 ──
        for y in range(1, fh):
            px[ox + 1, y] = _rgb(F_POLE)
            px[ox + 2, y] = _rgb(F_POLE_HI)
        px[ox + 1, 0] = _rgb(F_GOLD)
        px[ox + 2, 0] = _rgb(F_GOLD)

        # ── 旗面：从 x=3 一直到右端，越远摆动越大 ──
        x0, x1 = 3, fw - 1
        span = float(x1 - x0)
        for x in range(x0, x1 + 1):
            t = (x - x0) / max(1.0, span)          # 0 靠杆 → 1 尖端
            swing = math.sin(phase + t * 2.2) * (0.6 + 2.6 * t)
            dy = int(round(swing))
            # 旗面高度：靠杆高，往尖端收窄（三角旗）
            half = 3.0 * (1.0 - 0.55 * t)
            cy = 5 + dy
            top = int(round(cy - half))
            bot = int(round(cy + half))
            for y in range(top, bot + 1):
                if 0 <= y < fh:
                    # 上半受光、下半背光
                    px[ox + x, y] = _rgb(F_RED_HI if y <= cy else F_RED)
    return img


# ---------------------------------------------------------------------------
# 火苗
# ---------------------------------------------------------------------------

def make_flame(frames: int = 4, fw: int = 9, fh: int = 12) -> Image.Image:
    """
    一团火：底下宽、往上收成尖。逐帧变的是**焰尖高度与倾斜** ——
    只换颜色不换形状的话，看起来像灯泡在闪，不像火在烧。
    """
    img = _blank(fw, fh, frames)
    TIP = [2, 3, 1, 3]          # 每帧的焰尖 y
    LEAN = [-1, 0, 1, 0]        # 每帧的倾斜方向
    for f in range(frames):
        px = img.load()
        ox = f * fw
        tip = TIP[f % len(TIP)]
        lean = LEAN[f % len(LEAN)]
        base = fh - 1
        for y in range(tip, base + 1):
            t = (y - tip) / max(1.0, float(base - tip))     # 0 焰尖 → 1 焰底
            half = int(round(t * 3.0))
            cx = fw // 2 + int(round(lean * (1.0 - t) * 1.6))
            for x in range(cx - half, cx + half + 1):
                if not (0 <= x < fw):
                    continue
                d = abs(x - cx)
                if d == 0 and t < 0.75:
                    col = L_CORE        # 焰心
                elif d <= 1:
                    col = L_MID         # 中层
                else:
                    col = L_OUT         # 外焰
                px[ox + x, y] = _rgb(col)
    return img


# ---------------------------------------------------------------------------

JOBS = [
    ("fx_ripple.png", make_ripple),
    ("fx_flag.png", make_flag),
    ("fx_flame.png", make_flame),
]


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    palette = {c.upper() for c in PALETTE_HEX}
    print(f"  色板 {len(PALETTE_HEX)} 色   输出 {OUT}\n")

    for name, fn in JOBS:
        img = fn()
        semi = 0
        used = set()
        for r, g, b, a in img.get_flattened_data():
            if a < 128:
                if a > 0:
                    semi += 1
                continue
            used.add(f"#{r:02X}{g:02X}{b:02X}")
        off = used - palette
        if off:
            print(f"  [X] {name} 用了色板外的颜色：{sorted(off)}")
            return 1
        fw = img.size[0]
        print(f"  [OK] {name:<16} {img.size[0]}x{img.size[1]}  "
              f"{len(used)} 色  半透明像素 {semi}")
        img.save(OUT / name)

    print(f"\n  共生成 {len(JOBS)} 张动画帧带")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
