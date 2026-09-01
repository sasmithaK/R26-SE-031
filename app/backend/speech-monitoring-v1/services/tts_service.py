import hashlib
import struct
import os
import base64
import wave
from database import get_fs
from google import genai
from google.genai import types

def parse_audio_mime_type(mime_type: str) -> dict:
    bits_per_sample = 16
    rate = 24000

    parts = mime_type.split(";")
    for param in parts:
        param = param.strip()
        if param.lower().startswith("rate="):
            try:
                rate_str = param.split("=", 1)[1]
                rate = int(rate_str)
            except (ValueError, IndexError):
                pass
        elif param.startswith("audio/L"):
            try:
                bits_per_sample = int(param.split("L", 1)[1])
            except (ValueError, IndexError):
                pass

    return {"bits_per_sample": bits_per_sample, "rate": rate}

def convert_to_wav(audio_data: bytes, mime_type: str) -> bytes:
    parameters = parse_audio_mime_type(mime_type)
    bits_per_sample = parameters["bits_per_sample"]
    sample_rate = parameters["rate"]
    num_channels = 1
    data_size = len(audio_data)
    bytes_per_sample = bits_per_sample // 8
    block_align = num_channels * bytes_per_sample
    byte_rate = sample_rate * block_align
    chunk_size = 36 + data_size

    header = struct.pack(
        "<4sI4s4sIHHIIHH4sI",
        b"RIFF",          
        chunk_size,       
        b"WAVE",          
        b"fmt ",          
        16,               
        1,                
        num_channels,     
        sample_rate,      
        byte_rate,        
        block_align,      
        bits_per_sample,  
        b"data",          
        data_size         
    )
    return header + audio_data


class TTSService:
    @staticmethod
    def text_to_speech(text: str, folder: str = "general") -> str:
        """Generate a new speech file for given text and save locally. Returns text_hash."""
        text_hash = hashlib.md5(text.encode()).hexdigest()
        folder_dir = os.path.join(os.path.dirname(__file__), "..", "local_audio", folder)
        os.makedirs(folder_dir, exist_ok=True)
        local_path = os.path.join(folder_dir, f"{text_hash}.wav")
        relative_path = f"{folder}/{text_hash}.wav"
        
        if os.path.exists(local_path):
            return relative_path
            
        try:
            api_key = os.environ.get("GEMINI_API_KEY")
            if not api_key:
                raise RuntimeError("GEMINI_API_KEY environment variable not set")
            
            prompt_text = f"## Scene:\nA friendly, bright classroom setting, learning a new language together.\n\n## Sample Context:\nClear pronunciation, very encouraging tone, patient pacing, speaking naturally and fluently in Sinhala to a young child.\n\n## Transcript:\nSpeaker 1: {text}"
            
            payload = {
              "contents": [{"role": "user", "parts": [{"text": prompt_text}]}],
              "generationConfig": {
                "responseModalities": ["audio"],
                "speechConfig": {"voice_config": {"prebuilt_voice_config": {"voice_name": "Zephyr"}}}
              }
            }
            headers = {'Content-Type': 'application/json', 'x-goog-api-key': api_key}
            
            import requests
            import time
            
            # Use ONLY 3.1 (the original voice the user prefers)
            url = "https://generativelanguage.googleapis.com/v1alpha/models/gemini-3.1-flash-tts-preview:generateContent"
            print(f"Calling Gemini 3.1 REST API with text: {repr(prompt_text)}")
            start_time = time.time()
            response = requests.post(url, json=payload, headers=headers, timeout=15)
            print(f"Gemini 3.1 API call complete in {time.time() - start_time} seconds with status: {response.status_code}")
                
            if response.status_code != 200:
                raise RuntimeError(f"Gemini API returned error {response.status_code}: {response.text}")
                
            data = response.json()
            if 'candidates' not in data or not data['candidates']:
                raise RuntimeError(f"No candidates returned from Gemini API: {data}")
                
            inline_data = data['candidates'][0]['content']['parts'][0].get('inlineData', {})
            if not inline_data or 'data' not in inline_data:
                raise RuntimeError("No audio data returned in response parts")
                
            import base64
            import wave
            audio_bytes = base64.b64decode(inline_data['data'])
            
            with wave.open(local_path, "wb") as wav_file:
                wav_file.setnchannels(1)
                wav_file.setsampwidth(2)
                wav_file.setframerate(24000)
                wav_file.writeframes(audio_bytes)
                
            print(f"Successfully saved locally: {local_path}")
            return relative_path

        except Exception as e:
            raise RuntimeError(f"Text-to-speech generation failed: {e}")

    @staticmethod
    async def get_existing_speech(text_hash: str, folder: str = "general") -> bool:
        local_path = os.path.join(os.path.dirname(__file__), "..", "local_audio", folder, f"{text_hash}.wav")
        return os.path.exists(local_path)
