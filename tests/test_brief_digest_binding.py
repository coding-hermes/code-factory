#!/usr/bin/env python3
"""Hermetic tests for the `brief.digest` trust boundary on the receiving side (CF-275).

`scripts/node-bus-worker.py` verified `brief.digest` as sha256 over the directive TEXT alone
(`:1045-1066`), while `run_gate()` (`:936-955`) hands `gate.cmd` to `/bin/sh -lc` in the clone.
A brief whose gate was altered in flight therefore passed verification and then executed
attacker-chosen shell. The digest bound the prose and not the executable.

These arms hold the worker to the cf-brief-v1 contract, and each one is an assertion about a SIDE
EFFECT — a marker the gate wrote, or failed to write — not about what the worker said it would do:

  B1 green  a bound digest (text+gate+repo+ref) is accepted, the gate RUNS, the harness runs
  B2 red    the same valid brief with ONLY gate.cmd altered is refused by the named
            `brief_digest` row; neither the gate nor the harness ever runs
  B3 red    a legacy text-only digest beside a gate is refused, and the message names the scheme
  B4 green  a legacy text-only digest is still accepted on a brief with NO gate (nothing outside
            the text executes, so the digest is complete for its purpose)
  B5 red    a gate with no digest at all is refused — an unbound executable is never run
  B6 green  sender and node agree: equivalent spellings hash the same, every bound member changes
            the digest, the canonical bytes are pinned, and `--print-brief-digest` prints the value
            the node accepts

Run directly: `python3 tests/test_brief_digest_binding.py` — exit 0 on success, 1 on failure.
No network, no credential, no install; every fixture lives under `mktemp -d`.

The pre-fix control points the SAME fixture at another worker source, so the red needs no second
copy of the arms:

  CF_BUS_WORKER_SOURCE=/tmp/.../node-bus-worker.py CF_BRIEF_DIGEST_PREFIX_CONTROL=1 \\
      python3 tests/test_brief_digest_binding.py

which asserts that revision RUNS a gate whose cmd was changed after the digest was minted. A
fixture that cannot reproduce the defect it was written for is decoration.
"""

from __future__ import annotations

import base64
import contextlib
import copy
import hashlib
import importlib.util
import io
import json
import os
import shlex
import shutil
import subprocess
import sys
import tempfile
import types
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_WORKER = os.path.join(HERE, os.pardir, "scripts", "node-bus-worker.py")
WORKER = os.environ.get("CF_BUS_WORKER_SOURCE") or DEFAULT_WORKER
PREFIX_CONTROL = os.environ.get("CF_BRIEF_DIGEST_PREFIX_CONTROL") == "1"


def load_worker():
    """Import the worker source, whose filename is not a valid module name."""
    spec = importlib.util.spec_from_file_location("cf_bus_worker_cf275", WORKER)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


WORKER_MOD = load_worker()

DIRECTIVE = (
    'You are the foreman for lane "code-factory".\n'
    "\n"
    "Costs $5 per row and $HOME stays a literal dollar-sign word.\n"
    '  - a quoted body: {"status": "pending"}\n'
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


def text_only_digest(text):
    """The pre-CF-275 definition: sha256 over the directive text alone."""
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


class RecordingIdentity:
    """The slice of the node identity `process()` reads, with a harness that records its prompt."""

    def __init__(self, home, repo, stub, got, marker):
        self.home = home
        self.repo_path = repo
        self.project = "code-factory"
        self.harness_name = "fixture-recorder"
        self.stub = stub
        self.got = got
        self.marker = marker
        self.received = []

    def harness_argv(self, prompt):
        self.received.append(prompt)
        return [sys.executable, "-B", self.stub, prompt, self.got, self.marker]


class BriefDigestBindingTest(unittest.TestCase):
    def setUp(self):
        self.home = tempfile.mkdtemp(prefix="cf275-brief-")
        self.addCleanup(shutil.rmtree, self.home, ignore_errors=True)
        self.repo = os.path.join(self.home, "repo")
        os.makedirs(self.repo)
        self.got = os.path.join(self.home, "harness-prompt.txt")
        self.marker = os.path.join(self.home, "harness-started.txt")
        # The gate's side effect. It must exist ONLY if the shell actually ran.
        self.gate_marker = os.path.join(self.home, "gate-started.txt")
        self.stub = os.path.join(self.home, "record_harness.py")
        with open(self.stub, "w", encoding="utf-8") as handle:
            handle.write(STUB)
        self.ident = RecordingIdentity(
            self.home, self.repo, self.stub, self.got, self.marker
        )
        self.args = types.SimpleNamespace(dry_run=False, harness_wall=30)
        self.output = ""

    # -- dispatch builders -------------------------------------------------

    def gate(self, payload="gate-ran"):
        """A gate whose only observable effect is the marker file, so absence proves it never ran."""
        return {
            "cmd": f"printf {shlex.quote(payload)} > {shlex.quote(self.gate_marker)}",
            "expect_exit": 0,
        }

    def dispatch(self, gate_payload="gate-ran", digest="bound", gate=None):
        """A dispatch carrying text, gate, repo and ref. `digest` picks which scheme to mint."""
        dispatch = {
            "dispatch_id": "cf275-a",
            "corr_id": "lane-cf275-a",
            "lane": "code-factory",
            "repo": "https://example.invalid/code-factory.git",
            "ref": "main",
            "text_b64": b64(DIRECTIVE),
            "gate": self.gate(gate_payload) if gate is None else gate,
        }
        if digest == "bound":
            dispatch["brief"] = {
                "digest": WORKER_MOD.brief_digest(dispatch, DIRECTIVE),
                "bytes": len(DIRECTIVE.encode("utf-8")),
            }
        elif digest == "legacy":
            dispatch["brief"] = {
                "digest": text_only_digest(DIRECTIVE),
                "bytes": len(DIRECTIVE.encode("utf-8")),
            }
        return dispatch

    # -- runner ------------------------------------------------------------

    def run_dispatch(self, dispatch):
        buffer = io.StringIO()
        with contextlib.redirect_stdout(buffer):
            outcome = WORKER_MOD.process(dispatch, self.ident, None, self.args, {})
        self.output = buffer.getvalue()
        return outcome

    def gate_ran(self):
        return os.path.exists(self.gate_marker)

    def gate_bytes(self):
        with open(self.gate_marker, "rb") as handle:
            return handle.read()

    def harness_started(self):
        return os.path.exists(self.marker)

    # -- arms --------------------------------------------------------------

    def test_b1_bound_digest_is_accepted_and_the_gate_runs(self):
        """B1  bound digest over text+gate+repo+ref -> accepted, the gate RUNS, harness runs"""
        rows_ok, result, ack = self.run_dispatch(self.dispatch())
        self.assertIsNotNone(result, f"a bound brief produced no result: {self.output}")
        self.assertTrue(rows_ok, f"a bound brief was not accepted: {self.output}")
        self.assertEqual("completed", result.get("status"), f"status: {self.output}")
        self.assertNotIn(
            "refused_by", result, f"a valid brief was refused: {self.output}"
        )
        self.assertTrue(self.harness_started(), f"the harness never ran: {self.output}")
        self.assertTrue(
            self.gate_ran(), f"the gate never ran on a valid brief: {self.output}"
        )
        self.assertEqual(b"gate-ran", self.gate_bytes(), "the gate ran something else")
        self.assertEqual(0, result.get("gate_exit"), f"gate exit: {self.output}")
        self.assertIn("  PASS  brief_digest — ", self.output)
        self.assertIn(
            "cf-brief-v1",
            self.output,
            f"the row does not name the scheme: {self.output}",
        )

    def test_b2_altering_only_gate_cmd_is_refused_and_the_gate_never_runs(self):
        """B2  only gate.cmd altered -> named `brief_digest` refusal, gate and harness never run"""
        dispatch = self.dispatch()
        # EVERY other byte is identical to B1: the text, the repo/ref, brief.bytes, the digest.
        dispatch["gate"] = self.gate("tampered-by-in-flight-editor")
        rows_ok, result, ack = self.run_dispatch(dispatch)
        self.assertFalse(rows_ok, "a brief with a rewritten gate.cmd was accepted")
        self.assertEqual(
            "refused",
            result.get("status"),
            f"status: {result.get('status')!r} {self.output}",
        )
        self.assertEqual(
            "brief_digest",
            result.get("refused_by"),
            f"the refusal is not the named brief_digest one: {result.get('refused_by')!r}",
        )
        self.assertIn(
            "  FAIL  brief_digest — ",
            self.output,
            f"the refusal was not printed as a named brief_digest row: {self.output}",
        )
        self.assertFalse(
            self.gate_ran(), f"the altered gate RAN — the defect is live: {self.output}"
        )
        self.assertFalse(
            self.harness_started(), "the harness ran on a brief with an altered gate"
        )
        self.assertEqual(
            [], self.ident.received, "the harness command was built for a refused brief"
        )

    def test_b3_legacy_text_only_digest_beside_a_gate_is_refused(self):
        """B3  legacy sha256(text) with a gate present -> refused by name, scheme named in the row"""
        rows_ok, result, ack = self.run_dispatch(self.dispatch(digest="legacy"))
        self.assertFalse(rows_ok, "a gate was executed under a text-only digest")
        self.assertEqual("refused", result.get("status"), f"status: {self.output}")
        self.assertEqual(
            "brief_digest",
            result.get("refused_by"),
            f"the refusal is not brief_digest: {result.get('refused_by')!r}",
        )
        text = result.get("refusal", "")
        self.assertIn(
            "legacy text-only digest",
            text,
            f"the refusal does not name the legacy scheme: {text!r}",
        )
        self.assertIn(
            "cf-brief-v1",
            text,
            f"the refusal does not name the scheme to send: {text!r}",
        )
        self.assertIn("  FAIL  brief_digest — ", self.output)
        self.assertFalse(self.gate_ran(), "a legacy-digest gate ran anyway")
        self.assertFalse(
            self.harness_started(), "the harness ran under a legacy digest"
        )

    def test_b4_legacy_digest_without_a_gate_still_runs(self):
        """B4  legacy text-only digest on a brief with NO gate is still accepted (documented)"""
        dispatch = self.dispatch(digest="legacy")
        del dispatch["gate"]
        rows_ok, result, ack = self.run_dispatch(dispatch)
        self.assertTrue(
            rows_ok, f"a gate-less legacy digest stopped working: {self.output}"
        )
        self.assertEqual("completed", result.get("status"), f"status: {self.output}")
        self.assertTrue(self.harness_started(), "the harness did not run")
        self.assertFalse(self.gate_ran(), "a gate ran on a dispatch that carried none")
        self.assertIn("legacy sha256(text)", self.output)

    def test_b5_a_gate_with_no_digest_is_refused(self):
        """B5  gate present, brief.digest absent -> refused: an unbound executable is never run"""
        rows_ok, result, ack = self.run_dispatch(self.dispatch(digest="none"))
        self.assertFalse(rows_ok, "a gate with no digest at all was executed")
        self.assertEqual("refused", result.get("status"), f"status: {self.output}")
        self.assertEqual(
            "brief_digest",
            result.get("refused_by"),
            f"the refusal is not brief_digest: {result.get('refused_by')!r}",
        )
        self.assertIn("no brief.digest", result.get("refusal", ""))
        self.assertFalse(self.gate_ran(), "an unbound gate ran")
        self.assertFalse(
            self.harness_started(), "the harness ran without an integrity check"
        )

    def test_b6_sender_and_node_agree_on_the_canonical_bytes(self):
        """B6  equivalent spellings hash alike, every bound member changes the digest, the CLI agrees"""
        # The canonical bytes are pinned: an independent sender implements THIS, not a guess.
        minimal = {
            "text_b64": b64("hello"),
            "repo": "https://example.invalid/r.git",
            "ref": "main",
            "vars": {"CF_LANE": "x"},
            "gate": {"cmd": "go test ./...", "expect_exit": 0, "timeout_s": None},
        }
        pinned = (
            b'{"gate":{"cmd":"go test ./...","expect_exit":0,"timeout_s":null},'
            b'"ref":"main","repo":"https://example.invalid/r.git","scheme":"cf-brief-v1",'
            b'"text":"hello","vars":{"CF_LANE":"x"},"workdir":null}'
        )
        self.assertEqual(
            pinned,
            WORKER_MOD.brief_canonical_bytes(minimal, "hello"),
            "the canonical JSON form a sender must reproduce changed",
        )
        self.assertEqual(
            hashlib.sha256(pinned).hexdigest(),
            WORKER_MOD.brief_digest(minimal, "hello"),
        )

        # Equivalent spellings: member order, and a gate that omits expect_exit (= 0).
        reordered = {
            "gate": {"cmd": "go test ./...", "timeout_s": None},
            "ref": "main",
            "repo": "https://example.invalid/r.git",
            "vars": {"CF_LANE": "x"},
            "text_b64": b64("hello"),
        }
        self.assertEqual(
            WORKER_MOD.brief_digest(minimal, "hello"),
            WORKER_MOD.brief_digest(reordered, "hello"),
            "a sender that omits the defaulted expect_exit disagrees with the node",
        )

        # A falsy timeout is the wall-limit fallback either way, so it hashes like an absent one.
        zero_timeout = copy.deepcopy(reordered)
        zero_timeout["gate"] = {"cmd": "go test ./...", "timeout_s": 0}
        self.assertEqual(
            WORKER_MOD.brief_digest(minimal, "hello"),
            WORKER_MOD.brief_digest(zero_timeout, "hello"),
            "a falsy gate.timeout_s disagrees with a null one, though the node treats them alike",
        )

        # Every bound member changes the digest; nothing else in the dispatch does.
        base = self.dispatch()
        base_digest = WORKER_MOD.brief_digest(base, DIRECTIVE)
        mutations = {
            "text": {"text_b64": b64(DIRECTIVE + "one more line\n")},
            "gate.cmd": {"gate": self.gate("other")},
            "gate.expect_exit": {"gate": dict(self.gate(), expect_exit=1)},
            "repo": {"repo": "https://example.invalid/other.git"},
            "ref": {"ref": "node/cf275"},
            "workdir": {"workdir": self.repo},
            "vars": {"vars": {"CF_MODEL": "other/model"}},
        }
        for label, change in mutations.items():
            with self.subTest(member=label):
                altered = copy.deepcopy(base)
                altered.update(change)
                text = DIRECTIVE + "one more line\n" if label == "text" else DIRECTIVE
                self.assertNotEqual(
                    base_digest,
                    WORKER_MOD.brief_digest(altered, text),
                    f"changing {label} did not change the digest",
                )
        for label, change in (
            ("dispatch_id", {"dispatch_id": "cf275-other"}),
            ("corr_id", {"corr_id": "lane-cf275-other"}),
            ("brief.bytes", {"brief": {"digest": base["brief"]["digest"], "bytes": 1}}),
        ):
            with self.subTest(unbound=label):
                altered = copy.deepcopy(base)
                altered.update(change)
                self.assertEqual(
                    base_digest,
                    WORKER_MOD.brief_digest(altered, DIRECTIVE),
                    f"{label} is not executed, so it must not be inside the digest",
                )

        # The sender helper agrees with the node: the CLI prints exactly the digest B1 carries.
        path = os.path.join(self.home, "dispatch.json")
        with open(path, "w", encoding="utf-8") as handle:
            json.dump(base, handle)
        completed = subprocess.run(
            [sys.executable, "-B", WORKER, "--print-brief-digest", path],
            capture_output=True,
            text=True,
            timeout=60,
            stdin=subprocess.DEVNULL,
            env=dict(os.environ, PYTHONDONTWRITEBYTECODE="1"),
        )
        self.assertEqual(
            0, completed.returncode, f"--print-brief-digest: {completed.stderr}"
        )
        self.assertEqual(
            base["brief"]["digest"],
            completed.stdout.strip(),
            "the sender helper prints a digest the node would refuse",
        )

    def test_p0_prefix_control_runs_a_gate_altered_after_the_digest(self):
        """P0  the PRE-FIX worker runs the gate whose cmd was altered (the defect reproduces)"""
        dispatch = self.dispatch(digest="legacy")
        # The attacker rewrote gate.cmd in flight; the digest still covers the untouched text.
        dispatch["gate"] = self.gate("tampered-by-in-flight-editor")
        rows_ok, result, ack = self.run_dispatch(dispatch)
        self.assertTrue(
            rows_ok, f"the pre-fix source refused the tampered dispatch: {self.output}"
        )
        self.assertNotIn(
            "refused_by", result, f"the pre-fix source refused by name: {result}"
        )
        self.assertTrue(
            self.gate_ran(),
            f"the pre-fix source did not run the altered gate: {self.output}",
        )
        self.assertEqual(
            b"tampered-by-in-flight-editor",
            self.gate_bytes(),
            "the pre-fix source ran something other than the altered gate",
        )


ARMS = (
    "test_b1_bound_digest_is_accepted_and_the_gate_runs",
    "test_b2_altering_only_gate_cmd_is_refused_and_the_gate_never_runs",
    "test_b3_legacy_text_only_digest_beside_a_gate_is_refused",
    "test_b4_legacy_digest_without_a_gate_still_runs",
    "test_b5_a_gate_with_no_digest_is_refused",
    "test_b6_sender_and_node_agree_on_the_canonical_bytes",
)
PREFIX_ARM = "test_p0_prefix_control_runs_a_gate_altered_after_the_digest"


def run_arms(names):
    """Run each arm as its own unittest case and print one PASS/FAIL row per arm."""
    failures = 0
    for name in names:
        case = BriefDigestBindingTest(name)
        outcome = unittest.TestResult()
        case.run(outcome)
        row = (getattr(BriefDigestBindingTest, name).__doc__ or name).strip()
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
    print(f"brief digest binding (worker: {os.path.normpath(WORKER)})")
    sys.exit(1 if run_arms(chosen) else 0)
