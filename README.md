# YOLO 视觉识别系统

基于 YOLOv8n 的实时目标检测系统，支持前端视频流实时识别与语音播报。

## 项目介绍

| 项目 | 技术栈 |
|------|--------|
| 前端 | Vue3 + Vite + Tailwind CSS + Canvas |
| 后端 | FastAPI + Uvicorn + YOLOv8n |
| 通信 | WebSocket 实时传输 |
| 语音 | 阿里云通义千问 TTS |

## 功能特性

### 核心功能
- 实时摄像头目标检测
- 识别框 Canvas 叠加显示
- 中英文类别映射（COCO 80类）
- 动态帧率调整（根据服务器性能自动推荐）
- 自动 GPU/CPU 检测

### 语音播报
- 40+ 音色可选（中文、方言、外语）
- TTS 缓存机制（避免重复合成）
- 可调节音量
- 一键开关

### 用户体验
- 前置/后置摄像头自动检测与切换
- 设置弹窗分 Tab 设计（检测/语音）
- Toast 消息提示
- 推荐帧率与实际帧率对比显示
- WebSocket 自动 URL 检测与断线重连

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

### 项目结构

```
yolo-vision-system/
├── backend/                 # FastAPI 后端
│   ├── app/
│   │   ├── main.py         # 应用入口 & API 路由
│   │   ├── detector.py     # YOLO 检测器
│   │   ├── websocket_handler.py  # WebSocket 处理
│   │   └── tts_handler.py  # TTS 语音合成
│   ├── config.yaml         # 配置文件（TTS API Key 等）
│   ├── tts_cache/          # TTS 音频缓存目录
│   ├── requirements.txt    # Python 依赖
│   └── README.md           # 后端文档
│
├── frontend/               # Vue3 前端
│   ├── src/
│   │   ├── App.vue         # 主组件
│   │   ├── composables/
│   │   │   └── useWebSocket.js  # WebSocket 逻辑
│   │   └── assets/         # 静态资源
│   ├── package.json        # Node 依赖
│   └── README.md           # 前端文档
│
├── start.sh               # Linux 一键启动脚本
├── start.bat              # Windows 一键启动脚本
└── README.md              # 本文件
```

## API 文档

启动后端后访问：
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

### REST API 端点

| 端点 | 方法 | 说明 |
|------|------|------|
| `/api/classes` | GET | 获取识别类别（含中文映射） |
| `/api/info` | GET | 获取设备信息（CPU/GPU） |
| `/api/benchmark` | GET | 性能测试，返回推荐帧率 |
| `/api/config` | GET | 获取当前配置（TTS、检测尺寸等） |
| `/api/config` | POST | 更新配置 |
| `/api/detect` | POST | 上传图片进行检测 |
| `/api/tts/cache-size` | GET | 获取 TTS 缓存大小 |
| `/api/tts/clear-cache` | POST | 清除 TTS 缓存 |

### WebSocket 端点

```
ws://localhost:8000/ws/detect
```

发送二进制帧数据，接收 JSON 格式检测结果。

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

## TTS 语音播报配置

### 1. 获取阿里云 API Key

1. 访问 [阿里云 DashScope](https://dashscope.console.aliyun.com/)
2. 开通「通义千问语音合成」服务
3. 创建 API Key

### 2. 配置后端

编辑 `backend/config.yaml`：

```yaml
tts:
  enabled: true
  api_key: "your-dashscope-api-key"
  voice: "Cherry"  # 默认音色
detection:
  tts_cooldown: 3  # 语音播报冷却时间（秒）
```

### 3. 可用音色

| 音色 ID | 名称 | 描述 |
|---------|------|------|
| Cherry | 芊悦 | 阳光积极小姐姐 |
| Serena | 苏瑶 | 温柔小姐姐 |
| Ethan | 晨煦 | 标准普通话小哥哥 |
| Chelsie | 千雪 | 二次元虚拟女友 |
| Jada | 上海-阿珍 | 沪上阿姐（方言） |
| Rocky | 粤语-阿强 | 幽默阿强（方言） |
| Jennifer | 詹妮弗 | 美语女声（外语） |

> 完整 40+ 音色列表见前端设置面板

## 相关文档

- [前端文档](frontend/README.md)
- [后端文档](backend/README.md)
- [YOLOv8 官方文档](https://docs.ultralytics.com/)
- [阿里云 DashScope](https://dashscope.console.aliyun.com/)

## 常见问题

### Q: 识别延迟高怎么办？
A: 使用 GPU 服务器或降低前端帧率设置

### Q: 支持哪些识别类别？
A: COCO 80类，包括人、车、动物等

### Q: 如何切换模型？
A: 修改 `backend/app/detector.py` 中的模型路径

### Q: TTS 语音无法播报？
A: 检查 config.yaml 中的 API Key 是否正确配置，确保已开通通义千问语音合成服务

### Q: 摄像头切换按钮不显示？
A: 需要设备有前置和后置两个摄像头才会显示切换按钮
