@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
title 雨课堂自动刷课 - 一键安装

set "REPO=GPIO-PullUpTo-THEBEST/yuketang_autowatch"
set "ZIPURL=https://github.com/%REPO%/archive/refs/heads/main.zip"
set "DEST=%USERPROFILE%\yuketang-auto-study"
set "TMPZIP=%TEMP%\ykt-auto.zip"
set "TMPDIR=%TEMP%\ykt-auto-extract"

echo ==========================================
echo   雨课堂自动刷课  一键安装
echo ==========================================
echo.

rem ---------- 1. 检查 Python ----------
echo [1/5] 检查 Python...
set "PY="
where python >nul 2>&1 && set "PY=python"
if not defined PY ( where py >nul 2>&1 && set "PY=py" )
if not defined PY (
    echo.
    echo [错误] 没找到 Python
    echo 请先安装： https://www.python.org/downloads/
    echo 安装时务必勾选 "Add python.exe to PATH"
    echo.
    pause
    start "" "https://www.python.org/downloads/"
    exit /b 1
)
for /f "delims=" %%v in ('%PY% --version 2^>^&1') do echo       %%v

rem ---------- 2. 下载 ----------
echo.
echo [2/5] 下载脚本...
if exist "%TMPZIP%" del /q "%TMPZIP%"
powershell -NoProfile -Command "try{Invoke-WebRequest -Uri '%ZIPURL%' -OutFile '%TMPZIP%' -UseBasicParsing -TimeoutSec 60;exit 0}catch{exit 1}"
if errorlevel 1 (
    echo.
    echo [错误] 下载失败，检查网络后重试
    echo 也可以手动下载： %ZIPURL%
    pause
    exit /b 1
)
for %%f in ("%TMPZIP%") do echo       已下载 %%~zf 字节

rem ---------- 3. 解压 ----------
echo.
echo [3/5] 解压到 %DEST%
if exist "%TMPDIR%" rmdir /s /q "%TMPDIR%"
powershell -NoProfile -Command "Expand-Archive -Path '%TMPZIP%' -DestinationPath '%TMPDIR%' -Force"
if not exist "%TMPDIR%" (
    echo [错误] 解压失败
    pause
    exit /b 1
)

if exist "%DEST%" (
    echo       清理旧版本...
    rmdir /s /q "%DEST%"
)
for /d %%d in ("%TMPDIR%\*") do (
    move "%%d" "%DEST%" >nul
    goto :moved
)
:moved
rmdir /s /q "%TMPDIR%"
del /q "%TMPZIP%" 2>nul

if not exist "%DEST%\run_all.py" (
    echo [错误] 解压后找不到 run_all.py
    pause
    exit /b 1
)
echo       完成

rem ---------- 4. 装依赖 ----------
echo.
echo [4/5] 安装依赖...
cd /d "%DEST%"
%PY% -m pip install -r requirements.txt --quiet --disable-pip-version-check
%PY% -c "import websockets" >nul 2>&1
if errorlevel 1 (
    echo [错误] 依赖安装失败，手动执行： %PY% -m pip install websockets
    pause
    exit /b 1
)
echo       完成

rem ---------- 5. 启动 ----------
echo.
echo [5/5] 准备启动...
echo.
echo ==========================================
echo   安装完成，目录： %DEST%
echo ==========================================
echo.
echo 接下来会自动启动 start.bat
echo 它会重启 Chrome 并等你登录雨课堂
echo.
pause

if exist "%DEST%\start.bat" (
    call "%DEST%\start.bat"
) else (
    %PY% -u run_all.py
    pause
)
