#!/usr/bin/env bash
# Lightweight, offline tests of the real BUILD policy kernel; never launches builds.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
export PYTHONDONTWRITEBYTECODE=1
exec python3 - "$HERE" "${1:-}" <<'PY'
import copy
import hashlib
import json
import os
from pathlib import Path
import runpy
import subprocess
import sys
import tempfile
import unittest

REPO = Path(sys.argv[1])
MODE = sys.argv[2]
POLICY = Path(os.environ.get("BUILD_POLICY_UNDER_TEST", REPO / "scripts/build-policy.py"))
if MODE not in ("", "--mutation-controls"):
    sys.exit("FAIL build-contract: expected no option or --mutation-controls")
if not POLICY.is_file():
    sys.exit("FAIL build-contract: missing executable policy kernel scripts/build-policy.py")
policy = runpy.run_path(str(POLICY))
CONTEXT = {
    "project": "example-project", "repository": "example/repository",
    "trust": "trusted", "ref": "refs/heads/main", "runtime": "python-3.11-abi",
    "platform": "linux-x64", "manager": "pip", "manager_version": "26.2.1",
    "image_digest": "1" * 64, "lock_digest": "2" * 64,
    "build_digest": "3" * 64, "cache_kind": "packages",
}


class Contract(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="cf-build-test-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name) / "cache"
        self.root.mkdir(mode=0o700)
        self.source = Path(self.tmp.name) / "source"
        self.payload = b"small verified dependency bytes\n"
        self.source.write_bytes(self.payload)
        self.digest = hashlib.sha256(self.payload).hexdigest()
        self.context = copy.deepcopy(CONTEXT)

    def call(self, op, **kwargs):
        return policy["evaluate"](op, kwargs)

    def put(self, context=None, **kwargs):
        request = dict(context=context or self.context, root=str(self.root),
                       source=str(self.source), sha256=self.digest, job_trust="trusted")
        request.update(kwargs)
        return self.call("put", **request)

    def get(self, context=None, **kwargs):
        request = dict(context=context or self.context, root=str(self.root), sha256=self.digest)
        request.update(kwargs)
        return self.call("get", **request)

    def reject(self, reason, function, *args, **kwargs):
        with self.assertRaisesRegex(ValueError, reason):
            function(*args, **kwargs)

    def test_cache_reuse(self):
        self.assertEqual(self.get()["status"], "MISS")
        self.assertEqual(list(self.root.iterdir()), [])
        self.assertEqual(self.put()["status"], "STORED")
        blob = self.root / self.call("key", context=self.context)["key"] / "blob"
        self.assertEqual(blob.read_bytes(), self.payload)
        before = blob.stat()
        self.assertEqual(self.get(), {"status": "HIT", "sha256": self.digest,
                                     "bytes": len(self.payload)})
        self.assertEqual(self.put()["status"], "REUSE")
        after = blob.stat()
        self.assertEqual((before.st_ino, before.st_mtime_ns), (after.st_ino, after.st_mtime_ns))

    def test_all_key_dimensions_isolate_bytes(self):
        self.put()
        baseline = self.call("key", context=self.context)["key"]
        keys = {baseline}
        for field in CONTEXT:
            with self.subTest(dimension=field):
                other = dict(self.context)
                if field.endswith("_digest"):
                    other[field] = "4" * 64
                elif field == "trust":
                    other[field] = "untrusted"
                else:
                    other[field] += "-other"
                key = self.call("key", context=other)["key"]
                self.assertNotIn(key, keys, field)
                keys.add(key)
                self.assertEqual(self.get(other)["status"], "MISS", field)
        self.assertEqual(len(keys), len(CONTEXT) + 1)
        self.assertEqual(self.get()["status"], "HIT")

    def test_canonical_key_and_ambiguous_inputs(self):
        key = self.call("key", context=self.context)["key"]
        reordered = dict(reversed(list(self.context.items())))
        self.assertEqual(key, self.call("key", context=reordered)["key"])
        self.assertRegex(key, r"^cf-build-v1/[0-9a-f]{64}$")
        # Structured JSON must not collide on concatenated component boundaries.
        a = dict(self.context, project="ab", repository="c")
        b = dict(self.context, project="a", repository="bc")
        self.assertNotEqual(self.call("key", context=a), self.call("key", context=b))

    def test_untrusted_writes_denied(self):
        self.reject("trust_write_denied", self.put, job_trust="untrusted")
        self.assertEqual(list(self.root.iterdir()), [])
        self.put()
        original = self.get()
        self.reject("trust_write_denied", self.put, job_trust="untrusted")
        self.assertEqual(self.get(), original)
        untrusted = dict(self.context, trust="untrusted")
        self.assertEqual(self.put(untrusted, job_trust="untrusted")["status"], "STORED")
        self.reject("trust_write_denied", self.put, untrusted)

    def test_failed_integrity_not_reused(self):
        self.reject("source_integrity", self.put, sha256="0" * 64)
        self.assertEqual(list(self.root.iterdir()), [])
        self.put()
        blob = self.root / self.call("key", context=self.context)["key"] / "blob"
        blob.write_bytes(b"tampered")
        self.reject("entry_integrity", self.get)
        self.reject("entry_integrity", self.put)
        self.assertEqual(blob.read_bytes(), b"tampered")
        # Even valid bytes with a different externally supplied digest are denied.
        self.reject("entry_integrity", self.get, sha256="0" * 64)

    def test_input_validation(self):
        for field in CONTEXT:
            with self.subTest(missing=field):
                invalid = dict(self.context)
                del invalid[field]
                self.reject("context_fields", self.call, "key", context=invalid)
            for value in ("", " padded", "control\nvalue", None):
                with self.subTest(field=field, value=value):
                    self.reject("context", self.call, "key", context=dict(self.context, **{field: value}))
        self.reject("context_fields", self.call, "key", context=dict(self.context, extra="bad"))
        self.reject("context_trust", self.call, "key", context=dict(self.context, trust="unknown"))
        self.reject("context_digest", self.call, "key", context=dict(self.context, lock_digest="not-a-digest"))
        self.reject("trust_write_denied", self.put, job_trust="unknown")
        self.reject("digest", self.get, sha256="bad")
        self.reject("operation", self.call, "unsupported")

    def test_private_root_and_symlinks(self):
        self.root.chmod(0o755)
        self.reject("private_directory", self.get)
        self.root.chmod(0o700)
        alias = Path(self.tmp.name) / "alias"
        alias.symlink_to(self.root, target_is_directory=True)
        self.reject("symlink", self.get, root=str(alias))
        self.reject("symlink", self.get, root=str(alias / "child"))
        self.reject("root_missing", self.get, root=str(self.root / "missing"))
        self.put()
        entry = self.root / self.call("key", context=self.context)["key"]
        (entry / "blob").unlink()
        (entry / "blob").symlink_to(self.source)
        self.reject("regular_file", self.get)
        self.reject("regular_file", self.put)

    def test_host_loss_cold_recovery(self):
        self.put()
        replacement = Path(self.tmp.name) / "replacement"
        replacement.mkdir(mode=0o700)
        self.assertEqual(self.get(root=str(replacement))["status"], "MISS")
        self.assertEqual(self.put(root=str(replacement))["status"], "STORED")
        self.assertEqual(self.get(root=str(replacement)), self.get())

    def test_heavy_remote_admission(self):
        request = dict(weight="heavy", observed_host="worker-a", control_host="control-a",
                       admitted_hosts=["worker-a"])
        self.assertEqual(self.call("placement", **request)["status"], "ALLOW")
        self.assertEqual(self.call("placement", **request)["host"], "worker-a")
        # Control exclusion must hold even if inventory is misconfigured to include it.
        self.reject("control_host", self.call, "placement", **dict(
            request, observed_host="control-a", admitted_hosts=["control-a", "worker-a"]))
        for host in ("", "unknown", "not-admitted"):
            self.reject("identity|not_admitted", self.call, "placement", **dict(request, observed_host=host))
        self.reject("identity", self.call, "placement", **dict(request, control_host=""))
        self.reject("inventory", self.call, "placement", **dict(request, admitted_hosts=[]))
        self.reject("weight", self.call, "placement", **dict(request, weight="unknown"))
        self.assertEqual(self.call("placement", **dict(request, weight="light", observed_host="control-a"))["status"], "ALLOW")

    def test_cli_failures_and_real_bytes(self):
        def cli(op, request):
            return subprocess.run([sys.executable, str(POLICY), op], input=json.dumps(request),
                                  text=True, capture_output=True, check=False)
        result = cli("put", dict(context=self.context, root=str(self.root),
                                 source=str(self.source), sha256=self.digest, job_trust="trusted"))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["status"], "STORED")
        result = cli("get", dict(context=self.context, root=str(self.root), sha256=self.digest))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["bytes"], len(self.payload))
        for op, request in (("key", {}), ("placement", {}), ("bad", {})):
            result = cli(op, request)
            self.assertEqual(result.returncode, 1)
            self.assertIn("FAIL build-policy:", result.stderr)
            self.assertEqual(result.stdout, "")
        result = subprocess.run([sys.executable, str(POLICY), "key"], input="not-json",
                                text=True, capture_output=True, check=False)
        self.assertEqual(result.returncode, 1)
        self.assertIn("FAIL build-policy:", result.stderr)


if MODE == "--mutation-controls":
    text = POLICY.read_text()
    mutations = {
        "project-key": ('identity = dict(context)', 'identity = dict(context); identity["project"] = "omitted"'),
        "trust-key": ('identity = dict(context)', 'identity = dict(context); identity["trust"] = "omitted"'),
        "ref-key": ('identity = dict(context)', 'identity = dict(context); identity["ref"] = "omitted"'),
        "runtime-key": ('identity = dict(context)', 'identity = dict(context); identity["runtime"] = "omitted"'),
        "trusted-write": ('if job_trust not in TRUST or job_trust != context["trust"]:', 'if False:'),
        "integrity": ('if actual != expected:', 'if False:'),
        "control-placement": ('if observed_host == control_host and weight == "heavy":', 'if False:'),
    }
    with tempfile.TemporaryDirectory(prefix="cf-build-mutations-") as tmp:
        for name, (old, new) in mutations.items():
            if text.count(old) != 1:
                sys.exit("FAIL mutation anchor: " + name)
            mutant = Path(tmp) / (name + ".py")
            mutant.write_text(text.replace(old, new))
            env = dict(os.environ, BUILD_POLICY_UNDER_TEST=str(mutant))
            result = subprocess.run(["bash", str(REPO / "tests/build-contract.sh")], env=env,
                                    text=True, capture_output=True, check=False)
            if result.returncode == 0 or "FAILED (" not in result.stderr:
                sys.exit("FAIL mutation survived or did not reach assertions: " + name + "\n" + result.stderr)
            print("PASS mutation rejected: " + name + " (normal tests exit " + str(result.returncode) + ")")
        # Use a scratch copy of the actual selftest, retaining its normal fixtures.
        import shutil
        scratch = Path(tmp) / "repository"
        shutil.copytree(REPO, scratch, ignore=shutil.ignore_patterns(".git", ".gitreins", "__pycache__"))
        (scratch / "tests/build-contract.sh").write_text("#!/usr/bin/env bash\nprintf 'FAIL injected build-contract\\n'\nexit 23\n")
        result = subprocess.run(["bash", str(scratch / "tests/selftest.sh")],
                                text=True, capture_output=True, check=False)
        if result.returncode == 0 or "FAIL injected build-contract" not in result.stdout or "SELFTEST: FAIL" not in result.stdout:
            sys.exit("FAIL selftest did not propagate injected build-contract failure\n" + result.stdout + result.stderr)
        print("PASS selftest propagated build-contract exit 23 (selftest exit " + str(result.returncode) + ")")
    result = subprocess.run(["bash", str(REPO / "tests/build-contract.sh")],
                            env=dict(os.environ, BUILD_POLICY_UNDER_TEST=str(POLICY)), check=False)
    sys.exit(result.returncode)

result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(Contract))
if result.wasSuccessful():
    print("BUILD CONTRACT: PASS (" + str(result.testsRun) + " tests; hermetic policy only)")
    sys.exit(0)
print("BUILD CONTRACT: FAIL")
sys.exit(1)
PY
