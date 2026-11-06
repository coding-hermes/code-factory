#!/usr/bin/env python3
"""ownership.py — decide who owns the canonical checkout before a lane blocks on it.

Two failure modes this exists to prevent, both observed on code-factory:

  1. A lane blocks on untracked paths that no live process owns (inherited residue).
     The fix is disposition, never another blocked receipt.
  2. A lane blocks on untracked paths that a live process IS legitimately writing.
     The fix is to stand down, not to block: real work is in flight.

Usage:
  ownership.py status [--workdir DIR]   # JSON: clean | held-by-lock | live-writer | residue
  ownership.py claim --owner X --pid N --paths a,b [--seconds 21600]
  ownership.py release [--owner X]

Exit codes: 0 clean or held-by-live-worker (proceed/stand down), 3 residue (must dispose).
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path

LOCK = ".coding-hermes/panel.lock"
RESIDUE_IGNORES = [".gitreins/rescued-"]


def git(workdir: str, *args: str) -> str:
    return subprocess.run(
        ["git", "-C", workdir, *args], capture_output=True, text=True
    ).stdout


def untracked(workdir: str) -> list[str]:
    out = git(workdir, "status", "--porcelain=v1", "-z")
    paths = []
    for rec in out.split("\x00"):
        if rec.startswith("?? "):
            paths.append(rec[3:])
    return paths


def pid_alive(pid: int) -> bool:
    if pid <= 0:
        return False
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def pid_cmdline(pid: int) -> str:
    try:
        return Path(f"/proc/{pid}/cmdline").read_bytes().replace(b"\x00", b" ").decode(errors="replace")
    except OSError:
        return ""


def read_lock(workdir: str) -> dict | None:
    p = Path(workdir) / LOCK
    if not p.exists():
        return None
    try:
        return json.loads(p.read_text())
    except json.JSONDecodeError:
        return {"owner": "unknown", "pid": 0, "paths": [], "corrupt": True}


def classify(workdir: str) -> dict:
    lock = read_lock(workdir)
    paths = untracked(workdir)
    result = {"workdir": workdir, "untracked": len(paths), "lock": lock, "state": "clean"}

    if not paths:
        result["state"] = "clean"
        return result

    # 1. A live lock holder owns the paths it claimed; anything outside the claim is a
    #    separate question and must not be excused by the lock.
    if lock and pid_alive(int(lock.get("pid") or 0)):
        claimed = tuple(lock.get("paths") or ())
        covered = [p for p in paths if claimed and any(c.rstrip("/") in p for c in claimed)]
        outside = [p for p in paths if p not in covered]
        if covered and not outside:
            result.update(
                state="held-by-live-worker",
                owner=lock.get("owner"),
                pid=lock.get("pid"),
                cmdline=pid_cmdline(int(lock.get("pid") or 0))[:200],
                action="stand down — a live writer owns these paths",
            )
            return result
        if outside:
            result["outside_claim"] = outside[:10]
            result["locked_by"] = lock.get("owner")

    # 2. A stale lock is not an owner.
    if lock:
        result["stale_lock"] = {
            "owner": lock.get("owner"),
            "pid": lock.get("pid"),
            "alive": pid_alive(int(lock.get("pid") or 0)),
        }

    # 3. Inherited residue: nothing alive owns it, so it requires disposition.
    residue = [p for p in paths if any(p.startswith(r) or r in p for r in RESIDUE_IGNORES)]
    if residue and len(residue) == len(paths):
        result.update(
            state="residue",
            residue_paths=len(residue),
            action="dispose: publish anything unique, drop byte-identical copies, ignore the producer",
        )
        return result

    result.update(
        state="unowned-changes",
        sample=paths[:10],
        action="attribute to a live session before touching; if none, commit or revert",
    )
    return result


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["status", "claim", "release"])
    ap.add_argument("--workdir", default="/home/kara/code-factory")
    ap.add_argument("--owner", default="panel_loop")
    ap.add_argument("--pid", type=int, default=0)
    ap.add_argument("--paths", default="")
    ap.add_argument("--seconds", type=int, default=21600)
    a = ap.parse_args()

    if a.cmd == "status":
        r = classify(a.workdir)
        print(json.dumps(r, indent=2))
        return 3 if r["state"] in ("residue", "unowned-changes") else 0

    lock_path = Path(a.workdir) / LOCK
    if a.cmd == "claim":
        lock_path.parent.mkdir(parents=True, exist_ok=True)
        now = time.time()
        lock_path.write_text(json.dumps({
            "owner": a.owner,
            "pid": a.pid,
            "started": time.strftime("%Y-%m-%dT%H:%M:%S%z", time.localtime(now)),
            "expires": time.strftime("%Y-%m-%dT%H:%M:%S%z", time.localtime(now + a.seconds)),
            "workdir": a.workdir,
            "paths": [p.strip() for p in a.paths.split(",") if p.strip()],
            "reason": "handbook writer/judge loop in flight",
        }, indent=2) + "\n")
        print(f"claimed {a.workdir} for {a.owner} pid={a.pid}")
        return 0

    if lock_path.exists():
        lock_path.unlink()
        print(f"released {lock_path}")
    else:
        print("no lock to release")
    return 0


if __name__ == "__main__":
    sys.exit(main())
