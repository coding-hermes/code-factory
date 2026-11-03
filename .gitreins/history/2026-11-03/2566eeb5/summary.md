# Verdict: CF-089

**Task:** README lanes census fails closed on a bad page and asserts coverage against total
**Evaluated:** 2026-11-03T18:56:01.012741
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ The README.md 'The lanes' census block and docs/audits/cf089-census-recipe.sh must abort with a named message and nonzero exit when any page fetch fails (curl nonzero), returns non-2xx, or carries no .projects array; and must fail naming both measured numbers when the enumerated code-factory rows do not equal the total reported by the first request. Each shape carries a tests/selftest.sh arm that is falsifiable (reverting the check makes it fail). bash tests/selftest.sh prints SELFTEST: PASS at the fixed tip.: README.md 'The lanes' bash block and docs/audits/cf089-census-recipe.sh are byte-identical (python parity check printed parity: True; only the BASE line differs by parameterisation) and both contain all four guards: 'census: fetch failed at offset=$2' (curl nonzero), 'census: HTTP $status at offset=$2; refusing to count' (non-2xx), 'census: missing or invalid .projects array at offset=$2', and 'census: rows received=$received != total reported=$total; refusing to count' — each with exit 1. tests/selftest.sh arms 22-27 drive each shape through real curl/jq against docs/audits/cf089-census-standin.py (modes fetch/broken/missing-projects/wrong-projects/nonjson/short/healthy/nototal), and arm 28 asserts README/mirror parity. Falsifiability proven by mutation in a copy (/tmp/cf089mut): dropping the curl-nonzero guard -> arm 22 FAIL, SELFTEST: FAIL (2), exit 1; dropping the non-2xx guard -> arm 23 FAIL, SELFTEST: FAIL (2), exit 1; dropping the .projects guard -> arm 24 FAIL x3, SELFTEST: FAIL (4), exit 1; dropping the row/total guard -> arm 25 FAIL, SELFTEST: FAIL (2), exit 1. At the fixed tip `bash tests/selftest.sh` exits 0 and prints 'SELFTEST: PASS' with arms 22-28 all PASS (the lone 'FAIL disk_floor' line is fixture stdout echoed by arm 16's PASS branch, not a failing arm).
README census block and its executable mirror fail closed with named messages and nonzero exits for all four bad-page shapes, each backed by a mutation-proven selftest arm, and bash tests/selftest.sh exits 0 with SELFTEST: PASS at the fixed tip.

## Summary

Judge Result: CF-089

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ The README.md 'The lanes' census block and docs/audits/cf089-census-recipe.sh must abort with a named message and nonzero exit when any page fetch fails (curl nonzero), returns non-2xx, or carries no .projects array; and must fail naming both measured numbers when the enumerated code-factory rows do not equal the total reported by the first request. Each shape carries a tests/selftest.sh arm that is falsifiable (reverting the check makes it fail). bash tests/selftest.sh prints SELFTEST: PASS at the fixed tip.: README.md 'The lanes' bash block and docs/audits/cf089-census-recipe.sh are byte-identical (python parity check printed parity: True; only the BASE line differs by parameterisation) and both contain all four guards: 'census: fetch failed at offset=$2' (curl nonzero), 'census: HTTP $status at offset=$2; refusing to count' (non-2xx), 'census: missing or invalid .projects array at offset=$2', and 'census: rows received=$received != total reported=$total; refusing to count' — each with exit 1. tests/selftest.sh arms 22-27 drive each shape through real curl/jq against docs/audits/cf089-census-standin.py (modes fetch/broken/missing-projects/wrong-projects/nonjson/short/healthy/nototal), and arm 28 asserts README/mirror parity. Falsifiability proven by mutation in a copy (/tmp/cf089mut): dropping the curl-nonzero guard -> arm 22 FAIL, SELFTEST: FAIL (2), exit 1; dropping the non-2xx guard -> arm 23 FAIL, SELFTEST: FAIL (2), exit 1; dropping the .projects guard -> arm 24 FAIL x3, SELFTEST: FAIL (4), exit 1; dropping the row/total guard -> arm 25 FAIL, SELFTEST: FAIL (2), exit 1. At the fixed tip `bash tests/selftest.sh` exits 0 and prints 'SELFTEST: PASS' with arms 22-28 all PASS (the lone 'FAIL disk_floor' line is fixture stdout echoed by arm 16's PASS branch, not a failing arm).
README census block and its executable mirror fail closed with named messages and nonzero exits for all four bad-page shapes, each backed by a mutation-proven selftest arm, and bash tests/selftest.sh exits 0 with SELFTEST: PASS at the fixed tip.

Overall: PASS ✓
