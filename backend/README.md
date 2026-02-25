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
- WebSocket 实时视频流处理
- REST API 图片上传检测
- CORS 跨域支持
- 模型启动时预加载

## 快速开始

### 安装依赖

```bash
pip install -r requirements.txt
```

或使用 CPU 版本的 PyTorch（节省磁盘空间）:

```bash
pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu
pip install -r requirements.txt
```

### 启动服务

```bash
python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

服务启动后自动下载 YOLOv8n 模型（约6MB）。

### Docker 部署

```dockerfile
FROM python:3.10-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

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

### 2. 获取识别类别

```
GET /api/classes
```

响应:
```json
{
  "classes": [
    {"id": 0, "name": "person"},
    {"id": 1, "name": "bicycle"},
    ...
  ]
}
```

### 3. 图片检测

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
      "class_name": "person"
    }
  ],
  "image": "base64编码的绘制了框的图片"
}
```

### 4. WebSocket 实时检测

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
  "detections": [...],
  "image": "base64编码的绘制了框的图片"
}
```

## 检测器配置

### 默认参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| model | yolov8n.pt | 模型文件名 |
| conf | 0.25 | 置信度阈值 |

### 支持的模型

| 模型 | 参数量 | 速度 | 精度 |
|------|--------|------|------|
| yolov8n.pt | 3.2M | 最快 | 基础 |
| yolov8s.pt | 11.2M | 快 | 中等 |
| yolov8m.pt | 25.9M | 中等 | 较高 |
| yolov8l.pt | 53.7M | 慢 | 高 |
| yolov8x.pt | 103.7M | 最慢 | 最高 |

切换模型只需修改 `app/main.py` 中的模型路径。

## 支持的识别类别 (COCO 80类)

person, bicycle, car, motorcycle, airplane, bus, train, truck, boat, traffic light, fire hydrant, stop sign, parking meter, bench, bird, cat, dog, horse, sheep, cow, elephant, bear, zebra, giraffe, backpack, umbrella, handbag, tie, suitcase, frisbee, skis, snowboard, sports ball, kite, baseball bat, baseball glove, skateboard, surfboard, tennis racket, bottle, wine glass, cup, fork, knife, spoon, bowl, banana, apple, sandwich, orange, broccoli, carrot, hot dog, pizza, donut, cake, chair, couch, potted plant, bed, dining table, toilet, tv, laptop, mouse, remote, keyboard, cell phone, microwave, oven, toaster, sink, refrigerator, book, clock, vase, scissors, teddy bear, hair drier, toothbrush

## 性能优化

### 1. 帧率控制

前端可通过调整 `requestAnimationFrame` 频率控制发送帧率。

### 2. 图片压缩

前端发送前可压缩图片质量:
```javascript
canvas.toDataURL('image/jpeg', 0.8)
```

### 3. 批处理

可修改 `detector.py` 支持批量检测多帧。

## 错误处理

| 错误码 | 说明 |
|--------|------|
| 1006 | WebSocket 连接异常关闭 |
| 400 | 请求参数错误 |
| 500 | 服务器内部错误 |

## 日志

日志默认级别为 INFO，可通过修改 `app/main.py` 调整:

```python
logging.basicConfig(level=logging.DEBUG)
```

## 相关文档

- [FastAPI 文档](https://fastapi.tiangolo.com/)
- [Ultralytics YOLOv8](https://docs.ultralytics.com/)
- [YOLOv8 GitHub](https://github.com/ultralytics/ultralytics)
