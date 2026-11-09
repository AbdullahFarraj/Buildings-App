@echo off
chcp 65001 > nul
cd /d "%~dp0"
echo ========================================================
echo   Auto Sync Service (Every 60 Minutes) - PRODUCTION
echo ========================================================
node sync.js --env=prod --loop 60
pause
