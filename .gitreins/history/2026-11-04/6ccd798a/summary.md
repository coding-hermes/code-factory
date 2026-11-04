# Verdict: CF-157

**Task:** README asserts all fourteen shipped lanes are enabled=true, but the shipped census recipe prints code-factory-qa enabled=false
**Evaluated:** 2026-11-04T03:49:14.428936
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ README.md no longer asserts that the fourteen shipped lanes are all enabled on the live deployment: the sentence must present the enabled state as a dated measurement and point the reader at the census command as the authority. Verify: bash tests/selftest.sh prints SELFTEST: PASS; grep -c 'all .enabled=true' README.md returns 0 on the committed tree; bash docs/audits/cf089-census-recipe.sh still prints 19 rows.: All three verification steps confirmed on the committed tree (HEAD 7c51fbe). (1) `bash tests/selftest.sh` -> exit_code 0, final line `SELFTEST: PASS`; section 28 'README census and executable mirror agree except for BASE' -> `PASS  census README/mirror byte parity (BASE parameterisation only)`, proving the census code block was untouched. The 19 `FAIL` lines in the log are expected negative-fixture output inside passing sections (e.g. section 7b 'board gate rejects invalid records with line-numbered FAIL rows (CF-088)' -> `PASS  null fixture rejected, exit 1`), not suite failures. (2) `grep -c 'all .enabled=true' README.md` -> `0` (grep exit 1, no match); the only surviving enabled=true mention is README.md:209 `thirteen carried \`enabled=true\` and \`code-factory-qa\` carried \`enabled=false\``. (3) `bash docs/audits/cf089-census-recipe.sh` -> prints `19` followed by 19 code-factory rows, including `code-factory-qa enabled=false admission=cooldown parent=code-factory`. Wording at README.md:205-212 reads 'That command is the authority, not this paragraph. On the reference deployment, on 2026-11-04, it printed nineteen rows: ... Of the fourteen, thirteen carried `enabled=true` and `code-factory-qa` carried `enabled=false` ...' — a dated measurement that names the census command as the authority.
README.md now dates the enabled-state measurement (2026-11-04) and defers to the census command as authority; selftest passes (exit 0, SELFTEST: PASS), the 'all enabled=true' assertion is gone (grep count 0), and the census recipe still prints 19 rows with code-factory-qa enabled=false.

## Summary

Judge Result: CF-157

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ README.md no longer asserts that the fourteen shipped lanes are all enabled on the live deployment: the sentence must present the enabled state as a dated measurement and point the reader at the census command as the authority. Verify: bash tests/selftest.sh prints SELFTEST: PASS; grep -c 'all .enabled=true' README.md returns 0 on the committed tree; bash docs/audits/cf089-census-recipe.sh still prints 19 rows.: All three verification steps confirmed on the committed tree (HEAD 7c51fbe). (1) `bash tests/selftest.sh` -> exit_code 0, final line `SELFTEST: PASS`; section 28 'README census and executable mirror agree except for BASE' -> `PASS  census README/mirror byte parity (BASE parameterisation only)`, proving the census code block was untouched. The 19 `FAIL` lines in the log are expected negative-fixture output inside passing sections (e.g. section 7b 'board gate rejects invalid records with line-numbered FAIL rows (CF-088)' -> `PASS  null fixture rejected, exit 1`), not suite failures. (2) `grep -c 'all .enabled=true' README.md` -> `0` (grep exit 1, no match); the only surviving enabled=true mention is README.md:209 `thirteen carried \`enabled=true\` and \`code-factory-qa\` carried \`enabled=false\``. (3) `bash docs/audits/cf089-census-recipe.sh` -> prints `19` followed by 19 code-factory rows, including `code-factory-qa enabled=false admission=cooldown parent=code-factory`. Wording at README.md:205-212 reads 'That command is the authority, not this paragraph. On the reference deployment, on 2026-11-04, it printed nineteen rows: ... Of the fourteen, thirteen carried `enabled=true` and `code-factory-qa` carried `enabled=false` ...' — a dated measurement that names the census command as the authority.
README.md now dates the enabled-state measurement (2026-11-04) and defers to the census command as authority; selftest passes (exit 0, SELFTEST: PASS), the 'all enabled=true' assertion is gone (grep count 0), and the census recipe still prints 19 rows with code-factory-qa enabled=false.

Overall: PASS ✓
