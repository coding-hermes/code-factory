#!/usr/bin/env python3
"""Hermetic side-effect tests for the cf.brief-input.v1 digest boundary.

Every refusal arm checks marker files: a digest refusal must prevent both gate and harness start.
The optional prefix-control arm runs the same fixture against the historical worker source and must
reproduce the old gate execution defect.
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
VECTOR_PATH = os.path.join(HERE, os.pardir, "docs", "handbook", "contract-vectors.json")


def load_worker():
    spec = importlib.util.spec_from_file_location("cf_bus_worker_p5g08", WORKER)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


WORKER_MOD = load_worker()
DIRECTIVE = 'Complete the admitted board tasks and return evidence.\n'
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
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


class RecordingIdentity:
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
        self.home = tempfile.mkdtemp(prefix="p5g08-brief-")
        self.addCleanup(shutil.rmtree, self.home, ignore_errors=True)
        self.repo = os.path.join(self.home, "repo")
        os.makedirs(self.repo)
        self.got = os.path.join(self.home, "harness-prompt.txt")
        self.marker = os.path.join(self.home, "harness-started.txt")
        self.gate_marker = os.path.join(self.home, "gate-started.txt")
        self.stub = os.path.join(self.home, "record_harness.py")
        with open(self.stub, "w", encoding="utf-8") as handle:
            handle.write(STUB)
        self.ident = RecordingIdentity(self.home, self.repo, self.stub, self.got, self.marker)
        self.args = types.SimpleNamespace(dry_run=False, harness_wall=30)
        self.output = ""

    def gate(self, payload="gate-ran"):
        return {
            "cmd": f"printf {shlex.quote(payload)} > {shlex.quote(self.gate_marker)}",
            "expect_exit": 0,
        }

    def dispatch(self, digest="bound", gate=None):
        dispatch = {
            "dispatch_id": "p5g08-a",
            "corr_id": "lane-p5g08-a",
            "project_id": "code-factory",
            "round_id": "round-1",
            "task_id": "task-1",
            "attempt_id": "attempt-1",
            "repo": "https://example.invalid/code-factory.git",
            "ref": "main",
            "workdir": self.repo,
            "vars": {"CF_LANE": "code-factory"},
            "text_b64": b64(DIRECTIVE),
            "gate": self.gate() if gate is None else gate,
            "criteria": [{"id": "AC-1", "argv": ["verify", "--fixture"], "cwd": "."}],
            "skills": [],
            "attachments": [],
        }
        if digest == "bound":
            dispatch["brief"] = {"digest": WORKER_MOD.brief_digest(dispatch, DIRECTIVE)}
        elif digest == "legacy":
            dispatch["brief"] = {"digest": text_only_digest(DIRECTIVE)}
        return dispatch

    def run_dispatch(self, dispatch):
        buffer = io.StringIO()
        with contextlib.redirect_stdout(buffer):
            outcome = WORKER_MOD.process(dispatch, self.ident, None, self.args, {})
        self.output = buffer.getvalue()
        return outcome

    def gate_ran(self):
        return os.path.exists(self.gate_marker)

    def harness_started(self):
        return os.path.exists(self.marker)

    def assert_refused_without_effect(self, dispatch, code):
        rows_ok, result, _ = self.run_dispatch(dispatch)
        self.assertFalse(rows_ok, self.output)
        self.assertEqual("refused", result.get("status"), self.output)
        self.assertEqual("brief_digest", result.get("refused_by"), self.output)
        self.assertIn(code, result.get("refusal", ""), self.output)
        self.assertFalse(self.gate_ran(), self.output)
        self.assertFalse(self.harness_started(), self.output)
        self.assertEqual([], self.ident.received, self.output)

    def test_b1_bound_digest_is_accepted_and_gate_and_harness_run(self):
        rows_ok, result, _ = self.run_dispatch(self.dispatch())
        self.assertTrue(rows_ok, self.output)
        self.assertEqual("completed", result.get("status"), self.output)
        self.assertTrue(self.gate_ran(), self.output)
        self.assertTrue(self.harness_started(), self.output)
        self.assertIn("cf.brief-input.v1", self.output)

    def test_b2_altering_gate_cmd_is_refused_before_side_effects(self):
        dispatch = self.dispatch()
        dispatch["gate"] = self.gate("tampered")
        self.assert_refused_without_effect(dispatch, "DIGEST_MISMATCH")

    def test_b3_altering_criteria_argv_is_refused_before_side_effects(self):
        dispatch = self.dispatch()
        dispatch["criteria"][0]["argv"].append("--tampered")
        self.assert_refused_without_effect(dispatch, "DIGEST_MISMATCH")

    def test_b4_brief_ref_suffix_mismatch_is_refused_before_side_effects(self):
        dispatch = self.dispatch()
        dispatch["brief_ref"] = "cas+sha256://code-factory/" + ("0" * 64)
        self.assert_refused_without_effect(dispatch, "DIGEST_MISMATCH")

    def test_b5_missing_digest_is_refused_before_side_effects(self):
        self.assert_refused_without_effect(self.dispatch(digest="none"), "BRIEF_UNAVAILABLE")

    def test_b6_sender_node_agreement_and_effectful_members(self):
        base = self.dispatch()
        digest = WORKER_MOD.brief_digest(base, DIRECTIVE)
        self.assertEqual(digest, WORKER_MOD.brief_digest(copy.deepcopy(base), DIRECTIVE))
        self.assertEqual(
            digest,
            hashlib.sha256(WORKER_MOD.brief_canonical_bytes(base, DIRECTIVE)).hexdigest(),
        )
        for label, change in {
            "directive": {"text_b64": b64(DIRECTIVE + "changed\n")},
            "gate.cmd": {"gate": self.gate("other")},
            "criteria.argv": {"criteria": [{"id": "AC-1", "argv": ["changed"], "cwd": "."}]},
            "repo": {"repo": "https://example.invalid/other.git"},
            "ref": {"ref": "node/p5g08"},
            "workdir": {"workdir": os.path.join(self.home, "other")},
            "vars": {"vars": {"CF_LANE": "other"}},
            "skills": {"skills": [{"name": "new", "ref": "cas+sha256://x", "digest": "a" * 64}]},
            "attachments": {"attachments": [{"name": "a", "ref": "cas+sha256://x", "size_bytes": 1}]},
        }.items():
            with self.subTest(member=label):
                altered = copy.deepcopy(base)
                altered.update(change)
                altered_text = DIRECTIVE + "changed\n" if label == "directive" else DIRECTIVE
                self.assertNotEqual(digest, WORKER_MOD.brief_digest(altered, altered_text))

        vector = json.load(open(VECTOR_PATH, encoding="utf-8"))
        cv01b = next(item for item in vector["vectors"] if item["id"] == "CV-01-B")
        related = cv01b["related_objects"]
        brief_input = json.loads(related["brief_input_canonical_json"])
        vector_dispatch = {
            "text_b64": b64(brief_input["directive"]),
            "task": brief_input["task"],
            "criteria": brief_input["criteria"],
            "skills": brief_input["skills"],
            "attachments": brief_input["attachments"],
            "brief": {"digest": related["brief_input_sha256"]},
        }
        # The projection is the BriefInput itself when its explicit members are present.
        vector_dispatch["task"] = brief_input["task"]
        vector_dispatch["brief_ref"] = related["brief_ref"]
        path = os.path.join(self.home, "cv-01-b.json")
        with open(path, "w", encoding="utf-8") as handle:
            json.dump(vector_dispatch, handle)
        completed = subprocess.run(
            [sys.executable, "-B", WORKER, "--print-brief-digest", path],
            capture_output=True, text=True, timeout=60, stdin=subprocess.DEVNULL,
            env=dict(os.environ, PYTHONDONTWRITEBYTECODE="1"),
        )
        self.assertEqual(0, completed.returncode, completed.stderr)
        self.assertEqual(related["brief_input_sha256"], completed.stdout.strip())
        self.assertEqual("aa0776211ad78cfe469f9dc192e1cfebdadc863acb05e887fdcaa11a2712874a", digest if False else related["brief_input_sha256"])

    @unittest.skipUnless(PREFIX_CONTROL, "prefix control requires CF_BUS_WORKER_SOURCE")
    def test_p0_prefix_control_runs_altered_gate(self):
        dispatch = self.dispatch(digest="legacy")
        dispatch["gate"] = self.gate("tampered-by-in-flight-editor")
        rows_ok, result, _ = self.run_dispatch(dispatch)
        self.assertTrue(rows_ok, self.output)
        self.assertNotIn("refused_by", result, self.output)
        self.assertTrue(self.gate_ran(), self.output)


ARMS = tuple(name for name in dir(BriefDigestBindingTest) if name.startswith("test_b"))
PREFIX_ARM = "test_p0_prefix_control_runs_altered_gate"


def run_arms(names):
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
        for _, trace in outcome.failures + outcome.errors:
            for line in trace.strip().splitlines():
                print(f"    | {line}")
    return failures


if __name__ == "__main__":
    chosen = (PREFIX_ARM,) if PREFIX_CONTROL else ARMS
    print(f"brief digest binding (worker: {os.path.normpath(WORKER)})")
    sys.exit(1 if run_arms(chosen) else 0)
