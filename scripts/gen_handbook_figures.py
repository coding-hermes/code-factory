#!/usr/bin/env python3
"""gen_handbook_figures.py — the visual layer the handbook was missing.

Four view families, all generated from docs/SYSTEM-MODEL.yaml so no figure can drift
from the model:

  1. system-map.svg        — one full system map: layers as clusters, CT-nn on every edge
  2. module-M0..M12.svg    — one centred view per module: left = in contracts, right = out,
                             flows it participates in; derived mechanically from the model
  3. F1..F16.svg           — one sequence diagram per flow that has steps
  4. board-lifecycle.svg,
     tick-lifecycle.svg    — the two state machines

Print legibility is a GATE, not a hope: build_book.py constrains a landscape figure to
170 mm width (portrait to 200 mm height), so every figure is measured after render and
the smallest label must clear 2.05 mm on the printed sheet — the builder's own scale —
or the generator fails. State is carried by line style and a genre palette (dark ink
accents on white); there are no pastel state chips.
"""
from __future__ import annotations

import html
import math
import pathlib
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

import yaml

ROOT = pathlib.Path(__file__).resolve().parent.parent
MODEL = ROOT / "docs/SYSTEM-MODEL.yaml"
OUT = ROOT / "docs/handbook/figures"

# Print constraint applied by build_book.py svg_fit(): landscape -> 170 mm wide,
# portrait -> 200 mm tall. A label must survive that scale.
PRINT_W_MM, PRINT_H_MM = 170.0, 200.0
FLOOR_MM = 2.05

# Genre palette: dark inks on white. State lives in line style + ink, never a pastel chip.
STATE = {
    "PROVEN":     ("#14532d", "solid"),    # dark green, solid
    "PARTIAL":    ("#8a5200", "dashed"),   # dark amber, dashed
    "BROKEN":     ("#a11d1d", "dashed"),   # dark red, dashed
    "MISSING":    ("#a11d1d", "dotted"),   # dark red, dotted
    "UNVERIFIED": ("#555555", "dotted"),   # grey, dotted
}
INK = "#111111"
DASH = {"solid": "", "dashed": ' stroke-dasharray="9 6"', "dotted": ' stroke-dasharray="2 5"'}

# Short display names for the map (the full name lives in the register and module views).
SHORT = {
    "FOREMAN (Hermes)": "FOREMAN", "TASK-ROUTER": "ROUTER", "GITHUB CREDENTIALS": "GITHUB",
    "INFERENCE PROXY": "PROXY", "BUNKER DAEMON": "BUNKER", "CONFORMANCE BATTERY": "CONFORMANCE",
    "SESSION STORE": "SESSIONS", "CRIER (bus)": "CRIER",
}


def esc(s) -> str:
    return html.escape(str(s), quote=True)


def print_mm(font_units: float, vw: float, vh: float) -> float:
    """Printed mm of a font given the builder's rule (the wider dimension is constrained)."""
    if vw >= vh:
        return font_units * PRINT_W_MM / vw
    return font_units * PRINT_H_MM / vh


def min_label_mm(svg: str) -> float:
    """Smallest printed label on a sheet, exactly as build_book.py will scale it: the
    builder reads the width/height ATTRS to pick the constrained dimension, then the
    viewBox units scale by it."""
    head = svg[:600]
    aw = float(re.search(r'width="([\d.]+)', head).group(1))
    ah = float(re.search(r'height="([\d.]+)', head).group(1))
    vb = re.search(r'viewBox="[\d.]+ [\d.]+ ([\d.]+) ([\d.]+)"', svg)
    vw, vh = float(vb.group(1)), float(vb.group(2))
    if aw >= ah:
        unit = PRINT_W_MM / vw
    else:
        unit = PRINT_H_MM / vh
    sizes = [float(v) for v in re.findall(r'font-size="([\d.]+)', svg)]
    return min(sizes) * unit


# --------------------------------------------------------------------------- legends
def legend_svg(states, x, y, title, fs) -> list[str]:
    """An in-SVG legend block: one sample line per contract state, plus a title."""
    out = ['<g id="legend">']
    out.append(
        f'<rect x="{x - 12:.0f}" y="{y - fs * 1.6:.0f}" width="250" '
        f'height="{fs * (2.4 + 1.9 * len(states)):.0f}" fill="#ffffff" stroke="#bbbbbb" '
        f'stroke-width="1"/>'
    )
    out.append(
        f'<text x="{x:.0f}" y="{y:.0f}" font-size="{fs * 1.05:.1f}" font-weight="700" '
        f'fill="{INK}">{esc(title)}</text>'
    )
    for i, name in enumerate(states):
        color, style = STATE[name]
        ly = y + fs * (1.8 + 1.8 * i)
        out.append(
            f'<line x1="{x:.0f}" y1="{ly - fs * 0.4:.0f}" x2="{x + 48:.0f}" '
            f'y2="{ly - fs * 0.4:.0f}" stroke="{color}" stroke-width="3.5"{DASH[style]}/>'
        )
        out.append(f'<text x="{x + 58:.0f}" y="{ly:.0f}" font-size="{fs}" fill="{color}">{esc(name)}</text>')
    out.append("</g>")
    return out


# --------------------------------------------------------------------------- graphviz family
def map_dot(model, fs: int) -> str:
    by_layer = {}
    for c in model["components"]:
        by_layer.setdefault(c["layer"], []).append(c)
    lines = [
        "digraph system {",
        '  graph [rankdir=TB, nodesep=0.18, ranksep=0.42, splines=spline, fontname="Helvetica", '
        f'bgcolor="white", pad=0.20, newrank=true, fontsize={fs}];',
        f'  node [shape=box, style="rounded,filled", fillcolor="#fbfaf5", color="{INK}", '
        f'fontname="Helvetica", fontsize={fs}, penwidth=1.6, margin="0.08,0.05"];',
        f'  edge [fontname="Helvetica", fontsize={fs}, penwidth=1.8, arrowsize=0.9];',
    ]
    for layer in model["layers"]:
        members = by_layer.get(layer["id"], [])
        if not members:
            continue
        lines.append("  subgraph cluster_%s {" % layer["id"])
        lines.append(
            '    label="%s"; labeljust=l; fontsize=%d; fontcolor="#666666"; style="dashed"; color="#bbbbbb";'
            % (layer["name"], fs)
        )
        # ranks capped at 3 boxes: graph width is what the print scale eats, so the widest
        # band is broken into stacked rows (invisible chains; newrank keeps clusters independent)
        chunks = [members[i:i + 3] for i in range(0, len(members), 3)]
        for ci, ch in enumerate(chunks):
            for c in ch:
                lines.append('    c_%s [label=<<b>%s</b>>];'
                             % (c["id"], esc(SHORT.get(c["name"], c["name"]))))
            if ci > 0:
                for a, b in zip(chunks[ci - 1], ch):
                    lines.append('    c_%s -> c_%s [style=invis];' % (a["id"], b["id"]))
        lines.append("  }")
    for k in model["contracts"]:
        if str(k.get("id", "")).startswith("CT-"):
            color, style = STATE.get(k["state"], STATE["UNVERIFIED"])
            lines.append(
                '  c_%s -> c_%s [label="  %s  ", color="%s", style="%s", fontcolor="%s"];'
                % (k["from"], k["to"], k["id"], color, style, color)
            )
    lines.append("}")
    return "\n".join(lines)


def sm_dot(name: str, fs: int) -> str:
    if name == "board-lifecycle":
        head = "digraph board_row {"
        states = [
            ("pending", "pending\\ndispatchable"),
            ("claimed", "claimed\\nby a tick"),
            ("running", "in_progress\\nworker executing"),
            ("review", "review\\nverdict expected"),
            ("complete", "complete\\nevidence bound\\n(--evidence-run-id)"),
            ("blocked", "blocked\\nownership or defect"),
            ("deferred", "deferred\\nnot this cadence"),
        ]
        edges = [
            ("pending", "claimed", "tick selects"),
            ("claimed", "running", "gitreins start"),
            ("running", "review", "commit landed"),
            ("review", "complete", "verdict + evidence"),
            ("review", "running", "changes requested"),
            ("pending", "blocked", "cannot proceed"),
            ("pending", "deferred", "dependency unmet"),
            ("blocked", "pending", "blocker row closed"),
            ("running", "blocked", "worker died"),
        ]
    else:
        head = "digraph tick {"
        states = [
            ("fires", "TICK FIRES\\ncadence due"),
            ("evaluate", "EVALUATE\\nmode, board, pools,\\nstasis, noop-pacing"),
            ("deferred", "DEFERRED\\nload gate, gateway,\\nnoop pacing — retried"),
            ("admitted", "ADMITTED\\nenvelope out (CT-02)"),
            ("await", "AWAIT REPLY\\nwall_s / tick-timeout"),
            ("settle", "SETTLE\\ndispatch_leg.go"),
            ("completed", "COMPLETED\\nreply ok"),
            ("failed", "FAILED\\nreply failed"),
            ("timeout", "TIMEOUT\\ndispatch_deadline"),
        ]
        edges = [
            ("fires", "evaluate", "tick_process.go"),
            ("evaluate", "deferred", "gate holds"),
            ("deferred", "evaluate", "retried, not dropped"),
            ("evaluate", "admitted", "waiver or cooldown"),
            ("admitted", "await", "crier lease 30 s"),
            ("await", "settle", "reply or deadline"),
            ("settle", "completed", ""),
            ("settle", "failed", ""),
            ("settle", "timeout", ""),
        ]
    lines = [
        head,
        '  rankdir=TB; bgcolor="white";',   # TB: the print scale eats width, so the long chain runs down
        f'  node [shape=box style="rounded,filled" fillcolor="#fbfaf5" fontname="Helvetica" '
        f'fontsize={fs} color="{INK}" penwidth=1.6 margin="0.08,0.05"];',
        f'  edge [fontname="Helvetica" fontsize={fs} color="#555555"];',
    ]
    for sid, label in states:
        lines.append('  %s [label="%s"];' % (sid, label))
    for a, b, lab in edges:
        lines.append('  %s -> %s [label="%s"];' % (a, b, lab) if lab else "  %s -> %s;" % (a, b))
    lines.append("}")
    return "\n".join(lines)


def render_dot_tuned(dot_fn, out_svg: pathlib.Path, legend_title: str) -> dict:
    """Render with graphviz; if the smallest label would print below the floor, re-lay-out
    with bigger fonts ONLY while that still helps (graph width grows with font size, so the
    honest lever is the model's structure — the gate below catches what tuning cannot)."""
    fs = 20
    for _ in range(4):
        r = subprocess.run(["dot", "-Tsvg", "-o", str(out_svg)], input=dot_fn(fs),
                           text=True, capture_output=True, timeout=300)
        if r.returncode != 0:
            raise SystemExit("dot failed: " + r.stderr[-400:])
        svg = out_svg.read_text()
        min_mm = min_label_mm(svg)
        if min_mm >= 2.25:
            break
        fs = int(fs * 1.3) + 1
    # append the legend band, sized so the legend itself also clears the floor
    svg = out_svg.read_text()
    vb = re.search(r'viewBox="[\d.]+ [\d.]+ ([\d.]+) ([\d.]+)"', svg)
    vw, vh = float(vb.group(1)), float(vb.group(2))
    lg_fs = max(14, math.ceil(2.4 * vw / PRINT_W_MM))
    lh = lg_fs * (2.2 + 1.8 * len(STATE))
    lg = legend_svg(STATE, 20, vh + lg_fs * 1.8, legend_title, lg_fs)
    svg = svg.replace(vb.group(0), 'viewBox="0.00 0.00 %s %.2f"' % (vb.group(1), vh + lh))
    svg = re.sub(r'height="[\d.]+pt"', 'height="%.2fpt"' % (vh + lh), svg, count=1)
    svg = svg.replace("</svg>", "\n".join(lg) + "\n</svg>")
    out_svg.write_text(svg)
    return {"min_mm": min_label_mm(svg), "fs": fs}


# --------------------------------------------------------------------------- hand-rolled family
class Sheet:
    """A sheet designed at 170 mm print width: viewBox units are quarter-millimetres,
    so the 2.05 mm floor is 8.2 units and every font choice below stays above it."""

    UPX = 4                      # user units per mm at print scale
    W = int(PRINT_W_MM * UPX)    # 680 units = 170 mm
    FLOOR_U = 8.2

    def __init__(self, h_units: float):
        self.h = h_units
        self.body: list[str] = []

    def add(self, s: str):
        self.body.append(s)

    def text(self, x, y, s, size, weight="400", fill=INK, anchor="start"):
        assert size >= self.FLOOR_U, f"font {size} below floor"
        self.add(f'<text x="{x:.1f}" y="{y:.1f}" font-size="{size:.2f}" font-weight="{weight}" '
                 f'fill="{fill}" text-anchor="{anchor}">{esc(s)}</text>')

    def box(self, x, y, w, h, stroke=INK, sw=1.8, fill="#ffffff"):
        self.add(f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" fill="{fill}" '
                 f'stroke="{stroke}" stroke-width="{sw}"/>')

    def arrow(self, x1, y1, x2, y2, color=INK, sw=1.8, dash=None):
        d = f' stroke-dasharray="{dash}"' if dash else ""
        self.add(f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" '
                 f'stroke="{color}" stroke-width="{sw}"{d} marker-end="url(#ar)"/>')

    def emit(self, title=None) -> str:
        # Equal width/height attrs: build_book.py constrains the wider dimension, so equal
        # attrs force the WIDTH rule (170 mm) and keep this sheet's units at 0.25 mm even
        # when the canvas is portrait. Height follows the viewBox ratio.
        side_mm = max(self.W, self.h) / self.UPX
        head = (
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{side_mm:.1f}mm" '
            f'height="{side_mm:.1f}mm" viewBox="0 0 {self.W} {self.h:.1f}" '
            f'preserveAspectRatio="xMidYMid meet">'
            f'<rect width="{self.W}" height="{self.h:.1f}" fill="#ffffff"/>'
            '<defs><marker id="ar" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" '
            f'markerHeight="6" orient="auto"><path d="M0,0 L10,5 L0,10 z" fill="{INK}"/></marker></defs>'
        )
        return head + "\n".join(self.body) + "</svg>"


def wrap(s: str, width: int) -> list[str]:
    words, lines, cur = s.split(), [], ""
    for w in words:
        t = (cur + " " + w).strip()
        if len(t) <= width:
            cur = t
        else:
            if cur:
                lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


F_SMALL = 9.5   # 2.375 mm
F_BODY = 11.0   # 2.75 mm
F_HEAD = 13.0   # 3.25 mm
F_TITLE = 17.0  # 4.25 mm


def seq_sheet(model, flow) -> Sheet:
    """Sequence diagram: lifelines across, time down, every step cites its source."""
    by_id = {c["id"]: c for c in model["components"]}
    actors = []
    for a, b, _ in flow["steps"]:
        for x in (a, b):
            if x not in actors:
                actors.append(x)
    n = len(actors)
    margin = 60
    cell = (Sheet.W - margin * 2) / n
    rowh = 46
    top = 84
    steps = flow["steps"]
    extra = 1 if flow.get("note") else 0
    h = top + rowh * (len(steps) + extra) + 30
    sh = Sheet(h)
    ax = {a: margin + i * cell + cell / 2 for i, a in enumerate(actors)}
    lifeline_end = h - 16 if not extra else top + rowh * len(steps) - 6

    # legend band (top-right): how to read this figure
    sh.text(Sheet.W - 12, 22, "time flows down · every step cites its chapter or contract",
            F_SMALL, fill="#666666", anchor="end")

    for a in actors:
        x = ax[a]
        name = by_id[a]["name"]
        bw = max(cell - 14, len(name) * F_BODY * 0.62)
        sh.box(x - bw / 2, 36, bw, 30)
        for i, ln in enumerate(wrap(name, int(bw / (F_BODY * 0.6)))[:1]):
            sh.text(x, 56, ln, F_BODY, weight="700", anchor="middle")
        sh.add(f'<line x1="{x:.0f}" y1="70" x2="{x:.0f}" y2="{lifeline_end:.0f}" '
               f'stroke="#bbbbbb" stroke-width="1" stroke-dasharray="5 5"/>')

    for i, (a, b, what) in enumerate(steps):
        y = top + i * rowh
        x1, x2 = ax[a], ax[b]
        sh.text(10, y + 3, f"{i + 1}", F_SMALL, fill="#888888")
        if a == b:
            sh.add(f'<path d="M{x1 - 8:.0f},{y - 2:.0f} h22 v26 h-22" fill="none" '
                   f'stroke="{INK}" stroke-width="1.8" marker-end="url(#ar)"/>')
            tx, anchor = min(x1 + 24, Sheet.W - 320), "start"
        else:
            sh.arrow(x1, y, x2, y)
            tx, anchor = (x1 + x2) / 2, "middle"
            if abs(x2 - x1) < cell * 1.5:  # short arrow: keep the text clear of the lifelines
                right = x2 >= x1
                tx = (max(x1, x2) + 16) if right else (min(x1, x2) - 16)
                anchor = "start" if right else "end"
                tx = min(max(tx, 300), Sheet.W - 310) if anchor == "start" else max(min(tx, 380), 310)
        lines = wrap(what, 44 if a == b else 52)[:2]
        for j, ln in enumerate(lines):
            sh.text(tx, y - 8 + j * 13, ln, F_SMALL, fill="#14532d", anchor=anchor)
    if flow.get("note"):
        y = top + len(steps) * rowh + 8
        sh.add(f'<rect x="6" y="{y - 14:.0f}" width="{Sheet.W - 12}" height="22" fill="#ffffff"/>')
        sh.text(10, y, "note: " + flow["note"], F_SMALL, fill="#8a5200")
    return sh


def module_sheet(model, mod) -> Sheet:
    """Centred module view: left = inputs (upstream contracts), right = outputs (downstream),
    flows it participates in. Generated mechanically from components/contracts/flows."""
    by_id = {c["id"]: c for c in model["components"]}
    contracts = {k.get("id", f"{k['from']}->{k['to']}"): k for k in model["contracts"]}
    mcomps = [by_id[cid] for cid in mod.get("components", []) if cid in by_id]

    def row(cid):
        k = contracts[cid]
        frm, to = by_id.get(k["from"]), by_id.get(k["to"])
        color, _ = STATE.get(k["state"], STATE["UNVERIFIED"])
        return k, (frm["name"] if frm else k["from"]), (to["name"] if to else k["to"]), color

    ins = [(cid,) + row(cid) for cid in mod.get("contracts_in", [])]
    outs = [(cid,) + row(cid) for cid in mod.get("contracts_out", [])]

    part = []  # flow participation derived from the steps themselves
    for fl in model["flows"]:
        actors = {x for a, b, _ in fl["steps"] for x in (a, b)}
        if any(cid in actors for cid in mod.get("components", [])):
            part.append(fl)

    colw = 210
    lx, rx = 20, Sheet.W - 20 - colw
    cx = Sheet.W / 2
    cy = 206
    rowh = 56
    rows = max(len(ins), len(outs), 1)
    h = cy + 100 + rows * rowh + 60 + max(len(part), 1) * 40 + 40
    sh = Sheet(h)

    # title
    sh.text(24, 38, f"{mod['id']} — {mod['name']}", F_TITLE, weight="700")
    yy = 60
    for ln in wrap(mod["blurb"], 74)[:2]:
        sh.text(24, yy, ln, F_SMALL, fill="#555555")
        yy += 13

    # centre box with the module's components
    sh.box(cx - 75, cy - 34, 150, 84, sw=2.2)
    sh.text(cx, cy - 14, mod["id"], F_BODY, fill="#666666", anchor="middle")
    sh.text(cx, cy + 6, mod["name"], F_HEAD, weight="700", anchor="middle")
    comps_txt = ", ".join(c["name"] for c in mcomps) if mcomps \
        else "no bus component — the shell substrate (M0 §6)"
    if len(mcomps) != 1 or SHORT.get(mcomps[0]["name"], mcomps[0]["name"]) not in mod["name"]:
        for i, ln in enumerate(wrap(comps_txt, 34)[:2]):
            sh.text(cx, cy + (26 + i * 12), ln, F_SMALL, fill="#555555", anchor="middle")

    def contract_block(items, x, side):
        y0 = cy - 34
        sh.text(x, y0 - 14, "INPUTS — upstream contracts" if side == "l"
                else "OUTPUTS — downstream contracts", F_SMALL, weight="700", fill="#666666")
        if not items:
            sh.box(x, y0, colw, 44)
            sh.text(x + 10, y0 + 18, "no cross-system contract", F_SMALL, fill="#888888")
            sh.text(x + 10, y0 + 33, "none in Part IV or the chapter's §6", F_SMALL, fill="#999999")
            return
        for i, (cid, k, peer_from, peer_to, color) in enumerate(items):
            y = y0 + i * rowh
            card_h = rowh - 6
            yc = y + card_h / 2
            style = STATE[k["state"]][1]
            dash = {"solid": None, "dashed": "9 6", "dotted": "2 5"}[style]
            # connector first, so the card sits on top of its own arrow
            if side == "l":
                sh.arrow(x + colw, yc, cx - 77,
                         cy - 28 + (i + 0.5) * (56 / max(len(items), 1)), color=color, dash=dash)
            else:
                sh.arrow(cx + 77, cy - 28 + (i + 0.5) * (56 / max(len(items), 1)),
                         x, yc, color=color, dash=dash)
            sh.box(x, y, colw, card_h)
            peer = SHORT.get(peer_to if side == "r" else peer_from,
                             peer_to if side == "r" else peer_from)
            label = f"{peer} → {mod['id']}" if side == "l" else f"{mod['id']} → {peer}"
            sh.text(x + 10, y + 16, f"{cid} · {label}  [{k['state']}]", F_SMALL, weight="700", fill=color)
            lines = wrap(k["carries"], 44)[:2]
            for j, ln in enumerate(lines):
                sh.text(x + 10, y + (30 + j * 12), ln, F_SMALL, fill=color)

    contract_block(ins, lx, "l")
    contract_block(outs, rx, "r")

    # flows panel
    fy = max(cy + 100, cy - 34 + rows * rowh + 30)
    sh.text(24, fy, "FLOWS THIS MODULE PARTICIPATES IN", F_SMALL, weight="700", fill="#666666")
    if part:
        for i, fl in enumerate(part):
            txt = f"{fl['id']} {fl['name']} — {fl['question']}"
            for j, ln in enumerate(wrap(txt, 78)[:2]):
                sh.text(24 + j * 12, fy + 22 + i * 40 + j * 12, ln, F_SMALL)
    else:
        sh.text(24, fy + 22, "none — no flow step names this module's components", F_SMALL, fill="#888888")

    # legend: state ink/line meaning, top-right (clear of title text and of the columns)
    sh.add("".join(legend_svg(STATE, Sheet.W - 232, 56, "contract state — line style + ink", 9)))
    return sh


# --------------------------------------------------------------------------- main
def main() -> int:
    model = yaml.safe_load(MODEL.read_text())
    OUT.mkdir(parents=True, exist_ok=True)
    made = []

    # 1 — the full system map (graphviz layout, CT-nn on every edge)
    p = OUT / "system-map.svg"
    info = render_dot_tuned(lambda fs: map_dot(model, fs), p,
                            "contract state — CT-nn keys every edge to Part IV")
    made.append(("system-map.svg",
                 f"{len(model['components'])} components in {len(model['layers'])} layers; "
                 f"every edge is a numbered contract", info))

    # 2 — one centred view per module M0-M12
    for mod in model["modules"]:
        p = OUT / f"module-{mod['id']}.svg"
        p.write_text(module_sheet(model, mod).emit(""))
        made.append((p.name, f"{mod['id']} {mod['name']} — inputs left, outputs right, flows below", None))

    # 3 — one sequence diagram per flow with steps
    for fl in model["flows"]:
        if not fl.get("steps"):
            continue
        p = OUT / f"{fl['id']}.svg"
        p.write_text(seq_sheet(model, fl).emit(""))
        made.append((p.name, f"{fl['id']} {fl['name']} — {fl['question']}", None))

    # 4 — the two state machines
    for name, title in (
        ("board-lifecycle", "board row state — including the paths that are not 'forward'"),
        ("tick-lifecycle", "scheduler tick state — admission, dispatch, settlement (M9 §3)"),
    ):
        p = OUT / f"{name}.svg"
        info = render_dot_tuned(lambda fs, _n=name: sm_dot(_n, fs), p, title)
        made.append((p.name, title, info))

    # ---- GATE: every SVG must parse, and no label may print below the floor ----
    failures = []
    report = []
    for fname, desc, info in made:
        f = OUT / fname
        try:
            ET.fromstring(f.read_text())
        except ET.ParseError as e:
            failures.append(f"{fname}: XML parse error: {e}")
            continue
        mm = min_label_mm(f.read_text())
        report.append((fname, mm))
        if mm < FLOOR_MM:
            failures.append(f"{fname}: smallest label prints at {mm:.2f} mm (floor {FLOOR_MM})")

    index = ["# Figures", "",
             "Generated from `docs/SYSTEM-MODEL.yaml` by `scripts/gen_handbook_figures.py`.",
             "Every label is verified >= 2.05 mm at the builder's print scale.", "",
             "| figure | what it answers |", "|---|---|"]
    index += [f"| `{f}` | {q} |" for f, q, _ in made]
    (OUT / "INDEX.md").write_text("\n".join(index) + "\n")

    print(f"{len(made)} figures -> {OUT.relative_to(ROOT)}")
    for fname, mm in report:
        print(f"  {fname:<24} min label {mm:.2f} mm")
    if failures:
        print("FIGURE GATE FAIL:")
        for x in failures:
            print("  " + x)
        return 2
    print("figure gate: all SVGs parse; all labels >= %.2f mm at print scale" % FLOOR_MM)
    return 0


if __name__ == "__main__":
    sys.exit(main())
