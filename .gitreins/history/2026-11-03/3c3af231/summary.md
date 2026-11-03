# Verdict: CF-099

**Task:** PM: PRD milestone and acceptance plan describe a stale tree; reverse test map omits 13 of 28 sections
**Evaluated:** 2026-11-03T19:41:59.849045
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Run 'bash <(git show origin/main:...)' — concretely: the CF-099 probe exits 0 at the landed commit and exited 1 at 80fca8b with the drift lines 'plan says 15 sections, tests/selftest.sh has 28', 'milestone lists CF-075 as an open blocker, board says complete', 'milestone lists CF-077 as an open blocker, board says complete' and the CF-102 layer-arm misses; docs/PRD-code-factory.md milestone block names the tip it was re-measured at and lists only non-complete rows as open defects; docs/ACCEPTANCE-PLAN.md states 28 sections / 85 task rows / 115 events at 80fca8b and its reverse-direction table attributes every one of the 28 selftest sections; 'bash tests/selftest.sh' prints SELFTEST: PASS and 'bash scripts/boardctl validate' prints RESULT: OK at the landed commit.: Probe at landed commit a9d0cc8: `bash docs/audits/cf099-prd-drift-probe.sh` -> exit 0, output 'measured: tip=80fca8b rows=85 events=115 sections=28 open_blockers=CF-001 CF-004 CF-080 CF-110 CF-112' + 'OK: milestone, plan snapshot and layer arms agree at a9d0cc8'. Probe at 80fca8b (git worktree add /tmp/wt80 80fca8b, probe copied in) -> exit 1 with exactly the required lines: 'DRIFT: plan says 15 sections, tests/selftest.sh has 28', 'DRIFT: milestone lists CF-075 as an open blocker, board says complete', 'DRIFT: milestone lists CF-077 as an open blocker, board says complete', plus CF-102 layer-arm misses 'does not name §3/§4/§15/§20/layer 10'. PRD milestone block (docs/PRD-code-factory.md, awk '/^\*\*Status 20/') reads '**Status 2026-11-03 (re-measured at `80fca8b`): NOT MET.**' and lists only CF-080 (board: pending), CF-001, CF-004, CF-110, CF-112 as open defects, while CF-075/CF-077 are described as closed (board jq: both 'complete'). docs/ACCEPTANCE-PLAN.md:5-8 states 'at tip `80fca8b`' ... '28 sections' ... 'carries 85 task rows and 115 events'. Reverse-direction table at docs/ACCEPTANCE-PLAN.md:53-72 attributes §1,§2,§3,§4/§4b,§5,§6,§7,§8,§9,§10,§11,§12,§13,§14,§15,§16,§17,§18,§19,§20,§21,§22–§28 — all 28 sections (grep -cE '^say "[0-9]+\.' tests/selftest.sh = 28). PRD line 18 CF-102 cell names §3, §4/§4b, §14, §15, §20 and 'Layer 10 (base) has no arm'. `bash tests/selftest.sh` -> exit 0, 'SELFTEST: PASS', 70 PASS rows over 28 sections. `bash scripts/boardctl validate` -> exit 0, 'RESULT: OK (28 warning(s))'.
The CF-099 probe exits 0 at a9d0cc8 and exits 1 at 80fca8b with all four required drift lines plus the CF-102 layer-arm misses; the PRD milestone block names 80fca8b and lists only non-complete rows as open defects, the acceptance plan states 28 sections / 85 rows / 115 events with all 28 sections attributed in reverse, and both selftest and boardctl validate pass.

## Summary

Judge Result: CF-099

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Run 'bash <(git show origin/main:...)' — concretely: the CF-099 probe exits 0 at the landed commit and exited 1 at 80fca8b with the drift lines 'plan says 15 sections, tests/selftest.sh has 28', 'milestone lists CF-075 as an open blocker, board says complete', 'milestone lists CF-077 as an open blocker, board says complete' and the CF-102 layer-arm misses; docs/PRD-code-factory.md milestone block names the tip it was re-measured at and lists only non-complete rows as open defects; docs/ACCEPTANCE-PLAN.md states 28 sections / 85 task rows / 115 events at 80fca8b and its reverse-direction table attributes every one of the 28 selftest sections; 'bash tests/selftest.sh' prints SELFTEST: PASS and 'bash scripts/boardctl validate' prints RESULT: OK at the landed commit.: Probe at landed commit a9d0cc8: `bash docs/audits/cf099-prd-drift-probe.sh` -> exit 0, output 'measured: tip=80fca8b rows=85 events=115 sections=28 open_blockers=CF-001 CF-004 CF-080 CF-110 CF-112' + 'OK: milestone, plan snapshot and layer arms agree at a9d0cc8'. Probe at 80fca8b (git worktree add /tmp/wt80 80fca8b, probe copied in) -> exit 1 with exactly the required lines: 'DRIFT: plan says 15 sections, tests/selftest.sh has 28', 'DRIFT: milestone lists CF-075 as an open blocker, board says complete', 'DRIFT: milestone lists CF-077 as an open blocker, board says complete', plus CF-102 layer-arm misses 'does not name §3/§4/§15/§20/layer 10'. PRD milestone block (docs/PRD-code-factory.md, awk '/^\*\*Status 20/') reads '**Status 2026-11-03 (re-measured at `80fca8b`): NOT MET.**' and lists only CF-080 (board: pending), CF-001, CF-004, CF-110, CF-112 as open defects, while CF-075/CF-077 are described as closed (board jq: both 'complete'). docs/ACCEPTANCE-PLAN.md:5-8 states 'at tip `80fca8b`' ... '28 sections' ... 'carries 85 task rows and 115 events'. Reverse-direction table at docs/ACCEPTANCE-PLAN.md:53-72 attributes §1,§2,§3,§4/§4b,§5,§6,§7,§8,§9,§10,§11,§12,§13,§14,§15,§16,§17,§18,§19,§20,§21,§22–§28 — all 28 sections (grep -cE '^say "[0-9]+\.' tests/selftest.sh = 28). PRD line 18 CF-102 cell names §3, §4/§4b, §14, §15, §20 and 'Layer 10 (base) has no arm'. `bash tests/selftest.sh` -> exit 0, 'SELFTEST: PASS', 70 PASS rows over 28 sections. `bash scripts/boardctl validate` -> exit 0, 'RESULT: OK (28 warning(s))'.
The CF-099 probe exits 0 at a9d0cc8 and exits 1 at 80fca8b with all four required drift lines plus the CF-102 layer-arm misses; the PRD milestone block names 80fca8b and lists only non-complete rows as open defects, the acceptance plan states 28 sections / 85 rows / 115 events with all 28 sections attributed in reverse, and both selftest and boardctl validate pass.

Overall: PASS ✓
