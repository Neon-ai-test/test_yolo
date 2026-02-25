import asyncio
import base64
from fastapi import WebSocket, WebSocketDisconnect
from typing import Dict
import logging

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


async def handle_websocket(websocket: WebSocket, detector):
    await manager.connect(websocket)
    
    latest_image_bytes = None
    is_processing = False
    
    try:
        while True:
            try:
                message = await asyncio.wait_for(websocket.receive_bytes(), timeout=0.001)
            except asyncio.TimeoutError:
                await asyncio.sleep(0)
                continue
            
            if message and len(message) > 0:
                msg_type = message[0]
                
                if msg_type == 0x01:
                    image_bytes = message[1:]
                    latest_image_bytes = image_bytes
                    
                    if not is_processing and latest_image_bytes:
                        is_processing = True
                        img_data = latest_image_bytes
                        
                        def process():
                            try:
                                result = detector.detect(img_data, conf=0.25)
                                return result
                            except Exception as e:
                                logger.error(f"Detection error: {e}")
                                return {"detections": []}
                        
                        asyncio.get_event_loop().run_in_executor(None, process).add_done_callback(
                            lambda f: asyncio.create_task(send_result(f.result()))
                        )
                    
                    async def send_result(result):
                        nonlocal is_processing
                        is_processing = False
                        try:
                            response = {
                                "type": "result",
                                "detections": result["detections"]
                            }
                            await manager.send_message(websocket, response)
                        except Exception as e:
                            logger.error(f"Send error: {e}")

    except WebSocketDisconnect:
        manager.disconnect(websocket)
        logger.info("Client disconnected")
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
        manager.disconnect(websocket)
