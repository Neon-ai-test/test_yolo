#!/bin/bash

# ==========================================
# YOLO 视觉识别系统 - 一键启动脚本
# ==========================================
# 功能：启动后端和前端服务
# 用法：bash start.sh
# 停止：按 Ctrl+C
# ==========================================

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$SCRIPT_DIR/backend"
FRONTEND_DIR="$SCRIPT_DIR/frontend"

# 进程 ID 文件
PID_FILE="/tmp/yolo_pids"

# 清理函数
cleanup() {
    echo ""
    echo -e "${YELLOW}正在停止服务...${NC}"
    
    # 终止子进程
    if [ -f "$PID_FILE" ]; then
        while read pid; do
            if kill -0 $pid 2>/dev/null; then
                kill $pid 2>/dev/null
            fi
        done < "$PID_FILE"
        rm -f "$PID_FILE"
    fi
    
    # 确保清理干净
    pkill -f "uvicorn.*8000" 2>/dev/null || true
    pkill -f "vite.*3000" 2>/dev/null || true
    
    # 等待进程完全退出
    sleep 1
    
    echo -e "${GREEN}服务已停止${NC}"
    echo -e "${GREEN}再见！${NC}"
    exit 0
}

# 捕获 Ctrl+C 信号
trap cleanup SIGINT SIGTERM

# 打印标题
print_header() {
    echo ""
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE}    YOLO 视觉识别系统 - 启动中${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo ""
}

# 检查依赖
check_dependencies() {
    echo -e "${YELLOW}[1/4] 检查运行环境...${NC}"
    
    # 检查 Node.js
    if ! command -v node &> /dev/null; then
        echo -e "${RED}错误：未安装 Node.js${NC}"
        echo "请先安装 Node.js: https://nodejs.org/"
        exit 1
    fi
    
    # 检查 Python
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}错误：未安装 Python3${NC}"
        echo "请先安装 Python3"
        exit 1
    fi
    
    # 检查目录
    if [ ! -d "$BACKEND_DIR" ]; then
        echo -e "${RED}错误：找不到后端目录 $BACKEND_DIR${NC}"
        exit 1
    fi
    
    if [ ! -d "$FRONTEND_DIR" ]; then
        echo -e "${RED}错误：找不到前端目录 $FRONTEND_DIR${NC}"
        exit 1
    fi
    
    echo -e "  Node.js: $(node -v)"
    echo -e "  Python:  $(python3 --version)"
    echo -e "${GREEN}  环境检查通过${NC}"
    echo ""
}

# 安装依赖
install_dependencies() {
    echo -e "${YELLOW}[2/4] 检查项目依赖...${NC}"
    
    # 后端依赖
    if ! python3 -c "import fastapi" 2>/dev/null; then
        echo "  正在安装后端依赖..."
        pip3 install --user -q fastapi uvicorn[standard] websockets ultralytics opencv-python-headless numpy python-multipart pyyaml dashscope 2>/dev/null
    fi
    
    # 前端依赖
    if [ ! -d "$FRONTEND_DIR/node_modules" ]; then
        echo "  正在安装前端依赖..."
        cd "$FRONTEND_DIR"
        npm install --silent
        cd "$SCRIPT_DIR"
    fi
    
    echo -e "${GREEN}  依赖检查完成${NC}"
    echo ""
}

# 停止已有服务
stop_existing() {
    echo -e "${YELLOW}[3/4] 清理旧进程...${NC}"
    pkill -f "uvicorn.*8000" 2>/dev/null || true
    pkill -f "vite.*3000" 2>/dev/null || true
    rm -f "$PID_FILE"
    sleep 1
    echo -e "${GREEN}  清理完成${NC}"
    echo ""
}

# 启动服务
start_services() {
    echo -e "${YELLOW}[4/4] 启动服务...${NC}"
    echo ""
    
    # 设置 Python 路径和环境变量
    export PYTHONPATH="$BACKEND_DIR"
    export OMP_NUM_THREADS=1
    export TORCH_NNPACK_VERBOSE=0
    
    # 启动后端
    echo -e "${GREEN}启动后端服务 (端口 8000)...${NC}"
    cd "$BACKEND_DIR"
    python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000 &
    BACKEND_PID=$!
    cd "$SCRIPT_DIR"
    
    # 等待后端启动
    echo -n "  等待后端就绪"
    for i in {1..30}; do
        if curl -s http://localhost:8000/ > /dev/null 2>&1; then
            echo ""
            break
        fi
        echo -n "."
        sleep 1
    done
    
    if ! curl -s http://localhost:8000/ > /dev/null 2>&1; then
        echo ""
        echo -e "${RED}错误：后端启动失败${NC}"
        echo "请检查日志: cd backend && python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000"
        exit 1
    fi
    
    echo -e "${GREEN}  后端启动成功${NC}"
    
    # 启动前端
    echo ""
    echo -e "${GREEN}启动前端服务 (端口 3000)...${NC}"
    cd "$FRONTEND_DIR"
    npm run dev -- --host 0.0.0.0 &
    FRONTEND_PID=$!
    cd "$SCRIPT_DIR"
    
    # 保存 PID
    echo "$BACKEND_PID" > "$PID_FILE"
    echo "$FRONTEND_PID" >> "$PID_FILE"
    
    sleep 2
    
    echo -e "${GREEN}  前端启动成功${NC}"
    echo ""
}

# 打印使用信息
print_info() {
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${GREEN}  服务启动完成！${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo ""
    echo -e "  ${GREEN}前端地址:${NC}  http://localhost:3000"
    echo -e "  ${GREEN}后端地址:${NC}  http://localhost:8000"
    echo -e "  ${GREEN}API 文档:${NC}  http://localhost:8000/docs"
    echo ""
    echo -e "  ${YELLOW}按 Ctrl+C 停止服务${NC}"
    echo ""
    echo -e "${BLUE}==========================================${NC}"
    echo ""
}

# 打开浏览器
open_browser() {
    URL="http://localhost:3000"
    
    sleep 2  # 等待前端完全就绪
    
    # Linux
    if command -v xdg-open &> /dev/null; then
        xdg-open "$URL" 2>/dev/null &
        echo -e "${GREEN}已打开浏览器访问 $URL${NC}"
    # macOS
    elif command -v open &> /dev/null; then
        open "$URL"
        echo -e "${GREEN}已打开浏览器访问 $URL${NC}"
    # Windows (Git Bash / WSL)
    elif command -v start &> /dev/null; then
        start "$URL"
        echo -e "${GREEN}已打开浏览器访问 $URL${NC}"
    else
        echo -e "${YELLOW}请手动打开浏览器访问: $URL${NC}"
    fi
    echo ""
}

# 主函数
main() {
    print_header
    check_dependencies
    install_dependencies
    stop_existing
    start_services
    print_info
    open_browser
    
    # 等待子进程
    wait
}

main