# Verdict: CF-148-QA1

**Task:** QA filing: CF-053 isolation criterion false in the live fleet and uncatchable by the shipped scan; CF-123 probe discriminator is path-sensitive
**Evaluated:** 2026-11-04T02:43:02.735430
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Scope: THE FILING, not the fix. Do NOT require or evaluate any change to lane config, lane_target.py, tests/selftest.sh or CF-123's probe. Verify only, from the committed tree: (1) the commit's stat is docs-only and adds docs/audits/code-factory-qa-duckbrain-2026-11-04.md; the board rows CF-148 and CF-149 are present in HEAD's .coding-hermes/board/tasks.jsonl (landed by an earlier sibling commit) each with a non-empty single-line probe; (2) CF-053 reads status in_progress in HEAD's board with a foreman_note naming unmet acceptance criterion 4; (3) running CF-148's probe field from the repo root prints "bad": 0, "ok": true and scan_rc=0 for two lanes sharing one workdir; (4) running CF-149's probe prints two arms with unique_red_rows=1 and two 'disk_floor — resolver missing or unreadable:' lines at different temp paths; (5) bash tests/selftest.sh prints SELFTEST: PASS and bash scripts/boardctl validate prints RESULT: OK at this tree.: (1) `git show HEAD --name-only` => only `docs/audits/code-factory-qa-duckbrain-2026-11-04.md` (98 insertions, 1 file, docs-only; no lane config/lane_target.py/selftest.sh/CF-123 probe touched). `git show HEAD:.coding-hermes/board/tasks.jsonl` contains CF-148 (status pending) and CF-149 (status pending), each with a non-empty probe of exactly 1 line (verified via python: 'probe lines: 1' for both). (2) HEAD board CF-053: status='in_progress'; foreman_note contains "Criterion 4 does NOT reproduce: 'concurrent lanes do not share one mutable checkout' is false — ... the fleet measures 19 lanes / 1 distinct workdir ... Re-opened pending an owner decision". (3) CF-148 probe executed from repo root printed `  "bad": 0,` / `  "ok": true` / `scan_rc=0` (outer_rc=0) for lane-a and lane-b both with workdir=$PWD. (4) CF-149 probe executed twice cleanly: run1 `a_rc=0 a_summary=SELFTEST: PASS unique_red_rows=1` + `disk_floor — resolver missing or unreadable: /var/tmp/hermes-scratch/tmp.RdYb4x4qBD/scripts/disk_floor.py`, `b_rc=0 ... unique_red_rows=1` + `... tmp.OJXOX0kfSP/scripts/disk_floor.py`; run2 same shape with tmp.Af5nNJc1Y8 vs tmp.WLuflAqqdm (two arms, unique_red_rows=1 each, two disk_floor lines at different temp paths). (5) `bash tests/selftest.sh` tail => `SELFTEST: PASS`; `bash scripts/boardctl validate` tail => `RESULT: OK (53 warning(s))`. Audit doc content (docs/audits/code-factory-qa-duckbrain-2026-11-04.md §2/§3) matches the measured outputs.


## Summary

Judge Result: CF-148-QA1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Scope: THE FILING, not the fix. Do NOT require or evaluate any change to lane config, lane_target.py, tests/selftest.sh or CF-123's probe. Verify only, from the committed tree: (1) the commit's stat is docs-only and adds docs/audits/code-factory-qa-duckbrain-2026-11-04.md; the board rows CF-148 and CF-149 are present in HEAD's .coding-hermes/board/tasks.jsonl (landed by an earlier sibling commit) each with a non-empty single-line probe; (2) CF-053 reads status in_progress in HEAD's board with a foreman_note naming unmet acceptance criterion 4; (3) running CF-148's probe field from the repo root prints "bad": 0, "ok": true and scan_rc=0 for two lanes sharing one workdir; (4) running CF-149's probe prints two arms with unique_red_rows=1 and two 'disk_floor — resolver missing or unreadable:' lines at different temp paths; (5) bash tests/selftest.sh prints SELFTEST: PASS and bash scripts/boardctl validate prints RESULT: OK at this tree.: (1) `git show HEAD --name-only` => only `docs/audits/code-factory-qa-duckbrain-2026-11-04.md` (98 insertions, 1 file, docs-only; no lane config/lane_target.py/selftest.sh/CF-123 probe touched). `git show HEAD:.coding-hermes/board/tasks.jsonl` contains CF-148 (status pending) and CF-149 (status pending), each with a non-empty probe of exactly 1 line (verified via python: 'probe lines: 1' for both). (2) HEAD board CF-053: status='in_progress'; foreman_note contains "Criterion 4 does NOT reproduce: 'concurrent lanes do not share one mutable checkout' is false — ... the fleet measures 19 lanes / 1 distinct workdir ... Re-opened pending an owner decision". (3) CF-148 probe executed from repo root printed `  "bad": 0,` / `  "ok": true` / `scan_rc=0` (outer_rc=0) for lane-a and lane-b both with workdir=$PWD. (4) CF-149 probe executed twice cleanly: run1 `a_rc=0 a_summary=SELFTEST: PASS unique_red_rows=1` + `disk_floor — resolver missing or unreadable: /var/tmp/hermes-scratch/tmp.RdYb4x4qBD/scripts/disk_floor.py`, `b_rc=0 ... unique_red_rows=1` + `... tmp.OJXOX0kfSP/scripts/disk_floor.py`; run2 same shape with tmp.Af5nNJc1Y8 vs tmp.WLuflAqqdm (two arms, unique_red_rows=1 each, two disk_floor lines at different temp paths). (5) `bash tests/selftest.sh` tail => `SELFTEST: PASS`; `bash scripts/boardctl validate` tail => `RESULT: OK (53 warning(s))`. Audit doc content (docs/audits/code-factory-qa-duckbrain-2026-11-04.md §2/§3) matches the measured outputs.


Overall: PASS ✓
