# Verdict: CF-144

**Task:** Dogfood filing: README fresh-host promise is false for two of three Quick start commands
**Evaluated:** 2026-11-04T02:28:14.161904
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ FILING ONLY — the repair is future work tracked by pending board row CF-144 and is NOT expected at this commit. The filing is correct when: (1) board row CF-144 exists on the published tree with status pending, a numbered acceptance list, and a re-runnable probe; (2) the probe prints the two raw aborts (rc1=1 at bunker-server-install.sh line 14, rc2=1 at node-create.sh line 70) from the repo root; (3) docs/audits/code-factory-dogfood-2026-11-04-02-20-15.md carries the captured output the row cites and the README.md:32-34 sentence it contradicts; (4) bash tests/selftest.sh prints SELFTEST: PASS.: (1) .coding-hermes/board/tasks.jsonl:118 has {"id":"CF-144","status":"pending"} with acceptance_criteria numbered 0.–4. and a non-empty `probe` shell field; committed in HEAD 51efb66 (tasks.jsonl + events.jsonl, event 172 task_created). (2) Ran from repo root /home/kara/code-factory: `scripts/bunker-server-install.sh --check` -> 'scripts/bunker-server-install.sh: line 14: BUNKER_SERVER: set BUNKER_SERVER to your bunker server name' rc1=1; `scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes` -> 'scripts/node-create.sh: line 70: SERVER: set BUNKER_SERVER to your bunker server name' rc2=1 — exact match to the criterion. (3) docs/audits/code-factory-dogfood-2026-11-04-02-20-15.md:106-116 carries the captured rc1=1/rc2=1 block, and :86-89 quotes the contradicted sentence 'On a host with no bunker server, no Crier and no repo, all three commands reach their checkers and fail with the missing value named.' which README.md:32-34 does contain (verified by sed). (4) `bash tests/selftest.sh` -> EXIT=0, final line 'SELFTEST: PASS' (log /tmp/st.log).
CF-144 is correctly filed: pending board row with numbered ACs and a re-runnable probe, the probe reproduces both raw aborts (rc1=1 line 14, rc2=1 line 70), the audit doc carries the captured output plus the README.md:32-34 sentence, and bash tests/selftest.sh exits 0 with SELFTEST: PASS.

## Summary

Judge Result: CF-144

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ FILING ONLY — the repair is future work tracked by pending board row CF-144 and is NOT expected at this commit. The filing is correct when: (1) board row CF-144 exists on the published tree with status pending, a numbered acceptance list, and a re-runnable probe; (2) the probe prints the two raw aborts (rc1=1 at bunker-server-install.sh line 14, rc2=1 at node-create.sh line 70) from the repo root; (3) docs/audits/code-factory-dogfood-2026-11-04-02-20-15.md carries the captured output the row cites and the README.md:32-34 sentence it contradicts; (4) bash tests/selftest.sh prints SELFTEST: PASS.: (1) .coding-hermes/board/tasks.jsonl:118 has {"id":"CF-144","status":"pending"} with acceptance_criteria numbered 0.–4. and a non-empty `probe` shell field; committed in HEAD 51efb66 (tasks.jsonl + events.jsonl, event 172 task_created). (2) Ran from repo root /home/kara/code-factory: `scripts/bunker-server-install.sh --check` -> 'scripts/bunker-server-install.sh: line 14: BUNKER_SERVER: set BUNKER_SERVER to your bunker server name' rc1=1; `scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes` -> 'scripts/node-create.sh: line 70: SERVER: set BUNKER_SERVER to your bunker server name' rc2=1 — exact match to the criterion. (3) docs/audits/code-factory-dogfood-2026-11-04-02-20-15.md:106-116 carries the captured rc1=1/rc2=1 block, and :86-89 quotes the contradicted sentence 'On a host with no bunker server, no Crier and no repo, all three commands reach their checkers and fail with the missing value named.' which README.md:32-34 does contain (verified by sed). (4) `bash tests/selftest.sh` -> EXIT=0, final line 'SELFTEST: PASS' (log /tmp/st.log).
CF-144 is correctly filed: pending board row with numbered ACs and a re-runnable probe, the probe reproduces both raw aborts (rc1=1 line 14, rc2=1 line 70), the audit doc carries the captured output plus the README.md:32-34 sentence, and bash tests/selftest.sh exits 0 with SELFTEST: PASS.

Overall: PASS ✓
