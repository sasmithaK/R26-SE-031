# System Functionality & Research Architecture: Sinhala Adaptive Dyslexia Platform

This document details the operation of the four independent, research-driven microservices, designed for **Auditory Comprehension and Reading** for **Grade 1 & 2 Sri Lankan students**.

## System Overview
The system forms a closed-loop Adaptive Learning Architecture. It tracks physical interactions to understand cognitive struggles, dynamically sequences Sinhala content, triggers auditory interventions, and adapts the user interface in real-time.

---

## 0. Gamified Profiling (Onboarding Questionnaire)
Before any ML assessment begins, the system captures a baseline using a child-friendly interface.
- **Functionality:** Instead of standard text forms, Grade 1 students are asked highly visual questions (e.g., "Which balloon is easiest to read?", "Which room colors do you like?"). 
- **Purpose:** Instantly populates the initial User Profile for both the Content and Visual services, establishing preferences without waiting for ML models to "learn" them.

---

## 1. Monitoring-Service: Cognitive Learning Behavior Monitoring Engine
**Research Focus:** Tracking sensory interactions to map cognitive load and frustration.

### Variables Monitored:
- **Touch & Typing:** Captures `time_to_first_touch`, `total_time_on_screen`, and `erratic_clicks` (indicating frustration).
- **Touch-to-Read (Alternative to Gaze Tracking):** A "karaoke style" or "Touch-to-Reveal" mechanism. The child touches Sinhala syllables to hear or light them up. This provides exact tracking of *where* they are looking and *when* they hesitate, circumventing the need for inaccurate webcam eye-tracking.
- **Phonological Mistakes:** Logs exact mapping errors (e.g., confusing "Hraswa" vs "Deerga").

### System I/O:
- **Inputs:** Touch coordinates, Latency, Audio Replay triggers.
- **Outputs:** **Cognitive & Frustration Baseline** for the intervention models.

---

## 2. Content-Service: Personalized Content Engine
**Research Focus:** Dynamic lesson generation based on ML predicted learning paths.

### Functionality:
- **Dynamic Sequencing:** Moves away from a rigid syllabus. If the Intervention Service predicts a student learns better auditorily, it deals "Audio-First" challenges. If they improve, it re-introduces "Visual-First" challenges.
- **Personalized Hodiya Curriculum:** Generates scaffolded reading tasks mapping sounds to Sinhala letters (Grapheme-to-Phoneme).

### System I/O:
- **Inputs:** Mastery predictions, intervention paths.
- **Outputs:** **Dynamic Multimodal Lesson Plan**.

---

## 3. Intervention-Service: Guidance & Support Engine
**Research Focus:** Providing highly targeted, voice-assisted corrective paths.

### Functionality:
- **Voice Assistance:** Because Dyslexia is phonological, the service triggers voice-based audio cues (e.g., "Listen to the sound 'Ka' again") when a reading hesitation > 5 seconds is detected.
- **Learning Path Prediction:** Uses historical monitoring data to predict the best instructional approach, preventing failure before it happens.

### System I/O:
- **Inputs:** Real-time frustration flags from Monitoring, Mastery levels.
- **Outputs:** **Intervention Commands** (`play_audio_cue`, `split_syllables`).

---

## 4. Visual-Service: Adaptive Visual Learning Interface
**Research Focus:** Real-time adaptation of the visual environment to minimize reading hesitations.

### Functionality:
- **Dynamic UI Adjustment:** Listens for hesitation flags. If detected, instantly increases word spacing and scales up typography.
- **Pilla Color-Coding:** Specifically for Sinhala, visually isolates complex shapes by color-coding vowel modifiers (Pillas) in red and base letters in black, aiding visual separation for the dyslexic brain.

### System I/O:
- **Inputs:** Baseline preferences, real-time hesitation triggers.
- **Outputs:** Adjusted UI JSON themes.
