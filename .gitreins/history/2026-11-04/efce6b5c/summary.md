# Verdict: CF-198-DOC1

**Task:** Docs lane: the ACCEPTANCE-PLAN section-mapping table names §38 after the CF-182 landing
**Evaluated:** 2026-11-04T10:27:59.028036
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ The deliverable is a DOCUMENT CORRECTION on docs/ACCEPTANCE-PLAN.md, proving that the section-mapping table now names every numbered selftest section and that the prose count agrees with the tree. Everything must be re-runnable from the repository root.

1. Section probe, from the repo root:
   grep -cE '^say "[0-9]+\."' tests/selftest.sh     must print 38
   grep -oE '^\| §[0-9]+' docs/ACCEPTANCE-PLAN.md | grep -oE '[0-9]+' | sort -n | tail -1   must print 38
   grep -n '^| §38' docs/ACCEPTANCE-PLAN.md   must print exactly one row, naming board row CF-182 and docs/audits/prd-blocker-resolution.sh

2. The prose on the same page must agree with that count:
   grep -n 'mapping below names every numbered section' docs/ACCEPTANCE-PLAN.md   must show "38" numbered sections and "41 arms" (three lettered arms §4b, §7b, §31b).

3. The board row's own probe, extracted verbatim from the committed board and executed:
   jq -r 'select(.id=="CF-198").probe' .coding-hermes/board/tasks.jsonl > /tmp/cf198-probe.sh; bash /tmp/cf198-probe.sh
   must print "OK pins agree" (it prints "DRIFT ... mapping table ends at section 37" on the pre-fix tree at commit a564cda, which is the RED this correction closes).

4. The CI-equivalent gate at this commit:
   bash tests/selftest.sh   must end with "SELFTEST: PASS" and exit 0, and its section 38 output must show the three green rows "prd-blocker", "prd-blocker-red", "prd-blocker-closed".

5. The evidence file docs/audits/code-factory-docs-2026-11-04-cf198-section-map.md must exist, name this tick id, quote the pre-fix DRIFT output and the post-fix OK output, and carry a ch:trace line and a "not measured" list for the claims the tick could not verify.

Out of scope, do NOT grade: closing board row CF-198, the verdict binding, and any change to the code the table describes. The repair of any other documentation claim is future work tracked by its own row. This task grades the published correction only.: All five sub-probes executed from repo root at commit e7a248c (working tree clean). (1) `grep -cE '^say "[0-9]+\.' tests/selftest.sh` -> 38 (sections 1..38, e.g. line 1866 `say "38. the milestone blocker list resolves every cited id in one namespace (CF-182)"`); `grep -oE '^\| §[0-9]+' docs/ACCEPTANCE-PLAN.md | grep -oE '[0-9]+' | sort -n | tail -1` -> 38; `grep -n '^| §38' docs/ACCEPTANCE-PLAN.md` -> exactly one row at docs/ACCEPTANCE-PLAN.md:144 naming board `CF-182` and `docs/audits/prd-blocker-resolution.sh`. RED reproduced independently: `git show a564cda:docs/ACCEPTANCE-PLAN.md` mapping last = 37. (2) docs/ACCEPTANCE-PLAN.md:104 reads "names every numbered section in the current tree — 38, plus three lettered arms (§4b, §7b, §31b), so 41 arms"; `grep -cE '^say "[0-9]+[a-z]\.' tests/selftest.sh` -> 3, confirming 38+3=41. (3) Board probe extracted verbatim via jq and executed: output `selftest_sections=38 / plan_says=38 / mapping_last=38 / OK pins agree`, exit 0. (4) `bash tests/selftest.sh` -> EXIT_CODE=0, tail `SELFTEST: PASS`; section 38 block shows `PASS  prd-blocker — 14 cited ids, 12 rows, 2 requirement-only, exit 0`, `PASS  prd-blocker-red — CF-999 unresolved, exit 1`, `PASS  prd-blocker-closed — CF-009 complete, exit 1`. (5) docs/audits/code-factory-docs-2026-11-04-cf198-section-map.md exists (5054 bytes): line 1 names tick `code-factory-docs-2026-11-04-10-01-07`; line 43 quotes pre-fix `DRIFT: selftest has 38 sections, plan claims 38, mapping table ends at section 37`; line 49 quotes post-fix `OK pins agree`; line 92 carries `ch:trace row=CF-198 spec=docs/ACCEPTANCE-PLAN.md test=tests/selftest.sh#38 evidence=... verdict=CF-198-DOC1 commit=HEAD`; line 80 section "Claims I could not verify" lists three "not measured" items (mechanical table enforcement, §7c/CF-186 restoration, line 5's 171 rows/343 events). Diff scope is docs-only: 2 files, 98 insertions, 2 deletions (docs/ACCEPTANCE-PLAN.md + the evidence file), no code changes.
The docs correction is complete and re-runnable: the mapping table now ends at §38 with a single CF-182 row, the prose reads 38 sections / 41 arms, the board probe prints "OK pins agree" (RED at a564cda reproduced as 37), the selftest gate exits 0 with SELFTEST: PASS and three green section-38 rows, and the evidence file carries the tick id, both quoted outputs, a ch:trace line, and a not-measured list.

## Summary

Judge Result: CF-198-DOC1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ The deliverable is a DOCUMENT CORRECTION on docs/ACCEPTANCE-PLAN.md, proving that the section-mapping table now names every numbered selftest section and that the prose count agrees with the tree. Everything must be re-runnable from the repository root.

1. Section probe, from the repo root:
   grep -cE '^say "[0-9]+\."' tests/selftest.sh     must print 38
   grep -oE '^\| §[0-9]+' docs/ACCEPTANCE-PLAN.md | grep -oE '[0-9]+' | sort -n | tail -1   must print 38
   grep -n '^| §38' docs/ACCEPTANCE-PLAN.md   must print exactly one row, naming board row CF-182 and docs/audits/prd-blocker-resolution.sh

2. The prose on the same page must agree with that count:
   grep -n 'mapping below names every numbered section' docs/ACCEPTANCE-PLAN.md   must show "38" numbered sections and "41 arms" (three lettered arms §4b, §7b, §31b).

3. The board row's own probe, extracted verbatim from the committed board and executed:
   jq -r 'select(.id=="CF-198").probe' .coding-hermes/board/tasks.jsonl > /tmp/cf198-probe.sh; bash /tmp/cf198-probe.sh
   must print "OK pins agree" (it prints "DRIFT ... mapping table ends at section 37" on the pre-fix tree at commit a564cda, which is the RED this correction closes).

4. The CI-equivalent gate at this commit:
   bash tests/selftest.sh   must end with "SELFTEST: PASS" and exit 0, and its section 38 output must show the three green rows "prd-blocker", "prd-blocker-red", "prd-blocker-closed".

5. The evidence file docs/audits/code-factory-docs-2026-11-04-cf198-section-map.md must exist, name this tick id, quote the pre-fix DRIFT output and the post-fix OK output, and carry a ch:trace line and a "not measured" list for the claims the tick could not verify.

Out of scope, do NOT grade: closing board row CF-198, the verdict binding, and any change to the code the table describes. The repair of any other documentation claim is future work tracked by its own row. This task grades the published correction only.: All five sub-probes executed from repo root at commit e7a248c (working tree clean). (1) `grep -cE '^say "[0-9]+\.' tests/selftest.sh` -> 38 (sections 1..38, e.g. line 1866 `say "38. the milestone blocker list resolves every cited id in one namespace (CF-182)"`); `grep -oE '^\| §[0-9]+' docs/ACCEPTANCE-PLAN.md | grep -oE '[0-9]+' | sort -n | tail -1` -> 38; `grep -n '^| §38' docs/ACCEPTANCE-PLAN.md` -> exactly one row at docs/ACCEPTANCE-PLAN.md:144 naming board `CF-182` and `docs/audits/prd-blocker-resolution.sh`. RED reproduced independently: `git show a564cda:docs/ACCEPTANCE-PLAN.md` mapping last = 37. (2) docs/ACCEPTANCE-PLAN.md:104 reads "names every numbered section in the current tree — 38, plus three lettered arms (§4b, §7b, §31b), so 41 arms"; `grep -cE '^say "[0-9]+[a-z]\.' tests/selftest.sh` -> 3, confirming 38+3=41. (3) Board probe extracted verbatim via jq and executed: output `selftest_sections=38 / plan_says=38 / mapping_last=38 / OK pins agree`, exit 0. (4) `bash tests/selftest.sh` -> EXIT_CODE=0, tail `SELFTEST: PASS`; section 38 block shows `PASS  prd-blocker — 14 cited ids, 12 rows, 2 requirement-only, exit 0`, `PASS  prd-blocker-red — CF-999 unresolved, exit 1`, `PASS  prd-blocker-closed — CF-009 complete, exit 1`. (5) docs/audits/code-factory-docs-2026-11-04-cf198-section-map.md exists (5054 bytes): line 1 names tick `code-factory-docs-2026-11-04-10-01-07`; line 43 quotes pre-fix `DRIFT: selftest has 38 sections, plan claims 38, mapping table ends at section 37`; line 49 quotes post-fix `OK pins agree`; line 92 carries `ch:trace row=CF-198 spec=docs/ACCEPTANCE-PLAN.md test=tests/selftest.sh#38 evidence=... verdict=CF-198-DOC1 commit=HEAD`; line 80 section "Claims I could not verify" lists three "not measured" items (mechanical table enforcement, §7c/CF-186 restoration, line 5's 171 rows/343 events). Diff scope is docs-only: 2 files, 98 insertions, 2 deletions (docs/ACCEPTANCE-PLAN.md + the evidence file), no code changes.
The docs correction is complete and re-runnable: the mapping table now ends at §38 with a single CF-182 row, the prose reads 38 sections / 41 arms, the board probe prints "OK pins agree" (RED at a564cda reproduced as 37), the selftest gate exits 0 with SELFTEST: PASS and three green section-38 rows, and the evidence file carries the tick id, both quoted outputs, a ch:trace line, and a not-measured list.

Overall: PASS ✓
