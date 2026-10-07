#!/usr/bin/env python -u
# -*- coding: utf-8 -*-
"""终检第三轮：修剩下两处真问题 + 一处检查器错误。

真问题：
  · build_showcase.py L380 数字一览写「12,910 行有效代码」「419 张美术资产」
    → 13,004 / 421（合并稿里那个 12,910 就是从这来的 —— 上轮我只改了答辩稿）

检查器错误（第二轮我自己写错的）：
  · 美术张数：排除了 `_wip` 却**忘了 `_raw`**（Kenney 原始素材库上千张）→ 421 被算成 2988
  · 岗位：`numbers.json` **没有 `jobs` 顶层键**，实际在 `population.jobs` 下
  · 断言：继续引用**跑测试的输出**，不用正则统计
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import ROOT  # noqa: E402

SH = ROOT / "scripts" / "pipeline" / "build_showcase.py"


def show_jobs() -> None:
    n = json.loads((ROOT / "data" / "numbers.json").read_text(encoding="utf-8"))
    j = n["population"]["jobs"]
    print("  population.jobs 结构：%s" % list(j))
    for k, v in j.items():
        if isinstance(v, (list, dict)):
            print("    %-14s %s(%d) %s" % (k, type(v).__name__, len(v),
                                           (list(v)[:10] if isinstance(v, dict)
                                            else v[:6])))
        else:
            print("    %-14s %s" % (k, v))


def fix_showcase() -> None:
    t = SH.read_text(encoding="utf-8")
    old = '''    stats = [("12,910", "行有效代码"), ("64", "条事件"),
             ("13", "座建筑"), ("419", "张美术资产")]'''
    new = '''    stats = [("13,004", "行作品代码"), ("64", "条事件"),
             ("13", "座建筑"), ("421", "张美术资产")]'''
    if old in t:
        SH.write_text(t.replace(old, new, 1), encoding="utf-8")
        back = SH.read_text(encoding="utf-8")
        print("  展示稿数字一览 -> 13,004 / 421，回读：%s"
              % ("✓" if "13,004" in back else "✗"))
    elif new in t:
        print("  展示稿已是新值")
    else:
        print("  [X] 展示稿锚点没匹配上")
        return
    import py_compile
    py_compile.compile(str(SH), doraise=True)
    print("  语法检查通过")


def fix_audit() -> None:
    A = ROOT / "scripts" / "pipeline" / "audit_v2.py"
    t = A.read_text(encoding="utf-8")
    n = 0
    pairs = [
        ('png = [f for f in A.rglob("*.png") if "_wip" not in f.parts]',
         'png = [f for f in A.rglob("*.png")\n           if "_wip" not in f.parts and "_raw" not in f.parts]'),
        ('return {"美术": len(png), "音频": len(aud), "岗位": len(num.get("jobs", {}))}',
         'jobs = num.get("population", {}).get("jobs", {})\n'
         '    jn = len(jobs.get("list", jobs)) if isinstance(jobs, dict) else 0\n'
         '    return {"美术": len(png), "音频": len(aud), "岗位": jn}'),
    ]
    for old, new in pairs:
        if old in t:
            t = t.replace(old, new, 1)
            n += 1
    A.write_text(t, encoding="utf-8")
    import py_compile
    py_compile.compile(str(A), doraise=True)
    print("  检查器修 %d 处（排除 _raw + 岗位路径），语法检查通过" % n)


if __name__ == "__main__":
    print("  ① population.jobs 结构：")
    show_jobs()
    print("\n  ② 修展示稿数字：")
    fix_showcase()
    print("\n  ③ 修检查器：")
    fix_audit()
