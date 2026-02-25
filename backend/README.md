# YOLO 视觉识别系统 - 后端

基于 FastAPI + YOLOv8n 实现的实时目标检测后端服务。

## 技术栈

| 技术 | 版本 | 说明 |
|------|------|------|
| FastAPI | ^0.132.0 | 现代高性能Web框架 |
| Uvicorn | ^0.41.0 | ASGI服务器 |
| Ultralytics | ^8.4.15 | YOLOv8官方库 |
| OpenCV | ^4.13.0 | 图像处理 |
| NumPy | ^2.2.6 | 数值计算 |

## 项目结构

```
backend/
├── app/
│   ├── main.py                 # 应用入口 & API路由
│   ├── detector.py             # YOLO检测器实现
│   ├── websocket_handler.py    # WebSocket处理器
│   └── models/                 # 模型文件目录
├── requirements.txt            # Python依赖
└── ...
```

## 功能特性

- YOLOv8n 实时目标检测
- WebSocket 实时视频流处理（异步）
- REST API 图片上传检测
- CORS 跨域支持
- 模型启动时预加载
- 自动GPU/CPU检测
- 性能基准测试
- 中英文类别映射

## 快速开始

### 安装依赖

```bash
pip install -r requirements.txt
```

### 启动服务

```bash
python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

服务启动后自动下载 YOLOv8n 模型（约6MB）。

## API 接口

### 1. 健康检查

```
GET /
```

响应:
```json
{
  "message": "YOLO Vision API",
  "status": "running"
}
```

### 2. 获取识别类别（含中文）

```
GET /api/classes
```

响应:
```json
{
  "classes": [
    {"id": 0, "name": "person", "name_cn": "人"},
    {"id": 1, "name": "bicycle", "name_cn": "自行车"},
    ...
  ]
}
```

### 3. 性能测试

```
GET /api/benchmark
```

响应:
```json
{
  "device": "cpu",
  "avg_process_time_ms": 262.52,
  "recommended_fps": 3,
  "iterations": 5
}
```

### 4. 设备信息

```
GET /api/info
```

响应:
```json
{
  "device": "cuda",
  "model": "yolov8n"
}
```

### 5. 图片检测

```
POST /api/detect
Content-Type: multipart/form-data
```

请求: 图片文件

响应:
```json
{
  "detections": [
    {
      "bbox": [100.5, 200.3, 300.7, 400.1],
      "confidence": 0.95,
      "class_id": 0,
      "class_name": "person",
      "class_name_cn": "人"
    }
  ]
}
```

### 6. WebSocket 实时检测

```
WS /ws/detect
```

发送:
```json
{
  "type": "frame",
  "image": "base64编码的图片"
}
```

接收:
```json
{
  "type": "result",
  "detections": [...]
}
```

## 性能优化

### 后端优化策略

1. **自动GPU检测**：自动使用CUDA加速
2. **异步处理**：WebSocket不阻塞
3. **队列削峰**：只处理最新帧
4. **输入尺寸优化**：默认320x320

### 帧率预估

| 硬件 | 预期FPS |
|------|---------|
| CPU (普通) | 2-5 FPS |
| CPU (高性能服务器) | 5-10 FPS |
| GPU (GTX 1060+) | 30-50 FPS |
| GPU (RTX 3080+) | 60-100 FPS |

## 支持的识别类别 (COCO 80类中文)

| ID | 英文 | 中文 |
|----|------|------|
| 0 | person | 人 |
| 1 | bicycle | 自行车 |
| 2 | car | 汽车 |
| 3 | motorcycle | 摩托车 |
| 4 | airplane | 飞机 |
| ... | ... | ... |
| 79 | toothbrush | 牙刷 |

完整列表见 `detector.py` 中的 `COCO_CLASSES_CN` 字典。

## 检测器配置

### 默认参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| model | yolov8n.pt | 模型文件名 |
| conf | 0.25 | 置信度阈值 |
| imgsz | 320 | 输入图片尺寸 |

### 支持的模型

| 模型 | 参数量 | 速度 | 精度 |
|------|--------|------|------|
| yolov8n.pt | 3.2M | 最快 | 基础 |
| yolov8s.pt | 11.2M | 快 | 中等 |
| yolov8m.pt | 25.9M | 中等 | 较高 |
| yolov8l.pt | 53.7M | 慢 | 高 |
| yolov8x.pt | 103.7M | 最慢 | 最高 |

切换模型只需修改 `app/detector.py` 中的模型路径。

## 部署教程

### 本地开发部署

```bash
# 1. 克隆项目
git clone <repo-url>
cd yolo-vision-system

# 2. 启动后端
cd backend
pip install -r requirements.txt
python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000

# 3. 启动前端（新终端）
cd frontend
npm install
npm run dev
```

访问 http://localhost:3000

### 服务器部署（阿里云等）

#### 1. 环境要求

- Ubuntu 18.04+ / CentOS 8+
- Python 3.8+
- Node.js 16+

#### 2. 后端部署

```bash
# 安装依赖
cd /var/www/yolo-vision-system/backend
pip install -r requirements.txt

# 使用Systemd管理（推荐）
sudo tee /etc/systemd/system/yolo-api.service << EOF
[Unit]
Description=YOLO Vision API
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=/var/www/yolo-vision-system/backend
ExecStart=/usr/bin/python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable yolo-api
sudo systemctl start yolo-api
```

#### 3. 前端部署

```bash
# 构建
cd /var/www/yolo-vision-system/frontend
npm install
npm run build

# 配置Nginx
sudo tee /etc/nginx/sites-available/yolo << EOF
server {
    listen 80;
    server_name your-domain.com;

    root /var/www/yolo-vision-system/frontend/dist;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location /api {
        proxy_pass http://127.0.0.1:8000;
    }

    location /ws {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/yolo /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

#### 4. GPU服务器部署（推荐）

```bash
# 安装CUDA版PyTorch
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu118

# 后端会自动检测并使用GPU
```

#### 5. Docker部署

```dockerfile
# Dockerfile
FROM python:3.10-slim

WORKDIR /app
RUN pip install --no-cache-dir torch torchvision --index-url https://download.pytorch.org/whl/cu118

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

构建运行：
```bash
docker build -t yolo-vision .
docker run -d --gpus all -p 8000:8000 yolo-vision
```

### 端口开放

服务器安全组需开放：
- 80 (HTTP)
- 443 (HTTPS)
- 8000 (后端API)

## 错误处理

| 错误码 | 说明 |
|--------|------|
| 1006 | WebSocket 连接异常关闭 |
| 400 | 请求参数错误 |
| 500 | 服务器内部错误 |

## 日志

日志默认级别为 INFO：

```bash
# 查看日志
sudo journalctl -u yolo-api -f
```

## 相关文档

- [FastAPI 文档](https://fastapi.tiangolo.com/)
- [Ultralytics YOLOv8](https://docs.ultralytics.com/)
- [YOLOv8 GitHub](https://github.com/ultralytics/ultralytics)
