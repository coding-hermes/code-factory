#!/usr/bin/env python3
"""Check the P5G-23 design artifact, not a deployed settlement service."""

import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHAPTER = ROOT / "docs/handbook/parts/I-system-arrangement.md"
HEADER = "#### 1.9.9a Offline memory custody and settlement (P5G-23)"
PIN = "d5de281d5da8ab3ed24d548e5316d9b444930461"
CASES = {
    "disconnected": (0, 0, 0),
    "invalid_receipt": (0, 0, 0),
    "deadline": (0, 1, 0),
    "accepted_loss": (0, 1, 1),
    "controller_custody": (1, 0, 0),
    "late_custody": (1, 1, 0),
}


def validate(text):
    assert text.count(HEADER) == 1
    section = text.split(HEADER, 1)[1].split("\n### ", 1)[0]
    assert PIN in section
    assert "TARGET-UNIMPLEMENTED / UNVERIFIED" in section
    for label in (
        "Actor",
        "Data shape",
        "Ordering",
        "Failure behavior",
        "Recovery rule",
    ):
        assert re.search(rf"^{re.escape(label)}: .+", section, re.MULTILINE), label
    for token in (
        "signed by the authorized controller custodian",
        "Crier report custody is not memory custody",
        "current fence",
        "complete expected record set",
        "LOCAL_STORE_LOST",
        "late valid receipt appends a reconciliation revision",
        "explicit authorized loss acceptance",
    ):
        assert token in section, token
    rows = {}
    for line in section.splitlines():
        if not line.startswith("| "):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if cells[0] in CASES:
            assert len(cells) == 6 and cells[0] not in rows, cells
            rows[cells[0]] = cells
    assert set(rows) == set(CASES), "missing decision vector"
    for name, inputs in CASES.items():
        row = rows[name]
        assert tuple(map(int, row[1:4])) == inputs, name
        valid, expired, loss = inputs
        state = (
            "postcheck_pending"
            if valid
            else "unknown"
            if expired
            else "awaiting_evidence"
        )
        release = int(bool(valid or loss))
        assert (row[4], int(row[5])) == (state, release), name


class MemorySettlementContractTest(unittest.TestCase):
    def test_vectors_and_negative_controls(self):
        text = CHAPTER.read_text(encoding="utf-8")
        validate(text)
        for old, new in (
            (
                "| deadline | 0 | 1 | 0 | unknown | 0 |",
                "| deadline | 0 | 1 | 0 | unknown | 1 |",
            ),
            (
                "| controller_custody | 1 | 0 | 0 | postcheck_pending | 1 |",
                "| controller_custody | 1 | 0 | 0 | settled_success | 1 |",
            ),
            (
                "Crier report custody is not memory custody",
                "Crier report custody is memory custody",
            ),
        ):
            with self.subTest(old=old):
                self.assertIn(old, text)
                with self.assertRaises(AssertionError):
                    validate(text.replace(old, new))

    def test_repository_paths_and_source_pin(self):
        text = CHAPTER.read_text(encoding="utf-8")
        paths = set(re.findall(r"(?:scripts|tests|specs|docs)/[A-Za-z0-9_./-]+", text))
        self.assertTrue(paths)
        self.assertEqual([], sorted(p for p in paths if not (ROOT / p).exists()))
        for path in (
            "docs/handbook/parts/I-system-arrangement.md",
            "docs/handbook/parts/II-flows.md",
        ):
            result = subprocess.run(
                ["git", "cat-file", "-e", f"{PIN}:{path}"],
                cwd=ROOT,
                capture_output=True,
                check=False,
            )
            self.assertEqual(0, result.returncode, (path, result.stderr))


if __name__ == "__main__":
    unittest.main(verbosity=2)
