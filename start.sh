#!/bin/bash
#
# ==========================================
# YOLO 视觉识别系统 - 启动脚本 v2.0
# ==========================================
# 功能：管理后端和前端服务
# 用法：./start.sh [command] [options]
# ==========================================

set -e

# ==========================================
# 配置变量
# ==========================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$SCRIPT_DIR/backend"
FRONTEND_DIR="$SCRIPT_DIR/frontend"
LOGS_DIR="$SCRIPT_DIR/logs"
PID_DIR="$SCRIPT_DIR/.pids"

# 默认端口
DEFAULT_API_PORT=8000
DEFAULT_WEB_PORT=3000

# 当前配置
API_PORT=$DEFAULT_API_PORT
WEB_PORT=$DEFAULT_WEB_PORT
NO_BROWSER=false
DEV_MODE=false
COMMAND="start"

# 日志文件
BACKEND_LOG="$LOGS_DIR/backend.log"
FRONTEND_LOG="$LOGS_DIR/frontend.log"
ERROR_LOG="$LOGS_DIR/error.log"

# PID 文件
BACKEND_PID_FILE="$PID_DIR/backend.pid"
FRONTEND_PID_FILE="$PID_DIR/frontend.pid"

# ==========================================
# 颜色定义
# ==========================================
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# ==========================================
# 工具函数
# ==========================================

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${CYAN}==>${NC} ${BOLD}$1${NC}"
}

show_progress() {
    local current=$1
    local total=$2
    local width=30
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "\r  ["
    printf "%${filled}s" | tr ' ' '='
    printf "%${empty}s" | tr ' ' ' '
    printf "] %3d%%" "$percent"
}

check_port() {
    local port=$1
    if lsof -i :$port > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

wait_for_port() {
    local port=$1
    local max_wait=${2:-30}
    local count=0
    
    while [ $count -lt $max_wait ]; do
        if check_port $port; then
            return 0
        fi
        show_progress $count $max_wait
        sleep 1
        ((count++))
    done
    
    echo ""
    return 1
}

wait_for_service() {
    local port=$1
    local name=$2
    local max_wait=${3:-30}
    local count=0
    
    echo -n "  等待 $name 启动"
    
    while [ $count -lt $max_wait ]; do
        if curl -s http://localhost:$port/ > /dev/null 2>&1; then
            echo " ✓"
            return 0
        fi
        echo -n "."
        sleep 1
        ((count++))
    done
    
    echo " ✗"
    return 1
}

get_pid_by_port() {
    local port=$1
    lsof -t -i :$port 2>/dev/null | head -1
}

kill_port() {
    local port=$1
    local pid=$(get_pid_by_port $port)
    
    if [ -n "$pid" ]; then
        kill $pid 2>/dev/null || true
        sleep 1
        if check_port $port; then
            kill -9 $pid 2>/dev/null || true
        fi
    fi
}

check_service_status() {
    local name=$1
    local port=$2
    local pid_file=$3
    
    echo -e "  ${BOLD}$name${NC}"
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 $pid 2>/dev/null; then
            echo -e "    状态:   ${GREEN}运行中${NC}"
            echo -e "    PID:    $pid"
        else
            echo -e "    状态:   ${YELLOW}已停止 (PID 文件过期)${NC}"
        fi
    elif check_port $port; then
        local pid=$(get_pid_by_port $port)
        echo -e "    状态:   ${YELLOW}运行中 (无 PID 文件)${NC}"
        echo -e "    PID:    $pid"
    else
        echo -e "    状态:   ${RED}已停止${NC}"
    fi
    
    echo -e "    端口:   $port"
    echo -e "    地址:   http://localhost:$port"
    echo ""
}

# ==========================================
# 帮助信息
# ==========================================
show_help() {
    echo ""
    echo -e "${BLUE}用法:${NC}"
    echo "  ./start.sh [command] [options]"
    echo ""
    echo -e "${BLUE}命令:${NC}"
    echo "  start       启动服务 (默认)"
    echo "  stop        停止服务"
    echo "  restart     重启服务"
    echo "  status      查看服务状态"
    echo "  logs        查看日志"
    echo "  help        显示帮助信息"
    echo ""
    echo -e "${BLUE}选项:${NC}"
    echo "  --port-api PORT    API 端口 (默认: $DEFAULT_API_PORT)"
    echo "  --port-web PORT    前端端口 (默认: $DEFAULT_WEB_PORT)"
    echo "  --no-browser       不自动打开浏览器"
    echo "  --dev              开发模式 (详细日志输出到控制台)"
    echo ""
    echo -e "${BLUE}示例:${NC}"
    echo "  ./start.sh                          # 启动服务 (默认端口)"
    echo "  ./start.sh start --port-api 8080    # 使用自定义 API 端口启动"
    echo "  ./start.sh stop                     # 停止服务"
    echo "  ./start.sh restart                  # 重启服务"
    echo "  ./start.sh status                   # 查看状态"
    echo "  ./start.sh logs --follow            # 实时查看日志"
    echo ""
}

# ==========================================
# 参数解析
# ==========================================
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            start|stop|restart|status|logs|help)
                COMMAND=$1
                shift
                ;;
            --port-api)
                API_PORT=$2
                shift 2
                ;;
            --port-web)
                WEB_PORT=$2
                shift 2
                ;;
            --no-browser)
                NO_BROWSER=true
                shift
                ;;
            --dev)
                DEV_MODE=true
                shift
                ;;
            --follow|-f)
                LOG_FOLLOW=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# ==========================================
# 检查依赖
# ==========================================
check_dependencies() {
    log_step "检查运行环境..."
    echo ""
    
    local missing=()
    
    if command -v node &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} Node.js: $(node -v)"
    else
        echo -e "  ${RED}✗${NC} Node.js: 未安装"
        missing+=("Node.js")
    fi
    
    if command -v python3 &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} Python: $(python3 --version)"
    else
        echo -e "  ${RED}✗${NC} Python: 未安装"
        missing+=("Python3")
    fi
    
    if command -v pip3 &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} pip: $(pip3 --version | cut -d' ' -f2)"
    else
        echo -e "  ${RED}✗${NC} pip: 未安装"
        missing+=("pip3")
    fi
    
    if command -v curl &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} curl: 已安装"
    else
        echo -e "  ${YELLOW}!${NC} curl: 未安装 (健康检查将不可用)"
    fi
    
    echo ""
    
    if [ ! -d "$BACKEND_DIR" ]; then
        log_error "找不到后端目录: $BACKEND_DIR"
        exit 1
    fi
    
    if [ ! -d "$FRONTEND_DIR" ]; then
        log_error "找不到前端目录: $FRONTONTEND_DIR"
        exit 1
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "缺少依赖: ${missing[*]}"
        echo ""
        echo "安装建议:"
        echo "  Node.js:  https://nodejs.org/"
        echo "  Python:   https://www.python.org/"
        exit 1
    fi
    
    log_info "环境检查通过"
}

# ==========================================
# 安装依赖
# ==========================================
install_dependencies() {
    log_step "检查项目依赖..."
    echo ""
    
    if ! python3 -c "import fastapi" 2>/dev/null; then
        echo -n "  安装后端依赖"
        pip3 install --user -q fastapi "uvicorn[standard]" websockets ultralytics opencv-python-headless numpy python-multipart pyyaml dashscope 2>/dev/null
        if [ $? -eq 0 ]; then
            echo " ✓"
        else
            echo " ✗"
            log_warn "后端依赖安装可能不完整，尝试继续..."
        fi
    else
        echo -e "  ${GREEN}✓${NC} 后端依赖已安装"
    fi
    
    if [ ! -d "$FRONTEND_DIR/node_modules" ]; then
        echo -n "  安装前端依赖"
        (cd "$FRONTEND_DIR" && npm install --silent 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo " ✓"
        else
            echo " ✗"
            log_warn "前端依赖安装可能不完整，尝试继续..."
        fi
    else
        echo -e "  ${GREEN}✓${NC} 前端依赖已安装"
    fi
    
    echo ""
    log_info "依赖检查完成"
}

# ==========================================
# 创建必要的目录
# ==========================================
create_directories() {
    mkdir -p "$LOGS_DIR"
    mkdir -p "$PID_DIR"
}

# ==========================================
# 启动服务
# ==========================================
start_services() {
    log_step "启动服务..."
    echo ""
    
    # 清理旧日志
    log_info "清理旧日志..."
    rm -f "$BACKEND_LOG" "$FRONTEND_LOG" "$ERROR_LOG" 2>/dev/null || true
    echo ""
    
    # 检查端口是否被占用
    if check_port $API_PORT; then
        log_warn "端口 $API_PORT 已被占用"
        local pid=$(get_pid_by_port $API_PORT)
        echo "  占用进程 PID: $pid"
        read -p "  是否终止占用进程? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            kill_port $API_PORT
        else
            log_error "无法启动服务，端口被占用"
            exit 1
        fi
    fi
    
    if check_port $WEB_PORT; then
        log_warn "端口 $WEB_PORT 已被占用"
        local pid=$(get_pid_by_port $WEB_PORT)
        echo "  占用进程 PID: $pid"
        read -p "  是否终止占用进程? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            kill_port $WEB_PORT
        else
            log_error "无法启动服务，端口被占用"
            exit 1
        fi
    fi
    
    # 设置环境变量
    export PYTHONPATH="$BACKEND_DIR"
    export OMP_NUM_THREADS=1
    export TORCH_NNPACK_VERBOSE=0
    
    # 启动后端
    echo -e "  ${GREEN}→${NC} 启动后端服务 (端口 $API_PORT)..."
    cd "$BACKEND_DIR"
    
    if [ "$DEV_MODE" = true ]; then
        python3 -m uvicorn app.main:app --host 0.0.0.0 --port $API_PORT 2>&1 | tee "$BACKEND_LOG" &
    else
        python3 -m uvicorn app.main:app --host 0.0.0.0 --port $API_PORT >> "$BACKEND_LOG" 2>&1 &
    fi
    BACKEND_PID=$!
    echo $BACKEND_PID > "$BACKEND_PID_FILE"
    cd "$SCRIPT_DIR"
    
    # 等待后端启动
    if ! wait_for_service $API_PORT "后端" 30; then
        log_error "后端启动失败"
        echo ""
        echo "  故障排查:"
        echo "  1. 查看日志: cat $BACKEND_LOG"
        echo "  2. 手动启动: cd backend && python3 -m uvicorn app.main:app --port $API_PORT"
        exit 1
    fi
    
    # 启动前端
    echo -e "  ${GREEN}→${NC} 启动前端服务 (端口 $WEB_PORT)..."
    cd "$FRONTEND_DIR"
    
    if [ "$DEV_MODE" = true ]; then
        npm run dev -- --host 0.0.0.0 --port $WEB_PORT 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | tee "$FRONTEND_LOG" &
    else
        npm run dev -- --host 0.0.0.0 --port $WEB_PORT >> "$FRONTEND_LOG" 2>&1 &
    fi
    FRONTEND_PID=$!
    echo $FRONTEND_PID > "$FRONTEND_PID_FILE"
    cd "$SCRIPT_DIR"
    
    sleep 2
    
    if check_port $WEB_PORT; then
        echo -e "  ${GREEN}✓${NC} 前端启动成功"
    else
        log_warn "前端可能未完全启动，请稍候检查"
    fi
    
    echo ""
}

# ==========================================
# 停止服务
# ==========================================
stop_services() {
    log_step "停止服务..."
    echo ""
    
    local stopped=false
    
    if [ -f "$BACKEND_PID_FILE" ]; then
        local pid=$(cat "$BACKEND_PID_FILE")
        if kill -0 $pid 2>/dev/null; then
            echo -n "  停止后端服务..."
            kill $pid 2>/dev/null
            sleep 1
            if kill -0 $pid 2>/dev/null; then
                kill -9 $pid 2>/dev/null
            fi
            echo " ✓"
            stopped=true
        fi
        rm -f "$BACKEND_PID_FILE"
    fi
    
    if check_port $API_PORT; then
        kill_port $API_PORT
        echo -e "  ${YELLOW}!${NC} 已终止占用端口 $API_PORT 的进程"
        stopped=true
    fi
    
    if [ -f "$FRONTEND_PID_FILE" ]; then
        local pid=$(cat "$FRONTEND_PID_FILE")
        if kill -0 $pid 2>/dev/null; then
            echo -n "  停止前端服务..."
            kill $pid 2>/dev/null
            sleep 1
            if kill -0 $pid 2>/dev/null; then
                kill -9 $pid 2>/dev/null
            fi
            echo " ✓"
            stopped=true
        fi
        rm -f "$FRONTEND_PID_FILE"
    fi
    
    if check_port $WEB_PORT; then
        kill_port $WEB_PORT
        echo -e "  ${YELLOW}!${NC} 已终止占用端口 $WEB_PORT 的进程"
        stopped=true
    fi
    
    if [ "$stopped" = true ]; then
        echo ""
        log_info "服务已停止"
    else
        echo ""
        log_info "没有运行中的服务"
    fi
}

# ==========================================
# 重启服务
# ==========================================
restart_services() {
    stop_services
    echo ""
    create_directories
    check_dependencies
    install_dependencies
    start_services
}

# ==========================================
# 查看状态
# ==========================================
show_status() {
    log_step "服务状态"
    echo ""
    
    echo -e "${BLUE}==========================================${NC}"
    echo ""
    
    check_service_status "后端服务" $API_PORT "$BACKEND_PID_FILE"
    check_service_status "前端服务" $WEB_PORT "$FRONTEND_PID_FILE"
    
    echo -e "${BLUE}==========================================${NC}"
    echo ""
    
    if [ -f "$BACKEND_LOG" ] || [ -f "$FRONTEND_LOG" ]; then
        echo "日志文件:"
        [ -f "$BACKEND_LOG" ] && echo "  后端: $BACKEND_LOG"
        [ -f "$FRONTEND_LOG" ] && echo "  前端: $FRONTEND_LOG"
        echo ""
        echo "查看日志: ./start.sh logs"
        echo ""
    fi
}

# ==========================================
# 查看日志
# ==========================================
show_logs() {
    local log_type="all"
    local lines=50
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            backend|api)
                log_type="backend"
                shift
                ;;
            frontend|web)
                log_type="frontend"
                shift
                ;;
            --follow|-f)
                LOG_FOLLOW=true
                shift
                ;;
            --lines|-n)
                lines=$2
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done
    
    if [ "$LOG_FOLLOW" = true ]; then
        if [ "$log_type" = "backend" ]; then
            tail -f "$BACKEND_LOG" 2>/dev/null || log_error "后端日志文件不存在"
        elif [ "$log_type" = "frontend" ]; then
            tail -f "$FRONTEND_LOG" 2>/dev/null || log_error "前端日志文件不存在"
        else
            log_info "实时查看所有日志 (Ctrl+C 退出)..."
            tail -f "$BACKEND_LOG" "$FRONTEND_LOG" 2>/dev/null || log_error "日志文件不存在"
        fi
    else
        echo -e "${BLUE}========== 后端日志 (最近 $lines 行) ==========${NC}"
        if [ -f "$BACKEND_LOG" ]; then
            tail -n $lines "$BACKEND_LOG"
        else
            echo "日志文件不存在"
        fi
        
        echo ""
        echo -e "${BLUE}========== 前端日志 (最近 $lines 行) ==========${NC}"
        if [ -f "$FRONTEND_LOG" ]; then
            tail -n $lines "$FRONTEND_LOG"
        else
            echo "日志文件不存在"
        fi
        
        echo ""
        echo "提示: 使用 --follow 或 -f 实时查看日志"
    fi
}

# ==========================================
# 打印启动成功信息
# ==========================================
print_success_info() {
    echo ""
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${GREEN}  服务启动成功！${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo ""
    echo -e "  ${GREEN}前端地址:${NC}  http://localhost:$WEB_PORT"
    echo -e "  ${GREEN}后端地址:${NC}  http://localhost:$API_PORT"
    echo -e "  ${GREEN}API 文档:${NC}  http://localhost:$API_PORT/docs"
    echo ""
    echo -e "  ${YELLOW}停止服务:${NC}  ./start.sh stop"
    echo -e "  ${YELLOW}查看状态:${NC}  ./start.sh status"
    echo -e "  ${YELLOW}查看日志:${NC}  ./start.sh logs"
    echo ""
    echo -e "${BLUE}==========================================${NC}"
    echo ""
}

# ==========================================
# 打开浏览器
# ==========================================
open_browser() {
    if [ "$NO_BROWSER" = true ]; then
        return
    fi
    
    local URL="http://localhost:$WEB_PORT"
    
    sleep 2
    
    echo -n "  打开浏览器..."
    
    if command -v xdg-open &> /dev/null; then
        xdg-open "$URL" 2>/dev/null &
        echo " ✓"
    elif command -v open &> /dev/null; then
        open "$URL"
        echo " ✓"
    elif command -v start &> /dev/null; then
        start "$URL" 2>/dev/null
        echo " ✓"
    else
        echo ""
        echo -e "  ${YELLOW}请手动打开浏览器访问: $URL${NC}"
    fi
    
    echo ""
}

# ==========================================
# 主函数
# ==========================================
main() {
    parse_args "$@"
    
    case $COMMAND in
        start)
            create_directories
            check_dependencies
            install_dependencies
            start_services
            print_success_info
            open_browser
            ;;
        stop)
            stop_services
            ;;
        restart)
            restart_services
            print_success_info
            open_browser
            ;;
        status)
            show_status
            ;;
        logs)
            shift
            show_logs "$@"
            ;;
        help)
            show_help
            ;;
        *)
            log_error "未知命令: $COMMAND"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
