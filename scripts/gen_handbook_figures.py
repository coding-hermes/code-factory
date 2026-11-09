#!/usr/bin/env python3
"""gen_handbook_figures.py — the visual layer, drawn in the nasa-handbook genre.

Every figure is regenerated from docs/SYSTEM-MODEL.yaml so no figure can drift
from the model, but the LOOK is the skill's line-drafting genre, not a graph
renderer's output (references/svg-parts.md conventions):

  - pure black on pure white — state is carried by LINE STYLE
    (solid = PROVEN, long-dash = PARTIAL, fine-dash = BROKEN, dotted =
    MISSING/UNVERIFIED), never by colour or a tint; printers halftone tints.
  - all drawing text is Routed Gothic (Leroy lettering), small caps, 2.05 mm
    floor at print scale; wire labels sit 0.8 mm above their wire.
  - hairlines (0.16–0.5 mm), 2 mm arrowheads, right-angle wires only —
    no graphviz splines, no Bezier anything.
  - dashed panels are boundaries (layers, trust domains); solid thin boxes are
    components; drums would be storage.

Figures emitted (same registry as before):

  system-map.svg        layered dashed panels, one box per component, every
                        contract a right-angle wire labelled CT-nn (rotated on
                        its vertical run) — hand-routed, no graphviz
  module-M0..M12.svg    centred view: inputs left, outputs right, flows below
  F1..F16.svg           sequence diagrams: lifelines across, time down
  board-lifecycle.svg,
  tick-lifecycle.svg    state machines, boxes on a grid, orthogonal edges

GATES (all mechanical, all run here): XML parses; smallest label >= 2.05 mm at
the builder's print scale; no colour anywhere except pure black/white.

    python3 scripts/gen_handbook_figures.py
"""

from __future__ import annotations

import html
import pathlib
import re
import sys
import xml.etree.ElementTree as ET

import yaml

ROOT = pathlib.Path(__file__).resolve().parent.parent
MODEL = ROOT / "docs/SYSTEM-MODEL.yaml"
OUT = ROOT / "docs/handbook/figures"

PRINT_W_MM, PRINT_H_MM = (
    170.0,
    250.0,
)  # builder's constraints: 179 mm column, 250 mm figure band
FLOOR_MM = 2.05

INK = "#000000"
PAPER = "#ffffff"
FF = "Routed Gothic Narrow, Routed Gothic, sans-serif"

# contract state -> line style on the wire (genre: black ink only)
STATE_DASH = {
    "PROVEN": None,  # solid
    "PARTIAL": "12 7",  # long dash
    "BROKEN": "4 3",  # fine dash
    "MISSING": "1.5 3.5",  # dotted
    "UNVERIFIED": "1.5 3.5",  # dotted — no evidence either way
}
STATE_LEGEND = [
    ("PROVEN", "solid — exercised with evidence"),
    ("PARTIAL", "long dash — holds in part"),
    ("BROKEN", "fine dash — known not to hold"),
    ("MISSING", "dotted — not built"),
    ("UNVERIFIED", "dotted — no evidence either way"),
]

SHORT = {
    "FOREMAN (Hermes)": "FOREMAN",
    "GITHUB CREDENTIALS": "GITHUB",
    "INFERENCE PROXY": "PROXY",
    "BUNKER DAEMON": "BUNKER",
    "CONFORMANCE BATTERY": "CONFORMANCE",
    "SESSION STORE": "SESSIONS",
    "CRIER (bus)": "CRIER",
}


def esc(s) -> str:
    return html.escape(str(s), quote=True)


def min_label_mm(svg: str) -> float:
    """Smallest printed label on a sheet, with EXACTLY the builder's fit rule
    (build_book.py svg_fit): scale = min(1, 170/w_mm, 250/h_mm) applied to the
    figure's natural millimetre size, then viewBox units scale by it."""
    head = svg[:600]
    aw = float(re.search(r'width="([\d.]+)', head).group(1))
    ah = float(re.search(r'height="([\d.]+)', head).group(1))
    vb = re.search(r'viewBox="[\d.]+ [\d.]+ ([\d.]+) ([\d.]+)"', svg)
    vw = float(vb.group(1))
    scale = min(1.0, PRINT_W_MM / aw, PRINT_H_MM / ah)
    return (
        min(sizes_) * scale * aw / vw
        if (sizes_ := [float(v) for v in re.findall(r'font-size="([\d.]+)', svg)])
        else 99.0
    )


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


F_SMALL = 9.5  # 2.35 mm at print scale
F_TINY = 8.4  # 2.10 mm — secondary lines, wire names
F_BODY = 11.0  # 2.75 mm
F_HEAD = 13.0  # 3.25 mm
F_TITLE = 17.0  # 4.25 mm


class Sheet:
    """A sheet designed at 170 mm print width: viewBox units are quarter-millimetres,
    so the 2.05 mm floor is 8.2 units and every font choice below stays above it.
    Line weights in genre units: hairline 0.7 (0.175 mm), object 1.8 (0.45 mm)."""

    UPX = 4  # user units per mm at print scale
    W = int(PRINT_W_MM * UPX)  # 680 units = 170 mm
    FLOOR_U = 8.2

    def __init__(self, h_units: float):
        self.h = h_units
        self.body: list[str] = []

    def add(self, s: str):
        self.body.append(s)

    # ---- text ----------------------------------------------------------------
    def text(self, x, y, s, size, fill=INK, anchor="start", rotate=None):
        assert size >= self.FLOOR_U, f"font {size} below floor"
        if rotate is not None:
            # transform ONLY: x/y attrs would translate a second time inside the
            # rotated frame and throw the label off the canvas
            self.add(
                f'<text transform="translate({x:.1f} {y:.1f}) rotate({rotate})" '
                f'font-size="{size:.2f}" fill="{fill}" text-anchor="{anchor}">{esc(s)}</text>'
            )
        else:
            self.add(
                f'<text x="{x:.1f}" y="{y:.1f}" font-size="{size:.2f}" fill="{fill}" '
                f'text-anchor="{anchor}">{esc(s)}</text>'
            )

    # ---- structure -----------------------------------------------------------
    def box(self, x, y, w, h, sw=1.8):
        self.add(
            f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" '
            f'fill="{PAPER}" stroke="{INK}" stroke-width="{sw}"/>'
        )

    def panel(self, x, y, w, h):
        self.add(
            f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" fill="none" '
            f'stroke="{INK}" stroke-width="1.2" stroke-dasharray="6 4"/>'
        )

    def poly(self, pts, sw=1.2, dash=None, arrow=False):
        d = f' stroke-dasharray="{dash}"' if dash else ""
        m = ' marker-end="url(#ar)"' if arrow else ""
        p = " ".join(f"{x:.1f},{y:.1f}" for x, y in pts)
        self.add(
            f'<polyline points="{p}" fill="none" stroke="{INK}" '
            f'stroke-width="{sw}"{d}{m}/>'
        )

    def line(self, x1, y1, x2, y2, sw=1.2, dash=None, arrow=False):
        self.poly([(x1, y1), (x2, y2)], sw=sw, dash=dash, arrow=arrow)

    def hair(self, x1, y1, x2, y2, dash=None):
        self.line(x1, y1, x2, y2, sw=0.7, dash=dash)

    def dot(self, x, y):
        self.add(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="1.6" fill="{INK}"/>')

    def emit(self, title=None) -> str:
        # TRUE aspect attrs; the builder scales with min(1, 170/w, 250/h) and both
        # sides' gates model that rule, so the print-scale floor is honest.
        head = (
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.W / self.UPX:.1f}mm" '
            f'height="{self.h / self.UPX:.1f}mm" viewBox="0 0 {self.W} {self.h:.1f}" '
            f'preserveAspectRatio="xMidYMid meet">'
            f'<rect width="{self.W}" height="{self.h:.1f}" fill="{PAPER}"/>'
            '<defs><marker id="ar" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" '
            'markerHeight="8" orient="auto"><path d="M0,0 L10,5 L0,10 z" '
            f'fill="{INK}"/></marker></defs>'
            f'<g font-family="{FF}">'
        )
        return head + "\n".join(self.body) + "</g></svg>"


def legend_block(sh: Sheet, x: float, y: float, entries, title: str, fs=F_TINY):
    """Line-style legend: one sample line + one name per row, black ink."""
    sh.text(x, y, title, fs)
    for i, (state, name) in enumerate(entries):
        ly = y + fs * 1.9 * (i + 1)
        sh.line(
            x, ly - fs * 0.35, x + 34, ly - fs * 0.35, sw=1.4, dash=STATE_DASH[state]
        )
        sh.text(x + 42, ly, name, fs)


# --------------------------------------------------------------------------- system map
class Corridors:
    """Vertical channels between the component columns; each slot keeps an exclusive
    x and an exclusive y-interval, so two contracts never share a stretch of line."""

    def __init__(self, slots: list[float]):
        self.slots = {x: [] for x in slots}  # x -> list of (lo, hi) taken intervals

    def claim(self, lo: float, hi: float) -> float:
        lo, hi = min(lo, hi), max(lo, hi)
        for x in sorted(self.slots, key=lambda v: abs(v - (lo + hi) / 2)):
            ivs = self.slots[x]
            if all(hi < a - 8 or lo > b + 8 for a, b in ivs):
                ivs.append((lo, hi))
                return x
        raise RuntimeError(f"no free corridor for span {lo}..{hi}")


def system_map_sheet(model) -> Sheet:
    """The map is taller than the 250 mm figure band, so it prints scaled down —
    its type sizes start above the shared sizes so the PRINTED label still clears
    the 2.05 mm floor (the gate verifies this against the real scale)."""
    TINY, SMALL, TITLE = 17.5, 18.5, 24.0
    by_layer = {layer["id"]: [] for layer in model["layers"]}
    for c in model["components"]:
        by_layer[c["layer"]].append(c)
    by_id = {c["id"]: c for c in model["components"]}

    PX, BW, BH, COLGAP, ROWGAP = 16, 150, 40, 16, 12
    NAME_H = 18
    cols = 4
    col_x = [PX + i * (BW + COLGAP) for i in range(cols)]
    corridors = Corridors(
        [8.0] + [col_x[i] + BW + COLGAP / 2 for i in range(cols - 1)] + [672.0]
    )

    GH = 180  # gutter between panels (holds routing lanes)
    LANE0, LANE_STEP, N_LANES = 12, 18, 10
    panels = []
    y = 64  # title band above the first panel
    for layer in model["layers"]:
        members = by_layer[layer["id"]]
        rows = max(1, -(-len(members) // cols))
        ph = NAME_H + rows * (BH + ROWGAP) + 8
        panels.append((layer, members, y, ph, rows))
        y += ph + GH
    # legend band + host-boundary notes are sized from their ACTUAL line counts,
    # not guessed — the old fixed 96-unit tail let the legend render past the
    # viewBox edge
    TINY_ = TINY
    legend_h = TINY_ + len(STATE_LEGEND) * TINY_ * 1.9
    notes = [
        "A BUNKER TAG MARKS A COMPONENT THAT EXECUTES INSIDE THE BUNKER DEPLOYMENT / "
        "EXECUTION BOUNDARY; UNTAGGED COMPONENTS RUN ON THE CONTROL HOST.",
        "THE PROJECT FOREMAN RUNS IN ITS BUNKER; ITS RESPONSE RETURNS THROUGH CRIER "
        "TO THE SCHEDULER, WHICH RECORDS IT AND TRIGGERS SUBSEQUENT PROCESSING "
        "(CT-06R → CT-06).",
        "DUCKBRAIN IS INSTALLED IN EVERY BUNKER AND EXPOSES THE SAME LOGICAL PROJECT "
        "MEMORY DATA/VIEW AS THE CONTROLLER — PHYSICAL TOPOLOGY REMAINS UNRESOLVED.",
    ]
    note_lines = [ln for n in notes for ln in wrap(n, 62)]
    notes_h = len(note_lines) * (TINY_ + 3) + 22
    H = y - GH + legend_h + notes_h + 24

    sh = Sheet(H)
    sh.text(16, 30, "CODE FACTORY — SYSTEM MAP", TITLE)
    sh.text(
        664,
        52,
        "WIRES KEYED TO THE CONTRACT REGISTER (PART IV)",
        TINY,
        anchor="end",
    )

    pos = {}  # comp id -> (x, y, w, h, layer index)
    for li, (layer, members, py, ph, rows) in enumerate(panels):
        sh.panel(PX, py, 648, ph)
        sh.text(PX + 6, py + NAME_H - 6, layer["name"], SMALL)
        for i, c in enumerate(members):
            r, k = divmod(i, cols)
            bx, by = col_x[k], py + NAME_H + r * (BH + ROWGAP)
            pos[c["id"]] = (bx, by, BW, BH, li)
            sh.box(bx, by, BW, BH)
            name = SHORT.get(c["name"], c["name"])
            lines = wrap(name, 22)[:2]
            tagged = bool(c.get("host") == "bunker" or c.get("tag"))
            y0 = by + BH / 2 - (len(lines) - 1) * SMALL / 2 + SMALL * 0.35
            if tagged:
                y0 -= 5  # clear the tag strip at the bottom of the box
            for j, ln in enumerate(lines):
                sh.text(bx + BW / 2, y0 + j * SMALL, ln, SMALL, anchor="middle")
            if c.get("tag"):
                sh.text(bx + BW / 2, by + BH - 5, c["tag"], TINY, anchor="middle")
            if c.get("host") == "bunker" and name != "BUNKER":
                # role/host boundary: a tagged box executes INSIDE the Bunker
                # deployment/execution boundary; untagged boxes sit on the control host
                sh.text(bx + BW - 5, by + BH - 5, "BUNKER", TINY, anchor="end")

    gutter_top = {i: panels[i][2] + panels[i][3] for i in range(len(panels) - 1)}
    lanes: dict[int, list[float]] = {i: [] for i in range(len(panels) - 1)}

    def lane(g: int) -> float:
        free = gutter_top[g] + LANE0 + LANE_STEP * len(lanes[g])
        if len(lanes[g]) >= N_LANES:
            raise RuntimeError(f"gutter {g} out of lanes")
        lanes[g].append(free)
        return free

    for k in sorted(model["contracts"], key=lambda k: k.get("id", "")):
        cid = str(k.get("id", ""))
        sig = k.get("signal")
        a, b = by_id.get(k["from"]), by_id.get(k["to"])
        if not a or not b or a["id"] not in pos or b["id"] not in pos:
            continue
        ax, ay, aw, ah, la = pos[a["id"]]
        bx, by, bw, bh, lb = pos[b["id"]]
        dash = STATE_DASH.get(k["state"], STATE_DASH["UNVERIFIED"])
        if la == lb:
            g = min(la, len(panels) - 2)
            ly = lane(g)
            x1, x2 = sorted((ax + 30, bx + bw - 30))
            sh.poly(
                [(x1, ay + ah), (x1, ly), (x2, ly), (x2, by + bh)],
                dash=dash,
                arrow=True,
            )
            sh.text((x1 + x2) / 2, ly - 5, cid, TINY, anchor="middle")
            if sig:
                sh.text((x1 + x2) / 2, ly + 14, sig, TINY, anchor="middle")
        elif la < lb:
            x1 = ax + aw / 2
            x2 = bx + bw / 2
            lx = (x1 + x2) / 2 + k.get("label_dx", 0)
            if lb - la == 1:
                ly = lane(la)
                sh.poly(
                    [(x1, ay + ah), (x1, ly), (x2, ly), (x2, by)], dash=dash, arrow=True
                )
                sh.text(lx, ly - 5, cid, TINY, anchor="middle")
                if sig:
                    sh.text(lx, ly + 14, sig, TINY, anchor="middle")
            else:
                g1, g2 = lane(la), lane(lb - 1)
                xc = corridors.claim(ay + ah, by)
                sh.poly(
                    [(x1, ay + ah), (x1, g1), (xc, g1), (xc, g2), (x2, g2), (x2, by)],
                    dash=dash,
                    arrow=True,
                )
                sh.text((x1 + xc) / 2, g1 - 5, cid, TINY, anchor="middle")
                if sig:
                    sh.text((x1 + xc) / 2, g1 + 14, sig, TINY, anchor="middle")
        else:
            x1 = ax + aw / 2
            x2 = bx + bw / 2
            if la - lb == 1:
                ly = lane(lb)
                sh.poly(
                    [(x1, ay), (x1, ly), (x2, ly), (x2, by + bh)], dash=dash, arrow=True
                )
                sh.text((x1 + x2) / 2, ly - 5, cid, TINY, anchor="middle")
                if sig:
                    sh.text((x1 + x2) / 2, ly + 14, sig, TINY, anchor="middle")
            else:
                g1, g2 = lane(la - 1), lane(lb)
                xc = corridors.claim(ay, by + bh)
                sh.poly(
                    [(x1, ay), (x1, g1), (xc, g1), (xc, g2), (x2, g2), (x2, by + bh)],
                    dash=dash,
                    arrow=True,
                )
                sh.text((x1 + xc) / 2, g1 - 5, cid, TINY, anchor="middle")
                if sig:
                    sh.text((x1 + xc) / 2, g1 + 14, sig, TINY, anchor="middle")

    yl = H - notes_h - legend_h - 4
    legend_block(
        sh, 16, yl, STATE_LEGEND, "CONTRACT STATE — LINE STYLE, INK ONLY", fs=TINY
    )
    sh.hair(16, yl + legend_h + 8, 664, yl + legend_h + 8)
    notes = [
        "A BUNKER TAG MARKS A COMPONENT THAT EXECUTES INSIDE THE BUNKER DEPLOYMENT / "
        "EXECUTION BOUNDARY; UNTAGGED COMPONENTS RUN ON THE CONTROL HOST.",
        "THE PROJECT FOREMAN RUNS IN ITS BUNKER; ITS RESPONSE RETURNS THROUGH CRIER "
        "TO THE SCHEDULER, WHICH RECORDS IT AND TRIGGERS SUBSEQUENT PROCESSING "
        "(CT-06R → CT-06).",
        "DUCKBRAIN IS INSTALLED IN EVERY BUNKER AND EXPOSES THE SAME LOGICAL PROJECT "
        "MEMORY DATA/VIEW AS THE CONTROLLER — PHYSICAL TOPOLOGY REMAINS UNRESOLVED.",
    ]
    ny = yl + legend_h + 26
    for ln in note_lines:
        sh.text(16, ny, ln, TINY)
        ny += TINY + 3
    return sh


# --------------------------------------------------------------------------- state machines
def sm_sheet(states, edges, title, note) -> Sheet:
    """states: (id, label lines, col, row); edges: (a, b, label, kind) with kind in
    V (straight down), G (gutter route), S (side-channel return)."""
    BW, BH = 130, 44
    col_x = [120, 340, 560]
    row_y = [70, 170, 270, 370, 470, 570, 670]
    pos = {}
    for sid, label, c, r in states:
        pos[sid] = (col_x[c] - BW / 2, row_y[r] - BH / 2, c, r)
    H = row_y[max(r for _, _, _, r in states)] + BH / 2 + 96
    sh = Sheet(H)
    sh.text(16, 26, title, F_TITLE)

    def draw_box(sid, label):
        x, y, _, _ = pos[sid]
        sh.box(x, y, BW, BH)
        lines = label if isinstance(label, list) else [label]
        y0 = y + BH / 2 - (len(lines) - 1) * F_SMALL / 2 + F_SMALL * 0.35
        for j, ln in enumerate(lines):
            sh.text(x + BW / 2, y0 + j * F_SMALL, ln, F_SMALL, anchor="middle")

    for sid, label, _, _ in states:
        draw_box(sid, label)

    def bottom(sid):
        x, y, _, _ = pos[sid]
        return x + BW / 2, y + BH

    def top(sid):
        x, y, _, _ = pos[sid]
        return x + BW / 2, y

    def right(sid, dy=0):
        x, y, _, _ = pos[sid]
        return x + BW, y + BH / 2 + dy

    def left(sid, dy=0):
        x, y, _, _ = pos[sid]
        return x, y + BH / 2 + dy

    lanes: dict[tuple, list[float]] = {}

    def lane_y(r: int) -> float:
        # gutter between row r and r+1
        key = ("g", r)
        used = lanes.setdefault(key, [])
        y = row_y[r] + BH / 2 + 12 + 13 * len(used)
        used.append(y)
        return y

    for a, b, label, kind in edges:
        if kind == "V":
            x1, y1 = bottom(a)
            x2, y2 = top(b)
            sh.line(x1, y1, x2, y2 + 2, arrow=True)
            if label:
                sh.text(x1 + 6, (y1 + y2) / 2 + 2, label, F_TINY)
        elif kind == "G":
            # downward through one gutter lane: exit a bottom, jog, enter b top
            x1, y1 = bottom(a)
            x2, y2 = top(b)
            ca, cb = pos[a][2], pos[b][2]
            r = pos[a][3]
            ly = lane_y(r)
            if ca == cb:
                x1 += 26
                x2 -= 26 if x2 > x1 else -26
            sh.poly([(x1, y1), (x1, ly), (x2, ly), (x2, y2)], arrow=True)
            if label:
                sh.text((x1 + x2) / 2, ly - 4, label, F_TINY, anchor="middle")
        elif kind == "U":
            # return upward: exit a top, lane in the gutter above b, enter b top? no —
            # exit a top, jog in gutter between, enter b bottom
            x1, y1 = top(a)
            x2, y2 = bottom(b)
            r = pos[b][3]
            ly = lane_y(r)
            sh.poly([(x1, y1), (x1, ly), (x2, ly), (x2, y2)], arrow=True)
            if label:
                sh.text((x1 + x2) / 2, ly - 4, label, F_TINY, anchor="middle")
        elif kind == "S":
            # side route with an EXPLICIT channel x, entering b's right edge at an
            # explicit dy — hand-checked against the other edges of the machine
            pts, lab, lx, lyy, rot = label
            sh.poly(pts, arrow=True)
            if lx is not None:
                sh.text(lx, lyy, lab, F_TINY, anchor="middle", rotate=rot)
        elif kind == "H":
            # same row: take the facing sides from relative column position
            if pos[b][2] > pos[a][2]:
                x1, y1 = right(a)
                x2, y2 = left(b)
                sh.line(x1, y1, x2 - 2, y2, arrow=True)
            else:
                x1, y1 = left(a)
                x2, y2 = right(b)
                sh.line(x1, y1, x2 + 2, y2, arrow=True)
            if label:
                sh.text((x1 + x2) / 2, y1 - 6, label, F_TINY, anchor="middle")

    if note:
        ny = H - 24
        sh.hair(16, ny - 12, 664, ny - 12)
        sh.text(16, ny, "NOTE. " + note, F_TINY)
    return sh


def board_lifecycle() -> Sheet:
    states = [
        ("pending", ["PENDING", "DISPATCHABLE"], 1, 0),
        ("claimed", ["CLAIMED", "BY A TICK"], 1, 1),
        ("running", ["IN PROGRESS", "FOREMAN/WORKER RUN"], 1, 2),
        ("guard", ["COMMIT GUARD", "GITREINS TIER 1"], 1, 3),
        ("review", ["ACCEPTANCE JUDGMENT", "TIER 2 VERDICT"], 1, 4),
        ("integrate", ["INTEGRATION /", "PUBLICATION"], 1, 5),
        ("complete", ["COMPLETE", "EVIDENCE-BOUND"], 1, 6),
        ("deferred", ["DEFERRED", "NOT THIS CADENCE"], 0, 0),
        ("blocked", ["BLOCKED", "OWNERSHIP OR DEFECT"], 2, 2),
    ]
    edges = [
        ("pending", "claimed", "TICK SELECTS", "V"),
        # foreman/worker start — GitReins belongs to the pre-commit review plumbing,
        # not to the start transition (user correction on the w10 issue)
        ("claimed", "running", "FOREMAN / WORKER START", "V"),
        ("running", "guard", "COMMIT STAGED", "V"),
        ("guard", "review", "GUARD PASSED", "V"),
        ("review", "integrate", "VERDICT ACCEPTED", "V"),
        ("integrate", "complete", "PUBLISHED + EVIDENCE BOUND", "V"),
        # rework: acceptance verdict returns to the worker (preserved channel)
        (
            "review",
            "running",
            (
                [(405, 470), (440, 470), (440, 280), (405, 280)],
                "CHANGES REQUESTED -> WORKER REWORK",
                448,
                375,
                -90,
            ),
            "S",
        ),
        # guard failure also returns to the worker, on its own left-side channel
        (
            "guard",
            "running",
            (
                [(275, 370), (230, 370), (230, 280), (275, 280)],
                "GUARD FAIL -> REWORK",
                224,
                325,
                -90,
            ),
            "S",
        ),
        ("pending", "deferred", "DEPENDENCY UNMET", "H"),
        ("pending", "blocked", "CANNOT PROCEED", "G"),
        # deferred return trigger: the condition that makes a deferred row
        # dispatchable again is named on the figure (user redline)
        (
            "deferred",
            "pending",
            (
                [(120, 92), (120, 114), (300, 114), (300, 92)],
                "RETURN: DEPENDENCY MET / CADENCE",
                208,
                110,
                None,
            ),
            "S",
        ),
        # blocked/unblock path (preserved)
        (
            "blocked",
            "pending",
            (
                [(560, 248), (560, 126), (450, 126), (450, 92)],
                "BLOCKER ROW CLOSED",
                505,
                122,
                None,
            ),
            "S",
        ),
        ("running", "blocked", "WORKER DIED", "H"),
    ]
    return sm_sheet(
        states,
        edges,
        "BOARD ROW LIFECYCLE — INCLUDING THE PATHS THAT ARE NOT FORWARD",
        "COMPLETION CONSUMES AN ACCEPTED VERDICT, PUBLICATION PROOF AND RETAINED "
        "EVIDENCE — NEVER THE GITREINS INTERNAL STATUS ALONE.",
    )


def tick_lifecycle() -> Sheet:
    states = [
        ("fires", ["TICK FIRES", "CADENCE DUE"], 1, 0),
        ("evaluate", ["EVALUATE", "MODE, BOARD, POOLS,"], 1, 1),
        ("admitted", ["ADMITTED", "ENVELOPE OUT (CT-02)"], 1, 2),
        ("await", ["AWAIT REPLY", "WALL_S / TICK-TIMEOUT"], 1, 3),
        ("settle", ["SETTLE", "DISPATCH_LEG.GO"], 1, 4),
        ("completed", ["COMPLETED", "REPLY OK"], 0, 5),
        ("failed", ["FAILED", "REPLY FAILED"], 1, 5),
        ("timeout", ["TIMEOUT", "DISPATCH_DEADLINE"], 2, 5),
        ("deferred", ["DEFERRED", "LOAD GATE, GATEWAY,"], 0, 2),
    ]
    edges = [
        ("fires", "evaluate", "TICK_PROCESS.GO", "V"),
        ("evaluate", "admitted", "WAIVER OR COOLDOWN", "V"),
        # gate holds: evaluate left edge (low) -> corridor x=230 -> deferred right edge
        (
            "evaluate",
            "deferred",
            (
                [(275, 182), (230, 182), (230, 270), (185, 270)],
                "GATE HOLDS",
                224,
                226,
                -90,
            ),
            "S",
        ),
        # retried: deferred top -> left margin riser -> evaluate left edge (high)
        (
            "deferred",
            "evaluate",
            (
                [(120, 248), (120, 158), (275, 158)],
                "RETRIED, NOT DROPPED",
                197,
                154,
                None,
            ),
            "S",
        ),
        ("admitted", "await", "CRIER LEASE 30 S", "V"),
        ("await", "settle", "REPLY OR DEADLINE", "V"),
        ("settle", "completed", None, "G"),
        ("settle", "failed", None, "G"),
        ("settle", "timeout", None, "G"),
    ]
    return sm_sheet(
        states,
        edges,
        "SCHEDULER TICK LIFECYCLE — ADMISSION, DISPATCH, SETTLEMENT (M9 §3)",
        "A DEFERRED TICK IS RETRIED AT THE NEXT CADENCE, NEVER DROPPED.",
    )


# --------------------------------------------------------------------------- module views
def _host_tag(cid: str, comp) -> str:
    if comp is None:
        return "EXTERNAL PEER"
    if comp.get("host") == "bunker":
        return "IN THE BUNKER"
    if cid == "crier":
        return "LAUNCH/RETURN BOUNDARY"
    if cid == "scheduler":
        return "CONTROL PLANE"
    if comp.get("tag"):
        return f"CONTROL HOST · {comp['tag']}"
    return "CONTROL HOST"


def _enclosure(sh: Sheet, x, y, w, h, label):
    """Dashed host/bus boundary wrapper around one box, label inside top-left.
    A finer dash than the module panel's 6 4, so the two boundary levels read apart."""
    sh.add(
        f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" fill="none" '
        f'stroke="{INK}" stroke-width="1.0" stroke-dasharray="2.5 2.5"/>'
    )
    sh.text(x + 3, y + 9.5, label, F_TINY)


def module_sheet(model, mod) -> Sheet:
    by_id = {c["id"]: c for c in model["components"]}
    contracts = {k.get("id", f"{k['from']}->{k['to']}"): k for k in model["contracts"]}
    mids = [cid for cid in mod.get("components", []) if cid in by_id]
    mset = set(mids)
    ins_list, outs_list = mod.get("contracts_in", []), mod.get("contracts_out", [])

    # Wires are classified by the REGISTER's own direction; the module's in/out
    # lists only pick which contracts the view shows and give boundary wires
    # (neither endpoint owned here) their side.
    wires, seen = [], set()
    for cid in ins_list + outs_list:
        if cid in seen or cid not in contracts:
            continue
        seen.add(cid)
        k = contracts[cid]
        f, t = k["from"], k["to"]
        if f in mset and t in mset:
            wires.append(dict(cid=cid, k=k, kind="I"))
        elif t in mset:
            wires.append(dict(cid=cid, k=k, kind="IN", peer=f, target=t))
        elif f in mset:
            wires.append(dict(cid=cid, k=k, kind="OUT", peer=t, target=f))
        else:
            d = "IN" if cid in ins_list else "OUT"
            wires.append(
                dict(cid=cid, k=k, kind=d, peer=f if d == "IN" else t, target=None)
            )

    part = [
        fl
        for fl in model["flows"]
        if mset & {x for a, b, _ in fl["steps"] for x in (a, b)}
    ]

    # ---- geometry (units are quarter-mm; see Sheet) ----
    PW = 150  # peer box width
    PLX, PRX = 24, 506  # peer column left edges
    PAN_L, PAN_R, PAN_W = 264, 416, 152  # module boundary panel
    CB_L, CB_W, CH = 272, 136, 52  # component boxes
    TOP, CPITCH = 100, 66
    n_stack = max(len(mids), 1)
    comp_cy = [TOP + 50 + i * CPITCH for i in range(n_stack)]
    panel_bottom = comp_cy[-1] + CH / 2 + 30
    panel_cy = TOP + (panel_bottom - TOP) / 2

    # ---- peer rows per side: entry slots per target, then a collision pass ----
    rows_by_side: dict[str, list] = {}
    for side in ("IN", "OUT"):
        sw = [w for w in wires if w["kind"] == side]
        groups: dict = {}
        for w in sw:
            groups.setdefault(w["target"], []).append(w)
        for tgt, g in groups.items():
            n = len(g)
            for i, w in enumerate(g):
                off = (i - (n - 1) / 2) * (26 if tgt is None else 20)
                w["entry"] = panel_cy + off if tgt is None else comp_cy[mids.index(tgt)] + off
        # global separation pass: a boundary port may not sit on a component's
        # entry line, or their labels collide (CT-02 vs CT-15 on M9)
        entries = sorted(sw, key=lambda w: w["entry"])
        for i in range(1, len(entries)):
            prev = entries[i - 1]["entry"]
            if entries[i]["entry"] < prev + 22:
                e = entries[i]
                if e["target"] is None:  # ports have edge freedom — move them
                    e["entry"] = min(prev + 22, panel_bottom - 14)
                elif entries[i - 1]["target"] is None:
                    entries[i - 1]["entry"] = max(
                        e["entry"] - 22, TOP + 14
                    )
                    entries[i]["entry"] = max(e["entry"], entries[i - 1]["entry"] + 22)
        merged: dict = {}
        for w in sorted(sw, key=lambda w: w["entry"]):
            p = w["peer"]
            if p in merged:
                merged[p]["ks"].append(w)
            else:
                merged[p] = dict(peer=p, ks=[w], h=34 + 24)
        rows, ytop = [], 128
        for r in sorted(merged.values(), key=lambda r: r["ks"][0]["entry"]):
            top = max(r["ks"][0]["entry"] - r["h"] / 2, ytop)
            r["y"] = top
            ytop = top + r["h"] + 26  # room for the next row's enclosure label
            rows.append(r)
        for i, r in enumerate(rows):  # corridor per row, in row order: no crossings
            r["cx"] = (186 + 10 * i) if side == "IN" else (494 - 10 * i)
        rows_by_side[side] = rows

    band_bottom = panel_bottom
    for side in ("IN", "OUT"):
        for r in rows_by_side[side]:
            band_bottom = max(band_bottom, r["y"] + r["h"])

    sh = Sheet(10)  # true height fixed once the bottom band is placed

    sh.text(24, 34, f"{mod['id']} — {mod['name']}", F_TITLE)
    yy = 56
    for ln in wrap(mod["blurb"].upper(), 96)[:2]:
        sh.text(24, yy, ln, F_SMALL)
        yy += 12
    sh.text(24, 84, "CONTRACTS INTO THE MODULE", F_TINY)
    sh.text(656, 84, "CONTRACTS OUT OF THE MODULE", F_TINY, anchor="end")

    # ---- module boundary panel and its components ----
    sh.panel(PAN_L, TOP, PAN_W, panel_bottom - TOP)
    sh.text(PAN_L + 6, panel_bottom - 8, f"MODULE BOUNDARY — {mod['id']}", F_TINY)
    for i, cid in enumerate(mids):
        c = by_id[cid]
        cy = comp_cy[i]
        sh.box(CB_L, cy - CH / 2, CB_W, CH)
        nls = wrap(SHORT.get(c["name"], c["name"]), 26)
        if len(nls) == 1:
            sh.text(CB_L + CB_W / 2, cy - 4, nls[0], F_SMALL, anchor="middle")
        else:
            sh.text(CB_L + CB_W / 2, cy - 12, nls[0], F_SMALL, anchor="middle")
            sh.text(CB_L + CB_W / 2, cy - 2, nls[1], F_SMALL, anchor="middle")
        sh.text(CB_L + CB_W / 2, cy + 14, _host_tag(cid, c), F_TINY, anchor="middle")
        tag = _host_tag(cid, c)
        if tag == "IN THE BUNKER":
            _enclosure(
                sh, CB_L - 6, cy - CH / 2 - 20, CB_W + 12, CH + 28,
                "BUNKER EXECUTION BOUNDARY",
            )
        elif cid == "crier":
            _enclosure(
                sh, CB_L - 6, cy - CH / 2 - 20, CB_W + 12, CH + 28,
                "CRIER · LAUNCH / RETURN BOUNDARY",
            )
    if not mids:  # M0 — the shell substrate, no bus component
        cy = comp_cy[0]
        sh.box(CB_L, cy - CH / 2 - 5, CB_W, CH + 10)
        sh.text(CB_L + CB_W / 2, cy - 12, "SHELL SUBSTRATE", F_SMALL, anchor="middle")
        sh.text(CB_L + CB_W / 2, cy - 1, "NO BUS COMPONENT", F_TINY, anchor="middle")
        sh.text(CB_L + CB_W / 2, cy + 11, "OK · BAD · WARN · NOTE", F_TINY, anchor="middle")
        sh.text(CB_L + CB_W / 2, cy + 21, "FETCH_VERIFIED · REQUIRE_DISK", F_TINY, anchor="middle")

    if not rows_by_side["IN"]:
        sh.text(24, 130, "NO UPSTREAM CONTRACTS", F_TINY)
    if not rows_by_side["OUT"]:
        sh.text(656, 130, "NO DOWNSTREAM CONTRACTS", F_TINY, anchor="end")

    def draw_wire(w, y_peer, cx):
        k = w["k"]
        dash = STATE_DASH.get(k["state"], STATE_DASH["UNVERIFIED"])
        ye = w["entry"]
        if w["kind"] == "IN":
            x_end = 271.2 if w["target"] is not None else 262.8
            if abs(y_peer - ye) < 8:
                sh.line(174, ye, x_end, ye, sw=1.4, dash=dash, arrow=True)
                lab = (174 + x_end) / 2
            else:
                sh.poly(
                    [(174, y_peer), (cx, y_peer), (cx, ye), (x_end, ye)],
                    sw=1.4, dash=dash, arrow=True,
                )
                lab = (cx + x_end) / 2
        else:
            x0 = 408 if w["target"] is not None else PAN_R
            if abs(y_peer - ye) < 8:
                sh.line(x0, ye, 504.8, ye, sw=1.4, dash=dash, arrow=True)
                lab = (x0 + 504.8) / 2
            else:
                sh.poly(
                    [(x0, ye), (cx, ye), (cx, y_peer), (504.8, y_peer)],
                    sw=1.4, dash=dash, arrow=True,
                )
                lab = (x0 + cx) / 2
        sh.text(lab, ye - 5, w["cid"], F_TINY, anchor="middle")

    # ---- peer boxes (contract id · signal, state), boundary enclosures, wires ----
    for side in ("IN", "OUT"):
        for r in rows_by_side[side]:
            x = PLX if side == "IN" else PRX
            y, hh = r["y"], r["h"]
            comp = by_id.get(r["peer"])
            name = SHORT.get(comp["name"], comp["name"]) if comp else str(r["peer"]).upper()
            sh.box(x, y, PW, hh)
            sh.text(x + 10, y + 15, name, F_SMALL)
            sh.text(x + 10, y + 26, _host_tag(r["peer"], comp), F_TINY)
            ty = y + 37
            for w in r["ks"]:
                sig = w["k"].get("signal")
                sh.text(x + 10, ty, f"{w['cid']} · {sig}" if sig else w["cid"], F_TINY)
                sh.text(x + 10, ty + 11, str(w["k"]["state"]), F_TINY)
                ty += 22
            tag = _host_tag(r["peer"], comp)
            if tag == "IN THE BUNKER":
                _enclosure(sh, x - 6, y - 20, PW + 12, hh + 28, "BUNKER EXECUTION BOUNDARY")
            elif r["peer"] == "crier":
                _enclosure(sh, x - 6, y - 20, PW + 12, hh + 28, "CRIER · LAUNCH / RETURN BOUNDARY")
            for w in r["ks"]:
                draw_wire(w, y + hh / 2, r["cx"])

    # ---- internal contracts: both endpoints are this module's components ----
    for w in [w for w in wires if w["kind"] == "I"]:
        k = w["k"]
        dash = STATE_DASH.get(k["state"], STATE_DASH["UNVERIFIED"])
        ip, ic = mids.index(k["from"]), mids.index(k["to"])
        y1, y2 = comp_cy[ip], comp_cy[ic]
        txt = f"{w['cid']} · {k['state']}"
        wdt = len(txt) * 4.3
        if abs(ip - ic) == 1:  # adjacent in the stack: through the shared gap
            x = CB_L + CB_W / 2
            if ic > ip:
                sh.line(x, y1 + CH / 2, x, y2 - CH / 2 - 1, sw=1.4, dash=dash, arrow=True)
            else:
                sh.line(x, y1 - CH / 2, x, y2 + CH / 2 + 1, sw=1.4, dash=dash, arrow=True)
            mid = (y1 + y2) / 2
            sh.add(
                f'<rect x="{x - wdt / 2 - 3:.1f}" y="{mid - 5:.1f}" width="{wdt + 6:.1f}" '
                f'height="10" fill="{PAPER}"/>'
            )
            sh.text(x, mid + 2.5, txt, F_TINY, anchor="middle")
        else:  # around through the inner margin between boxes and panel edge
            xc = 412
            sh.poly(
                [(CB_L + CB_W, y1), (xc, y1), (xc, y2), (CB_L + CB_W - 1.2, y2)],
                sw=1.4, dash=dash, arrow=True,
            )
            gap_centers = [
                (comp_cy[i] + CH / 2 + comp_cy[i + 1] - CH / 2) / 2
                for i in range(len(mids) - 1)
            ]
            mid = min(gap_centers, key=lambda g: abs(g - (y1 + y2) / 2))
            sh.add(
                f'<rect x="{xc - wdt - 8:.1f}" y="{mid - 5:.1f}" width="{wdt + 6:.1f}" '
                f'height="10" fill="{PAPER}"/>'
            )
            sh.text(xc - 5, mid + 2.5, txt, F_TINY, anchor="end")

    # ---- flows this module participates in ----
    fy = band_bottom + 30
    sh.text(24, fy, "FLOWS THIS MODULE PARTICIPATES IN", F_TINY)
    if part:
        for i, fl in enumerate(part):
            r_, c_ = divmod(i, 3)
            sh.text(24 + c_ * 212, fy + 16 + r_ * 15, f"{fl['id']}  {fl['name']}".upper(), F_SMALL)
        flow_bottom = fy + 16 + ((len(part) - 1) // 3) * 15
    else:
        sh.text(24, fy + 16, "NONE — NO FLOW STEP NAMES THIS MODULE'S COMPONENTS", F_SMALL)
        flow_bottom = fy + 16

    ly = flow_bottom + 30
    legend_block(sh, 24, ly, STATE_LEGEND, "CONTRACT STATE — LINE STYLE, INK ONLY")
    by_ = ly + F_TINY * 1.9 * 5 + 8
    sh.add(
        f'<rect x="24" y="{by_:.1f}" width="9" height="6" fill="none" stroke="{INK}" '
        f'stroke-width="1.0" stroke-dasharray="2.5 2.5"/>'
    )
    sh.text(40, by_ + 5.5, "DASHED PANEL — MODULE / HOST / BUS BOUNDARY", F_TINY)
    nx, ny = 330, ly + 10
    for note in (
        "A BUNKER ENCLOSURE MARKS A COMPONENT THAT EXECUTES INSIDE THE BUNKER "
        "DEPLOYMENT / EXECUTION BOUNDARY; UNTAGGED BOXES RUN ON THE CONTROL HOST.",
        "THE CRIER ENCLOSURE MARKS THE LAUNCH / RETURN BOUNDARY BETWEEN THE "
        "CONTROL HOST AND THE BUNKERS (M10 §2).",
        "EACH PEER BOX CARRIES ITS CONTRACT ID, SIGNAL AND MEASURED STATE; THE "
        "WIRE STYLE REPEATS THE STATE (LEGEND, LEFT).",
    ):
        for ln in wrap(note, 74):
            sh.text(nx, ny, ln, F_TINY)
            ny += 11
    sh.h = max(by_ + 6, ny) + 16
    return sh


# --------------------------------------------------------------------------- flow sequences
# CF2A-01 v2 flow-coverage review — DRAWING CORRECTIONS for F1..F16. The model's
# flow steps remain the provenance record; these overrides redraw the DIAGRAM
# only: correct sender/receiver/direction on every arrow, request separated
# from response, local computation as a local (self) action, conditional
# behavior as a named branch (dashed arrow), and current implementation
# limitations labelled IMPL EVIDENCE — never drawn as approved target steps.
# A 4th element "BR" marks a conditional branch arrow.
FLOW_FIXES = {
    "F1": [
        (["scheduler", "board", "REFRESH + READ: LOCAL + REMOTE BOARD COPIES"]),
        (["board", "scheduler", "READ RESULT: COPY + WORKABILITY"]),
        (["scheduler", "scheduler", "LOCAL: ADMISSION (F11); PRE HOOK AFTER (IMPL EVIDENCE)"]),
        (["scheduler", "crier", "FOREMAN-ROUND REQUEST + ALLOWANCE (CT-02)"]),
        (["crier", "node", "CUSTODY: INBOX WRITE + 30 S LEASE (CT-03)"]),
        (["node", "crier", "INBOX PULL REQUEST — SIGNED GET"]),
        (["crier", "node", "LEASED RESPONSE — LAUNCH IN BUNKER"]),
        (["node", "foreman", "FOREMAN START: BRIEF + WORKSPACE IN BUNKER"]),
        (["foreman", "foreman", "LOCAL: READ BOARD + MEMORY, SELECT WORK, BUILD BRIEFS"]),
        (["foreman", "harness", "WAVE N: BRIEF — MVP HERMES HARNESS"]),
        (["harness", "foreman", "DIFF + EVIDENCE RETURNED"]),
        (["foreman", "gitreins", "GUARD TIER 1: STAGED DIFF (CT-12)"]),
        (["gitreins", "foreman", "JUDGMENT VERDICT + EVIDENCE (CT-13)"]),
        (["foreman", "board", "BOARD CLOSEOUT: ROWS + EVIDENCE (CT-14)"]),
        (["foreman", "duckbrain", "WORKER / WAVE / ROUND MEMORY (CT-15)"]),
        (["foreman", "foreman", "NEXT WAVE: ALLOWANCE NOT REPLENISHED"]),
        (["foreman", "crier", "ROUND REPORT — DURABLE RETURN LEG (CT-06R)"]),
        (["crier", "scheduler", "CORRELATED COMPLETION EVENT (CT-06)"]),
        (["scheduler", "scheduler", "LOCAL: EXECUTION SETTLEMENT — NOT BOARD"]),
        (["scheduler", "board", "END-OF-LANE: SYNC COPIES, BIND EVIDENCE"]),
    ],
    "F2": [
        (["owner", "manager", "DESIRED: HOST, PROJECT, PROFILE, PIN"]),
        (["manager", "provisioner", "PROVISIONING HANDOFF: DESIRED STATE + PROFILE"]),
        (["provisioner", "bunker", "CONTAINER CREATED, HOME, KEYS (M1 §3 S2)"]),
        (["provisioner", "node", "LAYERS: BASE, HARNESS, BUS, REPO (M1 §3)"]),
        (["provisioner", "node", "DUCKBRAIN IN EVERY BUNKER — SAME MEMORY VIEW"]),
        (["github", "node", "CREDENTIAL ISSUED APART FROM INSTALL (M7-C1)"]),
        (["node", "duckbrain", "IDENTITY + NAMESPACE CREDENTIAL — AUTH"]),
        (["verifier", "node", "VERIFY-NODE: CREATED ≠ VERIFIED (M1 §12)"]),
        (["verifier", "manager", "VERIFIED IDENTITY + VERSION / READINESS RESULT"]),
        (["manager", "crier", "VERIFIED CRIER REGISTRATION + BINDING (M1-C1)"]),
        (["crier", "scheduler", "READINESS BINDING: IDENTITY + VERSION"]),
        (["manager", "scheduler", "LOCAL: ADMISSION ENABLED ONLY AFTER READBACK"]),
    ],

    "F3": [
        (["node", "duckbrain", "R1 RUN RECORD — WRITER: NODE WORKER (CT-09, MISSING)"]),
        (["node", "duckbrain", "R2 FLEET INDEX — WRITER: NODE WORKER (CT-09, MISSING)"]),
        (["foreman", "duckbrain", "WORKER / WAVE RECORDS — WRITER: FOREMAN (CT-15)"]),
        (["foreman", "duckbrain", "FINAL-ROUND SUMMARY AT SETTLEMENT — DISTINCT RECORD"]),
        (["foreman", "duckbrain", "R3 WEEKLY ROLLUP — ADDITIONAL, NEVER THE ROUND RECORD"]),
        (["owner", "duckbrain", "RECALL REQUEST: BY PROJECT, WEEK, LANE"]),
        (["duckbrain", "owner", "RECALL RESULTS WITH PROVENANCE + FRESHNESS"]),
        (["foreman", "foreman", "LOCAL: PRE-BRIEF RECALL SHAPES THE WORK SELECTION"]),
        (["duckbrain", "duckbrain", "LOCAL: GIT-BACKED NAMESPACE PERSIST + PENDING-SYNC STATE"]),
    ],
    "F4": [
        (["owner", "handbook", "SOURCE / REQUIREMENTS INTAKE: REDLINES + ACCEPTED ISSUE"]),
        (["foreman", "docsgate", "SKELETON + SOURCE DELIVERED"]),
        (["panel", "docsgate", "SEAT AUTHORS: FILLS, CITES FILE:LINE"]),
        (["docsgate", "foreman", "STRUCTURAL PASS OR NAMED REFUSALS (CT-16) — NOT ACCEPTANCE"]),
        (["panel", "foreman", "INDEPENDENT SEMANTIC REVIEW: 3 SEATS, SPLITS REPORTED (M6 §3 S4)"]),
        (["panel", "foreman", "BRANCH — REJECTED FINDINGS RETURN: CORRECTION LOOP", "BR"]),
        (["spine", "handbook", "CROSS-DOCUMENT CHECKS: CT IDS, STATES, DANGLING REFS (M6 §3 S9)"]),
        (["handbook", "handbook", "LOCAL: BUILD + RENDER QA — PAGES INSPECTED, UNIQUE IDS"]),
        (["handbook", "owner", "VERSIONED REVIEW PACKAGE — DRAFT / ACCEPTED STATUS (CT-18)"]),
    ],
    "F5": [
        (["node", "gitreins", "COMMIT ON A NODE BRANCH — GUARD GRADES THE STAGED DIFF (CT-12)"]),
        (["gitreins", "node", "BRANCH — GUARD REFUSAL RETURNS FOR CORRECTION", "BR"]),
        (["gitreins", "foreman", "INDEPENDENT ACCEPTANCE VERDICT + EVIDENCE (CT-13)"]),
        (["owner", "lander", "LANDER MERGES BY THE CONFIGURED PR / DIRECT-MERGE POLICY"]),
        (["lander", "lander", "LOCAL: MERGED-TREE VERIFICATION — INVALIDATED CHECKS RERUN"]),
        (["lander", "foreman", "PUBLICATION PROOF: COMMIT ANCESTOR OF ORIGIN/MAIN (M3 §2)"]),
        (["foreman", "board", "ROW CLOSED ONLY AFTER VERDICT + PROOF MATCH (CT-14)"]),
        (["foreman", "duckbrain", "WORKER / WAVE MEMORY THROUGH RECOVERABLE CLOSEOUT (CT-15)"]),
    ],
    "F6": [
        (["provisioner", "safety", "MAINTENANCE TRIGGER: PERIODIC OR CAPACITY PRESSURE"]),
        (["safety", "safety", "LOCAL: INVENTORY CANDIDATES — ACTIVE-CLAIM + PROTECTED-PATH CHECKS FIRST"]),
        (["provisioner", "safety", "ALTERNATIVE A: RECLAIM DISK — CACHES + JOB DIRS PAST 24 H TTL (M8 §3 S1)"]),
        (["provisioner", "safety", "ALTERNATIVE B: NODE HYGIENE — ORPHAN HOMES / KEYS, 60 MIN GRACE (M1 §5)"]),
        (["safety", "node", "PROTECTED PATHS REFUSED BEFORE INSPECTION: REPO, NODE.JSON, CRIER.JSON (M8 §5)"]),
        (["node", "node", "ALTERNATIVE C: REPO FRESHNESS MEASURES LAG VS ORIGIN (M3 §5)"]),
        (["verifier", "node", "ALTERNATIVE D: NODE FRESHNESS — BRANCH / HEAD / LAG (M1 §11)"]),
        (["safety", "provisioner", "RESULT: BYTES RECLAIMED + RETAINED / REFUSED REASONS"]),
    ],
    "F7": [
        (["owner", "scheduler", "READ REQUEST: GET /API/V1/METRICS — SPAWNS, DEFERRALS, TICKS (M9 §8)"]),
        (["scheduler", "owner", "METRICS RESPONSE"]),
        (["owner", "scheduler", "READ REQUEST: /API/V1/STATUS — PER-PROJECT FAILURE RATES (M9 §5)"]),
        (["scheduler", "owner", "STATUS RESPONSE"]),
        (["owner", "crier", "READ REQUEST: /METRICS — GUARD + INBOX SERIES (M10 §8)"]),
        (["crier", "owner", "METRICS RESPONSE"]),
        (["proxy", "proxy", "FILE APPEND: USAGE JSONL PER REQUEST — A LOG, NOT AN HTTP READ (M12 §8)"]),
        (["proxy", "owner", "USAGE JSONL READ OUT: NODE, MODEL, STATUS, BYTES"]),
        (["manager", "manager", "LOCAL: OBSERVE DESIRED VS EFFECTIVE → SCOPED REPAIR + READINESS"]),
        (["manager", "owner", "FACTORY EVENT DELIVERY: RECEIVER INTERPRETS / PAGES / REPAIRS"]),
    ],
    "F8": [
        (["dispatcher", "dispatcher", "BRANCH A — REPLAY: REDELIVERY REPLAYS THE RECORDED RESULT"]),
        (["crier", "node", "BRANCH B — LEASE EXPIRY: UNACKED REDELIVERS, NOT LOST"]),
        (["scheduler", "sessionstore", "BRANCH C — REAP: --REAP-SESSIONS, DRY-RUN FIRST"]),
        (["sessionstore", "scheduler", "REAP RESULT: STALE SESSIONS CLOSED ONLY ON --APPLY"]),
        (["board", "foreman", "BRANCH D — BOARD READ RESOLVES FROM ORIGIN/MAIN (M4 §3)"]),
        (["board", "owner", "LOCK CHECK RESULT: ERROR — LOCK STATE UNKNOWN (M4 §3)"]),
        (["owner", "owner", "LOCAL: STOP AND DIAGNOSE — NEVER WRITE ON AN UNKNOWN LOCK"]),
        (["scheduler", "board", "CONVERGE: STATE + READINESS RECONCILED, THEN RETRY"]),
    ],
    "F9": [
        (["gateway", "scheduler", "MODE: GATEWAY FAILS — TICK DEFERRED, NOT EXEC-SPAWNED (M9 §5)"]),
        (["scheduler", "node", "MODE: LOAD GATE — SPAWNS DEFERRED WHILE LOAD ≥ THRESHOLD (M9 §3)"]),
        (["guard", "node", "MODE: GUARD PROVIDER OUTAGE — FAIL-OPEN UNLESS FAILCLOSED (M10 §10)"]),
        (["proxy", "node", "MODE: PROXY FAILS CLOSED AT STARTUP — NO TOKEN / NO KEY → EXIT 2 (M12 §11)"]),
        (["node", "node", "IMPL EVIDENCE: ABSENT HOOK EXITS 0 — A SILENT BYPASS TO DISPOSE (M3 §10)"]),
        (["node", "gitreins", "EXIT BRANCH — GATE RESTORED: PRE-COMMIT GRADING RESUMES", "BR"]),
        (["scheduler", "gateway", "EXIT BRANCH — DEPENDENCY BACK: ADMISSION RE-EVALUATED, MODE CLEARED", "BR"]),
    ],
    "F10": [
        (["owner", "manager", "INTENT: STOP / REMOVE / REBUILD — AUTHORITY + RETENTION (M1 §5)"]),
        (["manager", "provisioner", "DRAIN: NO NEW ASSIGNMENTS; ACTIVE WORK QUIESCED / CHECKPOINTED"]),
        (["manager", "provisioner", "PRESERVE: WORKSPACE, MEMORY, EVIDENCE BEFORE DESTRUCTION"]),
        (["provisioner", "bunker", "DESTROY: CONTAINER + PER-AGENT HOME REMOVED (M1 §5)"]),
        (["provisioner", "safety", "ORPHAN HOMES / KEYS REAPED VS A LIVE-REGISTRY CHECK (M1 §10)"]),
        (["manager", "provisioner", "REBUILD: SEED REAPPLIES FROM THE MANIFEST, DRIFT NAMED (M1 §3 S4)"]),
        (["provisioner", "verifier", "VERIFY: CREATED ≠ VERIFIED BEFORE WORK RE-ENABLED (M1 §12)"]),
        (["verifier", "manager", "VERIFIED IDENTITY + VERSION / READINESS RESULT"]),
        (["manager", "crier", "RE-REGISTER: NEW BINDING AFTER READINESS (M1-C1)"]),
        (["manager", "owner", "LIFECYCLE RESULT + RETAINED EVIDENCE REPORTED"]),
    ],
    "F11": [
        (["scheduler", "board", "REFRESH BEFORE ELIGIBILITY: REPO + BOARD COPIES, REVISION RECORDED"]),
        (["board", "scheduler", "READ RESULT: BOARD VERSION + OWNERSHIP"]),
        (["scheduler", "scheduler", "LOCAL: ADMISSION MODE — OVERRIDE → NAMESPACE → COOLDOWN (M9 §3)"]),
        (["scheduler", "scheduler", "LOCAL: BOARD-STASIS GATE — A SCHEDULER DECISION FROM OBSERVATIONS"]),
        (["scheduler", "board", "WORKABILITY: WORK / NO-WORK / UNREADABLE ARE DISTINCT (M9 §3)"]),
        (["scheduler", "scheduler", "LOCAL: USAGE POOLS RESERVED, OR A CAPACITY DENIAL EMITTED (M9 §3)"]),
        (["scheduler", "scheduler", "IMPL EVIDENCE: NOOP-PACING SPACES A NO-ARTIFACT LANE, 2× TO 8× FLOOR"]),
        (["scheduler", "crier", "ADMITTED: THE ENVELOPE IS DISPATCHED (CT-02)"]),
        (["scheduler", "scheduler", "DEFERRED: NAMED REASON + NEXT ELIGIBLE WAKEUP — NEVER DROPPED"]),
        (["scheduler", "board", "AFTER SETTLEMENT: FINAL REFRESH + BOARD-CHECK VERIFIER, DURABLE INCOMPLETE ON FAILURE"]),
    ],
    "F12": [
        (["owner", "github", "ISSUE: JWT FROM THE 0600 APP KEY → INSTALLATION TOKEN (M7 §5)"]),
        (["github", "owner", "TOKEN TO A 0600 FILE — THE VALUE IS NEVER PRINTED (M7 §7)"]),
        (["github", "node", "INSTALL: REFRESH --NODE WRITES AUTH/GITHUB.TOKEN (M7 §5)"]),
        (["node", "github", "READBACK: INSTALLED CREDENTIAL CHECKED AGAINST THE ISSUE"]),
        (["scoper", "dispatcher", "SEPARATE DOMAIN: PER-DISPATCH SCOPED TOKEN (M11 §6)"]),
        (["node", "proxy", "SEPARATE DOMAIN: NODE BEARER ≠ GITHUB TOKEN — FAIL-CLOSED (M12 §6)"]),
        (["owner", "github", "BRANCH — EXPIRY / LEAK SIGNAL: RENEW OR REVOKE WITH AUTHORITY", "BR"]),
        (["github", "node", "REPLACEMENT ACCESS INSTALLED; OLD AUTHORITY DENIED (M7 §12)"]),
    ],
    "F13": [
        (["owner", "manager", "DESIRED PIN + COMPATIBILITY MATRIX (M5 §5)"]),
        (["manager", "harness", "INSTALLER FETCHES A DIGEST-CHECKED ARTIFACT, APPLIES (M5 §5)"]),
        (["harness", "manager", "READBACK: INSTALLED VERSION VS PIN; DRIFT NAMED (M5 §10)"]),
        (["manager", "scheduler", "MIGRATION STORES APPLY THE SCHEMA CHANGE (M9 §3)"]),
        (["manager", "board", "MIGRATE: BOARDCTL NORMALIZE-STATUSES — ROW VOCABULARY (M4 §4)"]),
        (["manager", "manager", "LOCAL: EFFECTIVE RUNTIME READINESS RESULT"]),
        (["manager", "manager", "BRANCH — FAILED APPLY: ROLLBACK OR NAMED FORWARD RECOVERY", "BR"]),
    ],
    "F14": [
        (["node", "sessionstore", "EMIT: EVERY TURN, MODEL, TOKENS, COST → SESSION SINK (CT-11)"]),
        (["scheduler", "scheduler", "LOCAL: TICK + SPAWN COUNTERS — SCHEDULER METRICS SURFACE (M9 §8)"]),
        (["proxy", "proxy", "APPEND: USAGE JSONL — CAPTURE LOSS SILENT (IMPL EVIDENCE, M12 §11)"]),
        (["foreman", "duckbrain", "MEMORY RECORDS — PROVENANCE DISTINCT FROM TOKEN TELEMETRY (CT-15)"]),
        (["scheduler", "duckbrain", "NAMESPACE SYNC EVERY 5 M — SYNCHRONIZATION, NOT TELEMETRY (M9 §5)"]),
        (["owner", "scheduler", "READOUT: METRICS QUERY, CORRELATED BY RUN / TASK IDS"]),
    ],
    "F15": [
        (["owner", "manager", "BACKUP SCOPE + TRIGGER: REPO/BOARD, MEMORY, SCHEDULER/CRIER STATE (M4 §7)"]),
        (["manager", "board", "SNAPSHOT: BOARD_DRIFT COMPARES CHECKOUT VS ORIGIN/MAIN ROW BY ROW (M4 §7)"]),
        (["manager", "scheduler", "CHECKPOINT: --VERIFY-BOARD AT BOOT (M9 §5)"]),
        (["manager", "duckbrain", "SNAPSHOT: DUCKBRAIN HISTORY + DATA TO THE BACKUP DESTINATION"]),
        (["manager", "manager", "LOCAL: RESTORE INTO A SCRATCH HOME — ISOLATED, NOT LIVE (OUTLINE F15)"]),
        (["duckbrain", "manager", "MEMORY READBACK: A KNOWN ROW READ BACK PROVES THE RESTORE"]),
        (["board", "manager", "BOARD READBACK: REPRESENTATIVE ROWS VIA BOARDCTL"]),
        (["manager", "owner", "RECOVERY-POINT + REVOKED-SECRET POLICY BEFORE RESUME"]),
    ],
    "F16": [
        (["scheduler", "crier", "PER-TARGET DISPATCH: ENVELOPE TO EACH REGISTRY AGENT (M11 §3 S4)"]),
        (["crier", "dispatcher", "CRIER DELIVERY BOUNDARY: CUSTODY + REPLAY IDENTITY"]),
        (["dispatcher", "bunker", "EXEC: BUNKER EXEC RUNS THE HARNESS IN EACH TARGET CONTAINER (M11 §3 S1)"]),
        (["dispatcher", "crier", "RESULT + ACK: REPLY DELIVERED BEFORE ACK (M11 §3 S3)"]),
        (["crier", "scheduler", "SETTLEMENT: COMPLETION SETTLES PER DISPATCH (CT-06)"]),
        (["dispatcher", "dispatcher", "IMPL EVIDENCE: SERIAL LOOP — ONE LONG JOB HEAD-OF-LINE-BLOCKS LATER AGENTS (M11 §11 F11-5)"]),
        (["dispatcher", "dispatcher", "REDELIVERY: REPLAYS THE RECORDED RESULT — NEVER RERUNS (M11 §3 S3)"]),
    ],
}


def seq_sheet(model, flow) -> Sheet:
    by_id = {c["id"]: c for c in model["components"]}
    # Drawing corrections first (review), then the model's own steps.
    raw = FLOW_FIXES.get(flow["id"], flow["steps"])
    steps = [(s[0], s[1], s[2], (s[3] if len(s) > 3 else None)) for s in raw]
    actors = []
    for a, b, _, _ in steps:
        for x in (a, b):
            if x not in actors:
                actors.append(x)
    n = len(actors)
    margin = 60
    cell = (Sheet.W - margin * 2) / n
    # label width adapts to lifeline density: an 8-lifeline sheet cannot carry the
    # 52-char labels a 4-lifeline sheet can, without the texts colliding
    w_self = max(18, int(cell * 2.4 / (F_SMALL * 0.62)))
    w_pair = max(18, int(cell * 1.9 / (F_SMALL * 0.62)))
    top = 120  # title band above; leaves room for a first step's stacked label
    note_lines = wrap(flow["note"], 116)[:2] if flow.get("note") else []
    extra = len(note_lines)
    need = len(steps) + extra
    # keep the sheet within the 250 mm figure band so the print-scale label
    # floor (2.05 mm = 8.2 units) is not silently scaled below itself
    rowh = min(46, max(34, (990 - 40 - top) // max(need, 1)))
    h = top + rowh * need + 40
    sh = Sheet(h)
    ax = {a: margin + i * cell + cell / 2 for i, a in enumerate(actors)}
    lifeline_end = h - 20 if not extra else top + rowh * len(steps) - 6

    # unique figure reference on the sheet itself — the sheet is citable as its
    # own flow number regardless of the builder's running figure code
    sh.text(12, 22, f"{flow['id']} — {flow['name']}", F_TITLE)
    sh.text(
        Sheet.W - 12,
        22,
        "TIME FLOWS DOWN · EVERY STEP CITES ITS CHAPTER OR CONTRACT · "
        "DASHED = CONDITIONAL BRANCH",
        F_TINY,
        anchor="end",
    )

    for a in actors:
        x = ax[a]
        name = by_id[a]["name"]
        bw = min(cell - 4, max(cell - 14, len(name) * F_SMALL * 0.62 + 10))
        sh.box(x - bw / 2, 36, bw, 30)
        nl = wrap(name, int(bw / (F_SMALL * 0.6)))[:2]
        y0 = 56 if len(nl) == 1 else 46
        for i, ln in enumerate(nl):
            sh.text(x, y0 + i * 12, ln, F_SMALL, anchor="middle")
        sh.hair(x, 70, x, lifeline_end, dash="3 4")

    for i, (a, b, what, kind) in enumerate(steps):
        y = top + i * rowh
        x1, x2 = ax[a], ax[b]
        br = "6 4" if kind == "BR" else None

        def wtext(x, y_, s, anchor):
            # paper-backed label: an intermediate dashed lifeline is interrupted
            # behind the text instead of striking through it (parts-strip rule)
            wdt = len(s) * 5.5 + 6
            rx = x - wdt / 2 if anchor == "middle" else (x - wdt if anchor == "end" else x - 3)
            sh.add(
                f'<rect x="{rx:.1f}" y="{y_ - 8.1:.1f}" width="{wdt:.1f}" '
                f'height="10.9" fill="{PAPER}"/>'
            )
            sh.text(x, y_, s, F_SMALL, anchor=anchor)

        sh.text(10, y + 3, f"{i + 1}", F_SMALL)
        if a == b:
            sh.poly(
                [
                    (x1 - 8, y - 2),
                    (x1 + 14, y - 2),
                    (x1 + 14, y + 24),
                    (x1 - 8, y + 24),
                ],
                arrow=True,
                dash=br,
            )
            tx, anchor = min(x1 + 24, Sheet.W - 320), "start"
        else:
            sh.line(x1, y, x2, y, arrow=True, dash=br)
            tx, anchor = (x1 + x2) / 2, "middle"
            if abs(x2 - x1) < cell * 1.5:
                right = x2 >= x1
                tx = (max(x1, x2) + 16) if right else (min(x1, x2) - 16)
                anchor = "start" if right else "end"
                tx = (
                    min(max(tx, 300), Sheet.W - 310)
                    if anchor == "start"
                    else max(min(tx, 380), 310)
                )
        maxlines = 3 if rowh >= 44 else 2
        wrapped = wrap(what, w_self if a == b else w_pair)
        if len(wrapped) > maxlines:  # never drop words silently
            raise RuntimeError(
                f"{flow['id']} step {i + 1}: label needs {len(wrapped)} lines "
                f"(cap {maxlines}) — shorten it: {what!r}"
            )
        lines = wrapped[:maxlines]
        # lines read TOP-DOWN inside a block sitting just above its own arrow —
        # an upward stack reads backwards, and a downward one strikes the arrow
        nl = len(lines)
        for j, ln in enumerate(lines):
            wtext(tx, y - 8 - (nl - 1 - j) * 13, ln, anchor)
    if note_lines:
        y = top + len(steps) * rowh + 8
        sh.hair(6, y - 14, Sheet.W - 6, y - 14)
        for j, ln in enumerate(note_lines):
            sh.text(10, y + j * 15, ("NOTE. " if j == 0 else "      ") + ln, F_SMALL)
    return sh


# --------------------------------------------------------------------------- gates
def fig_fill(svg: str) -> float:
    """Drawn-content bounding box as a fraction of the sheet area — the B7 gate:
    a sheet whose drawing stops halfway down is blankness, not breathing room."""
    vb = re.search(r'viewBox="0 0 ([\d.]+) ([\d.]+)"', svg)
    W, H = float(vb.group(1)), float(vb.group(2))
    body = svg.split("</defs>", 1)[-1]  # the marker def's dummy path stays out
    xs, ys = [], []
    for m in re.finditer(r"<(rect|line|polyline|text|circle|ellipse)\b([^>]*?)/?>", body):
        at = m.group(2)
        if m.group(1) == "polyline" or "points" in at:
            for px, py in re.findall(r"(-?[\d.]+),(-?[\d.]+)", at):
                xs.append(float(px))
                ys.append(float(py))
        vals = {
            k: float(v)
            for k, v in re.findall(
                r'\b(x1|x2|y1|y2|cx|cy|width|height|rx|ry|r)="(-?[\d.]+)"', at
            )
        }
        x = re.search(r'\bx="(-?[\d.]+)"', at)
        y = re.search(r'\by="(-?[\d.]+)"', at)
        if m.group(1) == "rect" and float(vals.get("width", 0)) > W - 10:
            continue  # the full-canvas paper rect is not content
        if x:
            xs.append(float(x.group(1)))
        if y:
            ys.append(float(y.group(1)))
        if "x1" in vals:
            xs += [vals["x1"], vals["x2"]]
            ys += [vals["y1"], vals["y2"]]
        if "cx" in vals:
            r = vals.get("r", vals.get("rx", 1.0))
            xs += [vals["cx"] - r, vals["cx"] + r]
            ys += [vals["cy"] - (vals.get("ry", r)), vals["cy"] + (vals.get("ry", r))]
        if "width" in vals and x:
            xs.append(float(x.group(1)) + vals["width"])
        if "height" in vals and y:
            ys.append(float(y.group(1)) + vals["height"])
    if not xs or not ys:
        return 0.0
    return max(0.0, (max(xs) - min(xs)) * (max(ys) - min(ys))) / (W * H)


def bw_gate(svg: str, fname: str) -> str | None:
    """No colour anywhere: every fill/stroke must be pure black or pure white."""
    bad = set()
    for v in re.findall(r'(?:fill|stroke)="([^"]+)"', svg):
        v = v.strip().lower()
        if v in ("none", "") or v.startswith("url("):
            continue
        if v in ("#000", "#000000", "#fff", "#ffffff", "black", "white"):
            continue
        bad.add(v)
    if bad:
        return f"{fname}: non-black/white paint {sorted(bad)}"
    return None


def main() -> int:
    model = yaml.safe_load(MODEL.read_text())
    OUT.mkdir(parents=True, exist_ok=True)
    made = []

    p = OUT / "system-map.svg"
    p.write_text(system_map_sheet(model).emit())
    made.append(
        (
            "system-map.svg",
            f"{len(model['components'])} components in {len(model['layers'])} layers; "
            f"every edge is a numbered contract",
        )
    )

    for mod in model["modules"]:
        p = OUT / f"module-{mod['id']}.svg"
        p.write_text(module_sheet(model, mod).emit(""))
        made.append(
            (
                p.name,
                f"{mod['id']} {mod['name']} — inputs left, outputs right, flows below",
            )
        )

    for fl in model["flows"]:
        if not fl.get("steps"):
            continue
        p = OUT / f"{fl['id']}.svg"
        p.write_text(seq_sheet(model, fl).emit(""))
        made.append((p.name, f"{fl['id']} {fl['name']} — {fl['question']}"))

    for name, title in (
        (
            "board-lifecycle",
            "board row state — including the paths that are not 'forward'",
        ),
        (
            "tick-lifecycle",
            "scheduler tick state — admission, dispatch, settlement (M9 §3)",
        ),
    ):
        p = OUT / f"{name}.svg"
        p.write_text(
            (board_lifecycle if name == "board-lifecycle" else tick_lifecycle)().emit()
        )
        made.append((p.name, title))

    # ---- GATES: XML parses, labels clear the floor, ink is black and white only ----
    failures, report, fills = [], [], []
    for fname, _desc in made:
        f = OUT / fname
        try:
            ET.fromstring(f.read_text())
        except ET.ParseError as e:
            failures.append(f"{fname}: XML parse error: {e}")
            continue
        svg = f.read_text()
        mm = min_label_mm(svg)
        report.append((fname, mm))
        if mm < FLOOR_MM:
            failures.append(
                f"{fname}: smallest label prints at {mm:.2f} mm (floor {FLOOR_MM})"
            )
        err = bw_gate(svg, fname)
        if err:
            failures.append(err)
        if fname.startswith("module-"):
            fill = fig_fill(svg)
            fills.append((fname, fill))
            if fill < 0.70:
                failures.append(
                    f"{fname}: drawing covers only {fill:.0%} of the sheet (floor 70%)"
                )

    index = [
        "# Figures",
        "",
        "Generated from `docs/SYSTEM-MODEL.yaml` by `scripts/gen_handbook_figures.py`.",
        "Genre: nasa-handbook line drafting — black ink, line-style state, Routed Gothic labels.",
        "Every label is verified >= 2.05 mm at the builder's print scale; ink is black/white only.",
        "",
        "| figure | what it answers |",
        "|---|---|",
    ]
    index += [f"| `{f}` | {q} |" for f, q in made]
    (OUT / "INDEX.md").write_text("\n".join(index) + "\n")

    print(f"{len(made)} figures -> {OUT.relative_to(ROOT)}")
    for fname, mm in report:
        print(f"  {fname:<24} min label {mm:.2f} mm")
    for fname, fill in fills:
        print(f"  {fname:<24} drawn fill   {fill:.0%}")
    if failures:
        print("FIGURE GATE FAIL:")
        for x in failures:
            print("  " + x)
        return 2
    print(
        "figure gate: all SVGs parse; all labels >= %.2f mm at print scale; black/white only"
        % FLOOR_MM
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
