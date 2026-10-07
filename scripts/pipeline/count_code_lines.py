#!/usr/bin/env python -u
# -*- coding: utf-8 -*-
"""把"代码行数"按可辩护的口径数准。

为什么不能直接 rglob：那会把我这几周写的**打包/审计/截图/重构脚本**也数进去，
真实数字会虚高一倍。评审若去数 `scripts/*.gd` 会得到不同的数 —— 数字必须**能被复核**。

口径（写进文档时也要写清楚）：
  · 作品代码 = 游戏本体（scripts 下的 .gd，**排除** tests/ 与 capture_*/diag_* 工具场景）
             + AI 服务（ai_backend 下的 .py）
  · **不含**开发期工具（scripts/pipeline/ 的构建与审计脚本）
  · **不含**测试代码（scripts/tests/）
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import ROOT  # noqa: E402

S = ROOT / "scripts"


def lines(p: Path) -> int:
    return len(p.read_text(encoding="utf-8", errors="ignore").splitlines())


def bucket(name, files):
    n = sum(lines(f) for f in files)
    print("    %-22s %3d 个文件  %6d 行" % (name, len(files), n))
    return n


def main() -> None:
    print("  游戏代码（GDScript）：")
    gd_all = list(S.rglob("*.gd"))
    gd_test = [f for f in gd_all if "tests" in f.parts]
    gd_tool = [f for f in gd_all if re_capture(f)]
    gd_game = [f for f in gd_all if f not in gd_test and f not in gd_tool]
    a = bucket("游戏本体", gd_game)
    b = bucket("测试代码（不计）", gd_test)
    c = bucket("截图/诊断工具（不计）", gd_tool)

    print("\n  AI 服务（Python）：")
    be = list((ROOT / "ai_backend").rglob("*.py"))
    d = bucket("ai_backend", be)

    print("\n  开发期工具（不计）：")
    pl = list((S / "pipeline").rglob("*.py"))
    e = bucket("scripts/pipeline", pl)

    print("\n  ─────────────────────────────────────────────")
    print("  **作品代码 = %d 行**（GDScript %d + Python %d）" % (a + d, a, d))
    print("  另有：测试 %d 行、开发工具 %d 行（不计入作品代码）" % (b, e))
    print("\n  文档现在写的是：12,910 行（GDScript 8,143 + Python 4,767）")


def re_capture(f: Path) -> bool:
    n = f.name
    return n.startswith("capture_") or n.startswith("diag_")


if __name__ == "__main__":
    main()
