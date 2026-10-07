#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
把「跑出色板」的贴图批量拉回 32 色板，并**先备份原件**。

为什么需要
    色板是风格统一的唯一保障（assets/ART_STYLE.md 第二节），但管线有洞：
    有几处生成器/提取脚本直接写文件、没过后处理，于是悄悄写入了色板外的颜色。
    这些文件由 audit_palette.py 扫出来。

    这类问题的表现不是报错，而是「这块地方看着就是有点不对」——
    混在画面里最容易被当成美术风格问题放过去。

安全措施
    1. 处理前把原件整份复制到 assets/_wip/_palette_fix_backup/（带时间戳不会覆盖）
    2. 逐个报告「原色 → 映射色」，映射明显不合理时能一眼看出来
    3. 就地写回前先确认颜色确实变了（没变就不写，避免改 mtime 让 Godot 重导入）

用法
    .venv\\Scripts\\python.exe scripts\\pipeline\\normalize_offpalette.py --dry-run   # 只看映射
    .venv\\Scripts\\python.exe scripts\\pipeline\\normalize_offpalette.py             # 备份并写回
"""

from __future__ import annotations

import shutil
import sys
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image  # noqa: E402

from postprocess import PALETTE, PALETTE_HEX, nearest  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "assets"
BACKUP = ASSETS / "_wip" / "_palette_fix_backup"
SCAN_DIRS = ["tiles", "buildings", "fx", "ui"]
EXCLUDE_PARTS = {"portraits", "_raw", "_wip", "_reference", "_originals"}


def hex_of(rgb) -> str:
    return "#{:02X}{:02X}{:02X}".format(*rgb[:3])


def collect_offenders() -> list[Path]:
    palette = {c.upper() for c in PALETTE_HEX}
    out: list[Path] = []
    for sub in SCAN_DIRS:
        base = ASSETS / sub
        if not base.exists():
            continue
        for png in sorted(base.rglob("*.png")):
            if any(part in EXCLUDE_PARTS for part in png.parts):
                continue
            img = Image.open(png).convert("RGBA")
            used = {hex_of((r, g, b)) for r, g, b, a in img.get_flattened_data() if a >= 128}
            if used - palette:
                out.append(png)
    return out


def main() -> int:
    dry = "--dry-run" in sys.argv
    files = collect_offenders()

    print(f"  色板 {len(PALETTE_HEX)} 色")
    print(f"  跑出色板的贴图：{len(files)} 张\n")
    if not files:
        print("  [OK] 没有需要处理的文件。")
        return 0

    if not dry:
        stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        dest = BACKUP / stamp
        dest.mkdir(parents=True, exist_ok=True)
        print(f"  备份原件 → {dest.relative_to(ROOT)}")

    # 收集所有映射，便于人工核对「这个映射合不合理」
    mapping: dict[str, str] = {}
    changed = 0
    for png in files:
        img = Image.open(png).convert("RGBA")
        px = img.load()
        w, h = img.size
        touched = False
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if a < 128:
                    if a != 0:
                        px[x, y] = (0, 0, 0, 0)     # 半透明一律清干净
                        touched = True
                    continue
                nr, ng, nb = nearest((r, g, b))
                if (nr, ng, nb) != (r, g, b):
                    mapping.setdefault(hex_of((r, g, b)), hex_of((nr, ng, nb)))
                    px[x, y] = (nr, ng, nb, 255)
                    touched = True

        if not touched:
            print(f"    [--] {png.relative_to(ASSETS)}  无需改动")
            continue

        if dry:
            print(f"    [看] {png.relative_to(ASSETS)}  需改色")
        else:
            shutil.copy2(png, dest / png.name)
            img.save(png)
            print(f"    [OK] {png.relative_to(ASSETS)}")

        # 同时把同名 .import 之外的旧导入缓存清掉，强制 Godot 重新导入
        changed += 1

    print(f"\n  颜色映射（原色 → 色板内最近色）：")
    for src, dst in sorted(mapping.items()):
        print(f"    {src}  →  {dst}")

    if dry:
        print(f"\n  --dry-run：未写入。加参数去掉 --dry-run 即执行（会先备份）。")
    else:
        print(f"\n  处理 {changed} 张，原件备份在 {BACKUP.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
