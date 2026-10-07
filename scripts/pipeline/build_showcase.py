#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""《坎儿井》作品展示 PPT —— **展示用，不是答辩用**。

方向上的区别（这一版存在的理由）：
  · 答辩稿是"证据型"：文化→机制映射表、371 项断言表、双轨美术表 —— 全是论证，
    评委要的是"凭什么信你"。
  · 展示稿是"画面型"：**先让人看见这个游戏长什么样**，一句话一层意思，
    数字和大段论证全部退到幕后（要看证据有申报书和答辩稿）。

所以这一版：
  · **图占版面主体**：整幅大图页 + 2×2 画面墙 + 大图配一句话
  · 每页文字不超过两三行，一行不超过二十来字
  · 删掉全部表格；只留四个大数字做"体量感"
  · 封面/收尾用整幅实机画面压暗铺满

用法：<bundled-python> scripts/pipeline/build_showcase.py
"""
from __future__ import annotations

import sys as _sys
from pathlib import Path as _Path
_sys.path.insert(0, str(_Path(__file__).resolve().parent))
from _root import ROOT  # 路径唯一解析处，不再写死盘符
from pathlib import Path

from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.oxml.ns import qn
from pptx.util import Inches, Pt
from PIL import Image

ROOT = ROOT
ASSETS = ROOT / "deliverables" / "assets"
SHOTS = ROOT / "docs" / "screenshots"
# 按图片框比例裁好的截图（make_deck_crops.py 生成）—— 16:9 直接塞进超宽框会缩小留白
CROPS = ROOT / "deliverables" / "assets" / "crops"
EVENTS = ROOT / "assets" / "events"
OUT = ROOT / "deliverables" / "坎儿井_作品展示.pptx"

BG = RGBColor(0x2B, 0x21, 0x18)
PANEL = RGBColor(0x22, 0x1A, 0x13)
GOLD = RGBColor(0xE0, 0xA4, 0x3C)
CREAM = RGBColor(0xF0, 0xE4, 0xD0)
DEEP = RGBColor(0xA8, 0x52, 0x2F)
MUTED = RGBColor(0xB5, 0xA4, 0x8C)
FONT = "微软雅黑"

W, H = Inches(13.333), Inches(7.5)
TOTAL = 10


def set_font(run, size, color, bold=False) -> None:
    run.font.size = Pt(size)
    run.font.color.rgb = color
    run.font.bold = bold
    run.font.name = FONT
    rPr = run._r.get_or_add_rPr()
    for tag in ("a:latin", "a:ea", "a:cs"):
        el = rPr.find(qn(tag))
        if el is None:
            el = rPr.makeelement(qn(tag), {})
            rPr.append(el)
        el.set("typeface", FONT)


def alpha_fill(shape, rgb, alpha: float) -> None:
    shape.fill.solid()
    shape.fill.fore_color.rgb = rgb
    sf = shape.fill._xPr.find(qn("a:solidFill"))
    sf.find(qn("a:srgbClr")).append(
        shape.fill._xPr.makeelement(qn("a:alpha"), {"val": str(int(alpha * 100000))}))


def rect(slide, l, t, w, h, fill=None, line=None, lw=1.0, alpha=None, rounded=False):
    shp = slide.shapes.add_shape(
        MSO_SHAPE.ROUNDED_RECTANGLE if rounded else MSO_SHAPE.RECTANGLE, l, t, w, h)
    if fill is None:
        shp.fill.background()
    elif alpha is not None:
        alpha_fill(shp, fill, alpha)
    else:
        shp.fill.solid()
        shp.fill.fore_color.rgb = fill
    if line is None:
        shp.line.fill.background()
    else:
        shp.line.color.rgb = line
        shp.line.width = Pt(lw)
    shp.shadow.inherit = False
    if rounded:
        shp.adjustments[0] = 0.08
    return shp


def textbox(slide, l, t, w, h, lines, anchor=MSO_ANCHOR.TOP, align=PP_ALIGN.LEFT):
    tb = slide.shapes.add_textbox(l, t, w, h)
    tf = tb.text_frame
    tf.word_wrap = True
    tf.vertical_anchor = anchor
    for i, item in enumerate(lines):
        text, size, color, bold = item[0], item[1], item[2], item[3]
        space = item[4] if len(item) > 4 else 0
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.space_before = Pt(space)
        p.space_after = Pt(4)
        p.alignment = align
        run = p.add_run()
        run.text = text
        set_font(run, size, color, bold)
    return tb


def pic_alpha(pic, alpha: float) -> None:
    blip = pic._element.blipFill.find(qn("a:blip"))
    blip.append(blip.makeelement(qn("a:alphaModFix"), {"amt": str(int(alpha * 100000))}))


def send_to_back(el, slide) -> None:
    parent = el.getparent()
    parent.remove(el)
    parent.insert(2, el)


def fit_box(slide, img, l, t, w, h, frame=True, border=GOLD, bw=1.25):
    """按图自身比例缩进框内，**不裁不拉伸**。"""
    with Image.open(img) as im:
        iw, ih = im.size
    ar, br = iw / ih, w / h
    if ar >= br:
        nw, nh = w, int(w / ar)
    else:
        nh, nw = h, int(h * ar)
    nl, nt = int(l + (w - nw) / 2), int(t + (h - nh) / 2)
    if frame:
        rect(slide, nl - Inches(0.035), nt - Inches(0.035),
             nw + Inches(0.07), nh + Inches(0.07), DEEP)
    pic = slide.shapes.add_picture(str(img), nl, nt, nw, nh)
    if frame:
        pic.line.color.rgb = border
        pic.line.width = Pt(bw)
    return pic


def base(prs, page, framed=True):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    p = s.shapes.add_picture(str(ASSETS / "deck_bg.png"), 0, 0, W, H)
    send_to_back(p._element, s)
    if framed:
        for cx, cy, sx, sy in ((Inches(0.3), Inches(0.3), 1, 1),
                               (W - Inches(0.3), Inches(0.3), -1, 1),
                               (Inches(0.3), H - Inches(0.3), 1, -1),
                               (W - Inches(0.3), H - Inches(0.3), -1, -1)):
            tw, sz = Pt(1.6), Inches(0.26)
            rect(s, cx, cy if sy > 0 else cy - tw, sz, tw, GOLD)
            rect(s, cx if sx > 0 else cx - tw, cy, tw, sz, GOLD)
    textbox(s, W - Inches(1.7), H - Inches(0.46), Inches(1.2), Inches(0.3),
            [("%02d / %d" % (page, TOTAL), 10, MUTED, False)], align=PP_ALIGN.RIGHT)
    # 大号八瓣星水印，与底纹的 star8 呼应（极淡，压在内容之下）
    # ⚠ 尺寸必须让右边缘与下边缘都落在页内（上一版 4.60 英寸宽放在 W-4.30 处，
    #   右边缘超出 0.30 英寸 —— 渲染看不出来，但几何自检会报越界）
    wm = s.shapes.add_picture(str(ASSETS / "deck_logo.png"),
                              W - Inches(4.35), H - Inches(4.55),
                              Inches(4.20), Inches(4.20))
    pic_alpha(wm, 0.055)
    send_to_back(wm._element, s)

    # 页脚：左下角补作品名与团队，让 10 页成套（原来只有右下角页码）
    rect(s, Inches(0.98), H - Inches(0.50), Inches(0.14), Pt(1.0), GOLD)
    textbox(s, Inches(1.22), H - Inches(0.55), Inches(6.0), Inches(0.3),
            [("坎儿井　·　代码一次敲队", 9.5, MUTED, False)])
    return s


def big_title(slide, l, t, w, text, size=34, color=CREAM):
    textbox(slide, l, t, w, Inches(0.8), [(text, size, color, True)])


def caption(slide, l, t, w, text, size=10.5):
    textbox(slide, l, t, w, Inches(0.32), [(text, size, MUTED, False)])


# --------------------------------------------------------------------------
def outline_cards(prs, line=RGBColor(0x60, 0x4A, 0x30), lw=0.75) -> int:
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


def build() -> None:
    prs = Presentation()
    prs.slide_width, prs.slide_height = W, H

    # ── 1 封面：整幅实机画面 ──
    s = prs.slides.add_slide(prs.slide_layouts[6])
    s.shapes.add_picture(str(SHOTS / "S10_deck_A_绿洲全景.png"), 0, 0, W, H)
    rect(s, 0, 0, W, H, BG, alpha=0.55)
    rect(s, 0, H - Inches(1.25), W, Inches(1.25), BG, alpha=0.5)
    rect(s, Inches(0.95), Inches(2.05), Inches(0.17), Inches(1.95), GOLD)
    textbox(s, Inches(1.40), Inches(1.85), Inches(9.6), Inches(1.5),
            [("坎儿井", 92, CREAM, True)])
    textbox(s, Inches(1.44), Inches(3.35), Inches(9.0), Inches(0.6),
            [("新疆两千年水利遗产 · 一款能玩的经营游戏", 21, GOLD, True)])
    rect(s, Inches(1.44), Inches(4.02), Inches(6.0), Pt(1.4), DEEP)
    textbox(s, Inches(1.42), Inches(4.22), Inches(9.2), Inches(0.9),
            [("你扮演一位丝路驿丞，用坎儿井引来天山雪水，", 16, CREAM, False, 0),
             ("把荒漠驿站建成绿洲重镇。", 16, CREAM, False, 2)])
    textbox(s, Inches(1.00), H - Inches(0.86), Inches(11), Inches(0.34),
            [("代码一次敲队　·　李鹏宇 / 王焕楷 / 李云天", 11, MUTED, False),
             ("指导教师：徐媛媛　/　李中岩", 11, GOLD, False, 3)])

    # ── 2 一句话说清 ──
    s = base(prs, 2)
    big_title(s, Inches(0.95), Inches(1.55), Inches(11.4),
              "从一口井开始，把荒漠变回绿洲", 33)
    rect(s, Inches(0.99), Inches(2.32), Inches(3.4), Pt(1.4), GOLD)
    textbox(s, Inches(0.97), Inches(2.58), Inches(11.4), Inches(1.5),
            [("游戏里没有「开局送资源」这回事。你接手的驿站因为坎儿井淤塞、"
              "水源断绝而衰败 —— 第一件事只能是挖井。", 16.5, MUTED, False),
             ("而你挖的这个东西，在现实里已经用了两千多年。", 17, GOLD, True, 10)])
    for i, (num, label) in enumerate([("6 段", "竖井逐段打通"),
                                      ("+55 方", "每段新增日出水"),
                                      ("4 级", "涝坝蓄水扩容")]):
        x = Inches(1.05) + i * Inches(3.9)
        rect(s, x, Inches(4.15), Inches(0.10), Inches(1.05), GOLD)
        textbox(s, x + Inches(0.26), Inches(4.05), Inches(3.4), Inches(0.7),
                [(num, 34, GOLD, True)])
        textbox(s, x + Inches(0.28), Inches(4.78), Inches(3.4), Inches(0.4),
                [(label, 13.5, CREAM, False)])
    caption(s, Inches(0.97), Inches(5.72), Inches(11), "实机截图：六段竖井全部挖通之后的绿洲")
    fit_box(s, CROPS / "p2_绿洲横带.png",
            Inches(1.10), Inches(5.96), Inches(10.4), Inches(1.06), frame=False)

    # ── 3 你每天在做的事 ──
    s = base(prs, 3)
    big_title(s, Inches(0.95), Inches(1.30), Inches(11.4), "九个岗位，抢的是同一批人", 33)
    rect(s, Inches(0.99), Inches(2.06), Inches(3.4), Pt(1.4), GOLD)
    textbox(s, Inches(0.97), Inches(2.34), Inches(11.4), Inches(0.8),
            [("多派一个人去挖井，就少一个人种地。每一次分配都是取舍。", 16.5, MUTED, False)])
    jobs = ["治水", "耕作", "采集", "经商", "守卫", "炊事", "做工", "演艺", "待命"]
    for i, j in enumerate(jobs):
        col, row = i % 3, i // 3
        x = Inches(1.10) + col * Inches(3.62)
        y = Inches(3.10) + row * Inches(1.16)
        rect(s, x, y, Inches(3.32), Inches(0.94), PANEL, alpha=0.88, rounded=True,
             line=GOLD, lw=1.0)
        textbox(s, x, y + Inches(0.24), Inches(3.32), Inches(0.5),
                [(j, 20, CREAM, True)], align=PP_ALIGN.CENTER)
    textbox(s, Inches(1.10), Inches(6.58), Inches(10.4), Inches(0.5),
            [("你怎么派人，直接决定战场上有什么兵。", 14, MUTED, False)])

    # ── 4 画面墙（2×2）──
    s = base(prs, 4)
    big_title(s, Inches(0.95), Inches(0.62), Inches(11.4), "四个画面，看懂这个游戏", 30)
    rect(s, Inches(0.99), Inches(1.28), Inches(3.4), Pt(1.4), GOLD)
    wall = [
        (CROPS / "p4_畜牧.png", "畜牧页", "抓野畜、养牲口、擀毡织毯"),
        (CROPS / "p4_木卡姆.png", "木卡姆", "奏乐台 + 艺人 + 热瓦普，才能办一场"),
        (CROPS / "p4_御敌.png", "御敌之战", "自由布阵，兵种由岗位决定"),
        (CROPS / "p4_灾难.png", "灾难通告", "插画由本地 SDXL 生成"),
    ]
    for i, (img, name, desc) in enumerate(wall):
        col, row = i % 2, i // 2
        x = Inches(1.00) + col * Inches(5.42)
        y = Inches(1.72) + row * Inches(2.72)
        fit_box(s, img, x, y, Inches(5.10), Inches(1.92))
        textbox(s, x, y + Inches(1.95), Inches(5.2), Inches(0.34),
                [(name, 13.5, GOLD, True)])
        textbox(s, x, y + Inches(2.24), Inches(5.2), Inches(0.34),
                [(desc, 11, MUTED, False)])

    # ── 5 御敌之战（整幅）──
    s = prs.slides.add_slide(prs.slide_layouts[6])
    s.shapes.add_picture(str(SHOTS / "S10_deck_D_御敌布阵.png"), 0, 0, W, H)
    rect(s, 0, H - Inches(2.55), W, Inches(2.55), BG, alpha=0.78)
    rect(s, Inches(0.95), H - Inches(2.18), Inches(0.15), Inches(1.55), GOLD)
    textbox(s, Inches(1.38), H - Inches(2.28), Inches(11), Inches(0.8),
            [("阵型不是装饰，它决定谁活着回来", 32, CREAM, True)])
    textbox(s, Inches(1.40), H - Inches(1.42), Inches(11), Inches(0.5),
            [("同样 5 打 4、同样随机种子，只换摆法 —— 阵亡从 0 人到 3 人。", 16, MUTED, False)])
    textbox(s, Inches(1.40), H - Inches(0.92), Inches(11), Inches(0.5),
            [("全员压前线 0.00　·　自动布阵 1.00　·　一字纵队 1.17　·　弓手出射程 3.00",
              14.5, GOLD, True)])

    # ── 6 灾难来了 ──
    s = base(prs, 6)
    big_title(s, Inches(0.95), Inches(1.25), Inches(11.4), "沙漠不会等你准备好", 33)
    rect(s, Inches(0.99), Inches(2.01), Inches(3.4), Pt(1.4), GOLD)
    textbox(s, Inches(0.97), Inches(2.28), Inches(11.4), Inches(0.9),
            [("沙暴、大旱、融雪洪水、寒潮、瘟疫、蝗灾 —— 每一种都能预判，也能被建筑挡住。",
              16.5, MUTED, False)])
    fit_box(s, EVENTS / "disaster_sandstorm.png", Inches(1.05), Inches(3.35),
            Inches(3.3), Inches(3.55), border=GOLD)
    caption(s, Inches(1.05), Inches(6.96), Inches(3.4), "本地 SDXL 生成的灾难插画")
    fit_box(s, SHOTS / "S9_animal_C_灾难日志.png", Inches(4.75), Inches(3.35),
            Inches(6.85), Inches(3.55))
    caption(s, Inches(4.75), Inches(6.96), Inches(7.5), "实机截图：沙暴来袭时的通告卡")
    textbox(s, Inches(4.78), Inches(2.98), Inches(7.5), Inches(0.4),
            [("烽燧挡沙暴　·　围墙挡洪水　·　仓库挡寒潮　·　驿馆与居所挡瘟疫",
              13.5, GOLD, True)])

    # ── 7 文化不是贴上去的 ──
    s = base(prs, 7)
    big_title(s, Inches(0.95), Inches(0.62), Inches(11.4),
              "文化不是贴上去的，它管着你每天怎么活", 31)
    rect(s, Inches(0.99), Inches(1.32), Inches(3.4), Pt(1.4), GOLD)
    cards = [
        ("十二木卡姆", "六套真实曲目可演奏",
         "要有人、有场地、有乐器，才办得起来"),
        ("艾德莱斯绸", "棉花 4 → 绸 1",
         "秋天收棉，作坊织绸，商队高价收"),
        ("古尔邦节", "牲畜 ≥5 头，声望 +4",
         "养牲口不只是经济行为，更是体面"),
    ]
    for i, (name, line1, line2) in enumerate(cards):
        x = Inches(1.00) + i * Inches(3.62)
        rect(s, x, Inches(2.05), Inches(3.32), Inches(4.55), PANEL, alpha=0.8,
             rounded=True)
        rect(s, x, Inches(2.05), Inches(3.32), Inches(0.11), GOLD)
        textbox(s, x + Inches(0.32), Inches(2.48), Inches(3.0), Inches(0.5),
                [(name, 22, CREAM, True)])
        rect(s, x + Inches(0.34), Inches(3.12), Inches(1.5), Pt(1.2), DEEP)
        textbox(s, x + Inches(0.32), Inches(3.36), Inches(3.0), Inches(0.5),
                [(line1, 15, GOLD, True)])
        textbox(s, x + Inches(0.32), Inches(3.92), Inches(2.98), Inches(1.4),
                [(line2, 13.5, MUTED, False)])
        fit_box(s, [CROPS / "p7_木卡姆.png",
                    CROPS / "p7_畜牧.png",
                    CROPS / "p7_事件卡.png"][i],
                x + Inches(0.32), Inches(4.62), Inches(2.68), Inches(1.62),
                frame=False)

    textbox(s, Inches(0.97), Inches(6.74), Inches(11.4), Inches(0.62),
            [("坎儿井开凿技艺 · 国家级非物质文化遗产　|　"
              "新疆坎儿井 · 2014 年入选世界灌溉工程遗产名录", 11, MUTED, False),
             ("十二木卡姆 · 2005 年列入联合国教科文组织人类口头和非物质遗产代表作名录",
              11, MUTED, False, 3)])

    # ── 8 技术三句 ──
    s = base(prs, 8)
    big_title(s, Inches(0.95), Inches(1.05), Inches(11.4), "三件让它可以被真正玩起来的事", 31)
    rect(s, Inches(0.99), Inches(1.80), Inches(3.4), Pt(1.4), GOLD)
    rows = [
        ("AI 在线时是活的，离线时照样能玩",
         "7 位角色由大模型实时驱动；断网后数值、存档、全部系统都在本地跑，游戏 100% 可玩。"),
        ("一套新系统，只改数据不碰代码",
         "23 段数值全部外置。畜牧、灾难、加工、节庆、音乐这五套后期系统，都是加数据做出来的。"),
        ("像素贴图自己画，插画交给 AI",
         "贴图要 16px 网格与 34 色板精确，用程序化生成；插画要不带像素约束的手绘感，用本地 SDXL。"),
    ]
    for i, (t1, t2) in enumerate(rows):
        y = Inches(2.28) + i * Inches(1.46)
        rect(s, Inches(1.00), y, Inches(10.60), Inches(1.24), PANEL, alpha=0.78,
             rounded=True)
        rect(s, Inches(0.95), y, Inches(0.12), Inches(1.24), GOLD)
        textbox(s, Inches(1.45), y + Inches(0.16), Inches(9.9), Inches(0.44),
                [(t1, 19, CREAM, True)])
        textbox(s, Inches(1.47), y + Inches(0.66), Inches(9.9), Inches(0.5),
                [(t2, 13, MUTED, False)])

    # ── 9 数字一览 ──
    s = base(prs, 9)
    big_title(s, Inches(0.95), Inches(1.35), Inches(11.4), "现在做到哪儿了", 33)
    rect(s, Inches(0.99), Inches(2.11), Inches(3.4), Pt(1.4), GOLD)
    stats = [("13,004", "行作品代码"), ("64", "条事件"),
             ("13", "座建筑"), ("421", "张美术资产")]
    for i, (num, lab) in enumerate(stats):
        x = Inches(1.10) + i * Inches(2.66)
        rect(s, x, Inches(2.85), Inches(2.42), Inches(2.35), PANEL, alpha=0.8,
             rounded=True)
        rect(s, x + Inches(1.06), Inches(2.85), Inches(0.30), Pt(2.0), GOLD)
        textbox(s, x, Inches(3.20), Inches(2.42), Inches(1.0),
                [(num, 40, GOLD, True)], align=PP_ALIGN.CENTER)
        textbox(s, x, Inches(4.18), Inches(2.42), Inches(0.5),
                [(lab, 14, CREAM, False)], align=PP_ALIGN.CENTER)
    textbox(s, Inches(1.05), Inches(5.52), Inches(11.2), Inches(0.9),
            [("全部数值与事件都是纯文本 JSON，任何人都可以直接打开核查。", 15, MUTED, False)])
    fit_box(s, CROPS / "p9_建造.png", Inches(8.30), Inches(5.28),
            Inches(4.0), Inches(1.65))

    # ── 10 收尾（整幅）──
    s = prs.slides.add_slide(prs.slide_layouts[6])
    s.shapes.add_picture(str(SHOTS / "S10_deck_A_绿洲全景.png"), 0, 0, W, H)
    rect(s, 0, 0, W, H, BG, alpha=0.66)
    rect(s, Inches(0.95), Inches(2.35), Inches(0.15), Inches(1.7), GOLD)
    textbox(s, Inches(1.38), Inches(2.15), Inches(11), Inches(1.0),
            [("让文化活在需要它的那一刻", 40, CREAM, True)])
    textbox(s, Inches(1.40), Inches(3.28), Inches(10.6), Inches(1.2),
            [("没有一段科普段落，但坎儿井、十二木卡姆、艾德莱斯绸、诺鲁孜节，",
              16.5, MUTED, False, 0),
             ("都在你需要它的那一刻出现。", 16.5, MUTED, False, 3)])
    rect(s, Inches(1.42), Inches(4.72), Inches(5.2), Pt(1.3), DEEP)
    textbox(s, Inches(1.40), Inches(4.92), Inches(11), Inches(0.5),
            [("欢迎现场试玩　·　双击启动即开　·　AI 在线与离线两种状态都能演示",
              15, GOLD, True)])
    textbox(s, Inches(1.40), H - Inches(0.72), Inches(11), Inches(0.34),
            [("《坎儿井》· 代码一次敲队", 10.5, MUTED, False)])

    k = outline_cards(prs)
    print("  卡片描边：%d 个圆角矩形" % k)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    prs.save(OUT)
    print("  已生成：%s" % OUT)


if __name__ == "__main__":
    build()
