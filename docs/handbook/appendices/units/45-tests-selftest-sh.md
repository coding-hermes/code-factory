# 45. tests/selftest.sh — the commit gate battery

| Field | Value |
|---|---|
| Path | `~/code-factory/tests/selftest.sh` |
| Repository | `code-factory` |
| Revision | `8f77667b` |
| Status | **VERIFIED — the battery is described from its own source and its wiring to the commit guard is read from the guard config; both checks below were re-run at this revision** |

## 1. Purpose and why it matters

The one script every commit answers to: it proves the checks in this repo can FAIL, and a
green that cannot go red is decoration (`tests/selftest.sh:2`). The commit guard runs the
whole suite on every commit — `test_command: bash tests/selftest.sh` with `test_mode: full`
and a 900 s cap [fact: FACT-11]. What breaks if it is absent: every other record's
"Verification" row becomes an author's claim with no referee. What breaks if it lies: a
`SELFTEST: PASS` that a cannot-fail arm produced — which is why the failure counter only
counts real `selftest_fail()` calls and records the `  FAIL  ` row that made each increment
(`tests/selftest.sh:74-92`).

## 2. Dependencies and library contracts

| Dependency | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `scripts/lib.sh` | this repo | `ok`/`bad`/`warn` rows, `FAILED` counter — the battery sources it first (`tests/selftest.sh:5`) | every arm's row vocabulary shifts; the summary counters are the contract |
| `bash` with `set -uo pipefail` | host | unset variables and pipe failures abort the run rather than pass silently (`tests/selftest.sh:3`) | a weaker mode turns crashed arms into quiet greens |
| `python3` | host | most arms drive repo scripts and pytest legs through it | arms fail loudly, not wrongly |
| git | host | arms build fixture clones and read the board from refs | fixture arms fail, not the suite |

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| the arm census instrument agrees with the plan | `bash docs/audits/cf198-section-mapping.sh` | `arms_tree=80`, `RESULT: OK` | 2026-11-22 at `8f77667b` | PASS — `arms_plan=80 arms_tree=80` |
| every locator on this page resolves | `python3 scripts/master_doc_check.py docs/handbook/appendices/units --only 45- --strict` | `MASTER-DOC: PASS` | 2026-11-22 | PASS |
| the suite itself | `bash tests/selftest.sh` | `SELFTEST: PASS`, exit 0 | 2026-11-22 | PASS — see the commit body for the measured row counts |

## 4. Metrics emitted

None as counters — the suite is a build step, not a service. Its measurable output is the
row stream: one `  PASS  `/`  FAIL  ` row per arm plus the two summary lines, and the arm
count itself is measured by `docs/audits/cf198-section-mapping.sh`, not by the suite.

## 5. Log lines it can generate

- `SELFTEST: PASS` when the failure counter is zero (`tests/selftest.sh:32`).
- `SELFTEST: FAIL (n)` with n = counted `selftest_fail()` increments (`tests/selftest.sh:42`).
- `  FAIL  <arm> — <reason>` — the row an increment records, so a red run names its arms
  instead of leaving them to be diffed out of a log (`tests/selftest.sh:92`).

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| An arm that cannot fail | a green row for a check with no refusal path | a real green: the arm's negative fixture is named in its comment | the arm is the defect; fix the arm, not the suite |
| Fixture `FAIL` rows read as regressions | ~19–50 `  FAIL  ` rows inside a passing run | these are intentional negative fixtures asserting rejections; the counter stays at zero | read the counter line, not the row stream |
| Timeout under host load | the guard's 900 s cap kills the suite | a red verdict: a cut-off run fails closed, never pass-open (`.gitreins/config.yaml:19-22`) | re-run on a quieter host; the cap is a guard property |

## 7. Environment and settings it reads

| setting | source | requirement |
|---|---|---|
| `PATH` including `~/.local/bin` | operator host | tool-installing arms measure real binaries; a missing PATH produced a measured `SELFTEST: FAIL (2)` on an unconfigured host (docs/ACCEPTANCE-PLAN.md:9) |
| `TMPDIR`-adjacent scratch | host | fixture homes are throwaway dirs; the toolchain cache deliberately crosses the isolation boundary (`tests/selftest.sh:7-12`) |
| guard wiring | `.gitreins/config.yaml` | `test_mode: full`, `test_timeout: 900`, hook timeout above it so a cut-off run cannot report green [fact: FACT-11] |

## 8. Evidence of record

- The script itself, cited by line: header law `tests/selftest.sh:2`, shell mode `:5`,
  summary pair `:32`/`:42`, counter contract `:74-92`.
- The guard wiring that makes it the commit gate: `.gitreins/config.yaml:16-22`
  [fact: FACT-11]; the arm census instrument `docs/audits/cf198-section-mapping.sh`,
  run 2026-11-22: `arms_plan=80 arms_tree=80`, `RESULT: OK`.
- The acceptance plan's census claim pins this file's arm count as its own single claim:
  docs/ACCEPTANCE-PLAN.md:15.
- Harness support is graded by battery legs, not installs: fact: FACT-08 governs the
  conformance arm this battery shares with `tests/harness-conformance.sh`.
