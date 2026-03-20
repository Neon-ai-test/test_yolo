<template>
  <div class="absolute inset-0 flex items-center justify-center bg-black/60 z-50 p-4">
    <div class="bg-gray-800 rounded-xl w-[360px] sm:w-[480px] max-w-[95vw] max-h-[80vh] overflow-hidden flex">
      <div class="w-20 sm:w-24 bg-gray-900/50 flex flex-col py-4">
        <button
          @click="activeTab = 'detection'"
          class="flex flex-col items-center gap-1 py-3 px-2 transition-colors"
          :class="activeTab === 'detection' ? 'text-blue-400 bg-blue-500/20' : 'text-gray-400 hover:text-white'"
        >
          <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
            <path stroke-linecap="round" stroke-linejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
          </svg>
          <span class="text-xs">检测</span>
        </button>
        <button
          @click="activeTab = 'voice'"
          class="flex flex-col items-center gap-1 py-3 px-2 transition-colors"
          :class="activeTab === 'voice' ? 'text-blue-400 bg-blue-500/20' : 'text-gray-400 hover:text-white'"
        >
          <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
          </svg>
          <span class="text-xs">语音</span>
        </button>
      </div>

      <div class="flex-1 flex flex-col min-w-0">
        <div class="flex justify-between items-center p-4 border-b border-gray-700">
          <h3 class="text-white text-lg font-medium">
            {{ activeTab === 'detection' ? '检测配置' : '语音配置' }}
          </h3>
          <button @click="$emit('close')" class="text-gray-400 hover:text-white text-2xl leading-none">&times;</button>
        </div>

        <div class="flex-1 overflow-y-auto p-4 space-y-4">
          <template v-if="activeTab === 'detection'">
            <div>
              <div class="flex items-center justify-between mb-2">
                <span class="text-white text-sm">图像质量</span>
                <span class="text-gray-400 text-sm">{{ Math.round(jpegQuality * 100) }}%</span>
              </div>
              <input type="range" min="0.3" max="1" step="0.1" :value="jpegQuality"
                @input="update('jpegQuality', parseFloat($event.target.value))"
                class="w-full h-2 bg-white/30 rounded-lg appearance-none cursor-pointer">
              <p class="text-gray-500 text-xs mt-1">影响传输画质和速度</p>
            </div>

            <div>
              <div class="flex items-center justify-between mb-2">
                <span class="text-white text-sm">检测尺寸</span>
                <span class="text-gray-400 text-sm">{{ imgsz }}px</span>
              </div>
              <div class="flex gap-1 sm:gap-2 flex-wrap">
                <button v-for="size in imgszOptions" :key="size"
                  @click="update('imgsz', size)"
                  class="px-2 sm:px-3 py-1 rounded text-xs transition-colors"
                  :class="imgsz === size ? 'bg-blue-500 text-white' : 'bg-gray-600 text-gray-300 hover:bg-gray-500'">
                  {{ size }}
                </button>
              </div>
              <p class="text-gray-500 text-xs mt-2">数值越大精度越高，速度越慢</p>
            </div>
          </template>

          <template v-else>
            <div class="flex items-center justify-between">
              <span class="text-white text-sm">语音播报</span>
              <button @click="update('ttsEnabled', !ttsEnabled)"
                class="relative w-12 h-6 rounded-full transition-colors"
                :class="ttsEnabled ? 'bg-green-500' : 'bg-gray-600'">
                <span class="absolute top-0.5 left-0.5 w-5 h-5 bg-white rounded-full transition-transform"
                  :class="ttsEnabled ? 'translate-x-6' : 'translate-x-0'"></span>
              </button>
            </div>

            <div v-if="ttsEnabled">
              <div class="flex items-center justify-between mb-2">
                <span class="text-white text-sm">播报音量</span>
                <span class="text-gray-400 text-sm">{{ (ttsVolume * 100).toFixed(0) }}%</span>
              </div>
              <input type="range" min="0.1" max="2" step="0.1" :value="ttsVolume"
                @input="update('ttsVolume', parseFloat($event.target.value))"
                class="w-full h-2 bg-white/30 rounded-lg appearance-none cursor-pointer">
            </div>

            <div v-if="ttsEnabled">
              <div class="flex items-center justify-between mb-2">
                <span class="text-white text-sm">音色选择</span>
              </div>
              <select :value="ttsVoice" @change="update('ttsVoice', $event.target.value)"
                class="w-full px-3 py-2 bg-gray-700 text-white rounded-lg appearance-none cursor-pointer">
                <option v-for="v in VOICES" :key="v.id" :value="v.id">{{ v.name }} - {{ v.desc }}</option>
              </select>
            </div>

            <div class="pt-4 border-t border-gray-700 mt-4">
              <div class="flex items-center justify-between mb-2">
                <span class="text-white text-sm">缓存大小</span>
                <span class="text-gray-400 text-sm">{{ cacheSize.total_readable }}</span>
              </div>
              <button @click="$emit('clear-cache')"
                class="w-full px-3 py-2 bg-red-500/20 hover:bg-red-500/30 text-red-400 rounded-lg text-sm transition-colors">
                清除缓存
              </button>
            </div>
          </template>
        </div>

        <div class="p-4 border-t border-gray-700">
          <button @click="$emit('close')"
            class="w-full py-2 rounded-lg bg-blue-500 hover:bg-blue-600 text-white font-medium transition-colors">
            完成
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'

const props = defineProps({
  jpegQuality: { type: Number, default: 0.7 },
  imgsz: { type: Number, default: 320 },
  imgszOptions: { type: Array, default: () => [128, 160, 192, 224, 256, 288, 320, 416, 512, 640] },
  ttsEnabled: { type: Boolean, default: false },
  ttsVolume: { type: Number, default: 1 },
  ttsVoice: { type: String, default: 'Cherry' },
  cacheSize: { type: Object, default: () => ({ total_bytes: 0, total_readable: '0 B', by_voice: {} }) }
})

const emit = defineEmits(['close', 'change', 'clear-cache'])

const activeTab = ref('detection')

let saveTimer = null
const update = (field, value) => {
  emit('change', { field, value })
  if (saveTimer) clearTimeout(saveTimer)
  saveTimer = setTimeout(() => emit('save'), 300)
}

const VOICES = [
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
</script>
