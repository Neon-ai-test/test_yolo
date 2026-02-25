import cv2
import numpy as np
from ultralytics import YOLO
import torch
import time
import base64


COCO_CLASSES_CN = {
    0: "人", 1: "自行车", 2: "汽车", 3: "摩托车", 4: "飞机",
    5: "巴士", 6: "火车", 7: "卡车", 8: "船", 9: "红绿灯",
    10: "消防栓", 11: "停车标志", 12: "停车计费表", 13: "长凳", 14: "鸟",
    15: "猫", 16: "狗", 17: "马", 18: "羊", 19: "牛",
    20: "大象", 21: "熊", 22: "斑马", 23: "长颈鹿", 24: "背包",
    25: "雨伞", 26: "手提包", 27: "领带", 28: "行李箱", 29: "飞盘",
    30: "滑雪板", 31: "单板滑雪", 32: "运动球", 33: "风筝", 34: "棒球棍",
    35: "棒球手套", 36: "滑板", 37: "冲浪板", 38: "网球拍", 39: "瓶子",
    40: "酒杯", 41: "杯子", 42: "叉子", 43: "刀", 44: "勺子",
    45: "碗", 46: "香蕉", 47: "苹果", 48: "三明治", 49: "橙子",
    50: "西兰花", 51: "胡萝卜", 52: "热狗", 53: "披萨", 54: "甜甜圈",
    55: "蛋糕", 56: "椅子", 57: "沙发", 58: "盆栽", 59: "床",
    60: "餐桌", 61: "马桶", 62: "电视", 63: "笔记本电脑", 64: "鼠标",
    65: "遥控器", 66: "键盘", 67: "手机", 68: "微波炉", 69: "烤箱",
    70: "烤面包机", 71: "水槽", 72: "冰箱", 73: "书", 74: "时钟",
    75: "花瓶", 76: "剪刀", 77: "泰迪熊", 78: "吹风机", 79: "牙刷"
}


class YOLODetector:
    def __init__(self, model_path: str = "yolov8n.pt"):
        self.model = YOLO(model_path)
        self.class_names = self.model.names
        self.avg_process_time = 0
        self.benchmark_done = False
        
        self._detect_device()
        
    def _detect_device(self):
        if torch.cuda.is_available():
            self.device = 'cuda'
        else:
            self.device = 'cpu'
        self.model.to(self.device)
        
    def detect(self, image_data: bytes, conf: float = 0.25) -> dict:
        nparr = np.frombuffer(image_data, np.uint8)
        image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        results = self.model(image, conf=conf, verbose=False, device=self.device, imgsz=320)

        detections = []
        for result in results:
            boxes = result.boxes
            for box in boxes:
                x1, y1, x2, y2 = box.xyxy[0].cpu().numpy()
                conf_score = float(box.conf[0])
                class_id = int(box.cls[0])
                class_name = self.class_names[class_id]
                class_name_cn = COCO_CLASSES_CN.get(class_id, class_name)

                detections.append({
                    "bbox": [float(x1), float(y1), float(x2), float(y2)],
                    "confidence": conf_score,
                    "class_id": class_id,
                    "class_name": class_name,
                    "class_name_cn": class_name_cn
                })

        return {"detections": detections}

    def get_info(self) -> dict:
        return {
            "device": self.device,
            "model": "yolov8n"
        }

    def benchmark(self, test_data: bytes = None, iterations: int = 5) -> dict:
        if test_data is None:
            test_data = base64.b64decode(
                "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
            )
        
        times = []
        for _ in range(iterations):
            start = time.time()
            self.detect(test_data)
            times.append(time.time() - start)
        
        avg_time = sum(times) / len(times)
        self.avg_process_time = avg_time
        self.benchmark_done = True
        
        recommended_fps = int(1.0 / avg_time * 0.8)
        
        return {
            "device": self.device,
            "avg_process_time_ms": round(avg_time * 1000, 2),
            "recommended_fps": recommended_fps,
            "iterations": iterations
        }

    def get_classes(self) -> list:
        return [{"id": k, "name": v, "name_cn": COCO_CLASSES_CN.get(k, v)} for k, v in self.class_names.items()]
