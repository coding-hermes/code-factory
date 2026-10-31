# Verdict: CF-011

**Task:** Repair AGENTS credential rule trace
**Evaluated:** 2026-10-31T12:38:58.179609
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: harness state excluded from gitleaks scope (.gitreins/**)
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ 1. Every row id cited in AGENTS.md resolves to a row in .coding-hermes/board/tasks.jsonl.: AGENTS.md:41 cites `CF-002`, the only concrete row id in the file. A Python census over AGENTS.md vs tasks.jsonl returned cited=['CF-00','CF-002'] with CF-002 -> RESOLVES; the 'CF-00' hit is the template placeholder `CF-00N` at AGENTS.md:56 and :79, not a row id. Board contains 24 rows (CF-001..CF-015, CF-030..CF-038). `grep -rn CF-108` finds no occurrence in AGENTS.md (only historical docs/audits/*.md and docs/ACCEPTANCE-PLAN.md).
  ✓ 2. The corrected citation points at the row carrying credential acceptance criteria.: `git show 2630c3e -- AGENTS.md` shows the credential rule line changed from `CF-108` to `CF-002`. tasks.jsonl row CF-002 is "Node inference credential: restricted inference key, fail-closed on revoke" with acceptance_criteria: restricted key limited to needed models, ~/.hermes/.env mode 600 never in argv or a log, revoke fails closed, no operator credential copied to any agent — exactly the subject of AGENTS.md rule 8 ("one bundle file, mode 600, deleted after provisioning").
  ✓ 3. bash tests/selftest.sh exits 0 and prints SELFTEST: PASS.: Ran `bash tests/selftest.sh` in /home/kara/code-factory-review-2026-10-30-2035: exit_code 0, final line `SELFTEST: PASS`. All 7 sections PASS, including `5. the board is valid JSONL  PASS  24/24 rows parse` and `4. no literal credential assignments  PASS  none found`.
AGENTS.md's dead CF-108 credential citation was corrected to CF-002 (the board row that owns credential acceptance criteria), all cited row ids resolve, and tests/selftest.sh exits 0 printing SELFTEST: PASS.

## Summary

Judge Result: CF-011

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: harness state excluded from gitleaks scope (.gitreins/**)
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ 1. Every row id cited in AGENTS.md resolves to a row in .coding-hermes/board/tasks.jsonl.: AGENTS.md:41 cites `CF-002`, the only concrete row id in the file. A Python census over AGENTS.md vs tasks.jsonl returned cited=['CF-00','CF-002'] with CF-002 -> RESOLVES; the 'CF-00' hit is the template placeholder `CF-00N` at AGENTS.md:56 and :79, not a row id. Board contains 24 rows (CF-001..CF-015, CF-030..CF-038). `grep -rn CF-108` finds no occurrence in AGENTS.md (only historical docs/audits/*.md and docs/ACCEPTANCE-PLAN.md).
  ✓ 2. The corrected citation points at the row carrying credential acceptance criteria.: `git show 2630c3e -- AGENTS.md` shows the credential rule line changed from `CF-108` to `CF-002`. tasks.jsonl row CF-002 is "Node inference credential: restricted inference key, fail-closed on revoke" with acceptance_criteria: restricted key limited to needed models, ~/.hermes/.env mode 600 never in argv or a log, revoke fails closed, no operator credential copied to any agent — exactly the subject of AGENTS.md rule 8 ("one bundle file, mode 600, deleted after provisioning").
  ✓ 3. bash tests/selftest.sh exits 0 and prints SELFTEST: PASS.: Ran `bash tests/selftest.sh` in /home/kara/code-factory-review-2026-10-30-2035: exit_code 0, final line `SELFTEST: PASS`. All 7 sections PASS, including `5. the board is valid JSONL  PASS  24/24 rows parse` and `4. no literal credential assignments  PASS  none found`.
AGENTS.md's dead CF-108 credential citation was corrected to CF-002 (the board row that owns credential acceptance criteria), all cited row ids resolve, and tests/selftest.sh exits 0 printing SELFTEST: PASS.

Overall: PASS ✓
