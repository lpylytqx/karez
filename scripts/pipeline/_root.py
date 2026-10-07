#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""项目根目录的唯一解析处 —— **不要在任何脚本里再写死 D:\\坎儿井**。

解析顺序：
  1. 环境变量 `KAREZ_ROOT`（换机器、换盘符、跑 CI 时用这个覆盖）
  2. 从本文件位置往上推：scripts/pipeline/_root.py -> 上三级就是项目根
     （本文件在 <root>/scripts/pipeline/ 下，所以 parents[2] 是 <root>）

为什么单开一个文件：项目里十几个脚本原来各自写着 `Path(r"D:\\坎儿井")`，
一旦目录改名或换机器就得逐个改，而且极容易漏掉一个、跑出"一半写在新路径、
一半还在旧路径"的诡异结果。收敛到一处，改一个地方就够了。

用法：
    from _root import ROOT, DELIVERABLES, SCREENSHOTS, PACK
（把本文件所在目录加进 sys.path，或直接放在同目录下用）
"""
from __future__ import annotations

import os
from pathlib import Path

_ENV = os.environ.get("KAREZ_ROOT", "").strip()

if _ENV:
    ROOT = Path(_ENV).expanduser().resolve()
else:
    # _root.py 在 <root>/scripts/pipeline/ 下
    ROOT = Path(__file__).resolve().parents[2]

# 常用子目录，避免每个脚本各写一遍相对路径
SCRIPTS = ROOT / "scripts"
ASSETS = ROOT / "assets"
DATA = ROOT / "data"
DOCS = ROOT / "docs"
SCREENSHOTS = DOCS / "screenshots"
DELIVERABLES = ROOT / "deliverables"
PACK = ROOT / "参赛材料"
PIPELINE = SCRIPTS / "pipeline"
IMAGE_GEN = ROOT / "dsh-image-gen"
LOGS = ROOT / "logs"

PUBLIC = {
    "ROOT": ROOT,
    "SCRIPTS": SCRIPTS,
    "ASSETS": ASSETS,
    "DATA": DATA,
    "DOCS": DOCS,
    "SCREENSHOTS": SCREENSHOTS,
    "DELIVERABLES": DELIVERABLES,
    "PACK": PACK,
    "IMAGE_GEN": IMAGE_GEN,
    "LOGS": LOGS,
}


if __name__ == "__main__":
    missing = [k for k, v in PUBLIC.items() if k not in ("PACK",) and not v.exists()]
    print("  项目根：%s" % ROOT)
    print("  环境变量 KAREZ_ROOT：%s" % (_ENV or "（未设置，用文件位置推断）"))
    for k, v in PUBLIC.items():
        print("    %-12s %s%s" % (k, v, "" if v.exists() else "   <不存在>"))
    if missing:
        print("  ⚠ 不存在的目录：%s" % missing)
