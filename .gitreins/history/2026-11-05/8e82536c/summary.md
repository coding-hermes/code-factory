# Verdict: SYNC-2026-11-05-2316

**Task:** Bind CF-302 completion evidence to its tracked verdict artifact (sync lane bookkeeping)
**Evaluated:** 2026-11-05T23:54:58.372208
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Commit 7dde7da on origin/main carries a CF-302 row whose newest evidence entry names the artifact .gitreins/history/2026-11-05/85a546ff/verdict.json with tree_fp 297a0c26f425270093e635f6ff8c133b17d8feb206c0ba15552b9e22fcb94fcc, while the earlier run_id-only evidence entry is still present; the row still reads status complete, commit_hash f996376b1a318726de401228c2db7f58c3d79823, guard PASS, ci SKIP; the board holds 343 task rows and event 460 is an audit attributed to CF-302; board validation reports RESULT: OK and the repository selftest at f996376 reports SELFTEST: PASS. The landing-gate repair itself is out of scope: it was judged separately as run 85a546ff.: origin/main == 7dde7dabc650f1542834ac00f9922750bc551249 (git rev-parse origin/main). At 7dde7da, .coding-hermes/board/tasks.jsonl has 343 rows, no duplicate ids, one CF-302 row: detail.evidence[0]={run_id 85a546ff, ts 2026-11-05T23:44:41Z} (run_id-only entry preserved), evidence[1]={run_id 85a546ff, ts 2026-11-05T23:49:55Z, tree_fp 297a0c26f425270093e635f6ff8c133b17d8feb206c0ba15552b9e22fcb94fcc, artifacts [".gitreins/history/2026-11-05/85a546ff/verdict.json"]}; row reads status=complete, commit_hash=f996376b1a318726de401228c2db7f58c3d79823, guard_result=PASS, ci_result=SKIP. Artifact is tracked at 7dde7da (git ls-tree lists commit.patch, summary.md, verdict.json) and sha256sum of verdict.json == 297a0c26f425270093e635f6ff8c133b17d8feb206c0ba15552b9e22fcb94fcc; verdict.json content reads task_id=CF-302, commit=f996376b1a318726de401228c2db7f58c3d79823, passed=true. events.jsonl at 7dde7da has 461 events and id 460 = {"event_type":"audit","task_id":"CF-302","actor":"sync-lane"}. `bash scripts/boardctl validate` -> 'rows: 343 tasks, 461 events' and 'RESULT: OK (6 warning(s))', exit 0. `bash tests/selftest.sh` run fresh at 7dde7da -> 'SELFTEST: PASS' with 342 '  PASS' rows and 0 top-level FAIL rows (FAIL strings in the log are expected fixture output, e.g. section 7b). f996376 is an ancestor of origin/main (git merge-base --is-ancestor).


## Summary

Judge Result: SYNC-2026-11-05-2316

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Commit 7dde7da on origin/main carries a CF-302 row whose newest evidence entry names the artifact .gitreins/history/2026-11-05/85a546ff/verdict.json with tree_fp 297a0c26f425270093e635f6ff8c133b17d8feb206c0ba15552b9e22fcb94fcc, while the earlier run_id-only evidence entry is still present; the row still reads status complete, commit_hash f996376b1a318726de401228c2db7f58c3d79823, guard PASS, ci SKIP; the board holds 343 task rows and event 460 is an audit attributed to CF-302; board validation reports RESULT: OK and the repository selftest at f996376 reports SELFTEST: PASS. The landing-gate repair itself is out of scope: it was judged separately as run 85a546ff.: origin/main == 7dde7dabc650f1542834ac00f9922750bc551249 (git rev-parse origin/main). At 7dde7da, .coding-hermes/board/tasks.jsonl has 343 rows, no duplicate ids, one CF-302 row: detail.evidence[0]={run_id 85a546ff, ts 2026-11-05T23:44:41Z} (run_id-only entry preserved), evidence[1]={run_id 85a546ff, ts 2026-11-05T23:49:55Z, tree_fp 297a0c26f425270093e635f6ff8c133b17d8feb206c0ba15552b9e22fcb94fcc, artifacts [".gitreins/history/2026-11-05/85a546ff/verdict.json"]}; row reads status=complete, commit_hash=f996376b1a318726de401228c2db7f58c3d79823, guard_result=PASS, ci_result=SKIP. Artifact is tracked at 7dde7da (git ls-tree lists commit.patch, summary.md, verdict.json) and sha256sum of verdict.json == 297a0c26f425270093e635f6ff8c133b17d8feb206c0ba15552b9e22fcb94fcc; verdict.json content reads task_id=CF-302, commit=f996376b1a318726de401228c2db7f58c3d79823, passed=true. events.jsonl at 7dde7da has 461 events and id 460 = {"event_type":"audit","task_id":"CF-302","actor":"sync-lane"}. `bash scripts/boardctl validate` -> 'rows: 343 tasks, 461 events' and 'RESULT: OK (6 warning(s))', exit 0. `bash tests/selftest.sh` run fresh at 7dde7da -> 'SELFTEST: PASS' with 342 '  PASS' rows and 0 top-level FAIL rows (FAIL strings in the log are expected fixture output, e.g. section 7b). f996376 is an ancestor of origin/main (git merge-base --is-ancestor).


Overall: PASS ✓
