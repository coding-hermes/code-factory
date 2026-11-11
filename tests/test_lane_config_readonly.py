#!/usr/bin/env python3
"""Hermetic read/write contract tests for load_lane_config.py (CF-304)."""

from __future__ import annotations

import hashlib
import os
from pathlib import Path
import shutil
import sqlite3
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "load_lane_config.py"
BASE = "fe63289e58b554d46afce69ea25bbced35d329e1"
LANES = {
    "code-factory": ("coding-hermes", "tasks", "foreman"),
    "code-factory-qa": ("qa", "cooldown", "qa"),
    "code-factory-pm": ("coding-hermes", "cooldown", "pm"),
    "code-factory-dogfood": ("dogfood", "cooldown", "dogfood"),
    "code-factory-sync": ("coding-hermes", "cooldown", "sync"),
    "code-factory-duckbrain": ("duckbrain-sync", "cooldown", "duckbrain"),
}
OUTSIDER = "unrelated-project"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(
    script: Path, db: Path, root: Path, *args: str
) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env["SCHEDULER_DB"] = str(db)
    env["CODE_FACTORY_ROOT"] = str(root)
    return subprocess.run(
        [sys.executable, "-B", str(script), *args],
        cwd=ROOT,
        env=env,
        text=True,
        capture_output=True,
        check=False,
    )


def make_fixture(parent: Path) -> tuple[Path, Path]:
    root = parent / "fixture-root"
    shutil.copytree(ROOT / "prompts", root / "prompts")
    db = parent / "scheduler.db"
    con = sqlite3.connect(db)
    con.execute(
        "CREATE TABLE projects (name TEXT PRIMARY KEY, namespace_id TEXT, "
        "admission_mode TEXT, prompt TEXT, prompt_mode TEXT)"
    )
    for name in LANES:
        con.execute(
            "INSERT INTO projects VALUES (?, ?, ?, ?, ?)",
            (name, "old-namespace", "old-mode", "old prompt", "replace"),
        )
    con.execute(
        "INSERT INTO projects VALUES (?, ?, ?, ?, ?)",
        (OUTSIDER, "outside-namespace", "outside-mode", "outside prompt", "replace"),
    )
    con.commit()
    con.close()
    return db, root


def rows(db: Path) -> dict[str, tuple[str, str, str, str]]:
    con = sqlite3.connect(db)
    result = {
        row[0]: row[1:]
        for row in con.execute(
            "SELECT name, namespace_id, admission_mode, prompt, prompt_mode "
            "FROM projects ORDER BY name"
        )
    }
    con.close()
    return result


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def arm_default(parent: Path, root: Path) -> None:
    db = parent / "default.db"
    shutil.copy2(parent / "scheduler.db", db)
    before = digest(db)
    result = run(SCRIPT, db, root)
    require(
        result.returncode == 0, f"default exit {result.returncode}: {result.stderr}"
    )
    require("UPDATE set" in result.stdout, "default did not print report")
    require(all(name in result.stdout for name in LANES), "default omitted a lane")
    require(digest(db) == before, "default changed the database bytes")
    require(rows(db) == rows(parent / "scheduler.db"), "default changed database rows")


def arm_dry_run(parent: Path, root: Path) -> None:
    db = parent / "dry-run.db"
    shutil.copy2(parent / "scheduler.db", db)
    before = digest(db)
    result = run(SCRIPT, db, root, "--dry-run", "--apply")
    require(
        result.returncode == 0, f"dry-run exit {result.returncode}: {result.stderr}"
    )
    require(digest(db) == before, "dry-run changed the database bytes")
    require(all(name in result.stdout for name in LANES), "dry-run omitted a lane")
    for name, (namespace, mode, prompt_name) in LANES.items():
        prompt_length = len((root / "prompts" / f"{prompt_name}.md").read_text())
        expected = f"{name}: namespace_id 'old-namespace' -> {namespace}; admission_mode 'old-mode' -> {mode}; prompt length 10 -> {prompt_length}"
        require(expected in result.stdout, f"dry-run omitted exact update for {name}")


def arm_apply(parent: Path, root: Path) -> None:
    db = parent / "apply.db"
    shutil.copy2(parent / "scheduler.db", db)
    before = digest(db)
    result = run(SCRIPT, db, root, "--apply")
    require(result.returncode == 0, f"apply exit {result.returncode}: {result.stderr}")
    require(digest(db) != before, "apply did not change the database")
    actual = rows(db)
    for name, (namespace, mode, prompt_name) in LANES.items():
        require(actual[name][0] == namespace, f"apply namespace mismatch for {name}")
        require(actual[name][1] == mode, f"apply admission mismatch for {name}")
        require(
            actual[name][2] == (root / "prompts" / f"{prompt_name}.md").read_text(),
            f"apply prompt mismatch for {name}",
        )
        require(actual[name][3] == "append", f"apply prompt mode mismatch for {name}")
    require(
        actual[OUTSIDER] == rows(parent / "scheduler.db")[OUTSIDER],
        "apply touched non-target row",
    )


def arm_refusals(parent: Path, root: Path) -> None:
    missing = parent / "does-not-exist.db"
    result = run(SCRIPT, missing, root)
    require(result.returncode != 0, "missing DB unexpectedly succeeded")
    require(
        "database missing:" in result.stderr,
        f"missing DB was not named: {result.stderr}",
    )
    db = parent / "missing-prompt.db"
    shutil.copy2(parent / "scheduler.db", db)
    before = digest(db)
    missing_root = parent / "missing-prompt-root"
    shutil.copytree(root, missing_root)
    (missing_root / "prompts" / "foreman.md").unlink()
    result = run(SCRIPT, db, missing_root, "--dry-run")
    require(result.returncode != 0, "missing prompt unexpectedly succeeded")
    require(
        "prompt file missing:" in result.stderr,
        f"missing prompt was not named: {result.stderr}",
    )
    require(digest(db) == before, "missing prompt changed the database")


def arm_red_control(parent: Path, root: Path) -> None:
    red_root = parent / "red-root"
    shutil.copytree(root, red_root)
    (red_root / "prompts" / "foreman.md").write_text("fixture prompt\n")
    pre_fix = parent / "pre-fix.py"
    source = subprocess.run(
        ["git", "show", f"{BASE}:scripts/load_lane_config.py"],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    require(source.returncode == 0, f"pre-fix source unavailable: {source.stderr}")
    pre_fix.write_text(source.stdout)
    db = parent / "pre-fix.db"
    shutil.copy2(parent / "scheduler.db", db)
    before = digest(db)
    result = run(pre_fix, db, red_root)
    require(result.returncode == 0, f"pre-fix invocation failed: {result.stderr}")
    require(digest(db) != before, "pre-fix control did not reproduce a write")
    require(
        rows(db)["code-factory"][0] == "coding-hermes",
        "pre-fix control did not write lane row",
    )


def main() -> int:
    arms = [
        ("default read-only report", arm_default),
        ("dry-run exact update set", arm_dry_run),
        ("explicit apply", arm_apply),
        ("named missing DB/prompt refusals", arm_refusals),
    ]
    failures = []
    with tempfile.TemporaryDirectory(prefix="cf304-") as temp:
        parent = Path(temp)
        db, root = make_fixture(parent)
        for label, arm in arms:
            try:
                arm(parent, root)
                print(f"PASS {label}")
            except AssertionError as exc:
                failures.append(label)
                print(f"FAIL {label}: {exc}")
        try:
            arm_red_control(parent, root)
            print("PASS red control: pre-fix script writes the fixture")
        except AssertionError as exc:
            failures.append("red control")
            print(f"FAIL red control: {exc}")
    if failures:
        print(f"LANE-CONFIG-READONLY: FAIL ({len(failures)})")
        return 1
    print(
        "LANE-CONFIG-READONLY: PASS (5 arms; default and dry-run byte-identical, apply scoped, refusals named, red control caught)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
