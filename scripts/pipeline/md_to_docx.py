#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""把申报书 Markdown 转成排版规整的 Word（.docx）。

为什么不用 pandoc：本机没装 pandoc。这条路径用 python-docx 自己解析，
好处是**中文字体能显式指定**（python-docx 需要同时设 `w:eastAsia`，
只设 run.font.name 是没用的 —— 技能文档特别提醒过这一点）。

用法：<bundled-python> scripts/pipeline/md_to_docx.py
输入：docs/10-申报书.md
输出：deliverables/《坎儿井》作品申报书.docx
"""
from __future__ import annotations

import sys as _sys
from pathlib import Path as _Path
_sys.path.insert(0, str(_Path(__file__).resolve().parent))
from _root import ROOT  # 路径唯一解析处，不再写死盘符
import re
import sys
from pathlib import Path

from docx import Document
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml.ns import qn
from docx.shared import Emu, Pt, RGBColor

ROOT = ROOT
SRC = _Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "docs" / "10-申报书.md"
OUT = _Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / "deliverables" / (SRC.stem + ".docx")

BODY_FONT = "微软雅黑"
HEAD_FONT = "微软雅黑"        # 用雅黑：每台 Windows 都有，评审机不会因缺字体而排版错乱
ACCENT = RGBColor(0xA8, 0x52, 0x2F)   # 取自游戏 34 色板的深赭红
BODY_PT = 10.5


def set_cjk(run, font: str) -> None:
    """中文字体必须同时设 eastAsia，否则 Word 用默认宋体渲染。"""
    run.font.name = font
    rpr = run._element.get_or_add_rPr()
    rfonts = rpr.find(qn("w:rFonts"))
    if rfonts is None:
        rfonts = rpr.makeelement(qn("w:rFonts"), {})
        rpr.append(rfonts)
    rfonts.set(qn("w:eastAsia"), font)
    rfonts.set(qn("w:ascii"), font)
    rfonts.set(qn("w:hAnsi"), font)


def fit_table(table, text_twips: int, rows: list[list[str]]) -> None:
    """把表格宽度**钉死在正文宽度内**，三处都要写，缺一处就会被撑宽。

    ⚠ 只设 `cell.width` 是不够的 —— 那只写 `w:tcW`。渲染出来表格仍然溢出，
    读 XML 才发现两个真因：
      · `w:tblW = 0 type="auto"`（表宽自动）→ LibreOffice 按内容撑宽，
        再叠加居中，于是左右两边一起溢出页边距
      · `w:tblGrid` 的列宽是**均匀的**（python-docx 默认），而 fixed 布局下
        Word/LibreOffice 优先看 tblGrid
    所以这里三件一起做：tblW 定死 dxa、tblGrid 按比例写、对齐改左（万一还有
    残余溢出，也只影响右边缘，不会把左边也顶出版心）。
    """
    table.autofit = False
    ncol = len(table.columns)
    # 按"最长单元格字符数"给列分权重，加下限避免某列太窄
    weights = []
    for ci in range(ncol):
        longest = max((len(r[ci]) for r in rows if ci < len(r)), default=1)
        weights.append(max(4, min(longest, 40)))
    total = float(sum(weights))
    widths = [int(text_twips * w / total) for w in weights]

    tbl = table._tbl
    tblPr = tbl.tblPr
    # 1) w:tblW 定死为正文宽度
    for old in tblPr.findall(qn("w:tblW")):
        tblPr.remove(old)
    tblW = tblPr.makeelement(qn("w:tblW"), {qn("w:w"): str(sum(widths)), qn("w:type"): "dxa"})
    tblPr.append(tblW)
    # 2) w:tblGrid 逐列改写
    grid = tbl.find(qn("w:tblGrid"))
    if grid is not None:
        for gc, w in zip(grid.findall(qn("w:gridCol")), widths):
            gc.set(qn("w:w"), str(w))
    # 3) 单元格宽度也跟着写（部分渲染器只看 tcW）
    for ci, w in enumerate(widths):
        for cell in table.columns[ci].cells:
            cell.width = Emu(int(w * 635))
    table.alignment = WD_TABLE_ALIGNMENT.LEFT


def add_runs(par, text: str) -> None:
    """把 **粗体** 拆成 run，其余按普通文本。"""
    for part in re.split(r"(\*\*[^*]+\*\*)", text):
        if not part:
            continue
        bold = part.startswith("**") and part.endswith("**")
        run = par.add_run(part[2:-2] if bold else part)
        run.bold = bold
        run.font.size = Pt(BODY_PT)
        set_cjk(run, BODY_FONT)


def is_table_row(line: str) -> bool:
    return line.strip().startswith("|") and line.strip().endswith("|")


def split_row(line: str) -> list[str]:
    return [c.strip() for c in line.strip().strip("|").split("|")]


def main() -> None:
    lines = SRC.read_text(encoding="utf-8").splitlines()
    doc = Document()

    # 正文默认样式
    style = doc.styles["Normal"]
    style.font.name = BODY_FONT
    style.font.size = Pt(BODY_PT)
    style.element.rPr.rFonts.set(qn("w:eastAsia"), BODY_FONT)

    # 页边距收窄到 1 英寸（默认 1.25 英寸会把本来就宽的表格进一步挤出页面），
    # 并算出正文实际可用宽度，供表格钉宽用。
    sec = doc.sections[0]
    sec.left_margin = Emu(int(1440 * 635))
    sec.right_margin = Emu(int(1440 * 635))
    text_twips = int(sec.page_width / Emu(635)) - 1440 * 2

    i = 0
    first_h1 = True
    while i < len(lines):
        raw = lines[i]
        line = raw.rstrip()
        s = line.strip()

        # 代码块：申报书里没有，遇到就跳过围栏本身（保留内容为普通段）
        if s.startswith("```"):
            i += 1
            while i < len(lines) and not lines[i].strip().startswith("```"):
                i += 1
            i += 1
            continue

        if not s:
            i += 1
            continue

        if s == "---":
            i += 1
            continue

        # 表格
        if is_table_row(s):
            rows: list[list[str]] = []
            while i < len(lines) and is_table_row(lines[i]):
                cells = split_row(lines[i])
                # 跳过 |---|---| 分隔行
                if not all(re.fullmatch(r":?-{2,}:?", c) for c in cells):
                    rows.append(cells)
                i += 1
            if rows:
                ncol = max(len(r) for r in rows)
                t = doc.add_table(rows=0, cols=ncol)
                t.style = "Light Grid Accent 1"
                t.alignment = WD_TABLE_ALIGNMENT.CENTER
                for ri, row in enumerate(rows):
                    cells = t.add_row().cells
                    for ci in range(ncol):
                        txt = row[ci] if ci < len(row) else ""
                        par = cells[ci].paragraphs[0]
                        add_runs(par, txt)
                        if ri == 0:
                            for r in par.runs:
                                r.bold = True
                fit_table(t, text_twips, rows)
                doc.add_paragraph()
            continue

        # 标题
        m = re.match(r"^(#{1,4})\s+(.*)$", s)
        if m:
            level = len(m.group(1))
            text = m.group(2).strip()
            if level == 1 and first_h1:
                p = doc.add_heading("", level=0)
                run = p.add_run(text)
                set_cjk(run, HEAD_FONT)
                run.font.size = Pt(20)
                run.font.color.rgb = ACCENT
                run.bold = True
                p.alignment = WD_ALIGN_PARAGRAPH.CENTER
                # Title 样式自带缩进，会把居中算歪、文字被右边缘切掉，这里清零
                p.paragraph_format.left_indent = Emu(0)
                p.paragraph_format.right_indent = Emu(0)
                p.paragraph_format.first_line_indent = Emu(0)
                first_h1 = False
            else:
                p = doc.add_heading("", level=min(level, 3))
                run = p.add_run(text)
                set_cjk(run, HEAD_FONT)
                run.bold = True
                if level == 2:
                    run.font.color.rgb = ACCENT
            i += 1
            continue

        # 引用
        if s.startswith(">"):
            p = doc.add_paragraph()
            p.paragraph_format.left_indent = Pt(18)
            add_runs(p, s.lstrip("> ").strip())
            for r in p.runs:
                r.italic = True
                r.font.color.rgb = RGBColor(0x66, 0x66, 0x66)
            i += 1
            continue

        # 列表
        m = re.match(r"^([-*]|\d+\.)\s+(.*)$", s)
        if m:
            p = doc.add_paragraph(style="List Bullet" if m.group(1) in "-*" else "List Number")
            add_runs(p, m.group(2))
            i += 1
            continue

        # 普通段落
        p = doc.add_paragraph()
        add_runs(p, s)
        i += 1

    OUT.parent.mkdir(parents=True, exist_ok=True)
    doc.save(OUT)

    # 自检：段落数、表格数、字符数
    chk = Document(OUT)
    chars = sum(len(p.text) for p in chk.paragraphs)
    tchars = sum(len(c.text) for t in chk.tables for r in t.rows for c in r.cells)
    print("  已生成：%s" % OUT)
    print("  段落 %d 个，表格 %d 个，正文 %d 字 + 表格 %d 字 = %d 字"
          % (len(chk.paragraphs), len(chk.tables), chars, tchars, chars + tchars))


if __name__ == "__main__":
    main()
