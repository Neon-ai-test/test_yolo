import { ref } from 'vue'

export default function useWebSocket() {
  const socket = ref(null)
  const messageHandlers = ref([])
  let currentConfidence = 0.25
  let reconnectTimer = null
  let reconnectAttempts = 0
  const maxReconnectAttempts = 5
  const reconnectDelay = 2000
  let url = ''

  const connect = (wsUrl) => {
    url = wsUrl
    if (socket.value?.readyState === WebSocket.OPEN) {
      return true
    }

    if (reconnectTimer) {
      clearTimeout(reconnectTimer)
      reconnectTimer = null
    }

    socket.value = new WebSocket(wsUrl)

    socket.value.binaryType = 'arraybuffer'

    socket.value.onopen = () => {
      console.log('WebSocket connected')
      reconnectAttempts = 0
    }

    socket.value.onmessage = (event) => {
      const data = JSON.parse(event.data)
      messageHandlers.value.forEach(handler => handler(data))
    }

    socket.value.onclose = () => {
      console.log('WebSocket disconnected')
      socket.value = null
      tryReconnect()
    }

    socket.value.onerror = (error) => {
      console.error('WebSocket error:', error)
    }

    return true
  }

  const tryReconnect = () => {
    if (reconnectAttempts >= maxReconnectAttempts) {
      console.log('Max reconnect attempts reached')
      return
    }
    reconnectAttempts++
    console.log(`Reconnecting... (${reconnectAttempts}/${maxReconnectAttempts})`)
    reconnectTimer = setTimeout(() => {
      connect(url)
    }, reconnectDelay)
  }

  const disconnect = () => {
    if (reconnectTimer) {
      clearTimeout(reconnectTimer)
      reconnectTimer = null
    }
    reconnectAttempts = maxReconnectAttempts
    if (socket.value) {
      socket.value.close()
      socket.value = null
    }
  }

  const setConfidence = (conf) => {
    currentConfidence = conf
  }

  const sendFrame = (buffer) => {
    if (socket.value?.readyState === WebSocket.OPEN) {
      const confInt = Math.floor(currentConfidence * 100)
      const header = new Uint8Array([0x01, confInt])
      const combined = new Uint8Array(header.length + buffer.byteLength)
      combined.set(header, 0)
      combined.set(new Uint8Array(buffer), header.length)
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
    setConfidence,
    onMessage
  }
}
