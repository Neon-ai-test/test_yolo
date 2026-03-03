import os
import json
import yaml
import base64
import time
import threading
import hashlib
import dashscope
from dashscope.audio.qwen_tts_realtime import *

_config = None
_tts_lock = threading.Lock()

# 磁盘缓存目录
_CACHE_DIR = os.path.join(os.path.dirname(__file__), '..', 'tts_cache')


def _get_voice_cache_dir(voice: str) -> str:
    """获取指定音色的缓存目录"""
    voice_dir = os.path.join(_CACHE_DIR, voice)
    if not os.path.exists(voice_dir):
        os.makedirs(voice_dir, exist_ok=True)
    return voice_dir


def _ensure_cache_dir():
    """确保缓存目录存在"""
    if not os.path.exists(_CACHE_DIR):
        os.makedirs(_CACHE_DIR, exist_ok=True)


def load_config():
    global _config
    config_path = os.path.join(os.path.dirname(__file__), '..', 'config.yaml')
    with open(config_path, 'r', encoding='utf-8') as f:
        _config = yaml.safe_load(f)
    return _config


def get_tts_config():
    global _config
    if _config is None:
        load_config()
    return _config.get('tts', {})


def set_tts_enabled(enabled: bool):
    global _config
    if _config is None:
        load_config()
    _config['tts']['enabled'] = enabled


def get_tts_voice():
    """获取当前 TTS 音色"""
    config = get_tts_config()
    return config.get('voice', 'Cherry')


def set_tts_voice(voice: str):
    """设置 TTS 音色"""
    global _config
    if _config is None:
        load_config()
    _config['tts']['voice'] = voice


def _get_cache_key(text: str) -> str:
    """Generate cache key for text."""
    return hashlib.md5(text.encode()).hexdigest()


def _get_audio_file_path(voice: str, text: str) -> str:
    """获取音频文件的完整路径"""
    key = _get_cache_key(text)
    voice_dir = _get_voice_cache_dir(voice)
    return os.path.join(voice_dir, f"{key}.pcm")


def _get_cached_audio(text: str) -> bytes:
    """从磁盘缓存获取音频"""
    voice = get_tts_voice()
    file_path = _get_audio_file_path(voice, text)
    
    if os.path.exists(file_path):
        with open(file_path, 'rb') as f:
            return f.read()
    return None


def _set_cached_audio(text: str, audio_data: bytes):
    """将音频写入磁盘缓存"""
    voice = get_tts_voice()
    file_path = _get_audio_file_path(voice, text)
    
    _ensure_cache_dir()
    with open(file_path, 'wb') as f:
        f.write(audio_data)
    
    print(f'[TTS] Cached audio to {file_path}')


def get_cache_size() -> dict:
    """获取缓存大小信息"""
    _ensure_cache_dir()
    
    total_size = 0
    voice_sizes = {}
    
    try:
        for voice_dir_name in os.listdir(_CACHE_DIR):
            voice_dir = os.path.join(_CACHE_DIR, voice_dir_name)
            if os.path.isdir(voice_dir):
                voice_size = 0
                for file_name in os.listdir(voice_dir):
                    file_path = os.path.join(voice_dir, file_name)
                    if os.path.isfile(file_path):
                        voice_size += os.path.getsize(file_path)
                voice_sizes[voice_dir_name] = voice_size
                total_size += voice_size
    except Exception as e:
        print(f'[TTS] Error getting cache size: {e}')
    
    # 转换为人类可读格式
    def format_size(bytes_size):
        if bytes_size < 1024:
            return f"{bytes_size} B"
        elif bytes_size < 1024 * 1024:
            return f"{bytes_size / 1024:.1f} KB"
        else:
            return f"{bytes_size / (1024 * 1024):.1f} MB"
    
    return {
        "total_bytes": total_size,
        "total_readable": format_size(total_size),
        "by_voice": {voice: format_size(size) for voice, size in voice_sizes.items()}
    }


def clear_cache(voice: str = None):
    """清除缓存"""
    _ensure_cache_dir()
    
    if voice:
        # 清除指定音色
        voice_dir = _get_voice_cache_dir(voice)
        if os.path.exists(voice_dir):
            for file_name in os.listdir(voice_dir):
                file_path = os.path.join(voice_dir, file_name)
                if os.path.isfile(file_path):
                    os.remove(file_path)
            print(f'[TTS] Cleared cache for voice: {voice}')
    else:
        # 清除所有缓存
        for voice_dir_name in os.listdir(_CACHE_DIR):
            voice_dir = os.path.join(_CACHE_DIR, voice_dir_name)
            if os.path.isdir(voice_dir):
                for file_name in os.listdir(voice_dir):
                    file_path = os.path.join(voice_dir, file_name)
                    if os.path.isfile(file_path):
                        os.remove(file_path)
        print('[TTS] Cleared all cache')


class TTSCallback(QwenTtsRealtimeCallback):
    def __init__(self):
        self.audio_chunks = []
        self.complete_event = threading.Event()
        self.error = None

    def on_open(self) -> None:
        pass

    def on_close(self, close_status_code, close_msg) -> None:
        pass

    def on_event(self, response) -> None:
        try:
            if isinstance(response, str):
                response = json.loads(response)
            type = response.get('type', '')
            if 'response.audio.delta' == type:
                recv_audio_b64 = response.get('delta', '')
                if recv_audio_b64:
                    self.audio_chunks.append(recv_audio_b64)
            if 'response.done' == type or 'session.finished' == type:
                self.complete_event.set()
        except Exception as e:
            self.error = str(e)
            self.complete_event.set()

    def wait_for_finished(self, timeout=10):
        self.complete_event.wait(timeout=timeout)

    def get_audio_data(self):
        return b''.join(base64.b64decode(chunk) for chunk in self.audio_chunks)


def synthesize_speech(text: str) -> bytes:
    config = get_tts_config()
    if not config.get('enabled', False):
        print('[TTS] Disabled')
        return b''
    
    api_key = config.get('api_key', '')
    if not api_key or api_key == 'your-dashscope-api-key':
        print('[TTS] API key not configured')
        return b''
    
    # 先检查磁盘缓存
    cached_audio = _get_cached_audio(text)
    if cached_audio:
        print(f'[TTS] Cache hit for: {text}')
        return cached_audio
    
    dashscope.api_key = api_key
    
    callback = TTSCallback()
    
    try:
        print(f'[TTS] Synthesizing: {text}')
        
        tts = QwenTtsRealtime(
            model='qwen3-tts-flash-realtime',
            callback=callback,
        )
        
        tts.connect()
        tts.update_session(
            voice=config.get('voice', 'Cherry'),
            response_format=AudioFormat.PCM_24000HZ_MONO_16BIT,
            mode='server_commit'
        )
        
        tts.append_text(text)
        tts.finish()
        
        callback.wait_for_finished(timeout=10)
        
        audio_data = callback.get_audio_data()
        print(f'[TTS] Generated audio size: {len(audio_data)} bytes')
        
        tts.close()
        
        # 缓存到磁盘
        if audio_data:
            _set_cached_audio(text, audio_data)
        
        return audio_data
        
    except Exception as e:
        print(f'[TTS] Error: {e}')
        import traceback
        traceback.print_exc()
        return b''
