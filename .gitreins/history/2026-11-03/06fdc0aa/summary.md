# Verdict: CF-070-QA1

**Task:** QA re-verify CF-054/CF-055 at 8889cad and file three fail-open check gaps (CF-070..CF-072)
**Evaluated:** 2026-11-03T14:46:01.754392
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ The board at HEAD carries pending rows CF-070, CF-071 and CF-072, each with a probe field holding one paste-runnable command. Run each row's exact probe from the repo root: CF-070 prints 'PASS  inference_key — a provider key is present' for a .env whose only content is DEMO_API_KEY= (empty value); CF-071 prints 'FAIL  gateway_start — -> 000000' for a config.yaml whose only basic_auth occurrence is commented out, i.e. the public-bind auth gate admitted the launch; CF-072 prints 'FAIL  status_probe — /api/status -> 000000'. Additionally, CF-054's AC1 reproduces (README status-table line verbatim in a clean env exits 1 with NODE: FAIL) and CF-055's AC1 reproduces (printed FAIL rows 5 == NODE: FAIL (5)). No source change is expected from this read-only QA lane.: Board rows present and pending with probe fields: .coding-hermes/board/tasks.jsonl lines 54-56 (CF-070/CF-071/CF-072, status 'pending', each with a 'probe' key). Ran each row's exact probe string from repo root: CF-070 -> '  PASS  inference_key — a provider key is present in ~/.hermes/.env (value not read)' (exit 0); CF-071 -> '  FAIL  gateway_start — -> 000000 (see ~/.node-serve-10800.log)' plus 'HERMES: FAIL (2)' (exit 0); CF-072 -> '  FAIL  status_probe — /api/status -> 000000' (exit 0). CF-054 AC1: README.md:74 status-table command run verbatim under env -i HOME=<temp> PATH=/usr/local/bin:/usr/bin:/bin -> rc=1 with 'NODE: FAIL (3)'. CF-055 AC1: `bash tests/selftest.sh` (guards.test_command) section 14 printed 'PASS  adapter FAIL rows counted: 2 rows -> NODE: FAIL (2)' and 'PASS  passing adapter keeps NODE: PASS and exit 0', suite ended 'SELFTEST: PASS' (tests/selftest.sh:261-315 asserts summary integer == grep -c '^  FAIL'). No source change: `git diff 8889cad..HEAD --stat` shows only '.coding-hermes/board/tasks.jsonl | 3 +++' (1 file changed, 3 insertions).


## Summary

Judge Result: CF-070-QA1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ The board at HEAD carries pending rows CF-070, CF-071 and CF-072, each with a probe field holding one paste-runnable command. Run each row's exact probe from the repo root: CF-070 prints 'PASS  inference_key — a provider key is present' for a .env whose only content is DEMO_API_KEY= (empty value); CF-071 prints 'FAIL  gateway_start — -> 000000' for a config.yaml whose only basic_auth occurrence is commented out, i.e. the public-bind auth gate admitted the launch; CF-072 prints 'FAIL  status_probe — /api/status -> 000000'. Additionally, CF-054's AC1 reproduces (README status-table line verbatim in a clean env exits 1 with NODE: FAIL) and CF-055's AC1 reproduces (printed FAIL rows 5 == NODE: FAIL (5)). No source change is expected from this read-only QA lane.: Board rows present and pending with probe fields: .coding-hermes/board/tasks.jsonl lines 54-56 (CF-070/CF-071/CF-072, status 'pending', each with a 'probe' key). Ran each row's exact probe string from repo root: CF-070 -> '  PASS  inference_key — a provider key is present in ~/.hermes/.env (value not read)' (exit 0); CF-071 -> '  FAIL  gateway_start — -> 000000 (see ~/.node-serve-10800.log)' plus 'HERMES: FAIL (2)' (exit 0); CF-072 -> '  FAIL  status_probe — /api/status -> 000000' (exit 0). CF-054 AC1: README.md:74 status-table command run verbatim under env -i HOME=<temp> PATH=/usr/local/bin:/usr/bin:/bin -> rc=1 with 'NODE: FAIL (3)'. CF-055 AC1: `bash tests/selftest.sh` (guards.test_command) section 14 printed 'PASS  adapter FAIL rows counted: 2 rows -> NODE: FAIL (2)' and 'PASS  passing adapter keeps NODE: PASS and exit 0', suite ended 'SELFTEST: PASS' (tests/selftest.sh:261-315 asserts summary integer == grep -c '^  FAIL'). No source change: `git diff 8889cad..HEAD --stat` shows only '.coding-hermes/board/tasks.jsonl | 3 +++' (1 file changed, 3 insertions).


Overall: PASS ✓
