#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""第 13 页最终版：把图表换成**表格**。

走过的路，记下来免得下次再撞：
  1. native chart（python-pptx 的 add_chart）—— LibreOffice 把绘图区压到最底部，
     类目名挤出画面。渲染器说了算，不受我控。
  2. 自己用形状画柱状图 —— 柱子和网格线的坐标在渲染时被放大了约 1.5 倍
     （同一位置在别的页面对得上，在图表这条路径上对不上），两次都没稳定。
  3. 表格 —— 本 PPT 里已经用了 3 张表格，**每一张渲染都对得上**。

结论：在换渲染器不可控的前提下，**能用表格表达的数据就用表格**，
不要为了"图表感"去赌渲染器的行为。这一页要传达的只有一件事：
摆法不同，阵亡从 0 到 3 —— 表格完全担得起。
"""
import sys as _sys
from pathlib import Path as _Path
_sys.path.insert(0, str(_Path(__file__).resolve().parent))
from _root import ROOT  # 路径唯一解析处，不再写死盘符
from pathlib import Path

P = Path(str(ROOT / "scripts/pipeline/build_deck.py"))
t = P.read_text(encoding="utf-8")

START = "    # 数据：同样 5 打 4，只换摆法"
END = "              10, MUTED, False)])\n"
i = t.index(START)
j = t.index(END, i) + len(END)

NEW = '''    table(s, [
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
'''
t = t[:i] + NEW + t[j:]
P.write_text(t, encoding="utf-8")
print("  第 13 页已改为表格 + 结论条")
