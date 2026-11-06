# Verdict: CF-252

**Task:** CF-252 close: unservable-rating 503 regression is remedied in task-router (TR-361 slow always-run lane), proven by census + degrade tests
**Evaluated:** 2026-11-06T18:15:49.888680
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ 1. sqlite3 ~/.hermes/scheduler.db 'select count(*) from ticks where error like "%unservable-rating%" and spawned_at >= "2026-11-06T00:00"' returns 0 and the last such tick predates fix commit 0e8085e. 2. Same query over the pre-fix window 2026-11-04..2026-11-05T20:00 returns >0 (instrument can see both states). 3. cd ~/task-router && .venv/bin/python -m pytest -q tests/test_inferred_clamp_last_resort.py tests/test_tr361_slow_fallback.py passes.: (1) sqlite3 ~/.hermes/scheduler.db (symlink -> ~/.hermes/coding-hermes/scheduler.db) query for error like '%unservable-rating%' and spawned_at >= '2026-11-06T00:00' returned 0; max(spawned_at) over all such ticks = 2026-11-05T19:04:52-05:00 (773 total), which predates fix commit 0e8085e 'fix(TR-361): a SLOW always-run lane beats a 503 on the degraded path' dated Fri Nov 6 05:28:21 2026 -0500. (2) Same query over the pre-fix window (spawned_at >= '2026-11-04T00:00' and < '2026-11-05T20:00') returned 181 (>0), so the instrument distinguishes both states. (3) cd ~/task-router && .venv/bin/python -m pytest -q tests/test_inferred_clamp_last_resort.py tests/test_tr361_slow_fallback.py -> EXIT=0, output '................ [100%] 16 passed in 2.59s'; both test files present in ~/task-router/tests/.
All three legs verified with live command output: post-fix unservable-rating tick count is 0 (last such tick 2026-11-05T19:04:52 predates fix 0e8085e), the pre-fix window shows 181 occurrences, and the two named pytest files pass 16/16 with exit 0.

## Summary

Judge Result: CF-252

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ 1. sqlite3 ~/.hermes/scheduler.db 'select count(*) from ticks where error like "%unservable-rating%" and spawned_at >= "2026-11-06T00:00"' returns 0 and the last such tick predates fix commit 0e8085e. 2. Same query over the pre-fix window 2026-11-04..2026-11-05T20:00 returns >0 (instrument can see both states). 3. cd ~/task-router && .venv/bin/python -m pytest -q tests/test_inferred_clamp_last_resort.py tests/test_tr361_slow_fallback.py passes.: (1) sqlite3 ~/.hermes/scheduler.db (symlink -> ~/.hermes/coding-hermes/scheduler.db) query for error like '%unservable-rating%' and spawned_at >= '2026-11-06T00:00' returned 0; max(spawned_at) over all such ticks = 2026-11-05T19:04:52-05:00 (773 total), which predates fix commit 0e8085e 'fix(TR-361): a SLOW always-run lane beats a 503 on the degraded path' dated Fri Nov 6 05:28:21 2026 -0500. (2) Same query over the pre-fix window (spawned_at >= '2026-11-04T00:00' and < '2026-11-05T20:00') returned 181 (>0), so the instrument distinguishes both states. (3) cd ~/task-router && .venv/bin/python -m pytest -q tests/test_inferred_clamp_last_resort.py tests/test_tr361_slow_fallback.py -> EXIT=0, output '................ [100%] 16 passed in 2.59s'; both test files present in ~/task-router/tests/.
All three legs verified with live command output: post-fix unservable-rating tick count is 0 (last such tick 2026-11-05T19:04:52 predates fix 0e8085e), the pre-fix window shows 181 occurrences, and the two named pytest files pass 16/16 with exit 0.

Overall: PASS ✓
