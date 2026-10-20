"""Load C2 thresholds from ``c2_settings.json`` (one place to change and cite)."""
import json
import os

_PATH = os.getenv(
    "C2_SETTINGS_PATH",
    os.path.join(os.path.dirname(__file__), "..", "c2_settings.json"),
)
try:
    with open(_PATH, encoding="utf-8") as handle:
        SETTINGS = json.load(handle)
except (OSError, ValueError):
    SETTINGS = {}


def get(section: str, key: str, default):
    return (SETTINGS.get(section) or {}).get(key, default)
