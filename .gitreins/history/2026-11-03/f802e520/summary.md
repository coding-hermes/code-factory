# Verdict: CF-091

**Task:** Enforce intra-family repo_url agreement and publish a public-safe rejection census + waiver
**Evaluated:** 2026-11-03T17:59:43.372304
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ In a worktree at origin/main d107ac4: (1) scripts/lane_target.py repo-url --row enforces intra-family repo_url agreement: a primary+satellite fixture whose rows carry two different VALID git roots exits nonzero and names both lanes, while the aligned fixture exits 0; (2) a public-safe census artifact under docs/audits/ records live-export rejection totals by class plus the exact reproduction commands, with no lane names and no host paths, and a committed waiver file lists every remaining rejection class with a named owner and a re-check date; (3) tests/selftest.sh gains an arm that fails on the diverged fixture and passes on the aligned one, and reverting the divergence check makes that arm fail; (4) bash tests/selftest.sh prints SELFTEST: PASS and ruff check . plus ruff format --check . both exit 0.: (1) Live run of `python3 -B scripts/lane_target.py repo-url --row` on a primary+`-qa` fixture with two distinct valid git roots: exit 4, output `FAIL repo_url 'local:.../b' — repo_url diverges from primary 'fixture-primary': '.../b' != '.../a' [fixture-primary-qa]` (both lanes named); aligned fixture: exit 0, `repo_url: 0 rejected, 2 accepted`. Implementation at scripts/lane_target.py:483-514 (family_key/normalized_repo_url at :365-395). (2) docs/audits/cf091-repo-url-census.md + .json record totals (866 rows / 384 rejected / 482 accepted / exit 2) and per-class counts (253 stand-in top level, 76 unsupported https, 38 missing path, 15 non-git dir, 1 relative path, 1 diverges-from-primary) plus exact reproduction commands (read-only `sqlite3 -json "file:$HERMES_HOME/...?mode=ro&immutable=1"` export then `python3 -B scripts/lane_target.py repo-url --row projects.json`); grep for /home/ /Users/ /root/ /tmp/ /var/ /opt/ /srv/ /mnt/ returned no matches (exit 1) and no lane names appear (only cf091-* artifact filenames). docs/audits/cf091-repo-url-waiver.json lists all 6 classes, each with owner "scheduler-operator (fleet-ops)" and re_check "2026-12-01". (3) tests/selftest.sh:660-687 adds arm 21 building diverged.json/aligned.json and asserting diverged rc!=0 + both lane tags + aligned rc==0; deleting the divergence block from scripts/lane_target.py produced `FAIL repo_url family agreement (diverged exit 0, aligned exit 0)` and `SELFTEST: FAIL (2)`; file restored, git status clean. (4) `bash tests/selftest.sh` -> `SELFTEST: PASS` exit 0 (arm 21 PASS); `ruff check .` -> `All checks passed!` exit 0; `ruff format --check .` -> `11 files already formatted` exit 0; `python3 -B tests/test_lane_target.py` -> `Ran 36 tests ... OK`.
All four sub-criteria verified with live command output: intra-family divergence exits 4 naming both lanes while aligned exits 0, the public-safe census + waiver artifacts are complete and host-path/lane-name free, the new selftest arm fails when the check is reverted, and selftest plus both ruff commands exit 0.

## Summary

Judge Result: CF-091

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ In a worktree at origin/main d107ac4: (1) scripts/lane_target.py repo-url --row enforces intra-family repo_url agreement: a primary+satellite fixture whose rows carry two different VALID git roots exits nonzero and names both lanes, while the aligned fixture exits 0; (2) a public-safe census artifact under docs/audits/ records live-export rejection totals by class plus the exact reproduction commands, with no lane names and no host paths, and a committed waiver file lists every remaining rejection class with a named owner and a re-check date; (3) tests/selftest.sh gains an arm that fails on the diverged fixture and passes on the aligned one, and reverting the divergence check makes that arm fail; (4) bash tests/selftest.sh prints SELFTEST: PASS and ruff check . plus ruff format --check . both exit 0.: (1) Live run of `python3 -B scripts/lane_target.py repo-url --row` on a primary+`-qa` fixture with two distinct valid git roots: exit 4, output `FAIL repo_url 'local:.../b' — repo_url diverges from primary 'fixture-primary': '.../b' != '.../a' [fixture-primary-qa]` (both lanes named); aligned fixture: exit 0, `repo_url: 0 rejected, 2 accepted`. Implementation at scripts/lane_target.py:483-514 (family_key/normalized_repo_url at :365-395). (2) docs/audits/cf091-repo-url-census.md + .json record totals (866 rows / 384 rejected / 482 accepted / exit 2) and per-class counts (253 stand-in top level, 76 unsupported https, 38 missing path, 15 non-git dir, 1 relative path, 1 diverges-from-primary) plus exact reproduction commands (read-only `sqlite3 -json "file:$HERMES_HOME/...?mode=ro&immutable=1"` export then `python3 -B scripts/lane_target.py repo-url --row projects.json`); grep for /home/ /Users/ /root/ /tmp/ /var/ /opt/ /srv/ /mnt/ returned no matches (exit 1) and no lane names appear (only cf091-* artifact filenames). docs/audits/cf091-repo-url-waiver.json lists all 6 classes, each with owner "scheduler-operator (fleet-ops)" and re_check "2026-12-01". (3) tests/selftest.sh:660-687 adds arm 21 building diverged.json/aligned.json and asserting diverged rc!=0 + both lane tags + aligned rc==0; deleting the divergence block from scripts/lane_target.py produced `FAIL repo_url family agreement (diverged exit 0, aligned exit 0)` and `SELFTEST: FAIL (2)`; file restored, git status clean. (4) `bash tests/selftest.sh` -> `SELFTEST: PASS` exit 0 (arm 21 PASS); `ruff check .` -> `All checks passed!` exit 0; `ruff format --check .` -> `11 files already formatted` exit 0; `python3 -B tests/test_lane_target.py` -> `Ran 36 tests ... OK`.
All four sub-criteria verified with live command output: intra-family divergence exits 4 naming both lanes while aligned exits 0, the public-safe census + waiver artifacts are complete and host-path/lane-name free, the new selftest arm fails when the check is reverted, and selftest plus both ruff commands exit 0.

Overall: PASS ✓
