# Verdict: CF-190-PM

**Task:** File the push-transport defect row: the control host cannot push over the configured SSH remote and no doc names a working publish path
**Evaluated:** 2026-11-04T09:48:40.548424
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ At the graded commit: (1) `git show HEAD:.coding-hermes/board/tasks.jsonl | jq -c 'select(.id=="CF-190")'` prints exactly one row with status pending, priority P4, a non-empty probe, and acceptance_criteria containing the phrase push-transport; (2) running that row's probe verbatim from the repository root prints `ssh_rc=128` beside `Permission denied (publickey)` and `https_rc=0`; (3) `bash scripts/boardctl validate` prints RESULT: OK; (4) the commit diff touches only .coding-hermes/board/{tasks,events}.jsonl. This grades the FILING only: the repair (a documented publish command plus a selftest arm that fails when push auth is broken) is future work tracked by the pending row and is NOT expected at this commit.: HEAD=8e1e312c5adc6404f66ce012dbb50fd499149750. (1) `git show HEAD:.coding-hermes/board/tasks.jsonl | jq -c 'select(.id=="CF-190")'` returned exactly 1 line (wc -l = 1); jq projection gave status="pending", priority="P4", probe_len=441 (non-empty), acceptance_criteria test("push-transport")=true (AC text names `FAIL  push-transport — …` and `PASS  push-transport — …` rows). (2) Probe extracted verbatim with `jq -r '.probe'` and executed via bash from the repo root; actual output: `ssh_rc=128 git@github.com: Permission denied (publickey).` / `https_rc=0 Everything up-to-date`, exit=0 — ssh_rc=128 beside Permission denied (publickey) and https_rc=0, exact match. (3) `bash scripts/boardctl validate` exit_code=0, final line `RESULT: OK (3 warning(s))`; the 3 warnings are pre-existing free-form guard_result/ci_result on CF-034 (tasks.jsonl line 20) plus a headerless-board note, none concerning CF-190. (4) `git show --name-status --format="" HEAD` lists only `M .coding-hermes/board/events.jsonl` and `M .coding-hermes/board/tasks.jsonl` (numstat 1/0 and 1/0); the added event is id 330 task_created CF-190. No doc or selftest changes are present, consistent with the criterion's filing-only scope.
All four sub-criteria hold at commit 8e1e312: one pending P4 CF-190 row with a 441-char probe and push-transport acceptance criteria, the probe reproduces ssh_rc=128/Permission denied (publickey) with https_rc=0, boardctl validate prints RESULT: OK, and the diff touches only the two board JSONL files.

## Summary

Judge Result: CF-190-PM

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ At the graded commit: (1) `git show HEAD:.coding-hermes/board/tasks.jsonl | jq -c 'select(.id=="CF-190")'` prints exactly one row with status pending, priority P4, a non-empty probe, and acceptance_criteria containing the phrase push-transport; (2) running that row's probe verbatim from the repository root prints `ssh_rc=128` beside `Permission denied (publickey)` and `https_rc=0`; (3) `bash scripts/boardctl validate` prints RESULT: OK; (4) the commit diff touches only .coding-hermes/board/{tasks,events}.jsonl. This grades the FILING only: the repair (a documented publish command plus a selftest arm that fails when push auth is broken) is future work tracked by the pending row and is NOT expected at this commit.: HEAD=8e1e312c5adc6404f66ce012dbb50fd499149750. (1) `git show HEAD:.coding-hermes/board/tasks.jsonl | jq -c 'select(.id=="CF-190")'` returned exactly 1 line (wc -l = 1); jq projection gave status="pending", priority="P4", probe_len=441 (non-empty), acceptance_criteria test("push-transport")=true (AC text names `FAIL  push-transport — …` and `PASS  push-transport — …` rows). (2) Probe extracted verbatim with `jq -r '.probe'` and executed via bash from the repo root; actual output: `ssh_rc=128 git@github.com: Permission denied (publickey).` / `https_rc=0 Everything up-to-date`, exit=0 — ssh_rc=128 beside Permission denied (publickey) and https_rc=0, exact match. (3) `bash scripts/boardctl validate` exit_code=0, final line `RESULT: OK (3 warning(s))`; the 3 warnings are pre-existing free-form guard_result/ci_result on CF-034 (tasks.jsonl line 20) plus a headerless-board note, none concerning CF-190. (4) `git show --name-status --format="" HEAD` lists only `M .coding-hermes/board/events.jsonl` and `M .coding-hermes/board/tasks.jsonl` (numstat 1/0 and 1/0); the added event is id 330 task_created CF-190. No doc or selftest changes are present, consistent with the criterion's filing-only scope.
All four sub-criteria hold at commit 8e1e312: one pending P4 CF-190 row with a 441-char probe and push-transport acceptance criteria, the probe reproduces ssh_rc=128/Permission denied (publickey) with https_rc=0, boardctl validate prints RESULT: OK, and the diff touches only the two board JSONL files.

Overall: PASS ✓
