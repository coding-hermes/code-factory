# 57. docs/PRD-code-factory.md — the requirements record

| Field | Value |
|---|---|
| Path | `~/code-factory/docs/PRD-code-factory.md` |
| Repository | `code-factory` |
| Revision | `8f77667b` |
| Status | **VERIFIED — the requirements record is described from its own rules; its Verified-by discipline and id-namespace hazard are quoted with their resolving lines** |

## 1. Purpose and why it matters

The product requirements: a bare bunker agent becomes a node that receives a unit of work,
executes it in a repo with a real harness, and returns evidence a stranger can verify —
repeatably, without root, without a human in the loop (`docs/PRD-code-factory.md:3-5`).
Its method is the Verified-by cell: every requirement names the command, exit code or
number that decides it, and a cell that says **no test** is the finding that the repo
ships nothing that can fail on that requirement today (`docs/PRD-code-factory.md:9-13`)
[fact: FACT-10]. What breaks if it is absent: requirements become vibes. What breaks if
it lies: quoting a green selftest as proof of a requirement it does not exercise — the
failure mode the column exists to prevent (`docs/PRD-code-factory.md:11-13`).

## 2. Dependencies and library contracts

| Dependency | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `docs/ACCEPTANCE-PLAN.md` | this repo | carries the per-requirement status for CF-101–CF-112 (`docs/PRD-code-factory.md:10-13`) | requirement state and plan state diverge |
| `bash docs/audits/prd-blocker-resolution.sh` | this repo | decides each blocker id: prints `row=<status>` or `requirement-only`, exit 0 only when each resolves, is still open, and carries a Verified-by cell (`docs/PRD-code-factory.md:239-240`) | a closed row silences its requirement |
| the board | `.coding-hermes/board/tasks.jsonl` | the requirement id namespace CF-101–CF-112 now ALSO exists as board rows (the CF-421 mapping) — a citation must name its namespace in words (`docs/PRD-code-factory.md:15-24`) | id-shape-based tooling silently misresolves |

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| every locator on this page resolves | `python3 scripts/master_doc_check.py docs/handbook/appendices/units --only 57- --strict` | `MASTER-DOC: PASS` | 2026-11-22 | PASS |
| the blocker-resolution instrument agrees | `bash docs/audits/prd-blocker-resolution.sh` | exit 0, every id resolved and open with a Verified-by cell | 2026-11-22 at `8f77667b` | PASS — see commit body for the printed rows |
| the requirement table's header is on the named line | `sed -n 25p docs/PRD-code-factory.md` | `\| ID \| Requirement \| Verified by \|` | 2026-11-22 | PASS |

## 4. Metrics emitted

None as counters. Its measurable output is the requirement table itself — twelve ids,
each with a deciding command — plus the drift instruments the record names: the
blocker-resolution script and the acceptance plan's arm-census instruments, which grade
whether this document and the tree still agree.

## 5. Log lines it can generate

- Through its instrument: `row=<status>` / `requirement-only` per blocker id
  (`docs/PRD-code-factory.md:239-240`) — and a non-zero exit naming the id that no longer
  resolves, which is the record lying.
- Through the acceptance plan: the section-mapping instrument's counts (record 59), which
  grade the plan side of the same id family.

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| A green selftest quoted as requirement proof | a requirement marked satisfied | the Verified-by column's rule: the deciding command must decide THIS requirement (`docs/PRD-code-factory.md:9-13`) | name the specific command; run it |
| Id-namespace collision | `CF-110` resolves to a board row instead of a requirement | the namespace paragraph: cite the namespace in words (`docs/PRD-code-factory.md:15-24`) | keep the explicit mapping; never lean on id shape |
| A closed board row hiding an open requirement | the blocker script exits non-zero | the instrument's contract: exit 0 only when each id is open with a Verified-by cell (`:239-240`) | reopen the requirement or fix the mapping row |

## 7. Environment and settings it reads

| setting | source | requirement |
|---|---|---|
| requirement ids | CF-101–CF-112 (`docs/PRD-code-factory.md:15`) | a requirement namespace that shares one spelling with board rows — disambiguation is mandatory |
| acceptance status | docs/ACCEPTANCE-PLAN.md | the per-requirement verdict table |
| the repo's self-test | `tests/selftest.sh` | quoted only for what it exercises [fact: FACT-11] |

## 8. Evidence of record

- The record: goal `docs/PRD-code-factory.md:3-5`, Verified-by rule `:9-13`, id-namespace
  hazard `:15-24`, requirement table `:25`, blocker instrument `:239-240`.
- The enforcing pair: the acceptance plan (record 59) and the board contract (record 55);
  the closure law behind Verified-by: fact: FACT-10.
- The battery whose greens must not be over-quoted: record 45 [fact: FACT-11].
