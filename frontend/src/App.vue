<template>
  <div class="fixed inset-0 bg-black overflow-hidden">
    <!-- Toast 错误提示 -->
    <Transition name="toast">
      <div v-if="toast.show" class="fixed top-16 left-1/2 -translate-x-1/2 z-50 px-4 py-2 rounded-lg shadow-lg max-w-[90vw]"
        :class="toast.type === 'error' ? 'bg-red-500' : 'bg-green-500'">
        <p class="text-white text-sm">{{ toast.message }}</p>
      </div>
    </Transition>

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
    <div class="absolute top-0 left-0 right-0 p-2 sm:p-3 bg-gradient-to-b from-black/70 to-transparent">
      <div class="flex items-center justify-between text-white">
        <span class="text-xs sm:text-sm font-medium">YOLO 视觉识别</span>
        <div class="flex items-center gap-2 sm:gap-3">
          <!-- FPS: 推荐帧率 / 实际帧率 -->
          <span class="text-xs sm:text-sm">
            <span class="text-gray-400">{{ recommendedFps }}</span>
            <span class="text-yellow-400">/{{ currentFps }}</span>
            <span class="text-gray-500 text-xs">FPS</span>
          </span>
          <div class="flex items-center gap-1">
            <span class="text-xs">{{ (confidence * 100).toFixed(0) }}%</span>
            <input 
              type="range" 
              min="0.1" 
              max="0.9" 
              step="0.05" 
              v-model="confidence"
              @input="saveConfidence"
              class="w-14 sm:w-20 h-1 bg-white/30 rounded-lg appearance-none cursor-pointer"
            >
          </div>
          <span class="text-xs sm:text-sm px-2 py-0.5 rounded" :class="device === 'cuda' ? 'bg-green-500/70' : 'bg-yellow-500/70'">
            {{ device === 'cuda' ? 'GPU' : 'CPU' }}
          </span>
          <svg 
            xmlns="http://www.w3.org/2000/svg" 
            class="w-3 h-3" 
            :class="wsConnected ? 'text-green-400' : 'text-red-400'"
            fill="currentColor" 
            viewBox="0 0 24 24"
          >
            <circle cx="12" cy="12" r="6" />
          </svg>
        </div>
      </div>
    </div>
    
    <!-- 底部控制栏 -->
    <div class="absolute bottom-0 left-0 right-0 p-2 sm:p-3 bg-gradient-to-t from-black/70 to-transparent">
      <div class="flex justify-center gap-2 sm:gap-4">
        <!-- 摄像头切换按钮 -->
        <button 
          v-if="hasBackCamera"
          @click="switchCamera"
          :disabled="isStreaming"
          class="px-3 sm:px-4 py-2 rounded-full font-medium transition-colors bg-gray-600 hover:bg-gray-500 disabled:opacity-50 disabled:cursor-not-allowed text-sm"
        >
          <span class="hidden sm:inline flex items-center gap-1">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
            </svg>
            {{ currentCamera === 'user' ? '后置' : '前置' }}
          </span>
          <span class="sm:hidden">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
            </svg>
          </span>
        </button>
        <button 
          @click="toggleCamera"
          class="px-4 sm:px-6 py-2 rounded-full font-medium transition-colors text-sm"
          :class="isStreaming ? 'bg-red-500 hover:bg-red-600' : 'bg-green-500 hover:bg-green-600'"
        >
          {{ isStreaming ? '停止识别' : '开始识别' }}
        </button>
        <button 
          @click="showSettings = true"
          class="px-3 sm:px-4 py-2 rounded-full font-medium bg-gray-600 hover:bg-gray-500 transition-colors text-sm"
        >
          <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
            <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
          </svg>
        </button>
      </div>
    </div>
    
    <!-- 设置弹窗 -->
    <div v-if="showSettings" class="absolute inset-0 flex items-center justify-center bg-black/60 z-50 p-4">
      <div class="bg-gray-800 rounded-xl w-[360px] sm:w-[480px] max-w-[95vw] max-h-[80vh] overflow-hidden flex">
        <!-- 左侧 Tab 导航 -->
        <div class="w-20 sm:w-24 bg-gray-900/50 flex flex-col py-4">
          <button 
            @click="settingsTab = 'detection'"
            class="flex flex-col items-center gap-1 py-3 px-2 transition-colors"
            :class="settingsTab === 'detection' ? 'text-blue-400 bg-blue-500/20' : 'text-gray-400 hover:text-white'"
          >
            <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
              <path stroke-linecap="round" stroke-linejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
            </svg>
            <span class="text-xs">检测</span>
          </button>
          <button 
            @click="settingsTab = 'voice'"
            class="flex flex-col items-center gap-1 py-3 px-2 transition-colors"
            :class="settingsTab === 'voice' ? 'text-blue-400 bg-blue-500/20' : 'text-gray-400 hover:text-white'"
          >
            <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
            </svg>
            <span class="text-xs">语音</span>
          </button>
        </div>
        
        <!-- 右侧内容区 -->
        <div class="flex-1 flex flex-col min-w-0">
          <div class="flex justify-between items-center p-4 border-b border-gray-700">
            <h3 class="text-white text-lg font-medium">
              {{ settingsTab === 'detection' ? '检测配置' : '语音配置' }}
            </h3>
            <button @click="showSettings = false" class="text-gray-400 hover:text-white text-2xl leading-none">&times;</button>
          </div>
          
          <div class="flex-1 overflow-y-auto p-4 space-y-4">
            <!-- 检测配置 -->
            <template v-if="settingsTab === 'detection'">
              <!-- JPEG 图像质量 -->
              <div>
                <div class="flex items-center justify-between mb-2">
                  <span class="text-white text-sm">图像质量</span>
                  <span class="text-gray-400 text-sm">{{ Math.round(jpegQuality * 100) }}%</span>
                </div>
                <input 
                  type="range" 
                  min="0.3" 
                  max="1" 
                  step="0.1" 
                  v-model="jpegQuality"
                  class="w-full h-2 bg-white/30 rounded-lg appearance-none cursor-pointer"
                  @change="saveSettings"
                >
                <p class="text-gray-500 text-xs mt-1">影响传输画质和速度</p>
              </div>
              
              <!-- 检测尺寸 -->
              <div>
                <div class="flex items-center justify-between mb-2">
                  <span class="text-white text-sm">检测尺寸</span>
                  <span class="text-gray-400 text-sm">{{ imgsz }}px</span>
                </div>
                <div class="flex gap-1 sm:gap-2 flex-wrap">
                  <button 
                    v-for="size in imgszOptions" 
                    :key="size"
                    @click="imgsz = size; saveSettings()"
                    class="px-2 sm:px-3 py-1 rounded text-xs transition-colors"
                    :class="imgsz === size ? 'bg-blue-500 text-white' : 'bg-gray-600 text-gray-300 hover:bg-gray-500'"
                  >
                    {{ size }}
                  </button>
                </div>
                <p class="text-gray-500 text-xs mt-2">数值越大精度越高，速度越慢</p>
              </div>
            </template>
            
            <!-- 语音配置 -->
            <template v-else>
              <!-- 语音播报开关 -->
              <div class="flex items-center justify-between">
                <span class="text-white text-sm">语音播报</span>
                <button 
                  @click="ttsEnabled = !ttsEnabled; saveSettings()"
                  class="relative w-12 h-6 rounded-full transition-colors"
                  :class="ttsEnabled ? 'bg-green-500' : 'bg-gray-600'"
                >
                  <span 
                    class="absolute top-0.5 left-0.5 w-5 h-5 bg-white rounded-full transition-transform"
                    :class="ttsEnabled ? 'translate-x-6' : 'translate-x-0'"
                  ></span>
                </button>
              </div>
              
              <!-- TTS 音量控制 -->
              <div v-if="ttsEnabled">
                <div class="flex items-center justify-between mb-2">
                  <span class="text-white text-sm">播报音量</span>
                  <span class="text-gray-400 text-sm">{{ (ttsVolume * 100).toFixed(0) }}%</span>
                </div>
                <input 
                  type="range" 
                  min="0.1" 
                  max="2" 
                  step="0.1" 
                  v-model="ttsVolume"
                  class="w-full h-2 bg-white/30 rounded-lg appearance-none cursor-pointer"
                  @change="saveSettings"
                >
              </div>
              
              <!-- TTS 音色选择 -->
              <div v-if="ttsEnabled">
                <div class="flex items-center justify-between mb-2">
                  <span class="text-white text-sm">音色选择</span>
                </div>
                <select 
                  v-model="ttsVoice" 
                  @change="saveSettings"
                  class="w-full px-3 py-2 bg-gray-700 text-white rounded-lg appearance-none cursor-pointer"
                >
                  <option v-for="voice in voiceList" :key="voice.id" :value="voice.id">
                    {{ voice.name }} - {{ voice.desc }}
                  </option>
                </select>
              </div>
            </template>
          </div>
          
          <div class="p-4 border-t border-gray-700">
            <button 
              @click="showSettings = false" 
              class="w-full py-2 rounded-lg bg-blue-500 hover:bg-blue-600 text-white font-medium transition-colors"
            >
              完成
            </button>
          </div>
        </div>
      </div>
    </div>
    
    <!-- 右侧识别结果面板 -->
    <div 
      class="absolute top-12 sm:top-14 right-1 sm:right-3 w-36 sm:w-48 max-h-[50vh] sm:max-h-[60vh] overflow-y-auto rounded-lg bg-black/50 backdrop-blur-sm p-2 sm:p-3"
      :class="detections.length > 0 ? 'block' : 'hidden'"
    >
      <div class="text-white text-xs sm:text-sm">
        <div class="font-medium mb-2">识别结果 ({{ detections.length }})</div>
        <div class="space-y-1">
          <div 
            v-for="(det, idx) in uniqueDetections" 
            :key="idx"
            class="flex justify-between items-center py-1 px-2 bg-white/10 rounded"
          >
            <div class="flex items-center gap-1 sm:gap-2 min-w-0">
              <span class="w-2 h-2 rounded-full flex-shrink-0" :style="{ backgroundColor: getClassColor(det.class_name) }"></span>
              <span class="truncate">{{ det.class_name_cn || det.class_name }}</span>
            </div>
            <span class="text-gray-400 ml-1 flex-shrink-0">{{ (det.confidence * 100).toFixed(0) }}%</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, shallowRef } from 'vue'
import useWebSocket from './composables/useWebSocket'

// 类别颜色映射
const classColors = {
  person: '#3B82F6',     // 蓝色 - 人
  car: '#EF4444',        // 红色 - 车
  truck: '#DC2626',      // 深红 - 卡车
  bus: '#F97316',        // 橙色 - 公交车
  motorcycle: '#8B5CF6', // 紫色 - 摩托车
  bicycle: '#10B981',    // 绿色 - 自行车
  dog: '#EC4899',       // 粉色 - 狗
  cat: '#F43F5E',       // 红粉 - 猫
  bird: '#14B8A6',      // 青色 - 鸟
  horse: '#A855F7',     // 紫色 - 马
  sheep: '#22C55E',     // 绿色 - 羊
  cow: '#84CC16',       // 草绿 - 牛
  default: '#22D3EE'    // 青色 - 默认
}

const getClassColor = (className) => {
  return classColors[className?.toLowerCase()] || classColors.default
}

// 响应式状态
const videoRef = ref(null)
const canvasRef = ref(null)
const isStreaming = ref(false)
const detections = shallowRef([])
const wsConnected = ref(false)
const recommendedFps = ref(10)
const currentFps = ref(0)
const device = ref('cpu')
const CONFIDENCE = parseFloat(localStorage.getItem('yolo_confidence') || '0.25')
const confidence = ref(CONFIDENCE)
const showSettings = ref(false)
const settingsTab = ref('detection') // 'detection' or 'voice'
const ttsEnabled = ref(false)
const ttsVolume = ref(parseFloat(localStorage.getItem('yolo_tts_volume') || '1'))
const ttsVoice = ref('Cherry')

// TTS 音色列表
const voiceList = [
  // 中文标准音色
  { id: 'Cherry', name: '芊悦', desc: '阳光积极小姐姐' },
  { id: 'Serena', name: '苏瑶', desc: '温柔小姐姐' },
  { id: 'Ethan', name: '晨煦', desc: '标准普通话小哥哥' },
  { id: 'Chelsie', name: '千雪', desc: '二次元虚拟女友' },
  { id: 'Momo', name: '茉兔', desc: '撒娇搞怪' },
  { id: 'Vivian', name: '十三', desc: '拽拽小可爱' },
  { id: 'Moon', name: '月白', desc: '率性帅气小哥哥' },
  { id: 'Maia', name: '四月', desc: '知性温柔' },
  { id: 'Kai', name: '凯', desc: '耳朵SPA' },
  { id: 'Nofish', name: '不吃鱼', desc: '不会翘舌音' },
  { id: 'Bella', name: '萌宝', desc: '小萌妹' },
  { id: 'Jennifer', name: '詹妮弗', desc: '美语女声' },
  { id: 'Ryan', name: '甜茶', desc: '节奏感小哥哥' },
  { id: 'Katerina', name: '卡捷琳娜', desc: '御姐音' },
  { id: 'Aiden', name: '艾登', desc: '厨艺大男孩' },
  { id: 'Eldric Sage', name: '沧明子', desc: '沉稳老者' },
  { id: 'Mia', name: '乖小妹', desc: '温顺女生' },
  { id: 'Mochi', name: '沙小弥', desc: '聪明小男孩' },
  { id: 'Bellona', name: '燕铮莺', desc: '江湖女声' },
  { id: 'Vincent', name: '田叔', desc: '沙哑烟嗓' },
  { id: 'Bunny', name: '萌小姬', desc: '萌属性' },
  { id: 'Neil', name: '阿闻', desc: '新闻主持' },
  { id: 'Elias', name: '墨讲师', desc: '讲师女声' },
  { id: 'Arthur', name: '徐大爷', desc: '质朴老者' },
  { id: 'Nini', name: '邻家妹妹', desc: '甜美女生' },
  { id: 'Ebona', name: '诡婆婆', desc: '低语神秘' },
  { id: 'Seren', name: '小婉', desc: '助眠女声' },
  { id: 'Pip', name: '顽皮小孩', desc: '童真小男孩' },
  { id: 'Stella', name: '少女阿月', desc: '正义少女' },
  // 方言音色
  { id: 'Jada', name: '上海-阿珍', desc: '沪上阿姐' },
  { id: 'Dylan', name: '北京-晓东', desc: '北京胡同少年' },
  { id: 'Li', name: '南京-老李', desc: '瑜伽老师' },
  { id: 'Marcus', name: '陕西-秦川', desc: '老陕味道' },
  { id: 'Roy', name: '闽南-阿杰', desc: '台湾哥仔' },
  { id: 'Peter', name: '天津-李彼得', desc: '相声捧哏' },
  { id: 'Sunny', name: '四川-晴儿', desc: '川妹子' },
  { id: 'Eric', name: '四川-程川', desc: '市井男子' },
  { id: 'Rocky', name: '粤语-阿强', desc: '幽默阿强' },
  { id: 'Kiki', name: '粤语-阿清', desc: '港妹闺蜜' },
  // 外语音色
  { id: 'Bodega', name: '博德加', desc: '西班牙大叔' },
  { id: 'Sonrisa', name: '索尼莎', desc: '拉美大姐' },
  { id: 'Alek', name: '阿列克', desc: '战斗民族' },
  { id: 'Dolce', name: '多尔切', desc: '慵懒意大利' },
  { id: 'Sohee', name: '素熙', desc: '韩国欧尼' },
  { id: 'Ono Anna', name: '小野杏', desc: '青梅竹马' },
  { id: 'Lenn', name: '莱恩', desc: '德国青年' },
  { id: 'Emilien', name: '埃米尔安', desc: '法国哥哥' },
  { id: 'Andre', name: '安德雷', desc: '沉稳男生' },
  { id: 'Radio Gol', name: '拉迪奥·戈尔', desc: '足球解说' },
]

const jpegQuality = ref(parseFloat(localStorage.getItem('yolo_jpeg_quality') || '0.7'))
const imgsz = ref(320)
const imgszOptions = [128, 160, 192, 224, 256, 288, 320, 416, 512, 640]

// 摄像头状态
const currentCamera = ref('user')
const hasBackCamera = ref(false)

// 检测可用摄像头
const checkCameras = async () => {
  try {
    const devices = await navigator.mediaDevices.enumerateDevices()
    const videoDevices = devices.filter(d => d.kind === 'videoinput')
    hasBackCamera.value = videoDevices.some(d => {
      const label = d.label.toLowerCase()
      return label.includes('back') || label.includes('rear') || label.includes('后置')
    })
  } catch (e) {
    console.error('Failed to enumerate devices:', e)
  }
}

// Toast 状态
const toast = ref({
  show: false,
  message: '',
  type: 'error'
})

let toastTimer = null

const showToast = (message, type = 'error') => {
  if (toastTimer) clearTimeout(toastTimer)
  toast.value = { show: true, message, type }
  toastTimer = setTimeout(() => {
    toast.value.show = false
  }, 3000)
}

// FPS 计算
let frameCount = 0
let fpsLastTime = performance.now()

const updateFps = () => {
  frameCount++
  const now = performance.now()
  if (now - fpsLastTime >= 1000) {
    currentFps.value = frameCount
    frameCount = 0
    fpsLastTime = now
  }
}

// 去重检测结果
const uniqueDetections = computed(() => {
  const seen = new Map()
  for (const det of detections.value) {
    const key = det.class_name
    if (!seen.has(key) || seen.get(key).confidence < det.confidence) {
      seen.set(key, det)
    }
  }
  return Array.from(seen.values())
})
const saveConfidence = () => {
  localStorage.setItem('yolo_confidence', confidence.value.toString())
  setConfidence(confidence.value)
}

const loadSettings = async () => {
  try {
    const res = await fetch('/api/config')
    const data = await res.json()
    ttsEnabled.value = data.tts_enabled
    ttsVoice.value = data.tts_voice || 'Cherry'
    imgsz.value = data.imgsz
  } catch (e) {
    console.error('Failed to load config:', e)
  }
}

const saveSettings = async () => {
  try {
    localStorage.setItem('yolo_tts_volume', ttsVolume.value.toString())
    localStorage.setItem('yolo_jpeg_quality', jpegQuality.value.toString())
    await fetch('/api/config', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        tts_enabled: ttsEnabled.value,
        tts_volume: ttsVolume.value,
        tts_voice: ttsVoice.value,
        imgsz: imgsz.value
      })
    })
  } catch (e) {
    console.error('Failed to save config:', e)
  }
}

// 摄像头切换
const switchCamera = async () => {
  currentCamera.value = currentCamera.value === 'user' ? 'environment' : 'user'
  if (isStreaming.value) {
    stopCamera()
    await startCamera()
  }
}

// Auto-detect WebSocket URL based on current page location
const getWebSocketUrl = () => {
  const protocol = window.location.protocol === "https:" ? "wss:" : "ws:"
  const host = window.location.host
  return `${protocol}//${host}/ws/detect`
}

const { connect, disconnect, sendFrame, setConfidence, onMessage, isConnected } = useWebSocket()

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
    const volume = ttsVolume.value * 3
    for (let i = 0; i < int16Array.length; i++) {
      channelData[i] = (int16Array[i] / 32768.0) * volume
    }
    
    const source = audioCtx.createBufferSource()
    source.buffer = buffer
    source.connect(audioCtx.destination)
    source.start()
    console.log('[TTS] Playing...')
  } catch (e) {
    console.error('[TTS] Play error:', e)
  }
}

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
      video: { facingMode: currentCamera.value, width: 640, height: 480 }
    })
    videoRef.value.srcObject = stream
    await videoRef.value.play()
    
    isStreaming.value = true
    
    try {
      await connect(getWebSocketUrl())
      wsConnected.value = true
      setConfidence(confidence.value)
      captureFrame()
    } catch (e) {
      console.error('WebSocket connection failed:', e)
      wsConnected.value = false
      showToast('WebSocket 连接失败', 'error')
    }
  } catch (err) {
    console.error('Camera error:', err)
    showToast('无法访问摄像头', 'error')
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
  // Only process if WebSocket is connected and not currently processing
  if (!isProcessing && isConnected() && now - lastCaptureTime >= frameInterval) {
    console.log(`[capture] sending frame, isProcessing=${isProcessing}, interval=${now - lastCaptureTime}`)
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
            updateFps()
          })
        }
      }, 'image/jpeg', jpegQuality.value)
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
    
    // 使用类别颜色
    const color = getClassColor(det.class_name)
    ctx.strokeStyle = color
    ctx.lineWidth = 2
    ctx.strokeRect(sx1, sy1, sx2 - sx1, sy2 - sy1)
    
    ctx.font = '12px Arial'
    const label = `${className} ${(confidence * 100).toFixed(0)}%`
    const textWidth = ctx.measureText(label).width
    
    ctx.fillStyle = color
    ctx.globalAlpha = 0.8
    ctx.fillRect(sx1, sy1 - 14, textWidth + 4, 14)
    ctx.globalAlpha = 1
    
    ctx.fillStyle = '#FFFFFF'
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
  loadSettings()
  checkCameras()
})

onUnmounted(() => {
  stopCamera()
  if (toastTimer) clearTimeout(toastTimer)
})
</script>


<style scoped>
.toast-enter-active,
.toast-leave-active {
  transition: all 0.3s ease;
}

.toast-enter-from,
.toast-leave-to {
  opacity: 0;
  transform: translate(-50%, -20px);
}
</style>