"""CF-253 witness: the stall bound proven without pytest.

The repo's selftest gate is pytest-free by design (CI installs go and ruff only),
while tests/test_cf253_harness_stall_bound.py pins the same behaviour for the
local GitReins guard. This witness carries the arms the gate needs, in plain
python3, so a CI runner with no pytest still proves the bound instead of skipping.
"""

import contextlib
import importlib.util
import io
import os
import socket
import sys
import tempfile
import threading
import time
import types
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "worker_cf253_witness", ROOT / "scripts/node-bus-worker.py"
)
worker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(worker)

FAILURES = []


def check(name, condition, detail=""):
    if condition:
        print(f"  ok    {name}")
    else:
        FAILURES.append(name)
        print(f"  FAIL  {name} {detail}")


def identity(tmp, source):
    script = Path(tmp) / "client.py"
    script.write_text(source)
    ident = types.SimpleNamespace(
        home=str(tmp),
        repo_path=str(tmp),
        project="fixture",
        harness_name="fixture",
        harness_version="witness",
        agent="node",
        duckbrain_url="http://fixture",
        duckbrain_token_path=str(Path(tmp) / "token"),
    )
    ident.harness_argv = lambda prompt: [sys.executable, str(script)]
    return ident


def dead(pid_file, budget=5.0):
    """True once the harness child no longer answers signal 0."""
    pid = int(pid_file.read_text())
    deadline = time.monotonic() + budget
    while time.monotonic() < deadline:
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            return True
        time.sleep(0.05)
    return False


def arm_silent_socket():
    """A listener that accepts and sends no bytes must fail the run inside the bound."""
    with tempfile.TemporaryDirectory() as tmp:
        listener = socket.socket()
        listener.bind(("127.0.0.1", 0))
        listener.listen()
        listener.settimeout(15)
        release = threading.Event()
        accepted = threading.Event()

        def server():
            try:
                conn, _ = listener.accept()
                with conn:
                    accepted.set()
                    release.wait(20)
            finally:
                listener.close()

        thread = threading.Thread(target=server, daemon=True)
        thread.start()
        pid_file = Path(tmp) / "pid"
        port = listener.getsockname()[1]
        ident = identity(
            tmp,
            "import os,socket\n"
            f"open({str(pid_file)!r},'w').write(str(os.getpid()))\n"
            f"s=socket.create_connection(('127.0.0.1',{port}))\n"
            "s.recv(1)\n",
        )
        console = io.StringIO()
        try:
            with contextlib.redirect_stdout(console):
                code, elapsed, _out, _err, note = worker.run_harness(
                    ident, "", 30, stall_s=1
                )
        finally:
            release.set()
            thread.join(timeout=10)
        logged = console.getvalue()
        check("silent socket: the connection was accepted", accepted.is_set())
        check(
            "silent socket: fail naming the stall, not the wall",
            code is None
            and note.startswith("stalled:")
            and note != "wall limit 30s exceeded",
            f"code={code} note={note!r}",
        )
        check("silent socket: bounded", 1.0 <= elapsed < 20.0, f"elapsed={elapsed:.2f}")
        check(
            "silent socket: the harness child was killed",
            pid_file.exists() and dead(pid_file),
        )
        check(
            "silent socket: the effective bound is logged",
            "stall bound 1s" in logged,
            f"log={logged!r}",
        )


def arm_cpu_progress():
    """A harness burning CPU is progress, even with no output at all."""
    with tempfile.TemporaryDirectory() as tmp:
        ident = identity(
            tmp,
            "import time\nend=time.monotonic()+3.0\nwhile time.monotonic()<end: pass\n",
        )
        code, elapsed, out, err, note = worker.run_harness(ident, "", 20, stall_s=1)
        check(
            "cpu progress: a silent but busy harness survives the bound",
            code == 0 and not note and not out and elapsed >= 3.0,
            f"code={code} note={note!r} elapsed={elapsed:.2f}",
        )


def arm_output_and_wall():
    """Output resets the timer; --stall-s 0 restores wall-only behaviour."""
    with tempfile.TemporaryDirectory() as tmp:
        ident = identity(tmp, "print('hello')\n")
        code, _elapsed, out, _err, note = worker.run_harness(ident, "", 10, stall_s=1)
        check(
            "output: a fast harness passes untouched",
            code == 0 and "hello" in out and not note,
        )
        ident = identity(tmp, "import time\ntime.sleep(2.5)\nprint('done')\n")
        code, elapsed, out, _err, note = worker.run_harness(ident, "", 15, stall_s=0)
        check(
            "disabled: stall_s=0 waits out a silent 2.5s harness",
            code == 0 and "done" in out and not note and elapsed >= 2.5,
            f"code={code} note={note!r}",
        )
        ident = identity(tmp, "import time\ntime.sleep(10)\n")
        code, _elapsed, _out, _err, note = worker.run_harness(ident, "", 1, stall_s=0)
        check(
            "wall: a 1s wall still wins when the detector is off",
            code is None and note == "wall limit 1s exceeded",
            f"code={code} note={note!r}",
        )


def arm_parser():
    """A negative bound is a usage error, not a silent disable."""
    try:
        with contextlib.redirect_stderr(io.StringIO()):
            worker.main(["--stall-s", "-1", "--check"])
    except SystemExit as exc:
        check("parser: --stall-s -1 exits 2", exc.code == 2, f"code={exc.code}")
    else:
        check(
            "parser: --stall-s -1 exits 2", False, "main returned instead of refusing"
        )


def arm_memory_export():
    """The stall error reaches both durable records, not just stdout."""
    with tempfile.TemporaryDirectory() as tmp:
        saved = {}

        class FakeClient:
            def __init__(self, *args):
                pass

            def remember(self, namespace, key, record):
                saved[(namespace, key)] = dict(record)

            def read_exact(self, namespace, key):
                return saved[(namespace, key)]

        ident = identity(tmp, "print('unused')\n")
        original_client, original_git = worker.DuckBrainClient, worker.git_field
        worker.DuckBrainClient = FakeClient
        worker.git_field = lambda *args: "witness"
        try:
            result = {
                "status": "failed",
                "error": "stalled: no harness output and no CPU progress for 1s",
            }
            note = worker.memory_record(
                ident,
                {"dispatch_id": "d", "corr_id": "c", "board_row": "CF-253"},
                {"CF_NAMESPACE": "fixture", "CF_RUN_ID": "run", "CF_LANE": "fixture"},
                result,
                "FAIL",
            )
        finally:
            worker.DuckBrainClient, worker.git_field = original_client, original_git
        check("memory: memory_record reported no failure", note == "", f"note={note!r}")
        check(
            "memory: R1 and R2 both carry the stall error",
            len(saved) == 2
            and all(
                row["error"] == result["error"] and row["outcome"] == "FAIL"
                for row in saved.values()
            ),
            f"saved={list(saved.values())}",
        )


def main():
    print("CF-253 witness: stall bound without pytest")
    arm_silent_socket()
    arm_cpu_progress()
    arm_output_and_wall()
    arm_parser()
    arm_memory_export()
    if FAILURES:
        print(f"WITNESS: FAIL ({len(FAILURES)}) — " + "; ".join(FAILURES))
        return 1
    print("WITNESS: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
