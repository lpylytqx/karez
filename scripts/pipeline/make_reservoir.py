#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
生成涝坝（蓄水池）贴图，64x64。

背景：为什么必须重做
    原来的 reservoir_01.png **根本不是涝坝** —— 它是一张 UI 素材碎片：
    一个大圆角面板 + 一根竖滚动条 + 一根横进度条 + 一颗菱形，四块拼在一张 64x64 画布里。
    所以游戏里的涝坝看起来像个「蓝色浴缸」。

    这和之前查出的 tree_green_01「其实是树冠的四分之一」、grass_pebble_01
    「其实是青蓝斑块」是同一类错误：**贴图提取时挑错编号**。
    画面能跑、不报错，只是看着怪 —— 最容易被当成美术风格问题放过去。

为什么不交给 AI 生图
    试过了：本地 SDXL 出 1024x1024，再用最近邻降采样到 64x64 强制像素网格。
    网格确实出来了，但**细节在贴图尺寸下会塌成一团颜色涂抹**，
    而且它不遵守形制约束（prompt 里写明「平顶、不要瓦顶」，它照样画中式翘檐瓦顶）。
    地图贴图要的是 16px 网格精确、34 色板精确、形状可控 —— 这三件事过程化生成完胜。

设计要点
    · 涝坝是**生土蓄水池**，不是泳池：岸是夯土，边缘不规则，水面浑浊
    · 形状不取正圆/正矩，用带噪声的半径，才像人工挖出来的土坑
    · 留一个进水口缺口（明渠从那边引水）
    · 光源统一来自左上（与 ART_STYLE.md 一致）：左上岸亮、右下岸暗
    · 颜色全部取自 34 色板

输出：assets/buildings/reservoir_01.png（原图会备份到 assets/_wip/_originals/）
用法：
    .venv\\Scripts\\python.exe scripts\\pipeline\\make_reservoir.py
"""

from __future__ import annotations

import math
import random
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image  # noqa: E402

from postprocess import PALETTE_HEX  # noqa: E402  单一色源

SIZE = 64
OUT = Path(__file__).resolve().parents[2] / "assets" / "buildings" / "reservoir_01.png"
BACKUP = Path(__file__).resolve().parents[2] / "assets" / "_wip" / "_originals"

# 生土岸（亮 / 中 / 暗 / 极暗）—— 取自色板的生土与木质色系
BANK_HI = "#C9A277"
BANK_MID = "#9E7C55"
BANK_LOW = "#8B6B47"
BANK_DEEP = "#6B4F33"
# 水（亮 / 中 / 深 / 浑浊）—— 涝坝的水不清，用偏浊的一组
WATER_HI = "#8FC7D6"
WATER_MID = "#5A9CB0"
WATER_DEEP = "#3A7086"
WATER_MURK = "#7A8B78"


def _rgb(h: str) -> tuple[int, int, int, int]:
    s = h.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)  # type: ignore[return-value]


def main() -> int:
    rng = random.Random(20261006)

    cx = cy = (SIZE - 1) / 2.0
    # 岸的外半径：带 12 段噪声的椭圆，避免出现正圆
    N = 12
    outer_noise = [rng.uniform(-2.6, 2.6) for _ in range(N)]
    R_OUT_X, R_OUT_Y = 30.0, 27.0         # 略扁，更像蓄水池而不是圆坑
    R_WATER = 20.0                          # 水面半径
    R_INNER = R_WATER + 3.0                 # 岸内缘（水面到这里之间是湿泥）

    def outer_r(theta: float) -> float:
        """按角度取外半径（在噪声段之间线性插值，边缘才自然）。"""
        t = (theta % (2 * math.pi)) / (2 * math.pi) * N
        i0 = int(t) % N
        i1 = (i0 + 1) % N
        f = t - int(t)
        n = outer_noise[i0] * (1 - f) + outer_noise[i1] * f
        return 1.0 + n / R_OUT_X

    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    px = img.load()

    # 进水口方向：明渠从东边来（map_view 里涝坝往东引水），所以缺口开在东偏北
    INLET_ANGLE = math.radians(-18)
    INLET_HALF = math.radians(13)

    for y in range(SIZE):
        for x in range(SIZE):
            dx = x - cx
            dy = y - cy
            theta = math.atan2(dy, dx)
            # 归一化到椭圆坐标下的「相对半径」
            ex = dx / R_OUT_X
            ey = dy / R_OUT_Y
            d = math.sqrt(ex * ex + ey * ey)

            # 进水口缺口：把这个角度的岸「切掉」，露出通道
            da = abs((theta - INLET_ANGLE + math.pi) % (2 * math.pi) - math.pi)
            if da < INLET_HALF:
                if d > 0.62:      # 缺口处不放岸
                    continue

            r_out = outer_r(theta)
            water_r = R_WATER / R_OUT_X + rng.uniform(-0.035, 0.035)
            inner_r = R_INNER / R_OUT_X + rng.uniform(-0.02, 0.02)

            if d <= water_r:
                # ── 水面 ──
                depth = d / max(water_r, 1e-6)
                # 左上受光：用 (dx+dy) 判断哪边亮
                lit = (dx + dy) < 0
                if depth > 0.72:
                    px[x, y] = _rgb(WATER_DEEP)
                elif lit:
                    px[x, y] = _rgb(WATER_MID if depth > 0.30 else WATER_HI)
                else:
                    px[x, y] = _rgb(WATER_MURK if depth > 0.45 else WATER_MID)
            elif d <= inner_r:
                # ── 湿泥滩（水与岸之间）──
                px[x, y] = _rgb(BANK_LOW if (dx + dy) > 0 else BANK_MID)
            elif d <= r_out:
                # ── 生土岸：左上有高光，右下压暗 ──
                if (dx + dy) < -6:
                    px[x, y] = _rgb(BANK_HI)
                elif (dx + dy) < 4:
                    px[x, y] = _rgb(BANK_MID)
                else:
                    px[x, y] = _rgb(BANK_LOW)
            else:
                continue

    # ── 岸上的细节：几块石头与干草，别让岸是一圈纯色 ──
    for _ in range(9):
        ang = rng.uniform(0, 2 * math.pi)
        # 排除进水口那一带
        da = abs((ang - INLET_ANGLE + math.pi) % (2 * math.pi) - math.pi)
        if da < INLET_HALF + 0.25:
            continue
        rr = rng.uniform(R_WATER + 5, R_OUT_X - 2) / R_OUT_X
        x = int(cx + math.cos(ang) * rr * R_OUT_X)
        y = int(cy + math.sin(ang) * rr * R_OUT_Y)
        if 0 <= x < SIZE and 0 <= y < SIZE and px[x, y][3] > 0:
            col = BANK_HI if rng.random() < 0.5 else BANK_DEEP
            px[x, y] = _rgb(col)
            if rng.random() < 0.5 and x + 1 < SIZE:
                px[x + 1, y] = _rgb(BANK_DEEP if col == BANK_HI else BANK_LOW)

    # ── 水面高光：几道短横线，让水有波纹感而不是一块平板 ──
    for _ in range(5):
        ang = rng.uniform(0, 2 * math.pi)
        rr = rng.uniform(0.15, 0.62)
        x0 = int(cx + math.cos(ang) * rr * R_WATER)
        y0 = int(cy + math.sin(ang) * rr * R_WATER * 0.86)
        ln = rng.randint(2, 5)
        for i in range(ln):
            x, y = x0 + i, y0
            if 0 <= x < SIZE and 0 <= y < SIZE and px[x, y] == _rgb(WATER_MID):
                px[x, y] = _rgb(WATER_HI)

    # ---- 合规检查 ----
    palette = {c.upper() for c in PALETTE_HEX}
    used = {f"#{r:02X}{g:02X}{b:02X}" for r, g, b, a in img.get_flattened_data() if a >= 128}
    off = used - palette
    if off:
        print(f"  [X] 用了色板外的颜色：{sorted(off)}")
        return 1

    opaque = sum(1 for *_c, a in img.get_flattened_data() if a >= 128)
    semi = sum(1 for *_c, a in img.get_flattened_data() if 0 < a < 128)
    print(f"  输出 {OUT.name}  {SIZE}x{SIZE}")
    print(f"  不透明 {opaque}/{SIZE * SIZE} 像素（{opaque / (SIZE * SIZE):.0%}）")
    print(f"  半透明 {semi} 像素（应为 0，像素画不要抗锯齿边）")
    print(f"  用色 {len(used)} 种，全部在色板内")

    if len(used) < 6:
        print("  [!] 用色过少，形状可能没画出来")
    if opaque < SIZE * SIZE * 0.35:
        print("  [X] 不透明像素太少，形状可能是空的")
        return 1

    BACKUP.mkdir(parents=True, exist_ok=True)
    if OUT.exists():
        shutil.copy2(OUT, BACKUP / "reservoir_01.png.orig")
        print(f"  原图已备份 → {(BACKUP / 'reservoir_01.png.orig').relative_to(OUT.parents[2])}")
    img.save(OUT)
    print("  已写入")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
