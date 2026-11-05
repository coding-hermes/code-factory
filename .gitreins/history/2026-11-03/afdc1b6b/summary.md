# Verdict: CF-073-QA1

**Task:** QA filing: three complete rows (CF-052, PERF-012, CF-058) carry closure digests that resolve to no git object
**Evaluated:** 2026-11-03T14:57:43.322201
**Result:** ✗ FAIL

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✗ **tier2**
  - INCOMPLETE
  ✗ Reproduce: run the CF-073 probe field verbatim from the repo root; it must print three 'fatal: Not a valid object name' lines for CF-052 (64 zeros), PERF-012 (a7e996a2...) and CF-058 (839710de...). Verify the fix: for each of the three rows, the newest detail.evidence entry has a tree_fp where 'git cat-file -t <fp>' prints 'tree' (or the field reads none:<reason>), and the board writer/validator FAILs a row whose tree_fp is 64 zeros while PASSing a row whose tree_fp equals 'git rev-parse <commit_hash>^{tree}'. Verify the gate: 'bash tests/selftest.sh' prints SELFTEST: PASS and 'scripts/boardctl validate' prints RESULT: OK at the fixed tip.: Reproduce half PASSES: running the probe field verbatim from the repo root prints exactly three lines and exits 0 — 'CF-052 run_id=222a8b0 tree_fp=000000000000 -> fatal: Not a valid object name 0000...', 'PERF-012 ... a7e996a21e8c -> fatal: Not a valid object name a7e996a2...', 'CF-058 ... 839710de66cb -> fatal: Not a valid object name 839710de...'. Gate half PASSES: 'bash tests/selftest.sh' ends with 'SELFTEST: PASS' (exit 0) and 'scripts/boardctl validate' prints 'RESULT: OK (15 warning(s))' (exit 0). BUT the fix is entirely absent: (a) CF-052, PERF-012 and CF-058 each still carry exactly ONE detail.evidence entry with the same unresolvable tree_fp (0000...0000, a7e996a2..., 839710de...) — no appended entry, no 'none:<reason>' value; 'git cat-file -t' fails for all three. (b) No writer/validator check exists: 'grep -rn tree_fp scripts tests docs' returns zero hits; scripts/boardctl is a 21-line wrapper that execs an external Go binary with no tree_fp logic. Empirically, 'boardctl update CF-073 --evidence-run-id test-run --evidence-fingerprint 0000...(64 zeros)' printed 'updated task CF-073: detail, updated_at' with exit 0 (placeholder accepted), and 'scripts/boardctl validate' on a board where complete row CF-052's tree_fp was set to deadbeef*8 still printed 'RESULT: OK (14 warning(s))' with exit 0 — no FAIL, no row id, no offending field named. The last commit b430bed only adds the CF-073 row itself (1 insertion in tasks.jsonl); no code, test, or row fix was made. Board was restored to HEAD after these experiments.
The probe reproduces and the gate is green, but none of the actual fix work was done — the three rows still carry the unresolvable digests and the board writer/validator accepts a 64-zero placeholder with exit 0.

## Summary

Judge Result: CF-073-QA1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: FAIL
  INCOMPLETE
  ✗ Reproduce: run the CF-073 probe field verbatim from the repo root; it must print three 'fatal: Not a valid object name' lines for CF-052 (64 zeros), PERF-012 (a7e996a2...) and CF-058 (839710de...). Verify the fix: for each of the three rows, the newest detail.evidence entry has a tree_fp where 'git cat-file -t <fp>' prints 'tree' (or the field reads none:<reason>), and the board writer/validator FAILs a row whose tree_fp is 64 zeros while PASSing a row whose tree_fp equals 'git rev-parse <commit_hash>^{tree}'. Verify the gate: 'bash tests/selftest.sh' prints SELFTEST: PASS and 'scripts/boardctl validate' prints RESULT: OK at the fixed tip.: Reproduce half PASSES: running the probe field verbatim from the repo root prints exactly three lines and exits 0 — 'CF-052 run_id=222a8b0 tree_fp=000000000000 -> fatal: Not a valid object name 0000...', 'PERF-012 ... a7e996a21e8c -> fatal: Not a valid object name a7e996a2...', 'CF-058 ... 839710de66cb -> fatal: Not a valid object name 839710de...'. Gate half PASSES: 'bash tests/selftest.sh' ends with 'SELFTEST: PASS' (exit 0) and 'scripts/boardctl validate' prints 'RESULT: OK (15 warning(s))' (exit 0). BUT the fix is entirely absent: (a) CF-052, PERF-012 and CF-058 each still carry exactly ONE detail.evidence entry with the same unresolvable tree_fp (0000...0000, a7e996a2..., 839710de...) — no appended entry, no 'none:<reason>' value; 'git cat-file -t' fails for all three. (b) No writer/validator check exists: 'grep -rn tree_fp scripts tests docs' returns zero hits; scripts/boardctl is a 21-line wrapper that execs an external Go binary with no tree_fp logic. Empirically, 'boardctl update CF-073 --evidence-run-id test-run --evidence-fingerprint 0000...(64 zeros)' printed 'updated task CF-073: detail, updated_at' with exit 0 (placeholder accepted), and 'scripts/boardctl validate' on a board where complete row CF-052's tree_fp was set to deadbeef*8 still printed 'RESULT: OK (14 warning(s))' with exit 0 — no FAIL, no row id, no offending field named. The last commit b430bed only adds the CF-073 row itself (1 insertion in tasks.jsonl); no code, test, or row fix was made. Board was restored to HEAD after these experiments.
The probe reproduces and the gate is green, but none of the actual fix work was done — the three rows still carry the unresolvable digests and the board writer/validator accepts a 64-zero placeholder with exit 0.

Overall: FAIL ✗
