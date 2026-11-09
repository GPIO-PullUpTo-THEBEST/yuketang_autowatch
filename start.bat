@echo off
cd /d "%~dp0"
title Yuketang Auto Study

echo ==========================================
echo   Yuketang Auto Study
echo ==========================================
echo.

set "PY="
for /f "delims=" %%i in ('where python 2^>nul') do if not defined PY set "PY=%%i"
if not defined PY for /f "delims=" %%i in ('where py 2^>nul') do if not defined PY set "PY=%%i -3"
if not defined PY if exist "E:\Python313\python.exe" set "PY=E:\Python313\python.exe"
if not defined PY if exist "%LocalAppData%\Programs\Python\Python39\python.exe" set "PY=%LocalAppData%\Programs\Python\Python39\python.exe"
if not defined PY (
    echo [ERROR] Python not found.
    echo Install from https://www.python.org/downloads/
    pause
    exit /b 1
)
echo Python: %PY%
%PY% -c "import sys" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python cannot run: %PY%
    pause
    exit /b 1
)

%PY% -c "import websockets" >nul 2>&1
if errorlevel 1 (
    echo Installing dependencies...
    %PY% -m pip install -r requirements.txt
)

set "CHROME="
if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" set "CHROME=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if not defined CHROME if exist "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" set "CHROME=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
if not defined CHROME if exist "%LocalAppData%\Google\Chrome\Application\chrome.exe" set "CHROME=%LocalAppData%\Google\Chrome\Application\chrome.exe"
if not defined CHROME (
    echo [ERROR] chrome.exe not found.
    pause
    exit /b 1
)

set "PROFILE=%USERPROFILE%\ykt-chrome-profile"

echo.
echo [1/3] Checking debug port 9222...
powershell -NoProfile -Command "try{(Invoke-WebRequest 'http://127.0.0.1:9222/json/version' -UseBasicParsing -TimeoutSec 2)|Out-Null;exit 0}catch{exit 1}" >nul 2>&1
if %errorlevel%==0 (
    echo       Already running, skip Chrome restart
    goto :run
)

echo [2/3] Restarting Chrome with debug port...
echo       All Chrome windows will be closed in 3 seconds
timeout /t 3 /nobreak >nul
taskkill /IM chrome.exe /F >nul 2>&1
timeout /t 4 /nobreak >nul
start "" "%CHROME%" --remote-debugging-port=9222 --user-data-dir="%PROFILE%"
timeout /t 10 /nobreak >nul

powershell -NoProfile -Command "try{(Invoke-WebRequest 'http://127.0.0.1:9222/json/version' -UseBasicParsing -TimeoutSec 5)|Out-Null;exit 0}catch{exit 1}" >nul 2>&1
if not %errorlevel%==0 (
    echo [ERROR] Debug port 9222 not ready
    pause
    exit /b 1
)

echo.
echo       If not logged in, open https://www.yuketang.cn and scan QR code
echo       Press any key when ready
pause >nul

:run
echo.
echo [3/3] Starting...
echo ------------------------------------------
echo Keep the debug Chrome window OPEN
echo Press Ctrl+C to stop
echo ------------------------------------------
echo.

%PY% -u run_all.py

echo.
echo ==========================================
echo   Finished. Progress saved in progress.json
echo ==========================================
pause
