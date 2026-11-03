# Verdict: CF-007-AC3-RECLAIM

**Task:** Node reclaim before disk-floor refusal (CF-007 AC3)
**Evaluated:** 2026-11-03T17:35:28.439839
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ A node below its disk floor runs a bounded user-space reclaim of build caches, job dirs and stale clones before refusing admission, re-measures free space, reports the reclaimed GiB, and refuses only if still below the floor; a hermetic test proves each target, the kept-fresh-job and out-of-root cases, idempotence (second run reclaims 0), and that --check does not mutate; tests/selftest.sh prints SELFTEST: PASS.: scripts/reclaim_disk.py defines bounded targets BUILD_CACHES (.cache/pip, .cache/uv, .cache/pre-commit, .cache/go-build, .npm/_cacache) and AGED_PARENTS (.node/jobs, .node/clones) with a TTL; safety_reason() (lines 25-40) rejects symlinks, out-of-root real paths and PROTECTED (repo, .node/node.json, .node/crier.json, .node/floor.toml); reclaim() returns reclaimed_bytes/reclaimed_mib. scripts/project-node.sh:145-181: on --apply below floor it runs `reclaim_disk.py run --root "$HOME" --json`, prints the per-target lines, parses reclaimed_mib, re-measures via free_gb, emits `ok "disk" "${free} GB free after reclaim (freed ${freed} MiB; floor ...)"` and only then `bad "disk" ... < floor` + exit 1; the --check branch (lines 149-150) only prints 'check mode never mutates' and never invokes the reclaimer. Hermetic tests: `python3 -B tests/test_reclaim.py` -> 'Ran 9 tests in 0.735s / OK' covering test_all_targets (each cache), test_jobs_and_clones_ttl (old reaped, fresh kept), test_symlinks_and_outside_survive + test_symlink_parent_and_nested_symlink (out-of-root), test_protected_paths_survive_even_when_old, test_invalid_roots_and_ttl, test_idempotence_and_json (second run reclaimed_bytes == 0 and 'nothing to reclaim'), test_dry_run_reports_same_bytes_without_removal, test_targets. tests/selftest.sh section 20 (lines 587-660) proves reap-before-FAIL ordering, --check preserving the 8192-byte pip payload, re-measure admitting a recovered node, and fail-closed missing reclaimer. Ran the configured test command `bash tests/selftest.sh` -> exit=0, output line 86 'SELFTEST: PASS' (the lone '^  FAIL' at log line 55 is expected fixture output inside section 16's missing-disk_floor negative test). Manual spot-checks: --dry-run left the payload intact; a symlinked .cache/uv reported 'skipped:symlink' with the outside file untouched; second run reported reclaimed_bytes 0. scripts/node-create.sh:20 stages reclaim_disk.py so it reaches a node.
Reclaim-before-refusal is implemented in reclaim_disk.py + project-node.sh with re-measurement and GiB/MiB reporting, covered by 9 hermetic tests and selftest section 20, and `bash tests/selftest.sh` exits 0 printing SELFTEST: PASS.

## Summary

Judge Result: CF-007-AC3-RECLAIM

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ A node below its disk floor runs a bounded user-space reclaim of build caches, job dirs and stale clones before refusing admission, re-measures free space, reports the reclaimed GiB, and refuses only if still below the floor; a hermetic test proves each target, the kept-fresh-job and out-of-root cases, idempotence (second run reclaims 0), and that --check does not mutate; tests/selftest.sh prints SELFTEST: PASS.: scripts/reclaim_disk.py defines bounded targets BUILD_CACHES (.cache/pip, .cache/uv, .cache/pre-commit, .cache/go-build, .npm/_cacache) and AGED_PARENTS (.node/jobs, .node/clones) with a TTL; safety_reason() (lines 25-40) rejects symlinks, out-of-root real paths and PROTECTED (repo, .node/node.json, .node/crier.json, .node/floor.toml); reclaim() returns reclaimed_bytes/reclaimed_mib. scripts/project-node.sh:145-181: on --apply below floor it runs `reclaim_disk.py run --root "$HOME" --json`, prints the per-target lines, parses reclaimed_mib, re-measures via free_gb, emits `ok "disk" "${free} GB free after reclaim (freed ${freed} MiB; floor ...)"` and only then `bad "disk" ... < floor` + exit 1; the --check branch (lines 149-150) only prints 'check mode never mutates' and never invokes the reclaimer. Hermetic tests: `python3 -B tests/test_reclaim.py` -> 'Ran 9 tests in 0.735s / OK' covering test_all_targets (each cache), test_jobs_and_clones_ttl (old reaped, fresh kept), test_symlinks_and_outside_survive + test_symlink_parent_and_nested_symlink (out-of-root), test_protected_paths_survive_even_when_old, test_invalid_roots_and_ttl, test_idempotence_and_json (second run reclaimed_bytes == 0 and 'nothing to reclaim'), test_dry_run_reports_same_bytes_without_removal, test_targets. tests/selftest.sh section 20 (lines 587-660) proves reap-before-FAIL ordering, --check preserving the 8192-byte pip payload, re-measure admitting a recovered node, and fail-closed missing reclaimer. Ran the configured test command `bash tests/selftest.sh` -> exit=0, output line 86 'SELFTEST: PASS' (the lone '^  FAIL' at log line 55 is expected fixture output inside section 16's missing-disk_floor negative test). Manual spot-checks: --dry-run left the payload intact; a symlinked .cache/uv reported 'skipped:symlink' with the outside file untouched; second run reported reclaimed_bytes 0. scripts/node-create.sh:20 stages reclaim_disk.py so it reaches a node.
Reclaim-before-refusal is implemented in reclaim_disk.py + project-node.sh with re-measurement and GiB/MiB reporting, covered by 9 hermetic tests and selftest section 20, and `bash tests/selftest.sh` exits 0 printing SELFTEST: PASS.

Overall: PASS ✓
