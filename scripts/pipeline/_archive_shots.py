#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
（临时工具）把 Godot 渲出的截图归档进 docs/screenshots/，并合成四季对比图。

Godot 把截图写在 user:// 下，文件名是英文的；这里重命名成中文可读的名字，
再拼一张 2x2 的四季对比表 —— 单张截图看不出「换季到底换了什么」，
四张并排才有意义。
"""
from __future__ import annotations

import sys as _sys
from pathlib import Path as _Path
_sys.path.insert(0, str(_Path(__file__).resolve().parent))
from _root import ROOT  # 路径唯一解析处，不再写死盘符
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = ROOT
SRC = Path.home() / "AppData" / "Roaming" / "Godot" / "app_userdata" / "坎儿井"
DST = ROOT / "docs" / "screenshots"

# user:// 文件名 -> 归档文件名
COPY = [
    ("oasis_0.png", "S6_开局_0段竖井.png"),
    ("oasis_2.png", "S6_2段竖井.png"),
    ("oasis_4.png", "S6_4段竖井.png"),
    ("oasis_6.png", "S6_6段竖井_绿洲边缘过渡.png"),
]

LABELS = {
    "spring": "SPRING  (more flowers)",
    "summer": "SUMMER  (base)",
    "autumn": "AUTUMN  (golden trees)",
    "winter": "WINTER  (snow tiles, regenerated)",
}
ORDER = ["spring", "summer", "autumn", "winter"]


def main() -> int:
    DST.mkdir(parents=True, exist_ok=True)

    # 1. 归档单张
    print("  归档单张截图：")
    for src_name, dst_name in COPY:
        s = SRC / src_name
        if not s.exists():
            print(f"    [X] 缺 {src_name}")
            continue
        shutil.copy2(s, DST / dst_name)
        print(f"    [OK] {dst_name}")

    # 2. 四季对比：2x2
    tiles = []
    for key in ORDER:
        p = SRC / f"season_{key}.png"
        if not p.exists():
            print(f"    [X] 缺 season_{key}.png")
            return 1
        tiles.append(Image.open(p).convert("RGB"))

    # 单张缩到一半，2x2 后正好是一屏大小
    w, h = tiles[0].size
    tw, th = w // 2, h // 2
    pad = 6
    label_h = 22
    cell_h = th + label_h
    sheet = Image.new("RGB", (tw * 2 + pad * 3, cell_h * 2 + pad * 3), (26, 20, 16))
    draw = ImageDraw.Draw(sheet)

    for i, (key, img) in enumerate(zip(ORDER, tiles)):
        x = pad + (i % 2) * (tw + pad)
        y = pad + (i // 2) * (cell_h + pad)
        sheet.paste(img.resize((tw, th), Image.LANCZOS), (x, y))
        # 用 PIL 内置位图字体：只支持 ASCII，所以标签写英文
        draw.text((x + 2, y + th + 4), LABELS[key], fill=(240, 228, 208))

    out = DST / "S6_四季对比_雪地重做.png"
    sheet.save(out)
    print(f"\n  四季对比：{out}  ({sheet.width}x{sheet.height})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
