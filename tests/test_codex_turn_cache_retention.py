#!/usr/bin/env python3
"""Prove CF-446 bounds the retained Codex turn cache with a NAMED retention window.

The window and the pruning are two different claims and both are proven here against the real
adapter, with real directories and controlled mtimes:

  * the window resolves from one ordered chain (flag, then environment, then the default), reports
    which source won, and REFUSES a malformed / negative / out-of-range value instead of silently
    falling back to the default;
  * a run.* directory older than the window is removed by --turn, one inside the window survives,
    and nothing that is not one run.* leaf directly under the cache root is ever touched — the
    prune asks inside_turn_cache (the predicate the EXIT trap uses), not a second, weaker glob;
  * the live turn's directory is never a candidate, and a prune that cannot complete is a NAMED
    failure that makes the turn exit non-zero (the permission-denied leg, run for real).

The last test is the negative control: the same scenario against a copy of the adapter with the
prune call removed, which leaves the expired directory in place. Without it, "the old directory is
gone" would be satisfied by a fixture that never created one.
"""

from __future__ import annotations

import os
import re
import shutil
import stat
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INSTALLER = ROOT / "scripts" / "harness" / "install-codex.sh"
# Fake key, built by concatenation so the literal never looks like a live credential to the
# secrets scanner — its job here is to be written into the turn's auth.json and then asserted
# ABSENT from the adapter's output.
SECRET = "sk" + "-cf446-fixture-secret-never-print"
TOKEN = "CF-446-TOKEN-7f3a9c"
TURN_FILE = "codex-turn.txt"
HOUR = 3600
DEFAULT_WINDOW_H = 72
# 200h is well outside the 72h default; 1h is well inside it. Both margins are far larger than
# any clock rounding the adapter could do, so a boundary bug cannot be mistaken for a pass.
OLD_AGE_S = 200 * HOUR
FRESH_AGE_S = 1 * HOUR

FAKE_CODEX = """#!/usr/bin/env bash
set -eu
if [ "${1:-}" = "--version" ]; then
  printf 'codex-cli 0.166.0\\n'
  exit 0
fi
if [ "${1:-}" = "exec" ]; then
  mkdir -p "$CODEX_HOME/sessions/2026/01/01"
  printf '%s\\n' '{"type":"thread_settings","thread_settings":{"model":"fixture-model"}}' > "$CODEX_HOME/sessions/2026/01/01/rollout-20260101-fixture-thread.jsonl"
  : > "$CODEX_HOME/state_5.sqlite"
  printf 'CF-446-TOKEN-7f3a9c\\n' > "$PWD/codex-turn.txt"
  printf '%s\\n' '{"type":"thread.started","thread_id":"fixture-thread"}'
  exit 0
fi
exit 0
"""


class Sandbox:
    """A temp HOME with a fake codex on PATH and a turn-ready workdir."""

    def __init__(self, root: Path) -> None:
        self.root = root
        self.home = root / "home"
        self.workdir = self.home / "work"
        self.bin_dir = root / "bin"
        self.cache_root = self.home / ".cache" / "cf-codex"
        self.key_file = self.home / "keys" / "provider.key"

    def build(self) -> "Sandbox":
        self.home.mkdir(mode=0o700, parents=True)
        os.chmod(self.home, 0o700)
        self.workdir.mkdir()
        self.bin_dir.mkdir()
        subprocess.run(
            ["git", "init", str(self.workdir)], check=True, capture_output=True
        )
        self.key_file.parent.mkdir()
        self.key_file.write_text(SECRET + "\n", encoding="utf-8")
        os.chmod(self.key_file, stat.S_IRUSR | stat.S_IWUSR)
        codex = self.bin_dir / "codex"
        codex.write_text(FAKE_CODEX, encoding="utf-8")
        codex.chmod(0o755)
        return self

    def env(self, **extra: str) -> dict:
        env = {
            "HOME": str(self.home),
            "PATH": f"{self.bin_dir}:/usr/bin:/bin",
            "XDG_CACHE_HOME": str(self.home / ".cache"),
            "CF_API_KEY_FILE": str(self.key_file),
            "CF_MODEL": "fixture-model",
            "CF_PROVIDER": "fixture-provider",
            "CF_WORKDIR": str(self.workdir),
            "CF_NAMESPACE": "fixture-namespace",
            "CF_RUN_ID": "cf446-fixture-run",
            "CF_LANE": "fixture-lane",
            "CF_TURN_TOKEN": TOKEN,
            "CF_TURN_FILE": TURN_FILE,
            "CF_TIMEOUT_S": "10",
        }
        env.update(extra)
        return env


def aged_dir(path: Path, age_s: int, payload: str = "evidence") -> Path:
    """Create a directory with a controlled mtime, and a child so removal is recursive."""
    path.mkdir(parents=True, exist_ok=True)
    child = path / "sessions" / "2026" / "01" / "01" / "rollout-fixture.jsonl"
    child.parent.mkdir(parents=True, exist_ok=True)
    child.write_text(payload + "\n", encoding="utf-8")
    stamp = time.time() - age_s
    os.utime(child, (stamp, stamp))
    os.utime(path, (stamp, stamp))
    return path


def run_installer(installer: Path, args: list[str], env: dict) -> tuple[int, str]:
    proc = subprocess.run(
        ["bash", str(installer), *args],
        cwd=ROOT,
        env=env,
        text=True,
        capture_output=True,
        timeout=60,
    )
    return proc.returncode, proc.stdout + proc.stderr


class TurnCacheRetention(unittest.TestCase):
    # ---------------------------------------------------------------- AC1: the named window
    def test_window_resolution_order_and_which_source_won(self):
        with tempfile.TemporaryDirectory() as temp:
            sb = Sandbox(Path(temp)).build()
            # --check measures nothing that the window can change, so the row is asserted without
            # depending on the host's binary state.
            cases = [
                (
                    "default",
                    ["--check"],
                    {},
                    f"PASS  turn_cache — max age {DEFAULT_WINDOW_H}h (source: default)",
                ),
                (
                    "env",
                    ["--check"],
                    {"CF_TURN_CACHE_MAX_AGE_H": "5"},
                    "PASS  turn_cache — max age 5h (source: CF_TURN_CACHE_MAX_AGE_H)",
                ),
                (
                    "flag beats env",
                    ["--check", "--turn-cache-max-age", "7"],
                    {"CF_TURN_CACHE_MAX_AGE_H": "5"},
                    "PASS  turn_cache — max age 7h (source: --turn-cache-max-age)",
                ),
            ]
            for label, args, extra, expected in cases:
                rc, output = run_installer(INSTALLER, args, sb.env(**extra))
                self.assertIn(
                    expected,
                    output,
                    f"{label}: expected row missing (rc={rc})\n{output}",
                )
                self.assertNotIn("FAIL  turn_cache", output, label)
                self.assertNotIn("REFUSED", output, label)

    def test_malformed_values_are_refused_by_name_and_origin(self):
        with tempfile.TemporaryDirectory() as temp:
            sb = Sandbox(Path(temp)).build()
            cases = [
                (
                    "not a number",
                    {"CF_TURN_CACHE_MAX_AGE_H": "abc"},
                    "CF_TURN_CACHE_MAX_AGE_H",
                ),
                ("negative", {"CF_TURN_CACHE_MAX_AGE_H": "-3"}, "NEGATIVE"),
                ("empty-ish flag", None, "--turn-cache-max-age"),
            ]
            for label, extra, needle in cases:
                if extra is None:
                    args = ["--check", "--turn-cache-max-age", "1.5"]
                    env = sb.env()
                    needle = "is not a whole number"
                else:
                    args = ["--check"]
                    env = sb.env(**extra)
                rc, output = run_installer(INSTALLER, args, env)
                self.assertEqual(
                    2,
                    rc,
                    f"{label}: a malformed window must refuse with exit 2\n{output}",
                )
                self.assertIn(
                    "REFUSED (turn_cache)",
                    output,
                    f"{label}: no named refusal\n{output}",
                )
                self.assertIn(
                    needle,
                    output,
                    f"{label}: the refusal must name the origin\n{output}",
                )
                # Fail closed, never fall back: a silent default is how a cache stops being bounded.
                self.assertNotIn(
                    f"max age {DEFAULT_WINDOW_H}h (source: default)",
                    output,
                    f"{label}: the adapter fell back to the default\n{output}",
                )

            # Out of range, both ends, and the origin is still named.
            for bad in ("0", "8761"):
                rc, output = run_installer(
                    INSTALLER, ["--check"], sb.env(CF_TURN_CACHE_MAX_AGE_H=bad)
                )
                self.assertEqual(2, rc, f"range {bad}: want refusal\n{output}")
                self.assertIn("out of range", output, f"range {bad}: {output}")
                self.assertIn(
                    "CF_TURN_CACHE_MAX_AGE_H", output, f"range {bad}: {output}"
                )

    # ------------------------------------------- AC2: pruning, proven in both directions
    def test_expired_removed_fresh_kept_and_foreign_untouched(self):
        with tempfile.TemporaryDirectory() as temp:
            sb = Sandbox(Path(temp)).build()
            expired = aged_dir(sb.cache_root / "run.oldaaaa", OLD_AGE_S)
            fresh = aged_dir(sb.cache_root / "run.freshbb", FRESH_AGE_S)
            # (c) shapes that are NOT one run.* leaf directly under the cache root.
            nested = aged_dir(sb.cache_root / "nested" / "run.oldnest", OLD_AGE_S)
            suffixless = aged_dir(sb.cache_root / "run.", OLD_AGE_S)
            outside = aged_dir(sb.home / ".cache" / "run.outside", OLD_AGE_S)
            plain = aged_dir(sb.cache_root / "keepme", OLD_AGE_S)

            rc, output = run_installer(INSTALLER, ["--turn"], sb.env())
            self.assertEqual(0, rc, output)
            self.assertNotIn(SECRET, output)
            self.assertNotIn("OPENAI_API_KEY", output)
            self.assertIn(
                f"PASS  turn_cache — max age {DEFAULT_WINDOW_H}h (source: default)",
                output,
            )
            self.assertIn(
                f"PASS  turn_cache_prune — {sb.cache_root} — 1 directory(ies) older than "
                f"{DEFAULT_WINDOW_H}h removed",
                output,
            )

            # (a) older than the window: REMOVED, recursively.
            self.assertFalse(
                expired.exists(), f"expired turn directory survived the turn\n{output}"
            )
            # (b) inside the window: SURVIVES.
            self.assertTrue(
                fresh.is_dir(), f"a turn inside the window was pruned\n{output}"
            )
            # (c) the predicate, not a glob: each of these carries an old mtime and survives.
            self.assertTrue(
                nested.is_dir(), "a run.* that is not a direct leaf was removed"
            )
            self.assertTrue(
                suffixless.is_dir(), "'run.' (no suffix) is not a turn leaf"
            )
            self.assertTrue(
                outside.is_dir(), "a run.* OUTSIDE the cache root was removed"
            )
            self.assertTrue(
                plain.is_dir(), "an unrelated directory under the root was removed"
            )

            # The turn that just ran is intact and is NOT the directory that was pruned.
            match = re.search(
                r"PASS  turn_home — (\S+) \(isolated config \+ key", output
            )
            self.assertIsNotNone(match, output)
            turn_home = Path(match.group(1))
            self.assertTrue(
                turn_home.is_dir(), "the live turn's own home must exist after the turn"
            )
            self.assertNotEqual(str(expired), str(turn_home))
            self.assertTrue(
                (turn_home / "state_5.sqlite").exists(), "CF-329 index must survive"
            )
            self.assertFalse(
                (turn_home / "auth.json").exists(), "CF-329 credentials still removed"
            )

    def test_prune_runs_before_the_new_turn_home_is_created(self):
        """The ordering is a static invariant: a prune AFTER mktemp could delete the live turn."""
        source = INSTALLER.read_text(encoding="utf-8")
        prune_at = source.index('prune_turn_cache "$cache_root" "$turn_home"')
        mktemp_at = source.index('mktemp -d "$cache_root/run.XXXXXXXX"')
        self.assertLess(
            prune_at, mktemp_at, "the prune must precede the turn home's creation"
        )
        keep_at = source.index('[ -n "$keep" ] && [ "$p" = "$keep" ]')
        self.assertLess(
            keep_at, prune_at, "the live-turn guard must be inside the prune"
        )

    # ------------------------------------------------ AC3: a failed prune is not success
    @unittest.skipIf(
        os.geteuid() == 0, "a root-owned cache root cannot deny its own unlink"
    )
    def test_permission_denied_prune_fails_the_turn(self):
        with tempfile.TemporaryDirectory() as temp:
            sb = Sandbox(Path(temp)).build()
            expired = aged_dir(sb.cache_root / "run.stuckcc", OLD_AGE_S)
            os.chmod(
                sb.cache_root, 0o500
            )  # readable/searchable, not writable: rm must fail
            try:
                rc, output = run_installer(INSTALLER, ["--turn"], sb.env())
            finally:
                os.chmod(sb.cache_root, 0o700)

            self.assertNotEqual(0, rc, f"a failed prune must not exit 0\n{output}")
            self.assertIn("FAIL  turn_cache_prune", output, output)
            self.assertIn("CODEX: FAIL", output, output)
            # Nothing was claimed as pruned, and the turn never ran.
            self.assertNotIn("PASS  turn_cache_prune", output, output)
            self.assertNotIn("turn_home", output, output)
            self.assertNotIn("turn_exit", output, output)
            self.assertTrue(
                expired.is_dir(), "a failed prune must not half-remove the directory"
            )

    # ----------------------------------------------------- the negative control (PROVEN-RED)
    def test_pre_fix_adapter_leaves_the_expired_directory_in_place(self):
        """Remove the prune call from a copy: the same scenario must now FAIL its assertion."""
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            tree = root / "prefix"
            (tree / "scripts" / "harness").mkdir(parents=True)
            shutil.copy2(ROOT / "scripts" / "lib.sh", tree / "scripts" / "lib.sh")
            source = INSTALLER.read_text(encoding="utf-8")
            mutated = source.replace(
                'prune_turn_cache "$cache_root" "$turn_home"', "true"
            )
            # The premise: the mutation must actually have happened, or this arm proves nothing.
            self.assertEqual(
                1, source.count('prune_turn_cache "$cache_root" "$turn_home"')
            )
            self.assertNotEqual(
                source, mutated, "the pre-fix copy is identical — no control"
            )
            copy = tree / "scripts" / "harness" / "install-codex.sh"
            copy.write_text(mutated, encoding="utf-8")
            copy.chmod(0o755)

            sb = Sandbox(root / "sb").build()
            expired = aged_dir(sb.cache_root / "run.oldaaaa", OLD_AGE_S)
            rc, output = run_installer(copy, ["--turn"], sb.env())

            self.assertEqual(0, rc, output)
            self.assertNotIn("turn_cache_prune", output, "the control still pruned")
            self.assertTrue(
                expired.is_dir(),
                "negative control: the pre-fix adapter must leave the expired directory behind",
            )


if __name__ == "__main__":
    unittest.main()
