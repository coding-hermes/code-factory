#!/usr/bin/env python3
"""Check that complete board rows point at locally inspectable evidence runs."""

import argparse
import json
import os
import subprocess
import sys


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
    shared = os.path.join(os.path.dirname(os.path.abspath(common_dir)), ".gitreins", "history")
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
        unresolved = [
            run_id
            for run_id in _evidence_ids(row)
            if run_id not in events_text
            and not any(_run_directory_exists(base, run_id) for base in history_bases)
        ]
        if unresolved:
            findings.append((row.get("id", "<missing-id>"), unresolved))

    return complete_rows, findings, ignored, history_bases


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

    if ignored:
        print(f"ignored {ignored} invalid or non-object board lines")
    if not args.quiet_findings:
        for row_id, run_ids in findings:
            print(f"UNRESOLVED {row_id} {','.join(run_ids)}")
    print(
        f"stores: events={os.path.join(os.path.abspath(args.root), '.coding-hermes', 'board', 'events.jsonl')} "
        + " ".join(
            f"history={base} ({_history_run_count(base)} run dirs)" for base in history_bases
        )
    )
    print(f"checked {len(complete_rows)} complete rows, {len(findings)} unresolved")
    if args.strict and findings:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
