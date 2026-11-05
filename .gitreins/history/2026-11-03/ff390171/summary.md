# Verdict: SYNC-20261103-2348

**Task:** Sync lane: rebind CF-077 completion evidence to the landed commit, correct the README gate-row count, and file the remaining board-lifecycle drift
**Evaluated:** 2026-11-03T23:56:36.591188
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ 1. CF-077 commit_hash names 1232f7a04ce8bcfa94fd46166b3f05f1d1c55ffc, a commit that git merge-base --is-ancestor proves reaches origin/main, and no other row changes.: jq on .coding-hermes/board/tasks.jsonl: CF-077 commit_hash = 1232f7a04ce8bcfa94fd46166b3f05f1d1c55ffc. `git merge-base --is-ancestor 1232f7a04ce8bcfa94fd46166b3f05f1d1c55ffc origin/main` -> exit 0 (object is a commit: 'fix: fail closed when the auth probe cannot prove the gateway is closed. Addresses CF-077.'). Row-level diff HEAD~1..HEAD parsed as JSON: only CF-077 changed, and only field commit_hash (1dfb58b8aac966fa858e274992e01bad27d0632b -> 1232f7a0...); the sole other delta is the new CF-130 row (a filing, not a change to an existing row).
  ✓ 2. README.md's python3.12 gate-row claim matches what the command prints on this host.: README.md:73 now states the pinned-interpreter check prints four rows when no hermes binary is installed and five on a host where ~/.local/bin/hermes exists (adds `version`), with the 2026-11-03 re-measurement: rows python, binary, version, port, inference_key, `HERMES: FAIL (1)`, rc 1. Measured here: `HERMES_PYTHON_BIN=python3.12 bash scripts/harness/install-hermes.sh --check` -> 5 gate rows (python, binary, version, port, inference_key), 'HERMES: FAIL (1)', rc=1; unqualified `bash scripts/harness/install-hermes.sh --check` (python3 3.14.9) -> 1 row 'FAIL python'. Both arms match the README text exactly.
  ✓ 3. docs/audits/code-factory-sync-2026-11-03-2348.md records rows parsed, drift found, fixes applied and the residue disclosed.: docs/audits/code-factory-sync-2026-11-03-2348.md has a 'Board census' table ('Task rows parsed | 103', 'Events parsed | 146 (audit 25, task_completed 45, task_created 72, task_updated 4)', status split 38 complete/64 pending/1 in_progress) — all verified against HEAD~1 board files (103 rows/103 unique ids, 146 events with exactly those type counts, same status split). 'Drift found' table lists 5 numbered drifts (CF-077, README, CF-034/CF-041, CF-053, CF-005) plus a 'Checked and not drift' section; 'Fixes applied' lists the CF-077 rebind, the README both-arms correction and the CF-130 filing; 'Residue disclosed, not cleaned' table names .coding-hermes/board/.lock and the 13 untracked .gitreins/history/2026-11-03 bundles. (Minor: the 'Gates at this tree' block quotes 44 warnings while the tree now prints 45 — the doc explains the delta as CF-130's own probe warning and the commit message states 45.)
  ✓ 4. bash tests/selftest.sh prints SELFTEST: PASS and bash scripts/boardctl validate prints RESULT: OK.: `bash tests/selftest.sh` -> exit_code 0, final line 'SELFTEST: PASS'. `bash scripts/boardctl validate` -> exit_code 0, final line 'RESULT: OK (45 warning(s))'.
All four criteria verified: CF-077 is rebound to an origin/main-reachable commit with only that field changed, the README gate-row claim matches the measured 5-row/1-row arms on this host, the audit doc records census/drift/fixes/residue, and both gates print SELFTEST: PASS and RESULT: OK.

## Summary

Judge Result: SYNC-20261103-2348

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ 1. CF-077 commit_hash names 1232f7a04ce8bcfa94fd46166b3f05f1d1c55ffc, a commit that git merge-base --is-ancestor proves reaches origin/main, and no other row changes.: jq on .coding-hermes/board/tasks.jsonl: CF-077 commit_hash = 1232f7a04ce8bcfa94fd46166b3f05f1d1c55ffc. `git merge-base --is-ancestor 1232f7a04ce8bcfa94fd46166b3f05f1d1c55ffc origin/main` -> exit 0 (object is a commit: 'fix: fail closed when the auth probe cannot prove the gateway is closed. Addresses CF-077.'). Row-level diff HEAD~1..HEAD parsed as JSON: only CF-077 changed, and only field commit_hash (1dfb58b8aac966fa858e274992e01bad27d0632b -> 1232f7a0...); the sole other delta is the new CF-130 row (a filing, not a change to an existing row).
  ✓ 2. README.md's python3.12 gate-row claim matches what the command prints on this host.: README.md:73 now states the pinned-interpreter check prints four rows when no hermes binary is installed and five on a host where ~/.local/bin/hermes exists (adds `version`), with the 2026-11-03 re-measurement: rows python, binary, version, port, inference_key, `HERMES: FAIL (1)`, rc 1. Measured here: `HERMES_PYTHON_BIN=python3.12 bash scripts/harness/install-hermes.sh --check` -> 5 gate rows (python, binary, version, port, inference_key), 'HERMES: FAIL (1)', rc=1; unqualified `bash scripts/harness/install-hermes.sh --check` (python3 3.14.9) -> 1 row 'FAIL python'. Both arms match the README text exactly.
  ✓ 3. docs/audits/code-factory-sync-2026-11-03-2348.md records rows parsed, drift found, fixes applied and the residue disclosed.: docs/audits/code-factory-sync-2026-11-03-2348.md has a 'Board census' table ('Task rows parsed | 103', 'Events parsed | 146 (audit 25, task_completed 45, task_created 72, task_updated 4)', status split 38 complete/64 pending/1 in_progress) — all verified against HEAD~1 board files (103 rows/103 unique ids, 146 events with exactly those type counts, same status split). 'Drift found' table lists 5 numbered drifts (CF-077, README, CF-034/CF-041, CF-053, CF-005) plus a 'Checked and not drift' section; 'Fixes applied' lists the CF-077 rebind, the README both-arms correction and the CF-130 filing; 'Residue disclosed, not cleaned' table names .coding-hermes/board/.lock and the 13 untracked .gitreins/history/2026-11-03 bundles. (Minor: the 'Gates at this tree' block quotes 44 warnings while the tree now prints 45 — the doc explains the delta as CF-130's own probe warning and the commit message states 45.)
  ✓ 4. bash tests/selftest.sh prints SELFTEST: PASS and bash scripts/boardctl validate prints RESULT: OK.: `bash tests/selftest.sh` -> exit_code 0, final line 'SELFTEST: PASS'. `bash scripts/boardctl validate` -> exit_code 0, final line 'RESULT: OK (45 warning(s))'.
All four criteria verified: CF-077 is rebound to an origin/main-reachable commit with only that field changed, the README gate-row claim matches the measured 5-row/1-row arms on this host, the audit doc records census/drift/fixes/residue, and both gates print SELFTEST: PASS and RESULT: OK.

Overall: PASS ✓
