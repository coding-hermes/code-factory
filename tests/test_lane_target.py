#!/usr/bin/env python3
"""Hermetic tests for scripts/lane_target.py — no network, no real remotes.

The point of these tests is the defect they prevent: a lane workdir that is not a
plain local path (user@host:/path, ssh://, sftp://, ftp://, bunker://) must parse
and validate instead of being forced through os.makedirs, and a local path whose
git top level is $HOME must be rejected as the stand-in locator defect.

PERF-014: the read-only fixture repo (a main branch + an origin remote) is built
once per process and shared by every test that only reads it. Rebuilding it in
`setUp` cost four git spawns per test for state that never changed. Tests that
need their own state (the stand-in $HOME repo, the missing dir, the non-git dir)
keep their own throwaway directories.
"""

from __future__ import annotations

import atexit
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(
    0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts")
)
import lane_target  # noqa: E402

ORIGIN_URL = "https://example.invalid/o/r.git"

# A commit makes git spawn `maintenance run --auto --detach`, a child process this
# fixture has no use for; disabling it keeps the fixture deterministic (no reflog
# or pack activity racing teardown) and costs no coverage — nothing here reads
# maintenance state.
_GIT_CONFIG = {
    "GIT_CONFIG_COUNT": "1",
    "GIT_CONFIG_KEY_0": "maintenance.auto",
    "GIT_CONFIG_VALUE_0": "false",
}


def _git(cwd: str, *args: str) -> None:
    subprocess.run(
        ["git", "-C", cwd, *args],
        check=True,
        capture_output=True,
        env={
            **os.environ,
            **_GIT_CONFIG,
            "GIT_AUTHOR_NAME": "t",
            "GIT_AUTHOR_EMAIL": "t@example.invalid",
            "GIT_COMMITTER_NAME": "t",
            "GIT_COMMITTER_EMAIL": "t@example.invalid",
        },
    )


_FIXTURE: dict[str, str] | None = None


def fixture() -> dict[str, str]:
    """The shared read-only fixture: a plain `home` dir and a `repo` git checkout.

    Built on first use and reused by every test below, because each of them only
    reads it: `verify_local` and `scan` spawn git but never write to the target.
    """
    global _FIXTURE
    if _FIXTURE is None:
        root = tempfile.mkdtemp(prefix="lane-target-")
        atexit.register(shutil.rmtree, root, ignore_errors=True)
        home = os.path.join(root, "home")
        os.makedirs(home)
        repo = os.path.join(root, "repo")
        os.makedirs(repo)
        _git(repo, "init", "-q", "-b", "main")
        _git(repo, "commit", "-q", "--allow-empty", "-m", "init")
        # The exact stanza `git remote add origin <url>` writes, appended in-process
        # instead of spending a spawn on it. The tests prove it took effect through
        # git itself: `test_real_checkout_verifies` asserts remotes["origin"] and
        # `test_scan_mixed_rows` requires the ok-local row to pass `has_remote`.
        with open(os.path.join(repo, ".git", "config"), "a", encoding="utf-8") as fh:
            fh.write('[remote "origin"]\n\turl = %s\n' % ORIGIN_URL)
        _FIXTURE = {"root": root, "home": home, "repo": repo}
    return _FIXTURE


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
        self.assertEqual(
            (t.kind, t.scheme, t.user, t.host, t.path),
            ("remote", "ssh", "builder", "node-01", "/home/agent/cf"),
        )

    def test_scp_style_relative_path_normalised(self):
        self.assertEqual(lane_target.parse("b@h:srv/cf").path, "/srv/cf")

    def test_ssh_url_with_port(self):
        t = lane_target.parse("ssh://builder@node-01:2222/srv/cf")
        self.assertEqual(
            (t.port, t.user, t.host, t.path), (2222, "builder", "node-01", "/srv/cf")
        )

    def test_sftp_and_ftp(self):
        for raw in (
            "sftp://deploy@mirror/srv/cf",
            "ftp://deploy@mirror.example/pub/cf",
        ):
            t = lane_target.parse(raw)
            self.assertEqual(t.kind, "remote")
            self.assertEqual(t.user, "deploy")

    def test_bunker_agent(self):
        t = lane_target.parse("bunker://cf-worker/srv/cf")
        self.assertEqual((t.kind, t.agent, t.path), ("remote", "cf-worker", "/srv/cf"))

    def test_ipv4_host(self):
        self.assertEqual(
            lane_target.parse("b@192.168.1.20:/srv/cf").host, "192.168.1.20"
        )

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
    def test_real_checkout_verifies(self):
        f = fixture()
        out = lane_target.verify_local(f["repo"], home=f["home"])
        self.assertTrue(out["ok"], json.dumps(out, indent=2))
        self.assertEqual(out["remotes"]["origin"], ORIGIN_URL)

    def test_home_repo_rejected_as_standin_locator(self):
        # git init $HOME: the exact defect five satellites exhibited. This one needs
        # its own repo (the target IS the home dir), so it keeps a throwaway dir.
        standin = tempfile.mkdtemp(prefix="lane-target-home-")
        self.addCleanup(shutil.rmtree, standin, ignore_errors=True)
        _git(standin, "init", "-q", "-b", "main")
        out = lane_target.verify_local(standin, home=standin)
        self.assertFalse(out["ok"])
        checks = {c["check"]: c["ok"] for c in out["checks"]}
        self.assertFalse(checks["not_home_repo"])

    def test_missing_dir_fails(self):
        out = lane_target.verify_local(
            os.path.join(fixture()["root"], "nope"), home=fixture()["home"]
        )
        self.assertFalse(out["ok"])

    def test_non_git_dir_fails(self):
        plain = os.path.join(fixture()["root"], "plain")
        os.makedirs(plain, exist_ok=True)
        self.assertFalse(lane_target.verify_local(plain, home=fixture()["home"])["ok"])


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
        f = fixture()
        tmp = tempfile.mkdtemp(prefix="lane-scan-")
        self.addCleanup(shutil.rmtree, tmp, ignore_errors=True)

        path = os.path.join(tmp, "projects.jsonl")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(json.dumps({"name": "ok-local", "workdir": f["repo"]}) + "\n")
            fh.write(
                json.dumps({"name": "ok-remote", "workdir": "sftp://u@h/srv/cf"}) + "\n"
            )
            fh.write(json.dumps({"name": "bad-relative", "workdir": "work/cf"}) + "\n")

        out = lane_target.scan(path, allow_remote=True, home=f["home"])
        self.assertFalse(out["ok"])
        self.assertEqual(out["bad"], 1)
        names = {r["name"]: r["ok"] for r in out["rows"]}
        self.assertTrue(names["ok-local"])
        self.assertTrue(names["ok-remote"])
        self.assertFalse(names["bad-relative"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
