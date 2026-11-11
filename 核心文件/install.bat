@echo off
cd /d "%~dp0"
title Yuketang Auto Study - Installer

echo ==========================================
echo   Yuketang Auto Study - Installer
echo ==========================================
echo.

set "PY="
for /f "delims=" %%i in ('where python 2^>nul ^| findstr /i /v "WindowsApps"') do if not defined PY set "PY=%%i"
if not defined PY for /f "delims=" %%i in ('where py 2^>nul ^| findstr /i /v "WindowsApps"') do if not defined PY set "PY=%%i -3"
if not defined PY if exist "E:\Python313\python.exe" set "PY=E:\Python313\python.exe"
if not defined PY if exist "%LocalAppData%\Programs\Python\Python39\python.exe" set "PY=%LocalAppData%\Programs\Python\Python39\python.exe"
if not defined PY (
    echo [ERROR] Python not found.
    echo Opening download page...
    start "" "https://www.python.org/downloads/"
    pause
    exit /b 1
)
echo Python: %PY%

echo.
echo [1/2] Installing dependencies...
%PY% -m pip install -r requirements.txt
if errorlevel 1 (
    echo [WARN] pip install failed, trying mirror...
    %PY% -m pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple
)
%PY% -c "import websockets" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] dependencies still missing
    pause
    exit /b 1
)

echo.
echo [2/2] Launching start.bat ...
echo.
call start.bat
