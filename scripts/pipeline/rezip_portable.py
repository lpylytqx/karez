#!/usr/bin/env python -u
# -*- coding: utf-8 -*-
"""重新打包参赛包：**顶层套一个文件夹**，解压就是一个干净目录，别人拿到就能用。

三个要点：
  1. 所有东西放进 `坎儿井/` 这一层 —— 否则解压会把 scripts/ assets/ tools/ 直接
     倒进人家桌面，既不体面也容易覆盖同名目录
  2. 根目录放一份 `运行说明.txt` —— 双击哪个、要不要联网、AI 连不上会怎样，一次说清
  3. junction 会被 zipfile 展开成**真文件**（验证过 external_attr 是普通文件），
     所以解压到任何盘符都能跑，不会留下指向 D:\\坎儿井 的死链接

用法：.venv\\Scripts\\python.exe scripts\\pipeline\\rezip_portable.py
"""
from __future__ import annotations

import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import ROOT, PACK  # noqa: E402

TOP = "坎儿井"
OUT = PACK / "05-参赛打包ZIP" / "坎儿井_参赛包.zip"

EXCLUDE_DIRS = {".venv", ".dsh-pyenv", "logs", "dsh-image-gen", "deliverables",
                "参赛材料", "__pycache__", ".git", ".dsh-notes"}
EXCLUDE_REL = {"assets/_raw"}

README = """坎儿井 —— 运行说明
================================================

【怎么玩】
  双击  启动游戏.bat
  窗口打开后，本窗口可以关掉。无需安装任何东西。

【要不要联网 / AI 服务】
  不用。AI 服务（启动AI服务.bat）只是让角色对话由大模型实时生成；
  不启动它，游戏一样能完整游玩，对话走预设台词。
  也就是说：断网、没装 Python，都能玩。

【几个入口】
  启动游戏.bat        —— 正常开局（先进标题画面，按任意键开始）
  启动_御敌演示.bat    —— 直接跳到战场布阵阶段，方便看战斗

【操作】
  WASD 或方向键      移动主角
  点地图上的空位      派一个人过去（也可以点右侧「功能」里的按钮）
  「推进时段」        晨 → 午 → 暮 → 夜，每过一天
  滚轮 / +-           缩放地图
  按住左键拖动        平移地图
  F                   镜头回到主角
  底部输入框          和角色对话（需要 AI 服务；没开也能说话，走预设）

【里面都有什么】
  scripts\\      游戏本体（Godot 工程 + 代码）
  assets\\       美术与音频
  data\\         全部玩法数值（numbers.json）与事件库 —— 纯文本，可以直接打开看
  ai_backend\\   AI 服务（可选）
  tools\\        Godot 运行时
  参赛材料\\     申报书、答辩 PPT、10 张作品截图、游戏封面

【要求】
  Windows 10/11 64 位。显卡驱动正常即可，不需要独立显卡。
"""


def skip(p: Path) -> bool:
    rel = p.relative_to(ROOT)
    if any(part in EXCLUDE_DIRS for part in rel.parts):
        return True
    s = rel.as_posix()
    return any(s == e or s.startswith(e + "/") for e in EXCLUDE_REL)


def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    n = 0
    with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        for p in sorted(ROOT.rglob("*")):
            if not p.is_file() or skip(p):
                continue
            z.write(p, "%s/%s" % (TOP, p.relative_to(ROOT).as_posix()))
            n += 1
        for p in sorted(PACK.rglob("*")):
            if p.is_file() and not p.name.endswith(".zip"):
                z.write(p, "%s/参赛材料/%s" % (TOP, p.relative_to(PACK).as_posix()))
                n += 1
        z.writestr("%s/运行说明.txt" % TOP, README)
        n += 1
    print("  参수包：%s" % OUT.name)
    print("    顶层文件夹：%s/" % TOP)
    print("    文件数 %d，大小 %.1f MB" % (n, OUT.stat().st_size / 1024 / 1024))

    # 自检：顶层只有这一个文件夹 + 说明
    with zipfile.ZipFile(OUT) as z:
        tops = sorted({x.split("/")[0] for x in z.namelist()})
        print("    顶层条目：%s" % tops)
        must = ["%s/启动游戏.bat" % TOP, "%s/scripts/project.godot" % TOP,
                "%s/data/numbers.json" % TOP,
                "%s/tools/Godot_v4.7.2-stable_win64.exe" % TOP,
                "%s/运行说明.txt" % TOP,
                "%s/参赛材料/作品截图10张/01_治水成果_六段竖井挖通后的绿洲.jpg" % TOP]
        for m in must:
            print("    %-58s %s" % (m[len(TOP) + 1:], "在 ✓" if m in z.namelist() else "缺 ✗"))


if __name__ == "__main__":
    main()
