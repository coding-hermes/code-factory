# Verdict: CF-166-DOC2

**Task:** Grade the docs correction by its own row CF-166 (supersedes the mis-bound CF-166-DOC1 criterion)
**Evaluated:** 2026-11-04T06:31:14.146965
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ This task grades the docs correction at commit 8c184a2 by its own row, CF-166 (an earlier criterion text said CF-165 and therefore matched a SIBLING lane's unrelated CF-165 row; do not grade that row).

Scope: the commit changes documentation, one audit file and the two board ledgers — no code change is expected or required.

(1) In the COMMITTED tree at 8c184a2, `.coding-hermes/board/tasks.jsonl` carries exactly one row with id CF-166, status pending, whose `probe` is non-empty (199 chars) and whose acceptance_criteria name the three checks below; `.coding-hermes/board/events.jsonl` carries exactly one `task_created` event with task_id CF-166. The sibling's CF-165 row (boardctl event serialization, ~603-char probe) must still be present and unmodified — prove both rows coexist and that ids are unique.

(2) The stale sentence is gone and the replacement is specific: `grep -c 'requires `BUNKER_SERVER` in the environment' docs/OPERATIONS.md` prints 0; `grep -n 'CRIER_URL' docs/OPERATIONS.md` names the create path in the prerequisites bullet (~line 24), the entry-point bullet (~line 47) and the entry-point table row (~line 194), and that bullet states the gate order (`scripts/node-create.sh:69-79`).

(3) The behaviour the new prose describes reproduces at 8c184a2: `env -u CRIER_URL BUNKER_SERVER=x bash scripts/node-create.sh --project p --repo https://github.com/github/gitignore --harness hermes` prints `  FAIL  crier_url — CRIER_URL unset or empty — export CRIER_URL=http://crier.example:8767` and exits 1; with `CRIER_URL` set and `BUNKER_SERVER` unset it prints `  FAIL  server_declared — …` plus `NODE INCOMPLETE (1)` and exits 1.

(4) `grep -c 'CRIER_URL=http://crier.example:8767' docs/ACCEPTANCE-PLAN.md` prints 2 (the CF-101 and CF-110 recipes).

(5) `bash tests/selftest.sh` prints SELFTEST: PASS (rc 0) and `bash scripts/boardctl validate` prints RESULT: OK at the committed tree.: HEAD = 8c184a214528e41ce1d2fac38e4ba65257f7fb81 (git rev-parse HEAD), matching the graded commit. (1) tasks.jsonl:140 = {"id":"CF-166","status":"pending",...}; `jq -r '.probe|length'` on that row = 199; acceptance_criteria names all three checks (stale-sentence grep=0 + CRIER_URL in bullet/table + gate order :69-79; ACCEPTANCE-PLAN count=2; selftest PASS + boardctl RESULT: OK). tasks.jsonl:139 = CF-165 with probe length 603 (boardctl event serialization lane). `jq -r '.id' tasks.jsonl | sort | uniq -d` returned empty -> ids unique, both rows coexist. events.jsonl:239 is the single `task_created` with task_id CF-166 (`jq select(...)|.id | wc -l` = 1). CF-165 unmodified: `git diff --numstat c3b10cd 8c184a2 -- tasks.jsonl` = `1 0` (append-only), and line 139 md5 is identical in both trees (bdf5ec8dbc564ac9239f67b62154b59b). (2) `grep -c 'requires `BUNKER_SERVER` in the environment' docs/OPERATIONS.md` = 0. `grep -n CRIER_URL docs/OPERATIONS.md` -> line 24 (prerequisites bullet: 'Node creation (§2) additionally requires `CRIER_URL` ... refuses before any bunker call ... (`scripts/node-create.sh:69-72`)'), line 47 (entry-point bullet: 'requires both `BUNKER_SERVER` and `CRIER_URL` ... The gate order is `crier_url` first, then `server_declared` (`scripts/node-create.sh:69-79`)'), line 194 (entry-point table row: 'requires `BUNKER_SERVER` **and** `CRIER_URL` (refuses on either before any bunker call)'). (3) Arm A: `env -u CRIER_URL BUNKER_SERVER=x bash scripts/node-create.sh --project p --repo https://github.com/github/gitignore --harness hermes` -> '  FAIL  crier_url — CRIER_URL unset or empty — export CRIER_URL=http://crier.example:8767', EXIT=1. Arm B: `env -u BUNKER_SERVER CRIER_URL=http://crier.example:8767 ...` -> '  FAIL  server_declared — BUNKER_SERVER unset — no agent host to create the node on' + 'NODE INCOMPLETE (1)', EXIT=1. (4) `grep -c 'CRIER_URL=http://crier.example:8767' docs/ACCEPTANCE-PLAN.md` = 2 (line 73 CF-101, line 82 CF-110). (5) `bash tests/selftest.sh` -> 'SELFTEST: PASS', TRUE_SELFTEST_EXIT=0 (grep -c 'SELFTEST: PASS' = 1); `bash scripts/boardctl validate` -> 'RESULT: OK (3 warning(s))', VALIDATE_EXIT=0 (rows: 140 tasks, 239 events). No code change in the commit (5 files: 2 docs, 1 audit, 2 ledgers), consistent with the stated scope.
All five sub-checks of CF-166 pass at commit 8c184a2 with live command evidence: the CF-166 row (199-char probe, pending) and its single task_created event coexist with the byte-identical CF-165 row (603-char probe) under unique ids, the stale BUNKER_SERVER-only sentence is gone and replaced with CRIER_URL prose naming the gate order at lines 24/47/194, both node-create failure arms reproduce with exit 1, ACCEPTANCE-PLAN carries 2 CRIER_URL recipes, and selftest prints SELFTEST: PASS (rc 0) while boardctl validate prints RESULT: OK.

## Summary

Judge Result: CF-166-DOC2

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ This task grades the docs correction at commit 8c184a2 by its own row, CF-166 (an earlier criterion text said CF-165 and therefore matched a SIBLING lane's unrelated CF-165 row; do not grade that row).

Scope: the commit changes documentation, one audit file and the two board ledgers — no code change is expected or required.

(1) In the COMMITTED tree at 8c184a2, `.coding-hermes/board/tasks.jsonl` carries exactly one row with id CF-166, status pending, whose `probe` is non-empty (199 chars) and whose acceptance_criteria name the three checks below; `.coding-hermes/board/events.jsonl` carries exactly one `task_created` event with task_id CF-166. The sibling's CF-165 row (boardctl event serialization, ~603-char probe) must still be present and unmodified — prove both rows coexist and that ids are unique.

(2) The stale sentence is gone and the replacement is specific: `grep -c 'requires `BUNKER_SERVER` in the environment' docs/OPERATIONS.md` prints 0; `grep -n 'CRIER_URL' docs/OPERATIONS.md` names the create path in the prerequisites bullet (~line 24), the entry-point bullet (~line 47) and the entry-point table row (~line 194), and that bullet states the gate order (`scripts/node-create.sh:69-79`).

(3) The behaviour the new prose describes reproduces at 8c184a2: `env -u CRIER_URL BUNKER_SERVER=x bash scripts/node-create.sh --project p --repo https://github.com/github/gitignore --harness hermes` prints `  FAIL  crier_url — CRIER_URL unset or empty — export CRIER_URL=http://crier.example:8767` and exits 1; with `CRIER_URL` set and `BUNKER_SERVER` unset it prints `  FAIL  server_declared — …` plus `NODE INCOMPLETE (1)` and exits 1.

(4) `grep -c 'CRIER_URL=http://crier.example:8767' docs/ACCEPTANCE-PLAN.md` prints 2 (the CF-101 and CF-110 recipes).

(5) `bash tests/selftest.sh` prints SELFTEST: PASS (rc 0) and `bash scripts/boardctl validate` prints RESULT: OK at the committed tree.: HEAD = 8c184a214528e41ce1d2fac38e4ba65257f7fb81 (git rev-parse HEAD), matching the graded commit. (1) tasks.jsonl:140 = {"id":"CF-166","status":"pending",...}; `jq -r '.probe|length'` on that row = 199; acceptance_criteria names all three checks (stale-sentence grep=0 + CRIER_URL in bullet/table + gate order :69-79; ACCEPTANCE-PLAN count=2; selftest PASS + boardctl RESULT: OK). tasks.jsonl:139 = CF-165 with probe length 603 (boardctl event serialization lane). `jq -r '.id' tasks.jsonl | sort | uniq -d` returned empty -> ids unique, both rows coexist. events.jsonl:239 is the single `task_created` with task_id CF-166 (`jq select(...)|.id | wc -l` = 1). CF-165 unmodified: `git diff --numstat c3b10cd 8c184a2 -- tasks.jsonl` = `1 0` (append-only), and line 139 md5 is identical in both trees (bdf5ec8dbc564ac9239f67b62154b59b). (2) `grep -c 'requires `BUNKER_SERVER` in the environment' docs/OPERATIONS.md` = 0. `grep -n CRIER_URL docs/OPERATIONS.md` -> line 24 (prerequisites bullet: 'Node creation (§2) additionally requires `CRIER_URL` ... refuses before any bunker call ... (`scripts/node-create.sh:69-72`)'), line 47 (entry-point bullet: 'requires both `BUNKER_SERVER` and `CRIER_URL` ... The gate order is `crier_url` first, then `server_declared` (`scripts/node-create.sh:69-79`)'), line 194 (entry-point table row: 'requires `BUNKER_SERVER` **and** `CRIER_URL` (refuses on either before any bunker call)'). (3) Arm A: `env -u CRIER_URL BUNKER_SERVER=x bash scripts/node-create.sh --project p --repo https://github.com/github/gitignore --harness hermes` -> '  FAIL  crier_url — CRIER_URL unset or empty — export CRIER_URL=http://crier.example:8767', EXIT=1. Arm B: `env -u BUNKER_SERVER CRIER_URL=http://crier.example:8767 ...` -> '  FAIL  server_declared — BUNKER_SERVER unset — no agent host to create the node on' + 'NODE INCOMPLETE (1)', EXIT=1. (4) `grep -c 'CRIER_URL=http://crier.example:8767' docs/ACCEPTANCE-PLAN.md` = 2 (line 73 CF-101, line 82 CF-110). (5) `bash tests/selftest.sh` -> 'SELFTEST: PASS', TRUE_SELFTEST_EXIT=0 (grep -c 'SELFTEST: PASS' = 1); `bash scripts/boardctl validate` -> 'RESULT: OK (3 warning(s))', VALIDATE_EXIT=0 (rows: 140 tasks, 239 events). No code change in the commit (5 files: 2 docs, 1 audit, 2 ledgers), consistent with the stated scope.
All five sub-checks of CF-166 pass at commit 8c184a2 with live command evidence: the CF-166 row (199-char probe, pending) and its single task_created event coexist with the byte-identical CF-165 row (603-char probe) under unique ids, the stale BUNKER_SERVER-only sentence is gone and replaced with CRIER_URL prose naming the gate order at lines 24/47/194, both node-create failure arms reproduce with exit 1, ACCEPTANCE-PLAN carries 2 CRIER_URL recipes, and selftest prints SELFTEST: PASS (rc 0) while boardctl validate prints RESULT: OK.

Overall: PASS ✓
