import { ref } from 'vue'

export default function useWebSocket() {
  const socket = ref(null)
  const connected = ref(false)
  let messageHandlers = []
  let closeHandlers = []
  let currentConfidence = 0.25
  let wsUrl = ''

  const connect = (url) => {
    return new Promise((resolve, reject) => {
      wsUrl = url
      console.log('[WS] Connecting to:', url)

      if (socket.value?.readyState === WebSocket.OPEN) {
        console.log('[WS] Already open, reusing')
        resolve(true)
        return
      }

      const oldWs = socket.value
      socket.value = null
      if (oldWs) {
        try { oldWs.close() } catch (_) { /* noop */ }
      }

      let ws
      try {
        ws = new WebSocket(url)
      } catch (err) {
        console.error('[WS] new WebSocket() threw:', err.message)
        reject(new Error(`创建WebSocket失败: ${err.message}`))
        return
      }
      ws.binaryType = 'arraybuffer'
      socket.value = ws

      ws.onopen = () => {
        console.log('[WS] onopen fired, state=', ws.readyState)
        connected.value = true
        resolve(true)
      }

      ws.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data)
          if (data.type === 'connected') return
          for (const h of messageHandlers) h(data)
        } catch (_) { /* noop */ }
      }

      ws.onerror = (event) => {
        console.error('[WS] onerror, state=', ws?.readyState, 'url=', url)
        connected.value = false
        reject(new Error(`连接失败 (readyState=${ws?.readyState})`))
      }

      ws.onclose = (event) => {
        console.log('[WS] onclose, code=', event.code, 'reason=', event.reason)
        if (socket.value === ws) {
          connected.value = false
          for (const h of closeHandlers) h()
          socket.value = null
        }
      }
    })
  }

  const disconnect = () => {
    const ws = socket.value
    if (ws) {
      ws.onopen = null
      ws.onmessage = null
      ws.onerror = null
      ws.onclose = null
      try { ws.close() } catch (_) { /* noop */ }
      socket.value = null
    }
    connected.value = false
  }

  const setConfidence = (conf) => { currentConfidence = conf }
  const isConnected = () => socket.value?.readyState === WebSocket.OPEN

  const sendFrame = (buffer) => {
    if (!isConnected()) return
    const confByte = Math.floor(currentConfidence * 100)
    const header = new Uint8Array([0x01, confByte])
    const combined = new Uint8Array(header.length + buffer.byteLength)
    combined.set(header, 0)
    combined.set(new Uint8Array(buffer), header.length)
    socket.value.send(combined.buffer)
  }

  const onMessage = (handler) => { messageHandlers.push(handler) }
  const onClose = (handler) => { closeHandlers.push(handler) }

  const cleanup = () => {
    messageHandlers = []
    closeHandlers = []
  }

  return { connected, connect, disconnect, sendFrame, setConfidence, onMessage, onClose, isConnected, cleanup }
}
