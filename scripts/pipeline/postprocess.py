#!/usr/bin/env python3
"""
《坎儿井》统一后处理脚本
用法:
    python postprocess.py <输入PNG> [输出PNG]
    python postprocess.py --dir <输入目录>        # 批量处理整个目录
功能:
    1. 把任意像素图降色到 ART_STYLE.md 的 32 色板 (最近邻 RGB)
    2. 清半透明边缘: alpha < 128 的像素直接变全透明, 避免 AI 图/截图的灰边
    3. 不做缩放 (源素材必须是 16 的整数倍, 缩放交给 Godot 整数放大)
"""
import sys, os, glob
from PIL import Image

# ---- 色板 (逐字复制自 assets/ART_STYLE.md 第二节) ----
# 共 34 色 = 原 31 色 + 3 色冬季雪地梯度（见 ART_STYLE.md「冬季雪地」小节）。
# 雪地这一档是实机截图暴露出来的缺口：原色板是暖色系的，没有冷色中性色，
# 于是冬天只能自己造色，结果造出的 8 个灰蓝全部挤在 16 个色阶内（#CDD2DF~#DDE3F0），
# 整片地面没有明暗、看起来像蒙了一层灰。
PALETTE_HEX = [
    # 环境主色
    "#E8C79A", "#D9B382", "#B8935F", "#A88E6B",
    "#DFC398", "#C9A277", "#9E7C55", "#8B6B47", "#6B4F33",
    # 绿洲
    "#8A9B62", "#6E8F55", "#5A8F6B", "#3F6B4C",
    "#7FA34A", "#B5B04E", "#D4A93C",
    # 水
    "#8FC7D6", "#5A9CB0", "#3A7086", "#E8EEF2", "#7A8B78",
    # 火焰山
    "#A8522F", "#C9704A", "#8C3A2A",
    # UI
    "#2B2118", "#3D3024", "#F0E4D0", "#B5A48C",
    "#E0A43C", "#6E9E5A", "#1E1812",
    # 冬季雪地（亮 → 影；配合已有的 #E8EEF2 雪水白 构成 4 级梯度）
    "#F2F7FA", "#D5E0E9", "#AFC2D2",
]

def hx2rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

PALETTE = [hx2rgb(h) for h in PALETTE_HEX]

def nearest(rgb):
    """找色板里最近的颜色 (欧氏距离)"""
    r, g, b = rgb
    best = None; best_d = 1e9
    for pr, pg, pb in PALETTE:
        d = (r-pr)**2 + (g-pg)**2 + (b-pb)**2
        if d < best_d:
            best_d = d; best = (pr, pg, pb)
    return best

def process(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 128:
                px[x, y] = (0, 0, 0, 0)   # 半透明直接清掉
            else:
                nr, ng, nb = nearest((r, g, b))
                px[x, y] = (nr, ng, nb, 255)
    return im

def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__); sys.exit(1)
    if args[0] == "--dir":
        d = args[1]
        files = glob.glob(os.path.join(d, "*.png"))
        for f in files:
            out = f  # 原地覆盖
            process(Image.open(f)).save(out)
            print("ok", out)
    else:
        src = args[0]
        dst = args[1] if len(args) > 1 else src
        process(Image.open(src)).save(dst)
        print("ok", dst)

if __name__ == "__main__":
    main()
