#!/usr/bin/env python3
"""CLI regressions for ownership residue classification (CF-412)."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


OWNERSHIP = Path(
    os.environ.get(
        "OWNERSHIP_PY", Path(__file__).resolve().parents[1] / "scripts/ownership.py"
    )
).resolve()


class OwnershipResidueTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="cf412-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / "repo"
        self.repo.mkdir()
        self.env = os.environ.copy()
        self.env.update(
            HOME=str(self.root),
            XDG_CONFIG_HOME=str(self.root / "config"),
            GIT_CONFIG_GLOBAL=os.devnull,
            GIT_CONFIG_NOSYSTEM="1",
            GIT_CONFIG_COUNT="0",
        )
        self.git("init", "-q")
        self.git("config", "user.email", "fixture@example.invalid")
        self.git("config", "user.name", "fixture")
        self.git(
            "-c",
            "core.hooksPath=/dev/null",
            "commit",
            "--allow-empty",
            "-qm",
            "fixture",
        )

    def git(self, *args):
        return subprocess.run(
            ["git", "-C", str(self.repo), *args],
            env=self.env,
            check=True,
            capture_output=True,
            text=True,
        ).stdout

    def put(self, path):
        target = self.repo / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text("fixture\n")

    def assert_state(self, state, code):
        result = subprocess.run(
            [
                sys.executable,
                "-B",
                str(OWNERSHIP),
                "status",
                "--workdir",
                str(self.repo),
            ],
            env=self.env,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, code, result.stderr + result.stdout)
        self.assertEqual(json.loads(result.stdout)["state"], state, result.stdout)

    def test_collapsed_rescue_directory_is_residue(self):
        self.put(".gitreins/rescued-1.patch")
        self.assertEqual(self.git("status", "--porcelain"), "?? .gitreins/\n")
        self.assert_state("residue", 3)

    def test_rescue_and_other_file_are_unowned(self):
        self.put(".gitreins/rescued-1.patch")
        self.put(".gitreins/unrelated.txt")
        self.assert_state("unowned-changes", 3)

    def test_nested_substring_is_not_residue(self):
        self.put("other/.gitreins/rescued-1.patch")
        self.assert_state("unowned-changes", 3)

    def test_other_nested_file_is_not_residue(self):
        self.put(".gitreins/nested/unrelated.txt")
        self.assert_state("unowned-changes", 3)

    def test_staged_tracked_changes_are_unowned(self):
        self.put("tracked.txt")
        self.git("add", "tracked.txt")
        self.git("-c", "core.hooksPath=/dev/null", "commit", "-qm", "tracked")
        self.put("tracked.txt")
        (self.repo / "tracked.txt").write_text("changed\n")
        self.git("add", "tracked.txt")
        self.assert_state("unowned-changes", 3)

    def test_clean(self):
        self.assert_state("clean", 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
