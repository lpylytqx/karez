#!/usr/bin/env python -u
# -*- coding: utf-8 -*-
"""按"图片框的比例"裁实机截图 —— 修掉展示稿里"图缩小、四周留大白边"的问题。

问题（量出来的，不是看出来的）：
  · 第 2 页底部框 10.4×1.06 英寸 = **9.8:1**，塞一张 16:9 的截图 →
    图被缩到 1.88 英寸宽，两边各空 4 英寸。
  · 第 4 页画面墙每格 5.10×1.92 = **2.66:1**，16:9 塞进去 → 两边各空 0.84 英寸。
  · 第 9 页右下框 4.0×1.65 = 2.42:1，同样留空。
`fit_box()` 的规则是"按图自身比例缩进框内，不裁不拉伸" —— 规则本身没错，
**错在图的比例和框不匹配**。所以正确做法是**裁图去适配框**，而不是改 fit_box。

顺带把 HUD 裁掉：小图上的顶栏数字与右侧按钮只有几个像素高，投出来就是一团噪点。
游戏世界的区域是 x 0..864、y 156..536（逻辑 640×360 ×2 后，去掉顶栏 0..156、
右栏 864..1280、底栏 536..720）。

大图页（封面 / 战斗 / 收尾）**不裁** —— 那些地方 HUD 清晰可读，正是"这是真跑起来的
游戏"的证据。
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import ROOT  # noqa: E402

from PIL import Image  # noqa: E402

SHOTS = ROOT / "docs" / "screenshots"
OUT = ROOT / "deliverables" / "assets" / "crops"

# 游戏世界区（去掉 HUD 三面）
WORLD = (0, 156, 864, 536)      # 864 x 380 = 2.27:1

# 目标：(源图, 目标宽高比, 输出名)
JOBS = [
    ("S10_deck_A_绿洲全景", 10.4 / 1.06, "p2_绿洲横带.png", None),      # 第2页：用整幅宽
    ("S9_animal_A_有牲畜", 5.10 / 1.92, "p4_畜牧.png", WORLD),
    ("S9_animal_E_木卡姆", 5.10 / 1.92, "p4_木卡姆.png", WORLD),
    ("S10_deck_D_御敌布阵", 5.10 / 1.92, "p4_御敌.png", WORLD),
    ("S9_animal_C_灾难日志", 5.10 / 1.92, "p4_灾难.png", WORLD),
    ("S9_animal_E_木卡姆", 2.68 / 1.62, "p7_木卡姆.png", WORLD),
    ("S9_animal_A_有牲畜", 2.68 / 1.62, "p7_畜牧.png", WORLD),
    ("S10_deck_C_事件卡", 2.68 / 1.62, "p7_事件卡.png", WORLD),
    ("S11_建造菜单", 4.0 / 1.65, "p9_建造.png", WORLD),
]


def crop_to(im: Image.Image, ar: float, region) -> Image.Image:
    """在 region 内取**最大的、指定宽高比的、居中的**矩形。"""
    x0, y0, x1, y1 = region or (0, 0, im.width, im.height)
    w, h = x1 - x0, y1 - y0
    if w / h > ar:            # 区域太宽 → 收窄宽度
        nw, nh = int(h * ar), h
    else:                     # 区域太矮 → 压低高度
        nw, nh = w, int(w / ar)
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    return im.crop((cx - nw // 2, cy - nh // 2, cx - nw // 2 + nw, cy - nh // 2 + nh))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for stem, ar, out, region in JOBS:
        src = SHOTS / (stem + ".png")
        if not src.exists():
            print("  [缺] %s" % src.name)
            continue
        with Image.open(src) as im:
            c = crop_to(im.convert("RGB"), ar, region)
        c.save(OUT / out)
        print("  %-22s %-14s -> %-16s %s  比例 %.2f（目标 %.2f）"
              % (stem, "%dx%d" % Image.open(src).size, out, c.size,
                 c.width / c.height, ar))
    print("\n  裁图 %d 张 -> %s" % (len(JOBS), OUT))


if __name__ == "__main__":
    main()
