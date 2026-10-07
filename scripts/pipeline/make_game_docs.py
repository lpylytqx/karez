#!/usr/bin/env python -u
# -*- coding: utf-8 -*-
"""生成《坎儿井》的完整参赛文档集 —— 照非遗平台那套的格式与流程。

为什么是这一套：翻过 D:\\xinjiang_feiyi\\提交材料 后发现，那边交的是**一整套**
（作品说明 / 运行说明 / 人工智能工具使用说明 / 知识产权与第三方素材说明 /
图像佐证材料 / 团队分工与贡献说明 / 在线填报速查表 / PPT），
不是零散几份。竞赛对"AI 工具使用说明"和"素材授权"是有明确要求的，
所以这里按同样的清单给游戏补齐。

统一格式（与非遗版一致）：
    标题（居中）
    2026 年第十四届
    全国大学生数字媒体科技作品及创意竞赛
    作品名称：《坎儿井》  申报单位 / 团队 / 成员 / 指导教师 / 填报日期

签名：三张手写签名插到《团队分工与贡献说明》的承诺页。
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import DELIVERABLES, PACK  # noqa: E402

from docx import Document  # noqa: E402
from docx.enum.table import WD_TABLE_ALIGNMENT  # noqa: E402
from docx.enum.text import WD_ALIGN_PARAGRAPH  # noqa: E402
from docx.shared import Cm, Pt, RGBColor  # noqa: E402
from docx.oxml.ns import qn  # noqa: E402

OUT = DELIVERABLES / "参赛文档"
SIG = PACK / "90-原始材料" / "手写签名"
SHOTS = PACK / "作品截图10张"

COMP = ("2026 年第十四届", "全国大学生数字媒体科技作品及创意竞赛")
WORK = "《坎儿井》"
UNIT = "中国石油大学（北京）克拉玛依校区"
TEAM = "代码一次敲队"
MEMBERS = "李鹏宇　王焕楷　李云天"
ADVISORS = "徐媛媛　李中岩"
DATE = "2026 年 10 月 7 日"

AIGC_FONT = "微软雅黑"


def cjk(run, size=10.5, bold=False, color=None):
    run.font.size = Pt(size)
    run.font.bold = bold
    run.font.name = AIGC_FONT
    if color:
        run.font.color.rgb = color
    rPr = run._element.get_or_add_rPr()
    rf = rPr.find(qn("w:rFonts"))
    if rf is None:
        rf = rPr.makeelement(qn("w:rFonts"), {})
        rPr.append(rf)
    rf.set(qn("w:eastAsia"), AIGC_FONT)
    return run


def doc() -> Document:
    d = Document()
    st = d.styles["Normal"]
    st.font.name = AIGC_FONT
    st.font.size = Pt(10.5)
    st.element.rPr.rFonts.set(qn("w:eastAsia"), AIGC_FONT)
    for s in d.sections:
        s.left_margin = s.right_margin = Cm(2.4)
    return d


def head(d: Document, title: str, extra: list[str] | None = None):
    p = d.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    cjk(p.add_run(title), 20, True)
    for line in COMP:
        q = d.add_paragraph()
        q.alignment = WD_ALIGN_PARAGRAPH.CENTER
        cjk(q.add_run(line), 11)
    info = [("作品名称：", WORK), ("申报单位：", UNIT), ("团队名称：", TEAM),
            ("团队成员：", MEMBERS), ("指导教师：", ADVISORS), ("填报日期：", DATE)]
    if extra:
        info = [tuple(x.split("：", 1)) if isinstance(x, str) and "：" in x else x
                for x in extra] + info
    for k, v in info:
        q = d.add_paragraph()
        q.alignment = WD_ALIGN_PARAGRAPH.CENTER
        cjk(q.add_run(k + v), 10.5)
    d.add_paragraph()


def h(d: Document, text: str, level=1):
    p = d.add_paragraph()
    cjk(p.add_run(text), 14 if level == 1 else 12, True)
    p.paragraph_format.space_before = Pt(10)
    p.paragraph_format.space_after = Pt(4)


def t(d: Document, text: str, bullet=False):
    p = d.add_paragraph()
    cjk(p.add_run(("- " if bullet else "") + text), 10.5)
    return p


def table(d: Document, rows: list[list[str]], widths=None):
    tb = d.add_table(rows=0, cols=len(rows[0]))
    tb.style = "Light Grid Accent 1"
    tb.alignment = WD_TABLE_ALIGNMENT.CENTER
    for ri, row in enumerate(rows):
        cells = tb.add_row().cells
        for ci, v in enumerate(row):
            cells[ci].text = ""
            par = cells[ci].paragraphs[0]
            cjk(par.add_run(str(v)), 9.5, ri == 0)
    return tb


# ────────────────────────────── 各文档 ──────────────────────────────
def build_run() -> Path:
    d = doc()
    head(d, "作品运行说明")
    h(d, "一、运行环境要求")
    table(d, [
        ["项目", "要求"],
        ["操作系统", "Windows 10 / 11（64 位）"],
        ["运行时环境", "无需安装任何环境 —— 游戏引擎与运行库随参赛包一并附带"],
        ["Python", "不需要。AI 服务为可选组件，不启动不影响游玩"],
        ["网络", "**不需要联网**。AI 服务在线时角色对话由大模型实时生成；离线自动降级"],
        ["硬件", "集成显卡即可流畅运行；无需独立显卡"],
        ["磁盘占用", "解压后约 1.1 GB"],
    ])
    h(d, "二、启动步骤")
    t(d, "第 1 步：解压")
    t(d, "把「坎儿井_参赛包.zip」解压到任意目录（路径不含中文亦可），得到「坎儿井」文件夹。", True)
    t(d, "第 2 步：启动游戏")
    t(d, "双击文件夹内的「启动游戏.bat」。首次启动约 2–3 秒，随后进入标题画面。", True)
    t(d, "第 3 步：（可选）启动 AI 服务")
    t(d, "若要体验由大模型实时生成的角色对话，另双击「启动AI服务.bat」。", True)
    t(d, "未启动时游戏**依然完整可玩**，对话走团队预先编写的预设内容。", True)
    t(d, "第 4 步：开始游戏")
    t(d, "标题画面按任意键进入游戏。启动器的命令行窗口可以关闭，不影响游戏。", True)
    h(d, "三、三个启动入口")
    table(d, [
        ["入口文件", "用途"],
        ["启动游戏.bat", "正常开局：先到标题画面，按任意键开始"],
        ["启动_御敌演示.bat", "直接跳到战场布阵阶段，便于查看战斗系统"],
        ["启动AI服务.bat", "（可选）接通大模型，让角色对话实时生成"],
    ])
    h(d, "四、操作说明")
    table(d, [
        ["操作", "说明"],
        ["WASD / 方向键", "移动主角"],
        ["点地图上的空位", "派一名居民过去；也可以点右侧「功能」栏里的按钮"],
        ["推进时段", "晨 → 午 → 暮 → 夜；每过完一天结算一次"],
        ["滚轮 / + -", "缩放地图（可放可缩）"],
        ["按住左键拖动", "平移地图"],
        ["F", "镜头回到主角（头顶有「驿丞」金字）"],
        ["底部输入框", "与角色对话；需要 AI 服务，未启动时走预设台词"],
        ["右侧「存档 / 读档」", "保存或读取进度"],
    ])
    h(d, "五、常见问题")
    table(d, [
        ["现象", "原因与处理"],
        ["提示找不到 Godot 可执行文件", "「tools」文件夹里的引擎文件缺失，请重新完整解压"],
        ["提示找不到工程文件", "「scripts」文件夹缺失或不完整，请重新解压"],
        ["界面显示「AI 检测中」或「离线」", "AI 服务未启动。不影响游玩，对话走预设内容"],
        ["素材显示为断开的快捷方式", "解压工具把目录链接解成了链接。请用 Windows 自带解压或 7-Zip 重新解压"],
        ["窗口很小 / 想全屏", "游戏按 16:9 固定比例渲染，可拖动窗口边缘放大"],
    ])
    h(d, "六、数据可核查说明")
    t(d, "作品的全部玩法数值与事件文本均为纯文本文件，评审可直接打开核对：")
    t(d, "data/numbers.json —— 23 个数据段（水利 / 建筑 / 人口 / 农业 / 探索 / 战斗 / "
         "外交 / 经济 / 牲畜 / 灾难 / 加工 / 节庆 / 音乐等）", True)
    t(d, "data/events.v1.json —— 64 条事件", True)
    t(d, "data/characters.json —— 7 位角色的设定", True)
    p = OUT / "作品运行说明.docx"
    d.save(p)
    return p


def build_ai() -> Path:
    d = doc()
    head(d, "人工智能工具使用说明")
    h(d, "一、说明目的")
    t(d, "本说明如实列出《坎儿井》在创作过程中使用的人工智能工具、使用环节与生成内容范围，"
         "并说明团队对全部生成内容的核验与修改过程。本说明与《作品说明文档》"
         "《知识产权与第三方素材说明》中的相关表述保持一致。")
    h(d, "二、人工智能工具使用总览")
    table(d, [
        ["序号", "工具 / 模型", "类型", "提供方", "作品中的使用环节"],
        ["1", "Stable Diffusion XL（SDXL Base 1.0）", "图像生成模型",
         "Stability AI（**本地部署**，ComfyUI 运行）", "灾难与事件插画的底图生成"],
        ["2", "DeepSeek", "大语言模型", "深度求索", "角色对话与事件文本的运行时生成"],
        ["3", "大语言模型辅助编程", "大语言模型", "深度求索",
         "部分代码的实现建议与重构（输出均经团队运行验证后采用）"],
    ])
    t(d, "除上述三项外，作品的其余功能与内容均未使用人工智能工具。")
    h(d, "三、工具一：Stable Diffusion XL（本地部署）")
    t(d, "模型名称：sd_xl_base_1.0；运行方式：本地 ComfyUI，经 HTTP 接口调用，"
         "**全部生成过程在本机离线完成**，未上传任何素材至第三方服务。")
    t(d, "使用环节：生成灾难场景插画（沙暴 / 大旱 / 融雪洪水 / 寒潮 / 瘟疫 / 蝗灾，共 6 张）。")
    t(d, "团队核验与修改：每张生成图由团队人工筛选，剔除构图或内容不当的结果；"
         "随后统一裁切为 150×200 像素（与游戏内事件卡一致），并逐张核对画面内容是否与"
         "对应灾难相符。最终成品与生成原图一并保留在作品目录内，过程可复现。")
    t(d, "**排版说明**：作品内的中文标题与界面文字一律使用真实字体排版，"
         "不由图像生成模型绘制文字 —— 扩散模型写中文字必然出现错字或糊字。")
    h(d, "四、工具二：DeepSeek 大语言模型")
    t(d, "使用环节：游戏中 7 位角色（老坎匠、木卡姆艺人、哈萨克骑手、汉族商队掌柜、"
         "回族厨娘、神秘旅人、马匪头目）的对话文本，以及事件文本，在运行时由模型实时生成。")
    t(d, "约束与核验：")
    t(d, "每位角色有独立的人设卡（身份、说话习惯、可用知识范围），由团队撰写并作为系统提示固定传入；", True)
    t(d, "模型输出经过结构校验后才写入游戏状态，解析失败的输出会被丢弃并回退；", True)
    t(d, "**AI 服务不可用时，游戏自动降级为团队预先编写的预设内容，且全部玩法功能不受影响**；", True)
    t(d, "涉及民族文化与非遗的表述，团队事先限定了知识边界，不允许模型自行编造传承谱系与年代。", True)
    h(d, "五、工具三：大语言模型辅助编程")
    t(d, "使用环节：在部分功能模块的实现与重构过程中，团队使用大语言模型获取实现思路与代码草案。")
    t(d, "核验过程：所有输出均在本地实际运行，并通过团队自建的自动化测试"
         "（4 套、共 388 项断言）与结构校验后才会保留；未通过的部分由团队重写。")
    t(d, "**作品的架构设计、玩法规则、数值体系、美术风格与全部创作决策由团队确定**，"
         "模型承担的是执行层面的辅助。")
    h(d, "六、未使用人工智能工具的部分")
    t(d, "以下内容由团队手工完成或由确定性程序生成，不属于人工智能生成：")
    t(d, "像素贴图与统一色板 —— 由团队编写 Python + Pillow 脚本程序化绘制，"
         "配色锁定在 34 色板内，逐文件审计（属确定性程序生成，非生成式模型）；", True)
    t(d, "玩法系统、数值平衡、数据架构、测试体系 —— 团队设计与实现；", True)
    t(d, "文化内容的考据与撰写 —— 团队对照公开资料逐项核实；", True)
    t(d, "演示视频、全部参赛文档 —— 团队录制、撰写与校对。", True)
    h(d, "七、生成内容的标识方式")
    t(d, "作品内对 AI 生成内容做了可辨识的标注：灾难插画的生成方式记录在作品目录的"
         "脚本注释与文档中；角色对话在界面顶部明确显示 AI 服务的连接状态"
         "（「AI 检测中」/「离线」），玩家随时可以知道当前对话是实时生成还是预设内容。")
    p = OUT / "人工智能工具使用说明.docx"
    d.save(p)
    return p


def build_ip() -> Path:
    d = doc()
    head(d, "知识产权与第三方素材说明")
    h(d, "一、说明目的与范围")
    t(d, "本说明与《作品说明文档》《人工智能工具使用说明》配套提交，"
         "三份材料中的相关表述保持一致。")
    h(d, "二、作品原创性说明")
    t(d, "以下内容为参赛学生团队的原创成果，不存在抄袭、剽窃、套作或冒名情形：")
    for i, s in enumerate([
        "作品的选题方向、核心玩法框架与四个创新点构思；",
        "全部玩法系统的设计与实现：坎儿井水利、据点经营、九个岗位分工、建造、探索、"
        "御敌之战（自由布阵与兵种）、灾难、畜牧、加工、节庆、木卡姆；",
        "数据驱动架构（23 个数据段）、事件库（64 条）与存档结构的设计；",
        "AI 接口封装、角色人设与记忆机制、上下文预算控制，以及**离线降级路径**的设计；",
        "程序化像素贴图管线（含 34 色板约束与逐文件审计）与本地图像生成流程；",
        "自动化测试体系（4 套 388 项断言）与结构校验脚本；",
        "界面布局、信息层级与操作引导方案；",
        "演示视频、申报书、答辩 PPT 及全部参赛文档。",
    ]):
        t(d, "%d. %s" % (i + 1, s))
    h(d, "三、第三方素材来源与授权")
    t(d, "作品使用的第三方素材以**开放授权**的像素素材包为主，均已核查授权条款：")
    table(d, [
        ["素材", "用途", "来源与授权"],
        ["Ninja Adventure Asset Pack", "建筑、地块、道具等像素素材",
         "CC0（公有领域），允许商用与修改"],
        ["Kenney 系列素材包", "部分地块与音效底库",
         "CC0（公有领域）"],
        ["Sonniss GameAudioGDC", "音效底库", "Sonniss 授权，允许在游戏作品中使用"],
        ["开源字体（像素中文字体）", "界面文字",
         "SIL Open Font License 1.1，允许嵌入与再分发"],
    ])
    t(d, "完整清单与逐项授权记录见作品目录内的 docs/asset-licenses.md，可逐条核对。")
    h(d, "四、开源依赖")
    table(d, [
        ["依赖", "用途", "许可"],
        ["Godot Engine 4.7.2", "游戏引擎", "MIT"],
        ["Python 3 / FastAPI / uvicorn", "本地 AI 服务（可选）", "PSF / MIT / BSD"],
        ["Pillow", "像素贴图程序化生成与图像处理", "HPND"],
        ["python-docx / python-pptx", "参赛文档生成（开发期工具）", "MIT"],
    ])
    h(d, "五、人工智能生成内容的说明")
    t(d, "作品中由人工智能生成的内容及其标识方式，详见单独提交的"
         "《人工智能工具使用说明》。要点如下：")
    t(d, "灾难与事件插画由**本地部署**的 Stable Diffusion XL 生成，全程本机运行；", True)
    t(d, "角色对话与事件文本由大语言模型运行时生成，界面明确显示 AI 连接状态；", True)
    t(d, "像素贴图由确定性程序（Python + Pillow）生成，不属于生成式模型输出；", True)
    t(d, "中文标题与界面文字一律使用真实字体排版，不由模型绘制文字。", True)
    h(d, "六、民族文化内容的准确性")
    t(d, "作品涉及的非遗与民族文化内容，均由团队对照权威公开资料逐项核实后撰写。"
         "对公开资料未能确证的内容，作品内明确标注范围，不作编造：")
    t(d, "十二木卡姆仅收录团队确认无误的六套曲目，并在数据文件中注明「是十二套中的六套」；", True)
    t(d, "节庆日期在数据中注明「古尔邦节在现实中按伊斯兰历浮动」；", True)
    t(d, "不编写任何具体的传承谱系、师承关系或年代细节。", True)
    h(d, "七、声明")
    t(d, "本团队承诺：作品为学生团队原创，所使用第三方素材均已核查授权并按要求标注；"
         "如存在权利瑕疵，团队愿承担相应责任并及时更正。")
    table(d, [
        ["签名（团队负责人）", "日期"],
        ["", DATE],
    ])
    p = OUT / "知识产权与第三方素材说明.docx"
    d.save(p)
    return p


def build_evidence() -> Path:
    d = doc()
    head(d, "图像佐证材料")
    p = d.add_paragraph()
    cjk(p.add_run("说明：以下 10 张均为作品**实际运行时的界面截图**，未作内容修改，"
                  "仅统一转为 JPEG 以便提交。截图中的顶栏数值、右侧功能栏与底部对话栏"
                  "均为游戏实时状态。"), 10.5)
    d.add_paragraph()
    items = [
        ("一、治水成果", "六段竖井全部挖通后的绿洲。坎儿井是作品的唯一主线："
                         "每段竖井增加日出水量，出水量决定可灌溉范围与人口上限。"),
        ("二、核心玩法 · 九个岗位分工", "治水、耕作、采集、经商、守卫、炊事、做工、演艺、待命。"
                                       "九个岗位争夺同一批人，多派一人挖井就少一人种地。"),
        ("三、建造系统", "可建造的十三座建筑，按页浏览并显示材料造价。"),
        ("四、AI 事件卡", "与角色对话触发的事件，带多个选项与各自后果。"),
        ("五、御敌之战 · 自由布阵", "整片布阵区可自由站位；兵种由岗位决定"
                                    "（守卫→盾卫、采集→弓手、其余→乡勇）。"),
        ("六、畜牧系统", "五个真实畜种与四种野畜；可派人外出抓捕，栏位、繁殖与产出同页管理。"),
        ("七、非遗 · 十二木卡姆", "六套确认无误的木卡姆曲目。办一场需要奏乐台、"
                                  "木卡姆艺人在场，且库中有热瓦普。"),
        ("八、灾难系统", "沙暴来袭时的通告卡。卡片插画由本地部署的 Stable Diffusion XL 生成。"),
        ("九、四季表现 · 冬季", "同一片绿洲在冬季的表现：地表换雪、树木凋尽。"),
        ("十、四季表现 · 春季", "春季的花木与绿意，与冬季形成对照。"),
    ]
    for i, (name, desc) in enumerate(items):
        h(d, name)
        q = d.add_paragraph()
        cjk(q.add_run(desc), 10.5)
        img = sorted(SHOTS.glob("%02d_*.jpg" % (i + 1)))
        if img:
            pic = d.add_paragraph()
            pic.alignment = WD_ALIGN_PARAGRAPH.CENTER
            pic.add_run().add_picture(str(img[0]), width=Cm(15.5))
            cap = d.add_paragraph()
            cap.alignment = WD_ALIGN_PARAGRAPH.CENTER
            cjk(cap.add_run("图：%s" % name.split("、")[-1]), 9, False,
                RGBColor(0x60, 0x60, 0x60))
    p = OUT / "图像佐证材料.docx"
    d.save(p)
    return p


def build_team() -> Path:
    """分工说明 + 承诺页三张手写签名。"""
    d = doc()
    head(d, "团队分工与贡献说明")
    h(d, "一、团队构成")
    table(d, [
        ["申报单位", UNIT],
        ["团队名称", TEAM],
        ["团队人数", "3 人"],
        ["团队成员", "李鹏宇、王焕楷、李云天"],
        ["指导教师", "徐媛媛、李中岩"],
    ])
    h(d, "二、成员分工")
    table(d, [
        ["姓名", "专业 / 年级", "承担工作"],
        ["李鹏宇", "机电工程学院 自动化专业 2025 级",
         "游戏框架规划与核心系统实现、数据驱动架构设计、AI 接口对接与离线降级逻辑、"
         "程序化美术生产管线、自动化测试体系构建与整合"],
        ["王焕楷", "机电工程学院 自动化专业 2025 级",
         "与李云天共同负责：界面上手体验与视觉实现、新疆文化元素资料考据与核对、"
         "素材搜集与授权核查、演示视频录制与剪辑、参赛文档撰写与校对、功能测试与反馈"],
        ["李云天", "机电工程学院 自动化专业 2025 级",
         "与王焕楷共同负责：界面上手体验与视觉实现、新疆文化元素资料考据与核对、"
         "素材搜集与授权核查、演示视频录制与剪辑、参赛文档撰写与校对、功能测试与反馈"],
    ])
    t(d, "注：王焕楷与李云天两位成员的职责均等，承担同一组工作，各自与对方共同负责、互相补位。")
    h(d, "三、工作模块与负责人")
    table(d, [
        ["工作模块", "具体内容", "负责人"],
        ["选题与方案", "确定以坎儿井为题材、以「AIGC + 新疆丝路文化 + 经营玩法」为路径；提出并论证四个创新点", "李鹏宇"],
        ["核心玩法系统", "坎儿井水利、据点经营、九个岗位分工、建造、探索、御敌之战（自由布阵与兵种）、灾难、畜牧、加工、节庆、木卡姆", "李鹏宇"],
        ["数值与数据架构", "全部玩法数值外置为 23 个数据段；事件库 64 条；存档结构与旧存档迁移", "李鹏宇"],
        ["AI 对接与降级", "大模型接口封装、角色人设与记忆、上下文预算控制、离线降级路径", "李鹏宇"],
        ["美术生产", "程序化像素贴图管线（34 色板统一与逐文件审计）；本地图像生成；真字体中文排版", "李鹏宇"],
        ["测试与验证", "四套自动化测试共 388 项断言；结构校验；逐页截图视觉核对", "李鹏宇"],
        ["上手体验", "界面布局与信息层级、操作引导、新手提示语、色板与可读性调优", "王焕楷、李云天"],
        ["文化考据", "十二木卡姆曲目、诺鲁孜节与古尔邦节、地方畜种、作物与手工等资料的搜集与逐项核对", "王焕楷、李云天"],
        ["素材与授权", "第三方素材来源核查与授权标注、生成内容的标识方式梳理", "王焕楷、李云天"],
        ["演示与文档", "演示视频录制与剪辑、申报书与答辩 PPT 撰写校对、参赛材料整理", "王焕楷、李云天"],
    ])
    h(d, "四、协作与开发过程")
    for i, s in enumerate([
        "**选题与需求确定**：团队共同讨论确定以新疆坎儿井为题材，明确「文化必须进入玩法、"
        "而不是贴一层资料」的设计原则，据此确定以治水为唯一主线的经营玩法框架。",
        "**文化与内容准备**：分工搜集坎儿井、十二木卡姆、艾德莱斯绸、诺鲁孜节与古尔邦节、"
        "新疆地方畜种等公开资料，逐项核对后写成游戏内的数据条目；对无法确证的内容"
        "（如木卡姆传承谱系）明确不作编写。",
        "**系统开发**：按功能模块推进，先完成水利与经营主干，再依次接入建造、分工、战斗、"
        "灾难、畜牧、加工、节庆与木卡姆；每完成一个模块先跑自动化测试，再由其他成员实机试玩并反馈。",
        "**美术与素材**：确定「像素贴图程序化生成、插画由本地模型生成」的双轨路线；"
        "筛选素材并逐项核查授权，标注生成内容。",
        "**测试与完善**：进行完整功能走查与异常场景测试（旧存档读取、AI 服务不可用、"
        "灾难连续触发、以少打多、人口只剩 1 人等），根据测试结果迭代修复。",
        "**材料整理**：录制演示视频，撰写并逐字核对申报书、答辩 PPT 与全部参赛文档，"
        "并打包成可直接运行的参赛包。",
    ]):
        t(d, s.replace("**", ""))
    h(d, "五、原创贡献声明")
    for i, s in enumerate([
        "作品的选题方向、核心玩法框架、四个创新点构思由团队自主提出并确定；",
        "全部玩法系统、数值体系、AI 对接与降级逻辑、美术生产管线与测试体系由团队设计并实现；",
        "游戏中涉及的非遗与民族文化内容，由团队对照公开资料逐项核实后撰写；"
        "对公开资料未能确证的内容，作品内明确标注范围，不作编造；",
        "人工智能工具承担执行性辅助工作（程序化生成像素贴图的代码、本地扩散模型生成的插画、"
        "角色对话文本、部分代码实现），其输出均经团队在本地运行、测试与修改后采用；",
        "演示视频由团队录制与剪辑，全部参赛文档由团队组织撰写。",
    ]):
        t(d, "%d. %s" % (i + 1, s))
    h(d, "六、使用工具与资源")
    table(d, [
        ["类别", "内容"],
        ["游戏引擎", "Godot 4.7.2（GDScript）"],
        ["本地服务", "Python 3 + FastAPI（本地 AI 服务，可选启动）"],
        ["大语言模型", "DeepSeek（角色对话与事件文本；不可用时自动降级）"],
        ["图像生成", "本地部署 Stable Diffusion XL（ComfyUI，全流程本机运行）"],
        ["图像处理", "Python + Pillow（像素贴图程序化生成、色板审计、排版合成）"],
        ["数值与内容", "JSON（23 个数据段 + 64 条事件）"],
        ["质量保障", "自研自动化测试（4 套 388 项断言）、结构校验、色板与素材审计"],
    ])
    h(d, "七、承诺")
    t(d, "本团队承诺：以上分工与贡献说明真实反映各成员的实际工作情况，"
         "作品为学生团队的原创成果，不存在冒名参赛或虚假申报情形。"
         "如与实际情况不符，本团队愿承担相应责任。")
    d.add_paragraph()
    d.add_paragraph()
    # 三张手写签名
    names = ["李鹏宇", "王焕楷", "李云天"]
    tb = d.add_table(rows=2, cols=3)
    tb.alignment = WD_TABLE_ALIGNMENT.CENTER
    for ci, n in enumerate(names):
        cell = tb.cell(0, ci)
        cell.text = ""
        par = cell.paragraphs[0]
        par.alignment = WD_ALIGN_PARAGRAPH.CENTER
        f = SIG / (n + ".jpg")
        if f.exists():
            par.add_run().add_picture(str(f), width=Cm(3.6))
        else:
            cjk(par.add_run("＿＿＿＿＿＿"), 11)
        c2 = tb.cell(1, ci)
        c2.text = ""
        pp = c2.paragraphs[0]
        pp.alignment = WD_ALIGN_PARAGRAPH.CENTER
        cjk(pp.add_run(n), 10.5)
    d.add_paragraph()
    q = d.add_paragraph()
    q.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    cjk(q.add_run("日期：" + DATE), 11)
    p = OUT / "团队分工与贡献说明.docx"
    d.save(p)
    return p


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    made = []
    for fn in (build_run, build_ai, build_ip, build_evidence, build_team):
        p = fn()
        made.append(p)
        print("  %-34s %7.0f KB" % (p.name, p.stat().st_size / 1024))
    print("\n  生成 %d 份 -> %s" % (len(made), OUT))


if __name__ == "__main__":
    main()
