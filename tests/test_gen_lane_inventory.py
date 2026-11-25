"""CF-335 — the canonical lane inventory is generated, and the modules cite it.

The scheduler DB (``projects`` table) is the truth source for the code-factory
lane family. ``scripts/gen_lane_inventory.py`` is the only writer of
``docs/handbook/appendices/lane-inventory.md``; handbook modules 01, 07 and 35
cite that page instead of typing their own lane counts. These tests pin all
three halves:

* the generator's lane table matches the live DB exactly (each lane once);
* the committed page is byte-current with a fresh generation modulo the
  ``| Generated |`` stamp (the output is deterministic);
* the generator fails non-zero on an unreadable DB and refuses to publish a
  page whose duckbrain-resolution claim would be false;
* the three modules cite the page and no longer carry the stale typed
  artifacts (the 16-row duckbrain list, ``(16 lanes)``/``(1 lane)`` verdict
  text, ``eight predefined code-factory satellite lanes``).
"""

from __future__ import annotations

import importlib.util
import re
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "gen_lane_inventory.py"
INVENTORY = ROOT / "docs" / "handbook" / "appendices" / "lane-inventory.md"
UNITS = ROOT / "docs" / "handbook" / "appendices" / "units"
MODULE_01 = UNITS / "01-scripts-add-family-lanes-py.md"
MODULE_07 = UNITS / "07-scripts-bunker-config-gen-py.md"
MODULE_35 = UNITS / "35-scripts-repo-freshness-py.md"
LIVE_DB = Path.home() / ".hermes" / "coding-hermes" / "scheduler.db"

_spec = importlib.util.spec_from_file_location("gen_lane_inventory", SCRIPT)
gen = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(gen)

GENERATED_STAMP = re.compile(r"^\| Generated \| ")


def run_generator(output: Path, db: Path) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--db", str(db), "--output", str(output)],
        capture_output=True,
        text=True,
    )


def db_family_rows(db: Path) -> list[tuple[str, str, int, str]]:
    con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
    try:
        return [
            (name, parent, int(enabled), gen.tildefy(workdir))
            for name, parent, enabled, workdir in con.execute(gen.FAMILY_SQL)
        ]
    finally:
        con.close()


def parse_lane_table(text: str) -> list[tuple[str, str, int, str]]:
    """Parse the ``## Canonical lane table`` rows of a generated page."""
    rows: list[tuple[str, str, int, str]] = []
    in_table = False
    for line in text.splitlines():
        if line.startswith("## "):
            in_table = line == "## Canonical lane table"
            continue
        if not in_table or not line.startswith("| `"):
            continue
        cells = [cell.strip() for cell in line.strip("|").split("|")]
        rows.append(
            (
                cells[0].strip("`"),
                cells[1].strip("`"),
                int(cells[2]),
                cells[3].strip("`"),
            )
        )
    return rows


def without_stamp(text: str) -> list[str]:
    return [line for line in text.splitlines() if not GENERATED_STAMP.match(line)]


class GeneratorMatchesDatabase(unittest.TestCase):
    """AC1: the canonical lane set is derived from the scheduler DB."""

    def test_lane_table_matches_db_exactly(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "lane-inventory.md"
            proc = run_generator(out, LIVE_DB)
            self.assertEqual(proc.returncode, 0, proc.stderr)
            generated = parse_lane_table(out.read_text(encoding="utf-8"))
        expected = db_family_rows(LIVE_DB)
        self.assertGreater(len(expected), 0, "live DB has no code-factory family rows")
        # every DB lane appears exactly once
        self.assertEqual(len(generated), len(expected))
        self.assertEqual(
            [row[0] for row in generated], sorted(row[0] for row in expected)
        )
        self.assertEqual(sorted(generated), sorted(expected))

    def test_counts_section_matches_db(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "lane-inventory.md"
            self.assertEqual(run_generator(out, LIVE_DB).returncode, 0)
            text = out.read_text(encoding="utf-8")
        rows = db_family_rows(LIVE_DB)
        self.assertIn(f"| Family rows | {len(rows)} |", text)
        self.assertIn(
            f"| Enabled lanes | {sum(1 for _n, _p, e, _w in rows if e == 1)} |", text
        )

    def test_output_is_deterministic_except_stamp(self):
        with tempfile.TemporaryDirectory() as tmp:
            first = Path(tmp) / "a.md"
            second = Path(tmp) / "b.md"
            self.assertEqual(run_generator(first, LIVE_DB).returncode, 0)
            self.assertEqual(run_generator(second, LIVE_DB).returncode, 0)
            self.assertEqual(
                without_stamp(first.read_text(encoding="utf-8")),
                without_stamp(second.read_text(encoding="utf-8")),
            )

    def test_committed_inventory_is_current(self):
        """The committed page equals a fresh generation modulo the stamp."""
        self.assertTrue(INVENTORY.is_file(), "committed lane-inventory.md is missing")
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "lane-inventory.md"
            self.assertEqual(run_generator(out, LIVE_DB).returncode, 0)
            fresh = without_stamp(out.read_text(encoding="utf-8"))
        committed = without_stamp(INVENTORY.read_text(encoding="utf-8"))
        self.assertEqual(committed, fresh)

    def test_no_duckbrain_rows_in_live_db(self):
        """Premise of the committed resolution section."""
        con = sqlite3.connect(f"file:{LIVE_DB}?mode=ro", uri=True)
        try:
            live = con.execute(
                "SELECT name FROM projects WHERE name LIKE 'code-factory-duckbrain%'"
            ).fetchall()
        finally:
            con.close()
        self.assertEqual(live, [])


class GeneratorFailureContract(unittest.TestCase):
    """Fail non-zero when the DB is unreadable or the page would lie."""

    def test_missing_db_fails_nonzero(self):
        with tempfile.TemporaryDirectory() as tmp:
            proc = run_generator(Path(tmp) / "out.md", Path(tmp) / "absent.db")
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("absent.db", proc.stderr)

    def test_db_without_projects_table_fails_nonzero(self):
        with tempfile.TemporaryDirectory() as tmp:
            db = Path(tmp) / "empty.db"
            con = sqlite3.connect(db)
            con.execute("CREATE TABLE other (x INTEGER)")
            con.commit()
            con.close()
            proc = run_generator(Path(tmp) / "out.md", db)
        self.assertNotEqual(proc.returncode, 0)

    def test_live_duckbrain_row_refuses_to_publish(self):
        """A live duckbrain row would make the resolution false: refuse."""
        with tempfile.TemporaryDirectory() as tmp:
            db = Path(tmp) / "stale.db"
            con = sqlite3.connect(db)
            con.execute(
                "CREATE TABLE projects (name TEXT, parent TEXT, enabled INTEGER, workdir TEXT)"
            )
            con.execute(
                "INSERT INTO projects VALUES ('code-factory-duckbrain', '', 1, ?)",
                (str(Path.home() / "code-factory"),),
            )
            con.commit()
            con.close()
            proc = run_generator(Path(tmp) / "out.md", db)
            self.assertFalse((Path(tmp) / "out.md").exists(), "nothing must be written")
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("code-factory-duckbrain", proc.stderr)


class ModulesCiteTheInventory(unittest.TestCase):
    """AC3: modules 01, 07 and 35 cite the page; stale artifacts are gone."""

    def setUp(self):
        self.texts = {
            "01": MODULE_01.read_text(encoding="utf-8"),
            "07": MODULE_07.read_text(encoding="utf-8"),
            "35": MODULE_35.read_text(encoding="utf-8"),
        }

    def test_each_module_cites_the_inventory(self):
        for num, text in self.texts.items():
            self.assertIn(
                "lane-inventory.md", text, f"module {num} does not cite the page"
            )

    def test_module_35_drops_the_typed_lane_list(self):
        text = self.texts["35"]
        self.assertNotIn("code-factory-duckbrain", text)
        self.assertNotIn("16 lanes", text)

    def test_module_07_drops_the_quoted_lane_counts(self):
        text = self.texts["07"]
        self.assertNotIn("16 lanes", text)
        self.assertNotIn("lanes disagree: code-factory", text)

    def test_module_07_duckbrain_mentions_are_marked_historical(self):
        for line in self.texts["07"].splitlines():
            if "code-factory-duckbrain" in line:
                self.assertTrue(
                    any(
                        marker in line
                        for marker in ("2026-11-05", "retired", "superseded")
                    ),
                    f"unmarked duckbrain mention: {line[:120]}",
                )

    def test_module_01_drops_the_predefined_lane_count_claim(self):
        self.assertNotIn(
            "eight predefined code-factory satellite lanes", self.texts["01"]
        )

    def test_no_module_names_an_absolute_lane_count(self):
        """No `(N lanes)` / `N lanes` count for the code-factory family."""
        for num, text in self.texts.items():
            self.assertNotIn("16 lanes", text, f"module {num}")
            self.assertNotIn("code-factory (1 lane)", text, f"module {num}")


if __name__ == "__main__":
    unittest.main()
