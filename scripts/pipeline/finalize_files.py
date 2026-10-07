#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""参赛材料定稿：重存 10 张截图（修 JPEG 参数）+ 清理无用文件 + 固定文件夹。

一、为什么 10 张图"颜色看着奇怪"（真凶找到了）
   PIL 存 JPEG 默认用 **4:2:0 色度抽样** —— 亮度全分辨率、色度只存 1/4。
   这个策略是给人像/风景设计的，用在**像素画**上是灾难：
   颜色只采样一半像素，边缘互相渗色，放大后一片糊。
   实测：同一张图放大 4 倍，默认 4:2:0 的树边缘糊成一团，4:4:4 的和原图几乎一样。
   所以参赛截图一律 `subsampling=0`（4:4:4）+ q95。

二、清理原则
   · 删的都是**我自己生成**的：临时对照图、过程文件夹、换代前的旧截图
   · 用户的文件一个不碰（先列出清单，再删）
"""
import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import ROOT, SCREENSHOTS, PACK  # noqa: E402

from PIL import Image  # noqa: E402

# 固定的截图文件夹（用户要求：10 张放一个固定位置）
SHOT_DIR = PACK / "作品截图10张"

# 10 张的最终选图（源图 -> 输出名）
SHOTS = [
    ("S13_sub_A_绿洲中景",   "01_治水成果_六段竖井挖通后的绿洲"),
    ("S10_deck_B_分工面板",  "02_核心玩法_九个岗位分工"),
    ("S11_建造菜单",        "03_建造系统_十三座建筑"),
    ("S13_sub_B_事件卡中景", "04_AI事件_带选项与后果"),
    ("S10_deck_D_御敌布阵",  "05_自由布阵_兵种由岗位决定"),
    ("S13_sub_E_畜牧中景",   "06_畜牧系统_抓野畜与产出"),
    ("S9_animal_E_木卡姆",   "07_非遗_十二木卡姆可演奏"),
    ("S9_animal_C_灾难日志", "08_灾难系统_插画由本地SDX生成"),
    ("S13_sub_C_冬季雪景",   "09_四季表现_冬季雪地"),
    ("S13_sub_D_春季花木",   "10_四季表现_春季花木"),
]

# 我生成的、可以删的（先列清单）
TEMP_IN_PACK = ["_检查_10张对照.png", "_检查_新10张.png", "_检查_终版10张.png",
                "_对比", "02-作品截图10张jpg"]
# docs/screenshots 里换代前的旧截图（S2 ~ S8 系列：地图还是 40x22 格的年代）
OBSOLETE_PREFIX = ("S2_", "S3_", "S4_", "S5_", "S6_", "S7_", "S8_")


def shoot() -> int:
    SHOT_DIR.mkdir(parents=True, exist_ok=True)
    for old in SHOT_DIR.glob("*.jpg"):
        old.unlink()
    n = 0
    for stem, out in SHOTS:
        src = SCREENSHOTS / (stem + ".png")
        if not src.exists():
            print("    [缺] %s" % src.name)
            continue
        im = Image.open(src).convert("RGB")
        # ⚠ 关键：4:4:4，不抽样色度。默认 4:2:0 会把像素画糊掉。
        im.save(SHOT_DIR / (out + ".jpg"), "JPEG", quality=95, subsampling=0,
                optimize=True)
        n += 1
    print("  作品截图 %d/10 -> %s" % (n, SHOT_DIR.name))
    return n


def cleanup() -> None:
    killed = []
    for name in TEMP_IN_PACK:
        p = PACK / name
        if p.is_dir():
            import shutil
            shutil.rmtree(p, ignore_errors=True)
            killed.append(name + "/")
        elif p.exists():
            p.unlink()
            killed.append(name)
    # 旧代截图
    old = [p for p in SCREENSHOTS.glob("*.png")
           if p.name.startswith(OBSOLETE_PREFIX)]
    for p in old:
        p.unlink()
    print("  删除临时对照/过程目录 %d 项：%s" % (len(killed), killed))
    print("  删除换代前旧截图 %d 张（S2~S8 系列）" % len(old))
    # 我散落在 deliverables/assets 下的检查图
    extra = []
    for pat in ("_figcheck*.png", "_show*.png", "_deck*.png", "_buildmenu*.png",
                "_verify*.png", "_final_sheet.png", "_sheet.png", "_sitemap*"):
        for p in (ROOT / "deliverables" / "assets").glob(pat):
            p.unlink()
            extra.append(p.name)
    print("  删除产出目录里的检查图 %d 张" % len(extra))


def rezip() -> Path:
    zpath = PACK / "05-参赛打包ZIP" / "坎儿井_参赛包.zip"
    zpath.parent.mkdir(parents=True, exist_ok=True)
    EXCLUDE_DIRS = {".venv", ".dsh-pyenv", "logs", "dsh-image-gen", "deliverables",
                    "参赛材料", "__pycache__", ".git", ".dsh-notes"}
    EXCLUDE_REL = {"assets/_raw"}
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        n = 0
        for p in sorted(ROOT.rglob("*")):
            if not p.is_file():
                continue
            rel = p.relative_to(ROOT)
            if any(part in EXCLUDE_DIRS for part in rel.parts):
                continue
            if any(rel.as_posix() == e or rel.as_posix().startswith(e + "/")
                   for e in EXCLUDE_REL):
                continue
            z.write(p, rel.as_posix())
            n += 1
        for p in sorted(PACK.rglob("*")):
            if p.is_file() and not p.name.endswith(".zip"):
                z.write(p, "参赛材料/" + p.relative_to(PACK).as_posix())
                n += 1
    print("  参赛包：%d 个文件，%.1f MB" % (n, zpath.stat().st_size / 1024 / 1024))
    return zpath


def main() -> None:
    n = shoot()
    cleanup()
    rezip()
    print("\n  最终参赛材料目录：")
    for p in sorted(PACK.rglob("*")):
        rel = p.relative_to(PACK).as_posix()
        if p.is_dir():
            print("    [%s]/" % rel)
        elif p.suffix.lower() in (".jpg", ".png"):
            print("      %-52s %7.0f KB" % (rel, p.stat().st_size / 1024))
    if n != 10:
        print("  ⚠ 截图只有 %d 张" % n)


if __name__ == "__main__":
    main()
