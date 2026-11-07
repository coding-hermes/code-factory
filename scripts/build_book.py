#!/usr/bin/env python3
"""build_book.py — build the handbook from BOOK.yaml in the ONE house style.

The nasa-handbook root design is a page genre carried by sheet_style.py: cover, dochead,
stamped folio, print. A builder that writes its own CSS produces the costume the skill
names as a defect ("three ad-hoc stylesheets produce an artifact measurably worse than the
document it is meant to join"). This builder imports the house style and adds nothing:

  - handbook_lint first: markdown debris (stray backslash-newline, unbalanced backticks,
    markdown pipes inside code spans, stray quote escapes) fails the build before render
  - cover via sheet_style.cover()
  - a dochead on EVERY rendered page: content that flows past one sheet is split at print
    time by a pagination script Chrome runs before printing — blocks move to a new .page
    div with a cloned running head, tall tables split between rows with the header
    repeated and a "table continues" placard — so no page exists that content merely
    flowed onto
  - folio applied AFTER print via sheet_style.stamp()  (Chrome has no margin-box folio)
  - gap sheets that name what is missing, in black bold per genre
  - after print: every non-cover page must carry the running head, and body blocks must
    end above the footer band (<=276 mm of 297)

    python3 scripts/build_book.py --out /home/kara/code-factory-reports/handbook/CF2A-01-w1.pdf
"""
from __future__ import annotations

import argparse
import pathlib
import re
import sys

import yaml

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import fitz  # pymupdf — also sheet_style's renderer-side dependency  # noqa: E402
from gen_nasa_handbook import md_blocks  # noqa: E402
from sheet_style import CSS_PORTRAIT as CSS, cover, dochead, print_pdf, stamp  # noqa: E402
import handbook_lint  # noqa: E402

ROOT = HERE.parent
HB = ROOT / "docs/handbook"
BOOK = HB / "BOOK.yaml"
IMG_RE = re.compile(r"^!\[([^\]]*)\]\((figures/[^)]+\.svg)\)\s*$")

# The fit gate: body blocks must end above the footer band (275 mm guidance, ~0.35 mm
# PDF block rounding -> 276).
FIT_LIMIT_MM = 276

EXTRA_CSS = (
    "table{border-collapse:collapse;width:100%}td,th{border:1px solid #999;padding:4px 8px;"
    "font-size:12px;text-align:left}"
    ".gap{color:#000;font-weight:700}"
    ".tbl-cont{font-family:'Helvetica Neue',Arial,sans-serif;font-size:6.5pt;"
    "letter-spacing:0.14em;text-transform:uppercase;color:#444;margin:0 0 1mm}"
    # a table whose columns' min-content sums wider than the page makes Chrome
    # shrink-to-fit the WHOLE document (body type printed at 2/3 spec size);
    # anywhere-breaking inside cells is what keeps min-content <= column width
    "td,th,p,li,code,pre{overflow-wrap:anywhere}"
    # pin layout to the exact print content width (A4 minus the 16 mm side margins):
    # the pagination script measures heights in the screen viewport, which must equal
    # the print layout or every sheet overflows and reflows at print time
    "body{width:178mm}"
    "img{max-width:100%}"
)

# Runs in Chrome before --print-to-pdf writes. Splits any .page div taller than one
# page's content area: trailing blocks move to a new .page div with a cloned dochead;
# a table taller than a page gives up trailing rows to a cloned table headed by the
# same thead with a "table continues" placard. One render, no measurement round-trips.
PAGINATE_JS = """
(function () {
  var MAX = 920; // px; A4 content area is ~979 px (259 mm at 96 dpi) — budget kept
                 // under the print-time reflow so the fit gate (276 mm) never trips
  function h(el) { return el.scrollHeight; }
  function cloneHead(pg) {
    var hd = pg.querySelector('.dochead');
    return hd ? hd.cloneNode(true) : null;
  }
  function contentKids(el) {
    var a = [];
    for (var c = el.firstChild; c; c = c.nextSibling)
      if (c.nodeType === 1 && !(c.classList && c.classList.contains('dochead'))) a.push(c);
    return a;
  }

  // --- column balancing -------------------------------------------------------
  // Auto layout + overflow-wrap:anywhere starves narrow columns (a "Direction"
  // column collapses to 2 characters per line). Balance every table once from its
  // own word widths, freeze as a colgroup with fixed layout; continuations clone
  // the same colgroup so source and continuation columns never drift.
  var cv = document.createElement('canvas');
  var ctx = cv.getContext('2d');
  function balanceTable(table) {
    if (table._balanced) return;
    table._balanced = true;
    var first = table.rows[0];
    if (!first || !first.cells.length) return;
    var ncol = first.cells.length;
    var maxw = [];
    for (var c = 0; c < ncol; c++) maxw.push(0);
    for (var r = 0; r < table.rows.length; r++) {
      var cells = table.rows[r].cells;
      for (c = 0; c < ncol && c < cells.length; c++) {
        var cs = getComputedStyle(cells[c]);
        ctx.font = cs.fontStyle + ' ' + cs.fontWeight + ' ' + cs.fontSize + ' ' + cs.fontFamily;
        var words = cells[c].textContent.split(/\\s+/);
        for (var w = 0; w < words.length; w++) {
          var ww = ctx.measureText(words[w]).width + 17; // + cell padding and border
          if (ww > maxw[c]) maxw[c] = ww;
        }
      }
    }
    var total = table.clientWidth || 672;
    var sumNat = 0;
    for (c = 0; c < ncol; c++) sumNat += maxw[c];
    var cols = [];
    if (sumNat <= total) {
      var extra = total - sumNat;
      for (c = 0; c < ncol; c++) cols.push(maxw[c] + extra * (maxw[c] / sumNat));
    } else {
      // over commitment: shrink wide columns, keep every column usable
      var scale = (total - ncol * 44) / (sumNat - ncol * 44);
      for (c = 0; c < ncol; c++) cols.push(Math.max(44, maxw[c] * scale));
    }
    var cg = document.createElement('colgroup');
    for (c = 0; c < ncol; c++) {
      var col = document.createElement('col');
      col.style.width = cols[c].toFixed(1) + 'px';
      cg.appendChild(col);
    }
    table.insertBefore(cg, table.firstChild);
    table.style.tableLayout = 'fixed';
  }
  Array.prototype.slice.call(document.querySelectorAll('table')).forEach(balanceTable);

  // --- page splitting ----------------------------------------------------------
  // Split one .page div: peel trailing blocks off the end (reading order preserved by
  // inserting each at the TOP of the continuation) until the source fits one page.
  // After every move the continuation is re-measured; an element that overflows it is
  // reopened on a fresh page — Chrome must never be left to flow content onto a
  // page of its own, because such a page carries no running head.
  function splitPage(pg) {
    var anchor = { el: pg };
    var np = null;
    var guard = 0;
    var lastTable = null;
    function newPage() {
      np = document.createElement('div');
      np.className = 'page';
      var hd = cloneHead(pg);
      if (hd) np.appendChild(hd);
      anchor.el.parentNode.insertBefore(np, anchor.el.nextSibling);
      anchor.el = np;
    }
    function openTable() {
      newPage();
      var cont = document.createElement('p');
      cont.className = 'tbl-cont';
      cont.textContent = 'Table continues';
      np.appendChild(cont);
      var nt = document.createElement('table');
      var cg = lastTable.querySelector('colgroup');
      if (cg) nt.appendChild(cg.cloneNode(true));
      nt.style.tableLayout = 'fixed';
      var th = lastTable.querySelector('thead');
      if (th) nt.appendChild(th.cloneNode(true));
      nt.appendChild(document.createElement('tbody'));
      np.appendChild(nt);
      np._tb = nt.tBodies[0];
    }
    while (h(pg) > MAX && guard++ < 600) {
      var kids = contentKids(pg);
      if (!kids.length) break;
      var last = kids[kids.length - 1];
      if (last.tagName === 'TABLE' && last.rows.length > 1) {
        lastTable = last;
        if (!np || !np._tb) openTable();
        var row = last.rows[last.rows.length - 1];
        np._tb.insertBefore(row, np._tb.firstChild);
        if (h(np) > MAX) {  // the row overflowed this continuation — reopen
          np._tb.removeChild(row);
          openTable();
          np._tb.insertBefore(row, np._tb.firstChild);
        }
      } else {
        if (!np) newPage();
        np.insertBefore(last, contentKids(np)[0] || null);
        if (h(np) > MAX) {  // the block overflowed this continuation — reopen
          var node = last;
          np.removeChild(node);
          newPage();
          np.appendChild(node);
        }
      }
    }
    return np;
  }
  var pages = Array.prototype.slice.call(document.querySelectorAll('.page'));
  for (var i = 0; i < pages.length; i++) {
    var np = splitPage(pages[i]);
    var g = 0;
    while (np && h(np) > MAX && g++ < 10) np = splitPage(np);
  }
})();
"""


def svg_fit(path: pathlib.Path) -> str:
    """Constrain a figure by its wider dimension so nothing clips or prints sub-legible."""
    head = path.read_text()[:400]
    w = re.search(r'width="([\d.]+)', head)
    h = re.search(r'height="([\d.]+)', head)
    if w and h and float(w.group(1)) >= float(h.group(1)):
        return f'<img style="width:170mm" src="file://{path}"/>'
    return f'<img style="height:200mm" src="file://{path}"/>'


def body_blocks(text: str) -> tuple[list[str], list]:
    """Markdown -> block list; ![alt](figures/x.svg) lines are pulled out to become their own sheets."""
    kept, figs = [], []
    for line in text.splitlines():
        m = IMG_RE.match(line.strip())
        if m:
            p = HB / m.group(2)
            figs.append(p if p.exists() else None)
        else:
            kept.append(line)
    return md_blocks(kept), figs


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="/tmp/cf-handbook.pdf")
    a = ap.parse_args()

    # Markdown debris fails the build before anything renders.
    problems = handbook_lint.lint()
    for rel, lineno, kind, snippet in problems:
        print(f"LINT {rel}:{lineno} — {kind}: {snippet!r}")
    if problems:
        print(f"BUILD FAIL: handbook_lint found {len(problems)} finding(s)")
        return 2

    book = yaml.safe_load(BOOK.read_text())
    doc = book["doc"]
    doc_id = doc["id"]
    today = str(doc["issue"])
    # Figure codes live in BOOK.yaml, not in filenames: one id resolves to one object.
    fig_codes = {str(f["file"]): str(f["code"]) for f in book.get("figures", [])}

    sheets: list[tuple[str, list[str]]] = []  # (dochead section, html blocks)

    rows = ""
    for p in book["parts"]:
        state = (f"{len(p['files'])} chapters" if p["files"]
                 else "<b>NOT WRITTEN — gap sheet follows</b>")
        rows += f"<tr><td>{p['id']}</td><td>{p['title']}</td><td>{state}</td></tr>"
    sheets.append(("CONTENTS",
                   [f"<h1>CONTENTS</h1>"
                    f"<table><thead><tr><th>Part</th><th>Title</th><th>State</th></tr>"
                    f"</thead><tbody>{rows}</tbody></table>"]))

    for p in book["parts"]:
        if not p["files"]:
            sheets.append((f"PART {p['id']}",
                           [f"<h1>PART {p['id']} — {p['title']}</h1>",
                            "<p class='gap'>NOT WRITTEN. This sheet exists so the gap is visible in "
                            "the bound book rather than invisible in the file tree.</p>"]))
            continue
        for rel in p["files"]:
            f = HB / rel
            if not f.exists():
                sheets.append(("BUILD ERROR",
                               [f"<h1>BUILD ERROR</h1><p>{rel} is in the manifest and not on disk.</p>"]))
                continue
            # A module chapter opens with its own centered view: the hero figure sheet is
            # mounted BEFORE the chapter text, coded <part prefix>.<n> from the manifest
            # (Part III's prefix 3 + chapter M<n> -> FIGURE 3.<n>) with the issue date.
            mmod = re.match(r"chapters/M(\d+)-", rel)
            if mmod:
                n = mmod.group(1)
                hero = HB / f"figures/module-M{n}.svg"
                code = f"{p.get('prefix', p['id'])}.{n}"
                if hero.exists():
                    sheets.append((f"PART {p['id']} · FIGURE {code}",
                                   [f"<h2>FIGURE {code} — MODULE M{n} CENTERED VIEW — as of {today}</h2>",
                                    svg_fit(hero)]))
                else:
                    sheets.append(("BUILD ERROR",
                                   [f"<h1>BUILD ERROR</h1><p>figures/module-M{n}.svg is the "
                                    f"centered view of {rel} and is not on disk.</p>"]))
            blocks, figs = body_blocks(f.read_text())
            sheets.append((f"PART {p['id']} · {p['title'].upper()}", blocks))
            for fig in figs:  # one figure per sheet, hero-sized, caption carries the snapshot date
                if fig is None:
                    continue
                code = fig_codes.get(str(fig.relative_to(HB)), fig.stem.upper())
                sheets.append((f"PART {p['id']} · FIGURE {code}",
                               [f"<h2>FIGURE {code} — as of {today}</h2>", svg_fit(fig)]))

    # The .page container is what makes overflow measurable (skill: without it the fit
    # script no-ops and every page is silently unconstrained). The cover is its own page
    # div — a cover carries no dochead. The pagination script bounds every sheet so every
    # rendered page is a real .page div carrying its running head.
    title = doc["title"].upper()
    cover_html = cover(doc_id, doc["title"], doc["subtitle"],
                       (f"ISSUE {today}", doc["classification"], doc["scope"].strip()))
    pages_html = (f'<div class="page">{cover_html}</div>'
                  + "".join(f'<div class="page">{dochead(doc_id, s, title=title)}'
                            f'{chr(10).join(b)}</div>' for s, b in sheets))
    html_doc = (f"<!doctype html><html><head><meta charset='utf-8'><style>{CSS}"
                f"{EXTRA_CSS}</style></head><body>{pages_html}"
                f"<script>{PAGINATE_JS}</script></body></html>")

    out_html = pathlib.Path(a.out).with_suffix(".html")
    out_html.write_text(html_doc)
    print_pdf(out_html, a.out)
    stamp(a.out, doc_id, right=f"issue {today}")

    # Furniture check: every page after the cover must carry the running head in its top
    # band (the stamp's doc number sits in the footer band and does not count) — a page
    # without one is a page content flowed onto, headless and uncitable.
    pdf = fitz.open(a.out)
    headless = []
    for i, pg in enumerate(pdf, 1):
        if i == 1:
            continue
        top = [b for b in pg.get_text("blocks") if b[1] < 80]
        top_text = re.sub(r"\s+", "", " ".join(b[4] for b in top))
        if "CF2A-01·" not in top_text:
            headless.append(i)
    if headless:
        print(f"FIT FAIL: pages without a running head: {headless[:8]}")
        return 2

    # Fit check — the skill's own measurement: body blocks must end above the footer band.
    bad = []
    for i, pg in enumerate(pdf, 1):
        blocks = [b for b in pg.get_text("blocks") if b[1] < 770]
        if not blocks:
            continue
        maxy = max(b[3] for b in blocks) / 2.8346
        if maxy > FIT_LIMIT_MM:
            bad.append((i, round(maxy, 1)))
    if bad:
        print(f"FIT FAIL on {len(bad)} page(s), first: page {bad[0][0]} body ends {bad[0][1]} mm (limit 275)")
        return 2
    print(f"OK {a.out} ({pathlib.Path(a.out).stat().st_size} bytes) · {pdf.page_count} pages · "
          f"dochead + folio on every page · fit clean")
    return 0


if __name__ == "__main__":
    sys.exit(main())
