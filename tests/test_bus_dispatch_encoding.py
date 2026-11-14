#!/usr/bin/env python3
"""Hermetic tests for the dispatch's wire encoding on the receiving side (CF-354).

`specs/ENVELOPE.md` fixes the instruction member: the scheduler sends the directive as `text_b64`
(base64 of the UTF-8 text), because the reply relay's control-key guard refuses the prose a real
foreman prompt carries. `scripts/node-bus-worker.py` read only `text`, so every dispatch the
scheduler actually sent was refused by this repo's own node with the `brief` row. The live fleet
only worked because a dispatcher outside this repository decodes the member.

These arms hold the worker to the contract, and each one is an assertion about what the harness
RECEIVED, not about what the worker said it would do:

  A1 green  a dispatch carrying only `text_b64` runs; the harness gets exactly the decoded bytes
  A2 green  a dispatch carrying only the legacy `text` still runs (no regression)
  A3 red    a corrupt `text_b64` is refused by the named `text_b64` row; the harness never starts
            and the legacy `text` sitting beside it is never used
  A4 red    a dispatch with no instruction member keeps the existing named `brief` refusal
  A5 red    a `brief.digest` taken over the base64 (not the decoded text) is refused

Run directly: `python3 tests/test_bus_dispatch_encoding.py` — exit 0 on success, 1 on failure.
No network, no credential, no install; every fixture lives under `mktemp -d`.

The pre-fix control points the SAME fixture at another worker source, so the red needs no second
copy of the arms:

  CF_BUS_WORKER_SOURCE=/tmp/.../node-bus-worker.py CF_BUS_DISPATCH_PREFIX_CONTROL=1 \
      python3 tests/test_bus_dispatch_encoding.py

which asserts that revision refuses a `text_b64` dispatch with the named `brief` row. A fixture
that cannot reproduce the defect it was written for is decoration.
"""

from __future__ import annotations

import base64
import contextlib
import hashlib
import importlib.util
import io
import os
import shutil
import sys
import tempfile
import types
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_WORKER = os.path.join(HERE, os.pardir, "scripts", "node-bus-worker.py")
WORKER = os.environ.get("CF_BUS_WORKER_SOURCE") or DEFAULT_WORKER
PREFIX_CONTROL = os.environ.get("CF_BUS_DISPATCH_PREFIX_CONTROL") == "1"


def load_worker():
    """Import the worker source, whose filename is not a valid module name."""
    spec = importlib.util.spec_from_file_location("cf_bus_worker_cf354", WORKER)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


WORKER_MOD = load_worker()

# A directive with the shapes that made the encoding necessary: newlines, quotes, `$`-signs and
# a JSON body the relay's control-key guard would otherwise refuse.
DIRECTIVE = (
    'You are the foreman for lane "code-factory".\n'
    "\n"
    "Costs $5 per row and $HOME stays a literal dollar-sign word.\n"
    '  - a quoted body: {"status": "pending"}\n'
    "  - an apostrophe: it's fine\n"
    "\n"
    "Report a verdict.\n"
)

# Stands in for the harness: it records the prompt it was given and the fact that it started.
STUB = """\
import sys
from pathlib import Path
text, got, marker = sys.argv[1], sys.argv[2], sys.argv[3]
Path(marker).write_text("harness started\\n", encoding="utf-8")
Path(got).write_text(text, encoding="utf-8")
"""


def b64(text):
    return base64.b64encode(text.encode("utf-8")).decode("ascii")


class RecordingIdentity:
    """The slice of the node identity `process()` reads, with a harness that records its prompt."""

    def __init__(self, home, repo, stub, got, marker):
        self.home = home
        self.repo_path = repo
        self.project = "code-factory"
        self.harness_name = "fixture-recorder"
        self.harness_version = "unreported"
        self.duckbrain_url = ""
        self.duckbrain_token_path = os.path.join(self.home, "duckbrain.token")
        self.stub = stub
        self.got = got
        self.marker = marker
        self.received = []

    def harness_argv(self, prompt):
        self.received.append(prompt)
        return [sys.executable, "-B", self.stub, prompt, self.got, self.marker]


class BusDispatchEncodingTest(unittest.TestCase):
    def setUp(self):
        self.home = tempfile.mkdtemp(prefix="cf354-dispatch-")
        self.addCleanup(shutil.rmtree, self.home, ignore_errors=True)
        self.repo = os.path.join(self.home, "repo")
        os.makedirs(self.repo)
        self.got = os.path.join(self.home, "harness-prompt.txt")
        self.marker = os.path.join(self.home, "harness-started.txt")
        self.stub = os.path.join(self.home, "record_harness.py")
        with open(self.stub, "w", encoding="utf-8") as handle:
            handle.write(STUB)
        self.ident = RecordingIdentity(
            self.home, self.repo, self.stub, self.got, self.marker
        )
        # process() reads exactly these two flags off args for the non-dry-run path.
        self.args = types.SimpleNamespace(dry_run=False, harness_wall=30)
        self.output = ""

    def run_dispatch(self, dispatch):
        """Run one dispatch through process(), capturing the worker's rows as text."""
        buffer = io.StringIO()
        with contextlib.redirect_stdout(buffer):
            outcome = WORKER_MOD.process(dispatch, self.ident, None, self.args, {})
        self.output = buffer.getvalue()
        return outcome

    def harness_bytes(self):
        with open(self.got, "rb") as handle:
            return handle.read()

    def harness_started(self):
        return os.path.exists(self.marker)

    def test_a1_text_b64_only_dispatch_runs(self):
        """A1  text_b64-only dispatch runs; the harness receives exactly the decoded bytes"""
        dispatch = {
            "dispatch_id": "cf354-a1",
            "corr_id": "lane-cf354-a1",
            "lane": "code-factory",
            "project_id": "code-factory",
            "round_id": "round-a1",
            "task_id": "task-a1",
            "attempt_id": "attempt-a1",
            "repo": "https://example.invalid/code-factory.git",
            "ref": "main",
            "text_b64": b64(DIRECTIVE),
            "criteria": [],
            "skills": [],
            "attachments": [],
        }
        dispatch["brief"] = {
            "digest": WORKER_MOD.brief_digest(dispatch, DIRECTIVE),
            "bytes": len(DIRECTIVE.encode("utf-8")),
        }
        rows_ok, result, ack = self.run_dispatch(dispatch)
        self.assertIsNotNone(
            result, f"a text_b64 dispatch produced no result: {self.output}"
        )
        self.assertTrue(rows_ok, f"the dispatch did not succeed: {self.output}")
        self.assertEqual(
            "completed",
            result.get("status"),
            f"status was not a success status: {result.get('status')!r} {self.output}",
        )
        self.assertNotIn("refused_by", result, "a decoded dispatch was refused")
        self.assertTrue(self.ident.received, "the harness command was never built")
        self.assertEqual(
            {DIRECTIVE},
            set(self.ident.received),
            "the harness was not handed the decoded directive",
        )
        self.assertEqual(
            DIRECTIVE.encode("utf-8"),
            self.harness_bytes(),
            "the harness received different bytes than the sender encoded",
        )

    def test_a2_legacy_text_still_runs(self):
        """A2  a dispatch carrying only the legacy `text` still runs (no regression)"""
        dispatch = {
            "dispatch_id": "cf354-a2",
            "corr_id": "lane-cf354-a2",
            "project_id": "code-factory",
            "round_id": "round-a2",
            "task_id": "task-a2",
            "attempt_id": "attempt-a2",
            "repo": "https://example.invalid/code-factory.git",
            "ref": "main",
            "text": DIRECTIVE,
            "criteria": [],
            "skills": [],
            "attachments": [],
        }
        dispatch["brief"] = {"digest": WORKER_MOD.brief_digest(dispatch, DIRECTIVE)}
        rows_ok, result, ack = self.run_dispatch(dispatch)
        self.assertTrue(rows_ok, f"the legacy member no longer runs: {self.output}")
        self.assertEqual("completed", result.get("status"), f"status: {self.output}")
        self.assertEqual(
            DIRECTIVE.encode("utf-8"),
            self.harness_bytes(),
            "the harness received different bytes than the sender sent",
        )

    def test_a3_corrupt_text_b64_is_refused_without_fallback(self):
        """A3  corrupt text_b64 -> named `text_b64` refusal, no fallback, harness never started"""
        dispatch = {
            "dispatch_id": "cf354-a3",
            "corr_id": "lane-cf354-a3",
            # `*` and `!` are outside the base64 alphabet, and a valid `text` sits beside it.
            "text_b64": "not*base64!!",
            "text": DIRECTIVE,
        }
        rows_ok, result, ack = self.run_dispatch(dispatch)
        self.assertFalse(rows_ok, "a corrupt text_b64 was reported as a success")
        self.assertEqual(
            "refused", result.get("status"), f"status: {result.get('status')!r}"
        )
        self.assertEqual(
            "text_b64",
            result.get("refused_by"),
            f"the refusal is not the named text_b64 one: {result.get('refused_by')!r}",
        )
        self.assertFalse(
            self.harness_started(), "the harness ran on a corrupt dispatch"
        )
        self.assertEqual(
            [],
            self.ident.received,
            "the legacy `text` was used as a fallback for a corrupt `text_b64`",
        )
        self.assertIn(
            "  FAIL  text_b64 — ",
            self.output,
            f"the refusal was not printed as a named text_b64 row: {self.output}",
        )
        # The other two ways a present text_b64 does not decode are the same named refusal.
        for label, encoded in (
            ("non-UTF-8 bytes", base64.b64encode(b"\xff\xfe\xfa").decode("ascii")),
            ("empty after decode", base64.b64encode(b"  \n\t").decode("ascii")),
            ("not a string", None),
        ):
            with self.subTest(case=label):
                self.assertEqual(
                    ("", "text_b64"),
                    WORKER_MOD.directive_text({"text_b64": encoded}),
                    f"{label} was not refused as text_b64",
                )

    def test_a4_no_instruction_is_the_named_brief_refusal(self):
        """A4  no instruction member -> the existing named `brief` refusal, unchanged"""
        dispatch = {
            "dispatch_id": "cf354-a4",
            "corr_id": "lane-cf354-a4",
            "lane": "code-factory",
        }
        rows_ok, result, ack = self.run_dispatch(dispatch)
        self.assertFalse(
            rows_ok, "a dispatch without an instruction was reported as a success"
        )
        self.assertEqual(
            "refused", result.get("status"), f"status: {result.get('status')!r}"
        )
        self.assertEqual(
            "brief",
            result.get("refused_by"),
            f"the refusal is not the named brief one: {result.get('refused_by')!r}",
        )
        self.assertIn(
            "carries no `text`",
            result.get("refusal", ""),
            f"the absent-instruction wording changed: {result.get('refusal')!r}",
        )
        self.assertFalse(
            self.harness_started(), "the harness ran without an instruction"
        )

    def test_a5_digest_over_the_raw_base64_is_refused(self):
        """A5  brief.digest over the base64 (not the decoded text) is refused by `brief_digest`"""
        encoded = b64(DIRECTIVE)
        dispatch = {
            "dispatch_id": "cf354-a5",
            "corr_id": "lane-cf354-a5",
            "text_b64": encoded,
            "brief": {
                "digest": hashlib.sha256(encoded.encode("utf-8")).hexdigest(),
                "bytes": len(encoded),
            },
        }
        rows_ok, result, ack = self.run_dispatch(dispatch)
        self.assertFalse(rows_ok, "a digest taken over the base64 was accepted")
        self.assertEqual(
            "brief_digest",
            result.get("refused_by"),
            f"the refusal is not brief_digest: {result.get('refused_by')!r}",
        )
        self.assertFalse(
            self.harness_started(), "the harness ran on a mismatched brief"
        )
        self.assertIn(
            "  FAIL  brief_digest — ",
            self.output,
            f"the refusal was not printed as a named brief_digest row: {self.output}",
        )

    @unittest.skipUnless(
        PREFIX_CONTROL,
        "pre-fix control arm: asserts a PRE-FIX worker, so it needs the control env; run "
        "tests/selftest.sh or CF_BUS_WORKER_SOURCE=<pre-fix node-bus-worker.py> "
        "CF_BUS_DISPATCH_PREFIX_CONTROL=1 python3 tests/test_bus_dispatch_encoding.py",
    )
    def test_p0_prefix_control_refuses_text_b64_with_the_brief_row(self):
        """P0  the PRE-FIX source refuses a text_b64 dispatch with the `brief` row (the red)"""
        dispatch = {
            "dispatch_id": "cf354-p0",
            "corr_id": "lane-cf354-p0",
            "text_b64": b64(DIRECTIVE),
            "brief": {
                "digest": hashlib.sha256(DIRECTIVE.encode("utf-8")).hexdigest(),
                "bytes": len(DIRECTIVE.encode("utf-8")),
            },
        }
        rows_ok, result, ack = self.run_dispatch(dispatch)
        self.assertFalse(rows_ok, "the pre-fix source executed a text_b64 dispatch")
        self.assertEqual(
            "brief",
            result.get("refused_by"),
            f"the pre-fix refusal is not the named brief one: "
            f"{result.get('refused_by')!r}",
        )
        self.assertIn(
            "carries no `text`",
            result.get("refusal", ""),
            f"the pre-fix refusal wording changed: {result.get('refusal')!r}",
        )
        self.assertFalse(self.harness_started(), "the pre-fix source ran the harness")


ARMS = (
    "test_a1_text_b64_only_dispatch_runs",
    "test_a2_legacy_text_still_runs",
    "test_a3_corrupt_text_b64_is_refused_without_fallback",
    "test_a4_no_instruction_is_the_named_brief_refusal",
    "test_a5_digest_over_the_raw_base64_is_refused",
)
PREFIX_ARM = "test_p0_prefix_control_refuses_text_b64_with_the_brief_row"


def run_arms(names):
    """Run each arm as its own unittest case and print one PASS/FAIL row per arm."""
    failures = 0
    for name in names:
        case = BusDispatchEncodingTest(name)
        outcome = unittest.TestResult()
        case.run(outcome)
        row = (getattr(BusDispatchEncodingTest, name).__doc__ or name).strip()
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
    chosen = (PREFIX_ARM,) if PREFIX_CONTROL else ARMS
    print(f"bus dispatch encoding (worker: {os.path.normpath(WORKER)})")
    sys.exit(1 if run_arms(chosen) else 0)
