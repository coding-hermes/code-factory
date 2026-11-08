#!/usr/bin/env python3
"""Reap only fixed user-space caches and expired node job/clone directories."""
# ch:trace row=CF-290 spec=docs/handbook/chapters/M8-safety.md#s1 wave=none:serial test=tests/test_reclaim.py doc=docs/handbook/chapters/M8-safety.md evidence=none:commit-body witness=cmd:probe exit-124-pre-fix verdict=none:judged-after-merge commit=none:self-referential-hash memory=none:foreman-writes

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
DEFAULT_TTL_HOURS = 24


def _lexically_inside(root: Path, path: Path) -> bool:
    """True when `path` is `root` or names a descendant of it, without touching disk."""
    try:
        path.relative_to(root)
    except ValueError:
        return False
    return True


def safety_reason(root: Path, path: Path) -> str:
    """Validate real containment and every component before inspecting a target.

    Bounded by construction (CF-290). The pre-fix walk ran `while current != root` with
    no other termination condition, so any path outside the root never reached the
    containment verdict: at `/`, `Path("/").parent == Path("/")` and the loop spins
    forever, which made `skipped:outside-root` unreachable dead code and hung every
    caller that handed it a non-contained path. Here the component walk is bounded by
    the path's own depth below the root and cannot pass above it, so every path —
    inside, outside, symlinked or absent — returns.
    """
    real = Path(os.path.realpath(path))
    if _lexically_inside(root, path):
        # Symlink first, and only between root and target (root itself is not walked,
        # as before): a symlinked component is refused before realpath can present its
        # target as the thing being judged.
        current = path
        for _ in range(len(path.relative_to(root).parts)):
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


def newest_mtime(path: Path) -> float:
    """Newest mtime anywhere in the subtree, not the directory's own mtime.

    A directory's `st_mtime` moves only when that directory's own entries change, so a
    pip or go-build cache being written deep inside keeps an arbitrarily old directory
    stamp while its newest blob is seconds old. Judging a cache by
    `path.stat().st_mtime` would reap caches that are in active use, which is exactly
    what a provisioner must not do before refusing admission.
    """
    newest = path.lstat().st_mtime
    for dirpath, dirnames, filenames in os.walk(path, followlinks=False):
        for name in (*dirnames, *filenames):
            try:
                stamp = os.lstat(os.path.join(dirpath, name)).st_mtime
            except OSError:
                continue
            if stamp > newest:
                newest = stamp
    return newest


def reclaim(
    root: str,
    job_ttl_hours: float = DEFAULT_TTL_HOURS,
    dry_run: bool = False,
    cache_ttl_hours: float = DEFAULT_TTL_HOURS,
) -> dict:
    root_path = Path(os.path.realpath(root))
    if root_path == Path("/") or not root_path.is_dir():
        raise ValueError("root must be a directory other than /")
    for label, ttl in (("job", job_ttl_hours), ("cache", cache_ttl_hours)):
        if not math.isfinite(ttl) or ttl < 0:
            raise ValueError(f"{label} TTL must be finite and nonnegative")
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

    def target(path, ttl_hours, class_reason):
        reason = safety_reason(root_path, path)
        if reason:
            record(path, 0, "skipped", reason)
        elif not path.exists():
            record(path, 0, "absent", "absent")
        elif not path.is_dir():
            record(path, 0, "skipped", "not a directory")
        else:
            age = (now - newest_mtime(path)) / 3600
            if age <= ttl_hours:
                record(path, 0, "kept", f"fresh ({age:.1f}h <= TTL {ttl_hours:g}h)")
            else:
                size, complete = remove(path)
                expired = f"{class_reason} expired ({age:.1f}h > TTL {ttl_hours:g}h)"
                if complete:
                    record(path, size, "reaped", "dry-run" if dry_run else expired)
                else:
                    record(path, size, "kept", f"children refused — {expired}")

    for name in BUILD_CACHES:
        target(root_path / name, cache_ttl_hours, "build cache")
    for name in AGED_PARENTS:
        parent = root_path / name
        reason = safety_reason(root_path, parent)
        if reason:
            record(parent, 0, "skipped", reason)
        elif parent.is_dir():
            for child in sorted(parent.iterdir()):
                target(child, job_ttl_hours, "job dir")
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
        "cache_ttl_hours": cache_ttl_hours,
        "entries": entries,
    }


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("targets")
    run = sub.add_parser("run")
    run.add_argument("--root", required=True)
    run.add_argument("--job-ttl-hours", type=float, default=DEFAULT_TTL_HOURS)
    run.add_argument("--cache-ttl-hours", type=float, default=DEFAULT_TTL_HOURS)
    run.add_argument("--dry-run", action="store_true")
    run.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)
    if args.command == "targets":
        print("\n".join((*BUILD_CACHES, *(p + "/<directory>" for p in AGED_PARENTS))))
        return 0
    try:
        result = reclaim(
            args.root, args.job_ttl_hours, args.dry_run, args.cache_ttl_hours
        )
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
