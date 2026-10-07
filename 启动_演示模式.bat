@echo off
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

set GODOT=%~dp0tools\Godot_v4.7.2-stable_win64.exe

if not exist "%GODOT%" (
    echo [错误] 找不到 Godot 可执行文件：
    echo        %GODOT%
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

if not exist "%~dp0scripts\.godot" (
    echo [首次运行] 正在导入素材，约需 10-40 秒，请稍候 ...
    "%~dp0tools\Godot_v4.7.2-stable_win64_console.exe" --path "%~dp0scripts" --headless --import >nul 2>&1
    echo            导入完成。
    echo.
)

start "" "%GODOT%" --path "%~dp0scripts" -- --demo
exit /b 0
