#!/usr/bin/env python -u
# -*- coding: utf-8 -*-
"""生成展示稿的背景底纹 —— 替代原来那张"接近纯深褐"的 deck_bg.png。

原来那张实测：均值 RGB(55,40,27)、标准差 (23.9,12.3,4.6)，投到大屏上就是一块深色。
这一版按游戏的暖色板重新做一张，加四层质感：

  1. 斜向渐变     左上更暗、右下偏暖，给版面一个"光来的方向"
  2. 沙丘横纹     低频正弦横向叠层，模拟沙漠风纹（游戏的主场景就是沙漠）
  3. 几何菱格     64px 间距的极淡菱格网，纯几何装饰（不声称任何具体传统纹样）
  4. 暗角 + 颗粒   四周压暗把视线收进版面中心，细颗粒去掉塑料感

全部用 Pillow 程序化生成 —— 符合项目的双轨美术原则：
**受网格/配色约束的纹理走确定性程序，只有插画才交给扩散模型。**
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import ROOT  # noqa: E402

from PIL import Image, ImageDraw, ImageFilter  # noqa: E402

OUT = ROOT / "deliverables" / "assets" / "deck_bg.png"
W, H = 1920, 1080

# 直接取自游戏色板（postprocess.py 的 PALETTE_HEX）
DARK = (0x22, 0x1A, 0x13)
WARM = (0x3E, 0x2E, 0x1E)
GOLD = (0xE0, 0xA4, 0x3C)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def main() -> None:
    img = Image.new("RGB", (W, H))
    px = img.load()

    # ① 斜向渐变
    for y in range(H):
        for x in range(W):
            t = (x / W * 0.55 + y / H * 0.45)
            px[x, y] = lerp(DARK, WARM, t)

    # ② 沙丘横纹：两条不同频率的正弦叠层，极低幅度
    for y in range(H):
        band = (math.sin(y * 0.0125) * 4.2 + math.sin(y * 0.037 + 1.1) * 2.4
                + math.sin(y * 0.0042 + 2.3) * 3.0)
        d = int(band)
        if d == 0:
            continue
        for x in range(W):
            r, g, b = px[x, y]
            px[x, y] = (max(0, min(255, r + d)), max(0, min(255, g + d)),
                        max(0, min(255, b + int(d * 0.8))))

    # ③ 浅色斜向光带（从右上过来，很弱）
    glow = Image.new("L", (W, H), 0)
    gd = ImageDraw.Draw(glow)
    for i in range(26):
        t = i / 26
        rr = int(1500 * (1 - t))
        cx, cy = int(W * 0.82), int(-H * 0.10)
        gd.ellipse([cx - rr, cy - rr, cx + rr, cy + rr],
                   fill=int(9 * (1 - t)))
    glow = glow.filter(ImageFilter.GaussianBlur(120))
    gold_img = Image.new("RGB", (W, H), GOLD)
    img = Image.composite(gold_img, img, glow.point(lambda v: min(255, v * 3)))

    # ④ 几何菱格网：极淡，纯装饰
    lat = Image.new("L", (W, H), 0)
    ld = ImageDraw.Draw(lat)
    P = 64
    for i in range(-H // P - 1, W // P + 2):
        x0 = i * P
        ld.line([(x0, 0), (x0 + H, H)], fill=16, width=1)
        ld.line([(x0, H), (x0 + H, 0)], fill=16, width=1)
    lat = lat.filter(ImageFilter.GaussianBlur(0.5))
    cream = Image.new("RGB", (W, H), (0x8A, 0x74, 0x58))
    img = Image.composite(cream, img, lat)

    # ⑤ 暗角
    vig = Image.new("L", (W, H), 0)
    vd = ImageDraw.Draw(vig)
    for i in range(38):
        t = i / 38
        m = int(min(W, H) * (0.62 + t * 0.30))
        vd.rectangle([m * 0.36, m * 0.16, W - m * 0.36, H - m * 0.16],
                     outline=int(190 * (1 - t)))
    vig = vig.filter(ImageFilter.GaussianBlur(90))
    img = Image.composite(Image.new("RGB", (W, H), DARK), img,
                          vig.point(lambda v: 255 - v))

    # ⑥ 细颗粒（确定性伪随机，可复现）
    seed = 20261007
    for y in range(0, H, 1):
        for x in range(0, W, 1):
            seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
            n = ((seed >> 16) & 0x7) - 3
            if n:
                r, g, b = px[x, y] = img.getpixel((x, y))
                img.putpixel((x, y), (max(0, min(255, r + n)),
                                      max(0, min(255, g + n)),
                                      max(0, min(255, b + n))))

    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT)
    from PIL import ImageStat
    st = ImageStat.Stat(img)
    print("  已生成 %s  %s" % (OUT.name, img.size))
    print("    均值 %s  标准差 %s" % ([round(v) for v in st.mean],
                                     [round(v, 1) for v in st.stddev]))
    print("    （改前标准差 23.9/12.3/4.6 —— 越大越有质感）")


if __name__ == "__main__":
    main()
