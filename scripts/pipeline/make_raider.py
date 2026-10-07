#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
生成马匪行走图（16x16 帧，4 方向 × 4 帧 = 64x64）。

为什么自己画
    assets/characters 里只有 8 个**村民/角色**的行走图（老坎匠、厨娘、骑手…），
    一个敌人都没有。战斗要"看得见敌我"，就必须有辨识度足够的一张敌方图。
    备选方案是用 villager_walk.png 调成暗红当马匪 —— 一眼假，而且把"村民"
    和"马匪"混成同一套形，玩家分不清谁是谁。所以单独画。

与既有行走图的格式保持一致
    · 每帧 16x16，**精灵锚点在脚底**（offset 用法同 player.gd）
    · 列 = 4 帧走路循环，行 = down / left / right / up
    · 调色板仍取 34 色，与全项目统一

辨识度靠三件事（15px 的人物能用的手段不多）
    ① 深色斗篷 + 红腰带 —— 村民是土黄/绿色系，深色一眼区分
    ② 缠头布 + 只露一条眼缝 —— "匪"的视觉符号
    ③ 手里一根短木棍（左边那列），和村民的空手也不同

输出：assets/characters/raider_walk.png
用法：
    .venv\\Scripts\\python.exe scripts\\pipeline\\make_raider.py
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image  # noqa: E402

from postprocess import PALETTE_HEX  # noqa: E402

FW = FH = 16
DIRS = ["down", "left", "right", "up"]
FRAMES = 4
OUT = Path(__file__).resolve().parents[2] / "assets" / "characters" / "raider_walk.png"

# ── 用色（全在 34 色板内）──
CLOAK = "#3D3024"      # 斗篷主色
CLOAK_D = "#2B2118"    # 斗篷暗部
CLOAK_HI = "#6B4F33"   # 斗篷受光
SKIN = "#C9A277"       # 露出的皮肤
WRAP = "#8B6B47"       # 缠头布
WRAP_HI = "#A88E6B"
SASH = "#A8522F"       # 红腰带（关键辨识色）
SASH_HI = "#C9704A"
EYE = "#1E1812"
STICK = "#9E7C55"


def _rgb(h: str) -> tuple[int, int, int, int]:
    s = h.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)  # type: ignore[return-value]


def draw(direction: str, frame: int) -> Image.Image:
    """画一帧。frame 0..3 是走路循环，靠**整体上下 1px 的起伏**+左右脚交替表现。"""
    im = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
    px = im.load()
    # 起伏：0,1,0,-? —— 用 0/1 两档就够，2 档以上在 16px 里会像抽搐
    bob = 1 if frame in (1, 3) else 0
    # 左右脚：偶数帧抬左脚，奇数帧抬右脚
    lift_l = 1 if frame % 2 == 0 else 0
    lift_r = 1 if frame % 2 == 1 else 0

    def put(x: int, y: int, col: str) -> None:
        if 0 <= x < FW and 0 <= y < FH:
            px[x, y] = _rgb(col)

    cx = 8
    top = 2 + bob

    # ── 头（5x4）：缠头布 + 一条眼缝 ──
    for y in range(top, top + 4):
        for x in range(cx - 2, cx + 3):
            put(x, y, WRAP)
    for x in range(cx - 2, cx + 3):
        put(x, top, WRAP_HI)          # 头顶受光（光来自左上）
    if direction == "down":
        for x in range(cx - 1, cx + 2):
            put(x, top + 2, EYE)      # 眼缝
    elif direction == "up":
        # 背面：整块缠头布，不露眼
        for x in range(cx - 2, cx + 3):
            put(x, top + 2, WRAP)
    else:
        side = -1 if direction == "left" else 1
        put(cx + side, top + 2, EYE)

    # ── 脖子以下：斗篷（宽 6，到 y=12）──
    body_top = top + 4
    for y in range(body_top, body_top + 6):
        for x in range(cx - 3, cx + 4):
            put(x, y, CLOAK_D if x >= cx + 2 else CLOAK)
    # 左肩受光
    for y in range(body_top, body_top + 3):
        put(cx - 3, y, CLOAK_HI)
    # ── 红腰带 ──
    for x in range(cx - 3, cx + 4):
        put(x, body_top + 4, SASH)
    put(cx - 3, body_top + 4, SASH_HI)

    # ── 腿（两条，3px 高）──
    leg_y = body_top + 6
    for i, lx in enumerate((cx - 2, cx + 1)):
        lift = lift_l if i == 0 else lift_r
        for y in range(leg_y - lift, min(FH, leg_y + 3 - lift)):
            put(lx, y, CLOAK_D)
            put(lx + 1, y, CLOAK_D)

    # ── 手里的短棍（朝向侧面的那一侧）──
    if direction == "down":
        for y in range(body_top, body_top + 5):
            put(cx + 4, y, STICK)
    elif direction == "left":
        for y in range(body_top, body_top + 5):
            put(cx - 4, y, STICK)
    elif direction == "right":
        for y in range(body_top, body_top + 5):
            put(cx + 4, y, STICK)

    return im


def main() -> int:
    sheet = Image.new("RGBA", (FW * FRAMES, FH * len(DIRS)), (0, 0, 0, 0))
    for r, d in enumerate(DIRS):
        for c in range(FRAMES):
            sheet.paste(draw(d, c), (c * FW, r * FH))

    palette = {c.upper() for c in PALETTE_HEX}
    used: set[str] = set()
    for r, g, b, a in sheet.get_flattened_data():
        if a >= 128:
            used.add(f"#{r:02X}{g:02X}{b:02X}")
    off = used - palette
    if off:
        print(f"  [X] 用了色板外的颜色：{sorted(off)}")
        return 1

    opaque = sum(1 for *_c, a in sheet.get_flattened_data() if a >= 128)
    total = sheet.size[0] * sheet.size[1]
    print(f"  输出 {OUT.name}  {sheet.size[0]}x{sheet.size[1]}"
          f"  （{FRAMES} 帧 × {len(DIRS)} 方向，每帧 {FW}x{FH}）")
    print(f"  不透明 {opaque}/{total} = {opaque/total:.0%}（人物约占三成，其余是透明）")
    print(f"  用色 {len(used)} 种，全部在色板内")
    print("  方向行序：" + " / ".join(DIRS) + "（与 player.gd 的 facing 0/1/2/3 一致）")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT)
    print("  已写入")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
