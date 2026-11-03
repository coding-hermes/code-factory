# Verdict: CF-095-R1

**Task:** CF-095 review filing is on the published tree and its defect premise reproduces
**Evaluated:** 2026-11-03T18:21:31.097831
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ At origin/main f975b1d, CF-095 exists in .coding-hermes/board/tasks.jsonl with status pending and a paste-runnable probe in detail.probe, and the premise reproduces: docs/audits/cf091-repo-url-census.md names tip d107ac4, a detached worktree at d107ac4 prints '383 rejected, 483 accepted' with zero 'diverges from primary' lines, while daf2208 prints '384 rejected, 482 accepted' with exactly one such line. Filing-only: the repair is future work.: Every sub-claim verified by command output. (1) `git rev-parse origin/main` = f975b1d57b5bae47d648689f9514535af68de05a. (2) .coding-hermes/board/tasks.jsonl:82 has CF-095 with "status":"pending" and detail.probe (551 chars, single line). Probe executed verbatim (REPO bound to repo path) printed exactly: `0` (grep -c family_key), `repo_url: 383 rejected, 483 accepted`, `0` (grep -c 'diverges from primary'), exit 0 — paste-runnable and self-evidencing. (3) docs/audits/cf091-repo-url-census.md:54 'Repository tip measured: d107ac40965eabac139ed60f9f5b474f7df63ba2 (d107ac4)'; census totals table lines 14-15 state Rejected 384 / Accepted 482 and line 27 lists the 'repo_url diverges from primary' class = 1. (4) Detached worktree at d107ac4: `grep -c family_key scripts/lane_target.py` = 0 and `grep -c 'diverges from primary'` = 0; running the census's documented command on the read-only sqlite export printed `repo_url: 383 rejected, 483 accepted` with `grep -c 'diverges from primary'` = 0. (5) Detached worktree at daf2208: `grep -c family_key` = 2; same export printed `repo_url: 384 rejected, 482 accepted` with exactly 1 divergence line: "FAIL repo_url 'local:/home/kara/helios' — repo_url diverges from primary 'helios': '/home/kara/helios' != '/home/kara/helios-work' [helios-releng]". (6) Filing-only confirmed: `git show --name-only f975b1d` lists only .coding-hermes/board/events.jsonl and .coding-hermes/board/tasks.jsonl (3 insertions); `git diff --stat daf2208 HEAD -- scripts/lane_target.py docs/audits/cf091-repo-url-census.md` is empty, so no repair was applied and the census still carries the stale tip. (7) `scripts/boardctl validate` → RESULT: OK (26 warnings, all pre-existing 'probe outside declared canon' style warnings on other rows). Tracked working tree clean at f975b1d.


## Summary

Judge Result: CF-095-R1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ At origin/main f975b1d, CF-095 exists in .coding-hermes/board/tasks.jsonl with status pending and a paste-runnable probe in detail.probe, and the premise reproduces: docs/audits/cf091-repo-url-census.md names tip d107ac4, a detached worktree at d107ac4 prints '383 rejected, 483 accepted' with zero 'diverges from primary' lines, while daf2208 prints '384 rejected, 482 accepted' with exactly one such line. Filing-only: the repair is future work.: Every sub-claim verified by command output. (1) `git rev-parse origin/main` = f975b1d57b5bae47d648689f9514535af68de05a. (2) .coding-hermes/board/tasks.jsonl:82 has CF-095 with "status":"pending" and detail.probe (551 chars, single line). Probe executed verbatim (REPO bound to repo path) printed exactly: `0` (grep -c family_key), `repo_url: 383 rejected, 483 accepted`, `0` (grep -c 'diverges from primary'), exit 0 — paste-runnable and self-evidencing. (3) docs/audits/cf091-repo-url-census.md:54 'Repository tip measured: d107ac40965eabac139ed60f9f5b474f7df63ba2 (d107ac4)'; census totals table lines 14-15 state Rejected 384 / Accepted 482 and line 27 lists the 'repo_url diverges from primary' class = 1. (4) Detached worktree at d107ac4: `grep -c family_key scripts/lane_target.py` = 0 and `grep -c 'diverges from primary'` = 0; running the census's documented command on the read-only sqlite export printed `repo_url: 383 rejected, 483 accepted` with `grep -c 'diverges from primary'` = 0. (5) Detached worktree at daf2208: `grep -c family_key` = 2; same export printed `repo_url: 384 rejected, 482 accepted` with exactly 1 divergence line: "FAIL repo_url 'local:/home/kara/helios' — repo_url diverges from primary 'helios': '/home/kara/helios' != '/home/kara/helios-work' [helios-releng]". (6) Filing-only confirmed: `git show --name-only f975b1d` lists only .coding-hermes/board/events.jsonl and .coding-hermes/board/tasks.jsonl (3 insertions); `git diff --stat daf2208 HEAD -- scripts/lane_target.py docs/audits/cf091-repo-url-census.md` is empty, so no repair was applied and the census still carries the stale tip. (7) `scripts/boardctl validate` → RESULT: OK (26 warnings, all pre-existing 'probe outside declared canon' style warnings on other rows). Tracked working tree clean at f975b1d.


Overall: PASS ✓
