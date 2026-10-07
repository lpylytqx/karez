#!/usr/bin/env python -u
# -*- coding: utf-8 -*-
"""给展示稿补两样统一件：**每页页脚** 与 **所有卡片的描边**。

为什么用"后处理"而不是逐页改：
  逐页改要动 6 处卡片代码，每处都是一次字符串替换风险；
  而"给所有圆角矩形加描边"是一条通用规则就能覆盖 —— 卡片都是圆角矩形，
  满幅压暗层与细金条都是直角矩形，所以用**形状类型**做判据是安全的。

页脚：原来第 2~9 页只有右下角页码，左边是空的。补上作品名与团队，让 10 页成套。
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import ROOT  # noqa: E402

F = ROOT / "scripts" / "pipeline" / "build_showcase.py"


def main() -> None:
    t = F.read_text(encoding="utf-8")
    n = 0

    # ① 页脚：在 base() 里补一行作品名 + 团队
    old = '''    textbox(s, W - Inches(1.7), H - Inches(0.46), Inches(1.2), Inches(0.3),
            [("%02d / %d" % (page, TOTAL), 10, MUTED, False)], align=PP_ALIGN.RIGHT)
    return s'''
    new = '''    textbox(s, W - Inches(1.7), H - Inches(0.46), Inches(1.2), Inches(0.3),
            [("%02d / %d" % (page, TOTAL), 10, MUTED, False)], align=PP_ALIGN.RIGHT)
    # 页脚：左下角补作品名与团队，让 10 页成套（原来只有右下角页码）
    rect(s, Inches(0.98), H - Inches(0.50), Inches(0.14), Pt(1.0), GOLD)
    textbox(s, Inches(1.22), H - Inches(0.55), Inches(6.0), Inches(0.3),
            [("坎儿井　·　代码一次敲队", 9.5, MUTED, False)])
    return s'''
    if old in t:
        t = t.replace(old, new, 1)
        n += 1
        print("  ✓ 每页补页脚（作品名 · 团队）")

    # ② 卡片描边：新增后处理函数 + 在 save 前调用
    fn = '''

def outline_cards(prs, line=RGBColor(0x5E, 0x49, 0x30), lw=0.75) -> int:
    """给所有**圆角矩形**（= 卡片）加一道极细描边，把卡片从背景里"托"起来。

    判据用形状类型而不是逐页指定：卡片一律是圆角矩形，而满幅压暗层、
    细金条、分隔线都是直角矩形 —— 所以这条规则不会误伤。
    """
    k = 0
    for sl in prs.slides:
        for sh in sl.shapes:
            try:
                if sh.auto_shape_type == MSO_SHAPE.ROUNDED_RECTANGLE:
                    sh.line.color.rgb = line
                    sh.line.width = Pt(lw)
                    k += 1
            except Exception:
                continue
    return k

'''
    if "def outline_cards" not in t:
        t = t.replace("\n# ---------------------------------------------------------------------------\n",
                      fn + "\n# ---------------------------------------------------------------------------\n", 1)
        t = t.replace('    OUT.parent.mkdir(parents=True, exist_ok=True)\n    prs.save(OUT)',
                      '    k = outline_cards(prs)\n'
                      '    print("  卡片描边：%d 个圆角矩形" % k)\n'
                      '    OUT.parent.mkdir(parents=True, exist_ok=True)\n    prs.save(OUT)', 1)
        n += 1
        print("  ✓ 新增卡片描边后处理")

    if n == 0:
        print("  [警告] 一处都没改上")
        return
    F.write_text(t, encoding="utf-8")
    import py_compile
    py_compile.compile(str(F), doraise=True)
    print("  build_showcase.py 改 %d 处，语法检查通过" % n)


if __name__ == "__main__":
    main()
