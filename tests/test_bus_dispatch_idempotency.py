#!/usr/bin/env python3
"""Hermetic proof of receive-side dispatch idempotency (CF-132).

The contract under test is ``specs/ENVELOPE.md`` §"Correlation and idempotency":
"Every dispatch carries an ``idempotency_key``; a redelivered message must be recognised and the
previous result returned rather than the work being done twice."

Four things are proven here, all without a network, a real harness, or a path outside ``tmp_path``:

* AC 1 — two receives of one dispatch, sharing one seen-ledger, execute the harness ONCE; the
  second call returns the recorded result and says it did not re-run.
* AC 2 — the ledger survives a restart: the recorded execution is persisted with ``save_seen()``
  and a fresh ``load_seen()`` into an empty dict still replays instead of re-running. The third
  test drives the REAL loop (``once``) twice with a fake relay, so the write side — the worker
  recording the execution before it delivers, and reloading it at the next start — is exercised
  too, not just seeded by the test.
* AC 3 — the spec sentence quoted above is the behaviour these assertions pin; code and spec
  agree, so the spec is unchanged.
* AC 4 — an empty or non-string ``text`` is refused and returned ack-able, so a malformed
  dispatch cannot loop forever.
"""

from __future__ import annotations

import base64
import contextlib
import importlib.util
import io
import json
import types
from pathlib import Path

import pytest

HERE = Path(__file__).resolve().parent
WORKER = HERE.parent / "scripts" / "node-bus-worker.py"


def load_worker():
    """Import the worker source, whose filename is not a valid module name."""
    spec = importlib.util.spec_from_file_location("cf_bus_worker_cf132", WORKER)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


WORKER_MOD = load_worker()


class FakeHarness:
    """Count execution attempts while returning a deterministic harness result."""

    def __init__(self):
        self.calls = 0

    def __call__(self, ident, prompt, timeout_s, values=None):
        self.calls += 1
        return 0, 0.01, "fake harness output", "", ""


def identity(tmp_path):
    ident = types.SimpleNamespace(
        home=str(tmp_path),
        repo_path=str(tmp_path),
        project="code-factory",
        harness_name="fixture-harness",
        harness_version="test",
        duckbrain_url="",
        duckbrain_token_path=str(tmp_path / "duckbrain.token"),
        agent="fixture-node",
    )
    # process() builds the argv before calling run_harness; the fake runner replaces the latter.
    ident.harness_argv = lambda prompt: ["fake-harness", prompt]
    return ident


def args():
    return types.SimpleNamespace(dry_run=False, harness_wall=30)


def dispatch():
    message = {
        "dispatch_id": "cf132-dispatch-1",
        "corr_id": "cf132-correlation-1",
        "project_id": "code-factory",
        "round_id": "round-1",
        "task_id": "task-1",
        "attempt_id": "attempt-1",
        "text": "execute the fixture task",
        "criteria": [],
        "skills": [],
        "attachments": [],
    }
    message["brief"] = {
        "digest": WORKER_MOD.brief_digest(message, message["text"]),
    }
    return message


def run_process(dispatch_message, ident, seen, monkeypatch, output):
    with contextlib.redirect_stdout(output):
        return WORKER_MOD.process(
            dispatch_message,
            ident,
            None,
            args(),
            seen,
            in_reply_to="relay-message-1",
        )


def test_redelivery_runs_work_once_and_returns_same_result(tmp_path, monkeypatch):
    """AC 1: two receives with one in-memory ledger execute the harness once."""
    fake_harness = FakeHarness()
    monkeypatch.setattr(WORKER_MOD, "run_harness", fake_harness)
    monkeypatch.setattr(WORKER_MOD, "git_field", lambda *fields: "fixture-value")

    message = dispatch()
    seen = {}
    first_output = io.StringIO()
    first_ok, first_result, first_ack = run_process(
        message, identity(tmp_path), seen, monkeypatch, first_output
    )
    assert first_ok is True
    assert first_ack is True
    assert first_result is not None
    assert fake_harness.calls == 1

    key = WORKER_MOD.dispatch_key(message)
    seen[key] = first_result

    second_output = io.StringIO()
    second_ok, second_result, second_ack = run_process(
        message, identity(tmp_path), seen, monkeypatch, second_output
    )
    assert second_ok is True
    assert second_ack is True
    assert second_result == first_result
    assert fake_harness.calls == 1, "the redelivered dispatch re-ran the harness"
    assert "was already executed — returning the recorded result, not re-running" in (
        second_output.getvalue()
    )


def test_seen_ledger_survives_restart_and_replays_result(tmp_path, monkeypatch):
    """AC 2: a fresh load of bus-seen.json prevents execution after restart."""
    fake_harness = FakeHarness()
    monkeypatch.setattr(WORKER_MOD, "run_harness", fake_harness)
    monkeypatch.setattr(WORKER_MOD, "git_field", lambda *fields: "fixture-value")

    message = dispatch()
    key = WORKER_MOD.dispatch_key(message)
    first_seen = {}
    first_output = io.StringIO()
    _, first_result, first_ack = run_process(
        message, identity(tmp_path), first_seen, monkeypatch, first_output
    )
    assert first_result is not None
    assert first_ack is True
    assert fake_harness.calls == 1

    first_seen[key] = first_result
    seen_path = tmp_path / "bus-seen.json"
    WORKER_MOD.save_seen(str(seen_path), first_seen)

    restarted_seen = WORKER_MOD.load_seen(str(seen_path))
    assert restarted_seen == {key: first_result}

    replay_output = io.StringIO()
    replay_ok, replay_result, replay_ack = run_process(
        message, identity(tmp_path), restarted_seen, monkeypatch, replay_output
    )
    assert replay_ok is True
    assert replay_ack is True
    assert replay_result == first_result
    assert fake_harness.calls == 1, "the restart redelivery re-ran the harness"
    assert "was already executed — returning the recorded result, not re-running" in (
        replay_output.getvalue()
    )


@pytest.mark.parametrize("text", ["", 123, None])
def test_empty_or_non_string_text_is_refused_and_ackable(tmp_path, monkeypatch, text):
    """AC 4: malformed instruction text is refused and acknowledged without execution."""
    fake_harness = FakeHarness()
    monkeypatch.setattr(WORKER_MOD, "run_harness", fake_harness)

    message = {"dispatch_id": "cf132-malformed", "text": text}
    output = io.StringIO()
    rows_ok, result, should_ack = run_process(
        message, identity(tmp_path), {}, monkeypatch, output
    )

    assert rows_ok is False
    assert should_ack is True
    assert result is not None
    assert result["status"] == "refused"
    assert result["refused_by"] == "brief"
    assert fake_harness.calls == 0
    assert "carries no `text`" in output.getvalue()


class FakeBus:
    """The relay's inbox, plus the delivered result envelopes, with no socket involved."""

    def __init__(self, message):
        self.message = message
        self.deliveries = []
        self.requests = []

    def request(self, method, url, body=None, headers=None, timeout=None):
        self.requests.append((method, url))
        if url.endswith("/health"):
            return 200, "{}"
        if method == "GET" and "/inbox" in url:
            payload = base64.b64encode(json.dumps(self.message).encode("utf-8")).decode(
                "ascii"
            )
            return 200, json.dumps(
                {
                    "messages": [{"id": "relay-message-1", "payload": payload}],
                    "lease_id": "lease-1",
                    "queue_depth": 1,
                }
            )
        raise AssertionError(f"unexpected request {method} {url}")

    def deliver(
        self, signer, ident, target, result, args, in_reply_to="", idempotency_key=""
    ):
        self.deliveries.append(result)
        return True

    def ack(self, signer, ident, lease_id, message_ids, args):
        return True


def worker_identity(tmp_path):
    """A real Identity: node.json + token on disk under tmp_path, nothing read from $HOME."""
    node_dir = tmp_path / ".node"
    (node_dir / "auth").mkdir(parents=True, exist_ok=True)
    (node_dir / "node.json").write_text(
        json.dumps(
            {
                "project": "code-factory",
                "agent": "fixture-node",
                "repo": {"path": str(tmp_path)},
                "harness": {
                    "name": "fixture-harness",
                    "version": "test",
                    "cmd": "fake-harness",
                },
                "bus": {"base": "http://bus.invalid"},
            }
        ),
        encoding="utf-8",
    )
    (node_dir / "auth" / "crier.token").write_text("fixture-bearer\n", encoding="utf-8")
    return WORKER_MOD.Identity(str(tmp_path), once_args())


def once_args():
    return types.SimpleNamespace(
        dry_run=False,
        timeout=5,
        lease_seconds=5,
        limit=1,
        wait_seconds=0,
        reply_to="scheduler",
        harness_wall=30,
        identity=None,
        bus_identity=None,
        key=None,
        token_file=None,
        agent=None,
        project=None,
        crier=None,
        workdir=None,
        harness_cmd=None,
        duckbrain_url=None,
        duckbrain_token_file=None,
        gateway_port=None,
    )


def run_once(bus, ident, monkeypatch, output):
    monkeypatch.setattr(WORKER_MOD, "request", bus.request)
    monkeypatch.setattr(WORKER_MOD, "deliver", bus.deliver)
    monkeypatch.setattr(WORKER_MOD, "ack", bus.ack)
    with contextlib.redirect_stdout(output):
        return WORKER_MOD.once(ident, once_args())


def test_worker_loop_records_ledger_and_replays_on_redelivery(tmp_path, monkeypatch):
    """AC 1+2 through the real loop: `once` records at execution and replays after a restart.

    The first `once()` handles a leased message, records the result in
    `<home>/.node/bus-seen.json` and delivers it. The second `once()` runs in a fresh
    `Identity` — the seen-cache is read from disk, exactly as it is in a new process, and
    no state is shared with the first call in memory.
    """
    fake_harness = FakeHarness()
    monkeypatch.setattr(WORKER_MOD, "run_harness", fake_harness)
    monkeypatch.setattr(WORKER_MOD, "git_field", lambda *fields: "fixture-value")
    monkeypatch.setattr(WORKER_MOD, "load_seed", lambda path: b"\x01" * 32)

    message = dispatch()
    bus = FakeBus(message)

    first_output = io.StringIO()
    assert run_once(bus, worker_identity(tmp_path), monkeypatch, first_output) == 0
    assert fake_harness.calls == 1
    assert len(bus.deliveries) == 1

    seen_path = tmp_path / ".node" / "bus-seen.json"
    assert seen_path.exists(), "the loop did not record the execution before delivery"
    recorded = json.loads(seen_path.read_text(encoding="utf-8"))
    key = WORKER_MOD.dispatch_key(message)
    assert recorded == {key: bus.deliveries[0]}
    assert recorded[key]["dispatch_id"] == message["dispatch_id"]

    second_output = io.StringIO()
    assert run_once(bus, worker_identity(tmp_path), monkeypatch, second_output) == 0
    assert fake_harness.calls == 1, "the redelivered message re-ran the harness"
    assert len(bus.deliveries) == 2
    assert bus.deliveries[1] == bus.deliveries[0]
    assert "was already executed — returning the recorded result, not re-running" in (
        second_output.getvalue()
    )
