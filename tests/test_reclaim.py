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
        blob = path / "payload"
        blob.write_bytes(b"x" * 4096)
        if old:
            # Age the deepest file too: CF-290 judges a cache by the newest mtime in
            # its subtree, so a fresh blob keeps an old directory alive (by design).
            stamp = time.time() - 48 * 3600
            os.utime(blob, (stamp, stamp))
            os.utime(path, (stamp, stamp))
        return path

    def cli(self, *args):
        return subprocess.run(
            [sys.executable, "-B", reclaim_disk.__file__, *args],
            capture_output=True,
            text=True,
        )

    def test_all_targets(self):
        # Aged, because every class now carries a TTL (CF-290): a fresh cache must
        # survive, which is `test_fresh_build_cache_survives_ttl`'s arm.
        for name in reclaim_disk.BUILD_CACHES:
            self.payload(name, old=True)
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
        cache = self.payload(".cache/pip", old=True)
        (cache / "link").symlink_to(outside, target_is_directory=True)
        # Age every component the subtree walk reads: creating the link moved the cache
        # directory's own mtime, and the gate reads the newest of all of them.
        stamp = time.time() - 48 * 3600
        for path in (cache / "payload", cache / "link"):
            os.utime(path, (stamp, stamp), follow_symlinks=False)
        os.utime(cache, (stamp, stamp))
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
            self.assertEqual(
                self.cli(
                    "run", "--root", str(self.root), "--cache-ttl-hours", ttl
                ).returncode,
                2,
            )

    def test_idempotence_and_json(self):
        self.payload(".cache/pip", old=True)
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
        cache = self.payload(".cache/pip", old=True)
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

    def test_fresh_build_cache_survives_ttl(self):
        """CF-290: a build cache in active use must survive a default reclaim."""
        cache = self.payload(".cache/pip")
        result = reclaim_disk.reclaim(str(self.root))
        entry = next(e for e in result["entries"] if e["name"] == ".cache/pip")
        self.assertEqual(entry["action"], "kept")
        self.assertIn("TTL", entry["reason"])
        self.assertIn("fresh (", entry["reason"])
        self.assertEqual(result["reclaimed_bytes"], 0)
        self.assertTrue(cache.exists())
        self.assertTrue((cache / "payload").exists())
        # The gate is age, not class: the same cache aged past the TTL is reaped.
        stamp = time.time() - 48 * 3600
        for path in (cache / "payload", cache):
            os.utime(path, (stamp, stamp))
        aged = reclaim_disk.reclaim(str(self.root))
        self.assertEqual(
            [e["name"] for e in aged["entries"] if e["action"] == "reaped"],
            [".cache/pip"],
        )
        self.assertEqual(aged["reclaimed_bytes"], 4096)
        self.assertFalse(cache.exists())
        # ... and an explicit TTL of zero reaps even a fresh cache, which is what
        # proves the flag is wired rather than a constant.
        self.payload(".cache/uv")
        forced = reclaim_disk.reclaim(str(self.root), 0, False, 0)
        self.assertFalse((self.root / ".cache/uv").exists())
        self.assertEqual(forced["reclaimed_bytes"], 4096)
        self.assertEqual(forced["cache_ttl_hours"], 0)

    def test_outside_root_returns_skipped(self):
        """CF-290: containment is answered, never spun on, for a non-contained path."""
        with tempfile.TemporaryDirectory(prefix="reclaim-outside-") as outside_tmp:
            outside = Path(outside_tmp) / "outside"
            outside.mkdir()
            (outside / "payload").write_bytes(b"untouched")
            # The pre-fix walk never terminated here (Path("/").parent == Path("/")),
            # so the assertion is made in a child process with a deadline: a regression
            # fails the arm instead of hanging the suite.
            probe = subprocess.run(
                [
                    sys.executable,
                    "-B",
                    "-c",
                    "import sys; sys.path.insert(0, sys.argv[1]); import reclaim_disk;"
                    " from pathlib import Path;"
                    " print(reclaim_disk.safety_reason(Path(sys.argv[2]), Path(sys.argv[3])))",
                    str(Path(reclaim_disk.__file__).resolve().parent),
                    str(self.root),
                    str(outside),
                ],
                capture_output=True,
                text=True,
                timeout=20,
            )
            self.assertEqual(probe.returncode, 0, probe.stderr)
            self.assertEqual(probe.stdout.strip(), "skipped:outside-root")
            self.assertEqual(
                reclaim_disk.safety_reason(self.root, outside), "skipped:outside-root"
            )
            self.assertEqual(
                reclaim_disk.safety_reason(self.root, Path("/")), "skipped:outside-root"
            )
            # An absent path is answered, not raised, and stays inside the root.
            self.assertEqual(
                reclaim_disk.safety_reason(self.root, self.root / "nope"), ""
            )
            self.assertEqual((outside / "payload").read_bytes(), b"untouched")
        # The temporary tree above is removed by the with-block, on every path.

    def test_targets(self):
        result = self.cli("targets")
        self.assertEqual(result.returncode, 0)
        for name in (*reclaim_disk.BUILD_CACHES, *reclaim_disk.AGED_PARENTS):
            self.assertIn(name, result.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
