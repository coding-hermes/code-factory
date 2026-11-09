#!/usr/bin/env python3
"""Tests for the in-repo board evidence-pointer checker (CF-398)."""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
import uuid

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ROOT, "scripts", "board_evidence_check.py")
RESOLVABLE = os.path.join(ROOT, "tests", "fixtures", "board_evidence", "resolvable")
UNRESOLVABLE = os.path.join(
    ROOT, "tests", "fixtures", "board_evidence", "unresolvable"
)
HISTORY_RESOLVABLE = os.path.join(
    ROOT, "tests", "fixtures", "board_evidence", "history_resolvable"
)
HISTORY_ROOT = os.path.join(HISTORY_RESOLVABLE, ".gitreins", "history")


class BoardEvidenceCheck(unittest.TestCase):
    def run_checker(self, root, *args):
        return subprocess.run(
            [sys.executable, "-B", SCRIPT, "--root", root, *args],
            capture_output=True,
            text=True,
            cwd=ROOT,
        )

    @staticmethod
    def count_line(output):
        lines = [line for line in output.splitlines() if line.startswith("checked ")]
        if len(lines) != 1:
            raise AssertionError(f"expected one count line:\n{output}")
        return lines[0]

    @staticmethod
    def complete_row_count(tasks_path):
        count = 0
        with open(tasks_path, encoding="utf-8") as tasks_file:
            for line in tasks_file:
                if not line.strip():
                    continue
                try:
                    record = json.loads(line)
                except (TypeError, ValueError, UnicodeDecodeError):
                    continue
                if isinstance(record, dict) and record.get("status") == "complete":
                    count += 1
        return count

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
        self.assertEqual(findings, ["UNRESOLVED FIXTURE-UNRESOLVED missing-fixture-run"])
        self.assertIn("checked 1 complete rows, 1 unresolved", result.stdout)
        strict = self.run_checker(UNRESOLVABLE, "--strict")
        self.assertEqual(strict.returncode, 1, strict.stdout + strict.stderr)

    def test_history_resolvable_fixture_uses_history_by_default(self):
        result = self.run_checker(HISTORY_RESOLVABLE)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("UNRESOLVED ", result.stdout)
        self.assertIn("checked 1 complete rows, 0 unresolved", result.stdout)
        strict = self.run_checker(HISTORY_RESOLVABLE, "--strict")
        self.assertEqual(strict.returncode, 0, strict.stdout + strict.stderr)

        with tempfile.TemporaryDirectory() as empty_history:
            without_history = self.run_checker(
                HISTORY_RESOLVABLE, "--history-root", empty_history
            )
        self.assertEqual(without_history.returncode, 0, without_history.stdout)
        self.assertEqual(
            [
                line
                for line in without_history.stdout.splitlines()
                if line.startswith("UNRESOLVED ")
            ],
            ["UNRESOLVED FIXTURE-HISTORY-RESOLVABLE fixture-history-run"],
        )
        self.assertIn("checked 1 complete rows, 1 unresolved", without_history.stdout)

    def test_live_repo_uses_derived_count_and_strict_contract(self):
        result = self.run_checker(ROOT)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        count_line = self.count_line(result.stdout)
        match = re.fullmatch(r"checked (\d+) complete rows, (\d+) unresolved", count_line)
        self.assertIsNotNone(match, result.stdout)
        complete_count, unresolved_count = map(int, match.groups())
        tasks_path = os.path.join(ROOT, ".coding-hermes", "board", "tasks.jsonl")
        self.assertEqual(complete_count, self.complete_row_count(tasks_path))
        finding_count = sum(
            line.startswith("UNRESOLVED ") for line in result.stdout.splitlines()
        )
        self.assertEqual(unresolved_count, finding_count)
        strict = self.run_checker(ROOT, "--strict")
        self.assertEqual(strict.returncode, 1 if unresolved_count > 0 else 0)

    def test_new_breakage_can_fail(self):
        tasks_path = os.path.join(ROOT, ".coding-hermes", "board", "tasks.jsonl")
        events_path = os.path.join(ROOT, ".coding-hermes", "board", "events.jsonl")
        with tempfile.TemporaryDirectory() as temp_root:
            board_path = os.path.join(temp_root, ".coding-hermes", "board")
            os.makedirs(board_path)
            temp_tasks = os.path.join(board_path, "tasks.jsonl")
            temp_events = os.path.join(board_path, "events.jsonl")
            shutil.copyfile(tasks_path, temp_tasks)
            shutil.copyfile(events_path, temp_events)
            run_id = str(uuid.uuid4())
            baseline = self.run_checker(temp_root)
            self.assertEqual(baseline.returncode, 0, baseline.stdout + baseline.stderr)
            baseline_match = re.fullmatch(
                r"checked (\d+) complete rows, (\d+) unresolved",
                self.count_line(baseline.stdout),
            )
            self.assertIsNotNone(baseline_match, baseline.stdout)
            baseline_unresolved = int(baseline_match.group(2))
            with open(temp_tasks, "a", encoding="utf-8") as tasks_file:
                tasks_file.write(
                    json.dumps(
                        {
                            "id": "CF-398-NEW-BREAKAGE",
                            "status": "complete",
                            "detail": {"evidence": [{"run_id": run_id}]},
                        }
                    )
                    + "\n"
                )

            result = self.run_checker(temp_root)
            findings = [
                line for line in result.stdout.splitlines() if line.startswith("UNRESOLVED ")
            ]
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn(run_id, result.stdout)
            self.assertEqual(len(findings), baseline_unresolved + 1)
            self.assertEqual(
                self.count_line(result.stdout),
                f"checked {int(baseline_match.group(1)) + 1} complete rows, "
                f"{baseline_unresolved + 1} unresolved",
            )
            strict = self.run_checker(temp_root, "--strict")
            self.assertEqual(strict.returncode, 1, strict.stdout + strict.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
