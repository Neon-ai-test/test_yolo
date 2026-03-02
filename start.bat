@echo off
chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion

:: ==========================================
:: YOLO 视觉识别系统 - 启动脚本 v2.0
:: ==========================================
:: 功能：管理后端和前端服务
:: 用法：start.bat [command] [options]
:: ==========================================

set "SCRIPT_DIR=%~dp0"
set "BACKEND_DIR=%SCRIPT_DIR%backend"
set "FRONTEND_DIR=%SCRIPT_DIR%frontend"
set "LOGS_DIR=%SCRIPT_DIR%logs"
set "PID_DIR=%SCRIPT_DIR%.pids"

:: 默认端口
set "DEFAULT_API_PORT=8000"
set "DEFAULT_WEB_PORT=3000"

:: 当前配置
set "API_PORT=%DEFAULT_API_PORT%"
set "WEB_PORT=%DEFAULT_WEB_PORT%"
set "NO_BROWSER=false"
set "DEV_MODE=false"
set "COMMAND=start"

:: 日志文件
set "BACKEND_LOG=%LOGS_DIR%\backend.log"
set "FRONTEND_LOG=%LOGS_DIR%\frontend.log"
set "ERROR_LOG=%LOGS_DIR%\error.log"

:: PID 文件
set "BACKEND_PID_FILE=%PID_DIR%\backend.pid"
set "FRONTEND_PID_FILE=%PID_DIR%\frontend.pid"

:: 颜色定义 (Windows 10+)
for /f %%a in ('echo prompt $E^| cmd') do set "ESC=%%a"
set "GREEN=!ESC![92m"
set "YELLOW=!ESC![93m"
set "RED=!ESC![91m"
set "BLUE=!ESC![94m"
set "CYAN=!ESC![96m"
set "NC=!ESC![0m"
set "BOLD=!ESC![1m"

:: ==========================================
:: 工具函数
:: ==========================================

:log_info
echo %GREEN%[INFO]%NC% %~1
goto :eof

:log_warn
echo %YELLOW%[WARN]%NC% %~1
goto :eof

:log_error
echo %RED%[ERROR]%NC% %~1
goto :eof

:log_step
echo %CYAN%==^>%NC% %BOLD%%~1%NC%
goto :eof

:: 检查端口是否被占用
:check_port
netstat -ano | findstr ":%~1 " | findstr "LISTENING" >nul 2>&1
if %errorlevel% equ 0 (
    exit /b 0
) else (
    exit /b 1
)

:: 获取占用端口的 PID
:get_pid_by_port
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":%~1 " ^| findstr "LISTENING"') do (
    exit /b %%a
)
exit /b 1

:: 终止占用端口的进程
:kill_port
call :get_pid_by_port %~1
if !errorlevel! gtr 0 (
    taskkill /f /pid !errorlevel! >nul 2>&1
    timeout /t 1 /nobreak >nul
)
goto :eof

:: 等待服务启动
:wait_for_service
setlocal
set "PORT=%~1"
set "NAME=%~2"
set "MAX_WAIT=%~3"
if "%MAX_WAIT%"=="" set "MAX_WAIT=30"

echo   等待 %NAME% 启动
set "COUNT=0"
:wait_loop
timeout /t 1 /nobreak >nul
curl -s http://localhost:%PORT%/ >nul 2>&1
if !errorlevel! equ 0 (
    echo   [92m✓[0m
    endlocal & exit /b 0
)
set /a COUNT+=1
if !COUNT! LSS %MAX_WAIT% (
    echo -n .
    goto wait_loop
)
echo   [91m✗[0m
endlocal & exit /b 1

:: 检查服务状态
:check_service_status
setlocal
set "NAME=%~1"
set "PORT=%~2"
set "PID_FILE=%~3"

echo   %BOLD%%NAME%%NC%
if exist "%PID_FILE%" (
    set /p PID=<"%PID_FILE%"
    tasklist /fi "pid eq !PID!" | findstr /i "python.exe node.exe" >nul 2>&1
    if !errorlevel! equ 0 (
        echo     状态:   %GREEN%运行中%NC%
        echo     PID:    !PID!
    ) else (
        echo     状态:   %YELLOW%已停止 (PID 文件过期)%NC%
    )
) else (
    call :check_port !PORT!
    if !errorlevel! equ 0 (
        call :get_pid_by_port !PORT!
        echo     状态:   %YELLOW%运行中 (无 PID 文件)%NC%
        echo     PID:    !errorlevel!
    ) else (
        echo     状态:   %RED%已停止%NC%
    )
)
echo     端口:   !PORT!
echo     地址:   http://localhost:!PORT!
echo.
endlocal
goto :eof

:: ==========================================
:: 帮助信息
:: ==========================================
:show_help
echo.
echo %BLUE%用法:%NC%
echo   start.bat [command] [options]
echo.
echo %BLUE%命令:%NC%
echo   start       启动服务 (默认)
echo   stop        停止服务
echo   restart     重启服务
echo   status      查看服务状态
echo   logs        查看日志
echo   help        显示帮助信息
echo.
echo %BLUE%选项:%NC%
echo   --port-api PORT    API 端口 (默认: %DEFAULT_API_PORT%)
echo   --port-web PORT    前端端口 (默认: %DEFAULT_WEB_PORT%)
echo   --no-browser       不自动打开浏览器
echo   --dev              开发模式 (详细日志输出到控制台)
echo.
echo %BLUE%示例:%NC%
echo   start.bat                          启动服务 (默认端口)
echo   start.bat start --port-api 8080   使用自定义 API 端口启动
echo   start.bat stop                     停止服务
echo   start.bat restart                  重启服务
echo   start.bat status                   查看状态
echo   start.bat logs                     查看日志
echo.
exit /b 0

:: ==========================================
:: 参数解析
:: ==========================================
:parse_args
:parse_loop
if "%~1"=="" goto :parse_end
set "arg=%~1"

if "%arg%"=="start" set "COMMAND=start" & shift & goto :parse_loop
if "%arg%"=="stop" set "COMMAND=stop" & shift & goto :parse_loop
if "%arg%"=="restart" set "COMMAND=restart" & shift & goto :parse_loop
if "%arg%"=="status" set "COMMAND=status" & shift & goto :parse_loop
if "%arg%"=="logs" set "COMMAND=logs" & shift & goto :parse_loop
if "%arg%"=="help" set "COMMAND=help" & shift & goto :parse_loop

if "%arg%"=="--port-api" (
    set "API_PORT=%~2"
    shift & shift & goto :parse_loop
)
if "%arg%"=="--port-web" (
    set "WEB_PORT=%~2"
    shift & shift & goto :parse_loop
)
if "%arg%"=="--no-browser" (
    set "NO_BROWSER=true"
    shift & goto :parse_loop
)
if "%arg%"=="--dev" (
    set "DEV_MODE=true"
    shift & goto :parse_loop
)
if "%arg%"=="--help" goto :show_help

echo %RED%[ERROR]%NC% 未知参数: %arg%
goto :show_help

:parse_end
goto :eof

:: ==========================================
:: 检查依赖
:: ==========================================
:check_dependencies
call :log_step "检查运行环境..."
echo.

set "MISSING="
set "NODE_OK=false"
set "PYTHON_OK=false"

:: 检查 Node.js
where node >nul 2>&1
if !errorlevel! equ 0 (
    for /f "tokens=*" %%i in ('node -v') do echo   %GREEN%✓%NC% Node.js: %%i
    set "NODE_OK=true"
) else (
    echo   %RED%✗%NC% Node.js: 未安装
    set "MISSING=!MISSING!Node.js "
)

:: 检查 Python
where python >nul 2>&1
if !errorlevel! equ 0 (
    for /f "tokens=*" %%i in ('python --version') do echo   %GREEN%✓%NC% %%i
    set "PYTHON_OK=true"
) else (
    echo   %RED%✗%NC% Python: 未安装
    set "MISSING=!MISSING!Python "
)

:: 检查目录
if not exist "%BACKEND_DIR%" (
    call :log_error 找不到后端目录: %BACKEND_DIR%
    exit /b 1
)

if not exist "%FRONTEND_DIR%" (
    call :log_error 找不到前端目录: %FRONTEND_DIR%
    exit /b 1
)

if defined MISSING (
    call :log_error 缺少依赖: !MISSING!
    echo.
    echo 安装建议:
    echo   Node.js:  https://nodejs.org/
    echo   Python:   https://www.python.org/
    exit /b 1
)

call :log_info 环境检查通过
goto :eof

:: ==========================================
:: 安装依赖
:: ==========================================
:install_dependencies
call :log_step "检查项目依赖..."
echo.

:: 测试 pip 源连通性
call :log_info 测试 PyPI 连接...
set "PIP_INDEX="
set "PYPI_SOURCE=https://pypi.org/simple"
set "CHINA_PYPI=https://pypi.tuna.tsinghua.edu.cn"

curl -s --max-time 5 "%PYPI_SOURCE%" >nul 2>&1
if !errorlevel! equ 0 (
    set "PIP_INDEX=-i %PYPI_SOURCE%"
    echo   %GREEN%✓%NC% PyPI 连接正常
) else (
    echo   %YELLOW%!%NC% PyPI 连接失败，尝试国内源...
    curl -s --max-time 5 "%CHINA_PYPI%" >nul 2>&1
    if !errorlevel! equ 0 (
        set "PIP_INDEX=-i %CHINA_PYPI%"
        echo   %GREEN%✓%NC% 清华源连接正常
    ) else (
        echo   %YELLOW%!%NC% 无法连接任何 PyPI 源，使用默认
    )
)

:: 测试 npm 源连通性
call :log_info 测试 npm 注册表...
set "NPM_REG=https://registry.npmjs.org"
set "CHINA_NPM=https://registry.npmmirror.com"

curl -s --max-time 5 "%NPM_REG%" >nul 2>&1
if !errorlevel! equ 0 (
    set "NPM_REG=%NPM_REG%"
    echo   %GREEN%✓%NC% npm 注册表连接正常
) else (
    echo   %YELLOW%!%NC% npm 注册表连接失败，尝试国内源...
    curl -s --max-time 5 "%CHINA_NPM%" >nul 2>&1
    if !errorlevel! equ 0 (
        set "NPM_REG=%CHINA_NPM%"
        echo   %GREEN%✓%NC% 淘宝/NPM 镜像连接正常
    ) else (
        set "NPM_REG=%NPM_REG%"
        echo   %YELLOW%!%NC% 无法连接任何 npm 源，使用默认
    )
)
echo.

:: 后端依赖
python -c "import fastapi" >nul 2>&1
if !errorlevel! neq 0 (
    echo -n "   安装后端依赖"
    if defined PIP_INDEX (
        pip install -q %PIP_INDEX% fastapi "uvicorn[standard]" websockets ultralytics opencv-python-headless numpy python-multipart pyyaml dashscope >nul 2>&1
    ) else (
        pip install -q fastapi "uvicorn[standard]" websockets ultralytics opencv-python-headless numpy python-multipart pyyaml dashscope >nul 2>&1
    )
    if !errorlevel! equ 0 (
        echo   %GREEN%✓%NC%
    ) else (
        echo   %YELLOW%!%NC%
        call :log_warn 后端依赖安装可能不完整，尝试继续...
    )
) else (
    echo   %GREEN%✓%NC% 后端依赖已安装
)

:: 前端依赖
if not exist "%FRONTEND_DIR%\node_modules" (
    echo -n "   安装前端依赖"
    cd /d "%FRONTEND_DIR%"
    call npm config set registry "!NPM_REG!"
    call npm install --silent >nul 2>&1
    cd /d "%SCRIPT_DIR%"
    if !errorlevel! equ 0 (
        echo   %GREEN%✓%NC%
    ) else (
        echo   %YELLOW%!%NC%
        call :log_warn 前端依赖安装可能不完整，尝试继续...
    )
) else (
    echo   %GREEN%✓%NC% 前端依赖已安装
)

echo.
call :log_info 依赖检查完成
goto :eof

:: ==========================================
:: 创建必要的目录
:: ==========================================
:create_directories
if not exist "%LOGS_DIR%" mkdir "%LOGS_DIR%"
if not exist "%PID_DIR%" mkdir "%PID_DIR%"
goto :eof

:: ==========================================
:: 启动服务
:: ==========================================
:start_services
call :log_step "启动服务..."
echo.

:: 清理旧日志
call :log_info 清理旧日志...
if exist "%BACKEND_LOG%" del /f /q "%BACKEND_LOG%" >nul 2>&1
if exist "%FRONTEND_LOG%" del /f /q "%FRONTEND_LOG%" >nul 2>&1
if exist "%ERROR_LOG%" del /f /q "%ERROR_LOG%" >nul 2>&1
echo.

:: 检查端口是否被占用
call :check_port %API_PORT%
if !errorlevel! equ 0 (
    call :log_warn 端口 %API_PORT% 已被占用
    call :get_pid_by_port %API_PORT%
    echo    占用进程 PID: !errorlevel!
    set /p CHOICE="    是否终止占用进程? [y/N] "
    if /i "!CHOICE!"=="y" (
        call :kill_port %API_PORT%
    ) else (
        call :log_error 无法启动服务，端口被占用
        exit /b 1
    )
)

call :check_port %WEB_PORT%
if !errorlevel! equ 0 (
    call :log_error 端口 %WEB_PORT% 已被占用
    call :get_pid_by_port %WEB_PORT%
    echo    占用进程 PID: !errorlevel!
    set /p CHOICE="    是否终止占用进程? [y/N] "
    if /i "!CHOICE!"=="y" (
        call :kill_port %WEB_PORT%
    ) else (
        call :log_error 无法启动服务，端口被占用
        exit /b 1
    )
)

:: 设置环境变量
set "PYTHONPATH=%BACKEND_DIR%"
set "OMP_NUM_THREADS=1"

:: 启动后端
echo   %GREEN%^>%NC% 启动后端服务 (端口 %API_PORT%)...
cd /d "%BACKEND_DIR%"

if "%DEV_MODE%"=="true" (
    start /b cmd /c "python -m uvicorn app.main:app --host 0.0.0.0 --port %API_PORT% 2>&1"
) else (
    start /b cmd /c "python -m uvicorn app.main:app --host 0.0.0.0 --port %API_PORT% >> ..\%BACKEND_LOG% 2>&1"
)
cd /d "%SCRIPT_DIR%"

:: 等待后端启动
call :wait_for_service %API_PORT% "后端" 30
if !errorlevel! neq 0 (
    call :log_error 后端启动失败
    echo.
    echo    故障排查:
    echo    1. 查看日志: type %BACKEND_LOG%
    echo    2. 手动启动: cd backend ^&^& python -m uvicorn app.main:app --port %API_PORT%
    exit /b 1
)

:: 启动前端
echo   %GREEN%^>%NC% 启动前端服务 (端口 %WEB_PORT%)...
cd /d "%FRONTEND_DIR%"
start /b cmd /c "npm run dev -- --host 0.0.0.0 --port %WEB_PORT% >> ..\%FRONTEND_LOG% 2>&1"
cd /d "%SCRIPT_DIR%"

timeout /t 2 /nobreak >nul

:: 检查前端是否启动
call :check_port %WEB_PORT%
if !errorlevel! equ 0 (
    echo   %GREEN%✓%NC% 前端启动成功
) else (
    call :log_warn 前端可能未完全启动，请稍候检查
)

echo.
goto :eof

:: ==========================================
:: 停止服务
:: ==========================================
:stop_services
call :log_step "停止服务..."
echo.

set "STOPPED=false"

:: 停止后端
if exist "%BACKEND_PID_FILE%" (
    set /p BACKEND_PID=<"%BACKEND_PID_FILE%"
    tasklist /fi "pid eq %BACKEND_PID%" | findstr /i "python" >nul 2>&1
    if !errorlevel! equ 0 (
        echo -n "   停止后端服务..."
        taskkill /f /pid %BACKEND_PID% >nul 2>&1
        timeout /t 1 /nobreak >nul
        echo   %GREEN%✓%NC%
        set "STOPPED=true"
    )
    del /f "%BACKEND_PID_FILE%" >nul 2>&1
)

:: 确保端口释放
call :check_port %API_PORT%
if !errorlevel! equ 0 (
    call :kill_port %API_PORT%
    echo   %YELLOW%!%NC% 已终止占用端口 %API_PORT% 的进程
    set "STOPPED=true"
)

:: 停止前端
if exist "%FRONTEND_PID_FILE%" (
    set /p FRONTEND_PID=<"%FRONTEND_PID_FILE%"
    tasklist /fi "pid eq %FRONTEND_PID%" | findstr /i "node" >nul 2>&1
    if !errorlevel! equ 0 (
        echo -n "   停止前端服务..."
        taskkill /f /pid %FRONTEND_PID% >nul 2>&1
        timeout /t 1 /nobreak >nul
        echo   %GREEN%✓%NC%
        set "STOPPED=true"
    )
    del /f "%FRONTEND_PID_FILE%" >nul 2>&1
)

:: 确保端口释放
call :check_port %WEB_PORT%
if !errorlevel! equ 0 (
    call :kill_port %WEB_PORT%
    echo   %YELLOW%!%NC% 已终止占用端口 %WEB_PORT% 的进程
    set "STOPPED=true"
)

echo.
if "%STOPPED%"=="true" (
    call :log_info 服务已停止
) else (
    call :log_info 没有运行中的服务
)
goto :eof

:: ==========================================
:: 重启服务
:: ==========================================
:restart_services
call :stop_services
echo.
call :create_directories
call :check_dependencies
call :install_dependencies
call :start_services
goto :eof

:: ==========================================
:: 查看状态
:: ==========================================
:show_status
call :log_step "服务状态"
echo.

echo %BLUE%==========================================%NC%
echo.
call :check_service_status "后端服务" %API_PORT% "%BACKEND_PID_FILE%"
call :check_service_status "前端服务" %WEB_PORT% "%FRONTEND_PID_FILE%"

echo %BLUE%==========================================%NC%
echo.

:: 显示日志文件位置
if exist "%BACKEND_LOG%" (
    if exist "%FRONTEND_LOG%" (
        echo 日志文件:
        echo   后端: %BACKEND_LOG%
        echo   前端: %FRONTEND_LOG%
        echo.
        echo 查看日志: start.bat logs
        echo.
    )
)
goto :eof

:: ==========================================
:: 查看日志
:: ==========================================
:show_logs
set "LOG_TYPE=all"

if "%~1"=="" goto :logs_show_all
if "%~1"=="backend" set "LOG_TYPE=backend" & goto :logs_show
if "%~1"=="api" set "LOG_TYPE=backend" & goto :logs_show
if "%~1"=="frontend" set "LOG_TYPE=frontend" & goto :logs_show
if "%~1"=="web" set "LOG_TYPE=frontend" & goto :logs_show

:logs_show_all
echo %BLUE%========== 后端日志 ==========%NC%
if exist "%BACKEND_LOG%" (
    type "%BACKEND_LOG%"
) else (
    echo 日志文件不存在
)
echo.
echo %BLUE%========== 前端日志 ==========%NC%
if exist "%FRONTEND_LOG%" (
    type "%FRONTEND_LOG%"
) else (
    echo 日志文件不存在
)
echo.
goto :eof

:logs_show
if "%LOG_TYPE%"=="backend" (
    echo %BLUE%========== 后端日志 ==========%NC%
    if exist "%BACKEND_LOG%" (
        type "%BACKEND_LOG%"
    ) else (
        echo 日志文件不存在
    )
) else (
    echo %BLUE%========== 前端日志 ==========%NC%
    if exist "%FRONTEND_LOG%" (
        type "%FRONTEND_LOG%"
    ) else (
        echo 日志文件不存在
    )
)
echo.
goto :eof

:: ==========================================
:: 打印启动成功信息
:: ==========================================
:print_success_info
echo.
echo %BLUE%==========================================%NC%
echo %GREEN%  服务启动成功！%NC%
echo %BLUE%==========================================%NC%
echo.
echo   %GREEN%前端地址:%NC%  http://localhost:%WEB_PORT%
echo   %GREEN%后端地址:%NC%  http://localhost:%API_PORT%
echo   %GREEN%API 文档:%NC%  http://localhost:%API_PORT%/docs
echo.
echo   %YELLOW%停止服务:%NC%  start.bat stop
echo   %YELLOW%查看状态:%NC%  start.bat status
echo   %YELLOW%查看日志:%NC%  start.bat logs
echo.
echo %BLUE%==========================================%NC%
echo.
goto :eof

:: ==========================================
:: 打开浏览器
:: ==========================================
:open_browser
if "%NO_BROWSER%"=="true" goto :eof

set "URL=http://localhost:%WEB_PORT%"

timeout /t 2 /nobreak >nul

echo -n "   打开浏览器...
start %URL%
echo   %GREEN%✓%NC%
echo.
goto :eof

:: ==========================================
:: 主函数
:: ==========================================
:main
call :parse_args %*

if "%COMMAND%"=="start" (
    call :create_directories
    call :check_dependencies
    call :install_dependencies
    call :start_services
    call :print_success_info
    call :open_browser
    goto :end
)

if "%COMMAND%"=="stop" (
    call :stop_services
    goto :end
)

if "%COMMAND%"=="restart" (
    call :restart_services
    call :print_success_info
    call :open_browser
    goto :end
)

if "%COMMAND%"=="status" (
    call :show_status
    goto :end
)

if "%COMMAND%"=="logs" (
    shift
    goto :show_logs
)

if "%COMMAND%"=="help" (
    call :show_help
    goto :end
)

call :log_error 未知命令: %COMMAND%
call :show_help
exit /b 1

:end
endlocal
exit /b 0

:main
