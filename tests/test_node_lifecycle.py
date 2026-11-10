#!/usr/bin/env python3
"""Hermetic node supervisor, lease, cancellation and rebuild replay tests (CF-008)."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import textwrap
import time
import unittest

HERE = Path(__file__).resolve().parent
SCRIPT = HERE.parent / "scripts" / "node-lifecycle-supervisor.py"


def load_supervisor():
    spec = importlib.util.spec_from_file_location("cf_node_lifecycle", SCRIPT)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


SUPERVISOR = load_supervisor()


WORKER_FIXTURE = textwrap.dedent(
    """
    import os
    from pathlib import Path
    import subprocess
    import sys
    import time

    root = Path(sys.argv[1])
    count_path = root / "starts"
    count = int(count_path.read_text()) if count_path.exists() else 0
    count_path.write_text(str(count + 1))
    if count == 0:
        raise SystemExit(7)
    raise SystemExit(0)
    """
)


GROUP_FIXTURE = textwrap.dedent(
    """
    import os
    from pathlib import Path
    import signal
    import subprocess
    import sys
    import time

    root = Path(sys.argv[1])
    child = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(60)"])
    (root / "grandchild.pid").write_text(str(child.pid))
    def stop(_signum, _frame):
        try:
            os.kill(child.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        raise SystemExit(143)
    signal.signal(signal.SIGTERM, stop)
    while True:
        time.sleep(0.02)
    """
)


REPLAY_FIXTURE = textwrap.dedent(
    """
    from pathlib import Path
    import shutil
    import sys

    root = Path(sys.argv[1])
    action = sys.argv[2]
    state = root / "node-state.json"
    if action == "destroy":
        state.unlink(missing_ok=True)
    elif action == "create":
        state.write_text('{"node_id":"fixture-node","ready":true}\\n')
    else:
        raise SystemExit(2)
    """
)


def write_executable(path: Path, content: str) -> None:
    path.write_text(content, encoding="utf-8")
    path.chmod(0o755)


def read_state(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def proc_gone(pid: int) -> bool:
    proc = Path(f"/proc/{pid}")
    if not proc.exists():
        return True
    try:
        fields = (proc / "stat").read_text(encoding="utf-8").split()
    except (FileNotFoundError, OSError):
        return True
    return len(fields) > 2 and fields[2] == "Z"


class FakeClock:
    def __init__(self, value: float) -> None:
        self.value = value

    def __call__(self) -> float:
        return self.value


class NodeLifecycleTest(unittest.TestCase):
    def test_supervisor_restarts_child_in_its_group_and_records_evidence(self) -> None:
        with tempfile.TemporaryDirectory(prefix="cf008-supervise-") as raw:
            root = Path(raw)
            fixture = root / "worker.py"
            write_executable(fixture, WORKER_FIXTURE)
            state = root / "lifecycle.json"
            completion = root / "completion.json"
            result = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT),
                    "supervise",
                    "--state",
                    str(state),
                    "--completion-artifact",
                    str(completion),
                    "--poll-interval",
                    "0.01",
                    "--max-restarts",
                    "1",
                    "--",
                    sys.executable,
                    str(fixture),
                    str(root),
                ],
                capture_output=True,
                text=True,
                timeout=10,
            )
            self.assertEqual(0, result.returncode, result.stdout + result.stderr)
            payload = read_state(state)
            kinds = [event["event"] for event in payload["events"]]
            self.assertIn("restart", kinds)
            self.assertEqual(1, payload["restarts"])
            starts = [event for event in payload["events"] if event["event"] == "start"]
            self.assertEqual(2, len(starts))
            self.assertTrue(all(event["pid"] == event["pgid"] for event in starts))
            self.assertEqual("completed", payload["status"])
            self.assertTrue(completion.is_file())
            self.assertEqual(2, int((root / "starts").read_text()))
            for event in starts:
                self.assertTrue(proc_gone(event["pid"]), event)

    def test_ttl_renews_while_active_and_refuses_after_expiry(self) -> None:
        clock = FakeClock(100.0)
        lease = SUPERVISOR.Lease(ttl_seconds=10.0, renew_seconds=4.0, clock=clock)
        lease.start()
        self.assertEqual(110.0, lease.deadline)
        clock.value = 104.0
        self.assertTrue(lease.renew_if_due())
        self.assertEqual(114.0, lease.deadline)
        clock.value = 113.0
        self.assertTrue(lease.renew_if_due())
        self.assertEqual(123.0, lease.deadline)
        clock.value = 116.0
        self.assertFalse(lease.renew_if_due())
        self.assertFalse(lease.expired())
        clock.value = 123.0
        self.assertTrue(lease.expired())
        self.assertFalse(lease.renew_if_due())
        self.assertFalse(lease.active)
        self.assertEqual("expired", lease.refusal)

    def test_deadline_cancels_process_group_and_writes_no_completion(self) -> None:
        with tempfile.TemporaryDirectory(prefix="cf008-cancel-") as raw:
            root = Path(raw)
            fixture = root / "group.py"
            write_executable(fixture, GROUP_FIXTURE)
            state = root / "lifecycle.json"
            completion = root / "completion.json"
            deadline = root / "deadline"
            deadline.write_text(str(time.time()), encoding="utf-8")
            result = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT),
                    "supervise",
                    "--state",
                    str(state),
                    "--completion-artifact",
                    str(completion),
                    "--deadline-file",
                    str(deadline),
                    "--poll-interval",
                    "0.01",
                    "--",
                    sys.executable,
                    str(fixture),
                    str(root),
                ],
                capture_output=True,
                text=True,
                timeout=10,
            )
            self.assertNotEqual(0, result.returncode)
            payload = read_state(state)
            self.assertEqual("cancelled", payload["status"])
            cancelled = [event for event in payload["events"] if event["event"] == "cancel"]
            self.assertEqual(1, len(cancelled))
            self.assertEqual(cancelled[0]["pid"], cancelled[0]["pgid"])
            self.assertTrue(cancelled[0]["killed"])
            self.assertFalse(completion.exists())
            grandchild = root / "grandchild.pid"
            if grandchild.exists():
                self.assertTrue(proc_gone(int(grandchild.read_text())), grandchild.read_text())

    def test_destroy_create_replay_reconstructs_recorded_node_state(self) -> None:
        with tempfile.TemporaryDirectory(prefix="cf008-replay-") as raw:
            root = Path(raw)
            fixture = root / "rebuild.py"
            write_executable(fixture, REPLAY_FIXTURE)
            config = root / "replay.json"
            state = root / "replay-state.json"
            config.write_text(
                json.dumps(
                    {
                        "state_dir": str(root),
                        "destroy": [[sys.executable, str(fixture), str(root), "destroy"]],
                        "create": [[sys.executable, str(fixture), str(root), "create"]],
                        "expected": {
                            "path": "node-state.json",
                            "content": '{"node_id":"fixture-node","ready":true}\n',
                        },
                    }
                ),
                encoding="utf-8",
            )
            result = subprocess.run(
                [sys.executable, str(SCRIPT), "replay", "--config", str(config), "--state", str(state)],
                capture_output=True,
                text=True,
                timeout=10,
            )
            self.assertEqual(0, result.returncode, result.stdout + result.stderr)
            self.assertEqual(
                '{"node_id":"fixture-node","ready":true}\n',
                (root / "node-state.json").read_text(encoding="utf-8"),
            )
            payload = read_state(state)
            self.assertEqual("replayed", payload["status"])
            commands = [event for event in payload["events"] if event["event"] == "command"]
            self.assertEqual(["destroy", "create"], [event["phase"] for event in commands])
            self.assertEqual(
                config.read_text(encoding="utf-8"),
                payload["config_snapshot"],
            )


# ch:trace row=CF-008 spec=specs/NODE.md#N-6 wave=none:serial test=tests/test_node_lifecycle.py::NodeLifecycleTest doc=none:contract-is-in-spec evidence=tests/test_node_lifecycle.py witness=none:live-node-not-authorized verdict=none:foreman-judge commit=none:worker-commit memory=none:foreman-closeout


if __name__ == "__main__":
    unittest.main()
