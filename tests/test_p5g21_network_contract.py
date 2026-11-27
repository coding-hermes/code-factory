#!/usr/bin/env python3
"""Validate the P5G-21 specification table, not deployed network policy."""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHAPTER = ROOT / "docs/handbook/chapters/M1-provisioning.md"
HEADER = "### III.M1.S7 — Bootstrap network and dependency reachability (P5G-21)"
REVISION = "49f62e597dd0a4c95fbe97d474b100224f3d7e82"
ROWS = {
    "bootstrap / bus": ("Exact approved Crier endpoint", "authenticated bus operation"),
    "bootstrap / artifacts": (
        "Exact approved artifact hosts",
        "digest verified",
        "transitive dependencies",
    ),
    "bootstrap / workspace": (
        "Exact approved repository endpoint",
        "repository identity and revision",
    ),
    "runtime / control": (
        "Exact approved Crier and inference gateway endpoints",
        "effective policy verified",
    ),
    "runtime / memory": ("Exact approved DuckBrain endpoint", "independent readback"),
    "runtime / dependencies": (
        "Approved local sealed cache",
        "actual dependency resolution",
    ),
    "either / other": ("No undeclared destination", "Deny; no implicit fallback"),
}


def validate(text):
    section = text.split(HEADER, 1)[1].split("\n## ", 1)[0]
    assert REVISION in section
    for label in (
        "Actor",
        "Data shape",
        "Ordering",
        "Failure behavior",
        "Recovery rule",
    ):
        assert re.search(rf"^{re.escape(label)}: .+", section, re.MULTILINE), label
    rows = {}
    for line in section.splitlines():
        if line.startswith("| "):
            cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
            if len(cells) == 3 and cells[0] in ROWS:
                assert cells[0] not in rows, cells[0]
                rows[cells[0]] = cells
    assert set(rows) == set(ROWS), "missing or duplicate contract row"
    for name, required in ROWS.items():
        for token in required:
            assert token in " | ".join(rows[name]), (name, token)


class ContractTest(unittest.TestCase):
    def test_positive_and_negative_vectors(self):
        text = CHAPTER.read_text(encoding="utf-8")
        validate(text)
        for original, replacement in (
            ("No undeclared destination", "Any destination"),
            ("independent readback", "unverified transfer"),
        ):
            self.assertIn(original, text)
            with self.subTest(original=original), self.assertRaises(AssertionError):
                validate(text.replace(original, replacement))


if __name__ == "__main__":
    unittest.main(verbosity=2)
