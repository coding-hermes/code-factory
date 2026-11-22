#!/usr/bin/env python3
"""CF-461: the evidence partition must classify, not lump.

`docs/audits/cf461-evidence-partition.py` classifies every complete row whose closure
evidence does not resolve into `artifact-lost` (a verdict for the row exists elsewhere, so
the row is a rebind candidate) or `never-judged` (no verdict for the row exists at all).

The failure this test prevents is a classifier that degenerates into one bucket: a
partition that answers "artifact-lost" for everything invents rebind candidates, and one
that answers "never-judged" for everything sends rows to a pointless re-judge. So the
fixture pins one row per class, plus a red control: remove the candidate verdict and the
same row must move from artifact-lost to never-judged.
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INSTRUMENT = os.path.join(REPO, "docs", "audits", "cf461-evidence-partition.py")
CHECKER = os.path.join(REPO, "scripts", "board_evidence_check.py")


def _row(row_id, evidence):
    return {
        "id": row_id,
        "title": "fixture row %s" % row_id,
        "status": "complete",
        "priority": "P3",
        "commit_hash": "0" * 40,
        "detail": {"evidence": evidence},
    }


class Fixture(object):
    """A throwaway repo: a board, an event log, a history store and the checker."""

    def __init__(self):
        self.root = tempfile.mkdtemp(prefix="cf461-")
        os.makedirs(os.path.join(self.root, "scripts"))
        os.makedirs(os.path.join(self.root, ".coding-hermes", "board"))
        self.history = os.path.join(self.root, "hist")
        shutil.copy(
            CHECKER, os.path.join(self.root, "scripts", "board_evidence_check.py")
        )

        rows = [
            # resolves in events.jsonl
            _row("R-RESOLVED", [{"run_id": "runres0001"}]),
            # cites a run that resolves nowhere, but a verdict for this row exists
            _row("R-LOST", [{"run_id": "runmiss0001"}]),
            # cites a run that resolves nowhere and no verdict for the row exists
            _row("R-NEVER", [{"run_id": "runmiss0002"}]),
            # names no pointer at all — CF-513's class, excluded from the partition
            _row("R-ZERO", []),
        ]
        with open(self.board_path, "w", encoding="utf-8") as fh:
            for row in rows:
                fh.write(json.dumps(row, separators=(",", ":")) + "\n")

        with open(
            os.path.join(self.root, ".coding-hermes", "board", "events.jsonl"),
            "w",
            encoding="utf-8",
        ) as fh:
            fh.write(
                json.dumps(
                    {"ts": "2026-11-22T00:00:00Z", "detail": {"run_id": "runres0001"}},
                    separators=(",", ":"),
                )
                + "\n"
            )

        self.candidate = os.path.join(self.history, "2026-11-22", "cand0001")
        os.makedirs(self.candidate)
        with open(
            os.path.join(self.candidate, "verdict.json"), "w", encoding="utf-8"
        ) as fh:
            json.dump({"task_id": "R-LOST", "passed": True, "commit": "1" * 40}, fh)

    @property
    def board_path(self):
        return os.path.join(self.root, ".coding-hermes", "board", "tasks.jsonl")

    def run(self):
        proc = subprocess.run(
            [
                sys.executable,
                INSTRUMENT,
                self.root,
                ".coding-hermes/board/tasks.jsonl",
                self.history,
            ],
            capture_output=True,
            text=True,
            timeout=120,
        )
        return proc

    def cleanup(self):
        shutil.rmtree(self.root, ignore_errors=True)


class EvidenancePartitionTest(unittest.TestCase):
    def setUp(self):
        self.fx = Fixture()

    def tearDown(self):
        self.fx.cleanup()

    def test_partition_separates_the_three_classes(self):
        proc = self.fx.run()
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn(
            "resolvable=1 artifact_lost=1 never_judged=1 zero_evidence=1",
            proc.stdout,
            "one row per class expected; got:\n%s" % proc.stdout,
        )
        self.assertIn("R-LOST", proc.stdout)
        self.assertIn("artifact-lost", proc.stdout)

    def test_red_control_candidate_removal_moves_the_row_to_never_judged(self):
        """A classifier that always answers artifact-lost cannot pass this arm."""
        shutil.rmtree(os.path.join(self.fx.history, "2026-11-22", "cand0001"))
        proc = self.fx.run()
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn(
            "resolvable=1 artifact_lost=0 never_judged=2 zero_evidence=1",
            proc.stdout,
            "removing the only candidate verdict must reclassify R-LOST; got:\n%s"
            % proc.stdout,
        )
        self.assertIn("R-LOST", proc.stdout)
        self.assertIn("never-judged", proc.stdout)

    def test_partition_count_reconciles_with_the_gate_checker(self):
        """The instrument reuses the checker's rules, so the finding counts must agree."""
        proc = self.fx.run()
        self.assertEqual(proc.returncode, 0, proc.stderr)
        gate = subprocess.run(
            [
                sys.executable,
                os.path.join(self.fx.root, "scripts", "board_evidence_check.py"),
                "--root",
                self.fx.root,
                "--history-root",
                self.fx.history,
            ],
            capture_output=True,
            text=True,
            timeout=120,
        )
        # The gate counts zero-evidence as a finding (R-LOST + R-NEVER + R-ZERO = 3); the
        # partition separates that class out, so their totals differ by exactly that class.
        self.assertIn("checked 4 complete rows, 3 unresolved", gate.stdout, gate.stdout)
        self.assertIn("artifact_lost=1 never_judged=1 zero_evidence=1", proc.stdout)


if __name__ == "__main__":
    unittest.main()
