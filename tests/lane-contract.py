#!/usr/bin/env python3
"""Hermetic CF-022 CLI controls, not live scheduler or dispatch proof."""

import json
import os
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
AUDIT = ROOT / "scripts/audit-lanes.py"
CANARY = "PRIVATE_CANARY_DO_NOT_PUBLISH"
CHECKER = """import argparse
import json
from pathlib import Path
import sqlite3
SATELLITE_FAMILY_PINS = {"qa": 43200}
SATELLITE_FAMILY_NAMESPACES = {"qa": "qa"}
p = argparse.ArgumentParser()
for flag in ("db", "toml", "board", "skills-root"):
    p.add_argument("--" + flag, required=True)
p.add_argument("--json", action="store_true", required=True)
a = p.parse_args()
assert Path(a.toml).is_file() and Path(a.board).is_file()
with sqlite3.connect(Path(a.db).as_uri() + "?mode=ro", uri=True) as con:
    cd = con.execute("SELECT cooldown_s FROM projects WHERE name='code-factory-qa'").fetchone()[0]
findings = json.loads(Path(__file__).with_suffix(".json").read_text())
if cd != SATELLITE_FAMILY_PINS["qa"]:
    findings.append({"class":"family-floor", "subject":"code-factory-qa", "detail":"PRIVATE_CANARY_DO_NOT_PUBLISH"})
print(json.dumps({"ok": not findings, "violations": findings}))
raise SystemExit(1 if findings else 0)
"""


class LaneContract(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="cf022-")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.hh = self.base / "hermes"
        self.root = self.base / "project"
        self.wd = self.hh / "stand-in/qa/code-factory"
        self.board = self.root / ".coding-hermes/board"
        self.board.mkdir(parents=True)
        (self.board / "tasks.jsonl").write_text('{"id":"CF-001","status":"pending"}\n')
        self.wd.mkdir(parents=True)
        (self.wd / ".coding-hermes").mkdir()
        (self.wd / ".coding-hermes/board").symlink_to(
            self.board, target_is_directory=True
        )
        self.db = self.base / "scheduler.db"
        self.toml = self.base / "fleet.toml"
        self.checker = self.base / "checker.py"
        self.checker.write_text(CHECKER)
        self.checker.with_suffix(".json").write_text("[]")
        with sqlite3.connect(self.db) as con:
            con.execute("""CREATE TABLE projects (
                name TEXT, namespace_id TEXT, parent TEXT, workdir TEXT, enabled INTEGER,
                cooldown_s INTEGER, cooldown_floor_s INTEGER, cooldown_ceiling_s INTEGER,
                cooldown_pin_s INTEGER, adaptive_cooldown INTEGER, admission_mode TEXT,
                board_ownership TEXT, prompt_mode TEXT, prompt TEXT, gateway_key TEXT)""")
            con.execute(
                "CREATE TABLE namespaces (id TEXT, default_prompt TEXT, admission_mode TEXT)"
            )
            con.executemany(
                "INSERT INTO namespaces VALUES (?,?,?)",
                [("coding-hermes", CANARY, "tasks"), ("qa", CANARY, "cooldown")],
            )
            con.executemany(
                "INSERT INTO projects VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                [
                    (
                        "code-factory",
                        "coding-hermes",
                        "",
                        str(self.root),
                        1,
                        21600,
                        0,
                        0,
                        None,
                        0,
                        "tasks",
                        "",
                        "append",
                        CANARY,
                        CANARY,
                    ),
                    (
                        "code-factory-qa",
                        "qa",
                        "code-factory",
                        str(self.wd),
                        1,
                        43200,
                        43200,
                        345600,
                        43200,
                        0,
                        "cooldown",
                        "",
                        "append",
                        CANARY,
                        CANARY,
                    ),
                ],
            )
        self.toml.write_text("""[[projects]]
name = "code-factory"
cooldown_s = 21600
[[projects]]
name = "code-factory-qa"
cooldown_s = 43200
""")
        self.argv = [
            sys.executable,
            "-B",
            str(AUDIT),
            "--db",
            str(self.db),
            "--toml",
            str(self.toml),
            "--checker",
            str(self.checker),
            "--hermes-home",
            str(self.hh),
            "--project-root",
            str(self.root),
        ]

    def run_audit(self, expected):
        before = self.db.read_bytes(), self.toml.read_bytes()
        proc = subprocess.run(
            self.argv,
            capture_output=True,
            text=True,
            timeout=15,
            env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"},
        )
        self.assertEqual(proc.returncode, expected, proc.stdout + proc.stderr)
        self.assertNotIn(CANARY, proc.stdout + proc.stderr)
        self.assertNotIn(str(self.base), proc.stdout + proc.stderr)
        self.assertEqual(before, (self.db.read_bytes(), self.toml.read_bytes()))
        return json.loads(proc.stdout)

    def sql(self, query):
        with sqlite3.connect(self.db) as con:
            con.execute(query)

    def test_positive_and_private_fields(self):
        result = self.run_audit(0)
        self.assertEqual(result["result"], "PASS")
        self.assertEqual(result["lane_count"], 2)
        self.assertEqual(result["enabled_count"], 2)
        qa = result["lanes"][1]
        self.assertTrue(qa["board_is_primary"])
        self.assertEqual(qa["board"], "$PROJECT_ROOT/.coding-hermes/board/tasks.jsonl")
        self.assertEqual(qa["workdir"], "$HERMES_HOME/stand-in/qa/code-factory")
        self.assertEqual(qa["canonical_cooldown_s"], 43200)
        self.assertEqual(result["dispatch_readiness"], "not-verified")

    def test_missing_inputs(self):
        for flag in ("--db", "--toml", "--checker"):
            with self.subTest(flag=flag):
                old = list(self.argv)
                self.argv[self.argv.index(flag) + 1] = str(self.base / "missing")
                self.run_audit(2)
                self.argv = old
        self.assertFalse((self.base / "missing").exists())

    def test_bad_inputs(self):
        for path in (self.db, self.toml, self.checker):
            with self.subTest(path=path.name):
                before = path.read_bytes()
                path.write_text("not a valid input!")
                self.run_audit(2)
                path.write_bytes(before)

    def test_zero_match_is_error(self):
        self.sql("DELETE FROM projects")
        self.run_audit(2)

    def test_primary_only_is_error(self):
        self.sql("DELETE FROM projects WHERE name='code-factory-qa'")
        self.run_audit(2)

    def test_live_drift_negative_then_positive(self):
        self.sql("UPDATE projects SET cooldown_s=900 WHERE name='code-factory-qa'")
        result = self.run_audit(1)
        self.assertIn(
            {"class": "family-floor", "subject": "code-factory-qa"},
            result["scoped_findings"],
        )
        self.assertIn("toml-field-drift", result["lanes"][1]["issues"])
        self.sql("UPDATE projects SET cooldown_s=43200 WHERE name='code-factory-qa'")
        self.run_audit(0)

    def test_missing_dangling_duplicate_and_bad_board(self):
        link = self.wd / ".coding-hermes/board"
        link.unlink()
        self.assertIn(
            "board-invalid-or-missing", self.run_audit(1)["lanes"][1]["issues"]
        )
        link.symlink_to(self.base / "absent")
        self.run_audit(1)
        link.unlink()
        link.mkdir()
        task = link / "tasks.jsonl"
        task.write_bytes((self.board / "tasks.jsonl").read_bytes())
        self.assertIn("board-not-primary", self.run_audit(1)["lanes"][1]["issues"])
        for value in ("", "garbage", "{}", "[]"):
            task.write_text(value)
            self.assertFalse(self.run_audit(1)["lanes"][1]["board_valid"])

    def test_absent_toml_project_is_not_parity(self):
        self.toml.write_text('[[projects]]\nname="other"\n')
        self.assertIn("toml-project-absent", self.run_audit(1)["lanes"][1]["issues"])

    def test_unknown_policy_not_silently_passed(self):
        for checker in (
            CHECKER.replace('"qa": "qa"', '"pm": "pm"'),
            CHECKER.replace('{"qa": 43200}', "43200"),
        ):
            self.checker.write_text(checker)
            self.run_audit(2)

    def test_unrelated_failure_is_separate(self):
        self.checker.with_suffix(".json").write_text(
            json.dumps(
                [{"class": "cooldown", "subject": "other-lane", "detail": CANARY}]
            )
        )
        result = self.run_audit(0)
        self.assertEqual(result["unrelated_finding_count"], 1)
        self.assertEqual(result["checker_exit"], 1)
        self.assertEqual(result["scoped_findings"], [])

    def test_primary_board_failure_is_scoped(self):
        self.checker.with_suffix(".json").write_text(
            json.dumps(
                [{"class": "board-vocab", "subject": "CF-001", "detail": CANARY}]
            )
        )
        result = self.run_audit(1)
        self.assertEqual(
            result["scoped_findings"],
            [{"class": "board-vocab", "subject": "<primary-board>"}],
        )
        self.assertEqual(result["unrelated_finding_count"], 0)

    def test_checker_failure_cannot_pass(self):
        self.checker.write_text(
            CHECKER.split("p = argparse")[0]
            + '\nprint("PRIVATE_CANARY_DO_NOT_PUBLISH")\nraise SystemExit(3)\n'
        )
        self.run_audit(2)

    def test_checker_false_clean_exit_is_error(self):
        self.checker.write_text(
            CHECKER.replace(
                "raise SystemExit(1 if findings else 0)", "raise SystemExit(0)"
            )
        )
        self.sql("UPDATE projects SET cooldown_s=900 WHERE name='code-factory-qa'")
        self.run_audit(2)

    def test_checker_malformed_shapes_are_safe_errors(self):
        for value in ([], None, {"ok": False, "violations": [None]}):
            with self.subTest(value=value):
                self.checker.write_text(
                    CHECKER.split("p = argparse")[0]
                    + "\nprint("
                    + repr(json.dumps(value))
                    + ")\nraise SystemExit(1)\n"
                )
                self.run_audit(2)

    def test_unknown_paths_and_identifiers_are_redacted(self):
        self.sql(
            f"UPDATE projects SET workdir='/outside/{CANARY}', namespace_id='{CANARY}', "
            f"parent='{CANARY}', admission_mode='{CANARY}' WHERE name='code-factory-qa'"
        )
        lane = self.run_audit(1)["lanes"][1]
        self.assertEqual(lane["workdir"], "<outside-known-roots>")
        self.assertEqual(lane["namespace_id"], "<unrecognized>")
        self.assertEqual(lane["parent"], "<external>")


if __name__ == "__main__":
    unittest.main()
