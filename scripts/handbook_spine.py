#!/usr/bin/env python3
"""handbook_spine.py — mechanical cross-chapter consistency for the handbook.

Bane's objection to writing one module per round: "you will also struggle to keep
them all aligned." Correct. Chapter-by-chapter depth trades one failure for another
unless alignment stops being a memory task and becomes a check.

The spine is the set of facts every chapter must agree on:

  contracts   each interface has ONE canonical id; its two sides live in two
              chapters and must name the same producer/consumer pair
  settings    a variable documented in two chapters must have the same default
  references  every M<n> / F<n> cited must exist
  counts      the document's own totals (modules, flows, contracts) must match
              what the chapters actually contain

Run: python3 scripts/handbook_spine.py [--json]
Exit: 0 clean, 1 findings, 2 cannot parse.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

HB = Path("/home/kara/code-factory/docs/handbook")
CH = HB / "chapters"

# Canonical contract register: the 18 interfaces named in OUTLINE Part IV.
# id -> (name, expected producer system, expected consumer system)
CANON = {
    "CT-01": ("owner → scheduler", "owner", "scheduler"),
    "CT-02": ("scheduler → crier", "scheduler", "crier"),
    "CT-03": ("crier → node", "crier", "node"),
    "CT-04": ("node → crier", "node", "crier"),
    "CT-05": ("foreman → scheduler", "foreman", "scheduler"),
    "CT-06": ("crier → scheduler", "crier", "scheduler"),
    "CT-07": ("router → gateway", "router", "gateway"),
    "CT-08": ("crier → gateway", "crier", "gateway"),
    "CT-09": ("node → duckbrain", "node", "duckbrain"),
    "CT-10": ("node → board", "node", "board"),
    "CT-11": ("node → sessionstore", "node", "sessionstore"),
    "CT-12": ("node → gitreins", "node", "gitreins"),
    "CT-13": ("gitreins → board", "gitreins", "board"),
    "CT-14": ("foreman → board", "foreman", "board"),
    "CT-15": ("foreman → duckbrain", "foreman", "duckbrain"),
    "CT-16": ("docsgate → handbook", "docsgate", "handbook"),
    "CT-17": ("conformance → harness", "conformance", "harness"),
    "CT-18": ("handbook → owner", "handbook", "owner"),
}

# Boundary contracts: one end is an actor with no implementation file in the
# handbook's covered code — a human (owner), an LLM lane (foreman), or a service
# outside the five covered systems (router, gateway, duckbrain, sessionstore,
# boardctl, gitreins). For these, "cited under the canonical id, the covered side
# named, the far side honestly marked rumour/missing/UNVERIFIED" is the correct
# completion (OUTLINE Part I.9 "described only from the client side", and Part IV's
# own "missing" annotations). The spine therefore demands both sides only for
# INTERNAL contracts, where both ends live in covered code. A boundary contract is
# a finding only when no chapter cites its canonical id at all.
BOUNDARY = {
    "CT-01",  # owner -> scheduler  : the producer is a human writing fleet.toml + DB rows,
              #                      not a function (round-9 re-grade; was miscounted internal)
    # CT-05 (foreman -> scheduler) is INTERNAL, not boundary: both ends live in covered
    # code — producer scripts/load_lane_config.py:31-37 (copies prompts/*.md into
    # projects.prompt), consumer internal/scheduler/spawn.go:1244 buildForemanPrompt
    # (round-9 grok B3: the "foreman is an LLM lane" exemption was a covered-implementation
    # mislabelled external).
    "CT-07",  # router -> gateway   : task-router and the Hermes gateway, both out of scope
    "CT-08",  # crier -> gateway    : the Hermes gateway (out of scope)
    "CT-09",  # node -> duckbrain   : the duckbrain service (out of scope)
    "CT-10",  # node -> board       : the boardctl binary (out of scope)
    "CT-11",  # node -> sessionstore: the Hermes session store (out of scope)
    "CT-12",  # node -> gitreins    : the gitreins binary (out of scope)
    "CT-13",  # gitreins -> board   : gitreins + boardctl binaries (out of scope)
    "CT-14",  # foreman -> board    : the foreman lane + boardctl (out of scope)
    "CT-15",  # foreman -> duckbrain: the foreman lane + duckbrain (out of scope)
    "CT-16",  # docsgate -> handbook  : consumer is the handbook document, not a function
    "CT-17",  # conformance -> harness: consumer is the operator/board (FACT-08), not a function
    "CT-18",  # handbook -> owner     : the owner is a human
}

SETTING_ROW = re.compile(r"^\|\s*`?([A-Z][A-Z0-9_]{3,})`?\s*\|\s*([^|]{1,60})\|")
REF = re.compile(r"\b(?:M\d{1,2}|F\d{1,2})\b")
COUNT_CLAIM = re.compile(r"\b(\d{1,3})\s+(modules?|flows?|contracts?|chapters?|submodules?)\b", re.I)


def chapters() -> dict[str, str]:
    return {p.stem: p.read_text(errors="replace") for p in sorted(CH.glob("M*.md"))}


def section(text: str, n: int) -> str:
    """Body of '## <n>. ...' up to the next '## '."""
    m = re.search(rf"^##\s*{n}\.\s.*?$(.*?)(?=^##\s|\Z)", text, re.S | re.M)
    return m.group(1) if m else ""


def contract_rows(text: str) -> list[dict]:
    body = section(text, 6)
    rows = []
    for line in body.splitlines():
        if not line.startswith("|") or set(line) <= set("|-: "):
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        if len(cells) < 6 or cells[0].lower() == "id":
            continue
        rows.append({
            "local_id": cells[0],
            "peer": cells[1],
            "direction": cells[2],
            "producer": cells[3],
            "consumer": cells[4],
            "state": cells[5],
        })
    return rows


def has_fq(cell: str) -> bool:
    """A real implementation reference: file:line or file:function, not prose."""
    return bool(re.search(r"[\w./-]+\.(?:py|go|sh|ts|js|yaml|toml)(?:[:#][\w.\-/()]*)?", cell))


def norm_default(cell: str) -> str:
    """Compare the default, not its annotation.

    M2 writes `40 (`:112`)` and M5 writes `40 (`:276`)` — same default, different
    citation. Comparing whole cells reports a conflict that does not exist, which
    is exactly the noise that makes a checker ignorable.
    """
    s = re.sub(r"`[^`]*`", "", cell)          # drop backticked refs
    s = re.sub(r"\([^)]*\)", "", s)           # drop parentheticals
    s = s.strip().lower()
    m = re.match(r"^(-?\d+)", s)
    return m.group(1) if m else s[:24]


def norm_state(cell: str) -> str:
    """Canonical state word from a contract-state cell.

    'works (transport)' -> 'works'; 'broken — CF-355…' -> 'broken'. Only the
    leading keyword is compared, so a parenthetical scope note ('works,
    dispatcher leg') cannot be mistaken for a state disagreement (the round-9
    CT-06 finding: M9 said 'broken', M11 said 'works', the spine passed because
    it compared function tokens but never the state column).
    """
    m = re.search(r"\b(works?|broken|missing|unverified)\b", cell.lower())
    return m.group(1) if m else cell.strip().lower()[:24]


def func_tokens(cell: str) -> set[str]:
    """Function-name tokens in a contract cell.

    A function token is a backticked bare identifier that either immediately follows
    a `file:line` reference (`\\`handler.go:990\\` \\`HandleDeliver\\``) or carries a
    `()` call suffix (`\\`payload()\\``). Field names (`board`, `text_b64`) and dotted
    names (`crier.deliver`) are excluded, so a clarifying "field X (not Y)" cannot be
    mistaken for a function-name disagreement.
    """
    toks = re.findall(r"`([^`]+)`", cell)
    out: set[str] = set()
    prev_is_loc = False
    for t in toks:
        t = t.strip()
        is_loc = bool(re.search(r":\d", t))
        called = re.fullmatch(r"([A-Za-z_][A-Za-z0-9_]*)\(\)", t)
        bare = re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", t)
        if called:
            out.add(called.group(1))
        elif bare and prev_is_loc:
            out.add(t)
        prev_is_loc = is_loc
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()

    ch = chapters()
    if not ch:
        print("no chapters found", file=sys.stderr)
        return 2

    findings: list[dict] = []

    # 1. contract register: canonical ids must appear, and both sides must be real
    register: dict[str, list[tuple[str, dict]]] = defaultdict(list)
    edge: dict[tuple[str, str], list[tuple[str, dict]]] = defaultdict(list)
    for name, text in ch.items():
        for row in contract_rows(text):
            m = re.search(r"CT-\d{2}", row["local_id"] + " " + row["peer"])
            if m:
                register[m.group(0)].append((name, row))
            edge[(row["peer"].lower(), row["direction"].lower()[:3])].append((name, row))

    for cid, (label, prod, cons) in CANON.items():
        hits = register.get(cid, [])
        if not hits:
            findings.append({
                "kind": "CONTRACT UNREGISTERED",
                "subject": cid,
                "detail": f"{label} — no chapter cites canonical id {cid}; chapters invent local ids (M2-C1, M9-C2), so the two ends cannot be matched",
            })
            continue
        if cid in BOUNDARY:
            # Cited is sufficient: the far side is external by design, so "one side
            # named + the other marked rumour/missing" is the honest terminal state,
            # not a chapter defect.
            continue
        sides = [h for h in hits if has_fq(h[1]["producer"]) and has_fq(h[1]["consumer"])]
        if not sides:
            findings.append({
                "kind": "CONTRACT ONE-SIDED",
                "subject": cid,
                "detail": f"{label} — cited in {', '.join(h[0] for h in hits)} but no row names both implementations as file:line",
            })

    # 1b. cross-chapter agreement: an internal contract's two ends live in two (or more)
    # chapters, and those chapters must name the SAME producer/consumer FUNCTION, not just
    # *some* file token. This is the check the docstring promised and round-8 found missing:
    # has_fq() only proves a file:line pattern EXISTS; it cannot tell that M2 named
    # HandleDeliver while M10 named HandleRetrieve for the same canonical id. A cell with no
    # function token is skipped (a consumer may be legitimately plural — the retrieve surface
    # feeds both the node worker and the dispatcher).
    for cid, (label, prod, cons) in CANON.items():
        if cid in BOUNDARY:
            continue
        hits = register.get(cid, [])
        if len(hits) < 2:
            continue
        for role, key in (("producer", "producer"), ("consumer", "consumer")):
            nonempty = {name: frozenset(func_tokens(row[key])) for name, row in hits}
            nonempty = {n: t for n, t in nonempty.items() if t}
            if len(set(nonempty.values())) > 1:
                findings.append({
                    "kind": "CONTRACT PAIR DISAGREEMENT",
                    "subject": cid,
                    "detail": f"{label} — {role} differs across chapters: "
                              + "; ".join(f"{n}: {sorted(t)}" for n, t in sorted(nonempty.items())),
                })

    # 1c. cross-chapter state agreement (round-9 CT-06 finding): two chapters that
    # describe one internal contract from opposite ends must state the SAME state
    # word. The round-8/9 pair check compared producer/consumer function tokens but
    # never the state column, so M9 ("broken") and M11 ("works") for CT-06 passed
    # while flatly disagreeing. Parenthetical scope notes are normalized away.
    for cid, (label, prod, cons) in CANON.items():
        if cid in BOUNDARY:
            continue
        hits = register.get(cid, [])
        if len(hits) < 2:
            continue
        states = {norm_state(row["state"]) for _, row in hits}
        if len(states) > 1:
            findings.append({
                "kind": "CONTRACT STATE DISAGREEMENT",
                "subject": cid,
                "detail": f"{label} — state differs across chapters: "
                          + "; ".join(f"{name}: {norm_state(row['state'])}" for name, row in hits),
            })

    # 2. settings: same name, different default in two chapters
    seen: dict[str, list[tuple[str, str]]] = defaultdict(list)
    for name, text in ch.items():
        for line in section(text, 5).splitlines():
            m = SETTING_ROW.match(line)
            if m:
                seen[m.group(1)].append((name, norm_default(m.group(2))))
    for var, hits in sorted(seen.items()):
        defaults = {d for _, d in hits}
        if len(hits) > 1 and len(defaults) > 1:
            findings.append({
                "kind": "SETTING CONFLICT",
                "subject": var,
                "detail": "; ".join(f"{c}: {d}" for c, d in hits),
            })

    # 3. dangling references
    known = set(ch) | {f"M{i}" for i in range(13)}
    for name, text in ch.items():
        for ref in set(REF.findall(text)):
            # "M0 F0-4" is an outline field, not a flow id
            if re.search(rf"{ref}-\d", text):
                continue
            if ref.startswith("M") and ref not in known:
                findings.append({
                    "kind": "DANGLING REFERENCE",
                    "subject": f"{name} → {ref}",
                    "detail": "chapter cites a module id that has no chapter",
                })
            if ref.startswith("F") and not (1 <= int(ref[1:]) <= 16):
                findings.append({
                    "kind": "DANGLING REFERENCE",
                    "subject": f"{name} → {ref}",
                    "detail": "flow id outside F1-F16",
                })

    # 4. count claims inside chapters vs what exists
    actual = {
        "module": len(ch),
        "flow": 16,
        "contract": len(CANON),
        "chapter": len(ch),
        "submodule": None,
    }
    for name, text in ch.items():
        # Quoted command output ("44 module(s): 37 VERIFIED…") is not a count claim
        # about this document; it is a literal tool string. Strip backtick spans so
        # the count check only weighs prose totals, not quoted evidence.
        prose = re.sub(r"`[^`]*`", "", text)
        for num, word in COUNT_CLAIM.findall(prose):
            key = word.lower().rstrip("s")
            want = actual.get(key)
            if want and int(num) != want:
                findings.append({
                    "kind": "COUNT CLAIM",
                    "subject": f"{name}: '{num} {word}'",
                    "detail": f"document contains {want} {word}",
                })

    summary = defaultdict(int)
    for f in findings:
        summary[f["kind"]] += 1

    if a.json:
        print(json.dumps({"chapters": len(ch), "findings": findings, "summary": summary}, indent=2))
    else:
        print(f"chapters={len(ch)}  canonical contracts={len(CANON)}")
        print(f"findings={len(findings)}  " + "  ".join(f"{k}={v}" for k, v in sorted(summary.items())))
        for f in findings:
            print(f"  [{f['kind']}] {f['subject']}: {f['detail'][:170]}")
    return 0 if not findings else 1


if __name__ == "__main__":
    sys.exit(main())
