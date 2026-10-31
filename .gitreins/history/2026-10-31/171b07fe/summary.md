# Verdict: CF-013

**Task:** Make README works evidence rerunnable
**Evaluated:** 2026-10-31T12:39:12.533641
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: harness state excluded from gitleaks scope (.gitreins/**)
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ 1. Each works row in README status table has a pointer to a rerunnable command or stored artifact. 2. Following each pointer reproduces or re-derives the claimed figure, or the row states when and where it was measured. 3. bash tests/selftest.sh exits 0 and prints SELFTEST: PASS.: PASS: README.md:73-79 status table. Row1 (Hermes) -> `scripts/harness/install-hermes.sh --check` (ran: exit 1, prints PASS binary/version, FAIL port, PASS inference_key) + committed artifacts specs/HARNESS.md:16-24 and docs/audits/code-factory-readme-2026-10-30-20-29-25.md#2. Row2 (repo clone) -> rerunnable command with mktemp HOME + gitignore fixture + rev-parse readback (ran: PASS repo_clone @ 6bb5af7, readback 6bb5af7a1b05...). Rows 3-6 (missing/disarmed/not yet) each name a command or explicitly state no command exists.
Partial verdict — all verified criteria passed

## Summary

Judge Result: CF-013

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: harness state excluded from gitleaks scope (.gitreins/**)
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ 1. Each works row in README status table has a pointer to a rerunnable command or stored artifact. 2. Following each pointer reproduces or re-derives the claimed figure, or the row states when and where it was measured. 3. bash tests/selftest.sh exits 0 and prints SELFTEST: PASS.: PASS: README.md:73-79 status table. Row1 (Hermes) -> `scripts/harness/install-hermes.sh --check` (ran: exit 1, prints PASS binary/version, FAIL port, PASS inference_key) + committed artifacts specs/HARNESS.md:16-24 and docs/audits/code-factory-readme-2026-10-30-20-29-25.md#2. Row2 (repo clone) -> rerunnable command with mktemp HOME + gitignore fixture + rev-parse readback (ran: PASS repo_clone @ 6bb5af7, readback 6bb5af7a1b05...). Rows 3-6 (missing/disarmed/not yet) each name a command or explicitly state no command exists.
Partial verdict — all verified criteria passed

Overall: PASS ✓
