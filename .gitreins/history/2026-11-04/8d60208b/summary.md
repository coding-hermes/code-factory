# Verdict: CF-162-QA1

**Task:** QA filing: verify-node.sh certifies a node with no bus leg (CF-162)
**Evaluated:** 2026-11-04T04:33:41.825795
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Row CF-162 is present in .coding-hermes/board/tasks.jsonl at the pushed tip with measured reasoning and numbered, falsifiable acceptance criteria; the same tree carries the two audit events that reproduce CF-048 and CF-078.: Pushed tip confirmed: `git rev-parse HEAD` = f515745342224bda06616925f2cf5ef6f3dd3e8e and `git ls-remote origin refs/heads/main` = f515745342224bda06616925f2cf5ef6f3dd3e8e (working tree clean). CF-162 row present in .coding-hermes/board/tasks.jsonl (also present in `git show origin/main:.coding-hermes/board/tasks.jsonl`). Reasoning (2287 chars) is measured, not asserted: cites origin/main b9a7923 and three measured arms — (a) green `project-node.sh --apply` prints `PASS  crier_url` yet writes bus.base from CRIER_BASE falling back to `http://crier.example:8767`, with the CRIER_BASE control arm proving the writer reads the wrong variable; (b) verify-node.sh's five legs contain no bus leg, prints `VERIFY: PASS` exit 0 with zero `crier`/`bus` mentions; (c) node-create.sh inherits the gap — plus explicit non-duplication against CF-068/CF-078/CF-152/CF-080/CF-126. acceptance_criteria has 7 numbered items (regex `^\s*\d+\.` -> 1..7), each falsifiable with literal expected output: `FAIL  bus_unreachable — <base> -> 000`, `PASS  bus_reachable — <base> -> 200`, `FAIL  bus_manifest — absent`, `NODE INCOMPLETE` exit 1, and closing gates (`SELFTEST: PASS`, `RESULT: OK`, ruff rc 0, ls-remote == HEAD). Same tree carries both audit events — jq census on events.jsonl: `225 task_created CF-162`, `226 audit CF-048`, `227 audit CF-078` (identical ids at origin/main). Event 226 reproduces CF-048 with measurements (real board `PASS 135/135`, torn last record `PASS 2/2`, empty board `PASS 0/0`, vs `boardctl validate` -> `RESULT: FAIL`, exit 1); event 227 reproduces CF-078 with documented arm (`manifest bus.base = http://crier.example:8767`) vs control arm (`= http://fixture.invalid:8767`). Gates run fresh: `scripts/boardctl validate` -> `RESULT: OK (3 warning(s))`, rc 0; `bash tests/selftest.sh` -> `SELFTEST: PASS`.


## Summary

Judge Result: CF-162-QA1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Row CF-162 is present in .coding-hermes/board/tasks.jsonl at the pushed tip with measured reasoning and numbered, falsifiable acceptance criteria; the same tree carries the two audit events that reproduce CF-048 and CF-078.: Pushed tip confirmed: `git rev-parse HEAD` = f515745342224bda06616925f2cf5ef6f3dd3e8e and `git ls-remote origin refs/heads/main` = f515745342224bda06616925f2cf5ef6f3dd3e8e (working tree clean). CF-162 row present in .coding-hermes/board/tasks.jsonl (also present in `git show origin/main:.coding-hermes/board/tasks.jsonl`). Reasoning (2287 chars) is measured, not asserted: cites origin/main b9a7923 and three measured arms — (a) green `project-node.sh --apply` prints `PASS  crier_url` yet writes bus.base from CRIER_BASE falling back to `http://crier.example:8767`, with the CRIER_BASE control arm proving the writer reads the wrong variable; (b) verify-node.sh's five legs contain no bus leg, prints `VERIFY: PASS` exit 0 with zero `crier`/`bus` mentions; (c) node-create.sh inherits the gap — plus explicit non-duplication against CF-068/CF-078/CF-152/CF-080/CF-126. acceptance_criteria has 7 numbered items (regex `^\s*\d+\.` -> 1..7), each falsifiable with literal expected output: `FAIL  bus_unreachable — <base> -> 000`, `PASS  bus_reachable — <base> -> 200`, `FAIL  bus_manifest — absent`, `NODE INCOMPLETE` exit 1, and closing gates (`SELFTEST: PASS`, `RESULT: OK`, ruff rc 0, ls-remote == HEAD). Same tree carries both audit events — jq census on events.jsonl: `225 task_created CF-162`, `226 audit CF-048`, `227 audit CF-078` (identical ids at origin/main). Event 226 reproduces CF-048 with measurements (real board `PASS 135/135`, torn last record `PASS 2/2`, empty board `PASS 0/0`, vs `boardctl validate` -> `RESULT: FAIL`, exit 1); event 227 reproduces CF-078 with documented arm (`manifest bus.base = http://crier.example:8767`) vs control arm (`= http://fixture.invalid:8767`). Gates run fresh: `scripts/boardctl validate` -> `RESULT: OK (3 warning(s))`, rc 0; `bash tests/selftest.sh` -> `SELFTEST: PASS`.


Overall: PASS ✓
