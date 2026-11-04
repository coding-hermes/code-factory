# Verdict: CF-182-DOC1

**Task:** PRD: name the requirement-id namespace and make the milestone blocker list resolve
**Evaluated:** 2026-11-04T09:08:54.100836
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ docs/PRD-code-factory.md states its ID column is a requirement namespace distinct from board task ids (grep -c 'requirement namespace' docs/PRD-code-factory.md >= 1) and every CF-nnn cited after the phrase 'open defects' resolves either to a board row status from .coding-hermes/board/tasks.jsonl or is explicitly named requirement-only; bash docs/audits/cf099-prd-drift-probe.sh exits 0 and bash tests/selftest.sh prints SELFTEST: PASS at the landing commit: All four sub-conditions verified at landing commit 2d18289 (working tree clean). (1) `grep -c 'requirement namespace' docs/PRD-code-factory.md` = 1; docs/PRD-code-factory.md:15 reads "The `ID` column is a **requirement namespace**, not the board's task-id namespace", with lines 16-20 adding that CF-101–CF-112 identify requirements, the board need carry no row, and "a citation is resolved by its namespace, never by its shape". (2) Scripted resolution of every CF-nnn after 'open defects' (docs/PRD-code-factory.md:68) over the milestone block (lines 49-98) yields UNRESOLVED=[]: CF-001 in_progress, CF-002 in_progress, CF-004 pending, CF-080 pending, CF-131 pending, CF-132 pending, CF-133 pending, CF-136 pending, CF-137 in_progress, CF-138 in_progress, CF-139 in_progress, CF-150 pending (all from .coding-hermes/board/tasks.jsonl), plus CF-110 and CF-112 which are explicitly named requirement-only in prose at lines 72-74 ("requirement `CF-110` (no destroy path ships — a requirement id from the table above, so no board row exists or need exist for it) and requirement `CF-112` (... likewise requirement-only)"); `jq -r 'select(.id=="CF-110" or .id=="CF-112")' .coding-hermes/board/tasks.jsonl` prints nothing, confirming no board row. No cited id resolves to a complete row. (3) `bash docs/audits/cf099-prd-drift-probe.sh` => exit_code 0, output "measured: tip=8b81369 rows=154 events=291 sections=36 open_blockers=CF-001 CF-002 CF-004 CF-080 CF-110 CF-112 CF-131 CF-132 CF-133 CF-136 CF-137 CF-138 CF-139 CF-150" and "OK: milestone, plan snapshot and layer arms agree at 2d18289". (4) `bash tests/selftest.sh` => exit_code 0, stdout contains "SELFTEST: PASS" (grep -c = 1, grep -c 'SELFTEST: FAIL' = 0). A trailing "/bin/sh: 1: Bad substitution" line also reproduces at parent 171bf23, so it is pre-existing and does not affect the exit code.
The PRD now names its ID column a requirement namespace, all 14 CF-nnn ids cited after 'open defects' resolve to board statuses or are explicitly requirement-only, and both the drift probe (exit 0) and selftest (SELFTEST: PASS, exit 0) are green at landing commit 2d18289.

## Summary

Judge Result: CF-182-DOC1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ docs/PRD-code-factory.md states its ID column is a requirement namespace distinct from board task ids (grep -c 'requirement namespace' docs/PRD-code-factory.md >= 1) and every CF-nnn cited after the phrase 'open defects' resolves either to a board row status from .coding-hermes/board/tasks.jsonl or is explicitly named requirement-only; bash docs/audits/cf099-prd-drift-probe.sh exits 0 and bash tests/selftest.sh prints SELFTEST: PASS at the landing commit: All four sub-conditions verified at landing commit 2d18289 (working tree clean). (1) `grep -c 'requirement namespace' docs/PRD-code-factory.md` = 1; docs/PRD-code-factory.md:15 reads "The `ID` column is a **requirement namespace**, not the board's task-id namespace", with lines 16-20 adding that CF-101–CF-112 identify requirements, the board need carry no row, and "a citation is resolved by its namespace, never by its shape". (2) Scripted resolution of every CF-nnn after 'open defects' (docs/PRD-code-factory.md:68) over the milestone block (lines 49-98) yields UNRESOLVED=[]: CF-001 in_progress, CF-002 in_progress, CF-004 pending, CF-080 pending, CF-131 pending, CF-132 pending, CF-133 pending, CF-136 pending, CF-137 in_progress, CF-138 in_progress, CF-139 in_progress, CF-150 pending (all from .coding-hermes/board/tasks.jsonl), plus CF-110 and CF-112 which are explicitly named requirement-only in prose at lines 72-74 ("requirement `CF-110` (no destroy path ships — a requirement id from the table above, so no board row exists or need exist for it) and requirement `CF-112` (... likewise requirement-only)"); `jq -r 'select(.id=="CF-110" or .id=="CF-112")' .coding-hermes/board/tasks.jsonl` prints nothing, confirming no board row. No cited id resolves to a complete row. (3) `bash docs/audits/cf099-prd-drift-probe.sh` => exit_code 0, output "measured: tip=8b81369 rows=154 events=291 sections=36 open_blockers=CF-001 CF-002 CF-004 CF-080 CF-110 CF-112 CF-131 CF-132 CF-133 CF-136 CF-137 CF-138 CF-139 CF-150" and "OK: milestone, plan snapshot and layer arms agree at 2d18289". (4) `bash tests/selftest.sh` => exit_code 0, stdout contains "SELFTEST: PASS" (grep -c = 1, grep -c 'SELFTEST: FAIL' = 0). A trailing "/bin/sh: 1: Bad substitution" line also reproduces at parent 171bf23, so it is pre-existing and does not affect the exit code.
The PRD now names its ID column a requirement namespace, all 14 CF-nnn ids cited after 'open defects' resolve to board statuses or are explicitly requirement-only, and both the drift probe (exit 0) and selftest (SELFTEST: PASS, exit 0) are green at landing commit 2d18289.

Overall: PASS ✓
