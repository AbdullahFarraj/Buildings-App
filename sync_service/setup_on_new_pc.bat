@echo off
chcp 65001 > nul
cd /d "%~dp0"
echo ========================================================
echo   Checking Node.js and Installing Dependencies...
echo ========================================================
node -v
call npm install
echo.
echo ========================================================
echo   Setup Completed! You can now run run_sync_prod.bat
echo ========================================================
pause
