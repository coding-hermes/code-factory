# Verdict: CF-192

**Task:** P3 — install-hermes.sh turns its own public-bind auth gate OFF when a listener already occupies the port: --apply prints PASS port / PASS status_probe / HERMES: PASS on a config with no basic_auth
**Evaluated:** 2026-11-04T09:59:02.400742
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ The commit appends exactly one row to .coding-hermes/board/tasks.jsonl with id CF-192 (or the next free CF id if a sibling consumed it), status pending, a non-empty one-line probe that reproduces the occupied-port fail-open, and numbered acceptance criteria AC0-AC3; it also appends one task_created event to .coding-hermes/board/events.jsonl for that row. No other row is modified and no source file is changed.: Commit e5f52c5 touches only .coding-hermes/board/tasks.jsonl (+1) and .coding-hermes/board/events.jsonl (+1) — `git diff --name-only HEAD^ HEAD` lists no source files; working tree clean. tasks.jsonl: 165 -> 166 rows, prefix byte-identical (old==new[:165] True), 0 duplicate ids, exactly one row with id CF-192 and status "pending". Probe is non-empty (1011 chars, 0 newlines = one line) and was executed: it printed `PASS  port — listening on :10800`, `PASS  status_probe — /api/status -> 200`, `HERMES: PASS`, `auth_refusal_rows=0` with EXIT=0 — reproducing the occupied-port fail-open (root cause confirmed at scripts/harness/install-hermes.sh:251, where `check_public_bind_auth` and the gateway start are guarded by `if ! (command -v ss && ss -tln | grep -q ":$PORT ")`). acceptance_criteria is a numbered string containing AC0, AC1, AC2, AC3 (regex AC0–AC3 all present). events.jsonl: 333 -> 334, prefix identical, exactly one added event {id:334, event_type:"task_created", task_id:"CF-192"}. `bash scripts/boardctl validate` -> RESULT: OK (3 pre-existing warnings, none on CF-192).
The commit is a pure insert-only board append: one pending CF-192 row with a verified one-line reproducing probe and numbered AC0–AC3, plus one task_created event, with no other row or source file touched.

## Summary

Judge Result: CF-192

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ The commit appends exactly one row to .coding-hermes/board/tasks.jsonl with id CF-192 (or the next free CF id if a sibling consumed it), status pending, a non-empty one-line probe that reproduces the occupied-port fail-open, and numbered acceptance criteria AC0-AC3; it also appends one task_created event to .coding-hermes/board/events.jsonl for that row. No other row is modified and no source file is changed.: Commit e5f52c5 touches only .coding-hermes/board/tasks.jsonl (+1) and .coding-hermes/board/events.jsonl (+1) — `git diff --name-only HEAD^ HEAD` lists no source files; working tree clean. tasks.jsonl: 165 -> 166 rows, prefix byte-identical (old==new[:165] True), 0 duplicate ids, exactly one row with id CF-192 and status "pending". Probe is non-empty (1011 chars, 0 newlines = one line) and was executed: it printed `PASS  port — listening on :10800`, `PASS  status_probe — /api/status -> 200`, `HERMES: PASS`, `auth_refusal_rows=0` with EXIT=0 — reproducing the occupied-port fail-open (root cause confirmed at scripts/harness/install-hermes.sh:251, where `check_public_bind_auth` and the gateway start are guarded by `if ! (command -v ss && ss -tln | grep -q ":$PORT ")`). acceptance_criteria is a numbered string containing AC0, AC1, AC2, AC3 (regex AC0–AC3 all present). events.jsonl: 333 -> 334, prefix identical, exactly one added event {id:334, event_type:"task_created", task_id:"CF-192"}. `bash scripts/boardctl validate` -> RESULT: OK (3 pre-existing warnings, none on CF-192).
The commit is a pure insert-only board append: one pending CF-192 row with a verified one-line reproducing probe and numbered AC0–AC3, plus one task_created event, with no other row or source file touched.

Overall: PASS ✓
