import { ref } from 'vue'

export default function useWebSocket() {
  const socket = ref(null)
  const messageHandlers = ref([])

  const connect = (url) => {
    if (socket.value?.readyState === WebSocket.OPEN) {
      return true
    }

    socket.value = new WebSocket(url)

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

  const sendFrame = (imageData) => {
    if (socket.value?.readyState === WebSocket.OPEN) {
      socket.value.send(JSON.stringify({
        type: 'frame',
        image: imageData
      }))
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
