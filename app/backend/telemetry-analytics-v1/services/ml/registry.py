import json
import os
import joblib

class ModelRegistry:
    def __init__(self):
        self.config = {}
        self.models = {}
        self._load_registry()

    def _load_registry(self):
        registry_path = os.path.join(os.path.dirname(__file__), "..", "..", "models", "model_registry.json")
        if os.path.exists(registry_path):
            with open(registry_path, "r") as f:
                self.config = json.load(f)

    def load_model(self, name: str):
        if name in self.models:
            return self.models[name]
            
        model_path = os.path.join(os.path.dirname(__file__), "..", "..", "models", f"{name}.pkl")
        if os.path.exists(model_path):
            model = joblib.load(model_path)
            self.models[name] = model
            return model
        return None

    def get_config(self, name: str):
        return self.config.get(name, {})

registry = ModelRegistry()
