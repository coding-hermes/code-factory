# Verdict: CF-085

**Task:** Validate project-row local: repo_url resolves to a git root and document satellite repoint fan-out
**Evaluated:** 2026-11-03T16:52:06.865534
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ scripts/lane_target.py gains a repo-url check that rejects a project row whose local: repo_url is not a git root (naming the path and the git error, non-zero exit) while a real git root exits 0: scripts/lane_target.py adds check_repo_url() (requires realpath == git rev-parse --show-toplevel and a readable HEAD) and repo_urls() plus the `repo-url` subparser. Live runs: real git root -> "PASS repo_url '/tmp/.../real' — root '/tmp/.../real' HEAD 55f61a5b..." exit 0; phantom `local:/tmp/.../nope` -> "FAIL repo_url 'local:/tmp/.../nope' — path does not exist or is not a directory" exit 4; non-git dir -> "FAIL repo_url '.../plain' — not a git root (git: fatal: not a git repository (or any of the parent directories): .git)" exit 4; subdirectory -> "FAIL ... not a git root (git: top level is '.../real')" exit 4. Path and git error are named, exit is non-zero.
  ✓ tests/test_lane_target.py proves phantom, missing-path, non-git and real-root cases and tests/selftest.sh prints a PASS line naming the new check, SELFTEST: PASS: tests/test_lane_target.py class RepoURL (lines 214-303): test_phantom_root (missing path, exit 4, "path does not exist"), test_non_git_directory (exit 4, "not a git root (git: fatal:"), test_subdirectory (exit 4, "not a git root (git: top level is ...)"), test_real_root_spellings (exit 0, "PASS repo_url ... root ... HEAD ..."). `python3 -B tests/test_lane_target.py` -> "Ran 30 tests in 1.046s / OK", exit 0. `bash tests/selftest.sh` -> exit 0, prints "19. project repo_url must name a real git root (CF-085)", "PASS  repo_url guard rejects a phantom local: root (1 rejected, 1 accepted)", "SELFTEST: PASS".
  ✓ docs/SCHEDULER-ADMISSION.md documents the satellite repoint reconciliation; scripts/boardctl validate prints RESULT: OK; work committed on the branch: docs/SCHEDULER-ADMISSION.md lines 64-105 add "## Repo URL guard and primary-family reconciliation (CF-085)" with guard usage/exit codes and a 3-step operator reconciliation (inventory primary + every satellite, partial repo_url PUT plus matching fleet.toml update per satellite, read-back and re-run `repo-url --row` requiring "0 rejected"). `bash scripts/boardctl validate` -> exit 0, "RESULT: OK (24 warning(s))". Work committed on branch cf/cf-085-repo-url-root at d00577e "fix: reject project-row local: repo_url that is not a git root. Addresses CF-085." touching all four files; `git status --short` is empty.
All three criteria verified with live command output: repo-url guard rejects phantom/non-git/subdir roots with named path+git error and exit 4 while a real root exits 0, 30 tests OK plus SELFTEST: PASS naming the new check, docs document satellite repoint reconciliation, boardctl validate prints RESULT: OK, and the work is committed on the branch.

## Summary

Judge Result: CF-085

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ scripts/lane_target.py gains a repo-url check that rejects a project row whose local: repo_url is not a git root (naming the path and the git error, non-zero exit) while a real git root exits 0: scripts/lane_target.py adds check_repo_url() (requires realpath == git rev-parse --show-toplevel and a readable HEAD) and repo_urls() plus the `repo-url` subparser. Live runs: real git root -> "PASS repo_url '/tmp/.../real' — root '/tmp/.../real' HEAD 55f61a5b..." exit 0; phantom `local:/tmp/.../nope` -> "FAIL repo_url 'local:/tmp/.../nope' — path does not exist or is not a directory" exit 4; non-git dir -> "FAIL repo_url '.../plain' — not a git root (git: fatal: not a git repository (or any of the parent directories): .git)" exit 4; subdirectory -> "FAIL ... not a git root (git: top level is '.../real')" exit 4. Path and git error are named, exit is non-zero.
  ✓ tests/test_lane_target.py proves phantom, missing-path, non-git and real-root cases and tests/selftest.sh prints a PASS line naming the new check, SELFTEST: PASS: tests/test_lane_target.py class RepoURL (lines 214-303): test_phantom_root (missing path, exit 4, "path does not exist"), test_non_git_directory (exit 4, "not a git root (git: fatal:"), test_subdirectory (exit 4, "not a git root (git: top level is ...)"), test_real_root_spellings (exit 0, "PASS repo_url ... root ... HEAD ..."). `python3 -B tests/test_lane_target.py` -> "Ran 30 tests in 1.046s / OK", exit 0. `bash tests/selftest.sh` -> exit 0, prints "19. project repo_url must name a real git root (CF-085)", "PASS  repo_url guard rejects a phantom local: root (1 rejected, 1 accepted)", "SELFTEST: PASS".
  ✓ docs/SCHEDULER-ADMISSION.md documents the satellite repoint reconciliation; scripts/boardctl validate prints RESULT: OK; work committed on the branch: docs/SCHEDULER-ADMISSION.md lines 64-105 add "## Repo URL guard and primary-family reconciliation (CF-085)" with guard usage/exit codes and a 3-step operator reconciliation (inventory primary + every satellite, partial repo_url PUT plus matching fleet.toml update per satellite, read-back and re-run `repo-url --row` requiring "0 rejected"). `bash scripts/boardctl validate` -> exit 0, "RESULT: OK (24 warning(s))". Work committed on branch cf/cf-085-repo-url-root at d00577e "fix: reject project-row local: repo_url that is not a git root. Addresses CF-085." touching all four files; `git status --short` is empty.
All three criteria verified with live command output: repo-url guard rejects phantom/non-git/subdir roots with named path+git error and exit 4 while a real root exits 0, 30 tests OK plus SELFTEST: PASS naming the new check, docs document satellite repoint reconciliation, boardctl validate prints RESULT: OK, and the work is committed on the branch.

Overall: PASS ✓
