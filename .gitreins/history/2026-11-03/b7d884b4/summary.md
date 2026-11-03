# Verdict: CF-097-QA1

**Task:** QA filing: CF-097 repo-url home-root gap + CF-098 untraced code commit (code-factory-docs-qa 2026-11-03)
**Evaluated:** 2026-11-03T19:14:05.930593
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Filing-only grading; do not evaluate the underlying fixes (both filed rows are pending by definition). On the filing commit: (a) git show --stat HEAD names .coding-hermes/board/tasks.jsonl and .coding-hermes/board/events.jsonl as insert-only (+2 / +2 lines, 0 deletions); (b) jq -r 'select(.id=="CF-097" or .id=="CF-098") | .id + " " + .status + " probe_len=" + (.probe|length|tostring)' .coding-hermes/board/tasks.jsonl prints CF-097 pending probe_len>0 and CF-098 pending probe_len>0; (c) the CF-097 probe extracted from the committed board (jq -r 'select(.id=="CF-097").probe') and executed from the repo root prints verify_rc=4 with a not_home_repo check whose ok is false AND repo_url_rc=0 PASS for the same fixture path; (d) the CF-098 probe likewise prints exactly one 'untraced' line naming af67c3b and untraced_total=1; (e) bash tests/selftest.sh prints SELFTEST: PASS and bash scripts/boardctl validate prints RESULT: OK at that commit; (f) no duplicate row ids and the two appended ids are the next free CF ids. Context to record, not to re-grade: CF-090 was re-verified as true at its own commit 3b2c81e (ruff check . and ruff format --check . both exit 0) and its criterion no longer reproduced at af67c3b; a sibling lane has since fixed that drift as CF-096, so both ruff arms exit 0 again at 780a1e2.: All six sub-conditions verified on commit ce97c7d. (a) `git show --numstat HEAD` => "2\t0\t.coding-hermes/board/events.jsonl" and "2\t0\t.coding-hermes/board/tasks.jsonl"; shortstat "2 files changed, 4 insertions(+)"; name-status lists only those two files as M — insert-only, 0 deletions. (b) jq prints "CF-097 pending probe_len=546" and "CF-098 pending probe_len=283" (both >0). (c) CF-097 probe run from repo root => "verify_rc=4 [{\"check\": \"not_home_repo\", \"ok\": false, \"value\": \"top level is the home directory\"}]" and "repo_url_rc=0 PASS repo_url 'local:/var/tmp/hermes-scratch/tmp.xEKl3Iznws/h' — root '/var/tmp/hermes-scratch/tmp.xEKl3Iznws/h' HEAD 3017936..." — same fixture path, rc 4 vs rc 0. (d) CF-098 probe => exactly one untraced line "untraced af67c3b docs: document bunker:// targets and how they are proved on the agent" plus "untraced_total=1". (e) `bash tests/selftest.sh` exit_code=0 with "SELFTEST: PASS"; `bash scripts/boardctl validate` exit_code=0 with "RESULT: OK (28 warning(s))" (warnings are pre-existing 'probe outside declared canon' notices, not failures). (f) `jq -r '.id' | sort | uniq -d` returns empty (no duplicate ids across 85 rows); at HEAD~1 the highest CF id was CF-096 and the two appended task rows are exactly "CF-097 pending" and "CF-098 pending" — the next free CF ids. Both rows are pending as required for filing-only grading; underlying fixes not evaluated.


## Summary

Judge Result: CF-097-QA1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Filing-only grading; do not evaluate the underlying fixes (both filed rows are pending by definition). On the filing commit: (a) git show --stat HEAD names .coding-hermes/board/tasks.jsonl and .coding-hermes/board/events.jsonl as insert-only (+2 / +2 lines, 0 deletions); (b) jq -r 'select(.id=="CF-097" or .id=="CF-098") | .id + " " + .status + " probe_len=" + (.probe|length|tostring)' .coding-hermes/board/tasks.jsonl prints CF-097 pending probe_len>0 and CF-098 pending probe_len>0; (c) the CF-097 probe extracted from the committed board (jq -r 'select(.id=="CF-097").probe') and executed from the repo root prints verify_rc=4 with a not_home_repo check whose ok is false AND repo_url_rc=0 PASS for the same fixture path; (d) the CF-098 probe likewise prints exactly one 'untraced' line naming af67c3b and untraced_total=1; (e) bash tests/selftest.sh prints SELFTEST: PASS and bash scripts/boardctl validate prints RESULT: OK at that commit; (f) no duplicate row ids and the two appended ids are the next free CF ids. Context to record, not to re-grade: CF-090 was re-verified as true at its own commit 3b2c81e (ruff check . and ruff format --check . both exit 0) and its criterion no longer reproduced at af67c3b; a sibling lane has since fixed that drift as CF-096, so both ruff arms exit 0 again at 780a1e2.: All six sub-conditions verified on commit ce97c7d. (a) `git show --numstat HEAD` => "2\t0\t.coding-hermes/board/events.jsonl" and "2\t0\t.coding-hermes/board/tasks.jsonl"; shortstat "2 files changed, 4 insertions(+)"; name-status lists only those two files as M — insert-only, 0 deletions. (b) jq prints "CF-097 pending probe_len=546" and "CF-098 pending probe_len=283" (both >0). (c) CF-097 probe run from repo root => "verify_rc=4 [{\"check\": \"not_home_repo\", \"ok\": false, \"value\": \"top level is the home directory\"}]" and "repo_url_rc=0 PASS repo_url 'local:/var/tmp/hermes-scratch/tmp.xEKl3Iznws/h' — root '/var/tmp/hermes-scratch/tmp.xEKl3Iznws/h' HEAD 3017936..." — same fixture path, rc 4 vs rc 0. (d) CF-098 probe => exactly one untraced line "untraced af67c3b docs: document bunker:// targets and how they are proved on the agent" plus "untraced_total=1". (e) `bash tests/selftest.sh` exit_code=0 with "SELFTEST: PASS"; `bash scripts/boardctl validate` exit_code=0 with "RESULT: OK (28 warning(s))" (warnings are pre-existing 'probe outside declared canon' notices, not failures). (f) `jq -r '.id' | sort | uniq -d` returns empty (no duplicate ids across 85 rows); at HEAD~1 the highest CF id was CF-096 and the two appended task rows are exactly "CF-097 pending" and "CF-098 pending" — the next free CF ids. Both rows are pending as required for filing-only grading; underlying fixes not evaluated.


Overall: PASS ✓
