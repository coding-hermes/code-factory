#!/usr/bin/env python3
"""Tests for the in-repo board evidence-pointer checker (CF-398, CF-438)."""

import importlib.util
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
FIXTURES = os.path.join(ROOT, "tests", "fixtures", "board_evidence")
RESOLVABLE = os.path.join(FIXTURES, "resolvable")
UNRESOLVABLE = os.path.join(FIXTURES, "unresolvable")
HISTORY_RESOLVABLE = os.path.join(FIXTURES, "history_resolvable")
EMPTY_EVIDENCE = os.path.join(FIXTURES, "empty_evidence")
HISTORY_ROOT = os.path.join(HISTORY_RESOLVABLE, ".gitreins", "history")

# A complete row whose evidence cannot be verified is reported under one of these
# prefixes: a named run that is absent, or no evidence pointer at all (CF-438).
FINDING_PREFIXES = ("UNRESOLVED ", "ZERO-EVIDENCE ")
ALLOWLIST_LINE = re.compile(
    r"^allowlist: dated (\d{4}-\d{2}-\d{2}), (\d+) accepted ids, "
    r"(\d+) accepted findings of (\d+) findings, new=(none|\S+), cleared=(\d+)$"
)


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
    def finding_lines(output):
        return [
            line for line in output.splitlines() if line.startswith(FINDING_PREFIXES)
        ]

    @staticmethod
    def allowlist_line(output):
        lines = [line for line in output.splitlines() if line.startswith("allowlist:")]
        if len(lines) != 1:
            raise AssertionError(f"expected one allowlist line:\n{output}")
        return lines[0]

    @staticmethod
    def complete_rows(tasks_path):
        rows = []
        with open(tasks_path, encoding="utf-8") as tasks_file:
            for line in tasks_file:
                if not line.strip():
                    continue
                try:
                    record = json.loads(line)
                except (TypeError, ValueError, UnicodeDecodeError):
                    continue
                if isinstance(record, dict):
                    rows.append(record)
        return [row for row in rows if row.get("status") == "complete"]

    def complete_row_count(self, tasks_path):
        return len(self.complete_rows(tasks_path))

    @staticmethod
    def load_checker_module():
        """Import the script so allowlist checks can be asserted in-process."""
        spec = importlib.util.spec_from_file_location(
            "board_evidence_check_under_test", SCRIPT
        )
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    def copy_board(self, destination):
        board_path = os.path.join(destination, ".coding-hermes", "board")
        os.makedirs(board_path)
        live_board = os.path.join(ROOT, ".coding-hermes", "board")
        for name in ("tasks.jsonl", "events.jsonl"):
            shutil.copyfile(
                os.path.join(live_board, name), os.path.join(board_path, name)
            )
        return os.path.join(board_path, "tasks.jsonl")

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
            line
            for line in result.stdout.splitlines()
            if line.startswith("UNRESOLVED ")
        ]
        self.assertEqual(
            findings, ["UNRESOLVED FIXTURE-UNRESOLVED missing-fixture-run"]
        )
        self.assertIn("checked 1 complete rows, 1 unresolved", result.stdout)
        strict = self.run_checker(UNRESOLVABLE, "--strict")
        self.assertEqual(strict.returncode, 1, strict.stdout + strict.stderr)

    def test_empty_evidence_fixture_is_a_finding_and_fails_strict(self):
        """A complete row with no evidence pointer is a finding, not an omission.

        The fixture's row is named by its own event, so a gate that only looked
        for the id in events.jsonl would call it resolved; the evidence pointer
        itself is empty, and that is what must name the row.
        """
        result = self.run_checker(EMPTY_EVIDENCE)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(
            self.finding_lines(result.stdout),
            ["ZERO-EVIDENCE FIXTURE-EMPTY-EVIDENCE"],
        )
        self.assertIn("checked 1 complete rows, 1 unresolved", result.stdout)
        strict = self.run_checker(EMPTY_EVIDENCE, "--strict")
        self.assertEqual(strict.returncode, 1, strict.stdout + strict.stderr)
        self.assertIn("FIXTURE-EMPTY-EVIDENCE", strict.stdout)

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

    def test_live_repo_census_invariants_hold_in_any_checkout(self):
        """The live census is a report; only checkout-independent invariants are graded.

        Evidence resolves against ``events.jsonl`` plus the git-untracked
        ``.gitreins/history`` store, so the derived finding count is a property of
        the CHECKOUT (0 run dirs in a fresh clone or in CI, more where the run
        directories exist) and an equality against it can only hold on the machine
        that measured it (CF-475).  What holds everywhere, and is asserted here: the
        accepted baseline never exceeds what the census derived, the allowlist
        accounting adds up, ``--strict`` fails exactly when the run reported a
        finding, and the store line names a history root with its run-dir count.
        """
        result = self.run_checker(ROOT)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        count_line = self.count_line(result.stdout)
        match = re.fullmatch(
            r"checked (\d+) complete rows, (\d+) unresolved", count_line
        )
        self.assertIsNotNone(match, result.stdout)
        complete_count, unresolved_count = map(int, match.groups())
        tasks_path = os.path.join(ROOT, ".coding-hermes", "board", "tasks.jsonl")
        self.assertEqual(complete_count, self.complete_row_count(tasks_path))
        self.assertEqual(unresolved_count, len(self.finding_lines(result.stdout)))

        allow = ALLOWLIST_LINE.fullmatch(self.allowlist_line(result.stdout))
        self.assertIsNotNone(allow, result.stdout)
        accepted_ids, accepted, total = (int(value) for value in allow.group(2, 3, 4))
        new_ids = [] if allow.group(5) == "none" else allow.group(5).split(",")
        # accepted <= derived in any checkout: the allowlist can only accept ids the
        # census found, and every finding is either accepted or new.
        self.assertLessEqual(accepted, total)
        self.assertEqual(total, unresolved_count)
        self.assertEqual(len(new_ids), total - accepted)
        self.assertGreaterEqual(accepted_ids, accepted)

        expected_line = [
            line
            for line in result.stdout.splitlines()
            if line.startswith("expected_unresolved=")
        ]
        self.assertEqual(len(expected_line), 1, result.stdout)
        expected = int(
            re.match(r"expected_unresolved=(\d+)", expected_line[0]).group(1)
        )
        self.assertEqual(expected, accepted)

        # The census names its population, so a reader can tell a checkout with 0 run
        # dirs from the one that owns them.
        store_line = [
            line for line in result.stdout.splitlines() if line.startswith("stores:")
        ]
        self.assertEqual(len(store_line), 1, result.stdout)
        history_roots = re.findall(r"history=(.+?) \((\d+) run dirs\)", store_line[0])
        self.assertGreaterEqual(len(history_roots), 1, store_line[0])

        strict = self.run_checker(ROOT, "--strict")
        self.assertEqual(strict.returncode, 1 if unresolved_count else 0)

    def test_allowlist_cannot_absorb_a_new_zero_evidence_row(self):
        """The accepted baseline is a dated allowlist, not a runtime-derived count.

        Today's findings must all be named by the allowlist and every
        zero-evidence row the board carries must appear as a finding rather than
        being silently counted as resolved; a complete row added with empty
        evidence must then be reported as new, with the baseline unchanged.
        """
        module = self.load_checker_module()
        self.assertTrue(module.ACCEPTED_UNRESOLVED_DATE)
        allowlisted_id = sorted(module.ACCEPTED_UNRESOLVED)[0]
        _complete, live_findings, _ignored, _bases = module.check(ROOT, None)
        self.assertTrue(live_findings, "the live board carries findings")
        for row_id, kind, run_ids in live_findings:
            self.assertIn(kind, ("unresolved", "zero-evidence"))
            if kind == "zero-evidence":
                self.assertEqual(run_ids, [])
                # A zero-evidence finding does not depend on the history store, so in
                # any checkout the board's empty pointers must be accepted ids; a new
                # one is exactly the debt the allowlist cannot absorb.
                self.assertIn(row_id, module.ACCEPTED_UNRESOLVED)
        # Store-independent bound: the dated allowlist can accept at most the findings
        # the census derived.  The equality that discriminates is asserted below on a
        # fixture board, where the population is not a property of the checkout.
        self.assertLessEqual(
            module.expected_unresolved(live_findings), len(live_findings)
        )

        tasks_path = os.path.join(ROOT, ".coding-hermes", "board", "tasks.jsonl")
        board_zero_evidence = {
            row.get("id")
            for row in self.complete_rows(tasks_path)
            if not module._evidence_ids(row)
        }
        self.assertEqual(
            board_zero_evidence,
            {
                row_id
                for row_id, kind, _runs in live_findings
                if kind == "zero-evidence"
            },
        )

        # A board holding one accepted row and one row nobody accepted: the
        # accepted baseline is 1 while the reported count is 2, and that gap is
        # what a new zero-evidence row can no longer hide behind.
        with tempfile.TemporaryDirectory() as temp_root:
            board_path = os.path.join(temp_root, ".coding-hermes", "board")
            os.makedirs(board_path)
            temp_tasks = os.path.join(board_path, "tasks.jsonl")
            with open(temp_tasks, "w", encoding="utf-8") as tasks_file:
                for row_id in (allowlisted_id, "CF-438-NEW-ZERO-EVIDENCE"):
                    tasks_file.write(
                        json.dumps(
                            {
                                "id": row_id,
                                "status": "complete",
                                "detail": {"evidence": []},
                            }
                        )
                        + "\n"
                    )

            _complete, findings, _ignored, _bases = module.check(temp_root, None)
            self.assertIn((allowlisted_id, "zero-evidence", []), findings)
            self.assertIn(("CF-438-NEW-ZERO-EVIDENCE", "zero-evidence", []), findings)
            self.assertEqual(module.expected_unresolved(findings), 1)
            self.assertLess(module.expected_unresolved(findings), len(findings))
            self.assertNotIn("CF-438-NEW-ZERO-EVIDENCE", module.ACCEPTED_UNRESOLVED)

            result = self.run_checker(temp_root)
            self.assertIn(f"ZERO-EVIDENCE {allowlisted_id}", result.stdout)
            self.assertIn("ZERO-EVIDENCE CF-438-NEW-ZERO-EVIDENCE", result.stdout)
            self.assertIn("checked 2 complete rows, 2 unresolved", result.stdout)
            allow = ALLOWLIST_LINE.fullmatch(self.allowlist_line(result.stdout))
            self.assertIsNotNone(allow, result.stdout)
            self.assertEqual(allow.group(3), "1")
            self.assertEqual(allow.group(4), "2")
            self.assertEqual(allow.group(5), "CF-438-NEW-ZERO-EVIDENCE")
            strict = self.run_checker(temp_root, "--strict")
            self.assertEqual(strict.returncode, 1, strict.stdout + strict.stderr)

    def test_new_breakage_can_fail(self):
        with tempfile.TemporaryDirectory() as temp_root:
            temp_tasks = self.copy_board(temp_root)
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
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn(run_id, result.stdout)
            self.assertEqual(
                len(self.finding_lines(result.stdout)), baseline_unresolved + 1
            )
            self.assertEqual(
                self.count_line(result.stdout),
                f"checked {int(baseline_match.group(1)) + 1} complete rows, "
                f"{baseline_unresolved + 1} unresolved",
            )
            allow = ALLOWLIST_LINE.fullmatch(self.allowlist_line(result.stdout))
            self.assertIsNotNone(allow, result.stdout)
            new_ids = [] if allow.group(5) == "none" else allow.group(5).split(",")
            self.assertIn("CF-398-NEW-BREAKAGE", new_ids)
            strict = self.run_checker(temp_root, "--strict")
            self.assertEqual(strict.returncode, 1, strict.stdout + strict.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
