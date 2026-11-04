# Verdict: CF-152-QA1

**Task:** QA filing: CF-152 — verify-node.sh certifies the auth gate from a fixed /tmp path a second run rewrites (open gateway prints auth_gate PASS)
**Evaluated:** 2026-11-04T02:50:48.599113
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Filing-only task for board row CF-152. Do NOT evaluate the underlying fix: the row is pending by definition, and no repair of scripts/verify-node.sh is expected in this commit.

1. `git show --stat --format= HEAD` names `.coding-hermes/board/tasks.jsonl` and `.coding-hermes/board/events.jsonl`, and the tasks.jsonl diff is insert-only (+1/-0).: `git show --stat --format= HEAD` -> `.coding-hermes/board/events.jsonl | 1 +` and `.coding-hermes/board/tasks.jsonl | 1 +`, 2 files changed, 2 insertions(+). `git show --numstat --format= HEAD` -> `1\t0\t.coding-hermes/board/events.jsonl` and `1\t0\t.coding-hermes/board/tasks.jsonl`, i.e. insert-only +1/-0. Diff hunk is `@@ -123,3 +123,4 @@` (one appended line). No scripts/verify-node.sh change in the commit, consistent with filing-only.
  ✓ 2. `git show HEAD:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-152") | [.id,.status,((.probe//"")|length)] | @tsv'` prints `CF-152	pending	<n>` with n greater than 500.: Command output: `CF-152\tpending\t1088` — status is `pending` and probe length 1088 > 500.
  ✓ 3. Extract the probe with `jq -r 'select(.id=="CF-152").probe' .coding-hermes/board/tasks.jsonl > /tmp/cf152-probe.sh` and run `bash /tmp/cf152-probe.sh` from the repository root. It must print `armA_rc=1`, `armB_rc=0`, and the line `  PASS  auth_gate — auth_required:true (a public bind must not be open)`, and must exit 0.: Probe extracted to /tmp/cf152-probe.sh and run from repo root. Output: `ARM_A_no_second_writer:` / `  FAIL  auth_gate — /api/status -> 200; auth_required:true not measured` / `VERIFY: FAIL (1)` / `armA_rc=1`; `ARM_B_shared_path_rewritten:` / `  PASS  auth_gate — auth_required:true (a public bind must not be open)` / `VERIFY: PASS` / `armB_rc=0`; `PROBE_EXIT=0`. All three required strings present and exit 0.
  ✓ 4. `bash scripts/boardctl validate` prints `RESULT: OK` and `bash tests/selftest.sh` prints `SELFTEST: PASS`.: `bash scripts/boardctl validate` -> `RESULT: OK (55 warning(s))`, exit 0 (warnings are pre-existing canon-drift notes, e.g. `tasks.jsonl line 126 (task CF-152): key(s) {probe} outside the declared canon`, not errors). `bash tests/selftest.sh` -> final line `SELFTEST: PASS`, exit 0 (verified with a clean redirect run: SELFTEST_EXIT=0; an earlier exit 2 came from my own `${PIPESTATUS[0]}` under sh, not the suite).
  ✓ 5. The row carries non-empty `reasoning`, `acceptance_criteria` and `probe` fields, and the board has no duplicate ids.: jq on CF-152: reasoning_len=1450, acceptance_criteria_len=951, probe_len=1088 — all non-empty. `jq -r '.id' .coding-hermes/board/tasks.jsonl | sort | uniq -d` produced no output, so no duplicate ids (boardctl also reports 126 tasks, 187 events, 0 fixtures).
All five criteria verified: the commit is an insert-only board filing (+1 tasks.jsonl, +1 events.jsonl), CF-152 is pending with a 1088-char probe that reproduces armA_rc=1/armB_rc=0 and the auth_gate PASS line with exit 0, boardctl validate prints RESULT: OK, selftest prints SELFTEST: PASS, and the row has non-empty reasoning/acceptance_criteria/probe with no duplicate ids.

## Summary

Judge Result: CF-152-QA1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Filing-only task for board row CF-152. Do NOT evaluate the underlying fix: the row is pending by definition, and no repair of scripts/verify-node.sh is expected in this commit.

1. `git show --stat --format= HEAD` names `.coding-hermes/board/tasks.jsonl` and `.coding-hermes/board/events.jsonl`, and the tasks.jsonl diff is insert-only (+1/-0).: `git show --stat --format= HEAD` -> `.coding-hermes/board/events.jsonl | 1 +` and `.coding-hermes/board/tasks.jsonl | 1 +`, 2 files changed, 2 insertions(+). `git show --numstat --format= HEAD` -> `1\t0\t.coding-hermes/board/events.jsonl` and `1\t0\t.coding-hermes/board/tasks.jsonl`, i.e. insert-only +1/-0. Diff hunk is `@@ -123,3 +123,4 @@` (one appended line). No scripts/verify-node.sh change in the commit, consistent with filing-only.
  ✓ 2. `git show HEAD:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-152") | [.id,.status,((.probe//"")|length)] | @tsv'` prints `CF-152	pending	<n>` with n greater than 500.: Command output: `CF-152\tpending\t1088` — status is `pending` and probe length 1088 > 500.
  ✓ 3. Extract the probe with `jq -r 'select(.id=="CF-152").probe' .coding-hermes/board/tasks.jsonl > /tmp/cf152-probe.sh` and run `bash /tmp/cf152-probe.sh` from the repository root. It must print `armA_rc=1`, `armB_rc=0`, and the line `  PASS  auth_gate — auth_required:true (a public bind must not be open)`, and must exit 0.: Probe extracted to /tmp/cf152-probe.sh and run from repo root. Output: `ARM_A_no_second_writer:` / `  FAIL  auth_gate — /api/status -> 200; auth_required:true not measured` / `VERIFY: FAIL (1)` / `armA_rc=1`; `ARM_B_shared_path_rewritten:` / `  PASS  auth_gate — auth_required:true (a public bind must not be open)` / `VERIFY: PASS` / `armB_rc=0`; `PROBE_EXIT=0`. All three required strings present and exit 0.
  ✓ 4. `bash scripts/boardctl validate` prints `RESULT: OK` and `bash tests/selftest.sh` prints `SELFTEST: PASS`.: `bash scripts/boardctl validate` -> `RESULT: OK (55 warning(s))`, exit 0 (warnings are pre-existing canon-drift notes, e.g. `tasks.jsonl line 126 (task CF-152): key(s) {probe} outside the declared canon`, not errors). `bash tests/selftest.sh` -> final line `SELFTEST: PASS`, exit 0 (verified with a clean redirect run: SELFTEST_EXIT=0; an earlier exit 2 came from my own `${PIPESTATUS[0]}` under sh, not the suite).
  ✓ 5. The row carries non-empty `reasoning`, `acceptance_criteria` and `probe` fields, and the board has no duplicate ids.: jq on CF-152: reasoning_len=1450, acceptance_criteria_len=951, probe_len=1088 — all non-empty. `jq -r '.id' .coding-hermes/board/tasks.jsonl | sort | uniq -d` produced no output, so no duplicate ids (boardctl also reports 126 tasks, 187 events, 0 fixtures).
All five criteria verified: the commit is an insert-only board filing (+1 tasks.jsonl, +1 events.jsonl), CF-152 is pending with a 1088-char probe that reproduces armA_rc=1/armB_rc=0 and the auth_gate PASS line with exit 0, boardctl validate prints RESULT: OK, selftest prints SELFTEST: PASS, and the row has non-empty reasoning/acceptance_criteria/probe with no duplicate ids.

Overall: PASS ✓
