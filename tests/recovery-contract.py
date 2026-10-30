#!/usr/bin/env python3
"""Real-Git local loss simulation. No node adapter or production restore claim."""

import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
HELPER = REPO / "tests/recovery-fixture.py"
PAYLOAD = b"accepted synthetic gate evidence\n"
EXPECTED = hashlib.sha256(PAYLOAD).hexdigest()


class RecoveryContract(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="cf-recovery-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.control = self.root / "control"
        self.durable = self.root / "durable"
        self.scratch = self.root / "scratch"
        for path in (self.control, self.durable, self.scratch):
            path.mkdir(mode=0o700)
        self.env = {
            "PATH": os.defpath,
            "HOME": str(self.control),
            "XDG_CONFIG_HOME": str(self.control),
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": os.devnull,
            "GIT_TERMINAL_PROMPT": "0",
            "GIT_ALLOW_PROTOCOL": "file",
            "LC_ALL": "C",
        }
        self.origin = self.durable / "origin.git"
        self.git(
            "init",
            "--bare",
            "--object-format=sha1",
            "--initial-branch=main",
            str(self.origin),
        )
        self.worker = self.scratch / "lost-worker"
        self.git("clone", "--no-local", str(self.origin), str(self.worker))
        (self.worker / "source.txt").write_bytes(b"accepted source\n")
        self.git("-C", str(self.worker), "add", "source.txt")
        self.git("-C", str(self.worker), "commit", "-m", "accepted fixture")
        self.commit = self.git(
            "-C", str(self.worker), "rev-parse", "HEAD"
        ).stdout.strip()
        self.git("-C", str(self.worker), "push", "origin", "main")
        self.artifact = self.durable / "gate.log"
        self.artifact.write_bytes(PAYLOAD)
        # Control accepts against known fixture bytes BEFORE loss or any tampering.
        self.assertEqual(
            hashlib.sha256(self.artifact.read_bytes()).hexdigest(), EXPECTED
        )
        self.record = {
            "version": 1,
            "repository": "fixture/origin",
            "commit": self.commit,
            "dispatch_id": "accepted-job",
            "artifact": {"name": "gate.log", "sha256": EXPECTED, "bytes": len(PAYLOAD)},
            "pending_dispatches": ["pending-job"],
            "unpublished_work": "not-exported",
        }
        self.metadata = self.durable / "accepted.json"
        self.publish_metadata()
        # Advance published branch: recovery must NOT substitute current origin/main.
        (self.worker / "source.txt").write_bytes(b"newer published source\n")
        self.git("-C", str(self.worker), "commit", "-am", "newer published fixture")
        self.git("-C", str(self.worker), "push", "origin", "main")
        # Work never published is deliberately not recoverable.
        (self.worker / "unpublished.txt").write_bytes(b"unpublished change\n")
        self.git("-C", str(self.worker), "add", "unpublished.txt")
        self.git("-C", str(self.worker), "commit", "-m", "unpublished fixture")
        self.unpushed = self.git(
            "-C", str(self.worker), "rev-parse", "HEAD"
        ).stdout.strip()
        (self.worker / "dirty.txt").write_bytes(b"dirty untracked work\n")
        (self.worker / "pending-job").write_text("in progress\n")
        self.assertNotEqual(self.commit, self.unpushed)
        self.assertNotEqual(
            self.git(
                "--git-dir",
                str(self.origin),
                "cat-file",
                "-e",
                self.unpushed + "^{commit}",
                check=False,
            ).returncode,
            0,
        )
        shutil.rmtree(self.scratch)
        self.assertFalse(self.worker.exists())
        self.assertTrue(self.origin.is_dir())
        self.assertTrue(self.metadata.is_file())

    def git(self, *args, check=True):
        return subprocess.run(
            [
                "git",
                "-c",
                "core.hooksPath=" + os.devnull,
                "-c",
                "init.templateDir=",
                "-c",
                "user.name=totalwindupflightsystems",
                "-c",
                "user.email=fixture@example.invalid",
                *args,
            ],
            cwd=self.root,
            env=self.env,
            text=True,
            capture_output=True,
            timeout=20,
            check=check,
        )

    def publish_metadata(self):
        self.metadata.write_text(json.dumps(self.record, sort_keys=True))
        self.pin = hashlib.sha256(self.metadata.read_bytes()).hexdigest()

    def recover(self, dest="recovered-a", pin=None):
        return subprocess.run(
            [sys.executable, "-B", str(HELPER), str(self.root), pin or self.pin, dest],
            cwd=self.root,
            env=self.env,
            text=True,
            capture_output=True,
            timeout=30,
            check=False,
        )

    def reject(self, code, **kwargs):
        result = self.recover(**kwargs)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertEqual(result.stdout, "")
        self.assertEqual(result.stderr.strip(), "FAIL recovery:" + code)
        print("observed rejection=" + code + " exit=" + str(result.returncode))

    def snapshot(self, root):
        return {
            str(p.relative_to(root)): (
                p.read_bytes(),
                p.stat().st_ino,
                p.stat().st_mtime_ns,
            )
            for p in root.rglob("*")
            if p.is_file()
        }

    def test_recover_after_loss_and_repeat(self):
        durable_before = self.snapshot(self.durable)
        result = self.recover()
        self.assertEqual(result.returncode, 0, result.stderr)
        observed = json.loads(result.stdout)
        self.assertEqual(observed["commit"], self.commit)
        self.assertEqual(observed["sha256"], EXPECTED)
        self.assertEqual(observed["bytes"], len(PAYLOAD))
        self.assertEqual(observed["pending"], {"pending-job": "unknown"})
        self.assertEqual(observed["unpublished_work"], "unrecoverable")
        recovered = self.root / "recovered-a"
        self.assertEqual((recovered / "source.txt").read_bytes(), b"accepted source\n")
        self.assertFalse((recovered / "unpublished.txt").exists())
        self.assertFalse((recovered / "dirty.txt").exists())
        self.assertFalse((recovered / ".git/objects/info/alternates").exists())
        before = self.snapshot(recovered)
        second = self.recover()
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertEqual(json.loads(second.stdout), observed)
        self.assertEqual(before, self.snapshot(recovered))
        fresh = self.recover(dest="recovered-b")
        self.assertEqual(fresh.returncode, 0, fresh.stderr)
        self.assertEqual(json.loads(fresh.stdout), observed)
        self.assertEqual(durable_before, self.snapshot(self.durable))
        print(
            "observed recovery commit="
            + observed["commit"]
            + " sha256="
            + observed["sha256"]
            + " bytes="
            + str(observed["bytes"])
            + " repeat=unchanged fresh=recovered pending=unknown unpublished=unrecoverable"
        )

    def test_missing_commit(self):
        self.record["commit"] = "f" * 40
        self.publish_metadata()
        self.assertNotEqual(
            self.git(
                "--git-dir",
                str(self.origin),
                "cat-file",
                "-e",
                "f" * 40 + "^{commit}",
                check=False,
            ).returncode,
            0,
        )
        self.reject("commit_missing")

    def test_changed_artifact(self):
        self.artifact.write_bytes(b"X" * len(PAYLOAD))
        self.reject("artifact_integrity")

    def test_missing_artifact(self):
        self.artifact.unlink()
        self.reject("artifact_missing")

    def test_corrupt_metadata(self):
        self.metadata.write_bytes(b"corrupt")
        self.reject("metadata_integrity")

    def test_missing_metadata(self):
        self.metadata.unlink()
        self.reject("metadata_missing")

    def test_metadata_and_artifact_cannot_redefine_expectation(self):
        self.artifact.write_bytes(b"forged bytes\n")
        self.record["artifact"]["sha256"] = hashlib.sha256(
            self.artifact.read_bytes()
        ).hexdigest()
        self.record["artifact"]["bytes"] = self.artifact.stat().st_size
        # Attacker changes record + artifact, but cannot replace the control pin.
        self.metadata.write_text(json.dumps(self.record, sort_keys=True))
        self.reject("metadata_integrity")

    def test_pinned_but_invalid_metadata(self):
        for invalid in (b"not json", b'{"version":1,"version":1}', b"{}"):
            with self.subTest(invalid=invalid):
                self.metadata.write_bytes(invalid)
                self.pin = hashlib.sha256(invalid).hexdigest()
                self.reject("metadata_schema")
        for field, value in (
            ("commit", "main"),
            ("commit", "f" * 7),
            ("repository", "another/origin"),
            ("pending_dispatches", ["accepted-job"]),
        ):
            with self.subTest(field=field, value=value):
                original = self.record[field]
                self.record[field] = value
                self.publish_metadata()
                self.reject("metadata_schema")
                self.record[field] = original

    def test_invalid_trust_pin(self):
        self.reject("trust_pin", pin="not-a-digest")
        self.reject("metadata_integrity", pin="0" * 64)

    def test_dirty_or_wrong_workspace_not_overwritten(self):
        self.assertEqual(self.recover().returncode, 0)
        recovered = self.root / "recovered-a"
        (recovered / "source.txt").write_bytes(b"preserve this\n")
        self.reject("workspace_mismatch")
        self.assertEqual((recovered / "source.txt").read_bytes(), b"preserve this\n")
        (self.root / "occupied").mkdir()
        self.reject("workspace_mismatch", dest="occupied")

    def test_artifact_rechecked_on_repeat(self):
        self.assertEqual(self.recover().returncode, 0)
        self.artifact.write_bytes(b"changed after initial recovery")
        self.reject("artifact_integrity")


class MutationControls(unittest.TestCase):
    def test_private_semantic_mutations(self):
        text = HELPER.read_text()
        mutations = {
            "trust-pin": ("if actual_metadata != metadata_pin:", "if False:"),
            "artifact-digest": (
                'if actual != artifact["sha256"] or len(payload) != artifact["bytes"]:',
                "if False:",
            ),
            "pinned-checkout": (
                '"checkout", "--detach", commit',
                '"checkout", "--detach", "origin/main"',
            ),
        }
        with tempfile.TemporaryDirectory(prefix="cf-recovery-mutants-") as temp:
            for name, (old, new) in mutations.items():
                with self.subTest(mutation=name):
                    self.assertEqual(text.count(old), 1, name)
                    mutant = Path(temp) / (name + ".py")
                    mutant.write_text(text.replace(old, new))
                    # Compile first; an invalid program is not a meaningful mutant.
                    compile(mutant.read_text(), str(mutant), "exec")
                    command = [
                        sys.executable,
                        "-B",
                        str(Path(__file__)),
                        "--helper",
                        str(mutant),
                        "RecoveryContract",
                    ]
                    result = subprocess.run(
                        command,
                        text=True,
                        capture_output=True,
                        timeout=120,
                        check=False,
                    )
                    self.assertNotEqual(result.returncode, 0, name)
                    self.assertIn("FAIL: test_", result.stderr, result.stderr)
                    self.assertNotIn("ERROR:", result.stderr, result.stderr)
                    print(
                        "observed semantic mutant="
                        + name
                        + " assertion-failure exit="
                        + str(result.returncode)
                    )

    def test_selftest_propagates_recovery_failure(self):
        with tempfile.TemporaryDirectory(prefix="cf-recovery-caller-") as temp:
            target = Path(temp) / "repo"
            # Copy only the caller's inputs, never the original checkout or history.
            for name in ("scripts", "tests", "specs", "docs", ".coding-hermes/board"):
                shutil.copytree(
                    REPO / name,
                    target / name,
                    ignore=shutil.ignore_patterns("__pycache__", "*.pyc"),
                )
            fixture = target / "tests/recovery-contract.py"
            fixture.write_text(
                "import sys\nprint('FAIL injected recovery-contract exit=23')\nsys.exit(23)\n"
            )
            result = subprocess.run(
                ["bash", str(target / "tests/selftest.sh")],
                text=True,
                capture_output=True,
                timeout=180,
                check=False,
            )
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            self.assertIn("FAIL injected recovery-contract exit=23", result.stdout)
            self.assertIn("SELFTEST: FAIL (1)", result.stdout)
            self.assertNotIn("SELFTEST: PASS", result.stdout)
            print("observed selftest caller exit=1 recovery-child=23 failures=1")


if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "--helper":
        HELPER = Path(sys.argv[2])
        del sys.argv[1:3]
    unittest.main(verbosity=2)
