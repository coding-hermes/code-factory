# Verdict: CF-127

**Task:** Hermes install logs are per-run under HOME, not a shared /tmp file
**Evaluated:** 2026-11-04T03:11:19.087810
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ install-hermes.sh writes its pip log under the node HOME with mode 600 via mktemp; a pre-existing unwritable /tmp/hermes-install.log no longer affects the install; a genuine pip failure reports pip's exit status and the log actually written; install-hermes.sh --check writes no log; tests/selftest.sh carries the arm (§31) that reds on the old shape and greens on the new one; bash tests/selftest.sh prints SELFTEST: PASS and scripts/boardctl validate prints RESULT: OK: scripts/harness/install-hermes.sh:83-96: log_template="$HOME/.hermes-install-$PORT.XXXXXXXX.log"; `if pip_log=$(umask 077; mktemp "$log_template" 2>&1)` (mode 600, per-run under HOME, no /tmp/hermes-install.log reference anywhere in the file); creation failure -> `bad "install_log" "cannot create $log_template — $pip_log"`; genuine pip failure -> `bad "install" "pip exited $rc — log: $pip_log"` (reports pip's exit status and the actual log path). Log creation lives only inside `if [ "$MODE" = "--apply" ]` (line 81), so --check writes no log. tests/selftest.sh:1082-1215 carries §31 'pip-log-path' with 7 arms: old-shape red fixture (permission denied on the fixed file, exact misleading row, pip not invoked), --check no-log/no-pip, two new-shape runs (distinct HOME logs, `stat -c %a` = 600, fixed file untouched), mktemp-denied creation-failure row, successful install despite unwritable fixed file, and installed --check unchanged. Test run: `bash tests/selftest.sh` -> EXIT=0, output '31. Hermes pip logs are private per run and distinguish filesystem failures (CF-127)' with all 7 arms PASS and final line 'SELFTEST: PASS'. `bash scripts/boardctl validate` -> EXIT=0, 'RESULT: OK (3 warning(s))' (warnings are pre-existing free-form CF-034 rows, not failures).
Per-run HOME pip log via umask 077 mktemp with mode 600, accurate pip-exit reporting, no log on --check, and a §31 selftest arm that reds on the old shape and greens on the new — verified by a green selftest and boardctl validate.

## Summary

Judge Result: CF-127

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ install-hermes.sh writes its pip log under the node HOME with mode 600 via mktemp; a pre-existing unwritable /tmp/hermes-install.log no longer affects the install; a genuine pip failure reports pip's exit status and the log actually written; install-hermes.sh --check writes no log; tests/selftest.sh carries the arm (§31) that reds on the old shape and greens on the new one; bash tests/selftest.sh prints SELFTEST: PASS and scripts/boardctl validate prints RESULT: OK: scripts/harness/install-hermes.sh:83-96: log_template="$HOME/.hermes-install-$PORT.XXXXXXXX.log"; `if pip_log=$(umask 077; mktemp "$log_template" 2>&1)` (mode 600, per-run under HOME, no /tmp/hermes-install.log reference anywhere in the file); creation failure -> `bad "install_log" "cannot create $log_template — $pip_log"`; genuine pip failure -> `bad "install" "pip exited $rc — log: $pip_log"` (reports pip's exit status and the actual log path). Log creation lives only inside `if [ "$MODE" = "--apply" ]` (line 81), so --check writes no log. tests/selftest.sh:1082-1215 carries §31 'pip-log-path' with 7 arms: old-shape red fixture (permission denied on the fixed file, exact misleading row, pip not invoked), --check no-log/no-pip, two new-shape runs (distinct HOME logs, `stat -c %a` = 600, fixed file untouched), mktemp-denied creation-failure row, successful install despite unwritable fixed file, and installed --check unchanged. Test run: `bash tests/selftest.sh` -> EXIT=0, output '31. Hermes pip logs are private per run and distinguish filesystem failures (CF-127)' with all 7 arms PASS and final line 'SELFTEST: PASS'. `bash scripts/boardctl validate` -> EXIT=0, 'RESULT: OK (3 warning(s))' (warnings are pre-existing free-form CF-034 rows, not failures).
Per-run HOME pip log via umask 077 mktemp with mode 600, accurate pip-exit reporting, no log on --check, and a §31 selftest arm that reds on the old shape and greens on the new — verified by a green selftest and boardctl validate.

Overall: PASS ✓
