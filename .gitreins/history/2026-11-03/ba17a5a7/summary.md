# Verdict: CF-091-QA

**Task:** QA: the repo_url guard has never been applied to the live fleet
**Evaluated:** 2026-11-03T17:30:08.444469
**Result:** ✗ FAIL

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✗ **tier2**
  - INCOMPLETE
  ✗ A committed census shows the documented repo_url guard printing 0 rejected over every family named in docs/SCHEDULER-ADMISSION.md, or per-lane waivers with owners, and a selftest arm that fails when two rows of one family carry different valid roots.: None of the three required artifacts exist. (1) No committed census: `ls docs/audits/` shows no repo_url census file; the only docs/audits file mentioning repo_url is docs/audits/cf090-ruff-format.txt (incidental). The only record of a guard run is the CF-091 board row (.coding-hermes/board/tasks.jsonl:78), which reports the opposite of the criterion — '383 rejected, 483 accepted', exit 2, with the duckbrain family at 7 rejected — and is a bug report, not a census. (2) No waivers: `grep -rn waiver docs/ tests/ scripts/` returns nothing; the only hit is the CF-091 board row's own acceptance-criteria text, so there is no committed waiver file with named owners and re-check dates. (3) No divergence selftest arm: tests/selftest.sh arm 19 (lines 567-583) only compares a single valid `local:` root against a single phantom root ('PASS repo_url guard rejects a phantom local: root (1 rejected, 1 accepted)'); tests/test_lane_target.py test_rows_stdin_and_file (line 279-292) asserts '1 rejected, 1 accepted' for a phantom row, and no test anywhere feeds two rows of one family on two different VALID git roots. scripts/lane_target.py repo_urls() (lines 378-428) has no family grouping or primary-vs-satellite value comparison, so it cannot fail on divergence. Test evidence: `bash tests/selftest.sh` → EXIT=0, tail 'SELFTEST: PASS' (arm 19 PASS), i.e. the suite is green but contains no arm covering the required condition. The last commit a2cc8b8 touched only .coding-hermes/board/{events,tasks}.jsonl (5 insertions), adding no census, waiver, or test.
The task only filed CF-091 as a pending board row; no committed census, no waivers with owners, and no divergence-detecting selftest arm exist, so the criterion is unmet.

## Summary

Judge Result: CF-091-QA

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: FAIL
  INCOMPLETE
  ✗ A committed census shows the documented repo_url guard printing 0 rejected over every family named in docs/SCHEDULER-ADMISSION.md, or per-lane waivers with owners, and a selftest arm that fails when two rows of one family carry different valid roots.: None of the three required artifacts exist. (1) No committed census: `ls docs/audits/` shows no repo_url census file; the only docs/audits file mentioning repo_url is docs/audits/cf090-ruff-format.txt (incidental). The only record of a guard run is the CF-091 board row (.coding-hermes/board/tasks.jsonl:78), which reports the opposite of the criterion — '383 rejected, 483 accepted', exit 2, with the duckbrain family at 7 rejected — and is a bug report, not a census. (2) No waivers: `grep -rn waiver docs/ tests/ scripts/` returns nothing; the only hit is the CF-091 board row's own acceptance-criteria text, so there is no committed waiver file with named owners and re-check dates. (3) No divergence selftest arm: tests/selftest.sh arm 19 (lines 567-583) only compares a single valid `local:` root against a single phantom root ('PASS repo_url guard rejects a phantom local: root (1 rejected, 1 accepted)'); tests/test_lane_target.py test_rows_stdin_and_file (line 279-292) asserts '1 rejected, 1 accepted' for a phantom row, and no test anywhere feeds two rows of one family on two different VALID git roots. scripts/lane_target.py repo_urls() (lines 378-428) has no family grouping or primary-vs-satellite value comparison, so it cannot fail on divergence. Test evidence: `bash tests/selftest.sh` → EXIT=0, tail 'SELFTEST: PASS' (arm 19 PASS), i.e. the suite is green but contains no arm covering the required condition. The last commit a2cc8b8 touched only .coding-hermes/board/{events,tasks}.jsonl (5 insertions), adding no census, waiver, or test.
The task only filed CF-091 as a pending board row; no committed census, no waivers with owners, and no divergence-detecting selftest arm exist, so the criterion is unmet.

Overall: FAIL ✗
