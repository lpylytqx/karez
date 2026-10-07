#!/usr/bin/env python -u
# -*- coding: utf-8 -*-
"""修答辩稿里剩下的 3 处过期数字。

  L426  「12,910 行有效代码」                       → 13,004 行作品代码
  L427  「419 张美术 · 377 个音频 · 70+ 张实机截图」  → 421 张美术 · 189 个音频 · 25 张实机截图
  L373  「419 张 PNG 全部合规」                     → 421 张 PNG 全部合规

「70+ 张实机截图」也过期了 —— 我清理过截图目录，现在 25 张（其中 10 张是提交用的）。

改完必须**重新合并**（合并稿是从 build_showcase + build_deck 现画出来的），
否则合并稿里仍是旧数字。
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import ROOT  # noqa: E402

DK = ROOT / "scripts" / "pipeline" / "build_deck.py"

JOBS = [
    ("12,910 行有效代码 · 事件 64 条 · 建筑 13 座",
     "13,004 行作品代码 · 事件 64 条 · 建筑 13 座", "代码行数"),
    ("419 张美术 · 377 个音频 · 70+ 张实机截图",
     "421 张美术 · 189 个音频 · 25 张实机截图", "美术/音频/截图"),
    ("419 张 PNG 全部合规", "421 张 PNG 全部合规", "色板审计张数"),
]


def main() -> None:
    t = DK.read_text(encoding="utf-8")
    n = 0
    for old, new, what in JOBS:
        if old not in t:
            print("  %-18s %s" % (what, "已是新值" if new in t else "✗ 锚点没匹配上"))
            continue
        t = t.replace(old, new, 1)
        n += 1
        print("  %-18s ✓" % what)
    DK.write_text(t, encoding="utf-8")

    back = DK.read_text(encoding="utf-8")
    bad = [s for s in ("12,910", "377 个", "70+ 张") if s in back]
    print("\n  复查 build_deck.py 残留：%s" % (bad if bad else "干净 ✓"))
    import py_compile
    py_compile.compile(str(DK), doraise=True)
    print("  语法检查通过；改 %d 处" % n)


if __name__ == "__main__":
    main()
