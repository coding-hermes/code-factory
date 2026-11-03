# Verdict: CF-041

**Task:** README quick-start audit: verify CF-041's three reported defects against origin/main
**Evaluated:** 2026-11-03T12:53:27.031742
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Verifies at commit 9880018 that CF-041's defects do not reproduce: README exports BUNKER_SERVER before quick-start step 1 and step 1 reaches a RESULT: FAIL (n) line with named values; README step 2 is './scripts/project-node.sh --check --project myproject' and yields checker output, never 'unknown arg'; README Layout names the shipped adapters exactly matching scripts/harness/ (hermes, claude-code, opencode) and points at specs/HARNESS.md for codex/aider/goose/pi-agent; docs/audits/code-factory-CF-041.md records each command with its literal exit code; bash tests/selftest.sh prints SELFTEST: PASS.: All five sub-claims independently reproduced at the exported tree 9880018 (git archive 9880018 -> /tmp/cf041). (a) `git show 9880018:README.md` lines 18-23: `export BUNKER_SERVER=your-bunker-server` precedes step 1 `scripts/bunker-server-install.sh --check`; running it with the exports printed `RESULT: FAIL (2)` with named values (`FAIL server_declared — your-bunker-server not found in ...`, `FAIL server_reachable — your-bunker-server did not answer`), exit 1 — matching audit lines 30-46. (b) README line 26 is exactly `./scripts/project-node.sh --check --project myproject`; running it produced full checker output (`[00] preflight` ... `NODE: FAIL (3)`), exit 1, no 'unknown arg'; the `--agent` probe separately gave `unknown arg: --agent`, exit 2 (audit lines 85-92). (c) `git ls-tree 9880018 scripts/harness/` = install-claude-code.sh, install-hermes.sh, install-opencode.sh (exactly three); README lines 43-45 name shipped: hermes, claude-code, opencode and point codex/aider/goose/pi-agent at specs/HARNESS.md, which mentions all four at lines 23-26. (d) docs/audits/code-factory-CF-041.md records literal exit codes at lines 46, 55, 85, 92, 115, 129, 148 ('Exit code 1', 'Exit code 2', 'Exit code 0', 'Exit codes 1, 2 and 2'), and its verify-node section matches measurement (env set `--help` -> 'unknown arg: --help' exit 2; env unset -> line 17 abort exit 1; no args -> usage exit 2). (e) `bash tests/selftest.sh` at 9880018: exit_code 0, final line `SELFTEST: PASS`; same at HEAD (exit_code 0, `SELFTEST: PASS`).


## Summary

Judge Result: CF-041

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Verifies at commit 9880018 that CF-041's defects do not reproduce: README exports BUNKER_SERVER before quick-start step 1 and step 1 reaches a RESULT: FAIL (n) line with named values; README step 2 is './scripts/project-node.sh --check --project myproject' and yields checker output, never 'unknown arg'; README Layout names the shipped adapters exactly matching scripts/harness/ (hermes, claude-code, opencode) and points at specs/HARNESS.md for codex/aider/goose/pi-agent; docs/audits/code-factory-CF-041.md records each command with its literal exit code; bash tests/selftest.sh prints SELFTEST: PASS.: All five sub-claims independently reproduced at the exported tree 9880018 (git archive 9880018 -> /tmp/cf041). (a) `git show 9880018:README.md` lines 18-23: `export BUNKER_SERVER=your-bunker-server` precedes step 1 `scripts/bunker-server-install.sh --check`; running it with the exports printed `RESULT: FAIL (2)` with named values (`FAIL server_declared — your-bunker-server not found in ...`, `FAIL server_reachable — your-bunker-server did not answer`), exit 1 — matching audit lines 30-46. (b) README line 26 is exactly `./scripts/project-node.sh --check --project myproject`; running it produced full checker output (`[00] preflight` ... `NODE: FAIL (3)`), exit 1, no 'unknown arg'; the `--agent` probe separately gave `unknown arg: --agent`, exit 2 (audit lines 85-92). (c) `git ls-tree 9880018 scripts/harness/` = install-claude-code.sh, install-hermes.sh, install-opencode.sh (exactly three); README lines 43-45 name shipped: hermes, claude-code, opencode and point codex/aider/goose/pi-agent at specs/HARNESS.md, which mentions all four at lines 23-26. (d) docs/audits/code-factory-CF-041.md records literal exit codes at lines 46, 55, 85, 92, 115, 129, 148 ('Exit code 1', 'Exit code 2', 'Exit code 0', 'Exit codes 1, 2 and 2'), and its verify-node section matches measurement (env set `--help` -> 'unknown arg: --help' exit 2; env unset -> line 17 abort exit 1; no args -> usage exit 2). (e) `bash tests/selftest.sh` at 9880018: exit_code 0, final line `SELFTEST: PASS`; same at HEAD (exit_code 0, `SELFTEST: PASS`).


Overall: PASS ✓
