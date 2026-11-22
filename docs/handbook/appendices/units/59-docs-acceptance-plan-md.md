# 59. docs/ACCEPTANCE-PLAN.md — the acceptance and test plan

| Field | Value |
|---|---|
| Path | `~/code-factory/docs/ACCEPTANCE-PLAN.md` |
| Repository | `code-factory` |
| Revision | `8f77667b` |
| Status | **VERIFIED — the plan is described from its own rules; its arm-census claim is re-measured with the repo's own instrument at this revision** |

## 1. Purpose and why it matters

The bridge between the PRD's requirements and the tests that can actually fail: it scopes
CF-101–CF-112 and states up front that a passing repository self-test is not proof that
every requirement is accepted (`docs/ACCEPTANCE-PLAN.md:3-5`). Its discipline is
instrumented honesty: the plan carries exactly ONE arm-census claim, and that sentence is
graded by two committed instruments — the section-mapping script grades "the tree carries
N arms" and the drift probe grades the section phrase, so both instruments read one number
(`docs/ACCEPTANCE-PLAN.md:15`) [fact: FACT-11]. What breaks if it is absent: requirements
and tests drift apart silently. What breaks if it lies: an arm count quoted from memory —
which is why every figure on the census line is pinned to a named tip and must be
re-measured, not quoted.

## 2. Dependencies and library contracts

| Dependency | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `bash docs/audits/cf198-section-mapping.sh` | this repo | grades the arm-census sentence; must end `RESULT: OK` (`docs/ACCEPTANCE-PLAN.md:15`) | the plan and the tree's arm count disagree without a red |
| `bash docs/audits/cf099-prd-drift-probe.sh` | this repo | grades the "N numbered sections" phrase on the same line (`docs/ACCEPTANCE-PLAN.md:15`) | the second half of the census claim goes ungraded |
| `docs/PRD-code-factory.md` | this repo | the requirement ids this plan maps to tests (record 57) | the mapping rows and the requirement table diverge |
| `tests/selftest.sh` | this repo | the suite whose arms the plan counts [fact: FACT-11] | the census claim counts arms that no longer exist |

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| every locator on this page resolves | `python3 scripts/master_doc_check.py docs/handbook/appendices/units --only 59- --strict` | `MASTER-DOC: PASS` | 2026-11-22 | PASS |
| the arm census instrument agrees with the plan | `bash docs/audits/cf198-section-mapping.sh` | `RESULT: OK` | 2026-11-22 at `8f77667b` | PASS — `arms_plan=80 arms_tree=80` |
| the requirement-to-test matrix exists | `sed -n 90p docs/ACCEPTANCE-PLAN.md` | the matrix section heading | 2026-11-22 | PASS |

## 4. Metrics emitted

None as counters. The plan's measurable output is the census instruments' verdicts and the
evidence commands section — a list of exact commands whose output IS the acceptance state
(`docs/ACCEPTANCE-PLAN.md:255`) — plus dated evidence snapshots, each pinned to the tip it
was measured at (`docs/ACCEPTANCE-PLAN.md:19-30`).

## 5. Log lines it can generate

- Through its instruments: `arms_plan=80 arms_tree=80` + `RESULT: OK` from the section
  mapping, and the drift probe's `OK: milestone, plan snapshot and layer arms agree at
  <tip>` — the two lines that prove the plan's single census claim (`docs/ACCEPTANCE-PLAN.md:15`).
- A red instrument prints the offending phrase and side, which is how a plan-side drift is
  named rather than absorbed.

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| An arm count quoted from an old tip | the census line "lies" | the rule: every number is pinned to a named tip; re-measure (`docs/ACCEPTANCE-PLAN.md:15-19`) | re-run the instruments at the current tip |
| Suite greens quoted as acceptance | requirements marked accepted by selftest alone | the scope line refuses that: source evidence vs tests actually run (`docs/ACCEPTANCE-PLAN.md:3-5`) | use the requirement-to-test matrix rows |
| A mapping row missing | selftest §39 fails with a named plan-side row | the instrument's own red arm (`docs/ACCEPTANCE-PLAN.md:15`) | add the mapping row in the same change |

## 7. Environment and settings it reads

| setting | source | requirement |
|---|---|---|
| requirement ids | CF-101–CF-112 as board rows (the CF-421 mapping, `docs/ACCEPTANCE-PLAN.md:5`) | a requirement id is a requirement, never a task |
| the suite | `tests/selftest.sh` [fact: FACT-11] | the arms the census counts |
| host environment | `~/.local/bin` on PATH etc. | some legs need a configured host; the plan records both legs' measurements (`:7-9`) |

## 8. Evidence of record

- The plan: scope + honesty rule `docs/ACCEPTANCE-PLAN.md:3-5`, id mapping `:5`,
  instrumented census claim `:15`, unconfigured-host leg `:7-9`, evidence snapshots
  `:19-30`, requirement-to-test matrix `:90`, exact evidence commands `:255`.
- The instruments: `docs/audits/cf198-section-mapping.sh` (run 2026-11-22:
  `arms_plan=80 arms_tree=80`, `RESULT: OK`) and `docs/audits/cf099-prd-drift-probe.sh`.
- Harness acceptance is battery-gated, not install-gated: fact: FACT-08; the suite the
  arms belong to: record 45 [fact: FACT-11].
