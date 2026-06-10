"""
scripts/train_c4_intervention_rf.py
====================================
Random Forest classification for C4 (IIGE) — Phoneme Error Analysis.

MODEL PURPOSE:
    Maps [Word Features + Behavioral Flags] → Error Type Classification.
    Error Types: LONG_WORD, VOWEL_CONFUSION, CONSONANT_CONFUSION, UNFAMILIAR.

TRAINING DATA:
    - SPEAK-PP (Sinhala Dyslexia Corrected Dataset)
    - Articulation Errors Dataset
    - Synthetic augmentation for behavioral flags

Model saved to: models/c4_intervention_rf.pkl
"""

import os
import sys
import pickle
import pandas as pd
import numpy as np
from pathlib import Path
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, f1_score

sys.stdout.reconfigure(encoding='utf-8')

BASE = Path(__file__).parent.parent
DATA_DIR = BASE / "datasets"
MODELS_DIR = BASE / "models"
MODELS_DIR.mkdir(exist_ok=True)

# Word feature extraction logic
def extract_word_features(word: str) -> dict:
    if not isinstance(word, str): return {"syl_count": 0, "vowel_density": 0, "cluster_len": 0}
    # Syllables (approximate by Sinhala characters/pilla)
    # This is a simplified version of the real splitter for feature extraction
    syl_count = sum(1 for c in word if 0x0D80 <= ord(c) <= 0x0DFF) # Count Sinhala block chars
    vowel_signs = sum(1 for c in word if 0x0DCF <= ord(c) <= 0x0DDF)
    consonant_clusters = word.count('\u0DCA') # Hal kirima count
    
    return {
        "syl_count": syl_count,
        "vowel_density": vowel_signs / max(syl_count, 1),
        "cluster_len": consonant_clusters
    }

def train():
    print("[C4-RF] Loading and merging datasets...")
    
    # 1. Load SPEAK-PP
    speak_pp_path = DATA_DIR / "speak_pp" / "train.csv"
    if not speak_pp_path.exists():
        print("  Error: SPEAK-PP dataset not found. Run fetch_huggingface_datasets.py first.")
        return
    
    df_speak = pd.read_csv(speak_pp_path)
    
    # 2. Load Articulation Errors
    art_path = DATA_DIR / "articulation" / "train.csv"
    df_art = pd.read_csv(art_path)
    
    # 3. Clean and map labels
    # We map the 600+ diverse labels into our 4 core research categories
    label_map = {
        "visual reversal": "CONSONANT_CONFUSION",
        "visual_reversal": "CONSONANT_CONFUSION",
        "Phonetic Confusion": "CONSONANT_CONFUSION",
        "phonetic": "CONSONANT_CONFUSION",
        "Grammar": "UNFAMILIAR",
        "grammar": "UNFAMILIAR",
        "Spoken vs Written": "VOWEL_CONFUSION",
        "reversal": "CONSONANT_CONFUSION",
        "substitution": "CONSONANT_CONFUSION",
        "omission": "VOWEL_CONFUSION",
        "insertion": "LONG_WORD"
    }
    
    def map_label(x):
        return label_map.get(x, "VOWEL_CONFUSION") # Default to Vowel (most common in Sinhala)

    df_speak['target'] = df_speak['error_type'].apply(map_label)
    df_art['target'] = df_art['error_type'].apply(map_label)
    
    # Combine
    df_combined = pd.concat([
        df_speak[['clean_sentence', 'target']].rename(columns={'clean_sentence': 'word'}),
        df_art[['original_sentence', 'target']].rename(columns={'original_sentence': 'word'})
    ], ignore_index=True)
    
    print(f"  Total samples: {len(df_combined)}")
    
    # 4. Extract features
    print("  Extracting word features...")
    features_list = []
    for word in df_combined['word']:
        features_list.append(extract_word_features(word))
    
    df_features = pd.DataFrame(features_list)
    
    # Add synthetic behavioral flags (since real datasets don't have them)
    # We correlate them with the target for training
    df_features['reversal'] = (df_combined['target'] == 'CONSONANT_CONFUSION').astype(int) * np.random.choice([0, 1], size=len(df_combined), p=[0.3, 0.7])
    df_features['omission'] = (df_combined['target'] == 'VOWEL_CONFUSION').astype(int) * np.random.choice([0, 1], size=len(df_combined), p=[0.4, 0.6])
    df_features['substitution'] = (df_combined['target'] == 'CONSONANT_CONFUSION').astype(int) * np.random.choice([0, 1], size=len(df_combined), p=[0.5, 0.5])
    df_features['hesitation'] = np.random.choice([0, 1], size=len(df_combined), p=[0.6, 0.4])

    X = np.array(df_features.values, dtype=float)
    y = np.array(df_combined['target'].values, dtype=str)
    
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    print("[C4-RF] Training Random Forest...")
    model = RandomForestClassifier(n_estimators=100, max_depth=10, random_state=42)
    model.fit(X_train, y_train)
    
    # 5. Evaluate
    y_pred = model.predict(X_test)
    print("\n  Classification Report:")
    print(classification_report(y_test, y_pred))
    
    # 6. Save
    out_path = MODELS_DIR / "c4_intervention_rf.pkl"
    with open(out_path, "wb") as f:
        pickle.dump(model, f)
    print(f"\n[C4-RF] Model saved → {out_path}")
    
    # Feature Importance
    importances = model.feature_importances_
    cols = df_features.columns
    print("\n  Feature Importance:")
    for i, imp in enumerate(importances):
        print(f"    {cols[i]:<15}: {imp:.4f}")

if __name__ == "__main__":
    train()
