# CF-115 — arm evidence for the two CF-099 drift-probe legs that certified nothing

`docs/audits/cf099-prd-drift-probe.sh` claimed to prove that `docs/PRD-code-factory.md`'s milestone
block and `docs/ACCEPTANCE-PLAN.md`'s reverse-direction table still describe this tree. Two legs
certified nothing: the milestone open-defect leg went vacuous the moment the phrase it greps for was
reworded, and the reverse-direction table was never opened at all. This file records the arms that
prove both legs now bite, and that the legs which already worked were not weakened.

## What was measured at

- Corpus commit: `c1890a52` (`tick/cf115`, based on `origin/main`), unmodified except where an arm
  says otherwise. Each arm ran in its own `git clone` under `$TMPDIR`, so no arm could see another's
  corpus edits.
- Probe under test, fixed: `sha256 2a80b827a6a2c56d093057a878bd13c15041ac22ce202eca6bc37dba46fb40af`
  — these are the bytes this commit lands (`git show <this-commit>:docs/audits/cf099-prd-drift-probe.sh | sha256sum`).
- Probe under test, pre-fix (the row's red control): `sha256 c23af72a8a57ba05487117203a07505d4bb36a8b0ad5d05c158cdeb4e697e7a9`
  — `git show c1890a52:docs/audits/cf099-prd-drift-probe.sh`.
- Harness: `bash docs/audits/cf099-prd-drift-probe.sh`, run from each clone's root.

Fixture note (disclosed): the criterion-0 fixture clone also advances the plan header's stale census
snapshot (`carries 68 numbered sections` → `70`) so that the vacuity is visible as `rc=0` on its own.
That one-line edit exists **only inside that clone**; the plan's census is left stale and firing in the
delivered tree, and `docs/ACCEPTANCE-PLAN.md` is not part of this commit (AC5).

## Arm table

| # | arm | exact command | rc | DRIFT lines printed |
|---|-----|---------------|----|---------------------|
| 0 | untouched corpus (also the D-negative guard) | `bash docs/audits/cf099-prd-drift-probe.sh` | 1 | `DRIFT: plan says 68 sections, tests/selftest.sh has 70` — **only** this pre-existing stale-census line; `reverse_table_uncovered=none` |
| 0b | criterion 0 / red control: fixture (phrase reworded + `\| §22–§28` row deleted + census synced), **pre-fix probe** | `bash docs/audits/cf099-prd-drift-probe.sh` | **0** | none — prints `measured: … open_blockers=` (empty) then `OK: milestone, plan snapshot and layer arms agree at c1890a52`. This is the defect: a tree with both defects certified clean. |
| 1+2 | same fixture, **fixed probe** | `bash docs/audits/cf099-prd-drift-probe.sh` | 1 | `DRIFT: milestone Status block carries no open-defect phrase, so its blocker leg certifies nothing` + seven `DRIFT: tests/selftest.sh §22…§28 has no row in docs/ACCEPTANCE-PLAN.md's reverse-direction table`; `open_blockers=` empty, `reverse_table_uncovered=22 23 24 25 26 27 28` |
| A | phrase reworded only (plan intact) | same | 1 | stale-census line + `DRIFT: milestone Status block carries no open-defect phrase …`; **no** reverse-table line and `reverse_table_uncovered=none` → the new leg D does not fire on an intact table |
| D | `\| §22–§28` row deleted only (PRD intact) | same | 1 | stale-census line + the seven §22…§28 reverse-table lines; **no** milestone line |
| A2 | phrase intact, every `CF-nnn` id behind it emptied | same | 1 | stale-census line + `DRIFT: milestone open-defect phrase carries no CF-id list (open_blockers empty), so its blocker leg certifies nothing` |
| B | control: `` `CF-099` `` (board status `complete`) inserted into the milestone open-defect list | same | 1 (unchanged) | stale-census line + `DRIFT: milestone lists CF-099 as an open blocker, board says complete` — the pre-existing board-status leg still works |
| — | `--sections-only` (cheap fixture mode) | `bash docs/audits/cf099-prd-drift-probe.sh --sections-only` | 1 | stale-census line; `measured: plan_sections=68 selftest_sections=70 plan=docs/ACCEPTANCE-PLAN.md selftest=tests/selftest.sh` |

Arm 0 doubles as the D-negative guard: with the plan untouched and the phrase intact, the probe's only
DRIFT line is the pre-existing stale census — the new legs are not hair-triggered.

## The §22–§28 range row

`| §22–§28 census fail-closed arms …` is a **single** reverse-table row that covers §22, §23, §24,
§25, §26, §27 and §28 — the probe reports all seven only when that one row is deleted (arm D), and
reports none of them when it is present (arm 0), because leg D reuses
`docs/audits/cf198-section-mapping.sh`'s range expansion instead of matching `§N` literals one by one.

## What changed in the probe

- **Leg A** no longer derives its id list from an unconditional `sed -n 's/.*open defects//p'`. The
  phrase is now required (case-insensitive, `open defect`/`open defects`) and so is a non-empty `CF-nnn`
  list behind it; either absence is DRIFT. The board-status loop over those ids is unchanged, which is
  why control arm B still fires.
- **Leg D** is new: it invokes `docs/audits/cf198-section-mapping.sh --plan … --selftest …`, translates
  each `MISSING §N` into `DRIFT: tests/selftest.sh §N has no row in docs/ACCEPTANCE-PLAN.md's
  reverse-direction table`, and relays a non-zero checker exit that is *not* an uncovered section
  (including a missing checker) rather than letting a broken mapping leg read as "table intact".
- The measured line gained `reverse_table_uncovered=…`; `open_blockers=` keeps its position so existing
  greps still match, and `--sections-only` / `CF099_PLAN` / `CF099_SELFTEST` are untouched.

## Notes for the foreman

- The brief's literal Arm A command (`s/open defects on this path are /remaining gaps on this path are /`)
  is a no-op at `c1890a52`: the milestone block reads *"The open defects this milestone's legs depend on
  are …"*. The arms above reword **that** sentence, which is the same pure-prose change the defect
  describes. Worth a separate row if the brief text is reused.
- Still open and deliberately untouched: the plan header's stale census snapshot (68 numbered + 4
  lettered = 72 arms vs the tree's 70 + 4 = 74). The probe keeps reporting it, which is correct.
- Determinism: the probe was re-run 30× on the control-B clone — identical output every time
  (`grep -c 'no row in'` = 0/30). One earlier harness iteration printed a single spurious
  `§46 has no row` line while its clone was being set up; it never reproduced (3 further runs on that
  same clone, 30-run loop, and three full harness runs), and the probe reads only the plan, the
  selftest and the board, so a reported line is checkable by hand before it is believed.
