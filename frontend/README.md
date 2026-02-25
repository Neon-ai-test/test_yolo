# YOLO 视觉识别系统 - 前端

基于 Vue3 + Vite + Tailwind CSS 实现的 YOLOv8 实时目标检测前端应用。

## 技术栈

| 技术 | 版本 | 说明 |
|------|------|------|
| Vue | ^3.4.15 | 渐进式前端框架 |
| Vite | ^5.0.12 | 构建工具 |
| Tailwind CSS | ^3.4.1 | 原子化CSS框架 |
| PostCSS | ^8.4.33 | CSS转换工具 |
| Autoprefixer | ^10.4.17 | CSS兼容性处理 |

## 项目结构

```
frontend/
├── src/
│   ├── assets/
│   │   └── main.css           # 全局样式
│   ├── components/            # 组件目录
│   ├── composables/
│   │   └── useWebSocket.js    # WebSocket 复用逻辑
│   ├── App.vue                # 根组件
│   └── main.js                # 入口文件
├── index.html                 # HTML模板
├── vite.config.js             # Vite配置
├── tailwind.config.js         # Tailwind配置
├── postcss.config.js          # PostCSS配置
└── package.json               # 依赖配置
```

## 功能特性

- 实时摄像头视频流捕获
- WebSocket 实时与后端通信
- 目标检测框可视化展示（Canvas绘制）
- 识别结果列表展示（中英文）
- 目标数量与类别统计
- 动态帧率调整（根据服务器性能）
- 设备显示（CPU/GPU）

## 快速开始

### 安装依赖

```bash
npm install
```

### 开发模式

```bash
npm run dev
```

启动后访问 http://localhost:3000

### 生产构建

```bash
npm run build
```

构建产物输出到 `dist` 目录

### 预览构建

```bash
npm run preview
```

## 页面说明

### 主页面布局

```
┌──────────────────────────────────────────────────────────┐
│  YOLO 视觉识别系统         [CPU] 3 FPS  ● 已连接        │
├─────────────────────────────┬──────────────────────────┤
│                             │   识别结果                 │
│   ┌─────────────────────┐  │   ┌──────────────────┐    │
│   │                     │  │   │ 人  95%          │    │
│   │   视频/识别区域      │  │   │ 狗  87%          │    │
│   │   (Canvas叠加框)    │  │   └──────────────────┘    │
│   │                     │  │                            │
│   └─────────────────────┘  ├──────────────────────────┤
│                             │   检测统计                 │
│   [开始识别] [停止]         │   目标: 2  类别: 2        │
└─────────────────────────────┴──────────────────────────┘
```

### 顶部状态栏

| 显示 | 说明 |
|------|------|
| CPU (黄色) | 服务器使用CPU推理 |
| GPU (绿色) | 服务器使用GPU推理 |
| XX FPS | 推荐帧率（根据服务器性能动态调整） |

## WebSocket 通信

### 连接地址

```
ws://localhost:8000/ws/detect
```

### 发送消息格式

```javascript
{
  type: "frame",
  image: "base64编码的图片数据"
}
```

### 接收消息格式

```javascript
{
  type: "result",
  detections: [
    {
      bbox: [x1, y1, x2, y2],
      confidence: 0.95,
      class_id: 0,
      class_name: "person",
      class_name_cn: "人"
    }
  ]
}
```

## API 接口

| 接口 | 方法 | 说明 |
|------|------|------|
| `/api/classes` | GET | 获取识别类别列表（含中文） |
| `/api/benchmark` | GET | 性能测试，返回推荐帧率 |
| `/api/info` | GET | 获取设备信息 |

## 性能优化

### 前端优化策略

1. **帧率控制**：根据服务器推荐动态调整（默认10FPS）
2. **图片压缩**：发送前压缩至320x240，JPEG质量70%
3. **互斥锁**：防止请求堆积
4. **shallowRef**：减少Vue响应式开销
5. **Canvas绘制**：比传输带框图片更高效

### 后端优化策略

1. **自动GPU检测**：支持CUDA加速
2. **异步处理**：不阻塞WebSocket连接
3. **队列削峰**：只处理最新帧

## 样式配置

### Tailwind CSS

在 `tailwind.config.js` 中配置扫描路径：

```javascript
export default {
  content: [
    "./index.html",
    "./src/**/*.{vue,js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {},
  },
  plugins: [],
}
```

### 全局样式

`src/assets/main.css` 中引入 Tailwind 基础指令：

```css
@tailwind base;
@tailwind components;
@tailwind utilities;
```

## 浏览器兼容性

- Chrome >= 90
- Firefox >= 88
- Safari >= 14
- Edge >= 90

需要支持 `getUserMedia` API 以访问摄像头。

## 常见问题

### 1. 摄像头无法访问

检查浏览器权限设置，确保允许访问摄像头。

### 2. WebSocket 连接失败

确认后端服务已启动在 http://localhost:8000

### 3. 识别延迟高

- 服务器性能不足（推荐使用GPU）
- 网络延迟过高（建议局域网访问）

### 4. 帧率过低

- 使用GPU服务器可大幅提升
- 阿里云GPU实例可达30-60FPS

## 相关文档

- [Vue3 文档](https://vuejs.org/)
- [Vite 文档](https://vitejs.dev/)
- [Tailwind CSS 文档](https://tailwindcss.com/)
- [MDN getUserMedia](https://developer.mozilla.org/en-US/docs/Web/API/MediaDevices/getUserMedia)
