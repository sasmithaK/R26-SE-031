"""Parent-facing learning summary PDF.

Plain-language observations only: no pattern names, probabilities, indices or
diagnostic wording. Missing measurements are written as "not recorded yet",
never as zero or a default value.
"""
from datetime import datetime, timezone

from fpdf import FPDF


def _safe(text) -> str:
    """fpdf core fonts are Latin-1; replace characters they cannot draw."""
    return str(text if text is not None else "").encode("latin-1", "replace").decode("latin-1")


def _pct(value) -> str:
    return "not recorded yet" if value is None else f"{round(value * 100)}%"


class _ParentPDF(FPDF):
    def header(self):
        self.set_font("Helvetica", "B", 16)
        self.cell(0, 10, "Sipsara - Learning Summary", align="C", new_x="LMARGIN", new_y="NEXT")
        self.set_font("Helvetica", "", 10)
        self.cell(0, 6, f"Generated {datetime.now(timezone.utc).strftime('%d %b %Y')}",
                  align="C", new_x="LMARGIN", new_y="NEXT")
        self.ln(4)

    def footer(self):
        self.set_y(-18)
        self.set_font("Helvetica", "I", 8)
        self.multi_cell(0, 4, "These are learning observations from app activities. They are not marks, "
                              "rankings or a diagnosis. Please discuss any questions with your child's teacher "
                              "or a professional.", align="C")


def generate_parent_learning_report(data: dict) -> bytes:
    pdf = _ParentPDF()
    pdf.set_auto_page_break(auto=True, margin=22)
    pdf.add_page()

    def heading(text):
        pdf.ln(3)
        pdf.set_font("Helvetica", "B", 13)
        pdf.cell(0, 8, _safe(text), new_x="LMARGIN", new_y="NEXT")
        pdf.set_font("Helvetica", "", 11)

    def line(text):
        pdf.multi_cell(0, 6, _safe(text), new_x="LMARGIN", new_y="NEXT")

    pdf.set_font("Helvetica", "B", 12)
    line(f"Child: {data.get('child_name') or 'Your child'}   |   {data.get('period', '')}")
    pdf.set_font("Helvetica", "", 11)

    heading("Practice")
    line(f"Practice sessions: {data.get('sessions', 0)}"
         + (f" ({data['sessions_ended_early']} ended before a round was finished)" if data.get("sessions_ended_early") else ""))
    line(f"Completed activity rounds: {data.get('completed_rounds', 0)}")
    minutes = data.get("minutes")
    line(f"Practice time: {'not recorded yet' if minutes is None else f'{minutes} minutes'}")
    line(f"Last activity: {data.get('last_active') or 'not recorded yet'}")
    line(f"Correct on the first try: {_pct(data.get('first_try_accuracy'))}")
    seconds = data.get("typical_answer_seconds")
    line(f"Typical time to first touch: {'not recorded yet' if seconds is None else f'{seconds:.1f} seconds'}")

    heading("Activities")
    activities = data.get("activities") or []
    if not activities:
        line("No activities recorded in this period.")
    else:
        pdf.set_font("Helvetica", "B", 10)
        widths = (90, 30, 35, 35)
        for width, title in zip(widths, ("Activity", "Responses", "First try", "Needed another try")):
            pdf.cell(width, 7, title, border=1)
        pdf.ln()
        pdf.set_font("Helvetica", "", 10)
        for row in activities:
            pdf.cell(widths[0], 7, _safe(row.get("name"))[:48], border=1)
            pdf.cell(widths[1], 7, str(row.get("responses", 0)), border=1)
            pdf.cell(widths[2], 7, _pct(row.get("first_try")), border=1)
            pdf.cell(widths[3], 7, _pct(row.get("retry")), border=1)
            pdf.ln()

    heading("Reading aloud")
    recordings = data.get("recordings", 0)
    if not recordings:
        line("No reading recordings yet. Try the reading activities (Skills 5 and 6) together.")
    else:
        line(f"Recordings: {recordings}, clear enough to measure: {data.get('usable_recordings', 0)}")
        line(f"Letters read as expected (typical recording): {_pct(data.get('reading_letters'))}")

    heading("Shared with your therapist")
    line(f"Questionnaire sections completed: {data.get('questionnaire_done', 0)} of {data.get('questionnaire_total', 4)}")
    line("A connected professional has reviewed the combined learning summary."
         if data.get("reviewed") else "Not yet reviewed by a connected professional.")

    if data.get("practice_tip"):
        heading("Try together at home")
        line(data["practice_tip"])

    return bytes(pdf.output())
