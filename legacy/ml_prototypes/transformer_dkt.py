import torch.nn as nn
from data_generator import NUM_SKILLS

HIDDEN_DIM = 64

class TransformerDkt(nn.Module):
    def __init__(self):
        super(TransformerDkt, self).__init__()
        self.embedding = nn.Linear(NUM_SKILLS * 2, HIDDEN_DIM)
        encoder_layer = nn.TransformerEncoderLayer(d_model=HIDDEN_DIM, nhead=4, batch_first=True)
        self.transformer = nn.TransformerEncoder(encoder_layer, num_layers=2)
        self.fc = nn.Linear(HIDDEN_DIM, NUM_SKILLS)
        self.sig = nn.Sigmoid()

    def forward(self, x):
        x = self.embedding(x)
        out = self.transformer(x)
        return self.sig(self.fc(out))
