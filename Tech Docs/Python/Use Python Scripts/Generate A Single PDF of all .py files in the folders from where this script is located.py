from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import A4
import glob
import os

def wrap_code_line(line, max_width, pdf_canvas, font_name, font_size):
    # Get indentation (leading spaces or tabs)
    indent = ''
    for char in line:
        if char in (' ', '\t'):
            indent += char
        else:
            break

    max_line_width = max_width
    wrapped_lines = []
    remaining_line = line.rstrip('\n')
    
    while pdf_canvas.stringWidth(remaining_line, font_name, font_size) > max_line_width:
        cut_pos = len(remaining_line)
        while pdf_canvas.stringWidth(remaining_line[:cut_pos], font_name, font_size) > max_line_width:
            cut_pos -= 1
        
        wrapped_lines.append(remaining_line[:cut_pos])
        remaining_line = indent + remaining_line[cut_pos:].lstrip()
        
    wrapped_lines.append(remaining_line)
    return wrapped_lines

pdf = canvas.Canvas("all_scripts_indented_wrapped.pdf", pagesize=A4)
width, height = A4
left_margin = 30
right_margin = 30
usable_width = width - left_margin - right_margin

font_name = "Courier"
font_size = 10
line_height = 12

pdf.setFont(font_name, font_size)

for file in glob.glob("*.py"):
    # Reset font before drawing header
    pdf.setFont(font_name, font_size)
    pdf.drawString(left_margin, height - 30, f"File: {os.path.basename(file)}")
    y = height - 50
    with open(file, "r", encoding="utf-8") as f:
        for line in f:
            wrapped_lines = wrap_code_line(line.rstrip('\n'), usable_width, pdf, font_name, font_size)
            for wline in wrapped_lines:
                if y < 40:
                    pdf.showPage()
                    pdf.setFont(font_name, font_size)  # Reset font after page break
                    y = height - 40
                pdf.setFont(font_name, font_size)  # Reset font before each line (optional but safe)
                pdf.drawString(left_margin, y, wline)
                y -= line_height
    pdf.showPage()
    pdf.setFont(font_name, font_size)  # Reset font after file page break

pdf.save()
print("✅ PDF created with wrapped lines and preserved indentation!")
