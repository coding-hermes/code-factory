# Verdict: CF-091

**Task:** Enforce intra-family repo_url agreement and publish a public-safe rejection census + waiver
**Evaluated:** 2026-11-03T17:54:44.349950
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ In a worktree at origin/main d107ac4: (1) scripts/lane_target.py repo-url --row enforces intra-family repo_url agreement: a primary+satellite fixture whose rows carry two different VALID git roots exits nonzero and names both lanes, while the aligned fixture exits 0; (2) a public-safe census artifact under docs/audits/ records live-export rejection totals by class plus the exact reproduction commands, with no lane names and no host paths, and a committed waiver file lists every remaining rejection class with a named owner and a re-check date; (3) tests/selftest.sh gains an arm that fails on the diverged fixture and passes on the aligned one, and reverting the divergence check makes that arm fail; (4) bash tests/selftest.sh prints SELFTEST: PASS and ruff check . plus ruff format --check . both exit 0.: (1) Manual fixture (two real git repos, rows fixture-primary / fixture-primary-qa): diverged -> exit 4 with "FAIL repo_url '.../b' — repo_url diverges from primary 'fixture-primary': '.../b' != '.../a' [fixture-primary-qa]" naming both lanes; aligned -> "repo_url: 0 rejected, 2 accepted", exit 0. Impl: scripts/lane_target.py:352-395 (FAMILY_SUFFIXES/family_key/normalized_repo_url) and :489-520 (family grouping, codes.add(4)). (2) docs/audits/cf091-repo-url-census.md records totals (866 rows / 384 rejected / 482 accepted / exit 2), 6 rejection classes with counts, and exact reproduction commands (sqlite3 read-only export + `python3 -B scripts/lane_target.py repo-url --row projects.json`); cf091-repo-url-census.json mirrors it machine-readably. grep for /home/, /Users/, /var/tmp, /tmp/, hermes-scratch, .hermes across census md/json/waiver returned no matches (RC=1) and no lane names appear. docs/audits/cf091-repo-url-waiver.json lists all 6 classes, each with owner "scheduler-operator (fleet-ops)" and re_check "2026-12-01". (3) tests/selftest.sh:587-615 adds arm 20; unmodified run prints "PASS repo_url family agreement: diverged fixture rejected naming both lanes, aligned accepted"; after reverting the check (scripts/lane_target.py:489 `if row_file is not None:` -> `if False:`) the arm prints "FAIL repo_url family agreement (diverged exit 0, aligned exit 0)" and "SELFTEST: FAIL (2)" with exit 1 (file restored, tree clean). (4) `bash tests/selftest.sh` -> exit 0, tail "SELFTEST: PASS"; `ruff check .` -> "All checks passed!" exit 0; `ruff format --check .` -> "9 files already formatted" exit 0. Also `python3 -m unittest tests.test_lane_target` -> Ran 36 tests, OK.
All four sub-criteria verified with live command output: family divergence is enforced (exit 4 naming both lanes vs exit 0 aligned), the public-safe census + waiver artifacts are complete and host-path/lane-name free, the new selftest arm fails when the check is reverted, and selftest plus both ruff commands exit 0.

## Summary

Judge Result: CF-091

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ In a worktree at origin/main d107ac4: (1) scripts/lane_target.py repo-url --row enforces intra-family repo_url agreement: a primary+satellite fixture whose rows carry two different VALID git roots exits nonzero and names both lanes, while the aligned fixture exits 0; (2) a public-safe census artifact under docs/audits/ records live-export rejection totals by class plus the exact reproduction commands, with no lane names and no host paths, and a committed waiver file lists every remaining rejection class with a named owner and a re-check date; (3) tests/selftest.sh gains an arm that fails on the diverged fixture and passes on the aligned one, and reverting the divergence check makes that arm fail; (4) bash tests/selftest.sh prints SELFTEST: PASS and ruff check . plus ruff format --check . both exit 0.: (1) Manual fixture (two real git repos, rows fixture-primary / fixture-primary-qa): diverged -> exit 4 with "FAIL repo_url '.../b' — repo_url diverges from primary 'fixture-primary': '.../b' != '.../a' [fixture-primary-qa]" naming both lanes; aligned -> "repo_url: 0 rejected, 2 accepted", exit 0. Impl: scripts/lane_target.py:352-395 (FAMILY_SUFFIXES/family_key/normalized_repo_url) and :489-520 (family grouping, codes.add(4)). (2) docs/audits/cf091-repo-url-census.md records totals (866 rows / 384 rejected / 482 accepted / exit 2), 6 rejection classes with counts, and exact reproduction commands (sqlite3 read-only export + `python3 -B scripts/lane_target.py repo-url --row projects.json`); cf091-repo-url-census.json mirrors it machine-readably. grep for /home/, /Users/, /var/tmp, /tmp/, hermes-scratch, .hermes across census md/json/waiver returned no matches (RC=1) and no lane names appear. docs/audits/cf091-repo-url-waiver.json lists all 6 classes, each with owner "scheduler-operator (fleet-ops)" and re_check "2026-12-01". (3) tests/selftest.sh:587-615 adds arm 20; unmodified run prints "PASS repo_url family agreement: diverged fixture rejected naming both lanes, aligned accepted"; after reverting the check (scripts/lane_target.py:489 `if row_file is not None:` -> `if False:`) the arm prints "FAIL repo_url family agreement (diverged exit 0, aligned exit 0)" and "SELFTEST: FAIL (2)" with exit 1 (file restored, tree clean). (4) `bash tests/selftest.sh` -> exit 0, tail "SELFTEST: PASS"; `ruff check .` -> "All checks passed!" exit 0; `ruff format --check .` -> "9 files already formatted" exit 0. Also `python3 -m unittest tests.test_lane_target` -> Ran 36 tests, OK.
All four sub-criteria verified with live command output: family divergence is enforced (exit 4 naming both lanes vs exit 0 aligned), the public-safe census + waiver artifacts are complete and host-path/lane-name free, the new selftest arm fails when the check is reverted, and selftest plus both ruff commands exit 0.

Overall: PASS ✓
