#!/usr/bin/env python3
"""master_doc_check.py — the gate between "a model wrote a section" and "the section is true".

Run it before committing any docs/master change, and run it in the quorum brief as the shared
checklist. It refuses a document that lost structure, cites a line that does not exist, claims
VERIFIED without locators, or states a fact that is not in the ledger.

  python3 scripts/master_doc_check.py docs/master            # all modules
  python3 scripts/master_doc_check.py docs/master --only 09- --strict

Exit 0 = pass, 1 = at least one error (or a warning under --strict).
"""
import argparse
import pathlib
import re
import sys

# The eight headings the skeleton actually ships. The first version of this list was invented, so
# every document failed for the wrong reason — a template that teaches a shape the gate rejects is a
# defect (coding-hermes-nasa-spec, pitfalls). Derive this from the template, never from the method.
REQUIRED_SECTIONS = [
    "Purpose and why it matters",
    "Dependencies and library contracts",
    "Verification",
    "Metrics emitted",
    "Log lines it can generate",
    "Failure modes",
    "Environment and settings it reads",
    "Evidence of record",
]

LOCATOR = re.compile(r"\b([\w./-]+\.(?:py|sh|md|go|yaml|yml|jsonl|json|toml)):(\d+)")
FACT_REF = re.compile(r"\bfact:\s*(FACT-\d+)\b")
STATUS = re.compile(r"\|\s*Status\s*\|\s*\*\*(VERIFIED|UNVERIFIED|FAILING|RED)[^*]*\*\*")


def facts_ledger(root: pathlib.Path):
    """FACT-nn -> claim, from _facts.md. A document may only cite facts that exist."""
    p = root / "_facts.md"
    out = {}
    if not p.is_file():
        return out
    for line in p.read_text(encoding="utf-8").splitlines():
        m = re.match(r"\|\s*(FACT-\d+)\s*\|\s*([^|]+)\|", line)
        if m:
            out[m.group(1)] = m.group(2).strip()
    return out


def check(path: pathlib.Path, repo: pathlib.Path, facts: dict):
    text = path.read_text(encoding="utf-8")
    errs, warns = [], []

    # 1. structure: every required section present, in order-independent form
    h2 = [m.group(1).strip() for m in re.finditer(r"^##\s+(?:\d+\.\s*)?(.+)$", text, re.M)]
    for want in REQUIRED_SECTIONS:
        if not any(want.lower() in h.lower() for h in h2):
            errs.append("missing section: %s" % want)

    # 2. locators: every file:line must exist and the line must be inside the file
    locs = LOCATOR.findall(text)
    for fname, line in locs:
        base = pathlib.Path(fname).name
        cand = [repo / fname, repo / "specs" / base, repo / "docs" / base,
                repo / "scripts" / base, pathlib.Path(fname)]
        f = next((c for c in cand if c.is_file()), None)
        if f is None:
            errs.append("locator names no file: %s:%s" % (fname, line))
            continue
        try:
            n = sum(1 for _ in f.open("r", encoding="utf-8", errors="replace"))
        except OSError:
            errs.append("locator file unreadable: %s" % fname)
            continue
        if int(line) > n:
            errs.append("locator past EOF: %s:%s (file has %d lines)" % (fname, line, n))

    # 3. VERIFIED is earned: it needs locators and every cited fact must exist
    m = STATUS.search(text)
    status = m.group(1) if m else "RED"
    if status == "VERIFIED":
        if len(locs) < 3:
            errs.append("VERIFIED with %d locator(s) — needs at least 3" % len(locs))
        cited = set(FACT_REF.findall(text))
        missing = sorted(c for c in cited if c not in facts)
        if missing:
            errs.append("cites unknown fact(s): %s" % ", ".join(missing))
        if not cited:
            errs.append("VERIFIED without citing a single FACT-nn from _facts.md")

    # 4. the field contract's hard rule: an empty required field is the finding, not a blank
    for heading in ("Failure modes", "Metrics emitted", "Log lines"):
        block = re.search(r"^##\s+(?:\d+\.\s*)?%s.*?(?=^##\s|\Z)" % re.escape(heading), text, re.M | re.S)
        if block:
            body = re.sub(r"^##.*$", "", block.group(0), flags=re.M).strip()
            if len(body) < 40:
                warns.append("field looks empty: %s" % heading)

    # 5. placeholders are findings
    for token in ("UNKNOWN", "TODO", "TBD"):
        if token in text and status == "VERIFIED":
            errs.append("%s in a VERIFIED document" % token)

    return status, errs, warns


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("root", nargs="?", default="docs/master")
    ap.add_argument("--repo", default=".")
    ap.add_argument("--only", default="")
    ap.add_argument("--strict", action="store_true")
    a = ap.parse_args()
    root = pathlib.Path(a.root)
    repo = pathlib.Path(a.repo).resolve()
    facts = facts_ledger(root)
    only = tuple(x.strip() for x in a.only.split(",") if x.strip())

    files = [f for f in sorted(root.glob("[0-9][0-9]-*.md")) if not f.name.startswith("00-INDEX")]
    if only:
        files = [f for f in files if f.name.startswith(only)]
    total_err = total_warn = 0
    verified = 0
    for f in files:
        status, errs, warns = check(f, repo, facts)
        verified += status == "VERIFIED"
        total_err += len(errs)
        total_warn += len(warns)
        if errs or warns:
            print("%-46s %-10s %d error(s) %d warning(s)" % (f.name, status, len(errs), len(warns)))
            for e in errs:
                print("   FAIL  %s" % e)
            for w in warns:
                print("   WARN  %s" % w)
        else:
            print("%-46s %-10s ok" % (f.name, status))
    print("\n%d module(s): %d VERIFIED, %d error(s), %d warning(s), %d fact(s) in the ledger"
          % (len(files), verified, total_err, total_warn, len(facts)))
    bad = total_err or (a.strict and total_warn)
    print("MASTER-DOC: %s" % ("FAIL" if bad else "PASS"))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
