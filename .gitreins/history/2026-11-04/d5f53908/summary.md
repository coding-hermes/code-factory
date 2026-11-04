# Verdict: CF-169-DOC1

**Task:** Correct the scheduler-validates-8x-floor claim in docs/SCHEDULER-ADMISSION.md
**Evaluated:** 2026-11-04T07:12:49.209203
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ docs/SCHEDULER-ADMISSION.md no longer asserts that the scheduler API validates an enabled satellite's floor and ceiling pair at 8 x floor: the paragraph names the two shipped checks that actually run (laneIsUnarmed and validateLaneArming in coding-hermes/scheduler internal/api/lane_onboarding.go) and states the measured live ceiling/floor ratios, with the same-commit evidence file docs/audits/code-factory-docs-2026-11-04-cf169-validator-claim.md quoting the command and its output; bash tests/selftest.sh exits 0 at that commit. This is a documentation correction only: no scheduler or script behaviour change is expected.: docs/SCHEDULER-ADMISSION.md:44-56 replaces the old 'must have ... 8 x floor ... The scheduler/API validates the row before it is written or enabled' text (removed in commit 6fd2279 diff) with 'That is a provisioning expectation, not a gate: the shipped API refuses only the fully unarmed state. `laneIsUnarmed` is true when adaptive_cooldown=0 and floor<=0 and ceiling<=0 (`coding-hermes/scheduler` `internal/api/lane_onboarding.go:269-271`), and `validateLaneArming` refuses exactly that state and nothing else (`:303-310`)' — both shipped checks named with file:line. Measured live ratios stated at lines 53-55: 'carried ceiling/floor ratios of 8x (docs, perf, qa, readme, review), 16x, 48x, 192x, 224x and 576x, every row enabled.' Evidence file docs/audits/code-factory-docs-2026-11-04-cf169-validator-claim.md is in the SAME commit (git show HEAD --name-only lists only docs/SCHEDULER-ADMISSION.md and docs/audits/code-factory-docs-2026-11-04-cf169-validator-claim.md) and quotes the command plus literal output: lines 62-90 show `$ sqlite3 -header -column ~/.hermes/coding-hermes/scheduler.db "select name, cooldown_floor_s floor, cooldown_ceiling_s ceil, ... ratio ..."` with the 17-row table (8/16/48/192/224/576 ratios), and line 122/156 record `bash tests/selftest.sh` -> `SELFTEST: PASS`, rc 0. I ran `bash tests/selftest.sh` fresh: output ends 'SELFTEST: PASS', EXIT=0. Doc-only: commit stat shows 2 files, 186 insertions, 8 deletions, no scheduler or script files touched.
The 8x-floor validation claim is corrected with both shipped checks named, measured live ratios stated, same-commit evidence quoting command output, and selftest exits 0.

## Summary

Judge Result: CF-169-DOC1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ docs/SCHEDULER-ADMISSION.md no longer asserts that the scheduler API validates an enabled satellite's floor and ceiling pair at 8 x floor: the paragraph names the two shipped checks that actually run (laneIsUnarmed and validateLaneArming in coding-hermes/scheduler internal/api/lane_onboarding.go) and states the measured live ceiling/floor ratios, with the same-commit evidence file docs/audits/code-factory-docs-2026-11-04-cf169-validator-claim.md quoting the command and its output; bash tests/selftest.sh exits 0 at that commit. This is a documentation correction only: no scheduler or script behaviour change is expected.: docs/SCHEDULER-ADMISSION.md:44-56 replaces the old 'must have ... 8 x floor ... The scheduler/API validates the row before it is written or enabled' text (removed in commit 6fd2279 diff) with 'That is a provisioning expectation, not a gate: the shipped API refuses only the fully unarmed state. `laneIsUnarmed` is true when adaptive_cooldown=0 and floor<=0 and ceiling<=0 (`coding-hermes/scheduler` `internal/api/lane_onboarding.go:269-271`), and `validateLaneArming` refuses exactly that state and nothing else (`:303-310`)' — both shipped checks named with file:line. Measured live ratios stated at lines 53-55: 'carried ceiling/floor ratios of 8x (docs, perf, qa, readme, review), 16x, 48x, 192x, 224x and 576x, every row enabled.' Evidence file docs/audits/code-factory-docs-2026-11-04-cf169-validator-claim.md is in the SAME commit (git show HEAD --name-only lists only docs/SCHEDULER-ADMISSION.md and docs/audits/code-factory-docs-2026-11-04-cf169-validator-claim.md) and quotes the command plus literal output: lines 62-90 show `$ sqlite3 -header -column ~/.hermes/coding-hermes/scheduler.db "select name, cooldown_floor_s floor, cooldown_ceiling_s ceil, ... ratio ..."` with the 17-row table (8/16/48/192/224/576 ratios), and line 122/156 record `bash tests/selftest.sh` -> `SELFTEST: PASS`, rc 0. I ran `bash tests/selftest.sh` fresh: output ends 'SELFTEST: PASS', EXIT=0. Doc-only: commit stat shows 2 files, 186 insertions, 8 deletions, no scheduler or script files touched.
The 8x-floor validation claim is corrected with both shipped checks named, measured live ratios stated, same-commit evidence quoting command output, and selftest exits 0.

Overall: PASS ✓
