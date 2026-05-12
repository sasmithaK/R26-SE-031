import os
from datasets import load_dataset

def fetch_datasets():
    print("Fetching Sinhala Dyslexia Datasets from Hugging Face...")

    # 1. SiTSE (NLPC-UOM)
    # 1,000 complex Sinhala sentences paired with 3 human-written simplifications.
    # Not dyslexia-specific, but validated text readability resource.
    print("Loading NLPC-UOM/SiTSE...")
    sitse_dataset = load_dataset("NLPC-UOM/SiTSE")
    print(f"SiTSE loaded: {sitse_dataset}")

    # 2. sinhala-dyslexia-corrected-id20percent (SPEAK-PP)
    # 27,600 dyslexic->correct Sinhala sentence pairs with labeled error types.
    print("Loading SPEAK-PP/sinhala-dyslexia-corrected-id20percent...")
    speak_dataset = load_dataset("SPEAK-PP/sinhala-dyslexia-corrected-id20percent")
    print(f"SPEAK-PP loaded: {speak_dataset}")

    # 3. sinhala-dyslexia-assistant-articulation-errors (peshalaperera)
    # 3,000 rows with original text, dyslexic text, error type, and audio paths.
    print("Loading peshalaperera/sinhala-dyslexia-assistant-articulation-errors...")
    articulation_dataset = load_dataset("peshalaperera/sinhala-dyslexia-assistant-articulation-errors")
    print(f"Articulation loaded: {articulation_dataset}")

    # Save to disk for persistent access
    os.makedirs("datasets/sitse", exist_ok=True)
    sitse_dataset["train"].to_csv("datasets/sitse/train.csv")

    os.makedirs("datasets/speak_pp", exist_ok=True)
    speak_dataset["train"].to_csv("datasets/speak_pp/train.csv")

    os.makedirs("datasets/articulation", exist_ok=True)
    articulation_dataset["train"].to_csv("datasets/articulation/train.csv")
    articulation_dataset["test"].to_csv("datasets/articulation/test.csv")

    print("All datasets loaded and saved to datasets/ directory successfully!")

if __name__ == "__main__":
    fetch_datasets()
