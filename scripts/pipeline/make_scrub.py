#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
生成地面散落物：沙漠灌木/枯草 + 绿洲草丛。16x16，带透明通道。

为什么必须重做
    散布池里混进了**没有透明通道的地形块**，它们被当作"散落的小物件"撒在地图上：
        desert_pool: gravel_01（草绿+土黄的地形交界块）、dirt_patch_01（同类）、
                     sand_ripple_01（整块沙子）
        oasis_pool:  grass_flower_01（整块不透明绿方块）、
                     grass_pebble_01（整块绿 + 青蓝色石子，就是那个"青蓝斑块"）
    16x16 全不透明的方块撒在沙地/草地上，看起来就是**一张张邮票** ——
    用户的原话是「沙漠里那些绿色方块」。它们本来就不是道具，是地形之间的过渡块。

设计原则（针对"邮票感"）
    · **大部分透明**：不透明像素控制在 15%~35%。沙漠植物本来就稀疏，
      一整块实心色块无论什么颜色都会像贴纸。
    · **细线条**：用 1px 的枝/叶，而不是块。块状只能读出"色块"，读不出"植物"。
    · **沙漠用干色**：橄榄绿/枯黄/灰棕，不用绿洲那种鲜绿。骆驼刺和梭梭就是灰绿的。
    · **底边落地**：从 y=14 左右往上长，和 _add_ground 的摆放方式对得上。

输出：assets/tiles/props/
用法：
    .venv\\Scripts\\python.exe scripts\\pipeline\\make_scrub.py
"""

from __future__ import annotations

import random
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image  # noqa: E402

from postprocess import PALETTE_HEX  # noqa: E402

OUT = Path(__file__).resolve().parents[2] / "assets" / "tiles" / "props"
BACKUP = Path(__file__).resolve().parents[2] / "assets" / "_wip" / "_originals"
W = H = 16

# ── 用色（全部取自 34 色板）──
# 沙漠：干、灰、黄
D_THORN_MID = "#8A9B62"    # 骆驼刺的橄榄绿
D_THORN_LOW = "#6E8F55"
D_WOODY_HI = "#A88E6B"     # 梭梭/枯枝的灰棕
D_WOODY_LOW = "#8B6B47"
D_STRAW_HI = "#D9B382"     # 干草的枯黄
D_STRAW_LOW = "#B8935F"
# 绿洲：鲜一点但仍是像素画的低饱和
O_GRASS_HI = "#7FA34A"
O_GRASS_MID = "#6E8F55"
O_GRASS_LOW = "#3F6B4C"
# 共用
OUTLINE = "#3D3024"        # 深描边（与现有 rock_small_01 的描边一致）
FLOWER = "#E0A43C"


def _rgb(h: str) -> tuple[int, int, int, int]:
    s = h.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)  # type: ignore[return-value]


class Canvas:
    def __init__(self) -> None:
        self.im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        self.px = self.im.load()

    def put(self, x: int, y: int, col: str) -> None:
        if 0 <= x < W and 0 <= y < H:
            self.px[x, y] = _rgb(col)

    def line(self, x0: int, y0: int, x1: int, y1: int, col: str) -> None:
        """Bresenham，1px 线 —— 植物的枝都靠它，所以必须细。"""
        dx, dy = abs(x1 - x0), abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx - dy
        while True:
            self.put(x0, y0, col)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 > -dy:
                err -= dy
                x0 += sx
            if e2 < dx:
                err += dx
                y0 += sy

    def outline(self) -> None:
        """给已有像素描一圈深色边 —— 现有 rock/herb 都有，统一风格。
        只描**下方与左右**：上方留空，光是从左上来。"""
        src = self.im.copy().load()
        for y in range(H):
            for x in range(W):
                if src[x, y][3] >= 128:
                    continue
                touching = False
                for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < W and 0 <= ny < H and src[nx, ny][3] >= 128:
                        touching = True
                        break
                if touching:
                    self.px[x, y] = _rgb(OUTLINE)


def _tuft(rng: random.Random, blades: int, y_base: int, hmin: int, hmax: int,
          spread: int, hi: str, mid: str, low: str, tip: str | None = None) -> Canvas:
    """一丛草叶：从底部往外散开，越往外越短、越弯 —— 直上直下会像刷子。"""
    c = Canvas()
    for i in range(blades):
        t = (i / max(1, blades - 1)) - 0.5            # -0.5 .. 0.5
        bx = W // 2 + int(round(t * spread * 2))
        bh = rng.randint(hmin, hmax)
        # 外侧的草叶更矮，中间的最高 —— 一丛草的自然轮廓
        bh = max(2, bh - int(abs(t) * 4))
        top = y_base - bh
        col = hi if abs(t) < 0.25 else mid
        c.line(bx, y_base, bx + int(round(t * 3)), top, col)
        # 叶尖再点一下，颜色略亮/略枯
        c.put(bx + int(round(t * 3)), top, tip or hi)
    return c


def make_desert_thorn(rng: random.Random) -> Canvas:
    """骆驼刺：矮、密、带刺。沙漠里最典型的绿，但是灰绿不是鲜绿。"""
    c = _tuft(rng, blades=9, y_base=13, hmin=3, hmax=6, spread=4,
              hi=D_THORN_MID, mid=D_THORN_LOW, low=D_THORN_LOW)
    # 几根横生的短刺，让它读起来是"刺"而不是"草"
    for _ in range(4):
        y = rng.randint(9, 13)
        x = rng.randint(3, 9)
        c.line(x, y, x + rng.choice([-2, 2]), y, D_THORN_LOW)
    return c


def make_desert_scrub(rng: random.Random) -> Canvas:
    """梭梭/沙拐枣：细瘦的灰棕枝条，几乎看不到叶子。"""
    c = Canvas()
    base_y = 14
    for i in range(5):
        bx = W // 2 + rng.randint(-4, 4)
        h = rng.randint(4, 8)
        # 主干
        c.line(bx, base_y, bx + rng.choice([-1, 0, 1]), base_y - h, D_WOODY_LOW)
        # 上部一两个分叉
        if h >= 5:
            fy = base_y - h + rng.randint(1, 2)
            c.line(bx, fy, bx + rng.choice([-2, 2]), fy - rng.randint(1, 3), D_WOODY_HI)
    return c


def make_dry_grass(rng: random.Random) -> Canvas:
    """干草丛：枯黄，秋天的沙窝子里到处是。"""
    return _tuft(rng, blades=8, y_base=13, hmin=4, hmax=8, spread=4,
                 hi=D_STRAW_HI, mid=D_STRAW_LOW, low=D_STRAW_LOW, tip=D_STRAW_HI)


def make_twig(rng: random.Random) -> Canvas:
    """几截枯枝：最矮最不起眼，用来填空隙，不抢视线。"""
    c = Canvas()
    for i in range(3):
        x = 4 + i * 3 + rng.randint(-1, 1)
        y = 13 - rng.randint(0, 2)
        c.line(x, y, x + rng.choice([-2, -1, 1, 2]), y - rng.randint(2, 4), D_WOODY_LOW)
    return c


def make_grass_tuft(rng: random.Random) -> Canvas:
    """绿洲草丛：绿，但仍是细叶，不是色块。"""
    return _tuft(rng, blades=8, y_base=13, hmin=4, hmax=7, spread=4,
                 hi=O_GRASS_HI, mid=O_GRASS_MID, low=O_GRASS_LOW)


def make_grass_flower(rng: random.Random) -> Canvas:
    """草丛带小花：春天用。花只占 3~4 个像素，多了就俗。"""
    c = _tuft(rng, blades=7, y_base=13, hmin=4, hmax=7, spread=4,
              hi=O_GRASS_HI, mid=O_GRASS_MID, low=O_GRASS_LOW)
    # 花茎 + 花头
    fx = W // 2 + rng.choice([-2, 2])
    fy = 6
    c.line(W // 2 + rng.choice([-1, 1]), 13, fx, fy + 1, O_GRASS_LOW)
    c.put(fx, fy, FLOWER)
    c.put(fx, fy + 1, FLOWER)
    c.put(fx - 1, fy, FLOWER)
    c.put(fx + 1, fy, FLOWER)
    return c


JOBS = [
    ("desert_thorn_01.png", make_desert_thorn),
    ("desert_scrub_01.png", make_desert_scrub),
    ("desert_dry_grass_01.png", make_dry_grass),
    ("desert_twig_01.png", make_twig),
    ("grass_tuft_01.png", make_grass_tuft),
    ("grass_tuft_02.png", make_grass_flower),
]

# ---------------------------------------------------------------------------
# 附带修：把「水蓝色的石头」改成石灰色
# ---------------------------------------------------------------------------
#
# rock_small_01 / rock_pile_01 是散布池里的主要石头，但它们的用色是
#     #E8EEF2 / #8FC7D6 / #5A9CB0 / #3A7086
# —— 这是**水面**那一套色，不是石头。撒在干沙地上就是一小簇蓝斑，
# 看着像画面故障（更早那次"草地上的青蓝故障块"其实也是同一类：
# 拿水系素材当了陆地道具）。
#
# 形状是对的，所以只换色：按明度把水色的四级映射到石头的四级灰。
# 灰色调成偏灰而不是偏沙 —— 沙漠里石头要略微比沙地"冷"一点才读得出来，
# 用沙色会和地面糊在一起看不见。
ROCK_RECOLOR = {
    "#E8EEF2": "#F0E4D0",   # 最亮 → 暖白高光
    "#8FC7D6": "#B5A48C",   # 亮 → 石面受光
    "#5A9CB0": "#A88E6B",   # 中 → 石面
    "#3A7086": "#8B6B47",   # 暗 → 石面背光
    "#7A8B78": "#9E7C55",   # 浊 → 石缝
}


def recolor_water_rocks() -> int:
    """把水蓝色的石头改成石灰色。原件备份到 _wip/_originals/。"""
    fixed = 0
    for name in ("rock_small_01.png", "rock_pile_01.png"):
        p = OUT / name
        if not p.exists():
            print(f"  跳过（不存在）：{name}")
            continue
        im = Image.open(p).convert("RGBA")
        px = im.load()
        changed = 0
        for y in range(im.height):
            for x in range(im.width):
                r, g, b, a = px[x, y]
                if a < 128:
                    continue
                key = f"#{r:02X}{g:02X}{b:02X}"
                if key in ROCK_RECOLOR:
                    px[x, y] = _rgb(ROCK_RECOLOR[key])
                    changed += 1
        if changed:
            BACKUP.mkdir(parents=True, exist_ok=True)
            shutil.copy2(p, BACKUP / (name + ".blue_orig"))
            im.save(p)
            print(f"  {name:<22} 改了 {changed:>3} 个像素 → 石灰色")
            fixed += 1
        else:
            print(f"  {name:<22} 没有需要改的像素（可能已经改过）")
    return fixed


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    palette = {c.upper() for c in PALETTE_HEX}
    print(f"  色板 {len(PALETTE_HEX)} 色   输出 {OUT}\n")
    print(f"  {'文件':<26} {'不透明':>8}  {'占比':>5}  {'色数':>4}")
    print("  " + "-" * 52)
    ok = True
    for i, (name, fn) in enumerate(JOBS):
        rng = random.Random(20261006 + i)
        c = fn(rng)
        c.outline()
        img = c.im
        opaque = 0
        used: set[str] = set()
        for r, g, b, a in img.get_flattened_data():
            if a >= 128:
                opaque += 1
                used.add(f"#{r:02X}{g:02X}{b:02X}")
        off = used - palette
        if off:
            print(f"  [X] {name} 用了色板外的颜色：{sorted(off)}")
            ok = False
            continue
        ratio = opaque / float(W * H)
        flag = ""
        # 邮票感的来源就是"一整块实心"：占比超过 45% 就基本不是植物了
        if ratio > 0.45:
            flag = "  <-- 太实，会像邮票"
            ok = False
        print(f"  {name:<26} {opaque:>4}/{W*H:<3}  {ratio:>4.0%}  {len(used):>4}{flag}")
        img.save(OUT / name)
    print()
    print("  附带修：水蓝色的石头 → 石灰色")
    recolor_water_rocks()
    print()
    print("  全部合规。" if ok else "  [!] 有项目不合格，见上面的标记。")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
