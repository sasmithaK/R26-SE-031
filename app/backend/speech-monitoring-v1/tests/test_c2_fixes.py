"""C2 fixes: syllable count from Sinhala text, unreadable audio is a client error."""
import pytest

from services.acoustic_service import AcousticAnalysisService
from services.audio_quality_service import AudioQualityService, UnreadableAudioError


@pytest.mark.parametrize("text,expected", [
    ("අම්මා", 2),          # am-maa: dead consonant closes the syllable
    ("ක්‍රීඩා", 2),         # rakaransaya cluster + one vowel sign
    ("පොත", 2),
    ("මම පාසල් යමි", 6),
    ("ශ්‍රී ලංකාව", 4),     # anusvara adds no syllable
])
def test_sinhala_syllable_count(text, expected):
    assert AcousticAnalysisService().estimate_sinhala_syllables(text) == expected


def test_unreadable_audio_raises_client_error():
    with pytest.raises(UnreadableAudioError):
        AudioQualityService().decode(b"not a wav file")
