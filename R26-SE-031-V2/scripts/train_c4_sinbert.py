"""
scripts/train_c4_sinbert.py
============================
Fine-tune SinBERT (keshan3252/sinbert) on SPEAK-PP dataset for 4-class
Sinhala dyslexic error classification.

Reference: Perera & Sumanathilaka (2025) arXiv:2510.04750
Dataset:   SPEAK-PP/sinhala-dyslexia-corrected-id20percent (~27.6k rows)
Model:     keshan3252/sinbert → fine-tuned → models/c4_sinbert/
Target:    weighted F1 ≥ 0.70

Usage:
    python scripts/train_c4_sinbert.py
    python scripts/train_c4_sinbert.py --epochs 5 --batch 16

Prerequisites:
    pip install transformers torch datasets scikit-learn
    datasets/speak_pp/train.csv  (download via fetch_huggingface_datasets.py)
"""

import argparse
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(ROOT))

SPEAK_PP_PATH = ROOT / "datasets" / "speak_pp" / "train.csv"
OUTPUT_PATH   = ROOT / "models" / "c4_sinbert"
LABEL_MAP = {
    "visual reversal":    "VOWEL_CONFUSION",
    "visual_reversal":    "VOWEL_CONFUSION",
    "visual_scrambling":  "VOWEL_CONFUSION",
    "Phonetic Confusion": "CONSONANT_CONFUSION",
    "phonetic_confusion": "CONSONANT_CONFUSION",
    "phonetic":           "CONSONANT_CONFUSION",
    "Spelling":           "CONSONANT_CONFUSION",
    "substitution":       "CONSONANT_CONFUSION",
    "omission":           "UNFAMILIAR",
    "Omission":           "UNFAMILIAR",
    "Spoken vs Written":  "UNFAMILIAR",
    "spoken vs written":  "UNFAMILIAR",
    "Grammar":            "LONG_WORD",
    "grammar":            "LONG_WORD",
}
CLASSES = ["LONG_WORD", "VOWEL_CONFUSION", "CONSONANT_CONFUSION", "UNFAMILIAR"]
CLASS2ID = {c: i for i, c in enumerate(CLASSES)}


def load_speak_pp(path: Path):
    """Load and map SPEAK-PP to 4-class labels. Returns (texts, labels) lists."""
    import pandas as pd
    print(f"[SinBERT] Loading SPEAK-PP from {path}")
    if not path.exists():
        # Try loading from HuggingFace if local not available
        try:
            from datasets import load_dataset
            ds = load_dataset("SPEAK-PP/sinhala-dyslexia-corrected-id20percent", split="train")
            df = ds.to_pandas()
        except Exception as e:
            print(f"[SinBERT] SPEAK-PP not found locally and HuggingFace load failed: {e}")
            print("  Run: python scripts/fetch_huggingface_datasets.py first")
            sys.exit(1)
    else:
        df = pd.read_csv(path)

    print(f"[SinBERT] Raw rows: {len(df)}")
    # Detect column names
    text_col  = next((c for c in ["dyslexic_sentence", "sentence", "text"] if c in df.columns), df.columns[0])
    label_col = next((c for c in ["error_type", "label", "type"] if c in df.columns), df.columns[-1])

    df["mapped_label"] = df[label_col].map(LABEL_MAP)
    df = df[df["mapped_label"].notna()].copy()
    df = df[df[text_col].notna()].copy()
    print(f"[SinBERT] Usable rows after mapping: {len(df)}")
    print(f"[SinBERT] Label distribution:\n{df['mapped_label'].value_counts()}")

    texts  = df[text_col].tolist()
    labels = [CLASS2ID[l] for l in df["mapped_label"].tolist()]
    return texts, labels


def train(epochs: int = 3, batch_size: int = 16, max_length: int = 128):
    from transformers import (
        AutoTokenizer, AutoModelForSequenceClassification, TrainingArguments, Trainer
    )
    from sklearn.model_selection import train_test_split
    from sklearn.metrics import classification_report, f1_score
    import torch
    from torch.utils.data import Dataset

    class SinhalaDataset(Dataset):
        def __init__(self, encodings, labels):
            self.encodings = encodings
            self.labels    = labels
        def __len__(self):
            return len(self.labels)
        def __getitem__(self, idx):
            item = {k: torch.tensor(v[idx]) for k, v in self.encodings.items()}
            item["labels"] = torch.tensor(self.labels[idx])
            return item

    texts, labels = load_speak_pp(SPEAK_PP_PATH)
    X_train, X_val, y_train, y_val = train_test_split(
        texts, labels, test_size=0.2, stratify=labels, random_state=42
    )
    print(f"[SinBERT] Train: {len(X_train)}  Val: {len(X_val)}")

    print("[SinBERT] Loading tokenizer: keshan3252/sinbert")
    tokenizer = AutoTokenizer.from_pretrained("keshan3252/sinbert")
    model = AutoModelForSequenceClassification.from_pretrained(
        "keshan3252/sinbert",
        num_labels=len(CLASSES),
        id2label={i: c for i, c in enumerate(CLASSES)},
        label2id=CLASS2ID,
        ignore_mismatched_sizes=True,
    )

    def tokenize(texts_list):
        return tokenizer(texts_list, truncation=True, padding=True,
                         max_length=max_length, return_tensors=None)

    train_enc = tokenize(X_train)
    val_enc   = tokenize(X_val)
    train_ds  = SinhalaDataset(train_enc, y_train)
    val_ds    = SinhalaDataset(val_enc,   y_val)

    def compute_metrics(eval_pred):
        logits, labels = eval_pred
        preds = logits.argmax(axis=-1)
        f1 = f1_score(labels, preds, average="weighted")
        return {"f1": f1}

    OUTPUT_PATH.mkdir(parents=True, exist_ok=True)
    args = TrainingArguments(
        output_dir=str(OUTPUT_PATH),
        num_train_epochs=epochs,
        per_device_train_batch_size=batch_size,
        per_device_eval_batch_size=batch_size,
        evaluation_strategy="epoch",
        save_strategy="epoch",
        load_best_model_at_end=True,
        metric_for_best_model="f1",
        logging_steps=50,
        report_to="none",
    )
    trainer = Trainer(
        model=model,
        args=args,
        train_dataset=train_ds,
        eval_dataset=val_ds,
        compute_metrics=compute_metrics,
    )
    print(f"[SinBERT] Training for {epochs} epochs...")
    trainer.train()

    # Save final model + tokenizer
    model.save_pretrained(str(OUTPUT_PATH))
    tokenizer.save_pretrained(str(OUTPUT_PATH))

    # Evaluation report
    val_preds = trainer.predict(val_ds).predictions.argmax(axis=-1)
    print("\n[SinBERT] === Validation Report ===")
    print(classification_report(y_val, val_preds, target_names=CLASSES))
    f1 = f1_score(y_val, val_preds, average="weighted")
    print(f"[SinBERT] Weighted F1: {f1:.4f}  (target ≥ 0.70)")
    print(f"[SinBERT] Model saved to {OUTPUT_PATH}")

    # Save training metadata
    meta = {"weighted_f1": float(f1), "epochs": epochs, "n_train": len(X_train),
            "n_val": len(X_val), "classes": CLASSES,
            "reference": "Perera & Sumanathilaka (2025) arXiv:2510.04750"}
    with open(OUTPUT_PATH / "training_metadata.json", "w") as f:
        json.dump(meta, f, indent=2)

    return f1


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--epochs",  type=int, default=3)
    parser.add_argument("--batch",   type=int, default=16)
    args = parser.parse_args()
    f1 = train(args.epochs, args.batch)
    if f1 < 0.70:
        print(f"⚠️  F1={f1:.3f} below 0.70 target — consider more epochs or data cleaning")
    else:
        print(f"✅ F1={f1:.3f} meets research target (≥ 0.70)")


if __name__ == "__main__":
    main()
