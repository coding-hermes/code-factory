# Verdict: CF-099-PM1104-R2

**Task:** PM: reverse-mapping arm counts match the tree after the 36-section landing
**Evaluated:** 2026-11-04T08:48:58.352468
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ grep -cE '^say "[0-9]+\.' tests/selftest.sh prints 36 and lettered arms print 2, so docs/ACCEPTANCE-PLAN.md states 'Twelve of the 38 arms' and 'The remaining 26' and enumerates §36 with its governing row CF-159; bash docs/audits/cf099-prd-drift-probe.sh exits 0 at the committed HEAD; bash tests/selftest.sh prints SELFTEST: PASS.: All five sub-claims verified with fresh command output. (1) `grep -cE '^say "[0-9]+\.' tests/selftest.sh` -> 36 (sections 1..36, lines 9-1414). (2) Lettered arms = 2: tests/selftest.sh:94 `say "4b. clone failure after successful ref resolution is not an access failure"` and tests/selftest.sh:224 `say "7b. board gate rejects invalid records with line-numbered FAIL rows (CF-088)"` (the criterion's literal `^say "[a-z]\.` regex returns 0 because the arms are digit+letter, but the actual lettered-arm count is 2 as stated). (3) docs/ACCEPTANCE-PLAN.md:57 'Twelve of the 38 arms are named: §2, §3, §4, §4b, §5,...'; :62 'The remaining 26 — §1, §7, §7b, §8,'; :63 enumerates '...§35 and §36 — test repository and'; :67 '§36 `CF-159`'. (4) `bash docs/audits/cf099-prd-drift-probe.sh` -> exit_code 0, output 'measured: tip=8b81369 rows=154 events=291 sections=36 ...' and 'OK: milestone, plan snapshot and layer arms agree at 837a43e'. (5) `bash tests/selftest.sh` -> EXIT=0, 119 `PASS` rows, 19 `FAIL` rows (all intentional negative fixtures), and line 179 prints 'SELFTEST: PASS'. The single stderr line ('digest mismatch ... want 0000...') is the intentional negative fixture in §5 'fetch_verified refuses a wrong digest' and does not affect the exit status.


## Summary

Judge Result: CF-099-PM1104-R2

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ grep -cE '^say "[0-9]+\.' tests/selftest.sh prints 36 and lettered arms print 2, so docs/ACCEPTANCE-PLAN.md states 'Twelve of the 38 arms' and 'The remaining 26' and enumerates §36 with its governing row CF-159; bash docs/audits/cf099-prd-drift-probe.sh exits 0 at the committed HEAD; bash tests/selftest.sh prints SELFTEST: PASS.: All five sub-claims verified with fresh command output. (1) `grep -cE '^say "[0-9]+\.' tests/selftest.sh` -> 36 (sections 1..36, lines 9-1414). (2) Lettered arms = 2: tests/selftest.sh:94 `say "4b. clone failure after successful ref resolution is not an access failure"` and tests/selftest.sh:224 `say "7b. board gate rejects invalid records with line-numbered FAIL rows (CF-088)"` (the criterion's literal `^say "[a-z]\.` regex returns 0 because the arms are digit+letter, but the actual lettered-arm count is 2 as stated). (3) docs/ACCEPTANCE-PLAN.md:57 'Twelve of the 38 arms are named: §2, §3, §4, §4b, §5,...'; :62 'The remaining 26 — §1, §7, §7b, §8,'; :63 enumerates '...§35 and §36 — test repository and'; :67 '§36 `CF-159`'. (4) `bash docs/audits/cf099-prd-drift-probe.sh` -> exit_code 0, output 'measured: tip=8b81369 rows=154 events=291 sections=36 ...' and 'OK: milestone, plan snapshot and layer arms agree at 837a43e'. (5) `bash tests/selftest.sh` -> EXIT=0, 119 `PASS` rows, 19 `FAIL` rows (all intentional negative fixtures), and line 179 prints 'SELFTEST: PASS'. The single stderr line ('digest mismatch ... want 0000...') is the intentional negative fixture in §5 'fetch_verified refuses a wrong digest' and does not affect the exit status.


Overall: PASS ✓
