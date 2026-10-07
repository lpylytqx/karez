#!/usr/bin/env python -u
# -*- coding: utf-8 -*-
"""把两份 PPT 的定位改写为「自主命题·虚拟现实与游戏」，并补上新疆历史文化纵深。

改四处：
  build_showcase.py
    · 封面副标题：AI 原生定位 → 新疆两千年水利遗产定位
    · 第 2 页正文：补一句"你挖的这个东西，现实里用了两千多年"
    · 第 7 页：底部补一行历史依据脚注（三项权威认定）
  build_deck.py
    · 封面副标题：AIGC 数字创意作品 · 答辩 → 自主命题 · 虚拟现实与游戏
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import ROOT  # noqa: E402

SH = ROOT / "scripts" / "pipeline" / "build_showcase.py"
DK = ROOT / "scripts" / "pipeline" / "build_deck.py"


def main() -> None:
    s = SH.read_text(encoding="utf-8")
    n = 0

    # ① 封面副标题
    old1 = '[("一款 AI 原生的新疆丝路经营游戏", 21, GOLD, True)])'
    new1 = '[("新疆两千年水利遗产 · 一款能玩的经营游戏", 21, GOLD, True)])'
    if old1 in s:
        s = s.replace(old1, new1, 1)
        n += 1
        print("  ✓ 展示稿封面副标题")

    # ② 第 2 页正文补一句历史纵深
    old2 = '''    textbox(s, Inches(0.97), Inches(2.62), Inches(11.4), Inches(1.2),
            [("游戏里没有「开局送资源」这回事。你接手的驿站因为坎儿井淤塞、"
              "水源断绝而衰败 —— 第一件事只能是挖井。", 16.5, MUTED, False)])'''
    new2 = '''    textbox(s, Inches(0.97), Inches(2.58), Inches(11.4), Inches(1.5),
            [("游戏里没有「开局送资源」这回事。你接手的驿站因为坎儿井淤塞、"
              "水源断绝而衰败 —— 第一件事只能是挖井。", 16.5, MUTED, False),
             ("而你挖的这个东西，在现实里已经用了两千多年。", 17, GOLD, True, 10)])'''
    if old2 in s:
        s = s.replace(old2, new2, 1)
        n += 1
        print("  ✓ 展示稿第 2 页补历史纵深")
    else:
        print("  [警告] 第 2 页正文没匹配上")

    # ③ 第 7 页底部历史依据脚注
    anchor = '''                x + Inches(0.32), Inches(4.62), Inches(2.68), Inches(1.62),
                frame=False)
'''
    foot = '''
    textbox(s, Inches(0.97), Inches(6.74), Inches(11.4), Inches(0.62),
            [("坎儿井开凿技艺 · 国家级非物质文化遗产　|　"
              "新疆坎儿井 · 2014 年入选世界灌溉工程遗产名录", 11, MUTED, False),
             ("十二木卡姆 · 2005 年列入联合国教科文组织人类口头和非物质遗产代表作名录",
              11, MUTED, False, 3)])
'''
    if anchor in s and "世界灌溉工程遗产名录" not in s:
        s = s.replace(anchor, anchor + foot, 1)
        n += 1
        print("  ✓ 展示稿第 7 页补历史依据脚注")

    SH.write_text(s, encoding="utf-8")

    # ④ 答辩稿封面副标题
    d = DK.read_text(encoding="utf-8")
    old4 = '[("AIGC 数字创意作品 · 答辩", 14.5, GOLD, True)])'
    new4 = '[("自主命题 · 虚拟现实与游戏", 14.5, GOLD, True)])'
    if old4 in d:
        d = d.replace(old4, new4, 1)
        DK.write_text(d, encoding="utf-8")
        n += 1
        print("  ✓ 答辩稿封面副标题")
    else:
        print("  [警告] 答辩稿副标题没匹配上")

    print("  共改 %d 处" % n)
    import py_compile
    for f in (SH, DK):
        py_compile.compile(str(f), doraise=True)
    print("  两份脚本语法检查通过")


if __name__ == "__main__":
    main()
