# Verdict: CF-115-QA1

**Task:** QA filing check: CF-115 carries a re-runnable fail-open probe for the CF-099 drift probe
**Evaluated:** 2026-11-03T20:07:05.084951
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Filing only - do NOT evaluate or implement the underlying fix. At the pushed HEAD: (1) git show --stat HEAD names .coding-hermes/board/tasks.jsonl with insertions and zero deletions; (2) git show HEAD:.coding-hermes/board/tasks.jsonl piped to jq -e with filter select(.id=="CF-115") | .status=="pending" and (.probe|length>0) exits 0, and the probe value is a single line beginning with: d=$(mktemp -d) && git clone (3) that exact probe, run from the repository root, prints a measured line whose open_blockers= value is empty and then probe_rc=0 - the fail-open reproduction; (4) bash tests/selftest.sh prints SELFTEST: PASS and bash scripts/boardctl validate prints RESULT: OK at that HEAD.: Filing-only confirmed: HEAD=c534bae is pushed (git rev-parse @{u}==HEAD, rev-list --left-right --count @{u}...HEAD => '0 0', origin/main contains HEAD) and the diff touches only board files. (1) git show --numstat HEAD => '1\t0\t.coding-hermes/board/events.jsonl' and '1\t0\t.coding-hermes/board/tasks.jsonl' — 1 insertion, 0 deletions on tasks.jsonl (git show --stat: '2 files changed, 2 insertions(+)'). (2) git show HEAD:.coding-hermes/board/tasks.jsonl | jq -e 'select(.id=="CF-115") | .status=="pending" and (.probe|length>0)' printed 'true' with JQ_EXIT=0; probe value is strictly one line (wc -l=1, 364 bytes, python check newline_count=1, no_embedded_newline=True) and starts_ok=True for prefix 'd=$(mktemp -d) && git clone '. (3) Ran the exact probe from repo root: output line 1 = 'measured: tip=80fca8b rows=85 events=115 sections=28 open_blockers=' (matched regex ^measured: .*open_blockers=$ => OPEN_BLOCKERS_EMPTY_OK), followed by 'probe_rc=0' (PROBE_RC_0_OK), script exit=0 — the fail-open reproduction is live. Probe is non-destructive: git status --porcelain --untracked-files=no empty after the run. (4) bash tests/selftest.sh => SELFTEST_REAL_EXIT=0 and prints 'SELFTEST: PASS' (grep -c = 1); bash scripts/boardctl validate => VALIDATE_EXIT=0 with line 34 'RESULT: OK (30 warning(s))'. (An earlier exit_code=2 was my own ${PIPESTATUS[0]} expansion under sh, not the selftest.)
All four filing sub-criteria verified at pushed HEAD c534bae: board-only 1-insertion/0-deletion diff, jq -e exits 0 with a single-line mktemp/git-clone probe, that probe reproduces the fail-open (open_blockers= empty, probe_rc=0), and both SELFTEST: PASS and RESULT: OK print with exit 0.

## Summary

Judge Result: CF-115-QA1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Filing only - do NOT evaluate or implement the underlying fix. At the pushed HEAD: (1) git show --stat HEAD names .coding-hermes/board/tasks.jsonl with insertions and zero deletions; (2) git show HEAD:.coding-hermes/board/tasks.jsonl piped to jq -e with filter select(.id=="CF-115") | .status=="pending" and (.probe|length>0) exits 0, and the probe value is a single line beginning with: d=$(mktemp -d) && git clone (3) that exact probe, run from the repository root, prints a measured line whose open_blockers= value is empty and then probe_rc=0 - the fail-open reproduction; (4) bash tests/selftest.sh prints SELFTEST: PASS and bash scripts/boardctl validate prints RESULT: OK at that HEAD.: Filing-only confirmed: HEAD=c534bae is pushed (git rev-parse @{u}==HEAD, rev-list --left-right --count @{u}...HEAD => '0 0', origin/main contains HEAD) and the diff touches only board files. (1) git show --numstat HEAD => '1\t0\t.coding-hermes/board/events.jsonl' and '1\t0\t.coding-hermes/board/tasks.jsonl' — 1 insertion, 0 deletions on tasks.jsonl (git show --stat: '2 files changed, 2 insertions(+)'). (2) git show HEAD:.coding-hermes/board/tasks.jsonl | jq -e 'select(.id=="CF-115") | .status=="pending" and (.probe|length>0)' printed 'true' with JQ_EXIT=0; probe value is strictly one line (wc -l=1, 364 bytes, python check newline_count=1, no_embedded_newline=True) and starts_ok=True for prefix 'd=$(mktemp -d) && git clone '. (3) Ran the exact probe from repo root: output line 1 = 'measured: tip=80fca8b rows=85 events=115 sections=28 open_blockers=' (matched regex ^measured: .*open_blockers=$ => OPEN_BLOCKERS_EMPTY_OK), followed by 'probe_rc=0' (PROBE_RC_0_OK), script exit=0 — the fail-open reproduction is live. Probe is non-destructive: git status --porcelain --untracked-files=no empty after the run. (4) bash tests/selftest.sh => SELFTEST_REAL_EXIT=0 and prints 'SELFTEST: PASS' (grep -c = 1); bash scripts/boardctl validate => VALIDATE_EXIT=0 with line 34 'RESULT: OK (30 warning(s))'. (An earlier exit_code=2 was my own ${PIPESTATUS[0]} expansion under sh, not the selftest.)
All four filing sub-criteria verified at pushed HEAD c534bae: board-only 1-insertion/0-deletion diff, jq -e exits 0 with a single-line mktemp/git-clone probe, that probe reproduces the fail-open (open_blockers= empty, probe_rc=0), and both SELFTEST: PASS and RESULT: OK print with exit 0.

Overall: PASS ✓
