"""Correlation identity is required on results, but malformed work is refused on the wire."""

import importlib.util
import json
import types
from pathlib import Path

import pytest

spec = importlib.util.spec_from_file_location(
    "worker_identity",
    Path(__file__).resolve().parents[1] / "scripts/node-bus-worker.py",
)
worker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(worker)


@pytest.fixture
def setup_worker(tmp_path, monkeypatch):
    ident = types.SimpleNamespace(
        home=str(tmp_path),
        repo_path=str(tmp_path),
        project="test",
        harness_name="fixture",
        agent="node",
        url="http://fixture",
        duckbrain_url="",
    )
    ident.harness_argv = lambda text: ["fixture", text]
    args = types.SimpleNamespace(dry_run=False, harness_wall=10, timeout=1)
    signer = types.SimpleNamespace(headers=lambda *args: {})
    posted = []
    monkeypatch.setattr(worker, "git_field", lambda *args: "")
    monkeypatch.setattr(worker, "run_harness", lambda *args: (0, 0.1, "ok", "", ""))
    monkeypatch.setattr(worker, "memory_record", lambda *args: "")
    monkeypatch.setattr(
        worker,
        "request",
        lambda method, url, body, headers, timeout: (
            posted.append(json.loads(body)) or 201,
            '{"id":"sent"}',
        ),
    )
    return ident, args, signer, posted


@pytest.mark.parametrize("member", ["in_reply_to", "corr_id", "run_id"])
def test_missing_member_is_refused_and_delivered(setup_worker, member):
    ident, args, signer, posted = setup_worker
    dispatch = {
        "dispatch_id": "d",
        "corr_id": "c",
        "vars": {"CF_RUN_ID": "r"},
        "text": "work",
    }
    relay = "message"
    if member == "in_reply_to":
        relay = ""
    elif member == "corr_id":
        del dispatch["corr_id"]
    else:
        del dispatch["vars"]["CF_RUN_ID"]
    ok, result, ack = worker.process(
        dispatch, ident, signer, args, {}, in_reply_to=relay
    )
    assert not ok and ack and result["status"] == "refused" and result["ok"] is False
    assert result["refused_by"] == "envelope" and member in result["error"]
    assert result["missing"] == [member]
    assert worker.deliver(
        signer, ident, "scheduler", result, args, in_reply_to="relay-id"
    )
    assert posted[0]["payload"]["missing"] == [member]
    assert posted[0]["payload"]["in_reply_to"] == (relay or "relay-id")


@pytest.mark.parametrize("member", ["in_reply_to", "corr_id", "run_id"])
def test_egress_never_posts_invalid_result(setup_worker, member):
    ident, args, signer, posted = setup_worker
    result = {"status": "completed", "in_reply_to": "m", "corr_id": "c", "run_id": "r"}
    result[member] = ""
    assert not worker.deliver(signer, ident, "scheduler", result, args)
    assert posted == []


def test_vars_run_id_on_real_result(setup_worker):
    ident, args, signer, posted = setup_worker
    dispatch = {
        "dispatch_id": "d",
        "corr_id": "c",
        "vars": {"CF_RUN_ID": "r"},
        "text": "work",
    }
    dispatch["brief"] = {"digest": worker.brief_digest(dispatch, dispatch["text"])}
    ok, result, ack = worker.process(dispatch, ident, signer, args, {}, in_reply_to="m")
    assert (
        ok
        and ack
        and result["run_id"] == "r"
        and result["corr_id"] == "c"
        and result["in_reply_to"] == "m"
        and result["missing"] == []
    )
    assert worker.deliver(signer, ident, "scheduler", result, args)
    assert posted[0]["payload"] == result
