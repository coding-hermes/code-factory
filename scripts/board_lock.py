#!/usr/bin/env python3
"""board_lock.py — classify a board lock file; never mutate it.

`.coding-hermes/board/.lock` has no shipped consumer, is ignored by `.gitignore`
and has no holder, yet every lane treats its presence as an ownership barrier
(CF-119). A file nobody opens is not a held lock: it is residue that must not
stop board work, and must not be deleted either. This adjudicator makes the
classification re-runnable instead of hand-derived by every tick.

A present lock is HELD only when a live holder is proven:

  1. a `/proc/<pid>/fd` entry (excluding this process) that resolves to the
     path, or
  2. a non-blocking exclusive `flock` probe that fails with `EWOULDBLOCK`.

After that, the flock probe must succeed to prove a clean negative. Otherwise a
present file is RESIDUE, and the verdict names the two counts the hand
derivation used to require: shipped consumers matching `flock|fcntl` under
`scripts/boardctl*`, and board commits whose commit time is after the lock's
mtime. An absent path is ABSENT.

A probe that cannot run (the path cannot be opened, or flock fails with a
non-contention errno) proves nothing and is never folded into RESIDUE: it is
ERROR, exit 3, and the lock state is UNKNOWN. A partial `/proc` fd scan — a
process that raced exit or is not ours to inspect — stays a clean observation
and does not by itself produce ERROR.

The classifier never creates, truncates or deletes the lock path.

Usage:
  board_lock.py [PATH]        # default: <repo root>/.coding-hermes/board/.lock

Output: exactly one verdict line, and the exit code names the outcome.

  ABSENT                                                  exit 0
  HELD holder=pid-1234 | HELD holder=flock-eagain          exit 0
  RESIDUE consumers=<n> commits_after_mtime=<n|unknown>    exit 0
  ERROR lock=<path> probe=<detail> is not a clean negative — the lock state is UNKNOWN
                                                          exit 3
"""

from __future__ import annotations

import argparse
import errno
import fcntl
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import NamedTuple

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_LOCK = REPO_ROOT / ".coding-hermes" / "board" / ".lock"
CONSUMER_RE = re.compile(rb"flock|fcntl")


def fd_holders(lock: Path) -> list[int]:
    """Pids (excluding our own) with an open fd that resolves to ``lock``."""
    real = os.path.realpath(lock)
    mine = os.getpid()
    holders: set[int] = set()
    for entry in Path("/proc").iterdir():
        if not entry.name.isdigit() or int(entry.name) == mine:
            continue
        fds = entry / "fd"
        try:
            names = os.listdir(fds)
        except OSError:
            continue  # the process raced exit or is not ours to inspect
        for name in names:
            try:
                target = os.readlink(fds / name)
            except OSError:
                continue
            if target == str(lock) or os.path.realpath(target) == real:
                holders.add(int(entry.name))
                break
    return sorted(holders)


def flock_probe(lock: Path) -> tuple[str, str]:
    """Non-blocking exclusive ``flock`` probe.

    Returns ``(verdict, detail)`` where verdict is ``held`` (another process
    holds the lock), ``free`` (we acquired and released it) or ``error`` (the
    probe could not run and proves nothing).
    """
    try:
        fd = os.open(lock, os.O_RDONLY)
    except OSError:
        return "error", "open-failed"
    try:
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError as exc:
            if exc.errno in (errno.EWOULDBLOCK, errno.EAGAIN):
                return "held", "flock-eagain"
            return "error", f"errno-{exc.errno}"
        fcntl.flock(fd, fcntl.LOCK_UN)
        return "free", "uncontended"
    finally:
        os.close(fd)


def consumer_count() -> int:
    """Lines matching ``flock|fcntl`` under ``scripts/boardctl*`` (grep -r)."""
    count = 0
    for path in sorted((REPO_ROOT / "scripts").glob("boardctl*")):
        if path.is_file():
            count += _matching_lines(path)
        elif path.is_dir():
            for child in sorted(path.rglob("*")):
                if child.is_file():
                    count += _matching_lines(child)
    return count


def _matching_lines(path: Path) -> int:
    try:
        with path.open("rb") as handle:
            return sum(1 for line in handle if CONSUMER_RE.search(line))
    except OSError:
        return 0


def commits_after_mtime(lock: Path) -> str:
    """Board commits whose commit time is after the lock's mtime.

    Counts ``git log --since=@<mtime> -- .`` rooted at the lock's directory, the
    derivation CF-119 measured by hand. ``unknown`` when Git cannot answer (no
    repository, no git binary); a number is never invented.
    """
    try:
        mtime = int(os.stat(lock).st_mtime)
        result = subprocess.run(
            [
                "git",
                "-C",
                str(lock.parent),
                "log",
                f"--since=@{mtime}",
                "--format=%H",
                "--",
                ".",
            ],
            capture_output=True,
            timeout=30,
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return "unknown"
    if result.returncode != 0:
        return "unknown"
    return str(len(result.stdout.splitlines()))


class Verdict(NamedTuple):
    """One verdict line and the exit code that carries its outcome."""

    line: str
    exit_code: int


def adjudicate(lock: Path) -> Verdict:
    if not lock.exists():
        return Verdict("ABSENT", 0)
    holders = fd_holders(lock)
    if holders:
        return Verdict(f"HELD holder=pid-{holders[0]}", 0)
    verdict, detail = flock_probe(lock)
    if verdict == "held":
        return Verdict(f"HELD holder={detail}", 0)
    if verdict == "error":
        return Verdict(
            f"ERROR lock={lock} probe={detail} is not a clean negative — "
            "the lock state is UNKNOWN",
            3,
        )
    return Verdict(
        f"RESIDUE consumers={consumer_count()} "
        f"commits_after_mtime={commits_after_mtime(lock)}",
        0,
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Classify a board lock file; never mutate it."
    )
    parser.add_argument(
        "path",
        nargs="?",
        default=str(DEFAULT_LOCK),
        help="lock path (default: %(default)s)",
    )
    args = parser.parse_args()
    result = adjudicate(Path(args.path).expanduser())
    print(result.line)
    return result.exit_code


if __name__ == "__main__":
    sys.exit(main())
