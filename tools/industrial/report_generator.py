#!/usr/bin/env python3
"""
report_generator.py — Generate PDF reports from agent Markdown outputs.

Takes Markdown input (from maintenance-predictor, log-analyst, forge reviews),
converts to styled HTML then PDF (via weasyprint). Falls back to HTML if
weasyprint is not available.

Usage:
    python3 report_generator.py --input report.md --output report.pdf --title "Rapport Maintenance"
    python3 report_generator.py --input report.md --output report.html --format html
    python3 report_generator.py --input report.md --title "Weekly Report" --company "ACME Corp"
    cat analysis.md | python3 report_generator.py --output report.pdf --title "Analysis"

Part of Kill_LIFE tools/industrial — usable standalone for any project.
"""

from __future__ import annotations

import argparse
import html
import logging
import os
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Optional

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Markdown to HTML conversion (standalone, no dependencies)
# ---------------------------------------------------------------------------

def _md_to_html(md_text: str) -> str:
    """Convert Markdown to HTML. Handles headers, lists, code, tables, bold, italic, links."""
    lines = md_text.split("\n")
    html_parts: list[str] = []
    in_code_block = False
    in_table = False
    in_list = False
    list_type = ""  # "ul" or "ol"

    for line in lines:
        stripped = line.strip()

        # Code blocks
        if stripped.startswith("```"):
            if in_code_block:
                html_parts.append("</code></pre>")
                in_code_block = False
            else:
                lang = stripped[3:].strip()
                html_parts.append(f'<pre><code class="language-{html.escape(lang)}">' if lang else "<pre><code>")
                in_code_block = True
            continue

        if in_code_block:
            html_parts.append(html.escape(line))
            continue

        # Close table if we leave it
        if in_table and not stripped.startswith("|"):
            html_parts.append("</tbody></table>")
            in_table = False

        # Close list if we leave it
        if in_list and not stripped.startswith(("- ", "* ", "  - ", "  * ")) and not re.match(r"^\d+\.\s", stripped):
            html_parts.append(f"</{list_type}>")
            in_list = False

        # Empty line
        if not stripped:
            if in_list:
                html_parts.append(f"</{list_type}>")
                in_list = False
            html_parts.append("")
            continue

        # Horizontal rule
        if stripped in ("---", "***", "___"):
            html_parts.append("<hr>")
            continue

        # Headers
        m_header = re.match(r"^(#{1,6})\s+(.*)", stripped)
        if m_header:
            level = len(m_header.group(1))
            text = _inline_md(m_header.group(2))
            html_parts.append(f"<h{level}>{text}</h{level}>")
            continue

        # Table
        if stripped.startswith("|"):
            cells = [c.strip() for c in stripped.split("|")[1:-1]]
            if all(re.match(r"^[-:]+$", c) for c in cells):
                # Separator row — skip (header already emitted)
                continue
            if not in_table:
                html_parts.append('<table class="report-table"><thead><tr>')
                for cell in cells:
                    html_parts.append(f"<th>{_inline_md(cell)}</th>")
                html_parts.append("</tr></thead><tbody>")
                in_table = True
            else:
                html_parts.append("<tr>")
                for cell in cells:
                    html_parts.append(f"<td>{_inline_md(cell)}</td>")
                html_parts.append("</tr>")
            continue

        # Unordered list
        m_ul = re.match(r"^(\s*)[-*]\s+(.*)", stripped)
        if m_ul:
            if not in_list:
                list_type = "ul"
                in_list = True
                html_parts.append("<ul>")
            html_parts.append(f"<li>{_inline_md(m_ul.group(2))}</li>")
            continue

        # Ordered list
        m_ol = re.match(r"^(\s*)\d+\.\s+(.*)", stripped)
        if m_ol:
            if not in_list:
                list_type = "ol"
                in_list = True
                html_parts.append("<ol>")
            html_parts.append(f"<li>{_inline_md(m_ol.group(2))}</li>")
            continue

        # Blockquote
        if stripped.startswith(">"):
            text = _inline_md(stripped.lstrip("> "))
            html_parts.append(f"<blockquote>{text}</blockquote>")
            continue

        # Paragraph
        html_parts.append(f"<p>{_inline_md(stripped)}</p>")

    # Close open blocks
    if in_code_block:
        html_parts.append("</code></pre>")
    if in_table:
        html_parts.append("</tbody></table>")
    if in_list:
        html_parts.append(f"</{list_type}>")

    return "\n".join(html_parts)


def _inline_md(text: str) -> str:
    """Convert inline Markdown: bold, italic, code, links."""
    # Escape HTML first (but preserve our tags)
    text = html.escape(text)
    # Code
    text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)
    # Bold + italic
    text = re.sub(r"\*\*\*(.+?)\*\*\*", r"<strong><em>\1</em></strong>", text)
    # Bold
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    # Italic
    text = re.sub(r"\*(.+?)\*", r"<em>\1</em>", text)
    # Links
    text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', text)
    return text


# ---------------------------------------------------------------------------
# HTML template
# ---------------------------------------------------------------------------

CSS = """
@page {
    size: A4;
    margin: 2cm;
    @top-center {
        content: string(title);
        font-size: 9pt;
        color: #666;
    }
    @bottom-center {
        content: "Page " counter(page) " / " counter(pages);
        font-size: 9pt;
        color: #666;
    }
}

body {
    font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;
    font-size: 11pt;
    line-height: 1.5;
    color: #333;
    max-width: 210mm;
    margin: 0 auto;
    padding: 1em;
}

.report-header {
    border-bottom: 3px solid #2c3e50;
    padding-bottom: 1em;
    margin-bottom: 2em;
}

.report-header h1 {
    string-set: title content();
    color: #2c3e50;
    font-size: 22pt;
    margin: 0;
}

.report-header .meta {
    color: #666;
    font-size: 10pt;
    margin-top: 0.5em;
}

.logo-placeholder {
    float: right;
    width: 80px;
    height: 80px;
    border: 1px dashed #ccc;
    text-align: center;
    line-height: 80px;
    font-size: 9pt;
    color: #999;
}

h1 { color: #2c3e50; font-size: 18pt; margin-top: 1.5em; page-break-after: avoid; }
h2 { color: #34495e; font-size: 14pt; margin-top: 1.2em; page-break-after: avoid; }
h3 { color: #4a6274; font-size: 12pt; margin-top: 1em; page-break-after: avoid; }

.report-table {
    width: 100%;
    border-collapse: collapse;
    margin: 1em 0;
    font-size: 10pt;
}

.report-table th {
    background-color: #2c3e50;
    color: white;
    padding: 8px 10px;
    text-align: left;
}

.report-table td {
    border-bottom: 1px solid #ddd;
    padding: 6px 10px;
}

.report-table tr:nth-child(even) td {
    background-color: #f8f9fa;
}

blockquote {
    border-left: 4px solid #2c3e50;
    margin: 1em 0;
    padding: 0.5em 1em;
    background-color: #f8f9fa;
    color: #555;
}

code {
    background-color: #f0f0f0;
    padding: 2px 5px;
    border-radius: 3px;
    font-size: 10pt;
    font-family: 'Courier New', monospace;
}

pre {
    background-color: #f5f5f5;
    border: 1px solid #ddd;
    border-radius: 4px;
    padding: 1em;
    overflow-x: auto;
    font-size: 9pt;
    page-break-inside: avoid;
}

pre code {
    background: none;
    padding: 0;
}

hr {
    border: none;
    border-top: 1px solid #ddd;
    margin: 1.5em 0;
}

ul, ol { padding-left: 1.5em; }
li { margin-bottom: 0.3em; }

.report-footer {
    border-top: 1px solid #ddd;
    margin-top: 3em;
    padding-top: 1em;
    font-size: 9pt;
    color: #999;
    text-align: center;
}
"""


def build_html_report(
    body_html: str,
    title: str,
    company: str = "",
    date_str: str = "",
    logo_path: Optional[str] = None,
) -> str:
    """Wrap body HTML in a styled report template."""
    if not date_str:
        date_str = datetime.now().strftime("%Y-%m-%d %H:%M")

    logo_html = ""
    if logo_path and Path(logo_path).exists():
        logo_html = f'<img src="{html.escape(logo_path)}" alt="Logo" style="float:right; max-height:80px;">'
    else:
        logo_html = '<div class="logo-placeholder">LOGO</div>'

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{html.escape(title)}</title>
    <style>{CSS}</style>
</head>
<body>
    <div class="report-header">
        {logo_html}
        <h1>{html.escape(title)}</h1>
        <div class="meta">
            {html.escape(company) + ' &mdash; ' if company else ''}
            {html.escape(date_str)}
        </div>
    </div>

    {body_html}

    <div class="report-footer">
        Generated by Kill_LIFE Industrial Report Generator &mdash; {html.escape(date_str)}
    </div>
</body>
</html>
"""


# ---------------------------------------------------------------------------
# PDF generation
# ---------------------------------------------------------------------------

def html_to_pdf_weasyprint(html_content: str, output_path: str) -> None:
    """Convert HTML to PDF using weasyprint."""
    from weasyprint import HTML  # type: ignore
    HTML(string=html_content).write_pdf(output_path)


def html_to_pdf_wkhtmltopdf(html_content: str, output_path: str) -> None:
    """Convert HTML to PDF using wkhtmltopdf system command."""
    import subprocess
    import tempfile
    with tempfile.NamedTemporaryFile(mode="w", suffix=".html", delete=False) as f:
        f.write(html_content)
        tmp_html = f.name
    try:
        result = subprocess.run(
            ["wkhtmltopdf", "--quiet", "--page-size", "A4", "--margin-top", "20mm",
             "--margin-bottom", "20mm", "--margin-left", "20mm", "--margin-right", "20mm",
             tmp_html, output_path],
            capture_output=True, text=True, timeout=60,
        )
        if result.returncode != 0:
            raise RuntimeError(f"wkhtmltopdf failed: {result.stderr}")
    finally:
        os.unlink(tmp_html)


def generate_pdf(html_content: str, output_path: str) -> bool:
    """Try to generate PDF, return True on success. Falls back to HTML if PDF fails."""
    errors: list[str] = []
    for name, func in [
        ("weasyprint", html_to_pdf_weasyprint),
        ("wkhtmltopdf", html_to_pdf_wkhtmltopdf),
    ]:
        try:
            func(html_content, output_path)
            logger.info("PDF generated with %s", name)
            return True
        except ImportError:
            errors.append(f"{name}: not installed")
        except FileNotFoundError:
            errors.append(f"{name}: command not found")
        except Exception as exc:
            errors.append(f"{name}: {exc}")

    logger.warning("PDF generation failed: %s", "; ".join(errors))
    return False


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="report_generator",
        description="Generate styled PDF/HTML reports from Markdown. "
                    "Converts maintenance reports, log analyses, and forge reviews "
                    "to professional documents with header, styling, and page layout.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""Examples:
  python3 report_generator.py --input report.md --output report.pdf --title "Rapport Maintenance"
  python3 report_generator.py --input report.md --output report.html --format html
  python3 report_generator.py --input report.md --company "ACME Corp" --logo logo.png
  cat analysis.md | python3 report_generator.py --output report.pdf --title "Analysis"

PDF generation requires weasyprint or wkhtmltopdf. If neither is available,
the tool falls back to HTML output automatically.

Install weasyprint: pip install weasyprint
""",
    )
    parser.add_argument("--input", "-i", help="Input Markdown file (reads stdin if omitted)")
    parser.add_argument("--output", "-o", required=True, help="Output file path (.pdf or .html)")
    parser.add_argument("--title", "-t", default="Report", help="Report title (default: 'Report')")
    parser.add_argument("--company", "-c", default="", help="Company name for header")
    parser.add_argument("--date", default="", help="Report date (default: now)")
    parser.add_argument("--logo", default=None, help="Path to logo image file")
    parser.add_argument("--format", choices=["pdf", "html", "auto"], default="auto",
                        help="Output format. 'auto' detects from file extension (default: auto)")
    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")

    # Read Markdown input
    if args.input:
        p = Path(args.input)
        if not p.exists():
            logger.error("Input file not found: %s", args.input)
            sys.exit(1)
        md_text = p.read_text(encoding="utf-8")
    else:
        if sys.stdin.isatty():
            logger.error("No input file specified and stdin is a terminal. Use --input or pipe Markdown.")
            sys.exit(1)
        md_text = sys.stdin.read()

    if not md_text.strip():
        logger.error("Input is empty")
        sys.exit(1)

    logger.info("Input: %d chars of Markdown", len(md_text))

    # Convert Markdown to HTML body
    body_html = _md_to_html(md_text)

    # Build full HTML report
    full_html = build_html_report(
        body_html=body_html,
        title=args.title,
        company=args.company,
        date_str=args.date,
        logo_path=args.logo,
    )

    # Determine output format
    out_path = Path(args.output)
    if args.format == "auto":
        fmt = "pdf" if out_path.suffix.lower() == ".pdf" else "html"
    else:
        fmt = args.format

    if fmt == "html":
        out_path.write_text(full_html, encoding="utf-8")
        logger.info("HTML report written to %s", out_path)
    elif fmt == "pdf":
        success = generate_pdf(full_html, str(out_path))
        if success:
            logger.info("PDF report written to %s", out_path)
        else:
            # Fallback to HTML
            html_path = out_path.with_suffix(".html")
            html_path.write_text(full_html, encoding="utf-8")
            logger.warning(
                "PDF generation unavailable. HTML fallback written to %s\n"
                "Install weasyprint for PDF: pip install weasyprint",
                html_path,
            )


if __name__ == "__main__":
    main()
