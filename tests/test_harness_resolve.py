#!/usr/bin/env python3
"""Hermetic tests for scripts/harness_resolve.py — harness selection is data-driven (CF-230).

The rule under test is `specs/HARNESS-MATRIX.md` §4: directive > lane > matrix >
fallback, first hit wins WITH its reason recorded, and four named refusals instead
of a silent fallback. Every case here drives the real CLI (exit code + printed row)
or the real module; nothing is mocked, and the table is read from
`config/harness-matrix.json` at test time, so a hardcoded table in the resolver
fails the "the matrix is data" case below.

Run: python3 -B tests/test_harness_resolve.py   (works from any working directory)
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ROOT, "scripts", "harness_resolve.py")
MATRIX_FILE = os.path.join(ROOT, "config", "harness-matrix.json")
SPEC_FILE = os.path.join(ROOT, "specs", "HARNESS-MATRIX.md")

sys.path.insert(0, os.path.join(ROOT, "scripts"))
import harness_resolve  # noqa: E402

AC3_KEYS = (
    "harness_selected",
    "harness_reason",
    "model_requested",
    "model_served",
    "provider_family",
    "provider_binding",
    "lane",
    "lane_class",
)


def run_cli(*args: str, cwd: str = ROOT) -> tuple:
    """Run the real CLI; return (exit code, stdout+stderr)."""
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1")
    proc = subprocess.run(
        [sys.executable, "-B", SCRIPT, *args],
        capture_output=True,
        text=True,
        cwd=cwd,
        env=env,
    )
    return proc.returncode, proc.stdout + proc.stderr


def record(*args: str, cwd: str = ROOT) -> dict:
    rc, out = run_cli(*args, "--json", cwd=cwd)
    if rc != 0:
        raise AssertionError(f"expected exit 0 from {args}, got {rc}: {out}")
    return json.loads(out.strip())


class FamilyDerivation(unittest.TestCase):
    """The model-id -> family table documented in the module docstring."""

    CASES = (
        ("claude-sonnet-4", "claude"),
        ("claude-opus-4-1", "claude"),
        ("gpt-5", "openai"),
        ("gpt-6-luna", "openai"),
        ("o3-mini", "openai"),
        ("o4-mini", "openai"),
        ("o1-preview", "openai"),
        ("codex-mini-latest", "openai"),
        ("openai-codex/gpt-6-luna", "openai"),
        ("deepseek-v4-flash", "deepseek"),
        ("deepseek-v4-pro", "deepseek"),
        ("glm-5.3-flash", "zai"),
        ("zai/glm-4.6", "zai"),
        ("qwen3-coder", "qwen"),
        ("kimi-k2", "kimi"),
        ("moonshot-v1-128k", "kimi"),
        ("mistral-large-2411", "mistral"),
        ("llama-3.3-70b", "llama"),
        ("gemini-2.5-pro", "gemini"),
        ("grok-4", "grok"),
        ("minimax-m2", "minimax"),
        ("pi-agent", "pi"),
        ("omp-18.16.0", "pi"),
        ("anthropic/claude-sonnet-4", "claude"),
        ("totally-unknown-model", "unknown"),
    )

    def test_every_family_maps(self):
        for model, expected in self.CASES:
            with self.subTest(model=model):
                self.assertEqual(harness_resolve.model_family(model), expected)

    def test_empty_and_case(self):
        self.assertEqual(harness_resolve.model_family(""), "unknown")
        self.assertEqual(harness_resolve.model_family("GPT-5"), "openai")


class LaneClassDerivation(unittest.TestCase):
    SATELLITES = (
        "code-factory-qa",
        "code-factory-pm",
        "code-factory-sync",
        "code-factory-dogfood",
        "code-factory-releng",
        "code-factory-docs",
        "code-factory-readme",
        "code-factory-perf",
        "code-factory-review",
    )

    def test_satellite_suffixes(self):
        for lane in self.SATELLITES:
            with self.subTest(lane=lane):
                self.assertEqual(harness_resolve.lane_class(lane), "satellite")

    def test_foreman_names(self):
        for lane in ("code-factory", "code-factory-bankai", "code-factory-foreman"):
            with self.subTest(lane=lane):
                self.assertEqual(harness_resolve.lane_class(lane), "foreman")

    def test_default_and_override(self):
        self.assertEqual(harness_resolve.lane_class(None), "foreman")
        self.assertEqual(harness_resolve.lane_class(None, "satellite"), "satellite")
        self.assertEqual(
            harness_resolve.lane_class("code-factory", "satellite"), "satellite"
        )


class ResolutionOrder(unittest.TestCase):
    """AC1: directive > lane > matrix > fallback, each hit recording its own reason."""

    def test_directive_beats_lane_matrix_and_fallback(self):
        rec = record(
            "--explain",
            "claude-sonnet-4",
            "--lane",
            "code-factory-qa",
            "--lane-harness",
            "codex",
            "--directive-harness",
            "hermes",
        )
        self.assertEqual(
            (rec["harness_selected"], rec["harness_reason"]), ("hermes", "directive")
        )

    def test_lane_beats_matrix(self):
        rec = record(
            "--explain",
            "claude-sonnet-4",  # matrix would answer claude-code
            "--lane",
            "code-factory-qa",
            "--lane-harness",
            "opencode",
        )
        self.assertEqual(
            (rec["harness_selected"], rec["harness_reason"]), ("opencode", "lane")
        )

    def test_matrix_beats_fallback(self):
        rec = record("--explain", "claude-sonnet-4", "--lane", "code-factory-qa")
        self.assertEqual(
            (rec["harness_selected"], rec["harness_reason"]), ("claude-code", "matrix")
        )

    def test_fallback_is_reported_never_silent(self):
        # qwen is a known family with no by_family entry: the policy default wins.
        rc, out = run_cli("--explain", "qwen3-coder")
        self.assertEqual(rc, 0)
        self.assertIn("harness_selected=hermes", out)
        self.assertIn("harness_reason=fallback", out)
        rec = record("--explain", "qwen3-coder")
        self.assertEqual(
            (rec["harness_selected"], rec["harness_reason"]), ("hermes", "fallback")
        )

    def test_family_selects_matrix_entry(self):
        """AC1 against the table: claude -> claude-code, openai -> codex."""
        claude = record("--explain", "claude-sonnet-4")
        openai = record("--explain", "gpt-5")
        self.assertEqual(
            (claude["harness_selected"], claude["provider_family"]),
            ("claude-code", "claude"),
        )
        self.assertEqual(
            (openai["harness_selected"], openai["provider_family"]), ("codex", "openai")
        )


class Refusals(unittest.TestCase):
    """AC2 + AC4: each refusal is named, and the satellite lane proves it is lane-driven."""

    def test_foreman_lane_refuses_non_hermes(self):
        rc, out = run_cli(
            "--explain", "gpt-5", "--lane", "code-factory", "--lane-harness", "codex"
        )
        self.assertEqual(rc, 2, out)
        self.assertIn("FAIL harness_foreman_requires_hermes", out)
        self.assertIn("harness=codex", out)

    def test_matrix_resolved_non_hermes_foreman_lane_refuses(self):
        # No lane pin at all: the matrix alone selects codex, and I1 still refuses.
        rc, out = run_cli("--explain", "gpt-5", "--lane", "code-factory")
        self.assertEqual(rc, 2, out)
        self.assertIn("harness_foreman_requires_hermes", out)
        self.assertIn("lane=code-factory", out)

    def test_same_request_on_a_satellite_lane_is_allowed(self):
        rc, out = run_cli(
            "--explain", "gpt-5", "--lane", "code-factory-qa", "--lane-harness", "codex"
        )
        self.assertEqual(rc, 0, out)
        self.assertIn("harness_selected=codex", out)
        self.assertIn("harness_reason=lane", out)

    def test_installed_set_refuses_an_absent_harness(self):
        rc, out = run_cli(
            "--explain",
            "gpt-5",
            "--lane",
            "code-factory-qa",
            "--node-harnesses",
            "hermes",
        )
        self.assertEqual(rc, 2, out)
        self.assertIn("FAIL harness_unsupported: codex", out)
        self.assertIn("node has: hermes", out)

    def test_installed_set_allows_a_present_harness(self):
        rc, out = run_cli(
            "--explain",
            "gpt-5",
            "--lane",
            "code-factory-qa",
            "--node-harnesses",
            "hermes,codex",
        )
        self.assertEqual(rc, 0, out)
        self.assertIn("harness_selected=codex", out)

    def test_harness_that_cannot_host_the_family_refuses(self):
        rc, out = run_cli(
            "--explain",
            "deepseek-v4-flash",
            "--lane",
            "code-factory-qa",
            "--directive-harness",
            "codex",
        )
        self.assertEqual(rc, 2, out)
        self.assertIn("FAIL harness_cannot_host: codex deepseek", out)

    def test_a_named_shim_makes_the_same_pair_hostable(self):
        rc, out = run_cli(
            "--explain",
            "deepseek-v4-flash",
            "--lane",
            "code-factory-qa",
            "--directive-harness",
            "codex",
            "--shims",
            "deepseek=router-deepseek",
        )
        self.assertEqual(rc, 0, out)
        self.assertIn("harness_selected=codex", out)
        self.assertIn("provider_binding=shim/router-deepseek", out)

    def test_unknown_directive_harness_is_named(self):
        rc, out = run_cli("--explain", "claude-sonnet-4", "--directive-harness", "nope")
        self.assertEqual(rc, 2, out)
        self.assertIn("FAIL harness_directive_unknown: nope", out)

    def test_unknown_lane_harness_is_named(self):
        rc, out = run_cli(
            "--explain",
            "claude-sonnet-4",
            "--lane",
            "code-factory-qa",
            "--lane-harness",
            "nope",
        )
        self.assertEqual(rc, 2, out)
        self.assertIn("FAIL harness_lane_unknown: nope", out)

    def test_unparseable_shim_is_named(self):
        rc, out = run_cli(
            "--explain",
            "deepseek-v4-flash",
            "--lane",
            "code-factory-qa",
            "--shims",
            "deepseek",
        )
        self.assertEqual(rc, 2, out)
        self.assertIn("harness_shim_unparseable", out)


class RecordedDecision(unittest.TestCase):
    """AC3: every run records the decision, the reason, and requested vs served."""

    def test_json_record_carries_every_key(self):
        rec = record("--explain", "claude-sonnet-4", "--lane", "code-factory-qa")
        for key in AC3_KEYS:
            self.assertIn(key, rec, f"record is missing {key}")
        self.assertIn(
            rec["harness_reason"], ("directive", "lane", "matrix", "fallback")
        )
        self.assertIsNone(rec["model_served"], "model_served must be null before a run")
        self.assertEqual(rec["model_requested"], "claude-sonnet-4")
        self.assertEqual(rec["lane"], "code-factory-qa")
        self.assertEqual(rec["lane_class"], "satellite")

    def test_text_row_carries_every_recorded_field(self):
        rc, out = run_cli("--explain", "claude-sonnet-4")
        self.assertEqual(rc, 0, out)
        for token in (
            "PASS harness_selected=claude-code",
            "harness_reason=matrix",
            "model_requested=claude-sonnet-4",
            "provider_family=claude",
            "model_served=<null-until-a-run>",
            "provider_binding=native",
        ):
            self.assertIn(token, out)

    def test_help_documents_every_flag(self):
        rc, out = run_cli("--help")
        self.assertEqual(rc, 0, out)
        for flag in (
            "--explain",
            "--lane",
            "--lane-class",
            "--directive-harness",
            "--lane-harness",
            "--node-harnesses",
            "--shims",
            "--matrix-file",
            "--json",
        ):
            self.assertIn(flag, out)


class MatrixIsData(unittest.TestCase):
    """The table lives in json, not in code: point the resolver at another one."""

    def _write(self, body: dict) -> str:
        fd, path = tempfile.mkstemp(prefix="harness-matrix-", suffix=".json")
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump(body, fh)
        self.addCleanup(os.unlink, path)
        return path

    def test_shipped_matrix_loads_and_defaults_to_hermes(self):
        with open(MATRIX_FILE, encoding="utf-8") as fh:
            matrix = json.load(fh)
        self.assertEqual(matrix["default"], "hermes")
        self.assertEqual(matrix["by_family"]["claude"], "claude-code")
        self.assertEqual(matrix["by_family"]["openai"], "codex")
        self.assertIn("hermes", matrix["hosts"])

    def test_a_changed_matrix_changes_the_decision(self):
        path = self._write(
            {
                "default": "hermes",
                "by_family": {"claude": "opencode"},
                "hosts": {
                    "hermes": ["*"],
                    "opencode": ["*"],
                    "claude-code": ["claude"],
                },
                "shims": {},
            }
        )
        rec = record(
            "--explain",
            "claude-sonnet-4",
            "--lane",
            "code-factory-qa",
            "--matrix-file",
            path,
        )
        self.assertEqual(
            (rec["harness_selected"], rec["harness_reason"]), ("opencode", "matrix")
        )

    def test_an_unusable_matrix_is_named_not_ignored(self):
        path = self._write({"default": "hermes"})
        rc, out = run_cli("--explain", "claude-sonnet-4", "--matrix-file", path)
        self.assertEqual(rc, 2, out)
        self.assertIn("harness_matrix_invalid", out)

    def test_default_matrix_resolves_from_any_working_directory(self):
        with tempfile.TemporaryDirectory() as elsewhere:
            rc, out = run_cli("--explain", "claude-sonnet-4", cwd=elsewhere)
        self.assertEqual(rc, 0, out)
        self.assertIn("harness_selected=claude-code", out)


class SpecSync(unittest.TestCase):
    """AC1/AC4: every harness the matrix names is a harness §2 of the spec measured."""

    def _section_two_harness_names(self) -> set:
        with open(SPEC_FILE, encoding="utf-8") as fh:
            lines = fh.read().splitlines()
        start = None
        for index, line in enumerate(lines):
            if line.startswith("## 2."):
                start = index
                break
        self.assertIsNotNone(start, "specs/HARNESS-MATRIX.md has no '## 2.' section")
        names = set()
        for line in lines[start + 1 :]:
            if line.startswith("## "):
                break
            cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
            if not line.startswith("|") or len(cells) < 2:
                continue
            first = cells[0].replace("*", "").replace("`", "").strip()
            if (
                not first
                or first.lower().startswith("harness")
                or set(first) <= {"-", ":"}
            ):
                continue  # header or separator row
            for token in first.lower().replace("(", " ").replace(")", " ").split():
                names.add(token)
        return names

    def test_matrix_harnesses_are_measured_in_the_spec(self):
        named = self._section_two_harness_names()
        self.assertGreaterEqual(
            len(named), 5, f"§2 harness rows did not parse: {named}"
        )
        with open(MATRIX_FILE, encoding="utf-8") as fh:
            matrix = json.load(fh)
        for harness in sorted(set(matrix["by_family"].values()) | set(matrix["hosts"])):
            with self.subTest(harness=harness):
                self.assertIn(
                    harness,
                    named,
                    f"matrix names {harness!r} but specs/HARNESS-MATRIX.md §2 does not measure it",
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)
