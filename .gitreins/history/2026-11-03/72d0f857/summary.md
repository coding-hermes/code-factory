# Verdict: CF-095

**Task:** CF-091 census names tip d107ac4, which carries no family check
**Evaluated:** 2026-11-03T18:19:59.173938
**Result:** ✗ FAIL

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✗ **tier2**
  - INCOMPLETE
  ✗ A worktree at the tip named in docs/audits/cf091-repo-url-census.md reproduces its totals (866 rows, 384 rejected, 482 accepted, exit 2) and prints at least one repo_url diverges from primary line; today that tip prints 383 rejected/483 accepted with zero divergence lines.: The census names tip d107ac40965eabac139ed60f9f5b474f7df63ba2 (docs/audits/cf091-repo-url-census.md 'Repository tip measured'; cf091-repo-url-census.json tip_commit). A fresh worktree at that tip (`git worktree add --detach /tmp/wt_d107ac4 d107ac4`) run against the read-only export (866 rows, matching the census row count) gives: `python3 -B scripts/lane_target.py repo-url --row /tmp/projects.json` -> exit=2, 'repo_url: 383 rejected, 483 accepted', and `grep -c 'diverges from primary'` = 0 — i.e. exactly the broken state the criterion describes, not the census totals (384/482 + >=1 divergence line). d107ac4 does not even contain docs/audits/cf091-repo-url-census.md (ls: No such file or directory) and `grep diverges d107ac4:scripts/lane_target.py` returns no match; the family check (FAMILY_SUFFIXES/family_key/normalized_repo_url + divergence block) was added only in daf2208. The current HEAD f975b1d does print 384 rejected/482 accepted with 1 divergence line ('FAIL repo_url local:/home/kara/helios — repo_url diverges from primary helios'), but that is not the tip the census cites. The task's only commit f975b1d is board-only (board/events.jsonl, board/tasks.jsonl) and changes neither the census tip reference nor the code, so the criterion is unmet.
The census still cites d107ac4, which reproduces 383 rejected/483 accepted with zero divergence lines; only the later daf2208/HEAD carries the family check, and the task commit is board-only.

## Summary

Judge Result: CF-095

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: FAIL
  INCOMPLETE
  ✗ A worktree at the tip named in docs/audits/cf091-repo-url-census.md reproduces its totals (866 rows, 384 rejected, 482 accepted, exit 2) and prints at least one repo_url diverges from primary line; today that tip prints 383 rejected/483 accepted with zero divergence lines.: The census names tip d107ac40965eabac139ed60f9f5b474f7df63ba2 (docs/audits/cf091-repo-url-census.md 'Repository tip measured'; cf091-repo-url-census.json tip_commit). A fresh worktree at that tip (`git worktree add --detach /tmp/wt_d107ac4 d107ac4`) run against the read-only export (866 rows, matching the census row count) gives: `python3 -B scripts/lane_target.py repo-url --row /tmp/projects.json` -> exit=2, 'repo_url: 383 rejected, 483 accepted', and `grep -c 'diverges from primary'` = 0 — i.e. exactly the broken state the criterion describes, not the census totals (384/482 + >=1 divergence line). d107ac4 does not even contain docs/audits/cf091-repo-url-census.md (ls: No such file or directory) and `grep diverges d107ac4:scripts/lane_target.py` returns no match; the family check (FAMILY_SUFFIXES/family_key/normalized_repo_url + divergence block) was added only in daf2208. The current HEAD f975b1d does print 384 rejected/482 accepted with 1 divergence line ('FAIL repo_url local:/home/kara/helios — repo_url diverges from primary helios'), but that is not the tip the census cites. The task's only commit f975b1d is board-only (board/events.jsonl, board/tasks.jsonl) and changes neither the census tip reference nor the code, so the criterion is unmet.
The census still cites d107ac4, which reproduces 383 rejected/483 accepted with zero divergence lines; only the later daf2208/HEAD carries the family check, and the task commit is board-only.

Overall: FAIL ✗
