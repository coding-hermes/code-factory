#!/usr/bin/env python3
"""master_doc_panel.py — the review the checker cannot do.

The checker proves a document is *shaped* right: eight sections, every locator resolves, VERIFIED is
earned. It cannot tell whether a section says the TRUE thing about the component — that is judgement,
and the operator's method calls for a panel, not a gate.

Each seat gets the same brief and the same module list, answers independently, and the script reports
WHERE THEY AGREE and WHERE THEY SPLIT. A split is the most valuable output: it marks a section that
needs a human or a measurement, not a vote.

  python3 scripts/master_doc_panel.py --modules 03,04,05
  python3 scripts/master_doc_panel.py --modules 03 --seats sol,k3,flash --timeout 900

Seats default to three different families, all inside this project's lane policy (xkiro + DeepSeek
PAYG): gpt-6.1-sol, kimi-k3-agent, deepseek-v4-flash.
"""
import argparse
import json
import pathlib
import re
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

REPO = pathlib.Path(__file__).resolve().parent.parent

SEATS = {
    "sol": ("xkiro", "openai/gpt-6.1-sol"),
    "k3": ("xkiro", "moonshotai/kimi-k3-agent"),
    "flash": ("deepseek", "deepseek-v4-flash"),
}

BRIEF = """You are one seat on a review panel for the code-factory operations master document. Three
seats review independently; nobody sees the others. Grade the documents, do not rewrite them.

MODULES UNDER REVIEW (read each one):
{modules}

THE CONTRACT each module claims to satisfy — eight sections, in this order:
1 Purpose and why it matters · 2 Dependencies and library contracts · 3 Verification · 4 Metrics
emitted · 5 Log lines it can generate · 6 Failure modes · 7 Environment and settings it reads ·
8 Evidence of record

WHAT MAKES A SECTION WRONG, and what you are looking for:
* UNSOURCED — a factual claim with no locator, or a locator that does not support the sentence.
* WRONG — the source says something different from the document (name, default, direction of failure,
  exit code, both sides of a contract).
* THIN — the section is present but says nothing an operator could act on (e.g. "various errors may
  occur").
* INVENTED — a default, timeout, peer or exception class that the source does not contain.

You have tools. Open the source files the locators name. Run a command when a claim about behaviour
can be settled by running it. Do not take the document's word for anything, and do not take this
brief's word either.

OUTPUT — end your reply with exactly one JSON object, nothing after it:
{{"modules": [{{"file": "<module filename>", "sections": [{{"n": 1, "verdict": "OK|UNSOURCED|WRONG|THIN|INVENTED", "why": "<=20 words", "evidence": "path:LINE"}}], "verdict": "PASS|FAIL", "worst": "<=20 words"}}], "seat_note": "<=30 words"}}

A module's verdict is FAIL if any section is WRONG or INVENTED, or two or more are UNSOURCED/THIN.
Be specific enough that a fixer can act on your line without asking you a question.
"""


def module_paths(names):
    out = []
    for n in names:
        hits = sorted((REPO / "docs/master").glob("%s-*.md" % n.strip()))
        out.extend(hits)
    return out


def run_seat(seat, modules, timeout):
    provider, model = SEATS[seat]
    brief = BRIEF.format(modules="\n".join(str(m) for m in modules))
    with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False) as fh:
        fh.write(brief)
        path = fh.name
    try:
        r = subprocess.run(
            ["hermes", "chat", "-q", brief, "-m", model, "--provider", provider,
             "-Q", "--max-turns", "40"],
            capture_output=True, text=True, timeout=timeout, cwd=str(REPO),
        )
    except subprocess.TimeoutExpired:
        return seat, None, "timed out after %ds" % timeout
    finally:
        pathlib.Path(path).unlink(missing_ok=True)
    text = (r.stdout or "") + "\n" + (r.stderr or "")
    if r.returncode != 0 and not text.strip():
        return seat, None, "exit %d, no output" % r.returncode
    m = None
    for cand in re.finditer(r"\{.*\}", text, re.S):
        try:
            obj = json.loads(cand.group(0))
        except json.JSONDecodeError:
            continue
        if "modules" in obj:
            m = obj
    if m is None:
        return seat, None, "no JSON verdict in the reply (%d chars)" % len(text)
    return seat, m, "ok"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--modules", required=True, help="comma-separated module prefixes, e.g. 03,04,05")
    ap.add_argument("--seats", default="sol,k3,flash")
    ap.add_argument("--timeout", type=int, default=1200)
    ap.add_argument("--out", default="docs/master/_panel")
    a = ap.parse_args()

    modules = module_paths(a.modules.split(","))
    if not modules:
        print("no modules matched %s" % a.modules)
        return 2
    seats = [s.strip() for s in a.seats.split(",") if s.strip()]
    print("panel: %d module(s), %d seat(s): %s" % (len(modules), len(seats), ", ".join(seats)))

    results = {}
    with ThreadPoolExecutor(max_workers=len(seats)) as ex:
        for seat, obj, note in ex.map(lambda s: run_seat(s, modules, a.timeout), seats):
            results[seat] = {"verdict": obj, "note": note}
            print("  %-6s %s" % (seat, note if obj is None else "replied"))

    # agreement: per module, per section, the set of verdicts the seats returned
    tally = {}
    for seat, r in results.items():
        if not r["verdict"]:
            continue
        for mod in r["verdict"].get("modules", []):
            key = mod.get("file", "?")
            tally.setdefault(key, {"module_verdicts": {}, "sections": {}})
            tally[key]["module_verdicts"][seat] = mod.get("verdict", "?")
            for s in mod.get("sections", []):
                tally[key]["sections"].setdefault(str(s.get("n")), {})[seat] = (
                    s.get("verdict", "?"), s.get("why", ""), s.get("evidence", ""))

    outdir = REPO / a.out
    outdir.mkdir(parents=True, exist_ok=True)
    stamp = "_".join(m.stem.split("-")[0] for m in modules)
    jpath = outdir / ("%s.json" % stamp)
    jpath.write_text(json.dumps({"modules": [str(m) for m in modules], "seats": results,
                                 "tally": tally}, indent=2), encoding="utf-8")

    print("\n%-46s %s" % ("module", "seat verdicts"))
    disputed = 0
    for key, t in sorted(tally.items()):
        vs = t["module_verdicts"]
        vals = sorted(set(vs.values()))
        print("%-46s %s%s" % (key, ", ".join("%s=%s" % kv for kv in sorted(vs.items())),
                              "   <-- SPLIT" if len(vals) > 1 else ""))
        for n, per_seat in sorted(t["sections"].items()):
            bad = [s for s, (v, _, _) in per_seat.items() if v not in ("OK",)]
            if bad:
                disputed += 1
                for s in bad:
                    v, why, ev = per_seat[s]
                    print("    §%-2s %-6s %-10s %s  [%s]" % (n, s, v, why[:70], ev))

    seat_fail = [s for s, r in results.items() if not r["verdict"]]
    print("\n%d section finding(s); %d seat(s) answered; json: %s"
          % (disputed, len(results) - len(seat_fail), jpath))
    if seat_fail:
        print("SEATS WITH NO VERDICT: %s" % ", ".join(seat_fail))
    print("PANEL: %s" % ("INCOMPLETE" if seat_fail else ("FINDINGS" if disputed else "CLEAN")))
    return 1 if (seat_fail or disputed) else 0


if __name__ == "__main__":
    sys.exit(main())
