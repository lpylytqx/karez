#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""为答辩 PPT 生成两张「美化背景」用的素材：品牌标识 + 底纹。

为什么自己画而不是让扩散模型出：
  这两样都是**规则几何**（新疆风格的八角星纹、缠枝边饰），要求
  严格居中、可无损缩放、颜色精确落在项目的 34 色板内。
  程序化生成在这三件事上完胜 —— 和地图贴图是同一条道理。
  真正需要手绘感的（灾难过场插画）才走本地 SDXL。

输出：
  deliverables/assets/deck_logo.png   512x512  品牌标识（深底 + 金色八角星纹 + 坎字）
  deliverables/assets/deck_bg.png    1920x1080 底纹（极低对比，铺在 HTML 背景上）
"""
from __future__ import annotations

import sys as _sys
from pathlib import Path as _Path
_sys.path.insert(0, str(_Path(__file__).resolve().parent))
from _root import ROOT  # 路径唯一解析处，不再写死盘符
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(str(ROOT / "scripts/pipeline"))))

from PIL import Image, ImageDraw, ImageFont  # noqa: E402

from postprocess import PALETTE_HEX  # noqa: E402

OUT = Path(str(ROOT / "deliverables/assets"))
PAL = {c.upper() for c in PALETTE_HEX}

BG = "#2B2118"      # 深褐（PPT 背景色）
GOLD = "#E0A43C"    # 赭金（主色）
DEEP = "#A8522F"    # 深赭红
CREAM = "#F0E4D0"   # 奶白

for c in (BG, GOLD, DEEP, CREAM):
    assert c in PAL, "%s 不在 34 色板里" % c


def star8(d: ImageDraw.ImageDraw, cx: float, cy: float, r: float,
          r2: float, col, width: int = 0) -> None:
    """八角星纹：新疆/伊斯兰几何纹样里最常见的母题。"""
    pts = []
    for i in range(16):
        a = math.pi / 8 * i - math.pi / 2
        rr = r if i % 2 == 0 else r2
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    if width:
        d.line(pts + [pts[0]], fill=col, width=width, joint="curve")
    elif col is not None:
        d.polygon(pts, fill=col)


def make_logo() -> Image.Image:
    S = 512
    im = Image.new("RGB", (S, S), BG)
    d = ImageDraw.Draw(im)
    c = S / 2
    # 外圈：细环 + 一圈小八角星（缠枝边饰的简化）
    d.ellipse([c - 232, c - 232, c + 232, c + 232], outline=DEEP, width=6)
    for i in range(16):
        a = math.pi * 2 / 16 * i
        star8(d, c + 212 * math.cos(a), c + 212 * math.sin(a), 9, 4, GOLD)
    # 主体：深红八角星 → 金边 → 金八角星 → **深底中心**
    star8(d, c, c, 152, 64, DEEP)
    star8(d, c, c, 152, 64, GOLD, width=4)
    star8(d, c, c, 118, 50, GOLD)
    star8(d, c, c, 100, 42, BG)
    # ⚠ 关键一步：先把中心压成深底，再写奶白的字。
    #   第一版漏了这块深底，结果「坎」是奶白、它背后的星也是浅色 ——
    #   一片浅色里认不出字（截图核对才发现）。文字必须有对比底。
    d.ellipse([c - 84, c - 84, c + 84, c + 84], fill=BG, outline=GOLD, width=5)
    font = None
    for fp in (r"C:\Windows\Fonts\msyhbd.ttc", r"C:\Windows\Fonts\msyh.ttc",
               r"C:\Windows\Fonts\simhei.ttf"):
        if Path(fp).exists():
            font = ImageFont.truetype(fp, 116)
            break
    if font is not None:
        tb = d.textbbox((0, 0), "坎", font=font)
        d.text((c - (tb[2] - tb[0]) / 2 - tb[0], c - (tb[3] - tb[1]) / 2 - tb[1]),
               "坎", font=font, fill=CREAM)
    return im


def make_bg() -> Image.Image:
    """极低对比的底纹：只用八角星 + 细线，颜色压到背景附近，不抢文字。"""
    W, H = 1920, 1080
    im = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(im)
    # 背景色稍微往赭金偏一点点，做出暖调渐变感
    for y in range(H):
        t = y / H
        r = int(0x2B + (0x3A - 0x2B) * t)
        g = int(0x21 + (0x2C - 0x21) * t)
        b = int(0x18 + (0x1E - 0x18) * t)
        d.line([(0, y), (W, y)], fill=(r, g, b))
    step = 240
    for gy in range(-1, H // step + 2):
        for gx in range(-1, W // step + 2):
            x = gx * step + (step // 2 if gy % 2 else 0)
            y = gy * step
            # 用和背景只差几级的颜色：看得见纹样，但绝不抢文字
            star8(d, x, y, 54, 22, "#3A2C1F", width=2)
            star8(d, x, y, 28, 12, "#33261B", width=1)
    d.rectangle([0, 0, W - 1, H - 1], outline=DEEP, width=10)
    d.rectangle([14, 14, W - 15, H - 15], outline=GOLD, width=2)
    return im


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    logo = make_logo()
    logo.save(OUT / "deck_logo.png")
    bg = make_bg()
    bg.save(OUT / "deck_bg.png")
    print("  deck_logo.png  %s" % (logo.size,))
    print("  deck_bg.png    %s" % (bg.size,))
    # 自检：底纹不能有高对比像素（否则会抢文字）
    px = list(bg.resize((480, 270)).convert("L").getdata())
    print("  底纹亮度范围 %d~%d（应当很窄）" % (min(px), max(px)))


if __name__ == "__main__":
    main()
