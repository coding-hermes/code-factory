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
import subprocess
import sys
import time

import yaml

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import fitz  # pymupdf — also sheet_style's renderer-side dependency  # noqa: E402
from gen_nasa_handbook import inline, md_blocks  # noqa: E402
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
    "table{border-collapse:collapse;width:100%}td,th{border:1pt solid #000;padding:4px 8px;"
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
# page's content area by FORWARD assembly: walk the content in reading order, move the
# first block that crosses the budget and everything after it (in order, appended) to a
# new .page div inserted after this one with a cloned dochead; a table crossing the
# budget splits between rows, the first non-fitting row opening a continuation table
# (same colgroup, cloned thead, "table continues" placard) — or the whole table moves
# when no body row fits, so no sheet ever ends on a header with zero rows. One render,
# no measurement round-trips.
PAGINATE_JS = """
(function () {
  var MAX = 920; // px; A4 content area is ~979 px (259 mm at 96 dpi) — budget kept
                 // under the print-time reflow so the fit gate (276 mm) never trips
  function h(el) { return el.scrollHeight; }
  function cloneHead(pg) {
    var hd = pg.querySelector('.dochead');
    return hd ? hd.cloneNode(true) : null;
  }
  function makePage(pg) {
    var np = document.createElement('div');
    np.className = 'page';
    var hd = cloneHead(pg);
    if (hd) np.appendChild(hd);
    // the thumb tab travels with the sheet: every page of a part carries it
    var tab = pg.querySelector('.tab');
    if (tab) np.appendChild(tab.cloneNode(true));
    return np;
  }
  // every continuation opened, so a post-pagination pass can print real unit
  // counts ('units a–b of N') once each table chain's final row distribution is known
  var LINKS = [];
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
  // FORWARD assembly. The previous version peeled trailing blocks off the end and
  // inserted each at the top of ONE continuation div; that keeps order only while
  // everything fits on that one continuation. When the continuation itself overflowed,
  // a reopen path opened yet another page and kept peeling into it — page k+1 always
  // received content EARLIER than page k, so every multi-page split imposed in reverse
  // (Part IV printed CT-18..01, M0 §13..§8) and a continuation table opened for one
  // table could inherit rows from a different one. Now: walk the content IN reading
  // order, find the first block whose bottom crosses the budget, move it and everything
  // after it (appended, in order) to a new page inserted after this one; repeat on the
  // new page. The page sequence IS the reading order by construction.
  function bottomIn(pg, el) {
    return el.getBoundingClientRect().bottom - pg.getBoundingClientRect().top;
  }
  function openCont(np, tbl, firstUnit) {
    var cont = document.createElement('p');
    cont.className = 'tbl-cont';
    cont.textContent = 'Table continues';
    np.appendChild(cont);
    var nt = document.createElement('table');
    // a continuation inherits its source table's identity (reg -> register placard)
    if (tbl.className) nt.className = tbl.className;
    var cg = tbl.querySelector('colgroup');
    if (cg) nt.appendChild(cg.cloneNode(true));
    nt.style.tableLayout = 'fixed';
    var th = tbl.querySelector('thead');
    if (th) nt.appendChild(th.cloneNode(true));
    var tb = document.createElement('tbody');
    nt.appendChild(tb);
    np.appendChild(nt);
    LINKS.push({ src: tbl, cont: nt, plac: cont, first: firstUnit });
    return tb;
  }
  function splitPage(pg) {
    var tail = pg; // last page of the chain so far — every new page inserts after it
    var cur = pg;
    var guard = 0;
    while (h(cur) > MAX && guard++ < 1000) {
      var kids = contentKids(cur);
      // first cut point in reading order: the first kid that crosses the budget —
      // except a table, which is cut at its first non-fitting ROW (only a table that
      // straddles the cut decomposes; tables entirely after it move whole, so no
      // empty table skeleton is ever left behind on the source page)
      var kidIdx = -1, cutRow = -1, straddleTbl = null;
      for (k = 0; k < kids.length; k++) {
        var kd = kids[k];
        if (kd.tagName === 'TABLE' && kd.rows.length > 1) {
          var cr = -1;
          for (var r3 = 0; r3 < kd.rows.length; r3++)
            if (bottomIn(cur, kd.rows[r3]) > MAX - 12) { cr = r3; break; }
          if (cr === -1) continue; // table fits (border/margin sliver) — keep scanning
          kidIdx = k; cutRow = cr; straddleTbl = kd; break;
        }
        if (bottomIn(cur, kd) > MAX - 12) { kidIdx = k; break; }
      }
      if (kidIdx < 0) break; // overflow without a crossing unit — nothing to split
      if (kidIdx === 0 && kids.length === 1 && !straddleTbl) break; // unsplittable block
      var wholeTable = false;
      if (straddleTbl) {
        var headRows = straddleTbl.tHead ? straddleTbl.tHead.rows.length : 0;
        // a cut that would leave the source table header-only moves the whole table
        // instead; and a whole-table move is pointless when the table already opens
        // this page and still does not fit — accept that sheet's overflow
        wholeTable = cutRow <= headRows;
        if (wholeTable && kidIdx === 0) break;
      }
      // units to carry forward, in reading order
      var units = [];
      if (wholeTable || !straddleTbl) {
        for (k = kidIdx; k < kids.length; k++) units.push({ kid: kids[k] });
      } else {
        for (k = cutRow; k < straddleTbl.rows.length; k++)
          units.push({ kid: straddleTbl, row: straddleTbl.rows[k],
                       idx: k - (straddleTbl.tHead ? straddleTbl.tHead.rows.length : 0) });
        for (k = kidIdx + 1; k < kids.length; k++) units.push({ kid: kids[k] });
      }
      var np = makePage(pg);
      tail.parentNode.insertBefore(np, tail.nextSibling);
      tail = np;
      if (wholeTable) {
        // a "table continues" placard / TABLE code caption travels with the table it belongs to
        if (kidIdx > 0 && kids[kidIdx - 1].classList &&
            (kids[kidIdx - 1].classList.contains('tbl-cont') ||
             kids[kidIdx - 1].classList.contains('tbl-cap')))
          np.appendChild(kids[kidIdx - 1]);
        for (k = 0; k < units.length; k++) np.appendChild(units[k].kid);
        cur = np;
        continue;
      }
      // fill pages forward: rows of one table flow into a continuation table
      // (placard, cloned thead and colgroup) that opens on each new page; when a page
      // fills, the unit that crossed moves to the NEXT page — nothing ever moves back
      // to the source, so the source keeps nothing below the cut and the page sequence
      // is the reading order by construction. A whole table carried as a unit that
      // still cannot fit a fresh page decomposes into its rows the same way (the
      // element itself is dropped — its rows live on under a cloned thead).
      var target = np;
      var lastKid = null;
      var tb = null;
      function dismantleCont() { // drop a continuation frame left with zero rows
        if (tb && !tb.rows.length) {
          var nt = tb.parentNode;
          var plac = nt.previousElementSibling;
          if (plac && plac.classList && plac.classList.contains('tbl-cont'))
            target.removeChild(plac);
          target.removeChild(nt);
        }
      }
      for (k = 0; k < units.length; k++) {
        var un = units[k];
        if (un.row) {
          var placedRow = false;
          while (!placedRow) {
            var freshPage = !contentKids(target).length;
            if (un.kid !== lastKid) { tb = openCont(target, un.kid, un.idx); lastKid = un.kid; }
            tb.appendChild(un.row);
            if (h(target) <= MAX) { placedRow = true; break; }
            if (freshPage) break; // a row taller than any sheet — accept
            tb.removeChild(un.row);
            dismantleCont();
            lastKid = null;
            var npR = makePage(pg);
            tail.parentNode.insertBefore(npR, tail.nextSibling);
            tail = npR; target = npR;
          }
        } else {
          var kd = un.kid;
          var bigTable = kd.tagName === 'TABLE' && kd.rows.length > 1;
          var placedKid = false;
          while (!placedKid) {
            var freshPage2 = !contentKids(target).length;
            target.appendChild(kd);
            lastKid = null;
            if (h(target) <= MAX) { placedKid = true; break; }
            if (!bigTable) {
              if (freshPage2) { placedKid = true; break; } // monster block — accept
              target.removeChild(kd);
            } else {
              // decompose the table where it sits: body rows flow into continuation
              // tables, the element is dropped once its rows are placed (snapshot the
              // rows first — the list is live and shrinks as rows move out)
              target.removeChild(kd);
              var bodyStart = kd.tHead ? kd.tHead.rows.length : 0;
              var allRows = Array.prototype.slice.call(kd.rows);
              for (var ri = bodyStart; ri < allRows.length; ri++) {
                var rrow = allRows[ri];
                var placedR = false;
                while (!placedR) {
                  var freshPage3 = !contentKids(target).length;
                  if (kd !== lastKid) { tb = openCont(target, kd, ri - bodyStart); lastKid = kd; }
                  tb.appendChild(rrow);
                  if (h(target) <= MAX) { placedR = true; break; }
                  if (freshPage3) break; // monster row — accept
                  tb.removeChild(rrow);
                  dismantleCont();
                  lastKid = null;
                  var npR2 = makePage(pg);
                  tail.parentNode.insertBefore(npR2, tail.nextSibling);
                  tail = npR2; target = npR2;
                }
              }
              placedKid = true; break;
            }
            var npK = makePage(pg);
            tail.parentNode.insertBefore(npK, tail.nextSibling);
            tail = npK; target = npK;
          }
        }
      }
      cur = target;
    }
    return tail;
  }
  var pages = Array.prototype.slice.call(document.querySelectorAll('.page'));
  for (var i = 0; i < pages.length; i++) {
    var np = splitPage(pages[i]);
    var g = 0;
    while (np && h(np) > MAX && g++ < 10) np = splitPage(np);
  }

  // --- continuation placards: real unit counts ---------------------------------
  // Run AFTER all pagination: only then is each source table's row distribution
  // across its continuation tables final. Units are body rows, numbered in
  // reading order across the chain (source first, continuations in order).
  var groups = [];
  LINKS.forEach(function (L) {
    if (!L.cont.isConnected) return; // dismantled continuation frame
    var g2 = null;
    for (var i2 = 0; i2 < groups.length; i2++)
      if (groups[i2].src === L.src) { g2 = groups[i2]; break; }
    if (!g2) { g2 = { src: L.src, conts: [] }; groups.push(g2); }
    g2.conts.push(L);
  });
  groups.forEach(function (g2) {
    function bodyRows(t) {
      return t.rows.length - (t.tHead ? t.tHead.rows.length : 0);
    }
    var chain = [g2.src];
    g2.conts.forEach(function (L) { chain.push(L.cont); });
    var total = 0;
    chain.forEach(function (t) { total += bodyRows(t); });
    var done = 0;
    g2.conts.forEach(function (L) {
      var n = bodyRows(L.cont);
      if (n <= 0) return;
      var a = done + 1, b = done + n;
      done = b;
      var label = L.cont.classList.contains('reg')
        ? 'Contract register continues' : 'Table continues';
      L.plac.textContent = label + ' \u2014 units ' + a + '\u2013' + b + ' of ' + total;
    });
  });
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
    """Markdown -> block list; two pulls happen before the generic block walker:

    - ![alt](figures/x.svg) lines become their own sheets (returned separately);
    - a markdown blockquote opening 'NOTE:'/'CAUTION:'/'WARNING:' becomes a genre
      notice block (black left band + caps label) instead of prose. Other quotes,
      if any ever appear, fall through to the paragraph walker untouched.
    """
    kept, figs = [], []
    for line in text.splitlines():
        m = IMG_RE.match(line.strip())
        if m:
            p = HB / m.group(2)
            figs.append(p if p.exists() else None)
        else:
            kept.append(line)
    blocks: list[str] = []
    buf: list[str] = []

    def flush() -> None:
        if buf:
            blocks.extend(md_blocks(buf))
            buf.clear()

    i, n = 0, len(kept)
    while i < n:
        if kept[i].lstrip().startswith(">"):
            grp = []
            while i < n and kept[i].lstrip().startswith(">"):
                grp.append(re.sub(r"^\s*>\s?", "", kept[i]))
                i += 1
            m = re.match(r"(NOTE|CAUTION|WARNING)\s*:\s*(.+)", " ".join(grp).strip())
            if m:
                flush()
                blocks.append(
                    f'<div class="notice"><span class="lbl">{m.group(1)}</span>'
                    f'<span class="txt">{inline(m.group(2))}</span></div>'
                )
                continue
            buf.extend(f"> {g}" for g in grp)
            continue
        buf.append(kept[i])
        i += 1
    flush()
    return blocks, figs


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

    sheets: list[tuple[str, list[str], str]] = []  # (dochead section, html blocks, tab html)

    # --- S2b thumb tabs: a 3-letter code per part, stepped down the page edge ----
    PART_TAB = {"FM": "FMD", "I": "ARR", "II": "FLW", "III": "MOD",
                "IV": "REG", "V": "SET", "VI": "RSK", "VII": "WRK", "VIII": "DLV"}

    def tab_html(p_id: str, p_idx: int) -> str:
        code = PART_TAB.get(p_id)
        if not code:
            return ""
        top = 22 + (p_idx % 9) * 16  # mm; dictionary-style stepped position per part
        return f'<div class="tab" style="top:{top}mm">{code}</div>'

    # --- S2c change bars: files edited after the folio issue date ----------------
    issue_epoch = time.mktime(time.strptime(today, "%Y-%m-%d"))

    def changed_since_issue(f: pathlib.Path) -> bool:
        if f.stat().st_mtime > issue_epoch:  # uncommitted working-tree edits
            return True
        try:
            out = subprocess.run(
                ["git", "-C", str(ROOT), "log", "-1", "--format=%at", "--", str(f)],
                capture_output=True, text=True,
            ).stdout.strip()
            return bool(out) and int(out) > issue_epoch
        except (ValueError, OSError):
            return False

    def mark_changed(blocks: list[str]) -> list[str]:
        out = []
        for b in blocks:
            for tag in ("p", "pre", "ul", "ol"):
                if b.startswith(f"<{tag}>"):
                    b = b.replace(f"<{tag}>", f'<{tag} class="chg">', 1)
                    break
            out.append(b)
        return out

    # --- S1 table codes: TABLE x.y-n, assigned mechanically from the manifest ----
    counters: dict[tuple[str, int], int] = {}

    def code_tables(blocks: list[str], x: str, y: int, reg: bool) -> list[str]:
        out = []
        head = ""
        for b in blocks:
            mh = re.match(r"^<h[123]>(.*)</h[123]>$", b, re.S)
            if mh:
                head = re.sub(r"<[^>]+>", "", mh.group(1)).strip()
            if b.startswith("<table"):
                n = counters.get((x, y), 0) + 1
                counters[(x, y)] = n
                cap = f"TABLE {x}.{y}-{n}"
                if head:
                    cap += f" — {head}"
                out.append(f'<div class="tbl-cap">{cap}</div>')
                if reg:
                    b = b.replace("<table>", '<table class="reg">', 1)
            out.append(b)
        return out

    rows = ""
    for p in book["parts"]:
        state = (f"{len(p['files'])} chapters" if p["files"]
                 else "<b>NOT WRITTEN — gap sheet follows</b>")
        rows += f"<tr><td>{p['id']}</td><td>{p['title']}</td><td>{state}</td></tr>"
    sheets.append(("CONTENTS",
                   [f"<h1>CONTENTS</h1>"
                    f"<table><thead><tr><th>Part</th><th>Title</th><th>State</th></tr>"
                    f"</thead><tbody>{rows}</tbody></table>"], tab_html("FM", 0)))

    for p_idx, p in enumerate(book["parts"]):
        tab = tab_html(p["id"], p_idx)
        if not p["files"]:
            sheets.append((f"PART {p['id']}",
                           [f"<h1>PART {p['id']} — {p['title']}</h1>",
                            "<p class='gap'>NOT WRITTEN. This sheet exists so the gap is visible in "
                            "the bound book rather than invisible in the file tree.</p>"], tab))
            continue
        # the owning code x.y: x = part prefix (or part id), y = the module number
        # for chapters/M<n>, else the file's 1-based position within the part
        x = str(p.get("prefix", p["id"]))
        for f_idx, rel in enumerate(p["files"], 1):
            f = HB / rel
            if not f.exists():
                sheets.append(("BUILD ERROR",
                               [f"<h1>BUILD ERROR</h1><p>{rel} is in the manifest and not on disk.</p>"],
                               tab))
                continue
            # A module chapter opens with its own centered view: the hero figure sheet is
            # mounted BEFORE the chapter text, coded <part prefix>.<n> from the manifest
            # (Part III's prefix 3 + chapter M<n> -> FIGURE 3.<n>) with the issue date.
            mmod = re.match(r"chapters/M(\d+)-", rel)
            if mmod:
                n = mmod.group(1)
                y = int(n)
                hero = HB / f"figures/module-M{n}.svg"
                code = f"{p.get('prefix', p['id'])}.{n}"
                if hero.exists():
                    sheets.append((f"PART {p['id']} · FIGURE {code}",
                                   [f"<h2>FIGURE {code} — MODULE M{n} CENTERED VIEW — as of {today}</h2>",
                                    svg_fit(hero)], tab))
                else:
                    sheets.append(("BUILD ERROR",
                                   [f"<h1>BUILD ERROR</h1><p>figures/module-M{n}.svg is the "
                                    f"centered view of {rel} and is not on disk.</p>"], tab))
            else:
                y = f_idx
            blocks, figs = body_blocks(f.read_text())
            blocks = code_tables(blocks, x, y, reg=(rel == "parts/IV-contract-register.md"))
            if changed_since_issue(f):
                blocks = mark_changed(blocks)
            sheets.append((f"PART {p['id']} · {p['title'].upper()}", blocks, tab))
            for fig in figs:  # one figure per sheet, hero-sized, caption carries the snapshot date
                if fig is None:
                    continue
                code = fig_codes.get(str(fig.relative_to(HB)), fig.stem.upper())
                sheets.append((f"PART {p['id']} · FIGURE {code}",
                               [f"<h2>FIGURE {code} — as of {today}</h2>", svg_fit(fig)], tab))

    # The .page container is what makes overflow measurable (skill: without it the fit
    # script no-ops and every page is silently unconstrained). The cover is its own page
    # div — a cover carries no dochead. The pagination script bounds every sheet so every
    # rendered page is a real .page div carrying its running head.
    title = doc["title"].upper()
    cover_html = cover(doc_id, doc["title"], doc["subtitle"],
                       (f"ISSUE {today}", doc["classification"], doc["scope"].strip()))
    pages_html = (f'<div class="page">{cover_html}</div>'
                  + "".join(f'<div class="page">{dochead(doc_id, s, title=title)}{t}'
                            f'{chr(10).join(b)}</div>' for s, b, t in sheets))
    html_doc = (f"<!doctype html><html><head><meta charset='utf-8'><style>{CSS}"
                f"{EXTRA_CSS}</style></head><body>{pages_html}"
                f"<script>{PAGINATE_JS}</script></body></html>")

    out_html = pathlib.Path(a.out).with_suffix(".html")
    out_html.write_text(html_doc)
    print_pdf(out_html, a.out)

    # per-page subsystem name for the footer: each rendered page's own running head
    # names the part/section it belongs to (continuations clone it). The head is
    # letter-spaced, so extraction can inject spaces between characters — match by
    # whitespace-stripped section text against the builder's own sheet sections.
    probe = fitz.open(a.out)
    sec_compact = [(s, re.sub(r"\s+", "", s)) for s, _, _ in sheets]
    # longest section name first: a short section that is a prefix of a longer one
    # (e.g. "PART III" vs "PART III · FIGURE 3.5") must not win the suffix match
    sec_compact.sort(key=lambda t: -len(t[1]))
    subsys: list[str] = []
    for i, pg in enumerate(probe, 1):
        name = ""
        if i > 1:
            top = re.sub(r"\s+", "", " ".join(
                b[4] for b in pg.get_text("blocks") if b[1] < 80))
            for s, comp in sec_compact:
                if comp and comp in top:
                    name = s
                    break
        subsys.append(name)
    probe.close()

    stamp(a.out, doc_id, right=f"issue {today}", footer=f"change {today}", subsys=subsys)

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

    # W7 furniture gates: table codes, thumb tabs, genre notices, ink.
    all_text = "".join(pg.get_text() for pg in pdf)
    no_tab = []
    grey = []
    for i, pg in enumerate(pdf, 1):
        if i == 1:
            continue
        w = pg.rect.width
        near_edge = [d for d in pg.get_drawings()
                     if d.get("fill") == (0, 0, 0) and d["rect"].x1 > w - 2.5
                     and (d["rect"].x1 - d["rect"].x0) < 20]
        if not near_edge:
            no_tab.append(i)
        for d in pg.get_drawings():
            for key in ("color", "fill"):
                c = d.get(key)
                if c and all(abs(v - 0.6) < 0.02 for v in c):
                    grey.append((i, key))
                    break
    table_codes = re.findall(r"TABLE [A-Z0-9]+\.\d+-\d+", all_text)
    notices = len(re.findall(r"\b(?:NOTE|CAUTION|WARNING)\b", all_text))
    placards = len(re.findall(r"units \d+[–-]\d+ of \d+", all_text, re.I))
    if len(table_codes) <= 100:
        print(f"FURNITURE FAIL: {len(table_codes)} TABLE x.y-n codes in the book (need >100)")
        return 2
    if no_tab:
        print(f"FURNITURE FAIL: pages without a thumb tab: {no_tab[:8]}")
        return 2
    if notices < 1:
        print("FURNITURE FAIL: no NOTE/CAUTION/WARNING block rendered")
        return 2
    if grey:
        print(f"FURNITURE FAIL: {len(grey)} #999999 stroke/fill drawing(s), first: {grey[0]}")
        return 2
    print(f"OK {a.out} ({pathlib.Path(a.out).stat().st_size} bytes) · {pdf.page_count} pages · "
          f"dochead + folio on every page · fit clean · "
          f"{len(table_codes)} table codes · {placards} continuation unit counts · "
          f"{notices} notice labels · tabs on all pages · zero #999999 strokes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
