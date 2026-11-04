# Verdict: CF-071

**Task:** CF-071: public-bind auth gate must parse a non-empty dashboard.basic_auth, not grep for the substring
**Evaluated:** 2026-11-04T09:40:52.872824
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ 1. A config.yaml whose only basic_auth occurrence is a comment, or whose block has an empty username or password, is REFUSED with the same wording as an absent config and names the reason. 2. Positive control: a real non-empty basic_auth block proceeds to the launch path. 3. The decision reads a parsed value, never a bare grep -q, and still runs before any hermes serve invocation. 4. tests/selftest.sh covers commented, empty-value and real-value arms with named rows and prints SELFTEST: PASS.: Fresh run of `bash tests/selftest.sh` (guards.test_command) printed `SELFTEST: PASS` with 42 CF-071 rows all PASS. (1) scripts/harness/install-hermes.sh:177-186: absent block -> refuse("commented") when only a `# basic_auth:` comment exists, else refuse("block absent"); non-dict or empty/missing/non-string username|password -> refuse("empty value (username and password must both be non-empty)"); all reach the identical gateway_start refusal wording at :258. Selftest rows: `PASS CF-071 no-PyYAML commented: exit 1, launch=not reached`, `... empty-value: exit 1, launch=not reached`, `... empty-username/empty-password/missing-username/missing-password: exit 1, launch=not reached` (and same for `installed` mode). (2) Positive control: `PASS CF-071 no-PyYAML real-value: exit 1, launch=serve launch reached` and `PASS CF-071 installed real-value: exit 1, launch=serve launch reached`, with expected row `PASS gateway_start — /api/status -> 200`; plus red control `PASS CF-071 real-value red control: exit 1, launch reached, HTTP 503`. (3) check_public_bind_auth (install-hermes.sh:66-186) is a stdlib-only Python YAML-subset parser that builds a dict and tests `isinstance(auth.get(key), str) and auth[key].strip()`; the only `grep -q` uses in the file are the ss port probes (:209, :251) and the .env key check (:219) — no substring grep for basic_auth. It is invoked at :252 inside `if auth_reason=$(check_public_bind_auth); then` immediately before `nohup "$VENV/bin/hermes" serve --host 0.0.0.0 ...` at :253, so the gate runs before any serve invocation; the historical bypass is caught by `PASS CF-071 ... rejected grep-bypass mutation` (both modes). (4) tests/selftest.sh:326-505 `# BEGIN public-bind-auth` block defines named arms commented/empty-value/real-value (plus block-absent, wrong-key, empty-username, empty-password, missing-*, invalid-yaml, etc.), each emitting a named `PASS CF-071 <mode> <arm>: ...` row, and the suite ends with `SELFTEST: PASS`. Note: the script's shell exit code is 2 due to a trailing `/bin/sh: 1: Bad substitution` line printed after `SELFTEST: PASS` — a pre-existing harness artifact unrelated to CF-071 (all CF-071 rows and the final verdict line are PASS).


## Summary

Judge Result: CF-071

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ 1. A config.yaml whose only basic_auth occurrence is a comment, or whose block has an empty username or password, is REFUSED with the same wording as an absent config and names the reason. 2. Positive control: a real non-empty basic_auth block proceeds to the launch path. 3. The decision reads a parsed value, never a bare grep -q, and still runs before any hermes serve invocation. 4. tests/selftest.sh covers commented, empty-value and real-value arms with named rows and prints SELFTEST: PASS.: Fresh run of `bash tests/selftest.sh` (guards.test_command) printed `SELFTEST: PASS` with 42 CF-071 rows all PASS. (1) scripts/harness/install-hermes.sh:177-186: absent block -> refuse("commented") when only a `# basic_auth:` comment exists, else refuse("block absent"); non-dict or empty/missing/non-string username|password -> refuse("empty value (username and password must both be non-empty)"); all reach the identical gateway_start refusal wording at :258. Selftest rows: `PASS CF-071 no-PyYAML commented: exit 1, launch=not reached`, `... empty-value: exit 1, launch=not reached`, `... empty-username/empty-password/missing-username/missing-password: exit 1, launch=not reached` (and same for `installed` mode). (2) Positive control: `PASS CF-071 no-PyYAML real-value: exit 1, launch=serve launch reached` and `PASS CF-071 installed real-value: exit 1, launch=serve launch reached`, with expected row `PASS gateway_start — /api/status -> 200`; plus red control `PASS CF-071 real-value red control: exit 1, launch reached, HTTP 503`. (3) check_public_bind_auth (install-hermes.sh:66-186) is a stdlib-only Python YAML-subset parser that builds a dict and tests `isinstance(auth.get(key), str) and auth[key].strip()`; the only `grep -q` uses in the file are the ss port probes (:209, :251) and the .env key check (:219) — no substring grep for basic_auth. It is invoked at :252 inside `if auth_reason=$(check_public_bind_auth); then` immediately before `nohup "$VENV/bin/hermes" serve --host 0.0.0.0 ...` at :253, so the gate runs before any serve invocation; the historical bypass is caught by `PASS CF-071 ... rejected grep-bypass mutation` (both modes). (4) tests/selftest.sh:326-505 `# BEGIN public-bind-auth` block defines named arms commented/empty-value/real-value (plus block-absent, wrong-key, empty-username, empty-password, missing-*, invalid-yaml, etc.), each emitting a named `PASS CF-071 <mode> <arm>: ...` row, and the suite ends with `SELFTEST: PASS`. Note: the script's shell exit code is 2 due to a trailing `/bin/sh: 1: Bad substitution` line printed after `SELFTEST: PASS` — a pre-existing harness artifact unrelated to CF-071 (all CF-071 rows and the final verdict line are PASS).


Overall: PASS ✓
