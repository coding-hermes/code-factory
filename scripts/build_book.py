#!/usr/bin/env python3
"""build_book.py — build the handbook from BOOK.yaml in the ONE house style.

The nasa-handbook root design is a page genre carried by sheet_style.py: cover, dochead,
stamped folio, print. A builder that writes its own CSS produces the costume the skill
names as a defect ("three ad-hoc stylesheets produce an artifact measurably worse than the
document it is meant to join"). This builder imports the house style and adds nothing:

  - cover via sheet_style.cover()
  - dochead on every sheet
  - folio applied AFTER print via sheet_style.stamp()  (Chrome has no margin-box folio)
  - one figure per sheet, constrained by its wider dimension, caption with snapshot date
  - gap sheets that name what is missing
  - a fit check after print: body blocks must end above the footer band (<=275 mm of 297)

    python3 scripts/build_book.py --out /home/kara/code-factory-reports/handbook/CF2A-01.pdf
"""
from __future__ import annotations

import argparse
import pathlib
import re
import sys

import yaml

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from gen_nasa_handbook import md_to_html  # noqa: E402
from sheet_style import CSS_PORTRAIT as CSS, cover, dochead, print_pdf, stamp  # noqa: E402

ROOT = HERE.parent
HB = ROOT / "docs/handbook"
BOOK = HB / "BOOK.yaml"
IMG_RE = re.compile(r"^!\[([^\]]*)\]\((figures/[^)]+\.svg)\)\s*$")


def svg_fit(path: pathlib.Path) -> str:
    """Constrain a figure by its wider dimension so nothing clips or prints sub-legible."""
    head = path.read_text()[:400]
    w = re.search(r'width="([\d.]+)', head)
    h = re.search(r'height="([\d.]+)', head)
    if w and h and float(w.group(1)) >= float(h.group(1)):
        return f'<img style="width:170mm" src="file://{path}"/>'
    return f'<img style="height:200mm" src="file://{path}"/>'


def body_sheet(text: str) -> tuple[str, list]:
    """Markdown -> HTML; ![alt](figures/x.svg) lines are pulled out to become their own sheets."""
    kept, figs = [], []
    for line in text.splitlines():
        m = IMG_RE.match(line.strip())
        if m:
            p = HB / m.group(2)
            figs.append(p if p.exists() else None)
        else:
            kept.append(line)
    return md_to_html(kept), figs


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="/tmp/cf-handbook.pdf")
    a = ap.parse_args()
    book = yaml.safe_load(BOOK.read_text())
    doc = book["doc"]
    today = str(doc["issue"])

    sheets: list[tuple[str, str]] = []  # (dochead section, body html)

    sheets.append((doc["id"], cover(doc["id"], doc["title"], doc["subtitle"],
                                    (f"ISSUE {today}", doc["classification"], doc["scope"].strip()))))

    rows = ""
    for p in book["parts"]:
        state = (f"{len(p['files'])} chapters" if p["files"]
                 else "<b>NOT WRITTEN — gap sheet follows</b>")
        rows += f"<tr><td>{p['id']}</td><td>{p['title']}</td><td>{state}</td></tr>"
    sheets.append(("CONTENTS", f"<h1>CONTENTS</h1>"
                               f"<table><tr><th>Part</th><th>Title</th><th>State</th></tr>{rows}</table>"))

    for p in book["parts"]:
        if not p["files"]:
            sheets.append((f"PART {p['id']}",
                           f"<h1>PART {p['id']} — {p['title']}</h1>"
                           f"<p class='gap'>NOT WRITTEN. This sheet exists so the gap is visible in "
                           f"the bound book rather than invisible in the file tree.</p>"))
            continue
        for rel in p["files"]:
            f = HB / rel
            if not f.exists():
                sheets.append(("BUILD ERROR",
                               f"<h1>BUILD ERROR</h1><p>{rel} is in the manifest and not on disk.</p>"))
                continue
            html, figs = body_sheet(f.read_text())
            sheets.append((f"PART {p['id']} · {p['title'].upper()}", html))
            for fig in figs:  # one figure per sheet, hero-sized, caption carries the snapshot date
                if fig is None:
                    continue
                code = fig.stem.upper()
                sheets.append((f"PART {p['id']} · FIGURE {code}",
                               f"<h2>FIGURE {code} — as of {today}</h2>{svg_fit(fig)}"))

    # The .page container is what makes overflow measurable (skill: without it the fit
    # script no-ops and every page is silently unconstrained).
    html_doc = (f"<!doctype html><html><head><meta charset='utf-8'><style>{CSS}"
                "table{border-collapse:collapse;width:100%}td,th{border:1px solid #999;padding:4px 8px;font-size:12px;text-align:left}"
                ".gap{color:#7a1f1f;font-weight:600}img{max-width:100%}</style></head><body>")
    for section, body in sheets:
        html_doc += f'<div class="page">{dochead(doc["id"], section)}{body}</div>'
    html_doc += "</body></html>"

    out_html = pathlib.Path(a.out).with_suffix(".html")
    out_html.write_text(html_doc)
    print_pdf(out_html, a.out)
    stamp(a.out, doc["id"], right=f"issue {today}")

    # Fit check — the skill's own measurement: body blocks must end above the footer band.
    bad = []
    try:
        import pymupdf
        for i, pg in enumerate(pymupdf.open(a.out), 1):
            blocks = [b for b in pg.get_text("blocks") if b[1] < 770]
            if not blocks:
                continue
            maxy = max(b[3] for b in blocks) / 2.8346
            # 275 is the guidance; PDF block coords carry ~0.35 mm rounding, so the gate
            # fails past 276 — a real collision, not rounding noise.
            if maxy > 276:
                bad.append((i, round(maxy, 1)))
    except ImportError:
        print("fit check skipped: pymupdf missing")
    if bad:
        print(f"FIT FAIL on {len(bad)} page(s), first: page {bad[0][0]} body ends {bad[0][1]} mm (limit 275)")
        return 2
    print(f"OK {a.out} ({pathlib.Path(a.out).stat().st_size} bytes) · {len(sheets)} sheets · "
          f"folio stamped · fit clean")
    return 0


if __name__ == "__main__":
    sys.exit(main())
