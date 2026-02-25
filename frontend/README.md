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
- 目标检测框可视化展示
- 识别结果列表展示
- 目标数量与类别统计

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
┌─────────────────────────────────────────────┐
│  YOLO 视觉识别系统                    ● 已连接 │
├──────────────────────────┬──────────────────┤
│                          │   识别结果        │
│   ┌──────────────────┐   │   ┌──────────┐   │
│   │                  │   │   │ person   │   │
│   │   视频/识别区域    │   │   │ 98.5%    │   │
│   │                  │   │   └──────────┘   │
│   │                  │   │   ┌──────────┐   │
│   └──────────────────┘   │   │ car      │   │
│                          │   │ 85.2%    │   │
│   [开始识别] [截图识别]    │   └──────────┘   │
│                          ├──────────────────┤
│                          │   检测统计        │
│                          │   ┌──┬──┐        │
│                          │   │5 │3 │        │
│                          │   └──┴──┘        │
└──────────────────────────┴──────────────────┘
```

### 按钮功能

| 按钮 | 功能 |
|------|------|
| 开始识别 | 启动摄像头并开始实时识别 |
| 停止识别 | 停止摄像头和识别 |
| 截图识别 | 手动捕获当前帧进行识别 |

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
      class_name: "person"
    }
  ],
  image: "base64编码的绘制了框的图片"
}
```

## API 代理配置

前端通过 Vite 代理连接后端：

| 路径 | 目标 | 说明 |
|------|------|------|
| `/api/*` | http://localhost:8000 | REST API |
| `/ws/*` | ws://localhost:8000 | WebSocket |

代理配置位于 `vite.config.js`。

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

- 降低视频分辨率
- 检查网络延迟
- 确保后端有足够的计算资源

## 相关文档

- [Vue3 文档](https://vuejs.org/)
- [Vite 文档](https://vitejs.dev/)
- [Tailwind CSS 文档](https://tailwindcss.com/)
- [MDN getUserMedia](https://developer.mozilla.org/en-US/docs/Web/API/MediaDevices/getUserMedia)
