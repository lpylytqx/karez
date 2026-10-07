#!/usr/bin/env python -u
# -*- coding: utf-8 -*-
"""把两份 PPT 合并成一份 —— **第二版，换了做法**。

第一版失败的原因：我把页面的 XML 跨文件搬过去，然后手工重建图片关系
（a:blip 的 r:embed → get_or_add_image_part）。结果**每一张图都报错**
（`Argument must be bytes or unicode, got 'ImagePart'`），21 页里图全空 ——
而我的"回读校验"只数了 `a:blip` 元素的**个数**，个数是对的就打印了正常，
**恰好犯了这个项目上最忌讳的错：拿一个不能证明结论的指标当验证。**

这一版换思路：**不搬 XML，让两个生成脚本往同一个文稿里各画一遍。**
  · 两个 build() 内部都是 `prs = Presentation()` 然后 `prs.save(OUT)`
  · 所以把 `Presentation()` 换成一个返回**共享文稿的壳**，并把 save 变成空操作，
    两次 build() 就会把 25 页都画进同一个 prs
  · 图片走的是正常 python-pptx API，**不存在关系丢失的可能**
  · 最后按叙事顺序重排 `sldIdLst`，并丢掉不要的 4 页（答辩稿的封面/章节页/收尾）

顺便修掉上一版的验证方法：这次**逐页渲染**看，不看 XML 个数。
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import ROOT  # noqa: E402

D = ROOT / "deliverables"
OUT = D / "坎儿井_完整版.pptx"

# 目标顺序：('S' 展示稿页码, 'D' 答辩稿页码)
ORDER = [("S", 1), ("S", 2), ("S", 3), ("S", 4), ("S", 5), ("S", 6), ("S", 7),
         ("D", 3), ("D", 4), ("D", 5), ("D", 6),
         ("S", 8),
         ("D", 8), ("D", 9), ("D", 10), ("D", 11),
         ("D", 12), ("D", 13), ("D", 14),
         ("S", 9), ("S", 10)]
S_N, D_N = 10, 15


class Shim:
    """把 prs 包一层：读属性/调方法都转发，**唯独 save 变空操作**。

    这样两个 build() 各自的 `prs.save(自己的 OUT)` 就不会把源文件覆盖成半成品。
    """
    def __init__(self, real):
        object.__setattr__(self, "_r", real)

    def __getattr__(self, k):
        return getattr(self._r, k)

    def __setattr__(self, k, v):
        setattr(self._r, k, v)

    def save(self, *a, **k):
        return None


def main() -> None:
    import build_showcase as BS
    import build_deck as BD
    from pptx import Presentation

    prs = Presentation()
    shim = Shim(prs)
    BS.Presentation = lambda *a, **k: shim
    BD.Presentation = lambda *a, **k: shim

    BS.build()
    n1 = len(prs.slides)
    BD.build()
    n2 = len(prs.slides)
    print("  画入：展示稿后 %d 页，再答辩稿后 %d 页（合计 %d）" % (n1, n2, n2))

    # 索引映射：S 第 p 页 -> p-1；D 第 p 页 -> S_N + p - 1
    idx = [p - 1 if t == "S" else S_N + p - 1 for t, p in ORDER]
    keep = set(idx)

    sldIdLst = prs.slides._sldIdLst
    ids = list(sldIdLst)
    print("  原有 %d 页，保留 %d 页，丢弃 %d 页"
          % (len(ids), len(keep), len(ids) - len(keep)))
    # 先清空，再按目标顺序重新挂上
    for el in ids:
        sldIdLst.remove(el)
    for i in idx:
        sldIdLst.append(ids[i])

    prs.save(OUT)
    print("  已生成 %s（%d 页）" % (OUT.name, len(prs.slides)))

    # 回读：这次只报"能数清的事实"，不下结论
    from pptx import Presentation as P2
    back = P2(OUT)
    print("  回读：%d 页" % len(back.slides))
    for i, s in enumerate(back.slides, 1):
        pics = [sh for sh in s.shapes if sh.shape_type == 13]  # PICTURE
        missing = sum(1 for sh in pics if not getattr(sh, "_element", None) is None
                      and sh._element.find(".//" + "{http://schemas.openxmlformats.org/drawingml/2006/main}blip") is None)
        print("    第 %2d 页：形状 %2d  图片 %2d" % (i, len(s.shapes), len(pics)))
    print("\n  ⚠ 图片是否真的能显示，必须渲染后逐页看 —— 元素个数证明不了这件事。")


if __name__ == "__main__":
    main()
