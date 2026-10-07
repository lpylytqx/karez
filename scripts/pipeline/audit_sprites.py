#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
贴图体检：系统性地找出「名字与内容对不上」的坏图。

为什么需要
    这个项目已经**五次**栽在同一类错误上，每次都是靠翻截图偶然发现的：
        tree_green_01 / tree_orange_01   其实是树冠的四分之一
        tree_pink_01 / tree_small_02     是完全空图（0% 不透明）
        grass_pebble_01                  其实是青蓝斑块
        gravel_01 / dirt_patch_01        其实是地形交界块
        reservoir_01                     其实是 UI 碎片（面板+滚动条+进度条+菱形）
        campfire_01                      其实是两个橙色块夹一根白条
    共同点：**画面能跑、不报错**，只是看着怪 —— 靠人眼一张张看太慢，也一定会漏。

检测规则（按**用途分档**）
    ⚠ 第一版不分档，340 张里报了 275 张，全是误报 ——
      地形块本来就该 100% 不透明、四边贴边，拿「贴边」去问它毫无意义。
      规则必须知道这张图**是干什么用的**才有意义。

    A 空图        不透明像素 = 0                  → 图是死的（两个 tree_* 就是这样）
    B 满幅方块    四边各 ≥90% 边长 且 占比 >92%    → 整块不透明的方块。
                                                   建筑/道具都该有透明留白，
                                                   出现这种基本就是 tileset 碎片或 UI 件
                                                   （reservoir_01 / campfire_01 都是）
    C 色数异常    色数 > 48（像素画应远低于此）    → 照片/插画误入像素素材目录

    地形块目录（terrain / farm / water）**只查 A** —— 它们满幅是设计如此。

⚠ 这是**可疑名单，不是判决**。最终仍要人眼确认，
   但它能把「要看的图」从几百张缩到个位数。

用法：
    .venv\\Scripts\\python.exe scripts\\pipeline\\audit_sprites.py
    .venv\\Scripts\\python.exe scripts\\pipeline\\audit_sprites.py --dirs buildings
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets"
# 立绘/事件插画是手绘、不走像素规范，不参与体检
EXCLUDE_PARTS = {"portraits", "events", "_raw", "_wip", "_reference", "_originals", "audio"}
# 这些子目录是「整块地形」，满幅不透明是设计如此，只查空图
TERRAIN_DIRS = {"terrain", "farm", "water"}
# 像素画目录：色数有上限
PIXEL_DIRS = {"tiles", "buildings", "fx", "ui"}


def edge_touch(px, w: int, h: int) -> dict[str, int]:
    """四条边各有几个不透明像素。"""
    out = {"top": 0, "bottom": 0, "left": 0, "right": 0}
    for x in range(w):
        if px[x, 0][3] >= 128:
            out["top"] += 1
        if px[x, h - 1][3] >= 128:
            out["bottom"] += 1
    for y in range(h):
        if px[0, y][3] >= 128:
            out["left"] += 1
        if px[w - 1, y][3] >= 128:
            out["right"] += 1
    return out


def main() -> int:
    args = sys.argv[1:]
    dirs = ["buildings", "tiles", "fx", "ui"]
    if "--dirs" in args:
        dirs = args[args.index("--dirs") + 1].split(",")

    suspects: list[tuple[str, str, str]] = []   # (相对路径, 规则, 细节)
    total = 0

    for sub in dirs:
        base = ASSETS / sub
        if not base.exists():
            continue
        for png in sorted(base.rglob("*.png")):
            if any(part in EXCLUDE_PARTS for part in png.parts):
                continue
            if png.name.startswith("."):
                continue
            try:
                im = Image.open(png).convert("RGBA")
            except Exception as exc:  # noqa: BLE001
                suspects.append((str(png.relative_to(ASSETS)), "打不开", str(exc)))
                continue
            total += 1
            w, h = im.size
            px = im.load()
            opaque = 0
            colors: set[tuple[int, int, int]] = set()
            for y in range(h):
                for x in range(w):
                    r, g, b, a = px[x, y]
                    if a >= 128:
                        opaque += 1
                        colors.add((r, g, b))
            rel = str(png.relative_to(ASSETS))

            # A：空图 —— 所有目录都查
            if opaque == 0:
                suspects.append((rel, "A 空图", "不透明像素 0，摆上去什么也没有"))
                continue

            # 地形块：只查 A（满幅是设计如此）
            if any(part in TERRAIN_DIRS for part in png.parts):
                continue

            ratio = opaque / float(w * h)
            e = edge_touch(px, w, h)
            all_edges = (e["top"] >= w * 0.9 and e["bottom"] >= w * 0.9
                         and e["left"] >= h * 0.9 and e["right"] >= h * 0.9)

            if all_edges and ratio > 0.92:
                suspects.append((rel, "B 满幅方块",
                                 f"四边各 >=90% 且占比 {ratio:.0%}"
                                 f"（建筑/道具都该有透明留白）"))
            elif sub in PIXEL_DIRS and len(colors) > 48:
                suspects.append((rel, "C 色数异常",
                                 f"{len(colors)} 色（像素画应 <48）"))

    print(f"  体检 {total} 张（目录：{','.join(dirs)}，已排除立绘/插画）")
    print(f"  地形块目录 {sorted(TERRAIN_DIRS)} 只查空图\n")
    if not suspects:
        print("  [OK] 没有可疑贴图。")
        return 0

    print(f"  [!] {len(suspects)} 张可疑 —— 只是**可疑名单，不是判决**：\n")
    for rel, rule, detail in suspects:
        print(f"    {rule:<12} {rel}")
        print(f"                 {detail}")
    print("\n  下一步：用 _preview_tiles.py 把这几张拼成接触表放大看，")
    print("          确认后再决定重画还是弃用。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
