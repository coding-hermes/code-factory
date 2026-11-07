#!/usr/bin/env python3
"""build_book.py — build the handbook from BOOK.yaml, in the NASA shell.

Everything the 9 a.m. delivery lacked comes from here: a cover with the document number,
a generated contents table, a running head on every part, a stamped foot, and gap pages
that name what is missing instead of letting the book pretend to be complete.

    python3 scripts/build_book.py --out /tmp/cf-handbook.pdf
"""
from __future__ import annotations

import argparse
import datetime
import pathlib
import re
import subprocess
import sys

import yaml

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from gen_nasa_handbook import CSS, md_to_html  # noqa: E402

ROOT = HERE.parent
HB = ROOT / "docs/handbook"
BOOK = HB / "BOOK.yaml"


def page(body: str, head: str, foot: str) -> str:
    return f'<section class="sheet"><div class="runhead">{head}</div>{body}<div class="foot">{foot}</div></section>'


IMG_RE = re.compile(r"^!\[([^\]]*)\]\((figures/[^)]+\.svg)\)\s*$")


def figures_for(text: str) -> str:
    """Inline ![alt](figures/x.svg) as <figure> blocks with SVG content and FIGURE-code captions."""
    out, figs = [], []
    for line in text.splitlines():
        m = IMG_RE.match(line.strip())
        if m:
            alt, rel = m.group(1), m.group(2)
            svg_path = HB / rel
            code = rel.split("/")[-1].replace(".svg", "").upper()
            if svg_path.exists():
                figs.append(f'<figure id="FIG-{code}"><div class="fig">{svg_path.read_text()}</div>'
                            f'<figcaption>FIGURE {code} — {alt}</figcaption></figure>')
            else:
                figs.append(f'<p class="gap">FIGURE {code} MISSING — {rel} is referenced and not on disk.</p>')
        else:
            out.append(line)
    return md_to_html(out) + "".join(figs)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="/tmp/cf-handbook.pdf")
    a = ap.parse_args()
    book = yaml.safe_load(BOOK.read_text())
    doc = book["doc"]
    today = doc["issue"]
    html_pages: list[str] = []
    pages: list[tuple[str, str]] = []  # (head, body) — foot folio needs the total count

    def add(head: str, body: str) -> None:
        pages.append((head, body))

    # Cover — the page the genre requires before anything else.
    cover = (
        f'<div class="cover"><div class="docno">{doc["id"]}</div>'
        f'<h1>{doc["title"]}</h1><div class="subtitle">{doc["subtitle"]}</div><hr/>'
        f'<div class="meta">ISSUE {today} · {doc["classification"]}</div>'
        f'<p class="scope">{doc["scope"].strip()}</p></div>'
    )
    pages: list[tuple[str, str]] = []  # (head, body) — folio needs the total count

    def add(head: str, body: str) -> None:
        pages.append((head, body))

    # Cover — the page the genre requires before anything else.
    cover = (
        f'<div class="cover"><div class="docno">{doc["id"]}</div>'
        f'<h1>{doc["title"]}</h1><div class="subtitle">{doc["subtitle"]}</div><hr/>'
        f'<div class="meta">ISSUE {today} · {doc["classification"]}</div>'
        f'<p class="scope">{doc["scope"].strip()}</p></div>'
    )
    add(doc["id"], cover)

    # Contents — generated from the manifest, so it cannot disagree with the pages.
    toc = ["<h1>CONTENTS</h1><table><tr><th>Part</th><th>Title</th><th>State</th></tr>"]
    for p in book["parts"]:
        n = len(p["files"])
        state = f"{n} chapter{'s' if n != 1 else ''}" if n else "NOT WRITTEN — gap page follows"
        toc.append(f'<tr><td>{p["id"]}</td><td>{p["title"]}</td><td>{state}</td></tr>')
    toc.append("</table>")
    add(f'{doc["id"]} · CONTENTS', "".join(toc))

    # Parts — real files, or an honest gap page.
    for p in book["parts"]:
        phead = f'{doc["id"]} · PART {p["id"]} · {p["title"].upper()}'
        if not p["files"]:
            gap = f'<h1>PART {p["id"]} — {p["title"]}</h1><p class="gap">NOT WRITTEN. This page exists so the gap is visible in the bound book rather than invisible in the file tree.</p>'
            add(phead, gap)
            continue
        for rel in p["files"]:
            f = HB / rel
            if not f.exists():
                add(f'{doc["id"]} · BUILD ERROR',
                    f"<h1>BUILD ERROR</h1><p>{rel} is in the manifest and not on disk — build error.</p>")
                continue
            add(phead, figures_for(f.read_text()))

    total = len(pages)
    doc_html = (
        "<!doctype html><html><head><meta charset='utf-8'>"
        f"<style>{CSS}\n.sheet{{page-break-after:always;position:relative;min-height:95vh;}}"
        ".runhead{font-size:10px;letter-spacing:.12em;color:#555;border-bottom:1px solid #999;padding-bottom:4px;margin-bottom:18px;}"
        ".foot{position:absolute;bottom:8px;left:0;right:0;text-align:center;font-size:10px;color:#555;}"
        ".cover{text-align:center;padding-top:18vh}.cover h1{font-size:42px;margin:12px 0}"
        ".subtitle{font-style:italic;color:#444}.docno{font-size:13px;letter-spacing:.2em;color:#666}"
        ".meta{font-size:12px;color:#555;margin:18px 0}.scope{max-width:60ch;margin:0 auto;text-align:left;font-size:13px}"
        ".gap{color:#7a1f1f;font-weight:600}figcaption{font-size:11px;color:#444;text-align:center;margin-top:6px}"
        "img{max-width:100%}table{border-collapse:collapse;width:100%}"
        "td,th{border:1px solid #999;padding:4px 8px;font-size:12px;text-align:left}</style></head><body>"
        + "".join(page(head, body, f'{doc["id"]} · SHEET {i} OF {total} · {today}')
                  for i, (head, body) in enumerate(pages, start=1))
        + "</body></html>"
    )
    out_html = pathlib.Path(a.out).with_suffix(".html")
    out_html.write_text(doc_html)
    chrome = "/usr/bin/google-chrome"
    r = subprocess.run(
        [chrome, "--headless", "--disable-gpu", "--no-sandbox",
         "--run-all-compositor-stages-before-draw", f"--print-to-pdf={a.out}", str(out_html)],
        capture_output=True, text=True, timeout=900,
    )
    if r.returncode != 0 or not pathlib.Path(a.out).exists():
        print("chrome failed:", (r.stderr or r.stdout)[-400:])
        return 1
    figs = out_html.read_text().count("<figure")
    print(f"PDF {a.out} ({pathlib.Path(a.out).stat().st_size} bytes) · {total} sheets · {figs} inline figures · folio SHEET n OF {total}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
