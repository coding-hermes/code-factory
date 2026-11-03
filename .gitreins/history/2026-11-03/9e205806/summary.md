# Verdict: CF-128-QA1

**Task:** docs-QA filing: CF-128 (selftest section 29 has no Git-path/ancestry fixture) and CF-129 (docs/BOARD.md --repo claim contradicted by the ancestry leg)
**Evaluated:** 2026-11-03T21:08:12.857460
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Filing-only task for the code-factory docs-QA lane (tick code-factory-docs-qa-2026-11-03-20-47-54). Do NOT implement or grade the fixes the two rows describe; the rows are pending by definition. Verify only that the filing landed and that each row's own probe reproduces.

The two rows were drafted as CF-125/CF-126 and renumbered to CF-128/CF-129 at append time because a sibling lane consumed the drafted ids three minutes earlier (committed at 8df6b38, a README Quick-start dogfood walk — unrelated subject). The superseded GitReins task CF-125-QA1 was deleted before this task was created.

1. The closing commit is board-only: `git show --stat --oneline HEAD` lists exactly .coding-hermes/board/tasks.jsonl and .coding-hermes/board/events.jsonl with insertions only (no deletions).
2. The COMMITTED tree carries both rows as pending with a non-empty probe:
   `git show HEAD:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-128" or .id=="CF-129") | .id + " " + .status + " probe_len=" + (.probe|length|tostring)'`
   prints two lines, each ending probe_len > 500.
3. CF-128's probe (extracted from the committed row with `jq -r 'select(.id=="CF-128").probe'`, written to a file, run as `bash <file>` from the repository root) prints exactly:
   mutation_lines=1
   mutated_selftest_rc=0
   publish_drift_arms_green=7
   selftest_verdict=SELFTEST: PASS
   control_ancestry_rows=1
   control_fail_ancestry_rows=1
   mutant_ancestry_rows=0
   Meaning: with the HEAD-ancestry block disabled the suite still prints SELFTEST: PASS (the gate cannot red it), while the unmodified tool does name the failure on a divergent fixture.
4. CF-129's probe (same extraction, run as `bash <file>` from the repository root) prints:
   repo_a_has_pub=0
   repo_b_has_pub=1
   PASS  published ref — pub:.coding-hermes/board/tasks.jsonl resolved
   PASS  published ref — pub:.coding-hermes/board/events.jsonl resolved
   PASS  byte parity tasks.jsonl — identical
   PASS  byte parity events.jsonl — identical
   FAIL  HEAD ancestry — git rev-parse --verify pub^{commit}: exit 128; fatal: Needed a single revision
   RESULT: DRIFT (1 failed)
   with_repo_rc=1
   no_head_result=RESULT: OK no_head_rc=0
5. Gate at HEAD: `bash tests/selftest.sh` prints SELFTEST: PASS and `bash scripts/boardctl validate` prints RESULT: OK.
6. Publication: `git rev-parse HEAD` equals `git rev-parse gh/main` (this checkout's `origin` is a local filesystem path, so parity is measured against the published `gh` remote).: All six sub-conditions verified with live command output. (1) `git show --stat --oneline HEAD` = 481ba38, exactly `.coding-hermes/board/events.jsonl | 2 ++` and `.coding-hermes/board/tasks.jsonl | 2 ++`, '2 files changed, 4 insertions(+)'; `--numstat` confirms 2/0 and 2/0 (zero deletions); working tree clean. (2) Committed-tree jq prints 'CF-128 pending probe_len=1415' and 'CF-129 pending probe_len=1063' — both pending, both >500. (3) CF-128 probe extracted from committed row and run as `bash /tmp/cf128_probe.sh` from repo root printed verbatim: mutation_lines=1 / mutated_selftest_rc=0 / publish_drift_arms_green=7 / selftest_verdict=SELFTEST: PASS / control_ancestry_rows=1 / control_fail_ancestry_rows=1 / mutant_ancestry_rows=0 (rc=0) — exact match. (4) CF-129 probe run as `bash /tmp/cf129_probe.sh` printed verbatim: repo_a_has_pub=0 / repo_b_has_pub=1 / 4x PASS published-ref+byte-parity lines / 'FAIL  HEAD ancestry — git rev-parse --verify pub^{commit}: exit 128; fatal: Needed a single revision' / 'RESULT: DRIFT (1 failed)' / with_repo_rc=1 / no_head_result=RESULT: OK no_head_rc=0 — exact match. (5) `bash tests/selftest.sh` -> selftest_rc=0, tail 'SELFTEST: PASS'; `bash scripts/boardctl validate` -> validate_rc=0, final line 'RESULT: OK (44 warning(s))'. (6) `git rev-parse HEAD` = 481ba3896d9b57e09b5bcbea41dcf150c370e2bd = `git rev-parse gh/main`; origin url is /home/kara/code-factory (local path) as stated. Filing-only confirmed: both rows status=pending (fixes not implemented), events.jsonl gained exactly 2 task_created events (id 145 CF-128, id 146 CF-129, actor qa).


## Summary

Judge Result: CF-128-QA1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Filing-only task for the code-factory docs-QA lane (tick code-factory-docs-qa-2026-11-03-20-47-54). Do NOT implement or grade the fixes the two rows describe; the rows are pending by definition. Verify only that the filing landed and that each row's own probe reproduces.

The two rows were drafted as CF-125/CF-126 and renumbered to CF-128/CF-129 at append time because a sibling lane consumed the drafted ids three minutes earlier (committed at 8df6b38, a README Quick-start dogfood walk — unrelated subject). The superseded GitReins task CF-125-QA1 was deleted before this task was created.

1. The closing commit is board-only: `git show --stat --oneline HEAD` lists exactly .coding-hermes/board/tasks.jsonl and .coding-hermes/board/events.jsonl with insertions only (no deletions).
2. The COMMITTED tree carries both rows as pending with a non-empty probe:
   `git show HEAD:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-128" or .id=="CF-129") | .id + " " + .status + " probe_len=" + (.probe|length|tostring)'`
   prints two lines, each ending probe_len > 500.
3. CF-128's probe (extracted from the committed row with `jq -r 'select(.id=="CF-128").probe'`, written to a file, run as `bash <file>` from the repository root) prints exactly:
   mutation_lines=1
   mutated_selftest_rc=0
   publish_drift_arms_green=7
   selftest_verdict=SELFTEST: PASS
   control_ancestry_rows=1
   control_fail_ancestry_rows=1
   mutant_ancestry_rows=0
   Meaning: with the HEAD-ancestry block disabled the suite still prints SELFTEST: PASS (the gate cannot red it), while the unmodified tool does name the failure on a divergent fixture.
4. CF-129's probe (same extraction, run as `bash <file>` from the repository root) prints:
   repo_a_has_pub=0
   repo_b_has_pub=1
   PASS  published ref — pub:.coding-hermes/board/tasks.jsonl resolved
   PASS  published ref — pub:.coding-hermes/board/events.jsonl resolved
   PASS  byte parity tasks.jsonl — identical
   PASS  byte parity events.jsonl — identical
   FAIL  HEAD ancestry — git rev-parse --verify pub^{commit}: exit 128; fatal: Needed a single revision
   RESULT: DRIFT (1 failed)
   with_repo_rc=1
   no_head_result=RESULT: OK no_head_rc=0
5. Gate at HEAD: `bash tests/selftest.sh` prints SELFTEST: PASS and `bash scripts/boardctl validate` prints RESULT: OK.
6. Publication: `git rev-parse HEAD` equals `git rev-parse gh/main` (this checkout's `origin` is a local filesystem path, so parity is measured against the published `gh` remote).: All six sub-conditions verified with live command output. (1) `git show --stat --oneline HEAD` = 481ba38, exactly `.coding-hermes/board/events.jsonl | 2 ++` and `.coding-hermes/board/tasks.jsonl | 2 ++`, '2 files changed, 4 insertions(+)'; `--numstat` confirms 2/0 and 2/0 (zero deletions); working tree clean. (2) Committed-tree jq prints 'CF-128 pending probe_len=1415' and 'CF-129 pending probe_len=1063' — both pending, both >500. (3) CF-128 probe extracted from committed row and run as `bash /tmp/cf128_probe.sh` from repo root printed verbatim: mutation_lines=1 / mutated_selftest_rc=0 / publish_drift_arms_green=7 / selftest_verdict=SELFTEST: PASS / control_ancestry_rows=1 / control_fail_ancestry_rows=1 / mutant_ancestry_rows=0 (rc=0) — exact match. (4) CF-129 probe run as `bash /tmp/cf129_probe.sh` printed verbatim: repo_a_has_pub=0 / repo_b_has_pub=1 / 4x PASS published-ref+byte-parity lines / 'FAIL  HEAD ancestry — git rev-parse --verify pub^{commit}: exit 128; fatal: Needed a single revision' / 'RESULT: DRIFT (1 failed)' / with_repo_rc=1 / no_head_result=RESULT: OK no_head_rc=0 — exact match. (5) `bash tests/selftest.sh` -> selftest_rc=0, tail 'SELFTEST: PASS'; `bash scripts/boardctl validate` -> validate_rc=0, final line 'RESULT: OK (44 warning(s))'. (6) `git rev-parse HEAD` = 481ba3896d9b57e09b5bcbea41dcf150c370e2bd = `git rev-parse gh/main`; origin url is /home/kara/code-factory (local path) as stated. Filing-only confirmed: both rows status=pending (fixes not implemented), events.jsonl gained exactly 2 task_created events (id 145 CF-128, id 146 CF-129, actor qa).


Overall: PASS ✓
