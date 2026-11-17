#!/usr/bin/env python3
"""File this tick's dogfood finding rows through the board's own writer.

Every field is passed as an argv LIST (no shell interpolation, no command
substitution). Payload bodies are read from files staged with write_file.
Prints one line per row: id, rc, and the outcome line.
"""

import subprocess
import sys

BOARD = "~/code-factory"
BOARDCTL = "~/code-factory/scripts/boardctl"
SCRATCH = "~/.hermes/cache/scratch"


def read(name):
    """Return one staged payload body."""
    with open(f"{SCRATCH}/{name}", encoding="utf-8") as fh:
        return fh.read().strip()


ROWS = [
    {
        "id": "CF-489",
        "title": (
            "P1 \u2014 no ONLINE node host in this fleet can spawn an agent: the "
            "documented step-3 node create dies at bunkerd's slice-limits stage on "
            "both hosts that answer"
        ),
        "priority": "P1",
        "complexity": "3",
        "type": "bug",
        "reasoning": read("cf489-reasoning.txt"),
        "acceptance_criteria": read("cf489-ac.txt"),
        "capability_tags": "bunker,node-create,dogfood,host-containment",
    },
    {
        "id": "CF-490",
        "title": (
            "P2 \u2014 a spawn-stage refusal is passed through verbatim: no classified "
            "host row, no remedy line, and the host prerequisite appears in no document"
        ),
        "priority": "P2",
        "complexity": "2",
        "type": "bug",
        "reasoning": read("cf490-reasoning.txt"),
        "acceptance_criteria": read("cf490-ac.txt"),
        "capability_tags": "node-create,docs,error-surface,dogfood",
    },
]


def main():
    """Create each row; return 0 only when every create succeeded."""
    rc_all = 0
    for row in ROWS:
        argv = [
            BOARDCTL,
            "-C",
            f"{BOARD}/.coding-hermes/board",
            "create",
            "--id",
            row["id"],
            "--title",
            row["title"],
            "--type",
            row["type"],
            "--status",
            "pending",
            "--priority",
            row["priority"],
            "--complexity",
            row["complexity"],
            "--reasoning",
            row["reasoning"],
            "--acceptance-criteria",
            row["acceptance_criteria"],
            "--capability-tags",
            row["capability_tags"],
        ]
        proc = subprocess.run(argv, capture_output=True, text=True, cwd=BOARD)
        out = (proc.stdout or proc.stderr or "").strip().splitlines()
        print(f"{row['id']} rc={proc.returncode} out={out[0] if out else '<empty>'}")
        if proc.returncode != 0:
            rc_all = 1
            print((proc.stderr or "")[-600:])
    return rc_all


if __name__ == "__main__":
    sys.exit(main())
