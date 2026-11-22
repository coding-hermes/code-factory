#!/usr/bin/env python3
"""CF-131 live probe — the same reply is refused with the task body present, accepted stripped.

Posts ONE result envelope twice to a relay that speaks crier's documented inboxDeliver surface
and carries crier's prompt-injection guard (docs: specs/ENVELOPE.md §Reserved field names —
`"(system|instructions|prompt|tools|schema)"\\s*:` → `403 GUARD_BLOCKED`; the pre-match scans the
whole payload, so an escaped control-key shape inside a string value matches `stringified_json`
and blocks the same way):

  arm R  (task body present)  the reply's plain `reply` member echoes the dispatch text — the
          pre-CF-131 completion shape — expected: HTTP 403, `error: GUARD_BLOCKED`
  arm A  (task body stripped) the SAME reply with the task text removed and the report carried in
          base64 `reply_b64` — the dispatcher's current shape (in_reply_to, agent, ok, seconds,
          task_len, reply_b64, reply_len) — expected: HTTP 201 accepted

Re-runnable: every run builds a fresh relay on an ephemeral loopback port and prints the observed
status codes and bodies. Exit 0 iff both arms behave. The guard table is pinned to crier's
shipped seed table when a checkout is present (env CF_CRIER_PATTERNS_SRC), and never silently
unpinned.

Run: `python3 -B tests/probe_cf131_guard_roundtrip.py`   (no network, no credential)
"""

from __future__ import annotations

import base64
import http.server
import json
import os
import re
import sys
import threading
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, os.pardir))
CRIER_PATTERNS = os.environ.get("CF_CRIER_PATTERNS_SRC") or os.path.expanduser(
    "~/crier/internal/guard/patterns.go"
)

# crier's seed table, transcribed byte-for-byte (internal/guard/patterns.go).
GUARD_PATTERN_TABLE = (
    ("control_keys", r'"(system|instructions|prompt|tools|schema)"\s*:'),
    ("system_role", r'"role"\s*:\s*"system"'),
    ("stringified_json", r'"(\\u00[0-9a-f]{2}|\\")?[^"]*\\"\s*[:{]'),
)
GUARD_PATTERNS = [(name, re.compile(pattern)) for name, pattern in GUARD_PATTERN_TABLE]


def pin_or_complain():
    """PIN the transcription to crier's shipped table; return a complaint string or None."""
    if not os.path.isfile(CRIER_PATTERNS):
        return (
            f"UNPINNED: no crier checkout at {CRIER_PATTERNS} "
            f"(set CF_CRIER_PATTERNS_SRC); the probe's guard is the transcribed table only"
        )
    with open(CRIER_PATTERNS, encoding="utf-8") as handle:
        source = handle.read()
    for name, pattern in GUARD_PATTERN_TABLE:
        if f'{{Name: "{name}", Pattern: `{pattern}`' not in source:
            return (
                f"PIN BROKEN: the stub's {name} pattern is not crier's shipped pattern"
            )
    return None


def guard_scan(text):
    return [name for name, pattern in GUARD_PATTERNS if pattern.search(text)]


# The dispatch text a real work order carries: control-key-shaped lines are ordinary.
TASK_BODY = (
    'You are the foreman for lane "code-factory".\n'
    "## Task\n"
    'Fix the completion path. config/tools.json maps {"prompt": "hermes -z"} to the\n'
    "harness argv; the reply carries `tools:` and `schema` members.\n"
)
REPORT = "node result: completed — dispatch=d-1 exit=0 branch=node/crier/d-1 wall=14.9s"


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.0"

    def log_message(self, fmt, *args):  # noqa: A003 - keep the probe output readable
        return

    def _json(self, status, payload):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):  # noqa: N802 - BaseHTTPRequestHandler's spelling
        if not self.path.endswith("/inbox"):
            self._json(404, {"error": "no such route"})
            return
        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length) if length else b""
        try:
            body = json.loads(raw) if raw else {}
        except ValueError:
            body = {}
        payload_text = json.dumps(body.get("payload"), separators=(",", ":"))
        matched = guard_scan(payload_text)
        if matched:
            self._json(
                403,
                {"error": "GUARD_BLOCKED", "guard": {"matched_patterns": matched}},
            )
            return
        self._json(201, {"id": "probe-accept-1", "transport": "inbox"})


def post_envelope(url, envelope, sender="probe-node", key="probe:result"):
    body = json.dumps(
        {
            "payload": envelope,
            "sender": sender,
            "request_id": str(envelope.get("corr_id") or ""),
            "idempotency_key": key,
        },
        separators=(",", ":"),
    ).encode()
    request = urllib.request.Request(
        f"{url}/agents/scheduler/inbox", data=body, method="POST"
    )
    try:
        with urllib.request.urlopen(request, timeout=10) as answer:
            return answer.status, answer.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as error:
        return error.code, error.read().decode("utf-8", "replace")


def main():
    print(f"CF-131 guard round-trip probe (patterns: {CRIER_PATTERNS})")
    complaint = pin_or_complain()
    pin_text = complaint or "PASS — the guard table is crier's shipped seed table"
    print(f"  pin   {pin_text}")
    if complaint and "PIN BROKEN" in complaint:
        return 1

    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    url = f"http://{server.server_address[0]}:{server.server_address[1]}"
    failures = 0

    # Arm R — the reply echoes the task body in a PLAIN member (the pre-CF-131 shape).
    echo = {
        "env_version": 1,
        "in_reply_to": "msg-probe-1",
        "corr_id": "q-probe-1",
        "agent": "probe-node",
        "ok": True,
        "seconds": 14.9,
        "task_len": len(TASK_BODY),
        "reply": TASK_BODY + REPORT,
    }
    status, answer = post_envelope(url, echo)
    observed = guard_scan(json.dumps(echo, separators=(",", ":")))
    refused = status == 403 and "GUARD_BLOCKED" in answer
    failures += 0 if refused else 1
    print(
        f"  arm R task-body-present -> {status:03d} {answer.strip()} "
        f"(matched: {','.join(observed) or 'none'}) -> {'PASS' if refused else 'FAIL'}"
    )

    # Arm A — the SAME reply, task body stripped, report carried in base64 reply_b64.
    stripped = {
        "env_version": 1,
        "in_reply_to": "msg-probe-1",
        "corr_id": "q-probe-1",
        "agent": "probe-node",
        "ok": True,
        "seconds": 14.9,
        "task_len": len(TASK_BODY),
        "reply_b64": base64.b64encode(REPORT.encode("utf-8")).decode("ascii"),
        "reply_len": len(REPORT),
    }
    status, answer = post_envelope(url, stripped, key="probe:result-a")
    accepted = status == 201 and "probe-accept-1" in answer
    failures += 0 if accepted else 1
    print(
        f"  arm A task-body-stripped -> {status:03d} {answer.strip()} "
        f"-> {'PASS' if accepted else 'FAIL'}"
    )

    server.shutdown()
    server.server_close()
    thread.join(timeout=5)
    print(
        f"PROBE: {'PASS' if failures == 0 else 'FAIL'} ({failures} arm(s) misbehaved)"
    )
    print(f"EXIT={failures}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
