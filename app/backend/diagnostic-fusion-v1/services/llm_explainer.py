import os
import json
import logging
import httpx
from typing import Dict, Any, Tuple

logger = logging.getLogger(__name__)

# Fallback models if environment variables are not set
AZURE_AI_ENDPOINT = os.getenv("AZURE_AI_ENDPOINT", "https://api.github.com/models/chat/completions")
AZURE_AI_KEY = os.getenv("AZURE_AI_KEY", "") # You can use a GitHub token here for testing Llama-3-8B-Instruct
MODEL_NAME = os.getenv("AZURE_AI_MODEL", "Meta-Llama-3-8B-Instruct") 

async def generate_diagnostic_summary(
    student_id: str, 
    learner_profile: Dict[str, Any], 
    shap_explanations: Dict[str, Any]
) -> Tuple[str, str]:
    """
    Calls a Small Language Model (SLM) on Azure AI Studio to translate SHAP values 
    into a readable summary and recommendations.
    
    Returns:
        Tuple[str, str]: (llm_summary, llm_recommendations)
    """
    if not AZURE_AI_KEY:
        logger.warning("AZURE_AI_KEY not set. Skipping LLM explanation generation.")
        return ("LLM Summary not available (Missing API Key).", "LLM Recommendations not available.")
    
    # Construct the prompt
    primary_pattern = learner_profile.get("primary_pattern", "Unknown")
    confidence = learner_profile.get("confidence", 0.0)
    
    # Format SHAP values nicely
    shap_text = "\n".join([f"- {feat}: {float(val):+.3f}" for feat, val in shap_explanations.items()])
    
    system_prompt = (
        "Explain an experimental model trained on synthetic data. Do not diagnose a child, "
        "infer a cause, claim clinical validity, or interpret class scores as calibrated disorder risks. "
        "SHAP values are signed contributions to a model score, not causal evidence or percentages. "
        "State the synthetic-only validation limitation. Keep your output concise."
    )
    
    user_prompt = (
        f"Student ID: {student_id}\n"
        f"Experimental Learning Pattern: {primary_pattern} (Confidence: {confidence:.0%})\n\n"
        f"Machine Learning Feature Impacts (SHAP values):\n{shap_text}\n\n"
        "Based on this data, please provide two sections:\n"
        "1. SUMMARY: Two sentences about the model output and its limitation, not a finding about the child.\n"
        "2. RECOMMENDATIONS: Two data-quality or evaluation checks before interpreting the estimate."
    )
    
    headers = {
        "Authorization": f"Bearer {AZURE_AI_KEY}",
        "Content-Type": "application/json"
    }
    
    payload = {
        "model": MODEL_NAME,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt}
        ],
        "temperature": 0.3,
        "max_tokens": 250
    }
    
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                AZURE_AI_ENDPOINT,
                headers=headers,
                json=payload,
                timeout=15.0
            )
            response.raise_for_status()
            result = response.json()
            
            content = result["choices"][0]["message"]["content"]
            
            # Parse the content into summary and recommendations
            summary = ""
            recommendations = ""
            
            parts = content.split("RECOMMENDATIONS:")
            if len(parts) == 2:
                summary = parts[0].replace("SUMMARY:", "").strip()
                recommendations = parts[1].strip()
            else:
                summary = content.strip()
                
            return summary, recommendations
            
    except Exception as e:
        logger.error(f"Error generating LLM summary: {e}")
        return ("Error generating summary.", "Error generating recommendations.")
