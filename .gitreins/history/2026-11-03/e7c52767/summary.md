# Verdict: CF-089-QA1

**Task:** README census recipe reports a failed page as an empty page
**Evaluated:** 2026-11-03T16:56:44.191199
**Result:** ✗ FAIL

## Pipeline Stages

- ✗ **tier1**
  -   ✗ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Filing row CF-089 with a reproduced probe transcript committed under docs/audits: the verbatim README census recipe prints 1 matching row and exits 0 against a stand-in scheduler that 200s page 0 and 502s page 500 while two matching rows exist across that boundary; the board row states falsifiable acceptance criteria for per-page failure detection and a coverage assertion.: All elements verified live. (a) Transcript committed: `git ls-files docs/audits/` lists docs/audits/code-factory-qa-2026-11-03-cf089.probe.txt, added in commit 03f59e8. (b) Reproduction re-run by me, not just read: started docs/audits/cf089-census-standin.py, then `curl .../projects?limit=500&offset=0` -> `total=866 page0=500`; `curl -o /dev/null -w http=%{http_code} .../offset=500` -> `http=502`; `BASE=http://127.0.0.1:18999 bash docs/audits/cf089-census-recipe.sh` -> `jq: error (at <stdin>:0): Cannot iterate over null (null)` / `1` / `code-factory enabled=true admission=cooldown parent=x` / `RC=0` — exactly 1 matching row printed and exit 0, matching the committed transcript verbatim. (c) Two matching rows across the boundary: cf089-census-standin.py:12 `name = "code-factory" if i in (0, 600) else ...` — index 0 on page 0, index 600 only reachable via the 502 page. (d) Recipe is verbatim README: `diff` of README.md lines 158-168 (with 127.0.0.1:9090 -> $BASE) against docs/audits/cf089-census-recipe.sh lines 4-14 returned diff_rc=0. (e) Board row .coding-hermes/board/tasks.jsonl:76 CF-089 acceptance_criteria states falsifiable per-page failure detection (AC1: 'Any page whose fetch fails (curl nonzero), whose status is not 2xx, or whose body carries no .projects array aborts the census with a named message and a nonzero exit; one tests/selftest.sh arm per shape') and a coverage assertion (AC2: 'the number of project rows enumerated equals the total reported by the first request, or it fails naming both measured numbers'), plus AC3 falsifiability ('reverting the check makes each fixture fail with the named row, and bash tests/selftest.sh prints SELFTEST: PASS at the fixed tip'). Event .coding-hermes/board/events.jsonl:91 records task_created CF-089. (f) Test suite: `bash tests/selftest.sh` -> `SELFTEST: PASS`, exit_code 0.
CF-089 is filed with a committed, independently reproduced probe transcript showing the verbatim README census recipe printing 1 row and exiting 0 against a stand-in that 502s page 500 while 2 matching rows exist, and the board row carries falsifiable per-page-failure and coverage-assertion acceptance criteria.

## Summary

Judge Result: CF-089-QA1

Stage tier1: FAIL
    ✗ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Filing row CF-089 with a reproduced probe transcript committed under docs/audits: the verbatim README census recipe prints 1 matching row and exits 0 against a stand-in scheduler that 200s page 0 and 502s page 500 while two matching rows exist across that boundary; the board row states falsifiable acceptance criteria for per-page failure detection and a coverage assertion.: All elements verified live. (a) Transcript committed: `git ls-files docs/audits/` lists docs/audits/code-factory-qa-2026-11-03-cf089.probe.txt, added in commit 03f59e8. (b) Reproduction re-run by me, not just read: started docs/audits/cf089-census-standin.py, then `curl .../projects?limit=500&offset=0` -> `total=866 page0=500`; `curl -o /dev/null -w http=%{http_code} .../offset=500` -> `http=502`; `BASE=http://127.0.0.1:18999 bash docs/audits/cf089-census-recipe.sh` -> `jq: error (at <stdin>:0): Cannot iterate over null (null)` / `1` / `code-factory enabled=true admission=cooldown parent=x` / `RC=0` — exactly 1 matching row printed and exit 0, matching the committed transcript verbatim. (c) Two matching rows across the boundary: cf089-census-standin.py:12 `name = "code-factory" if i in (0, 600) else ...` — index 0 on page 0, index 600 only reachable via the 502 page. (d) Recipe is verbatim README: `diff` of README.md lines 158-168 (with 127.0.0.1:9090 -> $BASE) against docs/audits/cf089-census-recipe.sh lines 4-14 returned diff_rc=0. (e) Board row .coding-hermes/board/tasks.jsonl:76 CF-089 acceptance_criteria states falsifiable per-page failure detection (AC1: 'Any page whose fetch fails (curl nonzero), whose status is not 2xx, or whose body carries no .projects array aborts the census with a named message and a nonzero exit; one tests/selftest.sh arm per shape') and a coverage assertion (AC2: 'the number of project rows enumerated equals the total reported by the first request, or it fails naming both measured numbers'), plus AC3 falsifiability ('reverting the check makes each fixture fail with the named row, and bash tests/selftest.sh prints SELFTEST: PASS at the fixed tip'). Event .coding-hermes/board/events.jsonl:91 records task_created CF-089. (f) Test suite: `bash tests/selftest.sh` -> `SELFTEST: PASS`, exit_code 0.
CF-089 is filed with a committed, independently reproduced probe transcript showing the verbatim README census recipe printing 1 row and exiting 0 against a stand-in that 502s page 500 while 2 matching rows exist, and the board row carries falsifiable per-page-failure and coverage-assertion acceptance criteria.

Overall: FAIL ✗
