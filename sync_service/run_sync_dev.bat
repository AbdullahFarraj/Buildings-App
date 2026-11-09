@echo off
chcp 65001 > nul
cd /d "%~dp0"
echo ========================================================
echo   Starting Sync: DEVELOPMENT (binshafar-properties-dev)
echo ========================================================
node sync.js --env=dev
echo.
pause
