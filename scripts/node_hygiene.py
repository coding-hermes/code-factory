#!/usr/bin/env python3
"""node_hygiene.py — measure a node's footprint against the disk floor, and reap orphans.

Two jobs, one tool, because they are the same question asked twice: *what is this host
carrying that it should not be?*

footprint
    Sums the components a node actually occupies — the checkout, the Go and Node
    toolchains, the harness home, the node state dir, and the Go module cache when one is
    declared — and compares the total against the disk floor the ladder resolved. The
    number matters because the floor is admission policy (specs/NODE.md "Disk floor"): a
    node whose measured footprint plus working room exceeds free space must be refused
    *before* it fills the host, not discovered at 98 %.

    A component that is simply absent reports 0 MiB and says "absent" in the row; a module
    cache that was never declared reports `not-declared` with that reason rather than a
    silent 0 — an unexplained null on a live row is junk.

reap
    A bunker host accumulates agent homes and keys whose agent no longer exists. Left alone
    they are the "orphan homes/keys" that `bunker-server-install.sh` already warns about, and
    they are exactly the disk a new node needs. This removes an entry only when its id is
    absent from the registry, it is older than the grace window, it is not a symlink, and it
    lives directly under the directory the operator named. Check mode reaps nothing and exits
    non-zero for every orphan left, so it can gate a scale-up.

    The layout is declared, never guessed: `--homes-dir` holds one directory per agent
    (`bunker-<id>`, or `<id>`), `--keys-dir` holds `<id>.key` / `<id>.pub` / `id_<id>`.
    Without `--registry` nothing is reapable — an unmeasured orphan is not an orphan.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
import time
from pathlib import Path

WORKING_ROOM_MIB = 2048
COMPONENTS = (
    ("repo", "repo"),
    ("node_toolchain", "node-toolchain"),
    ("go_toolchain", "go-toolchain"),
    ("harness", ".hermes"),
    ("node_state", ".node"),
)
failures = 0


def ok(row: str, value: str) -> None:
    print(f"  PASS  {row} — {value}")


def bad(row: str, value: str) -> None:
    global failures
    failures += 1
    print(f"  FAIL  {row} — {value}")


def warn(row: str, value: str) -> None:
    print(f"  WARN  {row} — {value}")


def note(value: str) -> None:
    print(f"  ..    {value}")


def dir_bytes(root: Path) -> int:
    """Bytes under root, never following symlinks."""
    if not root.is_dir() or root.is_symlink():
        return 0
    total = 0
    for base, dirs, files in os.walk(root, followlinks=False):
        for name in files:
            path = Path(base) / name
            try:
                if path.is_symlink():
                    continue
                total += path.stat().st_size
            except OSError:
                continue
    return total


def mib(value: int) -> str:
    return f"{value / 1048576:.1f} MiB"


# ---------------------------------------------------------------- footprint
def cmd_footprint(args: argparse.Namespace) -> int:
    root = Path(os.path.expanduser(args.root)).resolve()
    if not root.is_dir():
        bad("footprint", f"{root} is not a directory")
        return 1
    measured: dict[str, dict] = {}
    total = 0
    for row, rel in COMPONENTS:
        path = root / rel
        size = dir_bytes(path)
        measured[row] = {
            "path": str(path),
            "bytes": size,
            "state": "present" if path.exists() else "absent",
        }
        total += size
    if args.modcache:
        cache = Path(os.path.expanduser(args.modcache)).resolve()
        size = dir_bytes(cache)
        measured["modcache"] = {
            "path": str(cache),
            "bytes": size,
            "state": "present" if cache.is_dir() else "absent",
        }
        total += size
    else:
        measured["modcache"] = {"path": "", "bytes": 0, "state": "not-declared"}

    free = shutil.disk_usage(str(root)).free
    room = int(args.working_room_mib)
    required = total + room * 1048576
    parts = ", ".join(
        f"{name} {mib(value['bytes'])}" for name, value in measured.items()
    )
    ok("footprint", f"{mib(total)} measured at {root}: {parts}")

    if free >= required:
        ok(
            "footprint:room",
            f"{mib(required)} required ({mib(total)} + {room} MiB working room), "
            f"{mib(free)} free, headroom {mib(free - required)}",
        )
    else:
        bad(
            "footprint:room",
            f"{mib(required)} required ({mib(total)} + {room} MiB working room) "
            f"> {mib(free)} free — short {mib(required - free)}",
        )

    if args.floor_gib is not None:
        floor_bytes = int(float(args.floor_gib) * 1073741824)
        pct = (total / floor_bytes * 100) if floor_bytes else 0.0
        if total <= floor_bytes:
            ok(
                "footprint:floor",
                f"{mib(total)} of the {args.floor_gib} GiB floor ({pct:.1f} %) "
                f"from {args.floor_source}",
            )
        else:
            bad(
                "footprint:floor",
                f"{mib(total)} exceeds the {args.floor_gib} GiB floor "
                f"({pct:.1f} %) from {args.floor_source}",
            )
    else:
        note(
            "footprint:floor — no --floor-gib given, so the total is measured but not admitted against a floor"
        )

    payload = {
        "root": str(root),
        "components": measured,
        "total_bytes": total,
        "working_room_mib": room,
        "required_bytes": required,
        "free_bytes": free,
        "floor_gib": args.floor_gib,
        "floor_source": args.floor_source,
        "verdict": "PASS" if failures == 0 else "FAIL",
    }
    if args.json:
        print(json.dumps(payload, sort_keys=True))
    if args.write:
        out = Path(os.path.expanduser(args.write))
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(payload, indent=1, sort_keys=True) + "\n")
    return 0 if failures == 0 else 1


# ---------------------------------------------------------------- reap
def entry_id(name: str) -> str:
    stem = name
    for suffix in (".key", ".pub", ".pem"):
        if stem.endswith(suffix):
            stem = stem[: -len(suffix)]
            break
    if stem.startswith("id_"):
        stem = stem[3:]
    if stem.startswith("bunker-"):
        # homes are `bunker-<full-id>`; the id itself may contain hyphens, so only the
        # first two segments are the prefix.
        stem = stem[len("bunker-") :]
    return stem


def load_registry(path: Path | None) -> set[str] | None:
    if path is None:
        return None
    if not path.is_file():
        return None
    ids: set[str] = set()
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeError):
        return None
    for line in lines:
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        # Accept a bare id list or `bunker list` output (`  <id>  <state> …`).
        ids.add(entry_id(line.split()[0]))
    return ids


def is_key_entry(name: str) -> bool:
    return name.startswith("id_") or name.endswith((".key", ".pub", ".pem"))


def scan(dir_path: Path, keys: bool) -> list[Path]:
    if not dir_path.is_dir():
        return []
    found = []
    for entry in sorted(dir_path.iterdir()):
        if entry.is_symlink():
            continue
        if keys and (entry.is_dir() or not is_key_entry(entry.name)):
            continue
        if not keys and not entry.is_dir():
            continue
        found.append(entry)
    return found


def cmd_reap(args: argparse.Namespace) -> int:
    homes = (
        Path(os.path.expanduser(args.homes_dir)).resolve() if args.homes_dir else None
    )
    keys = Path(os.path.expanduser(args.keys_dir)).resolve() if args.keys_dir else None
    if homes is None and keys is None:
        bad(
            "reap",
            "no --homes-dir or --keys-dir named — refusing to guess a server layout",
        )
        return 2
    for path in (homes, keys):
        if path is None:
            continue
        if str(path) in ("/", ""):
            bad("reap_root", f"refusing to reap {path}")
            return 2
    registry = load_registry(
        Path(os.path.expanduser(args.registry)).resolve() if args.registry else None
    )
    if registry is None:
        bad(
            "reap_registry",
            "no readable --registry — an orphan cannot be named without the list of live ids",
        )
        return 2

    now = time.time()
    grace = int(args.min_age_minutes) * 60
    orphans: list[Path] = []
    kept = 0
    young = 0
    for path, is_keys in ((homes, False), (keys, True)):
        if path is None:
            continue
        if not path.is_dir():
            bad("reap_dir", f"{path} is not a directory")
            continue
        for entry in scan(path, is_keys):
            ident = entry_id(entry.name)
            if ident in registry:
                kept += 1
                continue
            try:
                age = now - entry.stat().st_mtime
            except OSError:
                continue
            if age < grace:
                young += 1
                continue
            orphans.append(entry)
    if not homes:
        warn(
            "reap_homes",
            "no --homes-dir given — keys are considered without their homes",
        )
    if not keys:
        warn(
            "reap_keys", "no --keys-dir given — homes are considered without their keys"
        )

    if not orphans:
        ok(
            "orphans",
            f"none — {kept} live entries kept, {young} inside the {args.min_age_minutes} min grace window",
        )
        if args.json:
            print(
                json.dumps(
                    {"orphans": [], "reaped": [], "kept": kept, "young": young},
                    sort_keys=True,
                )
            )
        return 0

    names = ", ".join(str(p) for p in orphans[:8]) + (
        f" (+{len(orphans) - 8} more)" if len(orphans) > 8 else ""
    )
    if args.apply:
        reaped, refused = [], []
        for path in orphans:
            try:
                if path.is_dir() and not path.is_symlink():
                    shutil.rmtree(path)
                else:
                    path.unlink()
                reaped.append(str(path))
            except OSError as exc:
                refused.append(f"{path}: {exc}")
        if refused:
            bad(
                "reap", f"{len(refused)} could not be removed: {'; '.join(refused[:3])}"
            )
        remaining = [p for p in orphans if p.exists()]
        if remaining:
            bad("orphans", f"{len(remaining)} left after reap: {names}")
        else:
            ok("orphans", f"reaped {len(reaped)} orphan(s), {kept} live kept: {names}")
        if args.json:
            print(
                json.dumps(
                    {
                        "orphans": [str(p) for p in orphans],
                        "reaped": reaped,
                        "kept": kept,
                        "young": young,
                    },
                    sort_keys=True,
                )
            )
        return 0 if failures == 0 else 1

    bad(
        "orphans",
        f"{len(orphans)} orphan(s) would be reaped ({kept} live kept, "
        f"{young} inside grace): {names}",
    )
    note(
        "reap — check mode removed nothing; re-run with --apply to remove exactly these"
    )
    if args.json:
        print(
            json.dumps(
                {
                    "orphans": [str(p) for p in orphans],
                    "reaped": [],
                    "kept": kept,
                    "young": young,
                },
                sort_keys=True,
            )
        )
    return 1


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="node footprint and orphan reaper")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser(
        "footprint", help="measure a node's components against the disk floor"
    )
    p.add_argument("--root", default=os.path.expanduser("~"))
    p.add_argument("--floor-gib")
    p.add_argument("--floor-source", default="caller")
    p.add_argument("--modcache")
    p.add_argument("--working-room-mib", default=str(WORKING_ROOM_MIB))
    p.add_argument("--json", action="store_true")
    p.add_argument("--write")
    p.set_defaults(func=cmd_footprint)

    p = sub.add_parser("reap", help="remove orphan agent homes and keys")
    p.add_argument("--homes-dir")
    p.add_argument("--keys-dir")
    p.add_argument("--registry")
    p.add_argument("--min-age-minutes", default="60")
    p.add_argument("--apply", action="store_true")
    p.add_argument("--json", action="store_true")
    p.set_defaults(func=cmd_reap)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
