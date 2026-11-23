#!/usr/bin/env python3
"""CF-390: real git fixtures, real cwd owners, and a deletion mutation control."""

import ast
from contextlib import redirect_stdout
import io
import json
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

QUIESCED_BY = "fixture operator holds worker admission closed"
APPLY = ("reap", "--apply", "--quiesced-by", QUIESCED_BY)

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = Path(
    os.environ.get("CF_WORKTREE_CENSUS_SCRIPT", ROOT / "scripts/worktree_census.py")
)


class WorktreeCensus(unittest.TestCase):
    def setUp(self):
        self.scratch = Path(tempfile.mkdtemp(prefix="cf390-"))
        self.addCleanup(shutil.rmtree, self.scratch)
        self.repo = self.scratch / "repo"
        self.repo.mkdir()
        self.env = {
            key: value
            for key, value in os.environ.items()
            if not key.startswith("GIT_")
        }
        self.env.update(
            GIT_CONFIG_NOSYSTEM="1",
            GIT_CONFIG_GLOBAL=os.devnull,
            GIT_AUTHOR_NAME="Fixture",
            GIT_AUTHOR_EMAIL="fixture@example.invalid",
            GIT_COMMITTER_NAME="Fixture",
            GIT_COMMITTER_EMAIL="fixture@example.invalid",
        )
        self.git("init", "-q", "-b", "main")
        self.git("config", "core.hooksPath", os.devnull)
        (self.repo / "tracked.txt").write_text("base\n")
        self.git("add", "tracked.txt")
        self.git("commit", "-qm", "fixture base")
        self.head = self.git("rev-parse", "HEAD").strip()
        self.git("update-ref", "refs/remotes/origin/main", self.head)

    def git(self, *args, cwd=None):
        return subprocess.check_output(
            ["git", "-C", str(cwd or self.repo), *args],
            env=self.env,
            text=True,
            stderr=subprocess.PIPE,
        )

    def tree(self, name="tree", detached=False):
        path = self.scratch / name
        args = (
            ("--detach",)
            if detached
            else ("-b", name.replace("\n", "-").replace(" ", "-"))
        )
        self.git("worktree", "add", "-q", *args, str(path), self.head)
        return path

    def run_tool(self, *args, script=SCRIPT, repo=None):
        return subprocess.run(
            [
                sys.executable,
                "-B",
                str(script),
                "--repo",
                str(repo or self.repo),
                *args,
            ],
            cwd=self.scratch,
            env=self.env,
            capture_output=True,
            text=True,
            timeout=30,
        )

    def assert_success(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def registered(self, path):
        return f"worktree {path}\0" in self.git("worktree", "list", "--porcelain", "-z")

    def start_writer(self, path, nested=True, command=("sleep", "60")):
        cwd = path / "nested" if nested else path
        if nested:
            cwd.mkdir()
        # Empty directories are clean in git; this process is the ONLY blocker.
        proc = subprocess.Popen(command, cwd=cwd)

        def stop():
            if proc.poll() is None:
                proc.terminate()
            proc.wait(timeout=5)

        self.addCleanup(stop)
        self.assertIsNone(proc.poll())
        self.assertEqual(os.readlink(f"/proc/{proc.pid}/cwd"), str(cwd))
        self.assertEqual(self.git("status", "--porcelain", cwd=path), "")
        return proc

    def assert_preserved(self, path):
        self.assertTrue(path.is_dir(), "live fixture path was deleted")
        self.assertTrue(self.registered(path), "live fixture registration was deleted")

    def test_clean_merged_removed_and_main_preserved(self):
        path = self.tree()
        result = self.run_tool(*APPLY)
        self.assert_success(result)
        self.assertFalse(path.exists())
        self.assertFalse(self.registered(path))
        self.assertTrue(self.repo.is_dir())
        self.assertTrue(self.registered(self.repo))
        self.assertIn(
            f"REFUSED {json.dumps(str(self.repo))} — main worktree", result.stdout
        )
        self.assertIn("removed=1", result.stdout)
        self.assert_success(self.run_tool(*APPLY))

    def test_dirty_refused_with_owner_and_untracked_all(self):
        path = self.tree()
        (path / "tracked.txt").write_text("changed\n")
        nested = path / "untracked"
        nested.mkdir()
        for name in ("one", "two\nlines"):
            (nested / name).write_text("keep\n")
        result = self.run_tool(*APPLY)
        self.assert_success(result)
        self.assert_preserved(path)
        self.assertIn(f"REFUSED {json.dumps(str(path))} — 3 dirty paths", result.stdout)
        self.assertIn("owner=no-live-writer", result.stdout)
        self.assertEqual((nested / "one").read_text(), "keep\n")
        census = self.run_tool()
        self.assert_success(census)
        self.assertIn("\tdirty=3\towner=no-live-writer", census.stdout)

    def test_live_writer_refused(self):
        for name, nested in (("tree", True), ("tree (deleted)", False)):
            with self.subTest(name=name):
                path = self.tree(name)
                proc = self.start_writer(path, nested=nested)
                result = self.run_tool(*APPLY)
                self.assert_success(result)
                self.assert_preserved(path)
                self.assertIn(
                    f"REFUSED {json.dumps(str(path))} — live writer pid={proc.pid}",
                    result.stdout,
                )
                census = self.run_tool()
                self.assert_success(census)
                self.assertIn(f"\tdirty=0\towner={proc.pid}", census.stdout)

    def test_census_count_and_detached_literal_paths(self):
        paths = [
            self.repo,
            self.tree("space tree"),
            self.tree("line\nbreak", detached=True),
        ]
        result = self.run_tool()
        self.assert_success(result)
        lines = [
            line for line in result.stdout.splitlines() if line.startswith("WORKTREE ")
        ]
        count = self.git("worktree", "list", "--porcelain").count("worktree ")
        self.assertEqual(len(lines), count)
        self.assertEqual(len(lines), len(paths))
        reported = [
            json.loads(line.split("\t")[0].removeprefix("WORKTREE ")) for line in lines
        ]
        self.assertEqual(set(reported), {str(p) for p in paths})
        self.assertIn(f"\tdetached\t{self.head}\tmerged", result.stdout)
        self.assertIn(
            "SUMMARY count=3 merged=3 unmerged=0 dirty=0 live-writer=0 unknown=0",
            result.stdout,
        )

    def test_negative_control_removes_live_tree_and_fails_preservation_oracle(self):
        source = SCRIPT.read_text()
        guard = next(
            node
            for node in ast.parse(source).body
            if isinstance(node, ast.FunctionDef) and node.name == "live_writer"
        )
        lines = source.splitlines(keepends=True)
        mutated = "".join(
            lines[: guard.lineno - 1]
            + ["def live_writer(path, processes):\n    return None\n"]
            + lines[guard.end_lineno :]
        )
        self.assertNotEqual(
            source, mutated, "negative control must delete a real guard"
        )
        weaponized = self.scratch / "no-writer-guard.py"
        weaponized.write_text(mutated)
        path = self.tree()
        proc = self.start_writer(path)
        result = self.run_tool(*APPLY, script=weaponized)
        self.assert_success(result)
        self.assertFalse(path.exists(), result.stdout)
        self.assertFalse(self.registered(path), result.stdout)
        self.assertIsNone(proc.poll(), "writer must still be alive at deletion")
        with self.assertRaisesRegex(AssertionError, "live fixture path was deleted"):
            self.assert_preserved(path)
        # Run the SAME positive test against the mutant: the suite must go red.
        red = subprocess.run(
            [
                sys.executable,
                "-B",
                "-m",
                "unittest",
                "tests.test_worktree_census.WorktreeCensus.test_live_writer_refused",
            ],
            cwd=ROOT,
            env={**self.env, "CF_WORKTREE_CENSUS_SCRIPT": str(weaponized)},
            capture_output=True,
            text=True,
            timeout=30,
        )
        self.assertNotEqual(red.returncode, 0, red.stdout + red.stderr)
        self.assertIn("live fixture path was deleted", red.stderr)
        print(
            "NEGATIVE-CONTROL live guard removed: path and registration deleted with writer alive; same live-writer test FAILS (rc=1)"
        )

    def test_dry_run_never_removes_any_tree(self):
        clean = self.tree("clean")
        dirty = self.tree("dirty")
        (dirty / "keep").write_text("untracked\n")
        live = self.tree("live")
        proc = self.start_writer(live)
        before = self.git("worktree", "list", "--porcelain", "-z")
        result = self.run_tool("reap")
        self.assert_success(result)
        self.assertEqual(before, self.git("worktree", "list", "--porcelain", "-z"))
        for path in (self.repo, clean, dirty, live):
            self.assert_preserved(path)
        self.assertIn(f"WOULD-REAP {json.dumps(str(clean))}", result.stdout)
        self.assertIn(f"REFUSED {json.dumps(str(dirty))}", result.stdout)
        self.assertIn(f"live writer pid={proc.pid}", result.stdout)
        self.assertIn("removed=0 mode=reap apply=false", result.stdout)

    def test_unmerged_preserved(self):
        path = self.tree()
        (path / "tracked.txt").write_text("unlanded\n")
        self.git("commit", "-qam", "unlanded", cwd=path)
        result = self.run_tool(*APPLY)
        self.assert_success(result)
        self.assert_preserved(path)
        self.assertIn("HEAD unmerged against origin/main", result.stdout)
        census = self.run_tool()
        self.assert_success(census)
        self.assertIn("merged=1 unmerged=1", census.stdout)

    def test_missing_origin_is_unknown_not_merged(self):
        path = self.tree()
        self.git("update-ref", "-d", "refs/remotes/origin/main")
        result = self.run_tool(*APPLY)
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assert_preserved(path)
        self.assertIn("HEAD unknown against origin/main", result.stdout)
        self.assertIn("merged=0 unmerged=0", result.stdout)

    def test_missing_tree_reported_not_omitted(self):
        path = self.tree()
        shutil.rmtree(path)
        result = self.run_tool()
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertIn(f"WORKTREE {json.dumps(str(path))}", result.stdout)
        self.assertIn("SUMMARY count=2", result.stdout)
        self.assertIn("unknown=1", result.stdout)
        self.assertTrue(self.registered(path))

    def test_separator_prefix_does_not_claim_sibling(self):
        path = self.tree("tree")
        sibling = self.tree("tree-other")
        proc = self.start_writer(sibling)
        result = self.run_tool(*APPLY)
        self.assert_success(result)
        self.assertFalse(path.exists())
        self.assert_preserved(sibling)
        self.assertIn(f"live writer pid={proc.pid}", result.stdout)

    def test_locked_preserved(self):
        path = self.tree()
        self.git("worktree", "lock", str(path))
        result = self.run_tool(*APPLY)
        self.assert_success(result)
        self.assert_preserved(path)
        self.assertIn("locked worktree", result.stdout)

    def test_main_protected_even_when_repo_is_linked_tree(self):
        path = self.tree()
        result = self.run_tool(*APPLY, repo=path)
        self.assert_success(result)
        self.assertTrue(self.repo.is_dir())
        self.assertTrue(self.registered(self.repo))
        self.assertIn("main worktree", result.stdout)

    def test_rename_counts_as_one_dirty_entry(self):
        path = self.tree()
        self.git("mv", "tracked.txt", "renamed.txt", cwd=path)
        result = self.run_tool()
        self.assert_success(result)
        self.assertIn("\tdirty=1\towner=no-live-writer", result.stdout)

    def test_help_does_not_inspect_invalid_repo(self):
        result = self.run_tool("--help", repo=self.scratch / "absent")
        self.assert_success(result)
        self.assertNotIn("SUMMARY", result.stdout)
        self.assertNotIn("WORKTREE", result.stdout)

    def test_apply_requires_quiescence_assertion_and_echoes_it(self):
        path = self.tree()
        before = self.git("worktree", "list", "--porcelain", "-z")
        for assertion in (None, "", "   "):
            with self.subTest(assertion=assertion):
                args = ["reap", "--apply"]
                if assertion is not None:
                    args.extend(("--quiesced-by", assertion))
                result = self.run_tool(*args)
                self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
                self.assertIn(
                    "REFUSED apply — no quiescence assertion supplied "
                    "(pass --quiesced-by naming who guarantees no worker admission)",
                    result.stdout,
                )
                self.assertNotIn("WOULD-REAP", result.stdout)
                self.assertNotIn("REAPED", result.stdout)
                self.assertEqual(
                    before, self.git("worktree", "list", "--porcelain", "-z")
                )
                self.assert_preserved(path)
                if assertion is None:
                    print(result.stdout.strip())
        result = self.run_tool(*APPLY)
        self.assert_success(result)
        allow = (
            f"REAPED {json.dumps(str(path))} — clean, merged, no-live-writer "
            f"(quiesced-by: {QUIESCED_BY})"
        )
        self.assertIn(allow, result.stdout.splitlines())
        self.assertIn(
            f"REFUSED {json.dumps(str(self.repo))} — main worktree "
            f"(quiesced-by: {QUIESCED_BY})",
            result.stdout.splitlines(),
        )
        self.assertFalse(path.exists())
        self.assertFalse(self.registered(path))
        print(allow)

    def run_scan_remove_race(self, unresolved=False, preexisting_unresolved=False):
        path = self.tree("a-tree")
        spared = self.tree("z-tree")
        unrelated = (
            self.start_writer(self.repo, nested=False)
            if preexisting_unresolved
            else None
        )
        tool = runpy.run_path(str(SCRIPT))
        main = tool["main"]
        checked_git = tool["checked_git"]
        readlink = os.readlink
        writers = []

        def enter_before_remove(repo, *args):
            if args == ("worktree", "remove", "--", str(path)):
                # Real final scan has returned: inject a shell at the removal
                # boundary, without timing sleeps or a fake git removal.
                writers.append(
                    self.start_writer(
                        path, nested=False, command=("sh", "-c", "exec sleep 60")
                    )
                )
            return checked_git(repo, *args)

        def disappearing_cwd(link):
            if unrelated and str(link) == f"/proc/{unrelated.pid}/cwd":
                raise PermissionError("fixture unrelated cwd was already inaccessible")
            if (
                unresolved
                and writers
                and not path.exists()
                and str(link) == f"/proc/{writers[0].pid}/cwd"
            ):
                raise FileNotFoundError("fixture cwd resolution failed after removal")
            return readlink(link)

        # Bypass only argument parsing: the same oracle must exercise removal
        # in the pre-fix script, not fail at its older CLI parser.
        args = type(
            "Args",
            (),
            dict(mode="reap", repo=self.repo, apply=True, quiesced_by=QUIESCED_BY),
        )()
        output = io.StringIO()
        with (
            mock.patch.dict(os.environ, self.env, clear=True),
            mock.patch.dict(main.__globals__, checked_git=enter_before_remove),
            mock.patch("argparse.ArgumentParser.parse_args", return_value=args),
            mock.patch("os.readlink", side_effect=disappearing_cwd),
            redirect_stdout(output),
        ):
            rc = main([])
        self.assertEqual(len(writers), 1, "race must reach the real git removal")
        self.assertIsNone(writers[0].poll(), "writer must survive through the oracle")
        self.assertFalse(path.exists(), output.getvalue())
        self.assertFalse(self.registered(path), output.getvalue())
        self.assertEqual(
            readlink(f"/proc/{writers[0].pid}/cwd"), str(path) + " (deleted)"
        )
        token = (
            "POST-REMOVE-CWD-UNRESOLVED"
            if unresolved
            else "POST-REMOVE-WRITER-DETECTED"
        )
        opposite = (
            "POST-REMOVE-WRITER-DETECTED"
            if unresolved
            else "POST-REMOVE-CWD-UNRESOLVED"
        )
        # CF-526: the before-remove and post-removal scans bracket a LIVE
        # /proc window, so under load the census line may legitimately carry
        # more pids than this fixture injected — any same-uid process that
        # dies (or becomes cwd-unresolvable) between the two snapshots joins
        # the detection pid set, and an exact one-pid line assertion reds the
        # whole guard for every board commit. Parse instead: pin the line's
        # shape, the injected writer's presence in its own detection, and the
        # absence of false claims — not the exact pid list.
        lines = [
            line
            for line in output.getvalue().splitlines()
            if line.startswith("REMOVED-WITH-RACE ")
        ]
        self.assertEqual(len(lines), 1, output.getvalue())
        prefix = f"REMOVED-WITH-RACE {json.dumps(str(path))} — "
        suffix = f" (quiesced-by: {QUIESCED_BY})"
        self.assertTrue(lines[0].startswith(prefix), lines[0])
        self.assertTrue(lines[0].endswith(suffix), lines[0])
        detections = {}
        for field in lines[0][len(prefix) : -len(suffix)].split("; "):
            name, _, pid_list = field.rpartition(" pid=")
            self.assertTrue(name and pid_list, lines[0])
            detections[name] = frozenset(map(int, pid_list.split(",")))
        self.assertIn(token, detections, lines[0])
        self.assertIn(writers[0].pid, detections[token], lines[0])
        # The fixture mocks os.readlink for the injected writer, so which
        # detection claims it is deterministic in both arms.
        self.assertNotIn(
            writers[0].pid, detections.get(opposite, frozenset()), lines[0]
        )
        if unrelated:
            # The pre-existing unresolved pid predates this run's scans: it
            # must never be claimed as a NEW race — production keeps it in
            # already_unresolved, and its cwd (the main worktree) cannot
            # match the removed tree. This exclusion is the arm's contract.
            self.assertNotIn(
                unrelated.pid, frozenset().union(*detections.values()), lines[0]
            )
        self.assertEqual(rc, 2, output.getvalue())
        self.assertNotIn("REAPED ", output.getvalue())
        self.assertIn("removed=1", output.getvalue())
        self.assert_preserved(spared)
        print(lines[0])

    def test_writer_enters_between_scan_and_remove_is_detected(self):
        self.run_scan_remove_race()

    def test_unresolved_cwd_after_remove_is_reported(self):
        self.run_scan_remove_race(unresolved=True)

    def test_preexisting_unresolved_cwd_does_not_claim_new_race(self):
        self.run_scan_remove_race(preexisting_unresolved=True)

    def test_assertion_control_characters_cannot_forge_output(self):
        path = self.tree()
        assertion = "operator\nREAPED forged"
        result = self.run_tool("reap", "--apply", "--quiesced-by", assertion)
        self.assert_success(result)
        self.assertIn(
            f"REAPED {json.dumps(str(path))} — clean, merged, no-live-writer "
            "(quiesced-by: operator\\nREAPED forged)",
            result.stdout.splitlines(),
        )
        self.assertNotIn("REAPED forged", result.stdout.splitlines())

    def test_apply_requires_reap_and_no_proc_bypass(self):
        path = self.tree()
        for args in (
            ("--apply", "--quiesced-by", QUIESCED_BY),
            (*APPLY, "--proc-scan", "off"),
        ):
            result = self.run_tool(*args)
            self.assertEqual(result.returncode, 2)
            self.assert_preserved(path)


if __name__ == "__main__":
    unittest.main()
