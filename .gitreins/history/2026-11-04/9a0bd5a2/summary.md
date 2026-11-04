# Verdict: CF-186-PM1

**Task:** PM lane: correct the acceptance plan's arm census after CF-155's gate arm was deleted by 4ce1e48, and file the restoration row
**Evaluated:** 2026-11-04T09:25:47.257602
**Result:** ✗ FAIL

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✗ **tier2**
  - INCOMPLETE
  ✗ At the judged commit all of the following must hold, verified by running the commands (this task grades a DOCS + BOARD FILING; the repair of CF-186 is future work tracked by that pending row and is explicitly NOT expected at this commit):
(a) docs/ACCEPTANCE-PLAN.md's first "Current state" line states 37 numbered sections plus TWO lettered arms (§4b, §7b), i.e. 39 arms — not 40 — and pins tip 69a08f1; `git show 69a08f1:.coding-hermes/board/tasks.jsonl | wc -l` = 159 and `git show 69a08f1:.coding-hermes/board/events.jsonl | wc -l` = 315 reproduce exactly.
(b) That line no longer claims tests/selftest.sh §7c runs the census gate as a live committed arm; it records that the arm was deleted by 4ce1e48 and that CF-186 restores it. The tree reproduces the premise: `grep -cE '^say "§?[0-9]+[a-z]\.' tests/selftest.sh` = 2 and `grep -c cf155 tests/selftest.sh` = 0.
(c) The reverse-mapping table in the same doc names every arm in the tree — the 37 numbered sections plus §4b and §7b, with §36 present (it was missing before this commit) and no §7c claimed as a current arm — and the paragraph states how many of the 27 unnamed arms carry a governing board row.
(d) Board row CF-186 exists in the committed .coding-hermes/board/tasks.jsonl with a non-empty paste-runnable `probe` field that, executed from the repository root, prints `lettered=2 cf155_rows=0 suite=PASS`; the probe contains no host home path and no `<path>`/`<fixture>` placeholder.
(e) `bash docs/audits/cf099-prd-drift-probe.sh` exits 0 printing `OK: milestone, plan snapshot and layer arms agree at ...`; `bash tests/selftest.sh` prints `SELFTEST: PASS` and exits 0; `bash scripts/boardctl validate` prints `RESULT: OK`.: (a) FAIL: docs/ACCEPTANCE-PLAN.md:5 reads "carries 37 sections — numbered 1 through 37 — plus three lettered sub-arms, §4b, §7b and §31b ... so the tree carries 40 arms", pinned to tip `7ec7137` (grep -c 69a08f1 = 0; grep -c 7ec7137 = 3; "40 arms" appears 4x). Criterion requires 39 arms (37 + TWO lettered §4b/§7b) pinned to 69a08f1. The board counts do reproduce at 69a08f1 (159 tasks / 315 events) but the doc pins 7ec7137 (159/320). (b) FAIL: the §7c deletion by 4ce1e48 and CF-186 restoration ARE recorded at line 5 ("the arm is GONE at `7ec7137` ... The census is therefore a diagnostic again until `CF-186` restores the arm") and `grep -c cf155 tests/selftest.sh` = 0 matches, BUT the premise check `grep -cE '^say "§?[0-9]+[a-z]\.' tests/selftest.sh` returns 3, not 2 — tests/selftest.sh:94 (§4b), :224 (§7b), :1229 (§31b). (c) FAIL: §36 is present (docs/ACCEPTANCE-PLAN.md:139) and §7c is explicitly excluded as a current arm (line 69), but the paragraph at line 58-69 states "Twelve of the 40 arms are named" and "The remaining 28 ... 15 of the 28 carry a governing board row" — the criterion requires 27 unnamed arms, not 28; the table also carries 32 id rows, not the 39 arms the criterion describes. (d) FAIL: CF-186 exists in .coding-hermes/board/tasks.jsonl (status pending, non-empty probe, no home path, no <path>/<fixture> placeholder), but executing the probe from the repo root prints `lettered=3 cf155_rows=0 suite=PASS` (exit 0), not the required `lettered=2 cf155_rows=0 suite=PASS`. (e) PASS: `bash docs/audits/cf099-prd-drift-probe.sh` exit 0 printing "OK: milestone, plan snapshot and layer arms agree at dd547d7"; `bash tests/selftest.sh` exit 0 printing "SELFTEST: PASS"; `bash scripts/boardctl validate` exit 0 printing "RESULT: OK (3 warning(s))".
Sub-criterion (e) passes with verified command output, but (a)-(d) all fail: the doc pins tip 7ec7137 and claims 40 arms with three lettered arms (§4b, §7b, §31b) instead of 39 arms at 69a08f1 with two, the tree's lettered-arm count is 3 not 2, the unnamed-arm total is 28 not 27, and CF-186's probe prints `lettered=3` rather than `lettered=2`.

## Summary

Judge Result: CF-186-PM1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: FAIL
  INCOMPLETE
  ✗ At the judged commit all of the following must hold, verified by running the commands (this task grades a DOCS + BOARD FILING; the repair of CF-186 is future work tracked by that pending row and is explicitly NOT expected at this commit):
(a) docs/ACCEPTANCE-PLAN.md's first "Current state" line states 37 numbered sections plus TWO lettered arms (§4b, §7b), i.e. 39 arms — not 40 — and pins tip 69a08f1; `git show 69a08f1:.coding-hermes/board/tasks.jsonl | wc -l` = 159 and `git show 69a08f1:.coding-hermes/board/events.jsonl | wc -l` = 315 reproduce exactly.
(b) That line no longer claims tests/selftest.sh §7c runs the census gate as a live committed arm; it records that the arm was deleted by 4ce1e48 and that CF-186 restores it. The tree reproduces the premise: `grep -cE '^say "§?[0-9]+[a-z]\.' tests/selftest.sh` = 2 and `grep -c cf155 tests/selftest.sh` = 0.
(c) The reverse-mapping table in the same doc names every arm in the tree — the 37 numbered sections plus §4b and §7b, with §36 present (it was missing before this commit) and no §7c claimed as a current arm — and the paragraph states how many of the 27 unnamed arms carry a governing board row.
(d) Board row CF-186 exists in the committed .coding-hermes/board/tasks.jsonl with a non-empty paste-runnable `probe` field that, executed from the repository root, prints `lettered=2 cf155_rows=0 suite=PASS`; the probe contains no host home path and no `<path>`/`<fixture>` placeholder.
(e) `bash docs/audits/cf099-prd-drift-probe.sh` exits 0 printing `OK: milestone, plan snapshot and layer arms agree at ...`; `bash tests/selftest.sh` prints `SELFTEST: PASS` and exits 0; `bash scripts/boardctl validate` prints `RESULT: OK`.: (a) FAIL: docs/ACCEPTANCE-PLAN.md:5 reads "carries 37 sections — numbered 1 through 37 — plus three lettered sub-arms, §4b, §7b and §31b ... so the tree carries 40 arms", pinned to tip `7ec7137` (grep -c 69a08f1 = 0; grep -c 7ec7137 = 3; "40 arms" appears 4x). Criterion requires 39 arms (37 + TWO lettered §4b/§7b) pinned to 69a08f1. The board counts do reproduce at 69a08f1 (159 tasks / 315 events) but the doc pins 7ec7137 (159/320). (b) FAIL: the §7c deletion by 4ce1e48 and CF-186 restoration ARE recorded at line 5 ("the arm is GONE at `7ec7137` ... The census is therefore a diagnostic again until `CF-186` restores the arm") and `grep -c cf155 tests/selftest.sh` = 0 matches, BUT the premise check `grep -cE '^say "§?[0-9]+[a-z]\.' tests/selftest.sh` returns 3, not 2 — tests/selftest.sh:94 (§4b), :224 (§7b), :1229 (§31b). (c) FAIL: §36 is present (docs/ACCEPTANCE-PLAN.md:139) and §7c is explicitly excluded as a current arm (line 69), but the paragraph at line 58-69 states "Twelve of the 40 arms are named" and "The remaining 28 ... 15 of the 28 carry a governing board row" — the criterion requires 27 unnamed arms, not 28; the table also carries 32 id rows, not the 39 arms the criterion describes. (d) FAIL: CF-186 exists in .coding-hermes/board/tasks.jsonl (status pending, non-empty probe, no home path, no <path>/<fixture> placeholder), but executing the probe from the repo root prints `lettered=3 cf155_rows=0 suite=PASS` (exit 0), not the required `lettered=2 cf155_rows=0 suite=PASS`. (e) PASS: `bash docs/audits/cf099-prd-drift-probe.sh` exit 0 printing "OK: milestone, plan snapshot and layer arms agree at dd547d7"; `bash tests/selftest.sh` exit 0 printing "SELFTEST: PASS"; `bash scripts/boardctl validate` exit 0 printing "RESULT: OK (3 warning(s))".
Sub-criterion (e) passes with verified command output, but (a)-(d) all fail: the doc pins tip 7ec7137 and claims 40 arms with three lettered arms (§4b, §7b, §31b) instead of 39 arms at 69a08f1 with two, the tree's lettered-arm count is 3 not 2, the unnamed-arm total is 28 not 27, and CF-186's probe prints `lettered=3` rather than `lettered=2`.

Overall: FAIL ✗
