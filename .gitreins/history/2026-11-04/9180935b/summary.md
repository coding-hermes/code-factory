# Verdict: CF-153

**Task:** file CF-153: the create path cannot honour the remedy its own error prints
**Evaluated:** 2026-11-04T02:57:56.068806
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ FILING-ONLY criterion (the repair is future work tracked by the pending row and is NOT expected at this commit). At the graded commit: (1) .coding-hermes/board/tasks.jsonl contains exactly one row CF-153 with status "pending", a non-empty probe and a non-empty acceptance_criteria naming --ref on the create path; (2) .coding-hermes/board/events.jsonl contains a task_created event for CF-153; (3) docs/audits/code-factory-dogfood-2026-11-04-02-39-16.md exists and records the two measured arms (node-create.sh --ref -> unknown arg, rc=2; project-node.sh --layers 40 -> ref 'main' was not found) at the published tip; (4) the defect is reproducible from the row's own probe at this commit; (5) bash tests/selftest.sh prints SELFTEST: PASS and bash scripts/boardctl validate prints RESULT: OK; (6) scripts/node-create.sh is unchanged by this commit, so the fix is explicitly NOT part of this change.: (1) tasks.jsonl:127 — exactly one CF-153 row (python count=1), status="pending", probe_len=537, acceptance_criteria AC1 names "scripts/node-create.sh accepts a ref selection — a `--ref <branch-or-tag>` flag ... passes it through to the node's `project-node.sh --ref`". (2) events.jsonl:191 — {"event_type":"task_created","task_id":"CF-153","actor":"dogfood"}. (3) docs/audits/code-factory-dogfood-2026-11-04-02-39-16.md exists (7408 bytes); line 6 records published tip c29c024; lines 56-58 record `--ref master` -> `unknown arg: --ref` / `rc=2`; line 66 records `FAIL  repo_clone — ref 'main' was not found; pass --ref <branch-or-tag>` with `NODE: FAIL (1)`. (4) Ran the row's own probe verbatim at HEAD d27c499: output `ARM_create_path: / unknown arg: --ref / arm_create_rc=2 / ARM_node_layer40: ... NODE: FAIL (1)` — defect reproduces; code confirms node-create.sh:56-67 has no --ref (falls to `*)` at :65, exit 2) while project-node.sh:33/:53 support it and node-create.sh:103-104 forwards only NODE_PROJECT/NODE_GATEWAY_PORT/CRIER_URL. (5) `bash tests/selftest.sh` EXIT=0, line 146 `SELFTEST: PASS` (93 PASS rows); `bash scripts/boardctl validate` EXIT=0, line 7 `RESULT: OK (3 warning(s))`. (6) `git show HEAD --name-only` = only .coding-hermes/board/events.jsonl, .coding-hermes/board/tasks.jsonl, docs/audits/code-factory-dogfood-2026-11-04-02-39-16.md; `git show HEAD -- scripts/node-create.sh` empty and `git diff --name-only HEAD~1 HEAD -- scripts/ README.md` empty — the fix is explicitly not part of this commit.
All six filing-only sub-criteria hold at d27c499: one pending CF-153 row with probe and --ref-naming acceptance criteria, a task_created event, the audit recording both measured arms at tip c29c024, the defect reproducing from the row's own probe, SELFTEST: PASS and RESULT: OK, and no change to scripts/node-create.sh.

## Summary

Judge Result: CF-153

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ FILING-ONLY criterion (the repair is future work tracked by the pending row and is NOT expected at this commit). At the graded commit: (1) .coding-hermes/board/tasks.jsonl contains exactly one row CF-153 with status "pending", a non-empty probe and a non-empty acceptance_criteria naming --ref on the create path; (2) .coding-hermes/board/events.jsonl contains a task_created event for CF-153; (3) docs/audits/code-factory-dogfood-2026-11-04-02-39-16.md exists and records the two measured arms (node-create.sh --ref -> unknown arg, rc=2; project-node.sh --layers 40 -> ref 'main' was not found) at the published tip; (4) the defect is reproducible from the row's own probe at this commit; (5) bash tests/selftest.sh prints SELFTEST: PASS and bash scripts/boardctl validate prints RESULT: OK; (6) scripts/node-create.sh is unchanged by this commit, so the fix is explicitly NOT part of this change.: (1) tasks.jsonl:127 — exactly one CF-153 row (python count=1), status="pending", probe_len=537, acceptance_criteria AC1 names "scripts/node-create.sh accepts a ref selection — a `--ref <branch-or-tag>` flag ... passes it through to the node's `project-node.sh --ref`". (2) events.jsonl:191 — {"event_type":"task_created","task_id":"CF-153","actor":"dogfood"}. (3) docs/audits/code-factory-dogfood-2026-11-04-02-39-16.md exists (7408 bytes); line 6 records published tip c29c024; lines 56-58 record `--ref master` -> `unknown arg: --ref` / `rc=2`; line 66 records `FAIL  repo_clone — ref 'main' was not found; pass --ref <branch-or-tag>` with `NODE: FAIL (1)`. (4) Ran the row's own probe verbatim at HEAD d27c499: output `ARM_create_path: / unknown arg: --ref / arm_create_rc=2 / ARM_node_layer40: ... NODE: FAIL (1)` — defect reproduces; code confirms node-create.sh:56-67 has no --ref (falls to `*)` at :65, exit 2) while project-node.sh:33/:53 support it and node-create.sh:103-104 forwards only NODE_PROJECT/NODE_GATEWAY_PORT/CRIER_URL. (5) `bash tests/selftest.sh` EXIT=0, line 146 `SELFTEST: PASS` (93 PASS rows); `bash scripts/boardctl validate` EXIT=0, line 7 `RESULT: OK (3 warning(s))`. (6) `git show HEAD --name-only` = only .coding-hermes/board/events.jsonl, .coding-hermes/board/tasks.jsonl, docs/audits/code-factory-dogfood-2026-11-04-02-39-16.md; `git show HEAD -- scripts/node-create.sh` empty and `git diff --name-only HEAD~1 HEAD -- scripts/ README.md` empty — the fix is explicitly not part of this commit.
All six filing-only sub-criteria hold at d27c499: one pending CF-153 row with probe and --ref-naming acceptance criteria, a task_created event, the audit recording both measured arms at tip c29c024, the defect reproducing from the row's own probe, SELFTEST: PASS and RESULT: OK, and no change to scripts/node-create.sh.

Overall: PASS ✓
