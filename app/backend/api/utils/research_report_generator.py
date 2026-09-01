from fpdf import FPDF
import io

def generate_research_pdf(student_id: str, c1_data: dict, c2_data: dict, c3_data: dict, c4_data: dict) -> bytes:
    pdf = FPDF()
    pdf.add_page()
    
    def safe_str(text):
        if text is None or text == "":
            return "N/A"
        # Convert to string and replace unprintable latin-1 chars
        return str(text).encode('latin-1', 'replace').decode('latin-1')
        
    def add_section_header(title):
        pdf.ln(5)
        pdf.set_font("Arial", 'B', 14)
        pdf.set_fill_color(240, 240, 240)
        pdf.cell(0, 10, title, ln=True, fill=True)
        pdf.ln(2)
        pdf.set_font("Arial", '', 11)

    # Title & Header
    pdf.set_font("Arial", 'B', 18)
    pdf.cell(0, 12, f"Sipsara R26-SE-031 - Research Report", ln=True, align='C')
    pdf.set_font("Arial", 'I', 12)
    pdf.cell(0, 8, f"Student ID: {student_id} | Generated: {safe_str(c1_data.get('updated_at'))}", ln=True, align='C')
    pdf.ln(5)
    
    # ---------------------------------------------------------
    # Section 1: Overview
    # ---------------------------------------------------------
    add_section_header("1. Executive Summary")
    pdf.multi_cell(0, 6, "Experimental prototype. Synthetic results are not clinical validation or a finding about a child.", new_x="LMARGIN", new_y="NEXT")
    pdf.cell(0, 8, f"Primary Pattern Detected: {safe_str(c3_data.get('primary_pattern'))} (Confidence: {safe_str(c3_data.get('confidence'))})", ln=True)
    pdf.cell(0, 8, f"Estimated Learner Theta (IRT): {safe_str(c4_data.get('theta'))}", ln=True)
    
    # ---------------------------------------------------------
    # Section 2: C1 Behavioral Telemetry
    # ---------------------------------------------------------
    add_section_header("2. C1: Behavioral Telemetry")
    if c1_data:
        pdf.cell(0, 8, f"First Attempt Accuracy: {c1_data.get('first_attempt_accuracy', 'N/A')}", ln=True)
        pdf.cell(0, 8, f"Median Response Latency: {c1_data.get('median_response_latency_ms', 'N/A')} ms", ln=True)
        pdf.cell(0, 8, f"Behavioral Fatigue Proxy: {c1_data.get('behavioral_fatigue_proxy', 'N/A')}", ln=True)
        
        pdf.ln(3)
        pdf.set_font("Arial", 'B', 11)
        pdf.cell(0, 8, "Error Distribution:", ln=True)
        pdf.set_font("Arial", '', 11)
        errs = c1_data.get("error_distribution", {})
        if errs:
            for k, v in errs.items():
                pdf.cell(0, 6, f" - {k.replace('_', ' ').title()}: {v if v is not None else 'N/A'}", ln=True)
    else:
        pdf.cell(0, 8, "No C1 data available.", ln=True)
        
    # ---------------------------------------------------------
    # Section 3: C2 Speech & Acoustic Monitoring
    # ---------------------------------------------------------
    add_section_header("3. C2: Speech & Acoustic Monitoring")
    if c2_data and c2_data.get('latest'):
        latest = c2_data['latest']
        pdf.cell(0, 8, f"Expected Text: {safe_str(latest.get('expected_text'))}", ln=True)
        pdf.cell(0, 8, f"Transcription: {safe_str(latest.get('transcription'))}", ln=True)
        pdf.cell(0, 8, f"Word Error Rate (WER): {latest.get('wer', 'N/A')}", ln=True)
        pdf.cell(0, 8, f"Acoustic Latency: {latest.get('acoustic_latency_ms', 'N/A')} ms", ln=True)
        pdf.cell(0, 8, f"Intra-Word Silence Ratio: {latest.get('silence_ratio', 'N/A')}", ln=True)
        pdf.cell(0, 8, f"Local Jitter: {latest.get('jitter', 'N/A')} | Local Shimmer: {latest.get('shimmer', 'N/A')}", ln=True)
        pdf.cell(0, 8, f"Recording Quality: {safe_str(latest.get('recording_quality'))}", ln=True)
    else:
        pdf.cell(0, 8, "No C2 data available.", ln=True)

    # ---------------------------------------------------------
    # Section 4: C3 Diagnostic Fusion & XAI
    # ---------------------------------------------------------
    add_section_header("4. C3: Diagnostic Fusion & XAI")
    if c3_data:
        probs = c3_data.get("probabilities", {})
        if probs:
            pdf.set_font("Arial", 'B', 11)
            pdf.cell(0, 8, "Class Probabilities:", ln=True)
            pdf.set_font("Arial", '', 11)
            for k, v in probs.items():
                pdf.cell(0, 6, f" - {k}: {v:.2f}", ln=True)
        
        shaps = c3_data.get("shap_explanations", [])
        if shaps:
            pdf.ln(3)
            pdf.set_font("Arial", 'B', 11)
            pdf.cell(0, 8, "Top Feature Contributions (SHAP):", ln=True)
            pdf.set_font("Arial", '', 11)
            for s in shaps:
                impact = s.get('contribution', 0)
                direction = s.get('direction', 'unknown')
                feature = safe_str(s.get('feature', ''))
                pdf.cell(0, 6, f" - {feature}: {impact:.4f} ({direction})", ln=True)
                
        if c3_data.get("llm_summary"):
            pdf.ln(3)
            pdf.set_font("Arial", 'B', 11)
            pdf.cell(0, 8, "LLM Generated Summary:", ln=True)
            pdf.set_font("Arial", '', 11)
            pdf.multi_cell(0, 6, safe_str(c3_data["llm_summary"]), new_x="LMARGIN", new_y="NEXT")
    else:
        pdf.cell(0, 8, "No C3 data available.", ln=True)

    # ---------------------------------------------------------
    # Section 5: C4 Adaptive Learning
    # ---------------------------------------------------------
    add_section_header("5. C4: Adaptive Learning State")
    if c4_data:
        kcs = c4_data.get("knowledge_components", [])
        if kcs:
            pdf.set_font("Arial", 'B', 11)
            pdf.cell(0, 8, "Knowledge Components Mastery (BKT):", ln=True)
            pdf.set_font("Arial", '', 11)
            for kc in kcs:
                pdf.cell(0, 6, f" - {safe_str(kc.get('name'))}: {kc.get('mastery', 0):.2f}", ln=True)
                
        history = c4_data.get("history", [])
        if history:
            pdf.ln(3)
            pdf.set_font("Arial", 'B', 11)
            pdf.cell(0, 8, "Latest Adaptive Decision:", ln=True)
            pdf.set_font("Arial", '', 11)
            last = history[-1]
            pdf.cell(0, 6, f"Decision: {safe_str(last.get('decision'))}", ln=True)
            pdf.multi_cell(0, 6, f"Reason: {safe_str(last.get('reason'))}", new_x="LMARGIN", new_y="NEXT")
            pdf.cell(0, 6, f"Difficulty Selected: {last.get('selected_difficulty', 'N/A')}", ln=True)
    else:
        pdf.cell(0, 8, "No C4 data available.", ln=True)
        
    # ---------------------------------------------------------
    # Section 6: Research Limitations
    # ---------------------------------------------------------
    add_section_header("6. Research Disclaimers")
    pdf.set_font("Arial", 'I', 10)
    pdf.multi_cell(0, 6, "This report is generated by the Sipsara R26-SE-031 research prototype. "
                         "Data representations and ML predictions (XGBoost/SHAP) are based on synthetic "
                         "or preliminary field data and have not been validated for clinical diagnostic use. "
                         "This tool is intended strictly for exploratory research. "
                         "This PDF uses a Latin-1 font; view original Sinhala text in the dashboard.")

    # Return bytes
    out = pdf.output(dest='S')
    if isinstance(out, (bytes, bytearray)):
        return bytes(out)
    return out.encode('latin1')
