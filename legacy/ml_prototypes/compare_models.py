import torch
import torch.nn as nn
from torch.utils.data import DataLoader
from data_generator import SinhalaDKTDataset
from lstm_dkt import LSTMDkt
from transformer_dkt import TransformerDkt
from random_forest_baseline import train_and_evaluate_rf

BATCH_SIZE = 32

def compare_models():
    print("Generating Synthetic Sinhala Dyslexia Data...")
    dataset = SinhalaDKTDataset(num_samples=2000)
    loader = DataLoader(dataset, batch_size=BATCH_SIZE, shuffle=True)
    
    lstm_model = LSTMDkt()
    transformer_model = TransformerDkt()
    
    opt_lstm = torch.optim.Adam(lstm_model.parameters(), lr=0.01)
    opt_trans = torch.optim.Adam(transformer_model.parameters(), lr=0.01)
    criterion = nn.BCELoss()

    print("\n--- Training LSTM ---")
    for epoch in range(3):
        for x, y in loader:
            opt_lstm.zero_grad()
            loss = criterion(lstm_model(x), y)
            loss.backward()
            opt_lstm.step()
    print("LSTM Training Complete.")

    print("\n--- Training Transformer ---")
    for epoch in range(3):
        for x, y in loader:
            opt_trans.zero_grad()
            loss = criterion(transformer_model(x), y)
            loss.backward()
            opt_trans.step()
    print("Transformer Training Complete.")

    # Train Random Forest Baseline
    train_and_evaluate_rf(dataset)

    print("\nComparison Complete! You can now ensemble the predictions of all 3 models.")

if __name__ == "__main__":
    compare_models()
