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

# Per-connection TTS state (connection-scoped to avoid race conditions)
_connection_tts_state = {}
_tts_lock = threading.Lock()

# Concurrency limit - max pending frames in queue
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
    pending_count = 0  # Fix #5: Concurrency limit counter
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
                    # Fix #5: Check pending count before processing
                    if pending_count >= MAX_PENDING_FRAMES:
                        logger.warning(f"Connection {connection_id}: Max pending frames reached, dropping frame")
                        continue
                    
                    conf_int = message[1] if len(message) > 1 else 25
                    latest_confidence = conf_int / 100.0
                    image_bytes = message[2:] if len(message) > 2 else message[1:]
                    latest_image_bytes = image_bytes
                    
                    if not is_processing and latest_image_bytes:
                        is_processing = True
                        pending_count += 1
                        img_data = latest_image_bytes
                        conf = latest_confidence
                        
                        loop = asyncio.get_event_loop()
                        
                        def process_task():
                            try:
                                return detector.detect(img_data, conf=conf)
                            except Exception as e:
                                logger.error(f"Detection error: {e}")
                                return {"detections": []}
                        
                        def callback_wrapper(fut):
                            try:
                                result = fut.result()
                            except Exception as e:
                                logger.error(f"Executor error: {e}")
                                result = {"detections": []}
                            # 在正确的线程中调度 asyncio 任务
                            asyncio.run_coroutine_threadsafe(
                                send_result(result, websocket, connection_id),
                                loop
                            )
                        
                        loop.run_in_executor(None, process_task).add_done_callback(callback_wrapper)
                    async def send_result(result, ws, cid):
                        nonlocal is_processing, latest_detections, pending_count
                        pending_count -= 1  # Fix #5: Decrement on completion
                        is_processing = False
                        try:
                            detections = result.get("detections", [])
                            response = {
                                "type": "result",
                                "detections": detections
                            }
                            
                            new_classes = set(d["class_name_cn"] for d in detections)
                            old_classes = set(d["class_name_cn"] for d in latest_detections)
                            new_detected = new_classes - old_classes
                            
                            logger.info(f"Detections: {new_detected}, TTS enabled: {tts_handler.get_tts_config().get('enabled', False)}")
                            
                            # Fix #6: Pass connection_id to should_speak
                            if new_detected and tts_handler.get_tts_config().get('enabled', False):
                                config = tts_handler.get_tts_config()
                                for class_name in new_detected:
                                    if should_speak(class_name, cid):
                                        text = f"我看到了{class_name}"
                                        logger.info(f"[TTS] Speaking: {text}")
                                        audio_data = await asyncio.get_event_loop().run_in_executor(
                                            None, tts_handler.synthesize_speech, text
                                        )
                                        logger.info(f"[TTS] Audio generated, size: {len(audio_data) if audio_data else 0}")
                                        if audio_data:
                                            audio_b64 = base64.b64encode(audio_data).decode('utf-8')
                                            await manager.send_message(ws, {
                                                "type": "tts",
                                                "audio": audio_b64,
                                                "text": text
                                            })
                            
                            latest_detections = detections
                            await manager.send_message(ws, response)
                        except Exception as e:
                            logger.error(f"Send error: {e}")
    
    except WebSocketDisconnect:
        manager.disconnect(websocket)
        logger.info("Client disconnected")
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
        manager.disconnect(websocket)
