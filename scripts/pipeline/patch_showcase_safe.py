#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""把展示稿的排版改成**防御性布局**，不跟渲染器的缩放行为较劲。

背景：把元素按 1.05 / 3.33 / 5.61 / 7.89 / 10.17 英寸排成 5 列之后，
渲染图上第 4、5 格压出了右边缘。**文件里的几何是对的**（读回来确认过：
slide 13.333×7.5in、形状坐标就是那些值），所以偏差出在渲染环节 ——
但我没法控制评委机器上用什么渲染器。

所以策略改成两件事：
  1. **列数降到 3**（九宫格）：单格更宽，同样的偏差也压不出画
  2. **内容右边界一律收到 87%（≈11.6in）以内**，把 1.6in 当作"安全余量"让出去
这比"算出精确坐标然后赌渲染器听话"可靠得多。
"""
import sys as _sys
from pathlib import Path as _Path
_sys.path.insert(0, str(_Path(__file__).resolve().parent))
from _root import ROOT  # 路径唯一解析处，不再写死盘符
from pathlib import Path

P = Path(str(ROOT / "scripts/pipeline/build_showcase.py"))
t = P.read_text(encoding="utf-8")

# ── 九宫格：5 列改 3 列，右边界收到 11.6in ──
OLD = '''    jobs = ["治水", "耕作", "采集", "经商", "守卫", "炊事", "做工", "演艺", "待命"]
    for i, j in enumerate(jobs):
        col, row = i % 5, i // 5
        x = Inches(1.05) + col * Inches(2.28)
        y = Inches(3.35) + row * Inches(1.12)
        rect(s, x, y, Inches(2.02), Inches(0.86), PANEL, alpha=0.85, rounded=True,
             line=GOLD, lw=0.75)
        textbox(s, x, y + Inches(0.20), Inches(2.02), Inches(0.5),
                [(j, 21, CREAM, True)], align=PP_ALIGN.CENTER)
    textbox(s, Inches(1.05), Inches(5.70), Inches(11.2), Inches(0.5),
            [("安排谁值守、谁治水、谁带队 —— 而你在分工面板里怎么派人，"
              "直接决定战场上有什么兵。", 14, MUTED, False)])
    fit_box(s, SHOTS / "S10_deck_B_分工面板.png",
            Inches(8.15), Inches(5.72), Inches(4.1), Inches(1.35))'''
NEW = '''    jobs = ["治水", "耕作", "采集", "经商", "守卫", "炊事", "做工", "演艺", "待命"]
    for i, j in enumerate(jobs):
        col, row = i % 3, i // 3
        x = Inches(1.10) + col * Inches(3.62)
        y = Inches(3.10) + row * Inches(1.16)
        rect(s, x, y, Inches(3.32), Inches(0.94), PANEL, alpha=0.88, rounded=True,
             line=GOLD, lw=1.0)
        textbox(s, x, y + Inches(0.24), Inches(3.32), Inches(0.5),
                [(j, 20, CREAM, True)], align=PP_ALIGN.CENTER)
    textbox(s, Inches(1.10), Inches(6.58), Inches(10.4), Inches(0.5),
            [("你怎么派人，直接决定战场上有什么兵。", 14, MUTED, False)])'''
assert OLD in t, "九宫格段落没匹配上"
t = t.replace(OLD, NEW)

# ── 第 2 页底部那条绿洲长图右边界收回 ──
t = t.replace('Inches(1.05), Inches(5.98), Inches(11.2), Inches(1.05), frame=False)',
              'Inches(1.10), Inches(5.96), Inches(10.4), Inches(1.06), frame=False)')
# ── 四个画面墙：两列右边界收回 ──
t = t.replace('x = Inches(0.95) + col * Inches(5.86)', 'x = Inches(1.00) + col * Inches(5.42)')
t = t.replace('fit_box(s, img, x, y, Inches(5.52), Inches(1.95))',
              'fit_box(s, img, x, y, Inches(5.10), Inches(1.92))')
t = t.replace('textbox(s, x, y + Inches(1.98), Inches(5.6), Inches(0.34)',
              'textbox(s, x, y + Inches(1.95), Inches(5.2), Inches(0.34)')
t = t.replace('textbox(s, x, y + Inches(2.28), Inches(5.6), Inches(0.34)',
              'textbox(s, x, y + Inches(2.24), Inches(5.2), Inches(0.34)')
# ── 三张文化卡右边界收回 ──
t = t.replace('x = Inches(0.95) + i * Inches(3.94)', 'x = Inches(1.00) + i * Inches(3.62)')
t = t.replace('rect(s, x, Inches(2.05), Inches(3.62), Inches(4.55)',
              'rect(s, x, Inches(2.05), Inches(3.32), Inches(4.55)')
t = t.replace('rect(s, x, Inches(2.05), Inches(3.62), Inches(0.11)',
              'rect(s, x, Inches(2.05), Inches(3.32), Inches(0.11)')
t = t.replace('Inches(2.98), Inches(1.68),\n                frame=False)',
              'Inches(2.68), Inches(1.62),\n                frame=False)')
# ── 四个大数字右边界收回 ──
t = t.replace('x = Inches(1.05) + i * Inches(2.88)', 'x = Inches(1.10) + i * Inches(2.66)')
t = t.replace('rect(s, x, Inches(2.85), Inches(2.62), Inches(2.35)',
              'rect(s, x, Inches(2.85), Inches(2.42), Inches(2.35)')
t = t.replace('rect(s, x + Inches(1.16), Inches(2.85), Inches(0.30), Pt(2.0), GOLD)',
              'rect(s, x + Inches(1.06), Inches(2.85), Inches(0.30), Pt(2.0), GOLD)')
t = t.replace('textbox(s, x, Inches(3.20), Inches(2.62), Inches(1.0)',
              'textbox(s, x, Inches(3.20), Inches(2.42), Inches(1.0)')
t = t.replace('textbox(s, x, Inches(4.18), Inches(2.62), Inches(0.5)',
              'textbox(s, x, Inches(4.18), Inches(2.42), Inches(0.5)')
# ── 三条技术行右边界收回 ──
t = t.replace('rect(s, Inches(0.95), y, Inches(11.42), Inches(1.24)',
              'rect(s, Inches(1.00), y, Inches(10.60), Inches(1.24)')
t = t.replace('textbox(s, Inches(1.42), y + Inches(0.16), Inches(10.6), Inches(0.44)',
              'textbox(s, Inches(1.45), y + Inches(0.16), Inches(9.9), Inches(0.44)')
t = t.replace('textbox(s, Inches(1.44), y + Inches(0.66), Inches(10.6), Inches(0.5)',
              'textbox(s, Inches(1.47), y + Inches(0.66), Inches(9.9), Inches(0.5)')
# ── 灾难页两图右边界收回 ──
t = t.replace('Inches(4.75), Inches(3.35),\n            Inches(7.5), Inches(3.55))',
              'Inches(4.75), Inches(3.35),\n            Inches(6.85), Inches(3.55))')

P.write_text(t, encoding="utf-8")
print("  已改为防御性布局：九宫格 3 列 + 右边界收到 11.6in 以内")
