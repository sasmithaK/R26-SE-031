w# Reading Intervention — Flutter UI

Grade 1–2 friendly reading-helper UI for the intervention service. Each screen
maps to one of the six error / difficulty categories produced by Model 1, and
demonstrates the matching scaffolding activity that Model 2 will pick from.

## Activities

| Category | Screen | Pattern |
|---|---|---|
| Long word | `long_word_screen.dart` | Beat bar + syllable echo + tap-to-hear |
| Consonant confusion | `consonant_screen.dart` | First-sound anchor |
| Vowel sign | `vowel_screen.dart` | Consonant → vowel → blend → word |
| Unfamiliar word | `unfamiliar_screen.dart` | Meaning first → two-choice sense check |
| Fluency | `fluency_screen.dart` | Shadow read + repetition ladder |
| Phonological awareness | `phonological_screen.dart` | Rhyme recognition |

All screens share:

- Slow / Normal speech-rate toggle.
- Sinhala text rendered in large, high-contrast type with calm colours.
- Large (≥ 64 px) touch targets for Grade 1–2 hands.

## Run (two terminals)

### 1) Backend  —  intervention-service

```powershell
cd intervention-service
python -m pip install -r requirements.txt   # first time only
.\run_service.bat
```

or directly:

```powershell
python -m uvicorn main:app --host 127.0.0.1 --port 8000 --reload
```

Verify: open <http://127.0.0.1:8000/health> — should return `{"status":"healthy", ...}`.

### 2) Frontend  —  Flutter app

```powershell
cd intervention-service\frontend
flutter pub get                              # first time only
.\run_app.bat
```

or directly:

```powershell
flutter run -d chrome
```

Chrome opens with the Reading Helper hub. Stop with `q`, hot-restart with capital `R`.

## How audio works

- **Sinhala text** → fetched as a cached gTTS mp3 from the backend
  (`/api/v1/c4/tts?text=…&lang=si`). Correct Sinhala pronunciation.
- **Short syllables** (≤ 4 codepoints, e.g. `සෞ`) automatically use
  gTTS `slow=True` so they're long enough to hear clearly.
- **English text** → on-device `flutter_tts` (fallback).

If the banner at the top of an activity says **"සේවාව ක්‍රියා නොකරයි"**, the
backend isn't reachable — check Terminal 1.

## Project layout

```
intervention-service/frontend/
├── lib/
│   ├── main.dart                       hub with 6 activity cards
│   ├── theme/reading_theme.dart        Grade 1-2 dyslexia-friendly theme
│   ├── services/reading_audio_service.dart   TTS + backend audio
│   ├── widgets/activity_shell.dart     shared header + status banner
│   └── screens/                        one file per activity category
├── pubspec.yaml
├── run_app.bat                         one-click launcher
└── README.md
```
