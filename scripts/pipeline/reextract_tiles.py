#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
重新提取 Kenney tiny-farm / tiny-town 的 tile —— 修正第一版挑错的编号。

背景（值得留档，因为同类错误很容易再犯）：
    第一版是照着 tilemap 的**低分辨率标注图**目视识别、再按 `n = row*12 + col`
    心算编号挑的。结果大面积挑错：
        crop_stage_4_ripe  -> 实际拿到的是木桶
        crop_harvested     -> 实际是石堆
        fence_wood_rail    -> 实际是石地板
        wall_brick_01      -> 实际是窗户
        rock_small_01      -> 实际是红果灌木

    教训：**心算编号不可靠。** 正确做法是把整张网格按 8 倍放大、每格标上真实
    编号渲染出来，直接对着编号挑。tools 里已留 `render_grid` 供复查。

本脚本按修正后的编号重新提取，并先清掉第一版的错误文件。

用法：
    .venv\\Scripts\\python.exe scripts\\pipeline\\reextract_tiles.py
"""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image  # noqa: E402

from postprocess import process  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
WIP = ROOT / "assets" / "_wip"
ASSETS = ROOT / "assets"
BAK = WIP / "_originals"

# 第一版由本脚本重做的目录（terrain 里只动来自 tiny-town 的那几张树/杂物）
CLEAN_DIRS = ["tiles/farmland", "tiles/props"]
CLEAN_TERRAIN = [
    "tree_green_01", "tree_green_02", "tree_autumn_01", "tree_autumn_02",
    "mushroom_red_01", "grass_flower_01", "dirt_patch_01", "dirt_patch_02",
]

# (包, tile编号, 目标目录, 目标文件名)
PLAN = [
    # ── tiny-farm：农田基底 ──
    ("tiny-farm", 48, "tiles/farmland", "soil_plain_a.png"),
    ("tiny-farm", 49, "tiles/farmland", "soil_plain_b.png"),
    ("tiny-farm", 60, "tiles/farmland", "soil_tilled_a.png"),
    ("tiny-farm", 61, "tiles/farmland", "soil_tilled_b.png"),
    ("tiny-farm", 50, "tiles/farmland", "soil_field_c.png"),
    # ── tiny-farm：作物生长阶段（番茄那条线，四段最清楚）──
    ("tiny-farm", 40, "tiles/farmland", "crop_stage_1_seedling.png"),
    ("tiny-farm", 41, "tiles/farmland", "crop_stage_2_sprout.png"),
    ("tiny-farm", 42, "tiles/farmland", "crop_stage_3_growing.png"),
    ("tiny-farm", 44, "tiles/farmland", "crop_stage_4_ripe.png"),
    # ── tiny-farm：其他作物，用于农田多样性 ──
    ("tiny-farm", 6, "tiles/farmland", "crop_carrot.png"),
    ("tiny-farm", 18, "tiles/farmland", "crop_eggplant.png"),
    ("tiny-farm", 30, "tiles/farmland", "crop_corn.png"),
    ("tiny-farm", 54, "tiles/farmland", "crop_cabbage.png"),
    ("tiny-farm", 68, "tiles/farmland", "crop_wheat.png"),
    # ── tiny-farm：树 ──
    ("tiny-farm", 3, "tiles/props", "tree_pine_01.png"),
    ("tiny-farm", 15, "tiles/props", "tree_pine_02.png"),
    ("tiny-farm", 27, "tiles/props", "tree_round_01.png"),
    ("tiny-farm", 39, "tiles/props", "tree_round_02.png"),
    ("tiny-farm", 2, "tiles/props", "tree_trunk_01.png"),
    ("tiny-farm", 14, "tiles/props", "tree_trunk_02.png"),
    # ── tiny-farm：水井 ──
    ("tiny-farm", 72, "tiles/props", "well_stone_01.png"),
    ("tiny-farm", 73, "tiles/props", "well_stone_02.png"),
    # ── tiny-farm：石头与植被 ──
    ("tiny-farm", 77, "tiles/props", "rock_small_01.png"),
    ("tiny-farm", 89, "tiles/props", "rock_pile_01.png"),
    ("tiny-farm", 78, "tiles/props", "bush_berry_01.png"),
    ("tiny-farm", 79, "tiles/props", "mushroom_01.png"),
    ("tiny-farm", 80, "tiles/props", "herb_green_01.png"),
    ("tiny-farm", 83, "tiles/props", "sunflower_01.png"),
    # ── tiny-farm：容器 ──
    ("tiny-farm", 76, "tiles/props", "crate_wood_01.png"),
    ("tiny-farm", 75, "tiles/props", "barrel_wood_01.png"),
    ("tiny-farm", 85, "tiles/props", "barrel_banded_01.png"),
    ("tiny-farm", 84, "tiles/props", "bucket_metal_01.png"),
    ("tiny-farm", 123, "tiles/props", "basket_01.png"),
    # ── tiny-farm：工具 ──
    ("tiny-farm", 86, "tiles/props", "tool_hammer_01.png"),
    ("tiny-farm", 87, "tiles/props", "tool_axe_01.png"),
    ("tiny-farm", 88, "tiles/props", "tool_pickaxe_01.png"),
    # ── tiny-farm：动物与人物 ──
    ("tiny-farm", 120, "tiles/props", "animal_sheep_01.png"),
    ("tiny-farm", 121, "tiles/props", "animal_donkey_01.png"),
    ("tiny-farm", 122, "tiles/props", "animal_chicken_01.png"),
    ("tiny-farm", 108, "tiles/props", "person_farmer_01.png"),
    ("tiny-farm", 109, "tiles/props", "person_farmer_02.png"),
    # ── tiny-farm：其他 ──
    ("tiny-farm", 90, "tiles/props", "fence_x_01.png"),
    ("tiny-farm", 98, "tiles/props", "bench_wood_01.png"),
    ("tiny-farm", 100, "tiles/props", "trough_grey_01.png"),
    ("tiny-farm", 110, "tiles/props", "trough_water_01.png"),
    # ── tiny-town：树与地表 ──
    ("tiny-town", 16, "tiles/terrain", "tree_green_01.png"),
    ("tiny-town", 4, "tiles/terrain", "tree_green_02.png"),
    ("tiny-town", 15, "tiles/terrain", "tree_autumn_01.png"),
    ("tiny-town", 3, "tiles/terrain", "tree_autumn_02.png"),
    ("tiny-town", 29, "tiles/terrain", "mushroom_red_01.png"),
    ("tiny-town", 1, "tiles/terrain", "grass_flower_01.png"),
    ("tiny-town", 43, "tiles/terrain", "grass_pebble_01.png"),
    ("tiny-town", 12, "tiles/terrain", "dirt_patch_01.png"),
    ("tiny-town", 24, "tiles/terrain", "dirt_patch_02.png"),
    # ── tiny-town：墙 / 窗 / 门 ──
    ("tiny-town", 48, "tiles/props", "wall_stone_01.png"),
    ("tiny-town", 49, "tiles/props", "wall_stone_02.png"),
    ("tiny-town", 52, "tiles/props", "wall_brick_01.png"),
    ("tiny-town", 53, "tiles/props", "wall_brick_02.png"),
    ("tiny-town", 51, "tiles/props", "window_stone_01.png"),
    ("tiny-town", 55, "tiles/props", "window_brick_01.png"),
    ("tiny-town", 84, "tiles/props", "window_wood_01.png"),
    ("tiny-town", 74, "tiles/props", "door_wood_01.png"),
    ("tiny-town", 85, "tiles/props", "door_wood_02.png"),
    # ── tiny-town：栅栏 ──
    ("tiny-town", 47, "tiles/props", "fence_wood_post.png"),
    ("tiny-town", 45, "tiles/props", "fence_wood_rail.png"),
    ("tiny-town", 82, "tiles/props", "fence_end_post.png"),
    # ── tiny-town：道具 ──
    ("tiny-town", 83, "tiles/props", "signboard_01.png"),
    ("tiny-town", 104, "tiles/props", "well_blue_01.png"),
    ("tiny-town", 107, "tiles/props", "chest_open_01.png"),
    ("tiny-town", 130, "tiles/props", "chest_brown_01.png"),
    ("tiny-town", 93, "tiles/props", "coin_01.png"),
    ("tiny-town", 94, "tiles/props", "gold_bag_01.png"),
    ("tiny-town", 92, "tiles/props", "house_small_01.png"),
    ("tiny-town", 115, "tiles/props", "tool_mallet_01.png"),
    ("tiny-town", 116, "tiles/props", "tool_fork_01.png"),
    ("tiny-town", 127, "tiles/props", "tool_shovel_01.png"),
    ("tiny-town", 129, "tiles/props", "tool_axe_02.png"),
    ("tiny-town", 117, "tiles/props", "item_key_01.png"),
    ("tiny-town", 119, "tiles/props", "item_sword_01.png"),
]


def main() -> int:
    BAK.mkdir(parents=True, exist_ok=True)

    # ── 1. 清掉第一版的错误文件 ──
    removed = 0
    for rel in CLEAN_DIRS:
        d = ASSETS / rel
        if not d.is_dir():
            continue
        for f in d.glob("*.png"):
            f.unlink()
            removed += 1
    td = ASSETS / "tiles" / "terrain"
    for name in CLEAN_TERRAIN:
        p = td / f"{name}.png"
        if p.exists():
            p.unlink()
            removed += 1
    print(f"  清理第一版的错误文件：{removed} 个")

    # ── 2. 按修正编号重新提取 ──
    ok = miss = 0
    for pack, n, destdir, name in PLAN:
        src = WIP / pack / "Tiles" / f"tile_{n:04d}.png"
        if not src.exists():
            print(f"  [X] 源缺失 {pack}/tile_{n:04d}")
            miss += 1
            continue
        d = ASSETS / destdir
        d.mkdir(parents=True, exist_ok=True)
        # 留档原件
        shutil.copy2(src, BAK / f"{pack}_{n:04d}_{name}")
        im = Image.open(src).convert("RGBA")
        process(im).save(d / name, "PNG")
        ok += 1

    print(f"  重新提取：{ok} 个成功，{miss} 个缺失")
    print()
    for rel in ("tiles/farmland", "tiles/props"):
        d = ASSETS / rel
        cnt = len(list(d.glob("*.png"))) if d.is_dir() else 0
        print(f"  {rel:<18} {cnt} 张")
    tcnt = len(list(td.glob("*.png")))
    print(f"  {'tiles/terrain':<18} {tcnt} 张")
    return 0 if miss == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
