@echo off
chcp 65001 > nul
cd /d "%~dp0"
echo ========================================================
echo   Starting Sync: PRODUCTION (building-app1)
echo ========================================================
node sync.js --env=prod
echo.
pause
