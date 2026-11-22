"""CF-253: exercise a silent socket, CPU progress, wall and memory export."""

import importlib.util
import os
import socket
import sys
import threading
import time
import types
from pathlib import Path

import pytest

spec = importlib.util.spec_from_file_location(
    "worker_cf253", Path(__file__).resolve().parents[1] / "scripts/node-bus-worker.py"
)
worker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(worker)


def identity(tmp_path, source):
    script = tmp_path / "client.py"
    script.write_text(source)
    ident = types.SimpleNamespace(
        home=str(tmp_path),
        repo_path=str(tmp_path),
        project="fixture",
        harness_name="fixture",
        harness_version="test",
        agent="node",
        duckbrain_url="http://fixture",
        duckbrain_token_path=str(tmp_path / "token"),
    )
    ident.harness_argv = lambda prompt: [sys.executable, str(script)]
    return ident


def test_silent_upstream_stall_is_exported(tmp_path, monkeypatch, capsys):
    listener = socket.socket()
    listener.bind(("127.0.0.1", 0))
    listener.listen()
    listener.settimeout(10)
    release = threading.Event()
    accepted = threading.Event()

    def server():
        try:
            conn, _ = listener.accept()
            with conn:
                accepted.set()
                release.wait(15)
        finally:
            listener.close()

    thread = threading.Thread(target=server)
    thread.start()
    pidfile = tmp_path / "pid"
    ident = identity(
        tmp_path,
        f"import os,socket\nopen({str(pidfile)!r},'w').write(str(os.getpid()))\ns=socket.create_connection(('127.0.0.1',{listener.getsockname()[1]}))\ns.recv(1)\n",
    )
    saved = {}

    class FakeClient:
        def __init__(self, *args):
            pass

        def remember(self, namespace, key, record):
            saved[(namespace, key)] = dict(record)

        def read_exact(self, namespace, key):
            return saved[(namespace, key)]

    monkeypatch.setattr(worker, "DuckBrainClient", FakeClient)
    monkeypatch.setattr(worker, "git_field", lambda *args: "fixture")
    dispatch = {
        "dispatch_id": "d",
        "corr_id": "c",
        "text": "work",
        "vars": {
            "CF_RUN_ID": "run",
            "CF_MODEL": "fixture",
            "CF_PROVIDER": "fixture",
            "CF_NAMESPACE": "fixture",
            "CF_WORKDIR": str(tmp_path),
            "CF_LANE": "fixture",
        },
    }
    dispatch["brief"] = {"digest": worker.brief_digest(dispatch, dispatch["text"])}
    args = types.SimpleNamespace(dry_run=False, harness_wall=20, stall_s=2)
    start = time.monotonic()
    try:
        ok, result, ack = worker.process(
            dispatch, ident, None, args, {}, in_reply_to="m"
        )
    finally:
        release.set()
        thread.join(timeout=10)
    elapsed = time.monotonic() - start
    assert accepted.is_set()
    assert not ok and ack and result["status"] == "failed"
    assert "stalled" in result["error"] and 2 <= elapsed < 15
    assert len(saved) == 2
    assert all(
        row["error"] == result["error"] and row["outcome"] == "FAIL"
        for row in saved.values()
    )
    with pytest.raises(ProcessLookupError):
        os.kill(int(pidfile.read_text()), 0)
    output = capsys.readouterr().out
    assert output.index("stall bound 2s") < output.index("FAIL  harness")


def test_silent_cpu_progress_survives(tmp_path):
    ident = identity(
        tmp_path,
        "import time\nend=time.monotonic()+4.2\nwhile time.monotonic()<end: pass\n",
    )
    code, elapsed, out, err, note = worker.run_harness(ident, "", 12, stall_s=2)
    assert code == 0 and elapsed >= 4 and not out and not err and not note


def test_fast_output_and_disabled_stall_wall(tmp_path):
    ident = identity(tmp_path, "print('hello')\n")
    code, _, out, _, note = worker.run_harness(ident, "", 5, stall_s=2)
    assert code == 0 and out == "hello\n" and not note
    ident = identity(tmp_path, "import time\ntime.sleep(2.5)\nprint('done')\n")
    code, elapsed, out, _, note = worker.run_harness(ident, "", 6, stall_s=0)
    assert code == 0 and elapsed >= 2.5 and out == "done\n" and not note
    ident = identity(tmp_path, "import time\ntime.sleep(10)\n")
    code, _, _, _, note = worker.run_harness(ident, "", 1, stall_s=0)
    assert code is None and note == "wall limit 1s exceeded"


def test_negative_stall_rejected(capsys):
    with pytest.raises(SystemExit) as exc:
        worker.main(["--stall-s", "-1", "--check"])
    assert exc.value.code == 2
    assert "--stall-s must be non-negative" in capsys.readouterr().err
