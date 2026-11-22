#!/usr/bin/env python3
"""Check that the GitReins hook budget strictly exceeds its test budget."""

import argparse
import re
from pathlib import Path


def read_budgets(path: Path) -> dict[str, int]:
    """Read direct guards children from the supported YAML-ish config subset."""
    text = path.read_text(encoding="utf-8")
    budgets: dict[str, int] = {}
    in_guards = False
    seen_guards = False
    for line in text.splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if not line[0].isspace():
            if re.fullmatch(r"guards:\s*(?:#.*)?", line):
                if seen_guards:
                    raise ValueError("duplicate guards section")
                seen_guards = True
                in_guards = True
            else:
                in_guards = False
            continue
        if not in_guards:
            continue
        match = re.match(r"^( +)(test_timeout|hook_timeout)\s*:(.*)$", line)
        if not match:
            continue
        indent, key, value = match.groups()
        if len(indent) != 2:
            raise ValueError(f"guards.{key} must be a direct two-space-indented key")
        if key in budgets:
            raise ValueError(f"duplicate guards.{key}")
        value = value.split("#", 1)[0].strip()
        if not re.fullmatch(r"[0-9]+", value):
            raise ValueError(f"unparsable guards.{key}: expected an integer")
        budgets[key] = int(value)
    for key in ("test_timeout", "hook_timeout"):
        if key not in budgets:
            raise ValueError(f"missing guards.{key}")
    return budgets


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=Path(".gitreins/config.yaml"))
    parser.add_argument("--quiet", action="store_true", help="suppress the PASS line")
    args = parser.parse_args()
    try:
        budgets = read_budgets(args.config)
    except (OSError, UnicodeError, ValueError) as exc:
        print(f"ERROR guard budget: {exc}")
        return 2
    hook = budgets["hook_timeout"]
    test = budgets["test_timeout"]
    if hook <= test:
        print(
            f"FAIL guard budget: hook_timeout={hook}s <= test_timeout={test}s — "
            "hook_timeout must be strictly greater (a hook cut off mid-suite reports "
            "a fail-open PASS; CF-217/CF-522)"
        )
        return 1
    if not args.quiet:
        print(f"PASS guard budget: hook_timeout={hook}s > test_timeout={test}s")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
