#!/usr/bin/env python3
"""Read every registered worktree; reap only clean, landed, writer-free trees."""

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

DEFAULT_REPO = Path(__file__).resolve().parent.parent


def git(repo, *args):
    """Do not refresh index files during a read-only census or dry run."""
    return subprocess.run(
        ["git", "-C", os.fspath(repo), *args],
        env={**os.environ, "GIT_OPTIONAL_LOCKS": "0"},
        capture_output=True,
        timeout=30,
        check=False,
    )


def checked_git(repo, *args):
    result = git(repo, *args)
    if result.returncode:
        raise RuntimeError(os.fsdecode(result.stderr).strip() or "git command failed")
    return result.stdout


def registry(repo):
    """NUL fields preserve literal paths, including spaces and embedded newlines."""
    records = []
    record = {}
    for field in checked_git(repo, "worktree", "list", "--porcelain", "-z").split(
        b"\0"
    ):
        if not field:
            if record:
                records.append(record)
                record = {}
            continue
        key, _, value = os.fsdecode(field).partition(" ")
        record[key] = value
    if record:
        records.append(record)
    if not records or any("worktree" not in entry for entry in records):
        raise RuntimeError("worktree registry is empty or malformed")
    return records


def process_cwds(include_unresolved=False):
    """Only this uid; post-removal scans retain unresolved, still-present pids."""
    processes = []
    for entry in Path("/proc").iterdir():
        if not entry.name.isdecimal():
            continue
        try:
            if entry.stat().st_uid != os.getuid():
                continue
        except OSError:
            continue
        try:
            cwd = os.readlink(entry / "cwd")
        except OSError:
            # A vanished pid is normal. A still-present pid with unreadable cwd
            # cannot prove removal safe; report uncertainty rather than success.
            if not include_unresolved or not entry.exists():
                continue
            try:
                state = (entry / "stat").read_text().rsplit(") ", 1)[1].split()[0]
                if state in ("Z", "X"):
                    continue
            except FileNotFoundError:
                continue
            except (OSError, IndexError):
                pass
            cwd = None
        processes.append((int(entry.name), cwd))
    return processes


def live_writer(path, processes):
    """Return ALL matching pids, or None. No production bypass of this guard."""
    root = os.path.realpath(path)
    pids = []
    for pid, cwd in processes:
        if cwd is None:
            continue
        # The suffix may be a kernel marker OR part of a real directory name.
        # Match both interpretations conservatively; never hide a live owner.
        candidates = (cwd, cwd.removesuffix(" (deleted)"))
        if any(
            candidate == root or candidate.startswith(root.rstrip(os.sep) + os.sep)
            for candidate in candidates
        ):
            pids.append(pid)
    return ",".join(str(pid) for pid in sorted(pids)) or None


def dirty_paths(output):
    """Porcelain -z has a second pathname for renames/copies, not a second entry."""
    fields = iter(output.split(b"\0"))
    count = 0
    for field in fields:
        if not field:
            continue
        count += 1
        if b"R" in field[:2] or b"C" in field[:2]:
            next(fields)
    return count


def inspect(repo, entry, processes):
    path = entry["worktree"]
    row = {
        "path": path,
        "branch": entry.get("branch", "detached"),
        "head": entry.get("HEAD", "unknown"),
        "merged": "unknown",
        "dirty": None,
        "owner": live_writer(path, processes),
        "errors": [],
    }
    try:
        if "bare" in entry:
            raise RuntimeError("bare repository, not a removable working tree")
        top = os.fsdecode(
            checked_git(path, "rev-parse", "--show-toplevel")
        ).removesuffix("\n")
        if os.path.realpath(top) != os.path.realpath(path):
            raise RuntimeError("registered path is not its own worktree root")
        head = os.fsdecode(checked_git(path, "rev-parse", "HEAD")).strip()
        if head != row["head"]:
            raise RuntimeError("HEAD changed since registry snapshot; retry census")
        row["dirty"] = dirty_paths(
            checked_git(path, "status", "--porcelain", "-z", "--untracked-files=all")
        )
        result = git(repo, "merge-base", "--is-ancestor", head, "origin/main")
        if result.returncode not in (0, 1):
            raise RuntimeError(
                os.fsdecode(result.stderr).strip() or "ancestry check failed"
            )
        row["merged"] = "merged" if result.returncode == 0 else "unmerged"
    except (OSError, RuntimeError, subprocess.TimeoutExpired, StopIteration) as exc:
        row["errors"].append(str(exc))
    return row


def refusal(row, entry, main_path):
    reasons = list(row["errors"])
    if row["path"] == main_path:
        reasons.append("main worktree")
    if "locked" in entry:
        reasons.append("locked worktree")
    if row["owner"]:
        reasons.append("live writer pid=" + row["owner"])
    if row["dirty"] is None:
        reasons.append("dirty state unknown")
    elif row["dirty"]:
        reasons.append(
            f"{row['dirty']} dirty paths; owner={row['owner'] or 'no-live-writer'}"
        )
    if row["merged"] != "merged":
        reasons.append("HEAD " + row["merged"] + " against origin/main")
    return reasons


def display_path(path):
    # Quoting keeps one output line per registered entry even for hostile filenames.
    return json.dumps(path, ensure_ascii=True)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", nargs="?", choices=("census", "reap"), default="census")
    parser.add_argument("--repo", type=Path, default=DEFAULT_REPO)
    parser.add_argument(
        "--apply", action="store_true", help="remove eligible trees in reap mode"
    )
    parser.add_argument(
        "--quiesced-by",
        help="required for apply: name who guarantees no worker admission (operator claim)",
    )
    args = parser.parse_args(argv)
    if args.apply and args.mode != "reap":
        parser.error("--apply requires reap mode")
    if args.apply and not (args.quiesced_by or "").strip():
        print(
            "REFUSED apply — no quiescence assertion supplied "
            "(pass --quiesced-by naming who guarantees no worker admission)"
        )
        return 2
    # Escape control characters so operator-supplied text cannot forge log lines.
    assertion = (
        " (quiesced-by: " + json.dumps(args.quiesced_by, ensure_ascii=True)[1:-1] + ")"
        if args.apply
        else ""
    )

    try:
        entries = registry(args.repo)
        # Anchor git commands outside any linked tree this invocation may remove.
        args.repo = Path(entries[0]["worktree"])
        processes = process_cwds()
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as exc:
        print(f"FAIL census unavailable: {exc}{assertion}", file=sys.stderr)
        return 2
    rows = []
    removed = 0
    failed = False
    for entry in entries:
        row = inspect(args.repo, entry, processes)
        rows.append(row)
        if args.mode == "census":
            print(
                f"WORKTREE {display_path(row['path'])}\t{row['branch']}\t{row['head']}"
                f"\t{row['merged']}\tdirty={row['dirty'] if row['dirty'] is not None else 'unknown'}"
                f"\towner={row['owner'] or 'no-live-writer'}"
                + ("\terror=" + json.dumps(row["errors"]) if row["errors"] else "")
            )
            failed |= bool(row["errors"])
            continue
        if args.apply:
            # Re-read registry, HEAD, status and pids immediately before removal.
            # Never use --force: git must still refuse dirty or locked worktrees.
            try:
                fresh = registry(args.repo)
                current = next(e for e in fresh if e["worktree"] == row["path"])
                before_remove = process_cwds(include_unresolved=True)
                row = inspect(args.repo, current, before_remove)
                reasons = refusal(row, current, fresh[0]["worktree"])
                if current != entry:
                    reasons.append("registry entry changed since census")
            except (
                OSError,
                RuntimeError,
                subprocess.TimeoutExpired,
                StopIteration,
            ) as exc:
                reasons = ["revalidation unavailable: " + str(exc)]
                row["errors"].extend(reasons)
            rows[-1] = row
        else:
            reasons = refusal(row, entry, entries[0]["worktree"])
        label = display_path(row["path"])
        if reasons:
            print(f"REFUSED {label} — " + "; ".join(reasons) + assertion)
            failed |= bool(row["errors"])
        elif not args.apply:
            print(f"WOULD-REAP {label} — clean, merged, no-live-writer (dry-run)")
        else:
            try:
                checked_git(args.repo, "worktree", "remove", "--", row["path"])
                remaining = registry(args.repo)
                if os.path.exists(row["path"]) or any(
                    e["worktree"] == row["path"] for e in remaining
                ):
                    raise RuntimeError(
                        "removal did not remove both path and registration"
                    )
                removed += 1
                # The assertion is not a lock. Detect an observable breach in the
                # scan -> remove window, including Linux's deleted-cwd marker.
                after = process_cwds(include_unresolved=True)
                owner = live_writer(row["path"], after)
                already_unresolved = {pid for pid, cwd in before_remove if cwd is None}
                unresolved = ",".join(
                    str(pid)
                    for pid, cwd in sorted(after)
                    if cwd is None and pid not in already_unresolved
                )
                detections = []
                if owner:
                    detections.append("POST-REMOVE-WRITER-DETECTED pid=" + owner)
                if unresolved:
                    detections.append("POST-REMOVE-CWD-UNRESOLVED pid=" + unresolved)
                if detections:
                    print(
                        f"REMOVED-WITH-RACE {label} — "
                        + "; ".join(detections)
                        + assertion
                    )
                    failed = True
                    # The admission claim failed: do not remove more trees.
                    break
                print(f"REAPED {label} — clean, merged, no-live-writer{assertion}")
            except (OSError, RuntimeError, subprocess.TimeoutExpired) as exc:
                print(f"REFUSED {label} — removal failed: {exc}{assertion}")
                failed = True
                break
    print(
        f"SUMMARY count={len(rows)}"
        f" merged={sum(r['merged'] == 'merged' for r in rows)}"
        f" unmerged={sum(r['merged'] == 'unmerged' for r in rows)}"
        f" dirty={sum(bool(r['dirty']) for r in rows)}"
        f" live-writer={sum(bool(r['owner']) for r in rows)}"
        f" unknown={sum(bool(r['errors']) for r in rows)}"
        f" removed={removed} mode={args.mode} apply={str(args.apply).lower()}"
    )
    return 2 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
