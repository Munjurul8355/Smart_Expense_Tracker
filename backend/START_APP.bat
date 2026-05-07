@echo off
echo ========================================
echo Starting Expense Tracker Application
echo ========================================

REM Start Backend Server
echo Starting Backend Server...
cd /d C:\Flutter\expense_tracker\backend
start "Backend Server" cmd /k "node server.js"

REM Wait 5 seconds
timeout /t 5 /nobreak >nul

REM Start Flutter App
echo Starting Flutter App...
cd /d C:\Flutter\expense_tracker
start "Flutter App" cmd /k "flutter run -d chrome"

echo.
echo ========================================
echo Both servers are starting!
echo Please wait for Chrome to open...
echo ========================================
echo.
pause