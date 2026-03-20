import { ref } from 'vue'

export default function useTTS() {
  const ttsVolume = ref(parseFloat(localStorage.getItem('yolo_tts_volume') || '1'))
  let audioCtx = null

  const getCtx = () => {
    if (!audioCtx || audioCtx.state === 'closed') {
      audioCtx = new (window.AudioContext || window.webkitAudioContext)()
    }
    if (audioCtx.state === 'suspended') {
      audioCtx.resume()
    }
    return audioCtx
  }

  const playBeep = () => {
    try {
      const ctx = getCtx()
      const osc = ctx.createOscillator()
      const gain = ctx.createGain()
      osc.connect(gain)
      gain.connect(ctx.destination)
      osc.frequency.value = 800
      osc.type = 'sine'
      gain.gain.setValueAtTime(0.3, ctx.currentTime)
      gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.3)
      osc.start(ctx.currentTime)
      osc.stop(ctx.currentTime + 0.3)
    } catch (_) { /* noop */ }
  }

  const playPCM = (base64Data) => {
    try {
      const raw = Uint8Array.from(atob(base64Data), c => c.charCodeAt(0))
      const ctx = getCtx()
      const numSamples = raw.byteLength / 2
      const buffer = ctx.createBuffer(1, numSamples, 24000)
      const channel = buffer.getChannelData(0)
      const samples = new Int16Array(raw.buffer, raw.byteOffset, numSamples)
      const vol = ttsVolume.value * 3
      for (let i = 0; i < samples.length; i++) {
        channel[i] = (samples[i] / 32768.0) * vol
      }
      const src = ctx.createBufferSource()
      src.buffer = buffer
      src.connect(ctx.destination)
      src.start()
    } catch (e) {
      console.error('[TTS] Play error:', e)
    }
  }

  const cleanup = () => {
    if (audioCtx && audioCtx.state !== 'closed') {
      audioCtx.close()
      audioCtx = null
    }
  }

  return { ttsVolume, playBeep, playPCM, cleanup }
}
