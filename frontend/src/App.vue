<template>
  <div class="fixed inset-0 bg-black overflow-hidden">
    <Transition name="toast">
      <div v-if="toast.show" class="fixed top-16 left-1/2 -translate-x-1/2 z-50 px-4 py-2 rounded-lg shadow-lg max-w-[90vw]"
        :class="toast.type === 'error' ? 'bg-red-500' : 'bg-green-500'">
        <p class="text-white text-sm">{{ toast.message }}</p>
      </div>
    </Transition>

    <video ref="videoRef" autoplay playsinline muted class="absolute inset-0 w-full h-full object-contain"></video>
    <canvas ref="canvasRef" class="absolute inset-0 w-full h-full object-contain pointer-events-none"></canvas>

    <div v-if="!isStreaming" class="absolute inset-0 flex items-center justify-center bg-black/80">
      <p class="text-gray-400 text-lg">点击底部按钮开始识别</p>
    </div>

    <StatusBar
      v-model="confidence"
      :recommended-fps="recommendedFps"
      :current-fps="currentFps"
      :device="device"
      :connected="wsConnected"
      :loading="benchmarkLoading"
      @update:model-value="saveConfidence"
    />

    <div class="absolute bottom-0 left-0 right-0 p-2 sm:p-3 bg-gradient-to-t from-black/70 to-transparent">
      <div class="flex justify-center gap-2 sm:gap-4">
        <button v-if="hasBackCamera" @click="handleSwitchCamera"
          class="px-3 sm:px-4 py-2 rounded-full font-medium transition-colors bg-gray-600 hover:bg-gray-500 text-sm">
          <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 inline" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
          </svg>
          <span class="hidden sm:inline ml-1">{{ currentCamera === 'user' ? '后置' : '前置' }}</span>
        </button>
        <button @click="toggleDetection"
          class="px-4 sm:px-6 py-2 rounded-full font-medium transition-colors text-sm"
          :class="isStreaming ? 'bg-red-500 hover:bg-red-600' : 'bg-green-500 hover:bg-green-600'"
          :disabled="benchmarkLoading">
          {{ isStreaming ? '停止识别' : '开始识别' }}
        </button>
        <button @click="testWs"
          class="px-3 sm:px-4 py-2 rounded-full font-medium bg-blue-600 hover:bg-blue-500 transition-colors text-sm">
          <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M13 10V3L4 14h7v7l9-11h-7z" />
          </svg>
        </button>
        <button @click="showSettings = true"
          class="px-3 sm:px-4 py-2 rounded-full font-medium bg-gray-600 hover:bg-gray-500 transition-colors text-sm">
          <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
            <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
          </svg>
        </button>
      </div>
    </div>

    <SettingsDialog v-if="showSettings"
      :jpeg-quality="jpegQuality" :imgsz="imgsz" :imgsz-options="IMGSZ_OPTIONS"
      :tts-enabled="ttsEnabled" :tts-volume="ttsVolume" :tts-voice="ttsVoice" :cache-size="cacheSize"
      @close="showSettings = false" @change="handleSettingChange" @save="persistSettings" @clear-cache="clearCache"
    />

    <DetectionPanel :detections="detections" />
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, shallowRef, watch } from 'vue'
import useWebSocket from './composables/useWebSocket'
import useCamera from './composables/useCamera'
import useTTS from './composables/useTTS'
import StatusBar from './components/StatusBar.vue'
import DetectionPanel from './components/DetectionPanel.vue'
import SettingsDialog from './components/SettingsDialog.vue'

const IMGSZ_OPTIONS = [128, 160, 192, 224, 256, 288, 320, 416, 512, 640]
const RTT_WINDOW = 10

const { videoRef, currentCamera, hasBackCamera, checkCameras, startStream, stopStream, switchCamera } = useCamera()
const { connected: wsConnected, connect, disconnect, sendFrame, setConfidence, onMessage, onClose, isConnected, cleanup: cleanupWS } = useWebSocket()
const { ttsVolume, playBeep, playPCM, cleanup: cleanupTTS } = useTTS()

const canvasRef = ref(null)
const isStreaming = ref(false)
const detections = shallowRef([])
const recommendedFps = ref(10)
const currentFps = ref(0)
const device = ref('cpu')
const confidence = ref(parseFloat(localStorage.getItem('yolo_confidence') || '0.25'))
const showSettings = ref(false)
const benchmarkLoading = ref(false)
const ttsEnabled = ref(false)
const ttsVoice = ref('Cherry')
const cacheSize = ref({ total_bytes: 0, total_readable: '0 B', by_voice: {} })
const jpegQuality = ref(parseFloat(localStorage.getItem('yolo_jpeg_quality') || '0.7'))
const imgsz = ref(320)

const toast = ref({ show: false, message: '', type: 'error' })
let toastTimer = null
const showToast = (msg, type = 'error') => {
  if (toastTimer) clearTimeout(toastTimer)
  toast.value = { show: true, message: msg, type }
  toastTimer = setTimeout(() => { toast.value.show = false }, 3000)
}

let captureTimer = null
let isProcessing = false
let baseInterval = 100
let adaptiveInterval = 100
let imageSize = { width: 640, height: 480 }
let cachedCanvasSize = { width: 0, height: 0 }
let offscreenCanvas = null
let offscreenCtx = null
let cachedOffscreenSize = { width: 0, height: 0 }
let lastPersonCount = 0
let frameSentAt = 0
let rttSamples = []
let frameCount = 0
let fpsLastTime = performance.now()

const getWsUrl = () => {
  const proto = window.location.protocol === 'https:' ? 'wss:' : 'ws:'
  return `${proto}//${window.location.host}/ws/detect`
}

const getApiUrl = () => {
  return ''
}

const updateFps = () => {
  frameCount++
  const now = performance.now()
  if (now - fpsLastTime >= 1000) {
    currentFps.value = frameCount
    frameCount = 0
    fpsLastTime = now
  }
}

const updateRTT = (rtt) => {
  rttSamples.push(rtt)
  if (rttSamples.length > RTT_WINDOW) rttSamples.shift()
  const avg = rttSamples.reduce((a, b) => a + b, 0) / rttSamples.length
  adaptiveInterval = Math.max(baseInterval, Math.ceil(avg * 1.1))
}

const saveConfidence = () => {
  localStorage.setItem('yolo_confidence', confidence.value.toString())
  setConfidence(confidence.value)
}

const handleSettingChange = ({ field, value }) => {
  const map = { jpegQuality, imgsz, ttsEnabled, ttsVolume, ttsVoice }
  if (map[field]) map[field].value = value
}

const persistSettings = async () => {
  localStorage.setItem('yolo_tts_volume', ttsVolume.value.toString())
  localStorage.setItem('yolo_jpeg_quality', jpegQuality.value.toString())
  try {
    await fetch(`${getApiUrl()}/api/config`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        tts_enabled: ttsEnabled.value,
        tts_volume: ttsVolume.value,
        tts_voice: ttsVoice.value,
        imgsz: imgsz.value
      })
    })
  } catch (_) { /* noop */ }
}

const loadSettings = async () => {
  try {
    const res = await fetch(`${getApiUrl()}/api/config`)
    const data = await res.json()
    ttsEnabled.value = data.tts_enabled
    ttsVoice.value = data.tts_voice || 'Cherry'
    imgsz.value = data.imgsz
    await loadCacheSize()
  } catch (_) { /* noop */ }
}

const loadCacheSize = async () => {
  try {
    const res = await fetch(`${getApiUrl()}/api/tts/cache-size`)
    cacheSize.value = await res.json()
  } catch (_) { /* noop */ }
}

const clearCache = async () => {
  if (!confirm('确定要清除所有 TTS 缓存吗？')) return
  try {
    await fetch(`${getApiUrl()}/api/tts/clear-cache`, { method: 'POST' })
    await loadCacheSize()
    showToast('缓存已清除', 'success')
  } catch (_) {
    showToast('清除缓存失败', 'error')
  }
}

const testWs = async () => {
  const url = getWsUrl()
  showToast(`WS: ${url}`, 'success')
  try {
    await connect(url)
    showToast('WS 连接成功!', 'success')
  } catch (e) {
    showToast(`WS 失败: ${e.message}`, 'error')
  }
}

const initBenchmark = async () => {
  benchmarkLoading.value = true
  try {
    const [infoRes, benchmarkRes] = await Promise.all([
      fetch(`${getApiUrl()}/api/info`),
      fetch(`${getApiUrl()}/api/benchmark`)
    ])
    const info = await infoRes.json()
    const bm = await benchmarkRes.json()
    device.value = info.device || 'cpu'
    recommendedFps.value = bm.recommended_fps || 10
    baseInterval = Math.floor(1000 / recommendedFps.value)
    adaptiveInterval = baseInterval
  } catch (_) {
    recommendedFps.value = 10
    baseInterval = 100
    adaptiveInterval = 100
  } finally {
    benchmarkLoading.value = false
  }
}

const captureAndSend = () => {
  const video = videoRef.value
  if (!video || video.readyState !== 4) return
  const vw = video.videoWidth || 640
  const vh = video.videoHeight || 480
  const cw = video.clientWidth || vw
  const ch = video.clientHeight || vh
  const cRatio = cw / ch
  const vRatio = vw / vh
  let srcX = 0, srcY = 0, srcW = vw, srcH = vh
  if (cRatio > vRatio) {
    srcH = ch * vw / cw
    srcY = (vh - srcH) / 2
  } else {
    srcW = cw * vh / ch
    srcX = (vw - srcW) / 2
  }
  if (!offscreenCanvas) {
    offscreenCanvas = document.createElement('canvas')
    offscreenCtx = offscreenCanvas.getContext('2d')
  }
  const maxDim = Math.max(srcW, srcH)
  const scale = imgsz.value < maxDim ? imgsz.value / maxDim : 1
  const sendW = Math.round(srcW * scale)
  const sendH = Math.round(srcH * scale)
  if (cachedOffscreenSize.width !== sendW || cachedOffscreenSize.height !== sendH) {
    offscreenCanvas.width = sendW
    offscreenCanvas.height = sendH
    cachedOffscreenSize = { width: sendW, height: sendH }
  }
  imageSize = { width: sendW, height: sendH }
  offscreenCtx.drawImage(video, srcX, srcY, srcW, srcH, 0, 0, sendW, sendH)
  isProcessing = true
  offscreenCanvas.toBlob((blob) => {
    if (blob && isStreaming.value) {
      blob.arrayBuffer().then(buf => {
        frameSentAt = performance.now()
        sendFrame(buf)
        updateFps()
      })
    } else {
      isProcessing = false
    }
  }, 'image/jpeg', jpegQuality.value)
}

const captureLoop = () => {
  if (!isStreaming.value) return
  if (isProcessing && !isConnected()) isProcessing = false
  if (!isProcessing && isConnected()) captureAndSend()
  captureTimer = setTimeout(captureLoop, adaptiveInterval)
}

const startCapture = () => { captureTimer = setTimeout(captureLoop, 0) }
const stopCapture = () => {
  if (captureTimer) { clearTimeout(captureTimer); captureTimer = null }
}

const CLASS_COLORS = {
  person: '#3B82F6', car: '#EF4444', truck: '#DC2626', bus: '#F97316',
  motorcycle: '#8B5CF6', bicycle: '#10B981', dog: '#EC4899', cat: '#F43F5E',
  bird: '#14B8A6', horse: '#A855F7', sheep: '#22C55E', cow: '#84CC16'
}

const drawDetections = (dets) => {
  const canvas = canvasRef.value
  if (!canvas) return
  const ctx = canvas.getContext('2d')
  const w = canvas.clientWidth
  const h = canvas.clientHeight
  if (cachedCanvasSize.width !== w || cachedCanvasSize.height !== h) {
    canvas.width = w
    canvas.height = h
    cachedCanvasSize = { width: w, height: h }
  }
  ctx.clearRect(0, 0, canvas.width, canvas.height)
  if (!dets || dets.length === 0) return
  const video = videoRef.value
  if (!video) return
  const vw = video.videoWidth || 640
  const vh = video.videoHeight || 480
  const cw = video.clientWidth || vw
  const ch = video.clientHeight || vh
  const cRatio = cw / ch
  const vRatio = vw / vh
  let dw, dh, ox, oy
  if (cRatio > vRatio) { dh = ch; dw = dh * vRatio; ox = (cw - dw) / 2; oy = 0 }
  else { dw = cw; dh = dw / vRatio; ox = 0; oy = (ch - dh) / 2 }
  const sx = dw / imageSize.width
  const sy = dh / imageSize.height
  ctx.font = '12px Arial'
  for (const det of dets) {
    const [x1, y1, x2, y2] = det.bbox
    const label = `${det.class_name_cn || det.class_name} ${(det.confidence * 100).toFixed(0)}%`
    const color = CLASS_COLORS[det.class_name?.toLowerCase()] || '#22D3EE'
    const px1 = x1 * sx + ox
    const py1 = y1 * sy + oy
    const pw = (x2 - x1) * sx
    const ph = (y2 - y1) * sy
    ctx.strokeStyle = color
    ctx.lineWidth = 2
    ctx.strokeRect(px1, py1, pw, ph)
    const tw = ctx.measureText(label).width
    ctx.fillStyle = color
    ctx.globalAlpha = 0.8
    ctx.fillRect(px1, py1 - 14, tw + 4, 14)
    ctx.globalAlpha = 1
    ctx.fillStyle = '#FFFFFF'
    ctx.fillText(label, px1 + 2, py1 - 2)
  }
}

const toggleDetection = async () => {
  if (isStreaming.value) {
    stopCapture()
    stopStream()
    disconnect()
    isStreaming.value = false
    detections.value = []
    isProcessing = false
    rttSamples = []
    cachedCanvasSize = { width: 0, height: 0 }
    cachedOffscreenSize = { width: 0, height: 0 }
    offscreenCanvas = null
    offscreenCtx = null
    const c = canvasRef.value
    if (c) c.getContext('2d').clearRect(0, 0, c.width, c.height)
  } else {
    try {
      await startStream()
      isStreaming.value = true
      await connect(getWsUrl())
      setConfidence(confidence.value)
      startCapture()
    } catch (e) {
      stopCapture()
      stopStream()
      disconnect()
      isStreaming.value = false
      const msg = e.name === 'NotAllowedError' ? '无法访问摄像头' : `WS失败: ${e.message}`
      showToast(msg, 'error')
    }
  }
}

const handleSwitchCamera = async () => {
  const was = isStreaming.value
  if (was) { stopCapture(); stopStream() }
  switchCamera()
  if (was) {
    try {
      await startStream()
      startCapture()
    } catch (_) {
      showToast('摄像头切换失败', 'error')
    }
  }
}

onMessage((data) => {
  if (data.type === 'tts' && data.audio) {
    playPCM(data.audio)
    return
  }
  if (data.type === 'result') {
    isProcessing = false
    if (frameSentAt > 0) {
      updateRTT(performance.now() - frameSentAt)
      frameSentAt = 0
    }
    const dets = data.detections || []
    if (data.width && data.height) imageSize = { width: data.width, height: data.height }
    const pc = dets.filter(d => d.class_name === 'person').length
    if (pc > 0 && pc > lastPersonCount) playBeep()
    lastPersonCount = pc
    detections.value = dets
    drawDetections(dets)
  }
})

onClose(() => { isProcessing = false })

onMounted(() => {
  initBenchmark()
  loadSettings()
  checkCameras()
})

watch(showSettings, (v) => { if (v) loadCacheSize() })

onUnmounted(() => {
  stopCapture()
  stopStream()
  disconnect()
  cleanupWS()
  cleanupTTS()
  if (toastTimer) clearTimeout(toastTimer)
})
</script>

<style scoped>
.toast-enter-active, .toast-leave-active { transition: all 0.3s ease; }
.toast-enter-from, .toast-leave-to { opacity: 0; transform: translate(-50%, -20px); }
</style>
