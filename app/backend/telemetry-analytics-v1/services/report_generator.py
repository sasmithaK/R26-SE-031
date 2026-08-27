from fpdf import FPDF
import datetime
from typing import Dict, Any, List

class ClinicalReportPDF(FPDF):
    def header(self):
        self.set_font('helvetica', 'B', 15)
        self.cell(0, 10, 'AdaptEdMind Clinical Analytics Report', border=0, new_x="LMARGIN", new_y="NEXT", align='C')
        self.ln(10)

    def footer(self):
        self.set_y(-15)
        self.set_font('helvetica', 'I', 8)
        self.cell(0, 10, f'Page {self.page_no()}/{{nb}}', align='C')

def generate_pdf_report(student_name: str, profile: Dict[str, Any], sessions: List[Dict[str, Any]]) -> bytes:
    pdf = ClinicalReportPDF()
    pdf.add_page()
    
    # 1. Student Details
    pdf.set_font('helvetica', 'B', 12)
    pdf.cell(0, 10, f'Student Name: {student_name}', new_x="LMARGIN", new_y="NEXT")
    date_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    pdf.cell(0, 10, f'Report Generated: {date_str}', new_x="LMARGIN", new_y="NEXT")
    pdf.ln(5)
    
    # 2. Cognitive Indices
    pdf.set_font('helvetica', 'B', 14)
    pdf.cell(0, 10, 'Cognitive Profile Scores (0-100)', new_x="LMARGIN", new_y="NEXT")
    pdf.set_font('helvetica', '', 11)
    indices = profile.get("cognitive_indices", {})
    for key, val in indices.items():
        name = key.replace('_', ' ').title()
        pdf.cell(0, 8, f'{name}: {val}', new_x="LMARGIN", new_y="NEXT")
    
    pdf.ln(5)
    
    # 3. Risk Assessment
    pdf.set_font('helvetica', 'B', 14)
    pdf.cell(0, 10, 'Risk Classification', new_x="LMARGIN", new_y="NEXT")
    pdf.set_font('helvetica', '', 11)
    risks = profile.get("risk_assessment", {})
    overall = risks.get("overall_risk", "Unknown")
    pdf.set_font('helvetica', 'B', 11)
    pdf.cell(0, 8, f'Overall Risk: {overall}', new_x="LMARGIN", new_y="NEXT")
    pdf.set_font('helvetica', '', 11)
    for key, val in risks.items():
        if key == "overall_risk": continue
        name = key.replace('_', ' ').title()
        pdf.cell(0, 8, f'{name}: {val}', new_x="LMARGIN", new_y="NEXT")
        
    pdf.ln(10)
    
    # 4. Interventions
    pdf.add_page()
    pdf.set_font('helvetica', 'B', 14)
    pdf.cell(0, 10, 'Clinical Interventions & Recommendations', new_x="LMARGIN", new_y="NEXT")
    pdf.set_font('helvetica', '', 11)
    interventions = profile.get("recommended_interventions", [])
    for idx, inv in enumerate(interventions, 1):
        pdf.multi_cell(0, 8, f"{idx}. {inv}", new_x="LMARGIN", new_y="NEXT")
        pdf.ln(2)
        
    pdf.ln(10)
    
    # 5. Activity Breakdown
    pdf.add_page()
    pdf.set_font('helvetica', 'B', 14)
    pdf.cell(0, 10, 'Activity Performance Breakdown', new_x="LMARGIN", new_y="NEXT")
    
    # Group sessions by activity
    activity_stats = {}
    for s in sessions:
        for e in s.get("events", []):
            aname = e.get("activity_name", "Unknown")
            if aname not in activity_stats:
                activity_stats[aname] = {"attempts": 0, "total_score": 0, "total_hesitation": 0}
            activity_stats[aname]["attempts"] += 1
            activity_stats[aname]["total_score"] += e.get("score", 0)
            activity_stats[aname]["total_hesitation"] += e.get("hesitation_count", 0)
            
    pdf.set_font('helvetica', 'B', 10)
    
    # Table header
    # Usable width = 210 - 20 (margins) = 190. Let's do 4 columns
    pdf.cell(60, 10, 'Activity', border=1)
    pdf.cell(30, 10, 'Attempts', border=1)
    pdf.cell(50, 10, 'Avg Accuracy (%)', border=1)
    pdf.cell(50, 10, 'Avg Hesitation', border=1, new_x="LMARGIN", new_y="NEXT")
    
    pdf.set_font('helvetica', '', 10)
    for aname, stats in activity_stats.items():
        attempts = stats["attempts"]
        avg_score = (stats["total_score"] / attempts) * 100 if attempts > 0 else 0
        avg_hes = stats["total_hesitation"] / attempts if attempts > 0 else 0
        
        pdf.cell(60, 10, aname.replace('_', ' ').title(), border=1)
        pdf.cell(30, 10, str(attempts), border=1)
        pdf.cell(50, 10, f"{avg_score:.1f}%", border=1)
        pdf.cell(50, 10, f"{avg_hes:.1f}", border=1, new_x="LMARGIN", new_y="NEXT")
        
    return bytes(pdf.output())
