import asyncio
import base64
import time
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from fastapi import WebSocket, WebSocketDisconnect
from typing import Dict
import logging

from . import tts_handler

logger = logging.getLogger(__name__)

# YOLO 模型非线程安全，限制为单线程
_detect_executor = ThreadPoolExecutor(max_workers=1)
_tts_executor = ThreadPoolExecutor(max_workers=2)

# 物体消失多久后"忘记"它（秒），重新出现时才会再次播报
ABSENCE_THRESHOLD = 5.0


class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[WebSocket, bool] = {}

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections[websocket] = True
        try:
            await websocket.send_json({"type": "connected", "message": "ready"})
        except Exception:
            pass

    def disconnect(self, websocket: WebSocket):
        self.active_connections.pop(websocket, None)

    async def send_message(self, websocket: WebSocket, message: dict):
        try:
            await websocket.send_json(message)
        except Exception as e:
            logger.error(f"Send error: {e}")


manager = ConnectionManager()

MAX_PENDING_FRAMES = 2


async def _send_tts_async(websocket: WebSocket, text: str, loop: asyncio.AbstractEventLoop):
    try:
        audio_data = await loop.run_in_executor(_tts_executor, tts_handler.synthesize_speech, text)
        if audio_data:
            audio_b64 = base64.b64encode(audio_data).decode('utf-8')
            await manager.send_message(websocket, {
                "type": "tts",
                "audio": audio_b64,
                "text": text
            })
    except Exception as e:
        logger.error(f"TTS error: {e}")


async def handle_websocket(websocket: WebSocket, detector):
    await manager.connect(websocket)

    latest_image_bytes = None
    latest_confidence = 0.25
    is_processing = False
    pending_count = 0
    loop = asyncio.get_event_loop()

    # TTS 状态：class_name -> {count: int, last_seen: float}
    # count: 已播报的该类别数量
    # last_seen: 最后一次检测到的时间
    # 只在 count 增加时播报，消失超过 ABSENCE_THRESHOLD 后重置
    active_tts = {}

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

                    if pending_count >= MAX_PENDING_FRAMES:
                        continue

                    if not is_processing and latest_image_bytes:
                        is_processing = True
                        pending_count += 1

                        try:
                            result = await loop.run_in_executor(
                                _detect_executor, detector.detect, latest_image_bytes, latest_confidence
                            )
                            detections = result.get("detections", [])
                            img_w = result.get("width", 0)
                            img_h = result.get("height", 0)

                            now = time.time()
                            current_counts = Counter(
                                d.get("class_name_cn") for d in detections
                                if d.get("class_name_cn")
                            )

                            expired = [
                                cls for cls, state in active_tts.items()
                                if cls not in current_counts
                                and now - state['last_seen'] > ABSENCE_THRESHOLD
                            ]
                            for cls in expired:
                                del active_tts[cls]

                            speak_items = []
                            for cls, count in current_counts.items():
                                if cls in active_tts:
                                    active_tts[cls]['last_seen'] = now
                                    if count > active_tts[cls]['count']:
                                        # 同类物体数量增加（放入了新的同类物体）
                                        speak_items.append(cls)
                                        active_tts[cls]['count'] = count
                                else:
                                    # 全新类别，或消失足够久后重新出现
                                    active_tts[cls] = {'count': count, 'last_seen': now}
                                    speak_items.append(cls)

                            if speak_items and tts_handler.get_tts_config().get('enabled', False):
                                for class_name in speak_items:
                                    text = f"我看到了{class_name}"
                                    asyncio.create_task(_send_tts_async(websocket, text, loop))

                            await manager.send_message(websocket, {
                                "type": "result",
                                "detections": detections,
                                "width": img_w,
                                "height": img_h
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
