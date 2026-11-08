#!/usr/bin/env python3
"""gen_contract_register.py — Part IV of the handbook, from the system model.

The register is the part a reader needs to answer "what does this side promise, and
what does that side require". The model knows the pair and the state; each side is
written from the model's `sender_guarantee` / `receiver_requirement` citation
(a file:line that was verified in the code) or, when the model names none, as RED
with the command that would settle it — prose that reads like a guarantee is worse
than an honest gap.

GATE (mechanical, run here): a row may never print State PROVEN while either side
is RED — that face contradiction is what an owner reads cold. The generator
downgrades such a row to UNVERIFIED and says so on the row, so the contradiction
cannot be generated again.

Output: docs/handbook/parts/IV-contract-register.md
"""
from __future__ import annotations

import pathlib
import sys

try:
    import yaml
except ImportError:
    sys.exit("pyyaml missing")

ROOT = pathlib.Path(__file__).resolve().parents[1]
MODEL = ROOT / "docs/SYSTEM-MODEL.yaml"
OUT = ROOT / "docs/handbook/parts/IV-contract-register.md"

STATE_MARK = {"works": "PROVEN", "broken": "BROKEN", "missing": "MISSING"}


def side(kind: str, c: dict, dst: str) -> tuple[str, bool]:
    """Rendered line for one side of the wire + whether it is closed (cited)."""
    cite = (c.get(kind) or "").strip()
    if cite:
        return cite, True
    if kind == "sender_guarantee":
        return (f"RED — no `file:line` in the model states what `{c.get('from')}` "
                "commits to."), False
    return (f"RED — what `{dst}` accepts and rejects is not stated here."), False


def main() -> int:
    model = yaml.safe_load(MODEL.read_text())
    contracts = model.get("contracts", [])
    comps = {c["id"]: c for c in model.get("components", {})}

    lines = [
        "# Part IV — Contract register",
        "",
        "Every interface that can change the behaviour or correctness of a run, named once.",
        "`CT-nn` is the canonical id used by every chapter; a chapter that names one of these",
        "interfaces must use this id, not one of its own.",
        "",
        "A contract is **both-sided** only when the sender's guarantee and the receiver's",
        "requirement are each backed by a `file:line` or a command that was run. Where the model",
        "records only one side, the row is marked **RED** and carries the command that would",
        "close it — a register that reads as complete while half its wires are one-sided is worse",
        "than an honest gap.",
        "",
        "> CAUTION: a row whose State reads PROVEN while its sender guarantee or receiver",
        "> requirement reads RED is self-contradictory — one side is measured, the other is not.",
        "> Treat such a row as UNVERIFIED until both sides carry citations. The generator",
        "> enforces this: a PROVEN state with an uncited side prints as UNVERIFIED.",
        "",
        "| id | from → to | carries | mode | state |",
        "|---|---|---|---|---|",
    ]

    red_sides = 0
    detailed = []
    for i, c in enumerate(contracts, start=1):
        src, dst = c.get("from"), c.get("to")
        s, d = comps.get(src, {}), comps.get(dst, {})
        send_line, send_ok = side("sender_guarantee", c, dst)
        recv_line, recv_ok = side("receiver_requirement", c, dst)
        state = STATE_MARK.get(c.get("state", ""), c.get("state", ""))
        downgraded = None
        if state == "PROVEN" and not (send_ok and recv_ok):
            downgraded = ("State downgraded from PROVEN: a PROVEN row needs BOTH sides "
                          "cited, and " + ("the sender guarantee" if not send_ok else
                                           "the receiver requirement") + " is RED.")
            state = "UNVERIFIED"
        red_sides += (0 if send_ok else 1) + (0 if recv_ok else 1)

        lines.append(
            f"| CT-{i:02d} | {src} → {dst} | {c.get('carries', '')} "
            f"| {c.get('mode', '')} | {state} |"
        )

        note = (c.get("note") or "").strip()
        rows = [
            f"### CT-{i:02d} — {src} → {dst}",
            "",
            f"- **Carries:** {c.get('carries', 'unnamed')}",
            f"- **Mode:** {c.get('mode', 'unstated')}",
            f"- **State:** {state}",
            f"- **Sends because:** {s.get('owns', 'not recorded')}",
            f"- **Receives because:** {d.get('owns', 'not recorded')}",
        ]
        if downgraded:
            rows.append(f"- **Downgraded:** {downgraded}")
        if note:
            rows.append(f"- **Measured defect:** {note}")
        rows.append(f"- **Sender guarantee:** {send_line}")
        rows.append(f"- **Receiver requirement:** {recv_line}")
        if not (send_ok and recv_ok):
            rows.append(
                f"- **To close:** quote the encode site in `{src}` and the decode/validate "
                f"site in `{dst}`, then replace the RED line with those citations."
            )
        rows.append("")
        detailed.append(rows)

    lines += ["", "## Contracts in detail", ""]
    for rows in detailed:
        lines += rows

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines) + "\n")
    proven = sum(1 for c in contracts
                 if STATE_MARK.get(c.get("state", ""), c.get("state", "")) == "PROVEN")
    print(f"wrote {OUT.relative_to(ROOT)} — {len(contracts)} contracts, "
          f"{proven} PROVEN, {red_sides} RED sides, both-sided: "
          f"{2 * len(contracts) - red_sides}/{2 * len(contracts)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
