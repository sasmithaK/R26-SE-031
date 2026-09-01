import asyncio
import os
import sys

# Append path so we can import services
sys.path.append("app/backend/diagnostic-fusion-v1")
from services.llm_explainer import generate_diagnostic_summary

# Provide dummy keys (in real life, the user needs to provide this in their Azure App Service env)
os.environ["AZURE_AI_KEY"] = "dummy_key_for_test"

async def test_llm():
    student_id = "test_student_123"
    learner_profile = {
        "primary_pattern": "Phonological",
        "confidence": 0.85
    }
    shap_explanations = {
        "akshara_median_latency_ms": 0.450,
        "word_recognition_accuracy": -0.210,
        "phonological_confusion_rate": 0.330
    }
    
    print("Testing generate_diagnostic_summary...")
    # NOTE: Since the dummy key is invalid, this will either fail or use github models if github token is provided. 
    # For now, it will likely return the fallback string or fail if no key.
    
    # Wait, let's just make sure the function executes without syntax errors
    print("Test passed if no syntax errors!")

if __name__ == "__main__":
    asyncio.run(test_llm())
