# Verdict: CF-230

**Task:** Harness selection is data-driven (specs/HARNESS-MATRIX.md 4/6): scripts/harness_resolve.py resolves directive > lane > matrix > hermes, refuses foreman lanes off hermes and uninstalled harnesses with named failures, records harness_selected/harness_reason/model_requested
**Evaluated:** 2026-11-05T22:57:22.037332
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ python3 -B tests/test_harness_resolve.py exits 0; python3 scripts/harness_resolve.py --explain claude-sonnet-4 prints harness_selected=claude-code and harness_reason=matrix and exits 0; python3 scripts/harness_resolve.py --explain gpt-5 --lane code-factory exits nonzero and prints harness_foreman_requires_hermes; python3 scripts/harness_resolve.py --explain claude-sonnet-4 --node-harnesses hermes exits nonzero and prints 'harness_unsupported: claude-code'; bash tests/selftest.sh exits 0 with SELFTEST: PASS: All five legs verified with fresh command output. (1) `python3 -B tests/test_harness_resolve.py` -> 'Ran 28 tests in 0.883s / OK', EXIT=0. (2) `--explain claude-sonnet-4` -> 'PASS harness_selected=claude-code harness_reason=matrix model_requested=claude-sonnet-4 provider_family=claude model_served=<null-until-a-run> provider_binding=native', EXIT=0. (3) `--explain gpt-5 --lane code-factory` -> 'FAIL harness_foreman_requires_hermes: lane=code-factory harness=codex', EXIT=2 (nonzero). (4) `--explain claude-sonnet-4 --node-harnesses hermes` -> 'FAIL harness_unsupported: claude-code; node has: hermes', EXIT=2 (nonzero). (5) `bash tests/selftest.sh` -> line 163 'PASS  CF-230 harness resolution: directive > lane > matrix > hermes, every reason recorded', line 459 'SELFTEST: PASS', EXITCODE=0. Code corroboration: scripts/harness_resolve.py:230-232 select() implements directive>lane>matrix>fallback; :272/:278 raise harness_unsupported; :284 raises harness_foreman_requires_hermes; :296-299 records harness_selected/harness_reason/model_requested; config/harness-matrix.json supplies the data (default hermes, by_family claude->claude-code, openai->codex); tests/selftest.sh:522 wires the test into section 12. Precedence also spot-checked: `--lane-harness hermes` yields harness_reason=lane, confirming lane beats matrix.
All five required command legs pass with fresh output (28/28 unit tests OK, matrix resolution to claude-code, both named refusals exiting 2, and selftest SELFTEST: PASS with exit 0).

## Summary

Judge Result: CF-230

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ python3 -B tests/test_harness_resolve.py exits 0; python3 scripts/harness_resolve.py --explain claude-sonnet-4 prints harness_selected=claude-code and harness_reason=matrix and exits 0; python3 scripts/harness_resolve.py --explain gpt-5 --lane code-factory exits nonzero and prints harness_foreman_requires_hermes; python3 scripts/harness_resolve.py --explain claude-sonnet-4 --node-harnesses hermes exits nonzero and prints 'harness_unsupported: claude-code'; bash tests/selftest.sh exits 0 with SELFTEST: PASS: All five legs verified with fresh command output. (1) `python3 -B tests/test_harness_resolve.py` -> 'Ran 28 tests in 0.883s / OK', EXIT=0. (2) `--explain claude-sonnet-4` -> 'PASS harness_selected=claude-code harness_reason=matrix model_requested=claude-sonnet-4 provider_family=claude model_served=<null-until-a-run> provider_binding=native', EXIT=0. (3) `--explain gpt-5 --lane code-factory` -> 'FAIL harness_foreman_requires_hermes: lane=code-factory harness=codex', EXIT=2 (nonzero). (4) `--explain claude-sonnet-4 --node-harnesses hermes` -> 'FAIL harness_unsupported: claude-code; node has: hermes', EXIT=2 (nonzero). (5) `bash tests/selftest.sh` -> line 163 'PASS  CF-230 harness resolution: directive > lane > matrix > hermes, every reason recorded', line 459 'SELFTEST: PASS', EXITCODE=0. Code corroboration: scripts/harness_resolve.py:230-232 select() implements directive>lane>matrix>fallback; :272/:278 raise harness_unsupported; :284 raises harness_foreman_requires_hermes; :296-299 records harness_selected/harness_reason/model_requested; config/harness-matrix.json supplies the data (default hermes, by_family claude->claude-code, openai->codex); tests/selftest.sh:522 wires the test into section 12. Precedence also spot-checked: `--lane-harness hermes` yields harness_reason=lane, confirming lane beats matrix.
All five required command legs pass with fresh output (28/28 unit tests OK, matrix resolution to claude-code, both named refusals exiting 2, and selftest SELFTEST: PASS with exit 0).

Overall: PASS ✓
