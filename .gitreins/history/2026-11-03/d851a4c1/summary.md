# Verdict: CF-054

**Task:** README status re-run line must carry the node check's exit status
**Evaluated:** 2026-11-03T13:04:52.491167
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ 1. The command span in README's status table, run in env -i with a temp HOME, exits nonzero when the node check fails (probe in tests/selftest.sh shows rc!=0 red and rc=0 green). 2. The line carries the CRIER_URL export it needs on its own line and no trailing read-back. 3. bash tests/selftest.sh prints SELFTEST: PASS at the fixed tip.: (1) Independently reproduced the documented line shape in `env -i` with a temp HOME: red fixture (no ~/.node/crier.json) -> LINE_RC=1 with `NODE: FAIL (1)` while the clone still succeeded (`PASS repo_clone @ 19f0dc3`) and a separate `git -C "$h/repo" rev-parse HEAD` returned READBACK_RC=0, proving the old read-back masked the failure; green fixture (600 crier.json staged) -> GREEN_LINE_RC=0 with `NODE: PASS`. scripts/project-node.sh:197 makes the check's status the line's status (`NODE: PASS; exit 0` / `NODE: FAIL ($FAILED); exit 1`). tests/selftest.sh:355-380 asserts old shape rc=0 on NODE: FAIL, documented shape rc=1 red, rc=0 green — all four section-15 PASS lines observed. (2) README.md:74 command span is `home=$(mktemp -d); CRIER_URL=http://crier.example:8767 HOME="$home" ./scripts/project-node.sh --apply --project myproject --repo https://github.com/github/gitignore --ref main` — carries CRIER_URL= inline, ends with the node check, no `rev-parse` read-back (read-back is a separate span); tests/selftest.sh:322-329 binds exactly this and PASSed. (3) `bash tests/selftest.sh` exit_code=0, tail: `SELFTEST: PASS` (section 15: `PASS documented line carries CRIER_URL= and no trailing read-back`, `PASS old shape exits 0 on a failed check (NODE: FAIL (1))`, `PASS documented shape exits 1 on a failed check (NODE: FAIL (1))`, `PASS documented shape exits 0 on a passing fixture (NODE: PASS)`).
README.md:74 now carries CRIER_URL inline and ends with the node check, verified by an independent env -i reproduction (rc=1 red / rc=0 green) and a green `bash tests/selftest.sh` printing SELFTEST: PASS.

## Summary

Judge Result: CF-054

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ 1. The command span in README's status table, run in env -i with a temp HOME, exits nonzero when the node check fails (probe in tests/selftest.sh shows rc!=0 red and rc=0 green). 2. The line carries the CRIER_URL export it needs on its own line and no trailing read-back. 3. bash tests/selftest.sh prints SELFTEST: PASS at the fixed tip.: (1) Independently reproduced the documented line shape in `env -i` with a temp HOME: red fixture (no ~/.node/crier.json) -> LINE_RC=1 with `NODE: FAIL (1)` while the clone still succeeded (`PASS repo_clone @ 19f0dc3`) and a separate `git -C "$h/repo" rev-parse HEAD` returned READBACK_RC=0, proving the old read-back masked the failure; green fixture (600 crier.json staged) -> GREEN_LINE_RC=0 with `NODE: PASS`. scripts/project-node.sh:197 makes the check's status the line's status (`NODE: PASS; exit 0` / `NODE: FAIL ($FAILED); exit 1`). tests/selftest.sh:355-380 asserts old shape rc=0 on NODE: FAIL, documented shape rc=1 red, rc=0 green — all four section-15 PASS lines observed. (2) README.md:74 command span is `home=$(mktemp -d); CRIER_URL=http://crier.example:8767 HOME="$home" ./scripts/project-node.sh --apply --project myproject --repo https://github.com/github/gitignore --ref main` — carries CRIER_URL= inline, ends with the node check, no `rev-parse` read-back (read-back is a separate span); tests/selftest.sh:322-329 binds exactly this and PASSed. (3) `bash tests/selftest.sh` exit_code=0, tail: `SELFTEST: PASS` (section 15: `PASS documented line carries CRIER_URL= and no trailing read-back`, `PASS old shape exits 0 on a failed check (NODE: FAIL (1))`, `PASS documented shape exits 1 on a failed check (NODE: FAIL (1))`, `PASS documented shape exits 0 on a passing fixture (NODE: PASS)`).
README.md:74 now carries CRIER_URL inline and ends with the node check, verified by an independent env -i reproduction (rc=1 red / rc=0 green) and a green `bash tests/selftest.sh` printing SELFTEST: PASS.

Overall: PASS ✓
