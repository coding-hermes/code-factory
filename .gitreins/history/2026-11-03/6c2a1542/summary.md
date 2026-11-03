# Verdict: CF-092

**Task:** README Status row 1: name the interpreter-qualified --check command and stop claiming binary/port gates for the unqualified one
**Evaluated:** 2026-11-03T17:32:35.931957
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ README Status row 1 re-run cell names either the interpreter-qualified command (HERMES_PYTHON_BIN=python3.12) or states the interpreter precondition in that same cell, matching row 3's form; the state cell no longer claims binary and port gates for a command that stops at FAIL python; docs/audits/cf092-install-check-arms.txt shows both arms with gate-row counts 1 vs 4, binary/port row counts 0/1, and both exit codes; bash tests/selftest.sh prints SELFTEST: PASS at the fixed tip.: README.md:73 re-run cell now reads "Re-run the current local check with an interpreter inside the pin's range — `HERMES_PYTHON_BIN=python3.12 scripts/harness/install-hermes.sh --check` — which prints four gate rows (python, binary, port, `inference_key`). The unqualified `scripts/harness/install-hermes.sh --check` is the same command on the default `python3`, and there it prints one row: `FAIL python`." — same form as row 3 (README.md:75). State cell (README.md:73) no longer claims binary/port gates for the unqualified command: "On this host's default `python3` (3.14) that command prints exactly one gate row — `FAIL python` — and never reaches the binary or port arms; the binary, port and `inference_key` rows print only on an interpreter inside the pin's range (`HERMES_PYTHON_BIN=python3.12` prints four)." docs/audits/cf092-install-check-arms.txt: arm 1 "gate rows printed: 1 / gate rows naming binary: 0 / gate rows naming port: 0 / EXIT: 1"; arm 2 "gate rows printed: 4 / gate rows naming binary: 1 / gate rows naming port: 1 / EXIT: 1" — both arms, 1 vs 4, 0/1, both exit codes. Re-ran `bash docs/audits/cf092-arms.sh /tmp/cf092-regen.txt` (exit 0) and diffed against the committed transcript: identical (TRANSCRIPT_MATCHES). `bash tests/selftest.sh` at HEAD 1f980873a316672fd075e632843954876e66b769: exit_code=0, output line 80 "SELFTEST: PASS".
README Status row 1 now names the interpreter-qualified --check command matching row 3's form, the state cell states the measured 1-vs-4 gate-row split instead of claiming binary/port gates for the unqualified command, the committed transcript reproduces exactly with 1/4 gate rows, 0/1 binary and port rows and both exit codes, and bash tests/selftest.sh prints SELFTEST: PASS (exit 0) at the fixed tip.

## Summary

Judge Result: CF-092

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ README Status row 1 re-run cell names either the interpreter-qualified command (HERMES_PYTHON_BIN=python3.12) or states the interpreter precondition in that same cell, matching row 3's form; the state cell no longer claims binary and port gates for a command that stops at FAIL python; docs/audits/cf092-install-check-arms.txt shows both arms with gate-row counts 1 vs 4, binary/port row counts 0/1, and both exit codes; bash tests/selftest.sh prints SELFTEST: PASS at the fixed tip.: README.md:73 re-run cell now reads "Re-run the current local check with an interpreter inside the pin's range — `HERMES_PYTHON_BIN=python3.12 scripts/harness/install-hermes.sh --check` — which prints four gate rows (python, binary, port, `inference_key`). The unqualified `scripts/harness/install-hermes.sh --check` is the same command on the default `python3`, and there it prints one row: `FAIL python`." — same form as row 3 (README.md:75). State cell (README.md:73) no longer claims binary/port gates for the unqualified command: "On this host's default `python3` (3.14) that command prints exactly one gate row — `FAIL python` — and never reaches the binary or port arms; the binary, port and `inference_key` rows print only on an interpreter inside the pin's range (`HERMES_PYTHON_BIN=python3.12` prints four)." docs/audits/cf092-install-check-arms.txt: arm 1 "gate rows printed: 1 / gate rows naming binary: 0 / gate rows naming port: 0 / EXIT: 1"; arm 2 "gate rows printed: 4 / gate rows naming binary: 1 / gate rows naming port: 1 / EXIT: 1" — both arms, 1 vs 4, 0/1, both exit codes. Re-ran `bash docs/audits/cf092-arms.sh /tmp/cf092-regen.txt` (exit 0) and diffed against the committed transcript: identical (TRANSCRIPT_MATCHES). `bash tests/selftest.sh` at HEAD 1f980873a316672fd075e632843954876e66b769: exit_code=0, output line 80 "SELFTEST: PASS".
README Status row 1 now names the interpreter-qualified --check command matching row 3's form, the state cell states the measured 1-vs-4 gate-row split instead of claiming binary/port gates for the unqualified command, the committed transcript reproduces exactly with 1/4 gate rows, 0/1 binary and port rows and both exit codes, and bash tests/selftest.sh prints SELFTEST: PASS (exit 0) at the fixed tip.

Overall: PASS ✓
