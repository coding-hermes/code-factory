#!/usr/bin/env python3
"""Read-only, offline census of a checkout's board against its published copy."""

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys


BOARD = Path(".coding-hermes/board")
FILES = ("tasks.jsonl", "events.jsonl")
STATUSES = {"pending", "in_progress", "blocked", "complete"}


class Parser(argparse.ArgumentParser):
    def error(self, message):
        raise ValueError(message)


class Report:
    def __init__(self):
        self.failed = 0

    def row(self, passed, check, value):
        self.failed += not passed
        print(f"{'PASS' if passed else 'FAIL'}  {check} — {value}")

    def finish(self):
        print(f"RESULT: DRIFT ({self.failed} failed)" if self.failed else "RESULT: OK")
        return int(bool(self.failed))


def git(repo, *args):
    try:
        result = subprocess.run(
            ["git", "-C", str(repo), *args],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=30,
            check=False,
        )
    except (OSError, ValueError, subprocess.TimeoutExpired) as exc:
        raise ValueError(f"git {' '.join(args)}: {exc}") from exc
    if result.returncode:
        reason = result.stderr.decode("utf-8", errors="replace").strip()
        raise ValueError(
            f"git {' '.join(args)}: exit {result.returncode}; {reason or 'not an ancestor'}"
        )
    return result.stdout


def read_board(directory, side, report):
    contents = {}
    for name in FILES:
        try:
            contents[name] = (directory / name).read_bytes()
        except (OSError, ValueError) as exc:
            report.row(False, f"{side} files", f"{name}: {exc}")
        else:
            report.row(True, f"{side} files", f"{name}: {len(contents[name])} bytes")
    return contents


def parse_tasks(data, side, report):
    lines = data.splitlines()
    records = {}
    if not lines and side == "published":
        report.row(False, "board rows", "published tasks.jsonl has 0 rows")
    for number, line in enumerate(lines, 1):
        check = f"{side} tasks.jsonl line {number}"
        try:
            record = json.loads(line.decode("utf-8"))
        except (ValueError, UnicodeError, RecursionError) as exc:
            report.row(False, check, f"invalid JSON: {exc}")
            continue
        if not isinstance(record, dict):
            report.row(False, check, "expected JSON object")
            continue
        row_id = record.get("id")
        status = record.get("status")
        if not isinstance(row_id, str) or not row_id:
            report.row(False, check, "missing or invalid id")
            continue
        if row_id in records:
            report.row(False, check, f"duplicate id {row_id}")
            continue
        if not isinstance(status, str) or status not in STATUSES:
            report.row(False, check, f"{row_id}: missing or invalid status")
            continue
        records[row_id] = status
    return len(lines), records


def check(args, report):
    workdir = Path(args.workdir).expanduser().resolve()
    repo = Path(args.repo).expanduser().resolve() if args.repo else workdir
    work = read_board(workdir / BOARD, "workdir", report)
    # Zero rows must be refused before attempting to resolve the published side.
    if "tasks.jsonl" in work and not work["tasks.jsonl"].splitlines():
        report.row(False, "board rows", "tasks.jsonl has 0 rows")
    if args.published_dir:
        published = read_board(
            Path(args.published_dir).expanduser().resolve(), "published", report
        )
    else:
        published = {}
        for name in FILES:
            try:
                published[name] = git(repo, "show", f"{args.ref}:{BOARD / name}")
            except ValueError as exc:
                report.row(False, "published ref", str(exc))
            else:
                report.row(True, "published ref", f"{args.ref}:{BOARD / name} resolved")
    for name in FILES:
        for side, contents in (("workdir", work), ("published", published)):
            if name in contents:
                report.row(
                    True,
                    f"sha256 {side} {name}",
                    hashlib.sha256(contents[name]).hexdigest(),
                )
        available = name in work and name in published
        report.row(
            available and work[name] == published[name],
            f"byte parity {name}",
            "identical"
            if available and work[name] == published[name]
            else "bytes differ"
            if available
            else "unavailable board file",
        )
    census = {}
    for side, contents in (("workdir", work), ("published", published)):
        if "tasks.jsonl" in contents:
            census[side] = parse_tasks(contents["tasks.jsonl"], side, report)
    if len(census) == 2:
        work_count, work_rows = census["workdir"]
        pub_count, pub_rows = census["published"]
        divergent = sorted(
            key
            for key in work_rows.keys() & pub_rows.keys()
            if work_rows[key] != pub_rows[key]
        )
        missing = sorted(pub_rows.keys() - work_rows.keys())
        extra = sorted(work_rows.keys() - pub_rows.keys())
        for key in divergent:
            report.row(
                False,
                "board status",
                f"{key}: workdir={work_rows[key]} published={pub_rows[key]}",
            )
        report.row(not missing, "board missing ids", ",".join(missing) or "none")
        report.row(not extra, "board extra ids", ",".join(extra) or "none")
        all_ids = sorted(set(divergent + missing + extra))
        report.row(
            not all_ids and work_count == pub_count,
            "board rows",
            f"{work_count} vs {pub_count} rows; {len(all_ids)} divergent ids: "
            f"{','.join(all_ids) or 'none'}",
        )
    else:
        report.row(False, "board rows", "census unavailable: missing tasks.jsonl")
    if not args.no_head and not args.published_dir:
        try:
            head = git(workdir, "rev-parse", "HEAD").decode().strip()
            report.row(True, "HEAD", f"git rev-parse HEAD: {head}")
            ref_sha = git(workdir, "rev-parse", "--verify", f"{args.ref}^{{commit}}")
            ref_sha = ref_sha.decode().strip()
            try:
                git(workdir, "merge-base", "--is-ancestor", "HEAD", args.ref)
            except ValueError as exc:
                report.row(
                    False, "HEAD ancestry", f"HEAD={head} {args.ref}={ref_sha}; {exc}"
                )
            else:
                report.row(
                    True,
                    "HEAD ancestry",
                    f"git merge-base --is-ancestor HEAD {args.ref}: exit 0; "
                    f"HEAD={head} {args.ref}={ref_sha}",
                )
        except (ValueError, UnicodeError) as exc:
            report.row(False, "HEAD ancestry", str(exc))


def main():
    report = Report()
    parser = Parser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True, parser_class=Parser)
    command = commands.add_parser("check", help="compare workdir and published boards")
    command.add_argument(
        "--workdir", default=str(Path(__file__).resolve().parent.parent)
    )
    command.add_argument("--ref", default="origin/main")
    command.add_argument("--repo")
    command.add_argument("--published-dir")
    command.add_argument("--no-head", action="store_true")
    try:
        check(parser.parse_args(), report)
    except Exception as exc:
        # Bad paths, malformed input and unavailable tools must never emit tracebacks.
        report.row(False, "input", f"{type(exc).__name__}: {exc}")
    return report.finish()


if __name__ == "__main__":
    sys.exit(main())
