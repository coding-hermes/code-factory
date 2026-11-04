# Verdict: CF-150

**Task:** Dogfood filing: the documented node create path can never start its gateway (no step stages dashboard.basic_auth)
**Evaluated:** 2026-11-04T02:47:25.026840
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ FILING ONLY - the repair is future work tracked by pending board row CF-150 and is NOT expected at this commit. The filing is correct when: (1) board row CF-150 exists in the committed tree with status pending, a numbered acceptance list and a non-empty probe; (2) that probe, extracted from the committed board and run from the repo root, prints installer_basic_auth=3 with create_path_basic_auth and create_path_config_yaml both zero, names the gateway_start refusal line at scripts/harness/install-hermes.sh:100, and exits 0; (3) docs/audits/cf-dogfood-2026-11-04-gateway-apply.txt is present in the same commit and contains the measured FAIL gateway_start refused line, with no absolute host paths; (4) bash tests/selftest.sh prints SELFTEST: PASS and scripts/boardctl validate prints RESULT: OK at the judged commit. Do NOT evaluate the underlying fix.: (1) .coding-hermes/board/tasks.jsonl (committed at HEAD e657d98) has CF-150 with "status":"pending", acceptance_criteria numbered 0-4, and a non-empty probe; .coding-hermes/board/events.jsonl:182 records task_created. (2) `jq -r 'select(.id=="CF-150").probe' .coding-hermes/board/tasks.jsonl > /tmp/p150.sh; bash /tmp/p150.sh` from repo root printed: `installer_basic_auth=3 create_path_basic_auth=scripts/node-create.sh:0,scripts/project-node.sh:0, create_path_config_yaml=scripts/node-create.sh:0,scripts/project-node.sh:0,` then `100:      bad "gateway_start" "refused: a public bind needs dashboard.basic_auth in ~/.hermes/config.yaml"` and `rc=0`, EXIT=0; scripts/harness/install-hermes.sh:100 confirmed by sed (line 94 greps basic_auth, line 100 is the refusal). (3) `git show HEAD --name-only` lists docs/audits/cf-dogfood-2026-11-04-gateway-apply.txt in the same commit; the file contains `FAIL  gateway_start — refused: a public bind needs dashboard.basic_auth in ~/.hermes/config.yaml`; grep for /home|/Users|/root|/tmp|/var|/opt|/mnt returned exit 1 (no matches) — only standard system paths /usr/local/bin:/usr/bin:/bin and /usr/bin/python3.12 appear. (4) `bash tests/selftest.sh` -> SELFTEST_EXIT=0 with `SELFTEST: PASS`; `scripts/boardctl validate` -> BOARDCTL_EXIT=0 with `RESULT: OK (54 warning(s))` (warnings are pre-existing probe-key/free-vocabulary warnings). Underlying fix not evaluated, per instruction.
CF-150 is correctly filed: pending board row with numbered acceptance list and working probe (installer_basic_auth=3, create-path counts 0, refusal at install-hermes.sh:100, exit 0), the audit transcript is in the same commit with the measured FAIL line and no host paths, and both gates (SELFTEST: PASS, RESULT: OK) pass at the judged commit.

## Summary

Judge Result: CF-150

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ FILING ONLY - the repair is future work tracked by pending board row CF-150 and is NOT expected at this commit. The filing is correct when: (1) board row CF-150 exists in the committed tree with status pending, a numbered acceptance list and a non-empty probe; (2) that probe, extracted from the committed board and run from the repo root, prints installer_basic_auth=3 with create_path_basic_auth and create_path_config_yaml both zero, names the gateway_start refusal line at scripts/harness/install-hermes.sh:100, and exits 0; (3) docs/audits/cf-dogfood-2026-11-04-gateway-apply.txt is present in the same commit and contains the measured FAIL gateway_start refused line, with no absolute host paths; (4) bash tests/selftest.sh prints SELFTEST: PASS and scripts/boardctl validate prints RESULT: OK at the judged commit. Do NOT evaluate the underlying fix.: (1) .coding-hermes/board/tasks.jsonl (committed at HEAD e657d98) has CF-150 with "status":"pending", acceptance_criteria numbered 0-4, and a non-empty probe; .coding-hermes/board/events.jsonl:182 records task_created. (2) `jq -r 'select(.id=="CF-150").probe' .coding-hermes/board/tasks.jsonl > /tmp/p150.sh; bash /tmp/p150.sh` from repo root printed: `installer_basic_auth=3 create_path_basic_auth=scripts/node-create.sh:0,scripts/project-node.sh:0, create_path_config_yaml=scripts/node-create.sh:0,scripts/project-node.sh:0,` then `100:      bad "gateway_start" "refused: a public bind needs dashboard.basic_auth in ~/.hermes/config.yaml"` and `rc=0`, EXIT=0; scripts/harness/install-hermes.sh:100 confirmed by sed (line 94 greps basic_auth, line 100 is the refusal). (3) `git show HEAD --name-only` lists docs/audits/cf-dogfood-2026-11-04-gateway-apply.txt in the same commit; the file contains `FAIL  gateway_start — refused: a public bind needs dashboard.basic_auth in ~/.hermes/config.yaml`; grep for /home|/Users|/root|/tmp|/var|/opt|/mnt returned exit 1 (no matches) — only standard system paths /usr/local/bin:/usr/bin:/bin and /usr/bin/python3.12 appear. (4) `bash tests/selftest.sh` -> SELFTEST_EXIT=0 with `SELFTEST: PASS`; `scripts/boardctl validate` -> BOARDCTL_EXIT=0 with `RESULT: OK (54 warning(s))` (warnings are pre-existing probe-key/free-vocabulary warnings). Underlying fix not evaluated, per instruction.
CF-150 is correctly filed: pending board row with numbered acceptance list and working probe (installer_basic_auth=3, create-path counts 0, refusal at install-hermes.sh:100, exit 0), the audit transcript is in the same commit with the measured FAIL line and no host paths, and both gates (SELFTEST: PASS, RESULT: OK) pass at the judged commit.

Overall: PASS ✓
