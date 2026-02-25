#!/bin/bash

# YOLO Vision System - Quick Start Script
# This script starts both backend and frontend services
# Usage: ./start.sh

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$SCRIPT_DIR/backend"
FRONTEND_DIR="$SCRIPT_DIR/frontend"

# Check if this is the background run
if [ "$1" = "--background" ]; then
    # This is the background process - actually start services
    exec 2>&1
    
    # Set Python path
    export PYTHONPATH="$BACKEND_DIR:$HOME/.local/lib/python3.10/site-packages"
    
    echo "=========================================="
    echo "  YOLO Vision System - Starting"
    echo "=========================================="
    echo ""
    
    # Kill any existing processes
    pkill -f "uvicorn.*8000" 2>/dev/null || true
    pkill -f "vite.*3000" 2>/dev/null || true
    sleep 1
    
    # Start backend
    echo -e "${GREEN}Starting Backend Server (port 8000)...${NC}"
    cd "$BACKEND_DIR"
    python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000 >> /tmp/yolo_backend.log 2>&1 &
    BACKEND_PID=$!
    cd "$SCRIPT_DIR"
    
    # Wait for backend
    for i in {1..30}; do
        if curl -s http://localhost:8000/ > /dev/null 2>&1; then
            echo -e "  ${GREEN}Backend started!${NC}"
            break
        fi
        sleep 1
    done
    
    # Start frontend
    echo -e "${GREEN}Starting Frontend Server (port 3000)...${NC}"
    cd "$FRONTEND_DIR"
    npm run dev -- --host 0.0.0.0 >> /tmp/yolo_frontend.log 2>&1 &
    FRONTEND_PID=$!
    cd "$SCRIPT_DIR"
    
    sleep 2
    
    echo ""
    echo "=========================================="
    echo -e "  ${GREEN}Services Started!${NC}"
    echo "=========================================="
    echo ""
    echo "  Backend:  http://localhost:8000"
    echo "  Frontend: http://localhost:3000"
    echo "  Docs:     http://localhost:8000/docs"
    echo ""
    
    # Keep running
    wait
    exit 0
fi

# ==========================================
# Main script - foreground execution
# ==========================================

echo "=========================================="
echo "  YOLO Vision System - Quick Start"
echo "=========================================="
echo ""

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo -e "${RED}Error: Node.js is not installed${NC}"
    exit 1
fi

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: Python3 is not installed${NC}"
    exit 1
fi

# Check directories exist
if [ ! -d "$BACKEND_DIR" ]; then
    echo -e "${RED}Error: Backend directory not found${NC}"
    exit 1
fi

if [ ! -d "$FRONTEND_DIR" ]; then
    echo -e "${RED}Error: Frontend directory not found${NC}"
    exit 1
fi

echo -e "${YELLOW}Starting YOLO Vision System...${NC}"
echo ""

# Check/install backend dependencies
echo -e "${GREEN}[1/3] Checking backend dependencies...${NC}"
if ! python3 -c "import fastapi" 2>/dev/null; then
    echo "  Installing dependencies..."
    pip3 install --user -q fastapi uvicorn[standard] websockets ultralytics opencv-python-headless numpy python-multipart 2>/dev/null || true
fi
echo -e "  ${GREEN}OK${NC}"

# Check/install frontend dependencies
echo -e "${GREEN}[2/3] Checking frontend dependencies...${NC}"
if [ ! -d "$FRONTEND_DIR/node_modules" ]; then
    cd "$FRONTEND_DIR"
    npm install --silent
    cd "$SCRIPT_DIR"
fi
echo -e "  ${GREEN}OK${NC}"

echo -e "${GREEN}[3/3] Starting services...${NC}"
echo ""

# Start in background mode
nohup bash "$0" --background > /tmp/yolo_start.log 2>&1 &

echo "Starting services..."
echo ""
echo "=========================================="
echo -e "  ${GREEN}Services Starting...${NC}"
echo "=========================================="
echo ""
echo "  Please wait ~15 seconds for model to load..."
echo ""
echo "  Backend:  http://localhost:8000"
echo "  Frontend: http://localhost:3000"
echo ""
echo "  Or run 'tail -f /tmp/yolo_start.log' to see progress"
echo ""
echo "Press Ctrl+C to stop - services will continue running in background"
echo "=========================================="

# Wait a bit and check
sleep 5

# Show log
tail -15 /tmp/yolo_start.log 2>/dev/null || true
