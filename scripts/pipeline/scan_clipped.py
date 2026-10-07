#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""扫描素材：哪些贴图的**内容被画布边缘切断了**。

判据（可机械判定）：图像四边有不透明像素 => 内容顶到边 => 多半是被裁断的。
另外顺带量"贴边像素占整图不透明像素的比例"和"贴边那一条占该边的比例"，
用来区分"故意画到边的地面贴图"和"真的被切掉一半的物件"。

为什么要区分：
  · 地形/水面底纹本来就该铺满到边（sand_base / water_*）—— 贴边是正常的
  · 而树、建筑、动物、角色这类**独立物件**贴边就是被裁断了

用法：.venv\\Scripts\\python.exe scripts\\pipeline\\scan_clipped.py
"""
from __future__ import annotations

import sys as _sys
from pathlib import Path as _Path
_sys.path.insert(0, str(_Path(__file__).resolve().parent))
from _root import ROOT  # 路径唯一解析处，不再写死盘符
import json
from pathlib import Path

from PIL import Image

R = ROOT
ROOTS = ["assets/tiles", "assets/buildings", "assets/characters", "assets/fx", "assets/ui"]
# 这些目录天然铺满到边，不算被裁
TILEY = ("terrain", "water", "farmland", "farm")

rows: list[dict] = []
for root in ROOTS:
    base = R / root
    if not base.exists():
        continue
    for p in sorted(base.rglob("*.png")):
        rel = str(p.relative_to(R)).replace("\\", "/")
        if any(("/%s/" % t) in rel for t in TILEY):
            continue
        if "_wip" in rel or "_reference" in rel or "/_raw/" in rel or "/output/" in rel:
            continue
        try:
            im = Image.open(p).convert("RGBA")
        except Exception:
            continue
        w, h = im.size
        a = im.getchannel("A")
        px = a.load()
        opaque = sum(1 for y in range(h) for x in range(w) if px[x, y] > 8)
        if opaque == 0:
            rows.append({"file": rel, "why": "全透明（空图）", "size": f"{w}x{h}", "edge": 1.0})
            continue
        edges = {
            "top": sum(1 for x in range(w) if px[x, 0] > 8),
            "bottom": sum(1 for x in range(w) if px[x, h - 1] > 8),
            "left": sum(1 for y in range(h) if px[0, y] > 8),
            "right": sum(1 for y in range(h) if px[w - 1, y] > 8),
        }
        hit = {k: v for k, v in edges.items() if v > 0}
        if not hit:
            continue
        # 该边被占的比例（占这条边的长度）
        worst = max((v / (w if k in ("top", "bottom") else h)) for k, v in hit.items())
        edge_px = sum(hit.values())
        rows.append({"file": rel, "size": f"{w}x{h}", "edges": hit,
                     "edge_ratio": round(edge_px / max(1, opaque), 3),
                     "worst_side": round(worst, 3)})

rows.sort(key=lambda r: (-r.get("worst_side", 0), -r.get("edge_ratio", 0)))
print("=== 内容贴到画布边缘的素材（共 %d 个，已排除地形/水底纹）===" % len(rows))
print("  %-46s %-9s %-28s %s" % ("文件", "尺寸", "贴哪几条边(像素)", "最宽边占比"))
for r in rows[:28]:
    if r.get("why"):
        print("  %-46s %-9s %s" % (r["file"], r["size"], r["why"]))
    else:
        e = " ".join("%s%d" % (k[0].upper(), v) for k, v in r["edges"].items())
        print("  %-46s %-9s %-28s %.0f%%" % (r["file"], r["size"], e, r["worst_side"] * 100))

(R / "logs" / "scan_clipped.json").write_text(
    json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8")
print("\n  完整清单：logs/scan_clipped.json")
