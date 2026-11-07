#!/usr/bin/env python3
"""check_scan_scope.py — a secret-scan claim in a posture doc must name its scope.

Rule: any line in a scanned posture doc that contains the literal string
``gitleaks`` must also contain the literal string ``--log-opts`` on that same
line. A clean scan without a recorded scope is not a posture claim: with no
``--log-opts`` the revision range gitleaks scans is undefined at the claim
site, so the same repository can read green on ``main`` while other published
refs carry findings (CF-163 AC3 — this repo also publishes an unrelated
``master`` lineage with 547 findings on 64 commits, none an ancestor of
``main``). A reader must be able to tell which surface a green covered.

Scanned files, relative to the repo root (default: the directory containing
this script's ``scripts/`` parent): ``docs/audits/code-factory-releng-*.md``
and ``docs/SECURITY-TRIAGE.md``.

Every outcome is named, and no outcome is a green the gate did not measure
(CF-307):

* ``docs/audits`` must exist and be a READABLE directory. Missing, not a
  directory, or permission-denied is a ``FAIL`` that names the exact path and
  reason (exit 2) — never "no posture docs found";
* a fixed file that is a dangling symlink, or exists but cannot be read, is a
  ``FAIL`` (exit 2). Plain absence is not fatal — the file is optional — but
  the absence is named in the OK line so a reader can tell "not present" from
  "not read";
* a readable surface holding no matching document says so — "audit surface
  read, 0 posture docs" (exit 0) — and shares no wording with the failure.

Usage:
  python3 scripts/check_scan_scope.py [<repo-root>]

Exit codes: 0 clean (or the surface was read and is empty), 1 any violation,
2 when a path the gate must read is missing or unreadable.
"""

from __future__ import annotations

import argparse
import fnmatch
import os
import stat
import sys
from pathlib import Path

AUDIT_DIR = "docs/audits"
AUDIT_PATTERN = "code-factory-releng-*.md"
FIXED_FILES = ("docs/SECURITY-TRIAGE.md",)
CLAIM = "gitleaks"
SCOPE_FLAG = "--log-opts"


class UnreadablePath(Exception):
    """A path the gate was supposed to read and could not."""


def _reason(exc: OSError) -> str:
    return exc.strerror or type(exc).__name__


def audit_docs(root: Path) -> list[tuple[Path, str]]:
    """Return the matching audit docs, or raise if the surface cannot be read."""
    directory = root / AUDIT_DIR
    if not os.path.lexists(directory):
        raise UnreadablePath(f"{directory} missing — there is no scan surface to read")
    try:
        entry_stat = os.stat(directory)
    except OSError as exc:
        raise UnreadablePath(f"{directory} unreadable ({_reason(exc)})") from exc
    if not stat.S_ISDIR(entry_stat.st_mode):
        raise UnreadablePath(f"{directory} is not a directory")
    try:
        with os.scandir(directory) as listing:
            names = sorted(
                entry.name
                for entry in listing
                if fnmatch.fnmatchcase(entry.name, AUDIT_PATTERN)
            )
    except OSError as exc:
        # A directory the gate cannot list is not an empty directory: the glob
        # that used to back this check returned [] here and reported green.
        raise UnreadablePath(f"{directory} unreadable ({_reason(exc)})") from exc
    docs: list[tuple[Path, str]] = []
    for name in names:
        path = directory / name
        relpath = f"{AUDIT_DIR}/{name}"
        if path.is_symlink() and not path.exists():
            target = os.readlink(path)
            raise UnreadablePath(f"{relpath} is a dangling symlink (-> {target})")
        if not path.is_file():
            raise UnreadablePath(f"{relpath} is not a regular file")
        docs.append((path, relpath))
    return docs


def fixed_docs(root: Path) -> tuple[list[tuple[Path, str]], list[str]]:
    """Return (fixed files present, root-relative paths that are absent)."""
    present: list[tuple[Path, str]] = []
    absent: list[str] = []
    for rel in FIXED_FILES:
        path = root / rel
        if not os.path.lexists(path):
            absent.append(rel)
            continue
        if path.is_symlink() and not path.exists():
            target = os.readlink(path)
            raise UnreadablePath(f"{rel} is a dangling symlink (-> {target})")
        if not path.is_file():
            raise UnreadablePath(f"{rel} is not a regular file")
        present.append((path, rel))
    return present, absent


def scan(root: Path) -> tuple[list[tuple[str, int]], int, int, list[str]]:
    """Return (violations, gitleaks claim count, docs read, optional docs absent).

    Violations are (relpath, lineno) pairs, sorted by path then line number.
    The surface is resolved first, so an unreadable tree raises instead of
    returning an empty, green-looking scan.
    """
    violations: list[tuple[str, int]] = []
    claims = 0
    paths = audit_docs(root)
    optional, absent = fixed_docs(root)
    paths.extend(optional)
    for path, relpath in paths:
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError as exc:
            raise UnreadablePath(f"{relpath} unreadable ({_reason(exc)})") from exc
        for lineno, line in enumerate(text.splitlines(), 1):
            if CLAIM in line:
                claims += 1
                if SCOPE_FLAG not in line:
                    violations.append((relpath, lineno))
    violations.sort()
    return violations, claims, len(paths), absent


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Posture-doc gate: every line naming gitleaks must also name"
            " --log-opts on the same line — a clean scan without a recorded"
            " scope is not a posture claim (CF-163 AC3)."
        )
    )
    parser.add_argument(
        "root",
        nargs="?",
        default=None,
        help="repo root to scan (default: the directory containing scripts/)",
    )
    args = parser.parse_args(argv)
    if args.root:
        root = Path(args.root).resolve()
    else:
        root = Path(__file__).resolve().parent.parent
    if not root.is_dir():
        print(f"  FAIL  audit-scope: {root} is not a readable directory")
        print("RESULT: FAIL (unreadable path)")
        return 2
    try:
        violations, claims, docs_read, absent = scan(root)
    except UnreadablePath as exc:
        print(f"  FAIL  audit-scope: {exc}")
        print("RESULT: FAIL (unreadable path)")
        return 2
    for relpath, lineno in violations:
        print(
            f"  FAIL  audit-scope: {relpath}:{lineno} gitleaks claim names no {SCOPE_FLAG}"
        )
    if violations:
        print(f"RESULT: FAIL ({len(violations)} violation(s))")
        return 1
    missing = ""
    if absent:
        missing = f" ({', '.join(absent)} not present — not read)"
    if docs_read == 0:
        print(f"  OK  audit-scope: audit surface read, 0 posture docs{missing}")
    elif claims == 0:
        print(
            f"  OK  audit-scope: {docs_read} posture doc(s) read,"
            f" 0 gitleaks claim(s){missing}"
        )
    else:
        print(
            f"  OK  audit-scope: {claims} gitleaks claim(s) name their"
            f" {SCOPE_FLAG}{missing}"
        )
    print("RESULT: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
