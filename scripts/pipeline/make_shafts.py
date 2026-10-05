"""重新生成竖井贴图 —— 从「黑方块」改成俯视的井口。

问题（用户截图指出）：
  原来的 well_shaft_01.png 是 32x32，**70.3% 的像素是纯黑**，
  底下 2/3 是一整块深色方块，只有上沿一条锯齿状土色边。
  在 640x360 的地图上读起来就是一个**黑箱子**，不像一口井。

正确的读法：
  坎儿井的竖井是**俯视**看下去的 —— 挖出来的土在井口周围堆成一圈（土堆），
  中间是一个黑洞。所以要点是：
    · 一圈土色/沙色的**环**（外圈亮一点，是翻上来的干土）
    · 中间一个**带渐变的黑洞**（内圈暗、越往里越黑）
    · 外圈不能是方形的 —— 土的边缘要毛糙，否则又变回方块

尺寸保持 32x32（map_view 里井的间距与命中判定都按这个算）。
另出 well_shaft_construction.png：施工中的井 —— 土堆更高更散、洞更小。
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[2] / "assets" / "buildings"


def ring_color(r: float, r_out: float, seed: int) -> tuple:
    """土环的颜色：越靠外越亮（翻上来的干土），带随机深浅做颗粒感。"""
    t = r / r_out
    # 外圈浅沙 -> 内圈深褐
    base = (
        176 - int(58 * t),
        132 - int(46 * t),
        86 - int(30 * t),
    )
    # 用确定性的伪随机做土粒，不用 random 免得每次跑出来不一样
    n = math.sin(seed * 12.9898 + r * 78.233) * 43758.5453
    j = int((n - math.floor(n)) * 34) - 17
    return tuple(max(0, min(255, c + j)) for c in base)


def make_shaft(construction: bool) -> Image.Image:
    S = 32
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    px = im.load()
    cx = cy = (S - 1) / 2.0
    # 施工中：土堆更大、洞更小
    r_dirt = 14.6 if not construction else 15.2
    r_hole = 8.2 if not construction else 6.0

    for y in range(S):
        for x in range(S):
            dx, dy = x - cx, y - cy
            r = math.hypot(dx, dy)
            # 土堆边缘毛糙：按角度加一点起伏，否则外圈是个正圆/方块
            ang = math.atan2(dy, dx)
            wob = 0.9 * math.sin(ang * 5.0 + 1.7) + 0.6 * math.sin(ang * 9.0)
            rr = r_dirt + wob + (0.8 if construction else 0.0)
            if r > rr:
                continue
            if r <= r_hole:
                # 井洞：越靠中心越黑，边缘带一点土色过渡，不然像个贴上去的黑圆
                t = r / r_hole
                k = int(42 * (t ** 2.2))          # 边缘 42 -> 中心 0
                a = 255 if t < 0.92 else int(255 * (1.0 - (t - 0.92) / 0.08))
                px[x, y] = (k, k, max(0, k - 4), max(0, a))
            else:
                # 土堆：从洞口到外缘做一个亮起来的渐变，并沿半径画放射状的"翻土"痕
                t = (r - r_hole) / max(0.001, rr - r_hole)
                c = ring_color(r, rr, x * 31 + y)
                # 施工中堆得高，外缘更亮（新翻出来的湿土偏深，所以反而压暗内圈）
                if construction:
                    c = (int(c[0] * 0.92), int(c[1] * 0.90), int(c[2] * 0.88))
                # 放射状的翻土痕：每 60 度一道略暗的线
                spoke = math.sin(ang * 6.0)
                if spoke > 0.86 and t > 0.25:
                    c = (int(c[0] * 0.80), int(c[1] * 0.80), int(c[2] * 0.80))
                # 最外圈一像素压暗，当描边，避免和地面糊在一起
                if r > rr - 1.1:
                    c = (int(c[0] * 0.72), int(c[1] * 0.72), int(c[2] * 0.72))
                px[x, y] = (c[0], c[1], c[2], 255)

    if construction:
        # 施工中：井口旁边插两根木桩 + 一道绳子，一眼看出"还在挖"
        d = ImageDraw.Draw(im)
        d.line([(3, 30), (3, 16)], fill=(96, 66, 40, 255), width=1)
        d.line([(28, 30), (28, 18)], fill=(96, 66, 40, 255), width=1)
        d.line([(3, 17), (28, 19)], fill=(196, 172, 122, 255), width=1)
    return im


def main() -> None:
    for name, cons in (("well_shaft_01.png", False),
                       ("well_shaft_construction.png", True)):
        im = make_shaft(cons)
        p = OUT / name
        im.save(p)
        # 顺手报一下黑块占比，和改之前对比
        a = im.load()
        n_black = sum(1 for y in range(im.height) for x in range(im.width)
                      if a[x, y][3] > 200 and a[x, y][0] < 45
                      and a[x, y][1] < 45 and a[x, y][2] < 45)
        print("  -> %s  %dx%d  黑块占比 %.1f%%（改前 70.3%%/65.9%%）"
              % (p, im.width, im.height, n_black / (im.width * im.height) * 100))


if __name__ == "__main__":
    main()
