#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""量 PDF 里文字的真实横向范围，判断有没有冲出页边距。

为什么要用 PDF 而不是看渲染图：渲染 PNG 四周带白边，按像素估会算歪；
PDF 的 bbox 是排版后的**权威坐标**。
"""
import sys as _sys
from pathlib import Path as _Path
_sys.path.insert(0, str(_Path(__file__).resolve().parent))
from _root import ROOT  # 路径唯一解析处，不再写死盘符
import re
import subprocess
import sys
from pathlib import Path

BIN = Path(r"C:\Users\j\AppData\Local\Microsoft\WinGet\Packages"
           r"\oschwartz10612.Poppler_Microsoft.Winget.Source_8wekyb3d8bbwe"
           r"\poppler-25.07.0\Library\bin")
PDF = Path(str(ROOT / "deliverables/《坎儿井》作品申报书.pdf"))
OUT = Path(str(ROOT / "deliverables/_bbox.html"))

subprocess.run([str(BIN / "pdftotext.exe"), "-bbox", str(PDF), str(OUT)],
               capture_output=True)

info = subprocess.run([str(BIN / "pdfinfo.exe"), str(PDF)],
                      capture_output=True, text=True, errors="ignore").stdout
for ln in info.splitlines():
    if ln.startswith(("Pages", "Page size")):
        print("  " + ln.strip())

text = OUT.read_text(encoding="utf-8", errors="ignore")
pages = re.findall(r'<page width="([\d.]+)" height="([\d.]+)">(.*?)</page>',
                   text, re.S)
print("  抓到 %d 页" % len(pages))
for idx, (pw, ph, body) in enumerate(pages[:3], 1):
    pw, ph = float(pw), float(ph)
    words = re.findall(
        r'<word xMin="([\d.]+)" yMin="([\d.]+)" xMax="([\d.]+)" yMax="([\d.]+)">([^<]*)</word>',
        body)
    if not words:
        print("  第%d页 无文字" % idx)
        continue
    xs0 = [float(w[0]) for w in words]
    xs1 = [float(w[2]) for w in words]
    m = 72.0
    over = [w for w in words if float(w[2]) > pw - m + 1]
    print("  第%d页 %.0fx%.0f pt｜文字 %.1f ~ %.1f｜版心 %.0f~%.0f｜越界词 %d"
          % (idx, pw, ph, min(xs0), max(xs1), m, pw - m, len(over)))
    for w in over[:5]:
        print("      x %.0f~%.0f  %s" % (float(w[0]), float(w[2]), w[4][:22]))
