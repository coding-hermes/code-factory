#!/usr/bin/env python3
"""master_doc_check.py — the gate between "a model wrote a section" and "the section is true".

Run it before committing any master-document change, and run it in the quorum brief as the shared
checklist. It refuses a document that lost structure, cites a line that does not exist, claims
VERIFIED without locators, or states a fact that is not in the ledger.

  python3 scripts/master_doc_check.py                        # resolve the root, check every module
  python3 scripts/master_doc_check.py docs/master            # explicit root
  python3 scripts/master_doc_check.py --only 09- --strict

Exit 0 = pass, 1 = at least one error (or a warning under --strict, or a root that holds no
module), 2 = no master-document root exists at all.
"""

import argparse
import os
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

# The leading lookbehind must allow a DOT: `.coding-hermes/board/tasks.jsonl:7` is a real
# locator, and a \b before the character class silently dropped the dot and reported a
# missing file — a checker bug that failed a correct document.
LOCATOR = re.compile(
    r"(?<![\w/.-])([\w./-]*\.(?:py|sh|md|go|yaml|yml|jsonl|json|toml)):(\d+)"
)
FACT_REF = re.compile(r"\bfact:\s*(FACT-\d+)\b")
STATUS = re.compile(
    r"\|\s*Status\s*\|\s*\*\*(VERIFIED|UNVERIFIED|FAILING|RED)[^*]*\*\*"
)

# Where the module set lives, relative to --repo, in discovery order. docs/master is the layout
# MASTER-DOC-SCHEMA.md was written for; the Apollo re-arrange moved the modules under
# docs/handbook, and the gate went on reading the old directory. A root that does not exist yields
# an empty glob, and an empty glob used to print PASS; a gate that cannot fail. CF_MASTER_DIR is
# the same override master_doc_fill.py reads, so one variable moves both halves of the pipeline.
DEFAULT_ROOTS = ("docs/master", "docs/handbook/appendices/units")


def resolve_root(explicit, repo):
    """Return (root, tried). root is None when no candidate is an existing directory.

    An explicit positional root wins outright: an explicit caller named one directory and gets it,
    and if that directory is absent it is a named failure rather than a silent empty run. With no
    positional argument the candidates are CF_MASTER_DIR (when set and non-empty), then the two
    shipped layouts; the first one that is an existing directory wins.
    """
    if explicit is not None:
        path = pathlib.Path(explicit)
        return (path if path.is_dir() else None), [path]
    tried = []
    from_env = os.environ.get("CF_MASTER_DIR", "").strip()
    if from_env:
        tried.append(pathlib.Path(from_env))
    tried.extend(repo / rel for rel in DEFAULT_ROOTS)
    for cand in tried:
        if cand.is_dir():
            return cand, tried
    return None, tried


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
    h2 = [
        m.group(1).strip() for m in re.finditer(r"^##\s+(?:\d+\.\s*)?(.+)$", text, re.M)
    ]
    for want in REQUIRED_SECTIONS:
        if not any(want.lower() in h.lower() for h in h2):
            errs.append("missing section: %s" % want)

    # 2. locators: every file:line must exist and the line must be inside the file
    locs = LOCATOR.findall(text)
    for fname, line in locs:
        base = pathlib.Path(fname).name
        cand = [
            repo / fname,
            repo / "specs" / base,
            repo / "docs" / base,
            repo / "scripts" / base,
            pathlib.Path(fname),
        ]
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
            errs.append(
                "locator past EOF: %s:%s (file has %d lines)" % (fname, line, n)
            )

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
        block = re.search(
            r"^##\s+(?:\d+\.\s*)?%s.*?(?=^##\s|\Z)" % re.escape(heading),
            text,
            re.M | re.S,
        )
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
    ap.add_argument(
        "root",
        nargs="?",
        default=None,
        help="module root; omitted = resolve CF_MASTER_DIR, docs/master, "
        "docs/handbook/appendices/units under --repo",
    )
    ap.add_argument("--repo", default=".")
    ap.add_argument("--only", default="")
    ap.add_argument("--strict", action="store_true")
    a = ap.parse_args()
    repo = pathlib.Path(a.repo).resolve()
    root, tried = resolve_root(a.root, repo)
    if root is None:
        # Nothing to check is not a pass. Name every candidate that was tried, so a reader can see
        # which directory the gate looked for instead of wondering why the summary was empty.
        for cand in tried:
            print("   FAIL  no master doc root at %s" % cand)
        print("MASTER-DOC: FAIL")
        return 2
    print("root: %s" % root.resolve())
    facts = facts_ledger(root)
    only = tuple(x.strip() for x in a.only.split(",") if x.strip())

    found = [
        f
        for f in sorted(root.glob("[0-9][0-9]-*.md"))
        if not f.name.startswith("00-INDEX")
    ]
    # An empty selection is a named failure, not a silent pass. The summary still prints, with
    # zero modules in it, so the reader sees both the count and the reason it is zero.
    vacuous = None
    files = found
    if not found:
        vacuous = (
            "   FAIL  no module files (NN-*.md) in the resolved root: %s"
            % root.resolve()
        )
    elif only:
        files = [f for f in found if f.name.startswith(only)]
        if not files:
            vacuous = "   FAIL  --only %s selected none of the %d module(s) in %s" % (
                a.only,
                len(found),
                root.resolve(),
            )
    if vacuous:
        print(vacuous)
    total_err = total_warn = 0
    verified = 0
    computed = {}
    for f in files:
        status, errs, warns = check(f, repo, facts)
        computed[f.name] = status
        verified += status == "VERIFIED"
        total_err += len(errs)
        total_warn += len(warns)
        if errs or warns:
            print(
                "%-46s %-10s %d error(s) %d warning(s)"
                % (f.name, status, len(errs), len(warns))
            )
            for e in errs:
                print("   FAIL  %s" % e)
            for w in warns:
                print("   WARN  %s" % w)
        else:
            print("%-46s %-10s ok" % (f.name, status))

    # The index is part of the document, not a summary of it: a status column that disagrees with the
    # page it links to is the same lie as a page that stamps VERIFIED without earning it, and the gate
    # used to accept it because it never read the index at all.
    index = root / "00-INDEX.md"
    if index.exists() and not only:
        text = index.read_text(encoding="utf-8", errors="replace")
        rows = re.findall(
            r"\[`[^`]+`\]\((\d\d-[^)]+\.md)\)\s*\|\s*[^|]*\|\s*([A-Z]+)\s*\|", text
        )
        seen = set()
        for name, claimed in rows:
            seen.add(name)
            actual = computed.get(name)
            if actual and actual != claimed:
                total_err += 1
                print(
                    "   FAIL  00-INDEX.md claims %s is %s; this gate computed %s"
                    % (name, claimed, actual)
                )
        unlisted = sorted(set(computed) - seen)
        if unlisted:
            total_err += 1
            print(
                "   FAIL  00-INDEX.md has no row for %d module(s): %s"
                % (len(unlisted), ", ".join(unlisted[:4]))
            )

    print(
        "\n%d module(s): %d VERIFIED, %d error(s), %d warning(s), %d fact(s) in the ledger"
        % (len(files), verified, total_err, total_warn, len(facts))
    )
    bad = total_err or (a.strict and total_warn) or bool(vacuous)
    print("MASTER-DOC: %s" % ("FAIL" if bad else "PASS"))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
