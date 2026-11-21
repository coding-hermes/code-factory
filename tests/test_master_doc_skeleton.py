#!/usr/bin/env python3
"""CF-323: destructive regeneration, stable membership, and dry-run controls."""

import contextlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/master_doc_skeleton.py"
MANIFEST = ROOT / "scripts/master_doc_manifest.json"


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class MasterDocTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="cf323-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.repo = self.root / "repo"
        self.out = self.root / "out"
        old = subprocess.run(
            ["git", "show", "c15ad4fa:scripts/master_doc_skeleton.py"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        ).stdout
        legacy = self.root / "legacy.py"
        legacy.write_text(old, encoding="utf-8")
        self.legacy = load(legacy, "cf323_legacy")
        self.new = load(SCRIPT, "cf323_new")
        # This fixture reproduces the historic 40 numbered rows independently of discovery.
        index = subprocess.run(
            ["git", "show", "7e76d934:docs/master/00-INDEX.md"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        ).stdout
        import re

        self.rows = [
            (int(n), name, filename)
            for n, name, filename in re.findall(
                r"\| (\d+) \| \[`([^`]+)`\]\(([^)]+)\)", index
            )
        ]
        self.assertEqual(len(self.rows), 40)
        for _, name, _ in self.rows:
            p = self.repo / name
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text("# fixture\n", encoding="utf-8")
        self.legacy.REPOS = [("code-factory", str(self.repo))]
        self.legacy.PROXY = str(self.root / "missing-proxy")
        self.legacy.OUT = self.out

    def old_run(self):
        with contextlib.redirect_stdout(io.StringIO()):
            self.legacy.main()

    def run_new(self, *args):
        output = io.StringIO()
        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
            rc = self.new.main(
                ["--repo-root", str(self.repo), "--output", str(self.out), *args]
            )
        return rc, output.getvalue()

    def test_filled_document_refused_and_force_explicit(self):
        self.out.mkdir()
        target = self.out / self.rows[0][2]
        target.write_text("filled evidence\n", encoding="utf-8")
        self.old_run()
        self.assertNotEqual(
            target.read_text(),
            "filled evidence\n",
            "old generator must reproduce overwrite",
        )
        target.write_text("filled evidence\n", encoding="utf-8")
        before = {p.name: p.read_bytes() for p in self.out.iterdir()}
        rc, output = self.run_new("--apply")
        self.assertNotEqual(rc, 0, output)
        self.assertIn("refus", output.lower())
        self.assertEqual(target.read_text(), "filled evidence\n")
        self.assertEqual(before, {p.name: p.read_bytes() for p in self.out.iterdir()})
        rc, output = self.run_new("--apply", "--force")
        self.assertEqual(rc, 0, output)
        self.assertNotEqual(target.read_text(), "filled evidence\n")

    def test_historic_mapping_survives_inserted_script(self):
        inserted = self.repo / "scripts/aaa-new.py"
        inserted.write_text("# new\n", encoding="utf-8")
        self.old_run()
        self.assertTrue(
            (self.out / "01-scripts-aaa-new-py.md").exists(),
            "old discovery must renumber",
        )
        mapping = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(
            [(r["number"], r["component"]) for r in mapping],
            [(n, name) for n, name, _ in self.rows],
        )
        other = self.root / "new-out"
        self.out = other
        rc, output = self.run_new("--apply")
        self.assertEqual(rc, 0, output)
        self.assertTrue(
            all((other / filename).is_file() for _, _, filename in self.rows)
        )
        self.assertFalse((other / "01-scripts-aaa-new-py.md").exists())

    def test_default_dry_run_and_idempotent_apply(self):
        self.old_run()
        self.assertTrue(self.out.exists(), "old default must write")
        self.out = self.root / "dry-out"
        rc, output = self.run_new()
        self.assertEqual(rc, 0, output)
        self.assertIn("+++", output)
        self.assertFalse(self.out.exists())
        rc, output = self.run_new("--apply")
        self.assertEqual(rc, 0, output)
        before = {
            p.name: (p.read_bytes(), p.stat().st_mtime_ns) for p in self.out.iterdir()
        }
        rc, output = self.run_new("--apply")
        self.assertEqual(rc, 0, output)
        self.assertEqual(
            before,
            {
                p.name: (p.read_bytes(), p.stat().st_mtime_ns)
                for p in self.out.iterdir()
            },
        )
        rc, output = self.run_new()
        self.assertEqual(rc, 0, output)
        self.assertNotIn("+++", output)


if __name__ == "__main__":
    unittest.main()
