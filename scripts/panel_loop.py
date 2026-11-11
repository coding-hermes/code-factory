#!/usr/bin/env python3
"""panel_loop.py — one writer, five judges, repeat until the handbook stops losing.

Writer: Hermes agent on DeepSeek, executing against docs/handbook/OUTLINE.md.
Judges: five families fanned out staggered (same harness as the outline quorum).

Usage:
  panel_loop.py --rounds 6 --max-seconds 21000 [--start-round 1] [--chapters III.1,III.2]

State lives in docs/handbook/_panel/. Every round writes:
  round-N/writer.txt          writer session transcript tail
  round-N/CORRECTIONS.md      merged, deduped, ranked corrections
  round-N/seat-*.txt          judge verdicts
  STATE.json                  round, status, verdicts, blockers

The loop stops on the first of: unanimous PASS, no new defect class for two
consecutive rounds, or the round cap. It never claims success it did not observe.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(os.environ.get("PANEL_ROOT", "~/code-factory"))
HB = ROOT / "docs" / "handbook"
PANEL = HB / "_panel"
CH = HB / "chapters"
FANOUT = Path("~/.hermes/cache/scratch/cf-quorum-20261104/quorum_fanout_staggered.sh")
MANIFEST = Path("~/.hermes/cache/scratch/cf-quorum-20261104/seats.manifest")

WRITER_MODEL = os.environ.get("PANEL_WRITER_MODEL", "deepseek-v4-pro")
WRITER_PROVIDER = os.environ.get("PANEL_WRITER_PROVIDER", "deepseek")

KINDS = (
    "FALSE CLAIM",
    "OMISSION",
    "CONTRADICTION",
    "UNBUILDABLE",
    "UNVERIFIED",
    "PADDING",
)


def now() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")


def state_path() -> Path:
    return PANEL / "STATE.json"


def load_state() -> dict:
    p = state_path()
    if p.exists():
        return json.loads(p.read_text())
    return {
        "round": 0,
        "status": "idle",
        "history": [],
        "classes_seen": [],
        "clean_streak": 0,
    }


def save_state(st: dict) -> None:
    PANEL.mkdir(parents=True, exist_ok=True)
    state_path().write_text(json.dumps(st, indent=2) + "\n")


def unfinished_chapters() -> list[str]:
    """Chapters still to write, derived from the outline's module list."""
    outline = (HB / "OUTLINE.md").read_text()
    ids = sorted(set(re.findall(r"\bIII\.\d+(?:\.\d+)?\b", outline)))
    missing = []
    for cid in ids:
        hits = (
            list((HB / "chapters").glob(f"{cid}*.md"))
            if (HB / "chapters").exists()
            else []
        )
        if not hits:
            missing.append(cid)
    return missing


def writer_prompt(rnd: int, chapters: list[str] | None) -> str:
    corr = PANEL / f"round-{rnd - 1}" / "CORRECTIONS.md"
    target = (
        "Apply every correction in %s to docs/handbook/chapters/. " % corr
        if corr.exists()
        else "Write the chapters named below against docs/handbook/OUTLINE.md. "
    )
    scope = "This round covers ONLY: " + ", ".join(chapters) + ". " if chapters else ""
    return (
        "You are the writer for the code-factory NASA-style specification handbook. "
        "Read docs/handbook/PANEL-LOOP.md and docs/handbook/OUTLINE.md first, then "
        "docs/MASTER-DOC-SCHEMA.md for the field contract. "
        + target
        + scope
        + "Rules that are not negotiable: every claim carries a file:line or a command you "
        "actually ran; a chapter that stays RED is a valid outcome and a better one than a "
        "green chapter without evidence; never adopt the document over the code — if they "
        "disagree the code wins and the disagreement is a finding you file in this round. "
        "Write to docs/handbook/chapters/<chapter-id>-<slug>.md. "
        "ALIGNMENT IS CHECKED, NOT REMEMBERED: section 6 of every chapter must cite the "
        "CANONICAL contract ids CT-01..CT-18 from OUTLINE Part IV, not local ids like "
        "M2-C1 — two chapters describing the same interface from opposite ends must carry "
        "the same CT id or nothing can verify they agree. "
        "Before you finish, run `python3 scripts/handbook_spine.py` and drive its finding "
        "count to zero; paste the summary line into your manifest. "
        "End by printing a manifest: chapters written, chapters still skeleton, RED field "
        "count per chapter, and every command you ran with its exit status. "
        "Print WRITER ROUND COMPLETE when done. Round %d." % rnd
    )


def run_writer(
    rnd: int,
    chapters: list[str] | None,
    timeout_s: int,
    tag: str = "",
    prompt: str | None = None,
) -> tuple[bool, Path]:
    outdir = PANEL / f"round-{rnd}"
    outdir.mkdir(parents=True, exist_ok=True)
    log = outdir / (f"writer-{tag}.txt" if tag else "writer.txt")
    cmd = [
        "timeout",
        str(timeout_s),
        "hermes",
        "chat",
        "-q",
        prompt or writer_prompt(rnd, chapters),
        "-m",
        WRITER_MODEL,
        "--provider",
        WRITER_PROVIDER,
        "-Q",
        "--ignore-rules",
        "--max-turns",
        "200",
    ]
    with log.open("w") as fh:
        # The call's status is never read — completion is judged from the log text below — so it is
        # dropped rather than left to red the tracked python surface that selftest.sh §51 grades.
        subprocess.call(cmd, stdout=fh, stderr=subprocess.STDOUT, cwd=str(ROOT))
    ok = "WRITER ROUND COMPLETE" in log.read_text(errors="replace")
    return ok, log


def run_writers_parallel(
    rnd: int, groups: list[list[str]], timeout_s: int
) -> tuple[bool, list[Path]]:
    """Run one writer per section group, concurrently.

    Serial single-section edits lose: a fix in M9 invalidates what M2 says about the
    same contract, and the next round corrects M2 while breaking M9 again. Section
    groups written in the SAME round, against the same spine, converge instead of
    chasing each other. They are separate files, so there is no write conflict —
    the only conflict is semantic, and handbook_spine.py plus the reconcile pass
    are what catch it.
    """
    outdir = PANEL / f"round-{rnd}"
    outdir.mkdir(parents=True, exist_ok=True)
    procs = []
    for i, group in enumerate(groups, 1):
        tag = f"s{i}"
        log = outdir / f"writer-{tag}.txt"
        prompt = writer_prompt(rnd, group) + (
            f" You own ONLY these sections this round: {', '.join(group)}. "
            "Do not edit chapters outside your group — another writer owns them in the "
            "same round. If your section's correctness depends on a chapter you do not own, "
            "record it in your manifest as CROSS-SECTION DEPENDENCY with the exact claim the "
            "other chapter must satisfy, and write yours to match the canonical contract id."
        )
        cmd = [
            "timeout",
            str(timeout_s),
            "hermes",
            "chat",
            "-q",
            prompt,
            "-m",
            WRITER_MODEL,
            "--provider",
            WRITER_PROVIDER,
            "-Q",
            "--ignore-rules",
            "--max-turns",
            "200",
        ]
        fh = log.open("w")
        procs.append(
            (
                tag,
                log,
                fh,
                subprocess.Popen(
                    cmd, stdout=fh, stderr=subprocess.STDOUT, cwd=str(ROOT)
                ),
            )
        )
    results = []
    for tag, log, fh, p in procs:
        p.wait()
        fh.close()
        results.append(log)
    ok = all("WRITER ROUND COMPLETE" in p.read_text(errors="replace") for p in results)
    return ok, results


def judge_brief(rnd: int, chapters: list[str] | None) -> Path:
    outdir = PANEL / f"round-{rnd}"
    outdir.mkdir(parents=True, exist_ok=True)
    brief = outdir / "brief.md"
    scope = (
        ("Judge only these chapters: " + ", ".join(chapters) + ". ") if chapters else ""
    )
    brief.write_text(f"""# PANEL BRIEF — handbook round {rnd}

You are a judge. Judge the DOCUMENT AGAINST THE CODE. Never against the outline's own
language, never against what a previous seat said.

{scope}
Read:
- `docs/handbook/OUTLINE.md` — the structure the document must satisfy
- `docs/handbook/chapters/` — the chapters written so far
- `docs/MASTER-DOC-SCHEMA.md` — the field contract per chapter
- the code the chapters describe: `~/code-factory`,
  `~/coding-hermes-scheduler/coding-herms-scheduler`, `~/crier`,
  `~/crier-fleet`, `~/.hermes/scripts/cf-inference-proxy.py`

Check every chapter against the four rules that make a claim admissible:

1. **Evidence-or-RED** — does each claim carry a `file:line` or a command whose output is
   quoted? A claim without one is `UNVERIFIED` and blocks.
2. **Both sides** — does each contract name producer AND consumer as `file:function`?
   One side is a rumour.
3. **Consequence** — does each setting carry default, range and what breaks if changed?
   A name with no consequence is `NAME ONLY` and counts as unwritten.
4. **Repeatable** — if you cannot repeat the verification command yourself, say so.

Also run `python3 scripts/handbook_spine.py` and treat every finding it reports as a
blocking finding of kind CONTRADICTION: an unregistered canonical contract id, a setting
documented twice with different defaults, a dangling reference, or a count claim that
disagrees with what the chapters actually contain.

Also hunt: a claim contradicted by the code (`FALSE CLAIM`), a chapter that omits what the
code plainly does (`OMISSION`), two chapters that disagree (`CONTRADICTION`), a chapter no
writer could turn into work (`UNBUILDABLE`), prose that says nothing a reader can act on
(`PADDING`).

## Output format

```
VERDICT: PASS | FAIL
BLOCKING: <n> — findings that must be fixed before this chapter can be called written
NON-BLOCKING: <n>
FINDINGS: for each — kind (FALSE CLAIM|OMISSION|CONTRADICTION|UNBUILDABLE|UNVERIFIED|PADDING),
  chapter id, the claim quoted, the evidence (file:line or measured value), the fix
DEFECT CLASSES: the classes of defect you saw, as short labels
CHAPTER SCORECARD: per chapter id — WRITTEN | PARTIAL | SKELETON, with the reason
```

Be exact and be harsh: the owner has rejected one version of this document already. A
lenient round costs a whole loop iteration. End with PANEL REVIEW COMPLETE.
""")
    return brief


def run_panel(rnd: int, brief: Path, timeout_s: int) -> dict[str, Path]:
    outdir = PANEL / f"round-{rnd}" / "seats"
    outdir.mkdir(parents=True, exist_ok=True)
    subprocess.call(
        [
            "bash",
            str(FANOUT),
            str(brief),
            str(outdir),
            str(MANIFEST),
            str(timeout_s),
            "90",
        ],
        cwd="/home/kara",
    )
    return {p.stem.replace("seat-", ""): p for p in sorted(outdir.glob("seat-*.txt"))}


def rerun_missing(rnd: int, brief: Path, timeout_s: int, missing: list[str]) -> None:
    """Re-run only the families that failed to return.

    PANEL-LOOP.md says a round where a seat did not return does not count. Honouring
    that means re-running that family alone rather than letting a missing seat pass
    silently into the tally — round 6 lost kimi and the round still "completed".
    """
    if not missing:
        return
    lines = [
        ln
        for ln in MANIFEST.read_text().splitlines()
        if ln.strip()
        and not ln.strip().startswith("#")
        and ln.split("|")[0].strip() in missing
    ]
    if not lines:
        return
    sub = PANEL / f"round-{rnd}" / "seats" / "_rerun.manifest"
    sub.parent.mkdir(parents=True, exist_ok=True)
    sub.write_text("\n".join(lines) + "\n")
    print(f"  re-running missing seats: {', '.join(missing)}", flush=True)
    subprocess.call(
        [
            "bash",
            str(FANOUT),
            str(brief),
            str(PANEL / f"round-{rnd}" / "seats"),
            str(sub),
            str(timeout_s),
            "90",
        ],
        cwd="/home/kara",
    )


def parse_seat(p: Path) -> dict:
    text = p.read_text(errors="replace")
    verdict = "MISSING"
    m = re.search(r"^VERDICT:\s*(.+)$", text, re.M)
    if m:
        v = m.group(1).strip().upper()
        verdict = (
            "PASS"
            if v.startswith("PASS")
            else ("FAIL" if v.startswith("FAIL") else v[:20])
        )
    blocking = 0
    m = re.search(r"^BLOCKING:\s*(\d+)", text, re.M)
    if m:
        blocking = int(m.group(1))
    else:
        # fall back to counting findings lines with a claimed kind
        blocking = sum(
            1 for line in text.splitlines() if any(k in line.upper() for k in KINDS)
        )
    classes = []
    m = re.search(r"^DEFECT CLASSES:(.*?)(?=^[A-Z][A-Z ]+:|\Z)", text, re.S | re.M)
    if m:
        for chunk in re.split(r"[,;\n]", m.group(1)):
            c = chunk.strip(" -*•\t")
            # A defect class is prose: at least two words, no digits, parens or
            # file references. The earlier filter admitted fragments like ":19-42"
            # and "78 lines)", which made every round look like it produced new
            # classes and disabled the second stop condition entirely.
            if not (3 < len(c) < 60):
                continue
            if any(ch.isdigit() for ch in c) or any(ch in c for ch in "():/"):
                continue
            if len(c.split()) < 2:
                continue
            classes.append(c.lower())
    return {
        "seat": p.stem.replace("seat-", ""),
        "verdict": verdict,
        "blocking": blocking,
        "classes": classes,
        "bytes": p.stat().st_size,
        "complete": "PANEL REVIEW COMPLETE" in text,
    }


def merge_corrections(rnd: int, seats: dict[str, dict], paths: dict[str, Path]) -> Path:
    outdir = PANEL / f"round-{rnd}"
    lines = [f"# CORRECTIONS — round {rnd}\n", f"Generated {now()}.\n", "## Verdicts\n"]
    for tag, s in seats.items():
        lines.append(
            f"- **{tag}** — {s['verdict']}, blocking {s['blocking']}, "
            f"{s['bytes']} bytes, complete={s['complete']}"
        )
    lines.append("\n## Verdict text (verbatim, per seat)\n")
    for tag, p in paths.items():
        txt = p.read_text(errors="replace")
        lines.append(f"### {tag}\n\n```\n{txt.strip()}\n```\n")
    out = outdir / "CORRECTIONS.md"
    out.write_text("\n".join(lines) + "\n")
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--rounds", type=int, default=6)
    ap.add_argument("--max-seconds", type=int, default=21000)
    ap.add_argument("--start-round", type=int, default=None)
    ap.add_argument("--writer-timeout", type=int, default=4200)
    ap.add_argument("--judge-timeout", type=int, default=2700)
    ap.add_argument("--chapters", default="")
    ap.add_argument(
        "--groups",
        default="",
        help="explicit section groups, e.g. 'M0,M1;M4,M5' — overrides --parallel",
    )
    ap.add_argument(
        "--parallel",
        type=int,
        default=1,
        help="writers per round, one per section group (0/1 = single writer)",
    )
    args = ap.parse_args()

    chapters = [c.strip() for c in args.chapters.split(",") if c.strip()] or None
    st = load_state()
    # rounds=0 and max-seconds=0 mean NO CAP: the loop runs until a real stop
    # condition fires (unanimous PASS, or two consecutive rounds with no new
    # defect class). A cap is a budget for a session, not a definition of done.
    rounds = args.rounds if args.rounds > 0 else 10**9
    budget = args.max_seconds if args.max_seconds > 0 else 10**9
    rnd = args.start_round or (st["round"] + 1)
    t0 = time.time()
    PANEL.mkdir(parents=True, exist_ok=True)

    print(
        f"panel loop: start round {rnd}, cap {rounds if rounds < 10**8 else 'none'} rounds / "
        f"{budget if budget < 10**8 else 'none'}s"
    )
    print(f"writer: {WRITER_MODEL} @ {WRITER_PROVIDER}")
    st["status"] = "running"

    while st["round"] < rounds and (time.time() - t0) < budget:
        rnd = st["round"] + 1
        st["round"] = rnd
        save_state(st)

        print(f"\n=== ROUND {rnd} — writer ===", flush=True)
        if args.groups or args.parallel > 1:
            all_ch = chapters or sorted(p.stem for p in CH.glob("M*.md"))
            if not all_ch:
                print("no chapters to write — aborting round", flush=True)
                break
            if args.groups:
                groups = [
                    [c.strip() for c in g.split(",") if c.strip()]
                    for g in args.groups.split(";")
                    if g.strip()
                ]
            else:
                groups = [all_ch[i :: args.parallel] for i in range(args.parallel)]
            print(
                f"parallel writers: {len(groups)} groups — "
                + " | ".join(
                    f"s{i + 1}={len(g)}({g[0]}..{g[-1]})" for i, g in enumerate(groups)
                ),
                flush=True,
            )
            ok, logs = run_writers_parallel(rnd, groups, args.writer_timeout)
            print(f"writers complete_all={ok} logs={len(logs)}", flush=True)
        else:
            ok, log = run_writer(rnd, chapters, args.writer_timeout)
            print(f"writer complete={ok} log={log}", flush=True)
        if not ok:
            st["history"].append(
                {"round": rnd, "status": "writer-incomplete", "at": now()}
            )
            save_state(st)
            print(
                "a writer did not print ROUND COMPLETE — round does not count",
                flush=True,
            )
            continue

        # Reconcile: concurrent writers cannot see each other's edits this round, so the
        # seams between their sections are checked before anyone judges them.
        if args.parallel > 1:
            spine = subprocess.run(
                [sys.executable, str(ROOT / "scripts" / "handbook_spine.py")],
                capture_output=True,
                text=True,
                cwd=str(ROOT),
            )
            summary = (spine.stdout or "").splitlines()
            head = " / ".join(summary[:2])
            print(f"spine after parallel write: {head}", flush=True)
            if spine.returncode != 0:
                print(
                    "=== RECONCILE PASS — spine findings between concurrent sections ===",
                    flush=True,
                )
                rec = (
                    "You are the reconciler for the code-factory handbook. Concurrent writers "
                    "just edited different chapter groups in docs/handbook/chapters/ and could "
                    "not see each other's work. `python3 scripts/handbook_spine.py` reports "
                    "contradictions between their sections. Fix ONLY the cross-section "
                    "inconsistencies it reports — do not rewrite prose, do not change a claim "
                    "that is not named in a finding. Where two chapters disagree, determine the "
                    "truth from the code and correct the wrong side, citing file:line. Re-run the "
                    "spine until it reports zero findings, then print your summary and "
                    "RECONCILE COMPLETE."
                )
                subprocess.call(
                    [
                        "timeout",
                        str(args.writer_timeout),
                        "hermes",
                        "chat",
                        "-q",
                        rec,
                        "-m",
                        WRITER_MODEL,
                        "--provider",
                        WRITER_PROVIDER,
                        "-Q",
                        "--ignore-rules",
                        "--max-turns",
                        "120",
                    ],
                    stdout=(PANEL / f"round-{rnd}" / "reconcile.txt").open("w"),
                    stderr=subprocess.STDOUT,
                    cwd=str(ROOT),
                )
                spine = subprocess.run(
                    [sys.executable, str(ROOT / "scripts" / "handbook_spine.py")],
                    capture_output=True,
                    text=True,
                    cwd=str(ROOT),
                )
                print(
                    "spine after reconcile: "
                    + " / ".join((spine.stdout or "").splitlines()[:2]),
                    flush=True,
                )

        print(f"=== ROUND {rnd} — panel ===", flush=True)
        brief = judge_brief(rnd, chapters)
        paths = run_panel(rnd, brief, args.judge_timeout)
        seats = {tag: parse_seat(p) for tag, p in paths.items()}
        broken = [
            t
            for t, s in seats.items()
            if not s["complete"] or s["verdict"] == "MISSING"
        ]
        if broken:
            rerun_missing(rnd, brief, args.judge_timeout, broken)
            seats = {tag: parse_seat(p) for tag, p in paths.items()}
        for tag, s in seats.items():
            print(
                f"  {tag}: {s['verdict']} blocking={s['blocking']} complete={s['complete']}",
                flush=True,
            )

        corr = merge_corrections(rnd, seats, paths)
        print(f"corrections: {corr}", flush=True)

        real = [
            s for s in seats.values() if s["complete"] and s["verdict"] != "MISSING"
        ]
        unanimous = len(real) == len(seats) and all(
            s["verdict"] == "PASS" for s in real
        )
        new_classes = sorted(
            {c for s in seats.values() for c in s["classes"]} - set(st["classes_seen"])
        )
        st["classes_seen"] = sorted(
            set(st["classes_seen"]) | {c for s in seats.values() for c in s["classes"]}
        )
        st["clean_streak"] = 0 if new_classes else st["clean_streak"] + 1

        st["history"].append(
            {
                "round": rnd,
                "at": now(),
                "writer_complete": ok,
                "seats": seats,
                "new_classes": new_classes[:20],
                "clean_streak": st["clean_streak"],
                "corrections": str(corr),
            }
        )
        save_state(st)

        if unanimous:
            st["status"] = "unanimous-pass"
            save_state(st)
            print(f"STOP: unanimous PASS at round {rnd}")
            return 0
        if st["clean_streak"] >= 2:
            st["status"] = "no-new-defect-class"
            save_state(st)
            print(f"STOP: no new defect class for two rounds at round {rnd}")
            return 0
        print(
            f"round {rnd} done: {len(new_classes)} new defect classes, streak {st['clean_streak']}",
            flush=True,
        )

    st["status"] = "cap-reached"
    save_state(st)
    print(f"STOP: cap reached at round {st['round']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
