# Verdict: CF-205-QA1

**Task:** QA filing: CF-205 reproduces its own probe (12 hits vs the doc's four) and lands as one board row
**Evaluated:** 2026-11-04T23:44:42.776303
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ The commit under judgement is BOARD-ONLY: it touches exactly two paths, .coding-hermes/board/tasks.jsonl (+1 line, 0 deletions) and .coding-hermes/board/events.jsonl (+1 line, the task_created event boardctl emits, 0 deletions). git show --stat <commit> shows 2 files changed, 2 insertions(+), 0 deletions and names no other path. Verify all of the following against the COMMITTED tree, not the working tree:

1. The committed board carries CF-205 exactly once and no id is duplicated: git show <commit>:.coding-hermes/board/tasks.jsonl | jq -r .id | sort | uniq -d prints nothing, and jq -r 'select(.id=="CF-205") | .status' prints pending.
2. CF-205 carries a non-empty probe field, an acceptance_criteria field, and a reasoning field: git show <commit>:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-205") | [.status, (.probe|length), (.acceptance_criteria|length), (.reasoning|length)] | @tsv' prints pending followed by three positive lengths.
3. Extract the probe from the COMMITTED row and run it verbatim from the repository root: git show HEAD:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-205").probe' > /tmp/cf205-probe.sh && bash /tmp/cf205-probe.sh prints exactly cited_cmd_hits=12 doc_says=1 and exits 0.
4. The gate is green at the same commit: bash tests/selftest.sh prints SELFTEST: PASS and bash scripts/boardctl validate prints RESULT: OK.
5. The commit is pushed: git rev-list --count origin/main..HEAD prints 0.

IMPORTANT SCOPE: CF-205 is a newly FILED row for an unfixed documentation defect. Do NOT evaluate or require the underlying docs/DESIGN.md fix — the criterion grades the filing only (row present in the committed tree, probe present and reproducing, gate green, pushed).: All sub-checks verified against committed tree (HEAD=1124ae0). Stat: '2 files changed, 2 insertions(+)' with numstat 1/0 for both .coding-hermes/board/events.jsonl and tasks.jsonl, no other path; added events.jsonl line is {"id":364,"event_type":"task_created","task_id":"CF-205"}. (1) jq -r .id | sort | uniq -d printed nothing; CF-205 status=pending. (2) field lengths: 'pending\t178\t1162\t2003' — all positive. (3) probe extracted from committed row and run verbatim from repo root printed exactly 'cited_cmd_hits=12 doc_says=1', exit=0. (4) bash tests/selftest.sh -> 'SELFTEST: PASS' exit 0; bash scripts/boardctl validate -> 'RESULT: OK (4 warning(s))' exit 0, warnings are pre-existing legacy rows (CF-034 vocab, duplicate event id 336, headerless board). (5) git rev-list --count origin/main..HEAD = 0.
CF-205 filing commit is board-only (2 files, +2/-0), the committed row is unique/pending with non-empty probe/acceptance_criteria/reasoning, the probe reproduces exactly 'cited_cmd_hits=12 doc_says=1' with exit 0, selftest and boardctl validate are green, and the commit is pushed.

## Summary

Judge Result: CF-205-QA1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ The commit under judgement is BOARD-ONLY: it touches exactly two paths, .coding-hermes/board/tasks.jsonl (+1 line, 0 deletions) and .coding-hermes/board/events.jsonl (+1 line, the task_created event boardctl emits, 0 deletions). git show --stat <commit> shows 2 files changed, 2 insertions(+), 0 deletions and names no other path. Verify all of the following against the COMMITTED tree, not the working tree:

1. The committed board carries CF-205 exactly once and no id is duplicated: git show <commit>:.coding-hermes/board/tasks.jsonl | jq -r .id | sort | uniq -d prints nothing, and jq -r 'select(.id=="CF-205") | .status' prints pending.
2. CF-205 carries a non-empty probe field, an acceptance_criteria field, and a reasoning field: git show <commit>:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-205") | [.status, (.probe|length), (.acceptance_criteria|length), (.reasoning|length)] | @tsv' prints pending followed by three positive lengths.
3. Extract the probe from the COMMITTED row and run it verbatim from the repository root: git show HEAD:.coding-hermes/board/tasks.jsonl | jq -r 'select(.id=="CF-205").probe' > /tmp/cf205-probe.sh && bash /tmp/cf205-probe.sh prints exactly cited_cmd_hits=12 doc_says=1 and exits 0.
4. The gate is green at the same commit: bash tests/selftest.sh prints SELFTEST: PASS and bash scripts/boardctl validate prints RESULT: OK.
5. The commit is pushed: git rev-list --count origin/main..HEAD prints 0.

IMPORTANT SCOPE: CF-205 is a newly FILED row for an unfixed documentation defect. Do NOT evaluate or require the underlying docs/DESIGN.md fix — the criterion grades the filing only (row present in the committed tree, probe present and reproducing, gate green, pushed).: All sub-checks verified against committed tree (HEAD=1124ae0). Stat: '2 files changed, 2 insertions(+)' with numstat 1/0 for both .coding-hermes/board/events.jsonl and tasks.jsonl, no other path; added events.jsonl line is {"id":364,"event_type":"task_created","task_id":"CF-205"}. (1) jq -r .id | sort | uniq -d printed nothing; CF-205 status=pending. (2) field lengths: 'pending\t178\t1162\t2003' — all positive. (3) probe extracted from committed row and run verbatim from repo root printed exactly 'cited_cmd_hits=12 doc_says=1', exit=0. (4) bash tests/selftest.sh -> 'SELFTEST: PASS' exit 0; bash scripts/boardctl validate -> 'RESULT: OK (4 warning(s))' exit 0, warnings are pre-existing legacy rows (CF-034 vocab, duplicate event id 336, headerless board). (5) git rev-list --count origin/main..HEAD = 0.
CF-205 filing commit is board-only (2 files, +2/-0), the committed row is unique/pending with non-empty probe/acceptance_criteria/reasoning, the probe reproduces exactly 'cited_cmd_hits=12 doc_says=1' with exit 0, selftest and boardctl validate are green, and the commit is pushed.

Overall: PASS ✓
