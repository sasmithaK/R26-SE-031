import PyPDF2
import re

def analyze_rubric(pdf_path):
    print(f"Analyzing rubric at: {pdf_path}\n")
    try:
        with open(pdf_path, "rb") as file:
            reader = PyPDF2.PdfReader(file)
            text = ""
            for page in reader.pages:
                text += page.extract_text() + "\n"
                
        print("=== MARKING RUBRIC FINISHING POINTS (EXCELLENT CATEGORY) ===")
        print("To achieve the maximum marks (75-100), ensure the following criteria are met:\n")
        
        # Extracted insights based on the Progress Presentation 1 Mark Sheet
        finishing_points = {
            "Proven gap/Creative Solution (10%)": [
                "Problem Definition (30%): The identified problem is clearly presented referring to the current implementation.",
                "Proof of Concept (70%): The current implementation clearly demonstrates proof of concept of the proposed solution."
            ],
            "Capability in applying knowledge (25%)": [
                "Application of key pillars (30%): The current implementation clearly shows that the most appropriate research/knowledge areas have been identified and are being applied.",
                "Application of technologies (70%): Technologies being applied are well presented and in-depth knowledge of technologies is demonstrated."
            ],
            "Solution Implementation (40%)": [
                "Design Excellence (20%): Demonstrated excellent design features.",
                "Completion of prototype (30%): Work completed is satisfactory (approximately 50% where applicable) and no identifiable delay as per the project plan. **CRITICAL FOR 2-WEEK DEADLINE**",
                "Standards/Best Practices (20%): Application of appropriate standards/best practices is well demonstrated and clear evidence are present.",
                "User/Functional Requirements (20%): Comprehensive and realistic user requirements and the functional requirements well described.",
                "Risk Mitigation (10%): Project risks and appropriate measures have been clearly identified. Corrective actions are being executed or a comprehensive execution plan exists."
            ],
            "Effective Communication (15%)": [
                "Communication Skills (60%): Excellent structure and smooth flow of the presentation. Excellent performance at the Q&A session.",
                "Presentation Skills (40%): Excellent stage presence, body language, eye contact, voice projection and clarity. Commendable use of visual aids. Excellent time management."
            ],
            "Commercialization (10%)": [
                "Ability of commercialization (100%): Demonstrated sound evidence to prove business potential highlighting many achievable user benefits."
            ]
        }
        
        for category, points in finishing_points.items():
            print(f"[{category}]")
            for point in points:
                print(f"  - {point}")
            print()
            
        print("=== SUMMARY FOR 50% COMPLETION MILESTONE ===")
        print("To meet the 50% completion requirement for the upcoming evaluation:")
        print("1. Complete the core architecture setup for all 4 components.")
        print("2. Implement the 'Proof of Concept' for the Reading Strain Index (RSI) calculation and integrations.")
        print("3. Ensure UI components for AVLI and Intervention Engine are at least draft-ready.")
        print("4. Apply best practices (e.g., proper git commits, clean code, documentation) as it holds 20% of the implementation marks.")
        print("5. Keep a clear execution plan for the remaining 50%.")
            
    except Exception as e:
        print(f"Failed to read the rubric: {e}")

if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1:
        analyze_rubric(sys.argv[1])
    else:
        # Default path
        analyze_rubric(r"d:\01 ACADEMIA\4th Year\Y4.S1\RP-IT4010\00 - Implementation\R26-SE-031\docs\academic\marking rubric\Rubric-PP-1.pdf")
