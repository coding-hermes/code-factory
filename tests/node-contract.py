#!/usr/bin/env python3
"""CF-005 local fake-command fixtures; never live infrastructure proof."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class NodeContract(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="cf005-local-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.scripts = self.root / "scripts"
        shutil.copytree(ROOT / "scripts", self.scripts)
        self.home = self.root / "home"
        self.home.mkdir()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.calls = self.root / "calls.jsonl"
        self.env = {
            "PATH": f"{self.bin}:/usr/bin:/bin",
            "HOME": str(self.home),
            "BUNKER_SERVER": "local-fixture",
            "CRIER_URL": "http://crier.invalid",
            "CRIER_BASE": "http://crier.invalid",
            "NODE_DISK_FLOOR": "0",
            "CALLS": str(self.calls),
        }
        self.executable(
            self.bin / "bunker",
            """#!/usr/bin/python3
import json, os, subprocess, sys
with open(os.environ['CALLS'], 'a') as f: f.write(json.dumps(sys.argv[1:])+'\\n')
a=sys.argv[1:]
if a[0] in ('spawn','cp'): sys.exit(0)
if '--' in a:
    cmd=a[a.index('--')+1:]
    if cmd[:2] == ['python3','-c']:
        p = subprocess.run(cmd, env=os.environ, capture_output=True)
        if os.environ.get('LOCAL_CORRUPT') and p.returncode == 0:
            value=json.loads(p.stdout); value['sha256']='0'*64; print(json.dumps(value))
        else:
            sys.stdout.buffer.write(p.stdout); sys.stderr.buffer.write(p.stderr)
        sys.exit(p.returncode)
    text=cmd[-1]
    if 'echo ALIVE' in text: print('ALIVE local-fixture')
    elif 'hostname -I' in text: print('192.0.2.10')
    elif 'project-node.sh --apply' in text: print('NODE: PASS')
    elif 'sha256sum --' in text: print('fake-digest')
    elif 'cat --' in text: print('fake-bytes')
""",
        )
        self.executable(
            self.bin / "curl",
            """#!/usr/bin/python3
import sys
a=sys.argv[1:]
if '-o' in a and a[a.index('-o')+1] != '/dev/null':
    with open(a[a.index('-o')+1], 'w') as f: f.write('{"auth_required":true}')
print('401' if a[-1].endswith('/api/system/stats') else '200', end='')
""",
        )
        self.executable(
            self.scripts / "harness/install-hermes.sh",
            """#!/bin/bash
printf '  PASS  version — local-fixture-1\n'
exit 0
""",
        )
        # Deterministic local resource observations, not measurements of a node.
        self.executable(
            self.bin / "df",
            "#!/bin/bash\nprintf '%s\\n' 'Filesystem 1024-blocks Used Available Capacity Mounted on' 'fixture 20000000 1 1048576 1% /'\n",
        )
        self.executable(
            self.bin / "awk",
            """#!/bin/bash
if [[ "${*: -1}" == /proc/meminfo ]]; then echo 2048; else exec /usr/bin/awk "$@"; fi
""",
        )
        (self.home / ".node").mkdir()
        (self.home / ".node/crier.json").write_text("{}")
        (self.home / ".node/crier.json").chmod(0o600)
        (self.home / "repo/.git").mkdir(parents=True)
        self.executable(
            self.bin / "git",
            """#!/bin/bash
case "$*" in
 *'rev-parse --short HEAD'*) echo abc1234 ;;
 *'remote get-url origin'*) echo https://example.invalid/team/repo.git ;;
esac
""",
        )

    @staticmethod
    def executable(path, text):
        path.write_text(text)
        path.chmod(0o755)

    def run_script(self, name, *args, env=None):
        return subprocess.run(
            ["bash", str(self.scripts / name), *args],
            env=self.env if env is None else env,
            capture_output=True,
            text=True,
            timeout=30,
        )

    def recorded(self):
        return (
            [json.loads(s) for s in self.calls.read_text().splitlines()]
            if self.calls.exists()
            else []
        )

    def apply(self, *extra):
        return self.run_script(
            "project-node.sh",
            "--apply",
            "--project",
            "fixture",
            "--repo",
            "https://example.invalid/team/repo.git",
            "--harness",
            "hermes",
            *extra,
        )

    def test_named_check(self):
        env = dict(self.env)
        del env["CRIER_URL"]
        p = self.run_script(
            "project-node.sh", "--check", "--project", "fixture", env=env
        )
        self.assertNotEqual(p.returncode, 0, p.stdout + p.stderr)
        rows = [s for s in p.stdout.splitlines() if s.startswith("  FAIL  ")]
        self.assertEqual(
            [s.split(" — ")[0] for s in rows],
            ["  FAIL  crier_url"],
            p.stdout + p.stderr,
        )
        self.assertNotIn("unbound variable", p.stdout + p.stderr)
        self.assertRegex(p.stdout, r"(?m)^  FAIL  crier_url — .+$")

    def test_creator_preconditions_and_exact_triple(self):
        good = [
            "--project",
            "fixture",
            "--repo",
            "https://example.invalid/team/repo.git",
            "--harness",
            "hermes",
        ]
        invalid = [[], good[2:], good[:2] + good[4:], good[:4]]
        for flag, value in [
            ("--project", "../x"),
            ("--project", "x;id"),
            ("--repo", ""),
            ("--repo", "https://u:p@example.invalid/t/r.git"),
            ("--repo", "https://example.invalid/t/../r.git"),
            ("--repo", "https://example.invalid/t/r.git;id"),
            ("--repo", "-u"),
            ("--repo", "file:///tmp/repo"),
            ("--repo", "git@example.invalid:t/r.git$(id)"),
            ("--harness", "../hermes"),
            ("--harness", "opencode"),
        ]:
            args = good.copy()
            args[args.index(flag) + 1] = value
            invalid.append(args)
        for args in invalid:
            with self.subTest(args=args):
                self.calls.unlink(missing_ok=True)
                p = self.run_script("node-create.sh", *args)
                self.assertNotEqual(p.returncode, 0, p.stdout)
                self.assertEqual(self.recorded(), [], p.stdout + p.stderr)
        manifest = self.home / ".node/node.json"
        manifest.write_text("{}")
        p = self.run_script("node-create.sh", *good)
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        self.assertTrue(any(a[0] == "spawn" for a in self.recorded()))
        provision = [
            a[-1] for a in self.recorded() if "project-node.sh --apply" in a[-1]
        ]
        self.assertEqual(len(provision), 1)
        import shlex

        words = shlex.split(provision[0])
        for flag in ("--project", "--repo", "--harness"):
            self.assertEqual(words[words.index(flag) + 1], good[good.index(flag) + 1])

    def test_artifact_denials_before_remote_shell(self):
        for path in [
            "~/.hermes/.env",
            "~/.hermes/config.yaml",
            "/etc/passwd",
            "~/.node/../.hermes/.env",
            "~/.node/jobs/d1/artifacts/../../node.json",
            "~/.node/jobs/d2/artifacts/log.txt",
            "~/.node/jobs/d1/artifacts/.env",
            "~/.node/jobs/d1/artifacts/config.yaml",
            "~/.node/jobs/d1/artifacts/secret.txt",
            "~/.node/jobs/d1/artifacts/x;id",
        ]:
            with self.subTest(path=path):
                self.calls.unlink(missing_ok=True)
                p = self.run_script(
                    "verify-node.sh",
                    "--agent",
                    "fixture",
                    "--dispatch-id",
                    "d1",
                    "--artifact",
                    path,
                )
                self.assertNotEqual(p.returncode, 0, p.stdout)
                self.assertEqual(self.recorded(), [], p.stdout + p.stderr)

    def test_forbidden_manifest_paths_without_dispatch_option(self):
        # Baseline understands these options: a refusal must not be an unknown-flag decoy.
        for path in (
            "~/.hermes/.env",
            "~/.hermes/config.yaml",
            "/etc/passwd",
            "~/.node/../.hermes/.env",
            "~/.node/node.json/../config.yaml",
        ):
            with self.subTest(path=path):
                self.calls.unlink(missing_ok=True)
                p = self.run_script(
                    "verify-node.sh", "--agent", "fixture", "--artifact", path
                )
                self.assertNotEqual(p.returncode, 0, p.stdout)
                self.assertEqual(self.recorded(), [], p.stdout + p.stderr)

    def test_artifact_symlink_hardlink_and_positive(self):
        directory = self.home / ".node/jobs/d1/artifacts"
        directory.mkdir(parents=True)
        artifact = directory / "test.log"
        artifact.write_bytes(b"local fixture artifact\n")
        for path, args in [
            ("~/.node/jobs/d1/artifacts/test.log", ["--dispatch-id", "d1"]),
            ("~/.node/node.json", []),
        ]:
            (self.home / ".node/node.json").write_text("{}")
            p = self.run_script(
                "verify-node.sh", "--agent", "fixture", "--artifact", path, *args
            )
            self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
            self.assertIn("PASS  artifact_digest", p.stdout)
        outside = self.home / "outside"
        outside.write_text("local harmless sentinel")
        for kind in ("leaf", "parent", "hardlink", "fifo"):
            with self.subTest(kind=kind):
                artifact.unlink(missing_ok=True)
                if kind == "leaf":
                    artifact.symlink_to(outside)
                elif kind == "parent":
                    directory.rmdir()
                    directory.symlink_to(self.home, target_is_directory=True)
                elif kind == "hardlink":
                    os.link(outside, artifact)
                else:
                    os.mkfifo(artifact)
                self.calls.unlink(missing_ok=True)
                p = self.run_script(
                    "verify-node.sh",
                    "--agent",
                    "fixture",
                    "--dispatch-id",
                    "d1",
                    "--artifact",
                    "~/.node/jobs/d1/artifacts/test.log",
                )
                self.assertNotEqual(p.returncode, 0, p.stdout)
                self.assertFalse(
                    any("bash" in a for a in self.recorded()), self.recorded()
                )
                if kind == "parent":
                    directory.unlink()
                    directory.mkdir()
        artifact.unlink()

    def test_verifier_auth_and_digest_fail_closed(self):
        (self.home / ".node/node.json").write_text("{}")
        self.env["LOCAL_CORRUPT"] = "1"
        p = self.run_script(
            "verify-node.sh", "--agent", "fixture", "--artifact", "~/.node/node.json"
        )
        self.assertNotEqual(p.returncode, 0)
        self.assertIn("FAIL  artifact_digest", p.stdout)
        del self.env["LOCAL_CORRUPT"]
        self.executable(
            self.bin / "curl",
            """#!/usr/bin/python3
import sys
a=sys.argv[1:]
if '-o' in a and a[a.index('-o')+1] != '/dev/null':
    with open(a[a.index('-o')+1], 'w') as f: f.write('{"auth_required":false}')
print('200', end='')
""",
        )
        p = self.run_script(
            "verify-node.sh", "--agent", "fixture", "--artifact", "~/.node/node.json"
        )
        self.assertNotEqual(p.returncode, 0)
        self.assertIn("FAIL  auth_gate", p.stdout)
        self.assertIn("FAIL  unauth_refused", p.stdout)

    def test_creator_stops_on_provision_failure(self):
        path = self.bin / "bunker"
        text = path.read_text().replace("print('NODE: PASS')", "sys.exit(19)")
        self.executable(path, text)
        p = self.run_script(
            "node-create.sh",
            "--project",
            "fixture",
            "--harness",
            "hermes",
            "--repo",
            "https://example.invalid/team/repo.git",
        )
        self.assertNotEqual(p.returncode, 0)
        self.assertIn("FAIL  provision", p.stdout)
        self.assertNotIn("verify node", p.stdout)
        self.assertFalse(any("artifact-read" in a for a in self.recorded()))

    def test_manifest_write_failure(self):
        (self.home / ".node/node.json").mkdir()
        p = self.apply()
        self.assertNotEqual(p.returncode, 0, p.stdout + p.stderr)
        self.assertNotIn("PASS  manifest", p.stdout)
        self.assertRegex(p.stdout, r"(?m)^  FAIL  manifest(?:_identity|_write) — ")

    def test_manifest_writer_error_is_not_pass(self):
        self.executable(
            self.bin / "python3",
            """#!/bin/bash
if [[ "${2:-}" == manifest-write ]]; then echo 'local fixture writer failure' >&2; exit 19; fi
exec /usr/bin/python3 "$@"
""",
        )
        p = self.apply()
        self.assertNotEqual(p.returncode, 0, p.stdout + p.stderr)
        self.assertIn("FAIL  manifest_write", p.stdout)
        self.assertNotIn("PASS  manifest", p.stdout)
        self.assertFalse((self.home / ".node/node.json").exists())

    def test_manifest_identity_and_byte_idempotence(self):
        p = self.apply()
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        manifest = self.home / ".node/node.json"
        original = manifest.read_bytes()
        p = self.apply()
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        self.assertEqual(manifest.read_bytes(), original)
        for key in ("project", "repo", "harness"):
            data = json.loads(original)
            if key == "project":
                data[key] = "different"
            elif key == "repo":
                data[key]["origin"] = "https://example.invalid/team/other.git"
            else:
                data[key]["name"] = "different"
            manifest.write_text(json.dumps(data))
            before = manifest.read_bytes()
            p = self.apply()
            self.assertNotEqual(p.returncode, 0, p.stdout + p.stderr)
            self.assertIn("FAIL  manifest_identity", p.stdout)
            self.assertNotIn("PASS  manifest", p.stdout)
            self.assertEqual(manifest.read_bytes(), before)
        manifest.write_text("{broken")
        self.assertNotEqual(self.apply().returncode, 0)

    def test_hermes_inference_blocked_without_reading_keys(self):
        shutil.copy(
            ROOT / "scripts/harness/install-hermes.sh",
            self.scripts / "harness/install-hermes.sh",
        )
        # Fail before touching install/config/provider credentials, even in apply mode.
        for mode in ("--check", "--apply"):
            p = self.run_script("harness/install-hermes.sh", mode)
            self.assertNotEqual(p.returncode, 0)
            self.assertIn("FAIL  inference_integration", p.stdout)
            self.assertFalse((self.home / "hermes-venv").exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
