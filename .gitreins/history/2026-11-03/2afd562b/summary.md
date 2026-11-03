# Verdict: CF-094

**Task:** QA filing: the Tier-1 lint arm skips silently when ruff is absent (format violation still passes)
**Evaluated:** 2026-11-03T17:53:30.646711
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ This task grades the FILING ONLY, not the repair. At the graded commit: (a) .coding-hermes/board/tasks.jsonl contains a row with id CF-094 and status pending whose acceptance_criteria state a check that can fail for each gap; (b) docs/audits/cf094-lint-skip-arms.sh and its committed transcript docs/audits/cf094-lint-skip-arms.txt are present in that same tree, the script is syntactically valid (bash -n exits 0), and the transcript shows both arms: with ruff on PATH the guard lint check fails and guard.passed is false, while with PATH=/usr/local/bin:/usr/bin:/bin the lint check reports outcome unknown and guard.passed is true with the same violating file staged; (c) bash scripts/boardctl validate prints RESULT: OK and bash tests/selftest.sh prints SELFTEST: PASS at that tree. The repair described by CF-094 is future work tracked by the pending row and is NOT expected at this commit.: (a) .coding-hermes/board/tasks.jsonl:81 has {"id":"CF-094",...,"status":"pending"} with 4 numbered acceptance_criteria, each falsifiable: AC1 requires arm 2 to show GUARD_EXIT nonzero and guard.passed:false (currently 0/true), AC2 requires a repo-declared pinned ruff version, AC3 requires allow_skips:false to govern the skip class or be documented in docs/OPERATIONS.md, AC4 requires SELFTEST: PASS at the fixed tip. (b) Both files present in the same tree (docs/audits/cf094-lint-skip-arms.sh 3043 bytes, docs/audits/cf094-lint-skip-arms.txt 1590 bytes); `bash -n docs/audits/cf094-lint-skip-arms.sh` -> exit 0. Transcript shows control (ruff format --check EXIT: 1), arm 1 'GUARD_EXIT: 1 / lint.outcome: fail / lint.passed: false / guard.passed: false / guard.outcome: fail', and arm 2 'PATH=/usr/local/bin:/usr/bin:/bin ... GUARD_EXIT: 0 / lint.outcome: unknown / lint.passed: null / lint.summary: skipped — no linter on PATH / guard.passed: true / guard.outcome: pass' with the same staged fixture (script does `git reset -q; git add "$FIXTURE"` before arm 2). (c) `bash scripts/boardctl validate` -> 'RESULT: OK (26 warning(s))', exit 0; `bash tests/selftest.sh` -> 'SELFTEST: PASS' (log line 86), exit 0 — the 'FAIL disk_floor' line at log:55 is an intentional negative-path assertion inside test 16 (surrounded by PASS lines), not a suite failure. Working tree clean at 5fc1f9e5516e367a471d0da9d41b6ec2499cbc47; no repair code is present, consistent with the filing-only scope.
Filing-only task verified at 5fc1f9e: pending CF-094 row with falsifiable ACs, both audit artifacts present with bash -n exit 0 and a transcript showing both arms (fail/false with ruff, unknown/true without), boardctl validate RESULT: OK and selftest SELFTEST: PASS.

## Summary

Judge Result: CF-094

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ This task grades the FILING ONLY, not the repair. At the graded commit: (a) .coding-hermes/board/tasks.jsonl contains a row with id CF-094 and status pending whose acceptance_criteria state a check that can fail for each gap; (b) docs/audits/cf094-lint-skip-arms.sh and its committed transcript docs/audits/cf094-lint-skip-arms.txt are present in that same tree, the script is syntactically valid (bash -n exits 0), and the transcript shows both arms: with ruff on PATH the guard lint check fails and guard.passed is false, while with PATH=/usr/local/bin:/usr/bin:/bin the lint check reports outcome unknown and guard.passed is true with the same violating file staged; (c) bash scripts/boardctl validate prints RESULT: OK and bash tests/selftest.sh prints SELFTEST: PASS at that tree. The repair described by CF-094 is future work tracked by the pending row and is NOT expected at this commit.: (a) .coding-hermes/board/tasks.jsonl:81 has {"id":"CF-094",...,"status":"pending"} with 4 numbered acceptance_criteria, each falsifiable: AC1 requires arm 2 to show GUARD_EXIT nonzero and guard.passed:false (currently 0/true), AC2 requires a repo-declared pinned ruff version, AC3 requires allow_skips:false to govern the skip class or be documented in docs/OPERATIONS.md, AC4 requires SELFTEST: PASS at the fixed tip. (b) Both files present in the same tree (docs/audits/cf094-lint-skip-arms.sh 3043 bytes, docs/audits/cf094-lint-skip-arms.txt 1590 bytes); `bash -n docs/audits/cf094-lint-skip-arms.sh` -> exit 0. Transcript shows control (ruff format --check EXIT: 1), arm 1 'GUARD_EXIT: 1 / lint.outcome: fail / lint.passed: false / guard.passed: false / guard.outcome: fail', and arm 2 'PATH=/usr/local/bin:/usr/bin:/bin ... GUARD_EXIT: 0 / lint.outcome: unknown / lint.passed: null / lint.summary: skipped — no linter on PATH / guard.passed: true / guard.outcome: pass' with the same staged fixture (script does `git reset -q; git add "$FIXTURE"` before arm 2). (c) `bash scripts/boardctl validate` -> 'RESULT: OK (26 warning(s))', exit 0; `bash tests/selftest.sh` -> 'SELFTEST: PASS' (log line 86), exit 0 — the 'FAIL disk_floor' line at log:55 is an intentional negative-path assertion inside test 16 (surrounded by PASS lines), not a suite failure. Working tree clean at 5fc1f9e5516e367a471d0da9d41b6ec2499cbc47; no repair code is present, consistent with the filing-only scope.
Filing-only task verified at 5fc1f9e: pending CF-094 row with falsifiable ACs, both audit artifacts present with bash -n exit 0 and a transcript showing both arms (fail/false with ruff, unknown/true without), boardctl validate RESULT: OK and selftest SELFTEST: PASS.

Overall: PASS ✓
