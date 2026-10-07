#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""整理文件夹：删掉没用的（**只删我自己产生的**），并把结构理顺。

删除口径（严格）：
  · 我的构建/测试日志        logs/*                    —— 全是跑的中间输出
  · 我的核对拼图             deliverables/assets/_*.png —— 过程中的检查图
  · 根目录散落的临时截图      _verify_capture.png
  · 出图目录里的对照拼图      dsh-image-gen/cover/_sheet.png
  · 换代后没人再引用的截图    docs/screenshots 里未被任何构建脚本引用的

明确**不删**（哪怕看着像没用）：
  · dsh-image-gen/image-*.png —— 不是我生成的（本次会话之前就在），可能是你自己的
  · 参赛材料/ 下的任何文件
  · scripts/scenes/capture_*.gd —— 截图的可复现管线，删了以后就再也拍不回同样的图
  · assets/_raw/ —— Kenney 原始素材库，是素材再加工的原料

用法：.venv\\Scripts\\python.exe scripts\\pipeline\\tidy_folders.py [--dry]
"""
from __future__ import annotations

import re
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import ROOT, DELIVERABLES, DOCS, LOGS, IMAGE_GEN, PACK  # noqa: E402

DRY = "--dry" in sys.argv
deleted: list[tuple[str, int]] = []
kept_files: list[str] = []


def rm(p: Path) -> None:
    if not p.exists():
        return
    if p.is_dir():
        n = sum(1 for _ in p.rglob("*") if _.is_file())
        size = sum(_.stat().st_size for _ in p.rglob("*") if _.is_file())
        if not DRY:
            shutil.rmtree(p, ignore_errors=True)
        deleted.append((str(p.relative_to(ROOT)) + "/", size))
        del n
    else:
        size = p.stat().st_size
        if not DRY:
            p.unlink()
        deleted.append((str(p.relative_to(ROOT)), size))


def keep_shot_names() -> set[str]:
    """构建脚本里引用到的截图名 —— 这些不能删，删了脚本就跑不了。"""
    keep: set[str] = set()
    for name in ("build_deck.py", "build_showcase.py", "finalize_files.py",
                 "pack_competition.py", "finalize_submission.py"):
        p = ROOT / "scripts" / "pipeline" / name
        if not p.exists():
            continue
        txt = p.read_text(encoding="utf-8")
        keep |= set(re.findall(r"(S\d+_[A-Za-z0-9_\u4e00-\u9fff]+)\.png", txt))
    # 标题画面是成品的一部分，留着
    keep |= {"S12_title_封面", "S12_title_A_封面"}
    return keep


def main() -> None:
    # ① 日志
    if LOGS.exists():
        for p in LOGS.glob("*.log"):
            rm(p)
        for p in LOGS.glob("*.json"):
            rm(p)

    # ② deliverables/assets 下的核对拼图（留两张还在用的）
    KEEP_ASSETS = {"_预览_参赛10张.png", "_网格_左上8x8.png"}
    adir = DELIVERABLES / "assets"
    if adir.exists():
        for p in adir.glob("_*"):
            if p.name in KEEP_ASSETS:
                kept_files.append("deliverables/assets/" + p.name)
                continue
            rm(p)

    # ③ 根目录散落
    rm(ROOT / "_verify_capture.png")

    # ④ 出图目录的对照拼图（原始出图保留）
    rm(IMAGE_GEN / "cover" / "_sheet.png")

    # ⑤ 没人引用的截图
    keep = keep_shot_names()
    ss = DOCS / "screenshots"
    if ss.exists():
        for p in sorted(ss.glob("*.png")):
            if p.stem in keep:
                kept_files.append("docs/screenshots/" + p.name)
                continue
            rm(p)

    total = sum(s for _, s in deleted)
    print("  %s：删除 %d 项，释放 %.1f MB" % ("[试运行]" if DRY else "[已执行]",
                                            len(deleted), total / 1024 / 1024))
    print()
    print("  删掉的：")
    for name, size in deleted:
        print("    %-56s %8.0f KB" % (name, size / 1024))
    print()
    print("  保留的截图 %d 张（被构建脚本引用）：" % len(kept_files))
    for k in kept_files:
        print("    " + k)
    print()
    print("  参赛材料（一个没动）：")
    for p in sorted(PACK.rglob("*")):
        if p.is_file():
            print("    %-58s %8.0f KB" % (p.relative_to(PACK).as_posix(),
                                          p.stat().st_size / 1024))


if __name__ == "__main__":
    main()
