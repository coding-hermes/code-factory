#!/usr/bin/env python3
"""P5G-20 acceptance arms — the M1 III.M1.S6 provisioning-lifecycle section is checkable.

Parses docs/handbook/chapters/M1-provisioning.md subsection III.M1.S6
("Provisioning generations and retry lifecycle (P5G-20)") and validates the
board row's four acceptance arms as executable checks:

  1. the section cites P5G-20 and states the answer under exactly five labelled
     lines (Actor:, Data shape:, Ordering:, Failure behavior:, Recovery rule:);
  2. the section carries the deterministic state table, and each operation row
     carries the invariant values the cited sources specify (the expected
     vector below is the artifact's check);
  3. every (scripts|tests|specs|docs)/... path the section cites resolves in
     this tree;
  4. the section names the source revision it was measured against.

No network, no live node, no fixture mutation: the input is the chapter bytes.
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHAPTER = ROOT / "docs" / "handbook" / "chapters" / "M1-provisioning.md"
SOURCE_REVISION = "fe3d2ee08d04e7bc046638ba1290e1732e51bd12"

SECTION_HEADER = "### III.M1.S6 — Provisioning generations and retry lifecycle (P5G-20)"
LABELS = ("Actor", "Data shape", "Ordering", "Failure behavior", "Recovery rule")

# Expected vector for the deterministic state table: operation -> set of
# tokens its row must carry. Every token is grounded in the chapter's own
# normative surfaces (§15/§16/§17.1/§17.2/§17.4/§18.2/§18.3) or the shipped
# surfaces named in the row (deploy_key.py --replace gate, CF-008 replay).
ROW_INVARIANTS = {
    "create": {
        "expected_generation=0",
        "installs generation=1",
        "idempotent",
        "compare-and-swap refusal",
        "exact retry replays the original receipt",
    },
    "resume": {
        "same operation_id",
        "same generation",
        "same manifest_digest",
        "distinct request_id + idempotency_key",
        "allocates nothing",
        "only unfinished idempotent stages",
    },
    "upgrade": {
        "compares N",
        "installs N+1",
        "after drain/fence",
        "IDEMPOTENCY_KEY_REUSED",
        "GENERATION_CONFLICT",
        "GET operation/{operation_id}",
        "REPLACEMENT_REQUIRED",
    },
    "replace": {
        "fence old Bunker",
        "revoke its credentials",
        "revoked credentials are never inherited",
        "lost acknowledgement never causes a second launch",
    },
    "remove": {
        "compares current N",
        "without allocating a new runtime",
        "revoke all five credential classes",
        "REMOVED",
        "401 CAPABILITY_REVOKED",
    },
    "rotate": {
        "SEPARATE operation",
        "60 s",
        "half lifetime",
        "pass --replace to rotate it",
        "mutations use only the new generation",
    },
    "revoke": {
        "POST /v1/revocations",
        "negative probe",
        "no generation increment",
        "never resurrected",
    },
}


def section_text() -> str:
    lines = CHAPTER.read_text(encoding="utf-8").splitlines()
    start = None
    for i, line in enumerate(lines):
        if line.strip() == SECTION_HEADER:
            start = i
            break
    assert start is not None, f"section header not found: {SECTION_HEADER}"
    end = len(lines)
    for j in range(start + 1, len(lines)):
        if lines[j].startswith("## "):
            end = j
            break
    return "\n".join(lines[start:end])


def table_rows(text: str) -> list[list[str]]:
    """Return the data rows of the III.M1.S6 operation state table, in order."""
    rows = []
    in_table = False
    for line in text.splitlines():
        if line.startswith("| Operation | Discriminator |"):
            in_table = True
            continue
        if in_table:
            if not line.startswith("|"):
                break
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if cells and set(cells[0]) <= {"-", " "}:  # separator row
                continue
            rows.append(cells)
    return rows


class TestP5G20Section(unittest.TestCase):
    def setUp(self) -> None:
        self.text = section_text()

    def test_header_cites_row_id(self) -> None:
        self.assertIn(SECTION_HEADER, self.text.splitlines()[0])
        self.assertIn("P5G-20", self.text)

    def test_five_labelled_lines_present_exactly_once(self) -> None:
        for label in LABELS:
            pattern = re.compile(rf"^{label}: ", re.MULTILINE)
            found = pattern.findall(self.text)
            self.assertEqual(
                1, len(found), f"label {label!r} found {len(found)} times in III.M1.S6"
            )

    def test_section_names_source_revision(self) -> None:
        self.assertIn(SOURCE_REVISION[:8], self.text)
        hits = re.findall(r"\b[0-9a-f]{7,40}\b|v[0-9]+\.[0-9]+", self.text)
        self.assertTrue(hits, "no version/commit token inside §19")

    def test_cited_repository_paths_resolve(self) -> None:
        paths = sorted(
            set(re.findall(r"(?:scripts|tests|specs|docs)/[A-Za-z0-9_./-]+", self.text))
        )
        self.assertTrue(paths, "§19 cites no repository paths")
        missing = [p for p in paths if not (ROOT / p).exists()]
        self.assertEqual([], missing, f"missing cited paths: {missing}")

    def test_state_table_rows_match_expected_vector(self) -> None:
        rows = table_rows(self.text)
        ops = [row[0] for row in rows]
        self.assertEqual(
            sorted(ROW_INVARIANTS), sorted(ops), f"table operations: {ops}"
        )
        for row in rows:
            op, cells = row[0], " ".join(row[1:])
            missing_tokens = [
                token for token in ROW_INVARIANTS[op] if token not in cells
            ]
            self.assertEqual(
                [],
                missing_tokens,
                f"operation {op!r} row missing tokens: {missing_tokens}",
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
