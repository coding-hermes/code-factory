# Verdict: CF-163-L1

**Task:** Public posture: a gitleaks claim must name its scan scope (CF-163 AC3 slice)
**Evaluated:** 2026-11-04T06:26:33.177930
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ scripts/check_scan_scope.py exists and, over docs/audits/code-factory-releng-*.md and docs/SECURITY-TRIAGE.md, exits 1 naming a FAIL row for any file/line that mentions gitleaks without --log-opts on that line, and exits 0 printing OK when all claims name their scope; docs/audits/code-factory-releng-2026-11-04-CF-161.md no longer carries an unscoped gitleaks claim (it names --log-opts and discloses the correction); tests/selftest.sh carries a section proving the gate red on a fixture with an unscoped line and green on the real tree; bash tests/selftest.sh exits 0 with SELFTEST: PASS.: scripts/check_scan_scope.py exists (116 lines): AUDIT_GLOB='docs/audits/code-factory-releng-*.md' + FIXED_FILES=('docs/SECURITY-TRIAGE.md'); scan() flags any line containing 'gitleaks' without '--log-opts' (lines 64-69) and main() prints '  FAIL  audit-scope: <relpath>:<lineno> gitleaks claim names no --log-opts' then 'RESULT: FAIL (N violation(s))' returning 1 (lines 100-104). Live red proof on a fixture: `python3 scripts/check_scan_scope.py $tmpd` -> '  FAIL  audit-scope: docs/audits/code-factory-releng-fixture.md:1 gitleaks claim names no --log-opts / RESULT: FAIL (1 violation(s))' rc=1. Live green on real tree: '  OK  audit-scope: 3 gitleaks claim(s) name their --log-opts / RESULT: OK' rc=0. CF-161 line 25 now reads `gitleaks detect -c .gitleaks.toml --redact --log-opts="--all"` with a correction blockquote at lines 27-30 ('Correction (CF-163 AC3): the original arm above recorded no --log-opts ... not reproducible as a scope ... Re-measured ... --log-opts="--all" -> 547 findings; --log-opts="origin/main" -> 0 findings'). tests/selftest.sh lines 1316-1351 add section '34. a posture doc's gitleaks claim names its scan scope (CF-163 AC3)' with three arms: green on real tree, red on unscoped fixture (asserts rc=1 and the named FAIL row regex), green after the fixture names --log-opts. `bash tests/selftest.sh` -> rc=0, tail 'SELFTEST: PASS', 106 PASS rows, section 34 shows 'PASS posture docs name their scan scope / PASS unscoped claim -> FAIL audit-scope / PASS scoped claim -> OK'.
check_scan_scope.py enforces the --log-opts scope rule (rc=1 with named FAIL rows on an unscoped fixture, rc=0 OK on the real tree), CF-161's claim is corrected with disclosure, and bash tests/selftest.sh exits 0 with SELFTEST: PASS.

## Summary

Judge Result: CF-163-L1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ scripts/check_scan_scope.py exists and, over docs/audits/code-factory-releng-*.md and docs/SECURITY-TRIAGE.md, exits 1 naming a FAIL row for any file/line that mentions gitleaks without --log-opts on that line, and exits 0 printing OK when all claims name their scope; docs/audits/code-factory-releng-2026-11-04-CF-161.md no longer carries an unscoped gitleaks claim (it names --log-opts and discloses the correction); tests/selftest.sh carries a section proving the gate red on a fixture with an unscoped line and green on the real tree; bash tests/selftest.sh exits 0 with SELFTEST: PASS.: scripts/check_scan_scope.py exists (116 lines): AUDIT_GLOB='docs/audits/code-factory-releng-*.md' + FIXED_FILES=('docs/SECURITY-TRIAGE.md'); scan() flags any line containing 'gitleaks' without '--log-opts' (lines 64-69) and main() prints '  FAIL  audit-scope: <relpath>:<lineno> gitleaks claim names no --log-opts' then 'RESULT: FAIL (N violation(s))' returning 1 (lines 100-104). Live red proof on a fixture: `python3 scripts/check_scan_scope.py $tmpd` -> '  FAIL  audit-scope: docs/audits/code-factory-releng-fixture.md:1 gitleaks claim names no --log-opts / RESULT: FAIL (1 violation(s))' rc=1. Live green on real tree: '  OK  audit-scope: 3 gitleaks claim(s) name their --log-opts / RESULT: OK' rc=0. CF-161 line 25 now reads `gitleaks detect -c .gitleaks.toml --redact --log-opts="--all"` with a correction blockquote at lines 27-30 ('Correction (CF-163 AC3): the original arm above recorded no --log-opts ... not reproducible as a scope ... Re-measured ... --log-opts="--all" -> 547 findings; --log-opts="origin/main" -> 0 findings'). tests/selftest.sh lines 1316-1351 add section '34. a posture doc's gitleaks claim names its scan scope (CF-163 AC3)' with three arms: green on real tree, red on unscoped fixture (asserts rc=1 and the named FAIL row regex), green after the fixture names --log-opts. `bash tests/selftest.sh` -> rc=0, tail 'SELFTEST: PASS', 106 PASS rows, section 34 shows 'PASS posture docs name their scan scope / PASS unscoped claim -> FAIL audit-scope / PASS scoped claim -> OK'.
check_scan_scope.py enforces the --log-opts scope rule (rc=1 with named FAIL rows on an unscoped fixture, rc=0 OK on the real tree), CF-161's claim is corrected with disclosure, and bash tests/selftest.sh exits 0 with SELFTEST: PASS.

Overall: PASS ✓
