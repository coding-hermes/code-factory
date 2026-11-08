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
    "TASK-ROUTER": "ROUTER",
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
    TINY, SMALL, TITLE = 12.0, 13.4, 19.0
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

    GH = 140  # gutter between panels (holds routing lanes)
    LANE0, LANE_STEP, N_LANES = 12, 16, 8
    panels = []
    y = 10
    for layer in model["layers"]:
        members = by_layer[layer["id"]]
        rows = max(1, -(-len(members) // cols))
        ph = NAME_H + rows * (BH + ROWGAP) + 8
        panels.append((layer, members, y, ph, rows))
        y += ph + GH
    H = y - GH + 96  # legend band below the last panel

    sh = Sheet(H)
    sh.text(16, 28, "CODE FACTORY — SYSTEM MAP", TITLE)
    sh.text(
        664,
        26,
        "WIRE CT-nn IS KEYED TO THE CONTRACT REGISTER (PART IV)",
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
            y0 = by + BH / 2 - (len(lines) - 1) * SMALL / 2 + SMALL * 0.35
            for j, ln in enumerate(lines):
                sh.text(bx + BW / 2, y0 + j * SMALL, ln, SMALL, anchor="middle")

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
        elif la < lb:
            x1 = ax + aw / 2
            x2 = bx + bw / 2
            if lb - la == 1:
                ly = lane(la)
                sh.poly(
                    [(x1, ay + ah), (x1, ly), (x2, ly), (x2, by)], dash=dash, arrow=True
                )
                sh.text((x1 + x2) / 2, ly - 5, cid, TINY, anchor="middle")
            else:
                g1, g2 = lane(la), lane(lb - 1)
                xc = corridors.claim(ay + ah, by)
                sh.poly(
                    [(x1, ay + ah), (x1, g1), (xc, g1), (xc, g2), (x2, g2), (x2, by)],
                    dash=dash,
                    arrow=True,
                )
                sh.text((x1 + xc) / 2, g1 - 5, cid, TINY, anchor="middle")
        else:
            x1 = ax + aw / 2
            x2 = bx + bw / 2
            if la - lb == 1:
                ly = lane(lb)
                sh.poly(
                    [(x1, ay), (x1, ly), (x2, ly), (x2, by + bh)], dash=dash, arrow=True
                )
                sh.text((x1 + x2) / 2, ly - 5, cid, TINY, anchor="middle")
            else:
                g1, g2 = lane(la - 1), lane(lb)
                xc = corridors.claim(ay, by + bh)
                sh.poly(
                    [(x1, ay), (x1, g1), (xc, g1), (xc, g2), (x2, g2), (x2, by + bh)],
                    dash=dash,
                    arrow=True,
                )
                sh.text((x1 + xc) / 2, g1 - 5, cid, TINY, anchor="middle")

    legend_block(
        sh, 16, H - 76, STATE_LEGEND, "CONTRACT STATE — LINE STYLE, INK ONLY", fs=TINY
    )
    return sh


# --------------------------------------------------------------------------- state machines
def sm_sheet(states, edges, title, note) -> Sheet:
    """states: (id, label lines, col, row); edges: (a, b, label, kind) with kind in
    V (straight down), G (gutter route), S (side-channel return)."""
    BW, BH = 130, 44
    col_x = [120, 340, 560]
    row_y = [70, 170, 270, 370, 470, 570]
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
        ("running", ["IN PROGRESS", "WORKER EXECUTING"], 1, 2),
        ("review", ["REVIEW", "VERDICT EXPECTED"], 1, 3),
        ("complete", ["COMPLETE", "EVIDENCE BOUND"], 1, 4),
        ("deferred", ["DEFERRED", "NOT THIS CADENCE"], 0, 0),
        ("blocked", ["BLOCKED", "OWNERSHIP OR DEFECT"], 2, 2),
    ]
    edges = [
        ("pending", "claimed", "TICK SELECTS", "V"),
        ("claimed", "running", "GITREINS START", "V"),
        ("running", "review", "COMMIT LANDED", "V"),
        ("review", "complete", "VERDICT + EVIDENCE", "V"),
        # return: review right edge -> channel x=440 -> running right edge, 10 BELOW
        # the WORKER DIED line so the two arrowheads on that edge never share a y
        (
            "review",
            "running",
            (
                [(405, 370), (440, 370), (440, 280), (405, 280)],
                "CHANGES REQUESTED",
                448,
                325,
                -90,
            ),
            "S",
        ),
        ("pending", "deferred", "DEPENDENCY UNMET", "H"),
        ("pending", "blocked", "CANNOT PROCEED", "G"),
        # return: blocked top -> left part of pending's bottom edge, x=396 clear of
        # the TICK SELECTS riser at 340; one perpendicular crossing (no dot) at G's riser
        (
            "blocked",
            "pending",
            (
                [(560, 248), (560, 117), (396, 117), (396, 92)],
                "BLOCKER ROW CLOSED",
                478,
                113,
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
        "A ROW LEAVES THE BOARD ONLY THROUGH COMPLETE. BLOCKED AND DEFERRED ARE "
        "STATES OF PENDING, NOT EXITS.",
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
def module_sheet(model, mod) -> Sheet:
    by_id = {c["id"]: c for c in model["components"]}
    contracts = {k.get("id", f"{k['from']}->{k['to']}"): k for k in model["contracts"]}
    mcomps = [by_id[cid] for cid in mod.get("components", []) if cid in by_id]

    def row(cid):
        k = contracts[cid]
        frm, to = by_id.get(k["from"]), by_id.get(k["to"])
        return k, (frm["name"] if frm else k["from"]), (to["name"] if to else k["to"])

    ins = [(cid,) + row(cid) for cid in mod.get("contracts_in", [])]
    outs = [(cid,) + row(cid) for cid in mod.get("contracts_out", [])]

    part = []
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
    h = cy + 100 + rows * rowh + 60 + max(len(part), 1) * 40 + 60
    sh = Sheet(h)

    sh.text(24, 38, f"{mod['id']} — {mod['name']}", F_TITLE)
    yy = 60
    for ln in wrap(mod["blurb"], 74)[:2]:
        sh.text(24, yy, ln, F_SMALL)
        yy += 13

    # centre box with the module's components
    sh.box(cx - 75, cy - 34, 150, 84, sw=2.2)
    sh.text(cx, cy - 14, mod["id"], F_BODY, anchor="middle")
    sh.text(cx, cy + 6, mod["name"], F_HEAD, anchor="middle")
    comps_txt = (
        ", ".join(c["name"] for c in mcomps)
        if mcomps
        else "no bus component — the shell substrate (M0 §6)"
    )
    if (
        len(mcomps) != 1
        or SHORT.get(mcomps[0]["name"], mcomps[0]["name"]) not in mod["name"]
    ):
        for i, ln in enumerate(wrap(comps_txt, 34)[:2]):
            sh.text(cx, cy + (26 + i * 12), ln, F_TINY, anchor="middle")

    def contract_block(items, x, side):
        y0 = cy - 34
        sh.text(
            x,
            y0 - 14,
            "INPUTS — UPSTREAM CONTRACTS"
            if side == "l"
            else "OUTPUTS — DOWNSTREAM CONTRACTS",
            F_TINY,
        )
        if not items:
            sh.box(x, y0, colw, 44)
            sh.text(x + 10, y0 + 18, "no cross-system contract", F_SMALL)
            sh.text(x + 10, y0 + 33, "none in Part IV or the chapter's §6", F_TINY)
            return
        for i, (cid, k, peer_from, peer_to) in enumerate(items):
            y = y0 + i * rowh
            card_h = rowh - 6
            yc = y + card_h / 2
            dash = STATE_DASH.get(k["state"], STATE_DASH["UNVERIFIED"])
            if side == "l":
                sh.poly(
                    [
                        (x + colw, yc),
                        (cx - 77, cy - 28 + (i + 0.5) * (56 / max(len(items), 1))),
                    ],
                    sw=1.4,
                    dash=dash,
                    arrow=True,
                )
            else:
                sh.poly(
                    [
                        (cx + 77, cy - 28 + (i + 0.5) * (56 / max(len(items), 1))),
                        (x, yc),
                    ],
                    sw=1.4,
                    dash=dash,
                    arrow=True,
                )
            sh.box(x, y, colw, card_h)
            peer = SHORT.get(
                peer_to if side == "r" else peer_from,
                peer_to if side == "r" else peer_from,
            )
            label = (
                f"{peer} -> {mod['id']}" if side == "l" else f"{mod['id']} -> {peer}"
            )
            sh.text(x + 10, y + 16, f"{cid} · {label}  [{k['state']}]", F_TINY)
            lines = wrap(k["carries"], 46)[:2]
            for j, ln in enumerate(lines):
                sh.text(x + 10, y + (30 + j * 12), ln, F_TINY)

    contract_block(ins, lx, "l")
    contract_block(outs, rx, "r")

    fy = max(cy + 100, cy - 34 + rows * rowh + 30)
    sh.text(24, fy, "FLOWS THIS MODULE PARTICIPATES IN", F_TINY)
    if part:
        for i, fl in enumerate(part):
            txt = f"{fl['id']} {fl['name']} — {fl['question']}"
            for j, ln in enumerate(wrap(txt, 78)[:2]):
                sh.text(24 + j * 12, fy + 22 + i * 40 + j * 12, ln, F_SMALL)
    else:
        sh.text(
            24, fy + 22, "none — no flow step names this module's components", F_SMALL
        )

    legend_block(sh, Sheet.W - 250, 44, STATE_LEGEND, "CONTRACT STATE — LINE STYLE")
    return sh


# --------------------------------------------------------------------------- flow sequences
def seq_sheet(model, flow) -> Sheet:
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
    h = top + rowh * (len(steps) + extra) + 40
    sh = Sheet(h)
    ax = {a: margin + i * cell + cell / 2 for i, a in enumerate(actors)}
    lifeline_end = h - 20 if not extra else top + rowh * len(steps) - 6

    sh.text(
        Sheet.W - 12,
        24,
        "TIME FLOWS DOWN · EVERY STEP CITES ITS CHAPTER OR CONTRACT",
        F_TINY,
        anchor="end",
    )

    for a in actors:
        x = ax[a]
        name = by_id[a]["name"]
        bw = max(cell - 14, len(name) * F_BODY * 0.62)
        sh.box(x - bw / 2, 36, bw, 30)
        for i, ln in enumerate(wrap(name, int(bw / (F_BODY * 0.6)))[:1]):
            sh.text(x, 56, ln, F_BODY, anchor="middle")
        sh.hair(x, 70, x, lifeline_end, dash="3 4")

    for i, (a, b, what) in enumerate(steps):
        y = top + i * rowh
        x1, x2 = ax[a], ax[b]
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
            )
            tx, anchor = min(x1 + 24, Sheet.W - 320), "start"
        else:
            sh.line(x1, y, x2, y, arrow=True)
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
        lines = wrap(what, 44 if a == b else 52)[:2]
        for j, ln in enumerate(lines):
            sh.text(tx, y - 8 + j * 13, ln, F_SMALL, anchor=anchor)
    if flow.get("note"):
        y = top + len(steps) * rowh + 8
        sh.hair(6, y - 14, Sheet.W - 6, y - 14)
        sh.text(10, y, "NOTE. " + flow["note"], F_SMALL)
    return sh


# --------------------------------------------------------------------------- gates
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
    failures, report = [], []
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
