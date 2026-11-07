#!/usr/bin/env python3
"""reap_orphan_writers.py — kill writer sessions whose parent round is gone.

When panel_loop.py dies (crash, kill, provider outage) it leaves its `timeout ...
hermes chat -q ...` children alive. The supervisor then launches a new round, and
the orphans keep editing chapters with a prompt from the dead round — two writers
per file, no reconcile, and the judges grade a tree nobody owns.

An orphan is identified mechanically, not by name alone:
  cmdline contains the writer prompt signature
  AND its parent pid is 1 (reparented because the round that spawned it died)

Print the pids it killed so the supervisor log records the reaping.
"""
from __future__ import annotations

import os
import pathlib
import signal
import sys

SIGNATURE = "You are the writer for the code-factory"


def ppid_of(pid: str) -> int | None:
    try:
        raw = pathlib.Path(f"/proc/{pid}/stat").read_text()
    except OSError:
        return None
    # comm can contain spaces and parens; everything after the last ')' is stable
    tail = raw[raw.rfind(")") + 2:].split()
    try:
        return int(tail[1])
    except (IndexError, ValueError):
        return None


def main() -> int:
    killed = []
    for entry in pathlib.Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        try:
            cmd = (entry / "cmdline").read_bytes().replace(b"\x00", b" ").decode(errors="replace")
        except OSError:
            continue
        if SIGNATURE not in cmd:
            continue
        if ppid_of(entry.name) != 1:
            continue
        try:
            os.kill(int(entry.name), signal.SIGTERM)
            killed.append(entry.name)
        except OSError:
            pass
    print("reaped orphan writers: " + (", ".join(killed) if killed else "none"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
