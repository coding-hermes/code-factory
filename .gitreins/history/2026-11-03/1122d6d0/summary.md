# Verdict: CF-073-QA2

**Task:** QA filing verification: does board row CF-073 exist in the published tree with a probe that reproduces, at commit b430bed
**Evaluated:** 2026-11-03T14:59:48.747076
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Judge ONLY the filing commit b430bed; CF-073 is a pending row, so do NOT evaluate whether the defect is fixed. Run from the repo root: (1) 'git show b430bed --stat --format=%s' shows exactly one changed file (.coding-hermes/board/tasks.jsonl, 1 insertion). (2) 'git show b430bed:.coding-hermes/board/tasks.jsonl | jq -r "select(.id==\"CF-073\")|.id+\" \"+.priority+\" \"+.status"' prints 'CF-073 P3 pending' and the same row carries a non-empty probe field. (3) Execute that probe field verbatim from the repo root: it prints exactly three lines naming CF-052, PERF-012 and CF-058, each containing 'fatal: Not a valid object name', and exits 0. (4) 'bash tests/selftest.sh' prints SELFTEST: PASS and 'scripts/boardctl validate' prints RESULT: OK at HEAD. PASS requires all four; any missing item is a FAIL naming it.: All four sub-items verified from repo root /home/kara/code-factory (HEAD=b430bed67fcf8e5fcc60f2a859d3632fa694c122). (1) `git show b430bed --stat --format=%s` exit 0: subject 'board: file CF-073 — three complete rows still carry closure digests that resolve to no git object' and stat '.coding-hermes/board/tasks.jsonl | 1 +' / '1 file changed, 1 insertion(+)' — exactly one file, one insertion. (2) jq select(.id=="CF-073") printed exactly 'CF-073 P3 pending'; .probe is non-empty: 'cd /home/kara/code-factory; for r in CF-052 PERF-012 CF-058; do jq -r --arg r "$r" ... .coding-hermes/board/tasks.jsonl; done | while read -r id rid fp; do echo "$id run_id=$rid tree_fp=${fp:0:12} -> $(git cat-file -t "$fp" 2>&1 | head -1)"; done'. (3) Probe executed verbatim (under bash, as it uses bash-only ${fp:0:12}) produced exactly three lines, exit 0: 'CF-052 run_id=222a8b0 tree_fp=000000000000 -> fatal: Not a valid object name 0000...', 'PERF-012 run_id=code-factory-perf-2026-11-03-10-56-35-selftest-board-30row tree_fp=a7e996a21e8c -> fatal: Not a valid object name a7e9...', 'CF-058 run_id=9bd93bd8 tree_fp=839710de66cb -> fatal: Not a valid object name 8397...'. (4) `bash tests/selftest.sh` printed 'SELFTEST: PASS' with all numbered sub-checks PASS (e.g. 'PASS adapter FAIL rows counted: 2 rows -> NODE: FAIL (2)'); `scripts/boardctl validate` printed 'RESULT: OK (15 warning(s))' with exit 0 (warnings only, incl. benign 'key(s) {probe} outside the declared canon' for CF-073). Per instructions, the underlying defect was not evaluated since CF-073 is a pending row.
Commit b430bed files exactly one pending CF-073 row (P3, non-empty probe) whose probe reproduces three 'fatal: Not a valid object name' lines for CF-052/PERF-012/CF-058 with exit 0, and both selftest and boardctl validate pass at HEAD.

## Summary

Judge Result: CF-073-QA2

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Judge ONLY the filing commit b430bed; CF-073 is a pending row, so do NOT evaluate whether the defect is fixed. Run from the repo root: (1) 'git show b430bed --stat --format=%s' shows exactly one changed file (.coding-hermes/board/tasks.jsonl, 1 insertion). (2) 'git show b430bed:.coding-hermes/board/tasks.jsonl | jq -r "select(.id==\"CF-073\")|.id+\" \"+.priority+\" \"+.status"' prints 'CF-073 P3 pending' and the same row carries a non-empty probe field. (3) Execute that probe field verbatim from the repo root: it prints exactly three lines naming CF-052, PERF-012 and CF-058, each containing 'fatal: Not a valid object name', and exits 0. (4) 'bash tests/selftest.sh' prints SELFTEST: PASS and 'scripts/boardctl validate' prints RESULT: OK at HEAD. PASS requires all four; any missing item is a FAIL naming it.: All four sub-items verified from repo root /home/kara/code-factory (HEAD=b430bed67fcf8e5fcc60f2a859d3632fa694c122). (1) `git show b430bed --stat --format=%s` exit 0: subject 'board: file CF-073 — three complete rows still carry closure digests that resolve to no git object' and stat '.coding-hermes/board/tasks.jsonl | 1 +' / '1 file changed, 1 insertion(+)' — exactly one file, one insertion. (2) jq select(.id=="CF-073") printed exactly 'CF-073 P3 pending'; .probe is non-empty: 'cd /home/kara/code-factory; for r in CF-052 PERF-012 CF-058; do jq -r --arg r "$r" ... .coding-hermes/board/tasks.jsonl; done | while read -r id rid fp; do echo "$id run_id=$rid tree_fp=${fp:0:12} -> $(git cat-file -t "$fp" 2>&1 | head -1)"; done'. (3) Probe executed verbatim (under bash, as it uses bash-only ${fp:0:12}) produced exactly three lines, exit 0: 'CF-052 run_id=222a8b0 tree_fp=000000000000 -> fatal: Not a valid object name 0000...', 'PERF-012 run_id=code-factory-perf-2026-11-03-10-56-35-selftest-board-30row tree_fp=a7e996a21e8c -> fatal: Not a valid object name a7e9...', 'CF-058 run_id=9bd93bd8 tree_fp=839710de66cb -> fatal: Not a valid object name 8397...'. (4) `bash tests/selftest.sh` printed 'SELFTEST: PASS' with all numbered sub-checks PASS (e.g. 'PASS adapter FAIL rows counted: 2 rows -> NODE: FAIL (2)'); `scripts/boardctl validate` printed 'RESULT: OK (15 warning(s))' with exit 0 (warnings only, incl. benign 'key(s) {probe} outside the declared canon' for CF-073). Per instructions, the underlying defect was not evaluated since CF-073 is a pending row.
Commit b430bed files exactly one pending CF-073 row (P3, non-empty probe) whose probe reproduces three 'fatal: Not a valid object name' lines for CF-052/PERF-012/CF-058 with exit 0, and both selftest and boardctl validate pass at HEAD.

Overall: PASS ✓
