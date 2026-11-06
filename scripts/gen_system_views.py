#!/usr/bin/env python3
"""gen_system_views.py — draw the system from docs/SYSTEM-MODEL.yaml.

A box is a RESPONSIBILITY, not a path: nothing here moves when a script moves. The master view is laid
out by graphviz so numbering, arrowheads and layer clusters are the renderer's job, not a hand-tuned
guess. Each flow is drawn as a sequence diagram — time runs down, messages are horizontal, so a payload
can never be ambiguous about which line it belongs to.

    python3 scripts/gen_system_views.py --out /tmp/cf-system-views.pdf
"""

import argparse
import datetime
import html
import pathlib
import subprocess
import sys

import yaml

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from sheet_style import CSS_LANDSCAPE as CSS, cover, dochead, stamp  # noqa: E402

REPO = pathlib.Path(__file__).resolve().parent.parent
MODEL = REPO / "docs/SYSTEM-MODEL.yaml"

STATE = {
    "works": ("#14532d", "solid"),
    "broken": ("#a11d1d", "dashed"),
    "missing": ("#8a5200", "dotted"),
    "external": ("#555555", "solid"),
}


def head_short():
    return datetime.date.today().isoformat()


def esc(s):
    return html.escape(str(s), quote=True)


def nid(x):
    """Graphviz reserves node/edge/graph/subgraph: never emit a bare component id as a node name."""
    return "c_" + str(x)


def dot_quote(s):
    return '"' + str(s).replace('"', '\\"') + '"'


def master_dot(model):
    """One cluster per layer, one node per responsibility, one labelled edge per contract."""
    lines = [
        "digraph system {",
        '  graph [rankdir=TB, nodesep=0.75, ranksep=1.05, splines=spline, fontname="Helvetica", '
        'bgcolor="white", pad=0.25, newrank=true];',
        '  node [shape=box, style="rounded,filled", fillcolor="#fbfaf5", color="#111111", '
        'fontname="Helvetica", fontsize=17, penwidth=1.7, margin="0.16,0.10"];',
        '  edge [fontname="Helvetica", fontsize=15, penwidth=2.1, arrowsize=1.0];',
    ]
    for layer in model["layers"]:
        members = [c for c in model["components"] if c["layer"] == layer["id"]]
        lines.append("  subgraph cluster_%s {" % layer["id"])
        lines.append(
            '    label=%s; labeljust=l; fontsize=15; fontcolor="#666666"; style="dashed"; '
            'color="#bbbbbb";' % dot_quote(layer["name"] + "  ·  " + layer["blurb"])
        )
        for c in members:
            # A box says what the responsibility IS, in as few words as possible. The full owns/not text
            # lives in the component register: a box that carries a paragraph is unreadable at page size.
            label = (
                '<<b>%s</b><br/><font point-size="13" color="#333333">%s</font>>'
                % (esc(c["name"]), esc(c.get("role", c["owns"])))
            )
            lines.append("    %s [label=%s];" % (nid(c["id"]), label))
        lines.append("  }")
    for i, k in enumerate(model["contracts"], 1):
        color, style = STATE.get(k["state"], STATE["external"])
        # the arrow carries a NUMBER and nothing else: every word lives in the contract register, so a
        # label can never be truncated, overlap a box, or be claimed by the wrong line.
        label = "  %d  " % i
        lines.append(
            '  %s -> %s [label=%s, color="%s", style="%s", fontcolor="%s"];'
            % (nid(k["from"]), nid(k["to"]), dot_quote(label), color, style, color)
        )
    lines.append("}")
    return "\n".join(lines)


def render_dot(dot_src, out_svg):
    r = subprocess.run(
        ["dot", "-Tsvg", "-o", str(out_svg)],
        input=dot_src,
        text=True,
        capture_output=True,
        timeout=300,
    )
    if r.returncode != 0:
        raise SystemExit("dot failed: " + r.stderr[-400:])
    return out_svg


def seq_svg(model, flow):
    """Sequence diagram: lifelines across, time down. A payload always sits beside its own arrow."""
    by_id = {c["id"]: c for c in model["components"]}
    actors = []
    for a, b, _ in flow["steps"]:
        for x in (a, b):
            if x not in actors:
                actors.append(x)
    cw, top, rowh = 240, 108, 88
    width = cw * len(actors) + 60
    height = top + rowh * len(flow["steps"]) + 50
    ax = {a: 30 + i * cw + cw / 2 for i, a in enumerate(actors)}
    out = [
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="100%%" '
        'preserveAspectRatio="xMidYMid meet">' % (width, height),
        '<rect width="%d" height="%d" fill="#fff"/>' % (width, height),
        '<defs><marker id="ar" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" '
        'orient="auto"><path d="M0,0 L10,5 L0,10 z" fill="#111"/></marker></defs>',
    ]
    for a in actors:
        x = ax[a]
        out.append(
            '<rect x="%.0f" y="16" width="%d" height="48" rx="3" fill="#fbfaf5" '
            'stroke="#111" stroke-width="1.6"/>' % (x - cw / 2 + 16, cw - 32)
        )
        out.append(
            '<text x="%.0f" y="46" font-size="16" font-weight="700" text-anchor="middle" '
            'letter-spacing="1">%s</text>' % (x, esc(by_id[a]["name"]))
        )
        out.append(
            '<line x1="%.0f" y1="64" x2="%.0f" y2="%d" stroke="#bbbbbb" stroke-width="1" '
            'stroke-dasharray="4 4"/>' % (x, x, height - 16)
        )
    for i, (a, b, what) in enumerate(flow["steps"]):
        y = top + i * rowh
        x1, x2 = ax[a], ax[b]
        out.append(
            '<text x="14" y="%d" font-size="15" fill="#888">%d</text>' % (y - 9, i + 1)
        )
        if a == b:
            out.append(
                '<path d="M%.0f,%d h30 v30 h-30" fill="none" stroke="#111" stroke-width="1.6" '
                'marker-end="url(#ar)"/>' % (x1, y - 4)
            )
            mx, anchor = x1 + 46, "start"
        else:
            out.append(
                '<line x1="%.0f" y1="%d" x2="%.0f" y2="%d" stroke="#111" stroke-width="1.6" '
                'marker-end="url(#ar)"/>' % (x1, y, x2, y)
            )
            mx, anchor = (x1 + x2) / 2, "middle"
            if mx < 170:
                mx, anchor = 150, "start"
            elif mx > width - 170:
                mx, anchor = width - 150, "end"
        out.append(
            '<text x="%.0f" y="%d" font-size="15" fill="#14532d" text-anchor="%s">%s</text>'
            % (mx, y - 9, anchor, esc(what))
        )
    out.append("</svg>")
    return "\n".join(out)


def component_table(model):
    layer_name = {lay["id"]: lay["name"] for lay in model["layers"]}
    rows = []
    for c in model["components"]:
        impl = ", ".join(c.get("impl", [])) or "—"
        rows.append(
            "<tr><td><b>%s</b></td><td>%s</td><td>%s</td><td>%s</td><td><code>%s</code></td></tr>"
            % (
                esc(c["name"]),
                esc(layer_name.get(c["layer"], c["layer"])),
                esc(c["owns"]),
                esc(c["not"]),
                esc(impl),
            )
        )
    return (
        "<table><thead><tr><th>Component</th><th>Layer</th><th>Owns</th><th>Does not</th>"
        "<th>Implemented today at</th></tr></thead><tbody>"
        + "".join(rows)
        + "</tbody></table>"
    )


def contract_table(model):
    by_id = {c["id"]: c for c in model["components"]}
    rows = []
    for i, k in enumerate(model["contracts"], 1):
        rows.append(
            "<tr><td><b>%d</b></td><td>%s → %s</td><td>%s</td><td>%s</td>"
            "<td class='st-%s'>%s</td><td>%s</td></tr>"
            % (
                i,
                esc(by_id[k["from"]]["name"]),
                esc(by_id[k["to"]]["name"]),
                esc(k["carries"]),
                esc(k["mode"]),
                esc(k["state"]),
                esc(k["state"]).upper(),
                esc(k.get("note", "")),
            )
        )
    return (
        "<table><thead><tr><th>#</th><th>Contract</th><th>Carries</th><th>Mode</th><th>State</th>"
        "<th>What breaks</th></tr></thead><tbody>" + "".join(rows) + "</tbody></table>"
    )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="/tmp/cf-system-views.pdf")
    ap.add_argument("--workdir", default="/tmp/cf-views")
    a = ap.parse_args()
    wd = pathlib.Path(a.workdir)
    wd.mkdir(parents=True, exist_ok=True)

    model = yaml.safe_load(MODEL.read_text())
    doc = model["doc"]

    dot_src = master_dot(model)
    (wd / "master.dot").write_text(dot_src)
    render_dot(dot_src, wd / "master.svg")

    broken = [k for k in model["contracts"] if k["state"] != "works"]

    def P(section, body):
        return "<div class='page'>" + dochead(doc["id"], section) + body + "</div>"

    pages = [
        cover(
            doc["id"],
            doc["title"],
            doc["subtitle"],
            (
                "Systems view &middot; components, contracts, flows",
                "%d components &middot; %d contracts &middot; <b>%d do not hold</b>"
                % (len(model["components"]), len(model["contracts"]), len(broken)),
                "Generated from docs/SYSTEM-MODEL.yaml",
            ),
        ),
        P(
            "MASTER SYSTEM VIEW",
            "<h1>%s — %s</h1><h2>%s &middot; a box is a responsibility, not a file; every arrow is a numbered "
            "contract, and <b>%d of %d do not hold as specified</b></h2>"
            "<img src='master.svg' style='height:168mm'/>"
            "<div class='legend'>"
            "<span style='color:#14532d'><b>— solid</b> works</span>"
            "<span style='color:#a11d1d'><b>-- dashed</b> broken</span>"
            "<span style='color:#8a5200'><b>·· dotted</b> missing</span>"
            "<span style='color:#555'><b>— grey</b> external</span></div>"
            % (
                esc(doc["id"]),
                esc(doc["title"]),
                esc(doc["subtitle"]),
                len(broken),
                len(model["contracts"]),
            ),
        ),
    ]

    pages.append(
        P(
            "COMPONENT REGISTER",
            "<h1>COMPONENT REGISTER</h1>"
            "<h2>what each box owns, what it explicitly does not do, and where it lives today</h2>"
            "<p class='lede'>The <b>impl</b> column is the only volatile thing on these pages: it names "
            "where the responsibility is implemented now. Move a script, rename a repo, and the model "
            "does not change — only this column does.</p>" + component_table(model),
        )
    )

    pages.append(
        P(
            "CONTRACT REGISTER",
            "<h1>CONTRACT REGISTER</h1>"
            "<h2>every arrow in the master view, what it carries, how, and its measured state</h2>"
            + contract_table(model),
        )
    )

    for fl in model["flows"]:
        svg = seq_svg(model, fl)
        (wd / (fl["id"] + ".svg")).write_text(svg, encoding="utf-8")
        pages.append(
            P(
                fl["name"],
                "<h1>%s — %s</h1><h2>%s</h2>"
                "<img src='%s.svg' style='height:150mm'/>"
                "<div class='legend'>%s</div>"
                % (
                    esc(fl["id"]),
                    esc(fl["name"]),
                    esc(fl["question"]),
                    esc(fl["id"]),
                    esc(fl.get("note", "")),
                ),
            )
        )

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
    # The running foot and sheet number go on AFTER print: Chrome has no reliable margin-box folio,
    # and an unnumbered sheet cannot be cited.
    stamp(a.out, doc["id"], footer=datetime.date.today().isoformat())
    print(
        "pdf: %s (%.1f KB) — %d components, %d contracts (%d not working), %d flows"
        % (
            a.out,
            pathlib.Path(a.out).stat().st_size / 1024,
            len(model["components"]),
            len(model["contracts"]),
            len(broken),
            len(model["flows"]),
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
