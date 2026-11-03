# Verdict: CF-041

**Task:** README quick-start audit: verify CF-041's three reported defects against origin/main
**Evaluated:** 2026-11-03T12:52:07.460427
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Verifies at commit 9880018 that CF-041's defects do not reproduce: README exports BUNKER_SERVER before quick-start step 1 and step 1 reaches a RESULT: FAIL (n) line with named values; README step 2 is './scripts/project-node.sh --check --project myproject' and yields checker output, never 'unknown arg'; README Layout names the shipped adapters exactly matching scripts/harness/ (hermes, claude-code, opencode) and points at specs/HARNESS.md for codex/aider/goose/pi-agent; docs/audits/code-factory-CF-041.md records each command with its literal exit code; bash tests/selftest.sh prints SELFTEST: PASS.: Verified against a clean `git archive 9880018` export in /tmp/cf041. (a) README §Quick start at 9880018 prints `export CRIER_URL=...` and `export BUNKER_SERVER=your-bunker-server` before step 1; running `scripts/bunker-server-install.sh --check` with those exports produced `RESULT: FAIL (2)` naming `bunker_config — missing (/tmp/cf041-home/.config/bunker/config.yaml)` and `server_reachable — your-bunker-server did not answer`, exit 1. (b) README step 2 is literally `./scripts/project-node.sh --check --project myproject`; running it produced full checker output ending `NODE: FAIL (3)`, exit 1, and `grep -c 'unknown arg'` = 0; `--agent` (never printed by README) gives `unknown arg: --agent`, exit 2 — matching the audit's claim. (c) README §Layout says `shipped: hermes, claude-code, opencode` and `codex, aider, goose and pi-agent are documented in specs/HARNESS.md`; `git ls-tree 9880018 scripts/harness/` returns exactly install-claude-code.sh, install-hermes.sh, install-opencode.sh, and specs/HARNESS.md mentions all four documented adapters. (d) docs/audits/code-factory-CF-041.md records every command with its literal exit code ("Exit code 1" for claims 1/2/3/4 and verify-node, "Exit code 2" for the --agent rejection, "Exit code 0" for selftest). (e) `bash tests/selftest.sh` at 9880018 printed `SELFTEST: PASS` (line 45 of output) with exit_code 0. Minor non-material inaccuracies: the audit's verify-node.sh --help snippet shows the unset-var abort (reproducible only with `env -u BUNKER_SERVER`, exit 1; with the var set it prints `unknown arg: --help`, exit 2), and its python3 path differs from this host — neither contradicts any required fact.
All five sub-claims of CF-041's audit reproduce exactly at commit 9880018: README exports BUNKER_SERVER before step 1 which reaches `RESULT: FAIL (2)` with named values, step 2 is the `--project myproject` form yielding checker output with no 'unknown arg', Layout's three shipped adapters match scripts/harness/ and point at specs/HARNESS.md for the other four, the audit records literal exit codes, and selftest prints SELFTEST: PASS (exit 0).

## Summary

Judge Result: CF-041

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Verifies at commit 9880018 that CF-041's defects do not reproduce: README exports BUNKER_SERVER before quick-start step 1 and step 1 reaches a RESULT: FAIL (n) line with named values; README step 2 is './scripts/project-node.sh --check --project myproject' and yields checker output, never 'unknown arg'; README Layout names the shipped adapters exactly matching scripts/harness/ (hermes, claude-code, opencode) and points at specs/HARNESS.md for codex/aider/goose/pi-agent; docs/audits/code-factory-CF-041.md records each command with its literal exit code; bash tests/selftest.sh prints SELFTEST: PASS.: Verified against a clean `git archive 9880018` export in /tmp/cf041. (a) README §Quick start at 9880018 prints `export CRIER_URL=...` and `export BUNKER_SERVER=your-bunker-server` before step 1; running `scripts/bunker-server-install.sh --check` with those exports produced `RESULT: FAIL (2)` naming `bunker_config — missing (/tmp/cf041-home/.config/bunker/config.yaml)` and `server_reachable — your-bunker-server did not answer`, exit 1. (b) README step 2 is literally `./scripts/project-node.sh --check --project myproject`; running it produced full checker output ending `NODE: FAIL (3)`, exit 1, and `grep -c 'unknown arg'` = 0; `--agent` (never printed by README) gives `unknown arg: --agent`, exit 2 — matching the audit's claim. (c) README §Layout says `shipped: hermes, claude-code, opencode` and `codex, aider, goose and pi-agent are documented in specs/HARNESS.md`; `git ls-tree 9880018 scripts/harness/` returns exactly install-claude-code.sh, install-hermes.sh, install-opencode.sh, and specs/HARNESS.md mentions all four documented adapters. (d) docs/audits/code-factory-CF-041.md records every command with its literal exit code ("Exit code 1" for claims 1/2/3/4 and verify-node, "Exit code 2" for the --agent rejection, "Exit code 0" for selftest). (e) `bash tests/selftest.sh` at 9880018 printed `SELFTEST: PASS` (line 45 of output) with exit_code 0. Minor non-material inaccuracies: the audit's verify-node.sh --help snippet shows the unset-var abort (reproducible only with `env -u BUNKER_SERVER`, exit 1; with the var set it prints `unknown arg: --help`, exit 2), and its python3 path differs from this host — neither contradicts any required fact.
All five sub-claims of CF-041's audit reproduce exactly at commit 9880018: README exports BUNKER_SERVER before step 1 which reaches `RESULT: FAIL (2)` with named values, step 2 is the `--project myproject` form yielding checker output with no 'unknown arg', Layout's three shipped adapters match scripts/harness/ and point at specs/HARNESS.md for the other four, the audit records literal exit codes, and selftest prints SELFTEST: PASS (exit 0).

Overall: PASS ✓
