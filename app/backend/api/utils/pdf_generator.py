import os
from fpdf import FPDF
from datetime import datetime

class ReportPDF(FPDF):
    def __init__(self, title):
        super().__init__()
        self.report_title = title
        
    def header(self):
        self.set_font("Helvetica", "B", 15)
        self.cell(0, 10, self.report_title, border=False, align="C", new_x="LMARGIN", new_y="NEXT")
        self.set_font("Helvetica", "I", 10)
        self.cell(0, 10, f"Generated on {datetime.now().strftime('%Y-%m-%d %H:%M')}", border=False, align="C", new_x="LMARGIN", new_y="NEXT")
        self.ln(10)

    def footer(self):
        self.set_y(-15)
        self.set_font("Helvetica", "I", 8)
        self.cell(0, 10, f"Page {self.page_no()}/{{nb}}", border=False, align="C")

def generate_parent_report(student_id: str, overview: dict, skills: dict, pattern: dict) -> bytes:
    pdf = ReportPDF(title="SIPSARA Student Progress Report (Parent)")
    pdf.add_page()
    
    # Overview Section
    pdf.set_font("Helvetica", "B", 12)
    pdf.cell(0, 10, "Overview", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 11)
    
    accuracy = overview.get("accuracy", 0)
    practice_time = overview.get("practice_time_minutes", 0)
    fatigue = overview.get("fatigue_status", "Optimal")
    
    pdf.cell(0, 8, f"Accuracy: {accuracy}%", new_x="LMARGIN", new_y="NEXT")
    pdf.cell(0, 8, f"Practice Time: {practice_time} mins", new_x="LMARGIN", new_y="NEXT")
    pdf.cell(0, 8, f"Fatigue Status: {fatigue}", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(5)
    
    # Skills Section
    pdf.set_font("Helvetica", "B", 12)
    pdf.cell(0, 10, "Skills Mastery", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 11)
    
    skills_list = skills.get("skills", [])
    for skill in skills_list:
        pdf.cell(0, 8, f"{skill.get('skill_name')}: {skill.get('mastery_percentage')}% - {skill.get('status')}", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(5)
    
    # Learning Pattern Section
    pdf.set_font("Helvetica", "B", 12)
    pdf.cell(0, 10, "Learning Pattern", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 11)
    pdf.multi_cell(0, 8, f"Primary Pattern: {pattern.get('primary_learning_pattern')}")
    pdf.multi_cell(0, 8, f"Confidence: {pattern.get('confidence_level')}")
    pdf.multi_cell(0, 8, f"Recommended Practice: {pattern.get('recommended_practice')}")
    
    return pdf.output()

def generate_therapist_report(student_id: str, overview: dict, behavior: dict, kinematics: dict) -> bytes:
    pdf = ReportPDF(title="SIPSARA Clinical Progress Report (Therapist)")
    pdf.add_page()
    
    # Overview Section
    pdf.set_font("Helvetica", "B", 12)
    pdf.cell(0, 10, "Clinical Overview", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 11)
    
    confidence = overview.get("confidence", 0) * 100
    fatigue = overview.get("fatigue_score", 0)
    pattern = overview.get("primary_learning_pattern", "Unknown")
    
    pdf.cell(0, 8, f"Pattern Diagnostic Confidence: {confidence:.1f}%", new_x="LMARGIN", new_y="NEXT")
    pdf.cell(0, 8, f"Current Fatigue Score: {fatigue:.2f}", new_x="LMARGIN", new_y="NEXT")
    pdf.cell(0, 8, f"Identified Pattern: {pattern}", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(5)
    
    # Behavioral Section
    pdf.set_font("Helvetica", "B", 12)
    pdf.cell(0, 10, "Behavioral Indices", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 11)
    
    indices = behavior.get("learner_indices", {})
    for key, val in indices.items():
        pdf.cell(0, 8, f"{key.replace('_', ' ').title()}: {val}", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(5)
    
    # Kinematics Section
    pdf.set_font("Helvetica", "B", 12)
    pdf.cell(0, 10, "Kinematics Analysis", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 11)
    
    comp = kinematics.get("feature_comparison", {})
    for key, val in comp.items():
        pdf.cell(0, 8, f"{key.replace('_', ' ').title()}: {val}", new_x="LMARGIN", new_y="NEXT")
    
    return pdf.output()
