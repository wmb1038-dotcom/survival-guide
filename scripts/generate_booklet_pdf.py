import os
import re
from reportlab.lib import colors
from reportlab.lib.pagesizes import inch
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak, Frame, PageTemplate
from reportlab.lib.units import inch

# --- Configuration ---
INPUT_FILE = "POCKET_MED_BOOKLET.md"
OUTPUT_FILE = "SURVIVAL_MED_BOOKLET.pdf"
PAGE_WIDTH = 4 * inch
PAGE_HEIGHT = 6 * inch
MARGIN = 0.25 * inch
HEADER_TEXT = "PROPERTY OF THE BELL RESIDENCE - SURVIVAL PROTOCOL"

def draw_crop_marks(canvas, doc):
    """Draws faint crop marks at the corners of the 4x6 area."""
    canvas.saveState()
    canvas.setStrokeColor(colors.lightgrey)
    canvas.setLineWidth(0.5)
    
    # Corner length
    L = 0.2 * inch
    
    # Bottom Left
    canvas.line(0, 0, L, 0)
    canvas.line(0, 0, 0, L)
    
    # Top Left
    canvas.line(0, PAGE_HEIGHT, L, PAGE_HEIGHT)
    canvas.line(0, PAGE_HEIGHT, 0, PAGE_HEIGHT - L)
    
    # Top Right
    canvas.line(PAGE_WIDTH, PAGE_HEIGHT, PAGE_WIDTH - L, PAGE_HEIGHT)
    canvas.line(PAGE_WIDTH, PAGE_HEIGHT, PAGE_WIDTH, PAGE_HEIGHT - L)
    
    # Bottom Right
    canvas.line(PAGE_WIDTH, 0, PAGE_WIDTH - L, 0)
    canvas.line(PAGE_WIDTH, 0, PAGE_WIDTH, L)
    
    # Header
    canvas.setFont("Helvetica-Bold", 7)
    canvas.drawCentredString(PAGE_WIDTH/2.0, PAGE_HEIGHT - 0.15*inch, HEADER_TEXT)
    
    canvas.restoreState()

def generate_pdf():
    if not os.path.exists(INPUT_FILE):
        print(f"Error: {INPUT_FILE} not found.")
        return

    with open(INPUT_FILE, "r") as f:
        content = f.read()

    # Split content by page breaks
    pages_raw = content.split("--- PAGE BREAK ---")
    
    doc = SimpleDocTemplate(
        OUTPUT_FILE,
        pagesize=(PAGE_WIDTH, PAGE_HEIGHT),
        rightMargin=MARGIN,
        leftMargin=MARGIN,
        topMargin=MARGIN + 0.2*inch, # Extra space for header
        bottomMargin=MARGIN
    )

    styles = getSampleStyleSheet()
    
    # Custom Styles
    style_h3 = ParagraphStyle(
        'CustomH3',
        parent=styles['Heading3'],
        fontSize=10,
        leading=12,
        spaceAfter=6,
        textColor=colors.black,
        fontName='Helvetica-Bold'
    )
    
    style_body = ParagraphStyle(
        'CustomBody',
        parent=styles['Normal'],
        fontSize=8,
        leading=10,
        spaceAfter=4
    )
    
    style_action = ParagraphStyle(
        'ActionStep',
        parent=style_body,
        leftIndent=10,
        bulletIndent=0
    )

    elements = []

    for i, page_text in enumerate(pages_raw):
        lines = page_text.strip().split("\n")
        for line in lines:
            line = line.strip()
            if not line:
                continue
            
            # Simple Markdown Parsing
            if line.startswith("###"):
                text = line.replace("###", "").strip()
                elements.append(Paragraph(f"<b>{text}</b>", style_h3))
            elif line.startswith("**⚡ ACTION STEPS:**") or line.startswith("**⚠️ PREVENTION:**") or line.startswith("**🚩 RED FLAGS"):
                text = line.strip("*")
                elements.append(Paragraph(f"<b>{text}</b>", style_body))
            elif re.match(r"^\d+\.", line) or line.startswith("*"):
                # List items
                text = line.split(".", 1)[-1].strip() if "." in line else line.strip("*").strip()
                elements.append(Paragraph(f"• {text}", style_action))
            elif line.startswith("_"):
                # Note lines
                elements.append(Spacer(1, 4))
                elements.append(Paragraph("<font color='grey'>_______________________________________</font>", style_body))
            # Regular text - Escape & and handle bold
            text = line.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
            
            # Handle bold markdown **text** -> <b>text</b>
            # Use non-greedy match to find pairs of **
            text = re.sub(r"\*\*(.*?)\*\*", r"<b>\1</b>", text)
            
            elements.append(Paragraph(text, style_body))
        
        # Add Page Break if not the last page
        if i < len(pages_raw) - 1:
            elements.append(PageBreak())

    # Build PDF with crop marks and header on every page
    doc.build(elements, onLaterPages=draw_crop_marks, onFirstPage=draw_crop_marks)
    print(f"✓ PDF successfully generated: {OUTPUT_FILE}")

if __name__ == "__main__":
    generate_pdf()
