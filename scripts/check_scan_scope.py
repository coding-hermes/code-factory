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
and ``docs/SECURITY-TRIAGE.md``. A missing file is skipped; when nothing
matches there is nothing to police and the run is OK.

Usage:
  python3 scripts/check_scan_scope.py [<repo-root>]

Exit codes: 0 clean, 1 any violation, 2 when a scanned path is unreadable
(e.g. the root does not exist or is not a directory).
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

AUDIT_GLOB = "docs/audits/code-factory-releng-*.md"
FIXED_FILES = ("docs/SECURITY-TRIAGE.md",)
CLAIM = "gitleaks"
SCOPE_FLAG = "--log-opts"


class UnreadablePath(Exception):
    """A scanned path exists but cannot be read."""


def scanned_files(root: Path) -> list[Path]:
    paths = sorted(root.glob(AUDIT_GLOB))
    for rel in FIXED_FILES:
        candidate = root / rel
        if candidate.exists():
            paths.append(candidate)
    return paths


def scan(root: Path) -> tuple[list[tuple[str, int]], int, bool]:
    """Return (violations, gitleaks claim count, any file scanned).

    Violations are (relpath, lineno) pairs, sorted by path then line number.
    """
    violations: list[tuple[str, int]] = []
    claims = 0
    paths = scanned_files(root)
    for path in paths:
        relpath = path.relative_to(root).as_posix()
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError as exc:
            raise UnreadablePath(f"{relpath} unreadable ({exc})") from exc
        for lineno, line in enumerate(text.splitlines(), 1):
            if CLAIM in line:
                claims += 1
                if SCOPE_FLAG not in line:
                    violations.append((relpath, lineno))
    violations.sort()
    return violations, claims, bool(paths)


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
        violations, claims, scanned_any = scan(root)
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
    if not scanned_any:
        print("  OK  audit-scope: no posture docs found")
    else:
        print(f"  OK  audit-scope: {claims} gitleaks claim(s) name their {SCOPE_FLAG}")
    print("RESULT: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
