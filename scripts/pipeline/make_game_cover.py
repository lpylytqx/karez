#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""把 SDXL 出的关键插画做成《坎儿井》游戏封面（标题用真字体排版）。

两条定死的分工，这里各占一半：
  · 画面 —— 本地 SDXL 出（make_cover_art.py），要手绘感
  · 中文标题 —— **真字体排版**，绝不让扩散模型写字（写出来必然是错字）

排版上刻意做的几件事：
  · 标题**逐字绘制并加字距** —— 中文封面标题不加字距会显得挤，PIL 没有直接的字距参数
  · 标题加深色投影 + 左侧渐隐暗带 —— 保证任何底图上都读得清（这一条比好看更重要）
  · 金色细边框 + 四角角框，和 PPT/申报书用同一套视觉语言

输出：
  参赛材料/90-原始材料/游戏封面/封面_坎儿井_1920x1080.png   16:9（PPT、截图用）
  参赛材料/90-原始材料/游戏封面/封面_坎儿井_1080x1440.png   3:4（海报用）
  参赛材料/90-原始材料/游戏封面/封面_坎儿井_1080x1080.png   1:1（头像/缩略图用）

用法：.venv\\Scripts\\python.exe scripts\\pipeline\\make_game_cover.py
"""
from __future__ import annotations

import sys as _sys
from pathlib import Path as _Path
_sys.path.insert(0, str(_Path(__file__).resolve().parent))
from _root import ROOT  # 路径唯一解析处，不再写死盘符
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = ROOT
ART = ROOT / "dsh-image-gen" / "cover" / "cover_art_01.png"
OUT = ROOT / "参赛材料" / "90-原始材料" / "游戏封面"

GOLD = (0xE0, 0xA4, 0x3C)
CREAM = (0xF0, 0xE4, 0xD0)
DEEP = (0x2B, 0x21, 0x18)
MUTED = (0xC8, 0xB8, 0xA4)

SERIF = r"C:\Windows\Fonts\STZHONGS.TTF"      # 华文中宋：中式、端正，适合当主标题
SANS = r"C:\Windows\Fonts\msyhbd.ttc"          # 微软雅黑粗：副标题与信息行
SANS_R = r"C:\Windows\Fonts\msyh.ttc"


def track_text(draw, xy, text, font, fill, tracking=0, shadow=None, sh_off=5):
    """逐字绘制并加字距。PIL 没有字距参数，只能自己算。"""
    x, y = xy
    if shadow is not None:
        cx = x
        for ch in text:
            draw.text((cx + sh_off, y + sh_off), ch, font=font, fill=shadow)
            cx += draw.textlength(ch, font=font) + tracking
    for ch in text:
        draw.text((x, y), ch, font=font, fill=fill)
        x += draw.textlength(ch, font=font) + tracking
    return x


def text_w(draw, text, font, tracking=0):
    return sum(draw.textlength(c, font=font) for c in text) + tracking * (len(text) - 1)


def vgrad(im, box, color, a0, a1, horizontal=False, side="left"):
    """在指定区域铺一层渐隐色带（用来保证文字可读）。"""
    x0, y0, x1, y1 = box
    w, h = max(1, x1 - x0), max(1, y1 - y0)
    lay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = lay.load()
    for j in range(h):
        for i in range(w):
            t = (i / (w - 1)) if horizontal else (j / (h - 1))
            if horizontal and side == "right":
                t = 1 - t
            a = int((a0 + (a1 - a0) * t) * 255)
            px[i, j] = (*color, max(0, min(255, a)))
    im.alpha_composite(lay, (x0, y0))


def frame(draw, W, H, inset=26, gold=GOLD, tw=3, corner=54, cw=6):
    draw.rectangle([inset, inset, W - inset, H - inset], outline=gold, width=tw)
    c = corner
    for cx, cy, sx, sy in ((inset, inset, 1, 1), (W - inset, inset, -1, 1),
                           (inset, H - inset, 1, -1), (W - inset, H - inset, -1, -1)):
        draw.rectangle([min(cx, cx + sx * c), min(cy, cy + sy * cw),
                        max(cx, cx + sx * c), max(cy, cy + sy * cw)], fill=gold)
        draw.rectangle([min(cx, cx + sx * cw), min(cy, cy + sy * c),
                        max(cx, cx + sx * cw), max(cy, cy + sy * c)], fill=gold)


def cover_wide() -> Image.Image:
    art = Image.open(ART).convert("RGBA")
    W, H = 1920, 1080
    # 先按 16:9 裁（插画是 1344x768，比例一致）
    ar = art.width / art.height
    if ar > W / H:
        nw = int(art.height * W / H)
        art = art.crop(((art.width - nw) // 2, 0, (art.width + nw) // 2, art.height))
    else:
        nh = int(art.width * H / W)
        art = art.crop((0, (art.height - nh) // 2, art.width, (art.height + nh) // 2))
    im = art.resize((W, H), Image.LANCZOS)
    vgrad(im, (0, 0, 1080, H), DEEP, 0.90, 0.0, horizontal=True, side="left")
    vgrad(im, (0, H - 320, W, H), DEEP, 0.0, 0.72)

    d = ImageDraw.Draw(im)
    f_title = ImageFont.truetype(SERIF, 200)
    track_text(d, (150, 300), "坎儿井", f_title, CREAM, tracking=34,
               shadow=(20, 14, 10))
    d.rectangle([164, 566, 164 + 520, 566 + 5], fill=GOLD)
    f_sub = ImageFont.truetype(SANS, 44)
    d.text((164, 602), "AI 原生 · 新疆丝路经营游戏", font=f_sub, fill=GOLD)
    f_tag = ImageFont.truetype(SANS_R, 31)
    d.text((166, 676), "引来天山雪水，把荒漠变回绿洲", font=f_tag, fill=MUTED)
    f_team = ImageFont.truetype(SANS_R, 27)
    d.text((166, 940), "代码一次敲队", font=f_team, fill=MUTED)
    d.text((166, 978), "双击即玩　·　AI 在线与离线两种状态都能演示",
           font=ImageFont.truetype(SANS_R, 22), fill=(0x9A, 0x8A, 0x78))
    frame(d, W, H)
    return im


def cover_poster() -> Image.Image:
    """3:4 竖版海报：中式留白，标题压在下三分之一。"""
    art = Image.open(ART).convert("RGBA")
    W, H = 1080, 1440
    ar = art.width / art.height
    if ar > W / H:
        nw = int(art.height * W / H)
        art = art.crop(((art.width - nw) // 2, 0, (art.width + nw) // 2, art.height))
    else:
        nh = int(art.width * H / W)
        art = art.crop((0, (art.height - nh) // 2, art.width, (art.height + nh) // 2))
    im = art.resize((W, H), Image.LANCZOS)
    vgrad(im, (0, H - 620, W, H), DEEP, 0.0, 0.90)
    d = ImageDraw.Draw(im)
    f_title = ImageFont.truetype(SERIF, 168)
    tw = text_w(d, "坎儿井", f_title, 30)
    track_text(d, ((W - tw) / 2, H - 470), "坎儿井", f_title, CREAM, tracking=30,
               shadow=(18, 12, 8))
    f_sub = ImageFont.truetype(SANS, 36)
    s = "AI 原生 · 新疆丝路经营游戏"
    d.text(((W - d.textlength(s, font=f_sub)) / 2, H - 258), s, font=f_sub, fill=GOLD)
    f_tag = ImageFont.truetype(SANS_R, 26)
    t = "引来天山雪水，把荒漠变回绿洲"
    d.text(((W - d.textlength(t, font=f_tag)) / 2, H - 198), t, font=f_tag, fill=MUTED)
    f_team = ImageFont.truetype(SANS_R, 22)
    tm = "代码一次敲队"
    d.text(((W - d.textlength(tm, font=f_team)) / 2, H - 116), tm, font=f_team,
           fill=(0x9A, 0x8A, 0x78))
    frame(d, W, H, inset=22, corner=44, cw=5)
    return im


def cover_square() -> Image.Image:
    art = Image.open(ART).convert("RGBA")
    W = H = 1080
    nh = art.height
    nw = int(nh * W / H)
    if nw <= art.width:
        art = art.crop(((art.width - nw) // 2, 0, (art.width + nw) // 2, nh))
    im = art.resize((W, H), Image.LANCZOS)
    vgrad(im, (0, H - 520, W, H), DEEP, 0.0, 0.88)
    d = ImageDraw.Draw(im)
    f_title = ImageFont.truetype(SERIF, 150)
    tw = text_w(d, "坎儿井", f_title, 26)
    track_text(d, ((W - tw) / 2, H - 400), "坎儿井", f_title, CREAM, tracking=26,
               shadow=(18, 12, 8))
    f_sub = ImageFont.truetype(SANS, 33)
    s = "AI 原生 · 新疆丝路经营游戏"
    d.text(((W - d.textlength(s, font=f_sub)) / 2, H - 212), s, font=f_sub, fill=GOLD)
    frame(d, W, H, inset=20, corner=40, cw=5)
    return im


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, im in (("封面_坎儿井_1920x1080.png", cover_wide()),
                     ("封面_坎儿井_1080x1440.png", cover_poster()),
                     ("封面_坎儿井_1080x1080.png", cover_square())):
        p = OUT / name
        im.convert("RGB").save(p, "PNG")
        print("  %-34s %s  %.0f KB" % (name, im.size, p.stat().st_size / 1024))


if __name__ == "__main__":
    main()
