#!/usr/bin/env python -u
# -*- coding: utf-8 -*-
"""给演示导演配一个双击入口，并把用法写进随包说明。

产出：
  · 项目根 `启动_演示模式.bat`（**GBK + CRLF** —— 项目约定，中文 Windows 的 cmd
    默认代码页 936，UTF-8 的 bat 会乱码）
  · 更新 rezip_clean.py 里的 `运行说明.txt`，把演示模式的按键写进去
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _root import ROOT  # noqa: E402

BAT = """@echo off
chcp 936 >nul
title 坎儿井 - 演示模式（录视频用）
cd /d "%~dp0"

echo ================================================
echo   坎儿井  -  演示模式
echo ================================================
echo.
echo   这个入口把整条展示线索拆成 14 屏，按一下键就跳到下一屏，
echo   录演示视频时不用顺着游戏时间慢慢玩。
echo.
echo     空格 / 右方向键   下一屏
echo     左方向键          上一屏
echo     H                 隐藏/显示提示条（录正式画面时按它藏起来）
echo     R                 从第一屏重来
echo.
echo   14 屏依次是：
echo     开局荒地 / 六段竖井 / 九个岗位 / 建造 / AI事件卡 /
echo     御敌布阵 / 御敌开打 / 畜牧 / 木卡姆 / 灾难通告 /
echo     冬季 / 春季 / 镜头缩放 / 收尾全景
echo.
echo   注意：演示模式只改内存里的状态，**别点「存档」**，
echo         否则会把演示局面存下去。
echo.

set GODOT=%~dp0tools\\Godot_v4.7.2-stable_win64.exe

if not exist "%GODOT%" (
    echo [错误] 找不到 Godot 可执行文件：
    echo        %GODOT%
    echo.
    pause
    exit /b 1
)

if not exist "%~dp0scripts\\project.godot" (
    echo [错误] 找不到工程文件：%~dp0scripts\\project.godot
    echo        如果素材目录显示为断开的快捷方式，先运行 scripts\\rebuild_links.ps1
    echo.
    pause
    exit /b 1
)

if not exist "%~dp0scripts\\.godot" (
    echo [首次运行] 正在导入素材，约需 10-40 秒，请稍候 ...
    "%~dp0tools\\Godot_v4.7.2-stable_win64_console.exe" --path "%~dp0scripts" --headless --import >nul 2>&1
    echo            导入完成。
    echo.
)

start "" "%GODOT%" --path "%~dp0scripts" -- --demo
exit /b 0
"""

README_OLD = """【几个入口】
  启动游戏.bat        —— 正常开局（先进标题画面，按任意键开始）
  启动_御敌演示.bat    —— 直接跳到战场布阵阶段，方便看战斗
  启动AI服务.bat      —— （可选）接通大模型
"""

README_NEW = """【几个入口】
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
"""


def main() -> None:
    p = ROOT / "启动_演示模式.bat"
    p.write_bytes(BAT.replace("\n", "\r\n").encode("gbk"))
    b = p.read_bytes()
    print("  已写 %s（%d 字节，GBK=%s，CRLF=%s）"
          % (p.name, len(b), "✓" if _is_gbk(b) else "✗", "✓" if b"\r\n" in b else "✗"))

    rz = ROOT / "scripts" / "pipeline" / "rezip_clean.py"
    t = rz.read_text(encoding="utf-8")
    if "启动_演示模式" in t:
        print("  rezip_clean.py 的说明里已有演示模式，跳过")
    elif README_OLD in t:
        rz.write_text(t.replace(README_OLD, README_NEW, 1), encoding="utf-8")
        back = rz.read_text(encoding="utf-8")
        print("  运行说明已补演示模式，回读：%s"
              % ("✓" if "启动_演示模式" in back else "✗"))
        import py_compile
        py_compile.compile(str(rz), doraise=True)
    else:
        print("  [X] rezip_clean.py 的说明锚点没匹配上")


def _is_gbk(b: bytes) -> bool:
    try:
        b.decode("gbk")
        return True
    except UnicodeDecodeError:
        return False


if __name__ == "__main__":
    main()
