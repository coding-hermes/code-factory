#!/usr/bin/env python3
"""Check that complete board rows point at locally inspectable evidence runs."""

import argparse
import json
import os
import sys


# Measured at base commit 12e1162 (119 complete rows); the selftest arm asserts this.
EXPECTED_UNRESOLVED = 60


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


def _load_events(events_path):
    try:
        with open(events_path, encoding="utf-8") as events_file:
            return events_file.read()
    except FileNotFoundError:
        return ""


def _load_rows(tasks_path):
    rows = []
    ignored = 0
    with open(tasks_path, encoding="utf-8") as tasks_file:
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


def check(root):
    board_root = os.path.join(root, ".coding-hermes", "board")
    tasks_path = os.path.join(board_root, "tasks.jsonl")
    events_path = os.path.join(board_root, "events.jsonl")
    history_root = os.path.join(root, ".gitreins", "history")

    rows, ignored = _load_rows(tasks_path)
    events_text = _load_events(events_path)

    findings = []
    complete_rows = [row for row in rows if row.get("status") == "complete"]
    for row in complete_rows:
        unresolved = []
        for run_id in _evidence_ids(row):
            if not (
                _run_directory_exists(history_root, run_id)
                or run_id in events_text
            ):
                unresolved.append(run_id)
        if unresolved:
            findings.append((row.get("id", "<missing-id>"), unresolved))

    return complete_rows, findings, ignored


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
        help="exit 1 when an unresolved complete row is found",
    )
    args = parser.parse_args(argv)

    try:
        complete_rows, findings, ignored = check(os.path.abspath(args.root))
    except OSError as exc:
        print(f"board evidence check failed: {exc}", file=sys.stderr)
        return 2

    if ignored:
        print(f"ignored {ignored} invalid or non-object board lines")
    for row_id, run_ids in findings:
        print(f"UNRESOLVED {row_id} {','.join(run_ids)}")
    print(f"checked {len(complete_rows)} complete rows, {len(findings)} unresolved")
    if args.strict and findings:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
