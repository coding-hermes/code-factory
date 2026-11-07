#!/usr/bin/env python3
"""gen_nasa_handbook.py — build the NASA-format handbook from docs/master.

One A4 document, NASA-ish typography, generated from the markdown the checker already grades, so the
PDF can never say something the gate would reject without that being visible in the same tree.

    python3 scripts/gen_nasa_handbook.py --out /tmp/cf-handbook.pdf
"""

import argparse
import html
import pathlib
import re
import subprocess
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
MODULES = REPO / "docs/master"

CSS = """
@page { size: A4; margin: 20mm 16mm 18mm 16mm; }
html { font-size: 9.1pt; }
body { font-family: "Iowan Old Style", "Palatino Linotype", Georgia, serif; color: #000; line-height: 1.34;
       letter-spacing: 0.01em; margin: 0; }
h1 { font-family: "Helvetica Neue", Arial, sans-serif; font-size: 14pt; letter-spacing: 0.06em;
     text-transform: uppercase; border-bottom: 1.6pt solid #000; padding-bottom: 2mm; margin: 0 0 4mm;
     page-break-after: avoid; }
h2 { font-family: "Helvetica Neue", Arial, sans-serif; font-size: 10.6pt; letter-spacing: 0.1em;
     text-transform: uppercase; margin: 6mm 0 2mm; border-bottom: 0.6pt solid #666; padding-bottom: 1mm;
     page-break-after: avoid; }
h3 { font-size: 9.8pt; font-style: italic; margin: 4mm 0 1.4mm; page-break-after: avoid; }
p { margin: 0 0 2.2mm; text-align: justify; hyphens: auto; }
ul, ol { margin: 0 0 2.4mm 5mm; padding: 0; }
li { margin: 0 0 1.1mm; }
table { width: 100%; border-collapse: collapse; margin: 1.5mm 0 3.4mm; font-size: 8.2pt;
        font-family: "Helvetica Neue", Arial, sans-serif; }
th { text-align: left; font-weight: 700; border-bottom: 1pt solid #111; padding: 1.1mm 1.6mm;
     background: #efeee8; letter-spacing: 0.03em; }
td { border-bottom: 0.4pt solid #bbb; padding: 1.1mm 1.6mm; vertical-align: top; }
tr { page-break-inside: avoid; }
code { font-family: "SF Mono", Menlo, "DejaVu Sans Mono", monospace; font-size: 7.9pt;
       background: #f1f0ea; padding: 0 0.6mm; }
pre { font-family: "SF Mono", Menlo, "DejaVu Sans Mono", monospace; font-size: 7.6pt; background: #f4f3ed;
      border-left: 2pt solid #999; padding: 1.8mm 2.4mm; margin: 1.6mm 0 3mm; white-space: pre-wrap;
      page-break-inside: avoid; }
blockquote { margin: 2mm 0 2mm 4mm; padding-left: 3mm; border-left: 1.4pt solid #999; color: #333; }
hr { border: 0; border-top: 0.5pt solid #999; margin: 4mm 0; }
a { color: #111; text-decoration: none; border-bottom: 0.4pt dotted #666; }
.cover { text-align: center; page-break-after: always; padding-top: 45mm; }
.cover .doc { font-family: "Helvetica Neue", Arial, sans-serif; letter-spacing: 0.3em; font-size: 9pt; }
.cover h1 { border: 0; font-size: 26pt; letter-spacing: 0.2em; margin: 12mm 0 6mm; }
.cover .sub { font-size: 11pt; letter-spacing: 0.08em; }
.cover .meta { margin-top: 40mm; font-family: "Helvetica Neue", Arial, sans-serif; font-size: 8.4pt;
               letter-spacing: 0.06em; line-height: 1.9; }
.toc { page-break-after: always; }
.toc h1 { font-size: 13pt; }
.toc ol { list-style: none; margin-left: 0; font-family: "Helvetica Neue", Arial, sans-serif; font-size: 8.6pt; }
.toc li { display: flex; border-bottom: 0.3pt dotted #999; padding: 1mm 0; }
.toc .n { width: 16mm; }
.toc .t { flex: 1; }
.toc .s { width: 22mm; text-align: right; letter-spacing: 0.06em; }
.module { page-break-before: always; }
.module .dochead { font-family: "Helvetica Neue", Arial, sans-serif; font-size: 7.6pt; letter-spacing: 0.16em;
                   text-transform: uppercase; color: #444; border-bottom: 0.6pt solid #999;
                   padding-bottom: 1.2mm; margin-bottom: 3mm; }
.status-RED { color: #8a1c1c; font-weight: 700; }
.status-VERIFIED { color: #14532d; font-weight: 700; }
.status-UNVERIFIED, .status-FAILING { color: #7a4a00; font-weight: 700; }
"""


def inline(text):
    text = html.escape(text)
    text = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", text)
    text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)
    text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r"<a href='\2'>\1</a>", text)
    text = re.sub(r"(?<!\*)\*([^*]+)\*(?!\*)", r"<i>\1</i>", text)
    return text


def split_cells(row: str) -> list[str]:
    """Split a table row on pipes that are OUTSIDE inline code spans.

    A pipe inside backticks is content (a grep pattern, `bytes | None`); splitting
    on it tore cells apart and left stray backslash fragments in the printed row.
    """
    cells, buf, in_code = [], [], False
    for ch in row:
        if ch == "`":
            in_code = not in_code
            buf.append(ch)
        elif ch == "|" and not in_code:
            cells.append("".join(buf))
            buf = []
        else:
            buf.append(ch)
    cells.append("".join(buf))
    return cells


def md_to_html(lines):
    return "\n".join(md_blocks(lines))


def md_blocks(lines):
    out, i, n = [], 0, len(lines)
    while i < n:
        line = lines[i]
        if not line.strip():
            i += 1
            continue
        if line.startswith("```"):
            i += 1
            buf = []
            while i < n and not lines[i].startswith("```"):
                buf.append(html.escape(lines[i]))
                i += 1
            i += 1
            out.append("<pre>%s</pre>" % "\n".join(buf))
            continue
        m = re.match(r"^(#{1,6})\s+(.*)$", line)
        if m:
            lvl = len(m.group(1))
            tag = "h1" if lvl == 1 else ("h2" if lvl == 2 else "h3")
            out.append("<%s>%s</%s>" % (tag, inline(m.group(2)), tag))
            i += 1
            continue
        if line.lstrip().startswith("|"):
            rows = []
            while i < n and lines[i].lstrip().startswith("|"):
                rows.append(lines[i])
                i += 1
            cells = [[c.strip() for c in split_cells(r.strip().strip("|"))] for r in rows]
            body = [
                c
                for c in cells
                if not all(re.fullmatch(r":?-{2,}:?", x or "-") for x in c)
            ]
            if body:
                head, rest = body[0], body[1:]
                out.append(
                    "<table><thead><tr>%s</tr></thead><tbody>%s</tbody></table>"
                    % (
                        "".join("<th>%s</th>" % inline(c) for c in head),
                        "".join(
                            "<tr>%s</tr>"
                            % "".join("<td>%s</td>" % inline(c) for c in row)
                            for row in rest
                        ),
                    )
                )
            continue
        if re.match(r"^\s*([-*]|\d+\.)\s+", line):
            ordered = bool(re.match(r"^\s*\d+\.", line))
            items = []
            while i < n and re.match(r"^\s*([-*]|\d+\.)\s+", lines[i]):
                items.append(re.sub(r"^\s*([-*]|\d+\.)\s+", "", lines[i]))
                i += 1
                # Hanging-indent continuation lines belong to this item. Left
                # alone they rendered as orphaned paragraphs after the list.
                # An indented line that is itself a list item is a (flattened)
                # sub-item, not a continuation.
                while i < n and re.match(r"^\s{2,}\S", lines[i]) and not re.match(
                    r"^\s*([-*]|\d+\.)\s+", lines[i]
                ):
                    items[-1] += " " + lines[i].strip()
                    i += 1
            tag = "ol" if ordered else "ul"
            out.append(
                "<%s>%s</%s>"
                % (tag, "".join("<li>%s</li>" % inline(x) for x in items), tag)
            )
            continue
        if line.startswith(">"):
            buf = []
            while i < n and lines[i].startswith(">"):
                buf.append(lines[i].lstrip("> ").rstrip())
                i += 1
            out.append("<blockquote>%s</blockquote>" % inline(" ".join(buf)))
            continue
        if re.fullmatch(r"-{3,}", line.strip()):
            out.append("<hr>")
            i += 1
            continue
        para = [line.strip()]
        i += 1
        while (
            i < n
            and lines[i].strip()
            and not re.match(
                r"^(#{1,6}\s|\||```|>|\s*[-*]\s|\s*\d+\.\s|-{3,}$)", lines[i]
            )
        ):
            para.append(lines[i].strip())
            i += 1
        out.append("<p>%s</p>" % inline(" ".join(para)))
    return out


def status_of(text):
    m = re.search(r"\|\s*Status\s*\|\s*\*\*([A-Z]+)", text)
    return m.group(1) if m else "RED"


def deficiency_chapter(board_path, limit_per_priority=40):
    """A problem report generated from the board, so the handbook states its own open defects.

    Only rows that are NOT complete, ordered P1 first: a reader of the PDF should be able to see what
    the document set admits is broken without opening the repository.
    """
    import json as _json

    rows = []
    try:
        for line in pathlib.Path(board_path).read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                r = _json.loads(line)
            except _json.JSONDecodeError:
                continue
            if r.get("status") == "complete":
                continue
            rows.append(r)
    except OSError:
        return ""
    order = {"P1": 0, "P2": 1, "P3": 2}
    rows.sort(key=lambda r: (order.get(r.get("priority", "P3"), 3), str(r.get("id"))))
    out = [
        "<div class='module'><div class='dochead'>CF2A-DR &middot; PROBLEM / DEFICIENCY REPORT</div>"
        "<h1>Open deficiencies carried by this document set</h1>"
        "<p>Generated from <code>.coding-hermes/board/tasks.jsonl</code>: every row not yet complete, "
        "P1 first. Each one was measured by whoever documented the module it belongs to; none is a "
        "projection. The counts below are the handbook's own statement of what it cannot yet "
        "claim.</p>"
    ]
    counts = {}
    for r in rows:
        counts[r.get("priority", "P3")] = counts.get(r.get("priority", "P3"), 0) + 1
    out.append(
        "<p><b>%d open rows</b> &mdash; %s</p>"
        % (
            len(rows),
            " &middot; ".join("%s: %d" % (k, counts[k]) for k in sorted(counts)),
        )
    )
    current = None
    shown = {}
    for r in rows:
        pri = r.get("priority", "P3")
        shown[pri] = shown.get(pri, 0) + 1
        if shown[pri] > limit_per_priority:
            continue
        if pri != current:
            if current is not None:
                out.append("</tbody></table>")
            out.append(
                "<h2>%s (%d open)</h2><table><thead><tr><th style='width:16mm'>Id</th>"
                "<th>Deficiency</th><th style='width:22mm'>Status</th></tr></thead><tbody>"
                % (pri, counts.get(pri, 0))
            )
            current = pri
        out.append(
            "<tr><td>%s</td><td>%s</td><td>%s</td></tr>"
            % (
                inline(str(r.get("id", ""))),
                inline(str(r.get("title", ""))),
                inline(str(r.get("status", ""))),
            )
        )
    if current is not None:
        out.append("</tbody></table>")
    out.append(
        "<p><i>Rows beyond %d per priority are omitted here; the board is authoritative.</i></p></div>"
        % limit_per_priority
    )
    return "\n".join(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="/tmp/code-factory-handbook.pdf")
    ap.add_argument("--html", default="/tmp/cf-handbook.html")
    a = ap.parse_args()

    mods = [
        p
        for p in sorted(MODULES.glob("[0-9][0-9]-*.md"))
        if not p.name.startswith("00-")
    ]
    if not mods:
        print("no modules found")
        return 1

    parts = []
    parts.append(
        "<div class='cover'><div class='doc'>CF2A-00</div>"
        "<h1>CODE-FACTORY</h1><div class='sub'>Operations Handbook &mdash; System Description "
        "and Verification Record</div><div class='meta'>"
        "MODULES %d &middot; GENERATED FROM docs/master &middot; EVERY CLAIM LOCATOR-BACKED<br>"
        "EDITION %s &middot; CONTROL HOST (identity withheld)</div></div>"
        % (len(mods), html.escape(__import__("datetime").date.today().isoformat()))
    )

    toc = ["<div class='toc'><h1>Contents</h1><ol>"]
    for p in mods:
        t = p.read_text(encoding="utf-8")
        title = t.splitlines()[0].lstrip("# ").strip() if t.splitlines() else p.stem
        st = status_of(t)
        toc.append(
            "<li><span class='n'>%s</span><span class='t'>%s</span>"
            "<span class='s status-%s'>%s</span></li>"
            % (p.name[:2], html.escape(title), st, st)
        )
    toc.append("</ol></div>")
    parts.append("\n".join(toc))
    dr = deficiency_chapter(REPO / ".coding-hermes/board/tasks.jsonl")
    if dr:
        parts.append(dr)

    for p in mods:
        t = p.read_text(encoding="utf-8")
        st = status_of(t)
        body = md_to_html(t.splitlines())
        parts.append(
            "<div class='module'><div class='dochead'>CF2A-%s &middot; %s &middot; %s</div>%s</div>"
            % (p.name[:2], html.escape(p.stem), st, body)
        )

    doc = (
        "<!doctype html><html><head><meta charset='utf-8'>"
        "<title>code-factory operations handbook</title><style>%s</style></head><body>%s</body></html>"
        % (CSS, "\n".join(parts))
    )
    pathlib.Path(a.html).write_text(doc, encoding="utf-8")
    print("html: %s (%.1f KB)" % (a.html, len(doc) / 1024))

    chrome = "/usr/bin/google-chrome"
    cmd = [
        chrome,
        "--headless",
        "--disable-gpu",
        "--no-sandbox",
        "--no-pdf-header-footer",
        "--print-to-pdf=" + a.out,
        pathlib.Path(a.html).resolve().as_uri(),
    ]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=900)
    if r.returncode != 0 or not pathlib.Path(a.out).exists():
        print("chrome failed: %s" % (r.stderr or r.stdout)[-400:])
        return 1
    print("pdf: %s (%.1f KB)" % (a.out, pathlib.Path(a.out).stat().st_size / 1024))
    return 0


if __name__ == "__main__":
    sys.exit(main())
