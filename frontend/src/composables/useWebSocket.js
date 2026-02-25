import { ref } from 'vue'

export default function useWebSocket() {
  const socket = ref(null)
  const messageHandlers = ref([])

  const connect = (url) => {
    if (socket.value?.readyState === WebSocket.OPEN) {
      return true
    }

    socket.value = new WebSocket(url)

    socket.value.binaryType = 'arraybuffer'

    socket.value.onopen = () => {
      console.log('WebSocket connected')
    }

    socket.value.onmessage = (event) => {
      const data = JSON.parse(event.data)
      messageHandlers.value.forEach(handler => handler(data))
    }

    socket.value.onclose = () => {
      console.log('WebSocket disconnected')
    }

    socket.value.onerror = (error) => {
      console.error('WebSocket error:', error)
    }

    return true
  }

  const disconnect = () => {
    if (socket.value) {
      socket.value.close()
      socket.value = null
    }
  }

  const sendFrame = (buffer) => {
    if (socket.value?.readyState === WebSocket.OPEN) {
      // 创建包含类型前缀的二进制数据
      // 第一个字节: 0x01 = frame
      const frameType = new Uint8Array([0x01])
      const combined = new Uint8Array(frameType.length + buffer.byteLength)
      combined.set(frameType, 0)
      combined.set(new Uint8Array(buffer), frameType.length)
      socket.value.send(combined)
    }
  }

  const onMessage = (handler) => {
    messageHandlers.value.push(handler)
  }

  return {
    connect,
    disconnect,
    sendFrame,
    onMessage
  }
}
