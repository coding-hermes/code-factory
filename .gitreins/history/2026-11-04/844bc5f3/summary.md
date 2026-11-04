# Verdict: CF-147-RV2

**Task:** Review filing recovery: CF-147 delivered (row + probe + green gate; sibling rows disclosed, not insert-only)
**Evaluated:** 2026-11-04T02:46:00.726194
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ FILING-ONLY verification task (supersedes CF-147-RV1, whose criterion 5 required an insert-only +1-row commit). Do NOT grade or implement the underlying repair; the repair is future work tracked by the pending board row CF-147.

Context you must take as given: the graded board commit was authored while a second lane was alive and appending to the same two shared board files, so the commit legitimately carries that lane's lines in addition to this filing. Insert-only is therefore NOT a requirement of this task; attribution disclosure is.

Verify:
1. Row CF-147 is present exactly once in the committed board at the graded commit: status "pending", non-empty title, non-empty reasoning, non-empty acceptance_criteria, and a non-empty probe field (444 chars expected).
2. The probe is re-runnable by a stranger: `jq -r 'select(.id=="CF-147").probe' <board> > /tmp/p.sh && bash /tmp/p.sh` from the repo root prints "mutated-single rc=0" plus two concurrent lines reading rc=1. That output is the defect being filed. (Re-verified at 1abe4e2 on 2026-11-03 21:43 -05: mutated-single rc=0, conc-a rc=1, conc-b rc=1.)
3. `bash scripts/boardctl validate` prints RESULT: OK, and `bash tests/selftest.sh` prints SELFTEST: PASS and exits 0 at the graded tree.
4. Attribution disclosure: the graded commit's message names every line it swept from the concurrent lane (rows CF-148 and CF-149 and the CF-053 complete->in_progress flip) with their task ids, so a reader can attribute them without reading the working tree. The board then carries CF-147, CF-148 and CF-149 exactly once each, has zero duplicate ids, and no pre-existing row was deleted or renumbered: the row count grew from 120 to exactly 123 by those three named rows.
5. The GitReins task CF-147-QA1, left in_progress by the other lane, was NOT completed by this work.: All five sub-checks verified at graded commit bdadeb9 (board identical to HEAD 1384404: `git diff --stat bdadeb9 HEAD -- .coding-hermes/board/` empty). (1) `git show bdadeb9:.coding-hermes/board/tasks.jsonl | jq -s 'length'` for id==CF-147 = 1; fields: status=pending, title_len=176, reasoning_len=3646, acceptance_criteria string len=2454, probe string len=444 (exactly the expected 444). (2) Extracted probe to /tmp/p.sh and ran `bash /tmp/p.sh` from repo root -> output: 'mutated-single rc=0', 'conc-b rc=1', 'conc-a rc=1' (two concurrent lines rc=1), exit 0. (3) `bash scripts/boardctl validate` -> 'RESULT: OK (53 warning(s))', exit 0 (rows: 123 tasks, 181 events); `bash tests/selftest.sh` -> 'SELFTEST: PASS', SELFTEST_EXIT=0, 90 PASS rows. (4) Commit message contains a 'Sibling sweep, disclosed:' paragraph naming CF-148, CF-149 and 'flipped CF-053 complete -> in_progress (event 181)' with task ids; board at bdadeb9 = 123 rows vs parent bdadeb9^ = 120; comm of sorted ids shows added = exactly CF-147, CF-148, CF-149 and removed = none; `jq -r .id | sort | uniq -d` empty (zero duplicate ids); CF-148 and CF-149 each appear once; CF-053 status complete->in_progress confirmed; events 178/179/180/181 match the disclosure. (5) No GitReins task CF-147-QA1 exists in .gitreins/tasks.yaml (grep returns only the criterion text of CF-147-RV2 at line 870; task-id list has no CF-147-QA1) and no board row/event references it; bdadeb9's stat is board-only (tasks.jsonl + events.jsonl) and its message states the QA lane's CF-147-QA1 'was left in_progress by the dead execution; this commit does not touch it' — no evidence of completion by this work. No repair was graded or implemented.
Filing-only verification passes: CF-147 row present once with pending status and a 444-char re-runnable probe reproducing mutated-single rc=0 / conc-a rc=1 / conc-b rc=1, boardctl validate RESULT: OK and selftest SELFTEST: PASS exit 0, sibling sweep (CF-148, CF-149, CF-053 flip) fully disclosed with 120->123 rows and zero duplicates/deletions, and CF-147-QA1 untouched.

## Summary

Judge Result: CF-147-RV2

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ FILING-ONLY verification task (supersedes CF-147-RV1, whose criterion 5 required an insert-only +1-row commit). Do NOT grade or implement the underlying repair; the repair is future work tracked by the pending board row CF-147.

Context you must take as given: the graded board commit was authored while a second lane was alive and appending to the same two shared board files, so the commit legitimately carries that lane's lines in addition to this filing. Insert-only is therefore NOT a requirement of this task; attribution disclosure is.

Verify:
1. Row CF-147 is present exactly once in the committed board at the graded commit: status "pending", non-empty title, non-empty reasoning, non-empty acceptance_criteria, and a non-empty probe field (444 chars expected).
2. The probe is re-runnable by a stranger: `jq -r 'select(.id=="CF-147").probe' <board> > /tmp/p.sh && bash /tmp/p.sh` from the repo root prints "mutated-single rc=0" plus two concurrent lines reading rc=1. That output is the defect being filed. (Re-verified at 1abe4e2 on 2026-11-03 21:43 -05: mutated-single rc=0, conc-a rc=1, conc-b rc=1.)
3. `bash scripts/boardctl validate` prints RESULT: OK, and `bash tests/selftest.sh` prints SELFTEST: PASS and exits 0 at the graded tree.
4. Attribution disclosure: the graded commit's message names every line it swept from the concurrent lane (rows CF-148 and CF-149 and the CF-053 complete->in_progress flip) with their task ids, so a reader can attribute them without reading the working tree. The board then carries CF-147, CF-148 and CF-149 exactly once each, has zero duplicate ids, and no pre-existing row was deleted or renumbered: the row count grew from 120 to exactly 123 by those three named rows.
5. The GitReins task CF-147-QA1, left in_progress by the other lane, was NOT completed by this work.: All five sub-checks verified at graded commit bdadeb9 (board identical to HEAD 1384404: `git diff --stat bdadeb9 HEAD -- .coding-hermes/board/` empty). (1) `git show bdadeb9:.coding-hermes/board/tasks.jsonl | jq -s 'length'` for id==CF-147 = 1; fields: status=pending, title_len=176, reasoning_len=3646, acceptance_criteria string len=2454, probe string len=444 (exactly the expected 444). (2) Extracted probe to /tmp/p.sh and ran `bash /tmp/p.sh` from repo root -> output: 'mutated-single rc=0', 'conc-b rc=1', 'conc-a rc=1' (two concurrent lines rc=1), exit 0. (3) `bash scripts/boardctl validate` -> 'RESULT: OK (53 warning(s))', exit 0 (rows: 123 tasks, 181 events); `bash tests/selftest.sh` -> 'SELFTEST: PASS', SELFTEST_EXIT=0, 90 PASS rows. (4) Commit message contains a 'Sibling sweep, disclosed:' paragraph naming CF-148, CF-149 and 'flipped CF-053 complete -> in_progress (event 181)' with task ids; board at bdadeb9 = 123 rows vs parent bdadeb9^ = 120; comm of sorted ids shows added = exactly CF-147, CF-148, CF-149 and removed = none; `jq -r .id | sort | uniq -d` empty (zero duplicate ids); CF-148 and CF-149 each appear once; CF-053 status complete->in_progress confirmed; events 178/179/180/181 match the disclosure. (5) No GitReins task CF-147-QA1 exists in .gitreins/tasks.yaml (grep returns only the criterion text of CF-147-RV2 at line 870; task-id list has no CF-147-QA1) and no board row/event references it; bdadeb9's stat is board-only (tasks.jsonl + events.jsonl) and its message states the QA lane's CF-147-QA1 'was left in_progress by the dead execution; this commit does not touch it' — no evidence of completion by this work. No repair was graded or implemented.
Filing-only verification passes: CF-147 row present once with pending status and a 444-char re-runnable probe reproducing mutated-single rc=0 / conc-a rc=1 / conc-b rc=1, boardctl validate RESULT: OK and selftest SELFTEST: PASS exit 0, sibling sweep (CF-148, CF-149, CF-053 flip) fully disclosed with 120->123 rows and zero duplicates/deletions, and CF-147-QA1 untouched.

Overall: PASS ✓
