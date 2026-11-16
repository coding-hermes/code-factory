# CF-462 — one arm-census claim, graded by both plan instruments

**Row:** CF-462 (P3) · **Lane:** code-factory-duckbrain PM · **Tip measured:** `1a580d91`
**Tree under test:** `docs/ACCEPTANCE-PLAN.md` in the working tree; every instrument ran from the
repository root. Sections and arms were re-derived, never carried forward.

## What was false

The plan stated the arm census **twice**, and the two statements disagreed about the same tree:

| Where | Sentence | Value |
|---|---|---|
| `**Current state**` line (it `:15`) | "carries 68 numbered sections plus four lettered sub-arms … The checked-out tree carries 72 arms" | 68 sections / 72 arms |
| *The other direction: test sections with no PRD requirement* (it `:167`) | "The current tree carries 75 arms: 71 numbered sections and four lettered arms" | 71 sections / 75 arms |

Measured truth at `1a580d91`: `grep -cE '^say "[0-9]+\.' tests/selftest.sh` prints **71** numbered
sections, plus four lettered arms (§4b, §7b, §31b, §32a) = **75** arms. So the `:15` sentence was
stale and the `:167` sentence was true.

The defect has a sharp edge: **each instrument grades a different sentence.**

- `docs/audits/cf198-section-mapping.sh` greps the phrase `current tree carries N arms` → it graded
  `:167` → printed `arms_plan=75 arms_tree=75` / `RESULT: OK` / exit 0.
- `docs/audits/cf099-prd-drift-probe.sh` greps `N numbered sections` **on the first
  `**Current state**` line only** → it graded `:15` → printed
  `DRIFT: plan says 68 sections, tests/selftest.sh has 71` / exit **1**.

So the repository's own acceptance instrument was red at `main` while its section-mapping instrument
was green, over one fact. The probe's red line also reads as *tree* drift rather than as a stale
sentence, which is why the class survived several ticks.

## The fix

The census is now stated **once**, on the `**Current state**` line, carrying both phrasings the two
instruments read, at the derived value:

> `tests/selftest.sh` carries 71 numbered sections plus four lettered sub-arms, §4b, §7b, §31b and
> §32a — the current tree carries 75 arms.

The paragraph under *The other direction* no longer restates a number; it points at that single
claim and records why (so a second restatement cannot reintroduce the split). No section, no arm and
no reverse-table row was added or removed.

## Gates — command, exit code, output

| Gate | Command | Before | After |
|---|---|---|---|
| Single census claim (AC1) | `grep -cE "carries [0-9]+ numbered sections\|The current tree carries [0-9]+ arms" docs/ACCEPTANCE-PLAN.md` | 2 | **1** |
| Claim the mapping script reads (AC1) | `grep -cEo "current tree carries [0-9]+ arms" docs/ACCEPTANCE-PLAN.md` | 1 | **1** |
| Acceptance probe (AC2) | `bash docs/audits/cf099-prd-drift-probe.sh` | exit **1** — `DRIFT: plan says 68 sections, tests/selftest.sh has 71` | exit **0** — `OK: milestone, plan snapshot and layer arms agree at 1a580d91` |
| Section mapping | `bash docs/audits/cf198-section-mapping.sh` | exit 0 — `arms_plan=75 arms_tree=75` | exit 0 — `arms_plan=75 arms_tree=75` / `RESULT: OK` |
| Board shape | `bash scripts/boardctl validate` | — | exit 0 — `RESULT: OK (89 warning(s))` |
| Suite | `bash tests/selftest.sh` (clean clone of `1a580d91`) | — | **`SELFTEST: FAIL (1)`** — see *Residual* |

The probe's own `measured:` line after the fix reads
`tip=2f07051 rows=350 events=489 sections=71 open_blockers=CF-001 CF-002 CF-004 CF-080 CF-110 CF-112 CF-131 CF-132 CF-133 CF-136 CF-137 CF-138 CF-139 reverse_table_uncovered=none`
— the tip-pinned board snapshot (`2f07051`: 350 rows / 489 events) still reproduces, and the
reverse-direction table is covered.

## Red proof (AC3) — a clone, both directions

Clone of `1a580d91` with the edited plan copied in; the deciding sentence was then edited back to
the stale pair and restored. All four exit codes measured:

| Claim value in the clone | `cf099` | `cf198` |
|---|---|---|
| true (`71 numbered sections` / `current tree carries 75 arms`) | exit 0 — `OK: milestone, plan snapshot and layer arms agree at 1a580d91` | exit 0 — `RESULT: OK` |
| stale (`68 numbered sections` / `current tree carries 72 arms`) | exit **1** — `DRIFT: plan says 68 sections, tests/selftest.sh has 71` | exit **1** — `FAIL  section-mapping — prose claims 72 arms but tree carries 75` / `RESULT: DRIFT (1)` |
| restored to true | exit 0 | exit 0 |

Both directions fire, so neither instrument is decoration.

## Residual — AC4's suite leg is red at this tip, and it is not this row's

`bash tests/selftest.sh` in a clean clone of `1a580d91` (porcelain: only the plan edit) ends
`SELFTEST: FAIL (1)`, one arm:

```
  FAIL  CF-398 evidence checker (exit 0, strict 1): checked 176 complete rows, 104 unresolved
```

Attribution, measured rather than assumed:

- The arm runs `python3 scripts/board_evidence_check.py --quiet-findings` and `--strict`
  (`tests/selftest.sh:7641`, `:7646`). That checker contains **zero** references to
  `docs/ACCEPTANCE-PLAN.md` (`grep -c ACCEPTANCE-PLAN scripts/board_evidence_check.py` = 0), so this
  row's diff cannot influence it.
- Run directly at the same tip: lenient exit 0, `--strict` exit 1 —
  `allowlist: dated 2026-11-16, 62 accepted ids, 62 accepted findings of 104 findings, new=…(42 ids)…`.
  The strict arm is red because 42 live findings are outside the dated allowlist, not because of the
  census.
- The arm's owner is board row **CF-475**, whose fix a live sibling worker was writing in this shared
  checkout at the time of this tick (`scripts/board_evidence_check.py`, `tests/test_board_evidence_check.py`,
  `tests/selftest.sh` all modified; worker pid 1447477, brief `brief_cf475.txt`). This tick left every
  one of those paths untouched.

So CF-462's own subject is proven green and red-proved in both directions; AC4's literal
`SELFTEST: PASS` is withheld by an unrelated, pre-existing red owned by CF-475. Recorded here rather
than claimed away.

## Instrument noise, disclosed

A first-pass run of the battery printed
`DRIFT: tests/selftest.sh §22 has no row in docs/ACCEPTANCE-PLAN.md's reverse-direction table`.
Re-running `cf099` and `cf198` about a minute later against an unchanged plan printed
`reverse_table_uncovered=none` and `RESULT: OK`. `tests/selftest.sh` was being rewritten by the live
CF-475 worker during that window (mtime 16:37:35 local), so the §22 reading is a measurement taken
against a half-written suite, not a defect. It is recorded, not filed.
