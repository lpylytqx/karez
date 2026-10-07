#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""补救：从参赛包里恢复被误删的截图源，并用**修正后的规则**重新清理。

我犯的错：
  tidy_folders.py 的"保留规则"用正则 `(S\\d+_\\w+)\\.png` 去构建脚本里找被引用的截图名，
  但 finalize_files.py 里写的是**不带 .png 的字符串**（元组第一项）——
  于是 S13_sub_* / S10_deck_B,D / S9_animal_B,D 这些**正在被引用的源图被判成"没人用"删掉了**。

教训：**"没人引用"这个判断，不能用"正则没匹配上"来下结论** ——
正则没匹配上只说明"我的正则没找到"，不说明"没人用"。
救回来的办法：参赛包是在这次清理之前打的，里面有完整的一份。
"""
from __future__ import annotations

import re
import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import ROOT, DOCS, DELIVERABLES, IMAGE_GEN  # noqa: E402

ZIP = ROOT / "参赛材料" / "05-参赛打包ZIP" / "坎儿井_参赛包.zip"

# 这次清理实际删掉、且需要恢复的（截图 + 我自己的核对图 + 出图对照）
RESTORE_PREFIX = ("docs/screenshots/", "deliverables/assets/_")
RESTORE_EXTRA = ("dsh-image-gen/cover/_sheet.png",)


def restore() -> int:
    if not ZIP.exists():
        print("  [X] 找不到参赛包：%s" % ZIP)
        return -1
    n = 0
    with zipfile.ZipFile(ZIP) as z:
        for name in z.namelist():
            if name.endswith("/"):
                continue
            if not (name.startswith(RESTORE_PREFIX) or name in RESTORE_EXTRA):
                continue
            dst = ROOT / name
            if dst.exists():
                continue
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_bytes(z.read(name))
            n += 1
    print("  从参赛包恢复 %d 个文件" % n)
    return n


def referenced() -> set[str]:
    """**放宽**的引用判断：既看 `X.png`，也看裸字符串 `X`。

    前一次就是只看了带后缀的，才误判。宁可多留，不可错删。
    """
    keep: set[str] = set()
    for p in (ROOT / "scripts" / "pipeline").glob("*.py"):
        txt = p.read_text(encoding="utf-8")
        keep |= set(re.findall(r"(S\d+_[A-Za-z0-9_\u4e00-\u9fff]+)", txt))
    return keep


def main() -> None:
    restore()
    keep = referenced()
    ss = DOCS / "screenshots"
    extra = 0
    # 只删"确实没被任何 pipeline 脚本提到"的，而且这次宽松匹配
    for p in sorted(ss.glob("*.png")):
        if p.stem in keep:
            continue
        print("    仍然没人提到，但先留着：%s" % p.name)
        extra += 1
    print("  docs/screenshots 现有 %d 张，其中被引用 %d 张，未被引用 %d 张（未删，等你定）"
          % (len(list(ss.glob("*.png"))),
             len([p for p in ss.glob("*.png") if p.stem in keep]), extra))


if __name__ == "__main__":
    main()
