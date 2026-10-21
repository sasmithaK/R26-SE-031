# C2 Sinhala oral-reading pipeline

Version: `c2-pipeline-v3`

This component measures an oral-reading attempt. It is an experimental
learning-support instrument, not a diagnostic instrument.

## Processing stages

1. `quality`: WAV validation, resampling, duration, level, clipping, activity,
   spectral flatness and an estimated SNR. Failed recordings return
   `retry_required`; they do not receive a reading score.
2. `acoustic`: timing and fluency use the original signal. The ASR branch is
   normalized separately so it cannot change acoustic measurements.
3. `transcription`: Sinhala Whisper text, model identity, candidates and mean
   token likelihood when supported by the checkpoint.
4. `alignment`: NFC-normalized Sinhala word and orthographic-grapheme
   alignment, including substitutions, omissions and insertions.
5. Expected-text evidence: allowed variants and expected syllabic-event
   consistency are evaluated against the known curriculum item.
6. `fluency`: onset, response latency, active duration, pause measures,
   observed rate and repetitions. Jitter/shimmer remain exploratory and are
   excluded from the primary reading score.
7. `fusion`: combines measurement quality and available methods. It abstains
   with `uncertain` when methods disagree and with `retry_required` when the
   recording is invalid.

## Identity and storage

Each stored attempt includes student, session, event, attempt, skill,
activity, round and canonical item identifiers. `attempt_id` is idempotent per
student. Raw audio is hashed for traceability but is not persisted by this
route. Nested evidence and backward-compatible flat fields are stored in
`speech_features`.

## Skill protocol

- Skill 5 shows the written prompt before any TTS. TTS is a logged scaffold,
  and the reusable recording card captures the read-aloud attempt separately
  from the comprehension answer.
- Skill 6 uses tap-to-start/tap-to-stop recording. An uncertain STT result is
  stored but does not block the child. Only an invalid recording asks for a
  retry.

## Validation boundary

The deterministic tests cover silence/noise rejection, Sinhala alignment,
method disagreement and full evidence fusion using synthetic waveforms.
They establish engineering behavior only. Pediatric Sinhala ASR accuracy and
threshold validity require a later consented, human-transcribed pilot.
