@echo off
REM ==========================================
REM YOLO Vision System - One-click Start Script
REM ==========================================
REM Usage: start.bat
REM Stop: Press Ctrl+C
REM ==========================================

setlocal enabledelayedexpansion

REM Get script directory
set "SCRIPT_DIR=%~dp0"
set "BACKEND_DIR=%SCRIPT_DIR%backend"
set "FRONTEND_DIR=%SCRIPT_DIR%frontend"
set "PID_FILE=%TEMP%\yolo_pids.txt"

REM Colors (Windows 10+)
for /F %%a in ('echo prompt $E^| cmd') do set "ESC=%%a"
set "GREEN=!ESC![92m"
set "YELLOW=!ESC![93m"
set "RED=!ESC![91m"
set "BLUE=!ESC![94m"
set "NC=!ESC![0m"

REM Handle Ctrl+C
:setup_trap
REM Register cleanup on exit
if "%~1"=="cleanup" goto cleanup

REM Print header
echo.
echo %BLUE%==========================================%NC%
echo %BLUE%    YOLO Vision System - Starting%NC%
echo %BLUE%==========================================%NC%
echo.

REM Check dependencies
echo %YELLOW%[1/4] Checking environment...%NC%

where node >nul 2>&1
if errorlevel 1 (
    echo %RED%Error: Node.js not installed%NC%
    echo Please install Node.js: https://nodejs.org/
    exit /b 1
)

where python >nul 2>&1
if errorlevel 1 (
    echo %RED%Error: Python not installed%NC%
    echo Please install Python3
    exit /b 1
)

if not exist "%BACKEND_DIR%" (
    echo %RED%Error: Backend directory not found: %BACKEND_DIR%%NC%
    exit /b 1
)

if not exist "%FRONTEND_DIR%" (
    echo %RED%Error: Frontend directory not found: %FRONTEND_DIR%%NC%
    exit /b 1
)

for /f "tokens=*" %%i in ('node -v') do echo   Node.js: %%i
for /f "tokens=*" %%i in ('python --version') do echo   %%i
echo %GREEN%  Environment check passed%NC%
echo.

REM Install dependencies
echo %YELLOW%[2/4] Checking project dependencies...%NC%

python -c "import fastapi" >nul 2>&1
if errorlevel 1 (
    echo   Installing backend dependencies...
    pip install -q fastapi "uvicorn[standard]" websockets ultralytics opencv-python-headless numpy python-multipart pyyaml dashscope
)

if not exist "%FRONTEND_DIR%\node_modules" (
    echo   Installing frontend dependencies...
    cd /d "%FRONTEND_DIR%"
    call npm install --silent
    cd /d "%SCRIPT_DIR%"
)

echo %GREEN%  Dependencies check completed%NC%
echo.

REM Stop existing services
echo %YELLOW%[3/4] Cleaning up old processes...%NC%
taskkill /f /im "node.exe" /fi "WINDOWTITLE eq vite*" >nul 2>&1
REM Kill uvicorn on port 8000
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :8000 ^| findstr LISTENING') do taskkill /f /pid %%a >nul 2>&1
del /f "%PID_FILE%" >nul 2>&1
timeout /t 1 /nobreak >nul
echo %GREEN%  Cleanup completed%NC%
echo.

REM Start services
echo %YELLOW%[4/4] Starting services...%NC%
echo.

REM Set environment
set "PYTHONPATH=%BACKEND_DIR%"
set "OMP_NUM_THREADS=1"

REM Start backend
echo %GREEN%Starting backend service (port 8000)...%NC%
cd /d "%BACKEND_DIR%"
start /b python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
cd /d "%SCRIPT_DIR%"

REM Wait for backend
echo|set /p="  Waiting for backend"
:wait_backend
timeout /t 1 /nobreak >nul
curl -s http://localhost:8000/ >nul 2>&1
if errorlevel 1 (
    echo|set /p="."
    goto wait_backend
)
echo.
echo %GREEN%  Backend started successfully%NC%

REM Start frontend
echo.
echo %GREEN%Starting frontend service (port 3000)...%NC%
cd /d "%FRONTEND_DIR%"
start /b npm run dev -- --host 0.0.0.0
cd /d "%SCRIPT_DIR%"

timeout /t 2 /nobreak >nul
echo %GREEN%  Frontend started successfully%NC%
echo.

REM Print info
echo %BLUE%==========================================%NC%
echo %GREEN%  Services started successfully!%NC%
echo %BLUE%==========================================%NC%
echo.
echo   %GREEN%Frontend:%NC%  http://localhost:3000
echo   %GREEN%Backend:%NC%   http://localhost:8000
echo   %GREEN%API Docs:%NC%   http://localhost:8000/docs
echo.
echo   %YELLOW%Press Ctrl+C to stop services%NC%
echo.
echo %BLUE%==========================================%NC%
echo.

REM Open browser
timeout /t 2 /nobreak >nul
start http://localhost:3000
echo %GREEN%Browser opened: http://localhost:3000%NC%
echo.

REM Wait for user to press Ctrl+C
echo Press any key to stop services...
pause >nul

REM Cleanup on exit
:cleanup
echo.
echo %YELLOW%Stopping services...%NC%

REM Kill node processes for vite
taskkill /f /im "node.exe" /fi "WINDOWTITLE eq vite*" >nul 2>&1

REM Kill uvicorn on port 8000
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :8000 ^| findstr LISTENING') do taskkill /f /pid %%a >nul 2>&1

REM Kill node on port 3000
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :3000 ^| findstr LISTENING') do taskkill /f /pid %%a >nul 2>&1

del /f "%PID_FILE%" >nul 2>&1

echo %GREEN%Services stopped%NC%
echo %GREEN%Goodbye!%NC%
exit /b 0