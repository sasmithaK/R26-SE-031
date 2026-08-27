import hashlib
import io
from gtts import gTTS
from database import get_fs

class TTSService:
    @staticmethod
    async def text_to_speech(text: str) -> str:
        """Generate a new speech file for given text and upload to GridFS. Returns text_hash."""
        text_hash = hashlib.md5(text.encode()).hexdigest()
        
        # Check if already exists in GridFS
        existing = await TTSService.get_existing_speech(text_hash)
        if existing:
            return text_hash
            
        try:
            # Generate TTS in memory
            tts = gTTS(text=text, lang="si")
            fp = io.BytesIO()
            tts.write_to_fp(fp)
            fp.seek(0)
            
            # Upload to GridFS
            fs = get_fs()
            await fs.upload_from_stream(
                filename=text_hash,
                source=fp.read(),
                metadata={"contentType": "audio/mpeg", "text": text}
            )
            return text_hash
        except Exception as e:
            raise RuntimeError(f"Text-to-speech generation failed: {e}")

    @staticmethod
    async def get_existing_speech(text_hash: str) -> bool:
        """Check if a speech file for the given hash already exists in GridFS."""
        fs = get_fs()
        cursor = fs.find({"filename": text_hash})
        docs = await cursor.to_list(length=1)
        return len(docs) > 0
