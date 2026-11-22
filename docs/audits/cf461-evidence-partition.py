#!/usr/bin/env python3
"""CF-461: partition every COMPLETE row whose closure evidence does not resolve.

`scripts/board_evidence_check.py` answers "does this row's evidence resolve in one of the
two stores?". It does not answer the question a rebind needs: *why* it does not resolve,
and whether a usable verdict exists somewhere else.

This instrument reuses the checker's OWN evidence-shape and resolution rules (so the two
instruments cannot drift), then classifies every finding into exactly one of:

  artifact-lost  a verdict artifact for THIS row exists under the history store, but not
                 at the run the row cites — a REBIND candidate. Every candidate run is
                 printed with its pass state and graded commit.
  never-judged   no verdict artifact for this row exists anywhere under the history store,
                 so the row was closed without a judge run and must be re-judged or
                 reopened.

Complete rows whose evidence does resolve are counted as `resolvable`; rows that name no
evidence pointer at all are `zero_evidence` and are EXCLUDED, because row CF-513 owns that
class.

Usage:
  python3 docs/audits/cf461-evidence-partition.py [repo] [board-rel] [history-root]

Defaults: repo=".", board=".coding-hermes/board/tasks.jsonl", history=<repo>/.gitreins/history.

Prints both stores' denominators, one line per finding with its class and pointers, and a
final `resolvable=N artifact_lost=N never_judged=N zero_evidence=N`. Exit 0 always: it is
an instrument, not a gate.
"""

import json
import os
import sys

REPO = sys.argv[1] if len(sys.argv) > 1 else "."
BOARD_REL = sys.argv[2] if len(sys.argv) > 2 else ".coding-hermes/board/tasks.jsonl"
HISTORY = (
    sys.argv[3]
    if len(sys.argv) > 3
    else os.path.join(os.path.abspath(REPO), ".gitreins", "history")
)

sys.path.insert(0, os.path.join(os.path.abspath(REPO), "scripts"))
import board_evidence_check as checker  # noqa: E402  (path depends on the repo argument)


def scan_history(root):
    """{run_id: [(day, run, task_id, passed, commit)]} plus the run-dir count."""
    runs = {}
    total = 0
    if not os.path.isdir(root):
        return runs, 0
    for day in sorted(os.listdir(root)):
        daypath = os.path.join(root, day)
        if not os.path.isdir(daypath):
            continue
        for run in sorted(os.listdir(daypath)):
            vpath = os.path.join(daypath, run, "verdict.json")
            if not os.path.isfile(vpath):
                continue
            total += 1
            try:
                with open(vpath, "r", encoding="utf-8") as fh:
                    verdict = json.load(fh)
            except (OSError, ValueError):
                verdict = {}
            runs.setdefault(run, []).append(
                (
                    day,
                    run,
                    verdict.get("task_id") or verdict.get("id") or "",
                    verdict.get("passed"),
                    verdict.get("commit"),
                )
            )
    return runs, total


def main():
    root = os.path.abspath(REPO)
    board_path = (
        os.path.join(root, BOARD_REL) if not os.path.isabs(BOARD_REL) else BOARD_REL
    )
    events_path = os.path.join(root, ".coding-hermes", "board", "events.jsonl")

    rows, ignored = checker._load_rows(board_path)
    events_text, ignored_events = checker._load_events(events_path)
    runs, run_dirs = scan_history(HISTORY)
    by_task = {}
    for entries in runs.values():
        for day, run, task_id, passed, commit in entries:
            by_task.setdefault(task_id, []).append((day, run, passed, commit))

    complete = [row for row in rows if row.get("status") == "complete"]
    counts = {
        "resolvable": 0,
        "artifact_lost": 0,
        "never_judged": 0,
        "zero_evidence": 0,
    }
    lines = []

    for row in sorted(complete, key=lambda r: str(r.get("id"))):
        row_id = str(row.get("id"))
        shape, references = checker._evidence_references(row)
        if not references:
            counts["zero_evidence"] += 1
            lines.append("%-22s zero-evidence  (owned by CF-513)" % row_id)
            continue
        unresolved = [
            value
            for kind, value in references
            if not checker._reference_resolves(
                root, kind, value, events_text, [HISTORY]
            )
        ]
        if not unresolved:
            counts["resolvable"] += 1
            continue
        # A list row names independent runs and each must resolve; a dict bundle is one
        # record, so it is a finding only when NONE of its pointers is inspectable (CF-486).
        is_finding = shape == "list" or len(unresolved) == len(references)
        if not is_finding:
            counts["resolvable"] += 1
            continue
        if shape == "list":
            cite = ",".join(value for _kind, value in references)
        else:
            cite = ",".join(value for _kind, value in references)
        candidates = by_task.get(row_id, [])
        if candidates:
            counts["artifact_lost"] += 1
            lines.append("%-22s artifact-lost  cited=%s" % (row_id, cite))
            for day, run, passed, commit in sorted(candidates)[-4:]:
                match = (
                    "commit-match"
                    if commit and commit == row.get("commit_hash")
                    else "commit-differs"
                )
                lines.append(
                    "      candidate %s/%s passed=%s %s commit=%s"
                    % (day, run, passed, match, (commit or "-")[:8])
                )
        else:
            counts["never_judged"] += 1
            lines.append("%-22s never-judged  cited=%s" % (row_id, cite))

    print("repo=%s" % root)
    print(
        "board=%s rows=%d complete=%d ignored_lines=%d"
        % (board_path, len(rows), len(complete), ignored + ignored_events)
    )
    print("store events=%s" % events_path)
    print("store history=%s run_dirs=%d" % (HISTORY, run_dirs))
    print()
    for line in lines:
        print(line)
    print()
    print(
        "resolvable=%d artifact_lost=%d never_judged=%d zero_evidence=%d"
        % (
            counts["resolvable"],
            counts["artifact_lost"],
            counts["never_judged"],
            counts["zero_evidence"],
        )
    )
    print(
        "findings=%d (artifact_lost + never_judged); board_evidence_check.py must report the same "
        "finding count for this history store"
        % (counts["artifact_lost"] + counts["never_judged"])
    )
    print(
        "population note: the history store is git-untracked, so a checkout with 0 run dirs "
        "reports a larger finding population by construction; pass the store you mean to grade."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
