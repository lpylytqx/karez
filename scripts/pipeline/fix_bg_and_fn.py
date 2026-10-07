#!/usr/bin/env python -u
# -*- coding: utf-8 -*-
"""修两个 bug 并重出背景。

bug 1（背景变平）：暗角蒙版写反了。
    原来：vig 只在几圈"矩形轮廓"上亮，其余为 0；
          composite(dark, img, 255-vig) 于是在**大部分区域**取 dark
          —— 整张图被换成纯色，标准差从 23.9 掉到 2.4。
    改法：vig 做成**中心亮、边缘暗**的径向渐变（由大到小叠填充椭圆再模糊），
          然后 composite(dark, img, 255-vig) 就只在边缘压暗。✓

bug 2（NameError）：函数定义没插进去，调用插进去了。
    根因：我用一条 75 个短横的分隔线做锚点，而文件里是 74 个 ——
          **str.replace 匹配不上时是静默不动的**，我却照样打印了 ✓。
    改法：改锚到 `def build() -> None:` 之前，插入后**回读校验**。
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import ROOT  # noqa: E402

from PIL import Image, ImageDraw, ImageFilter, ImageStat  # noqa: E402

OUT = ROOT / "deliverables" / "assets" / "deck_bg.png"
F = ROOT / "scripts" / "pipeline" / "build_showcase.py"
W, H = 1920, 1080
DARK = (0x1E, 0x16, 0x10)
WARM = (0x46, 0x34, 0x22)
GOLD = (0xE0, 0xA4, 0x3C)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def make_bg() -> None:
    img = Image.new("RGB", (W, H))
    px = img.load()
    # ① 斜向渐变
    for y in range(H):
        ty = y / H * 0.45
        for x in range(W):
            px[x, y] = lerp(DARK, WARM, x / W * 0.55 + ty)

    # ② 沙丘横纹（幅度加大到看得见）
    for y in range(H):
        d = int(math.sin(y * 0.0125) * 7.5 + math.sin(y * 0.037 + 1.1) * 4.0
                + math.sin(y * 0.0042 + 2.3) * 5.5)
        if d:
            for x in range(W):
                r, g, b = px[x, y]
                px[x, y] = (max(0, min(255, r + d)), max(0, min(255, g + d)),
                            max(0, min(255, b + int(d * 0.75))))

    # ③ 浅色斜向光带（右上）
    glow = Image.new("L", (W, H), 0)
    gd = ImageDraw.Draw(glow)
    cx, cy = int(W * 0.84), int(-H * 0.12)
    for i in range(30):
        t = i / 30
        rr = int(1700 * (1 - t))
        gd.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=int(22 * (1 - t) ** 1.6))
    glow = glow.filter(ImageFilter.GaussianBlur(150))
    img = Image.composite(Image.new("RGB", (W, H), GOLD), img, glow)

    # ④ 几何菱格网（纯装饰，不声称任何具体传统纹样）
    lat = Image.new("L", (W, H), 0)
    ld = ImageDraw.Draw(lat)
    P = 64
    for i in range(-H // P - 1, W // P + 2):
        x0 = i * P
        ld.line([(x0, 0), (x0 + H, H)], fill=13, width=1)
        ld.line([(x0, H), (x0 + H, 0)], fill=13, width=1)
    lat = lat.filter(ImageFilter.GaussianBlur(0.6))
    img = Image.composite(Image.new("RGB", (W, H), (0x9A, 0x82, 0x62)), img, lat)

    # ⑤ 暗角 —— **中心亮、边缘暗**（上一版就是这里写反的）
    vig = Image.new("L", (W, H), 0)
    vd = ImageDraw.Draw(vig)
    for i in range(64):
        t = i / 63
        k = 1 - t * 0.94
        rx, ry = int(W * 0.80 * k), int(H * 0.88 * k)
        vd.ellipse([W // 2 - rx, H // 2 - ry, W // 2 + rx, H // 2 + ry],
                   fill=int(255 * t ** 0.8))
    vig = vig.filter(ImageFilter.GaussianBlur(70))
    img = Image.composite(Image.new("RGB", (W, H), (0x14, 0x0E, 0x0A)), img,
                          vig.point(lambda v: 255 - v))

    # ⑥ 细颗粒
    seed = 20261007
    p2 = img.load()
    for y in range(H):
        for x in range(W):
            seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
            n = ((seed >> 17) & 0x7) - 3
            if n:
                r, g, b = p2[x, y]
                p2[x, y] = (max(0, min(255, r + n)), max(0, min(255, g + n)),
                            max(0, min(255, b + n)))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT)
    st = ImageStat.Stat(img)
    print("  新背景 %s  均值 %s  标准差 %s（改前 23.9/12.3/4.6，上一版坏成 2.4）"
          % (img.size, [round(v) for v in st.mean], [round(v, 1) for v in st.stddev]))


def fix_fn() -> None:
    t = F.read_text(encoding="utf-8")
    if "def outline_cards" in t:
        print("  outline_cards 已存在，跳过")
        return
    fn = '''def outline_cards(prs, line=RGBColor(0x60, 0x4A, 0x30), lw=0.75) -> int:
    """给所有圆角矩形（= 卡片）加一道极细描边，把卡片从背景里托起来。

    判据用形状类型而非逐页指定：卡片一律是圆角矩形，而满幅压暗层、
    细金条、分隔线都是直角矩形 —— 这条规则不会误伤。
    """
    k = 0
    for sl in prs.slides:
        for sh in sl.shapes:
            try:
                if sh.auto_shape_type == MSO_SHAPE.ROUNDED_RECTANGLE:
                    sh.line.color.rgb = line
                    sh.line.width = Pt(lw)
                    k += 1
            except Exception:
                continue
    return k


'''
    anchor = "def build() -> None:"
    if anchor not in t:
        print("  [X] 找不到 build() 锚点")
        return
    t = t.replace(anchor, fn + anchor, 1)
    F.write_text(t, encoding="utf-8")
    # ★ 回读校验 —— 上一版就是"没改上却打印成功"
    back = F.read_text(encoding="utf-8")
    ok = "def outline_cards" in back and "k = outline_cards(prs)" in back
    print("  outline_cards 插入 + 回读校验：%s" % ("✓" if ok else "✗ 仍未成功"))
    import py_compile
    py_compile.compile(str(F), doraise=True)
    print("  语法检查通过")


if __name__ == "__main__":
    make_bg()
    fix_fn()
