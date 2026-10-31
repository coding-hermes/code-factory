#!/usr/bin/env python3
"""CF-025 disposable HOME checks; fake prerequisites, never live-node proof."""

import importlib.util
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "node_fixture", Path(__file__).with_name("node-contract.py")
)
fixture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixture)


def snapshot(home):
    """Include the root, hidden entries and lstat metadata; ignore only atime.

    Reading files/directories can update atime. Bytes, type, permissions, owner,
    links, inode, size, mtime and ctime must otherwise survive each invocation.
    Never follow symlinks when walking or reading the snapshot.
    """
    result = {}

    def visit(path):
        info = path.lstat()
        payload = None
        if stat.S_ISREG(info.st_mode):
            payload = path.read_bytes()
        elif stat.S_ISLNK(info.st_mode):
            payload = os.readlink(path)
        result[str(path.relative_to(home))] = (
            info.st_mode,
            info.st_uid,
            info.st_gid,
            info.st_nlink,
            info.st_ino,
            info.st_size,
            info.st_mtime_ns,
            info.st_ctime_ns,
            payload,
        )
        if stat.S_ISDIR(info.st_mode):
            for child in sorted(path.iterdir()):
                visit(child)

    visit(home)
    return result


class CheckPurity(unittest.TestCase):
    executable = staticmethod(fixture.NodeContract.executable)
    run_script = fixture.NodeContract.run_script
    apply = fixture.NodeContract.apply

    def setUp(self):
        fixture.NodeContract.setUp(self)
        # The existing fake adapter, curl, git, df and memory observation satisfy
        # every implemented layer without installation, network or credentials.
        scratch = self.root / "scratch"
        scratch.mkdir()
        self.env.update(TMPDIR=str(scratch), PYTHONDONTWRITEBYTECODE="1")
        self.home.chmod(0o700)

    def check(self, failures=(), *, empty=False, env=None):
        before = snapshot(self.home)
        for attempt in range(2):
            p = self.run_script(
                "project-node.sh", "--check", "--project", "fixture", env=env
            )
            output = p.stdout + p.stderr
            self.assertEqual(p.returncode, 1 if failures else 0, output)
            rows = [s.split(" — ")[0] for s in p.stdout.splitlines()]
            self.assertEqual(
                [s for s in rows if s.startswith("  FAIL  ")],
                [f"  FAIL  {name}" for name in failures],
                output,
            )
            self.assertIn("PASS  disk", p.stdout, output)
            self.assertIn("PASS  harness_check", p.stdout, output)
            self.assertIn("PASS  python:venv", p.stdout, output)
            self.assertIn("NODE: FAIL" if failures else "NODE: PASS", p.stdout)
            for decoy in ("unbound variable", "Traceback", "SyntaxError", "not found"):
                self.assertNotIn(decoy, output)
            self.assertEqual(snapshot(self.home), before, "HOME changed\n" + output)
            if empty:
                self.assertFalse(os.path.lexists(self.home / ".node"), output)
            if attempt == 0:
                for row in p.stdout.splitlines():
                    if row.startswith(("  FAIL  ", "NODE: ")):
                        print(row)
        label = ",".join(failures) if failures else "NODE: PASS"
        print(f"  PASS  check_purity — {label}; HOME unchanged across two checks")

    def seed(self):
        (self.home / "keep.bin").write_bytes(b"\x00unchanged\xff\n")
        (self.home / "keep.bin").chmod(0o640)
        (self.home / "keep-link").symlink_to("keep.bin")
        (self.home / "empty-directory").mkdir(mode=0o750)
        # Check must not rewrite even an existing manifest it does not publish.
        (self.home / ".node/node.json").write_bytes(b'{"fixture":"preserve"}\n')
        (self.home / ".node/node.json").chmod(0o600)

    def test_empty_home_no_state(self):
        shutil.rmtree(self.home / ".node")
        shutil.rmtree(self.home / "repo")
        self.assertEqual(list(self.home.iterdir()), [])
        # An actually empty HOME cannot satisfy existing identity/repo checks.
        # These are exact expected layer failures, not a fake healthy empty node.
        self.check(("crier_identity", "repo"), empty=True)

    def test_seeded_success_preserves_home(self):
        self.seed()
        self.check()

    def test_missing_crier_url_preserves_home(self):
        self.seed()
        env = dict(self.env)
        del env["CRIER_URL"]
        # CRIER_BASE remains set: exactly one prerequisite is missing.
        self.check(("crier_url",), env=env)

    def test_apply_may_create_state_after_admission(self):
        shutil.rmtree(self.home / ".node")
        p = self.apply()
        output = p.stdout + p.stderr
        self.assertEqual(p.returncode, 1, output)
        self.assertIn("PASS  disk", p.stdout)
        self.assertIn("PASS  harness_check", p.stdout)
        self.assertIn("FAIL  crier_identity", p.stdout)
        self.assertTrue((self.home / ".node").is_dir(), output)
        self.assertEqual(stat.S_IMODE((self.home / ".node").stat().st_mode), 0o700)
        self.assertFalse((self.home / ".node/node.json").exists())


class PurityMutations(unittest.TestCase):
    def test_runnable_mutations_and_selftest_propagation(self):
        # selftest selects CheckPurity explicitly, so these full-suite controls
        # cannot recursively invoke themselves. Every subprocess has a deadline.
        with tempfile.TemporaryDirectory(prefix="cf025-mutations-") as tmp:
            root = Path(tmp)
            for name in ("scripts", "tests", "specs", "docs"):
                shutil.copytree(ROOT / name, root / name)
            board = root / ".coding-hermes/board"
            board.mkdir(parents=True)
            shutil.copy(ROOT / ".coding-hermes/board/tasks.jsonl", board)
            path = root / "scripts/project-node.sh"
            source = path.read_text()
            anchor = "# ---------------------------------------------------------------- 00 preflight"
            self.assertEqual(source.count(anchor), 1)

            def run(args):
                return subprocess.run(
                    args, cwd=root, capture_output=True, text=True, timeout=180
                )

            commands = (
                [sys.executable, "-B", "tests/check-purity.py", "CheckPurity"],
                ["bash", "tests/selftest.sh"],
            )
            for command in commands:
                control = run(command)
                self.assertEqual(control.returncode, 0, control.stdout + control.stderr)
                self.assertIn("PASS  check_purity", control.stdout)
                if command[0] == "bash":
                    self.assertIn("SELFTEST: PASS", control.stdout)
            print("  PASS  purity unchanged-copy controls — fixture=0 selftest=0")
            for name, action in (
                ("directory", 'mkdir -p "$STATE"'),
                ("file", 'printf mutation > "$HOME/check-created"'),
            ):
                with self.subTest(mutation=name):
                    path.write_text(
                        source.replace(
                            anchor,
                            f'if [ "$MODE" = check ]; then {action}; fi\n{anchor}',
                        )
                    )
                    syntax = run(["bash", "-n", str(path)])
                    self.assertEqual(syntax.returncode, 0, syntax.stderr)
                    for command in commands:
                        p = run(command)
                        output = p.stdout + p.stderr
                        self.assertEqual(p.returncode, 1, output)
                        self.assertIn("AssertionError", output)
                        self.assertIn("HOME changed", output)
                        self.assertNotIn("SyntaxError", output)
                        if command[0] == "bash":
                            self.assertIn("FAIL  check purity contract", p.stdout)
                            self.assertIn("SELFTEST: FAIL", p.stdout)
                            self.assertNotIn("SELFTEST: PASS", p.stdout)
                    print(
                        f"  PASS  purity {name} mutation — bash -n=0; "
                        "fixture=1 HOME changed assertion; selftest=1 SELFTEST: FAIL"
                    )


if __name__ == "__main__":
    unittest.main(verbosity=2)
