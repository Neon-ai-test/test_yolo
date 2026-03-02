import asyncio
import base64
import time
from fastapi import WebSocket, WebSocketDisconnect
from typing import Dict
import logging
import threading

from . import tts_handler

logger = logging.getLogger(__name__)


class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[WebSocket, bool] = {}

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections[websocket] = True

    def disconnect(self, websocket: WebSocket):
        self.active_connections.pop(websocket, None)

    async def send_message(self, websocket: WebSocket, message: dict):
        try:
            await websocket.send_json(message)
        except Exception as e:
            logger.error(f"Send error: {e}")


manager = ConnectionManager()

# Per-connection TTS state
_connection_tts_state = {}
_tts_lock = threading.Lock()

# Concurrency limit
MAX_PENDING_FRAMES = 2


def should_speak(class_name: str, connection_id: int) -> bool:
    """Check if TTS should speak for this connection."""
    config = tts_handler.get_tts_config()
    if not config.get('enabled', False):
        return False
    
    cooldown = config.get('detection', {}).get('tts_cooldown', 3)
    current_time = time.time()
    
    with _tts_lock:
        key = f"{connection_id}:{class_name}"
        last_time = _connection_tts_state.get(key, 0)
        if current_time - last_time < cooldown:
            return False
        _connection_tts_state[key] = current_time
        return True


async def handle_websocket(websocket: WebSocket, detector):
    await manager.connect(websocket)
    
    # Connection-scoped state
    connection_id = id(websocket)
    latest_image_bytes = None
    latest_confidence = 0.25
    is_processing = False
    pending_count = 0
    latest_detections = []
    
    try:
        while True:
            try:
                message = await asyncio.wait_for(websocket.receive_bytes(), timeout=1.0)
            except asyncio.TimeoutError:
                await asyncio.sleep(0)
                continue
            
            if message and len(message) > 0:
                msg_type = message[0]
                
                if msg_type == 0x01:
                    conf_int = message[1] if len(message) > 1 else 25
                    latest_confidence = conf_int / 100.0
                    image_bytes = message[2:] if len(message) > 2 else message[1:]
                    latest_image_bytes = image_bytes
                    img_size = len(image_bytes) if image_bytes else 0
                    
                    if not is_processing and latest_image_bytes:
                        is_processing = True
                        pending_count += 1
                        
                        # 直接同步处理（简单可靠）
                        try:
                            result = detector.detect(latest_image_bytes, conf=latest_confidence)
                            detections = result.get("detections", [])
                            
                            new_classes = set(d.get("class_name_cn") for d in detections)
                            old_classes = set(d.get("class_name_cn") for d in latest_detections)
                            new_detected = new_classes - old_classes
                            
                            logger.info(f"Detections: {new_detected}")
                            
                            # TTS 处理
                            if new_detected and tts_handler.get_tts_config().get('enabled', False):
                                for class_name in new_detected:
                                    if should_speak(class_name, connection_id):
                                        text = f"我看到了{class_name}"
                                        try:
                                            audio_data = tts_handler.synthesize_speech(text)
                                            if audio_data:
                                                audio_b64 = base64.b64encode(audio_data).decode('utf-8')
                                                await manager.send_message(websocket, {
                                                    "type": "tts", 
                                                    "audio": audio_b64, 
                                                    "text": text
                                                })
                                        except Exception as tts_err:
                                            logger.error(f"TTS error: {tts_err}")
                            
                            latest_detections = detections
                            
                            # 发送结果
                            logger.info(f"[WS] Sending result, detections={len(detections)}")
                            await manager.send_message(websocket, {
                                "type": "result", 
                                "detections": detections
                            })
                            
                        except Exception as e:
                            logger.error(f"Detection error: {e}")
                        finally:
                            pending_count -= 1
                            is_processing = False
                            
    except WebSocketDisconnect:
        manager.disconnect(websocket)
        logger.info("Client disconnected")
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
        manager.disconnect(websocket)
