"""重新生成沙漠枯树 —— 原来的 tree_dead_01.png 是一张碎片。

【怎么发现的】
用户问「为什么树的右侧都被切掉了」。没有猜，量了一下：
    tree_dead_01.png  48x48
      最右一列 不透明像素 36 个   <- 贴边，说明是被裁断的
      最左一列 不透明像素  6 个
放大看：右侧一条硬直边贯穿整个高度，树枝在半截断掉 ——
**这张素材本身就是一个更大枯树的碎片**，跟当初那张假营火是同一类问题。
（make_trees.py 里原先把 tree_dead_01 列为「素材里能用的完整树」，这个判断是错的。）

【做法】程序化生成一棵完整的枯树：
  · 递归分叉的枝干，越往上越细、越短 —— 这是树而不是"一根柱子上插了几根棍"
  · 不带叶子（枯树），只用两种棕色，和项目里其余树一致
  · **四周留边**：画完检查四条边，任何一条有像素就报错，
    免得又做出"看着像被切了"的东西 —— 这次的教训就在这
  · 固定种子，每次跑出来一样

尺寸 48x48（map_view 的沙漠枯树按这个尺寸摆）。
"""
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[2] / "assets" / "tiles" / "nature"
S = 48

TRUNK = (139, 107, 71, 255)          # 与 make_trees.py 的 TRUNK 一致
TRUNK_DARK = (107, 79, 51, 255)


def branch(d: ImageDraw.ImageDraw, x: float, y: float, ang: float,
           length: float, width: float, depth: int, rnd: random.Random) -> None:
    """递归画一根枝：从 (x,y) 沿 ang 方向长 length，随后自分叉。"""
    if depth <= 0 or length < 3.0:
        return
    x2 = x + math.cos(ang) * length
    y2 = y + math.sin(ang) * length
    col = TRUNK if depth > 2 else TRUNK_DARK
    d.line([(x, y), (x2, y2)], fill=col, width=max(1, int(round(width))))
    # 越往上分两叉，左右各偏一点
    for side in (-1, 1):
        if rnd.random() < (0.92 if depth > 2 else 0.55):
            na = ang + side * rnd.uniform(0.30, 0.72)
            branch(d, x2, y2, na,
                   length * rnd.uniform(0.58, 0.76),
                   width * 0.62, depth - 1, rnd)


def make_dead_tree() -> Image.Image:
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    rnd = random.Random(20261005)
    # 树干从底部中央起，向上略偏 —— 完全笔直会像电线杆
    bx = S / 2.0
    by = S - 2.0
    branch(d, bx, by, -math.pi / 2 + rnd.uniform(-0.06, 0.06),
           14.0, 5.0, 5, rnd)
    return im


def edge_report(im: Image.Image) -> list:
    """四条边各有几个不透明像素 —— 非零就是又被切了。"""
    a = im.load()
    bad = []
    for name, pts in (
        ("上", [(x, 0) for x in range(im.width)]),
        ("下", [(x, im.height - 1) for x in range(im.width)]),
        ("左", [(0, y) for y in range(im.height)]),
        ("右", [(im.width - 1, y) for y in range(im.height)]),
    ):
        n = sum(1 for (x, y) in pts if a[x, y][3] > 0)
        if n:
            bad.append((name, n))
    return bad


def main() -> None:
    im = make_dead_tree()
    bad = edge_report(im)
    p = OUT / "tree_dead_01.png"
    im.save(p)
    print("  -> %s  %dx%d" % (p, im.width, im.height))
    if bad:
        print("     [X] 仍然贴边（会被看成被切）: " +
              "、".join("%s边%dpx" % (n, c) for n, c in bad))
    else:
        print("     四周都有留白，不会再看着像被切")


if __name__ == "__main__":
    main()
