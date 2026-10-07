#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""清点《坎儿井》的实际实现规模，供申报书/PPT 引用。

为什么要单独跑一遍：设计大纲（GDD）是**纲领**，写的是目标；
申报书要写的是**已实现的事实**。两者混着写，评审一验证就露馅。
所以这里全部从代码与数据里数出来，不引用任何文档里的说法。
"""
from __future__ import annotations

import sys as _sys
from pathlib import Path as _Path
_sys.path.insert(0, str(_Path(__file__).resolve().parent))
from _root import ROOT  # 路径唯一解析处，不再写死盘符
import glob
import json
import re
from pathlib import Path

R = ROOT
d = json.loads((R / "data" / "numbers.json").read_text(encoding="utf-8"))
ev = json.loads((R / "data" / "events.v1.json").read_text(encoding="utf-8"))

# ---- 代码规模 ----
gd = sorted((R / "scripts").rglob("*.gd"))
gd_lines = sum(len(p.read_text(encoding="utf-8").splitlines()) for p in gd)
py = sorted((R / "ai_backend").glob("*.py")) + sorted((R / "scripts/pipeline").glob("*.py"))
py_lines = sum(len(p.read_text(encoding="utf-8", errors="ignore").splitlines()) for p in py)
gd_code = sum(1 for p in gd for ln in p.read_text(encoding="utf-8").splitlines()
              if ln.strip() and not ln.strip().startswith("#"))
py_code = sum(1 for p in py for ln in p.read_text(encoding="utf-8", errors="ignore").splitlines()
              if ln.strip() and not ln.strip().startswith("#"))

print("=== 代码规模（真实统计）===")
print(f"  GDScript：{len(gd)} 个文件 / {gd_lines} 行（去注释空行 {gd_code} 行）")
print(f"  Python  ：{len(py)} 个文件 / {py_lines} 行（去注释空行 {py_code} 行）")
print(f"  合计代码行（去注释空行）：{gd_code + py_code}")

# ---- 系统规模 ----
print()
print("=== 系统规模 ===")
foods = d["resources"]["food"]["items"]
print(f"  坎儿井：{len(d['karez'].get('sections', []))} 段竖井 + 涝坝 {len(d['karez'].get('reservoir', {}).get('levels', []))} 级扩容")
print(f"  岗位  ：{len([j for j in d['population']['jobs']['list']])} 个 —— "
      + "、".join(j["display"] for j in d["population"]["jobs"]["list"]))
print(f"  建筑  ：{len(d['buildings']['list'])} 座 —— "
      + "、".join(b["display"] for b in d["buildings"]["list"]))
print(f"  食物  ：{len(foods)} 类 —— " + "、".join(v["display"] for v in foods.values()))
print(f"  材料  ：{len(d['resources']['materials']['items'])} 类")
print(f"  牲畜  ：{len(d['livestock']['species'])} 个品种 —— "
      + "、".join(v["display"] for v in d["livestock"]["species"].values()))
print(f"  野畜  ：{len(d['livestock']['wild'])} 种 —— "
      + "、".join(v["display"] for v in d["livestock"]["wild"].values()))
print(f"  加工  ：{len(d['crafts']['recipes'])} 条配方 —— "
      + "、".join(r["display"] for r in d["crafts"]["recipes"]))
print(f"  灾难  ：{len(d['disasters']['list'])} 种 —— "
      + "、".join(c["display"] for c in d["disasters"]["list"]))
print(f"  节庆  ：{len(d['festivals']['list'])} 个 —— "
      + "、".join(f["display"] for f in d["festivals"]["list"]))
print(f"  木卡姆：{len(d['music']['suites'])} 套 —— "
      + "、".join(s["display"] for s in d["music"]["suites"]))
print(f"  战斗  ：兵种 {len(d['battle']['troops']['list'])} 种 —— "
      + "、".join(v["display"] for v in d["battle"]["troops"]["list"].values()))
print(f"  探索点：{len(d['exploration'].get('routes', d['exploration'].get('destinations', [])))} 处"
      if isinstance(d["exploration"].get("routes", d["exploration"].get("destinations")), list)
      else f"  探索  ：{list(d['exploration'].keys())}")

# ---- 事件库 ----
if isinstance(ev, dict) and "events" in ev:
    evs = ev["events"]
else:
    evs = ev if isinstance(ev, list) else []
cats: dict[str, int] = {}
for e in evs:
    cats[str(e.get("category", "?"))] = cats.get(str(e.get("category", "?")), 0) + 1
print()
print("=== 内容库 ===")
print(f"  事件  ：{len(evs)} 条，分类 " + "、".join(f"{k}{v}" for k, v in cats.items()))

# ---- 美术与音频 ----
png = list((R / "assets").rglob("*.png"))
png = [p for p in png if "_wip" not in str(p) and "_reference" not in str(p) and "_raw" not in str(p)]
ogg = list((R / "assets").rglob("*.ogg")) + list((R / "assets").rglob("*.wav"))
size = sum(p.stat().st_size for p in png) / 1024 / 1024
print(f"  美术  ：{len(png)} 张 PNG / {size:.1f} MB")
print(f"  音频  ：{len(ogg)} 个音频文件")
pal = re.search(r"PALETTE_HEX\s*=\s*\[(.*?)\]", (R / "scripts/pipeline/postprocess.py").read_text(encoding="utf-8"), re.S)
print(f"  色板  ：{len(re.findall(r'#[0-9A-Fa-f]{6}', pal.group(1)))} 色（全项目统一）")

# ---- 测试规模 ----
print()
print("=== 测试规模 ===")
for t in sorted((R / "scripts/tests").glob("*.gd")):
    txt = t.read_text(encoding="utf-8")
    n = len(re.findall(r"_ok\(", txt))
    print(f"  {t.name:<28} 断言 {n} 条")
print(f"  verify.py 检查项：{len(re.findall(r'check\(', (R/'ai_backend/verify.py').read_text(encoding='utf-8')))}")

# ---- 角色 ----
cj = R / "data/characters.json"
if cj.exists():
    cd = json.loads(cj.read_text(encoding="utf-8"))
    chs = cd.get("characters", cd) if isinstance(cd, dict) else cd
    print()
    print("=== AI 角色 ===")
    if isinstance(chs, list):
        for c in chs:
            print(f"  {c.get('id',''):<20} {c.get('display', c.get('name',''))}")
    else:
        print("  ", list(chs.keys())[:12])
