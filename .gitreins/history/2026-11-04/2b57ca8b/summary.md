# Verdict: CF-143-DUCK2

**Task:** CF-143 filing verification (narrow)
**Evaluated:** 2026-11-04T02:17:44.543430
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Filing verified. (1) Run: jq -r 'select(.id=="CF-143").probe' .coding-hermes/board/tasks.jsonl | bash -> prints exactly one line: df0c8fc: 36 35 .coding-hermes/board/events.jsonl. (2) bash tests/selftest.sh -> SELFTEST: PASS. (3) git rev-parse HEAD equals git rev-parse origin/main and tracked porcelain is empty. Scope: the FILING only; CF-143 is pending, do not grade its fix.: (1) Probe command exit_code 0, output exactly one line (verified via `| wc -l` = 1): 'df0c8fc: 36\t35\t.coding-hermes/board/events.jsonl' — matches the required line. Probe is a real detector, not a hardcoded echo: `git log --format='commit %h' --numstat -- .coding-hermes/board/events.jsonl | awk '/^commit /{c=$2; next} NF==3 && $2+0>0 {print c": "$0}'`; independently corroborated by `git show --numstat df0c8fc -- .coding-hermes/board/events.jsonl` -> '36\t35\t.coding-hermes/board/events.jsonl'. (2) `bash tests/selftest.sh` exit_code 0, final line 'SELFTEST: PASS' (arms 25-29 all PASS incl. publish-drift fixtures). (3) `git rev-parse HEAD` = 4b24e8412a31d1014b46a8266dce40a16134fff4 and `git rev-parse origin/main` = 4b24e8412a31d1014b46a8266dce40a16134fff4 (equal); `git status --porcelain --untracked-files=no` returned empty. Scope respected: CF-143 status is 'pending' (fix not graded) and HEAD 4b24e84 touches only .coding-hermes/board/events.jsonl (+2) and .coding-hermes/board/tasks.jsonl (+1) — filing only.
All three filing checks pass with fresh command output: the probe prints exactly the required single line, selftest prints SELFTEST: PASS at exit 0, and HEAD matches origin/main with empty tracked porcelain.

## Summary

Judge Result: CF-143-DUCK2

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Filing verified. (1) Run: jq -r 'select(.id=="CF-143").probe' .coding-hermes/board/tasks.jsonl | bash -> prints exactly one line: df0c8fc: 36 35 .coding-hermes/board/events.jsonl. (2) bash tests/selftest.sh -> SELFTEST: PASS. (3) git rev-parse HEAD equals git rev-parse origin/main and tracked porcelain is empty. Scope: the FILING only; CF-143 is pending, do not grade its fix.: (1) Probe command exit_code 0, output exactly one line (verified via `| wc -l` = 1): 'df0c8fc: 36\t35\t.coding-hermes/board/events.jsonl' — matches the required line. Probe is a real detector, not a hardcoded echo: `git log --format='commit %h' --numstat -- .coding-hermes/board/events.jsonl | awk '/^commit /{c=$2; next} NF==3 && $2+0>0 {print c": "$0}'`; independently corroborated by `git show --numstat df0c8fc -- .coding-hermes/board/events.jsonl` -> '36\t35\t.coding-hermes/board/events.jsonl'. (2) `bash tests/selftest.sh` exit_code 0, final line 'SELFTEST: PASS' (arms 25-29 all PASS incl. publish-drift fixtures). (3) `git rev-parse HEAD` = 4b24e8412a31d1014b46a8266dce40a16134fff4 and `git rev-parse origin/main` = 4b24e8412a31d1014b46a8266dce40a16134fff4 (equal); `git status --porcelain --untracked-files=no` returned empty. Scope respected: CF-143 status is 'pending' (fix not graded) and HEAD 4b24e84 touches only .coding-hermes/board/events.jsonl (+2) and .coding-hermes/board/tasks.jsonl (+1) — filing only.
All three filing checks pass with fresh command output: the probe prints exactly the required single line, selftest prints SELFTEST: PASS at exit 0, and HEAD matches origin/main with empty tracked porcelain.

Overall: PASS ✓
