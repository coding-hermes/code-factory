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


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="/tmp/cf-handbook.pdf")
    a = ap.parse_args()
    book = yaml.safe_load(BOOK.read_text())
    doc = book["doc"]
    today = doc["issue"]
    html_pages: list[str] = []

    # Cover — the page the genre requires before anything else.
    cover = (
        f'<div class="cover"><div class="docno">{doc["id"]}</div>'
        f'<h1>{doc["title"]}</h1><div class="subtitle">{doc["subtitle"]}</div><hr/>'
        f'<div class="meta">ISSUE {today} · {doc["classification"]}</div>'
        f'<p class="scope">{doc["scope"].strip()}</p></div>'
    )
    html_pages.append(page(cover, doc["id"], f'{doc["id"]} · COVER · {today}'))

    # Contents — generated from the manifest, so it cannot disagree with the pages.
    toc = ["<h1>CONTENTS</h1><table><tr><th>Part</th><th>Title</th><th>State</th></tr>"]
    for p in book["parts"]:
        n = len(p["files"])
        state = f"{n} chapter{'s' if n != 1 else ''}" if n else "NOT WRITTEN — gap page follows"
        toc.append(f'<tr><td>{p["id"]}</td><td>{p["title"]}</td><td>{state}</td></tr>')
    toc.append("</table>")
    html_pages.append(page("".join(toc), f'{doc["id"]} · CONTENTS', f'{doc["id"]} · {today}'))

    # Parts — real files, or an honest gap page.
    for p in book["parts"]:
        if not p["files"]:
            gap = f'<h1>PART {p["id"]} — {p["title"]}</h1><p class="gap">NOT WRITTEN. This page exists so the gap is visible in the bound book rather than invisible in the file tree.</p>'
            html_pages.append(page(gap, f'{doc["id"]} · PART {p["id"]}', f'{doc["id"]} · SHEET · {today}'))
            continue
        for rel in p["files"]:
            f = HB / rel
            if not f.exists():
                html_pages.append(page(f"<h1>MISSING FILE</h1><p>{rel} is in the manifest and not on disk — build error.</p>",
                                       f'{doc["id"]} · BUILD ERROR', f'{doc["id"]} · {today}'))
                continue
            body = md_to_html(f.read_text().splitlines())
            head = f'{doc["id"]} · PART {p["id"]} · {p["title"].upper()}'
            html_pages.append(page(body, head, f'{doc["id"]} · SHEET · {today}'))

    doc_html = (
        "<!doctype html><html><head><meta charset='utf-8'>"
        f"<style>{CSS}\n.sheet{{page-break-after:always;position:relative;min-height:95vh;}}"
        ".runhead{font-size:10px;letter-spacing:.12em;color:#555;border-bottom:1px solid #999;padding-bottom:4px;margin-bottom:18px;}"
        ".foot{position:absolute;bottom:8px;left:0;right:0;text-align:center;font-size:10px;color:#555;}"
        ".cover{text-align:center;padding-top:18vh}.cover h1{font-size:42px;margin:12px 0}"
        ".subtitle{font-style:italic;color:#444}.docno{font-size:13px;letter-spacing:.2em;color:#666}"
        ".meta{font-size:12px;color:#555;margin:18px 0}.scope{max-width:60ch;margin:0 auto;text-align:left;font-size:13px}"
        ".gap{color:#7a1f1f;font-weight:600}img{max-width:100%}table{border-collapse:collapse;width:100%}"
        "td,th{border:1px solid #999;padding:4px 8px;font-size:12px;text-align:left}</style></head><body>"
        + "".join(html_pages)
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
    print(f"PDF {a.out} ({pathlib.Path(a.out).stat().st_size} bytes) · HTML {out_html}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
