"""
intervention-service-v1/core/syllable_splitter.py
===================================================
Sinhala Unicode Syllable Splitter — Rule-Based NLP.

Sinhala Unicode block: U+0D80 – U+0DFF

Key Unicode codepoints:
    Independent vowels:  U+0D85–U+0D96   (අ ආ ඇ ඈ ඉ ඊ ...)
    Consonants:          U+0D9A–U+0DC6   (ක ඛ ග ...)
    Dependent vowel signs: U+0DCF–U+0DDF (ා ි ී ු ූ ෘ ෙ ේ ෛ ො ෝ ෞ ෟ)
    AL_LAKUNA (hal kirima): U+0DCA        (් — kills inherent vowel; conjunct marker)
    Anusvara:            U+0D82           (ං)
    Visargaya:           U+0D83           (ඃ)
    ZWNJ:                U+200C           (used inside conjunct clusters in some fonts)

Syllable Rules:
    1. Independent vowel → one syllable unit
    2. Consonant + optional vowel sign(s) → one syllable
    3. Conjunct (consonant + AL_LAKUNA + consonant) → no internal boundary;
       the whole cluster is one syllable onset
    4. Anusvara/Visargaya attach to the preceding syllable

Validation target: F1 ≥ 0.95 on 200-word NIE Grade 1–2 curriculum set.
"""

from __future__ import annotations

from typing import List


# ── Unicode codepoint ranges ─────────────────────────────────────────────

_INDEPENDENT_VOWELS = set(range(0x0D85, 0x0D97))   # U+0D85–U+0D96
_CONSONANTS         = set(range(0x0D9A, 0x0DC7))   # U+0D9A–U+0DC6
_VOWEL_SIGNS        = set(range(0x0DCF, 0x0DE0))   # U+0DCF–U+0DDF
_AL_LAKUNA          = 0x0DCA                        # ්
_ANUSVARA           = 0x0D82                        # ං
_VISARGAYA          = 0x0D83                        # ඃ
_ZWNJ               = 0x200C

# Characters that attach to the preceding syllable (no boundary before them)
_CODA_ATTACHMENTS   = {_ANUSVARA, _VISARGAYA, _AL_LAKUNA}


def _cp(char: str) -> int:
    """Return Unicode codepoint of a single character."""
    return ord(char)


def _is_consonant(char: str) -> bool:
    return _cp(char) in _CONSONANTS


def _is_vowel_sign(char: str) -> bool:
    return _cp(char) in _VOWEL_SIGNS


def _is_independent_vowel(char: str) -> bool:
    return _cp(char) in _INDEPENDENT_VOWELS


def _is_al_lakuna(char: str) -> bool:
    return _cp(char) == _AL_LAKUNA


def _is_coda(char: str) -> bool:
    return _cp(char) in _CODA_ATTACHMENTS


def split_syllables(word: str) -> List[str]:
    """
    Split a Sinhala word string into syllable units.

    Algorithm:
        Iterate through characters, building syllable segments.
        A new syllable boundary opens when a new consonant or independent
        vowel is encountered and the current segment already has a nucleus
        (vowel sign, inherent vowel implied, or explicit vowel).
        AL_LAKUNA joins the preceding consonant to the following one
        (conjunct cluster — no boundary inside).

    Args:
        word: A Sinhala word string (may contain spaces, which are skipped).

    Returns:
        List of syllable strings, e.g. ["ක", "ළු"] for "කළු".

    Examples:
        split_syllables("කළු")  → ["කළ", "ු"]        # 2-syllable word
        split_syllables("කතා") → ["ක", "තා"]          # 2-syllable word
        split_syllables("අලං") → ["අ", "ලං"]           # independent vowel + coda
        split_syllables("ශ්‍ර") → ["ශ්‍ර"]              # conjunct — no break
    """
    if not word:
        return []

    chars = [c for c in word if c != " " and _cp(c) != _ZWNJ]
    if not chars:
        return []

    syllables: List[str] = []
    current: List[str] = []
    i = 0

    while i < len(chars):
        ch = chars[i]

        # ── Conjunct check: consonant + AL_LAKUNA + consonant ────────────
        # Pattern: C + ් + C  → merge all three into current syllable onset
        if _is_consonant(ch) and (i + 1) < len(chars) and _is_al_lakuna(chars[i + 1]):
            # Peek ahead: is there another consonant after AL_LAKUNA?
            if (i + 2) < len(chars) and _is_consonant(chars[i + 2]):
                # Conjunct cluster — consume C + ් + C as one onset
                if current and not _needs_more(current):
                    # Only flush if the current syllable is already complete
                    syllables.append("".join(current))
                    current = []
                current.extend([ch, chars[i + 1], chars[i + 2]])
                i += 3
                continue
            else:
                # AL_LAKUNA as coda (hal-kirima) — attach to current
                if not current:
                    current.append(ch)
                else:
                    if _is_consonant(current[-1]) or _is_vowel_sign(current[-1]):
                        # consonant finisher — attach AL_LAKUNA to current syllable
                        current.append(ch)
                        current.append(chars[i + 1])
                        i += 2
                        # After AL_LAKUNA coda, this syllable is closed
                        syllables.append("".join(current))
                        current = []
                        continue
                    else:
                        current.append(ch)
                i += 1
                continue

        # ── Dependent vowel sign ─────────────────────────────────────────
        if _is_vowel_sign(ch):
            current.append(ch)
            i += 1
            continue

        # ── Coda diacritics (anusvara, visargaya) ────────────────────────
        if _is_coda(ch):
            current.append(ch)
            i += 1
            # After coda, syllable is closed
            syllables.append("".join(current))
            current = []
            continue

        # ── Independent vowel ────────────────────────────────────────────
        if _is_independent_vowel(ch):
            if current:
                syllables.append("".join(current))
                current = []
            current.append(ch)
            i += 1
            continue

        # ── Consonant: starts a new syllable ─────────────────────────────
        if _is_consonant(ch):
            if current:
                syllables.append("".join(current))
                current = []
            current.append(ch)
            i += 1
            continue

        # ── Unknown character (punctuation, numerals, etc.) ───────────────
        if current:
            syllables.append("".join(current))
            current = []
        syllables.append(ch)
        i += 1

    if current:
        syllables.append("".join(current))

    return [s for s in syllables if s]


def _needs_more(segment: List[str]) -> bool:
    """
    True if the current segment is just a consonant with no vowel nucleus yet
    (implying it's still waiting for a vowel sign or a conjunct).
    This prevents premature syllable boundary before a vowel sign.
    """
    if not segment:
        return False
    last = segment[-1]
    return _is_consonant(last)


def syllable_count(word: str) -> int:
    """Convenience: return number of syllables in a Sinhala word."""
    return len(split_syllables(word))


def build_stage1_audio_sequence(syllables: List[str]) -> List[str]:
    """
    Build a list of gTTS-compatible phonetic hints for each syllable.
    Returns the same list (Sinhala text passed directly to gTTS Sinhala).
    Future: could map to IPA or romanization for non-Sinhala TTS.
    """
    return syllables
