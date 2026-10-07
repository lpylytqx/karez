#!/usr/bin/env python -u
# -*- coding: utf-8 -*-
"""把页脚那行改回"只写团队名"，去掉指导教师。

改 3 处：
  · 展示稿 · 每页页脚        坎儿井 · 代码一次敲队 · 指导教师 …   →  坎儿井 · 代码一次敲队
  · 展示稿 · 收尾页底部行      《坎儿井》· 代码一次敲队 · 指导教师 … →  《坎儿井》· 代码一次敲队
  · 答辩稿 · 每页页脚         同上

**不动**的地方：
  · 展示稿封面那行金色的「指导教师：徐媛媛 / 李中岩」—— 那是上次专门要求加的独立一行，
    不是页脚
  · 答辩稿封面同样保留

改完要重新合并（merge_decks3.py），因为合并稿是从两个源脚本现画出来的。
每次替换都回读校验。
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import ROOT  # noqa: E402

SH = ROOT / "scripts" / "pipeline" / "build_showcase.py"
DK = ROOT / "scripts" / "pipeline" / "build_deck.py"
ADV = "　·　指导教师 徐媛媛 / 李中岩"

JOBS = [
    (SH, '[("坎儿井　·　代码一次敲队%s", 9.5, MUTED, False)])' % ADV,
         '[("坎儿井　·　代码一次敲队", 9.5, MUTED, False)])',
         "展示稿 · 每页页脚"),
    (SH, '[("《坎儿井》· 代码一次敲队%s", 10.5, MUTED, False)])' % ADV,
         '[("《坎儿井》· 代码一次敲队", 10.5, MUTED, False)])',
         "展示稿 · 收尾页底部"),
    (DK, '[("《坎儿井》· 代码一次敲队%s", 9, MUTED, False)])' % ADV,
         '[("《坎儿井》· 代码一次敲队", 9, MUTED, False)])',
         "答辩稿 · 每页页脚"),
]


def main() -> None:
    ok = 0
    for path, old, new, what in JOBS:
        t = path.read_text(encoding="utf-8")
        if old not in t:
            # 可能已经改过了
            if new in t:
                print("  %-20s 已经是新写法，跳过" % what)
            else:
                print("  %-20s ✗ 锚点没匹配上" % what)
            continue
        path.write_text(t.replace(old, new, 1), encoding="utf-8")
        back = path.read_text(encoding="utf-8")
        if new in back:
            ok += 1
            print("  %-20s ✓（已回读确认）" % what)
        else:
            print("  %-20s ✗ 回读没找到新写法" % what)

    # 校验：页脚不再带指导老师，但封面那行必须还在
    sh = SH.read_text(encoding="utf-8")
    print("\n  校验：")
    print("    展示稿页脚带指导老师：%s（应为 否）"
          % ("是 ✗" if '坎儿井　·　代码一次敲队　·　指导教师' in sh else "否 ✓"))
    print("    展示稿封面仍保留指导教师：%s（应为 是）"
          % ("是 ✓" if "指导教师：徐媛媛　/　李中岩" in sh else "否 ✗"))
    dk = DK.read_text(encoding="utf-8")
    print("    答辩稿页脚带指导老师：%s（应为 否）"
          % ("是 ✗" if '《坎儿井》· 代码一次敲队　·　指导教师' in dk else "否 ✓"))
    print("    答辩稿封面仍保留指导教师：%s（应为 是）"
          % ("是 ✓" if "指导教师 徐媛媛 / 李中岩" in dk else "否 ✗"))

    import py_compile
    for f in (SH, DK):
        py_compile.compile(str(f), doraise=True)
    print("  两份脚本语法检查通过；改 %d 处" % ok)


if __name__ == "__main__":
    main()
