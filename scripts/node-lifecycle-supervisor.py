#!/usr/bin/env python3
"""Bounded node lifecycle supervisor and destroy/create replay helper (CF-008).

This module deliberately owns only repository-local lifecycle mechanics.  A bunker client or
scheduler may wrap it, but live bunker state is not inferred here: every command and result is
recorded in the supplied state file.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import signal
import subprocess
import time
from typing import Callable, Iterable


POLL_INTERVAL = 0.1
KILL_GRACE_SECONDS = 1.0


def atomic_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def read_deadline(path: Path | None) -> float | None:
    if path is None:
        return None
    try:
        value = float(path.read_text(encoding="utf-8").strip())
    except (OSError, ValueError) as exc:
        raise ValueError(f"deadline file {path} is not a unix timestamp: {exc}") from exc
    return value


class Lease:
    """A monotonic, injectable TTL lease; renewal is allowed only while active."""

    def __init__(
        self,
        ttl_seconds: float,
        renew_seconds: float | None = None,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        if ttl_seconds <= 0:
            raise ValueError("ttl must be greater than zero")
        self.ttl_seconds = float(ttl_seconds)
        self.renew_seconds = float(renew_seconds or ttl_seconds / 2)
        if self.renew_seconds <= 0 or self.renew_seconds > self.ttl_seconds:
            raise ValueError("renew interval must be greater than zero and no greater than ttl")
        self.clock = clock
        self.deadline = 0.0
        self.next_renewal = 0.0
        self.active = False
        self.refusal = ""

    def start(self) -> None:
        now = self.clock()
        self.deadline = now + self.ttl_seconds
        self.next_renewal = now + self.renew_seconds
        self.active = True
        self.refusal = ""

    def expired(self) -> bool:
        if not self.active:
            return bool(self.refusal)
        if self.clock() >= self.deadline:
            self.active = False
            self.refusal = "expired"
            return True
        return False

    def renew_if_due(self) -> bool:
        if not self.active or self.expired():
            return False
        now = self.clock()
        if now < self.next_renewal:
            return False
        self.deadline = now + self.ttl_seconds
        self.next_renewal = now + self.renew_seconds
        return True


def child_group_alive(pgid: int) -> bool:
    """Probe one explicit process group without broad process matching."""
    try:
        os.killpg(pgid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def terminate_group(process: subprocess.Popen[object], grace: float = KILL_GRACE_SECONDS) -> bool:
    """Terminate exactly the process group created for ``process`` and return if it is gone."""
    pgid = process.pid
    try:
        os.killpg(pgid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        process.wait(timeout=grace)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(pgid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        try:
            process.wait(timeout=grace)
        except subprocess.TimeoutExpired:
            return False
    return not child_group_alive(pgid)


def command_event(phase: str, command: list[str], returncode: int) -> dict:
    return {"event": "command", "phase": phase, "command": command, "returncode": returncode}


def run_replay(config_path: Path, state_path: Path) -> int:
    try:
        raw = config_path.read_text(encoding="utf-8")
        config = json.loads(raw)
    except (OSError, json.JSONDecodeError) as exc:
        print(f"FAIL replay_config — {exc}")
        return 1
    if not isinstance(config, dict):
        print("FAIL replay_config — expected an object")
        return 1
    root = Path(str(config.get("state_dir") or config_path.parent)).resolve()
    events: list[dict] = []
    state = {"status": "replaying", "events": [], "config_snapshot": raw}
    atomic_json(state_path, state)
    for phase in ("destroy", "create"):
        commands = config.get(phase)
        if not isinstance(commands, list) or not commands:
            state.update(status="failed", error=f"{phase} commands are required", events=events)
            atomic_json(state_path, state)
            print(f"FAIL {phase} — commands are required")
            return 1
        for command in commands:
            if not isinstance(command, list) or not command or not all(
                isinstance(item, str) and item for item in command
            ):
                state.update(status="failed", error=f"{phase} command is not argv", events=events)
                atomic_json(state_path, state)
                print(f"FAIL {phase} — command must be a non-empty argv list")
                return 1
            try:
                completed = subprocess.run(
                    command,
                    cwd=root,
                    check=False,
                    capture_output=True,
                    text=True,
                    stdin=subprocess.DEVNULL,
                )
            except OSError as exc:
                event = command_event(phase, command, 127)
                events.append(event)
                state.update(status="failed", error=f"{phase} could not start: {exc}", events=events)
                atomic_json(state_path, state)
                print(f"FAIL {phase} — could not start: {exc}")
                return 1
            event = command_event(phase, command, completed.returncode)
            events.append(event)
            if completed.returncode != 0:
                state.update(
                    status="failed",
                    error=f"{phase} exited {completed.returncode}",
                    events=events,
                )
                atomic_json(state_path, state)
                print(f"FAIL {phase} — exit {completed.returncode}")
                return 1
    expected = config.get("expected")
    if not isinstance(expected, dict) or not isinstance(expected.get("path"), str):
        state.update(status="failed", error="expected.path is required", events=events)
        atomic_json(state_path, state)
        print("FAIL expected — expected.path is required")
        return 1
    expected_path = Path(expected["path"])
    if not expected_path.is_absolute():
        expected_path = root / expected_path
    expected_path = expected_path.resolve()
    if root not in expected_path.parents and expected_path != root:
        state.update(status="failed", error="expected.path escapes state_dir", events=events)
        atomic_json(state_path, state)
        print("FAIL expected — path escapes state_dir")
        return 1
    try:
        measured = expected_path.read_text(encoding="utf-8")
    except OSError as exc:
        state.update(status="failed", error=f"expected artifact absent: {exc}", events=events)
        atomic_json(state_path, state)
        print(f"FAIL expected — artifact absent: {exc}")
        return 1
    if measured != expected.get("content"):
        state.update(status="failed", error="expected artifact content differs", events=events)
        atomic_json(state_path, state)
        print("FAIL expected — artifact content differs")
        return 1
    state.update(status="replayed", events=events, expected_path=str(expected_path))
    atomic_json(state_path, state)
    print(f"PASS replay — destroy/create reconstructed {expected_path}")
    return 0


def run_supervisor(args: argparse.Namespace) -> int:
    command = list(args.command)
    if not command:
        print("FAIL command — a child argv is required")
        return 1
    state_path = Path(args.state)
    completion_path = Path(args.completion_artifact) if args.completion_artifact else None
    deadline_path = Path(args.deadline_file) if args.deadline_file else None
    deadline = read_deadline(deadline_path)
    clock = time.monotonic
    lease = Lease(args.ttl, args.renew_interval, clock=clock)
    lease.start()
    events: list[dict] = []
    state: dict = {
        "status": "running",
        "command": command,
        "restarts": 0,
        "events": events,
        "ttl_seconds": args.ttl,
        "renew_interval": args.renew_interval,
    }
    atomic_json(state_path, state)
    process: subprocess.Popen[bytes] | None = None

    def persist(status: str, **extra: object) -> None:
        state.update(status=status, events=events, **extra)
        atomic_json(state_path, state)

    def cancel(reason: str) -> int:
        if process is None:
            persist("cancelled", error=reason)
            return 1
        pgid = process.pid
        killed = terminate_group(process)
        events.append(
            {
                "event": "cancel",
                "reason": reason,
                "pid": process.pid,
                "pgid": pgid,
                "killed": killed,
            }
        )
        persist("cancelled", error=reason, pid=process.pid, pgid=pgid)
        return 1

    try:
        while True:
            if process is not None and deadline is not None and time.time() >= deadline:
                return cancel("deadline")
            if process is not None and lease.expired():
                return cancel("ttl expired")
            if process is None:
                process = subprocess.Popen(
                    command,
                    start_new_session=True,
                    stdin=subprocess.DEVNULL,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
                events.append({"event": "start", "pid": process.pid, "pgid": process.pid})
                persist("running", pid=process.pid, pgid=process.pid)
            returncode = process.poll()
            if returncode is None:
                if lease.renew_if_due():
                    events.append({"event": "renew", "deadline": lease.deadline})
                    persist("running", lease_deadline=lease.deadline)
                time.sleep(args.poll_interval)
                continue
            pid = process.pid
            pgid = process.pid
            events.append({"event": "exit", "pid": pid, "pgid": pgid, "returncode": returncode})
            process = None
            if returncode == 0:
                if deadline is not None and time.time() >= deadline:
                    return cancel("deadline")
                if lease.expired():
                    return cancel("ttl expired")
                if completion_path is not None:
                    atomic_json(completion_path, {"status": "completed", "pid": pid})
                persist("completed", pid=pid, pgid=pgid)
                print("PASS supervisor — child completed")
                return 0
            if state["restarts"] >= args.max_restarts:
                persist("failed", error=f"child exited {returncode}", pid=pid, pgid=pgid)
                print(f"FAIL supervisor — child exited {returncode} after {state['restarts']} restart(s)")
                return 1
            state["restarts"] += 1
            events.append({"event": "restart", "after_pid": pid, "returncode": returncode, "restart": state["restarts"]})
            persist("running")
    except (OSError, ValueError) as exc:
        if process is not None:
            terminate_group(process)
        persist("failed", error=str(exc))
        print(f"FAIL supervisor — {exc}")
        return 1


def positive_float(value: str) -> float:
    parsed = float(value)
    if parsed <= 0:
        raise argparse.ArgumentTypeError("must be greater than zero")
    return parsed


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description=__doc__)
    sub = root.add_subparsers(dest="mode", required=True)
    supervise = sub.add_parser("supervise")
    supervise.add_argument("--state", required=True)
    supervise.add_argument("--completion-artifact")
    supervise.add_argument("--deadline-file")
    supervise.add_argument("--ttl", type=positive_float, default=1800.0)
    supervise.add_argument("--renew-interval", type=positive_float, default=None)
    supervise.add_argument("--poll-interval", type=positive_float, default=POLL_INTERVAL)
    supervise.add_argument("--max-restarts", type=int, default=3)
    supervise.add_argument("command", nargs=argparse.REMAINDER)
    replay = sub.add_parser("replay")
    replay.add_argument("--config", required=True)
    replay.add_argument("--state", required=True)
    return root


def main(argv: Iterable[str] | None = None) -> int:
    args = parser().parse_args(argv)
    if args.mode == "replay":
        return run_replay(Path(args.config), Path(args.state))
    if args.command[:1] == ["--"]:
        args.command = args.command[1:]
    return run_supervisor(args)


if __name__ == "__main__":
    raise SystemExit(main())
