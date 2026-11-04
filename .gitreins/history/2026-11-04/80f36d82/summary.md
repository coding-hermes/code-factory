# Verdict: CF-195-QA1

**Task:** QA filing: docs cite code by line number and nothing re-measures the pins
**Evaluated:** 2026-11-04T10:13:57.423321
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Filing-only scope: the committed tree at HEAD adds exactly one board row CF-195 to .coding-hermes/board/tasks.jsonl (git diff --numstat shows 1 0) and the row carries a non-empty probe. Run, from the repository root at HEAD: bash -c "$(jq -r 'select(.id=='\''\"CF-195\"'\'') | .probe' .coding-hermes/board/tasks.jsonl)" and expect the five STALE lines plus stale_pins=5, exit 0. Also require bash tests/selftest.sh printing SELFTEST: PASS and bash scripts/boardctl validate printing RESULT: OK. Do NOT evaluate the underlying repair (re-pointing the citations and adding a checker); that is future work tracked by the pending row CF-195.: HEAD=24916c5, working tree clean. (1) Scope: `git diff --numstat HEAD~1 HEAD -- .coding-hermes/board/tasks.jsonl` => "1\t0"; full commit stat = events.jsonl 1+, tasks.jsonl 1+ (2 insertions, 0 deletions). Added task id parsed from the diff = CF-195 only; removed lines = 0; `grep -c '"id":"CF-195"'` = 1 (single row). Commit touches only .coding-hermes/board/{tasks,events}.jsonl — docs/ and scripts/ unmodified, so no repair was performed. (2) Non-empty probe: jq reports status=pending, probe_len=818, probe matches /stale_pins/. (3) Probe execution: `bash -c "$(jq -r 'select(.id=="CF-195")|.probe' .coding-hermes/board/tasks.jsonl)"` printed exactly 5 STALE lines (`grep -c '^STALE'` = 5): OPERATIONS.md->bunker-server-install.sh:56 now 63; OPERATIONS.md->project-node.sh:176 now 205; THREAT-MODEL.md->bunker-server-install.sh:56 now 63; THREAT-MODEL.md->install-hermes.sh:43-48 now 220; THREAT-MODEL.md->install-hermes.sh:61-69 now 258; followed by `stale_pins=5`, PROBE_EXIT=0. (4) `bash tests/selftest.sh > /tmp/st2.log 2>&1` => SELFTEST_EXIT=0, line 288 `SELFTEST: PASS`, 193 PASS rows (an initial FAIL was a SIGPIPE artifact of piping to `tail`, not a real failure). (5) `bash scripts/boardctl validate > /tmp/bv.log 2>&1` => VALIDATE_EXIT=0, line 8 `RESULT: OK (4 warning(s))`; the 4 warnings are pre-existing legacy rows (CF-034 free-form fields, duplicate event id 336, headerless board), not introduced by this commit.
Filing-only commit 24916c5 adds exactly one CF-195 board row (numstat 1 0) with an 818-char probe that emits five STALE lines plus stale_pins=5 at exit 0, while selftest prints SELFTEST: PASS (exit 0) and boardctl validate prints RESULT: OK (exit 0).

## Summary

Judge Result: CF-195-QA1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Filing-only scope: the committed tree at HEAD adds exactly one board row CF-195 to .coding-hermes/board/tasks.jsonl (git diff --numstat shows 1 0) and the row carries a non-empty probe. Run, from the repository root at HEAD: bash -c "$(jq -r 'select(.id=='\''\"CF-195\"'\'') | .probe' .coding-hermes/board/tasks.jsonl)" and expect the five STALE lines plus stale_pins=5, exit 0. Also require bash tests/selftest.sh printing SELFTEST: PASS and bash scripts/boardctl validate printing RESULT: OK. Do NOT evaluate the underlying repair (re-pointing the citations and adding a checker); that is future work tracked by the pending row CF-195.: HEAD=24916c5, working tree clean. (1) Scope: `git diff --numstat HEAD~1 HEAD -- .coding-hermes/board/tasks.jsonl` => "1\t0"; full commit stat = events.jsonl 1+, tasks.jsonl 1+ (2 insertions, 0 deletions). Added task id parsed from the diff = CF-195 only; removed lines = 0; `grep -c '"id":"CF-195"'` = 1 (single row). Commit touches only .coding-hermes/board/{tasks,events}.jsonl — docs/ and scripts/ unmodified, so no repair was performed. (2) Non-empty probe: jq reports status=pending, probe_len=818, probe matches /stale_pins/. (3) Probe execution: `bash -c "$(jq -r 'select(.id=="CF-195")|.probe' .coding-hermes/board/tasks.jsonl)"` printed exactly 5 STALE lines (`grep -c '^STALE'` = 5): OPERATIONS.md->bunker-server-install.sh:56 now 63; OPERATIONS.md->project-node.sh:176 now 205; THREAT-MODEL.md->bunker-server-install.sh:56 now 63; THREAT-MODEL.md->install-hermes.sh:43-48 now 220; THREAT-MODEL.md->install-hermes.sh:61-69 now 258; followed by `stale_pins=5`, PROBE_EXIT=0. (4) `bash tests/selftest.sh > /tmp/st2.log 2>&1` => SELFTEST_EXIT=0, line 288 `SELFTEST: PASS`, 193 PASS rows (an initial FAIL was a SIGPIPE artifact of piping to `tail`, not a real failure). (5) `bash scripts/boardctl validate > /tmp/bv.log 2>&1` => VALIDATE_EXIT=0, line 8 `RESULT: OK (4 warning(s))`; the 4 warnings are pre-existing legacy rows (CF-034 free-form fields, duplicate event id 336, headerless board), not introduced by this commit.
Filing-only commit 24916c5 adds exactly one CF-195 board row (numstat 1 0) with an 818-char probe that emits five STALE lines plus stale_pins=5 at exit 0, while selftest prints SELFTEST: PASS (exit 0) and boardctl validate prints RESULT: OK (exit 0).

Overall: PASS ✓
