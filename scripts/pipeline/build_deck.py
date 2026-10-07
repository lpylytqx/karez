#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""《坎儿井》创新点答辩 PPT —— python-pptx 直排（美化版）。

为什么放弃 dsh-ppt 的图文版式：
  它的 `image-right` 图框又高又窄，图按高度撑开必然横向溢出，
  **只要图比框宽，右半边就永远看不到**。按 1.42 / 1.70 / 0.66 三种宽比裁过都不行。
  半截的图比没有图更糟，所以换成 python-pptx：位置和尺寸由我算，一个像素都不裁。

美化（相对上一版）：
  · 内容页四角加金色角框，整页不再是"裸"的
  · 文字栏垫一层半透明深色面板，和底纹拉开层次、正文更清楚
  · 章节页：大号暗纹数字 01/02 + 巨幅低透明度徽标水印 + 金色横线
  · 封面：金色分隔线、团队署名条、底部渐隐暗带、巨幅水印
  · 金句页：面板 + 左侧金色竖条（引述样式）
  · 图片：深赭外框 + 金色内框"装裱"，配金色小竖条的图注
  · 全页：徽标、页脚、页码、徽标下细金线

用法：<bundled-python> scripts/pipeline/build_deck.py
"""
from __future__ import annotations

import sys as _sys
from pathlib import Path as _Path
_sys.path.insert(0, str(_Path(__file__).resolve().parent))
from _root import ROOT  # 路径唯一解析处，不再写死盘符
from pathlib import Path

from pptx import Presentation
from pptx.chart.data import CategoryChartData
from pptx.dml.color import RGBColor
from pptx.enum.chart import XL_CHART_TYPE, XL_LEGEND_POSITION
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.oxml.ns import qn
from pptx.util import Emu, Inches, Pt
from PIL import Image

ROOT = ROOT
ASSETS = ROOT / "deliverables" / "assets"
SHOTS = ROOT / "docs" / "screenshots"
OUT = ROOT / "deliverables" / "坎儿井_创新点答辩.pptx"

BG = RGBColor(0x2B, 0x21, 0x18)
PANEL = RGBColor(0x22, 0x1A, 0x13)
GOLD = RGBColor(0xE0, 0xA4, 0x3C)
CREAM = RGBColor(0xF0, 0xE4, 0xD0)
DEEP = RGBColor(0xA8, 0x52, 0x2F)
MUTED = RGBColor(0xB5, 0xA4, 0x8C)
FONT = "微软雅黑"

W = Inches(13.333)
H = Inches(7.5)
TOTAL = 15
ML = Inches(0.86)
CW = Inches(11.62)


def set_font(run, size, color, bold=False) -> None:
    """中文字体必须同时写 latin / ea / cs，只设 font.name 对中文无效。"""
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
    clr = sf.find(qn("a:srgbClr"))
    clr.append(clr.makeelement(qn("a:alpha"), {"val": str(int(alpha * 100000))}))


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
        shp.adjustments[0] = 0.06
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
        p.space_after = Pt(3)
        p.alignment = align
        run = p.add_run()
        run.text = text
        set_font(run, size, color, bold)
    return tb


def pic_alpha(pic, alpha: float) -> None:
    blip = pic._element.blipFill.find(qn("a:blip"))
    blip.append(blip.makeelement(qn("a:alphaModFix"), {"amt": str(int(alpha * 100000))}))


def fit_box(slide, img_path, l, t, w, h, frame=True):
    """按图片自身比例缩放进 (l,t,w,h)，**不裁不拉伸**。这是换掉旧工具的唯一理由。"""
    with Image.open(img_path) as im:
        iw, ih = im.size
    img_ar, box_ar = iw / ih, w / h
    if img_ar >= box_ar:
        nw, nh = w, int(w / img_ar)
    else:
        nh, nw = h, int(h * img_ar)
    nl, nt = int(l + (w - nw) / 2), int(t + (h - nh) / 2)
    if frame:
        rect(slide, nl - Inches(0.045), nt - Inches(0.045),
             nw + Inches(0.09), nh + Inches(0.09), DEEP)
    pic = slide.shapes.add_picture(str(img_path), nl, nt, nw, nh)
    pic.line.color.rgb = GOLD
    pic.line.width = Pt(1.25)
    return pic


def send_to_back(el, slide) -> None:
    parent = el.getparent()
    parent.remove(el)
    parent.insert(2, el)


def watermark(slide, l, t, size):
    p = slide.shapes.add_picture(str(ASSETS / "deck_logo.png"), l, t, size, size)
    pic_alpha(p, 0.085)
    p.line.fill.background()
    return p


def corners(slide, inset=Inches(0.34), size=Inches(0.30), tw=Pt(1.6)) -> None:
    """四角金色角框 —— 新疆几何边饰的极简版，给整页一个"装框"的完整感。"""
    for cx, cy, sx, sy in ((inset, inset, 1, 1), (W - inset, inset, -1, 1),
                           (inset, H - inset, 1, -1), (W - inset, H - inset, -1, -1)):
        # ⚠ 两条臂都必须**朝内**画：右边角标若不向左翻，就会画到页外
        #   （曾经右边/下边各超出 0.08 英寸，靠几何自检才发现）
        rect(slide, cx if sx > 0 else cx - size,
             cy if sy > 0 else cy - tw, size, tw, GOLD)
        rect(slide, cx if sx > 0 else cx - tw,
             cy if sy > 0 else cy - size, tw, size, GOLD)


def new_slide(prs, page: int, framed=True):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    bgpic = s.shapes.add_picture(str(ASSETS / "deck_bg.png"), 0, 0, W, H)
    send_to_back(bgpic._element, s)
    if framed:
        corners(s)
    logo = s.shapes.add_picture(str(ASSETS / "deck_logo.png"),
                                W - Inches(1.02), Inches(0.30), Inches(0.60), Inches(0.60))
    logo.line.fill.background()
    rect(s, W - Inches(1.05), Inches(1.00), Inches(0.63), Pt(1.2), GOLD)
    textbox(s, Inches(0.62), H - Inches(0.50), Inches(9), Inches(0.32),
            [("《坎儿井》· 代码一次敲队", 9, MUTED, False)])
    textbox(s, W - Inches(1.85), H - Inches(0.50), Inches(1.3), Inches(0.32),
            [("%02d / %d" % (page, TOTAL), 9, MUTED, False)], align=PP_ALIGN.RIGHT)
    return s


def head(slide, kicker: str, title: str) -> None:
    rect(slide, ML - Inches(0.24), Inches(0.50), Inches(0.10), Inches(0.50), GOLD)
    textbox(slide, ML, Inches(0.44), CW, Inches(0.34), [(kicker, 11, GOLD, True)])
    textbox(slide, ML, Inches(0.74), CW, Inches(0.66), [(title, 26, CREAM, True)])
    rect(slide, ML, Inches(1.46), CW, Pt(1.0), GOLD)


def bullets(slide, items, l, t, w, size=15, gap=12, panel=True):
    h = H - t - Inches(0.72)
    if panel:
        rect(slide, l - Inches(0.22), t - Inches(0.14), w + Inches(0.36), h,
             PANEL, alpha=0.72, rounded=True)
    tb = slide.shapes.add_textbox(l, t, w, h)
    tf = tb.text_frame
    tf.word_wrap = True
    for i, it in enumerate(items):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.space_before = Pt(0 if i == 0 else gap)
        r1 = p.add_run()
        r1.text = "· "
        set_font(r1, size, GOLD, True)
        r2 = p.add_run()
        r2.text = it
        set_font(r2, size, CREAM, False)
    return tb


def table(slide, rows, l, t, w, h, col_w=None, size=10.5):
    shp = slide.shapes.add_table(len(rows), len(rows[0]), l, t, w, h)
    tbl = shp.table
    if col_w:
        tot = sum(col_w)
        for i, cw in enumerate(col_w):
            tbl.columns[i].width = Emu(int(w * cw / tot))
    for ri, row in enumerate(rows):
        for ci, val in enumerate(row):
            cell = tbl.cell(ri, ci)
            cell.text = ""
            cell.margin_left = Inches(0.07)
            cell.margin_right = Inches(0.05)
            cell.margin_top = Inches(0.02)
            cell.margin_bottom = Inches(0.02)
            cell.vertical_anchor = MSO_ANCHOR.MIDDLE
            cell.fill.solid()
            cell.fill.fore_color.rgb = GOLD if ri == 0 else (PANEL if ri % 2 else BG)
            run = cell.text_frame.paragraphs[0].add_run()
            run.text = str(val)
            set_font(run, size, BG if ri == 0 else CREAM, ri == 0)
    return tbl


def figure(slide, img, caption, box):
    fit_box(slide, img, *box)
    cy = box[1] + box[3] + Inches(0.06)
    rect(slide, box[0], cy, Inches(0.05), Inches(0.24), GOLD)
    textbox(slide, box[0] + Inches(0.13), cy - Inches(0.02), box[2], Inches(0.3),
            [(caption, 9.5, MUTED, False)])


def section_page(prs, page, num, title, subtitle):
    s = new_slide(prs, page)
    watermark(s, W - Inches(5.4), Inches(1.35), Inches(4.6))
    textbox(s, ML, Inches(2.30), Inches(4), Inches(1.4), [(num, 74, DEEP, True)])
    rect(s, ML + Inches(0.04), Inches(2.72), Inches(0.15), Inches(1.32), GOLD)
    textbox(s, ML + Inches(0.42), Inches(2.52), Inches(10), Inches(0.6),
            [(title, 37, CREAM, True)])
    textbox(s, ML + Inches(0.44), Inches(3.40), Inches(10), Inches(0.5),
            [(subtitle, 16, MUTED, False)])
    rect(s, ML + Inches(0.44), Inches(3.92), Inches(4.6), Pt(1.2), GOLD)


def build() -> None:
    prs = Presentation()
    prs.slide_width, prs.slide_height = W, H

    # ── 1 封面 ──
    s = prs.slides.add_slide(prs.slide_layouts[6])
    s.shapes.add_picture(str(SHOTS / "S10_deck_A_绿洲全景.png"), 0, 0, W, H)
    rect(s, 0, 0, W, H, BG, alpha=0.58)
    rect(s, 0, H - Inches(1.35), W, Inches(1.35), BG, alpha=0.55)
    corners(s, inset=Inches(0.30), size=Inches(0.38), tw=Pt(2.0))
    watermark(s, W - Inches(4.3), Inches(0.7), Inches(3.6))
    rect(s, Inches(0.95), Inches(2.30), Inches(0.17), Inches(1.52), GOLD)
    textbox(s, Inches(1.38), Inches(2.12), Inches(9.4), Inches(1.3),
            [("《坎儿井》", 56, CREAM, True)])
    rect(s, Inches(1.42), Inches(3.52), Inches(6.2), Pt(1.4), DEEP)
    textbox(s, Inches(1.40), Inches(3.70), Inches(9.0), Inches(1.0),
            [("你扮演一位丝路驿丞，用坎儿井引来天山雪水，", 17, CREAM, False, 0),
             ("把荒漠驿站建成绿洲重镇。", 17, CREAM, False, 2)])
    textbox(s, Inches(1.40), Inches(4.95), Inches(9.0), Inches(0.4),
            [("自主命题 · 虚拟现实与游戏", 14.5, GOLD, True)])
    rect(s, Inches(0.98), H - Inches(1.06), Inches(11.4), Pt(0.9), DEEP)
    textbox(s, Inches(0.98), H - Inches(0.92), Inches(11), Inches(0.34),
            [("代码一次敲队　·　李鹏宇 / 王焕楷 / 李云天　·　指导教师 徐媛媛 / 李中岩",
              11, MUTED, False)])

    # ── 2 / 7 章节 ──
    section_page(prs, 2, "01", "一、我们讲的是哪一个新疆",
                 "不是风情画，是一个水利工程如何养活一片绿洲")
    section_page(prs, 7, "02", "二、四个创新点", "每一条都能当场演示、当场验证")

    # ── 3 坎儿井是主线 ──
    s = new_slide(prs, 3)
    head(s, "核心设计", "坎儿井不是背景板，它是唯一的主线")
    bullets(s, ["不挖井，活不过第七天", "6 段竖井逐段开挖，每段 +55 方/日",
                "水 → 人口 → 劳动力，整条链条的源头",
                "涝坝四级扩容（450 / 900 / 1600 / 2600 方）",
                "把荒漠一步一步推成绿洲"], ML, Inches(1.78), Inches(5.3))
    figure(s, SHOTS / "S10_deck_A_绿洲全景.png",
           "实机截图：六段竖井全部挖通、涝坝满水位",
           (Inches(6.72), Inches(1.62), Inches(5.85), Inches(4.52)))

    # ── 4 文化→机制表 ──
    s = new_slide(prs, 4)
    head(s, "文化 → 机制 映射（一）水与农", "文化拆掉之后，玩法还成立吗？")
    table(s, [
        ["文化元素", "变成什么机制", "拆掉会怎样"],
        ["坎儿井", "6 段竖井，每段 +55 方/日", "主线消失"],
        ["涝坝", "4 级扩容 450~2600 方", "旱季无从准备"],
        ["葡萄晾房", "瓜果保质 8 天 → 葡萄干 120 天", "过冬储粮策略消失"],
        ["馕 / 粮食", "保质 12 天 / 90 天", "腐坏系统失去层次"],
        ["棉花", "秋收，可织艾德莱斯绸", "手工产业链断源"],
    ], ML, Inches(1.76), Inches(9.6), Inches(4.3), col_w=[2.0, 5.0, 3.4])

    # ── 5 牧与工 ──
    s = new_slide(prs, 5)
    head(s, "文化 → 机制 映射（二）", "牧与工：养羊必须真的能换成钱")
    bullets(s, ["5 个真实畜种：阿勒泰细毛羊、绒山羊、双峰驼、库车驴、吐鲁番鸡",
                "4 种野畜：盘羊、鹅喉羚、蒙古野驴、野驼 —— 派人去草原抓",
                "抓野畜成功率随去过次数上升，失败不扣人",
                "擀毡：羊毛 3 → 毡子 1；织毯：羊毛 6 + 织物 2 → 地毯 1",
                "木料 6 + 工具 1 → 热瓦普 1（办木卡姆的前置道具）"],
            ML, Inches(1.78), Inches(5.3), size=13.5)
    figure(s, SHOTS / "S9_animal_A_有牲畜.png",
           "实机截图：畜牧页 —— 栏位、产出、抓野畜与扩建",
           (Inches(6.72), Inches(1.62), Inches(5.85), Inches(4.52)))

    # ── 6 乐与节 ──
    s = new_slide(prs, 6)
    head(s, "文化 → 机制 映射（三）", "办一场木卡姆要人、场地、乐器")
    bullets(s, ["十二木卡姆，取确认无误的六套可演奏",
                "需要：奏乐台 + 木卡姆艺人 + 库里有热瓦普",
                "消耗 2 行动点，办完冷却 3 天",
                "诺鲁孜节 / 葡萄熟了 / 古尔邦节 三个真实节庆",
                "古尔邦节：家里牲畜 ≥5 头，声望额外 +4"],
            ML, Inches(1.78), Inches(5.3), size=13.5)
    figure(s, SHOTS / "S9_animal_E_木卡姆.png",
           "实机截图：点地图上的奏乐台即可办一场",
           (Inches(6.72), Inches(1.62), Inches(5.85), Inches(4.52)))

    # ── 8 创新一 ──
    s = new_slide(prs, 8)
    head(s, "创新一 · AI 原生 + 可离线降级", "AI 是放大器，不是运行的必要条件")
    rect(s, ML, Inches(1.90), CW, Inches(3.9), PANEL, alpha=0.76, rounded=True)
    rect(s, ML, Inches(1.90), Inches(0.13), Inches(3.9), GOLD)
    textbox(s, ML + Inches(0.45), Inches(2.18), Inches(10.7), Inches(3.4), [
        ("AI 在线时：7 位角色由大模型实时驱动，各有独立人设、长期记忆、情绪与亲密度。",
         15, CREAM, False, 0),
        ("玩家用自然语言对话，不是选选项；角色会记住你说过的话、许过的承诺。",
         15, CREAM, False, 17),
        ("AI 离线时：数值、状态、存档、全部系统逻辑都在本地 —— 游戏 100% 可玩。",
         15, GOLD, False, 17),
        ("这让作品从「演示品」变成「能交付的产品」：断网、API 挂掉，游戏都不会变成一块砖。",
         15, CREAM, False, 17),
    ])

    # ── 9 创新二 ──
    s = new_slide(prs, 9)
    head(s, "创新二 · 数据驱动架构", "23 段数值全部外置")
    bullets(s, ["data/numbers.json 共 23 个顶层数据段",
                "水利 / 建筑 / 人口 / 农业 / 探索 / 战斗 / 外交 / 经济",
                "后期新增畜牧、灾难、加工、节庆、音乐五套系统",
                "全部玩法调优都靠改数据完成，不碰代码",
                "配套 verify.py 做 48 项结构与数值自洽校验"],
            ML, Inches(1.78), Inches(5.3), size=13.5)
    figure(s, SHOTS / "S10_deck_C_事件卡.png",
           "实机截图：事件卡 —— 64 条事件库中的一条，带选项与后果",
           (Inches(6.72), Inches(1.62), Inches(5.85), Inches(4.52)))

    # ── 10 创新三 ──
    s = new_slide(prs, 10)
    head(s, "创新三 · 双轨美术生产", "该程序化的程序化，该上 AI 的上 AI")
    table(s, [
        ["资产类型", "生产工具", "为什么"],
        ["像素贴图", "Python + Pillow 程序化", "要 16px 网格与 34 色板精确"],
        ["插画", "本地 ComfyUI + SDXL", "要手绘感、不受像素约束"],
        ["色板一致性", "34 色统一 + 逐文件审计", "421 张 PNG 全部合规"],
        ["灾难插画 6 张", "本地 SDXL 自动出图", "全流程可复现"],
    ], ML, Inches(1.76), Inches(9.6), Inches(3.4), col_w=[2.6, 3.9, 4.2])

    # ── 11 创新四 ──
    s = new_slide(prs, 11)
    head(s, "创新四 · 可验证性工程", "388 项断言证明它能跑")
    table(s, [
        ["测试套件", "断言", "覆盖重点"],
        ["logic_test", "47", "水利平衡、建造、事件结算"],
        ["battle_edge", "85", "以少打多、交战存读档"],
        ["livestock_disaster", "102", "畜牧 / 灾难 / 加工 / 节庆"],
        ["input_probe", "16", "真实输入事件走完整管线"],
        ["verify.py", "48", "跨文件引用、水平衡、一致性"],
    ], ML, Inches(1.76), Inches(9.6), Inches(3.9), col_w=[3.0, 1.2, 6.2])

    # ── 12 玩法深度 ──
    s = new_slide(prs, 12)
    head(s, "玩法深度", "9 个岗位争同一批人")
    bullets(s, ["9 岗位：治水 / 耕作 / 采集 / 经商 / 守卫 / 炊事 / 做工 / 演艺 / 待命",
                "自由布阵：整片布阵区随便站，不是固定格子",
                "兵种由岗位决定：守卫→盾卫、采集→弓手、其余→乡勇",
                "实测：5 打 4，摆法不同阵亡相差 0.00 ~ 3.00 人",
                "6 种灾难各有能挡它的建筑（烽燧 / 围墙 / 仓库 / 驿馆）"],
            ML, Inches(1.78), Inches(5.3), size=13.5)
    figure(s, SHOTS / "S10_deck_D_御敌布阵.png",
           "实机截图：御敌之战自由布阵，五人三色兵种",
           (Inches(6.72), Inches(1.62), Inches(5.85), Inches(4.52)))

    # ── 13 图表 ──
    s = new_slide(prs, 13)
    head(s, "实测数据", "阵型真的影响胜负：同样 5 人打 4 人")
    table(s, [
        ["摆法", "平均阵亡", "说明"],
        ["全员压前线", "0.00", "五个人挤成一条线，敌人逐个撞上来"],
        ["自动布阵", "1.00", "盾卫在前、弓手在后，差 20px"],
        ["一字纵队", "1.17", "纵深拉太开，前排被打完才轮到后排"],
        ["弓手出射程", "3.00", "弓手站到 52px 射程之外 —— 最差摆法"],
    ], ML, Inches(1.76), Inches(9.9), Inches(2.9), col_w=[2.4, 1.6, 6.0], size=12)
    rect(s, ML, Inches(4.92), CW, Inches(1.30), PANEL, alpha=0.76, rounded=True)
    rect(s, ML, Inches(4.92), Inches(0.12), Inches(1.30), GOLD)
    textbox(s, ML + Inches(0.42), Inches(5.10), Inches(10.9), Inches(1.0), [
        ("同样 5 打 4、同样随机种子，只换摆法，阵亡从 0 人到 3 人 —— ", 15, CREAM, False, 0),
        ("摆法真的决定胜负，不是装饰。", 15, GOLD, True, 2),
    ])
    textbox(s, ML, Inches(6.34), Inches(11), Inches(0.36),
            [("每种摆法各跑 6 遍、共用同一组随机种子（scripts/tests/formation_probe.gd）",
              10, MUTED, False)])

    # ── 14 交付状态 ──
    s = new_slide(prs, 14)
    head(s, "交付状态", "可运行、可核查、可扩展")
    bullets(s, ["双击启动即玩，无需安装任何环境",
                "13,004 行作品代码 · 事件 64 条 · 建筑 13 座",
                "421 张美术 · 189 个音频 · 25 张实机截图",
                "全部数值与事件为纯文本 JSON，任何人可核查",
                "增加新畜种 / 新灾难 / 新曲目只需改数据"],
            ML, Inches(1.78), Inches(5.3), size=13.5)
    figure(s, SHOTS / "S9_animal_C_灾难日志.png",
           "实机截图：沙暴通告卡，插画由本地 SDXL 生成",
           (Inches(6.72), Inches(1.62), Inches(5.85), Inches(4.52)))

    # ── 15 收尾 ──
    s = new_slide(prs, 15)
    watermark(s, W - Inches(4.9), Inches(1.9), Inches(4.2))
    rect(s, ML, Inches(2.42), Inches(0.15), Inches(1.42), GOLD)
    textbox(s, ML + Inches(0.42), Inches(2.24), Inches(10.6), Inches(1.0),
            [("让文化活在需要它的那一刻", 40, CREAM, True)])
    rect(s, ML + Inches(0.44), Inches(3.62), Inches(5.0), Pt(1.2), DEEP)
    textbox(s, ML + Inches(0.44), Inches(3.82), Inches(9.6), Inches(1.2),
            [("没有一段科普段落，但坎儿井、十二木卡姆、艾德莱斯绸、诺鲁孜节，"
              "都在需要它的那一刻出现。", 15.5, MUTED, False)])
    textbox(s, ML + Inches(0.44), Inches(5.05), Inches(10.4), Inches(0.5),
            [("欢迎现场试玩　·　双击启动即开　·　AI 在线与离线两种状态都能演示",
              15, GOLD, True)])

    OUT.parent.mkdir(parents=True, exist_ok=True)
    prs.save(OUT)
    print("  已生成：%s" % OUT)


if __name__ == "__main__":
    build()
