#!/usr/bin/env python3
"""Check that complete board rows point at locally inspectable evidence runs.

A complete row is only evidence when it names a run that can be inspected here.
Two shapes are findings:

* ``UNRESOLVED <id> <run>`` — the row names a run that is in neither
  ``events.jsonl`` nor any GitReins history store;
* ``ZERO-EVIDENCE <id>`` — the row's ``detail.evidence`` is empty or yields no
  run id at all, so there is nothing to resolve (CF-438).  An empty pointer is
  not a resolved pointer: without this finding the row is silently counted as
  satisfied and the gate cannot fail on it.

The accepted debt is an EXPLICIT DATED ALLOWLIST of row ids, never a number
derived from the rows being graded.  ``expected_unresolved`` is therefore the
number of findings the allowlist names, which stays below the reported count the
moment a complete row nobody accepted appears — that disagreement is what the
CF-398 selftest arm fails on.  The summary line's ``cleared`` count is allowlist
ids that no longer fail: good news, so it is reported for pruning rather than
failed on.
"""

import argparse
import json
import os
import subprocess
import sys

# Accepted complete-row evidence debt, measured on tip 8b9148c5 (2026-11-16):
# 58 rows naming a run that is absent from this store, plus the 4 rows whose
# evidence pointer is empty — CF-289, CF-305, P5G-34, CF-422.  Ids, not a count:
# a new zero-evidence or unresolvable row is reported as new, not absorbed by a
# baseline that was computed from the very findings it grades.  Adding an id here
# is a dated act of acceptance; removing one is what closing a row looks like.
ACCEPTED_UNRESOLVED_DATE = "2026-11-16"
ACCEPTED_UNRESOLVED = frozenset(
    """
    CF-008 CF-011 CF-012 CF-013 CF-034 CF-037 CF-038 CF-041 CF-050 CF-051
    CF-052 CF-064 CF-082 CF-089 CF-090 CF-092 CF-096 CF-097 CF-114 CF-115
    CF-127 CF-128 CF-141 CF-150 CF-153 CF-157 CF-167 CF-182 CF-192 CF-197
    CF-198 CF-219 CF-226 CF-230 CF-244 CF-245 CF-257 CF-259 CF-270 CF-275
    CF-277 CF-280 CF-289 CF-291 CF-303 CF-305 CF-307 CF-320 CF-354 CF-370
    CF-378 CF-379 CF-382 CF-401 CF-402 CF-404 CF-411 CF-422 P5G-34 PERF-012
    PERF-014 QA-CODE-FACTORY-2
    """.split()
)


def _default_history_roots(root):
    """Return the GitReins history stores to consult, most specific first.

    History directories are git-untracked, so a linked worktree carries only the
    subset that happens to be committed.  Reading the checkout's own store plus
    the repository-wide store (found through the common git directory) keeps a
    worktree and the registered checkout on the same effective store, and leaves
    a plain directory tree (e.g. a fixture) resolving from its own store only.
    """
    local = os.path.join(root, ".gitreins", "history")
    roots = [local]
    try:
        result = subprocess.run(
            ["git", "-C", root, "rev-parse", "--git-common-dir"],
            capture_output=True,
            text=True,
            timeout=10,
        )
    except (OSError, subprocess.SubprocessError):
        return roots
    if result.returncode != 0 or not result.stdout.strip():
        return roots
    common_dir = result.stdout.strip()
    if not os.path.isabs(common_dir):
        common_dir = os.path.join(root, common_dir)
    shared = os.path.join(
        os.path.dirname(os.path.abspath(common_dir)), ".gitreins", "history"
    )
    if shared not in roots:
        roots.append(shared)
    return roots


def _run_directory_exists(history_root, run_id):
    """Return whether any dated GitReins history directory contains run_id."""
    if not os.path.isdir(history_root):
        return False
    try:
        dates = os.listdir(history_root)
    except OSError:
        return False
    for date in dates:
        if os.path.isdir(os.path.join(history_root, date, run_id)):
            return True
    return False


def _history_run_count(history_root):
    """Return the number of run directories under dated history directories."""
    if not os.path.isdir(history_root):
        return 0
    count = 0
    try:
        dates = os.listdir(history_root)
    except OSError:
        return 0
    for date in dates:
        date_path = os.path.join(history_root, date)
        if not os.path.isdir(date_path):
            continue
        try:
            count += sum(
                os.path.isdir(os.path.join(date_path, run_id))
                for run_id in os.listdir(date_path)
            )
        except OSError:
            continue
    return count


def _load_events(events_path):
    valid_lines = []
    ignored = 0
    try:
        with open(events_path, encoding="utf-8", errors="replace") as events_file:
            for line in events_file:
                if not line.strip():
                    continue
                try:
                    json.loads(line)
                except (TypeError, ValueError, UnicodeDecodeError):
                    ignored += 1
                    continue
                valid_lines.append(line)
    except FileNotFoundError:
        pass
    return "".join(valid_lines), ignored


def _load_rows(tasks_path):
    rows = []
    ignored = 0
    with open(tasks_path, encoding="utf-8", errors="replace") as tasks_file:
        for line in tasks_file:
            if not line.strip():
                continue
            try:
                record = json.loads(line)
            except (TypeError, ValueError, UnicodeDecodeError):
                ignored += 1
                continue
            if not isinstance(record, dict):
                ignored += 1
                continue
            rows.append(record)
    return rows, ignored


def _evidence_ids(row):
    detail = row.get("detail")
    if not isinstance(detail, dict):
        return []
    evidence = detail.get("evidence")
    if not isinstance(evidence, list):
        return []
    return [
        item["run_id"]
        for item in evidence
        if isinstance(item, dict)
        and isinstance(item.get("run_id"), str)
        and item["run_id"]
    ]


def check(root, history_root=None):
    """Return (complete rows, findings, ignored lines, history roots).

    Each finding is ``(row_id, kind, run_ids)`` with ``kind`` either
    ``"unresolved"`` (named runs that resolve nowhere) or ``"zero-evidence"``
    (the row names no run at all, so nothing can be inspected).
    """
    board_root = os.path.join(root, ".coding-hermes", "board")
    tasks_path = os.path.join(board_root, "tasks.jsonl")
    events_path = os.path.join(board_root, "events.jsonl")
    history_bases = [history_root] if history_root else _default_history_roots(root)

    rows, ignored = _load_rows(tasks_path)
    events_text, ignored_events = _load_events(events_path)
    ignored += ignored_events

    findings = []
    complete_rows = [row for row in rows if row.get("status") == "complete"]
    for row in complete_rows:
        row_id = row.get("id", "<missing-id>")
        evidence_ids = _evidence_ids(row)
        if not evidence_ids:
            findings.append((row_id, "zero-evidence", []))
            continue
        unresolved = [
            run_id
            for run_id in evidence_ids
            if run_id not in events_text
            and not any(_run_directory_exists(base, run_id) for base in history_bases)
        ]
        if unresolved:
            findings.append((row_id, "unresolved", unresolved))

    return complete_rows, findings, ignored, history_bases


DEFAULT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def allowlist_report(findings):
    """Split findings into allowlisted, new, and allowlist entries now cleared."""
    failing = {row_id for row_id, _kind, _runs in findings}
    accepted = sorted(failing & ACCEPTED_UNRESOLVED)
    new = sorted(failing - ACCEPTED_UNRESOLVED)
    cleared = sorted(ACCEPTED_UNRESOLVED - failing)
    return accepted, new, cleared


def expected_unresolved(findings):
    """Return how many of today's findings the dated allowlist accepts.

    Derived from ACCEPTED_UNRESOLVED and the findings, never from the findings
    alone: a complete row nobody has accepted cannot raise this number, so it
    stays below the reported count and the selftest's equality check fails.
    """
    return len(allowlist_report(findings)[0])


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        help="repository root (default: the repository containing this script)",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="exit 1 when a complete row's evidence does not resolve (including a row that names no evidence at all)",
    )
    parser.add_argument(
        "--history-root",
        help="GitReins history root (default: the repository-wide .gitreins/history, shared by all worktrees)",
    )
    parser.add_argument(
        "--quiet-findings",
        action="store_true",
        help="suppress per-row unresolved findings",
    )
    args = parser.parse_args(argv)

    try:
        complete_rows, findings, ignored, history_bases = check(
            os.path.abspath(args.root),
            os.path.abspath(args.history_root) if args.history_root else None,
        )
    except OSError as exc:
        print(f"board evidence check failed: {exc}", file=sys.stderr)
        return 2

    accepted, new, cleared = allowlist_report(findings)

    if ignored:
        print(f"ignored {ignored} invalid or non-object board lines")
    if not args.quiet_findings:
        for row_id, kind, run_ids in findings:
            if kind == "zero-evidence":
                print(f"ZERO-EVIDENCE {row_id}")
            else:
                print(f"UNRESOLVED {row_id} {','.join(run_ids)}")
    print(
        f"stores: events={os.path.join(os.path.abspath(args.root), '.coding-hermes', 'board', 'events.jsonl')} "
        + " ".join(
            f"history={base} ({_history_run_count(base)} run dirs)"
            for base in history_bases
        )
    )
    print(
        f"allowlist: dated {ACCEPTED_UNRESOLVED_DATE},"
        f" {len(ACCEPTED_UNRESOLVED)} accepted ids,"
        f" {len(accepted)} accepted findings of {len(findings)} findings,"
        f" new={','.join(new) if new else 'none'},"
        f" cleared={len(cleared)}"
    )
    if os.path.abspath(args.root) == DEFAULT_ROOT:
        print(
            f"expected_unresolved={expected_unresolved(findings)}"
            f" (accepted by the {ACCEPTED_UNRESOLVED_DATE} allowlist, not derived"
            " from the findings)"
        )
    print(f"checked {len(complete_rows)} complete rows, {len(findings)} unresolved")
    if args.strict and findings:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
