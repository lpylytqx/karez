#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""给 dsh-ppt 生成的 HTML 放映版加底纹背景（美化背景）。

为什么要单独改 HTML：dsh-ppt 的 brand 只支持背景**颜色**，没有背景**图**字段，
所以 PPTX 那边靠「封面 logo + 每页品牌标识」提升质感；
而 HTML 是浏览器里的成品，可以用 CSS 直接铺底纹。

两点讲究：
  1. 底纹作为 .slide::before 的**最后一层**（CSS 里越靠后越在底下），
     这样原有的径向渐变仍然叠在上面，不会因为铺了图就失去层次。
  2. 顺便把渐变里的冷蓝换成游戏的暖赭 —— 主题 data 自带一层青色
     rgba(6,182,212,.16)，铺在暖色底纹上会发灰。
  3. 底纹以 **base64 内嵌**，HTML 保持单文件、拷到哪都能双击放。

用法：.venv\\Scripts\\python.exe scripts\\pipeline\\beautify_deck_html.py
"""
from __future__ import annotations

import sys as _sys
from pathlib import Path as _Path
_sys.path.insert(0, str(_Path(__file__).resolve().parent))
from _root import ROOT  # 路径唯一解析处，不再写死盘符
import base64
import io
import re
from pathlib import Path

from PIL import Image

ROOT = ROOT
HTML = ROOT / "deliverables" / "坎儿井_创新点答辩.html"
BG_PNG = ROOT / "deliverables" / "assets" / "deck_bg.png"
MARK = "/* deck-bg-injected */"

OLD = """  background:
    radial-gradient(42% 34% at 82% 18%, rgba(224,164,60,0.22), transparent 70%),
    radial-gradient(36% 30% at 12% 86%, rgba(6,182,212,0.16), transparent 70%),
    radial-gradient(70% 60% at 50% 50%, rgba(13,20,36,0.55), transparent 100%);"""

NEW_TMPL = """  /* deck-bg-injected */
  background:
    radial-gradient(42% 34% at 82% 18%, rgba(224,164,60,0.26), transparent 70%),
    radial-gradient(36% 30% at 12% 86%, rgba(201,112,74,0.20), transparent 70%),
    radial-gradient(70% 60% at 50% 50%, rgba(43,33,24,0.42), transparent 100%),
    url("data:image/jpeg;base64,{b64}") center/cover no-repeat;"""


def main() -> None:
    html = HTML.read_text(encoding="utf-8")
    if MARK in html:
        print("  已注入过，跳过（幂等）")
        return
    if OLD not in html:
        raise SystemExit("  找不到预期的 .slide::before 背景块 —— 模板可能变了，"
                         "不要盲目替换，先人工核对")

    im = Image.open(BG_PNG).convert("RGB")
    im.thumbnail((1600, 900), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=84, optimize=True)
    b64 = base64.b64encode(buf.getvalue()).decode("ascii")
    print("  底纹 %s -> JPEG %d KB -> base64 %d KB"
          % (im.size, len(buf.getvalue()) // 1024, len(b64) // 1024))

    html = html.replace(OLD, NEW_TMPL.format(b64=b64))
    HTML.write_text(html, encoding="utf-8")
    print("  已写入 %s（%.2f MB）" % (HTML.name, HTML.stat().st_size / 1024 / 1024))

    # 自检：数据 URI 完整、层序对（url 必须在最后）
    chk = HTML.read_text(encoding="utf-8")
    m = re.search(r"\.slide::before\{(.*?)\}", chk, re.S)
    body = m.group(1) if m else ""
    print("  自检：含标记 %s｜含 data-uri %s｜url 在渐变之后 %s"
          % (MARK in chk, "data:image/jpeg;base64," in body,
             body.find("url(") > body.find("radial-gradient")))


if __name__ == "__main__":
    main()
