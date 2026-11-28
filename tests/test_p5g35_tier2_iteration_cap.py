#!/usr/bin/env python3
"""P5G-35 regression: the tier-2 evaluator starvation is bounded, not re-capped.

Drives the REAL GitReins tier-2 evaluator (engine.evaluator from the local
~/gitreins build) with scripted mock judges, so every assertion below is
against the engine's actual loop, cap metering and verdict parsing.

Three properties, matching the P5G-35 acceptance criteria:

1. EXAMINED verdict — a one-criterion task graded under the read-once PROOF
   recipe returns a merits status (PASS) with a detail that names the evidence
   (the log's decisive lines), inside the very cap that starved the
   unconverged runs, with the run's verdict path and iteration count recorded.
2. The binding rung is the ITERATION cap, proven by measurement — the
   unconverged arm's summary carries the literal cap line ("Cap exceeded:
   Iteration cap (N) reached (N.8 used)"), the wall clock is recorded and sits
   far under max_time, and the output spend sits far under max_output_tokens,
   so neither of those rungs bound the run.
3. The poll is bounded rather than the budget — the compliant judge reads the
   log exactly once and issues ZERO sleep/grep polls, while the unconverged
   judge burns the entire cap on consecutive polls without ever reading the
   log; the engine's exact-repeat dedup hint fires (measured, count > 0) yet
   does not bound the loop, which is exactly why the recipe, not another cap
   raise, is the remedy. The poll count is recorded next to the cap used.

Negative controls: a tampered fixture log grades examined-FAIL naming the
differing line (the verdict tracks evidence, it is not a rubber stamp), and
the unconverged poller reproduces the unexamined FAILIF shape ("Not examined
— evaluation ended before this criterion was reached").

Run standalone: python3 -B tests/test_p5g35_tier2_iteration_cap.py
Skips (named) when the ~/gitreins engine build is absent — the fixture is the
CF-426 probe's dependency shape, not a hidden one.
"""

from __future__ import annotations

import importlib.util
import json
import pathlib
import tempfile
import unittest

HERE = pathlib.Path(__file__).resolve().parent
REPO_ROOT = HERE.parent
PROBE_PATH = REPO_ROOT / "scripts" / "probe_p5g35_tier2_poll_bound.py"

_ENGINE_ERR = ""
_probe = None
try:
    _spec = importlib.util.spec_from_file_location(
        "probe_p5g35_tier2_poll_bound", PROBE_PATH
    )
    _probe = importlib.util.module_from_spec(_spec)
    _spec.loader.exec_module(_probe)
except Exception as _e:  # pragma: no cover — engine build missing on CI clones
    _ENGINE_ERR = f"{type(_e).__name__}: {_e}"


@unittest.skipUnless(
    _probe is not None, f"gitreins engine not importable: {_ENGINE_ERR}"
)
class TestP5G35Tier2IterationCap(unittest.TestCase):
    """The three arms the board row's PROOF names, driven against the real engine."""

    def _fresh(self):
        """Scratch config (cap 8 / max_time 30m / out 1m) + fixture workdir."""
        tmp = tempfile.TemporaryDirectory(prefix="p5g35-test-")
        self.addCleanup(tmp.cleanup)
        cfg = pathlib.Path(tmp.name) / "cfg"
        work = pathlib.Path(tmp.name) / "work"
        _probe.make_config(str(cfg))
        return str(cfg), str(work)

    # ── AC1: the examined verdict ────────────────────────────────────────

    def test_bounded_recipe_returns_examined_verdict_with_named_evidence(self):
        cfg, work = self._fresh()
        s = _probe.run_bounded_arm(work, cfg)
        record = {
            "verdict": s["verdict"],
            "items": s["items"],
            "iterations_used": s["iterations_used"],
            "cap_used": s["cap_used"],
        }
        # The verdict path and the iteration count the run used — the two
        # facts AC1 says the row must record.
        print("P5G35_TEST_RECORD " + json.dumps(record, ensure_ascii=False))
        self.assertEqual(s["verdict"], "COMPLETE")
        self.assertEqual(s["criteria_graded"], 1)
        self.assertEqual(s["criteria_unexamined"], 0)
        item = s["items"][0]
        self.assertEqual(item["status"], "PASS")  # merits status, not UNVERIFIED
        # The detail names evidence, not "Not examined — …".
        self.assertIn("SELFTEST: PASS", item["detail"])
        self.assertNotIn("Not examined", item["detail"])
        # Examined INSIDE the cap that starved the unconverged runs.
        self.assertLess(s["iterations_used"], s["cap_used"]["max_iterations"])
        self.assertGreaterEqual(s["log_reads"], 1)

    def test_tampered_log_is_graded_examined_fail_not_rubber_stamped(self):
        """Negative control: the verdict tracks the evidence, so a differing
        tally line flips the merit to FAIL with that line named — an
        unexamined-rubber-stamp regression cannot pass this test."""
        cfg, work = self._fresh()
        s = _probe.run_bounded_arm(work, cfg, tamper=True)
        self.assertEqual(s["criteria_graded"], 1)
        self.assertEqual(s["criteria_unexamined"], 0)
        item = s["items"][0]
        self.assertEqual(item["status"], "FAIL")
        self.assertIn("SELFTEST: FAIL (2)", item["detail"])
        self.assertNotIn("Not examined", item["detail"])

    # ── AC2: the knob that bound, justified by measurement ───────────────

    def test_unconverged_run_trips_the_iteration_cap_with_the_literal_line(self):
        cfg, work = self._fresh()
        s = _probe.run_starved_arm(work, cfg)
        # Literal cap line the row must quote.
        self.assertIn("Cap exceeded: Iteration cap (8) reached (8.", s["summary"])
        self.assertEqual(s["cap_line"], "Iteration cap (8) reached (8.7 used)")
        # The binding rung IS the iteration cap.
        self.assertEqual(s["binding_rung"], "iterations")
        # max_time and max_output_tokens were NOT the binding rungs: the wall
        # clock is recorded and sits far under max_time, the output spend far
        # under max_output_tokens.
        self.assertLess(s["elapsed_s"], s["max_time_seconds"])
        self.assertTrue(s["time_not_binding"])
        self.assertLess(s["output_tokens_used_est"], s["max_output_tokens"])
        self.assertTrue(s["output_not_binding"])
        # The FAILIF shape: 0 of 1 graded, criterion unexamined.
        self.assertEqual(s["verdict"], "INCOMPLETE")
        self.assertEqual(s["criteria_graded"], 0)
        self.assertEqual(s["criteria_unexamined"], 1)
        self.assertEqual(s["items"][0]["status"], "UNVERIFIED")
        self.assertTrue(s["items"][0]["detail"].startswith("Not examined"))

    # ── AC3: the poll is bounded, and the count is recorded next to the cap ─

    def test_poll_loop_is_unbounded_without_the_recipe_and_bounded_with_it(self):
        """The compliant judge reads the log ONCE and issues ZERO polls; the
        unconverged judge burns the whole cap on consecutive polls, and the
        dedup hint (measured firing) does not bound it."""
        cfg, work = self._fresh()
        bounded = _probe.run_bounded_arm(work, cfg)
        starved = _probe.run_starved_arm(work, cfg)
        # Bounded: log read once, zero sleep/grep polls against it.
        self.assertEqual(bounded["log_reads"], 1)
        self.assertEqual(bounded["poll_count"], 0)
        # Starved: consecutive sleep/grep polls, never a read — the loop the
        # recipe removes, and the exact-repeat dedup hint fired yet the run
        # still starved (a warning is not a bound).
        self.assertGreaterEqual(starved["poll_count"], 5)
        self.assertEqual(starved["log_reads"], 0)
        self.assertGreaterEqual(starved["dedup_warnings"], 1)
        # The poll count is recorded NEXT TO the cap the run used (the pair
        # AC3 says the row must carry).
        self.assertIn("poll_count", bounded)
        self.assertIn("poll_count", starved)
        self.assertIn("cap_used", bounded)
        self.assertIn("cap_used", starved)
        self.assertEqual(bounded["cap_used"]["max_iterations"], 8)
        self.assertEqual(starved["cap_used"]["max_iterations"], 8)

    def test_evidence_bundle_records_poll_count_beside_the_cap(self):
        """The durable evidence artifact the row cites carries, for each arm,
        the cap used and the measured poll count side by side."""
        evidence = _probe.build_evidence(
            {
                "bounded": {
                    "cap_used": {"max_iterations": 8},
                    "poll_count": 0,
                    "log_reads": 1,
                },
                "starved": {
                    "cap_used": {"max_iterations": 8},
                    "poll_count": 8,
                    "log_reads": 0,
                },
            }
        )
        arms = evidence["arms"]
        self.assertEqual(arms["bounded"]["poll_count"], 0)
        self.assertEqual(arms["bounded"]["cap_used"]["max_iterations"], 8)
        self.assertEqual(arms["starved"]["poll_count"], 8)
        # Round-trips as JSON (it is written beside the probe and committed).
        json.dumps(evidence)


if __name__ == "__main__":
    unittest.main(verbosity=2)
