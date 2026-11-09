#!/usr/bin/env python3
"""Tests for the in-repo board evidence-pointer checker (CF-398)."""

import os
import subprocess
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ROOT, "scripts", "board_evidence_check.py")
RESOLVABLE = os.path.join(ROOT, "tests", "fixtures", "board_evidence", "resolvable")
UNRESOLVABLE = os.path.join(
    ROOT, "tests", "fixtures", "board_evidence", "unresolvable"
)

sys.path.insert(0, os.path.join(ROOT, "scripts"))
import board_evidence_check  # noqa: E402


class BoardEvidenceCheck(unittest.TestCase):
    def run_checker(self, root, *args):
        return subprocess.run(
            [sys.executable, "-B", SCRIPT, "--root", root, *args],
            capture_output=True,
            text=True,
            cwd=ROOT,
        )

    def test_resolvable_fixture_has_no_findings(self):
        result = self.run_checker(RESOLVABLE)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("UNRESOLVED ", result.stdout)
        self.assertIn("checked 1 complete rows, 0 unresolved", result.stdout)
        strict = self.run_checker(RESOLVABLE, "--strict")
        self.assertEqual(strict.returncode, 0, strict.stdout + strict.stderr)

    def test_unresolvable_fixture_is_discriminating_and_strict(self):
        result = self.run_checker(UNRESOLVABLE)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        findings = [
            line for line in result.stdout.splitlines() if line.startswith("UNRESOLVED ")
        ]
        self.assertEqual(len(findings), 1)
        self.assertEqual(findings[0], "UNRESOLVED FIXTURE-UNRESOLVED missing-fixture-run")
        self.assertIn("checked 1 complete rows, 1 unresolved", result.stdout)
        strict = self.run_checker(UNRESOLVABLE, "--strict")
        self.assertEqual(strict.returncode, 1, strict.stdout + strict.stderr)
        self.assertNotEqual(result.stdout, self.run_checker(RESOLVABLE).stdout)

    def test_live_repo_matches_expected_unresolved_count(self):
        result = self.run_checker(ROOT)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        expected = board_evidence_check.EXPECTED_UNRESOLVED
        self.assertTrue(
            result.stdout.splitlines()[-1].endswith(f", {expected} unresolved"),
            result.stdout,
        )
        self.assertTrue(
            result.stdout.splitlines()[-1].startswith("checked "),
            result.stdout,
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
