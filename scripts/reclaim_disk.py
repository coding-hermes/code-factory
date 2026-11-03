#!/usr/bin/env python3
"""Reap only fixed user-space caches and expired node job/clone directories."""

from __future__ import annotations

import argparse
import json
import math
import os
from pathlib import Path
import sys
import time

BUILD_CACHES = (
    ".cache/pip",
    ".cache/uv",
    ".cache/pre-commit",
    ".cache/go-build",
    ".npm/_cacache",
)
AGED_PARENTS = (".node/jobs", ".node/clones")
PROTECTED = ("repo", ".node/node.json", ".node/crier.json", ".node/floor.toml")


def safety_reason(root: Path, path: Path) -> str:
    """Validate real containment and every component before inspecting a target."""
    real = Path(os.path.realpath(path))
    current = path
    while current != root:
        if current.is_symlink():
            return "skipped:symlink"
        current = current.parent
    if real == root or root not in real.parents:
        return "skipped:outside-root"
    for name in PROTECTED:
        protected = root / name
        if real == protected or protected in real.parents:
            return "skipped:protected"
    return ""


def reclaim(root: str, job_ttl_hours: float = 24, dry_run: bool = False) -> dict:
    root_path = Path(os.path.realpath(root))
    if root_path == Path("/") or not root_path.is_dir():
        raise ValueError("root must be a directory other than /")
    if not math.isfinite(job_ttl_hours) or job_ttl_hours < 0:
        raise ValueError("job TTL must be finite and nonnegative")
    entries = []
    now = time.time()

    def record(path, size, action, reason):
        entries.append(
            {
                "name": path.relative_to(root_path).as_posix(),
                "path": str(path),
                "bytes": size,
                "action": action,
                "reason": reason,
            }
        )

    def remove(path):
        reason = safety_reason(root_path, path)
        if reason:
            record(path, 0, "skipped", reason)
            return 0, False
        if path.is_dir():
            size = 0
            complete = True
            for child in sorted(path.iterdir()):
                freed, removed = remove(child)
                size += freed
                complete = complete and removed
            if complete and not dry_run:
                path.rmdir()
            return size, complete
        size = path.stat().st_size
        if not dry_run:
            path.unlink()
        return size, True

    def target(path, aged=False):
        reason = safety_reason(root_path, path)
        if reason:
            record(path, 0, "skipped", reason)
        elif not path.exists():
            record(path, 0, "absent", "absent")
        elif not path.is_dir():
            record(path, 0, "skipped", "not a directory")
        elif aged and (now - path.stat().st_mtime) / 3600 <= job_ttl_hours:
            age = (now - path.stat().st_mtime) / 3600
            record(path, 0, "kept", f"fresh ({age:.1f}h <= TTL {job_ttl_hours:g}h)")
        else:
            size, complete = remove(path)
            record(
                path,
                size,
                "reaped" if complete else "kept",
                "dry-run" if dry_run else ("expired" if aged else "build cache"),
            )

    for name in BUILD_CACHES:
        target(root_path / name)
    for name in AGED_PARENTS:
        parent = root_path / name
        reason = safety_reason(root_path, parent)
        if reason:
            record(parent, 0, "skipped", reason)
        elif parent.is_dir():
            for child in sorted(parent.iterdir()):
                target(child, aged=True)
        else:
            record(
                parent,
                0,
                "absent" if not parent.exists() else "skipped",
                "absent" if not parent.exists() else "not a directory",
            )
    total = sum(entry["bytes"] for entry in entries)
    return {
        "root": str(root_path),
        "reclaimed_bytes": total,
        "reclaimed_mib": round(total / 1048576, 3),
        "job_ttl_hours": job_ttl_hours,
        "entries": entries,
    }


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("targets")
    run = sub.add_parser("run")
    run.add_argument("--root", required=True)
    run.add_argument("--job-ttl-hours", type=float, default=24)
    run.add_argument("--dry-run", action="store_true")
    run.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)
    if args.command == "targets":
        print("\n".join((*BUILD_CACHES, *(p + "/<directory>" for p in AGED_PARENTS))))
        return 0
    try:
        result = reclaim(args.root, args.job_ttl_hours, args.dry_run)
    except (ValueError, OSError) as exc:
        print(f"reclaim: {exc}", file=sys.stderr)
        return 2
    for entry in result["entries"]:
        action = {
            "reaped": "reap",
            "kept": "keep",
            "skipped": "skip",
            "absent": "skip",
        }[entry["action"]]
        reason = entry["reason"]
        if reason == "skipped:symlink":
            reason = "symlink not followed"
        if entry["bytes"] or entry["action"] == "reaped":
            verb = "would free" if args.dry_run else "freed"
            reason = f"{entry['bytes'] / 1000000:.1f} MB {verb} from {entry['path']} ({reason})"
        print(f"  {action}  {entry['name']} — {reason}")
    if not result["reclaimed_bytes"]:
        print("  note reclaim — nothing to reclaim")
    if args.json:
        print(json.dumps(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())
