#!/usr/bin/env python3
"""Production node-bus-worker I3 exporter tests (CF-231)."""

from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORKER = ROOT / "scripts" / "node-bus-worker.py"


def load_worker():
    spec = importlib.util.spec_from_file_location("cf_node_bus_worker_memory", WORKER)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


WORKER_MOD = load_worker()


class Ident:
    def __init__(self, home: str, harness: Path):
        self.home = home
        self.error = ""
        self.node_path = ""
        self.bus_path = ""
        self.key_path = ""
        self.token_path = ""
        self.seen_path = os.path.join(home, "seen.json")
        self.agent = "fixture-node"
        self.project = "code-factory"
        self.url = ""
        self.repo_path = home
        self.harness_cmd = [str(harness), "{prompt}"]
        self.harness_name = "hermes"
        self.port = 0


class NodeBusMemoryTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.mkdtemp(prefix="cf231-node-memory-")
        self.addCleanup(shutil.rmtree, self.temp, ignore_errors=True)
        self.home = Path(self.temp)
        subprocess.run(["git", "init", "-q", self.temp], check=True)
        subprocess.run(["git", "-C", self.temp, "config", "user.email", "fixture@example.invalid"], check=True)
        subprocess.run(["git", "-C", self.temp, "config", "user.name", "CF-231 fixture"], check=True)
        self.harness = self.home / "harness.py"
        self.harness.write_text(
            "#!/usr/bin/env python3\n"
            "import sys\n"
            "print('harness ran: ' + sys.argv[1])\n"
            "print('harness_version=fixture-1')\n"
            "print('model_served=served-model')\n",
            encoding="utf-8",
        )
        self.harness.chmod(0o755)
        (self.home / "marker").write_text("fixture\n", encoding="utf-8")
        subprocess.run(["git", "-C", self.temp, "add", "marker"], check=True)
        subprocess.run(["git", "-C", self.temp, "commit", "-q", "-m", "fixture"], check=True)
        self.ident = Ident(self.temp, self.harness)
        self.ident.harness_argv = lambda prompt: [str(self.harness), prompt]
        self.args = type("Args", (), {"dry_run": False, "harness_wall": 30})()

    def dispatch(self, *, model_served=True, values=None):
        vars_ = {
            "CF_MODEL": "requested-model",
            "CF_PROVIDER": "fixture-provider",
            "CF_WORKDIR": self.temp,
            "CF_NAMESPACE": "code-factory",
            "CF_RUN_ID": "cf231-run-1",
            "CF_LANE": "code-factory-qa",
        }
        if values is not None:
            vars_ = values
        dispatch = {
            "dispatch_id": "cf231-dispatch-1",
            "corr_id": "cf231-corr-1",
            "lane": "code-factory-qa",
            "tick": "cf231-tick-1",
            "harness_version": "fixture-1",
            "provider_binding": "native/fixture",
            "text": "write the fixture artifact",
            "vars": vars_,
        }
        if not model_served:
            self.harness.write_text(
                "#!/usr/bin/env python3\nprint('harness_version=fixture-1')\n",
                encoding="utf-8",
            )
            self.harness.chmod(0o755)
        dispatch["brief"] = {
            "digest": WORKER_MOD.brief_digest(dispatch, dispatch["text"]),
            "bytes": len(dispatch["text"].encode()),
        }
        dispatch.pop("brief", None)
        return dispatch

    def run_process(self, dispatch):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            result = WORKER_MOD.process(dispatch, self.ident, None, self.args, {})
        return (*result, output.getvalue())

    def test_success_runs_through_process_and_writes_shared_record(self):
        rows_ok, result, should_ack, _ = self.run_process(self.dispatch())
        self.assertTrue(rows_ok, result)
        self.assertTrue(should_ack)
        self.assertEqual("written", result["memory"]["status"])
        artifact = Path(result["memory"]["artifact"])
        self.assertTrue(artifact.is_file())
        record = json.loads(artifact.read_text(encoding="utf-8"))
        self.assertEqual("code-factory", record["namespace"])
        self.assertEqual("cf231-run-1", record["run_id"])
        self.assertEqual("code-factory-qa", record["lane"])
        self.assertEqual("hermes", record["harness"])
        self.assertEqual("fixture-1", record["harness_version"])
        self.assertEqual("requested-model", record["model_requested"])
        self.assertEqual("served-model", record["model_served"])
        self.assertEqual("native/fixture", record["provider_binding"])
        self.assertRegex(record["commit"], r"^[0-9a-f]{40}$")
        self.assertEqual("cf231-tick-1", record["tick"])

    def test_missing_model_served_is_explicitly_unsupported(self):
        rows_ok, result, _, _ = self.run_process(self.dispatch(model_served=False))
        self.assertTrue(rows_ok, result)
        self.assertEqual("unsupported", result["memory"]["status"])
        self.assertIn("model_served", result["memory"]["reason"])
        self.assertFalse(list((self.home / ".node").rglob("*.json")))

    def test_missing_namespace_is_refused_and_named_unsupported(self):
        values = {
            "CF_MODEL": "requested-model",
            "CF_PROVIDER": "fixture-provider",
            "CF_WORKDIR": self.temp,
            "CF_RUN_ID": "cf231-run-1",
            "CF_LANE": "code-factory-qa",
        }
        rows_ok, result, _, _ = self.run_process(self.dispatch(values=values))
        self.assertTrue(rows_ok)
        self.assertEqual("completed", result["status"])
        self.assertEqual("unsupported", result["memory"]["status"])
        self.assertIn("namespace", result["memory"]["reason"])


# ch:trace row=CF-231 spec=specs/HARNESS-MATRIX.md#I3 wave=none:serial test=python3 -B tests/test_node_bus_memory.py doc=docs/handbook/chapters/M5-harness.md prompt=cf231-brief evidence=tests/test_node_bus_memory.py witness=none:local-runtime-artifact-only verdict=none:foreman-judge commit=37226d1273f18995d5938bfa45d19baba9a4e176 memory=none:foreman-closeout

if __name__ == "__main__":
    unittest.main(verbosity=2)
