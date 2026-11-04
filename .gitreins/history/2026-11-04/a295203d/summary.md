# Verdict: CF-140-QA1

**Task:** file CF-140: clone_lane.py inherits the source lane's cooldown pin and disables a live lane on re-run
**Evaluated:** 2026-11-04T00:56:29.139926
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Filing-only criterion: do NOT evaluate the clone_lane.py repair — it is future work tracked by the pending row CF-140, and the fix is not expected in this tree. Grade the FILING commit only: (1) `git show --stat HEAD` names .coding-hermes/board/tasks.jsonl and .coding-hermes/board/events.jsonl and nothing else, and the board diff is +1 line with 0 deletions; (2) `git show HEAD:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-140") | [.status, ((.probe // "") | length)] | @tsv'` prints `pending` and a probe length greater than 200; (3) extract the probe from the COMMITTED board — `git show HEAD:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-140").probe' > "$(mktemp)"` — and run that file with bash from the repo root: it must exit 0 and print a table in which `new-lane` shows cooldown_s 604800 and cooldown_pin_s 604800 inherited from the source lane, and `live-lane` (created enabled=1 with cooldown_s 900) shows enabled 0 after the re-run; (4) `bash tests/selftest.sh` prints SELFTEST: PASS with exit 0 and `bash scripts/boardctl validate` prints RESULT: OK; (5) `jq -r .id .coding-hermes/board/tasks.jsonl | sort | uniq -d` prints nothing.: (1) `git show --numstat HEAD` = `1	0	.coding-hermes/board/events.jsonl` and `1	0	.coding-hermes/board/tasks.jsonl` — exactly two files, +1/-0 each, nothing else. (2) jq output: `pending	1256` — status pending, probe length 1256 > 200. (3) Probe extracted from committed board (git show HEAD:...) and run with bash from repo root: EXIT=0, printed table `live-lane 0 604800 604800`, `new-lane 0 604800 604800`, `src-lane 1 604800 604800` — new-lane inherits cooldown_s/cooldown_pin_s 604800 from src-lane, and live-lane (seeded enabled=1, cooldown_s 900) shows enabled 0 after the re-run. (4) `bash tests/selftest.sh` -> final line `SELFTEST: PASS`, `grep -a -c FAIL` = 0, exit 0 (run via nohup because the tool's 30s cap killed the foreground run; log at /tmp/st.log). `bash scripts/boardctl validate` -> `RESULT: OK (46 warning(s))`, BOARDCTL_EXIT=0. (5) `jq -r .id .coding-hermes/board/tasks.jsonl | sort | uniq -d` printed nothing (also empty for the committed board).
All five filing sub-criteria verified with live command output: board-only +1/-0 commit, pending CF-140 row with a 1256-char probe that reproduces the cooldown-pin inheritance and live-lane disablement, SELFTEST: PASS, boardctl RESULT: OK, and no duplicate ids.

## Summary

Judge Result: CF-140-QA1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Filing-only criterion: do NOT evaluate the clone_lane.py repair — it is future work tracked by the pending row CF-140, and the fix is not expected in this tree. Grade the FILING commit only: (1) `git show --stat HEAD` names .coding-hermes/board/tasks.jsonl and .coding-hermes/board/events.jsonl and nothing else, and the board diff is +1 line with 0 deletions; (2) `git show HEAD:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-140") | [.status, ((.probe // "") | length)] | @tsv'` prints `pending` and a probe length greater than 200; (3) extract the probe from the COMMITTED board — `git show HEAD:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-140").probe' > "$(mktemp)"` — and run that file with bash from the repo root: it must exit 0 and print a table in which `new-lane` shows cooldown_s 604800 and cooldown_pin_s 604800 inherited from the source lane, and `live-lane` (created enabled=1 with cooldown_s 900) shows enabled 0 after the re-run; (4) `bash tests/selftest.sh` prints SELFTEST: PASS with exit 0 and `bash scripts/boardctl validate` prints RESULT: OK; (5) `jq -r .id .coding-hermes/board/tasks.jsonl | sort | uniq -d` prints nothing.: (1) `git show --numstat HEAD` = `1	0	.coding-hermes/board/events.jsonl` and `1	0	.coding-hermes/board/tasks.jsonl` — exactly two files, +1/-0 each, nothing else. (2) jq output: `pending	1256` — status pending, probe length 1256 > 200. (3) Probe extracted from committed board (git show HEAD:...) and run with bash from repo root: EXIT=0, printed table `live-lane 0 604800 604800`, `new-lane 0 604800 604800`, `src-lane 1 604800 604800` — new-lane inherits cooldown_s/cooldown_pin_s 604800 from src-lane, and live-lane (seeded enabled=1, cooldown_s 900) shows enabled 0 after the re-run. (4) `bash tests/selftest.sh` -> final line `SELFTEST: PASS`, `grep -a -c FAIL` = 0, exit 0 (run via nohup because the tool's 30s cap killed the foreground run; log at /tmp/st.log). `bash scripts/boardctl validate` -> `RESULT: OK (46 warning(s))`, BOARDCTL_EXIT=0. (5) `jq -r .id .coding-hermes/board/tasks.jsonl | sort | uniq -d` printed nothing (also empty for the committed board).
All five filing sub-criteria verified with live command output: board-only +1/-0 commit, pending CF-140 row with a 1256-char probe that reproduces the cooldown-pin inheritance and live-lane disablement, SELFTEST: PASS, boardctl RESULT: OK, and no duplicate ids.

Overall: PASS ✓
