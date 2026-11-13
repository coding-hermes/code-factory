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


GIT_BIN = shutil.which("git") or "git"


def _git(cwd: str, *args: str) -> None:
    subprocess.run(
        [GIT_BIN, "-C", cwd, *args],
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
        t = lane_target.parse("builder@node-01:/srv/cf")
        self.assertEqual(
            (t.kind, t.scheme, t.user, t.host, t.path),
            ("remote", "ssh", "builder", "node-01", "/srv/cf"),
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


class RepoURL(unittest.TestCase):
    def run_check(self, *args, rows=None):
        return subprocess.run(
            [sys.executable, "-B", str(lane_target.__file__), "repo-url", *args],
            input=json.dumps(rows) if rows is not None else None,
            capture_output=True,
            text=True,
        )

    def test_phantom_root(self):
        path = os.path.join(fixture()["root"], "phantom")
        out = self.run_check("local:" + path)
        self.assertEqual(out.returncode, 4, out.stderr)
        self.assertIn(f"FAIL repo_url 'local:{path}' — path does not exist", out.stdout)
        self.assertIn("1 rejected, 0 accepted", out.stdout)

    def test_non_git_directory(self):
        path = fixture()["home"]
        out = self.run_check(path)
        self.assertEqual(out.returncode, 4, out.stderr)
        self.assertIn(
            f"FAIL repo_url '{path}' — not a git root (git: fatal:", out.stdout
        )

    def test_subdirectory(self):
        path = os.path.join(fixture()["repo"], "subdir")
        os.makedirs(path, exist_ok=True)
        out = self.run_check("local:" + path)
        self.assertEqual(out.returncode, 4, out.stderr)
        self.assertIn(
            f"not a git root (git: top level is '{fixture()['repo']}')", out.stdout
        )

    def test_real_root_spellings(self):
        path = fixture()["repo"]
        head = lane_target._git(path, "rev-parse", "HEAD").stdout.strip()
        for raw in (path, "local:" + path, "file:" + path, "file://" + path):
            with self.subTest(raw=raw):
                out = self.run_check(raw)
                self.assertEqual(out.returncode, 0, out.stderr)
                self.assertIn(
                    f"PASS repo_url {raw!r} — root {path!r} HEAD {head}", out.stdout
                )
                self.assertIn("0 rejected, 1 accepted", out.stdout)

    def test_home_relative_and_symlink(self):
        path = fixture()["repo"]
        relative = "~/" + os.path.relpath(path, os.path.expanduser("~"))
        link = os.path.join(fixture()["root"], "link")
        os.symlink(path, link)
        for raw in (relative, link):
            out = self.run_check(raw)
            self.assertEqual(out.returncode, 0, out.stderr)
            self.assertIn(f"root {path!r} HEAD", out.stdout)

    def test_remote_requires_optin(self):
        raw = "ssh://u@example.invalid/srv/repo"
        out = self.run_check(raw)
        self.assertEqual(out.returncode, 3, out.stderr)
        self.assertIn(f"FAIL repo_url {raw!r} — target", out.stdout)
        self.assertIn("Re-run with --allow-remote", out.stdout)
        out = self.run_check(raw, "--allow-remote")
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("remote-structural-only", out.stdout)

    def test_rows_stdin_and_file(self):
        rows = [
            {"name": "primary", "repo_url": fixture()["repo"]},
            {"name": "primary-qa", "repo_url": "local:" + fixture()["root"]},
        ]
        out = self.run_check("--row", "-", rows=rows)
        self.assertEqual(out.returncode, 4, out.stderr)
        self.assertIn("1 rejected, 1 accepted", out.stdout)
        self.assertIn("[primary-qa]", out.stdout)
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json") as fh:
            json.dump(rows[0], fh)
            fh.flush()
            out = self.run_check("--row", fh.name)
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("[primary]", out.stdout)

    def test_invalid_rows(self):
        for rows in ({}, {"repo_url": 42}, [None], "not a row", []):
            with self.subTest(rows=rows):
                out = self.run_check("--row", "-", rows=rows)
                self.assertEqual(out.returncode, 2, out.stderr)
                self.assertIn("FAIL repo_url", out.stdout)
        out = self.run_check("--row", "-", rows={"repo_url": "relative/path"})
        self.assertEqual(out.returncode, 2, out.stderr)
        self.assertIn("cannot classify target", out.stdout)


class RepoURLHomeRoot(unittest.TestCase):
    """CF-097: `repo-url` and `verify` must agree that a $HOME-rooted repo is no root.

    Both arms are driven with HOME pointing INSIDE the fixture — the subprocess gets
    `HOME=<fixture>` and `verify_local` gets the same directory as its `home` — so
    neither leg reads the host's real home and the pair cannot pass by agreeing about
    a directory this test never built.
    """

    def setUp(self):
        self.root = tempfile.mkdtemp(prefix="lane-target-home-root-")
        self.addCleanup(shutil.rmtree, self.root, ignore_errors=True)
        self.home = os.path.join(self.root, "home")
        os.makedirs(self.home)
        _git(self.home, "init", "-q", "-b", "main")
        _git(self.home, "commit", "-q", "--allow-empty", "-m", "fixture")
        self.home_real = os.path.realpath(self.home)

    def run_check(self, *args):
        return subprocess.run(
            [sys.executable, "-B", str(lane_target.__file__), "repo-url", *args],
            capture_output=True,
            text=True,
            env={**os.environ, "HOME": self.home_real},
        )

    def test_home_rooted_repo_rejected_by_both_arms(self):
        verified = lane_target.verify_local(self.home_real, home=self.home_real)
        self.assertFalse(verified["ok"])
        checks = {c["check"]: c["ok"] for c in verified["checks"]}
        self.assertFalse(checks["not_home_repo"])
        out = self.run_check(self.home_real)
        self.assertEqual(out.returncode, 4, out.stdout + out.stderr)
        self.assertIn(
            f"FAIL repo_url {self.home_real!r} — not_home_repo: git top level is "
            f"the home directory {self.home_real!r}",
            out.stdout,
        )
        self.assertIn("repo_url: 1 rejected, 0 accepted", out.stdout)
        self.assertNotIn("PASS repo_url", out.stdout)

    def test_non_home_root_still_accepted_under_fixture_home(self):
        repo = fixture()["repo"]
        head = lane_target._git(repo, "rev-parse", "HEAD").stdout.strip()
        out = self.run_check(repo)
        self.assertEqual(out.returncode, 0, out.stdout + out.stderr)
        self.assertIn(f"PASS repo_url {repo!r} — root {repo!r} HEAD {head}", out.stdout)
        self.assertIn("repo_url: 0 rejected, 1 accepted", out.stdout)

    def test_subdirectory_of_home_repo_names_the_top_level_mismatch(self):
        # Order matters: only a target that IS the home directory carries the
        # not_home_repo reason; a path inside it is still the ordinary mismatch.
        sub = os.path.join(self.home_real, "sub")
        os.makedirs(sub)
        out = self.run_check(sub)
        self.assertEqual(out.returncode, 4, out.stdout + out.stderr)
        self.assertIn(f"top level is {self.home_real!r}", out.stdout)
        self.assertNotIn("not_home_repo", out.stdout)


def two_roots() -> dict[str, str]:
    """Two real, different git roots for the CF-091 family-agreement tests."""
    root = tempfile.mkdtemp(prefix="lane-family-")
    atexit.register(shutil.rmtree, root, ignore_errors=True)
    made = {"root": root}
    for name in ("repo-a", "repo-b"):
        path = os.path.join(root, name)
        os.makedirs(path)
        _git(path, "init", "-q", "-b", "main")
        _git(path, "commit", "-q", "--allow-empty", "-m", "init")
        made[name] = path
    return made


class RepoURLFamilyAgreement(unittest.TestCase):
    """CF-091: a satellite's repo_url must agree with its family primary."""

    def run_check(self, *args, rows=None):
        return subprocess.run(
            [sys.executable, "-B", str(lane_target.__file__), "repo-url", *args],
            input=json.dumps(rows) if rows is not None else None,
            capture_output=True,
            text=True,
        )

    def test_suffix_primary_and_ordinary_primary_match(self):
        roots = two_roots()
        for primary in ("notes", "notes-docs"):
            for diverged in (False, True):
                with self.subTest(primary=primary, diverged=diverged):
                    rows = [
                        {"name": primary, "repo_url": roots["repo-a"]},
                        {
                            "name": primary + "-qa",
                            "repo_url": roots["repo-b" if diverged else "repo-a"],
                        },
                    ]
                    out = self.run_check("--row", "-", rows=rows)
                    self.assertEqual(out.returncode, 4 if diverged else 0, out.stdout)
                    if diverged:
                        self.assertIn(f"diverges from primary '{primary}'", out.stdout)

    def test_nested_primary_compared_to_own_satellite_and_parent(self):
        roots = two_roots()
        rows = [
            {"name": "notes", "repo_url": roots["repo-a"]},
            {"name": "notes-docs", "repo_url": roots["repo-a"]},
            {"name": "notes-docs-qa", "repo_url": roots["repo-b"]},
        ]
        out = self.run_check("--row", "-", rows=rows)
        self.assertEqual(out.returncode, 4, out.stdout)
        self.assertIn("diverges from primary 'notes-docs'", out.stdout)

    def test_duplicate_primary_is_ambiguous(self):
        roots = two_roots()
        rows = [
            {"name": "notes", "repo_url": roots["repo-a"]},
            {"name": "notes", "repo_url": roots["repo-b"]},
            {"name": "notes-qa", "repo_url": roots["repo-a"]},
        ]
        out = self.run_check("--row", "-", rows=rows)
        self.assertNotEqual(out.returncode, 0, out.stdout)
        self.assertIn("ambiguous", out.stdout)

    def test_invalid_root_still_compared(self):
        rows = [
            {"name": "notes-docs", "repo_url": "/missing-cf305-root"},
            {"name": "notes-docs-qa", "repo_url": fixture()["repo"]},
        ]
        out = self.run_check("--row", "-", rows=rows)
        self.assertEqual(out.returncode, 4, out.stdout)
        self.assertIn("diverges from primary 'notes-docs'", out.stdout)
        self.assertIn("2 rejected, 0 accepted", out.stdout)

    def test_sync_remains_independent_from_parent(self):
        roots = two_roots()
        rows = [
            {"name": "notes", "repo_url": roots["repo-a"]},
            {"name": "notes-sync", "repo_url": roots["repo-b"]},
        ]
        out = self.run_check("--row", "-", rows=rows)
        self.assertEqual(out.returncode, 0, out.stdout)
        self.assertNotIn("diverges", out.stdout)

    def test_diverged_satellite_is_rejected_naming_both_lanes(self):
        roots = two_roots()
        rows = [
            {"name": "proj", "repo_url": "local:" + roots["repo-a"]},
            {"name": "proj-qa", "repo_url": "local:" + roots["repo-b"]},
        ]
        out = self.run_check("--row", "-", rows=rows)
        self.assertEqual(out.returncode, 4, out.stdout)
        self.assertIn("repo_url diverges from primary 'proj'", out.stdout)
        # Both lanes of the family are named in the output.
        self.assertIn("[proj]", out.stdout)
        self.assertIn("[proj-qa]", out.stdout)
        self.assertIn("1 rejected, 1 accepted", out.stdout)

    def test_aligned_satellite_passes(self):
        roots = two_roots()
        rows = [
            {"name": "proj", "repo_url": "local:" + roots["repo-a"]},
            {"name": "proj-qa", "repo_url": "local:" + roots["repo-a"]},
        ]
        out = self.run_check("--row", "-", rows=rows)
        self.assertEqual(out.returncode, 0, out.stdout)
        self.assertIn("0 rejected, 2 accepted", out.stdout)
        self.assertNotIn("diverges", out.stdout)

    def test_spelling_normalization_agrees(self):
        # ~, local:, file: and a trailing slash naming the same checkout agree.
        path = fixture()["repo"]
        relative = "local:~/" + os.path.relpath(path, os.path.expanduser("~"))
        rows = [
            {"name": "proj", "repo_url": path + "/"},
            {"name": "proj-perf", "repo_url": relative},
        ]
        out = self.run_check("--row", "-", rows=rows)
        self.assertEqual(out.returncode, 0, out.stdout)
        self.assertIn("0 rejected, 2 accepted", out.stdout)

    def test_sync_pair_is_not_grouped(self):
        # A -sync lane's leaf is its full lane name, so two sync lanes with
        # different roots must never be compared.
        roots = two_roots()
        rows = [
            {"name": "aa-sync", "repo_url": "local:" + roots["repo-a"]},
            {"name": "bb-sync", "repo_url": "local:" + roots["repo-b"]},
        ]
        out = self.run_check("--row", "-", rows=rows)
        self.assertEqual(out.returncode, 0, out.stdout)
        self.assertIn("0 rejected, 2 accepted", out.stdout)
        self.assertNotIn("diverges", out.stdout)

    def test_unrelated_lanes_with_different_roots_pass(self):
        roots = two_roots()
        rows = [
            {"name": "one", "repo_url": "local:" + roots["repo-a"]},
            {"name": "two", "repo_url": "local:" + roots["repo-b"]},
        ]
        out = self.run_check("--row", "-", rows=rows)
        self.assertEqual(out.returncode, 0, out.stdout)
        self.assertIn("0 rejected, 2 accepted", out.stdout)
        self.assertNotIn("diverges", out.stdout)

    def test_single_target_call_unchanged(self):
        roots = two_roots()
        out = self.run_check("local:" + roots["repo-a"])
        self.assertEqual(out.returncode, 0, out.stdout)
        self.assertIn("0 rejected, 1 accepted", out.stdout)
        self.assertNotIn("diverges", out.stdout)


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


class VerifyBunker(unittest.TestCase):
    """bunker:// targets are proved by asking the agent, never assumed."""

    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="bunker-shim-")
        self.bin = os.path.join(self.tmp, "bin")
        os.makedirs(self.bin)
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)

    def _shim(self, home="/home/bunker-abc", exists=True, exit_code=0):
        path = os.path.join(self.bin, "bunker")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(
                "#!/usr/bin/env bash\n"
                "if [ \"$1\" = info ]; then\n"
                "  echo '══════════ Agent: abc ══════════'\n"
                "  echo 'bunker: reading server \"staging\"' >&2\n"
                "  exit 0\n"
                "fi\n"
                f'echo "HOME={home}"\n'
                f'echo "PATH_EXISTS={"1" if exists else "0"}"\n'
                f"exit {exit_code}\n"
            )
        os.chmod(path, 0o755)
        return path

    def test_existing_path_verifies(self):
        client = self._shim(exists=True)
        t = lane_target.parse("bunker://abc/srv/repo")
        old = os.environ["PATH"]
        os.environ["PATH"] = self.bin + os.pathsep + old
        try:
            out = lane_target.verify_bunker(t, bunker_bin=os.path.join(self.bin, "bunker"))
        finally:
            os.environ["PATH"] = old
        self.assertTrue(out["ok"], json.dumps(out, indent=2))
        self.assertEqual(out["verified"], "bunker-exec")
        self.assertEqual(out["agent_home"], "/home/bunker-abc")

    def test_missing_path_fails(self):
        self._shim(exists=False)
        t = lane_target.parse("bunker://abc/srv/nope")
        old = os.environ["PATH"]
        os.environ["PATH"] = self.bin + os.pathsep + old
        try:
            out = lane_target.verify_bunker(t, bunker_bin=os.path.join(self.bin, "bunker"))
        finally:
            os.environ["PATH"] = old
        self.assertFalse(out["ok"])
        checks = {c["check"]: c["ok"] for c in out["checks"]}
        self.assertFalse(checks["path_exists"])

    def test_unreachable_agent_fails(self):
        t = lane_target.parse("bunker://abc/srv/repo")
        old = os.environ["PATH"]
        os.environ["PATH"] = os.path.join(self.tmp, "empty")
        try:
            out = lane_target.verify_bunker(t, bunker_bin=os.path.join(self.bin, "bunker"))
        finally:
            os.environ["PATH"] = old
        self.assertFalse(out["ok"])
        self.assertIn("client_identity", [c["check"] for c in out["checks"]])

    def test_exec_flag_and_identity_server(self):
        self._shim()
        env = {**os.environ, "PATH": self.bin + os.pathsep + os.environ["PATH"], "BUNKER_BIN": os.path.join(self.bin, "bunker")}
        out = subprocess.run(
            [sys.executable, lane_target.__file__, "verify", "bunker://abc/srv/repo",
             "--exec-bunker", "--bunker-server", "staging"],
            capture_output=True, text=True, env=env,
        )
        self.assertEqual(out.returncode, 0, out.stdout + out.stderr)
        result = json.loads(out.stdout)
        self.assertEqual(result["verified"], "bunker-exec")
        self.assertTrue(next(c for c in result["checks"] if c["check"] == "client_identity")["ok"])

    def test_stub_and_wrong_identity_refused_by_verify_and_plan(self):
        path = os.path.join(self.tmp, "lanes.jsonl")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(json.dumps({"name": "lane"}) + "\n")
        env = {**os.environ, "PATH": self.bin + os.pathsep + os.environ["PATH"], "BUNKER_BIN": os.path.join(self.bin, "bunker")}
        for identity in ("HOME=/opt/lane-home\\nPATH_EXISTS=1", "══════════ Agent: wrong ══════════"):
            with self.subTest(identity=identity):
                with open(os.path.join(self.bin, "bunker"), "w", encoding="utf-8") as fh:
                    fh.write("#!/bin/sh\nprintf '" + identity + "\\n'\n")
                os.chmod(os.path.join(self.bin, "bunker"), 0o755)
                verified = subprocess.run(
                    [sys.executable, lane_target.__file__, "verify", "bunker://abc/srv/repo", "--exec-bunker"],
                    capture_output=True, text=True, env=env,
                )
                self.assertNotEqual(verified.returncode, 0)
                row = next(c for c in json.loads(verified.stdout)["checks"] if c["check"] == "client_identity")
                self.assertFalse(row["ok"])
                self.assertIn(identity.split("\\n")[0], row["value"])
                for extra in ([], ["--path", "/srv/repo"]):
                    plan = subprocess.run(
                        [sys.executable, lane_target.__file__, "plan", path, "--agent", "abc", *extra],
                        capture_output=True, text=True, env=env,
                    )
                    self.assertNotEqual(plan.returncode, 0, plan.stdout)
                    self.assertIn("client_identity", plan.stderr)
                    self.assertEqual(plan.stdout, "")

    def test_wrong_server_refused(self):
        self._shim()
        env = {**os.environ, "PATH": self.bin + os.pathsep + os.environ["PATH"], "BUNKER_BIN": os.path.join(self.bin, "bunker")}
        out = subprocess.run(
            [sys.executable, lane_target.__file__, "verify", "bunker://abc/srv/repo",
             "--exec-bunker", "--bunker-server", "other"],
            capture_output=True, text=True, env=env,
        )
        self.assertNotEqual(out.returncode, 0)
        row = next(c for c in json.loads(out.stdout)["checks"] if c["check"] == "client_identity")
        self.assertFalse(row["ok"])
        self.assertIn('reading server "staging"', row["value"])

    def test_plan_refuses_nothing_but_emits_targets(self):
        path = os.path.join(self.tmp, "lanes.jsonl")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(json.dumps({"name": "code-factory-docs"}) + "\n")
            fh.write(json.dumps({"name": "other-lane"}) + "\n")
        self._shim()
        env = {**os.environ, "PATH": self.bin + os.pathsep + os.environ["PATH"], "BUNKER_BIN": os.path.join(self.bin, "bunker")}
        for extra in (["--path", "/srv/repo"], []):
            out = subprocess.run(
                [sys.executable, lane_target.__file__, "plan", path, "--agent", "abc",
                 "--prefix", "code-factory", *extra],
                capture_output=True, text=True, env=env,
            )
            self.assertEqual(out.returncode, 0, out.stderr)
            rows = json.loads(out.stdout)
            self.assertEqual(len(rows), 1)
            self.assertEqual(rows[0]["workdir"], "bunker://abc" +
                             ("/srv/repo" if extra else "/home/bunker-abc/repo"))

    def test_mimicking_path_stub_requires_matching_pin(self):
        mimic = self._shim()
        other = os.path.join(self.tmp, "other")
        with open(other, "w", encoding="utf-8") as fh:
            fh.write("#!/bin/sh\necho wrong\n")
        os.chmod(other, 0o755)
        env = {**os.environ, "PATH": self.bin + os.pathsep + os.environ["PATH"], "BUNKER_BIN": mimic}
        cmd = [sys.executable, lane_target.__file__, "verify", "bunker://abc/srv/repo", "--exec-bunker", "--bunker-server", "staging"]
        denied = subprocess.run(cmd + ["--bunker-bin", other], capture_output=True, text=True, env=env)
        self.assertNotEqual(denied.returncode, 0)
        self.assertFalse(json.loads(denied.stdout)["checks"][0]["ok"])
        allowed = subprocess.run(cmd, capture_output=True, text=True, env=env)
        self.assertEqual(allowed.returncode, 0, allowed.stdout + allowed.stderr)
        row = json.loads(allowed.stdout)["checks"][0]
        self.assertIn(os.path.realpath(mimic), row["value"])
        import hashlib
        with open(mimic, "rb") as fh:
            self.assertIn(hashlib.sha256(fh.read()).hexdigest(), row["value"])
        self.assertIn("Agent: abc", row["value"])
        self.assertIn('reading server "staging"', row["value"])

    def test_unpinned_client_is_refused_with_remedy(self):
        self._shim()
        env = {**os.environ, "PATH": self.bin + os.pathsep + os.environ["PATH"], "BUNKER_BIN": os.path.join(self.bin, "bunker")}
        env.pop("BUNKER_BIN", None)
        out = subprocess.run([sys.executable, lane_target.__file__, "verify", "bunker://abc/srv/repo", "--exec-bunker"], capture_output=True, text=True, env=env)
        row = json.loads(out.stdout)["checks"][0]
        self.assertEqual(out.returncode, 4)
        self.assertFalse(row["ok"])
        self.assertIn("unpinned", row["value"])
        self.assertIn("--bunker-bin", row["value"])
        self.assertIn("BUNKER_BIN", row["value"])

    def test_scan_forwards_exec_bunker(self):
        client = self._shim()
        path = os.path.join(self.tmp, "scan.jsonl")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(json.dumps({"name": "lane", "workdir": "bunker://abc/srv/repo"}) + "\n")
        cmd = [sys.executable, lane_target.__file__, "scan", path, "--exec-bunker", "--bunker-bin", client, "--bunker-server", "staging"]
        good = subprocess.run(cmd, capture_output=True, text=True)
        self.assertEqual(good.returncode, 0, good.stdout + good.stderr)
        self.assertEqual(json.loads(good.stdout)["rows"][0]["target"]["verified"], "bunker-exec")


if __name__ == "__main__":
    unittest.main(verbosity=2)
