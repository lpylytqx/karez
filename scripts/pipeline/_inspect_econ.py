#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""打印 numbers.json 里与经济/物产/节庆相关的结构，供补内容前定位。"""
import sys as _sys
from pathlib import Path as _Path
_sys.path.insert(0, str(_Path(__file__).resolve().parent))
from _root import ROOT  # 路径唯一解析处，不再写死盘符
import json
from pathlib import Path

d = json.loads((ROOT / "data" / "numbers.json").read_text(encoding="utf-8"))

print("=== economy ===")
e = d["economy"]
for k in e:
    s = json.dumps(e[k], ensure_ascii=False)
    print(f"  {k}: {s[:420]}")
print()
print("=== foods（resources.food.items）===")
for k, v in d["resources"]["food"]["items"].items():
    print(f"  {k:<10} {json.dumps(v, ensure_ascii=False)}")
print()
print("=== materials.items ===")
for k, v in d["resources"]["materials"]["items"].items():
    print(f"  {k:<10} {json.dumps(v, ensure_ascii=False)}")
print()
print("=== 晾房 grain/drying 相关 ===")
for b in d["buildings"]["list"]:
    if b["id"] == "liangfang":
        print(" ", json.dumps(b, ensure_ascii=False))
print()
print("=== calendar（节庆可挂的地方）===")
print(" ", json.dumps(d["calendar"], ensure_ascii=False)[:700])
print()
print("=== 是否已有节庆/货物表 ===")
for k in d:
    if k in ("festivals", "goods", "crafts", "music"):
        print(f"  已存在: {k}")
print("  顶层键:", list(d.keys()))
