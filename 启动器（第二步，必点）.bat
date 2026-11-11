@echo off
cd /d "%~dp0"
if not exist "启动器（不用点）.ps1" (
    echo [ERROR] 找不到 启动器（不用点）.ps1
    pause
    exit /b 1
)
start "" powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0启动器（不用点）.ps1"
exit
