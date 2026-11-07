#!/usr/bin/env python3
"""board_read.py — read a lane's OWN board, even when the checkout is dirty.

The failure this replaces: a tick found the workdir dirty, the skill said "a board
behind origin/main is non-evidence", and the tick refused to read the board at all.
252 pending rows became invisible, and the tick reported "not selected" as if the
board were empty.

The board lives in git. `origin/main` is the canonical store; the working copy is a
cache that other writers (workers, panel loops, siblings) are allowed to dirty.
So the board is ALWAYS readable — from the canonical ref when the working copy
disagrees, from the working copy only when there is no remote to ask.

This command never refuses. It reports which source it used, so a lane can say
"read from origin/main (local copy drifted by N rows)" instead of "prohibited".

Usage:
  board_read.py                 # summary + next dispatchable rows
  board_read.py --json          # the canonical board as JSON
  board_read.py --next 10       # the next N dispatchable rows
  board_read.py --source        # just the source and its freshness
"""
from __future__ import annotations

import argparse
import json
import pathlib
import subprocess
import sys

BOARD = ".coding-hermes/board/tasks.jsonl"
TERMINAL = {"complete", "completed", "done", "closed", "cancelled", "canceled", "blocked", "deferred"}


def git(root: pathlib.Path, *args: str) -> str | None:
    try:
        out = subprocess.run(
            ["git", "-C", str(root), *args],
            capture_output=True, text=True, timeout=25,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    return out.stdout if out.returncode == 0 else None


def parse(text: str) -> list[dict]:
    rows = []
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError:
            continue  # a malformed row is not a reason to refuse the whole board
    return rows


def load(root: pathlib.Path) -> tuple[list[dict], str]:
    """Return (rows, source). Canonical ref first, working copy second."""
    # A remote ref that exists but is behind local is still the canonical store for
    # a lane; only the absence of the ref sends us to the working copy.
    for ref in ("origin/main", "origin/master", "main", "HEAD"):
        blob = git(root, "show", f"{ref}:{BOARD}")
        if blob and blob.strip():
            return parse(blob), ref
    local = root / BOARD
    if local.exists():
        return parse(local.read_text()), "worktree"
    return [], "none"


def workable(rows: list[dict]) -> list[dict]:
    done = {str(r.get("id")) for r in rows if str(r.get("status", "")).lower() in TERMINAL}
    out = []
    for r in rows:
        if str(r.get("status", "")).lower() != "pending":
            continue
        deps = r.get("depends_on") or r.get("depends") or []
        if isinstance(deps, str):
            deps = [d.strip() for d in deps.split(",") if d.strip()]
        if any(str(d) not in done for d in deps):
            continue
        out.append(r)
    order = {"P0": 0, "P1": 1, "P2": 2, "P3": 3}
    out.sort(key=lambda r: (order.get(str(r.get("priority", "")), 9), str(r.get("id"))))
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=".")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--next", type=int, default=5)
    ap.add_argument("--source", action="store_true")
    a = ap.parse_args()
    root = pathlib.Path(a.root).resolve()

    rows, source = load(root)
    if not rows:
        print(json.dumps({"source": source, "rows": 0,
                          "error": "no board found in any ref or in the worktree"}))
        return 0

    if a.source:
        print(json.dumps({"source": source, "rows": len(rows)}))
        return 0
    if a.json:
        print(json.dumps({"source": source, "rows": rows}))
        return 0

    counts: dict[str, int] = {}
    for r in rows:
        counts[str(r.get("status"))] = counts.get(str(r.get("status")), 0) + 1
    nxt = workable(rows)
    print(f"board source : {source}   ({len(rows)} rows)")
    print("status       : " + "  ".join(f"{k}={v}" for k, v in sorted(counts.items())))
    print(f"dispatchable : {len(nxt)} pending rows with satisfied dependencies")
    for r in nxt[: a.next]:
        print(f"  {r.get('id'):<10} {str(r.get('priority')):<3} {str(r.get('title', ''))[:90]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
