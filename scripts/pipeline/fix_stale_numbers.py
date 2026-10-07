#!/usr/bin/env python -u
# -*- coding: utf-8 -*-
"""按"数得准"的真实数据，修正申报书/作品信息表里的过期数字。

终检发现 4 处对不上（其中两处是我的检查器自己数错，已排除）：

  ✗ 代码行数  文档 12,910（GDScript 8,143 + Python 4,767）
              实际 13,004（游戏本体 8,664 + AI 服务 1,917 + 测试 2,423）
              口径说明必须写进去，否则评审去数 scripts/*.gd 会得到别的数
  ✗ 音频个数  文档 377 个
              实际 **189 个** —— 377 是把每个音频的 `.import` 副档也数了一遍
              （189 × 2 ≈ 378，正好对得上，所以是数法错了而不是数据变了）
  ✗ 美术张数  文档 419 张
              实际 421 张（`assets/` 下排除 `_wip` 开发中间产物后的张数）
  ✗ PPT 断言  答辩稿页面标题「371 项断言证明它能跑」
              实际 **388 项**（跑测试确认：15+170+84+119）

**没改的**：事件 64 ✓ 建筑 13 ✓ 岗位 9 ✓ 数据段 23 ✓ 灾难 6 ✓ 节庆 3 ✓
木卡姆 6 ✓ 加工 5 ✓ 畜种 5 ✓ 断言 388 ✓ —— 这些都核过是对的。
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import ROOT  # noqa: E402

MD = ROOT / "docs"
DK = ROOT / "scripts" / "pipeline" / "build_deck.py"

JOBS = [
    (MD / "10-申报书.md",
     "| **代码规模** | 12,910 行有效代码（GDScript 35 个文件 8,143 行 + Python 43 个文件 4,767 行） |",
     "| **代码规模** | **13,004 行**作品代码：游戏本体 GDScript 8,664 行（14 个文件）"
     "+ AI 服务 Python 1,917 行（10 个文件）+ 自动化测试 2,423 行（6 个文件）。"
     "另有开发期构建/审计脚本 11,856 行不计入 |",
     "申报书 · 代码规模"),
    (MD / "10-申报书.md", "| **音频资产** | 377 个音频文件 |",
     "| **音频资产** | 189 个音频文件（148 个 wav + 41 个 ogg） |",
     "申报书 · 音频"),
    (MD / "10-申报书.md", "| 有效代码 | 12,910 行 |", "| 作品代码 | 13,004 行（含测试 2,423 行）|",
     "申报书 · 交付清单代码行"),
    (MD / "10-申报书.md", "| 音频 | 377 个 |", "| 音频 | 189 个 |", "申报书 · 交付清单音频"),
    (MD / "12-作品信息表.md",
     "| 有效代码 | 12,910 行（GDScript 8,143 行 + Python 4,767 行） |",
     "| 作品代码 | **13,004 行**（游戏本体 8,664 + AI 服务 1,917 + 自动化测试 2,423）|",
     "信息表 · 代码行"),
    (DK, "371 项断言证明它能跑", "388 项断言证明它能跑", "答辩稿 · 断言数标题"),
    (DK, "371 项断言", "388 项断言", "答辩稿 · 断言数正文"),
]


def main() -> None:
    changed = 0
    for path, old, new, what in JOBS:
        if not path.exists():
            print("  [缺] %s" % path.name)
            continue
        t = path.read_text(encoding="utf-8")
        if old not in t:
            if new in t:
                print("  %-24s 已是新值，跳过" % what)
            else:
                print("  %-24s ✗ 锚点没匹配上" % what)
            continue
        path.write_text(t.replace(old, new, 1), encoding="utf-8")
        back = path.read_text(encoding="utf-8")
        if new in back:
            changed += 1
            print("  %-24s ✓（已回读确认）" % what)
        else:
            print("  %-24s ✗ 回读没找到" % what)

    print("\n  复查残留：")
    for path in (MD / "10-申报书.md", MD / "12-作品信息表.md", DK):
        t = path.read_text(encoding="utf-8")
        bad = [s for s in ("12,910", "377 个", "371 项", "8,143", "4,767") if s in t]
        print("    %-22s %s" % (path.name, "残留 " + str(bad) if bad else "干净 ✓"))

    import py_compile
    py_compile.compile(str(DK), doraise=True)
    print("  build_deck.py 语法检查通过；共改 %d 处" % changed)


if __name__ == "__main__":
    main()
