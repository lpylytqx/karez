#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
把 SDXL 生成的事件插画裁切成卡片尺寸，归档到 assets/events/。

为什么事件插画走 AI 生图而不是过程化生成
    地图贴图要的是 16px 网格精确、34 色板精确、形状可控 —— 这三件事过程化生成完胜，
    试过 SDXL + 最近邻降采样，细节在贴图尺寸下会塌成一团颜色涂抹。
    但**事件卡插画反过来**：它不受像素网格约束、要的就是手绘感、显示尺寸也够大（200x240），
    这正是扩散模型擅长的位置。和立绘（512x512 暖色油画）是同一个道理。

裁切规则
    · 底部去掉 5%：扩散模型爱在右下角留一个签名/水印样的小标记，裁掉最省事
    · 按目标宽高比居中裁，再缩到卡片尺寸
    · 保留 JPG/PNG 原样，**不做降色** —— 插画和立绘一样，刻意不走 34 色板
      （见 assets/ART_STYLE.md：像素风只约束地图与 UI，手绘插画独立）

输出：assets/events/{manage,explore,diplomacy,crisis,night,winter}.png
用法：
    .venv\\Scripts\\python.exe scripts\\pipeline\\make_event_art.py
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
GEN = ROOT / "dsh-image-gen"
OUT = ROOT / "assets" / "events"

# 卡片左侧插画区的尺寸。改这里要同步改 hud.gd 的 EVENT_ART_W / EVENT_ART_H。
#
# ⚠ 尺寸是按 **640x360 逻辑像素**定的（HUD 的坐标空间），不是按 1280x720 窗口。
#   第一版设成 200x240 + 卡片 760 宽，直接超出 640 宽的屏幕、文字被切在右缘。
CARD_W, CARD_H = 150, 200
# 底部裁掉的比例（去签名/水印）
TRIM_BOTTOM = 0.05

# 归档名 -> 生成的原始文件
ART = {
    "manage":    "image-48c4065d.png",   # 绿洲农田与劳作的村落
    "explore":   "image-3297f4d3.png",   # 沙丘上的驼队
    "diplomacy": "image-984dca8a.png",   # 巴扎里谈生意的两个商人
    "crisis":    "image-3c45dceb.png",   # 压过来的沙暴
    "night":     "image-138c40bf.png",   # 篝火边的乐师
    "winter":    "image-6a38f34d.png",   # 雪后的平顶生土村落
}


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    target = CARD_W / CARD_H
    made = 0

    for name, src_name in ART.items():
        src = GEN / src_name
        if not src.exists():
            print(f"  [X] 缺源图 {src_name}")
            continue

        im = Image.open(src).convert("RGB")
        w, h = im.size
        # 先去掉底部（签名/水印），得到可用高度
        usable_h = int(h * (1.0 - TRIM_BOTTOM))
        # 按目标宽高比居中裁宽
        crop_w = min(w, int(usable_h * target))
        left = (w - crop_w) // 2
        im2 = im.crop((left, 0, left + crop_w, usable_h)).resize(
            (CARD_W, CARD_H), Image.LANCZOS)

        dst = OUT / f"{name}.png"
        im2.save(dst)
        print(f"  [OK] {name:<10} {src_name}  {w}x{h} → 裁 {crop_w}x{usable_h} → "
              f"{CARD_W}x{CARD_H}  {dst.stat().st_size / 1024:.0f} KB")
        made += 1

    print(f"\n  归档 {made} 张事件插画 → {OUT.relative_to(ROOT)}")
    if made != len(ART):
        print("  [!] 有源图缺失，未全部归档")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
