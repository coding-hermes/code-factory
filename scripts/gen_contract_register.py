#!/usr/bin/env python3
"""gen_contract_register.py — Part IV of the handbook, from the system model.

The register is the part a reader needs to answer "what does this side promise, and
what does that side require". The model knows the pair and the state; it does not know
both sides of every wire, so anything unproven is written RED with the command that
would settle it rather than prose that reads like a guarantee.

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


def main() -> int:
    model = yaml.safe_load(MODEL.read_text())
    contracts = model.get("contracts", [])
    comps = {c["id"]: c for c in model.get("components", [])}

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
        "> Treat such a row as UNVERIFIED until both sides carry citations.",
        "",
        "| id | from → to | carries | mode | state |",
        "|---|---|---|---|---|",
    ]
    for i, c in enumerate(contracts, start=1):
        lines.append(
            f"| CT-{i:02d} | {c.get('from')} → {c.get('to')} | {c.get('carries', '')} "
            f"| {c.get('mode', '')} | {STATE_MARK.get(c.get('state', ''), c.get('state', ''))} |"
        )

    lines += ["", "## Contracts in detail", ""]
    for i, c in enumerate(contracts, start=1):
        src, dst = c.get("from"), c.get("to")
        s, d = comps.get(src, {}), comps.get(dst, {})
        note = (c.get("note") or "").strip()
        lines += [
            f"### CT-{i:02d} — {src} → {dst}",
            "",
            f"- **Carries:** {c.get('carries', 'unnamed')}",
            f"- **Mode:** {c.get('mode', 'unstated')}",
            f"- **State:** {STATE_MARK.get(c.get('state', ''), c.get('state', ''))}",
            f"- **Sends because:** {s.get('owns', 'not recorded')}",
            f"- **Receives because:** {d.get('owns', 'not recorded')}",
        ]
        if note:
            lines.append(f"- **Measured defect:** {note}")
        lines.append(
            "- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to."
        )
        lines.append(
            f"- **Receiver requirement:** RED — what `{dst}` accepts and rejects is not stated here."
        )
        lines.append(
            f"- **To close:** quote the encode site in `{src}` and the decode/validate site in "
            f"`{dst}`, then replace both RED lines with those citations."
        )
        lines.append("")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines) + "\n")
    red = sum(2 for _ in contracts)
    print(f"wrote {OUT.relative_to(ROOT)} — {len(contracts)} contracts, {red} RED sides, "
          f"{len(lines)} lines")
    return 0


if __name__ == "__main__":
    sys.exit(main())
