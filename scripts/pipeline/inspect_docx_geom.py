#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""读 docx 的真实几何：页面/页边距/表格宽/列宽，全用 twips。

为什么不用渲染图看：渲染 PNG 四周带白边，按像素估算会算歪。
XML 里的数字是权威值。
"""
import sys as _sys
from pathlib import Path as _Path
_sys.path.insert(0, str(_Path(__file__).resolve().parent))
from _root import ROOT  # 路径唯一解析处，不再写死盘符
from docx import Document
from docx.oxml.ns import qn

P = str(ROOT / "deliverables/《坎儿井》作品申报书.docx")
d = Document(P)
s = d.sections[0]

def tw(v):
    return None if v is None else int(v / 635)

print("=== 页面与页边距（twips）===")
print(f"  页宽 {tw(s.page_width)}  页高 {tw(s.page_height)}")
print(f"  左边距 {tw(s.left_margin)}  右边距 {tw(s.right_margin)}")
print(f"  正文可用宽 = {tw(s.page_width) - tw(s.left_margin) - tw(s.right_margin)} twips"
      f" = {(tw(s.page_width) - tw(s.left_margin) - tw(s.right_margin))/1440:.2f} 英寸")

print()
print("=== 表格 ===")
for i, t in enumerate(d.tables):
    tbl = t._tbl
    tblW = tbl.find(qn('w:tblPr') + '/' + qn('w:tblW'))
    layout = tbl.find(qn('w:tblPr') + '/' + qn('w:tblLayout'))
    grid = tbl.find(qn('w:tblGrid'))
    cols = []
    if grid is not None:
        cols = [int(g.get(qn('w:w'))) for g in grid.findall(qn('w:gridCol'))]
    cells_w = [int(c.width / 635) for c in t.rows[0].cells if c.width is not None]
    print(f"  表{i+1}: {len(t.rows)}行 x {len(t.columns)}列")
    print(f"      tblW={tblW.get(qn('w:w')) if tblW is not None else None}"
          f" type={tblW.get(qn('w:type')) if tblW is not None else None}")
    print(f"      tblLayout={layout.get(qn('w:type')) if layout is not None else None}")
    print(f"      gridCol={cols}  合计={sum(cols)}")
    print(f"      首行单元格宽={cells_w}  合计={sum(cells_w)}")
