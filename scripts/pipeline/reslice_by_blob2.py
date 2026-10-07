#!/usr/bin/env python -u
# -*- coding: utf-8 -*-
"""按连通域重裁建筑贴图（第二版，规则改对了）。

第一版失败的原因：我拿"边缘有没有内容"当验收标准 —— 但**连通域的外接矩形必然是
紧贴内容画的**，所以它的四条边必然都有内容。这个指标对紧贴裁剪毫无意义（对格线硬切
才有意义）。所以第一版一张都没通过，是**判据错了**，不是方法错。

这一版：不猜坐标，改成给每栋房子一个"**点在里面**"的格坐标（从网格图上读），
取包含该点的连通块，用它的外接矩形裁剪 —— 必然是完整的一栋，且必然不被切。
"""
from __future__ import annotations

import sys
from collections import deque
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import ROOT  # noqa: E402

from PIL import Image  # noqa: E402

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_buildings as MB  # noqa: E402

A = 8
T = 16

# 贴图 -> (格列, 格行)：这个点必须落在目标建筑身上（从 _网格_全图.png 读出来的）
PICK = {
    "inn_01.png":             (1, 1),    # 橙顶大屋（最左）
    "warehouse_01.png":       (5, 1),    # 米色大屋（第二栋）
    "stable_01.png":          (9, 1),    # 第三栋橙顶
    "grape_drying_01.png":    (13, 1),   # 红顶楼
    "workshop_01.png":        (17, 0),   # 蓝顶挂招牌（作坊）
    "shop_01.png":            (21, 1),   # **绿顶商店 —— 用户指出左边被切的那个**
    "house_resident_01.png":  (3, 9),    # 茅顶圆屋
    "watchtower_sand_01.png": (0, 9),    # 土坯墙段
}


def blobs(sheet: Image.Image):
    w, h = sheet.size
    px = sheet.load()
    lab = [[0] * w for _ in range(h)]
    out = []
    cid = 0
    for y0 in range(h):
        for x0 in range(w):
            if lab[y0][x0] or px[x0, y0][3] <= A:
                continue
            cid += 1
            q = deque([(x0, y0)])
            lab[y0][x0] = cid
            minx = maxx = x0
            miny = maxy = y0
            while q:
                x, y = q.popleft()
                minx = min(minx, x); maxx = max(maxx, x)
                miny = min(miny, y); maxy = max(maxy, y)
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and not lab[ny][nx] \
                            and px[nx, ny][3] > A:
                        lab[ny][nx] = cid
                        q.append((nx, ny))
            out.append((cid, minx, miny, maxx + 1, maxy + 1))
    return lab, out


def main() -> None:
    sheet = Image.open(MB.SRC).convert("RGBA")
    lab, bl = blobs(sheet)
    tag = {c: (x0, y0, x1, y1) for c, x0, y0, x1, y1 in bl}
    print("  大图 %s，连通块 %d 个" % (sheet.size, len(bl)))
    print()
    print("  %-26s %-14s %-12s %s" % ("贴图", "原尺寸", "新尺寸", "说明"))
    n = 0
    for name, (cx, cy) in PICK.items():
        dst = MB.BUILD / name
        if not dst.exists():
            print("  %-26s %s" % (name, "[不存在]"))
            continue
        px_, py_ = cx * T + T // 2, cy * T + T // 2
        cid = lab[py_][px_]
        if cid == 0 or cid not in tag:
            print("  %-26s 该格点是空的，跳过" % name)
            continue
        x0, y0, x1, y1 = tag[cid]
        crop = sheet.crop((x0, y0, x1, y1))
        old = Image.open(dst)
        crop.save(dst)
        n += 1
        print("  %-26s %-14s %-12s 格点(%d,%d) -> 块 (%d,%d)-(%d,%d)"
              % (name, "%dx%d" % old.size, "%dx%d" % crop.size, cx, cy, x0, y0, x1, y1))
    print("\n  重裁 %d 张" % n)


if __name__ == "__main__":
    main()
