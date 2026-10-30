#!/usr/bin/env python3
"""CF-007 synthetic local disk admission; no live node measurements."""

import fcntl
import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import unittest

spec = importlib.util.spec_from_file_location(
    "node_fixture", Path(__file__).with_name("node-contract.py")
)
fixture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixture)


class DiskContract(unittest.TestCase):
    executable = staticmethod(fixture.NodeContract.executable)
    run_script = fixture.NodeContract.run_script
    apply = fixture.NodeContract.apply

    def setUp(self):
        fixture.NodeContract.setUp(self)
        self.home.chmod(0o700)
        # Existing scripts use fixed provisioning logs; keep fixture writes private.
        for name, log in (("project-node.sh", "clone"), ("node-create.sh", "spawn")):
            path = self.scripts / name
            path.write_text(
                path.read_text().replace(
                    f"/tmp/{log}.log", str(self.root / f"{log}.log")
                )
            )
        self.env["NODE_DISK_FLOOR"] = "5"
        self.effects = self.root / "effects"
        self.env["EFFECTS"] = str(self.effects)
        self.observations = self.root / "observations"
        self.env["OBSERVATIONS"] = str(self.observations)
        self.executable(
            self.scripts / "harness/install-hermes.sh",
            '#!/bin/bash\necho adapter >> "$EFFECTS"\nprintf "  PASS  version — fixture-1\\n"\n',
        )
        self.executable(
            self.bin / "git",
            """#!/bin/bash
echo git >> "$EFFECTS"
if [ "$1" = clone ]; then mkdir -p "$HOME/repo/.git"; else echo abc1234; fi
""",
        )
        (self.home / "repo/.git").rmdir()
        (self.home / "repo").rmdir()
        self.df("5242879")

    def df(self, free, after=None):
        self.env["DF_BEFORE"] = free
        self.env["DF_AFTER"] = free if after is None else after
        self.executable(
            self.bin / "df",
            """#!/bin/bash
[ "$*" = "-Pk -- $HOME" ] && [ "$LC_ALL" = C ] || exit 18
free="$DF_BEFORE"
if [ ! -f "$HOME/.node/disposable-cache-v1/cache-one.bin" ]; then free="$DF_AFTER"; fi
echo "$free" >> "$OBSERVATIONS"
printf '%s\\n' 'Filesystem 1024-blocks Used Available Capacity Mounted on' "fixture 20000000 1 $free 1% /"
""",
        )

    def disk(self, *args, home=None):
        env = dict(self.env)
        if home is not None:
            env["HOME"] = str(home)
        return subprocess.run(
            [
                "bash",
                "-c",
                '. "$1"; shift; require_disk "$HOME" "$NODE_DISK_FLOOR" "$@"',
                "fixture",
                str(self.scripts / "lib.sh"),
                *args,
            ],
            env=env,
            capture_output=True,
            text=True,
            timeout=20,
        )

    def cache(self, home=None):
        home = self.home if home is None else home
        state = home / ".node"
        state.mkdir(exist_ok=True, mode=0o700)
        state.chmod(0o700)
        directory = state / "disposable-cache-v1"
        directory.mkdir(mode=0o700)
        blob = directory / "cache-one.bin"
        blob.write_bytes(b"synthetic disposable cache")
        blob.chmod(0o600)
        return directory, blob

    def refused(self, result):
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("FAIL  disk", result.stdout, result.stdout + result.stderr)
        self.assertNotIn("Traceback", result.stderr)
        self.assertFalse(self.effects.exists(), result.stdout + result.stderr)
        self.assertFalse((self.home / ".node/node.json").exists())

    def test_low_disk_stops_before_install_clone_and_state(self):
        self.df("1048576")
        (self.home / ".node/crier.json").unlink()
        (self.home / ".node").rmdir()
        p = self.apply()
        self.refused(p)
        self.assertFalse((self.home / ".node").exists(), p.stdout + p.stderr)

    def test_boundary_exact_above_and_fractional_floor(self):
        for free, floor, accepted in [
            ("5242879", "5", False),
            ("5242880", "5", True),
            ("5242881", "5", True),
            ("5242880", "5.000000001", False),
            ("5242881", "5.000000001", True),
            ("0", "0", True),
        ]:
            with self.subTest(free=free, floor=floor):
                self.df(free)
                self.env["NODE_DISK_FLOOR"] = floor
                p = self.disk()
                self.assertEqual(
                    p.returncode, 0 if accepted else 1, p.stdout + p.stderr
                )
                self.assertIn(f"{free} KiB available", p.stdout)
                self.assertIn(f"floor {floor} GiB", p.stdout)
                self.assertIn("GiB free", p.stdout)
        # Exercise the actual apply path through adapter, clone and publication.
        for free in ("5242880", "5242881"):
            self.df(free)
            self.env["NODE_DISK_FLOOR"] = "5"
            p = self.apply()
            self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
            self.assertIn("PASS  manifest", p.stdout)
        self.assertIn("adapter", self.effects.read_text())
        self.assertIn("git", self.effects.read_text())

    def test_malformed_floors_never_measure_or_reclaim(self):
        _, blob = self.cache()
        for floor in (
            "",
            "-1",
            "+5",
            " 5",
            "5 ",
            "NaN",
            "inf",
            "1e1",
            ".5",
            "5.",
            "５",
            "1\n",
            "1234567890",
            "0.1234567890",
        ):
            with self.subTest(floor=floor):
                self.env["NODE_DISK_FLOOR"] = floor
                self.refused(self.apply("--reclaim-disposable"))
                self.assertTrue(blob.exists())
                self.assertFalse(self.observations.exists())

    def test_failed_and_malformed_df_even_at_zero(self):
        _, blob = self.cache()
        self.env["NODE_DISK_FLOOR"] = "0"
        cases = [
            "exit 19",
            "exit 0",
            "echo garbage",
            "printf '%s\\n' 'Filesystem 1024-blocks Used Available Capacity Mounted on'",
        ]
        header = "Filesystem 1024-blocks Used Available Capacity Mounted on"
        for free in ("-1", "NaN", "1.1", "1e9", "５", "999999999999999999999"):
            cases.append(f"printf '%s\\n' '{header}' 'fixture 20000000 1 {free} 1% /'")
        for row in (
            "fixture 10 2 9 1% /",
            "fixture 10 1 1 101% /",
            "fixture 10 1 1 no /",
            "fixture 10 1 1 1% relative",
        ):
            cases.append(f"printf '%s\\n' '{header}' '{row}'")
        cases += [
            f"printf '%s\\n' '{header}' 'fixture 10 1 1 1% /' 'extra row'",
            f"printf '%s\\n' '{header}' 'fixture 10 1 1 1% /'; exit 1",
        ]
        for body in cases:
            with self.subTest(body=body):
                self.executable(self.bin / "df", "#!/bin/bash\n" + body + "\n")
                self.refused(self.apply("--reclaim-disposable"))
                self.assertTrue(blob.exists())

    def test_df_timeout_fails_closed(self):
        helper_spec = importlib.util.spec_from_file_location(
            "disk_policy", self.scripts / "disk-policy.py"
        )
        helper = importlib.util.module_from_spec(helper_spec)
        helper_spec.loader.exec_module(helper)
        from unittest.mock import patch

        with patch.object(
            helper.subprocess, "run", side_effect=subprocess.TimeoutExpired("df", 10)
        ) as run:
            with self.assertRaises(subprocess.TimeoutExpired):
                helper.available_kib(str(self.home))
        self.assertEqual(run.call_args.kwargs["timeout"], 10)
        # Real CLI failure path with a private-copy timeout, not a syntax error.
        path = self.scripts / "disk-policy.py"
        path.write_text(path.read_text().replace("timeout=10,", "timeout=0.01,"))
        self.executable(self.bin / "df", "#!/bin/bash\nexec sleep 1\n")
        self.refused(self.apply())

    def test_reclaim_still_low_remeasures_and_preserves_outside(self):
        _, blob = self.cache()
        sentinels = []
        for relative in (
            "outside",
            "repo/.git/keep",
            ".node/jobs/d1/artifacts/keep",
            ".node/node-config",
            ".node/credential",
        ):
            path = self.home / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"must survive")
            sentinels.append(path)
        self.df("1048576")
        self.refused(self.apply("--reclaim-disposable"))
        self.assertFalse(blob.exists())
        self.assertEqual(
            self.observations.read_text().splitlines(), ["1048576", "1048576"]
        )
        for path in sentinels:
            self.assertEqual(path.read_bytes(), b"must survive")

    def test_reclaim_enables_admission_and_repeat_is_idempotent(self):
        directory, blob = self.cache()
        self.df("1048576", "5242880")
        p = self.apply("--reclaim-disposable")
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        self.assertFalse(blob.exists())
        self.assertEqual(
            self.observations.read_text().splitlines(), ["1048576", "5242880"]
        )
        manifest = self.home / ".node/node.json"
        original = manifest.read_bytes()
        stamp = directory.stat().st_mtime_ns
        p = self.apply("--reclaim-disposable")
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        self.assertEqual(manifest.read_bytes(), original)
        self.assertEqual(directory.stat().st_mtime_ns, stamp)
        # Actually execute empty reclaim twice while still below floor.
        self.df("1048576")
        for _ in range(2):
            p = self.disk("--reclaim-disposable")
            self.assertEqual(p.returncode, 1, p.stdout + p.stderr)
            self.assertIn("0 cache blobs removed", p.stdout)
            self.assertEqual(directory.stat().st_mtime_ns, stamp)

    def test_check_and_default_apply_do_not_reclaim(self):
        _, blob = self.cache()
        self.df("1048576", "5242880")
        for mode in ("--check", "--apply"):
            args = [
                mode,
                "--project",
                "fixture",
                "--repo",
                "https://example.invalid/team/repo.git",
            ]
            if mode == "--check":
                args.append("--reclaim-disposable")
            self.refused(self.run_script("project-node.sh", *args))
            self.assertTrue(blob.exists())
        self.assertEqual(
            self.observations.read_text().splitlines(), ["1048576", "1048576"]
        )
        shutil.rmtree(self.home / ".node")
        self.df("5242880")
        p = self.run_script("project-node.sh", "--check", "--project", "fixture")
        self.assertNotEqual(p.returncode, 0)  # Missing bus/repo, not disk.
        self.assertIn("PASS  disk", p.stdout)
        self.assertFalse((self.home / ".node").exists())

    def test_absent_namespace_remeasures_without_creating_it(self):
        (self.home / ".node").chmod(0o700)
        self.df("1048576")
        self.refused(self.apply("--reclaim-disposable"))
        self.assertEqual(
            self.observations.read_text().splitlines(), ["1048576", "1048576"]
        )
        self.assertFalse((self.home / ".node/disposable-cache-v1").exists())
        (self.home / ".node/crier.json").unlink()
        (self.home / ".node").rmdir()
        self.observations.unlink()
        self.refused(self.apply("--reclaim-disposable"))
        self.assertEqual(
            self.observations.read_text().splitlines(), ["1048576", "1048576"]
        )
        self.assertFalse((self.home / ".node").exists())

    def test_unsafe_names_types_links_modes_and_paths_refuse_without_deletion(self):
        sentinel = self.root / "outside-sentinel"
        sentinel.write_bytes(b"outside must survive")
        sentinel.chmod(0o600)
        for kind in (
            "name",
            "repo",
            "symlink",
            "hardlink",
            "fifo",
            "file-mode",
            "dir-mode",
            "state-mode",
            "home-mode",
            "cache-link",
            "state-link",
            "home-link",
            "ancestor-link",
            "limit",
        ):
            with self.subTest(kind=kind):
                home = self.root / kind
                home.mkdir(mode=0o700)
                directory, blob = self.cache(home)
                bad = directory / "cache-bad.bin"
                if kind == "name":
                    (directory / "credentials").write_text("not disposable")
                elif kind == "repo":
                    (bad / ".git").mkdir(parents=True)
                elif kind == "symlink":
                    bad.symlink_to(sentinel)
                elif kind == "hardlink":
                    os.link(sentinel, bad)
                elif kind == "fifo":
                    os.mkfifo(bad)
                elif kind == "file-mode":
                    blob.chmod(0o644)
                elif kind == "dir-mode":
                    directory.chmod(0o777)
                elif kind == "state-mode":
                    directory.parent.chmod(0o755)
                elif kind == "home-mode":
                    home.chmod(0o777)
                elif kind in ("cache-link", "state-link"):
                    target = directory if kind == "cache-link" else directory.parent
                    moved = home / "preserved"
                    target.rename(moved)
                    target.symlink_to(moved, target_is_directory=True)
                elif kind == "home-link":
                    alias = self.root / "home-alias"
                    alias.symlink_to(home, target_is_directory=True)
                    home = alias
                elif kind == "ancestor-link":
                    alias = self.root / "ancestor-alias"
                    alias.symlink_to(self.root, target_is_directory=True)
                    home = alias / kind
                elif kind == "limit":
                    for number in range(1024):
                        path = directory / f"cache-{number}.bin"
                        path.touch(mode=0o600)
                p = self.disk("--reclaim-disposable", home=home)
                self.assertEqual(p.returncode, 1, p.stdout + p.stderr)
                self.assertIn("FAIL  disk", p.stdout)
                # No eligible blob should be deleted, even if encountered first.
                if kind == "cache-link":
                    blob = self.root / kind / "preserved/cache-one.bin"
                elif kind == "state-link":
                    blob = (
                        self.root / kind / "preserved/disposable-cache-v1/cache-one.bin"
                    )
                self.assertTrue(blob.exists(), p.stdout + p.stderr)
                self.assertEqual(sentinel.read_bytes(), b"outside must survive")
        # Caller-selected cleanup targets are never accepted.
        p = self.disk("--reclaim-disposable", str(sentinel))
        self.assertEqual(p.returncode, 1)
        self.assertIn("invalid disk policy arguments", p.stdout)
        self.assertEqual(sentinel.read_bytes(), b"outside must survive")

    def test_helper_rejects_caller_selected_reclaim_root(self):
        other = self.root / "other-home"
        other.mkdir(mode=0o700)
        _, blob = self.cache(other)
        # Fake df accepts any path so rejection must come from reclaim scope.
        self.executable(
            self.bin / "df",
            "#!/bin/bash\nprintf '%s\\n' 'Filesystem 1024-blocks Used Available Capacity Mounted on' 'fixture 20000000 1 1048576 1% /'\n",
        )
        p = subprocess.run(
            [
                "python3",
                "-B",
                str(self.scripts / "disk-policy.py"),
                str(other),
                "5",
                "--reclaim-disposable",
            ],
            env=self.env,
            capture_output=True,
            text=True,
            timeout=20,
        )
        self.assertEqual(p.returncode, 1, p.stdout + p.stderr)
        self.assertIn("unsafe reclaim HOME", p.stdout)
        self.assertTrue(blob.exists())

    def test_locked_namespace_refuses(self):
        directory, blob = self.cache()
        fd = os.open(directory, os.O_RDONLY | os.O_DIRECTORY)
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            p = self.apply("--reclaim-disposable")
        finally:
            os.close(fd)
        self.refused(p)
        self.assertTrue(blob.exists())

    def test_second_measurement_failure_refuses_after_reclaim(self):
        _, blob = self.cache()
        self.df("1048576", "bad")
        self.refused(self.apply("--reclaim-disposable"))
        self.assertFalse(blob.exists())
        self.assertEqual(self.observations.read_text().splitlines(), ["1048576", "bad"])

    def test_creator_stages_helper_and_stops_on_copy_failure(self):
        (self.home / ".node/node.json").write_text("{}")
        args = (
            "--project",
            "fixture",
            "--repo",
            "https://example.invalid/team/repo.git",
            "--harness",
            "hermes",
        )
        p = self.run_script("node-create.sh", *args)
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        calls = fixture.NodeContract.recorded(self)
        self.assertTrue(
            any(a[0] == "cp" and a[1].endswith("/disk-policy.py") for a in calls)
        )
        self.calls.unlink()
        path = self.bin / "bunker"
        text = path.read_text().replace(
            "if a[0] in ('spawn','cp'):",
            "if a[0] == 'cp' and a[1].endswith('/disk-policy.py'): sys.exit(19)\nif a[0] in ('spawn','cp'):",
        )
        self.executable(path, text)
        p = self.run_script("node-create.sh", *args)
        self.assertNotEqual(p.returncode, 0)
        self.assertIn("FAIL  stage_disk_policy", p.stdout)
        self.assertFalse(
            any(
                "project-node.sh --apply" in a[-1]
                for a in fixture.NodeContract.recorded(self)
            )
        )

    def test_refusal_removal_mutation_breaks_exact_regression(self):
        # Change only the caller's refusal, retaining real FAIL output/counter.
        private = self.root / "mutation"
        shutil.copytree(fixture.ROOT / "scripts", private / "scripts")
        (private / "tests").mkdir()
        for name in ("disk-contract.py", "node-contract.py"):
            shutil.copy(Path(__file__).with_name(name), private / "tests" / name)
        path = private / "scripts/project-node.sh"
        before = path.read_text()
        needle = 'require_disk "${disk_args[@]}" || { say "NODE: FAIL (disk admission)"; exit 1; }'
        self.assertEqual(before.count(needle), 1)
        path.write_text(
            before.replace(needle, 'require_disk "${disk_args[@]}" || true')
        )
        p = subprocess.run(
            [
                "python3",
                "-B",
                str(private / "tests/disk-contract.py"),
                "DiskContract.test_low_disk_stops_before_install_clone_and_state",
            ],
            capture_output=True,
            text=True,
            timeout=30,
        )
        self.assertEqual(p.returncode, 1, p.stdout + p.stderr)
        self.assertIn("AssertionError: True is not false", p.stderr)
        self.assertIn("FAIL  disk", p.stderr)
        self.assertIn("PASS  harness_check", p.stderr)
        self.assertIn("PASS  repo_clone", p.stderr)
        self.assertNotIn("SyntaxError", p.stderr)
        print(
            "  PASS  disk mutation: exact regression caught adapter/clone fall-through"
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
