# Verdict: CF-058

**Task:** README lanes section: replace the false disabled-duckbrain claim with a quoted, re-runnable census command and state the admission drift
**Evaluated:** 2026-11-03T12:43:14.243043
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ 1. The README paragraph about code-factory-duckbrain-* rows carries a copy-pasteable curl|jq command that prints enabled/admission/parent for the family and returns the live nineteen rows.: README.md:157-160 fenced bash block: `curl -s 'http://127.0.0.1:9090/api/v1/projects?limit=500' | jq -r '.projects[] | select(.name|startswith("code-factory")) | "\(.name) enabled=\(.enabled) admission=\(.admission_mode) parent=\(.parent // "-")"'`. Extracted lines 158-160 verbatim to /tmp/cmd4.sh and executed: exit_code 0, `wc -l` = 19 rows, every row enabled=true, each line printing name/enabled/admission/parent (e.g. `code-factory-duckbrain enabled=true admission=tasks parent=code-factory`). Matches README.md:163 'prints nineteen rows'. The old false claim ('The scheduler also carries disabled code-factory-duckbrain-* rows') is removed per git show HEAD.
  ✓ 2. The paragraph states that the admission column is the loader-written default and names the code-factory-duckbrain cooldown->tasks drift.: README.md:153-154: 'The table above is the family these two loaders configure, and its admission column is the value the loaders write at setup.' README.md:166-167: 'It also prints `code-factory-duckbrain admission=tasks` against the `cooldown` the loader writes — the drift the command exists to expose.' Drift confirmed against source: scripts/load_lane_config.py:26 sets "code-factory-duckbrain": ("duckbrain-sync", "cooldown", "duckbrain") while the live census prints admission=tasks.
  ✓ 3. bash tests/selftest.sh prints SELFTEST: PASS at the fixed tip.: Ran `bash tests/selftest.sh` at HEAD 557ac3f (working tree clean): exit_code 0, output line 45 = 'SELFTEST: PASS', 29 PASS lines and 0 FAIL lines; section 9 'every prompt file the README relies on exists' PASS.
The README lanes paragraph now carries a verbatim curl|jq census that re-runs live to exactly 19 enabled rows with enabled/admission/parent, states the admission column is the loader-written default and names the code-factory-duckbrain cooldown->tasks drift, and bash tests/selftest.sh exits 0 printing SELFTEST: PASS at the fixed tip.

## Summary

Judge Result: CF-058

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ 1. The README paragraph about code-factory-duckbrain-* rows carries a copy-pasteable curl|jq command that prints enabled/admission/parent for the family and returns the live nineteen rows.: README.md:157-160 fenced bash block: `curl -s 'http://127.0.0.1:9090/api/v1/projects?limit=500' | jq -r '.projects[] | select(.name|startswith("code-factory")) | "\(.name) enabled=\(.enabled) admission=\(.admission_mode) parent=\(.parent // "-")"'`. Extracted lines 158-160 verbatim to /tmp/cmd4.sh and executed: exit_code 0, `wc -l` = 19 rows, every row enabled=true, each line printing name/enabled/admission/parent (e.g. `code-factory-duckbrain enabled=true admission=tasks parent=code-factory`). Matches README.md:163 'prints nineteen rows'. The old false claim ('The scheduler also carries disabled code-factory-duckbrain-* rows') is removed per git show HEAD.
  ✓ 2. The paragraph states that the admission column is the loader-written default and names the code-factory-duckbrain cooldown->tasks drift.: README.md:153-154: 'The table above is the family these two loaders configure, and its admission column is the value the loaders write at setup.' README.md:166-167: 'It also prints `code-factory-duckbrain admission=tasks` against the `cooldown` the loader writes — the drift the command exists to expose.' Drift confirmed against source: scripts/load_lane_config.py:26 sets "code-factory-duckbrain": ("duckbrain-sync", "cooldown", "duckbrain") while the live census prints admission=tasks.
  ✓ 3. bash tests/selftest.sh prints SELFTEST: PASS at the fixed tip.: Ran `bash tests/selftest.sh` at HEAD 557ac3f (working tree clean): exit_code 0, output line 45 = 'SELFTEST: PASS', 29 PASS lines and 0 FAIL lines; section 9 'every prompt file the README relies on exists' PASS.
The README lanes paragraph now carries a verbatim curl|jq census that re-runs live to exactly 19 enabled rows with enabled/admission/parent, states the admission column is the loader-written default and names the code-factory-duckbrain cooldown->tasks drift, and bash tests/selftest.sh exits 0 printing SELFTEST: PASS at the fixed tip.

Overall: PASS ✓
