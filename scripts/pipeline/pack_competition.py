#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""整理中国数媒参赛材料：按**上传口**建目录树，把文件各就各位。

依据（竞赛当时的要求）：cmit.cn 命题类 · AIGC 类数字创意作品创作赛项，
六个上传口 —— 承诺书盖章扫描 / 作品截图 10 张 jpg / 作品视频 mp4 /
答辩 PPT / 参赛打包 ZIP ≤10GB /（学生证仅国际赛）。

目录按**上传口**编号，而不是按文件类型 —— 交材料时是照着上传口一个个传的，
按上传口编号能一眼看出"哪个口还空着"。

清理只清我自己产生的临时产物（多轮渲染目录、_*.json），用户自己的文件一律不动。

用法：.venv\\Scripts\\python.exe scripts\\pipeline\\pack_competition.py
"""
from __future__ import annotations

import sys as _sys
from pathlib import Path as _Path
_sys.path.insert(0, str(_Path(__file__).resolve().parent))
from _root import ROOT  # 路径唯一解析处，不再写死盘符
import shutil
from pathlib import Path

from PIL import Image

ROOT = ROOT
DELIV = ROOT / "deliverables"
PACK = ROOT / "参赛材料"
SHOTS = ROOT / "docs" / "screenshots"

# 10 张作品截图：按评分点挑，不是随便凑数
#   六项评分里前五项都需要画面支撑：选题(水/绿洲)、创新(AI事件)、技术(建造/分工)、
#   完成度(畜牧·灾难·木卡姆)、传播(四季·绿洲生长)
# 选图清单统一在 finalize_files.py —— 这份已删除，
# 免得留在这里引用到已清理的旧截图（曾因此把源图误删过）。


def jpg(src: Path, dst: Path, maxw=1920, q=92) -> None:
    im = Image.open(src).convert("RGB")
    if im.width > maxw:
        im = im.resize((maxw, int(im.height * maxw / im.width)), Image.LANCZOS)
    dst.parent.mkdir(parents=True, exist_ok=True)
    im.save(dst, "JPEG", quality=q, optimize=True)


def cleanup() -> list[str]:
    """只删我自己产生的临时产物。"""
    killed: list[str] = []
    for d in sorted(DELIV.glob("render*")) + sorted(DELIV.glob("docx_preview*")):
        if d.is_dir():
            killed.append(d.name)
            shutil.rmtree(d, ignore_errors=True)
    for f in list(DELIV.glob("_*.json")) + list(DELIV.glob("_*.png")):
        killed.append(f.name)
        f.unlink(missing_ok=True)
    return killed


def main() -> None:
    killed = cleanup()
    print("  清理临时产物 %d 项" % len(killed))

    PACK.mkdir(parents=True, exist_ok=True)

    # ── 02 作品截图 10 张 ──
    d = PACK / "02-作品截图10张jpg"
    d.mkdir(parents=True, exist_ok=True)
    n = 0
    for src_name, out_name in SHOT_LIST:
        src = SHOTS / (src_name + ".png")
        if not src.exists():
            print("    [缺] %s" % src.name)
            continue
        jpg(src, d / (out_name + ".jpg"))
        n += 1
    print("  作品截图 %d/10 张 -> %s" % (n, d.name))

    # ── 04 答辩 PPT ──
    d = PACK / "04-答辩PPT"
    d.mkdir(parents=True, exist_ok=True)
    for name in ["坎儿井_创新点答辩.pptx", "坎儿井_作品展示.pptx",
                 "《坎儿井》作品申报书.pdf"]:
        p = DELIV / name
        if p.exists():
            shutil.copy2(p, d / name)
    print("  答辩 PPT 与申报书 -> %s（%d 个文件）"
          % (d.name, len(list(d.iterdir()))))

    # ── 03 作品视频（占位 + 说明）──
    d = PACK / "03-作品视频mp4"
    d.mkdir(parents=True, exist_ok=True)
    (d / "说明.txt").write_text(
        "本目录放作品演示视频（.mp4）。\n\n"
        "建议内容（与展示稿 10 页一一对应）：\n"
        "  1. 封面：绿洲全景（10 秒）\n"
        "  2. 从荒地开始挖通六段竖井，绿洲随水扩展（40 秒）\n"
        "  3. 分工面板：多派一人挖井就少一人种地（20 秒）\n"
        "  4. 建造菜单：13 座建筑翻页（15 秒）\n"
        "  5. 事件卡：与老坎匠对话触发的 AI 事件（20 秒）\n"
        "  6. 御敌之战：自由布阵 → 开战 → 战果（40 秒）\n"
        "  7. 畜牧页：派人抓野畜、栏位与产出（25 秒）\n"
        "  8. 木卡姆：点奏乐台办一场（20 秒）\n"
        "  9. 灾难：沙暴通告卡 + 全屏色调（15 秒）\n"
        " 10. 收尾：四季对比（15 秒）\n\n"
        "录制方式：双击 启动游戏.bat，用 Win+Alt+R（Xbox Game Bar）录屏。\n"
        "总时长建议 3 分钟内。\n",
        encoding="utf-8")
    print("  视频目录已建（含录制建议）")

    # ── 01 承诺书（占位）──
    d = PACK / "01-承诺书盖章扫描"
    d.mkdir(parents=True, exist_ok=True)
    (d / "说明.txt").write_text(
        "本目录放**承诺书盖章扫描件**。\n\n"
        "步骤：\n"
        "  1. 到竞赛官网（cmit.cn）下载本届承诺书模板\n"
        "  2. 三名学生手写签名、指导教师签名\n"
        "  3. 学校/学院盖章\n"
        "  4. 扫描成 PDF 或 JPG 放进来\n\n"
        "⚠ 这一步必须团队自己完成 —— 签名和盖章无法代做。\n",
        encoding="utf-8")
    print("  承诺书目录已建（含步骤说明）")

    # ── 05 参赛打包 ──
    d = PACK / "05-参赛打包ZIP"
    d.mkdir(parents=True, exist_ok=True)
    (d / "说明.txt").write_text(
        "本目录放最终打包的参赛 ZIP（≤10GB）。\n\n"
        "打包内容建议：\n"
        "  · 作品可运行包（scripts/ + data/ + assets/ + tools/ + 启动游戏.bat）\n"
        "  · 申报书 PDF\n"
        "  · 答辩 PPT\n"
        "  · 10 张作品截图\n"
        "  · 演示视频\n"
        "  · README（运行方式、AI 密钥说明）\n\n"
        "注意：**不要把 .venv / assets/_raw / logs 打进去**，那些是开发用中间产物，\n"
        "体积大且与评审无关。\n",
        encoding="utf-8")
    print("  打包目录已建（含打包内容建议）")

    # ── 90 原始材料 ──
    d = PACK / "90-原始材料"
    d.mkdir(parents=True, exist_ok=True)
    for name in ["《坎儿井》作品申报书.docx", "《坎儿井》作品申报书.pdf",
                 "坎儿井_创新点答辩.pptx", "坎儿井_作品展示.pptx"]:
        p = DELIV / name
        if p.exists():
            shutil.copy2(p, d / name)
    for name in ["README.md", "progress.md"]:
        p = ROOT / name
        if p.exists():
            shutil.copy2(p, d / name)
    d2 = d / "游戏封面"
    d2.mkdir(exist_ok=True)
    print("  原始材料 -> %s" % d.name)

    print("\n  目录树：")
    for p in sorted(PACK.iterdir()):
        if p.is_dir():
            print("    %s/  (%d 项)" % (p.name, len(list(p.iterdir()))))


if __name__ == "__main__":
    main()
