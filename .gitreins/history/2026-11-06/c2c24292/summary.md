# Verdict: CF-280

**Task:** lib.sh fetch_verified fails closed
**Evaluated:** 2026-11-06T13:09:18.701159
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Test lib.sh fetch_verified returns non-zero when its destination directory cannot be created and when the final mv fails, so a caller's failure branch is reachable; a selftest arm proves a FAIL row is printed rather than a silent success and the arm can go red when the guard is removed.: scripts/lib.sh:29-41 now checks both placement steps: `if ! mkdir -p "$dir"; then rm -f "$tmp"; printf 'cannot create destination directory %s for %s\n' ... >&2; return 1; fi` and `if ! mv "$tmp" "$dest"; then rm -f "$tmp"; printf 'cannot move verified download into place at %s for %s\n' ... >&2; return 1; fi`, followed by an explicit `return 0` at :41 so the trailing `chmod +x "$dest" 2>/dev/null || true` no longer decides the function's status. tests/selftest.sh:155-176 adds two arms: (a) `: > "$tmpd/blocker"` makes the destination's parent a regular FILE so mkdir -p fails ENOTDIR for root and non-root, asserting `fetch_rc -ne 0` AND `[ ! -e "$tmpd/blocker/bin" ]`; (b) a fixture caller (tests/selftest.sh:167-172) mirroring install-go.sh's `fetch_verified ... || { bad "go:download" ...; exit 1; }` shape, asserting rc!=0 and exactly one row matching `^  FAIL  go:download` (row-anchored, so a shell death cannot fake a pass). Test evidence: `bash tests/selftest.sh` (test_command from .gitreins/config.yaml) exited with final line `SELFTEST: PASS`, section 5 printing `PASS  uncreatable destination -> fetch_verified exit 1, no artifact installed` and `PASS  caller surfaced the failed install: 1 '^  FAIL  go:download' row, fixture exit 1`. Red-proof verified by reverting fetch_verified to the pre-fix body (unchecked mkdir/mv + `chmod ... || true`) and re-running the suite: section 5 then printed `FAIL  uncreatable destination was reported as a verified install (exit 0)` and `FAIL  caller did not surface the failed install (exit 0, 0 go:download row(s))` — both arms go red when the guard is removed. scripts/lib.sh was restored afterwards (git status clean).
fetch_verified now fails closed on both mkdir and mv failures with explicit return 1, and the two new selftest arms pass green on the fix and demonstrably go red when the guard is reverted.

## Summary

Judge Result: CF-280

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Test lib.sh fetch_verified returns non-zero when its destination directory cannot be created and when the final mv fails, so a caller's failure branch is reachable; a selftest arm proves a FAIL row is printed rather than a silent success and the arm can go red when the guard is removed.: scripts/lib.sh:29-41 now checks both placement steps: `if ! mkdir -p "$dir"; then rm -f "$tmp"; printf 'cannot create destination directory %s for %s\n' ... >&2; return 1; fi` and `if ! mv "$tmp" "$dest"; then rm -f "$tmp"; printf 'cannot move verified download into place at %s for %s\n' ... >&2; return 1; fi`, followed by an explicit `return 0` at :41 so the trailing `chmod +x "$dest" 2>/dev/null || true` no longer decides the function's status. tests/selftest.sh:155-176 adds two arms: (a) `: > "$tmpd/blocker"` makes the destination's parent a regular FILE so mkdir -p fails ENOTDIR for root and non-root, asserting `fetch_rc -ne 0` AND `[ ! -e "$tmpd/blocker/bin" ]`; (b) a fixture caller (tests/selftest.sh:167-172) mirroring install-go.sh's `fetch_verified ... || { bad "go:download" ...; exit 1; }` shape, asserting rc!=0 and exactly one row matching `^  FAIL  go:download` (row-anchored, so a shell death cannot fake a pass). Test evidence: `bash tests/selftest.sh` (test_command from .gitreins/config.yaml) exited with final line `SELFTEST: PASS`, section 5 printing `PASS  uncreatable destination -> fetch_verified exit 1, no artifact installed` and `PASS  caller surfaced the failed install: 1 '^  FAIL  go:download' row, fixture exit 1`. Red-proof verified by reverting fetch_verified to the pre-fix body (unchecked mkdir/mv + `chmod ... || true`) and re-running the suite: section 5 then printed `FAIL  uncreatable destination was reported as a verified install (exit 0)` and `FAIL  caller did not surface the failed install (exit 0, 0 go:download row(s))` — both arms go red when the guard is removed. scripts/lib.sh was restored afterwards (git status clean).
fetch_verified now fails closed on both mkdir and mv failures with explicit return 1, and the two new selftest arms pass green on the fix and demonstrably go red when the guard is reverted.

Overall: PASS ✓
