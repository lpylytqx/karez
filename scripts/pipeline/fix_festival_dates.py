#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""修一个「永远触发不了」的节日：古尔邦节写在秋季第 40 天，但每季只有 30 天。

代码里 `in_season = ((day - 1) % 30) + 1` 算出来永远是 1..30，
所以 `day=40` 的节日**一次都不会触发** —— 而它看起来完全正常：
数据合法、代码不报错、测试也不失败，只是那个节日静悄悄地不存在。

这正是「数据驱动系统最典型的静默失效」。所以顺手加一条静态自检：
所有节日的 day 必须落在 1..days_per_season 之内。
"""
import sys as _sys
from pathlib import Path as _Path
_sys.path.insert(0, str(_Path(__file__).resolve().parent))
from _root import ROOT  # 路径唯一解析处，不再写死盘符
import json
from pathlib import Path

P = ROOT / "data" / "numbers.json"
d = json.loads(P.read_text(encoding="utf-8"))
per = int(d["calendar"]["days_per_season"])

fixed = []
for f in d["festivals"]["list"]:
    if not (1 <= int(f["day"]) <= per):
        old = f["day"]
        # 贴近季末但不越界：季末是收获/团聚的时节，古尔邦节放这里比放月初更顺
        f["day"] = per - 5
        f["note"] = "原写 day=%s，但每季只有 %d 天，永远触发不了；改成 %d。" % (old, per, f["day"])
        fixed.append((f["id"], old, f["day"]))

d["festivals"]["note"] = (
    d["festivals"]["note"]
    + "  ⚠ day 是**季内第几天**（1..%d），写成 40 这种超界值不会报错，"
      "但那个节日永远不会触发 —— verify 里有一条静态自检守着它。" % per
)

P.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

chk = json.loads(P.read_text(encoding="utf-8"))
for fid, old, new in fixed:
    print("  已修：%s 第 %s 天 -> 第 %s 天" % (fid, old, new))
print("  节庆表：")
for f in chk["festivals"]["list"]:
    ok = "OK " if 1 <= int(f["day"]) <= per else "越界"
    print("    [%s] %-10s %-8s %s 第 %d 天" % (ok, f["id"], f["display"], f["season"], f["day"]))
