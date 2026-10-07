#!/usr/bin/env python -u
# -*- coding: utf-8 -*-
"""把指导教师补到两份 PPT 的署名里。

现状：
  · 答辩稿封面**已有**「… · 指导教师 徐媛媛 / 李中岩」✓，但它的页脚没有
  · 展示稿**三处都没有**（页脚 / 封面 / 收尾）

改 4 处，措辞与答辩稿封面保持一致（徐媛媛 / 李中岩）。

⚠ 每一次替换后都**回读校验** —— 这个项目上 `str.replace` 匹配不上时是静默不动的，
  我已经因此误报过两次"改好了"。
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import ROOT  # noqa: E402

SH = ROOT / "scripts" / "pipeline" / "build_showcase.py"
DK = ROOT / "scripts" / "pipeline" / "build_deck.py"

ADV = "指导教师 徐媛媛 / 李中岩"

JOBS = [
    # (文件, 原文, 新文, 说明)
    (SH, '[("坎儿井　·　代码一次敲队", 9.5, MUTED, False)])',
         '[("坎儿井　·　代码一次敲队　·　%s", 9.5, MUTED, False)])' % ADV,
         "展示稿 · 每页页脚"),
    (SH, '[("代码一次敲队　·　李鹏宇 / 王焕楷 / 李云天", 11, MUTED, False)])',
         '[("代码一次敲队　·　李鹏宇 / 王焕楷 / 李云天", 11, MUTED, False),\n'
         '             ("指导教师：徐媛媛　/　李中岩", 11, GOLD, False, 3)])',
         "展示稿 · 封面"),
    (SH, '[("《坎儿井》· 代码一次敲队", 10.5, MUTED, False)])',
         '[("《坎儿井》· 代码一次敲队　·　%s", 10.5, MUTED, False)])' % ADV,
         "展示稿 · 收尾页"),
    (DK, '[("《坎儿井》· 代码一次敲队", 9, MUTED, False)])',
         '[("《坎儿井》· 代码一次敲队　·　%s", 9, MUTED, False)])' % ADV,
         "答辩稿 · 每页页脚"),
]


def main() -> None:
    ok = 0
    for path, old, new, what in JOBS:
        t = path.read_text(encoding="utf-8")
        if new.strip().split("\n")[0] in t and ADV in t and old not in t:
            print("  %-22s 已改过，跳过" % what)
            continue
        if old not in t:
            print("  %-22s ✗ 锚点没匹配上，未改" % what)
            continue
        t2 = t.replace(old, new, 1)
        path.write_text(t2, encoding="utf-8")
        back = path.read_text(encoding="utf-8")   # ★ 回读校验
        if ADV in back:
            ok += 1
            print("  %-22s ✓（已回读确认）" % what)
        else:
            print("  %-22s ✗ 写入后回读没找到，请检查" % what)

    import py_compile
    for f in (SH, DK):
        py_compile.compile(str(f), doraise=True)
    print("  共改 %d 处，两份脚本语法检查通过" % ok)


if __name__ == "__main__":
    main()
