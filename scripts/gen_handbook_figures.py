#!/usr/bin/env python3
"""gen_handbook_figures.py — the visual layer the handbook was missing.

The book had correctness and no orientation: 33k words of hard detail and not one page
that answers "what does this system look like". A reader cannot hold a fleet in their
head from prose alone.

Every figure here is generated from docs/SYSTEM-MODEL.yaml, so it cannot drift from the
model — a flow that changes produces a diagram that changes. Output is SVG, which stays
crisp in both the HTML book and the PDF.
"""
from __future__ import annotations

import pathlib
import sys

import yaml

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import gen_system_views as g  # noqa: E402

ROOT = HERE.parent
MODEL = ROOT / "docs/SYSTEM-MODEL.yaml"
OUT = ROOT / "docs/handbook/figures"

LIFECYCLE_DOT = """
digraph board_row {
  rankdir=LR;
  bgcolor="white";
  node [shape=box style="rounded,filled" fontname="Helvetica" fontsize=13 color="#333"];
  edge [fontname="Helvetica" fontsize=11 color="#555"];

  pending   [label="pending\\ndispatchable", fillcolor="#eef2ff"];
  claimed   [label="claimed\\nby a tick", fillcolor="#e0f2fe"];
  running   [label="in_progress\\nworker executing", fillcolor="#dcfce7"];
  review    [label="review\\nverdict expected", fillcolor="#fef9c3"];
  complete  [label="complete\\nevidence resolves", fillcolor="#bbf7d0"];
  blocked   [label="blocked\\nownership or defect", fillcolor="#fecaca"];
  deferred  [label="deferred\\nnot this cadence", fillcolor="#e5e7eb"];

  pending  -> claimed  [label="tick selects"];
  claimed  -> running  [label="gitreins start"];
  running  -> review   [label="commit landed"];
  review   -> complete [label="verdict + evidence"];
  review   -> running  [label="changes requested"];
  pending  -> blocked  [label="cannot proceed"];
  pending  -> deferred [label="dependency unmet"];
  blocked  -> pending  [label="blocker row closed"];
  running  -> blocked  [label="worker died"];
}
"""


def slug(s: str) -> str:
    return "".join(ch.lower() if ch.isalnum() else "-" for ch in s).strip("-")[:40]


def main() -> int:
    model = yaml.safe_load(MODEL.read_text())
    OUT.mkdir(parents=True, exist_ok=True)
    made = []

    g.render_dot(g.master_dot(model), OUT / "00-system-map.svg")
    made.append(("00-system-map.svg", "The system as components and layers — responsibilities, not paths"))

    g.render_dot(LIFECYCLE_DOT, OUT / "00-board-row-lifecycle.svg")
    made.append(("00-board-row-lifecycle.svg", "How a board row moves, including the paths that are not 'forward'"))

    for flow in model.get("flows", []):
        fid = flow.get("id", "F?")
        name = f"{fid}-{slug(flow.get('name', 'flow'))}"
        (OUT / f"{name}.svg").write_text(g.seq_svg(model, flow))
        made.append((f"{name}.svg", f"{fid} — {flow.get('question', flow.get('name', ''))}"))

    index = ["# Figures", "", "Generated from `docs/SYSTEM-MODEL.yaml` by `scripts/gen_handbook_figures.py`.", "",
             "| figure | what it answers |", "|---|---|"]
    index += [f"| `{f}` | {q} |" for f, q in made]
    (OUT / "INDEX.md").write_text("\n".join(index) + "\n")

    print(f"{len(made)} figures -> {OUT.relative_to(ROOT)}")
    for f, q in made:
        print(f"  {f:<40} {q[:70]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
