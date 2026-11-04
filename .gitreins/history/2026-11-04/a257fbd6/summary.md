# Verdict: CF-167-DOC2

**Task:** docs/OPERATIONS.md: the verify-node recipe states the BUNKER_SERVER contract the code enforces (CF-167)
**Evaluated:** 2026-11-04T06:48:11.921937
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Correct docs/OPERATIONS.md so the verify-node.sh recipe states the shipped environment contract instead of an intention, and file the row that carries the claim. This task grades a DOCUMENTATION CORRECTION, not a code fix: making --server self-sufficient is owned by row CF-063 and is NOT expected at this commit.

The claim: docs/OPERATIONS.md:127 said "Required environment: BUNKER_SERVER unless --server is supplied" and :195 listed the invocation with no environment precondition. scripts/verify-node.sh:17 assigns SERVER="${BUNKER_SERVER:?...}", so the shell expands that guard while executing line 17, before the argument loop at :18-26 reads argv (:21 handles --server).

Executable requirements (run each, compare literal output):
1. env -u BUNKER_SERVER ./scripts/verify-node.sh --agent probe-agent --server some-server --port 10800; echo rc=$? -> prints "./scripts/verify-node.sh: line 17: BUNKER_SERVER: set BUNKER_SERVER to your bunker server name" and rc=1, with no "verify node" banner.
2. BUNKER_SERVER=some-server ./scripts/verify-node.sh --agent probe-agent --server some-server --port 10800 -> prints "verify node probe-agent" and reaches the agent_alive row (control arm; the placeholder server then fails).
3. grep -n 'unless .--server. is supplied' docs/OPERATIONS.md -> no matches, exit 1.
4. awk 'NR==127' docs/OPERATIONS.md -> names scripts/verify-node.sh:17 and the argument loop at :18-26, states the env var is required even when --server is passed, and names CF-063 as the owner of relaxing the guard.
5. awk 'NR==195' docs/OPERATIONS.md -> the inventory boundary cell carries the same requirement.
6. docs/audits/code-factory-docs-2026-11-04-verify-env.md is present in the committed tree with the before/after table, the code path with line numbers, both arm transcripts, a "not measured" section, a ch:trace line and a STATUS/TIER/EVIDENCE footer.
7. jq -c 'select(.id=="CF-167")' .coding-hermes/board/tasks.jsonl -> row present with a non-empty probe.
8. bash scripts/boardctl validate -> RESULT: OK.

Gate expectation, stated so the judge does not grade an inherited defect: tests/selftest.sh is RED at the base tip 9b7fb6f with two audit-scope rows naming docs/audits/code-factory-releng-2026-11-04-CF-163-AC3.md:39 and :77 (a sibling lane's file, repair in flight). The requirement is that the same two rows and the same SELFTEST: FAIL (1) appear at this commit, i.e. this commit introduces NO new failure and adds no new audit-scope violation. Quote both runs, or the single run plus the base-tip worktree run recorded in docs/audits/code-factory-docs-2026-11-04-verify-env.md section 6. Do NOT require SELFTEST: PASS and do not grade the sibling audit file itself.: Req1: `env -u BUNKER_SERVER ./scripts/verify-node.sh --agent probe-agent --server some-server --port 10800` -> "./scripts/verify-node.sh: line 17: BUNKER_SERVER: set BUNKER_SERVER to your bunker server name" / rc=1, no banner. Req2: with BUNKER_SERVER=some-server -> "verify node probe-agent" then "FAIL  agent_alive — bunker: server \"some-server\" not found in config" / RESULT: FAIL. Req3: `grep -n 'unless .--server. is supplied' docs/OPERATIONS.md` -> no output, grep_rc=1. Req4: awk NR==127 = "3. Use `scripts/verify-node.sh --agent ID --server NAME ...` ... Required environment: `BUNKER_SERVER` must be set even when `--server NAME` is supplied — `scripts/verify-node.sh:17` expands `${BUNKER_SERVER:?…}` ... before the argument loop at `:18-26` parses `--server` (`:21`) ... CF-063 owns relaxing the guard". Req5: awk NR==195 inventory row boundary cell = "`BUNKER_SERVER` must be set even when `--server` is passed (`scripts/verify-node.sh:17`, guarded before the argument loop)". Req6: `git ls-files docs/audits/code-factory-docs-2026-11-04-verify-env.md` tracked, 106 lines; contains §1 before/after table (2 rows for :127 and :195), §2 code path quoting lines 17-26, §3 Arm A (line-17 abort, RC=1) and Arm B (verify node probe-agent, agent_alive FAIL) transcripts, §5 "Claims I could not verify" (not measured), a `ch:trace row=CF-167 ...` line, and STATUS/TIER/EVIDENCE footer. Req7: jq select(.id=="CF-167") returns the row with probe "env -u BUNKER_SERVER ./scripts/verify-node.sh --agent probe-agent --server some-server --port 10800; echo rc=$?". Req8: `bash scripts/boardctl validate` -> "rows: 141 tasks, 249 events" / "RESULT: OK (3 warning(s))" rc=0. Gate: at this commit `bash tests/selftest.sh` -> "SELFTEST: PASS" rc=0 (141/141 rows parse); at base tip 9b7fb6f in a detached worktree -> "FAIL  audit-scope: docs/audits/code-factory-releng-2026-11-04-CF-163-AC3.md:39 ..." and ":77 ..." with "SELFTEST: FAIL (1)" rc=1 — the inherited red is gone and this commit adds no new failure or audit-scope violation. No code change to verify-node.sh was made or required (CF-063 owns that).
All eight executable requirements pass with literal output, the audit file carries every required section, and the selftest gate is PASS at this commit versus the documented inherited FAIL (1) at base tip 9b7fb6f.

## Summary

Judge Result: CF-167-DOC2

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Correct docs/OPERATIONS.md so the verify-node.sh recipe states the shipped environment contract instead of an intention, and file the row that carries the claim. This task grades a DOCUMENTATION CORRECTION, not a code fix: making --server self-sufficient is owned by row CF-063 and is NOT expected at this commit.

The claim: docs/OPERATIONS.md:127 said "Required environment: BUNKER_SERVER unless --server is supplied" and :195 listed the invocation with no environment precondition. scripts/verify-node.sh:17 assigns SERVER="${BUNKER_SERVER:?...}", so the shell expands that guard while executing line 17, before the argument loop at :18-26 reads argv (:21 handles --server).

Executable requirements (run each, compare literal output):
1. env -u BUNKER_SERVER ./scripts/verify-node.sh --agent probe-agent --server some-server --port 10800; echo rc=$? -> prints "./scripts/verify-node.sh: line 17: BUNKER_SERVER: set BUNKER_SERVER to your bunker server name" and rc=1, with no "verify node" banner.
2. BUNKER_SERVER=some-server ./scripts/verify-node.sh --agent probe-agent --server some-server --port 10800 -> prints "verify node probe-agent" and reaches the agent_alive row (control arm; the placeholder server then fails).
3. grep -n 'unless .--server. is supplied' docs/OPERATIONS.md -> no matches, exit 1.
4. awk 'NR==127' docs/OPERATIONS.md -> names scripts/verify-node.sh:17 and the argument loop at :18-26, states the env var is required even when --server is passed, and names CF-063 as the owner of relaxing the guard.
5. awk 'NR==195' docs/OPERATIONS.md -> the inventory boundary cell carries the same requirement.
6. docs/audits/code-factory-docs-2026-11-04-verify-env.md is present in the committed tree with the before/after table, the code path with line numbers, both arm transcripts, a "not measured" section, a ch:trace line and a STATUS/TIER/EVIDENCE footer.
7. jq -c 'select(.id=="CF-167")' .coding-hermes/board/tasks.jsonl -> row present with a non-empty probe.
8. bash scripts/boardctl validate -> RESULT: OK.

Gate expectation, stated so the judge does not grade an inherited defect: tests/selftest.sh is RED at the base tip 9b7fb6f with two audit-scope rows naming docs/audits/code-factory-releng-2026-11-04-CF-163-AC3.md:39 and :77 (a sibling lane's file, repair in flight). The requirement is that the same two rows and the same SELFTEST: FAIL (1) appear at this commit, i.e. this commit introduces NO new failure and adds no new audit-scope violation. Quote both runs, or the single run plus the base-tip worktree run recorded in docs/audits/code-factory-docs-2026-11-04-verify-env.md section 6. Do NOT require SELFTEST: PASS and do not grade the sibling audit file itself.: Req1: `env -u BUNKER_SERVER ./scripts/verify-node.sh --agent probe-agent --server some-server --port 10800` -> "./scripts/verify-node.sh: line 17: BUNKER_SERVER: set BUNKER_SERVER to your bunker server name" / rc=1, no banner. Req2: with BUNKER_SERVER=some-server -> "verify node probe-agent" then "FAIL  agent_alive — bunker: server \"some-server\" not found in config" / RESULT: FAIL. Req3: `grep -n 'unless .--server. is supplied' docs/OPERATIONS.md` -> no output, grep_rc=1. Req4: awk NR==127 = "3. Use `scripts/verify-node.sh --agent ID --server NAME ...` ... Required environment: `BUNKER_SERVER` must be set even when `--server NAME` is supplied — `scripts/verify-node.sh:17` expands `${BUNKER_SERVER:?…}` ... before the argument loop at `:18-26` parses `--server` (`:21`) ... CF-063 owns relaxing the guard". Req5: awk NR==195 inventory row boundary cell = "`BUNKER_SERVER` must be set even when `--server` is passed (`scripts/verify-node.sh:17`, guarded before the argument loop)". Req6: `git ls-files docs/audits/code-factory-docs-2026-11-04-verify-env.md` tracked, 106 lines; contains §1 before/after table (2 rows for :127 and :195), §2 code path quoting lines 17-26, §3 Arm A (line-17 abort, RC=1) and Arm B (verify node probe-agent, agent_alive FAIL) transcripts, §5 "Claims I could not verify" (not measured), a `ch:trace row=CF-167 ...` line, and STATUS/TIER/EVIDENCE footer. Req7: jq select(.id=="CF-167") returns the row with probe "env -u BUNKER_SERVER ./scripts/verify-node.sh --agent probe-agent --server some-server --port 10800; echo rc=$?". Req8: `bash scripts/boardctl validate` -> "rows: 141 tasks, 249 events" / "RESULT: OK (3 warning(s))" rc=0. Gate: at this commit `bash tests/selftest.sh` -> "SELFTEST: PASS" rc=0 (141/141 rows parse); at base tip 9b7fb6f in a detached worktree -> "FAIL  audit-scope: docs/audits/code-factory-releng-2026-11-04-CF-163-AC3.md:39 ..." and ":77 ..." with "SELFTEST: FAIL (1)" rc=1 — the inherited red is gone and this commit adds no new failure or audit-scope violation. No code change to verify-node.sh was made or required (CF-063 owns that).
All eight executable requirements pass with literal output, the audit file carries every required section, and the selftest gate is PASS at this commit versus the documented inherited FAIL (1) at base tip 9b7fb6f.

Overall: PASS ✓
