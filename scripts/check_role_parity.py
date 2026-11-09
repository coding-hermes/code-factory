#!/usr/bin/env python3
"""Check parity between the resolver role table and the shell fallback table."""

from __future__ import annotations

import argparse
import importlib.util
import re
import sys
from pathlib import Path
from typing import Any


_ROLE_LINE = re.compile(
    r"^\s*([A-Za-z_][A-Za-z0-9_-]*)\)\s+FLOOR_BUILTIN=(\d+)\s*;;\s*$"
)
_CASE_MARKER = 'case "$ROLE" in'


def _fail(message: str) -> int:
    print(f"FAIL {message}")
    return 1


def _resolver_roles(path: Path) -> dict[str, int] | None:
    try:
        spec = importlib.util.spec_from_file_location("cf299_disk_floor", path)
        if spec is None or spec.loader is None:
            raise RuntimeError("could not load module")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        roles: Any = getattr(module, "ROLE_DEFAULTS")
    except (
        AttributeError,
        ImportError,
        OSError,
        RuntimeError,
        SyntaxError,
        ValueError,
    ):
        return None
    if not isinstance(roles, dict) or not roles:
        return None
    if any(
        not isinstance(role, str) or not isinstance(value, int)
        for role, value in roles.items()
    ):
        return None
    return roles


def _ladder_roles(path: Path) -> dict[str, int] | None:
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
        start = next(
            index for index, line in enumerate(lines) if line.strip() == _CASE_MARKER
        )
        end = next(
            index
            for index in range(start + 1, len(lines))
            if lines[index].strip() == "esac"
        )
    except (OSError, StopIteration):
        return None
    roles: dict[str, int] = {}
    for line in lines[start + 1 : end]:
        match = _ROLE_LINE.match(line)
        if match:
            roles[match.group(1)] = int(match.group(2))
    if not roles:
        print(f"FAIL ladder table: {path} (no FLOOR_BUILTIN role pairs)")
        return None
    return roles


def _format_roles(roles: dict[str, int]) -> str:
    return ", ".join(f"{role}={roles[role]}" for role in sorted(roles))


def check(root: Path) -> int:
    resolver_path = root / "scripts" / "disk_floor.py"
    ladder_path = root / "scripts" / "project-node.sh"
    resolver = _resolver_roles(resolver_path)
    if resolver is None:
        return _fail(f"resolver table unavailable: {resolver_path}")
    try:
        ladder_source = ladder_path.read_text(encoding="utf-8")
    except OSError:
        ladder_source = ""
    if _CASE_MARKER not in ladder_source:
        return _fail(
            "role-set drift: resolver roles present; ladder case marker missing"
        )
    ladder = _ladder_roles(ladder_path)
    if ladder is None:
        return _fail(f"ladder table unavailable: {ladder_path}")

    if set(resolver) != set(ladder):
        resolver_roles = _format_roles(resolver)
        ladder_roles = _format_roles(ladder)
        return _fail(
            f"role-set drift: resolver={resolver_roles}; ladder={ladder_roles}"
        )

    all_roles = sorted(resolver)
    divergences = 0
    for role in all_roles:
        resolver_value = resolver.get(role, "<missing>")
        ladder_value = ladder.get(role, "<missing>")
        if resolver_value != ladder_value:
            print(f"FAIL role {role}: resolver={resolver_value}; ladder={ladder_value}")
            divergences += 1
    if divergences:
        return 1

    print(
        "PASS role parity: "
        f"{resolver_path} ROLE_DEFAULTS and {ladder_path} {_CASE_MARKER}; "
        f"{_format_roles(resolver)}"
    )
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="check disk-floor role table parity")
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="repository root (default: the repository containing this script)",
    )
    args = parser.parse_args(argv)
    return check(args.root.resolve())


if __name__ == "__main__":
    sys.exit(main())
