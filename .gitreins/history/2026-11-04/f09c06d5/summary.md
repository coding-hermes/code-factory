# Verdict: CF-163-L3

**Task:** CF-163 AC3: restore the audit-scope gate on the published tip
**Evaluated:** 2026-11-04T06:39:39.863591
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ bash tests/selftest.sh exits 0 with SELFTEST: PASS at the published tip, and python3 scripts/check_scan_scope.py reports RESULT: OK (0 violations) over docs/audits/code-factory-releng-*.md; the two failing claim sites in docs/audits/code-factory-releng-2026-11-04-CF-163-AC3.md (lines 39 and 77) must name their --log-opts scope instead of removing the gitleaks references: All three sub-requirements verified with fresh command output at HEAD 8995064. (1) `bash tests/selftest.sh` -> SELFTEST_EXIT=0, output line 'SELFTEST: PASS', 107 PASS rows; section 34 'a posture doc's gitleaks claim names its scan scope (CF-163 AC3)' shows 3 PASS rows including 'unscoped claim -> FAIL audit-scope' and 'scoped claim -> OK'. (2) `python3 scripts/check_scan_scope.py` -> SCANSCOPE_EXIT=0, output '  OK  audit-scope: 7 gitleaks claim(s) name their --log-opts' / 'RESULT: OK' (0 violations). (3) Both claim sites name their scope with gitleaks references PRESERVED: line 39 = '## Landed: CF-163 AC3 (one gitleaks claim must name its `--log-opts` scan scope)'; line 77 = '| published ref surface | ... `gitleaks detect --redact --log-opts="--all"` (1152 commits, 57.39 MB) -> 547 findings in 64 commits, all 64 on `master` | ...'. grep -n gitleaks shows 4 occurrences (39, 48, 58, 77) all retained; the diff shows the old text '547 gitleaks findings on 64 commits' was rewritten to name the arm, not deleted. ANTI-GAMING: `git diff-tree --no-commit-id --name-only -r HEAD` shows the commit changed ONLY docs/audits/code-factory-releng-2026-11-04-CF-163-AC3.md — scripts/check_scan_scope.py was last touched in 5794a49, so the gate was not weakened. Pre-repair tree extracted via `git archive HEAD~1` to /tmp/prerepair_check and run against the gate -> exit 1 with exactly 'FAIL audit-scope: docs/audits/code-factory-releng-2026-11-04-CF-163-AC3.md:39 gitleaks claim names no --log-opts' and the same for :77, 'RESULT: FAIL (2 violation(s))', confirming the fix addresses a real defect and the gate still detects unscoped claims.
Both gates are green at the published tip (selftest exit 0 with SELFTEST: PASS; check_scan_scope exit 0 with RESULT: OK), and lines 39 and 77 now name their --log-opts scope while retaining the gitleaks references, with the gate script unmodified and the pre-repair tree verifiably RED on exactly those two sites.

## Summary

Judge Result: CF-163-L3

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ bash tests/selftest.sh exits 0 with SELFTEST: PASS at the published tip, and python3 scripts/check_scan_scope.py reports RESULT: OK (0 violations) over docs/audits/code-factory-releng-*.md; the two failing claim sites in docs/audits/code-factory-releng-2026-11-04-CF-163-AC3.md (lines 39 and 77) must name their --log-opts scope instead of removing the gitleaks references: All three sub-requirements verified with fresh command output at HEAD 8995064. (1) `bash tests/selftest.sh` -> SELFTEST_EXIT=0, output line 'SELFTEST: PASS', 107 PASS rows; section 34 'a posture doc's gitleaks claim names its scan scope (CF-163 AC3)' shows 3 PASS rows including 'unscoped claim -> FAIL audit-scope' and 'scoped claim -> OK'. (2) `python3 scripts/check_scan_scope.py` -> SCANSCOPE_EXIT=0, output '  OK  audit-scope: 7 gitleaks claim(s) name their --log-opts' / 'RESULT: OK' (0 violations). (3) Both claim sites name their scope with gitleaks references PRESERVED: line 39 = '## Landed: CF-163 AC3 (one gitleaks claim must name its `--log-opts` scan scope)'; line 77 = '| published ref surface | ... `gitleaks detect --redact --log-opts="--all"` (1152 commits, 57.39 MB) -> 547 findings in 64 commits, all 64 on `master` | ...'. grep -n gitleaks shows 4 occurrences (39, 48, 58, 77) all retained; the diff shows the old text '547 gitleaks findings on 64 commits' was rewritten to name the arm, not deleted. ANTI-GAMING: `git diff-tree --no-commit-id --name-only -r HEAD` shows the commit changed ONLY docs/audits/code-factory-releng-2026-11-04-CF-163-AC3.md — scripts/check_scan_scope.py was last touched in 5794a49, so the gate was not weakened. Pre-repair tree extracted via `git archive HEAD~1` to /tmp/prerepair_check and run against the gate -> exit 1 with exactly 'FAIL audit-scope: docs/audits/code-factory-releng-2026-11-04-CF-163-AC3.md:39 gitleaks claim names no --log-opts' and the same for :77, 'RESULT: FAIL (2 violation(s))', confirming the fix addresses a real defect and the gate still detects unscoped claims.
Both gates are green at the published tip (selftest exit 0 with SELFTEST: PASS; check_scan_scope exit 0 with RESULT: OK), and lines 39 and 77 now name their --log-opts scope while retaining the gitleaks references, with the gate script unmodified and the pre-repair tree verifiably RED on exactly those two sites.

Overall: PASS ✓
