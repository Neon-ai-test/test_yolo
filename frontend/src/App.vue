<template>
  <div class="min-h-screen bg-gray-100">
    <header class="bg-white shadow-sm">
      <div class="max-w-7xl mx-auto px-4 py-4 flex items-center justify-between">
        <h1 class="text-2xl font-bold text-gray-800">YOLO 视觉识别系统</h1>
        <div class="flex items-center gap-4">
          <span class="text-sm px-2 py-1 rounded" :class="device === 'cuda' ? 'bg-green-100 text-green-700' : 'bg-yellow-100 text-yellow-700'">
            {{ device === 'cuda' ? '● GPU' : '○ CPU' }}
          </span>
          <span class="text-sm text-gray-500">{{ recommendedFps }} FPS</span>
          <span class="text-sm" :class="wsConnected ? 'text-green-600' : 'text-red-600'">
            {{ wsConnected ? '● 已连接' : '● 未连接' }}
          </span>
        </div>
      </div>
    </header>

    <main class="max-w-7xl mx-auto px-4 py-6">
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div class="lg:col-span-2">
          <div class="bg-white rounded-lg shadow p-4">
            <div class="relative bg-black rounded-lg overflow-hidden" style="aspect-ratio: 4/3;">
              <video 
                ref="videoRef" 
                autoplay 
                playsinline 
                muted
                class="absolute inset-0 w-full h-full object-contain"
              ></video>
              <canvas 
                ref="canvasRef"
                class="absolute inset-0 w-full h-full pointer-events-none"
              ></canvas>
              
              <div v-if="!isStreaming" class="absolute inset-0 flex items-center justify-center bg-gray-900">
                <p class="text-gray-400">点击下方按钮开始识别</p>
              </div>
            </div>
            
            <div class="mt-4 flex gap-4">
              <button 
                @click="toggleCamera"
                class="px-6 py-2 rounded-lg font-medium transition-colors"
                :class="isStreaming ? 'bg-red-500 hover:bg-red-600' : 'bg-green-500 hover:bg-green-600'"
              >
                {{ isStreaming ? '停止识别' : '开始识别' }}
              </button>
            </div>
          </div>
        </div>

        <div class="space-y-4">
          <div class="bg-white rounded-lg shadow p-4">
            <h2 class="text-lg font-semibold mb-3">识别结果</h2>
            <div v-if="detections.length > 0" class="space-y-2 max-h-64 overflow-y-auto">
              <div 
                v-for="(det, idx) in detections" 
                :key="idx"
                class="p-2 bg-gray-50 rounded flex justify-between items-center"
              >
                <span class="font-medium">{{ det.class_name_cn || det.class_name }}</span>
                <span class="text-sm text-gray-500">{{ (det.confidence * 100).toFixed(1) }}%</span>
              </div>
            </div>
            <p v-else class="text-gray-400 text-sm">暂无识别结果</p>
          </div>

          <div class="bg-white rounded-lg shadow p-4">
            <h2 class="text-lg font-semibold mb-3">检测统计</h2>
            <div class="grid grid-cols-2 gap-4">
              <div class="text-center p-3 bg-gray-50 rounded">
                <div class="text-2xl font-bold text-blue-600">{{ detections.length }}</div>
                <div class="text-sm text-gray-500">目标数量</div>
              </div>
              <div class="text-center p-3 bg-gray-50 rounded">
                <div class="text-2xl font-bold text-green-600">{{ uniqueClasses }}</div>
                <div class="text-sm text-gray-500">类别数量</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </main>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, shallowRef } from 'vue'
import useWebSocket from './composables/useWebSocket'

const videoRef = ref(null)
const canvasRef = ref(null)
const isStreaming = ref(false)
const detections = shallowRef([])
const wsConnected = ref(false)
const recommendedFps = ref(10)
const device = ref('cpu')

const { connect, disconnect, sendFrame, onMessage } = useWebSocket()

const uniqueClasses = computed(() => {
  const classes = new Set(detections.value.map(d => d.class_name))
  return classes.size
})

let stream = null
let captureTimer = null
let isProcessing = false
let frameInterval = 100

const initBenchmark = async () => {
  try {
    const [infoRes, benchmarkRes] = await Promise.all([
      fetch('http://localhost:8000/api/info'),
      fetch('http://localhost:8000/api/benchmark')
    ])
    const info = await infoRes.json()
    const benchmark = await benchmarkRes.json()
    
    device.value = info.device || 'cpu'
    recommendedFps.value = benchmark.recommended_fps || 10
    frameInterval = Math.floor(1000 / recommendedFps.value)
    console.log('Device:', info, 'Benchmark:', benchmark)
  } catch (e) {
    console.warn('Init failed, using defaults')
    recommendedFps.value = 10
    frameInterval = 100
  }
}

const toggleCamera = async () => {
  if (isStreaming.value) {
    stopCamera()
  } else {
    await startCamera()
  }
}

const startCamera = async () => {
  try {
    stream = await navigator.mediaDevices.getUserMedia({
      video: { facingMode: 'user', width: 640, height: 480 }
    })
    videoRef.value.srcObject = stream
    await videoRef.value.play()
    
    isStreaming.value = true
    
    wsConnected.value = connect('ws://localhost:8000/ws/detect')
    
    captureFrame()
  } catch (err) {
    console.error('Camera error:', err)
    alert('无法访问摄像头')
  }
}

const stopCamera = () => {
  if (stream) {
    stream.getTracks().forEach(track => track.stop())
    stream = null
  }
  if (captureTimer) {
    clearInterval(captureTimer)
    captureTimer = null
  }
  isStreaming.value = false
  disconnect()
  wsConnected.value = false
  detections.value = []
  isProcessing = false
  
  const canvas = canvasRef.value
  if (canvas) {
    const ctx = canvas.getContext('2d')
    ctx.clearRect(0, 0, canvas.width, canvas.height)
  }
}

const captureFrame = () => {
  if (!isStreaming.value) return
  
  captureTimer = setInterval(() => {
    if (isProcessing) return
    
    const video = videoRef.value
    if (!video || video.readyState !== 4) return
    
    const canvas = document.createElement('canvas')
    canvas.width = 192
    canvas.height = 144
    const ctx = canvas.getContext('2d')
    ctx.drawImage(video, 0, 0, 192, 144)
    
    canvas.toBlob((blob) => {
      if (blob && isStreaming.value) {
        blob.arrayBuffer().then(buffer => {
          isProcessing = true
          sendFrame(buffer)
        })
      }
    }, 'image/jpeg', 0.7)
  }, frameInterval)
}

const drawDetections = (dets) => {
  const canvas = canvasRef.value
  if (!canvas) return
  
  const ctx = canvas.getContext('2d')
  const video = videoRef.value
  
  canvas.width = video.videoWidth || 640
  canvas.height = video.videoHeight || 480
  
  ctx.clearRect(0, 0, canvas.width, canvas.height)
  
  if (!dets || dets.length === 0) return
  
  const scaleX = canvas.width / 192
  const scaleY = canvas.height / 144
  
  for (const det of dets) {
    const [x1, y1, x2, y2] = det.bbox
    const confidence = det.confidence
    const className = det.class_name_cn || det.class_name
    
    const sx1 = x1 * scaleX
    const sy1 = y1 * scaleY
    const sx2 = x2 * scaleX
    const sy2 = y2 * scaleY
    
    ctx.strokeStyle = '#00FF00'
    ctx.lineWidth = 2
    ctx.strokeRect(sx1, sy1, sx2 - sx1, sy2 - sy1)
    
    ctx.fillStyle = '#00FF00'
    ctx.font = '14px Arial'
    const label = `${className} ${(confidence * 100).toFixed(0)}%`
    const textWidth = ctx.measureText(label).width
    
    ctx.fillStyle = 'rgba(0, 255, 0, 0.8)'
    ctx.fillRect(sx1, sy1 - 18, textWidth + 8, 18)
    
    ctx.fillStyle = '#000000'
    ctx.fillText(label, sx1 + 4, sy1 - 4)
  }
}

onMessage((data) => {
  if (data.type === 'result') {
    isProcessing = false
    const dets = data.detections || []
    detections.value = dets
    drawDetections(dets)
  }
})

onMounted(() => {
  initBenchmark()
})

onUnmounted(() => {
  stopCamera()
})
</script>
