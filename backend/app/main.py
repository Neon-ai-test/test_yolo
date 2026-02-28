from fastapi import FastAPI, WebSocket, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import logging
import base64
from pydantic import BaseModel

from .detector import YOLODetector
from .websocket_handler import handle_websocket
from . import tts_handler

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

detector = None


class ConfigUpdate(BaseModel):
    tts_enabled: bool = None
    imgsz: int = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global detector
    logger.info("Loading YOLOv8n model...")
    try:
        detector = YOLODetector("yolov8n.pt")
        logger.info("Model loaded successfully")
    except Exception as e:
        logger.error(f"Failed to load model: {e}")
        detector = YOLODetector()
    yield


app = FastAPI(title="YOLO Vision API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
async def root():
    return {"message": "YOLO Vision API", "status": "running"}


@app.get("/api/classes")
async def get_classes():
    return {"classes": detector.get_classes()}


@app.get("/api/info")
async def get_info():
    return detector.get_info()


@app.get("/api/benchmark")
async def get_benchmark():
    result = detector.benchmark(iterations=5)
    return result


@app.get("/api/config")
async def get_config():
    tts_config = tts_handler.get_tts_config()
    return {
        "tts_enabled": tts_config.get('enabled', False),
        "imgsz": detector.imgsz,
        "imgsz_options": [100, 128, 192, 256, 320, 480, 640]
    }


@app.post("/api/config")
async def update_config(config: ConfigUpdate):
    if config.tts_enabled is not None:
        tts_handler.set_tts_enabled(config.tts_enabled)
    if config.imgsz is not None:
        detector.set_imgsz(config.imgsz)
    return {"success": True}


@app.websocket("/ws/detect")
async def websocket_endpoint(websocket: WebSocket):
    await handle_websocket(websocket, detector)


@app.post("/api/detect")
async def detect_image(file: UploadFile = File(...)):
    contents = await file.read()
    result = detector.detect(contents)
    return {"detections": result["detections"]}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
