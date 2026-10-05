# -*- coding: utf-8 -*-
"""重切 assets/buildings 里挑错的几张。

背景（同一类错误第三次出现，值得留档）：
    buildings/ 是项目最初提交 a9051c3 里一次性抽的，那时还没有「按编号核对」的规矩。
    后来 reextract_tiles.py 复查过 tiles/，但**从未复查 buildings/**。
    结果这几张一直错着：
        kitchen_01.png        实际是一堆不相干的图块（绿屋顶碎片 + 棕盒子 + 两块砖墙）
        bazar_stall_red.png   实际是一丛树叶树枝，不是摊位
        house_resident_01.png 实际是建筑立面的一个残块
        campfire_01.png       实际是一汪水加一坨橙色

    用户在地图上看到「厨房」位置那一坨认不出的东西，问「这是啥」——
    放大核对才发现根因在这。

修法：对着带编号的全量图块表（tools 里已留渲染脚本）按编号重挑，
      再按原尺寸放大，保证不影响既有布局。
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
WIP = ROOT / "assets" / "_wip"
BUILD = ROOT / "assets" / "buildings"

# (包, tile编号, 目标文件, 这是什么)
PLAN = [
    ("tiny-town", 83, "bazar_stall_red.png", "带雨棚的摊位"),
    ("tiny-town", 22, "campfire_01.png", "橙黄色火焰"),
    ("tiny-town", 85, "house_resident_01.png", "带门的砖房正面"),
    ("tiny-town", 107, "kitchen_01.png", "吊锅（明确的炊具）"),
]


def main() -> int:
    ok = 0
    for pack, n, name, what in PLAN:
        src = WIP / pack / "Tiles" / f"tile_{n:04d}.png"
        dst = BUILD / name
        if not src.exists():
            print(f"  [X] {name}: 源不存在 {src}")
            continue
        old = Image.open(dst).size if dst.exists() else None
        im = Image.open(src).convert("RGBA")
        # 按原尺寸放大，避免改变地图上的占位大小
        if old and (old[0] % im.width == 0) and (old[1] % im.height == 0):
            k = old[0] // im.width
            if k > 1:
                im = im.resize((im.width * k, im.height * k), Image.NEAREST)
        im.save(dst)
        print(f"  {name:<26} {pack} #{n:<4} {what:<14} {old} -> {im.size}")
        ok += 1
    print(f"\n  重切 {ok}/{len(PLAN)} 张")
    return 0 if ok == len(PLAN) else 1


if __name__ == "__main__":
    raise SystemExit(main())
