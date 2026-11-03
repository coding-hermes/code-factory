# Verdict: CF-064

**Task:** README status table states the interpreter precondition its inference_key command needs
**Evaluated:** 2026-11-03T16:56:31.919138
**Result:** ✗ FAIL

## Pipeline Stages

- ✗ **tier1**
  -   ✗ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Both arms are transcripted in docs/audits/code-factory-CF-064.probe.txt: the default python3 (3.14) stops at FAIL python with 0 rows naming inference_key, and HERMES_PYTHON_BIN=python3.12 prints FAIL inference_key; README status rows 1 and 3 state that precondition in the same cell as the command; bash tests/selftest.sh prints SELFTEST: PASS.: docs/audits/code-factory-CF-064.probe.txt contains arm 1 (`env -i HOME=... scripts/harness/install-hermes.sh --check` -> `FAIL  python — hermes-agent 0.19.0 requires python >=3.11,<3.14; found 3.14.4`, `EXIT: 1`, `rows naming inference_key: 0`) and arm 2 (`HERMES_PYTHON_BIN=python3.12 ... install-hermes.sh --check` -> `PASS  python — 3.12.13`, `FAIL  inference_key — no provider key ...`, `rows naming inference_key: 1`). Reproduced live: arm 1 exit 1 with only the FAIL python row; arm 2 exit 1 with `FAIL  inference_key`. README.md:74 (row 1, Hermes in a bunker) command cell states 'Its `inference_key` row is reachable only once the interpreter is inside the pin's range: the default `python3` here is 3.14, so the same command stops at `FAIL python` first (CF-064; both arms in `docs/audits/code-factory-CF-064.probe.txt`)'; README.md:75 (row 3, Node inference credential) command cell states 'That row prints only on an interpreter inside the pin's range; the default `python3` here is 3.14 and stops at `FAIL python` first, so name one explicitly: `HERMES_PYTHON_BIN=python3.12 scripts/harness/install-hermes.sh --check` -> `FAIL inference_key`'. `bash tests/selftest.sh` output tail: `SELFTEST: PASS`, exit_code 0.
Probe transcript records both interpreter arms, README status rows 1 and 3 state the python-range precondition in the command cell, and the selftest prints SELFTEST: PASS (exit 0).

## Summary

Judge Result: CF-064

Stage tier1: FAIL
    ✗ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Both arms are transcripted in docs/audits/code-factory-CF-064.probe.txt: the default python3 (3.14) stops at FAIL python with 0 rows naming inference_key, and HERMES_PYTHON_BIN=python3.12 prints FAIL inference_key; README status rows 1 and 3 state that precondition in the same cell as the command; bash tests/selftest.sh prints SELFTEST: PASS.: docs/audits/code-factory-CF-064.probe.txt contains arm 1 (`env -i HOME=... scripts/harness/install-hermes.sh --check` -> `FAIL  python — hermes-agent 0.19.0 requires python >=3.11,<3.14; found 3.14.4`, `EXIT: 1`, `rows naming inference_key: 0`) and arm 2 (`HERMES_PYTHON_BIN=python3.12 ... install-hermes.sh --check` -> `PASS  python — 3.12.13`, `FAIL  inference_key — no provider key ...`, `rows naming inference_key: 1`). Reproduced live: arm 1 exit 1 with only the FAIL python row; arm 2 exit 1 with `FAIL  inference_key`. README.md:74 (row 1, Hermes in a bunker) command cell states 'Its `inference_key` row is reachable only once the interpreter is inside the pin's range: the default `python3` here is 3.14, so the same command stops at `FAIL python` first (CF-064; both arms in `docs/audits/code-factory-CF-064.probe.txt`)'; README.md:75 (row 3, Node inference credential) command cell states 'That row prints only on an interpreter inside the pin's range; the default `python3` here is 3.14 and stops at `FAIL python` first, so name one explicitly: `HERMES_PYTHON_BIN=python3.12 scripts/harness/install-hermes.sh --check` -> `FAIL inference_key`'. `bash tests/selftest.sh` output tail: `SELFTEST: PASS`, exit_code 0.
Probe transcript records both interpreter arms, README status rows 1 and 3 state the python-range precondition in the command cell, and the selftest prints SELFTEST: PASS (exit 0).

Overall: FAIL ✗
