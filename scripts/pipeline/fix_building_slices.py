#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""修被切掉的建筑贴图：向外扩边，直到边缘干净。

问题（用户指出）：房子的**左边被切掉**。
根因：make_buildings.py 的 PLAN 用 `(列, 行, 宽格, 高格)` **硬切在格线边界**上，
一栋房子实际比计划宽一格时，多出来的那格就留在画布外 —— 表现为一条边
（多为左边）有内容顶到边界。实测 35 张建筑贴图里 26 张有边缘接触。

做法：对每张图在**源大图**上试扩边
  · 哪条边有内容顶边，就往那个方向扩 1 格，重裁
  · **只有扩完那条边变干净了才接受**，否则回退（防止把隔壁房子拉进来）
  · 最多扩 4 格
最后用同一个判据复查，并打印前后对比。

用法：.venv\\Scripts\\python.exe scripts\\pipeline\\fix_building_slices.py
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import ROOT  # noqa: E402

from PIL import Image  # noqa: E402

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_buildings as MB  # noqa: E402  复用 SRC / BUILD / T / PLAN

T = MB.T
A = 8          # alpha 阈值
MAX_GROW = 4   # 每个方向最多扩几格


def edges(im: Image.Image) -> dict[str, int]:
    w, h = im.size
    px = im.load()
    return {
        "L": sum(1 for y in range(h) if px[0, y][3] > A),
        "R": sum(1 for y in range(h) if px[w - 1, y][3] > A),
        "T": sum(1 for x in range(w) if px[x, 0][3] > A),
        "B": sum(1 for x in range(w) if px[x, h - 1][3] > A),
    }


def main() -> None:
    sheet = Image.open(MB.SRC).convert("RGBA")
    print("  源 %s = %s" % (MB.SRC.name, sheet.size))
    print("  %-26s %-22s %s" % ("文件", "扩边前(L/R/T/B)", "扩边后 / 结果"))
    fixed = 0
    for name, cx, cy, cw, chh in [(p[0], p[1], p[2], p[3], p[4]) for p in MB.PLAN]:
        dst = MB.BUILD / name
        if not dst.exists():
            continue
        old = Image.open(dst).convert("RGBA")
        e0 = edges(old)
        box = [cx * T, cy * T, (cx + cw) * T, (cy + chh) * T]
        grew = []
        for side in ("L", "T", "R", "B"):
            for _ in range(MAX_GROW):
                cur = sheet.crop(tuple(box))
                if edges(cur)[side] == 0:
                    break
                nb = list(box)
                if side == "L" and nb[0] - T >= 0:
                    nb[0] -= T
                elif side == "T" and nb[1] - T >= 0:
                    nb[1] -= T
                elif side == "R" and nb[2] + T <= sheet.width:
                    nb[2] += T
                elif side == "B" and nb[3] + T <= sheet.height:
                    nb[3] += T
                else:
                    break
                cand = sheet.crop(tuple(nb))
                # 只接受"这条边变干净"的扩张，否则回退（免得把隔壁房子拉进来）
                if edges(cand)[side] < edges(cur)[side]:
                    box = nb
                    grew.append(side)
                else:
                    break
        out = sheet.crop(tuple(box))
        e1 = edges(out)
        if grew and sum(e1.values()) < sum(e0.values()):
            if out.size != old.size:
                out = out.resize(old.size, Image.NEAREST)
                # 扩边后按原尺寸回缩会再引入切边，所以尺寸变了就不缩
                out = sheet.crop(tuple(box))
            out.save(dst)
            fixed += 1
            print("  %-26s %-22s %s  扩了%s" % (
                name, "%d/%d/%d/%d" % (e0["L"], e0["R"], e0["T"], e0["B"]),
                "%d/%d/%d/%d" % (e1["L"], e1["R"], e1["T"], e1["B"]),
                "".join(grew)))
        else:
            print("  %-26s %-22s %s" % (
                name, "%d/%d/%d/%d" % (e0["L"], e0["R"], e0["T"], e0["B"]), "无法改善"))
    print("\n  修好 %d 张。剩下的需要对着网格图手工定坐标。" % fixed)


if __name__ == "__main__":
    main()
