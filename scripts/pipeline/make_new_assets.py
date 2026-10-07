#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""补三张缺失的像素素材：奏乐台、双峰驼、绒山羊。

为什么要补：
  · 奏乐台（numbers.json 的 yinletai）：现有素材里没有任何一张能当乐器台用。
    拿巴扎摊位糊上去会让游戏在画面上对玩家撒谎（这个项目已经栽过 8 次
    「贴图名字与内容对不上」）。
  · 双峰驼 / 绒山羊：畜牧系统里这两种牲畜有数值、能在面板上看到，
    但地图上画不出来（只有羊/驴/鸡的图）—— 等于系统有一半是隐形的。

画法：用 **ASCII 图**定义每个像素，不是盲写坐标。
  好处有两个：形状一眼能读、而且每行宽度可以断言 ——
  盲写坐标时一个手滑就是把整张图挪歪，看图才发现。

颜色全部取自 34 色板（`postprocess.PALETTE_HEX`），脚本会**断言**用到的
每个颜色都在色板里，否则直接报错退出。这样不可能产出跑出色板的图。

用法：.venv\\Scripts\\python.exe scripts\\pipeline\\make_new_assets.py
输出：assets/buildings/yinletai_01.png（32x32）
      assets/tiles/props/animal_camel_01.png（16x16）
      assets/tiles/props/animal_goat_01.png（16x16）
      assets/_wip/_check_new_assets.png（放大对照图，供肉眼核对）
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image  # noqa: E402

from postprocess import PALETTE_HEX  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
PAL = {c.upper() for c in PALETTE_HEX}

# ---------------------------------------------------------------------------
# 奏乐台 32x32
# ---------------------------------------------------------------------------
# 形制：一座低矮的土台，上面铺艾德莱斯绸花毡，放一只手鼓、靠一把热瓦普。
# 为什么不是"一座华丽的舞台"：这是村里自己搭的台子，不是剧院 ——
# 土台 + 花毡 + 两件乐器，反而比精雕细琢更像"木卡姆在这儿响起"。
YINLETAI = [
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    ".............ww.................",
    "...........wwWWww...........nn..",
    "..........wWWWWWWw.........nNn..",
    "..........wWWWWWWw.........nNn..",
    "..........wWWWWWWw.......nnNn...",
    "...........wwWWww......nnNNn....",
    ".............ww......nnNNn......",
    "...................nnNNn........",
    "..........gggggggggNNn..........",
    "........ggGGGGGGGGGgn...........",
    "......ggGGGGGGGGGGGGgg..........",
    "....ggGGGGGGGGGGGGGGGGgg........",
    "...gGGGGGGGGGGGGGGGGGGGGg.......",
    "..gGGGrrGGGrrGGGrrGGGrrGGGg.....",
    "..gGGGrRrGGrRrGGrRrGGrRrGGg.....",
    "..gGGGrrGGGrrGGGrrGGGrrGGGg.....",
    "..gGGGGGGGGGGGGGGGGGGGGGGGg.....",
    "..gGGGGGGGGGGGGGGGGGGGGGGGg.....",
    "...gggggggggggggggggggggggg.....",
    "....dd...................dd.....",
    "....dd...................dd.....",
    "....dd...................dd.....",
    "....dd...................dd.....",
    "................................",
]
YINLETAI_KEY = {
    "w": "#8B6B47",   # 鼓身木框（暗）
    "W": "#C9A277",   # 鼓面/木框（亮）
    "g": "#6B4F33",   # 花毡边（暗棕）
    "G": "#A8522F",   # 花毡主色（艾德莱斯红）
    "r": "#C9704A",   # 花纹（橙红）
    "R": "#E0A43C",   # 花纹（金）
    "n": "#8B6B47",   # 热瓦普琴颈
    "N": "#DFC398",   # 琴颈高光
    "d": "#3D3024",   # 台腿
}

# ---------------------------------------------------------------------------
# 双峰驼 16x16（侧视，头朝右）
# ---------------------------------------------------------------------------
# 15 色板里最像骆驼的就这一组驼褐。双峰驼的辨识点全在**双峰 + 长脖子**，
# 所以峰要**突出背线**、脖子要细长。
#
# ⚠ 第一版失败了：整个身子一个平色，两个峰完全糊进躯干里，
#   放大一看就是"一坨有腿的驼色方块"，说是狗也行、说是羊也行。
#   这一版把身子分成「受光面 B / 阴影面 H」两种色，峰的轮廓才浮得出来。
CAMEL = [
    "................",
    "..........oo....",
    ".........oBWo...",
    ".........oBWWo..",
    "..........oBo...",
    "..........oWo...",
    ".oo...oo..oWo...",
    "oBBo.oBBo.oWo...",
    "oBBBBoBBBBoWo...",
    "oHHHHHHHHHHHo...",
    ".oHHHHHHHHHo....",
    ".oHoHHoHHoH.....",
    "..o..o..o.o.....",
    "..o..o..o.o.....",
    "..o..o..o.o.....",
    "................",
]
CAMEL_KEY = {
    "o": "#3D3024",   # 轮廓
    "B": "#C9A277",   # 驼毛·受光面
    "W": "#DFC398",   # 头部高光
    "H": "#8B6B47",   # 驼毛·阴影面（让峰与腹部读得出来）
}

# 辨识点是**弯角**：角要够大、且用深色，否则 16px 下就退化成一只白羊。
# 体色用最浅的奶白，和羊（驼褐）在同一片草地上一眼能分开。
#
# ⚠ 第一版同样失败了：角只有 2px、颜色又和轮廓一样，放大后完全看不见。
#   这一版角占 4px 宽、分两段向后弯。
GOAT = [
    "................",
    "....oooo........",
    "...oo..oo.......",
    "..oo....oWWo....",
    ".........oWWo...",
    "........oWWWWo..",
    ".......oWWWWWo..",
    "..oWWWWWWWWWWo..",
    ".oWWWWWWWWWWWo..",
    ".oWWWWWWWWWWo...",
    "..oBBBBBBBBo....",
    "..o.o.o.o.......",
    "..o.o.o.o.......",
    "..o.o.o.o.......",
    "................",
    "................",
]
GOAT_KEY = {
    "o": "#3D3024",   # 轮廓与角
    "W": "#F0E4D0",   # 奶白体色·受光面
    "B": "#E8C79A",   # 奶白体色·阴影面
}

ASSETS = [
    ("yinletai_01.png", "buildings", YINLETAI, YINLETAI_KEY, 32, 32),
    ("animal_camel_01.png", "tiles/props", CAMEL, CAMEL_KEY, 16, 16),
    ("animal_goat_01.png", "tiles/props", GOAT, GOAT_KEY, 16, 16),
]

# ---------------------------------------------------------------------------
# 畜栏 32x32
# ---------------------------------------------------------------------------
# 为什么必须新画：`assets/buildings/fence_wood_01.png` 名字像栅栏，
# **实际是一块房子墙面的碎片**（橙色墙 + 窗格，93% 不透明）。
# 直接拿它当畜栏就是又一次「贴图名字与内容对不上」—— 这个项目已经栽过 9 次，
# 所以用之前先看图，看完就决定自己画一张。
#
# 形制：两道横栏（远栏+近栏）+ 立柱，栏里两只羊。远栏细、近栏粗，
# 这样 32px 下也有"围起来一块地"的纵深，而不是一个方框。
YANGJUAN = [
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    ".oooooooooooooooooooooooooooooo.",
    ".oWWWWWWWWWWWWWWWWWWWWWWWWWWWWo.",
    ".oooooooooooooooooooooooooooooo.",
    "..o..........................o..",
    "..o...SS....................o...",
    "..o..sSSs...................o...",
    "..o...ss....................o...",
    "..o..........................o..",
    "..o.........SS..............o...",
    "..o........sSSs.............o...",
    "..o.........ss..............o...",
    "..o..........................o..",
    ".oooooooooooooooooooooooooooooo.",
    ".oWWWWWWWWWWWWWWWWWWWWWWWWWWWWo.",
    ".oWWWWWWWWWWWWWWWWWWWWWWWWWWWWo.",
    ".oooooooooooooooooooooooooooooo.",
    "................................",
    "................................",
]
YANGJUAN_KEY = {
    "o": "#3D3024",   # 轮廓
    "W": "#DFC398",   # 木栏受光面
    "S": "#F0E4D0",   # 羊毛（亮）
    "s": "#E8C79A",   # 羊毛（暗）
}
ASSETS.append(("yangjuan_01.png", "buildings", YANGJUAN, YANGJUAN_KEY, 32, 32))


def hex_to_rgba(h: str) -> tuple[int, int, int, int]:
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def build(rows: list[str], key: dict[str, str], w: int, h: int) -> Image.Image:
    assert len(rows) == h, f"行数应为 {h}，实际 {len(rows)}"
    for i, r in enumerate(rows):
        assert len(r) == w, f"第 {i} 行宽度应为 {w}，实际 {len(r)}：{r!r}"
    # 颜色断言：不在 34 色板里的颜色直接报错，绝不产出跑色的图
    for k, v in key.items():
        assert v.upper() in PAL, f"纹素 {k} 的颜色 {v} 不在色板里"
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = im.load()
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch == ".":
                continue
            assert ch in key, f"第 {y} 行出现了未定义的纹素 {ch!r}"
            px[x, y] = hex_to_rgba(key[ch])
    return im


def main() -> None:
    made: list[Image.Image] = []
    for name, sub, rows, key, w, h in ASSETS:
        im = build(rows, key, w, h)
        out = ROOT / "assets" / sub / name
        out.parent.mkdir(parents=True, exist_ok=True)
        im.save(out)
        opaque = sum(1 for p in im.getdata() if p[3] > 0)
        cols = len({p for p in im.getdata() if p[3] > 0})
        print(f"  {name:<26} {w}x{h}  不透明 {opaque:>4} px  用色 {cols} 种  -> {sub}/")
        made.append(im)

    # 放大对照图：8 倍、最近邻。必须看图 —— 这个项目里"贴图名字与内容对不上"
    # 已经栽过 8 次，全部是没看图造成的。
    Z = 8
    pad = 6
    sheet_w = sum(im.width * Z + pad for im in made) + pad
    sheet_h = max(im.height * Z for im in made) + pad * 2 + 14
    sheet = Image.new("RGBA", (sheet_w, sheet_h), (40, 34, 26, 255))
    x = pad
    for im in made:
        big = im.resize((im.width * Z, im.height * Z), Image.NEAREST)
        sheet.alpha_composite(big, (x, pad))
        x += im.width * Z + pad
    check = ROOT / "assets" / "_wip" / "_check_new_assets.png"
    sheet.save(check)
    print(f"  对照图（放大 {Z} 倍）-> {check}")


if __name__ == "__main__":
    main()
