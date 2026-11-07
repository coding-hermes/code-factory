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
html { font-size: 8pt; }
body { font-family: %(serif)s; color: #000; line-height: 1.34; letter-spacing: 0.055em; margin: 0; }
h1 { font-family: %(sans)s; font-size: 15pt; letter-spacing: 0.05em; text-transform: uppercase;
     border-bottom: 1.5pt solid #000; padding-bottom: 2mm; margin: 0 0 3mm;
     page-break-after: avoid; }
h2 { font-family: %(sans)s; font-size: 9.8pt; letter-spacing: 0.1em; text-transform: uppercase;
     margin: 0 0 2.4mm; color: #000; font-weight: 400; border-bottom: 1pt solid #000;
     padding-bottom: 1.2mm; page-break-after: avoid; }
p.lede { font-size: 8pt; max-width: 100%%; margin: 0 0 3mm; text-align: justify; hyphens: auto; }
table { width: 100%%; border-collapse: collapse; margin: 1.5mm 0 3mm; font-size: 7.6pt;
        font-family: %(sans)s; }
th { text-align: left; font-weight: 700; border-bottom: 1pt solid #000; padding: 1.1mm 1.6mm;
     background: #efeee8; letter-spacing: 0.03em; }
td { border-bottom: 0.4pt solid #bbb; padding: 1.1mm 1.6mm; vertical-align: top; }
tr { page-break-inside: avoid; }
code { font-family: %(mono)s; font-size: 7.2pt; background: #f1f0ea; padding: 0 0.5mm; }
pre { font-family: %(mono)s; font-size: 7.6pt; background: #f4f3ed; border-left: 2pt solid #000;
      padding: 1.8mm 2.4mm; margin: 1.6mm 0 3mm; white-space: pre-wrap; overflow-wrap: anywhere;
      page-break-inside: avoid; }
/* without white-space: pre-wrap the UA default `pre` never wraps, one long command line
   runs the page 2x wide, and Chrome shrink-to-fits the whole document to 2/3 type size */
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
           color: #000; font-weight: 700; border-bottom: 1pt solid #000; padding-bottom: 1.2mm;
           margin-bottom: 2.6mm; display: flex; justify-content: space-between; }
.dochead .r { color: #000; font-weight: 400; letter-spacing: 0.1em; }
.cover { text-align: center; page-break-after: always; padding-top: 42mm; }
.cover .doc { font-family: %(sans)s; letter-spacing: 0.3em; font-size: 9pt; }
.cover h1 { border: 0; font-size: 24pt; letter-spacing: 0.18em; margin: 12mm 0 6mm; }
.cover .sub { font-size: 11pt; letter-spacing: 0.06em; font-style: italic; }
.cover .rule { width: 40mm; margin: 8mm auto; border-top: 1.5pt solid #000; }
.cover .meta { margin-top: 32mm; font-family: %(sans)s; font-size: 8.2pt; letter-spacing: 0.05em;
               line-height: 1.9; color: #000; }
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


def dochead(doc_id, section, right="", title=""):
    """Running head: doc number + handbook title + section, black bold, over a black rule."""
    left = " &middot; ".join([doc_id] + [t for t in (title, section) if t])
    return (
        "<div class='dochead'><span>%s</span><span class='r'>%s</span></div>"
        % (left, right)
    )


def stamp(pdf_path, doc_id, right="code-factory", footer=""):
    """Doc number, centred folio and running foot, applied after print so every page carries them.

    Chrome cannot put a running foot in a margin box reliably, and a document without page numbers
    cannot be cited — which is the whole point of these sheets. The sheet number lives ONCE, in the
    centred folio (<i> OF <total>): the left slot is the doc id alone, not a second copy of it.
    """
    path = pathlib.Path(pdf_path)
    doc = fitz.open(path)
    total = doc.page_count
    for i, page in enumerate(doc, 1):
        rect = page.rect
        y = rect.height - 18
        page.insert_text(
            (36, y),
            doc_id,
            fontname="hebo",
            fontsize=6.6,
            color=(0, 0, 0),
        )
        txt = "%s \u00b7 %s" % (right, footer) if footer else right
        w = fitz.get_text_length(txt, fontname="hebo", fontsize=6.6)
        page.insert_text(
            (rect.width - 36 - w, y),
            txt,
            fontname="hebo",
            fontsize=6.6,
            color=(0, 0, 0),
        )
        num = "%d OF %d" % (i, total)
        nw = fitz.get_text_length(num, fontname="hebo", fontsize=6.6)
        page.insert_text(
            ((rect.width - nw) / 2, y),
            num,
            fontname="hebo",
            fontsize=6.6,
            color=(0, 0, 0),
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
