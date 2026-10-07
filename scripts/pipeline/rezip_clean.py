#!/usr/bin/env python -u
# -*- coding: utf-8 -*-
"""打**上传用**的参赛包 —— 只放有用的东西。

对照：非遗那个参赛包只有 55 个文件 / 12.7 MB，里面是「运行必需的最少源码 + 素材 + 文档材料」，
没有开发脚本、没有截图、没有日志。我上一版塞了 5423 个文件 / 422 MB，明显不对。

砍掉的（都是"对评审无用"或"重复"）：
  · assets/              —— 与 scripts/ 下的素材**完全重复**（约 290 MB）。游戏读的是
                            res://… 即 scripts/ 那份；assets/ 只是开发期的源目录
  · scripts/.godot/      —— 导入缓存 90 MB。Godot 首次运行会自动重建；
                            而且它内部存**绝对路径**，带到别的机器反而是隐患
  · fonts/*.zip          —— 字体原始下载压缩包 37 MB（用的是解压后的 ttf）
  · fonts/ 其余 13 个语种字体 —— 游戏只引用 zh_hans 那一个
  · docs/ deliverables/ logs/ dsh-image-gen/ 参赛材料/ —— 开发与过程文件
  · scripts/pipeline/ capture_*.gd diag_*.gd —— 我自己的开发脚本与截图工具
  · **/__pycache__/ .venv/ .dsh-pyenv/

保留的（评审需要的）：
  · tools/Godot…win64.exe + 启动*.bat + 运行说明.txt  —— 解压即可运行
  · scripts/ 游戏工程与素材（junction 已展开成真文件）
  · data/ 全部数值与事件（纯文本，可核查）
  · ai_backend/ 本地 AI 服务（可选）
  · 文档材料/ 八份参赛文档（含签好名的分工说明）
  · 作品截图/ 十张（另有一个单独上传口，但放进来让包自足）

用法：.venv\\Scripts\\python.exe scripts\\pipeline\\rezip_clean.py
"""
from __future__ import annotations

import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import ROOT, DELIVERABLES, PACK  # noqa: E402

TOP = "坎儿井"
OUT = PACK / "05-参赛打包ZIP" / "坎儿井_参赛包.zip"

DROP_DIRS = {".venv", ".dsh-pyenv", ".dsh-notes", "assets", "docs", "logs",
             "deliverables", "dsh-image-gen", "参赛材料", "__pycache__", ".git"}

# 相对于项目根的前缀（目录或文件）一律不打包
DROP_REL_PREFIX = (
    "scripts/.godot", "scripts/pipeline",
)
# 文件名/后缀规则
DROP_SUFFIX = (".zip",)
DROP_NAME_GLOBS = ("capture_*.gd", "capture_*.tscn", "diag_*.gd", "diag_*.tscn",
                   "*.pyc", "rebuild_links.ps1")

# 游戏只引用这一个字体；其余语种与原始压缩包都不要
KEEP_FONT = "ark-pixel-12px-proportional-zh_hans.ttf"

# 这几个是**填报辅助材料**，只给操作者自己对照，不随包提交：
#     · 在线填报速查表 —— 填报人看着填的，评审不需要
# 打包脚本是按目录批量收 docx 的，光靠"这次没拷进去"不够，写死排除才稳。
NEVER_PACK = ("速查表", "填报")


def keep(rel: str) -> bool:
    parts = rel.split("/")
    if any(p in DROP_DIRS for p in parts[:-1]) or parts[0] in DROP_DIRS:
        return False
    if rel.startswith(DROP_REL_PREFIX):
        return False
    name = parts[-1]
    if name.endswith(DROP_SUFFIX):
        return False
    for g in DROP_NAME_GLOBS:
        if Path(name).match(g):
            return False
    # 字体目录：只留用到的那一个（以及它的 .import）
    if rel.startswith("scripts/fonts/") or rel.startswith("fonts/"):
        return KEEP_FONT in name
    return True


README = """坎儿井 —— 运行说明
================================================

【怎么玩】
  双击  启动游戏.bat
  窗口打开后，本目录的命令行窗口可以关掉。无需安装任何东西。

【要不要联网 / 装 Python】
  都不用。AI 服务（启动AI服务.bat）只是让角色对话由大模型实时生成；
  不启动它，游戏一样能完整游玩，对话走预设台词。

【几个入口】
  启动游戏.bat        —— 正常开局（先进标题画面，按任意键开始）
  启动_御敌演示.bat    —— 直接跳到战场布阵阶段，方便看战斗
  启动_演示模式.bat    —— **录演示视频用**：整条线索拆成 14 屏，
                        按一下键跳到下一屏，不用顺着游戏时间慢慢玩
  启动AI服务.bat      —— （可选）接通大模型

【演示模式怎么用】
  双击 启动_演示模式.bat，进去后：
    空格 / 右方向键   下一屏
    左方向键          上一屏
    H                 隐藏提示条（录正式画面时按它藏起来）
    R                 从第一屏重来
  14 屏依次是：开局荒地 / 六段竖井 / 九个岗位 / 建造 / AI事件卡 /
  御敌布阵 / 御敌开打 / 畜牧 / 木卡姆 / 灾难通告 / 冬季 / 春季 /
  镜头缩放 / 收尾全景。
  ⚠ 演示模式只改内存里的状态，别点「存档」。

【操作】
  WASD 或方向键      移动主角
  点地图上的空位      派一个人过去（也可点右侧「功能」）
  「推进时段」        晨 → 午 → 暮 → 夜
  滚轮 / +-           缩放地图
  按住左键拖动        平移地图
  F                   镜头回到主角
  底部输入框          和角色对话

【目录说明】
  scripts\\      游戏工程与全部素材
  data\\         全部玩法数值与事件库（纯文本，可直接打开核查）
  ai_backend\\   AI 服务（可选）
  tools\\        Godot 运行时
  文档材料\\     参赛文档（作品说明、运行说明、AI 工具使用说明、
                 知识产权说明、图像佐证、团队分工与贡献说明等）
  作品截图\\     十张作品截图

【要求】
  Windows 10/11 64 位，集成显卡即可。
"""


def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    n = 0
    raw = 0
    with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        for p in sorted(ROOT.rglob("*")):
            if not p.is_file():
                continue
            rel = p.relative_to(ROOT).as_posix()
            if not keep(rel):
                continue
            z.write(p, "%s/%s" % (TOP, rel))
            n += 1
            raw += p.stat().st_size
        # 文档材料（八份）
        for p in sorted((DELIVERABLES / "参赛文档").glob("*.docx")):
            if any(k in p.name for k in NEVER_PACK):
                print("    [不进包] %s（填报辅助材料）" % p.name)
                continue
            z.write(p, "%s/文档材料/%s" % (TOP, p.name))
            n += 1
        # 合并稿（展示 + 答辩合成一份）—— 不再单独放原来那两份
        _m = DELIVERABLES / "坎儿井_完整版.pptx"
        if _m.exists():
            z.write(_m, "%s/文档材料/%s" % (TOP, _m.name))
            n += 1
        for name in ("《坎儿井》作品信息表.docx", "《坎儿井》作品申报书.docx",
                     "《坎儿井》作品申报书.pdf"):
            q = DELIVERABLES / name
            if q.exists():
                z.write(q, "%s/文档材料/%s" % (TOP, name))
                n += 1
        # 作品截图（十张）
        for p in sorted((PACK / "作品截图10张").glob("*.jpg")):
            z.write(p, "%s/作品截图/%s" % (TOP, p.name))
            n += 1
        z.writestr("%s/运行说明.txt" % TOP, README)
        n += 1

    print("  参赛包：%s" % OUT.name)
    print("    文件数 %d（上一版 5423）" % n)
    print("    压缩前 %.1f MB　打包后 %.1f MB（上一版 422.5 MB）"
          % (raw / 1024 / 1024, OUT.stat().st_size / 1024 / 1024))
    with zipfile.ZipFile(OUT) as z:
        names = z.namelist()
        print("    顶层条目：%s" % sorted({x.split("/")[0] for x in names}))
        print("    %-30s %s" % ("一级目录/文件：", ""))
        tops = {}
        for x in names:
            if x.endswith("/"):
                continue
            k = x.split("/")[1] if len(x.split("/")) > 2 else "(根)"
            tops[k] = tops.get(k, 0) + 1
        for k in sorted(tops):
            print("      %-24s %4d 个" % (k, tops[k]))
        print("    关键项自检：")
        for probe in ("%s/启动游戏.bat" % TOP, "%s/scripts/project.godot" % TOP,
                      "%s/data/numbers.json" % TOP,
                      "%s/tools/Godot_v4.7.2-stable_win64.exe" % TOP,
                      "%s/运行说明.txt" % TOP,
                      "%s/scripts/fonts/ark-12px/%s" % (TOP, KEEP_FONT)):
            print("      %-56s %s" % (probe[len(TOP) + 1:], "在 ✓" if probe in names else "缺 ✗"))


if __name__ == "__main__":
    main()
