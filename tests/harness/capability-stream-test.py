#!/usr/bin/env python3
"""Exercise capability probes with stdout, stderr and absent capabilities."""

from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


def function(source, name):
    start = source.index(name + "() {")
    end = source.index("\n}", start) + 2
    return source[start:end]


def probe(source, name, binary):
    script = (
        """ok() { printf 'PASS %s %s\\n' "$1" "$2"; }
bad() { printf 'FAIL %s %s\\n' "$1" "$2"; }
note() { printf 'NOTE %s\\n' "$*"; }
"""
        + function(source, name)
        + "\n"
        + name
        + ' "$1"\n'
    )
    return subprocess.run(
        ["bash", "-s", "--", str(binary)], input=script, text=True, capture_output=True
    )


class CapabilityStreams(unittest.TestCase):
    def test_codex_help_streams_and_missing(self):
        path = "scripts/harness/install-codex.sh"
        source = (ROOT / path).read_text()
        old = subprocess.check_output(
            ["git", "show", "0a1a0e7225e36e519df8503e8f615b3ba0e7c62e:" + path],
            text=True,
            cwd=ROOT,
        )
        with tempfile.TemporaryDirectory() as d:
            binary = Path(d) / "codex"
            for stream in ("1", "2", "missing"):
                text = (
                    "no capabilities"
                    if stream == "missing"
                    else "--json --sandbox app-server"
                )
                fd = "2" if stream == "2" else "1"
                binary.write_text(
                    '#!/bin/sh\nprintf "%s\\n" "' + text + '" >&' + fd + "\n"
                )
                binary.chmod(0o755)
                for name in ("report_exec_contract", "report_app_server"):
                    with self.subTest(stream=stream, name=name):
                        result = probe(source, name, binary)
                        self.assertEqual(
                            result.returncode,
                            1 if stream == "missing" else 0,
                            result.stdout,
                        )
                        if stream == "2":
                            red = probe(old, name, binary)
                            self.assertNotEqual(red.returncode, 0, red.stdout)

    def test_claude_budget_probe_streams_and_red_control(self):
        path = "scripts/harness/install-claude-code.sh"
        source = (ROOT / path).read_text()
        old = subprocess.check_output(
            ["git", "show", "0a1a0e7225e36e519df8503e8f615b3ba0e7c62e:" + path],
            text=True,
            cwd=ROOT,
        )

        def run(src, binary):
            start = src.index('  if "$BIN" --help', src.index("do_turn()"))
            end = src.index("\n  fi", start) + len("\n  fi")
            script = (
                'BIN="$1"; MAX_TURNS=40; CLAUDE_CODE_PIN=test; TIMEOUT_S=10; cli=(); note() { :; }\n'
                + src[start:end]
                + '\nprintf "%s\\n" "${cli[*]}"\n'
            )
            return subprocess.check_output(
                ["bash", "-s", "--", str(binary)], input=script, text=True
            )

        with tempfile.TemporaryDirectory() as d:
            binary = Path(d) / "claude"
            for fd in ("1", "2"):
                binary.write_text(
                    '#!/bin/sh\nprintf "%s\\n" --max-turns >&' + fd + "\n"
                )
                binary.chmod(0o755)
                self.assertEqual(run(source, binary).strip(), "--max-turns 40")
            self.assertEqual(run(old, binary).strip(), "")
            binary.write_text('#!/bin/sh\nprintf "%s\\n" unavailable >&2\n')
            self.assertEqual(run(source, binary).strip(), "")


if __name__ == "__main__":
    unittest.main(verbosity=2)
