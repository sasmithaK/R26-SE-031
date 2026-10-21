# Model card — C2 reading aloud (speech measures)

**Status:** research prototype. C2 makes no classification. It measures reading-aloud recordings for professional review.
**Version:** pipeline `c2-pipeline-v3` · settings `c2_settings.json` · 21 Oct 2026

## Purpose
Turn a child's reading-aloud recording (Skills 5–6) into measures a professional can review: letters and words read as expected, time to start speaking, pauses and reading rate. It also judges whether the recording was clear enough to measure at all.

## Pipeline (per recording)
1. **Quality gate.** Checks duration, level, signal-to-noise, clipping and active speech. A recording that fails gets `retry_required`, and **no reading accuracy is stored** (previously stored as 0%).
2. **Sinhala speech recognition.** Whisper fine-tuned for Sinhala (`AqeelShafy7/Whisper-Sinhala_Audio_to_Text`), bundled in the Azure image.
3. **Alignment.** Word-level and letter-level (grapheme) edit alignment against the expected sentence, giving substitutions, omissions and insertions.
4. **Acoustic measures:**
   - voice onset after pressing record
   - pauses of 0.2–3 s
   - silence within words
   - spoken beats vs expected syllables
   - jitter and shimmer (exploratory)
5. **Fusion.** Reading score = 70% letters + 20% words + 10% beat consistency. Confidence comes from recording quality and agreement between methods; `uncertain` records the reasons.

## Changes on 21 Oct 2026
- **Syllable counting:** expected syllables are now counted from the Sinhala text. A consonant with hal kirima carries no vowel, and conjuncts count once. The old count subtracted hal kirima twice.
- **Beat detector:** the window was `wait = 30` frames, which allowed at most about 1 beat per second, while children read 2–4 syllables per second. It is now configurable (`syllable_peaks`) and starts at 4 frames. **Tune it on labelled recordings.**
- **Bad uploads:** unreadable audio returns 422, not 500.
- **App-side fixes:**
  - the story page and stimulus time are fixed when recording starts
  - no swiping while recording
  - the microphone stops on exit
  - attempt IDs are unique, so a re-recording no longer overwrites an earlier one
  - the student ID lookup also checks `student_id`
- **Dashboard additions:** letters read differently, re-recordings per sentence, and a words-per-minute trend (clear recordings only).

## Validity evidence still needed (real-world testing)
- **Speech recognition word error rate on Grade 1 Sinhala reading:** 20–30 sentences read by several speakers, transcribed by hand.
- **Beat detector settings:** compare expected syllables with detected beats on those recordings.
- **Quality gate thresholds:** share of clear recordings at home vs in a quiet room.

## Limitations
- Speech recognition errors look the same as reading errors in the letter and word measures. Check the transcript before acting.
- Jitter and shimmer are unreliable on short child recordings. They are shown only as exploratory measures.
- Every threshold is an engineering setting until a consented pilot validates it.

## Files
`speech-monitoring-v1/services/*` · `routers/stt.py` · `c2_settings.json` · `tests/test_c2_fixes.py`
