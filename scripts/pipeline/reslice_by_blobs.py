#!/usr/bin/env python -u
# -*- coding: utf-8 -*-
"""按「连通域」重裁建筑贴图 —— 修左边被切掉的问题。

为什么不再用坐标表：`make_buildings.py` 的 `(列,行,宽格,高格)` 是**硬切在 16px 格线**上，
一栋房子实际跨到格子中间时就被切了。用户指出的绿顶商店 `shop_01.png` 左边 63/64 行有内容，
就是这么来的。靠眼睛对着网格图标坐标，慢且容易错。

改成机械办法：
  1. 在素材大图上做**连通域标记**（4 邻接，alpha>8 的像素算前景）
  2. 每个连通块就是**一栋完整的建筑**（大图里建筑之间有透明缝，所以能被分开）
  3. 取连通块的**外接矩形**当裁剪框 —— 必然不切边
  4. 把每张现有贴图与"各连通块的外接矩形裁剪"做匹配（缩到同一尺寸比像素差），
     取最像的那个覆盖过去；匹配太差的（说明该贴图本来就不是从这张大图来的）不动

这样是**可验证**的：跑完再用"边缘是否有内容"复检一次，切边数应当降到 0。
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
MIN_AREA = 600      # 小于这个面积的连通块当碎图块，不当建筑


def label(sheet: Image.Image) -> tuple[list[list[int]], list[tuple[int, int, int, int, int]]]:
    """4 邻接连通域标记。返回 (标签图, [(面积, x0, y0, x1, y1)])。"""
    w, h = sheet.size
    px = sheet.load()
    lab = [[0] * w for _ in range(h)]
    comps: list[tuple[int, int, int, int, int]] = []
    cid = 0
    for y0 in range(h):
        for x0 in range(w):
            if lab[y0][x0] or px[x0, y0][3] <= A:
                continue
            cid += 1
            q = deque([(x0, y0)])
            lab[y0][x0] = cid
            n = 0
            minx = maxx = x0
            miny = maxy = y0
            while q:
                x, y = q.popleft()
                n += 1
                minx = min(minx, x); maxx = max(maxx, x)
                miny = min(miny, y); maxy = max(maxy, y)
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and not lab[ny][nx] \
                            and px[nx, ny][3] > A:
                        lab[ny][nx] = cid
                        q.append((nx, ny))
            comps.append((n, minx, miny, maxx + 1, maxy + 1))
    return lab, comps


def edges(im: Image.Image) -> int:
    w, h = im.size
    px = im.load()
    return (sum(1 for y in range(h) if px[0, y][3] > A)
            + sum(1 for y in range(h) if px[w - 1, y][3] > A)
            + sum(1 for x in range(w) if px[x, 0][3] > A)
            + sum(1 for x in range(w) if px[x, h - 1][3] > A))


def trim(im: Image.Image) -> Image.Image:
    bb = im.getbbox()
    return im.crop(bb) if bb else im


def diff(a: Image.Image, b: Image.Image) -> float:
    """两张图缩到 40x40 后的平均像素差（越小越像）。"""
    S = 40
    pa = trim(a).convert("RGBA").resize((S, S), Image.LANCZOS)
    pb = trim(b).convert("RGBA").resize((S, S), Image.LANCZOS)
    da, db = pa.load(), pb.load()
    tot = 0
    for y in range(S):
        for x in range(S):
            tot += abs(da[x, y][0] - db[x, y][0]) + abs(da[x, y][1] - db[x, y][1]) \
                + abs(da[x, y][2] - db[x, y][2]) + abs(da[x, y][3] - db[x, y][3])
    return tot / (S * S * 4)


def main() -> None:
    sheet = Image.open(MB.SRC).convert("RGBA")
    _, comps = label(sheet)
    big = [c for c in comps if c[0] >= MIN_AREA]
    print("  大图 %s：连通块 %d 个，其中面积≥%d 的 %d 个（当建筑候选）"
          % (sheet.size, len(comps), MIN_AREA, len(big)))

    boxes = []
    for area, x0, y0, x1, y1 in big:
        w, h = x1 - x0, y1 - y0
        if w >= 24 and h >= 24:            # 建筑至少 1.5 格
            boxes.append((area, x0, y0, x1, y1))
    print("  其中 %d 个尺寸够格当建筑\n" % len(boxes))

    fixed, kept, poor = [], [], []
    for p in sorted(MB.BUILD.glob("*.png")):
        cur = Image.open(p).convert("RGBA")
        e0 = edges(cur)
        if e0 == 0:
            kept.append(p.name)
            continue
        best, bd = None, 1e9
        for area, x0, y0, x1, y1 in boxes:
            cand = sheet.crop((x0, y0, x1, y1))
            dd = diff(cur, cand)
            if dd < bd:
                bd, best = dd, cand
        if best is None or bd > 26:
            poor.append((p.name, e0, round(bd, 1)))
            continue
        e1 = edges(best)
        if e1 == 0 and best.size != cur.size:
            best.save(p)
            fixed.append((p.name, e0, best.size))
        else:
            poor.append((p.name, e0, round(bd, 1)))
    print("  修好（切边 → 0）%d 张：" % len(fixed))
    for n, e0, sz in fixed:
        print("    %-26s 原切边 %-4d -> %s  边0" % (n, e0, sz))
    print("\n  本来就干净 %d 张" % len(kept))
    print("  没把握（未动）%d 张：" % len(poor))
    for n, e0, bd in poor[:14]:
        print("    %-26s 切边 %-4d 匹配差 %.1f" % (n, e0, bd))


if __name__ == "__main__":
    main()
