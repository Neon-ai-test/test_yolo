<template>
  <div class="fixed inset-0 bg-black overflow-hidden">
    <!-- 视频区域 -->
    <video 
      ref="videoRef" 
      autoplay 
      playsinline 
      muted
      class="absolute inset-0 w-full h-full object-contain"
    ></video>
    <canvas 
      ref="canvasRef"
      class="absolute inset-0 w-full h-full object-contain pointer-events-none"
    ></canvas>
    
    <!-- 未开始提示 -->
    <div v-if="!isStreaming" class="absolute inset-0 flex items-center justify-center bg-black/80">
      <p class="text-gray-400 text-lg">点击底部按钮开始识别</p>
    </div>
    
    <!-- 顶部状态栏 -->
    <div class="absolute top-0 left-0 right-0 p-3 bg-gradient-to-b from-black/70 to-transparent">
      <div class="flex items-center justify-between text-white">
        <span class="text-sm font-medium">YOLO 视觉识别</span>
        <div class="flex items-center gap-3">
          <div class="flex items-center gap-1">
            <span class="text-xs">{{ (confidence * 100).toFixed(0) }}%</span>
            <input 
              type="range" 
              min="0.1" 
              max="0.9" 
              step="0.05" 
              v-model="confidence"
              @input="saveConfidence"
              class="w-20 h-1 bg-white/30 rounded-lg appearance-none cursor-pointer"
            >
          </div>
          <span class="text-sm px-2 py-0.5 rounded" :class="device === 'cuda' ? 'bg-green-500/70' : 'bg-yellow-500/70'">
            {{ device === 'cuda' ? 'GPU' : 'CPU' }}
          </span>
          <span class="text-sm">{{ recommendedFps }} FPS</span>
          <span class="text-sm" :class="wsConnected ? 'text-green-400' : 'text-red-400'">
            {{ wsConnected ? '●' : '○' }}
          </span>
        </div>
      </div>
    </div>
    
    <!-- 底部控制栏 -->
    <div class="absolute bottom-0 left-0 right-0 p-3 bg-gradient-to-t from-black/70 to-transparent">
      <div class="flex justify-center gap-4">
        <button 
          @click="toggleCamera"
          class="px-6 py-2 rounded-full font-medium transition-colors"
          :class="isStreaming ? 'bg-red-500 hover:bg-red-600' : 'bg-green-500 hover:bg-green-600'"
        >
          {{ isStreaming ? '停止识别' : '开始识别' }}
        </button>
      </div>
    </div>
    
    <!-- 右侧识别结果面板 -->
    <div 
      class="absolute top-16 right-3 w-48 max-h-[60vh] overflow-y-auto rounded-lg bg-black/50 backdrop-blur-sm p-3"
      :class="detections.length > 0 ? 'block' : 'hidden'"
    >
      <div class="text-white text-sm">
        <div class="font-medium mb-2">识别结果 ({{ detections.length }})</div>
        <div class="space-y-1">
          <div 
            v-for="(det, idx) in detections" 
            :key="idx"
            class="flex justify-between items-center py-1 px-2 bg-white/10 rounded"
          >
            <span>{{ det.class_name_cn || det.class_name }}</span>
            <span class="text-gray-400">{{ (det.confidence * 100).toFixed(0) }}%</span>
          </div>
        </div>
      </div>
    </div>
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
const CONFIDENCE = parseFloat(localStorage.getItem('yolo_confidence') || '0.25')
const confidence = ref(CONFIDENCE)

const saveConfidence = () => {
  localStorage.setItem('yolo_confidence', confidence.value.toString())
  setConfidence(confidence.value)
}

const { connect, disconnect, sendFrame, setConfidence, onMessage } = useWebSocket()

const uniqueClasses = computed(() => {
  const classes = new Set(detections.value.map(d => d.class_name))
  return classes.size
})

let stream = null
let rafId = null
let lastCaptureTime = 0
let isProcessing = false
let frameInterval = 100
let imageSize = { width: 640, height: 480 }
let lastPersonCount = 0
let cachedCanvasSize = { width: 0, height: 0 }
let offscreenCanvas = null
let offscreenCtx = null
const SCALE_FACTOR = 1
const PLAY_SOUND = false

const playDetectionSound = () => {
  if (!PLAY_SOUND) return
  try {
    const audioCtx = new (window.AudioContext || window.webkitAudioContext)()
    const oscillator = audioCtx.createOscillator()
    const gainNode = audioCtx.createGain()
    
    oscillator.connect(gainNode)
    gainNode.connect(audioCtx.destination)
    
    oscillator.frequency.value = 800
    oscillator.type = 'sine'
    gainNode.gain.setValueAtTime(0.3, audioCtx.currentTime)
    gainNode.gain.exponentialRampToValueAtTime(0.01, audioCtx.currentTime + 0.3)
    
    oscillator.start(audioCtx.currentTime)
    oscillator.stop(audioCtx.currentTime + 0.3)
  } catch (e) {
    console.log('Audio error:', e)
  }
}

const playTTSAudio = (audioBase64) => {
  console.log('[TTS] Received audio, length:', audioBase64.length)
  try {
    const audioData = Uint8Array.from(atob(audioBase64), c => c.charCodeAt(0))
    console.log('[TTS] Audio data length:', audioData.length)
    
    const audioCtx = new (window.AudioContext || window.webkitAudioContext)()
    const sampleRate = 24000
    const numChannels = 1
    const numSamples = audioData.length / 2
    
    const buffer = audioCtx.createBuffer(numChannels, numSamples, sampleRate)
    const channelData = buffer.getChannelData(0)
    
    const int16Array = new Int16Array(audioData.buffer)
    for (let i = 0; i < int16Array.length; i++) {
      channelData[i] = (int16Array[i] / 32768.0) * 3  // 放大音量
    }
    
    const source = audioCtx.createBufferSource()
    source.buffer = buffer
    source.connect(audioCtx.destination)
    source.start()
    console.log('[TTS] Playing...')
  } catch (e) {
    console.error('[TTS] Play error:', e)
  }
} // 图片放大倍数，可调整

const initBenchmark = async () => {
  try {
    const [infoRes, benchmarkRes] = await Promise.all([
      fetch('/api/info'),
      fetch('/api/benchmark')
    ])
    const info = await infoRes.json()
    const benchmark = await benchmarkRes.json()
    
    device.value = info.device || 'cpu'
    recommendedFps.value = benchmark.recommended_fps || 10
    frameInterval = Math.floor(1000 / recommendedFps.value)
  } catch (e) {
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
    
    wsConnected.value = connect('ws://localhost:3000/ws/detect')
    setConfidence(confidence.value)
    
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
  if (rafId) {
    cancelAnimationFrame(rafId)
    rafId = null
  }
  isStreaming.value = false
  disconnect()
  wsConnected.value = false
  detections.value = []
  isProcessing = false
  cachedCanvasSize = { width: 0, height: 0 }
  offscreenCanvas = null
  offscreenCtx = null
  lastCaptureTime = 0
  
  const canvas = canvasRef.value
  if (canvas) {
    const ctx = canvas.getContext('2d')
    ctx.clearRect(0, 0, canvas.width, canvas.height)
  }
}

const captureFrame = () => {
  if (!isStreaming.value) return
  
  const now = performance.now()
  if (!isProcessing && now - lastCaptureTime >= frameInterval) {
    lastCaptureTime = now
    
    const video = videoRef.value
    if (video && video.readyState === 4) {
      const videoWidth = video.videoWidth || 640
      const videoHeight = video.videoHeight || 480
      
      const containerWidth = video.clientWidth
      const containerHeight = video.clientHeight
      
      const containerRatio = containerWidth / containerHeight
      const videoRatio = videoWidth / videoHeight
      
      let srcX = 0, srcY = 0, srcW = videoWidth, srcH = videoHeight
      
      if (containerRatio > videoRatio) {
        srcH = containerHeight * videoWidth / containerWidth
        srcY = (videoHeight - srcH) / 2
      } else {
        srcW = containerWidth * videoHeight / containerHeight
        srcX = (videoWidth - srcW) / 2
      }
      
      if (!offscreenCanvas) {
        offscreenCanvas = document.createElement('canvas')
        offscreenCtx = offscreenCanvas.getContext('2d')
      }
      
      offscreenCanvas.width = Math.floor(srcW * SCALE_FACTOR)
      offscreenCanvas.height = Math.floor(srcH * SCALE_FACTOR)
      imageSize = { width: offscreenCanvas.width, height: offscreenCanvas.height }
      
      offscreenCtx.drawImage(video, srcX, srcY, srcW, srcH, 0, 0, offscreenCanvas.width, offscreenCanvas.height)
      
      offscreenCanvas.toBlob((blob) => {
        if (blob && isStreaming.value) {
          blob.arrayBuffer().then(buffer => {
            isProcessing = true
            sendFrame(buffer)
          })
        }
      }, 'image/jpeg', 0.7)
    }
  }
  
  rafId = requestAnimationFrame(captureFrame)
}

const drawDetections = (dets) => {
  const canvas = canvasRef.value
  if (!canvas) return
  
  const ctx = canvas.getContext('2d')
  
  const newWidth = canvas.clientWidth
  const newHeight = canvas.clientHeight
  if (cachedCanvasSize.width !== newWidth || cachedCanvasSize.height !== newHeight) {
    canvas.width = newWidth
    canvas.height = newHeight
    cachedCanvasSize = { width: newWidth, height: newHeight }
  }
  
  ctx.clearRect(0, 0, canvas.width, canvas.height)
  
  if (!dets || dets.length === 0) return
  
  const video = videoRef.value
  if (!video) return
  
  const videoWidth = video.videoWidth || 640
  const videoHeight = video.videoHeight || 480
  
  const containerWidth = video.clientWidth
  const containerHeight = video.clientHeight
  
  const containerRatio = containerWidth / containerHeight
  const videoRatio = videoWidth / videoHeight
  
  let videoDisplayWidth, videoDisplayHeight, offsetX, offsetY
  
  if (containerRatio > videoRatio) {
    videoDisplayHeight = containerHeight
    videoDisplayWidth = videoDisplayHeight * videoRatio
    offsetX = (containerWidth - videoDisplayWidth) / 2
    offsetY = 0
  } else {
    videoDisplayWidth = containerWidth
    videoDisplayHeight = videoDisplayWidth / videoRatio
    offsetX = 0
    offsetY = (containerHeight - videoDisplayHeight) / 2
  }
  
  const scaleX = videoDisplayWidth / imageSize.width
  const scaleY = videoDisplayHeight / imageSize.height
  
  for (const det of dets) {
    const [x1, y1, x2, y2] = det.bbox
    const confidence = det.confidence
    const className = det.class_name_cn || det.class_name
    
    const sx1 = x1 * scaleX + offsetX
    const sy1 = y1 * scaleY + offsetY
    const sx2 = x2 * scaleX + offsetX
    const sy2 = y2 * scaleY + offsetY
    
    ctx.strokeStyle = '#00FF00'
    ctx.lineWidth = 2
    ctx.strokeRect(sx1, sy1, sx2 - sx1, sy2 - sy1)
    
    ctx.font = '12px Arial'
    const label = `${className} ${(confidence * 100).toFixed(0)}%`
    const textWidth = ctx.measureText(label).width
    
    ctx.fillStyle = 'rgba(0, 255, 0, 0.8)'
    ctx.fillRect(sx1, sy1 - 14, textWidth + 4, 14)
    
    ctx.fillStyle = '#000000'
    ctx.fillText(label, sx1 + 2, sy1 - 2)
  }
}

onMessage((data) => {
  console.log('[WS] Received:', data.type)
  
  if (data.type === 'tts' && data.audio) {
    console.log('[TTS] Got audio, text:', data.text)
    playTTSAudio(data.audio)
    return
  }
  
  if (data.type === 'result') {
    isProcessing = false
    const dets = data.detections || []
    if (data.width && data.height) {
      imageSize = { width: data.width, height: data.height }
    }
    
    const personCount = dets.filter(d => d.class_name === 'person').length
    if (personCount > 0 && personCount > lastPersonCount) {
      playDetectionSound()
    }
    lastPersonCount = personCount
    
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
