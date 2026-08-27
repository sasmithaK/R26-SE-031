import io
import os
import requests
from datetime import datetime
from fpdf import FPDF

FONT_URL = "https://github.com/googlefonts/noto-fonts/raw/main/hinted/ttf/NotoSansSinhala/NotoSansSinhala-Regular.ttf"
FONT_PATH = "NotoSansSinhala-Regular.ttf"

# Mapping the exact 42 questions from the frontend Dart file
ASSESSMENT_QUESTIONS = {
    'basic': [
        'ඔබේ දරුවාට වම සහ දකුණ හඳුනාගැනීමට අපහසුද?',
        'කියවීමේදී ඔබේ දරුවා ඉක්මනින්ම මහන්සි වනවාද?',
        'කියවීමේදී ඔබේ දරුවාගේ අවධානය නිතර වෙනත් දේවල් වෙත යොමුවනවාද?',
        'කියවීමේදී ඔබේ දරුවා නිතර වැරදි කරනවාද?',
        'එක කාර්යයක් කෙරෙහි දිගු වේලාවක් අවධානය පවත්වා ගැනීමට ඔබේ දරුවාට අපහසුද?',
        'පුද්ගලයන්ගේ නම් මතක තබා ගැනීමට ඔබේ දරුවාට අපහසුද?',
        'කතා කරන විට වචන නිවැරදිව උච්චාරණය කිරීමට ඔබේ දරුවාට අපහසුද?',
        'දන්නා කෙටි වචන ලියන ආකාරය සමහර විට ඔබේ දරුවාට අමතක වනවාද?',
        'කලින් නොදුටු වචන නිවැරදිව ලිවීමට ඔබේ දරුවාට අපහසුද?',
        'කලින් නොකියවූ වචන කියවීමට ඔබේ දරුවාට අපහසුද?',
        'වචනයක තේරුම දැන සිටියත් එය ලිවීමට ඔබේ දරුවාට අපහසුද?',
        'කියවීමේදී සමහර වචන ළඟ නතර වී නැවත උත්සාහ කිරීමට ඔබේ දරුවාට සිදුවනවාද?',
        'කියවීමේදී ඔබේ දරුවාගේ ඇස් හොඳින් එකට ක්‍රියා නොකරන බවක් පෙනෙනවාද?',
        'කියවීමේදී වචන හෙලවෙනවා, බොඳව පෙනෙනවා හෝ අවධානය යොමු කිරීමට අපහසු බව ඔබේ දරුවා පවසනවාද?'
    ],
    'reading': [
        'කුඩා කාලයේ සිට අකුරු හා ශබ්ද අතර සම්බන්ධතාවය (Phonics) ඉගෙන ගැනීමට ඔබේ දරුවාට අපහසුතා තිබුණාද?',
        'ශබ්ද නඟා කියවීමේදී ඔබේ දරුවා නිතර වැරදි කරනවාද?',
        'ලියා ඇති දේ නැවත නැවත කියවීමකින් තොරව තේරුම් ගැනීමට ඔබේ දරුවාට අපහසුද?',
        'ඔබේ දරුවාගේ කියවීමේ වේගය මන්දගාමීද?',
        'කියවීමේදී වචන අතහැර යාම හෝ වැරදි ලෙස කියවීම සිදුවනවාද?',
        'කියවීමේදී කියවමින් සිටි ස්ථානය අහිමි කරගැනීම ඔබේ දරුවාට සිදුවනවාද?',
        'ලිපියක් ඉක්මනින් පිරික්සා අවශ්‍ය තොරතුරු සොයා ගැනීමට ඔබේ දරුවාට අපහසුද?',
        'කියවීමේදී ඔබේ දරුවා ඉක්මනින් අවධානය වෙනතකට යොමුවනවාද?',
        'කියවීමේදී වචන හෙලවෙනවා, එකට මිශ්‍ර වනවා හෝ වෙනස් ලෙස පෙනෙනවා කියා ඔබේ දරුවා පවසනවාද?',
        'සුදු කඩදාසියක් හෝ සුදු පුවරුවක් දෙස බලන විට ඇස්වල අපහසුතාවයක් ඔබේ දරුවාට දැනෙනවාද?'
    ],
    'writing': [
        'ඔබේ දරුවාට වචන නිවැරදිව අක්ෂර වින්‍යාස කිරීම දිගින් දිගටම අපහසුද?',
        'සමාන කෙටි වචන එකිනෙකට පටලවා ගැනීම ඔබේ දරුවාට සිදුවනවාද?',
        'ලියන විට, විශේෂයෙන් පීඩනයක් යටතේ, වචන අතහැර යාම සිදුවනවාද?',
        'ඔබේ දරුවාගේ අත් අකුරු පැහැදිලි නොවීම හෝ ලිවීමේ වේගය මන්දගාමී වීම පෙනෙනවාද?',
        'කතා කිරීමේ හැකියාවට සාපේක්ෂව ලිවීමේ හැකියාව අඩු බව පෙනෙනවාද?',
        'කතා කිරීමේදී තම අදහස් හොඳින් ප්‍රකාශ කළද, එම අදහස් ලිවීමේදී ප්‍රකාශ කිරීමට ඔබේ දරුවාට අපහසුද?'
    ],
    'other': [
        'කුඩා කාලයේදී කථන හෝ භාෂා සංවර්ධනයේ ප්‍රමාදයක් තිබුණාද?',
        'කුඩා කාලයේදී මැද කනේ ආසාදන (Glue Ear / Otitis Media) ඇති වී තිබුණාද?',
        'ඇදුම, එක්සීමා වැනි ප්‍රතිශක්තිකරණ පද්ධතියට සම්බන්ධ රෝග තිබුණාද?',
        'හොඳින් කතා කළද, අදහස් පිළිවෙළකට ප්‍රකාශ කිරීමට ඔබේ දරුවාට අපහසුද?',
        'අවශ්‍ය වචනය මතකයට ගන්නා විට ප්‍රමාද වීම හෝ වචන වැරදි ලෙස උච්චාරණය කිරීම සිදුවනවාද?',
        'ප්‍රශ්නයක් ඇසූ විට, එය තේරුම් ගෙන පිළිතුරු දීමට සාමාන්‍යයෙන් වඩා වැඩි කාලයක් ගන්නවාද?',
        'ඔබේ දරුවාට මතක තබා ගැනීමේ අපහසුතා තිබෙනවාද?',
        'ගණිත ගණනය කිරීම්, සංඛ්‍යා පිටපත් කිරීම හෝ ගුණක වගු මතක තබා ගැනීමේ අපහසුතා තිබෙනවාද?',
        'ADHD හෝ Dyspraxia වැනි වෙනත් සංවර්ධන සම්බන්ධ තත්ත්වයක් හඳුනාගෙන තිබෙනවාද?',
        'තමන්ට අපහසු තත්ත්වයන්ට මුහුණ දෙන විට අධික කනස්සල්ලක් හෝ භීතියක් පෙන්වනවාද?',
        'කාලය කළමනාකරණය කිරීම, පිළිවෙළට වැඩ කිරීම, හෝ අවකාශය පිළිබඳ අවබෝධය සම්බන්ධ අපහසුතා තිබෙනවාද?',
        'සාමාන්‍ය බුද්ධිමය හැකියාව තිබුණද, විශේෂයෙන් කියවීම හා ලිවීම සම්බන්ධ පාසල් කාර්යසාධනය බලාපොරොත්තු වූ මට්ටමට නොපැමිණෙන බව පෙනෙනවාද?'
    ]
}

CATEGORY_TITLES = {
    'basic': 'Basic Dyslexia Assessment',
    'reading': 'Reading and Visual Perception',
    'writing': 'Writing Difficulties',
    'other': 'Other Related Difficulties'
}

def ensure_font_exists():
    if not os.path.exists(FONT_PATH):
        try:
            r = requests.get(FONT_URL, allow_redirects=True)
            with open(FONT_PATH, 'wb') as f:
                f.write(r.content)
        except Exception:
            pass

class AssessmentPDF(FPDF):
    def header(self):
        self.set_font('Helvetica', 'B', 24)
        self.set_text_color(26, 35, 126) # calmBlue
        self.cell(0, 15, 'Comprehensive Assessment Report', border=0, ln=1, align='C')
        self.ln(5)

    def footer(self):
        self.set_y(-15)
        self.set_font('Helvetica', 'I', 8)
        self.set_text_color(128, 128, 128)
        self.cell(0, 10, f'Page {self.page_no()}', 0, 0, 'C')

def generate_assessment_report(student: dict) -> bytes:
    ensure_font_exists()
    pdf = AssessmentPDF()
    pdf.add_page()
    
    # Check if font downloaded successfully
    has_sinhala = False
    if os.path.exists(FONT_PATH):
        pdf.add_font('Sinhala', '', FONT_PATH, uni=True)
        has_sinhala = True

    # Header details
    pdf.set_font('Helvetica', '', 12)
    pdf.set_text_color(0, 0, 0)
    pdf.cell(0, 8, f"Student Name: {student.get('first_name', '')} {student.get('last_name', '')}", ln=1)
    pdf.cell(0, 8, f"Age: {student.get('age', 'N/A')}", ln=1)
    pdf.cell(0, 8, f"Report Date: {datetime.now().strftime('%Y-%m-%d')}", ln=1)
    
    comp_results = student.get('comprehensive_assessment_results', {})
    
    # Calculate Total Score
    total_yes = 0
    total_q = 0
    for cat, results in comp_results.items():
        total_q += len(results)
        total_yes += sum([1 for r in results if r is True])
        
    score_percentage = (total_yes / total_q * 100) if total_q > 0 else 0
    pdf.ln(5)
    pdf.set_font('Helvetica', 'B', 14)
    pdf.cell(0, 10, f"Overall Risk Score: {total_yes} / {total_q} ({score_percentage:.1f}%)", ln=1)
    pdf.ln(5)

    # Print Questions
    for cat in ['basic', 'reading', 'writing', 'other']:
        if cat in comp_results and cat in ASSESSMENT_QUESTIONS:
            answers = comp_results[cat]
            questions = ASSESSMENT_QUESTIONS[cat]
            
            pdf.set_font('Helvetica', 'B', 14)
            pdf.set_text_color(40, 53, 147)
            pdf.cell(0, 10, CATEGORY_TITLES.get(cat, cat.capitalize()), ln=1)
            pdf.ln(2)
            
            for i, ans in enumerate(answers):
                if i < len(questions):
                    question_text = questions[i]
                    answer_text = "Yes" if ans else "No"
                    
                    pdf.set_font('Helvetica', 'B', 10)
                    if ans:
                        pdf.set_text_color(220, 53, 69) # Red for Yes
                    else:
                        pdf.set_text_color(40, 167, 69) # Green for No
                    
                    pdf.cell(15, 6, answer_text, border=0)
                    
                    if has_sinhala:
                        pdf.set_font('Sinhala', '', 11)
                        pdf.set_text_color(0, 0, 0)
                        pdf.multi_cell(0, 6, question_text, border=0)
                    else:
                        pdf.set_font('Helvetica', '', 11)
                        pdf.set_text_color(0, 0, 0)
                        pdf.multi_cell(0, 6, "Sinhala font not available to render question text.", border=0)
                    
                    pdf.ln(2)
            
            pdf.ln(5)

    return pdf.output(dest='S').encode('latin1')
