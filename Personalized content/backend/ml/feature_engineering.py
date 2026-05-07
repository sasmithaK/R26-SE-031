import pandas as pd
from sklearn.preprocessing import StandardScaler, LabelEncoder

class FeatureEngineer:
    def __init__(self):
        self.scaler = StandardScaler()
        self.num_cols = [
            "mean_hesitation", 
            "std_hesitation", 
            "mean_correction", 
            "std_correction", 
            "session_count", 
            "cognitive_load", 
            "hesitation_time_ms", 
            "erratic_clicks"
        ]
        
    def fit_transform(self, df: pd.DataFrame, is_training: bool = True) -> pd.DataFrame:
        df = df.copy()
        
        # Ensure all missing columns exist with defaults
        for col in self.num_cols:
            if col not in df.columns:
                df[col] = 0.0
                
        if is_training:
            df[self.num_cols] = self.scaler.fit_transform(df[self.num_cols])
        else:
            df[self.num_cols] = self.scaler.transform(df[self.num_cols])
                
        return df
