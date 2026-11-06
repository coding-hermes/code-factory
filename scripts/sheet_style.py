#!/usr/bin/env python3
"""sheet_style.py — one visual language for every generated sheet.

The handbook looked like a document and the figures looked like screenshots of a web page. That was not
a rendering bug: each generator carried its own CSS, so the fill, the rules and the type scale drifted
apart. This is the single source of the house style — cover, sheet head, page furniture, stamping — so a
figure sheet and a handbook page read as the same publication.

A sheet is not a slide: it carries a document number, a sheet number and the same type scale as the
handbook, so it can be bound next to it.
"""

import pathlib
import subprocess

import fitz  # pymupdf


# --- type scale, shared with the handbook -------------------------------------------------------------
SERIF = '"Iowan Old Style", "Palatino Linotype", Georgia, serif'
SANS = '"Helvetica Neue", Arial, sans-serif'
MONO = '"SF Mono", Menlo, "DejaVu Sans Mono", monospace'

_BASE = """
html { font-size: 9.1pt; }
body { font-family: %(serif)s; color: #111; line-height: 1.34; letter-spacing: 0.01em; margin: 0; }
h1 { font-family: %(sans)s; font-size: 15pt; letter-spacing: 0.05em; text-transform: uppercase;
     border-bottom: 1.6pt solid #111; padding-bottom: 2mm; margin: 0 0 3mm; }
h2 { font-family: %(sans)s; font-size: 9.8pt; letter-spacing: 0.1em; text-transform: uppercase;
     margin: 0 0 2.4mm; color: #333; font-weight: 400; border-bottom: 0.5pt solid #999;
     padding-bottom: 1.2mm; }
p.lede { font-size: 8.6pt; max-width: 100%%; margin: 0 0 3mm; text-align: justify; hyphens: auto; }
table { width: 100%%; border-collapse: collapse; margin: 1.5mm 0 3mm; font-size: 7.6pt;
        font-family: %(sans)s; }
th { text-align: left; font-weight: 700; border-bottom: 1pt solid #111; padding: 1.1mm 1.6mm;
     background: #efeee8; letter-spacing: 0.03em; }
td { border-bottom: 0.4pt solid #bbb; padding: 1.1mm 1.6mm; vertical-align: top; }
tr { page-break-inside: avoid; }
code { font-family: %(mono)s; font-size: 7.2pt; background: #f1f0ea; padding: 0 0.5mm; }
.legend { font-family: %(sans)s; font-size: 8pt; margin-top: 1mm; }
.legend span { margin-right: 7mm; }
.st-works { color: #14532d; font-weight: 700; }
.st-broken { color: #a11d1d; font-weight: 700; }
.st-missing { color: #8a5200; font-weight: 700; }
.st-external { color: #555555; font-weight: 700; }
.trig { color: #14532d; }
.none { color: #a11d1d; }
img { display: block; margin: 0 auto; }
.dochead { font-family: %(sans)s; font-size: 7.4pt; letter-spacing: 0.18em; text-transform: uppercase;
           color: #444; border-bottom: 0.6pt solid #999; padding-bottom: 1.2mm; margin-bottom: 2.6mm;
           display: flex; justify-content: space-between; }
.dochead .r { color: #777; letter-spacing: 0.1em; }
.cover { text-align: center; page-break-after: always; padding-top: 42mm; }
.cover .doc { font-family: %(sans)s; letter-spacing: 0.3em; font-size: 9pt; }
.cover h1 { border: 0; font-size: 24pt; letter-spacing: 0.18em; margin: 12mm 0 6mm; }
.cover .sub { font-size: 11pt; letter-spacing: 0.06em; font-style: italic; }
.cover .rule { width: 40mm; margin: 8mm auto; border-top: 1.2pt solid #111; }
.cover .meta { margin-top: 32mm; font-family: %(sans)s; font-size: 8.2pt; letter-spacing: 0.05em;
               line-height: 1.9; color: #333; }
.page { page-break-after: always; break-inside: avoid; }
""" % {"serif": SERIF, "sans": SANS, "mono": MONO}

CSS_LANDSCAPE = "@page { size: A4 landscape; margin: 16mm 12mm 14mm 12mm; }\n" + _BASE
CSS_PORTRAIT = "@page { size: A4; margin: 20mm 16mm 18mm 16mm; }\n" + _BASE


def cover(doc_id, title, subtitle, meta=()):
    """A cover is what makes the artifact a document rather than a printout."""
    lines = "".join("%s<br/>" % m for m in meta)
    return (
        "<div class='cover'><div class='doc'>%s</div><h1>%s</h1>"
        "<div class='sub'>%s</div><div class='rule'></div>"
        "<div class='meta'>%s</div></div>" % (doc_id, title, subtitle, lines)
    )


def dochead(doc_id, section, right=""):
    return (
        "<div class='dochead'><span>%s &middot; %s</span><span class='r'>%s</span></div>"
        % (doc_id, section, right)
    )


def stamp(pdf_path, doc_id, right="code-factory", footer=""):
    """Sheet number and running foot, applied after print so every page carries it.

    Chrome cannot put a running foot in a margin box reliably, and a document without page numbers
    cannot be cited — which is the whole point of these sheets.
    """
    path = pathlib.Path(pdf_path)
    doc = fitz.open(path)
    total = doc.page_count
    for i, page in enumerate(doc, 1):
        rect = page.rect
        y = rect.height - 18
        page.insert_text(
            (36, y),
            "%s \u00b7 SHEET %d OF %d" % (doc_id, i, total),
            fontname="helv",
            fontsize=6.6,
            color=(0.25, 0.25, 0.25),
        )
        txt = "%s \u00b7 %s" % (right, footer) if footer else right
        w = fitz.get_text_length(txt, fontname="helv", fontsize=6.6)
        page.insert_text(
            (rect.width - 36 - w, y),
            txt,
            fontname="helv",
            fontsize=6.6,
            color=(0.25, 0.25, 0.25),
        )
        num = "%d" % i
        nw = fitz.get_text_length(num, fontname="helv", fontsize=6.6)
        page.insert_text(
            ((rect.width - nw) / 2, y),
            num,
            fontname="helv",
            fontsize=6.6,
            color=(0.4, 0.4, 0.4),
        )
    doc.saveIncr()
    doc.close()


def print_pdf(html_path, pdf_path, chrome="/usr/bin/google-chrome", timeout=600):
    subprocess.run(
        [
            chrome,
            "--headless",
            "--disable-gpu",
            "--no-sandbox",
            "--no-pdf-header-footer",
            "--print-to-pdf=" + str(pdf_path),
            pathlib.Path(html_path).resolve().as_uri(),
        ],
        capture_output=True,
        text=True,
        timeout=timeout,
    )
