#!/usr/bin/env python3
"""Hermetic coverage for bounded disk reclaim (CF-007 AC3)."""

from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import reclaim_disk  # noqa: E402


class Reclaim(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="reclaim-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name) / "home"
        self.root.mkdir()

    def payload(self, name, old=False):
        path = self.root / name
        path.mkdir(parents=True)
        (path / "payload").write_bytes(b"x" * 4096)
        if old:
            stamp = time.time() - 48 * 3600
            os.utime(path, (stamp, stamp))
        return path

    def cli(self, *args):
        return subprocess.run(
            [sys.executable, "-B", reclaim_disk.__file__, *args],
            capture_output=True,
            text=True,
        )

    def test_all_targets(self):
        for name in reclaim_disk.BUILD_CACHES:
            self.payload(name)
        result = reclaim_disk.reclaim(str(self.root))
        self.assertEqual(result["reclaimed_bytes"], 5 * 4096)
        for name in reclaim_disk.BUILD_CACHES:
            self.assertFalse((self.root / name).exists())

    def test_jobs_and_clones_ttl(self):
        for parent in reclaim_disk.AGED_PARENTS:
            old = self.payload(parent + "/old", old=True)
            fresh = self.payload(parent + "/fresh")
            reclaim_disk.reclaim(str(self.root))
            self.assertFalse(old.exists())
            self.assertTrue(fresh.exists())
        self.assertEqual(
            reclaim_disk.reclaim(str(self.root), 0)["reclaimed_bytes"], 8192
        )

    def test_symlinks_and_outside_survive(self):
        outside = Path(self.tmp.name) / "outside"
        outside.mkdir()
        (outside / "payload").write_bytes(b"untouched")
        for name in (".cache/pip", ".node/jobs/old", ".node/clones/old"):
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.symlink_to(outside, target_is_directory=True)
        result = reclaim_disk.reclaim(str(self.root))
        skipped = [e for e in result["entries"] if e["reason"] == "skipped:symlink"]
        self.assertEqual(len(skipped), 3)
        self.assertEqual((outside / "payload").read_bytes(), b"untouched")
        self.assertTrue((self.root / ".cache/pip").is_symlink())

    def test_symlink_parent_and_nested_symlink(self):
        outside = Path(self.tmp.name) / "outside"
        outside.mkdir()
        (outside / "pip").mkdir()
        (self.root / ".cache").symlink_to(outside, target_is_directory=True)
        result = reclaim_disk.reclaim(str(self.root))
        self.assertTrue((outside / "pip").exists())
        self.assertEqual(result["entries"][0]["reason"], "skipped:symlink")
        (self.root / ".cache").unlink()
        cache = self.payload(".cache/pip")
        (cache / "link").symlink_to(outside, target_is_directory=True)
        result = reclaim_disk.reclaim(str(self.root))
        self.assertTrue((cache / "link").is_symlink())
        self.assertTrue(
            any(e["reason"] == "skipped:symlink" for e in result["entries"])
        )

    def test_protected_paths_survive_even_when_old(self):
        self.payload("repo", old=True)
        for name in reclaim_disk.PROTECTED[1:]:
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"identity")
            os.utime(path, (1, 1))
        reclaim_disk.reclaim(str(self.root), 0)
        for name in reclaim_disk.PROTECTED:
            self.assertTrue((self.root / name).exists())
        self.assertEqual((self.root / "repo/payload").stat().st_size, 4096)

    def test_invalid_roots_and_ttl(self):
        file = self.root / "file"
        file.touch()
        for root in ("/", str(file), str(self.root / "absent")):
            with self.subTest(root=root):
                self.assertEqual(self.cli("run", "--root", root).returncode, 2)
        for ttl in ("-1", "nan", "inf"):
            self.assertEqual(
                self.cli(
                    "run", "--root", str(self.root), "--job-ttl-hours", ttl
                ).returncode,
                2,
            )

    def test_idempotence_and_json(self):
        self.payload(".cache/pip")
        first = self.cli("run", "--root", str(self.root), "--json")
        self.assertEqual(first.returncode, 0, first.stderr)
        self.assertEqual(
            json.loads(first.stdout.splitlines()[-1])["reclaimed_bytes"], 4096
        )
        second = self.cli("run", "--root", str(self.root), "--json")
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertEqual(
            json.loads(second.stdout.splitlines()[-1])["reclaimed_bytes"], 0
        )
        self.assertIn("nothing to reclaim", second.stdout)

    def test_dry_run_reports_same_bytes_without_removal(self):
        cache = self.payload(".cache/pip")
        old = self.payload(".node/jobs/old", old=True)
        preview = self.cli("run", "--root", str(self.root), "--dry-run", "--json")
        self.assertEqual(preview.returncode, 0, preview.stderr)
        self.assertTrue((cache / "payload").exists())
        self.assertTrue((old / "payload").exists())
        actual = reclaim_disk.reclaim(str(self.root))
        self.assertEqual(
            json.loads(preview.stdout.splitlines()[-1])["reclaimed_bytes"],
            actual["reclaimed_bytes"],
        )
        self.assertEqual(actual["reclaimed_bytes"], 8192)

    def test_targets(self):
        result = self.cli("targets")
        self.assertEqual(result.returncode, 0)
        for name in (*reclaim_disk.BUILD_CACHES, *reclaim_disk.AGED_PARENTS):
            self.assertIn(name, result.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
