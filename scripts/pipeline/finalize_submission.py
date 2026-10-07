#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""定稿：重建 10 张作品截图（换成中景取景）+ 打参赛 ZIP。

为什么换图：上一版 10 张里有几张是"最小缩放"下拍的，绿洲只占画面一角、
周围大片空沙地 —— 实测 AI 事件那张**对比度只有 9**（几乎糊成纯色块），
四季那张干脆是一张白底四格对比图（不是游戏画面）。中景取景后颜色和可读性都回来了。

打包排除项也在这里写死：.venv / logs / .dsh-pyenv / dsh-image-gen / assets/_raw
—— 都是开发中间产物，体积大且与评审无关。
"""
from __future__ import annotations

import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import ROOT, SCREENSHOTS, PACK  # noqa: E402

from PIL import Image  # noqa: E402

# 新选的 10 张（中景取景优先）
SHOTS = [
    ("S13_sub_A_绿洲中景",        "01_治水成果_六段竖井挖通后的绿洲"),
    ("S10_deck_B_分工面板",       "02_核心玩法_九个岗位分工"),
    ("S11_建造菜单",             "03_建造系统_十三座建筑"),
    ("S13_sub_B_事件卡中景",      "04_AI事件_带选项与后果"),
    ("S10_deck_D_御敌布阵",       "05_自由布阵_兵种由岗位决定"),
    ("S13_sub_E_畜牧中景",        "06_畜牧系统_抓野畜与产出"),
    ("S9_animal_E_木卡姆",        "07_非遗_十二木卡姆可演奏"),
    ("S9_animal_C_灾难日志",      "08_灾难系统_插画由本地SDXL生成"),
    ("S13_sub_C_冬季雪景",        "09_四季表现_冬季雪地"),
    ("S13_sub_D_春季花木",        "10_四季表现_春季花木"),
]

EXCLUDE_DIRS = {".venv", ".dsh-pyenv", "logs", "dsh-image-gen", "deliverables",
                "参赛材料", "__pycache__", ".git", ".dsh-notes"}
EXCLUDE_REL = {"assets/_raw"}


def jpg(src: Path, dst: Path, maxw=1920, q=92) -> None:
    im = Image.open(src).convert("RGB")
    if im.width > maxw:
        im = im.resize((maxw, int(im.height * maxw / im.width)), Image.LANCZOS)
    dst.parent.mkdir(parents=True, exist_ok=True)
    im.save(dst, "JPEG", quality=q, optimize=True)


def rebuild() -> int:
    d = PACK / "02-作品截图10张jpg"
    d.mkdir(parents=True, exist_ok=True)
    for old in d.glob("*.jpg"):
        old.unlink()
    n = 0
    for stem, out in SHOTS:
        src = SCREENSHOTS / (stem + ".png")
        if not src.exists():
            print("    [缺] %s" % src.name)
            continue
        jpg(src, d / (out + ".jpg"))
        n += 1
    print("  作品截图 %d/10 -> %s" % (n, d.name))
    return n


def skip(p: Path) -> bool:
    rel = p.relative_to(ROOT).as_posix()
    if any(part in EXCLUDE_DIRS for part in p.relative_to(ROOT).parts):
        return True
    return any(rel == e or rel.startswith(e + "/") for e in EXCLUDE_REL)


def make_zip() -> Path:
    zpath = PACK / "05-参赛打包ZIP" / "坎儿井_参赛包.zip"
    zpath.parent.mkdir(parents=True, exist_ok=True)
    files = 0
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        for p in sorted(ROOT.rglob("*")):
            if not p.is_file() or skip(p):
                continue
            z.write(p, p.relative_to(ROOT).as_posix())
            files += 1
        # 把材料也打进去（评审要看申报书/PPT/截图）
        for p in sorted(PACK.rglob("*")):
            if not p.is_file() or p.name.endswith(".zip"):
                continue
            z.write(p, ("参赛材料/" + p.relative_to(PACK).as_posix()))
            files += 1
    print("  参赛包：%s（%d 个文件，%.1f MB）"
          % (zpath.name, files, zpath.stat().st_size / 1024 / 1024))
    return zpath


def main() -> None:
    n = rebuild()
    z = make_zip()
    if n != 10:
        print("  ⚠ 截图只有 %d 张" % n)
    print("  完成：%s" % z)


if __name__ == "__main__":
    main()
