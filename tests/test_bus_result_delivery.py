#!/usr/bin/env python3
"""Hermetic tests for the RETURN half of the bus round trip (CF-211).

The scheduler always had the receiving half: `internal/scheduler/dispatch_leg.go` polls its own
inbox, correlates a reply by `in_reply_to` / `corr_id`, acks it, derives a verdict and completes
the tick. What had never been exercised is the PRODUCING half — a node that posts a result the
scheduler can do anything with. Two things were missing, and both are asserted here against the
REAL worker CLI:

  * the scheduler reads `payload["ok"]`, and treats its ABSENCE as success
    (`dispatchReplyVerdict`, dispatch_leg.go:713) — so a node that only said
    `"status": "failed"` had its failure closed as a COMPLETED tick;
  * a lost delivery was never retried with a stable relay idempotency key, and the result was
    cached only AFTER delivery, so a redelivery re-RAN the harness instead of re-sending the
    result.

Every arm drives `scripts/node-bus-worker.py --once` as a subprocess against ONE stub relay that
speaks crier's documented inbox surface (`docs/openapi.yaml` → `inboxDeliver` /
`GET /agents/{id}/inbox` / `POST /agents/{id}/inbox/ack`): the deliver body must carry a JSON
OBJECT `payload`, retries dedupe on `idempotency_key`, a blocking-budget exhaustion is a 504 that
stores nothing, and an answer that is lost after the store keeps the stored message. No network,
no credential, no live node: one `mktemp -d` per arm.

The consumer side is modelled from the scheduler's own code, case for case, and the model is
PINNED to that source (`consumer-pin`, below) plus to the scheduler's own test names:
`TestCorrelateDispatchReply_IdentityNotArrival`, `TestDispatchLeg_AgentVerdictOfFailureFailsTheTick`
and `TestDispatchLeg_AllUncorrelatedBatchNeverCompletesTheTick`. The pin prints SKIP when no
scheduler checkout is present; it never silently passes a disagreement.

  A1 green  a completed run POSTs the envelope to reply_to with corr_id + dispatch_id +
            in_reply_to + ok=true, and the scheduler's model completes the tick
  A2 green  a failing gate POSTs ok=false with the node's reason, and the tick FAILS with it
            (not: completes)
  A3 red    the PRE-CF-211 envelope (the same bytes minus ok/error/reply_b64/in_reply_to) reads
            as a SUCCESS while `status` says failed — the arm discriminates on `ok` alone
  A4 red    a result whose corr_id and in_reply_to name a DIFFERENT hand-out never completes the
            tick: the await names the expected corr_id, the message is settled as residue (acked
            when it can belong to nobody, deferred when it names another in-flight hand-out)
  A5 green  a 504 (blocking budget exhausted) leaves the dispatch unacked and the work uncached
            as delivered; the next poll re-delivers the SAME result with the SAME key and does
            NOT re-run the harness, and the ack follows the accepted delivery
  A6 green  an answer lost after the relay stored it (dropped connection) still lands exactly
            once: the retry is answered with the FIRST accept id
  A7 green  a gate that could not run is a FAILED result — never a completed tick on work
            nobody gated (the node's own FAIL row and the envelope agree)

Run directly: `python3 tests/test_bus_result_delivery.py` — exit 0 on success, 1 on failure.
The red control runs the SAME fixture against a pre-fix worker source and requires the defect:

  git show 9af58a0:scripts/node-bus-worker.py > /tmp/prefix-worker.py
  CF_BUS_WORKER_SOURCE=/tmp/prefix-worker.py CF_BUS_RESULT_PREFIX_CONTROL=1 \
      python3 tests/test_bus_result_delivery.py

which asserts the pre-fix envelope carries no `ok`/`in_reply_to`/idempotency key, that a failed
gate is therefore completed as a success, and that a refused delivery re-runs the harness. Those
arms fail against the fixed worker, so the pair discriminates. A fixture that cannot reproduce the
defect it was written for is decoration.
"""

from __future__ import annotations

import base64
import contextlib
import http.server
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import unittest
import urllib.parse

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_WORKER = os.path.join(HERE, os.pardir, "scripts", "node-bus-worker.py")
WORKER = os.environ.get("CF_BUS_WORKER_SOURCE") or DEFAULT_WORKER

SCHED_CANDIDATES = (
    os.environ.get("CF_SCHEDULER_SRC") or "",
    os.path.expanduser("~/coding-hermes-scheduler/coding-herms-scheduler"),
    os.path.expanduser("~/coding-hermes-scheduler"),
)

# Control mode: the arms must then hold a PRE-FIX worker source (CF_BUS_WORKER_SOURCE) to the
# defect this row was raised on, rather than to the contract.
PREFIX_CONTROL = os.environ.get("CF_BUS_RESULT_PREFIX_CONTROL") == "1"


def load_worker():
    """Import the worker source, whose filename is not a valid module name."""
    spec = importlib.util.spec_from_file_location("cf_bus_worker_cf211", WORKER)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


WORKER_MOD = load_worker()

DIRECTIVE = (
    'You are the foreman for lane "code-factory".\n'
    "Ship the return leg and report a verdict.\n"
)

# Stands in for the harness: records that it STARTED, the prompt it got, and the exit code it was
# told to answer with. Nothing about it is read from the environment — the worker scrubs every
# CF_* variable before the child starts, so the fixture takes its arguments in argv.
STUB_HARNESS = """\
import sys
from pathlib import Path
prompt, run_dir, code = sys.argv[1], Path(sys.argv[2]), int(sys.argv[3])
run_dir.mkdir(parents=True, exist_ok=True)
with open(run_dir / "runs.txt", "a", encoding="utf-8") as handle:
    handle.write("run\\n")
(run_dir / "prompt.txt").write_text(prompt, encoding="utf-8")
sys.stdout.write("foreman report: shipped CF-211, %d chars of directive\\n" % len(prompt))
sys.stderr.write("stub harness stderr\\n")
sys.exit(code)
"""

# A fixed seed, so the fixture key is reproducible and nothing is generated at random. The key is
# never printed: the worker builds its own PEM parser, and the relay here does not verify it. The
# PEM header is ASSEMBLED from fragments on purpose — a credential-shaped literal in a source file
# is what the secret scanner exists to refuse, and an allowlist for this path would also exempt a
# real key pasted here later.
SEED = bytes(range(32))
PKCS8_DER = bytes.fromhex("302e020100300506032b657004220420") + SEED
_PEM_LABEL = "PRIVATE" + " KEY"
PEM_KEY = (
    "-----BEGIN "
    + _PEM_LABEL
    + "-----\n"
    + base64.encodebytes(PKCS8_DER).decode("ascii")
    + "-----END "
    + _PEM_LABEL
    + "-----\n"
)


def b64(text):
    return base64.b64encode(text.encode("utf-8")).decode("ascii")


def unb64(text):
    return base64.b64decode(text).decode("utf-8", "replace")


def dispatch_envelope(
    dispatch_id, corr_id, reply_to="scheduler", gate=None, text=DIRECTIVE
):
    """A dispatch exactly as the scheduler sends it, with a cf-brief-v1 digest over what runs."""
    dispatch = {
        "env_version": 1,
        "dispatch_id": dispatch_id,
        "corr_id": corr_id,
        "reply_to": reply_to,
        "lane": "code-factory",
        "text_b64": b64(text),
    }
    if gate is not None:
        dispatch["gate"] = gate
    # The digest covers text+gate+repo+ref+workdir+vars, and `brief` itself is not hashed, so it
    # can be attached after the rest of the envelope exists.
    dispatch["brief"] = {
        "digest": WORKER_MOD.brief_digest(dispatch, text),
        "bytes": len(text.encode()),
    }
    return dispatch


# ---------------------------------------------------------------------------------------------
# the stub relay — crier's documented inbox surface, in memory
# ---------------------------------------------------------------------------------------------


class RelayState:
    """One relay's state: what is pending, what was delivered, what was acked, in what order."""

    def __init__(self):
        self.lock = threading.Lock()
        self.agent = "fixture-node"
        self.scheduler = "scheduler"
        # messages the node's inbox will hand out: [{"id", "payload"(dict)}]
        self.pending = []
        # the scripted answer for each POST /agents/{id}/inbox, popped in order; "ok" when empty
        self.deliver_modes = []
        # every request, in arrival order: ("health"|"inbox"|"deliver"|"ack", detail)
        self.events = []
        self.deliveries = []  # [{path, body, headers}]
        self.acks = []  # [{lease_id, message_ids}]
        self.stored = []  # [{id, key, payload}]
        self.by_key = {}  # idempotency_key -> accept id
        self.seq = 0

    def next_id(self, prefix):
        self.seq += 1
        return f"{prefix}-{self.seq}"

    def order(self):
        """The arrival order of the two calls the ack rule is about."""
        return [kind for kind, _ in self.events]


class RelayHandler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.0"

    def log_message(self, fmt, *args):  # noqa: A003 - silence the fixture, keep the wire
        return

    # -- helpers ---------------------------------------------------------------------------
    def _json(self, status, payload):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _body(self):
        length = int(self.headers.get("Content-Length") or 0)
        return self.rfile.read(length) if length else b""

    # -- routes ----------------------------------------------------------------------------
    def do_GET(self):  # noqa: N802 - BaseHTTPRequestHandler's spelling
        parsed = urllib.parse.urlparse(self.path)
        state = self.server.state
        if parsed.path == "/health":
            with state.lock:
                state.events.append(("health", None))
            self._json(200, {"status": "ok"})
            return
        if parsed.path.endswith("/inbox"):
            with state.lock:
                state.events.append(("inbox", None))
                lease = state.next_id("lease")
                messages = [
                    {"id": item["id"], "payload": b64(json.dumps(item["payload"]))}
                    for item in state.pending
                ]
            self._json(
                200,
                {"lease_id": lease, "messages": messages, "queue_depth": len(messages)},
            )
            return
        self._json(404, {"error": "no such route"})

    def do_POST(self):  # noqa: N802 - BaseHTTPRequestHandler's spelling
        parsed = urllib.parse.urlparse(self.path)
        state = self.server.state
        raw = self._body()
        try:
            body = json.loads(raw) if raw else {}
        except ValueError:
            body = {}
        if parsed.path.endswith("/inbox/ack"):
            with state.lock:
                state.events.append(("ack", body.get("message_ids") or []))
                state.acks.append(body)
                acked = set(body.get("message_ids") or [])
                state.pending = [m for m in state.pending if m["id"] not in acked]
            self.send_response(204)
            self.end_headers()
            return
        if parsed.path.endswith("/inbox"):
            with state.lock:
                state.events.append(("deliver", None))
                state.deliveries.append(
                    {
                        "path": parsed.path,
                        "body": body,
                        "headers": dict(self.headers),
                    }
                )
                mode = state.deliver_modes.pop(0) if state.deliver_modes else "ok"
            if mode == "504":
                # crier's blocking-budget exhaustion: nothing durable was stored, and the same
                # delivery may still land later (docs/openapi.yaml, inboxDeliver).
                self._json(504, {"error": "blocking delivery budget exhausted"})
                return
            key = str(body.get("idempotency_key") or "")
            with state.lock:
                if key and key in state.by_key:
                    accept = state.by_key[key]
                    replayed = True
                else:
                    accept = state.next_id("res")
                    if key:
                        state.by_key[key] = accept
                    state.stored.append(
                        {"id": accept, "key": key, "payload": body.get("payload")}
                    )
                    replayed = False
            if mode == "drop":
                # Stored, then the answer is lost on the way back: the sender sees no response
                # while the relay holds the message. A durable inbox is exactly this.
                self.close_connection = True
                return
            self._json(201, {"id": accept, "transport": "inbox", "replayed": replayed})
            return
        self._json(404, {"error": "no such route"})


class Relay:
    """A running stub relay bound to an ephemeral port on loopback."""

    def __init__(self):
        self.state = RelayState()
        self.httpd = http.server.ThreadingHTTPServer(("127.0.0.1", 0), RelayHandler)
        self.httpd.state = self.state
        self.thread = threading.Thread(target=self.httpd.serve_forever, daemon=True)
        self.thread.start()

    @property
    def url(self):
        host, port = self.httpd.server_address[:2]
        return f"http://{host}:{port}"

    def seed(self, message_id, dispatch):
        self.state.pending.append({"id": message_id, "payload": dispatch})

    def close(self):
        self.httpd.shutdown()
        self.httpd.server_close()
        self.thread.join(timeout=5)

    # -- readers ---------------------------------------------------------------------------
    def delivered(self):
        return [d for d in self.state.deliveries]

    def acks(self):
        return [a for a in self.state.acks]

    def order(self):
        return self.state.order()

    def stored(self):
        return self.state.stored


# ---------------------------------------------------------------------------------------------
# the scheduler's consumer, modelled from internal/scheduler/dispatch_leg.go
# ---------------------------------------------------------------------------------------------


def consumer_correlate(payload, receipt):
    """`correlateDispatchReply` (dispatch_leg.go:673) — identity, never arrival order.

    The scheduler matches on `in_reply_to` (the relay message id) FIRST, then on `corr_id`, then
    on the original dispatch echoed back inside `task` (string or object). Anything else is not
    an answer to this hand-out, however plausible it looks.
    """
    if not isinstance(payload, dict):
        return False
    in_reply_to = payload.get("in_reply_to")
    if (
        isinstance(in_reply_to, str)
        and in_reply_to
        and receipt["message_id"]
        and in_reply_to == receipt["message_id"]
    ):
        return True
    corr_id = payload.get("corr_id")
    if isinstance(corr_id, str) and corr_id and corr_id == receipt["corr_id"]:
        return True
    task = payload.get("task")
    if isinstance(task, dict) and task.get("corr_id") == receipt["corr_id"]:
        return True
    if isinstance(task, str) and receipt["corr_id"] in task:
        with contextlib.suppress(ValueError):
            echoed = json.loads(task)
            if isinstance(echoed, dict) and echoed.get("corr_id") == receipt["corr_id"]:
                return True
    return False


def _decoded_field(payload, key):
    enc = payload.get(key)
    if not isinstance(enc, str) or not enc:
        return ""
    try:
        return base64.b64decode(enc).decode("utf-8", "replace")
    except Exception:  # noqa: BLE001 - an unreadable field is an absent one
        return ""


def consumer_verdict(payload):
    """`dispatchReplyVerdict` (dispatch_leg.go:713) — `ok` is the verdict, absence is success."""
    flag = payload.get("ok")
    if flag is False:
        decoded = _decoded_field(payload, "error_b64")
        if decoded:
            return False, decoded
        for key in ("error", "err", "reply", "text", "message"):
            value = payload.get(key)
            if isinstance(value, str) and value.strip():
                return False, value
        return False, "the agent reported ok=false"
    return True, ""


def consumer_text(payload):
    """`dispatchReplyText` (dispatch_leg.go:744) — `reply_b64` first, then the plain members."""
    decoded = _decoded_field(payload, "reply_b64")
    if decoded:
        return decoded
    for key in ("reply", "answer", "text", "message", "output"):
        value = payload.get(key)
        if isinstance(value, str) and value.strip():
            return value
    return json.dumps(payload, sort_keys=True) if payload else ""


def dispatch_reply_key(payload):
    """`dispatchReplyKey` (dispatch_leg.go:563) — the identity a message CLAIMS, for the log."""
    if not isinstance(payload, dict):
        return "unreadable"
    for key in ("corr_id", "in_reply_to"):
        value = payload.get(key)
        if isinstance(value, str) and value:
            return value
    task = payload.get("task")
    if isinstance(task, dict) and isinstance(task.get("corr_id"), str):
        return task["corr_id"]
    if isinstance(task, str):
        with contextlib.suppress(ValueError):
            echoed = json.loads(task)
            if isinstance(echoed, dict) and isinstance(echoed.get("corr_id"), str):
                return echoed["corr_id"]
    return "unidentified"


def consumer_await(messages, receipt, outstanding=None):
    """`awaitDispatchReply` (dispatch_leg.go:362) — the batch, then the deadline verdict.

    `outstanding` is the set of corr ids / message ids that belong to OTHER in-flight hand-outs
    (`dispatchReplyOwnedElsewhere`, dispatch_leg.go:651): a message naming one of them is deferred
    for its owner instead of being acked as residue.
    """
    outstanding = set(outstanding or ())
    keys, acked, deferred = [], 0, 0
    for message in messages:
        payload = message["payload"]
        if consumer_correlate(payload, receipt):
            ok, why = consumer_verdict(payload)
            text = consumer_text(payload) or why
            return {
                "state": "completed" if ok else "failed",
                "text": text,
                "detail": "",
            }
        keys.append(dispatch_reply_key(payload))
        key = keys[-1]
        if key in outstanding or payload.get("in_reply_to") in outstanding:
            deferred += 1
        else:
            acked += 1
    detail = (
        f"[dispatch-inbox] seen={len(messages)} correlated=0 "
        f"uncorrelated={len(messages)} keys={','.join(keys)} acked={acked} deferred={deferred}"
    )
    return {
        "state": "expired",
        "text": "",
        "detail": detail,
        "error": (
            f"no correlated reply for corr={receipt['corr_id']} "
            f"(message={receipt['message_id']}) within the tick budget — the hand-out is "
            f"recorded and the agent may still answer"
        ),
    }


# ---------------------------------------------------------------------------------------------
# the node fixture — a real $HOME, a real key, a real stub harness
# ---------------------------------------------------------------------------------------------


class Fixture:
    def __init__(
        self, root, relay_url, corr_id="q-lane-1", exit_code=0, message_id="msg-1"
    ):
        self.root = root
        self.home = os.path.join(root, "home")
        self.repo = os.path.join(self.home, "repo")
        self.run_dir = os.path.join(root, "harness-runs")
        self.stub = os.path.join(root, "stub_harness.py")
        self.corr_id = corr_id
        self.message_id = message_id
        os.makedirs(os.path.join(self.home, ".node", "auth"))
        os.makedirs(self.repo)
        os.makedirs(self.run_dir, exist_ok=True)
        with open(self.stub, "w", encoding="utf-8") as handle:
            handle.write(STUB_HARNESS)
        self.write(os.path.join(self.home, ".node", "agent.key"), PEM_KEY, mode=0o600)
        self.write(
            os.path.join(self.home, ".node", "auth", "crier.token"),
            "fixture-token\n",
            mode=0o600,
        )
        self.write(
            os.path.join(self.home, ".node", "node.json"),
            json.dumps(
                {
                    "node_id": "fixture-node",
                    "project": "code-factory",
                    "repo": {"path": self.repo},
                    "harness": {
                        "name": "fixture-recorder",
                        "cmd": [
                            sys.executable,
                            "-B",
                            self.stub,
                            "{prompt}",
                            self.run_dir,
                            str(exit_code),
                        ],
                    },
                }
            ),
            mode=0o600,
        )
        self.write(
            os.path.join(self.home, ".node", "crier.json"),
            json.dumps(
                {
                    "agent": "fixture-node",
                    "project": "code-factory",
                    "url": relay_url,
                }
            ),
            mode=0o600,
        )

    @staticmethod
    def write(path, text, mode=0o644):
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(text)
        os.chmod(path, mode)

    def runs(self):
        path = os.path.join(self.run_dir, "runs.txt")
        if not os.path.exists(path):
            return 0
        with open(path, encoding="utf-8") as handle:
            return len([line for line in handle if line.strip()])

    def received_prompt(self):
        path = os.path.join(self.run_dir, "prompt.txt")
        if not os.path.exists(path):
            return ""
        with open(path, encoding="utf-8") as handle:
            return handle.read()


def run_worker(fixture, *extra):
    """Run the REAL worker once, as a CLI, with the fixture HOME."""
    argv = [
        sys.executable,
        "-B",
        WORKER,
        "--once",
        "--home",
        fixture.home,
        "--timeout",
        "10",
        "--limit",
        "10",
        "--lease-seconds",
        "30",
        *extra,
    ]
    completed = subprocess.run(
        argv,
        capture_output=True,
        text=True,
        timeout=120,
        stdin=subprocess.DEVNULL,
        env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"},
    )
    return completed.returncode, completed.stdout + completed.stderr


# ---------------------------------------------------------------------------------------------
# arms
# ---------------------------------------------------------------------------------------------

# The members the pre-CF-211 builder emitted. A3 strips exactly these from a real envelope, so the
# red proof cannot drift from the producer it is about.
PRE_FIX_MEMBERS = (
    "env_version",
    "dispatch_id",
    "corr_id",
    "status",
    "host_identity",
    "harness",
    "vars",
    "exit_codes",
    "gate_exit",
    "branch",
    "commit",
    "artifacts",
    "wall_s",
    "finished_at",
)
CF211_MEMBERS = ("ok", "error", "reply_b64", "in_reply_to")


class Rig(unittest.TestCase):
    """One stub relay, one node HOME, and the REAL worker CLI for every arm."""

    def setUp(self):
        self.root = tempfile.mkdtemp(prefix="cf211-result-")
        self.addCleanup(shutil.rmtree, self.root, ignore_errors=True)
        self.relay = Relay()
        self.addCleanup(self.relay.close)
        self.fixture = Fixture(self.root, self.relay.url)
        self.output = ""

    # -- helpers ---------------------------------------------------------------------------
    def run_once(self, *extra):
        code, output = run_worker(self.fixture, *extra)
        self.output += output
        return code, output

    def delivered_payload(self, index=0):
        deliveries = self.relay.delivered()
        self.assertTrue(
            deliveries, f"nothing was delivered to the relay: {self.output}"
        )
        return deliveries[index]["body"]["payload"]

    def assert_delivered_before_acked(self):
        order = self.relay.order()
        self.assertIn("deliver", order, f"no deliver request: {order} {self.output}")
        self.assertIn("ack", order, f"no ack request: {order} {self.output}")
        self.assertLess(
            order.index("deliver"),
            order.index("ack"),
            f"the dispatch was acked BEFORE its result was delivered: {order}",
        )


class BusResultDeliveryTest(Rig):
    # -- A1 --------------------------------------------------------------------------------
    def test_a1_completed_result_reaches_the_scheduler_inbox(self):
        """A1  completed run: envelope with corr_id + dispatch_id to reply_to, then the ack"""
        dispatch = dispatch_envelope("d-a1", self.fixture.corr_id, reply_to="scheduler")
        self.relay.seed(self.fixture.message_id, dispatch)

        code, output = self.run_once()
        self.assertEqual(0, code, f"a completed run did not exit 0: {output}")
        self.assertIn("BUS WORKER: OK", output)

        deliveries = self.relay.delivered()
        self.assertEqual(
            1,
            len(deliveries),
            f"expected one result delivery, got {len(deliveries)}: {output}",
        )
        self.assertEqual(
            "/agents/scheduler/inbox",
            deliveries[0]["path"],
            "the result was not addressed to the dispatch's reply_to",
        )
        body = deliveries[0]["body"]
        self.assertEqual(
            "fixture-node", body.get("sender"), "the deliver body names no sender"
        )
        self.assertEqual(
            self.fixture.corr_id,
            body.get("request_id"),
            "request_id is not the corr_id",
        )
        self.assertTrue(
            str(body.get("idempotency_key") or "").endswith(":result"),
            f"the delivery carries no stable idempotency key: {body.get('idempotency_key')!r}",
        )

        payload = body["payload"]
        self.assertEqual(self.fixture.corr_id, payload.get("corr_id"))
        self.assertEqual("d-a1", payload.get("dispatch_id"))
        self.assertEqual(
            self.fixture.message_id,
            payload.get("in_reply_to"),
            "the result does not name the relay message the dispatch arrived under",
        )
        self.assertIs(
            True, payload.get("ok"), f"a completed run did not say ok: {payload}"
        )
        self.assertEqual("completed", payload.get("status"))

        text = unb64(payload["reply_b64"])
        self.assertIn("node result: completed", text)
        self.assertIn(
            "shipped CF-211", text, "the harness report did not reach reply_b64"
        )

        self.assert_delivered_before_acked()
        self.assertEqual(
            [[self.fixture.message_id]],
            [ack.get("message_ids") for ack in self.relay.acks()],
            "the ack did not name exactly the delivered message",
        )
        self.assertEqual(DIRECTIVE, self.fixture.received_prompt())

        received = consumer_await(
            [{"payload": payload}],
            {"corr_id": self.fixture.corr_id, "message_id": self.fixture.message_id},
        )
        self.assertEqual(
            "completed",
            received["state"],
            f"the scheduler's model did not complete the tick: {received}",
        )
        self.assertIn(
            "shipped CF-211", received["text"], "the tick carries no reply text"
        )

    # -- A2 --------------------------------------------------------------------------------
    def test_a2_failed_gate_result_fails_the_tick_with_the_nodes_reason(self):
        """A2  failing gate: ok=false + the node's reason, and the tick FAILS (not completes)"""
        gate = {"cmd": "exit 7", "expect_exit": 0}
        dispatch = dispatch_envelope(
            "d-a2", self.fixture.corr_id, reply_to="scheduler", gate=gate
        )
        self.relay.seed(self.fixture.message_id, dispatch)

        code, output = self.run_once()
        self.assertNotEqual(0, code, f"a failed run exited 0: {output}")
        self.assertIn("BUS WORKER: FAIL", output)

        payload = self.delivered_payload()
        self.assertIs(
            False,
            payload.get("ok"),
            f"a failed run did not say ok=false — the scheduler reads `ok`, not `status`: "
            f"{payload}",
        )
        self.assertEqual("failed", payload.get("status"))
        self.assertIn(
            "exit 7", str(payload.get("error") or ""), "the reason is not in `error`"
        )
        self.assertIn("gate", str(payload.get("error") or ""))
        self.assertIn("exit 7", unb64(payload["reply_b64"]))

        # A failure is still DELIVERED and then acked: withholding the ack would loop the work.
        self.assert_delivered_before_acked()

        received = consumer_await(
            [{"payload": payload}],
            {"corr_id": self.fixture.corr_id, "message_id": self.fixture.message_id},
        )
        self.assertEqual(
            "failed",
            received["state"],
            f"the scheduler's model completed a failed run: {received}",
        )
        self.assertIn(
            "exit 7",
            received["text"],
            f"the tick's failure text does not carry the node's reason: {received['text']!r}",
        )

    # -- A3 --------------------------------------------------------------------------------
    def test_a3_pre_cf211_envelope_reads_as_success(self):
        """A3  the pre-CF-211 envelope (no `ok`) reads as SUCCESS — the red this arm detects"""
        gate = {"cmd": "exit 7", "expect_exit": 0}
        dispatch = dispatch_envelope(
            "d-a3", self.fixture.corr_id, reply_to="scheduler", gate=gate
        )
        self.relay.seed(self.fixture.message_id, dispatch)
        self.run_once()
        payload = self.delivered_payload()

        # The strip is faithful or the red proves nothing: every pre-fix member is present, and
        # the only members removed are the ones this row added.
        for name in PRE_FIX_MEMBERS:
            self.assertIn(
                name, payload, f"the envelope lost the pre-fix member {name!r}"
            )
        for name in CF211_MEMBERS:
            self.assertIn(
                name, payload, f"the envelope lost the CF-211 member {name!r}"
            )
        pre_fix = {name: payload[name] for name in PRE_FIX_MEMBERS}
        self.assertEqual("failed", pre_fix["status"])

        verdict, _why = consumer_verdict(pre_fix)
        self.assertTrue(
            verdict,
            "the pre-fix envelope was NOT read as a success — the arm no longer reproduces the "
            "defect it exists for",
        )
        received = consumer_await(
            [{"payload": pre_fix}],
            {"corr_id": self.fixture.corr_id, "message_id": self.fixture.message_id},
        )
        self.assertEqual(
            "completed",
            received["state"],
            f"the pre-fix strip no longer completes a failed run: {received}",
        )
        # And the same fixture with `ok` present is a failure: the arm discriminates on `ok`.
        verdict, why = consumer_verdict(payload)
        self.assertFalse(verdict, "the fixed envelope was read as a success")
        self.assertIn("exit 7", why)

    # -- A4 --------------------------------------------------------------------------------
    def test_a4_mismatched_corr_id_never_completes_the_tick(self):
        """A4  a result naming a DIFFERENT hand-out is never completed, and is named"""
        dispatch = dispatch_envelope("d-a4", "q-lane-foreign", reply_to="scheduler")
        self.relay.seed("msg-foreign", dispatch)
        self.run_once()
        payload = self.delivered_payload()

        # The scheduler is awaiting ITS hand-out: a different corr_id and a different message id.
        receipt = {"corr_id": "q-lane-awaited", "message_id": "msg-awaited"}
        self.assertFalse(
            consumer_correlate(payload, receipt),
            "a result for another hand-out correlated to this one",
        )

        received = consumer_await([{"payload": payload}], receipt)
        self.assertEqual(
            "expired",
            received["state"],
            f"the tick completed on a mismatched corr_id: {received}",
        )
        self.assertNotEqual("completed", received["state"])
        self.assertIn(
            "q-lane-awaited",
            received["error"],
            "the mismatch was not named — the await must name the corr_id it waited for",
        )
        self.assertIn(
            "[dispatch-inbox] seen=1 correlated=0 uncorrelated=1 keys=q-lane-foreign "
            "acked=1 deferred=0",
            received["detail"],
            f"the mismatch was not settled by name: {received['detail']}",
        )

        # A message that names ANOTHER in-flight hand-out is deferred for its owner, not consumed.
        deferred = consumer_await(
            [{"payload": payload}], receipt, outstanding={"q-lane-foreign"}
        )
        self.assertEqual("expired", deferred["state"])
        self.assertIn("acked=0 deferred=1", deferred["detail"])

        # The identity, not the string, is what correlates: a foreign corr_id beside the right
        # in_reply_to IS this hand-out's answer (the scheduler checks that key first).
        same_handout = dict(payload)
        same_handout["corr_id"] = "q-lane-foreign"
        self.assertTrue(
            consumer_correlate(
                same_handout,
                {
                    "corr_id": "q-lane-awaited",
                    "message_id": payload["in_reply_to"],
                },
            ),
            "the relay message id no longer correlates",
        )
        self.assertFalse(
            consumer_correlate(
                {"corr_id": "q-lane-foreign", "in_reply_to": "msg-foreign"},
                receipt,
            ),
            "a message naming neither key correlated",
        )

    # -- A5 --------------------------------------------------------------------------------
    def test_a5_budget_exhaustion_is_retried_not_dropped(self):
        """A5  a 504 leaves the dispatch unacked; the retry re-delivers, never re-runs"""
        dispatch = dispatch_envelope("d-a5", self.fixture.corr_id, reply_to="scheduler")
        self.relay.seed(self.fixture.message_id, dispatch)
        self.relay.state.deliver_modes = ["504", "ok"]

        code, output = self.run_once()
        self.assertNotEqual(0, code, f"a refused delivery exited 0: {output}")
        self.assertIn("FAIL  reply", output)
        self.assertEqual(
            [],
            self.relay.acks(),
            "the dispatch was acked although its result was refused",
        )
        first = self.relay.delivered()[0]["body"]
        self.assertEqual(1, self.fixture.runs())

        # The dispatch comes back (nothing acked it): the retry must re-DELIVER the recorded
        # result, not run the harness again.
        code, output = self.run_once()
        self.assertEqual(0, code, f"the retry did not complete: {output}")
        deliveries = self.relay.delivered()
        self.assertEqual(
            2, len(deliveries), f"expected a retry delivery, got {len(deliveries)}"
        )
        second = deliveries[1]["body"]
        self.assertEqual(
            first.get("idempotency_key"),
            second.get("idempotency_key"),
            "the retry used a different idempotency key, so the relay would store a second result",
        )
        self.assertEqual(
            first["payload"].get("corr_id"), second["payload"].get("corr_id")
        )
        self.assertEqual(
            1,
            self.fixture.runs(),
            "the redelivered dispatch RE-RAN the harness instead of re-sending its result",
        )
        self.assertEqual(
            1, len(self.relay.stored()), "the relay stored more than one result"
        )
        self.assertIn(
            "idempotent", output, f"the redelivery was not recognised: {output}"
        )
        self.assert_delivered_before_acked()

    # -- A6 --------------------------------------------------------------------------------
    def test_a6_lost_answer_still_lands_exactly_once(self):
        """A6  an answer lost after the store: the retry is answered with the FIRST accept"""
        dispatch = dispatch_envelope("d-a6", self.fixture.corr_id, reply_to="scheduler")
        self.relay.seed(self.fixture.message_id, dispatch)
        self.relay.state.deliver_modes = ["drop", "ok"]

        code, output = self.run_once()
        self.assertNotEqual(0, code, f"a lost answer exited 0: {output}")
        self.assertEqual([], self.relay.acks(), "acked without an accepted delivery")
        self.assertEqual(
            1, len(self.relay.stored()), "the relay did not store the result"
        )
        accept_id = self.relay.stored()[0]["id"]

        code, output = self.run_once()
        self.assertEqual(0, code, f"the retry did not complete: {output}")
        self.assertEqual(
            1,
            len(self.relay.stored()),
            "the retry stored a SECOND result for the same dispatch",
        )
        self.assertEqual(1, self.fixture.runs(), "the retry re-ran the harness")
        self.assertEqual(
            accept_id,
            self.relay.stored()[0]["id"],
            "the accepted message id changed on retry",
        )
        self.assert_delivered_before_acked()

    # -- A7 --------------------------------------------------------------------------------
    def test_a7_a_gate_that_could_not_run_is_not_a_pass(self):
        """A7  a gate that could not run is a FAILED result, never a completed tick"""
        dispatch = dispatch_envelope(
            "d-a7", self.fixture.corr_id, reply_to="scheduler", gate={}
        )
        self.relay.seed(self.fixture.message_id, dispatch)

        code, output = self.run_once()
        self.assertIn(
            "FAIL  gate",
            output,
            f"an unrunnable gate did not print a FAIL row: {output}",
        )
        self.assertNotEqual(0, code, "a run whose gate never ran exited 0")
        payload = self.delivered_payload()
        self.assertIs(
            False,
            payload.get("ok"),
            f"a run whose gate never ran said ok: {payload}",
        )
        self.assertEqual("failed", payload.get("status"))
        self.assertIn("gate did not run", str(payload.get("error") or ""))

        received = consumer_await(
            [{"payload": payload}],
            {"corr_id": self.fixture.corr_id, "message_id": self.fixture.message_id},
        )
        self.assertEqual(
            "failed",
            received["state"],
            f"a tick completed on work nobody gated: {received}",
        )


# ---------------------------------------------------------------------------------------------
# the consumer pin — the model above must still be the scheduler's code
# ---------------------------------------------------------------------------------------------

CONSUMER_ANCHORS = (
    (
        'payload["in_reply_to"].(string); s != "" && receipt.MessageID != "" && s == '
        "receipt.MessageID",
        "correlates on the relay message id first",
    ),
    (
        'payload["corr_id"].(string); s != "" && s == receipt.CorrID',
        "correlates on corr_id",
    ),
    ('payload["ok"].(bool); ok && !v', "reads `ok` as the verdict"),
    ("reply_b64", "decodes reply_b64 as the reply text"),
    ("Status: TickCompleted", "completes a tick"),
    ("Status: TickFailed", "fails a tick"),
    ("DispatchStateExpired", "expires the hand-out when nothing correlates"),
)


def scheduler_source():
    for candidate in SCHED_CANDIDATES:
        if not candidate:
            continue
        path = os.path.join(candidate, "internal", "scheduler", "dispatch_leg.go")
        if os.path.isfile(path):
            return path
    return ""


def consumer_pin(failures):
    """Assert the modelled consumer is still the real one. SKIP (loudly) without a checkout."""
    path = scheduler_source()
    if not path:
        print(
            "  SKIP  consumer-pin — no scheduler checkout found "
            "(set CF_SCHEDULER_SRC to internal/scheduler/dispatch_leg.go's repo root); the model "
            "in this file is UNPINNED in this run"
        )
        return
    try:
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
    except OSError as exc:
        failures.append(f"consumer-pin — {path} unreadable ({exc})")
        return
    flat = re.sub(r"\s+", " ", text)
    missing = [why for anchor, why in CONSUMER_ANCHORS if anchor not in flat]
    if missing:
        failures.append(
            f"consumer-pin — {path} no longer {', '.join(missing)}; the model in this test "
            f"describes a consumer the scheduler does not have"
        )
        return
    print(
        f"  PASS  consumer-pin — {len(CONSUMER_ANCHORS)} anchors still hold in "
        f"{os.path.basename(path)} (the model matches dispatch_leg.go)"
    )


# ---------------------------------------------------------------------------------------------
# the pre-fix control — run against the revision this row was raised on
#
#   git show 9af58a0:scripts/node-bus-worker.py > /tmp/node-bus-worker.py &&
#   CF_BUS_WORKER_SOURCE=/tmp/node-bus-worker.py CF_BUS_RESULT_PREFIX_CONTROL=1 \
#       python3 tests/test_bus_result_delivery.py
#
# It asserts the DEFECT: no `ok` on the envelope, no `in_reply_to`, no relay idempotency key —
# and therefore a failed run read as a completed tick, and a refused delivery re-running the
# harness. Pointed at the fixed worker these arms fail, so the pair discriminates.
#
# Under a bare `unittest discover` this class would be graded against the CURRENT (fixed) worker
# and fail by construction, so the whole class skips without its control env: a reader sees WHY
# and the exact command that makes the arms execute.
# ---------------------------------------------------------------------------------------------


@unittest.skipUnless(
    PREFIX_CONTROL,
    "pre-fix control arm: asserts a PRE-FIX worker, so it needs the control env; run "
    "tests/selftest.sh or CF_BUS_WORKER_SOURCE=<pre-fix node-bus-worker.py> "
    "CF_BUS_RESULT_PREFIX_CONTROL=1 python3 tests/test_bus_result_delivery.py",
)
# ch:trace row=CF-396 spec=docs/handbook/OUTLINE.md#VIII.5:chapter-unwritten-recorded-as-finding test=tests/test_bus_result_delivery.py::PreFixControlTest doc=none:chapter-gap-filed-separately evidence=A1,A2,A3 in commit body witness=none:reason no-external-surface verdict=none:reason foreman-runs-gitreins commit=none:reason-no-sha-in-own-body memory=none:reason
class PreFixControlTest(Rig):
    def test_p1_envelope_carries_no_ok_and_no_in_reply_to(self):
        """P1  pre-fix: the delivered envelope has no `ok`, no in_reply_to, no relay key"""
        dispatch = dispatch_envelope("d-p1", self.fixture.corr_id, reply_to="scheduler")
        self.relay.seed(self.fixture.message_id, dispatch)
        code, output = self.run_once()
        self.assertEqual(0, code, f"the pre-fix worker did not run: {output}")

        body = self.relay.delivered()[0]["body"]
        self.assertNotIn(
            "ok", body["payload"], f"the pre-fix envelope already carried `ok`: {body}"
        )
        self.assertNotIn(
            "in_reply_to",
            body["payload"],
            f"the pre-fix envelope already carried in_reply_to: {body}",
        )
        self.assertFalse(
            body.get("idempotency_key"),
            f"the pre-fix delivery already carried an idempotency key: {body}",
        )

    def test_p2_a_failed_gate_completes_the_tick_as_success(self):
        """P2  pre-fix: a FAILED gate is read as a completed tick (the defect CF-211 is about)"""
        gate = {"cmd": "exit 7", "expect_exit": 0}
        dispatch = dispatch_envelope(
            "d-p2", self.fixture.corr_id, reply_to="scheduler", gate=gate
        )
        self.relay.seed(self.fixture.message_id, dispatch)
        self.run_once()
        payload = self.delivered_payload()
        self.assertEqual("failed", payload.get("status"), "the run did not fail")
        received = consumer_await(
            [{"payload": payload}],
            {"corr_id": self.fixture.corr_id, "message_id": self.fixture.message_id},
        )
        self.assertEqual(
            "completed",
            received["state"],
            f"the pre-fix worker already failed the tick ({received}) — the control no longer "
            f"reproduces the defect",
        )

    def test_p3_a_refused_delivery_re_runs_the_harness(self):
        """P3  pre-fix: a 504 then redelivery RE-RUNS the work instead of re-sending the result"""
        dispatch = dispatch_envelope("d-p3", self.fixture.corr_id, reply_to="scheduler")
        self.relay.seed(self.fixture.message_id, dispatch)
        self.relay.state.deliver_modes = ["504", "ok"]
        self.run_once()
        self.run_once()
        self.assertEqual(
            2,
            self.fixture.runs(),
            "the pre-fix worker already refused to re-run the harness — the control no longer "
            "reproduces the defect",
        )


ARMS = (
    "test_a1_completed_result_reaches_the_scheduler_inbox",
    "test_a2_failed_gate_result_fails_the_tick_with_the_nodes_reason",
    "test_a3_pre_cf211_envelope_reads_as_success",
    "test_a4_mismatched_corr_id_never_completes_the_tick",
    "test_a5_budget_exhaustion_is_retried_not_dropped",
    "test_a6_lost_answer_still_lands_exactly_once",
    "test_a7_a_gate_that_could_not_run_is_not_a_pass",
)

CONTROL_ARMS = (
    "test_p1_envelope_carries_no_ok_and_no_in_reply_to",
    "test_p2_a_failed_gate_completes_the_tick_as_success",
    "test_p3_a_refused_delivery_re_runs_the_harness",
)


def run_arms(names, case_class=BusResultDeliveryTest):
    failures = 0
    for name in names:
        case = case_class(name)
        outcome = unittest.TestResult()
        case.run(outcome)
        row = (getattr(case_class, name).__doc__ or name).strip()
        if outcome.wasSuccessful():
            print(f"  PASS  {row}")
            continue
        failures += 1
        print(f"  FAIL  {row}")
        for failed, trace in outcome.failures + outcome.errors:
            for line in trace.strip().splitlines():
                print(f"    | {line}")
    return failures


if __name__ == "__main__":
    print(f"bus result delivery (worker: {os.path.normpath(WORKER)})")
    if PREFIX_CONTROL:
        print("  mode  PRE-FIX CONTROL — these arms assert the defect, not the fix")
        sys.exit(1 if run_arms(CONTROL_ARMS, PreFixControlTest) else 0)
    problems = []
    consumer_pin(problems)
    for problem in problems:
        print(f"  FAIL  {problem}")
    sys.exit(1 if run_arms(ARMS) + len(problems) else 0)
