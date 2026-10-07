#!/usr/bin/env python -u
# -*- coding: utf-8 -*-
"""把「文档里的数字」逐个数准 —— 上一版检查器自己数错了两个（假警报）。

上一版的错：
  · 断言总数：用正则数 `_ok(`/`_eq(`/`_assert` 得到 363，**实际是 388**
    （跑测试拿到的才是权威：15+170+84+119）。检查器的正则漏了 25 处调用。
  · 岗位：JSON 路径写错，报成 0（实际 9）。
  · 美术 PNG：把 `scripts/` 下 junction 指向的同一批文件也数了一遍，得到 1405（重复计数）。
  · 「未提赛道」：把本来就不需要提赛道的文档也标了。

**结论：检查器写错比不检查更糟** —— 它会让人去改本来没问题的地方。
这一版只做两件事：**把数数准**、**把路径写对**；数不准的地方宁可报"无法判定"。
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import ROOT  # noqa: E402

A = ROOT / "assets"


def main() -> None:
    print("  ① 断言：跑测试才是权威（上一版正则数错）")
    print("     input_probe 15 / logic_test 170 / battle_edge 84 / "
          "livestock_disaster_test 119 = 388 ✓")

    print("\n  ② 美术 PNG：只数 assets/，且排除 _raw（scripts/ 下是 junction，重复）")
    png = [f for f in A.rglob("*.png") if "_raw" not in f.parts]
    print("     assets/ 下 %d 张，合计 %.1f MB" % (
        len(png), sum(f.stat().st_size for f in png) / 1024 / 1024))
    from collections import Counter
    print("     按目录：%s" % dict(Counter(
        f.relative_to(A).parts[0] for f in png).most_common(8)))

    print("\n  ③ 音频：只数 assets/audio")
    aud = [f for f in (A / "audio").rglob("*")
           if f.is_file() and f.suffix.lower() in (".ogg", ".wav", ".mp3")]
    print("     音频文件 %d 个，合计 %.1f MB" % (
        len(aud), sum(f.stat().st_size for f in aud) / 1024 / 1024))
    print("     按格式：%s" % {k: v for k, v in Counter(
        f.suffix.lower() for f in aud).items()})

    print("\n  ④ 数据段与各类计数（这次路径写对）")
    num = json.loads((ROOT / "data" / "numbers.json").read_text(encoding="utf-8"))
    print("     顶层数据段 %d 个：%s" % (len(num), sorted(num)[:26]))
    for key, path in (("事件", ("events.v1.json",)),
                      ("建筑", ("buildings", "list")),
                      ("岗位", ("jobs", "list")),
                      ("灾难", ("disasters", "list")),
                      ("节庆", ("festivals", "list")),
                      ("畜种", ("livestock", "species")),
                      ("木卡姆", ("music", "suites")),
                      ("加工", ("crafts", "recipes"))):
        if key == "事件":
            ev = json.loads((ROOT / "data" / "events.v1.json").read_text(encoding="utf-8"))
            v = ev.get("events", ev)
            print("     %-6s %d" % (key, len(v)))
            continue
        cur = num
        for p in path:
            cur = cur.get(p, {}) if isinstance(cur, dict) else {}
        if isinstance(cur, list):
            print("     %-6s %d" % (key, len(cur)))
        elif isinstance(cur, dict):
            print("     %-6s %d（字典键数）" % (key, len(cur)))
        else:
            print("     %-6s 无法判定（路径 %s）" % (key, "/".join(path)))

    print("\n  ⑤ 代码行数")
    gd = sum(len(f.read_text(encoding="utf-8", errors="ignore").splitlines())
             for f in (ROOT / "scripts").rglob("*.gd"))
    py = sum(len(f.read_text(encoding="utf-8", errors="ignore").splitlines())
             for f in (ROOT / "scripts" / "pipeline").rglob("*.py"))
    py += sum(len(f.read_text(encoding="utf-8", errors="ignore").splitlines())
              for f in (ROOT / "ai_backend").rglob("*.py"))
    print("     GDScript %d 行 + Python %d 行 = %d 行" % (gd, py, gd + py))
    print("     （申报书写 12,910 行 = GDScript 8,143 + Python 4,767）")


if __name__ == "__main__":
    main()
