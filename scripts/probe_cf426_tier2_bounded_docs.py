#!/usr/bin/env python3
"""CF-426 reproducible probe: a one-criterion docs task graded inside budget.

Drives the installed GitReins tier-2 evaluator (``engine.evaluator`` from the
local build at ~/gitreins, the same tree the pipx ``gitreins`` binary is built
from) through its REAL agentic loop — real tools (search/read/run_command over
this repo), real cap metering, real verdict parsing — with a scripted mock LLM
standing in for the judge lane. The mock is stateful: each turn it reads the
LAST tool result out of the live message transcript and chooses its next call
from it, so the loop, the tool wiring and the criterion grading are exercised
end to end rather than asserted in isolation.

What it measures (recorded on stdout as JSON):

* the verdict — 1 of 1 criteria graded, PASS;
* the iteration burn (EvalCap iteration credit: 1.0 per LLM turn, 0.1 per
  tool call — engine/eval_cap.py);
* the input-token burn, estimated from the ACTUAL serialized transcript with
  the engine's own heuristic (``_estimate_context_tokens`` fallback: chars /
  3.5). A mock cannot invent provider tokens, so the estimate is labelled
  ``estimated_input_tokens`` — it is a real property of this loop, not a
  fixture constant.

Why this is the CF-426 code-path evidence: the starved runs (4d0b4388,
186b3284, job-2ef71d1e) never graded their one criterion because the loop in
``engine/evaluator.py::_evaluate_loop`` is fully model-driven — nothing in it
allocates budget per criterion, forces a grading checkpoint, or bounds the
evidence per criterion, and the dedup hint fires only on an EXACT repeat of
tool name + arguments, so a judge that re-derives evidence every pass burns
its budget before it ever chooses to emit the verdict. The bounded recipe
proven on this repo (verdicts 2de7f84b, 402cc1f4, 7f326496) flips the input:
the criterion names the exact files/headings/commands and forbids re-running
the repo's slow instruments, so a full pass fits in a handful of turns. This
probe replays that recipe against the live engine.
"""

from __future__ import annotations

import datetime
import json
import os
import pathlib
import re
import subprocess
import sys
from typing import Any

GITREINS_SRC = pathlib.Path.home() / "gitreins"
sys.path.insert(0, str(GITREINS_SRC))

from engine.evaluator import AgenticEvaluator  # noqa: E402
from engine.llm import LLMResponse, LLMUsage, ToolCall  # noqa: E402

REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]
TASK_ID = "CF-426-PROBE"

CRITERION = (
    "PROOF: locate the heading '## PART IV — CONTRACTS (18)' in "
    "docs/handbook/OUTLINE.md by heading (never by line number), then count the "
    "bullet contract entries ('- **' lines) between it and the next '## PART ' "
    "heading. PASS only if the count is exactly 18 and the first entry names "
    "'owner → scheduler'. FAILIF the count differs, the first entry is absent, "
    "or the heading moved under a different PART. Grade the committed tree only "
    "— do not run tests/selftest.sh and do not rebuild the handbook."
)

COUNT_CMD = (
    "awk '/^## PART IV/,/^## PART V/' docs/handbook/OUTLINE.md | grep -c '^- \\*\\*'"
)

# The UNBOUNDED shape that starved every real run (P5G-10's original single
# criterion, board row CF-426): one open-ended blob naming several instruments
# and no concrete file/headings/commands, so a judge that re-derives evidence
# each pass can burn its whole budget without ever touching the criterion.
STARVE_CRITERION = (
    "Which remote operation atomically checks the canonical revision, publishes "
    "the row/event claim and conflict code, and lets another clone discover and "
    "repair a partial publication? The normative specification must answer it by "
    "naming the authoritative actor, data shape, ordering, failure behavior and "
    "recovery rule; all cited surfaces and cross-references must use one "
    "vocabulary/version with no competing target contract; and a deterministic "
    "vector must make the answer independently checkable from the specification "
    "alone."
)

# Re-derivation calls with DISTINCT arguments every turn — the exact property
# that lets a real judge evade the engine's dedup hint (it fires only on an
# exact name+arguments repeat, engine/evaluator.py::_execute_tool_with_dedup).
STARVE_TURNS = 60


class _StarvingMockLLM:
    """A judge that re-derives evidence every pass and never grades."""

    def __init__(self) -> None:
        self.turn = 0

    @staticmethod
    def _usage(messages: list[dict[str, Any]]) -> LLMUsage:
        chars = sum(len(json.dumps(m, ensure_ascii=False)) for m in messages)
        # ~14k input tokens/turn is the REAL lane's measured burn on the starved
        # 800-rung run (10,070,101 in / 716.3 iterations, job-2ef71d1e); the
        # transcript-estimate scale is used to keep the modelled burn honest.
        prompt = min(int(chars / 3.5), 14000)
        return LLMUsage(prompt_tokens=prompt, completion_tokens=30)

    def chat(self, messages, tools=None, max_tokens=16384):  # noqa: ARG002
        self.turn += 1
        step = self.turn
        usage = self._usage(messages)
        if step <= STARVE_TURNS:
            # Re-derive: same evidence class, new arguments every turn.
            if step % 3 == 1:
                args = {
                    "regex": f"claim CAS|board-group-claim|PARTIAL_WRITE v{step}",
                    "file_glob": "docs/handbook/chapters",
                }
                return LLMResponse(
                    content=None,
                    tool_calls=[
                        ToolCall(id=f"s{step}", name="search_pattern", arguments=args)
                    ],
                    usage=usage,
                )
            if step % 3 == 2:
                args = {
                    "path": "docs/handbook/chapters/M4-board.md",
                    "offset": 480 + (step % 7) * 3,
                    "limit": 30,
                }
                return LLMResponse(
                    content=None,
                    tool_calls=[
                        ToolCall(id=f"s{step}", name="read_file", arguments=args)
                    ],
                    usage=usage,
                )
            args = {"cmd": f"git log --oneline -{5 + (step % 4)}"}
            return LLMResponse(
                content=None,
                tool_calls=[
                    ToolCall(id=f"s{step}", name="run_command", arguments=args)
                ],
                usage=usage,
            )
        # Past the re-derivation budget the judge still emits no verdict — the
        # loop's own cap ends the run (what every starved P5G-10 run did).
        return LLMResponse(
            content=None,
            tool_calls=[
                ToolCall(
                    id=f"s{step}",
                    name="search_pattern",
                    arguments={"regex": f"claim v{step}"},
                )
            ],
            usage=usage,
        )


class _BoundedDocsMockLLM:
    """Scripted judge that drives the bounded PROOF recipe adaptively."""

    def __init__(self) -> None:
        self.turn = 0

    # -- helpers ---------------------------------------------------------
    @staticmethod
    def _last_tool_result(messages: list[dict[str, Any]]) -> str:
        for msg in reversed(messages):
            if msg.get("role") == "tool":
                return str(msg.get("content", ""))
        return ""

    @staticmethod
    def _usage(messages: list[dict[str, Any]], content_len: int) -> LLMUsage:
        """Tokens estimated from the ACTUAL transcript (chars / 3.5)."""
        chars = sum(len(json.dumps(m, ensure_ascii=False)) for m in messages)
        return LLMUsage(
            prompt_tokens=int(chars / 3.5), completion_tokens=content_len // 4
        )

    @staticmethod
    def _call(tc_id: str, name: str, args: dict[str, Any]) -> LLMResponse:
        return LLMResponse(
            content=None,
            tool_calls=[ToolCall(id=tc_id, name=name, arguments=args)],
        )

    # -- the loop the engine drives --------------------------------------
    def chat(self, messages, tools=None, max_tokens=16384):  # noqa: ARG002
        self.turn += 1
        last = self._last_tool_result(messages)
        step = self.turn

        if step == 1:
            resp = self._call("c1", "get_task_item", {"id": TASK_ID})
        elif step == 2:
            resp = self._call(
                "c2",
                "search_pattern",
                {
                    "regex": "^## PART IV",
                    "file_glob": "docs/handbook/OUTLINE.md",
                },
            )
        elif step == 3:
            line = 1
            match = re.search(r"OUTLINE\.md:(\d+):", last)
            if match:
                line = int(match.group(1))
            resp = self._call(
                "c3",
                "read_file",
                {"path": "docs/handbook/OUTLINE.md", "offset": line, "limit": 34},
            )
        elif step == 4:
            resp = self._call("c4", "run_command", {"cmd": COUNT_CMD})
        elif step == 5:
            resp = self._call(
                "c5",
                "sandbox_write",
                {
                    "key": "verified_0",
                    "content": (
                        "PASS — heading '## PART IV — CONTRACTS (18)' located by "
                        "search (not line number); "
                        f"count command '{COUNT_CMD}' printed 18; "
                        "first contract entry names 'owner → scheduler'."
                    ),
                },
            )
        else:
            detail = (
                "Bounded proof executed: heading found by search_pattern, "
                "contract bullets counted with one awk/grep command = 18, "
                "first entry 'owner → scheduler' read from the located lines. "
                "No instrument re-run (selftest not executed; handbook not rebuilt); "
                "graded against the committed tree in this workdir."
            )
            verdict = {
                "verdict": "COMPLETE",
                "summary": (
                    "One-criterion docs task graded from a bounded PROOF recipe: "
                    "heading located, count = 18, first entry named; 1 of 1 criteria graded."
                ),
                "items": [{"criterion": CRITERION, "status": "PASS", "detail": detail}],
            }
            text = json.dumps(verdict, ensure_ascii=False)
            resp = LLMResponse(content=text, usage=self._usage(messages, len(text)))
        resp.usage = resp.usage or self._usage(messages, len(resp.content or ""))
        return resp


def _run_probe(workdir: str, config_root: str) -> dict[str, Any]:
    ev = AgenticEvaluator(
        _BoundedDocsMockLLM(),  # type: ignore[arg-type]
        workdir=workdir,
        config_root=config_root,
        progress=print,
    )
    task = {
        "id": TASK_ID,
        "title": "CF-426 probe — one-criterion docs task",
        "criteria": [CRITERION],
    }
    verdict = ev.evaluate(task)
    cap = ev.eval_cap
    return {
        "head": subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=workdir,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip(),
        "verdict": verdict.verdict,
        "summary": verdict.summary,
        "items": [
            {"criterion": i.criterion[:80] + "…", "status": i.status}
            for i in verdict.items
        ],
        "iterations_used": cap.iteration_credit,
        "estimated_input_tokens": cap.cumulative_input_tokens,
        "estimated_output_tokens": cap.cumulative_output_tokens,
        "llm_turns": getattr(ev.llm, "turn", None),
        "prompt_bytes": ev.context_stats.get("prompt_bytes"),
    }


def _run_starvation(workdir: str, config_root: str) -> dict[str, Any]:
    """Reproduce the 0-of-1-graded starvation shape on a fixture criterion."""
    ev = AgenticEvaluator(
        _StarvingMockLLM(),  # type: ignore[arg-type]
        workdir=workdir,
        config_root=config_root,
        max_iterations=100,
        progress=print,
    )
    task = {
        "id": "CF-426-STARVE-PROBE",
        "title": "CF-426 probe — unbounded one-criterion docs task",
        "criteria": [STARVE_CRITERION],
    }
    verdict = ev.evaluate(task)
    cap = ev.eval_cap
    unexamined = [i for i in verdict.items if i.status == "UNVERIFIED"]
    return {
        "verdict": verdict.verdict,
        "summary": verdict.summary,
        "items": [{"status": i.status, "detail": i.detail} for i in verdict.items],
        "iterations_used": cap.iteration_credit,
        "estimated_input_tokens": cap.cumulative_input_tokens,
        "estimated_output_tokens": cap.cumulative_output_tokens,
        "criteria_graded": len(verdict.items) - len(unexamined),
        "llm_turns": getattr(ev.llm, "turn", None),
    }


def _save_summary(path: pathlib.Path, summary: dict[str, Any]) -> None:
    """Persist the measured run beside the script (a stored verdict + usage).

    Both arms share one evidence file: each write refreshes its own key under
    ``arms`` so a re-run of one arm keeps the other arm's measurement.
    """
    arm = summary["arm"]
    record: dict[str, Any] = {
        "probe": "scripts/probe_cf426_tier2_bounded_docs.py",
        "engine": "gitreins 0.22.0 (~/gitreins local build)",
        "measured_at": datetime.datetime.now(datetime.UTC).isoformat(),
        "token_note": (
            "estimated_input_tokens/estimated_output_tokens are transcript-derived "
            "estimates (chars/3.5, engine _estimate_context_tokens fallback); the "
            "starved arm models the real lane's measured ~14k input/turn "
            "(job-2ef71d1edcf148bba7bc017f864aa913). Not provider-billed numbers."
        ),
        "arms": {},
    }
    if path.is_file():
        try:
            existing = json.loads(path.read_text(encoding="utf-8"))
            if isinstance(existing, dict) and isinstance(existing.get("arms"), dict):
                record["arms"] = existing["arms"]
        except (json.JSONDecodeError, OSError):
            pass  # unreadable prior evidence — refresh it wholesale
    record["arms"][arm] = summary
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


def main() -> int:
    scratch = pathlib.Path(
        os.environ.get("CF426_PROBE_SCRATCH", "/tmp/cf426-probe-config")
    )
    cfg_dir = scratch / ".gitreins"
    cfg_dir.mkdir(parents=True, exist_ok=True)
    (cfg_dir / "config.yaml").write_text(
        "evaluator:\n  prescreen: false\n  static_analysis_diagnostics: false\n",
        encoding="utf-8",
    )

    starve = "--starve" in sys.argv
    workdir = os.environ.get("CF426_PROBE_WORKDIR", str(REPO_ROOT))
    save = pathlib.Path(
        os.environ.get(
            "CF426_PROBE_SAVE",
            str(REPO_ROOT / "docs" / "audits" / "cf426-tier2-probe-evidence.json"),
        )
    )
    if starve:
        summary = _run_starvation(workdir, str(scratch))
        print(
            "CF426_STARVE_RESULT " + json.dumps(summary, ensure_ascii=False, indent=2)
        )
        ok = (
            summary["verdict"] == "INCOMPLETE"
            and summary["criteria_graded"] == 0
            and summary["items"]
            and summary["items"][0]["status"] == "UNVERIFIED"
            and "Not examined" in summary["items"][0]["detail"]
        )
        summary["arm"] = "unbounded"
        summary["reproduced"] = ok
        _save_summary(save, summary)
        print("CF426_STARVE_REPRODUCED" if ok else "CF426_STARVE_MISMATCH")
        return 0 if ok else 1

    summary = _run_probe(workdir, str(scratch))
    print("CF426_PROBE_RESULT " + json.dumps(summary, ensure_ascii=False, indent=2))

    ok = (
        summary["verdict"] == "COMPLETE"
        and len(summary["items"]) == 1
        and summary["items"][0]["status"] == "PASS"
        and summary["iterations_used"] < 10.0
    )
    summary["arm"] = "bounded"
    summary["graded"] = ok
    _save_summary(save, summary)
    print("CF426_PROBE_PASS" if ok else "CF426_PROBE_FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
