#!/usr/bin/env python3
"""CF-276: exercise node-create's actual cp destinations without a live bunker."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class BusWorkerStaging(unittest.TestCase):
    def test_transport_places_worker_at_connect_probe_path(self):
        with tempfile.TemporaryDirectory(prefix="cf276-") as directory:
            temp = Path(directory)
            node = temp / "node"
            binary = temp / "bin"
            node.mkdir()
            binary.mkdir()
            bunker = binary / "bunker"
            bunker.write_text(
                '#!/bin/bash\n'
                'case "$1" in\n'
                ' info) exit 0 ;;\n'
                ' cp) destination="${3#*:}"; '
                'mkdir -p "$FIXTURE_NODE/$(dirname "$destination")"; '
                'cp "$2" "$FIXTURE_NODE/$destination" ;;\n'
                ' exec) case "${!#}" in\n'
                '  chmod*) chmod +x "$FIXTURE_NODE/node-bus-worker.py" ;;\n'
                '  *NODE_PROJECT=*) exit 1 ;;\n'
                ' esac ;;\n'
                ' *) exit 99 ;;\n'
                'esac\n'
            )
            bunker.chmod(0o755)
            env = dict(os.environ, PATH=f"{binary}:/usr/bin:/bin", HOME=str(temp),
                       FIXTURE_NODE=str(node), BUNKER_SERVER="fixture", CRIER_URL="http://fixture.invalid")
            result = subprocess.run(
                ["bash", str(ROOT / "scripts/node-create.sh"), "--agent", "fixture", "--project", "fixture"],
                env=env, capture_output=True, text=True, timeout=30,
            )
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            self.assertIn("PASS  staged", result.stdout)
            worker = node / "node-bus-worker.py"
            self.assertTrue(worker.is_file(), result.stdout + result.stderr)
            self.assertEqual(worker.read_bytes(), (ROOT / "scripts/node-bus-worker.py").read_bytes())
            self.assertTrue(os.access(worker, os.X_OK))
            self.assertIn('$HOME/node-bus-worker.py', (ROOT / "scripts/bunker-crier-connect.sh").read_text())
            help_result = subprocess.run(["python3", "-B", str(worker), "--help"], capture_output=True, timeout=15)
            self.assertEqual(help_result.returncode, 0, help_result.stderr)

    def test_missing_sidecar_is_named_refusal(self):
        with tempfile.TemporaryDirectory(prefix="cf276-negative-") as directory:
            scripts = Path(directory) / "scripts"
            shutil.copytree(ROOT / "scripts", scripts, ignore=shutil.ignore_patterns("__pycache__"))
            (scripts / "node-bus-worker.py").unlink()
            result = subprocess.run(["bash", str(scripts / "node-create.sh"), "--staged-files"],
                                    capture_output=True, text=True, timeout=15)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("missing scripts/node-bus-worker.py", result.stderr)


if __name__ == "__main__":
    unittest.main()
