# Verdict: CF-200-QA1

**Task:** P3 — six board rows store `detail` or `detail.evidence` as a bare string: every iterating consumer errors, and boardctl validate still reports RESULT: OK
**Evaluated:** 2026-11-04T10:36:05.514070
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Filing-only QA task. Grade the FILING, not a repair: CF-200 is pending by definition, so the repair is future work tracked by that row and is NOT expected at this commit.

Re-runnable evidence, executed from the repo root at the committed tree:

1. `jq -c 'select(.id=="CF-200")' .coding-hermes/board/tasks.jsonl` prints exactly one row with status="pending", a non-empty `probe`, `acceptance_criteria` whose item 0 is the reproduction, and `reasoning` naming the measured census (174 rows: detail null=29/object=143/string=2, evidence array=76/string=4) plus the boundary that separates it from CF-074, CF-144, CF-045 and CF-199.
2. The row's own probe, extracted with `jq -r 'select(.id=="CF-200").probe' .coding-hermes/board/tasks.jsonl` and run with `bash`, prints `detail_null=29 detail_object=144 detail_string=2`, `evidence_array=76 evidence_string=4`, four `STRING_EVIDENCE` lines (CF-172, CF-173, CF-174, CF-179), two `STRING_DETAIL` lines (CF-128, CF-130), `control_array_iterate_rc=0`, `defect_evidence_iterate_rc=4`, `defect_detail_iterate_rc=4`, `validator_rc=0 detail_evidence_warnings=0`, and exits 0.
3. `bash scripts/boardctl validate` prints `RESULT: OK`; `bash tests/selftest.sh` prints `SELFTEST: PASS`.
4. The board diff is insert-only: `.coding-hermes/board/tasks.jsonl` gains exactly one line (174 -> 175), every line parses, and there are no duplicate ids.

Do not evaluate whether the board writer was repaired.: All four evidence clauses reproduced at commit 90e7bdf. (1) `jq -c 'select(.id=="CF-200")' .coding-hermes/board/tasks.jsonl` returns exactly one row: status="pending", probe length 1229 B, acceptance_criteria (string form) item 0 = "AC0 — reproduce on the current tree from the repo root: this row's `probe` ... prints detail_null=29 detail_object=144 detail_string=2 ...", and reasoning names the census ("174 task rows", "`detail` null=29, object=143, string=2 (CF-128, CF-130)", "`detail.evidence` array=76, absent/null=63, string=4 (CF-172, CF-173, CF-174, CF-179)") plus a BOUNDARY paragraph explicitly naming CF-074, CF-144, CF-045/CF-084 and CF-199. (2) Probe extracted via `jq -r 'select(.id=="CF-200").probe'` and run with bash: exit 0, output `detail_null=29 detail_object=144 detail_string=2`, `evidence_array=76 evidence_string=4`, STRING_DETAIL CF-128/CF-130, STRING_EVIDENCE CF-172/CF-173/CF-174/CF-179, `control_array_iterate_rc=0`, `defect_evidence_iterate_rc=4`, `defect_detail_iterate_rc=4`, `validator_rc=0 detail_evidence_warnings=0`. (3) `bash scripts/boardctl validate` -> "RESULT: OK (4 warning(s))" exit 0; `bash tests/selftest.sh` -> "SELFTEST: PASS" exit 0. (4) `git diff HEAD~1 HEAD --numstat -- .coding-hermes/board/tasks.jsonl` = `1 0` (0 removed, 1 added lines), line count 174 -> 175, `jq -c . tasks.jsonl` parses every line (ALL_PARSE_OK), `jq -r .id | sort | uniq -d` empty (no duplicate ids). No repair is claimed or required — the row is pending and the repair is tracked as future work (AC1-AC6).
CF-200 is correctly filed as a pending row whose probe, census, boundary and insert-only board diff all reproduce exactly as specified, with validate RESULT: OK and SELFTEST: PASS.

## Summary

Judge Result: CF-200-QA1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Filing-only QA task. Grade the FILING, not a repair: CF-200 is pending by definition, so the repair is future work tracked by that row and is NOT expected at this commit.

Re-runnable evidence, executed from the repo root at the committed tree:

1. `jq -c 'select(.id=="CF-200")' .coding-hermes/board/tasks.jsonl` prints exactly one row with status="pending", a non-empty `probe`, `acceptance_criteria` whose item 0 is the reproduction, and `reasoning` naming the measured census (174 rows: detail null=29/object=143/string=2, evidence array=76/string=4) plus the boundary that separates it from CF-074, CF-144, CF-045 and CF-199.
2. The row's own probe, extracted with `jq -r 'select(.id=="CF-200").probe' .coding-hermes/board/tasks.jsonl` and run with `bash`, prints `detail_null=29 detail_object=144 detail_string=2`, `evidence_array=76 evidence_string=4`, four `STRING_EVIDENCE` lines (CF-172, CF-173, CF-174, CF-179), two `STRING_DETAIL` lines (CF-128, CF-130), `control_array_iterate_rc=0`, `defect_evidence_iterate_rc=4`, `defect_detail_iterate_rc=4`, `validator_rc=0 detail_evidence_warnings=0`, and exits 0.
3. `bash scripts/boardctl validate` prints `RESULT: OK`; `bash tests/selftest.sh` prints `SELFTEST: PASS`.
4. The board diff is insert-only: `.coding-hermes/board/tasks.jsonl` gains exactly one line (174 -> 175), every line parses, and there are no duplicate ids.

Do not evaluate whether the board writer was repaired.: All four evidence clauses reproduced at commit 90e7bdf. (1) `jq -c 'select(.id=="CF-200")' .coding-hermes/board/tasks.jsonl` returns exactly one row: status="pending", probe length 1229 B, acceptance_criteria (string form) item 0 = "AC0 — reproduce on the current tree from the repo root: this row's `probe` ... prints detail_null=29 detail_object=144 detail_string=2 ...", and reasoning names the census ("174 task rows", "`detail` null=29, object=143, string=2 (CF-128, CF-130)", "`detail.evidence` array=76, absent/null=63, string=4 (CF-172, CF-173, CF-174, CF-179)") plus a BOUNDARY paragraph explicitly naming CF-074, CF-144, CF-045/CF-084 and CF-199. (2) Probe extracted via `jq -r 'select(.id=="CF-200").probe'` and run with bash: exit 0, output `detail_null=29 detail_object=144 detail_string=2`, `evidence_array=76 evidence_string=4`, STRING_DETAIL CF-128/CF-130, STRING_EVIDENCE CF-172/CF-173/CF-174/CF-179, `control_array_iterate_rc=0`, `defect_evidence_iterate_rc=4`, `defect_detail_iterate_rc=4`, `validator_rc=0 detail_evidence_warnings=0`. (3) `bash scripts/boardctl validate` -> "RESULT: OK (4 warning(s))" exit 0; `bash tests/selftest.sh` -> "SELFTEST: PASS" exit 0. (4) `git diff HEAD~1 HEAD --numstat -- .coding-hermes/board/tasks.jsonl` = `1 0` (0 removed, 1 added lines), line count 174 -> 175, `jq -c . tasks.jsonl` parses every line (ALL_PARSE_OK), `jq -r .id | sort | uniq -d` empty (no duplicate ids). No repair is claimed or required — the row is pending and the repair is tracked as future work (AC1-AC6).
CF-200 is correctly filed as a pending row whose probe, census, boundary and insert-only board diff all reproduce exactly as specified, with validate RESULT: OK and SELFTEST: PASS.

Overall: PASS ✓
