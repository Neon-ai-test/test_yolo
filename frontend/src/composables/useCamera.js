import { ref } from 'vue'

export default function useCamera() {
  const videoRef = ref(null)
  const currentCamera = ref('user')
  const hasBackCamera = ref(false)
  let stream = null

  const checkCameras = async () => {
    try {
      const devices = await navigator.mediaDevices.enumerateDevices()
      const videoDevices = devices.filter(d => d.kind === 'videoinput')
      hasBackCamera.value = videoDevices.some(d => {
        const label = d.label.toLowerCase()
        return label.includes('back') || label.includes('rear') || label.includes('后置')
      })
    } catch (_) { /* noop */ }
  }

  const startStream = async () => {
    stream = await navigator.mediaDevices.getUserMedia({
      video: { facingMode: currentCamera.value, width: 640, height: 480 }
    })
    videoRef.value.srcObject = stream
    await videoRef.value.play()
  }

  const stopStream = () => {
    if (stream) {
      stream.getTracks().forEach(t => t.stop())
      stream = null
    }
  }

  const switchCamera = () => {
    currentCamera.value = currentCamera.value === 'user' ? 'environment' : 'user'
  }

  return { videoRef, currentCamera, hasBackCamera, checkCameras, startStream, stopStream, switchCamera }
}
