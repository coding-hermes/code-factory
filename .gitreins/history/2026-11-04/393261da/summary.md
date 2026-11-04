# Verdict: CF-198-PM2

**Task:** CF-198 superseding landing: the section mapping and arm count are DERIVED by a committed checker with a named red arm
**Evaluated:** 2026-11-04T10:37:50.377861
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ At commit a9d36fb docs/ACCEPTANCE-PLAN.md's mapping table covers every numbered selftest section and its prose arm count equals the derived total; docs/audits/cf198-section-mapping.sh derives both sides (numbered sections, lettered arms, mapping rows including closed ranges, prose claim) and exits nonzero naming the divergent section and the side that lacks it; tests/selftest.sh carries a §39 arm whose red leg strips the §38 mapping row from a fixture copy and asserts the NAMED plan-side FAIL row while the real tree prints RESULT: OK with arms_plan == arms_tree; bash tests/selftest.sh prints SELFTEST: PASS and bash scripts/boardctl validate prints RESULT: OK.: Checker docs/audits/cf198-section-mapping.sh derives numbered sections (`grep -oE '^say "[0-9]+\.'`), lettered arms (`^say "[0-9]+[a-z]\.`), mapping rows (`^\| §[0-9]+(–§?[0-9]+)?` with closed-range expansion via `awk -F'–§?'`), and the prose claim (`current tree carries [0-9]+ arms`). Run at a9d36fb: all 39 sections print 'OK §N — plan row present', 'arms_plan=42 arms_tree=42', 'RESULT: OK', exit 0. Falsifiability verified by me: stripping the §38 row from a fixture copy yields 'MISSING §38 — tree carries it, plan mapping table does not' + 'FAIL section-mapping — §38 missing from plan mapping table', 'RESULT: DRIFT (1)', exit 1; a phantom '| §40' row yields 'EXTRA §40 — plan names it, tree has no such section', exit 1; prose 42→41 yields 'prose claims 41 arms but tree carries 42', exit 1. Plan table covers §1–§39 including §38 (docs/ACCEPTANCE-PLAN.md:143), §39 (:144) and the closed range §22–§28 (:131); prose at :104 says 'current tree carries 42 arms: 39 numbered sections and three lettered arms (§4b, §7b, §31b)' == derived 39+3=42. tests/selftest.sh:1916 is the §39 arm; green leg (:1918-1931) parses arms_plan/arms_tree and requires 'RESULT: OK'; red leg (:1933-1941) awk-strips '^| §38 ' from a fixture copy and requires regex '^  FAIL  section-mapping.*§38.*plan' plus nonzero rc. Actual runs: `bash tests/selftest.sh` → 'PASS  section-mapping-real — green verdict, arms_plan=42 arms_tree=42', 'PASS  section-mapping-red — missing §38 names plan side, exit 1', 'SELFTEST: PASS', exit 0 (196 PASS lines, no FAIL rows); `bash scripts/boardctl validate` → 'RESULT: OK (4 warning(s))', exit 0; `bash -n $(git ls-files '*.sh')` → exit 0.
The committed checker derives both the section mapping and arm count, reds with named plan-side/tree-side drift on three independent mutations, the §39 selftest arm exercises both legs, and both required commands print SELFTEST: PASS and RESULT: OK.

## Summary

Judge Result: CF-198-PM2

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ At commit a9d36fb docs/ACCEPTANCE-PLAN.md's mapping table covers every numbered selftest section and its prose arm count equals the derived total; docs/audits/cf198-section-mapping.sh derives both sides (numbered sections, lettered arms, mapping rows including closed ranges, prose claim) and exits nonzero naming the divergent section and the side that lacks it; tests/selftest.sh carries a §39 arm whose red leg strips the §38 mapping row from a fixture copy and asserts the NAMED plan-side FAIL row while the real tree prints RESULT: OK with arms_plan == arms_tree; bash tests/selftest.sh prints SELFTEST: PASS and bash scripts/boardctl validate prints RESULT: OK.: Checker docs/audits/cf198-section-mapping.sh derives numbered sections (`grep -oE '^say "[0-9]+\.'`), lettered arms (`^say "[0-9]+[a-z]\.`), mapping rows (`^\| §[0-9]+(–§?[0-9]+)?` with closed-range expansion via `awk -F'–§?'`), and the prose claim (`current tree carries [0-9]+ arms`). Run at a9d36fb: all 39 sections print 'OK §N — plan row present', 'arms_plan=42 arms_tree=42', 'RESULT: OK', exit 0. Falsifiability verified by me: stripping the §38 row from a fixture copy yields 'MISSING §38 — tree carries it, plan mapping table does not' + 'FAIL section-mapping — §38 missing from plan mapping table', 'RESULT: DRIFT (1)', exit 1; a phantom '| §40' row yields 'EXTRA §40 — plan names it, tree has no such section', exit 1; prose 42→41 yields 'prose claims 41 arms but tree carries 42', exit 1. Plan table covers §1–§39 including §38 (docs/ACCEPTANCE-PLAN.md:143), §39 (:144) and the closed range §22–§28 (:131); prose at :104 says 'current tree carries 42 arms: 39 numbered sections and three lettered arms (§4b, §7b, §31b)' == derived 39+3=42. tests/selftest.sh:1916 is the §39 arm; green leg (:1918-1931) parses arms_plan/arms_tree and requires 'RESULT: OK'; red leg (:1933-1941) awk-strips '^| §38 ' from a fixture copy and requires regex '^  FAIL  section-mapping.*§38.*plan' plus nonzero rc. Actual runs: `bash tests/selftest.sh` → 'PASS  section-mapping-real — green verdict, arms_plan=42 arms_tree=42', 'PASS  section-mapping-red — missing §38 names plan side, exit 1', 'SELFTEST: PASS', exit 0 (196 PASS lines, no FAIL rows); `bash scripts/boardctl validate` → 'RESULT: OK (4 warning(s))', exit 0; `bash -n $(git ls-files '*.sh')` → exit 0.
The committed checker derives both the section mapping and arm count, reds with named plan-side/tree-side drift on three independent mutations, the §39 selftest arm exercises both legs, and both required commands print SELFTEST: PASS and RESULT: OK.

Overall: PASS ✓
