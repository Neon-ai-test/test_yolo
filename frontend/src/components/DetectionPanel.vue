<template>
  <div
    class="absolute top-12 sm:top-14 right-1 sm:right-3 w-36 sm:w-48 max-h-[50vh] sm:max-h-[60vh] overflow-y-auto rounded-lg bg-black/50 backdrop-blur-sm p-2 sm:p-3"
    :class="detections.length > 0 ? 'block' : 'hidden'"
  >
    <div class="text-white text-xs sm:text-sm">
      <div class="font-medium mb-2">识别结果 ({{ detections.length }})</div>
      <div class="space-y-1">
        <div
          v-for="det in grouped"
          :key="det.class_name"
          class="flex justify-between items-center py-1 px-2 bg-white/10 rounded"
        >
          <div class="flex items-center gap-1 sm:gap-2 min-w-0">
            <span class="w-2 h-2 rounded-full flex-shrink-0" :style="{ backgroundColor: colorOf(det.class_name) }"></span>
            <span class="truncate">{{ det.class_name_cn || det.class_name }}</span>
          </div>
          <span class="text-gray-400 ml-1 flex-shrink-0">{{ (det.confidence * 100).toFixed(0) }}%</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  detections: { type: Array, default: () => [] }
})

const CLASS_COLORS = {
  person: '#3B82F6', car: '#EF4444', truck: '#DC2626', bus: '#F97316',
  motorcycle: '#8B5CF6', bicycle: '#10B981', dog: '#EC4899', cat: '#F43F5E',
  bird: '#14B8A6', horse: '#A855F7', sheep: '#22C55E', cow: '#84CC16'
}
const DEFAULT_COLOR = '#22D3EE'

const colorOf = (name) => CLASS_COLORS[name?.toLowerCase()] || DEFAULT_COLOR

const grouped = computed(() => {
  const best = new Map()
  for (const d of props.detections) {
    const key = d.class_name
    if (!best.has(key) || best.get(key).confidence < d.confidence) {
      best.set(key, d)
    }
  }
  return Array.from(best.values())
})
</script>
