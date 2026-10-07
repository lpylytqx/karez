#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
色板合规审计：扫出所有「用了色板之外颜色」的贴图。

为什么需要：
    色板是《坎儿井》美术风格统一的唯一保障（见 assets/ART_STYLE.md 第二节）。
    只要有一批贴图是绕过管线生成的，就会悄悄跑出色板 ——
    表现不是报错，而是「这块地方看着就是有点不对」，最容易被当成风格问题放过去。
    雪地贴图就是这样漏掉的：它们是冷灰蓝（#D1D7E3 一类），而色板里根本没有这一档，
    于是冬天整片地面发灰、和其余季节不像同一套美术。

关于「不参与检查」的素材（重要，别误以为是漏扫）：
    SCAN_DIRS 只含 tiles / buildings / fx / ui —— 即**像素风**那一类。
    以下两类**刻意**不做像素化，也就不该受 34 色板约束：

      assets/characters/portraits/**  立绘（512x512 暖色油画，见 ART_STYLE.md 第 119 行）
      assets/events/**                事件卡插画（SDXL 生成，见 make_event_art.py）

    加新素材目录时先想清楚它属于哪一类：像素风（进 SCAN_DIRS）还是手绘插画（不进）。

用法：
    .venv\\Scripts\\python.exe scripts\\pipeline\\audit_palette.py           # 只报告
    .venv\\Scripts\\python.exe scripts\\pipeline\\audit_palette.py --strict  # 有违规即返回 1
"""

from __future__ import annotations

import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image  # noqa: E402

from postprocess import PALETTE_HEX  # noqa: E402

ROOT = Path(__file__).resolve().parents[2] / "assets"
SCAN_DIRS = ["tiles", "buildings", "fx", "ui"]
# 立绘按设计不走色板，排除
EXCLUDE_PARTS = {"portraits", "_raw", "_wip", "_reference", "_originals"}


def hex_of(rgb: tuple[int, int, int]) -> str:
    return "#{:02X}{:02X}{:02X}".format(*rgb)


def main() -> int:
    strict = "--strict" in sys.argv
    palette = {c.upper() for c in PALETTE_HEX}

    checked = 0
    offenders: list[tuple[Path, list[str]]] = []
    all_colors: Counter[str] = Counter()

    for sub in SCAN_DIRS:
        base = ROOT / sub
        if not base.exists():
            continue
        for png in sorted(base.rglob("*.png")):
            if any(part in EXCLUDE_PARTS for part in png.parts):
                continue
            # 跳过 Godot 的导入缓存残留
            if png.name.startswith("."):
                continue
            try:
                img = Image.open(png).convert("RGBA")
            except Exception as exc:  # noqa: BLE001
                print(f"  [X] 打不开 {png.name}: {exc}")
                continue

            checked += 1
            used: set[str] = set()
            for r, g, b, a in img.get_flattened_data():
                if a < 128:
                    continue                      # 全透明像素不参与判色
                used.add(hex_of((r, g, b)))
            all_colors.update(used)

            off = sorted(c for c in used if c not in palette)
            if off:
                offenders.append((png.relative_to(ROOT), off))

    print(f"  检查 {checked} 张 PNG（已排除立绘/{'/'.join(sorted(EXCLUDE_PARTS))}）")
    print(f"  色板 {len(palette)} 色\n")

    if not offenders:
        print("  [OK] 全部合规，没有用到色板外的颜色。")
        return 0

    print(f"  [!] {len(offenders)} 张用了色板外的颜色：\n")

    # 按「第一处违规色」聚类，方便看出是同一批贴图的问题
    groups: dict[str, list[Path]] = {}
    for rel, off in offenders:
        groups.setdefault(off[0], []).append(rel)

    for color, files in sorted(groups.items(), key=lambda kv: -len(kv[1])):
        print(f"  {color}   {len(files)} 张")
        for f in files[:6]:
            print(f"      {f}")
        if len(files) > 6:
            print(f"      …另有 {len(files) - 6} 张")
        print()

    all_off = Counter()
    for _rel, off in offenders:
        all_off.update(off)
    print("  违规色汇总（出现文件数 → 颜色）：")
    for color, n in all_off.most_common(20):
        print(f"    {n:>4} 张  {color}")

    return 1 if strict else 0


if __name__ == "__main__":
    raise SystemExit(main())
