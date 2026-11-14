#!/usr/bin/env python3
"""I3 record, adapter export, and conformance checks for CF-330."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts" / "harness"))
import harness_memory as memory  # noqa: E402


def record(harness: str = "hermes") -> dict[str, str]:
    return dict(
        namespace="project-qa",
        run_id="run-123",
        lane="project-qa",
        harness=harness,
        harness_version="1.2.3",
        model_requested="requested",
        model_served="served",
        provider_binding="native",
        commit="abc123",
        tick="-",
    )


class MemoryContract(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / "record.json"
        self.writer = memory.MemoryWriter(self.path)

    def test_five_harnesses_roundtrip_exact_bytes_and_fields(self):
        for harness in ("hermes", "codex", "claude-code", "opencode", "pi-agent"):
            with self.subTest(harness=harness):
                expected = record(harness)
                data = self.writer.write(expected, "project-qa")
                self.assertEqual(data, memory.canonical_bytes(expected))
                self.assertEqual(self.writer.read("project-qa"), data)
                self.assertEqual(json.loads(data), expected)

    def test_missing_and_wrong_namespace_refused_before_write(self):
        for namespace, expected in (
            ("", "project-qa"),
            ("wrong", "project-qa"),
            ("default", "default"),
            ("project-qa", ""),
        ):
            with self.subTest(namespace=namespace, expected=expected):
                candidate = record()
                candidate["namespace"] = namespace
                with self.assertRaises(memory.MemoryRecordError):
                    self.writer.write(candidate, expected)
                self.assertFalse(self.path.exists())

    def test_missing_field_and_tampered_readback_fail(self):
        candidate = record()
        del candidate["model_served"]
        with self.assertRaises(memory.MemoryRecordError):
            self.writer.write(candidate, "project-qa")
        self.assertFalse(self.path.exists())
        self.writer.write(record(), "project-qa")
        with self.assertRaises(memory.MemoryRecordError):
            self.writer.read("wrong")
        self.path.write_bytes(self.path.read_bytes() + b" ")
        with self.assertRaises(memory.MemoryRecordError):
            self.writer.read("project-qa")

    def test_memory_records_write_r1_then_r2_with_fail_outcome(self):
        candidate = record()
        candidate.update(
            started_at="2026-11-14T00:00:00Z",
            ended_at="2026-11-14T00:01:00Z",
            board_row="CF-330",
            node="node-fixture",
        )
        r1, r2 = memory.memory_records(candidate, "FAIL")
        self.assertEqual("FAIL", r1["outcome"])
        self.assertEqual("FAIL", r2["outcome"])
        self.assertEqual("project-qa", r1["namespace"])
        self.assertEqual("run-123", r2["run_id"])
        self.assertNotIn("prompt", r2)
        self.assertNotIn("credential", repr(r2).lower())
        self.assertEqual("CF-330", r1["board_row"])
        self.assertEqual("node-fixture", r2["node"])
        self.assertEqual("2026-11-14T00:00:00Z", r1["started_at"])
        self.assertEqual("2026-11-14T00:01:00Z", r2["ended_at"])
        self.assertEqual([], r2["artifact_digests"])
        self.assertNotIn("source_code", r2)
        self.assertNotIn("diff", r2)
        self.assertNotIn("secret", repr(r2).lower())

    def test_duckbrain_client_requires_mode_600_token_and_exact_keys(self):
        with self.assertRaises(memory.MemoryRecordError):
            memory.DuckBrainClient("http://127.0.0.1:1", self.path)
        self.path.write_text("fixture-token\n", encoding="utf-8")
        os.chmod(self.path, 0o644)
        with self.assertRaises(memory.MemoryRecordError):
            memory.DuckBrainClient("http://127.0.0.1:1", self.path)

    def test_export_records_orders_r1_before_r2_and_reads_both(self):
        client = mock.Mock()
        keys = memory.export_records(client, record(), "PASS")
        self.assertEqual(
            [
                mock.call(
                    "project-qa", "/runs/project-qa/unknown-week/run-123", mock.ANY
                ),
                mock.call(
                    "factory",
                    "/factory/project-qa/unknown-week/project-qa/run-123",
                    mock.ANY,
                ),
            ],
            client.remember.call_args_list,
        )
        self.assertEqual(
            [
                mock.call("project-qa", "/runs/project-qa/unknown-week/run-123"),
                mock.call(
                    "factory", "/factory/project-qa/unknown-week/project-qa/run-123"
                ),
            ],
            client.read_exact.call_args_list,
        )
        self.assertEqual(2, len(keys))

    def test_battery_names_fixture_and_unsupported_runtime_for_every_adapter(self):
        harnesses = (
            "hermes",
            "claude-code",
            "codex",
            "opencode",
            "opencode-v2",
            "dsh",
            "deepseek",
            "pi-agent",
            "aider",
            "goose",
        )
        env = dict(os.environ, HC_WORK_ROOT=self.temp.name)
        proc = subprocess.run(
            ["bash", str(ROOT / "tests" / "harness-conformance.sh"), "--memory-only"],
            capture_output=True,
            text=True,
            env=env,
            timeout=60,
        )
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        for harness in harnesses:
            with self.subTest(harness=harness):
                self.assertIn(f"PASS  {harness}:memory-r1-write", proc.stdout)
                self.assertIn(f"PASS  {harness}:memory-r2-read", proc.stdout)
                self.assertIn(f"PASS  {harness}:memory-provenance", proc.stdout)
                self.assertIn(
                    f"SKIP  {harness}:memory — no live DuckBrain", proc.stdout
                )
                self.assertNotIn(f"FAIL  {harness}:memory", proc.stdout)
        self.assertEqual(10, proc.stdout.count("SKIP  "))
        self.assertEqual(40, proc.stdout.count("memory-r"))
        self.assertEqual(10, proc.stdout.count("memory-provenance"))
        self.assertEqual(10, proc.stdout.count("memory-negative"))
        self.assertIn("HARNESS CONFORMANCE: PASS", proc.stdout)
        self.assertNotIn("UNSUPPORTED", proc.stdout)
        self.assertNotIn("credential", proc.stdout.lower())
        self.assertNotIn("source code", proc.stdout.lower())
        self.assertNotIn("R2 written before R1", proc.stdout)
        self.assertNotIn("outcome PASS", proc.stdout)
        self.assertIn("FAIL outcome", proc.stdout)
        self.assertIn("factory namespace", proc.stdout)
        self.assertIn("missing namespace refused", proc.stdout)
        self.assertIn("exact-key readback verified", proc.stdout)
        self.assertIn("required non-empty provenance", proc.stdout)
        self.assertIn("live DuckBrain", proc.stdout)
        self.assertIn("fixture is not live support evidence", proc.stdout)
        self.assertNotIn("CF-330", proc.stdout)
        self.assertIn("cf330-hermes-run", proc.stdout)
        self.assertIn("code-factory-qa", proc.stdout)
        self.assertIn("target factory namespace", proc.stdout)
        self.assertNotIn("default namespace accepted", proc.stdout)
        self.assertNotIn("wrong namespace accepted", proc.stdout)
        self.assertNotIn("recorded a credential", proc.stdout)
        self.assertNotIn("prompt text", proc.stdout)
        self.assertNotIn("absolute path", proc.stdout)
        self.assertNotIn("PASS  hermes:memory —", proc.stdout)
        self.assertNotIn("FAIL  hermes:memory —", proc.stdout)
        self.assertNotIn("PASS  codex:memory —", proc.stdout)
        self.assertNotIn("FAIL  codex:memory —", proc.stdout)
        self.assertTrue(
            proc.stdout.endswith("HARNESS CONFORMANCE: PASS\n"), proc.stdout[-100:]
        )


if __name__ == "__main__":
    unittest.main()
