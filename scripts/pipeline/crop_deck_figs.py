#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""给 PPT 用的截图统一裁剪成「窄一点」的比例。

两个理由：
  1. dsh-ppt 的 image-right 布局里图片框偏窄，直接塞 16:9 的全屏截图会**从右侧溢出**画布
     （渲染核对时发现：标题和截图右边缘都被切掉）。裁成 4:3 / 竖构图就不挤了。
  2. 全屏截图里有一大圈没信息的边（沙漠、HUD 空白），裁掉中心内容反而更清楚。

⚠ 顺带发现一个错误：文档目录里的 `S9_animal_D_牧场.png` 里**其实是灾难通告卡** ——
   拍摄脚本在 D 镜头前没有关掉 C 的通告卡，而我只核对过 C 就以为 D 是对的。
   所以本次不再引用那张「牧场」图，改用确认过的 `S9_animal_A_有牲畜.png`。
   （这条教训：**每张要交付的图都得自己看过，不能靠文件名**。）
"""
import sys as _sys
from pathlib import Path as _Path
_sys.path.insert(0, str(_Path(__file__).resolve().parent))
from _root import ROOT  # 路径唯一解析处，不再写死盘符
from pathlib import Path

from PIL import Image

S = Path(str(ROOT / "docs/screenshots"))
OUT = Path(str(ROOT / "deliverables/assets/figs"))
OUT.mkdir(parents=True, exist_ok=True)

# 规则（四条，全是渲染核对出来的）：
#   1. **左边从 0 或极小开始**，否则界面文字的左半边会被切
#      （第一版把横幅切成了「砍之战」「阵 5/5」）。
#   2. dsh-ppt 的 image-right 版式里，图片框**又高又窄** —— 图按高度撑开就横向溢出，
#      所以 1.19~1.42 的横构图**照样被右裁**。要完整显示必须是**竖构图**。
#   3. 竖构图只适合本来就竖着的内容（各种右侧面板）。绿洲、战场是横构图题材，
#      硬裁成竖条等于毁掉画面 —— **宁可不放图**，那些页就保持纯文字。
#   4. 裁完必须逐张看过。只看 PPT 缩略对照图太小，看不出文字被切。
MAX_ASPECT = 0.70

JOBS = {
    # 竖构图：都是右侧那一条面板，正好是竖的
    "fig_herd.png":    ("S9_animal_A_有牲畜.png",  (880, 110, 1280, 720)),
    "fig_jobs.png":    ("S10_deck_B_分工面板.png", (900, 120, 1280, 710)),
    "fig_muqam.png":   ("S9_animal_E_木卡姆.png",  (880, 100, 1280, 720)),
    # 灾难卡：裁**插画那一侧**（x 40~500）。
    # 第一版裁的是右边文字侧，把本地 SDXL 生成的那张沙暴插画整个裁掉了 ——
    # 而它恰恰是这张图最值钱的部分（AIGC 赛项要看的正是它）。
    "fig_disaster.png": ("S9_animal_C_灾难日志.png", (30, 45, 500, 720)),
    # 封面用：横构图 + cover 裁切，只当装饰，切掉不心疼
    "fig_oasis.png":   ("S10_deck_A_绿洲全景.png", (0, 0, 1280, 720)),
}

print("  裁剪结果：")
for out, (src, box) in JOBS.items():
    p = S / src
    if not p.exists():
        print("    [缺] %s" % src)
        continue
    im = Image.open(p).convert("RGB").crop(box)
    # 兜底：宽了就从右边收，保证不超 MAX_ASPECT（宁少放一点，也不要被版式裁）
    if im.width / im.height > MAX_ASPECT:
        want_w = int(round(im.height * MAX_ASPECT))
        over = im.width - want_w
        im = im.crop((over // 2, 0, im.width - (over - over // 2), im.height))
    # 缩到最多 900px 高，避免 PPT 体积膨胀
    if im.height > 900:
        im = im.resize((int(im.width * 900 / im.height), 900), Image.LANCZOS)
    im.save(OUT / out)
    print("    %-18s %-28s %s  %.2f:1" % (out, src, im.size, im.width / im.height))
