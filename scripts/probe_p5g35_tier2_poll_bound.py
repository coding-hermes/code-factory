#!/usr/bin/env python3
"""P5G-35 instrument: bound tier-2 evaluator starvation by measurement, not by another cap raise.

Drives the installed GitReins tier-2 evaluator (``engine.evaluator`` from the
local build at ~/gitreins, the same tree the pipx ``gitreins`` binary is built
from) through its REAL agentic loop — real tools (read_file/run_command/
sandbox_write over a scratch workdir), real cap metering, real verdict
parsing — with scripted mock judges standing in for the lane.

Why this exists (P5G-35 / CF-426 history in .gitreins/config.yaml): every cap
rung the tier-2 judge outgrew (15 → 40 → 100 → 200 → 400 → 800) ended with the
same shape — "0 of 1 criteria graded", criterion UNVERIFIED "Not examined —
evaluation ended before this criterion was reached" — and the 800 rung died on
the 10M input-token budget at 716.3 iterations without grading anything, so
raising the cap is measured NOT to converge. Nothing in
``engine/evaluator.py::_evaluate_loop`` allocates budget per criterion or
bounds evidence gathering, and the engine's dedup hint fires only on an EXACT
tool-name + arguments repeat, so a judge that varies one argument per poll
re-bills every pass. This instrument measures the remedies the row files:

* bounded arm — the read-once PROOF recipe: the criterion names the recorded
  log and forbids polling and re-derivation; a judge that follows it reads the
  log exactly ONCE (0 sleep/grep poll calls) and grades the criterion EXAMINED
  (merits status + a detail naming the evidence) well inside the same cap the
  starved runs burned.
* starved arm — the same one-criterion task driven by an unconverging judge
  that polls the log with ``sleep``/``grep`` run_commands, varying arguments
  each pass and interleaving exact repeats: the run trips the ITERATION cap
  with the literal cap line ("Cap exceeded: Iteration cap (N) reached (N.8
  used)"), the wall clock stays far under max_time, the output spend far under
  max_output_tokens (so neither of those rungs bound), and the criterion comes
  back UNVERIFIED — the exact FAILIF shape P5G-35 names.

Both arms read the SAME scratch config (evaluator.max_iterations: 8,
max_time: "30m", max_output_tokens: "1m") so the only variable is judge
behavior. Every number the row cites — the cap line, the wall clock, the poll
count, the log reads, the dedup warnings — is measured from the evaluator's
own tool record and message transcript, not asserted.

Ownership note (P5G-35): the structural poll cap lives in the gitreins engine
(the loop is model-driven; a per-tool-seam poll counter is gitreins-repo work,
not code-factory). This repo's licensed remedy is the bounded judged evidence
scope proven on real verdicts (2de7f84b, 402cc1f4, 7f326496) — the read-once
recipe replayed here — plus the measured poll count recorded next to the cap
the run used, which is exactly what AC3 of P5G-35 requires the row to carry.

Token figures are transcript-derived estimates (chars / 3.5, the engine's own
``_estimate_context_tokens`` fallback scale) — labelled estimates, not
provider-billed numbers, like the CF-426 probe before it.
"""

from __future__ import annotations

import datetime
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile
import time
from typing import Any

GITREINS_SRC = pathlib.Path.home() / "gitreins"
sys.path.insert(0, str(GITREINS_SRC))

from engine.evaluator import AgenticEvaluator  # noqa: E402
from engine.llm import LLMResponse, LLMUsage, ToolCall  # noqa: E402

REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]
TASK_ID = "P5G-35-PROBE"

# The one knob surface this repo owns for the evaluator: .gitreins/config.yaml.
# The starved runs bound on the iteration cap while max_time and
# max_output_tokens stayed far from their rungs, so the scratch config keeps
# both of those GENEROUS and pins only max_iterations — the arm then proves
# WHICH rung actually bound, with numbers.
CONFIG_YAML = (
    "evaluator:\n"
    "  prescreen: false\n"
    "  static_analysis_diagnostics: false\n"
    "  max_iterations: 8\n"
    '  max_time: "30m"\n'
    '  max_output_tokens: "1m"\n'
)
CAP_USED = {"max_iterations": 8, "max_time": "30m", "max_output_tokens": "1m"}

GATE_LOG_NAME = "gate.log"
GATE_LOG_TALLY = "SELFTEST: PASS"
GATE_LOG_EXIT = "EXIT=0"

_GATE_LOG_CLEAN = """\
# p5g35 recorded gate log (fixture) — the committed-tree record a judge grades
# from instead of re-running the suite or polling for a live one.
PASS  cf261-missing-lib
PASS  board-evidence-check
PASS  selftest-section-census
PASS  bus-envelope-identity
WARN  cf099-drift-red (fixture arm, expected red)
{tally}
{exit}
"""

_GATE_LOG_TAMPERED = """\
# p5g35 recorded gate log (fixture, TAMPERED arm) — the tally line moved.
PASS  cf261-missing-lib
PASS  board-evidence-check
FAIL  selftest-section-census — census count drifted
FAIL  bus-envelope-identity
{tally}
{exit}
"""

CRITERION = (
    "PROOF: read the recorded gate log 'gate.log' exactly once — never poll it "
    "(no sleep/grep run_command against it, not even once) and never re-run "
    "tests/selftest.sh or rebuild any artifact. PASS only if the log's final "
    f"tally line is exactly '{GATE_LOG_TALLY}' and the exit line is "
    f"'{GATE_LOG_EXIT}'. FAILIF either line is missing or differs. Grade the "
    "recorded log only; no other instrument may answer this criterion."
)

# The literal cap line the row quotes: the text between "Cap exceeded: " and
# the trailing remedy sentence, whichever rung tripped ("Iteration cap (8)
# reached (8.8 used)" / "Time cap (1s) exceeded (1s elapsed)" / the token
# budget shapes). The starved arm's test asserts the ITERATION spelling.
_CAP_LINE_RE = re.compile(r"Cap exceeded: (.+?)(?:\. (?:Increase|Simplify))")


def make_config(config_root: str) -> None:
    cfg_dir = pathlib.Path(config_root) / ".gitreins"
    cfg_dir.mkdir(parents=True, exist_ok=True)
    (cfg_dir / "config.yaml").write_text(CONFIG_YAML, encoding="utf-8")


def make_fixture(workdir: str, tamper: bool = False) -> pathlib.Path:
    root = pathlib.Path(workdir)
    root.mkdir(parents=True, exist_ok=True)
    log = root / GATE_LOG_NAME
    template = _GATE_LOG_TAMPERED if tamper else _GATE_LOG_CLEAN
    tally = "SELFTEST: FAIL (2)" if tamper else GATE_LOG_TALLY
    log.write_text(template.format(tally=tally, exit=GATE_LOG_EXIT), encoding="utf-8")
    return log


class _BaseMockJudge:
    """Shared transcript plumbing for both scripted judges."""

    def __init__(self) -> None:
        self.turn = 0
        self.dedup_warnings_seen = 0
        self.graded_passed = False

    @staticmethod
    def _last_tool_result(messages: list[dict[str, Any]]) -> str:
        for msg in reversed(messages):
            if msg.get("role") == "tool":
                return str(msg.get("content", ""))
        return ""

    def _count_dedup(self, messages: list[dict[str, Any]]) -> None:
        # Only the LAST tool message: dedup warnings persist in the transcript,
        # so scanning the whole history each turn would count one warning O(n²).
        last = self._last_tool_result(messages)
        if "_dedup_warning" in last:
            self.dedup_warnings_seen += 1

    @staticmethod
    def _usage(messages: list[dict[str, Any]], completion_chars: int) -> LLMUsage:
        chars = sum(len(json.dumps(m, ensure_ascii=False)) for m in messages)
        return LLMUsage(
            prompt_tokens=int(chars / 3.5), completion_tokens=completion_chars // 4
        )

    @staticmethod
    def _call(tc_id: str, name: str, args: dict[str, Any]) -> LLMResponse:
        return LLMResponse(
            content=None,
            tool_calls=[ToolCall(id=tc_id, name=name, arguments=args)],
        )


class _ReadOnceJudge(_BaseMockJudge):
    """Scripted judge following the read-once PROOF recipe — 1 read, 0 polls.

    Adaptive on the negative-control arm: the status and the evidence-naming
    detail derive from the ACTUAL log content returned by read_file, so a
    tampered fixture grades FAIL with the differing line named, not a rubber
    stamp.
    """

    def chat(self, messages, tools=None, max_tokens=16384):  # noqa: ARG002
        self.turn += 1
        self._count_dedup(messages)
        step = self.turn
        last = self._last_tool_result(messages)
        if step == 1:
            return self._call("b1", "get_task_item", {"id": TASK_ID})
        if step == 2:
            return self._call("b2", "read_file", {"path": GATE_LOG_NAME})
        if step == 3:
            passed = GATE_LOG_TALLY in last and GATE_LOG_EXIT in last
            self.graded_passed = passed
            tally_line = GATE_LOG_TALLY if passed else "SELFTEST: FAIL (2)"
            evidence = (
                f"{'PASS' if passed else 'FAIL'} — recorded log '{GATE_LOG_NAME}' read "
                f"exactly once (1 read_file, 0 sleep/grep polls); final tally line "
                f"'{tally_line}' and exit line '{GATE_LOG_EXIT}' "
                f"{'present as required' if passed else 'present but the tally differs'}; "
                "tests/selftest.sh NOT re-run; no other instrument consulted."
            )
            return self._call(
                "b3",
                "sandbox_write",
                {"key": "verified_0", "content": evidence},
            )
        passed = getattr(self, "graded_passed", False)
        verdict = {
            "verdict": "COMPLETE" if passed else "INCOMPLETE",
            "summary": (
                "Read-once recipe: log read once, graded from its final tally and "
                "exit lines; 1 of 1 criteria graded, examined with named evidence."
            ),
            "items": [
                {
                    "criterion": CRITERION,
                    "status": "PASS" if passed else "FAIL",
                    "detail": (
                        "Evidence: gate.log read once — final tally line "
                        f"'{GATE_LOG_TALLY if passed else 'SELFTEST: FAIL (2)'}', exit "
                        f"line '{GATE_LOG_EXIT}'; no poll, no re-run."
                    ),
                }
            ],
        }
        text = json.dumps(verdict, ensure_ascii=False)
        return LLMResponse(content=text, usage=self._usage(messages, len(text)))


# Re-derivation polls with DISTINCT arguments every pass — the property that
# evades the engine's exact-repeat dedup hint (engine/evaluator.py::
# _execute_tool_with_dedup keys on the exact tool name + arguments). Every
# third turn repeats the EXACT first poll so the arm also measures that the
# dedup hint fires yet does NOT bound the loop.
_POLL_VARIANTS = (
    "sleep 0; grep -c 'PASS' " + GATE_LOG_NAME,
    "sleep 0 && grep -n 'PASS' " + GATE_LOG_NAME + " | tail -1",
    "sleep 0; grep -c 'EXIT' " + GATE_LOG_NAME,
    "sleep 0 && grep -n 'SELFTEST' " + GATE_LOG_NAME + " | tail -1",
)


class _PollLoopJudge(_BaseMockJudge):
    """Unconverging judge: sleeps/greps the log forever, never emits a verdict.

    This is the shape every starved real run took: the criterion never gets
    graded because the judge keeps re-deriving (here: polling) instead of
    concluding, and nothing in the loop bounds it before the cap.
    """

    def chat(self, messages, tools=None, max_tokens=16384):  # noqa: ARG002
        self.turn += 1
        self._count_dedup(messages)
        step = self.turn
        if step % 3 == 0:
            cmd = _POLL_VARIANTS[0]  # exact repeat — triggers the dedup hint
        else:
            cmd = _POLL_VARIANTS[step % len(_POLL_VARIANTS)]
        resp = self._call(
            f"s{step}",
            "run_command",
            {"cmd": cmd},
        )
        resp.usage = self._usage(messages, 20)
        return resp


def _tool_stats(ev: AgenticEvaluator) -> dict[str, int]:
    """Ground-truth poll/read/dedup counts from the evaluator's OWN tool record."""
    polls = reads = 0
    for line in ev._tool_record:
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            continue
        if rec.get("tool") == "run_command":
            cmd = str((rec.get("arguments") or {}).get("cmd", ""))
            if GATE_LOG_NAME in cmd and "grep" in cmd and "sleep" in cmd:
                polls += 1
        elif rec.get("tool") == "read_file":
            path = str((rec.get("arguments") or {}).get("path", ""))
            if GATE_LOG_NAME in path:
                reads += 1
    return {
        "poll_count": polls,
        "log_reads": reads,
        "dedup_warnings": ev.llm.dedup_warnings_seen,  # type: ignore[attr-defined]
    }


def _summarize(
    ev: AgenticEvaluator,
    verdict: Any,
    judge: _BaseMockJudge,
    elapsed_s: float,
) -> dict[str, Any]:
    cap = ev.eval_cap
    items = [
        {
            "status": i.status,
            "detail": i.detail[:200],
            "evidence_named": "Evidence:" in i.detail or "read" in i.detail.lower(),
        }
        for i in verdict.items
    ]
    graded = sum(1 for it in items if it["status"] in ("PASS", "FAIL"))
    unexamined = sum(1 for it in items if it["status"] == "UNVERIFIED")
    m = _CAP_LINE_RE.search(verdict.summary or "")
    max_seconds = cap.max_seconds if cap.max_seconds > 0 else float("inf")
    max_out = cap.max_output_tokens if cap.max_output_tokens > 0 else float("inf")
    stats = _tool_stats(ev)
    return {
        "task": TASK_ID,
        "criterion": CRITERION[:100] + "…",
        "verdict": verdict.verdict,
        "outcome": getattr(verdict, "outcome", ""),
        "summary": verdict.summary,
        "items": items,
        "criteria_graded": graded,
        "criteria_unexamined": unexamined,
        "cap_used": dict(CAP_USED),
        "cap_line": m.group(1) if m else "",
        "binding_rung": cap.trip_kind or "",
        "iterations_used": round(cap.iteration_credit, 1),
        "elapsed_s": round(elapsed_s, 2),
        "input_tokens_used_est": cap.cumulative_input_tokens,
        "output_tokens_used_est": cap.cumulative_output_tokens,
        "max_time_seconds": max_seconds if max_seconds != float("inf") else None,
        "time_not_binding": bool(
            elapsed_s < max_seconds if max_seconds != float("inf") else True
        ),
        "max_output_tokens": max_out if max_out != float("inf") else None,
        "output_not_binding": bool(
            cap.cumulative_output_tokens < max_out if max_out != float("inf") else True
        ),
        "llm_turns": judge.turn,
        **stats,
    }


def run_bounded_arm(
    workdir: str, config_root: str, tamper: bool = False
) -> dict[str, Any]:
    make_fixture(workdir, tamper=tamper)
    ev = AgenticEvaluator(
        _ReadOnceJudge(),  # type: ignore[arg-type]
        workdir=workdir,
        config_root=config_root,
        progress=None,
    )
    task = {
        "id": TASK_ID,
        "title": "P5G-35 probe — read-once bounded gate-log criterion",
        "criteria": [CRITERION],
    }
    start = time.monotonic()
    verdict = ev.evaluate(task)
    elapsed = time.monotonic() - start
    return _summarize(ev, verdict, ev.llm, elapsed)  # type: ignore[arg-type]


def run_starved_arm(workdir: str, config_root: str) -> dict[str, Any]:
    make_fixture(workdir)
    ev = AgenticEvaluator(
        _PollLoopJudge(),  # type: ignore[arg-type]
        workdir=workdir,
        config_root=config_root,
        progress=None,
    )
    task = {
        "id": TASK_ID,
        "title": "P5G-35 probe — unconverged poll-loop judge on the same criterion",
        "criteria": [CRITERION],
    }
    start = time.monotonic()
    verdict = ev.evaluate(task)
    elapsed = time.monotonic() - start
    return _summarize(ev, verdict, ev.llm, elapsed)  # type: ignore[arg-type]


def build_evidence(arms: dict[str, dict[str, Any]]) -> dict[str, Any]:
    head = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
        text=True,
    ).stdout.strip()
    return {
        "probe": "scripts/probe_p5g35_tier2_poll_bound.py",
        "engine": "gitreins 0.22.x (~/gitreins local build)",
        "measured_at": datetime.datetime.now(datetime.UTC).isoformat(),
        "head": head,
        "token_note": (
            "input/output token figures are transcript-derived estimates "
            "(chars/3.5, engine _estimate_context_tokens scale); not provider-billed "
            "numbers. Poll/read counts are measured from the evaluator's own "
            "_tool_record and the message transcript (_dedup_warning markers)."
        ),
        "arms": arms,
    }


def _save(path: pathlib.Path, evidence: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(evidence, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


def main() -> int:
    save = pathlib.Path(
        os.environ.get(
            "P5G35_EVIDENCE_SAVE",
            str(REPO_ROOT / "docs" / "audits" / "p5g35-tier2-evidence.json"),
        )
    )
    ok = True
    arms: dict[str, dict[str, Any]] = {}
    with tempfile.TemporaryDirectory(prefix="p5g35-bounded-") as tmp:
        cfg = os.path.join(tmp, "cfg")
        work = os.path.join(tmp, "work")
        make_config(cfg)
        arms["bounded"] = run_bounded_arm(work, cfg)
        b = arms["bounded"]
        print("P5G35_BOUNDED_RESULT " + json.dumps(b, ensure_ascii=False, indent=2))
        bounded_ok = (
            b["verdict"] == "COMPLETE"
            and b["criteria_graded"] == 1
            and b["criteria_unexamined"] == 0
            and b["items"][0]["status"] == "PASS"
            and b["log_reads"] == 1
            and b["poll_count"] == 0
            and b["iterations_used"] < CAP_USED["max_iterations"]
        )
        print("P5G35_BOUNDED_PASS" if bounded_ok else "P5G35_BOUNDED_FAIL")
        ok = ok and bounded_ok
    with tempfile.TemporaryDirectory(prefix="p5g35-starve-") as tmp:
        cfg = os.path.join(tmp, "cfg")
        work = os.path.join(tmp, "work")
        make_config(cfg)
        arms["starved"] = run_starved_arm(work, cfg)
        s = arms["starved"]
        print("P5G35_STARVED_RESULT " + json.dumps(s, ensure_ascii=False, indent=2))
        starved_ok = (
            s["verdict"] == "INCOMPLETE"
            and s["criteria_graded"] == 0
            and s["criteria_unexamined"] == 1
            and s["items"][0]["status"] == "UNVERIFIED"
            and s["cap_line"].startswith("Iteration cap (8) reached (")
            and s["binding_rung"] == "iterations"
            and s["time_not_binding"]
            and s["output_not_binding"]
            and s["poll_count"] >= 5
            and s["dedup_warnings"] >= 1
        )
        print("P5G35_STARVE_REPRODUCED" if starved_ok else "P5G35_STARVE_MISMATCH")
        ok = ok and starved_ok

    evidence = build_evidence(arms)
    _save(save, evidence)
    print(f"P5G35_EVIDENCE_WRITTEN {save}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
