<template>
  <div class="absolute top-0 left-0 right-0 p-2 sm:p-3 bg-gradient-to-b from-black/70 to-transparent">
    <div class="flex items-center justify-between text-white">
      <span class="text-xs sm:text-sm font-medium">
        {{ loading ? '测速中...' : 'YOLO 视觉识别' }}
      </span>
      <div class="flex items-center gap-2 sm:gap-3">
        <span class="text-xs sm:text-sm">
          <span class="text-gray-400">{{ recommendedFps }}</span>
          <span class="text-yellow-400">/{{ currentFps }}</span>
          <span class="text-gray-500 text-xs">FPS</span>
        </span>
        <div class="flex items-center gap-1">
          <span class="text-xs">{{ (modelValue * 100).toFixed(0) }}%</span>
          <input
            type="range"
            min="0.1"
            max="0.9"
            step="0.05"
            :value="modelValue"
            @input="$emit('update:modelValue', parseFloat($event.target.value))"
            class="w-16 sm:w-20 h-2 bg-white/30 rounded-lg appearance-none cursor-pointer touch-none"
          >
        </div>
        <span class="text-xs sm:text-sm px-2 py-0.5 rounded" :class="device === 'cuda' ? 'bg-green-500/70' : 'bg-yellow-500/70'">
          {{ device === 'cuda' ? 'GPU' : 'CPU' }}
        </span>
        <svg xmlns="http://www.w3.org/2000/svg" class="w-3 h-3" :class="connected ? 'text-green-400' : 'text-red-400'" fill="currentColor" viewBox="0 0 24 24">
          <circle cx="12" cy="12" r="6" />
        </svg>
      </div>
    </div>
  </div>
</template>

<script setup>
defineProps({
  recommendedFps: { type: Number, default: 10 },
  currentFps: { type: Number, default: 0 },
  modelValue: { type: Number, default: 0.25 },
  device: { type: String, default: 'cpu' },
  connected: { type: Boolean, default: false },
  loading: { type: Boolean, default: false }
})

defineEmits(['update:modelValue'])
</script>
