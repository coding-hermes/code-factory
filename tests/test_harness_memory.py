#!/usr/bin/env python3
"""Hermetic I3 record and conformance checks (CF-231); no DuckBrain service is contacted."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

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
        self.assertNotEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        for harness in harnesses:
            with self.subTest(harness=harness):
                self.assertIn(f"PASS  {harness}:memory-fixture", proc.stdout)
                self.assertIn(f"FAIL  {harness}:memory — UNSUPPORTED", proc.stdout)


if __name__ == "__main__":
    unittest.main()
