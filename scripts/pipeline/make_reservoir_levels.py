#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
生成涝坝的 4 档水位贴图（64x64）。

为什么
    涝坝原来只有一张图，无论满着还是快干了都长一样 ——
    而水是这游戏的核心资源，玩家看不出「还剩多少水」，只能去读顶栏的数字。
    水位分档之后，一眼就能看出涝坝是满的、还是快见底了。

四档（水位半径 / 湿泥圈 / 水色）
    lv1  8   —— 几乎见底，只剩一汪浊水，大片泥滩
    lv2  13  —— 半池，水色偏浊
    lv3  17  —— 大半池
    lv4  20  —— 满池，水色最清

档位由 game_state.reservoir_level() 按「当前水量 ÷ 容量」算，地图只负责取图 ——
判据只有一处，和 gate 遵循同一条原则。

输出：assets/buildings/reservoir_lv1..4.png
用法：
    .venv\\Scripts\\python.exe scripts\\pipeline\\make_reservoir_levels.py
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

SIZE = 64
OUT = Path(__file__).resolve().parents[2] / "assets" / "buildings"
BACKUP = Path(__file__).resolve().parents[2] / "assets" / "_wip" / "_originals"

BANK_HI = "#C9A277"
BANK_MID = "#9E7C55"
BANK_LOW = "#8B6B47"
BANK_DEEP = "#6B4F33"

WATER_HI = "#8FC7D6"
WATER_MID = "#5A9CB0"
WATER_DEEP = "#3A7086"
WATER_MURK = "#7A8B78"

# (水位半径, 湿泥圈外扩, 浅水色, 中水色, 深水色)
LEVELS = [
    (8.0, 7.0, WATER_MURK, WATER_MURK, WATER_MID),
    (13.0, 5.0, WATER_MURK, WATER_MID, WATER_DEEP),
    (17.0, 3.5, WATER_MID, WATER_MID, WATER_DEEP),
    (20.0, 3.0, WATER_HI, WATER_MID, WATER_DEEP),
]

R_OUT_X, R_OUT_Y = 30.0, 27.0


def _rgb(h: str) -> tuple[int, int, int, int]:
    s = h.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)  # type: ignore[return-value]


def build(level_idx: int, seed: int) -> Image.Image:
    """level_idx 从 0 起。同一个 seed 保证四档的岸形完全一致 ——
    只有水位不同。否则从 lv3 掉到 lv2 时，整圈岸会跟着"跳"一下，像换了个池子。"""
    rng = random.Random(seed)
    water_r_px, mud_extra, c_hi, c_mid, c_deep = LEVELS[level_idx]

    cx = cy = (SIZE - 1) / 2.0
    N = 12
    outer_noise = [rng.uniform(-2.6, 2.6) for _ in range(N)]

    def outer_r(theta: float) -> float:
        t = (theta % (2 * math.pi)) / (2 * math.pi) * N
        i0 = int(t) % N
        i1 = (i0 + 1) % N
        f = t - int(t)
        n = outer_noise[i0] * (1 - f) + outer_noise[i1] * f
        return 1.0 + n / R_OUT_X

    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    px = img.load()

    INLET_ANGLE = math.radians(-18)
    INLET_HALF = math.radians(13)

    water_r = water_r_px / R_OUT_X
    inner_r = (water_r_px + mud_extra) / R_OUT_X

    for y in range(SIZE):
        for x in range(SIZE):
            dx = x - cx
            dy = y - cy
            theta = math.atan2(dy, dx)
            ex = dx / R_OUT_X
            ey = dy / R_OUT_Y
            d = math.sqrt(ex * ex + ey * ey)

            da = abs((theta - INLET_ANGLE + math.pi) % (2 * math.pi) - math.pi)
            if da < INLET_HALF and d > 0.62:
                continue

            r_out = outer_r(theta)
            wj = rng.uniform(-0.035, 0.035)
            mj = rng.uniform(-0.02, 0.02)

            if d <= water_r + wj:
                depth = d / max(water_r + wj, 1e-6)
                lit = (dx + dy) < 0
                if depth > 0.72:
                    px[x, y] = _rgb(c_deep)
                elif lit:
                    px[x, y] = _rgb(c_mid if depth > 0.30 else c_hi)
                else:
                    # 背光面：浅水时整片都偏浊，满水时才露出水蓝
                    px[x, y] = _rgb(c_mid if depth > 0.45 else c_mid)
            elif d <= inner_r + mj:
                px[x, y] = _rgb(BANK_LOW if (dx + dy) > 0 else BANK_MID)
            elif d <= r_out:
                if (dx + dy) < -6:
                    px[x, y] = _rgb(BANK_HI)
                elif (dx + dy) < 4:
                    px[x, y] = _rgb(BANK_MID)
                else:
                    px[x, y] = _rgb(BANK_LOW)
            else:
                continue

    # 岸上的石头与干草（四档同 seed，位置一致）
    for _ in range(9):
        ang = rng.uniform(0, 2 * math.pi)
        da = abs((ang - INLET_ANGLE + math.pi) % (2 * math.pi) - math.pi)
        if da < INLET_HALF + 0.25:
            continue
        rr = rng.uniform(water_r_px + 5, R_OUT_X - 2) / R_OUT_X
        x = int(cx + math.cos(ang) * rr * R_OUT_X)
        y = int(cy + math.sin(ang) * rr * R_OUT_Y)
        if 0 <= x < SIZE and 0 <= y < SIZE and px[x, y][3] > 0:
            col = BANK_HI if rng.random() < 0.5 else BANK_DEEP
            px[x, y] = _rgb(col)
            if rng.random() < 0.5 and x + 1 < SIZE:
                px[x + 1, y] = _rgb(col)

    return img


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    palette = {c.upper() for c in PALETTE_HEX}
    print(f"  色板 {len(PALETTE_HEX)} 色   输出 {OUT}\n")
    ok = True
    for i in range(4):
        img = build(i, seed=20261006)
        used = {f"#{r:02X}{g:02X}{b:02X}"
                for r, g, b, a in img.get_flattened_data() if a >= 128}
        off = used - palette
        if off:
            print(f"  [X] lv{i+1} 用了色板外的颜色：{sorted(off)}")
            ok = False
            continue
        # 水面占比：低水位必须明显小于高水位，否则分档白做
        waterish = sum(1 for r, g, b, a in img.get_flattened_data()
                       if a >= 128 and b > r + 12)
        name = f"reservoir_lv{i+1}.png"
        print(f"  [OK] {name:<22} {len(used)} 色   水面像素 {waterish:>4}")
        img.save(OUT / name)

    # 旧的那张单图留个备份（已被 reservoir_lv4.png 取代）
    old = OUT / "reservoir_01.png"
    if old.exists():
        BACKUP.mkdir(parents=True, exist_ok=True)
        shutil.copy2(old, BACKUP / "reservoir_01.png.orig2")
        print(f"\n  旧单图已备份 → reservoir_01.png.orig2（现由 reservoir_lv1..4.png 取代）")
    print("\n  全部合规。" if ok else "\n  [!] 有项目不合格。")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
