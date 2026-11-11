#!/usr/bin/env python3
"""book_style.py — the book's page genre, taken from the nasa-handbook skill's own template.

The skill's rule: a builder that writes its own CSS produces a costume, not the genre
("three ad-hoc stylesheets produce an artifact measurably worse than the document it is
meant to join"). So the CSS here is EXTRACTED from docs/handbook/assets/template.html —
the skill's page, with its @font-face registrations (Routed Gothic for drawing labels,
Letter Gothic for the checklist card and the stamped folio, Iowan-or-Georgia serif for
body) — and this module adds only what a multi-page BOOK needs that a single page does
not: the cover block, markdown content styles in the same genre, and the post-print
folio stamp (Chrome has no margin-box folio).

Retired: scripts/sheet_style.py (hand-rolled CSS, grey table tints, Helvetica heads —
every one of which the genre forbids: tints halftone into dots on a printer).

The fonts must ALSO be installed as system fonts (fc-wise) for the FIGURES: an SVG used
as an <img> cannot fetch webfonts, so its Routed Gothic labels resolve from the system.
The build copies docs/handbook/assets/fonts to the output dir for the HTML side.
"""
from __future__ import annotations

import pathlib
import re
import subprocess

import fitz  # pymupdf

ROOT = pathlib.Path(__file__).resolve().parent.parent
TEMPLATE = ROOT / "docs/handbook/assets/template.html"
FONTS = ROOT / "docs/handbook/assets/fonts"

CHROME = "/usr/bin/google-chrome"


def load_css() -> str:
    """The template's own <style> block, verbatim — the genre's single source."""
    html = TEMPLATE.read_text()
    m = re.search(r"<style>(.*)</style>", html, re.S)
    if not m:
        raise SystemExit("template.html has no <style> block")
    return m.group(1)


# What a BOOK adds to the page genre: markdown content styled BY the template's own
# vocabulary (serif body at 8 pt with Selectric spacing, hairline black table rules,
# no tint anywhere), plus the cover.
BOOK_CSS = """
a { color: #000; text-decoration: none; }
/* ---- markdown content, in the template's vocabulary ---- */
h1 { font: 400 15pt/1.3 var(--type); letter-spacing: 0.12em; text-align: center;
     border-bottom: 1.5pt solid var(--ink); padding-bottom: 2mm; margin: 4mm 0 4mm; }
h2 { font-size: 10.5pt; font-weight: 400; letter-spacing: 0.08em; margin: 4mm 0 2mm;
     text-decoration: underline; text-underline-offset: 1.6pt;
     text-decoration-thickness: 0.5pt; }
h3 { font-size: 9.5pt; font-weight: 400; letter-spacing: 0.06em; margin: 3mm 0 1.5mm; }
p { margin: 0 0 1.6mm; }
ul, ol { margin: 0 0 2mm 6mm; padding: 0; }
li { margin-bottom: 1mm; }
code { font-family: "SF Mono", Menlo, "DejaVu Sans Mono", monospace; font-size: 7.2pt;
       letter-spacing: 0; }
pre { font-family: "SF Mono", Menlo, "DejaVu Sans Mono", monospace; font-size: 7.2pt;
      letter-spacing: 0; border: 0.6pt solid var(--ink); padding: 2mm; margin: 2mm 0;
      white-space: pre-wrap; overflow-wrap: anywhere; background: var(--paper); }
blockquote { margin: 2mm 0 2mm 4mm; padding-left: 3mm; border-left: 1.4pt solid var(--ink); }
hr { border: 0; border-top: 0.5pt solid var(--ink); margin: 3mm 0; }
table { width: 100%; border-collapse: collapse; font-size: 7.3pt; line-height: 1.25;
        margin: 2mm 0 3mm; }
th, td { border: 0.6pt solid var(--ink); padding: 0.8mm 1.6mm; text-align: left;
         vertical-align: top; font-weight: 400; }
thead th { text-align: center; letter-spacing: 0.1em; }
td, th, p, li, code, pre { overflow-wrap: anywhere; }
.gap { font-weight: 700; }
.tbl-cont { font-size: 6.5pt; letter-spacing: 0.14em; text-transform: uppercase;
            margin: 0 0 1mm; }
.tbl-cap { text-align: center; letter-spacing: 0.07em; margin: 2mm 0 0.8mm; }
/* change bar: a thin black bar in the left margin marks text amended after the
   basic date (the template's .changebar, adapted to flowing markdown blocks) */
.chg { position: relative; }
.chg::before { content: ""; position: absolute; left: -3.4mm; top: 0; bottom: 0;
               width: 1.3mm; background: var(--ink); }
/* genre notice: centred caps label over the text, per the template's .notice */
.notice { margin: 2.4mm 0; }
.notice .lbl { display: block; text-align: center; letter-spacing: 0.18em;
               font-weight: 700; text-decoration: underline;
               text-underline-offset: 1.6pt; text-decoration-thickness: 0.6pt;
               margin-bottom: 0.8mm; }
.notice .txt { display: block; font-size: 7.4pt; line-height: 1.28; }
img { max-width: 100%; }

/* Flight Data File checklist card, per the template's own .card: black title bar,
   numbered steps, verification lines — and LETTER GOTHIC ONLY, the one face the
   template reserves for crew checklists. */
.card { border: 0.8pt solid var(--ink); font-family: var(--selectric); font-size: 7.1pt;
        line-height: 1.3; letter-spacing: 0; margin: 2.5mm 0; break-inside: avoid; }
.card .bar { background: var(--ink); color: var(--paper); font-weight: 700;
             padding: 0.5mm 1.8mm; display: flex; justify-content: space-between; }
.card ol { list-style: none; margin: 0; padding: 0.8mm 1.8mm 1mm; }
.card li { display: grid; grid-template-columns: 3.2mm 1fr; white-space: pre; }

/* ---- cover (a cover carries no dochead) ---- */
.cover { text-align: center; padding-top: 66mm; }
.cover .doc { letter-spacing: 0.3em; font-size: 10pt; }
.cover h1 { border: 0; font: 400 24pt/1.25 var(--type); letter-spacing: 0.18em;
            margin: 16mm 0 8mm; }
.cover .sub { font-style: italic; font-size: 11pt; letter-spacing: 0.04em; }
.cover .rule { width: 40mm; margin: 10mm auto; border-top: 1.5pt solid var(--ink); }
.cover .meta { margin-top: 34mm; font-size: 8.6pt; letter-spacing: 0.05em; line-height: 2; }
"""


def cover(doc_id: str, title: str, subtitle: str, meta=()) -> str:
    """Cover per references/build-the-set.md: doc number, title, italic subtitle,
    hairline rule, meta block that states scope and the one number that matters."""
    lines = "".join("<div>%s</div>" % m for m in meta)
    return (
        "<div class='cover'><div class='doc'>%s</div><h1>%s</h1>"
        "<div class='sub'>%s</div><div class='rule'></div>"
        "<div class='meta'>%s</div></div>" % (doc_id, title, subtitle, lines)
    )


def head_html(doc_id: str, title_line: str, section: str) -> str:
    """Running head: the template's .head — doc number over title over section, rule."""
    return ("<header class='head'><div class='doc'>%s &middot; INTERNAL</div>"
            "<div class='title'>%s</div><div class='part'>%s</div>"
            "<div class='rule'></div></header>" % (doc_id, title_line, section))


def tab_html(text: str) -> str:
    return "<div class='tab'>%s</div>" % text


def foot_html(sub: str, date: str) -> str:
    """Dated foot with fill-ins; the page number itself is the post-print folio."""
    return ("<footer class='foot'><div class='rule'></div><div class='sub'>%s</div>"
            "<div class='line'>"
            "<span>Mission <span class='fill' style='width:20mm'>CF2A</span></span>"
            "<span>Basic Date <span class='fill' style='width:30mm'>%s</span></span>"
            "<span>Change Date <span class='fill' style='width:30mm'>&nbsp;</span></span>"
            "<span>Page <span class='fill' style='width:18mm'>&nbsp;</span></span>"
            "</div></footer>" % (sub, date))


def print_pdf(html_path: str | pathlib.Path, pdf_path: str | pathlib.Path,
              timeout: int = 600) -> None:
    """Print with the flags the template's fonts need: --allow-file-access-from-files
    lets the page load ./fonts, --virtual-time-budget lets them settle before capture."""
    subprocess.run(
        [CHROME, "--headless=new", "--disable-gpu", "--no-sandbox",
         "--allow-file-access-from-files", "--virtual-time-budget=30000",
         "--no-pdf-header-footer", "--print-to-pdf=" + str(pdf_path),
         pathlib.Path(html_path).resolve().as_uri()],
        capture_output=True, text=True, timeout=timeout,
    )


def fit_line(html_path: str | pathlib.Path) -> tuple[str, int]:
    """The template's fit check, read back the way render.sh does: --dump-dom and
    grep data-fit. 'OVERFLOW …' means a page's content ran into the footer band.
    Also counts the .page divs — after pagination this is the exact PDF page count
    a well-formed print must produce (a second gate: Chrome printing a blank page
    or dropping one shows up here)."""
    r = subprocess.run(
        [CHROME, "--headless=new", "--disable-gpu", "--no-sandbox",
         "--allow-file-access-from-files", "--virtual-time-budget=30000",
         "--dump-dom", pathlib.Path(html_path).resolve().as_uri()],
        capture_output=True, text=True, timeout=300,
    )
    m = re.search(r'data-fit="([^"]*)"', r.stdout)
    fit = m.group(1) if m else "unknown (no fit script output)"
    return fit, len(re.findall(r'class="page"', r.stdout))


def stamp(pdf_path, doc_id, right=""):
    """Doc number, centred folio and running foot, applied after print so every page
    carries them. Set in LETTER GOTHIC — the stamped data line is Selectric work, and
    it is what puts Letter Gothic in the PDF's font census on every page."""
    path = pathlib.Path(pdf_path)
    font = fitz.Font(fontfile=str(FONTS / "LetterGothicCode-R.ttf"))
    doc = fitz.open(path)
    total = doc.page_count
    for i, page in enumerate(doc, 1):
        rect = page.rect
        y = rect.height - 18
        tw = fitz.TextWriter(rect)
        tw.append((36, y), doc_id, font=font, fontsize=7)
        if right:
            tw.append((rect.width - 36 - font.text_length(right, 7), y), right,
                      font=font, fontsize=7)
        num = "%d OF %d" % (i, total)
        tw.append(((rect.width - font.text_length(num, 7)) / 2, y), num,
                  font=font, fontsize=7)
        tw.write_text(page)
    doc.saveIncr()
    doc.close()


def font_census(pdf_path) -> set[str]:
    doc = fitz.open(pdf_path)
    fonts: set[str] = set()
    for pg in doc:
        for f in pg.get_fonts():
            fonts.add(f[3].split("+")[-1])
    doc.close()
    return fonts
