# System Functionality & Research Architecture: Sinhala Adaptive Dyslexia Platform

This document details the operation of the four independent, research-driven microservices, now specifically optimized for **Auditory Comprehension and Reading** for **Grade 1 & 2 Sri Lankan students**.

## System Overview
The system centers on the link between **Graphemes (written letters)** and **Phonemes (sounds)** in the Sinhala language. It identifies where the student's reading struggles originate: is it a visual processing issue (Reading) or a sound-mapping issue (Auditory Comprehension)?

---

## 1. Monitoring-Service: Cognitive Learning Behavior Monitoring Engine (CLBME)
**Research Focus:** Identifying the gap between auditory and visual processing speeds.

### Variables Monitored:
- **Audio-Visual Latency:** Time taken to select a letter after its sound is played.
- **Audio Replay Frequency:** How many times a student re-plays a sound before attempting an answer (indicates auditory processing lag).
- **Phonological Awareness Metrics:** Tracking errors specifically in "Hraswa" (short) vs "Deerga" (long) vowel sounds in Sinhala.
- **Reading Fixation:** Implicitly tracking stalling on complex Sinhala "Bandi Akshara" (combined letters).

### System I/O:
- **Inputs:** UI Telemetry, Audio event logs (Play/Pause/Replay), Touch response times.
- **Outputs:** **Phonological Profile** (mapping the student's listening vs. reading mastery).

---

## 2. Content-Service: Personalized Content Engine
**Research Focus:** Balancing reading and listening tasks to bridge the phonological gap.

### Functionality:
- **Cross-Modal Personalization:** If a student shows high Auditory Comprehension but poor Reading, the service generates "Scaffolded Reading" tasks where audio cues are gradually faded out.
- **Sinhala Hodiya Curriculum:** Dynamically sequences content from the national Grade 1/2 syllabus, focusing on phoneme-to-grapheme matching (e.g., matching the sound "Ka" to the letter "ක").

### System I/O:
- **Inputs:** Listening vs. Reading score ratios, historical syllable mastery.
- **Outputs:** **Multimodal Lesson Plan** (A mix of audio-first and text-first questions).

---

## 3. Intervention-Service: Guidance & Support Engine
**Research Focus:** Optimizing **Synchronized Multimodal Cues** (Audio-Visual Alignment).

### Functionality:
- **Synchronized Highlighting:** When an audio pronunciation is played, the service commands the UI to highlight the specific *Akshara* or *Pilla* being sounded out.
- **Auditory Scaffolding:** Provides "Phonetic Blending" help (e.g., sounding out "ක" + "ඇ" = "කැ") to assist in reading decoding.
- **Modality Switching:** Decides whether to provide an audio-only cue, a visual split, or a combined cue based on the error type.

### System I/O:
- **Inputs:** Real-time Reading/Listening struggle flags.
- **Outputs:** **Sync-Commands** (e.g., `{"highlight": "කො", "audio": "ko_sound.mp3"}`).

---

## 4. Visual-Service: Adaptive Visual Learning Interface (AVLI)
**Research Focus:** Optimizing the visual environment for **Reading Fluency**.

### Functionality:
- **Reading-Optimized UI:** Implements "Bionic Reading" style Sinhala highlights (bolding the start of letters) and increased line-spacing to prevent "Visual Overload."
- **Sync-Rendering:** Handles the real-time visual feedback (highlights/bubbles) requested by the Intervention-Service during auditory tasks.

### System I/O:
- **Inputs:** Sync-Commands, Personalized Typography vectors.
- **Outputs:** High-fidelity Flutter interface with synchronized audio-visual feedback.
