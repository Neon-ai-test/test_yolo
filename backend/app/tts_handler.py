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

# Audio cache to avoid recreating same audio
_audio_cache = {}
_audio_cache_lock = threading.Lock()
_CACHE_TTL = 300  # 5 minutes cache TTL


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


def _get_cache_key(text: str) -> str:
    """Generate cache key for text."""
    return hashlib.md5(text.encode()).hexdigest()


def _get_cached_audio(text: str) -> bytes:
    """Get cached audio if available and not expired."""
    key = _get_cache_key(text)
    with _audio_cache_lock:
        if key in _audio_cache:
            cached_time, audio_data = _audio_cache[key]
            if time.time() - cached_time < _CACHE_TTL:
                return audio_data
            else:
                del _audio_cache[key]
    return None


def _set_cached_audio(text: str, audio_data: bytes):
    """Cache audio with TTL."""
    key = _get_cache_key(text)
    with _audio_cache_lock:
        _audio_cache[key] = (time.time(), audio_data)


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
    
    # Check cache first (Fix #6: avoid recreating same audio)
    cached_audio = _get_cached_audio(text)
    if cached_audio:
        print(f'[TTS] Cache hit for: {text}')
        return cached_audio
    
    dashscope.api_key = api_key
    
    callback = TTSCallback()
    
    try:
        print(f'[TTS] Synthesizing: {text}')
        
        tts = QwenTtsRealtime(
            model='qwen3-tts-instruct-flash-realtime',
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
        
        # Cache the audio (Fix #6: cache for reuse)
        if audio_data:
            _set_cached_audio(text, audio_data)
        
        return audio_data
        
    except Exception as e:
        print(f'[TTS] Error: {e}')
        import traceback
        traceback.print_exc()
        return b''
