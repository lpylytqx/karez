@echo off
chcp 936 >nul
title 坎儿井 - AI 服务
cd /d "%~dp0"

echo ================================================
echo   坎儿井  -  AI 旁挂服务
echo ================================================
echo.

set PY=%~dp0.venv\Scripts\python.exe

if not exist "%PY%" (
    echo [错误] 找不到 Python 虚拟环境：
    echo        %PY%
    echo.
    echo   请先在项目根目录重建虚拟环境并安装依赖：
    echo        py -3 -m venv .venv
    echo        .venv\Scripts\python.exe -m pip install -r ai_backend\requirements.txt
    echo.
    pause
    exit /b 1
)

if not exist "%~dp0ai_backend\.env" (
    echo [提示] 还没有 ai_backend\.env
    echo        服务会以 demo 模式运行（返回预设台词，不调用模型）。
    echo        要接通真实 AI：
    echo          1. 复制 ai_backend\.env.example 为 ai_backend\.env
    echo          2. 填入 DEEPSEEK_API_KEY，确认 FORCE_DEMO=0
    echo.
)

echo 服务地址： http://127.0.0.1:8787
echo 健康检查： http://127.0.0.1:8787/health
echo.
echo 保持本窗口开着，关掉即停止服务。
echo 按 Ctrl+C 可手动停止。
echo ================================================
echo.

"%PY%" "%~dp0ai_backend\main.py"

echo.
echo 服务已停止。
pause
