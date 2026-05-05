import torch.nn as nn
from data_generator import NUM_SKILLS

HIDDEN_DIM = 64

class LSTMDkt(nn.Module):
    def __init__(self):
        super(LSTMDkt, self).__init__()
        self.lstm = nn.LSTM(NUM_SKILLS * 2, HIDDEN_DIM, batch_first=True)
        self.fc = nn.Linear(HIDDEN_DIM, NUM_SKILLS)
        self.sig = nn.Sigmoid()

    def forward(self, x):
        out, _ = self.lstm(x)
        return self.sig(self.fc(out))
