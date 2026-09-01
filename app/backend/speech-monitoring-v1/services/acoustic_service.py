import librosa
try:
    import parselmouth
    HAS_PARSELMOUTH = True
except ImportError:
    HAS_PARSELMOUTH = False
import numpy as np
import io
import soundfile as sf
import math

class AcousticAnalysisService:
    def __init__(self):
        # Removed WebRTC VAD due to C compiler dependencies on Windows
        pass

    def estimate_sinhala_syllables(self, text: str) -> int:
        """
        Estimates the number of syllables in a Sinhala word/phrase.
        Sinhala is an abugida, so each consonant is a syllable unless modified by a hal-kirima (්) \u0dca
        which removes the inherent vowel. 
        """
        if not text:
            return 1
            
        # Remove spaces and punctuation
        cleaned = ''.join(c for c in text if c.isalnum() or c == '\u0dca')
        
        # Count all characters
        total_chars = len(cleaned)
        
        # In Unicode Sinhala, vowels marks are separate characters, 
        # but they combine with the consonant. 
        # A basic heuristic:
        # 1. Count total characters.
        # 2. Subtract the number of vowel marks (since they don't add a new syllable, they modify existing one).
        # Vowel marks block: \u0dcf to \u0ddf
        # 3. Hal kirima (\u0dca) removes the inherent vowel, so it merges with the previous consonant 
        #    creating a consonant cluster, effectively reducing syllable count by 1.
        
        vowel_marks = sum(1 for c in cleaned if '\u0dcf' <= c <= '\u0ddf')
        hal_kirima = sum(1 for c in cleaned if c == '\u0dca')
        
        # The true syllable count is roughly the number of base consonants/vowels 
        # minus the ones that are killed by hal_kirima.
        base_chars = total_chars - vowel_marks - hal_kirima
        
        estimated = base_chars - hal_kirima
        return max(1, estimated)

    def find_voice_onset(self, y: np.ndarray, sr: int, top_db: int = 30) -> int:
        """
        Finds the first frame (in ms) where speech is detected using librosa.
        Returns the onset in milliseconds relative to the start of the audio.
        """
        # Split returns intervals [start_sample, end_sample]
        intervals = librosa.effects.split(y, top_db=top_db)
        if len(intervals) > 0:
            first_sample = intervals[0][0]
            # Convert sample index to milliseconds
            return int((first_sample / sr) * 1000)
        return 0 # Default to 0 if no speech found

    def count_syllable_peaks(self, y: np.ndarray, sr: int) -> int:
        """
        Uses librosa to count energy peaks (vowels/syllables) in the audio.
        """
        # Calculate the onset strength envelope
        onset_env = librosa.onset.onset_strength(y=y, sr=sr)
        
        # Detect peaks in the onset strength envelope
        peaks = librosa.onset.onset_detect(onset_envelope=onset_env, sr=sr, wait=30, pre_max=20, post_max=20, pre_avg=100, post_avg=100, delta=0.2)
        
        return len(peaks)

    def extract_prosody(self, audio_file_path: str):
        """
        Uses Parselmouth (Praat) to extract jitter and shimmer.
        """
        if not HAS_PARSELMOUTH:
            print("Parselmouth is not installed. Skipping prosody extraction.")
            return None, None
            
        try:
            sound = parselmouth.Sound(audio_file_path)
            pitch = sound.to_pitch()
            pulses = parselmouth.praat.call([sound, pitch], "To PointProcess (cc)")
            
            jitter = parselmouth.praat.call(pulses, "Get jitter (local)", 0, 0, 0.0001, 0.02, 1.3)
            shimmer = parselmouth.praat.call([sound, pulses], "Get shimmer (local)", 0, 0, 0.0001, 0.02, 1.3, 1.6)
            
            # Handle NaN values
            if math.isnan(jitter): jitter = None
            if math.isnan(shimmer): shimmer = None
            
            return jitter, shimmer
        except Exception as e:
            print(f"Parselmouth error: {e}")
            return None, None

    def calculate_intra_word_silence(self, y: np.ndarray, sr: int, top_db: int = 20) -> float:
        """
        Calculates the percentage of silence within the speech segment.
        """
        # Get non-silent intervals
        intervals = librosa.effects.split(y, top_db=top_db)
        
        if len(intervals) == 0:
            return 1.0
            
        start_idx = intervals[0][0]
        end_idx = intervals[-1][1]
        
        total_speech_duration = end_idx - start_idx
        if total_speech_duration <= 0:
            return 1.0
            
        active_duration = sum([end - start for start, end in intervals])
        silence_duration = total_speech_duration - active_duration
        
        return float(silence_duration) / float(total_speech_duration)

    def analyze_audio(self, wav_bytes: bytes, expected_text: str, expected_syllables: int, t_stimulus: int, t_record_start: int):
        """
        Main function to analyze the acoustic features.
        """
        # Save bytes to a temporary file
        import tempfile
        import os
        
        with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as temp_wav:
            temp_wav.write(wav_bytes)
            temp_wav_path = temp_wav.name
            
        try:
            # 1. Load audio with librosa (flutter_sound creates a perfect WAV file at 16000Hz)
            y, sr = librosa.load(temp_wav_path, sr=16000)

            # 2. VAD & Latency
            t_voice_onset = self.find_voice_onset(y, sr)
            
            # Calculate True Latency
            # t_record_start is the unix timestamp when mic was pressed
            # t_stimulus is the unix timestamp when the image was shown
            # Note: If the user presses record *before* speaking, the latency is from stimulus -> speech.
            if t_stimulus > 0 and t_record_start >= t_stimulus:
                latency_ms = (t_record_start - t_stimulus) + t_voice_onset
            else:
                latency_ms = t_voice_onset # Fallback if timestamps are invalid
                
            # 3. Syllable Peak Counting
            detected_peaks = self.count_syllable_peaks(y, sr)
            
            # If expected_syllables not provided, estimate it
            if expected_syllables <= 0:
                expected_syllables = self.estimate_sinhala_syllables(expected_text)
                
            peak_delta = abs(detected_peaks - expected_syllables)
            
            # 4. Clinical Prosody (Jitter/Shimmer)
            # Apply pre-emphasis filter to stabilize Praat's F0 tracking on noisy/pediatric voices
            filtered_y = librosa.effects.preemphasis(y)
            sf.write(temp_wav_path, filtered_y, sr, subtype='PCM_16')
            jitter, shimmer = self.extract_prosody(temp_wav_path)
            
            # 5. Intra-word Silence and Pauses
            intervals = librosa.effects.split(y, top_db=20)
            
            silence_ratio = 1.0
            speech_duration_ms = 0.0
            pause_count = 0
            mean_pause_duration_ms = 0.0
            pause_ratio = 1.0
            
            if len(intervals) > 0:
                start_idx = intervals[0][0]
                end_idx = intervals[-1][1]
                total_speech_duration_samples = end_idx - start_idx
                
                if total_speech_duration_samples > 0:
                    speech_duration_ms = float(total_speech_duration_samples) / sr * 1000.0
                    active_duration = sum([end - start for start, end in intervals])
                    silence_duration = total_speech_duration_samples - active_duration
                    silence_ratio = float(silence_duration) / float(total_speech_duration_samples)
                    
                    # Calculate pauses between active intervals
                    pauses = []
                    for i in range(1, len(intervals)):
                        pause_samples = intervals[i][0] - intervals[i-1][1]
                        pause_ms = (float(pause_samples) / sr) * 1000.0
                        if 200 <= pause_ms <= 3000:
                            pauses.append(pause_ms)
                    
                    pause_count = len(pauses)
                    mean_pause_duration_ms = sum(pauses) / len(pauses) if pauses else 0.0
                    
                    total_pause_ms = sum(pauses)
                    pause_ratio = total_pause_ms / speech_duration_ms if speech_duration_ms > 0 else 0.0

            # STT fallback (just for logging/comparison)
            try:
                from services.stt_service import get_stt_engine
                transcription = get_stt_engine().transcribe_audio_bytes(wav_bytes)
            except:
                transcription = ""

            return {
                "transcription": transcription, # Optional — Whisper (adult model, accuracy limited on children)
                "Acoustic_Latency_ms": latency_ms,
                "Voice_Onset_ms": t_voice_onset,
                "Detected_Peaks": detected_peaks,
                "Expected_Syllables": expected_syllables,
                "Peak_Count_Delta": peak_delta,
                "Intra_Word_Silence_Ratio": round(silence_ratio, 4),
                "Speech_Duration_ms": round(speech_duration_ms, 2),
                "Pause_Count": pause_count,
                "Mean_Pause_Duration_ms": round(mean_pause_duration_ms, 2),
                "Pause_Ratio": round(pause_ratio, 4),
                "Local_Jitter": round(jitter, 6) if jitter is not None else None,
                "Local_Shimmer": round(shimmer, 6) if shimmer is not None else None,
                # Diagnostic quality flag: helps therapist interpret results
                # "poor_prosody_extraction" = Praat failed on noisy audio (jitter/shimmer default to 0.0)
                # "mostly_silence" = Child likely did not speak clearly
                "recording_quality": (
                    "mostly_silence" if silence_ratio > 0.90
                    else "poor_prosody_extraction" if (jitter is None or shimmer is None)
                    else "good"
                ),
            }
            
        finally:
            if os.path.exists(temp_wav_path):
                os.remove(temp_wav_path)
