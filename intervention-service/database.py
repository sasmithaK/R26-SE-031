"""
Local SQLite persistence for Component 4–style passage pre-scan + word predictions + audio metadata.

MongoDB collections (intervention_log, outcome_log, etc.) remain on Atlas and are wired in main.py.
This module mirrors content-service/database.py naming: database helpers beside the FastAPI entrypoint.
"""
import json
import sqlite3
from pathlib import Path
from typing import Optional

# Single-file DB alongside this package (same idea as content-service/content_state.db).
DB_PATH = Path(__file__).resolve().parent / "c4_state.db"


def get_conn() -> sqlite3.Connection:
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row
    return conn


def init_local_db() -> None:
    """Create SQLite tables if missing."""
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    with get_conn() as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS passages (
              passage_id TEXT PRIMARY KEY,
              student_id TEXT NOT NULL,
              session_id TEXT NOT NULL,
              raw_text   TEXT NOT NULL,
              language   TEXT,
              created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS words (
              word_id    TEXT PRIMARY KEY,
              passage_id TEXT NOT NULL,
              word_index INTEGER NOT NULL,
              word_text  TEXT NOT NULL,
              syllables_json TEXT,
              UNIQUE(passage_id, word_index)
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS word_predictions (
              word_id TEXT PRIMARY KEY,
              difficulty_score REAL NOT NULL,
              error_type_hint TEXT,
              model1_version TEXT,
              created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS audio_cache (
              audio_id TEXT PRIMARY KEY,
              lang TEXT NOT NULL,
              text TEXT NOT NULL,
              kind TEXT NOT NULL,
              file_rel_path TEXT NOT NULL,
              created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
            """
        )


def upsert_passage(
    *,
    passage_id: str,
    student_id: str,
    session_id: str,
    raw_text: str,
    language: Optional[str],
) -> None:
    with get_conn() as conn:
        conn.execute(
            """
            INSERT INTO passages(passage_id, student_id, session_id, raw_text, language)
            VALUES(?, ?, ?, ?, ?)
            ON CONFLICT(passage_id) DO UPDATE SET
              student_id=excluded.student_id,
              session_id=excluded.session_id,
              raw_text=excluded.raw_text,
              language=excluded.language
            """,
            (passage_id, student_id, session_id, raw_text, language),
        )


def upsert_word(
    *,
    word_id: str,
    passage_id: str,
    word_index: int,
    word_text: str,
    syllables: Optional[list[str]],
) -> None:
    syll_json = json.dumps(syllables, ensure_ascii=False) if syllables is not None else None
    with get_conn() as conn:
        conn.execute(
            """
            INSERT INTO words(word_id, passage_id, word_index, word_text, syllables_json)
            VALUES(?, ?, ?, ?, ?)
            ON CONFLICT(word_id) DO UPDATE SET
              passage_id=excluded.passage_id,
              word_index=excluded.word_index,
              word_text=excluded.word_text,
              syllables_json=excluded.syllables_json
            """,
            (word_id, passage_id, word_index, word_text, syll_json),
        )


def upsert_word_prediction(
    *,
    word_id: str,
    difficulty_score: float,
    error_type_hint: Optional[str],
    model1_version: str,
) -> None:
    with get_conn() as conn:
        conn.execute(
            """
            INSERT INTO word_predictions(word_id, difficulty_score, error_type_hint, model1_version)
            VALUES(?, ?, ?, ?)
            ON CONFLICT(word_id) DO UPDATE SET
              difficulty_score=excluded.difficulty_score,
              error_type_hint=excluded.error_type_hint,
              model1_version=excluded.model1_version
            """,
            (word_id, float(difficulty_score), error_type_hint, model1_version),
        )


def upsert_audio_asset(
    *,
    audio_id: str,
    lang: str,
    text: str,
    kind: str,
    file_rel_path: str,
) -> None:
    with get_conn() as conn:
        conn.execute(
            """
            INSERT INTO audio_cache(audio_id, lang, text, kind, file_rel_path)
            VALUES(?, ?, ?, ?, ?)
            ON CONFLICT(audio_id) DO UPDATE SET
              lang=excluded.lang,
              text=excluded.text,
              kind=excluded.kind,
              file_rel_path=excluded.file_rel_path
            """,
            (audio_id, lang, text, kind, file_rel_path),
        )


def get_audio_rel_path(audio_id: str) -> Optional[str]:
    with get_conn() as conn:
        row = conn.execute("SELECT file_rel_path FROM audio_cache WHERE audio_id=?", (audio_id,)).fetchone()
        return str(row["file_rel_path"]) if row else None
