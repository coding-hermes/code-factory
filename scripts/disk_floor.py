#!/usr/bin/env python3
"""disk_floor.py — resolve the node disk floor from an explicit, ordered chain.

A node refuses admission below its floor and names the number (CF-007). That
number is operator policy, not a constant: roles differ in footprint, hardware
differs in capacity, and a fixed 5 GiB is wrong on both a small worker and a
full builder. This resolver makes the floor configurable while keeping the
refusal falsifiable and the precedence unambiguous.

Precedence, highest first:

  1. --cli VALUE            (project-node.sh --disk-floor VALUE)
  2. NODE_DISK_FLOOR        (environment)
  3. config file [disk] role values, then [disk] default
  4. built-in role default

Accepted values: "<int>" or "<int>G" / "<int>GiB" / "<decimal>G" in GiB.
Anything else fails closed (exit 2) rather than silently falling back to a
default — a typo must not lower a floor.

Usage:
  disk_floor.py resolve [--role worker|builder|full] [--cli V] [--env V]
                        [--config PATH] [--explain]
  disk_floor.py roles
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from typing import Optional

ROLE_DEFAULTS = {"worker": 5, "builder": 10, "full": 20}
DEFAULT_ROLE = "worker"
MIN_GIB = 1
MAX_GIB = 4096
_VALUE_RE = re.compile(r"^(?P<num>\d+(?:\.\d+)?)\s*(?:G|GiB|g|gib)?$")


class FloorError(ValueError):
    pass


def parse_value(raw: object, origin: str = "value") -> int:
    """Parse a floor value in GiB. Raises FloorError for anything ambiguous."""
    if raw is None:
        raise FloorError(f"{origin}: no value")
    if isinstance(raw, bool):
        raise FloorError(f"{origin}: booleans are not sizes")
    if isinstance(raw, int):
        gib = raw
    elif isinstance(raw, float):
        gib = int(raw)
    else:
        text = str(raw).strip()
        if not text:
            raise FloorError(f"{origin}: empty value")
        m = _VALUE_RE.match(text)
        if not m:
            raise FloorError(
                f"{origin}: {text!r} is not a size; use GiB as an integer or "
                "'7G' / '7GiB' / '1.5G'"
            )
        gib = int(float(m.group("num")))
    if gib < MIN_GIB:
        raise FloorError(f"{origin}: {gib} GiB is below the minimum of {MIN_GIB} GiB")
    if gib > MAX_GIB:
        raise FloorError(f"{origin}: {gib} GiB exceeds the maximum of {MAX_GIB} GiB")
    return gib


def load_config(path: Optional[str]) -> dict:
    """Read [disk] from a TOML config file. Missing file = no overrides."""
    if not path:
        return {}
    if not os.path.exists(path):
        return {}
    try:
        import tomllib  # Python 3.11+
    except ModuleNotFoundError:  # pragma: no cover - 3.9/3.10 hosts
        return _load_config_minimal(path)
    with open(path, "rb") as fh:
        data = tomllib.load(fh)
    disk = data.get("disk") or {}
    if not isinstance(disk, dict):
        raise FloorError(f"{path}: [disk] must be a table")
    return disk


def _load_config_minimal(path: str) -> dict:
    """Tiny [disk] reader for interpreters without tomllib."""
    out: dict = {}
    section = None
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.split("#", 1)[0].strip()
            if not line:
                continue
            if line.startswith("[") and line.endswith("]"):
                section = line[1:-1].strip()
                continue
            if section == "disk" and "=" in line:
                k, _, v = line.partition("=")
                out[k.strip()] = v.strip().strip('"').strip("'")
    return out


def default_config_path() -> str:
    return os.path.join(os.path.expanduser("~"), ".node", "floor.toml")


def resolve(
    role: str = DEFAULT_ROLE,
    cli: Optional[str] = None,
    env: Optional[str] = None,
    config_path: Optional[str] = None,
) -> tuple[int, str]:
    """Return (gib, source) applying the documented precedence."""
    if role not in ROLE_DEFAULTS:
        raise FloorError(
            f"unknown role {role!r}; expected one of {', '.join(sorted(ROLE_DEFAULTS))}"
        )
    if cli is not None:
        return parse_value(cli, "--disk-floor"), "cli"
    if env is not None:
        return parse_value(env, "NODE_DISK_FLOOR"), "env"
    disk = load_config(config_path or default_config_path())
    key = f"{role}_gib"
    if key in disk:
        return parse_value(disk[key], f"{config_path or default_config_path()} [disk] {key}"), "config-role"
    if "default" in disk or "default_gib" in disk:
        raw = disk.get("default", disk.get("default_gib"))
        return parse_value(raw, f"{config_path or default_config_path()} [disk] default"), "config-default"
    return ROLE_DEFAULTS[role], "role-default"


def main(argv: Optional[list] = None) -> int:
    ap = argparse.ArgumentParser(description="resolve the node disk floor")
    sub = ap.add_subparsers(dest="cmd", required=True)

    r = sub.add_parser("resolve")
    r.add_argument("--role", default=os.environ.get("NODE_ROLE", DEFAULT_ROLE))
    r.add_argument("--cli", default=None)
    r.add_argument("--env", default=os.environ.get("NODE_DISK_FLOOR"))
    r.add_argument("--config", default=os.environ.get("NODE_DISK_FLOOR_CONFIG"))
    r.add_argument("--explain", action="store_true")

    sub.add_parser("roles")

    a = ap.parse_args(argv)
    try:
        if a.cmd == "roles":
            for name, gib in sorted(ROLE_DEFAULTS.items()):
                print(f"{name}\t{gib}")
            return 0
        gib, source = resolve(a.role, a.cli, a.env, a.config)
        if a.explain:
            print(json.dumps({"role": a.role, "floor_gib": gib, "source": source}))
        else:
            print(gib)
        return 0
    except FloorError as exc:
        print(f"FAIL disk-floor: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
