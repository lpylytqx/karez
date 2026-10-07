@echo off
chcp 936 >nul
title 坎儿井 - 御敌演示（直接进布阵）
cd /d "%~dp0"

echo ================================================
echo   坎儿井  -  御敌演示
echo ================================================
echo.
echo   这个入口会跳过前置，直接把你送到东边战场，
echo   停在「布阵」阶段。
echo.

set GODOT=%~dp0tools\Godot_v4.7.2-stable_win64.exe

if not exist "%GODOT%" (
    echo [错误] 找不到 Godot 可执行文件：
    echo        %GODOT%
    echo.
    echo   请到 https://godotengine.org/download 下载 Godot 4.7.2 标准版，
    echo   重命名为 Godot_v4.7.2-stable_win64.exe，放进 tools\ 目录。
    echo.
    pause
    exit /b 1
)

if not exist "%~dp0scripts\project.godot" (
    echo [错误] 找不到工程文件：%~dp0scripts\project.godot
    echo        如果素材目录显示为断开的快捷方式，先运行 scripts\rebuild_links.ps1
    echo.
    pause
    exit /b 1
)

echo   操作说明：
echo     点地图上的空位      放一个人上去（最多 6 人）
echo     点已布阵的人        把他收回
echo     「自动布阵」        一键按前排优先站位
echo     「开战」            打完看战果
echo     「结束」            收场，镜头回主角
echo.
echo     滚轮 / +-           缩放
echo     按住左键拖动        平移地图
echo     F                   镜头回到主角（头顶带「驿丞」金字）
echo.
echo   注意：演示只改内存里的状态，**别点「存档」**，否则会把演示局面存下去。
echo.
echo   游戏窗口打开后，本窗口可以关掉。
echo.

if not exist "%~dp0scripts\\.godot\" (
    echo [首次运行] 正在导入素材，约需 10-40 秒，请稍候 ...
    "%~dp0tools\\Godot_v4.7.2-stable_win64_console.exe" --path "%~dp0scripts" --headless --import >nul 2>&1
    echo            导入完成。
    echo.
)
start "" "%GODOT%" --path "%~dp0scripts" -- --battle
exit /b 0
