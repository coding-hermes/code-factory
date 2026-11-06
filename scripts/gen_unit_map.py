#!/usr/bin/env python3
"""gen_unit_map.py — draw which module and submodule each script serves, and what calls it.

docs/UNIT-MAP.yaml says which responsibility a unit belongs to and what it changes. The TRIGGER is not
authored: this script measures it, by finding every code reference to the unit and printing the line that
does the referencing. A condition the call site shows is therefore always evidence, never a claim.

    python3 scripts/gen_unit_map.py --out /tmp/cf-unit-map.pdf
"""

import argparse
import datetime
import html
import json
import pathlib
import re
import subprocess
import sys

import yaml

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from sheet_style import CSS_LANDSCAPE as CSS, cover, dochead, stamp  # noqa: E402

REPO = pathlib.Path(__file__).resolve().parent.parent
MAP = REPO / "docs/UNIT-MAP.yaml"
# A trigger is CODE. Config, records and docs mention units constantly and prove nothing about who
# runs them, so only shell and python count as callers.
SCAN_SUFFIX = {".sh", ".py"}
# generators embed unit names in their own prose; they never call them
NOT_CALLERS = {"gen_unit_map.py", "gen_system_views.py", "gen_nasa_handbook.py"}


def esc(s):
    return html.escape(str(s), quote=True)


def scan_refs():
    """unit name -> [{'at': file:line, 'text': line}] for CODE files only. Docs are not triggers."""
    units = sorted(
        p.name
        for p in (REPO / "scripts").rglob("*")
        if p.is_file() and p.suffix in (".py", ".sh")
    )
    units.append("boardctl")
    refs = {u: [] for u in units}
    for f in REPO.rglob("*"):
        if not f.is_file() or f.suffix not in SCAN_SUFFIX:
            continue
        if ".git/" in str(f) or str(f).startswith(str(REPO / "docs")):
            continue
        if f.name in NOT_CALLERS:
            continue
        try:
            lines = f.read_text(errors="replace").splitlines()
        except Exception:
            continue
        for u in units:
            if f.name == u:
                continue
            pat = re.compile(r"(?<![\w.-])" + re.escape(u) + r"(?![\w.-])")
            for i, line in enumerate(lines, 1):
                if pat.search(line):
                    refs[u].append(
                        {
                            "at": "%s:%d" % (f.relative_to(REPO), i),
                            "text": line.strip()[:160],
                        }
                    )
                    break
    for u in refs:
        refs[u].sort(
            key=lambda r: 0 if re.search(r"[\$]|python3|bash|\./", r["text"]) else 1
        )
    return refs


def module_dot(model, mid, refs):
    """One module: a cluster per submodule, a node per unit, an edge where a unit is referenced by another unit."""
    mod = next(m for m in model["modules"] if m["id"] == mid)
    owner = {}
    for sm in mod["submodules"]:
        for u in sm["units"]:
            owner[u["unit"]] = sm["id"]
    lines = [
        "digraph m {",
        "  graph [rankdir=LR, nodesep=0.35, ranksep=1.1, splines=spline, "
        'fontname="Helvetica", pad=0.15];',
        '  node [shape=box, style="rounded,filled", fillcolor="#fbfaf5", fontname="Helvetica", '
        'fontsize=13, penwidth=1.4, margin="0.12,0.07"];',
        '  edge [fontname="Helvetica", fontsize=10, penwidth=1.4, color="#14532d", arrowsize=0.7];',
    ]
    for sm in mod["submodules"]:
        lines.append("  subgraph cluster_%s {" % sm["id"].replace(".", "_"))
        lines.append(
            '    label="%s"; labeljust=l; fontsize=12; fontcolor="#555555"; style="dashed"; '
            'color="#bbbbbb";' % sm["name"].replace('"', "'")
        )
        for u in sm["units"]:
            lines.append('    "%s" [label="%s"];' % (u["unit"], u["unit"]))
        lines.append("  }")
    drawn = set()
    for u in {x["unit"] for sm in mod["submodules"] for x in sm["units"]}:
        for r in refs.get(u, []):
            caller = pathlib.PurePath(r["at"].split(":")[0]).name
            if caller in owner and caller != u and (caller, u) not in drawn:
                drawn.add((caller, u))
                lines.append('  "%s" -> "%s";' % (caller, u))
    lines.append("}")
    return "\n".join(lines), drawn


def master_dot(model, refs):
    """Modules as boxes, with the edges MEASURED: an arrow means a unit in one module references a unit in
    another. Counts are references, not importance."""
    unit_mod = {}
    for m in model["modules"]:
        for sm in m["submodules"]:
            for u in sm["units"]:
                unit_mod[u["unit"]] = m["id"]
    edges = {}
    for unit, refs_list in refs.items():
        dst = unit_mod.get(unit)
        if not dst:
            continue
        for r in refs_list:
            caller = pathlib.PurePath(r["at"].split(":")[0]).name
            src = unit_mod.get(caller)
            if src and src != dst:
                edges[(src, dst)] = edges.get((src, dst), 0) + 1

    lines = [
        "digraph units {",
        "  graph [rankdir=LR, nodesep=0.45, ranksep=1.5, splines=spline, "
        'fontname="Helvetica", pad=0.2];',
        '  node [shape=box, style="rounded,filled", fillcolor="#fbfaf5", fontname="Helvetica", '
        'fontsize=17, penwidth=1.7, margin="0.18,0.10"];',
        '  edge [color="#14532d", penwidth=1.8, arrowsize=0.8, fontname="Helvetica", fontsize=13, '
        'fontcolor="#14532d"];',
    ]
    for m in model["modules"]:
        n = sum(len(sm["units"]) for sm in m["submodules"])
        lines.append(
            '  "%s" [label=<<b>%s</b><br/><font point-size="13">%s</font>'
            '<br/><font point-size="12" color="#666666">%d submodule%s · %d unit%s</font>>];'
            % (
                m["id"],
                esc(m["name"]),
                esc(m["blurb"]),
                len(m["submodules"]),
                "" if len(m["submodules"]) == 1 else "s",
                n,
                "" if n == 1 else "s",
            )
        )
    for (a, b), n in sorted(edges.items()):
        lines.append('  "%s" -> "%s" [label=" %d "];' % (a, b, n))
    lines.append("}")
    return "\n".join(lines)


def render(dot_src, out):
    r = subprocess.run(
        ["dot", "-Tsvg", "-o", str(out)],
        input=dot_src,
        text=True,
        capture_output=True,
        timeout=300,
    )
    if r.returncode != 0:
        raise SystemExit("dot failed: " + r.stderr[-300:])


def unit_rows(mod, refs):
    rows = []
    for sm in mod["submodules"]:
        for u in sm["units"]:
            r = refs.get(u["unit"], [])
            trig = (
                "<br/>".join(
                    "<code>%s</code> %s" % (esc(x["at"]), esc(x["text"])) for x in r[:2]
                )
                if r
                else "<span class='none'>no code caller — operator or documented only</span>"
            )
            rows.append(
                "<tr><td><b>%s</b></td><td>%s</td><td>%s</td><td class='trig'>%s</td></tr>"
                % (esc(u["unit"]), esc(sm["name"]), esc(u["effect"]), trig)
            )
    return rows


def table_of(rows):
    return (
        "<table><thead><tr><th>Unit</th><th>Submodule</th><th>What changes when it runs</th>"
        "<th>Invoked from (measured)</th></tr></thead><tbody>"
        + "".join(rows)
        + "</tbody></table>"
    )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="/tmp/cf-unit-map.pdf")
    ap.add_argument("--workdir", default="/tmp/cf-unitmap")
    a = ap.parse_args()
    wd = pathlib.Path(a.workdir)
    wd.mkdir(parents=True, exist_ok=True)

    model = yaml.safe_load(MAP.read_text())
    refs = scan_refs()

    render(master_dot(model, refs), wd / "master.svg")
    total_units = sum(
        len(sm["units"]) for m in model["modules"] for sm in m["submodules"]
    )
    orphan = [
        u["unit"]
        for m in model["modules"]
        for sm in m["submodules"]
        for u in sm["units"]
        if not refs.get(u["unit"])
    ]
    pages = [
        "<div class='page'><h1>UNIT MAP — which module each script serves</h1>"
        "<h2>%d modules · %d submodules · %d units · %d with no code caller</h2>"
        "<p class='lede'>A unit is a script. A submodule is a responsibility inside a module. A module is "
        "a reason the system exists. The grouping is not by directory: <code>node_seed.py</code> sits in "
        "PROVISIONING because a node without a seed cannot work, even though it lives in "
        "<code>scripts/</code> next to the board tools.</p>"
        "<img src='master.svg' style='width:258mm'/>"
        "<p class='lede'>An arrow means a unit in one module references a unit in another; the number is how many such references were measured in code. It is a coupling count, not an importance score.</p></div>"
        % (
            len(model["modules"]),
            sum(len(m["submodules"]) for m in model["modules"]),
            total_units,
            len(orphan),
        )
    ]

    for m in model["modules"]:
        dot_src, edges = module_dot(model, m["id"], refs)
        render(dot_src, wd / ("%s.svg" % m["id"]))
        rows = unit_rows(m, refs)
        for i in range(0, len(rows), 7):
            chunk = rows[i : i + 7]
            first = i == 0
            head = (
                (
                    "<div class='page'><h1>%s — %s</h1><h2>%s · %d submodules · units %d-%d of %d · %d "
                    "measured unit-to-unit calls</h2><img src='%s.svg' style='height:%dmm'/>"
                    % (
                        esc(m["id"]),
                        esc(m["name"]),
                        esc(m["blurb"]),
                        len(m["submodules"]),
                        i + 1,
                        i + len(chunk),
                        len(rows),
                        len(edges),
                        esc(m["id"]),
                        62,
                    )
                )
                if first
                else (
                    "<div class='page'><h1>%s — %s (continued)</h1><h2>units %d-%d of %d</h2>"
                    % (esc(m["id"]), esc(m["name"]), i + 1, i + len(chunk), len(rows))
                )
            )
            cont = (
                ""
                if i + len(chunk) >= len(rows)
                else "<p class='lede'><i>Table continues on the next sheet.</i></p>"
            )
            legend = (
                (
                    "<div class='legend'>Red <b>no code caller</b> means nothing in the repo invokes this unit: "
                    "an operator types it, or a lane prompt does. That is a fact about the system, not a gap in "
                    "the scan.</div>"
                )
                if first
                else ""
            )
            pages.append(head + table_of(chunk) + cont + legend + "</div>")

    # one house style for every sheet: cover, document head, running foot
    pages.insert(
        0,
        cover(
            "CF2A-11",
            "UNIT MAP",
            "Modules, submodules, units and their triggers",
            (
                "%d modules &middot; %d submodules &middot; %d units"
                % (
                    len(model["modules"]),
                    sum(len(m["submodules"]) for m in model["modules"]),
                    total_units,
                ),
                "%d units have no code caller" % len(orphan),
                "Generated from docs/UNIT-MAP.yaml",
            ),
        ),
    )
    withhead = []
    for page in pages:
        m = re.search(r"<h1>([^<]*)</h1>", page)
        section = m.group(1) if m else "UNIT MAP"
        withhead.append(
            page.replace(
                "<div class='page'>",
                "<div class='page'>" + dochead("CF2A-11", section),
                1,
            )
            if page.startswith("<div class='page'>")
            else page
        )
    pages = withhead

    (wd / "index.html").write_text(
        "<!doctype html><html><head><meta charset='utf-8'><style>"
        + CSS
        + "</style></head><body>"
        + "\n".join(pages)
        + "</body></html>",
        encoding="utf-8",
    )
    subprocess.run(
        [
            "/usr/bin/google-chrome",
            "--headless",
            "--disable-gpu",
            "--no-sandbox",
            "--no-pdf-header-footer",
            "--print-to-pdf=" + a.out,
            (wd / "index.html").resolve().as_uri(),
        ],
        capture_output=True,
        text=True,
        timeout=600,
    )
    stamp(a.out, "CF2A-11", footer=datetime.date.today().isoformat())
    json.dump(refs, open(wd / "refs.json", "w"), indent=1)
    print(
        "pdf: %s (%.1f KB) — %d modules, %d units, %d with no code caller"
        % (
            a.out,
            pathlib.Path(a.out).stat().st_size / 1024,
            len(model["modules"]),
            total_units,
            len(orphan),
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
