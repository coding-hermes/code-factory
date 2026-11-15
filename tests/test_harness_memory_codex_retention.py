#!/usr/bin/env python3
"""Prove CF-329 preserves Codex evidence while removing turn credentials."""

from __future__ import annotations

import os
import re
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INSTALLER = ROOT / "scripts" / "harness" / "install-codex.sh"
# Fake key, built by concatenation so the literal never looks like a live credential to the
# secrets scanner — its whole job here is to be written into the turn's auth.json and then
# asserted ABSENT from the adapter's output.
SECRET = "sk" + "-cf329-fixture-secret-never-print"


class CodexEvidenceRetention(unittest.TestCase):
    def test_rollout_and_index_survive_while_turn_credentials_are_removed(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            home = root / "home"
            workdir = home / "work"
            bin_dir = root / "bin"
            home.mkdir(mode=0o700)
            workdir.mkdir()
            bin_dir.mkdir()
            os.chmod(home, 0o700)

            subprocess.run(
                ["git", "init", str(workdir)], check=True, capture_output=True
            )
            key_file = home / "keys" / "provider.key"
            key_file.parent.mkdir()
            key_file.write_text(SECRET + "\n", encoding="utf-8")
            os.chmod(key_file, stat.S_IRUSR | stat.S_IWUSR)

            codex = bin_dir / "codex"
            codex.write_text(
                """#!/usr/bin/env bash
set -eu
if [ "${1:-}" = "--version" ]; then
  printf 'codex-cli 0.166.0\\n'
  exit 0
fi
if [ "${1:-}" = "exec" ]; then
  mkdir -p "$CODEX_HOME/sessions/2026/01/01"
  printf '%s\\n' '{"type":"thread_settings","thread_settings":{"model":"fixture-model"}}' > "$CODEX_HOME/sessions/2026/01/01/rollout-20260101-fixture-thread.jsonl"
  : > "$CODEX_HOME/state_5.sqlite"
  printf 'CF-329-TOKEN-7f3a9c\\n' > "$PWD/codex-turn.txt"
  printf '%s\\n' '{"type":"thread.started","thread_id":"fixture-thread"}'
  exit 0
fi
exit 0
""",
                encoding="utf-8",
            )
            codex.chmod(0o755)

            env = {
                "HOME": str(home),
                "PATH": f"{bin_dir}:/usr/bin:/bin",
                "XDG_CACHE_HOME": str(home / ".cache"),
                "CF_API_KEY_FILE": str(key_file),
                "CF_MODEL": "fixture-model",
                "CF_PROVIDER": "fixture-provider",
                "CF_WORKDIR": str(workdir),
                "CF_NAMESPACE": "fixture-namespace",
                "CF_RUN_ID": "cf329-fixture-run",
                "CF_LANE": "fixture-lane",
                "CF_TURN_TOKEN": "CF-329-TOKEN-7f3a9c",
                "CF_TURN_FILE": "codex-turn.txt",
                "CF_TIMEOUT_S": "10",
            }
            proc = subprocess.run(
                ["bash", str(INSTALLER), "--turn"],
                cwd=ROOT,
                env=env,
                text=True,
                capture_output=True,
                timeout=30,
            )
            output = proc.stdout + proc.stderr
            self.assertEqual(0, proc.returncode, output)
            self.assertNotIn(SECRET, output)
            self.assertNotIn("OPENAI_API_KEY", output)

            match = re.search(
                r"PASS  turn_home — (\S+) \(isolated config \+ key", output
            )
            self.assertIsNotNone(match, output)
            turn_home = Path(match.group(1))

            rollout = (
                turn_home
                / "sessions"
                / "2026"
                / "01"
                / "01"
                / "rollout-20260101-fixture-thread.jsonl"
            )
            state = turn_home / "state_5.sqlite"
            self.assertTrue(
                rollout.exists(),
                "negative control: the EXIT trap must not delete the Codex sessions tree; "
                f"{turn_home} or its sessions/ rollout is missing",
            )
            self.assertTrue(
                state.exists(), "the Codex SQLite index must survive cleanup"
            )
            self.assertTrue(
                (turn_home / "sessions").is_dir(), f"{turn_home}/sessions must survive"
            )
            self.assertTrue(turn_home.is_dir(), output)
            self.assertFalse((turn_home / "auth.json").exists())
            config = turn_home / "config.toml"
            self.assertFalse(config.exists())
            self.assertNotIn(
                SECRET, config.read_text(encoding="utf-8") if config.exists() else ""
            )
            self.assertIn(f"PASS  rollout — {rollout}", output)
            self.assertIn("preserved for run cf329-fixture-run", output)


if __name__ == "__main__":
    unittest.main()
