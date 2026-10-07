#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
生成地形层级之间的**抖动过渡贴图**（16x16）。

背景：为什么需要
    绿洲的地形是按半径切的四档（desert / sparse / medium / lush），格与格之间是
    **硬边**。实机截图上看，绿洲就是一块贴在沙地上的绿色斑点，而不是「从沙漠里
    长出来」—— 而这恰好是本作最重要的一句视觉表达（GDD 8.1）。
    内部三档草之间同样是硬边，一眼能看出是几个色块拼的。

为什么上一轮的「过渡贴图」方案失败了，而这一轮能行
    上一轮用的是 desert_light_01/02 那类**带装饰斑块的过渡贴图**：每张自带一块
    固定位置的橙黄斑块，而 16x16 的格子没法按方向旋转去「朝向」绿洲，于是每个
    边界格都重复同一块斑，拼成一排各说各话的方块，比硬边还难看（已实机确认）。

    失败的是「带固定斑块的装饰贴图」，不是「过渡」这件事本身。
    正确的做法是**抖动（dither）**：逐像素随机混合两种材质。

        抖动是**各向同性**的 —— 从任何方向看都是同一种噪点结构，
        所以它不需要「朝向绿洲」，也就没有上面那个问题。

    这是像素画处理地形边界的通行手法，也是 16 位机时代的做法。

覆盖的材质对（按「沙漠程度」由外到内）
    sand   ↔ sparse ↔ medium ↔ lush        （夏/春/秋）
    snow   ↔ snow_sparse ↔ snow_medium ↔ snow_lush   （冬）

取色方式
    **不硬编码颜色**，而是读取现有底纹、按真实颜色频率加权采样。
    好处：过渡贴图和底纹必然一致；底纹改了不用同步改这里。

输出：assets/tiles/terrain/trans_{外层}_{内层}_d{密度}_{变体}.png
用法：
    .venv\\Scripts\\python.exe scripts\\pipeline\\make_transitions.py
"""

from __future__ import annotations

import random
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image  # noqa: E402

from postprocess import PALETTE_HEX  # noqa: E402  单一色源，避免两处色板漂移

TILE = 16
TERRAIN = Path(__file__).resolve().parents[2] / "assets" / "tiles" / "terrain"

# 4x4 有序抖动矩阵（Bayer）。有序而非纯随机：
# 纯随机会变成一团彩噪，有序抖动才有 16 位机那种「网点」质感。
BAYER4 = [
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5],
]

# ---- 材质：键名 -> 底纹文件 ----
# 键名会出现在输出文件名里，改名要同步改 map_view.gd 的 TERRAIN_LAYERS。
MATERIALS: dict[str, list[str]] = {
    # 夏 / 春 / 秋
    "sand":   ["sand_base_01.png", "sand_base_02.png", "sand_base_03.png",
               "sand_base_04.png", "sand_base_05.png"],
    "sparse": ["grass_sparse_base_01.png", "grass_sparse_base_02.png"],
    "medium": ["grass_medium_base_01.png", "grass_medium_base_02.png"],
    "lush":   ["grass_lush_base_01.png", "grass_lush_base_02.png"],
    # 冬
    "snow":        ["snow_desert_01.png", "snow_desert_02.png", "snow_desert_03.png"],
    "snow_sparse": ["snow_sparse_01.png", "snow_sparse_02.png"],
    "snow_medium": ["snow_medium_01.png", "snow_medium_02.png"],
    "snow_lush":   ["snow_lush_01.png", "snow_lush_02.png"],
}

# 需要生成过渡的材质对（外层=更沙漠，内层=更绿）
PAIRS: list[tuple[str, str]] = [
    # 沙 ↔ 各级草。含跳级对（sand↔medium / sand↔lush）：
    # 边缘抖动是随机的，偶尔会有 medium 格直接贴着 sand 格。
    ("sand", "sparse"), ("sand", "medium"), ("sand", "lush"),
    # 草地内部层级。这几对以前是硬边，截图里能看出是几个色块拼的。
    ("sparse", "medium"), ("medium", "lush"),
    # 冬天同理
    ("snow", "snow_sparse"), ("snow", "snow_medium"), ("snow", "snow_lush"),
    ("snow_sparse", "snow_medium"), ("snow_medium", "snow_lush"),
]

# 三档密度（内层材质像素占比）。对应「贴着 1 / 2 / 3+ 个更沙漠的邻格」。
# 不是 0.5 一刀切：边缘一格是「草渐渐稀疏」，越靠外草越少。
DENSITIES = [0.72, 0.46, 0.26]
VARIANTS = 3


def _rgb(h: str) -> tuple[int, int, int]:
    s = h.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]


def _hex(rgb: tuple[int, int, int]) -> str:
    return "#{:02X}{:02X}{:02X}".format(*rgb)


_POOL_CACHE: dict[str, list[tuple[int, int, int]]] = {}


def color_pool(key: str) -> list[tuple[int, int, int]]:
    """
    材质 key 的**按出现频率加权**的颜色池。

    加权而不是取唯一色：底纹是「基色 + 少量细点」，唯一色会让细点色被过度采样，
    过渡贴图就会比底纹花。按频率铺开才能复现同样的密度。
    """
    if key in _POOL_CACHE:
        return _POOL_CACHE[key]

    counter: Counter[tuple[int, int, int]] = Counter()
    for name in MATERIALS[key]:
        path = TERRAIN / name
        if not path.exists():
            raise FileNotFoundError(f"底纹不存在：{path}（先跑 make_ground.py / make_snow.py）")
        img = Image.open(path).convert("RGB")
        if img.size != (TILE, TILE):
            raise ValueError(f"{name} 不是 {TILE}x{TILE}，实际 {img.size}")
        counter.update(img.get_flattened_data())

    pool: list[tuple[int, int, int]] = []
    for color, count in counter.most_common():
        # 每种颜色按出现次数放进池子，但设上限，避免某张特别花的底纹压倒其余
        pool.extend([color] * min(count, 40))
    _POOL_CACHE[key] = pool
    return pool


def make_tile(
    outer_pool: list[tuple[int, int, int]],
    inner_pool: list[tuple[int, int, int]],
    density: float,
    rng: random.Random,
) -> Image.Image:
    """
    逐像素抖动，但按 **2x2 成簇**。

    为什么成簇：纯逐像素的 Bayer 抖动出来是「网点印花」——每个像素间隔着翻色，
    16px 的格子放大到屏幕上是规则的**筛网纹**，看着像印刷网点而不是草。
    改成 2x2 一块地决定，再在块的边缘做随机侵蚀，得到的是一丛丛的草与沙，
    既保留抖动的各向同性（不需要朝向绿洲），又更有机。
    """
    img = Image.new("RGB", (TILE, TILE))
    px = img.load()

    # 先在 8x8 的「块网格」上决定每一块是内层还是外层
    is_inner: dict[tuple[int, int], bool] = {}
    for by in range(TILE // 2):
        for bx in range(TILE // 2):
            # 有序抖动阈值 + 少量抖动，打散 Bayer 的规则感
            thr = (BAYER4[by % 4][bx % 4] + rng.uniform(-1.6, 1.6)) / 16.0
            is_inner[(bx, by)] = thr < density

    for y in range(TILE):
        for x in range(TILE):
            bx, by = x // 2, y // 2
            flag = is_inner[(bx, by)]
            # 块边缘做随机侵蚀：约 1/4 的像素跟随邻块的取值，
            # 这样块与块之间不会留下整齐的 2px 方格边
            if x % 2 == 0 or y % 2 == 0:
                if rng.random() < 0.28:
                    nb = is_inner.get((bx + (1 if x % 2 == 0 else 0),
                                       by + (1 if y % 2 == 0 else 0)))
                    if nb is not None:
                        flag = nb
            px[x, y] = rng.choice(inner_pool if flag else outer_pool)
    return img


def main() -> int:
    palette = {c.upper() for c in PALETTE_HEX}
    print(f"  色板 {len(PALETTE_HEX)} 色   输出 {TERRAIN}\n")

    made: list[str] = []
    seen: set[str] = set()

    for outer, inner in PAIRS:
        outer_pool = color_pool(outer)
        inner_pool = color_pool(inner)
        count = 0
        for density in DENSITIES:
            tag = int(round(density * 100))
            for v in range(1, VARIANTS + 1):
                # 固定种子：可复现，重跑结果逐字节相同
                seed = abs(hash((outer, inner, tag, v))) % 0x7FFFFFFF
                rng = random.Random(seed)
                img = make_tile(outer_pool, inner_pool, density, rng)

                name = f"trans_{outer}_{inner}_d{tag}_{v}.png"
                used = {_hex(c) for c in img.get_flattened_data()}
                off = used - palette
                if off:
                    print(f"  [X] {name} 用了色板外的颜色：{sorted(off)}")
                    return 1
                img.save(TERRAIN / name)
                made.append(name)
                seen |= used
                count += 1
        print(f"  [OK] {outer:<12} → {inner:<12} {count} 张"
              f"（{len({_hex(c) for c in outer_pool})} 色 × {len({_hex(c) for c in inner_pool})} 色）")

    print(f"\n  共生成 {len(made)} 张过渡贴图，覆盖 {len(PAIRS)} 对材质，"
          f"用到 {len(seen)} 种色板颜色")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
