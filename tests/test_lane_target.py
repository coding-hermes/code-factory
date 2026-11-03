#!/usr/bin/env python3
"""Hermetic tests for scripts/lane_target.py — no network, no real remotes.

The point of these tests is the defect they prevent: a lane workdir that is not a
plain local path (user@host:/path, ssh://, sftp://, ftp://, bunker://) must parse
and validate instead of being forced through os.makedirs, and a local path whose
git top level is $HOME must be rejected as the stand-in locator defect.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts"))
import lane_target  # noqa: E402


def _git(cwd: str, *args: str) -> None:
    subprocess.run(
        ["git", "-C", cwd, *args],
        check=True,
        capture_output=True,
        env={**os.environ, "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@example.invalid",
             "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@example.invalid"},
    )


class ParseLocal(unittest.TestCase):
    def test_absolute_path(self):
        t = lane_target.parse("/srv/cf")
        self.assertEqual(t.kind, "local")
        self.assertTrue(t.is_local)
        self.assertEqual(t.path, "/srv/cf")

    def test_home_relative(self):
        t = lane_target.parse("~/work/cf")
        self.assertEqual(t.kind, "local")
        self.assertTrue(t.path.startswith(os.path.expanduser("~")))

    def test_local_scheme(self):
        self.assertEqual(lane_target.parse("local:/srv/cf").path, "/srv/cf")
        self.assertEqual(lane_target.parse("file:///srv/cf").path, "/srv/cf")

    def test_relative_rejected(self):
        with self.assertRaises(lane_target.TargetError):
            lane_target.parse("work/cf")

    def test_empty_rejected(self):
        for bad in ("", "   ", None):
            with self.assertRaises(lane_target.TargetError):
                lane_target.parse(bad)


class ParseRemote(unittest.TestCase):
    def test_scp_style_user_host_path(self):
        t = lane_target.parse("builder@node-01:/home/agent/cf")
        self.assertEqual((t.kind, t.scheme, t.user, t.host, t.path),
                         ("remote", "ssh", "builder", "node-01", "/home/agent/cf"))

    def test_scp_style_relative_path_normalised(self):
        self.assertEqual(lane_target.parse("b@h:srv/cf").path, "/srv/cf")

    def test_ssh_url_with_port(self):
        t = lane_target.parse("ssh://builder@node-01:2222/srv/cf")
        self.assertEqual((t.port, t.user, t.host, t.path), (2222, "builder", "node-01", "/srv/cf"))

    def test_sftp_and_ftp(self):
        for raw in ("sftp://deploy@mirror/srv/cf", "ftp://deploy@mirror.example/pub/cf"):
            t = lane_target.parse(raw)
            self.assertEqual(t.kind, "remote")
            self.assertEqual(t.user, "deploy")

    def test_bunker_agent(self):
        t = lane_target.parse("bunker://cf-worker/srv/cf")
        self.assertEqual((t.kind, t.agent, t.path), ("remote", "cf-worker", "/srv/cf"))

    def test_ipv4_host(self):
        self.assertEqual(lane_target.parse("b@192.168.1.20:/srv/cf").host, "192.168.1.20")

    def test_bad_port(self):
        with self.assertRaises(lane_target.TargetError):
            lane_target.parse("ssh://b@h:0/srv/cf")
        with self.assertRaises(lane_target.TargetError):
            lane_target.parse("ssh://b@h:99999/srv/cf")

    def test_unknown_scheme(self):
        with self.assertRaises(lane_target.TargetError):
            lane_target.parse("gopher://h/p")

    def test_missing_path(self):
        with self.assertRaises(lane_target.TargetError):
            lane_target.parse("ssh://b@h")

    def test_display_roundtrip(self):
        raw = "ssh://builder@node-01:2222/srv/cf"
        self.assertEqual(lane_target.parse(raw).display(), raw)


class VerifyLocal(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="lane-target-")
        self.home = os.path.join(self.tmp, "home")
        os.makedirs(self.home)
        self.repo = os.path.join(self.tmp, "repo")
        os.makedirs(self.repo)
        _git(self.repo, "init", "-q", "-b", "main")
        with open(os.path.join(self.repo, "README.md"), "w", encoding="utf-8") as fh:
            fh.write("x\n")
        _git(self.repo, "add", "README.md")
        _git(self.repo, "commit", "-qm", "init")
        _git(self.repo, "remote", "add", "origin", "https://example.invalid/o/r.git")

    def test_real_checkout_verifies(self):
        out = lane_target.verify_local(self.repo, home=self.home)
        self.assertTrue(out["ok"], json.dumps(out, indent=2))
        self.assertEqual(out["remotes"]["origin"], "https://example.invalid/o/r.git")

    def test_home_repo_rejected_as_standin_locator(self):
        # git init $HOME: the exact defect five satellites exhibited.
        _git(self.home, "init", "-q", "-b", "main")
        out = lane_target.verify_local(self.home, home=self.home)
        self.assertFalse(out["ok"])
        checks = {c["check"]: c["ok"] for c in out["checks"]}
        self.assertFalse(checks["not_home_repo"])

    def test_missing_dir_fails(self):
        out = lane_target.verify_local(os.path.join(self.tmp, "nope"), home=self.home)
        self.assertFalse(out["ok"])

    def test_non_git_dir_fails(self):
        plain = os.path.join(self.tmp, "plain")
        os.makedirs(plain)
        self.assertFalse(lane_target.verify_local(plain, home=self.home)["ok"])


class VerifyRemote(unittest.TestCase):
    def test_remote_requires_optin(self):
        t = lane_target.parse("builder@node-01:/srv/cf")
        with self.assertRaises(PermissionError):
            lane_target.verify(t, allow_remote=False)

    def test_remote_structural_only(self):
        t = lane_target.parse("builder@node-01:/srv/cf")
        out = lane_target.verify(t, allow_remote=True)
        self.assertTrue(out["ok"])
        self.assertEqual(out["verified"], "remote-structural-only")
        self.assertIn("NOT checked", out["note"])


class ScanProjects(unittest.TestCase):
    def test_scan_mixed_rows(self):
        tmp = tempfile.mkdtemp(prefix="lane-scan-")
        home = os.path.join(tmp, "home")
        os.makedirs(home)
        repo = os.path.join(tmp, "repo")
        os.makedirs(repo)
        _git(repo, "init", "-q", "-b", "main")
        with open(os.path.join(repo, "f"), "w", encoding="utf-8") as fh:
            fh.write("x")
        _git(repo, "add", "f")
        _git(repo, "commit", "-qm", "init")
        _git(repo, "remote", "add", "origin", "https://example.invalid/o/r.git")

        path = os.path.join(tmp, "projects.jsonl")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(json.dumps({"name": "ok-local", "workdir": repo}) + "\n")
            fh.write(json.dumps({"name": "ok-remote", "workdir": "sftp://u@h/srv/cf"}) + "\n")
            fh.write(json.dumps({"name": "bad-relative", "workdir": "work/cf"}) + "\n")

        out = lane_target.scan(path, allow_remote=True, home=home)
        self.assertFalse(out["ok"])
        self.assertEqual(out["bad"], 1)
        names = {r["name"]: r["ok"] for r in out["rows"]}
        self.assertTrue(names["ok-local"])
        self.assertTrue(names["ok-remote"])
        self.assertFalse(names["bad-relative"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
