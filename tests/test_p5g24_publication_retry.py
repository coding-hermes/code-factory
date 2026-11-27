#!/usr/bin/env python3
"""Check the P5G-24 design artifact, not a deployed publication broker."""

import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHAPTER = ROOT / "docs/handbook/parts/I-system-arrangement.md"
HEADER = "#### 1.9.7a Publication retry and exact-tree proof (P5G-24)"
PIN = "4000cc4f2e0eb671a8d1f391d0483054d6e5707a"
# case -> (ref_shows, state, same_key_retry)
CASES = {
    "landed_exact": ("accepted", "confirmed", "0"),
    "landed_advanced": ("descendant", "confirmed", "0"),
    "not_landed": ("base", "published_pending", "1"),
    "remote_moved": ("moved", "superseded", "0"),
    "outcome_unknown": ("unavailable", "published_pending", "0"),
}
STATE_FROM_REF = {
    "accepted": "confirmed",
    "descendant": "confirmed",
    "base": "published_pending",
    "moved": "superseded",
    "unavailable": "published_pending",
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
        'SHA-256(UTF-8("publication-intent.v1") || JCS(intent))',
        "CAS is the only write primitive",
        "The same key never re-fires",
        "READBACK_UNAVAILABLE",
        "no replacement publication or success is authorized",
        "an unconditional push is refused",
        "--evidence-run-id",
        "contains no hash of itself",
        "descendant",
    ):
        assert token in section, token
    rows = {}
    for line in section.splitlines():
        if not line.startswith("| "):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if cells[0] in CASES:
            assert len(cells) == 4 and cells[0] not in rows, cells
            rows[cells[0]] = cells
    assert set(rows) == set(CASES), "missing decision vector"
    for name, (ref, state, retry) in CASES.items():
        row = rows[name]
        assert row[1] == ref and row[2] == state and row[3] == retry, name
        # The table must agree with the recovery rule it tabulates.
        assert row[2] == STATE_FROM_REF[row[1]], name
        assert row[3] == ("1" if row[1] == "base" else "0"), name


class PublicationRetryContractTest(unittest.TestCase):
    def test_vectors_and_negative_controls(self):
        text = CHAPTER.read_text(encoding="utf-8")
        validate(text)
        for old, new in (
            # A moved remote must never leave the key re-firable.
            (
                "| remote_moved | moved | superseded | 0 |",
                "| remote_moved | moved | published_pending | 1 |",
            ),
            # A still-at-base ref is the one resumable outcome.
            (
                "| not_landed | base | published_pending | 1 |",
                "| not_landed | base | published_pending | 0 |",
            ),
            # An advanced tip is still exactly-once published work.
            (
                "| landed_advanced | descendant | confirmed | 0 |",
                "| landed_advanced | descendant | superseded | 0 |",
            ),
            # The no-self-hashing rule is load-bearing, not prose.
            ("contains no hash of itself", "contains a hash of itself"),
            # Only CAS writes are permitted.
            ("an unconditional push is refused", "an unconditional push is permitted"),
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
            "docs/handbook/chapters/M3-repository.md",
            "docs/handbook/chapters/M4-board.md",
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
