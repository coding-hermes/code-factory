# Verdict: CF-241-QA1

**Task:** QA filing: CF-241 (CF-206 shipped patch is unapplyable) + reopen CF-206 AC6
**Evaluated:** 2026-11-05T11:44:01.467732
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Filing-only criterion. Verify only the filing: (1) git show --name-only HEAD names exactly .coding-hermes/board/tasks.jsonl and .coding-hermes/board/events.jsonl; (2) committed CF-241 status=pending with probe length >0 and CF-206 status=in_progress; (3) committed probe runs from repo root printing patch=patches/fleet-ops-shell-toolkit.patch and apply_check_rc=; (4) bash tests/selftest.sh prints SELFTEST: PASS and bash scripts/boardctl validate prints RESULT: OK: All 4 legs verified at HEAD=1abb6c8b, tree clean. (1) `git show --name-only HEAD` (exit_code=0) lists exactly `.coding-hermes/board/events.jsonl` and `.coding-hermes/board/tasks.jsonl` (2 files changed, 5 insertions, 1 deletion) — no fleet_ops_check.py or patches/ path touched. (2) `git show HEAD:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-241") | [.status, ((.probe//"")|length)] | @tsv'` printed `pending	296` (pending, probe length 296 > 0) and the CF-206 select printed `in_progress`, exit_code=0. (3) Probe extracted from the COMMITTED board to /tmp/cf241-probe.sh and run from repo root; literal output: `patch=patches/fleet-ops-shell-toolkit.patch target=fleet_ops_check.py target_at_head=absent apply_check_rc=1` — a single line carrying the required patch= value and a measured apply_check_rc (=1), probe exit 0. (4) `bash tests/selftest.sh` (exit_code=0) prints `SELFTEST: PASS`; `bash scripts/boardctl validate` (exit_code=0) prints `RESULT: OK (4 warning(s))`, matching the 4 pre-existing warnings cited in the commit message.
The QA filing commit cleanly touches only the two board files; the committed board carries CF-241 pending with a 296-char runnable probe (which runs and reports patch=patches/fleet-ops-shell-toolkit.patch with apply_check_rc=1), reopens CF-206 to in_progress, and both selftest and boardctl validate pass.

## Summary

Judge Result: CF-241-QA1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Filing-only criterion. Verify only the filing: (1) git show --name-only HEAD names exactly .coding-hermes/board/tasks.jsonl and .coding-hermes/board/events.jsonl; (2) committed CF-241 status=pending with probe length >0 and CF-206 status=in_progress; (3) committed probe runs from repo root printing patch=patches/fleet-ops-shell-toolkit.patch and apply_check_rc=; (4) bash tests/selftest.sh prints SELFTEST: PASS and bash scripts/boardctl validate prints RESULT: OK: All 4 legs verified at HEAD=1abb6c8b, tree clean. (1) `git show --name-only HEAD` (exit_code=0) lists exactly `.coding-hermes/board/events.jsonl` and `.coding-hermes/board/tasks.jsonl` (2 files changed, 5 insertions, 1 deletion) — no fleet_ops_check.py or patches/ path touched. (2) `git show HEAD:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-241") | [.status, ((.probe//"")|length)] | @tsv'` printed `pending	296` (pending, probe length 296 > 0) and the CF-206 select printed `in_progress`, exit_code=0. (3) Probe extracted from the COMMITTED board to /tmp/cf241-probe.sh and run from repo root; literal output: `patch=patches/fleet-ops-shell-toolkit.patch target=fleet_ops_check.py target_at_head=absent apply_check_rc=1` — a single line carrying the required patch= value and a measured apply_check_rc (=1), probe exit 0. (4) `bash tests/selftest.sh` (exit_code=0) prints `SELFTEST: PASS`; `bash scripts/boardctl validate` (exit_code=0) prints `RESULT: OK (4 warning(s))`, matching the 4 pre-existing warnings cited in the commit message.
The QA filing commit cleanly touches only the two board files; the committed board carries CF-241 pending with a 296-char runnable probe (which runs and reports patch=patches/fleet-ops-shell-toolkit.patch with apply_check_rc=1), reopens CF-206 to in_progress, and both selftest and boardctl validate pass.

Overall: PASS ✓
