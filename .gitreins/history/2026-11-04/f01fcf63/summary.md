# Verdict: CF-198-QA1

**Task:** QA filing: ACCEPTANCE-PLAN mapping table still ends at section 37 after the CF-182 landing
**Evaluated:** 2026-11-04T10:22:33.855352
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Filing-only scope: the committed tree at HEAD adds exactly one board row CF-198 and the row carries a non-empty probe. From the repository root at HEAD run: jq -r 'select(.id=="CF-198") | .probe' .coding-hermes/board/tasks.jsonl > /tmp/p198.sh; bash /tmp/p198.sh — expect selftest_sections=38, plan_says=38, mapping_last=37 and the DRIFT line naming the mapping table, exit 0. Also require bash tests/selftest.sh printing SELFTEST: PASS and bash scripts/boardctl validate printing RESULT: OK. Do NOT evaluate the repair (extending the mapping table and adding a derived checker); that is future work tracked by the pending row CF-198.: Scope: `git show --name-only HEAD` (7edebf0) lists only .coding-hermes/board/events.jsonl and .coding-hermes/board/tasks.jsonl; `git show --name-only HEAD | grep -E '^(docs|tests|scripts)/'` => NONE, so no repair was attempted. tasks.jsonl diff = 1 added line, 0 removed; `grep -c '"id":"CF-198"'` = 1; row is status=pending with probe_len=483 (non-empty). Probe run exactly as specified: `jq -r 'select(.id=="CF-198") | .probe' .coding-hermes/board/tasks.jsonl > /tmp/p198.sh; bash /tmp/p198.sh` printed 'selftest_sections=38', 'plan_says=38', 'mapping_last=37', 'DRIFT: selftest has 38 sections, plan claims 38, mapping table ends at section 37' (DRIFT line names the mapping table), EXIT=0. `bash tests/selftest.sh` => SELFTEST_EXIT=0 with 'SELFTEST: PASS' present (grep -c = 1). `bash scripts/boardctl validate` => VALIDATE_EXIT=0 with 'RESULT: OK (4 warning(s))' (warnings pre-existing: CF-034 free-form guard_result/ci_result, duplicate event id 336, headerless board). Finding independently confirmed real: docs/ACCEPTANCE-PLAN.md mapping table last row is '| §37' (33 rows) while tests/selftest.sh:1866 carries 'say "38. the milestone blocker list resolves every cited id in one namespace (CF-182)"'.
HEAD 7edebf0 is a clean filing-only commit adding exactly one CF-198 board row with a non-empty probe that reproduces selftest_sections=38 / plan_says=38 / mapping_last=37 plus the mapping-table DRIFT line at exit 0, with selftest SELFTEST: PASS and boardctl RESULT: OK.

## Summary

Judge Result: CF-198-QA1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Filing-only scope: the committed tree at HEAD adds exactly one board row CF-198 and the row carries a non-empty probe. From the repository root at HEAD run: jq -r 'select(.id=="CF-198") | .probe' .coding-hermes/board/tasks.jsonl > /tmp/p198.sh; bash /tmp/p198.sh — expect selftest_sections=38, plan_says=38, mapping_last=37 and the DRIFT line naming the mapping table, exit 0. Also require bash tests/selftest.sh printing SELFTEST: PASS and bash scripts/boardctl validate printing RESULT: OK. Do NOT evaluate the repair (extending the mapping table and adding a derived checker); that is future work tracked by the pending row CF-198.: Scope: `git show --name-only HEAD` (7edebf0) lists only .coding-hermes/board/events.jsonl and .coding-hermes/board/tasks.jsonl; `git show --name-only HEAD | grep -E '^(docs|tests|scripts)/'` => NONE, so no repair was attempted. tasks.jsonl diff = 1 added line, 0 removed; `grep -c '"id":"CF-198"'` = 1; row is status=pending with probe_len=483 (non-empty). Probe run exactly as specified: `jq -r 'select(.id=="CF-198") | .probe' .coding-hermes/board/tasks.jsonl > /tmp/p198.sh; bash /tmp/p198.sh` printed 'selftest_sections=38', 'plan_says=38', 'mapping_last=37', 'DRIFT: selftest has 38 sections, plan claims 38, mapping table ends at section 37' (DRIFT line names the mapping table), EXIT=0. `bash tests/selftest.sh` => SELFTEST_EXIT=0 with 'SELFTEST: PASS' present (grep -c = 1). `bash scripts/boardctl validate` => VALIDATE_EXIT=0 with 'RESULT: OK (4 warning(s))' (warnings pre-existing: CF-034 free-form guard_result/ci_result, duplicate event id 336, headerless board). Finding independently confirmed real: docs/ACCEPTANCE-PLAN.md mapping table last row is '| §37' (33 rows) while tests/selftest.sh:1866 carries 'say "38. the milestone blocker list resolves every cited id in one namespace (CF-182)"'.
HEAD 7edebf0 is a clean filing-only commit adding exactly one CF-198 board row with a non-empty probe that reproduces selftest_sections=38 / plan_says=38 / mapping_last=37 plus the mapping-table DRIFT line at exit 0, with selftest SELFTEST: PASS and boardctl RESULT: OK.

Overall: PASS ✓
