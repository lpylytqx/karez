@echo off
chcp 936 >nul
title 坎儿井 - 启动游戏
cd /d "%~dp0"

echo ================================================
echo   坎儿井  -  启动游戏
echo ================================================
echo.

set GODOT=%~dp0tools\Godot_v4.7.2-stable_win64.exe

if not exist "%GODOT%" (
    echo [错误] 找不到 Godot 可执行文件：
    echo        %GODOT%
    echo.
    echo   该文件约 172MB，超过 GitHub 单文件上限，未随仓库分发。
    echo   请到 https://godotengine.org/download 下载 Godot 4.7.2 标准版，
    echo   重命名为 Godot_v4.7.2-stable_win64.exe，放进 tools\ 目录。
    echo.
    pause
    exit /b 1
)

if not exist "%~dp0scripts\project.godot" (
    echo [错误] 找不到工程文件：
    echo        %~dp0scripts\project.godot
    echo.
    echo   如果六个素材目录（tiles / buildings / characters / fonts / fx / audio）
    echo   显示为断开的快捷方式，请先双击运行：
    echo        scripts\rebuild_links.ps1
    echo.
    pause
    exit /b 1
)

echo [1/2] 检查 AI 服务 ...
powershell -NoProfile -Command "try{(Invoke-WebRequest -Uri 'http://127.0.0.1:8787/health' -TimeoutSec 3 -UseBasicParsing)|Out-Null;exit 0}catch{exit 1}" >nul 2>&1
if %errorlevel%==0 (
    echo       在线  -  角色对话走真实 DeepSeek
) else (
    echo       未启动  -  游戏照常能玩，只是对话走预设兜底
    echo       想接通真实 AI：先双击「启动AI服务.bat」
)

echo.
echo [2/2] 启动游戏 ...
echo.
echo   操作说明：
echo     WASD 或方向键      移动角色
echo     点地图上的竖井     开挖（也可用右侧「挖竖井」按钮）
echo     「推进时段」       晨 - 午 - 暮 - 夜，跨过夜晚结算一天
echo     「查看事件」       手动触发一条事件
echo     底部输入框         和角色对话（需要 AI 服务）
echo     右侧「存档 / 读档」 保存进度
echo.
echo   游戏窗口打开后，本窗口可以关掉。
echo.

start "" "%GODOT%" --path "%~dp0scripts"
exit /b 0
