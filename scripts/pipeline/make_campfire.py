#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
生成营火贴图（26x20，静态石圈+木柴；火苗是另一张动画帧带 fx_flame.png）。

为什么重做
    原来的 campfire_01.png **不是营火** —— 它是两个橙色色块夹一根白条，
    32x32 里 96% 是不透明像素、四条边全部贴边。这是本项目第五例
    「贴图名字与内容对不上」（前四例见 audit_sprites.py 的注释），
    而它之所以一直没被发现，是因为**之前没有任何脚本引用它** ——
    直到这一轮把 camp 从空区域改成有贴图的地标，它才第一次出现在画面上。

设计
    · 石圈：一圈大小不一的石子，不是标准圆（标准圆看着像零件不像营地）
    · 木柴：三根交叉的柴，中间压暗
    · 火光：木柴缝隙里点几粒余烬色（#C9704A），上面会叠动态火苗
    · 光源统一来自左上，与 ART_STYLE.md 一致
    · 颜色全部取自 34 色板

输出：assets/buildings/campfire_01.png（原图备份到 assets/_wip/_originals/）
用法：
    .venv\\Scripts\\python.exe scripts\\pipeline\\make_campfire.py
"""

from __future__ import annotations

import math
import random
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image  # noqa: E402

from postprocess import PALETTE_HEX  # noqa: E402

W, H = 26, 20
OUT = Path(__file__).resolve().parents[2] / "assets" / "buildings" / "campfire_01.png"
BACKUP = Path(__file__).resolve().parents[2] / "assets" / "_wip" / "_originals"

STONE_HI = "#A88E6B"
STONE_MID = "#8B6B47"
STONE_LOW = "#6B4F33"
LOG_MID = "#6B4F33"
LOG_HI = "#8B6B47"
EMBER = "#C9704A"
EMBER_HI = "#E0A43C"


def _rgb(h: str) -> tuple[int, int, int, int]:
    s = h.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)  # type: ignore[return-value]


def main() -> int:
    rng = random.Random(20261006)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()

    cx, cy = W / 2.0, H / 2.0 + 1.0

    # ── 石圈：椭圆上摆大小不一的石子 ──
    RX, RY = 10.5, 6.0
    n = 11
    for i in range(n):
        a = (i / float(n)) * math.tau + rng.uniform(-0.08, 0.08)
        sx = int(round(cx + math.cos(a) * RX + rng.uniform(-1.0, 1.0)))
        sy = int(round(cy + math.sin(a) * RY + rng.uniform(-0.8, 0.8)))
        w = rng.choice([2, 2, 3])
        h = rng.choice([2, 3])
        for dy in range(h):
            for dx in range(w):
                x, y = sx + dx, sy + dy
                if not (0 <= x < W and 0 <= y < H):
                    continue
                # 左上受光、右下压暗
                lit = (dx + dy) < (w + h) / 2.0 - 0.5
                px[x, y] = _rgb(STONE_HI if lit else STONE_LOW)
        # 石子在右下角投一小片影，镇住它
        if 0 <= sx + w < W and 0 <= sy + h < H:
            px[sx + w, sy + h] = _rgb(STONE_MID)

    # ── 木柴：三根交叉，长度和角度都不一样 ──
    LOGS = [(-6.5, 0.0, 6.5, 0.0), (-5.5, 2.2, 5.5, -1.4), (-4.0, -2.0, 4.5, 1.8)]
    for (x0, y0, x1, y1) in LOGS:
        steps = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
        for s in range(steps + 1):
            t = s / float(steps)
            x = int(round(cx + x0 + (x1 - x0) * t))
            y = int(round(cy + y0 + (y1 - y0) * t))
            for d in (0, 1):
                xx, yy = x + d, y
                if 0 <= xx < W and 0 <= yy < H:
                    # 上半受光
                    px[xx, yy] = _rgb(LOG_HI if d == 0 else LOG_MID)

    # ── 余烬：柴缝里的几点火色，火苗会叠在这上面 ──
    for _ in range(7):
        x = int(round(cx + rng.uniform(-3.2, 3.2)))
        y = int(round(cy + rng.uniform(-1.6, 1.6)))
        if 0 <= x < W and 0 <= y < H:
            px[x, y] = _rgb(EMBER_HI if rng.random() < 0.4 else EMBER)

    # ---- 合规检查 ----
    palette = {c.upper() for c in PALETTE_HEX}
    used = {f"#{r:02X}{g:02X}{b:02X}" for r, g, b, a in img.get_flattened_data() if a >= 128}
    off = used - palette
    if off:
        print(f"  [X] 用了色板外的颜色：{sorted(off)}")
        return 1
    opaque = sum(1 for *_c, a in img.get_flattened_data() if a >= 128)
    semi = sum(1 for *_c, a in img.get_flattened_data() if 0 < a < 128)
    ratio = opaque / float(W * H)
    print(f"  输出 {OUT.name}  {W}x{H}")
    print(f"  不透明 {opaque}/{W * H}（{ratio:.0%}）  半透明 {semi} 像素")
    print(f"  用色 {len(used)} 种，全部在色板内")
    if ratio > 0.75:
        print("  [X] 占比过高，营火应当有大量透明留白（是不是又画成整块了）")
        return 1

    BACKUP.mkdir(parents=True, exist_ok=True)
    if OUT.exists():
        shutil.copy2(OUT, BACKUP / "campfire_01.png.orig")
        print(f"  原图已备份 → {(BACKUP / 'campfire_01.png.orig').relative_to(OUT.parents[2])}")
    img.save(OUT)
    print("  已写入")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
