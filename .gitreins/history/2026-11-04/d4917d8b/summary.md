# Verdict: CF-144

**Task:** Dogfood filing: README fresh-host promise is false for two of three Quick start commands
**Evaluated:** 2026-11-04T02:31:39.148603
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ FILING ONLY — the repair is future work tracked by pending board row CF-144 and is NOT expected at this commit. The filing is correct when: (1) board row CF-144 exists on the published tree with status pending, a numbered acceptance list, and a re-runnable probe; (2) the probe prints the two raw aborts (rc1=1 at bunker-server-install.sh line 14, rc2=1 at node-create.sh line 70) from the repo root; (3) docs/audits/code-factory-dogfood-2026-11-04-02-20-15.md carries the captured output the row cites and the README.md:32-34 sentence it contradicts; (4) bash tests/selftest.sh prints SELFTEST: PASS.: (1) Row exists on the published tree as CF-145 (renumbered from the drafted CF-144 by the append helper, delta=1, because a sibling lane consumed CF-144 at 51efb66; the renumber is documented at docs/audits/code-factory-dogfood-2026-11-04-02-20-15.md:106-110 and in the commit message). `git show origin/main:.coding-hermes/board/tasks.jsonl | jq 'select(.id=="CF-145")'` returns status=pending, acceptance_criteria with numbered items 1-4, and a non-empty probe; `git rev-list --count origin/main..HEAD` = 0 so the row is published. (2) Probe run from repo root reproduced verbatim: 'scripts/bunker-server-install.sh: line 14: BUNKER_SERVER: set BUNKER_SERVER to your bunker server name' / rc1=1, then 'scripts/node-create.sh: line 70: SERVER: set BUNKER_SERVER to your bunker server name' / rc2=1. (3) Audit doc carries the captured blocks at lines 31, 71, 79 and the exact probe transcript at lines 116-119 (rc1=1, rc2=1); lines 88-89 quote the contradicted sentence, which matches README.md:32-34 verbatim ('On a host with no bunker server, no Crier and no repo, all three commands reach their checkers and fail with the missing value named.'). (4) `bash tests/selftest.sh` -> EXIT=0, final line 'SELFTEST: PASS' (89 PASS lines, 0 FAIL lines).
The filing is correct: pending row CF-145 (renumbered from CF-144, documented) carries numbered ACs and a probe that reproduces both raw aborts (rc1=1 line 14, rc2=1 line 70), the audit doc holds the captured output and the contradicted README.md:32-34 sentence, and bash tests/selftest.sh exits 0 printing SELFTEST: PASS.

## Summary

Judge Result: CF-144

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ FILING ONLY — the repair is future work tracked by pending board row CF-144 and is NOT expected at this commit. The filing is correct when: (1) board row CF-144 exists on the published tree with status pending, a numbered acceptance list, and a re-runnable probe; (2) the probe prints the two raw aborts (rc1=1 at bunker-server-install.sh line 14, rc2=1 at node-create.sh line 70) from the repo root; (3) docs/audits/code-factory-dogfood-2026-11-04-02-20-15.md carries the captured output the row cites and the README.md:32-34 sentence it contradicts; (4) bash tests/selftest.sh prints SELFTEST: PASS.: (1) Row exists on the published tree as CF-145 (renumbered from the drafted CF-144 by the append helper, delta=1, because a sibling lane consumed CF-144 at 51efb66; the renumber is documented at docs/audits/code-factory-dogfood-2026-11-04-02-20-15.md:106-110 and in the commit message). `git show origin/main:.coding-hermes/board/tasks.jsonl | jq 'select(.id=="CF-145")'` returns status=pending, acceptance_criteria with numbered items 1-4, and a non-empty probe; `git rev-list --count origin/main..HEAD` = 0 so the row is published. (2) Probe run from repo root reproduced verbatim: 'scripts/bunker-server-install.sh: line 14: BUNKER_SERVER: set BUNKER_SERVER to your bunker server name' / rc1=1, then 'scripts/node-create.sh: line 70: SERVER: set BUNKER_SERVER to your bunker server name' / rc2=1. (3) Audit doc carries the captured blocks at lines 31, 71, 79 and the exact probe transcript at lines 116-119 (rc1=1, rc2=1); lines 88-89 quote the contradicted sentence, which matches README.md:32-34 verbatim ('On a host with no bunker server, no Crier and no repo, all three commands reach their checkers and fail with the missing value named.'). (4) `bash tests/selftest.sh` -> EXIT=0, final line 'SELFTEST: PASS' (89 PASS lines, 0 FAIL lines).
The filing is correct: pending row CF-145 (renumbered from CF-144, documented) carries numbered ACs and a probe that reproduces both raw aborts (rc1=1 line 14, rc2=1 line 70), the audit doc holds the captured output and the contradicted README.md:32-34 sentence, and bash tests/selftest.sh exits 0 printing SELFTEST: PASS.

Overall: PASS ✓
