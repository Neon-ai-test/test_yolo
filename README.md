# YOLO 视觉识别系统

基于 YOLOv8n 的实时目标检测系统，支持前端视频流实时识别与显示。

## 项目介绍

| 项目 | 技术栈 |
|------|--------|
| 前端 | Vue3 + Vite + Tailwind CSS + Canvas |
| 后端 | FastAPI + Uvicorn + YOLOv8n |
| 通信 | WebSocket 实时传输 |

## 功能特性

- 实时摄像头目标检测
- 识别框 Canvas 叠加显示
- 中英文类别映射
- 动态帧率调整
- 自动 GPU/CPU 检测
- REST API 支持

## 快速开始

### 本地运行

```bash
# 方式1：使用启动脚本（推荐）
bash start.sh

# 方式2：手动运行
# 终端1 - 后端
cd backend
pip install -r requirements.txt
python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000

# 终端2 - 前端
cd frontend
npm install
npm run dev
```

访问 http://localhost:3000

## 项目结构

```
yolo-vision-system/
├── backend/                 # FastAPI 后端
│   ├── app/
│   │   ├── main.py         # 应用入口
│   │   ├── detector.py     # YOLO 检测器
│   │   └── websocket_handler.py  # WebSocket 处理
│   ├── requirements.txt     # Python 依赖
│   └── README.md           # 后端文档
│
├── frontend/               # Vue3 前端
│   ├── src/
│   │   ├── App.vue         # 主组件
│   │   ├── composables/    # 复用逻辑
│   │   └── assets/         # 静态资源
│   ├── package.json        # Node 依赖
│   └── README.md           # 前端文档
│
├── start.sh               # 一键启动脚本
└── README.md              # 本文件
```

## API 文档

启动后端后访问：
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## 部署

### 阿里云服务器部署

详细部署教程见 [backend/README.md](backend/README.md)

#### 基础部署

```bash
# 1. 上传代码到服务器
scp -r ./ user@your-server:/var/www/yolo-vision-system/

# 2. 安装后端依赖
cd /var/www/yolo-vision-system/backend
pip install -r requirements.txt

# 3. 使用 Gunicorn + Nginx 部署
pip install gunicorn

# 4. 构建前端
cd ../frontend
npm install
npm run build
```

#### GPU 服务器部署

```bash
# 安装 CUDA 版 PyTorch
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu118

# 后端会自动使用 GPU
```

#### Docker 部署

```bash
# 构建镜像
docker build -t yolo-vision -f backend/Dockerfile .

# 运行
docker run -d --gpus all -p 8000:8000 -p 3000:3000 yolo-vision
```

### Nginx 配置

```nginx
server {
    listen 80;
    server_name your-domain.com;

    # 前端静态文件
    root /var/www/yolo-vision-system/frontend/dist;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # API 代理
    location /api {
        proxy_pass http://127.0.0.1:8000;
    }

    # WebSocket 代理
    location /ws {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

## 性能

| 环境 | 预期帧率 |
|------|----------|
| CPU (普通PC) | 2-5 FPS |
| CPU (服务器) | 5-10 FPS |
| GPU (GTX 1060) | 30-50 FPS |
| GPU (RTX 3080+) | 60-100 FPS |

## 常见问题

### Q: 识别延迟高怎么办？
A: 使用 GPU 服务器或降低前端帧率设置

### Q: 支持哪些识别类别？
A: COCO 80类，包括人、车、动物等

### Q: 如何切换模型？
A: 修改 `backend/app/detector.py` 中的模型路径

## 相关文档

- [前端文档](frontend/README.md)
- [后端文档](backend/README.md)
- [YOLOv8 官方文档](https://docs.ultralytics.com/)
