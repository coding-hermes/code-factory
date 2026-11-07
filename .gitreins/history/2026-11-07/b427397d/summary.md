# Verdict: CF-097

**Task:** repo-url arm applies not_home_repo like the verify arm
**Evaluated:** 2026-11-07T19:31:40.044605
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Run from /home/kara/code-factory at the landed commit: (1) a hermetic fixture whose HOME is a git repo (init an empty repo at $HOME) must be REJECTED by 'python3 scripts/lane_target.py repo-url <HOME>' with exit 4 and a named home-directory reason, while the same path is still rejected by the verify arm; (2) 'python3 -B tests/test_lane_target.py' passes and includes a test proving both arms hermetically with HOME set inside the fixture and a non-home root still accepted; (3) 'bash tests/selftest.sh' prints SELFTEST: PASS including a new arm for that rejection, and 'bash scripts/boardctl validate' prints RESULT: OK.: (1) Hermetic run at commit 66598c9 with HOME=<tmp>/home initialized as a git repo: `env HOME=$tmpd/home python3 scripts/lane_target.py repo-url $tmpd/home` -> rc=4, stdout `FAIL repo_url '<HOME>' — not_home_repo: git top level is the home directory '<HOME>'` + `repo_url: 1 rejected, 0 accepted`; `verify $tmpd/home` -> rc=4 with `{"check":"not_home_repo","ok":false,"value":"top level is the home directory"}`. Fix is in check_repo_url (git show HEAD -- scripts/lane_target.py, +9 lines: home_real = os.path.realpath(os.path.expanduser("~")); if root == home_real: raise RuntimeError("not_home_repo: ...")). (2) `python3 -B tests/test_lane_target.py` -> exit 0, `Ran 43 tests in 1.575s` / `OK`. New class RepoURLHomeRoot at tests/test_lane_target.py:309-366: setUp inits a git repo at fixture home (:321-325), run_check passes env HOME=self.home_real (:332); test_home_rooted_repo_rejected_by_both_arms (:335) asserts verify_local not_home_repo false AND repo-url rc 4 with the named reason; test_non_home_root_still_accepted_under_fixture_home (:350) asserts rc 0 and `PASS repo_url ... HEAD <sha>`; test_subdirectory_of_home_repo_names_the_top_level_mismatch (:358). (3) `bash tests/selftest.sh` -> line 362 `SELFTEST: PASS`, with new section-19 arms at lines 11-12: `PASS  repo-url refuses the home-rooted repo verify refuses (exit 4, not_home_repo)` and the red control `PASS  pre-fix a32f234 accepts the home-rooted repo — the repo-url arm is falsifiable` (the 10 `FAIL` lines in the log are intentional negative-control arms of other sections). `bash scripts/boardctl validate` -> `RESULT: OK (7 warning(s))`.
All three sub-checks verified with live command output: repo-url and verify both reject a $HOME-rooted repo with exit 4 and the named not_home_repo reason, the 43-test suite passes with a hermetic RepoURLHomeRoot class covering both arms plus a non-home acceptance case, and selftest prints SELFTEST: PASS with the new arm while boardctl validate prints RESULT: OK.

## Summary

Judge Result: CF-097

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Run from /home/kara/code-factory at the landed commit: (1) a hermetic fixture whose HOME is a git repo (init an empty repo at $HOME) must be REJECTED by 'python3 scripts/lane_target.py repo-url <HOME>' with exit 4 and a named home-directory reason, while the same path is still rejected by the verify arm; (2) 'python3 -B tests/test_lane_target.py' passes and includes a test proving both arms hermetically with HOME set inside the fixture and a non-home root still accepted; (3) 'bash tests/selftest.sh' prints SELFTEST: PASS including a new arm for that rejection, and 'bash scripts/boardctl validate' prints RESULT: OK.: (1) Hermetic run at commit 66598c9 with HOME=<tmp>/home initialized as a git repo: `env HOME=$tmpd/home python3 scripts/lane_target.py repo-url $tmpd/home` -> rc=4, stdout `FAIL repo_url '<HOME>' — not_home_repo: git top level is the home directory '<HOME>'` + `repo_url: 1 rejected, 0 accepted`; `verify $tmpd/home` -> rc=4 with `{"check":"not_home_repo","ok":false,"value":"top level is the home directory"}`. Fix is in check_repo_url (git show HEAD -- scripts/lane_target.py, +9 lines: home_real = os.path.realpath(os.path.expanduser("~")); if root == home_real: raise RuntimeError("not_home_repo: ...")). (2) `python3 -B tests/test_lane_target.py` -> exit 0, `Ran 43 tests in 1.575s` / `OK`. New class RepoURLHomeRoot at tests/test_lane_target.py:309-366: setUp inits a git repo at fixture home (:321-325), run_check passes env HOME=self.home_real (:332); test_home_rooted_repo_rejected_by_both_arms (:335) asserts verify_local not_home_repo false AND repo-url rc 4 with the named reason; test_non_home_root_still_accepted_under_fixture_home (:350) asserts rc 0 and `PASS repo_url ... HEAD <sha>`; test_subdirectory_of_home_repo_names_the_top_level_mismatch (:358). (3) `bash tests/selftest.sh` -> line 362 `SELFTEST: PASS`, with new section-19 arms at lines 11-12: `PASS  repo-url refuses the home-rooted repo verify refuses (exit 4, not_home_repo)` and the red control `PASS  pre-fix a32f234 accepts the home-rooted repo — the repo-url arm is falsifiable` (the 10 `FAIL` lines in the log are intentional negative-control arms of other sections). `bash scripts/boardctl validate` -> `RESULT: OK (7 warning(s))`.
All three sub-checks verified with live command output: repo-url and verify both reject a $HOME-rooted repo with exit 4 and the named not_home_repo reason, the 43-test suite passes with a hermetic RepoURLHomeRoot class covering both arms plus a non-home acceptance case, and selftest prints SELFTEST: PASS with the new arm while boardctl validate prints RESULT: OK.

Overall: PASS ✓
