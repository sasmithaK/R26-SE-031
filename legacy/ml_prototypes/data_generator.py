import torch
import numpy as np
from torch.utils.data import Dataset

# 1. PARAMETERS
NUM_SKILLS = 20  # e.g., Sinhala syllables
SEQ_LEN = 10

class SinhalaDKTDataset(Dataset):
    def __init__(self, num_samples=1000):
        self.data = []
        for _ in range(num_samples):
            seq = []
            for _ in range(SEQ_LEN):
                skill = np.random.randint(0, NUM_SKILLS)
                correct = np.random.randint(0, 2)
                seq.append([skill, correct])
            self.data.append(seq)
            
    def __len__(self): 
        return len(self.data)
    
    def __getitem__(self, idx):
        seq = np.array(self.data[idx])
        x = np.zeros((SEQ_LEN, NUM_SKILLS * 2))
        for t in range(SEQ_LEN):
            skill, correct = seq[t]
            x[t, skill * 2 + correct] = 1
        y = np.zeros((SEQ_LEN, NUM_SKILLS))
        for t in range(SEQ_LEN):
            skill, correct = seq[t]
            y[t, skill] = correct
        return torch.FloatTensor(x), torch.FloatTensor(y)
