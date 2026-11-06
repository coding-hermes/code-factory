#!/usr/bin/env python3
"""Hermetic tests for scripts/clone_lane.py — no network, no real scheduler DB.

The point of these tests is the defect they prevent (CF-357): `clone_lane.py --from X --to X`
fetched the source row, rewrote it as if it were the destination and then ran
`UPDATE projects ... WHERE name=<X>` — which on a live lane disables and reconfigures
production scheduler state instead of failing. A typo must be a refusal, not a rewrite.

The refusal is asserted three ways: exit code 2, a stderr line naming `--to`, `--from` and the
shared lane name, and a source row that is identical (full `SELECT *` dump) before and after.
A third arm points `--db` at a path that does not exist and proves the file is still absent
afterwards, i.e. the refusal happens before any sqlite connection. The positive control runs a
genuine clone through the same fixture, so the refusal is not a blanket break.
"""

from __future__ import annotations

import os
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "..", "scripts", "clone_lane.py")

SRC = "fixture-src-lane"

# Every column the script reads or writes, plus the realistic not-null neighbours a live
# scheduler row carries: the clone does `SELECT *` and re-inserts the whole row, so a schema
# narrower than production would hide a broken INSERT/UPDATE path.
SCHEMA = """
CREATE TABLE projects (
    name                 TEXT PRIMARY KEY,
    repo_url             TEXT NOT NULL,
    workdir              TEXT NOT NULL,
    weight               INTEGER NOT NULL DEFAULT 10,
    priority             INTEGER NOT NULL DEFAULT 5,
    cooldown_s           INTEGER NOT NULL DEFAULT 900,
    decay_rate           REAL NOT NULL DEFAULT 1.0,
    model                TEXT NOT NULL DEFAULT 'deepseek-v4-pro',
    provider             TEXT NOT NULL DEFAULT 'deepseek-foreman',
    enabled              INTEGER NOT NULL DEFAULT 1,
    created_at           TEXT NOT NULL,
    updated_at           TEXT NOT NULL,
    last_tick_started    TEXT,
    last_tick_completed  TEXT,
    command              TEXT DEFAULT '',
    namespace_id         TEXT,
    deliver              TEXT DEFAULT '',
    worker_model         TEXT DEFAULT '',
    worker_provider      TEXT DEFAULT '',
    consecutive_failures INTEGER NOT NULL DEFAULT 0,
    fallback_model       TEXT DEFAULT '',
    fallback_provider    TEXT DEFAULT '',
    idle_model           TEXT NOT NULL DEFAULT '',
    idle_provider        TEXT NOT NULL DEFAULT '',
    model_chain          TEXT NOT NULL DEFAULT '',
    prompt               TEXT NOT NULL DEFAULT '',
    prompt_mode          TEXT NOT NULL DEFAULT 'append',
    adaptive_cooldown    INTEGER NOT NULL DEFAULT 0,
    cooldown_floor_s     INTEGER NOT NULL DEFAULT 0,
    cooldown_ceiling_s   INTEGER NOT NULL DEFAULT 0,
    admission_mode       TEXT NOT NULL DEFAULT '',
    board_ownership      TEXT NOT NULL DEFAULT '',
    parent               TEXT NOT NULL DEFAULT '',
    last_tick_status     TEXT NOT NULL DEFAULT '',
    scheduler_id         TEXT NOT NULL DEFAULT ''
)
"""

# Distinctive values: if the clone ever rewrote this row, any field changing would be visible.
SOURCE_ROW = {
    "name": SRC,
    "repo_url": "local:/srv/fixture/source-repo",
    "workdir": "/srv/fixture/source-workdir",
    "weight": 42,
    "priority": 7,
    "cooldown_s": 1800,
    "model": "source-model",
    "provider": "source-provider",
    "enabled": 1,
    "created_at": "2026-01-02T03:04:05Z",
    "updated_at": "2026-01-02T03:04:05Z",
    "last_tick_started": "2026-01-02T03:04:05Z",
    "last_tick_completed": "2026-01-02T03:05:05Z",
    "command": "source-command",
    "namespace_id": "source-namespace",
    "consecutive_failures": 3,
    "prompt": "SOURCE PROMPT BODY",
    "prompt_mode": "append",
    "cooldown_floor_s": 600,
    "admission_mode": "cooldown",
    "parent": "source-parent",
    "last_tick_status": "ok",
    "scheduler_id": "source-scheduler",
}


def build_db(path: str) -> None:
    """Create a temp scheduler-shaped DB holding one live source lane."""
    con = sqlite3.connect(path)
    try:
        con.executescript(SCHEMA)
        cols = list(SOURCE_ROW)
        con.execute(
            f"INSERT INTO projects ({','.join(cols)}) "
            f"VALUES ({','.join('?' * len(cols))})",
            [SOURCE_ROW[c] for c in cols],
        )
        con.commit()
    finally:
        con.close()


def dump(path: str) -> list[tuple]:
    """Every row of projects as plain tuples: `SELECT *` with no column ordering assumption."""
    con = sqlite3.connect(path)
    try:
        return [
            tuple(row) for row in con.execute("SELECT * FROM projects ORDER BY name")
        ]
    finally:
        con.close()


def fetch(path: str, name: str) -> dict | None:
    con = sqlite3.connect(path)
    con.row_factory = sqlite3.Row
    try:
        row = con.execute("SELECT * FROM projects WHERE name=?", (name,)).fetchone()
        return dict(row) if row is not None else None
    finally:
        con.close()


def run_script(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, "-B", SCRIPT, *args],
        capture_output=True,
        text=True,
        env={**os.environ, "SCHEDULER_DB": ""},
    )


class FixtureCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="clone-lane-")
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.db = os.path.join(self.tmp, "scheduler.db")
        build_db(self.db)


class SameLaneRefused(FixtureCase):
    """A lane may not be cloned onto itself; the source row must survive untouched."""

    def refuse(self, db: str | None = None) -> subprocess.CompletedProcess:
        return run_script(
            "--from",
            SRC,
            "--to",
            SRC,
            "--workdir",
            "/srv/fixture/new",
            "--namespace",
            "docs",
            "--parent",
            SRC,
            "--db",
            db or self.db,
        )

    def test_refusal_exits_2_and_names_both_arguments(self):
        out = self.refuse()
        self.assertEqual(out.returncode, 2, out.stderr)
        self.assertIn("REFUSED", out.stderr)
        self.assertIn("--to", out.stderr)
        self.assertIn("--from", out.stderr)
        self.assertIn(SRC, out.stderr)
        # No success line, no mutation report: the script stops before reading the row.
        self.assertEqual(out.stdout, "")
        self.assertNotIn("configured", out.stdout + out.stderr)
        self.assertNotIn("created", out.stdout + out.stderr)

    def test_source_row_is_identical_after_refusal(self):
        before = dump(self.db)
        self.refuse()
        after = dump(self.db)
        self.assertEqual(before, after, "the refused clone mutated the source row")
        row = fetch(self.db, SRC)
        self.assertIsNotNone(row)
        # The live fields the same-name UPDATE used to overwrite and disable.
        self.assertEqual(row["enabled"], 1)
        self.assertEqual(row["workdir"], SOURCE_ROW["workdir"])
        self.assertEqual(row["namespace_id"], SOURCE_ROW["namespace_id"])
        self.assertEqual(row["last_tick_status"], "ok")
        self.assertEqual(row["consecutive_failures"], 3)

    def test_refusal_happens_before_the_database_is_opened(self):
        # sqlite3.connect() creates the file on first use. Pointing --db at a path that does
        # not exist proves no connection was made: the file is still absent afterwards.
        absent = os.path.join(self.tmp, "never-created.db")
        out = self.refuse(absent)
        self.assertEqual(out.returncode, 2, out.stderr)
        self.assertFalse(
            os.path.exists(absent), "the refusal opened/created a database"
        )


class GenuineCloneStillWorks(FixtureCase):
    """Positive control: the refusal must not break the clone the script exists for."""

    def test_clone_to_a_new_lane_succeeds(self):
        out = run_script(
            "--from",
            SRC,
            "--to",
            "fixture-dst-lane",
            "--workdir",
            "/srv/fixture/dst",
            "--namespace",
            "docs",
            "--parent",
            "fixture-parent",
            "--db",
            self.db,
        )
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn(f"created fixture-dst-lane (cloned from {SRC})", out.stdout)
        dst = fetch(self.db, "fixture-dst-lane")
        self.assertIsNotNone(dst)
        self.assertEqual(dst["workdir"], "/srv/fixture/dst")
        self.assertEqual(dst["namespace_id"], "docs")
        self.assertEqual(dst["parent"], "fixture-parent")
        self.assertEqual(dst["enabled"], 0)
        self.assertEqual(dst["prompt"], SOURCE_ROW["prompt"])
        src = fetch(self.db, SRC)
        self.assertIsNotNone(src)
        self.assertEqual(src["workdir"], SOURCE_ROW["workdir"])
        self.assertEqual(src["enabled"], 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
