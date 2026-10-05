# -*- coding: utf-8 -*-
"""按坐标从 TilesetHouse.png 正确裁出村庄建筑。

背景（同一类错误第四次出现）：
    assets/buildings/ 是项目最初提交 a9051c3 里一次性抽的，
    做法是「从 tileset 上裁任意矩形区域」。结果很多张裁在了建筑的中间，
    拿到的是半截墙 —— 截图里一眼能看出断口。

    用户先后指着「厨房」和「晾房」问「这是啥」，两次都是这个原因。

源文件：_raw/ninja_adventure/.../TilesetHouse.png  (528x368 = 33x23 格，每格 16px)

做法：
    对着带坐标网格的渲染图（tools 里已留脚本）按 (列,行,宽,高) 指定完整的
    单体建筑，裁下来后**缩放到该文件原有的尺寸** —— 尺寸不变，地图布局就不动。
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = (ROOT / "assets" / "_raw" / "ninja_adventure" /
       "Ninja Adventure - Asset Pack" / "Backgrounds" / "Tilesets" / "TilesetHouse.png")
BUILD = ROOT / "assets" / "buildings"

T = 16  # 每格像素

# (目标文件, 列, 行, 宽格, 高格, 说明)
#
# ⚠ 已知未完：stable / grape_drying / bazar_stall_blue / watchtower 四张
# 还没有找到合适的完整建筑。inn 与 warehouse 已确认正确（完整单体建筑）。
# 坐标一律以 _wip/_TilesetHouse_grid.png 上的网格标注为准。
PLAN = [
    ("inn_01.png",             0,  0, 4, 4, "橙顶大屋（带门廊）"),      # 已确认
    ("warehouse_01.png",       4,  0, 4, 4, "黄褐色大屋（宽门洞）"),    # 已确认
    ("stable_01.png",          8,  0, 4, 4, "第三栋橙顶大屋（与驿馆不同款）"),
    ("grape_drying_01.png",   12,  0, 4, 4, "红顶建筑"),
    ("house_resident_01.png",  3,  8, 3, 3, "茅顶圆屋"),
    ("bazar_stall_blue.png",  19,  5, 3, 3, "占位，稍后由红色摊位换色覆盖"),
    ("watchtower_sand_01.png", 0,  8, 1, 3, "土坯墙段（当塔身）"),
]

## 蓝色摊位不再从大图上找 —— 试了三组坐标都只能裁到穹顶中间的一坨棕色。
## 直接由**已经确认正确的红色摊位换色**得到：两个摊位本来就该是一对，
## 换色既保证可辨认，也保证风格一致。
HUE_SWAP = ("bazar_stall_red.png", "bazar_stall_blue.png")


def _hue_shift_to_blue(im: Image.Image) -> Image.Image:
    """把偏红的像素整体转到蓝色。只动色相，明度与饱和度保持不变。"""
    px = im.load()
    w, h = im.size
    out = im.copy()
    op = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            # 只有明显偏红的像素参与换色（木架等中性色保持原样）
            if r > g + 20 and r > b + 20:
                op[x, y] = (b, g, r, a)   # 红蓝通道互换
    return out


def main() -> int:
    if not SRC.exists():
        print(f"  [X] 源不存在：{SRC}")
        return 1
    sheet = Image.open(SRC).convert("RGBA")
    print(f"  源 {SRC.name} = {sheet.size} ({sheet.width//T} x {sheet.height//T} 格)\n")

    for name, cx, cy, cw, chh, what in PLAN:
        dst = BUILD / name
        box = (cx * T, cy * T, (cx + cw) * T, (cy + chh) * T)
        crop = sheet.crop(box)
        old = Image.open(dst).size if dst.exists() else crop.size
        if old != crop.size:
            crop = crop.resize(old, Image.NEAREST)
        crop.save(dst)
        print(f"  {name:<24} 格({cx:>2},{cy:>2}) {cw}x{chh}  {what:<18} -> {crop.size}")
    # 收尾：由红色摊位换色得到蓝色摊位
    src_name, dst_name = HUE_SWAP
    sp, dp = BUILD / src_name, BUILD / dst_name
    if sp.exists():
        _hue_shift_to_blue(Image.open(sp).convert("RGBA")).save(dp)
        print(f"  {dst_name:<24} 由 {src_name} 换色          -> "
              f"{Image.open(dp).size}")

    print(f"\n  重裁 {len(PLAN)} 张 + 换色 1 张")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
