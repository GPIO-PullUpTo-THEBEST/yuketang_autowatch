@echo off
chcp 65001 >nul
cd /d "%~dp0"
title Yuketang Auto Study

echo ==========================================
echo   Yuketang Auto Study
echo ==========================================
echo.

rem ---- 找 Python ----
set "PY="
where python >nul 2>&1 && set "PY=python"
if not defined PY (
    where py >nul 2>&1 && set "PY=py"
)
if not defined PY (
    echo [ERROR] Python not found in PATH.
    echo Install Python 3.8+ or edit the PY variable in this file.
    pause
    exit /b 1
)
echo Using Python: %PY%
%PY% -c "import websockets" >nul 2>&1
if errorlevel 1 (
    echo Installing dependencies...
    %PY% -m pip install -r requirements.txt
)
echo.

rem ---- Chrome 路径 ----
set "CHROME="
if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" set "CHROME=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if not defined CHROME if exist "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" set "CHROME=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
if not defined CHROME if exist "%LocalAppData%\Google\Chrome\Application\chrome.exe" set "CHROME=%LocalAppData%\Google\Chrome\Application\chrome.exe"
if not defined CHROME (
    echo [ERROR] chrome.exe not found. Edit CHROME variable in this file.
    pause
    exit /b 1
)

set "PROFILE=%USERPROFILE%\ykt-chrome-profile"

echo [1/4] Checking debug port %CDP_PORT%...
powershell -NoProfile -Command "try{(Invoke-WebRequest 'http://127.0.0.1:9222/json/version' -UseBasicParsing -TimeoutSec 2)|Out-Null;exit 0}catch{exit 1}" >nul 2>&1
if %errorlevel%==0 (
    echo       Port 9222 ready, skip Chrome restart
    goto :run
)

echo [2/4] Restarting Chrome with debug port...
echo       All Chrome windows will be closed in 3 seconds
timeout /t 3 /nobreak >nul
taskkill /IM chrome.exe /F >nul 2>&1
timeout /t 4 /nobreak >nul

echo [3/4] Launching Chrome debug instance...
start "" "%CHROME%" --remote-debugging-port=9222 --user-data-dir="%PROFILE%"
timeout /t 10 /nobreak >nul

powershell -NoProfile -Command "try{(Invoke-WebRequest 'http://127.0.0.1:9222/json/version' -UseBasicParsing -TimeoutSec 5)|Out-Null;exit 0}catch{exit 1}" >nul 2>&1
if not %errorlevel%==0 (
    echo [ERROR] Debug port did not come up
    pause
    exit /b 1
)
echo       Port 9222 OK

echo.
echo       If you are not logged in yet, log in at https://www.yuketang.cn
echo       Press any key when ready
pause >nul

:run
echo.
echo [4/4] Starting...
echo ------------------------------------------
echo Do NOT close the debug Chrome window
echo Press Ctrl+C to stop at any time
echo ------------------------------------------
echo.

%PY% -u run_all.py

echo.
echo ==========================================
echo   Finished
echo ==========================================
echo Progress saved in progress.json
echo Next run resumes from where it stopped
echo.
pause
