# Verdict: CF-155-DOC1

**Task:** Docs lane resumed-tick fix: ACCEPTANCE-PLAN section census red at the published tip, plus a gate that catches the next drift
**Evaluated:** 2026-11-04T08:59:59.792470
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ At the judged commit, all must hold: (a) the numbered-section count stated in the first Current state line of docs/ACCEPTANCE-PLAN.md equals grep -cE of numbered say sections in tests/selftest.sh; (b) that line names a resolvable tip sha and the task-row and event counts it states reproduce from git show of that sha; (c) the reverse-direction list and its governing-row map name section 36 governed by board row CF-159; (d) a committed gate arm proves both directions in one run, a fixture carrying one extra numbered section fails the check and the unmodified tree passes, with both exit codes and the fixture path quoted in the evidence file; (e) bash tests/selftest.sh prints SELFTEST: PASS and bash docs/audits/cf099-prd-drift-probe.sh exits 0 at that commit.: (a) docs/ACCEPTANCE-PLAN.md:5 states "carries 36 sections — numbered 1 through 36"; `grep -cE '^say "[0-9]+\.' tests/selftest.sh` = 36 — match. (b) Line 5 names tip `8b81369`; `git cat-file -t 8b81369` = commit (resolvable); `git show 8b81369:.coding-hermes/board/tasks.jsonl | wc -l` = 154 and `...events.jsonl | wc -l` = 291, exactly the "154 task rows and 291 events" the line states. (c) docs/ACCEPTANCE-PLAN.md:56-67 reverse-direction list; line 67 governing-row map reads "§36 `CF-159`", and line 5 states "§36 (CF-159 ...) ... is governed by board row CF-159". (d) tests/selftest.sh:268-289 §7c runs both directions in one arm: green on the real tree (CF099_PLAN/CF099_SELFTEST = repo files, expects rc 0 + `measured: plan_sections=... selftest_sections=...`) and red on a copied fixture with `say "99. drift fixture"` appended, asserting rc 1 and the exact `DRIFT: plan says N sections, tests/selftest.sh has N+1` line. Evidence file docs/audits/code-factory-docs-2026-11-04-cf155-section-census.md:58-70 quotes `sections_rc=0`, `fixture_rc=1`, `DRIFT: plan says 36 sections, tests/selftest.sh has 37`, and `fixture_path=/var/tmp/cf155-fixture.fxN9q5`. (e) Ran fresh: `bash tests/selftest.sh` -> SELFTEST_EXIT=0, final line `SELFTEST: PASS`, with transcript lines 60-61 `PASS  cf155 sections census green at this tree` and `PASS  cf155 sections census red on a fixture with one extra numbered section`; `bash docs/audits/cf099-prd-drift-probe.sh` -> PROBE_EXIT=0, output `measured: tip=8b81369 rows=154 events=291 sections=36 ...` / `OK: milestone, plan snapshot and layer arms agree at 32f38a5`.
All five sub-conditions hold at commit 32f38a5: the plan's 36-section census matches the selftest, the pinned tip 8b81369 reproduces 154 rows/291 events, §36 is mapped to CF-159, §7c proves both gate directions with quoted exit codes and fixture path, and both selftest and the drift probe exit 0.

## Summary

Judge Result: CF-155-DOC1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ At the judged commit, all must hold: (a) the numbered-section count stated in the first Current state line of docs/ACCEPTANCE-PLAN.md equals grep -cE of numbered say sections in tests/selftest.sh; (b) that line names a resolvable tip sha and the task-row and event counts it states reproduce from git show of that sha; (c) the reverse-direction list and its governing-row map name section 36 governed by board row CF-159; (d) a committed gate arm proves both directions in one run, a fixture carrying one extra numbered section fails the check and the unmodified tree passes, with both exit codes and the fixture path quoted in the evidence file; (e) bash tests/selftest.sh prints SELFTEST: PASS and bash docs/audits/cf099-prd-drift-probe.sh exits 0 at that commit.: (a) docs/ACCEPTANCE-PLAN.md:5 states "carries 36 sections — numbered 1 through 36"; `grep -cE '^say "[0-9]+\.' tests/selftest.sh` = 36 — match. (b) Line 5 names tip `8b81369`; `git cat-file -t 8b81369` = commit (resolvable); `git show 8b81369:.coding-hermes/board/tasks.jsonl | wc -l` = 154 and `...events.jsonl | wc -l` = 291, exactly the "154 task rows and 291 events" the line states. (c) docs/ACCEPTANCE-PLAN.md:56-67 reverse-direction list; line 67 governing-row map reads "§36 `CF-159`", and line 5 states "§36 (CF-159 ...) ... is governed by board row CF-159". (d) tests/selftest.sh:268-289 §7c runs both directions in one arm: green on the real tree (CF099_PLAN/CF099_SELFTEST = repo files, expects rc 0 + `measured: plan_sections=... selftest_sections=...`) and red on a copied fixture with `say "99. drift fixture"` appended, asserting rc 1 and the exact `DRIFT: plan says N sections, tests/selftest.sh has N+1` line. Evidence file docs/audits/code-factory-docs-2026-11-04-cf155-section-census.md:58-70 quotes `sections_rc=0`, `fixture_rc=1`, `DRIFT: plan says 36 sections, tests/selftest.sh has 37`, and `fixture_path=/var/tmp/cf155-fixture.fxN9q5`. (e) Ran fresh: `bash tests/selftest.sh` -> SELFTEST_EXIT=0, final line `SELFTEST: PASS`, with transcript lines 60-61 `PASS  cf155 sections census green at this tree` and `PASS  cf155 sections census red on a fixture with one extra numbered section`; `bash docs/audits/cf099-prd-drift-probe.sh` -> PROBE_EXIT=0, output `measured: tip=8b81369 rows=154 events=291 sections=36 ...` / `OK: milestone, plan snapshot and layer arms agree at 32f38a5`.
All five sub-conditions hold at commit 32f38a5: the plan's 36-section census matches the selftest, the pinned tip 8b81369 reproduces 154 rows/291 events, §36 is mapped to CF-159, §7c proves both gate directions with quoted exit codes and fixture path, and both selftest and the drift probe exit 0.

Overall: PASS ✓
