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
# The only uncertainty fields the census tool can print after a removal.
RACE_DETECTION_FIELDS = (
    "POST-REMOVE-CWD-UNRESOLVED",
    "POST-REMOVE-WRITER-DETECTED",
)

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = Path(
    os.environ.get("CF_WORKTREE_CENSUS_SCRIPT", ROOT / "scripts/worktree_census.py")
)


class _FakeResult:
    """Minimal stand-in for subprocess.run's result in helper unit tests."""

    def __init__(self, returncode, stdout, stderr=""):
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr


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

    def assert_clean_reap(self, result, path, writer_pids=frozenset()):
        """Assert a clean reap, tolerating ONLY the ambient /proc noise report.

        Ambient same-uid pids on this host (systemd session helpers, ssh-agent,
        sshd sessions, krakend) are permanently cwd-unresolvable and short-lived
        churn joins them between snapshots, so an otherwise clean reap can
        legitimately print POST-REMOVE-CWD-UNRESOLVED pid=<ambient> and exit 2
        (CF-533). Accept rc==2 only when every reported pid is outside this
        fixture, the reported tree is the one this arm reaped, the tool's own
        SUMMARY confirms the removal, and no REAPED line is present (the
        uncertainty report replaces it — a REAPED line next to a race report
        would be forged output). Any other non-zero rc stays a hard failure.
        Returns True when an ambient report was accepted.
        """
        if result.returncode == 0:
            return False
        race_lines = [
            line
            for line in result.stdout.splitlines()
            if line.startswith("REMOVED-WITH-RACE ")
        ]
        self.assertTrue(
            race_lines,
            "rc=2 without a race report is not ambient noise:\n"
            + result.stdout
            + result.stderr,
        )
        prefix = f"REMOVED-WITH-RACE {json.dumps(str(path))} — "
        named = set()
        for line in race_lines:
            self.assertTrue(line.startswith(prefix), line)
            body = line[len(prefix) :]
            cut = body.rfind(" (quiesced-by: ")
            self.assertTrue(cut >= 0, line)
            for field in body[:cut].split("; "):
                name, sep, pid_list = field.rpartition(" pid=")
                self.assertIn(name, RACE_DETECTION_FIELDS, line)
                self.assertTrue(sep and pid_list, line)
                pids = frozenset(map(int, pid_list.split(",")))
                self.assertTrue(pids, line)
                named |= pids
        swallowed = named & set(writer_pids)
        self.assertFalse(
            swallowed,
            "ambient tolerance must never swallow a fixture writer pid "
            f"{sorted(swallowed)}:\n{result.stdout}{result.stderr}",
        )
        self.assertIn("removed=1", result.stdout, result.stdout + result.stderr)
        # No output LINE may be a REAPED report while a race report is present
        # (the uncertainty report replaces it). The echoed quiesced-by suffix
        # may legitimately contain the literal assertion text mid-line, so the
        # check is line-anchored, not a whole-stdout substring search.
        reaped_lines = [
            line for line in result.stdout.splitlines() if line.startswith("REAPED ")
        ]
        self.assertEqual(
            [],
            reaped_lines,
            "a REAPED line next to a race report is forged output:\n" + result.stdout,
        )
        return True

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
        self.assert_clean_reap(result, path)
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
        self.assert_clean_reap(result, path, writer_pids={proc.pid})
        self.assertFalse(path.exists(), result.stdout)
        self.assertFalse(self.registered(path), result.stdout)
        self.assertIsNone(proc.poll(), "writer must still be alive at deletion")
        with self.assertRaisesRegex(AssertionError, "live fixture path was deleted"):
            self.assert_preserved(path)
        # Run the SAME positive test against the mutant: the suite must go red
        # for the FORGERY reason — the preservation oracle catching the deleted
        # live tree. An ambient cwd-unresolvable report inside the sub-run also
        # reds it (the sub-run's assert_success sees rc=2 before its
        # preservation assert), but such a red proves proc noise, not the
        # mutant, so retry past them until the forgery red appears.
        red = None
        for _ in range(6):
            red = subprocess.run(
                [
                    sys.executable,
                    "-B",
                    "-m",
                    "unittest",
                    "tests.test_worktree_census.WorktreeCensus."
                    "test_live_writer_refused",
                ],
                cwd=ROOT,
                env={**self.env, "CF_WORKTREE_CENSUS_SCRIPT": str(weaponized)},
                capture_output=True,
                text=True,
                timeout=30,
            )
            if "live fixture path was deleted" in red.stderr:
                break
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
        ambient = self.assert_clean_reap(result, path, writer_pids={proc.pid})
        self.assertFalse(path.exists())
        self.assert_preserved(sibling)
        if not ambient:
            self.assertIn(f"live writer pid={proc.pid}", result.stdout)
        # An ambient rc=2 breaks the tool's loop before the sibling is scanned,
        # so its census line is absent there; the removal of "tree" beside a
        # live "tree-other" writer still proves the prefix discrimination, and
        # assert_clean_reap rejects any report naming the sibling's writer pid.

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
        self.assert_clean_reap(result, path)
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
        ambient = self.assert_clean_reap(result, path)
        allow = (
            f"REAPED {json.dumps(str(path))} — clean, merged, no-live-writer "
            f"(quiesced-by: {QUIESCED_BY})"
        )
        race = next(
            (
                line
                for line in result.stdout.splitlines()
                if line.startswith("REMOVED-WITH-RACE ")
            ),
            None,
        )
        if ambient:
            # The uncertainty report replaced the REAPED line; the echoed
            # quiescence assertion must still terminate it as one line.
            self.assertTrue(race.endswith(f"(quiesced-by: {QUIESCED_BY})"), race)
        else:
            self.assertIn(allow, result.stdout.splitlines())
        self.assertIn(
            f"REFUSED {json.dumps(str(self.repo))} — main worktree "
            f"(quiesced-by: {QUIESCED_BY})",
            result.stdout.splitlines(),
        )
        self.assertFalse(path.exists())
        self.assertFalse(self.registered(path))
        print(race if ambient else allow)

    def test_clean_reap_helper_tolerates_only_ambient_noise(self):
        # The tolerance itself must be able to fail: an ambient-only rc=2 is
        # accepted, a report naming a fixture writer pid is rejected, an rc=2
        # without a race report is rejected, and rc=0 stays the clean path.
        ambient = (
            'REFUSED "/scratch/repo" — main worktree (quiesced-by: x)\n'
            'REMOVED-WITH-RACE "/scratch/tree" — POST-REMOVE-CWD-UNRESOLVED '
            "pid=1,2 (quiesced-by: x)\n"
            "SUMMARY count=2 merged=2 unmerged=0 dirty=0 live-writer=0 "
            "unknown=0 removed=1 mode=reap apply=true\n"
        )
        self.assertTrue(
            self.assert_clean_reap(_FakeResult(2, ambient), Path("/scratch/tree"))
        )
        with self.assertRaises(AssertionError):
            self.assert_clean_reap(
                _FakeResult(2, ambient.replace("pid=1,2 ", "pid=1,2,77 ")),
                Path("/scratch/tree"),
                writer_pids={77},
            )
        with self.assertRaises(AssertionError):
            self.assert_clean_reap(
                _FakeResult(2, 'REFUSED "/scratch/tree" — 1 dirty paths\n'),
                Path("/scratch/tree"),
            )
        with self.assertRaises(AssertionError):
            self.assert_clean_reap(
                _FakeResult(2, "SUMMARY count=1 removed=0 mode=reap apply=true\n"),
                Path("/scratch/tree"),
            )
        self.assertFalse(
            self.assert_clean_reap(_FakeResult(0, ambient), Path("/scratch/tree"))
        )

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
        ambient = self.assert_clean_reap(result, path)
        if ambient:
            # The uncertainty report replaced the REAPED line; the escaped
            # assertion must still terminate it as one line, unforgeable.
            race = next(
                line
                for line in result.stdout.splitlines()
                if line.startswith("REMOVED-WITH-RACE ")
            )
            self.assertTrue(
                race.endswith("(quiesced-by: operator\\nREAPED forged)"), race
            )
        else:
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
