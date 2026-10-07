#!/usr/bin/env python -u
# -*- coding: utf-8 -*-
"""合并稿的第二个修正：换对页 + 重写页脚页码。

修正一：丢错页了。
  我按源码注释以为答辩稿第 3 页是章节页，实际渲染出来是「四个创新点」的**过场页**；
  而真正的**内容页「乐与节」在第 7 页**，被我当章节页丢掉了 ——
  音乐与节庆是文化线的重点，不能丢。
  改为：保留 D7「乐与节」，丢掉 D3 过场页。

修正二：页码不自洽。
  两套稿子各自编页（展示稿「07 / 10」、答辩稿「05 / 15」），合并成 21 页后全对不上。
  合并后统一重写成「NN / 21」。

`find_page_number` 的判据：文本形如「数字 / 数字」且很短 —— 这是两套稿子页脚的共同特征，
不会误伤正文（正文里没有这种孤立短文本）。
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import ROOT  # noqa: E402

D = ROOT / "deliverables"
OUT = D / "坎儿井_完整版.pptx"

# ★ 修正后的顺序：D3 换成 D7（乐与节）
ORDER = [("S", 1), ("S", 2), ("S", 3), ("S", 4), ("S", 5), ("S", 6), ("S", 7),
         ("D", 4), ("D", 5), ("D", 6), ("D", 7),
         ("S", 8),
         ("D", 8), ("D", 9), ("D", 10), ("D", 11),
         ("D", 12), ("D", 13), ("D", 14),
         ("S", 9), ("S", 10)]
S_N = 10

PAGE_RE = re.compile(r"^\s*\d{1,2}\s*/\s*\d{1,2}\s*$")


class Shim:
    def __init__(self, real):
        object.__setattr__(self, "_r", real)

    def __getattr__(self, k):
        return getattr(self._r, k)

    def __setattr__(self, k, v):
        setattr(self._r, k, v)

    def save(self, *a, **k):
        return None


def renumber(prs, total: int) -> int:
    """把每页页脚的「NN / MM」统一重写成「NN / total」。"""
    n = 0
    for i, s in enumerate(prs.slides, 1):
        for sh in s.shapes:
            if not sh.has_text_frame:
                continue
            tf = sh.text_frame
            if len(tf.paragraphs) != 1:
                continue
            txt = tf.text
            if not PAGE_RE.match(txt):
                continue
            run = tf.paragraphs[0].runs[0] if tf.paragraphs[0].runs else None
            if run is None:
                continue
            run.text = "%02d / %d" % (i, total)
            n += 1
    return n


def main() -> None:
    import build_showcase as BS
    import build_deck as BD
    from pptx import Presentation

    prs = Presentation()
    shim = Shim(prs)
    BS.Presentation = lambda *a, **k: shim
    BD.Presentation = lambda *a, **k: shim
    BS.build()
    BD.build()
    print("  画入合计 %d 页" % len(prs.slides))

    idx = [p - 1 if t == "S" else S_N + p - 1 for t, p in ORDER]
    sldIdLst = prs.slides._sldIdLst
    ids = list(sldIdLst)
    for el in ids:
        sldIdLst.remove(el)
    for i in idx:
        sldIdLst.append(ids[i])
    print("  保留 %d 页，丢弃 %d 页（答辩稿封面 / 过场页 / 收尾）"
          % (len(idx), len(ids) - len(idx)))

    k = renumber(prs, len(idx))
    print("  页脚页码重写 %d 处 -> 统一为 NN / %d" % (k, len(idx)))

    prs.save(OUT)
    print("  已生成 %s（%d 页）" % (OUT.name, len(prs.slides)))


if __name__ == "__main__":
    main()
