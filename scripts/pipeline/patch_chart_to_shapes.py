#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""把第 13 页的「原生图表」换成**用形状画柱状图**。

原因：native chart 的绘图区是交给渲染器算的，LibreOffice 会把绘图区压到最底部、
类目名挤出画面（实测两轮都是如此），而评委机器上未必是 PowerPoint。
用形状自己画柱子和标签，**在哪个渲染器里都长一样**。

数据只有 4 根柱子，手画完全可控；换成真正需要交互筛选的大数据集才值得用 native chart。
"""
import sys as _sys
from pathlib import Path as _Path
_sys.path.insert(0, str(_Path(__file__).resolve().parent))
from _root import ROOT  # 路径唯一解析处，不再写死盘符
from pathlib import Path

P = Path(str(ROOT / "scripts/pipeline/build_deck.py"))
t = P.read_text(encoding="utf-8")

START = "    data = CategoryChartData()"
END = "             10, MUTED, False)])\n"
i = t.index(START)
j = t.index(END, i) + len(END)

NEW = '''    # 数据：同样 5 打 4，只换摆法，各跑 6 遍的平均阵亡人数
    bars = [("全员压前线", 0.0), ("自动布阵", 1.0), ("一字纵队", 1.17), ("弓手出射程", 3.0)]
    base_y = Inches(5.62)          # 基线
    max_h = Inches(3.05)           # 3.0 对应的柱高
    vmax = 3.5
    n = len(bars)
    slot = Inches(2.05)
    x0 = Inches(2.30)
    # 网格线与刻度
    for v in (0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5):
        y = base_y - int(max_h * v / vmax)
        rect(s, x0, y, Inches(8.4), Pt(0.6), MUTED if v else GOLD)
        textbox(s, x0 - Inches(0.62), y - Inches(0.13), Inches(0.52), Inches(0.26),
                [("%g" % v, 10, MUTED, False)], align=PP_ALIGN.RIGHT)
    for k, (name, val) in enumerate(bars):
        cx = x0 + Inches(0.45) + k * slot
        h = int(max_h * val / vmax)
        if h > 0:
            rect(s, cx, base_y - h, Inches(1.05), h, GOLD)
        else:
            rect(s, cx, base_y - Pt(1.5), Inches(1.05), Pt(1.5), DEEP)
        textbox(s, cx - Inches(0.25), base_y - h - Inches(0.34), Inches(1.55), Inches(0.3),
                [("%g" % val, 12.5, GOLD, True)], align=PP_ALIGN.CENTER)
        textbox(s, cx - Inches(0.35), base_y + Inches(0.10), Inches(1.75), Inches(0.34),
                [(name, 11.5, CREAM, False)], align=PP_ALIGN.CENTER)
    rect(s, ML, Inches(1.70), CW, Pt(0.8), GOLD, alpha=0.35)
    textbox(s, x0, Inches(1.86), Inches(8.4), Inches(0.3),
            [("平均阵亡人数（人）", 11.5, MUTED, False)], align=PP_ALIGN.CENTER)
    textbox(s, x0, Inches(6.16), Inches(8.6), Inches(0.4),
            [("每种摆法各跑 6 遍、共用同一组随机种子（scripts/tests/formation_probe.gd）",
              10, MUTED, False)])
'''
t = t[:i] + NEW + t[j:]
P.write_text(t, encoding="utf-8")
print("  第 13 页已改为形状画柱状图")
