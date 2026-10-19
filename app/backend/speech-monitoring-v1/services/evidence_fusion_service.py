"""Stage 7 of C2: conservative, quality-aware evidence fusion."""

from __future__ import annotations

from typing import Any, Dict


FUSION_VERSION = "c2-evidence-fusion-v1"


def _number(value: Any) -> float | None:
    if isinstance(value, (int, float)):
        return float(value)
    return None


class EvidenceFusionService:
    def fuse(
        self,
        quality: Dict[str, Any],
        transcription: Dict[str, Any],
        alignment: Dict[str, Any],
        acoustic: Dict[str, Any],
    ) -> Dict[str, Any]:
        grapheme_accuracy = _number((alignment.get("grapheme") or {}).get("accuracy"))
        word_accuracy = _number((alignment.get("word") or {}).get("accuracy"))
        asr_confidence = _number(transcription.get("confidence"))
        quality_score = _number(quality.get("quality_score")) or 0.0
        peak_delta = _number(acoustic.get("Peak_Count_Delta"))
        expected_units = _number(acoustic.get("Expected_Syllables"))
        syllable_consistency = None
        if peak_delta is not None and expected_units and expected_units > 0:
            syllable_consistency = max(0.0, 1.0 - peak_delta / expected_units)

        available_methods = []
        if transcription.get("text"):
            available_methods.append("stt")
        if grapheme_accuracy is not None:
            available_methods.append("expected_text_alignment")
        if acoustic.get("Speech_Duration_ms") is not None:
            available_methods.append("acoustic_fluency")
        available_methods.append("recording_quality")

        disagreement_reasons = []
        if grapheme_accuracy is not None and syllable_consistency is not None:
            if abs(grapheme_accuracy - syllable_consistency) > 0.45:
                disagreement_reasons.append("text_acoustic_disagreement")
        if asr_confidence is not None and grapheme_accuracy is not None:
            if asr_confidence < 0.35 and grapheme_accuracy > 0.80:
                disagreement_reasons.append("low_asr_confidence_despite_close_text")

        if quality.get("retry_required"):
            status = "retry_required"
        elif not transcription.get("text"):
            status = "uncertain"
            disagreement_reasons.append("missing_transcription")
        elif disagreement_reasons:
            status = "uncertain"
        else:
            status = "valid"

        method_coverage = min(1.0, len(available_methods) / 4.0)
        # Do not invent a "neutral" ASR confidence when Whisper cannot supply
        # one. Confidence is calculated only from methods that actually
        # produced a measurement.
        confidence_terms = [(0.45, 1.0), (0.25, method_coverage)]
        if asr_confidence is not None:
            confidence_terms.append((0.30, asr_confidence))
        term_weight = sum(weight for weight, _ in confidence_terms)
        evidence_confidence = sum(weight * value for weight, value in confidence_terms) / term_weight
        combined_confidence = quality_score * evidence_confidence
        if disagreement_reasons:
            combined_confidence *= 0.70
        if status == "retry_required":
            combined_confidence = min(combined_confidence, 0.25)

        reading_score = None
        if status != "retry_required" and grapheme_accuracy is not None:
            components = [(grapheme_accuracy, 0.70)]
            if word_accuracy is not None:
                components.append((word_accuracy, 0.20))
            if syllable_consistency is not None:
                components.append((syllable_consistency, 0.10))
            total_weight = sum(weight for _, weight in components)
            reading_score = sum(value * weight for value, weight in components) / total_weight

        return {
            "measurement_status": status,
            "combined_confidence": round(max(0.0, min(1.0, combined_confidence)), 4),
            "reading_performance_score": (
                round(max(0.0, min(1.0, reading_score)), 4)
                if reading_score is not None
                else None
            ),
            "available_methods": available_methods,
            "asr_confidence_available": asr_confidence is not None,
            "method_disagreement": bool(disagreement_reasons),
            "disagreement_reasons": disagreement_reasons,
            "decision_policy": "abstain_on_poor_quality_or_method_disagreement",
            "version": FUSION_VERSION,
            "interpretation": "Experimental reading-performance evidence; not a diagnosis.",
        }
