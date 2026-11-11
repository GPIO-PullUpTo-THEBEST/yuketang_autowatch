@echo off
title Stop Yuketang Auto Study
echo Stopping runner...
powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='python.exe'\" | Where-Object { $_.CommandLine -match 'run_all' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force; Write-Host ('Stopped PID ' + $_.ProcessId) }"
echo.
echo Done. Chrome stays open, progress saved.
timeout /t 3 /nobreak >nul
