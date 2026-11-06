# Verdict: CF-372

**Task:** install-deepseek.sh and install-pi-agent.sh: contract-conforming adapters
**Evaluated:** 2026-11-06T01:02:58.076131
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ After the commit: scripts/harness/install-deepseek.sh and scripts/harness/install-pi-agent.sh exist, source harness-vars.sh, and document every §5 CF_* name in --help; tests/harness/vars-contract-test.sh covers six installers and reports zero FAIL rows; tests/harness-conformance.sh --vars-only prints summary: 8 pass, 0 fail, 0 skip naming deepseek and pi-agent as PASS; --apply on both adapters is a named refusal, not a silent success.: Both files exist and are executable (ls: install-deepseek.sh 4847B, install-pi-agent.sh 5660B). Both source the contract: install-deepseek.sh:18 `. "$HERE/harness-vars.sh"`, install-pi-agent.sh:17 same. --help documents all 12 §5 names in both (per-name grep counts: CF_MODEL=2/2, CF_PROVIDER=2/2, CF_BASE_URL=3/3, CF_API_KEY_FILE=3/3, CF_WORKDIR=3/3, CF_NAMESPACE=2/2, CF_RUN_ID=2/2, CF_LANE=2/2, CF_SKILLS_DIR=2/2, CF_HARNESS_OPTS=2/2, CF_MAX_TURNS=3/3, CF_TIMEOUT_S=3/3 — matching CFV_DECLARED in harness-vars.sh:28-29 and specs/HARNESS-MATRIX.md §5). vars-contract-test.sh:26-27 INSTALLERS=(install-hermes.sh install-opencode.sh install-claude-code.sh install-codex.sh install-deepseek.sh install-pi-agent.sh) = six; run output: 'vars-contract: 32 pass, 0 fail, 1 skip' / 'VARS CONTRACT: PASS', exit 0, `grep -c '^  FAIL'` = 0, with per-installer sections for all six including install-deepseek.sh and install-pi-agent.sh. `bash tests/harness-conformance.sh --vars-only` exit 0 prints 'PASS deepseek:vars — §5 set accepted in --contract (12 declared)...' and 'PASS pi-agent:vars — ...' and 'summary: 8 pass, 0 fail, 0 skip' / 'HARNESS CONFORMANCE: PASS'. --apply is a named refusal on both: deepseek prints 'FAIL apply — refused — no measured deepseek install ladder in this repo (no pin, no artifact digest, nothing recorded in specs/HARNESS.md)...' then 'DEEPSEEK: FAIL (2)' exit=1; pi-agent prints 'FAIL apply — refused — no measured pi install ladder in this repo...' then 'PI-AGENT: FAIL (1)' exit=1 (measured exit codes: deepseek --apply exit=1, pi-agent --apply exit=1).
Both adapters exist, source harness-vars.sh, document all 12 §5 CF_* names in --help, the six-installer vars-contract test reports 32 pass/0 fail, conformance --vars-only reports 8 pass/0 fail/0 skip with deepseek and pi-agent PASS, and --apply is a named refusal exiting 1 on both.

## Summary

Judge Result: CF-372

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ After the commit: scripts/harness/install-deepseek.sh and scripts/harness/install-pi-agent.sh exist, source harness-vars.sh, and document every §5 CF_* name in --help; tests/harness/vars-contract-test.sh covers six installers and reports zero FAIL rows; tests/harness-conformance.sh --vars-only prints summary: 8 pass, 0 fail, 0 skip naming deepseek and pi-agent as PASS; --apply on both adapters is a named refusal, not a silent success.: Both files exist and are executable (ls: install-deepseek.sh 4847B, install-pi-agent.sh 5660B). Both source the contract: install-deepseek.sh:18 `. "$HERE/harness-vars.sh"`, install-pi-agent.sh:17 same. --help documents all 12 §5 names in both (per-name grep counts: CF_MODEL=2/2, CF_PROVIDER=2/2, CF_BASE_URL=3/3, CF_API_KEY_FILE=3/3, CF_WORKDIR=3/3, CF_NAMESPACE=2/2, CF_RUN_ID=2/2, CF_LANE=2/2, CF_SKILLS_DIR=2/2, CF_HARNESS_OPTS=2/2, CF_MAX_TURNS=3/3, CF_TIMEOUT_S=3/3 — matching CFV_DECLARED in harness-vars.sh:28-29 and specs/HARNESS-MATRIX.md §5). vars-contract-test.sh:26-27 INSTALLERS=(install-hermes.sh install-opencode.sh install-claude-code.sh install-codex.sh install-deepseek.sh install-pi-agent.sh) = six; run output: 'vars-contract: 32 pass, 0 fail, 1 skip' / 'VARS CONTRACT: PASS', exit 0, `grep -c '^  FAIL'` = 0, with per-installer sections for all six including install-deepseek.sh and install-pi-agent.sh. `bash tests/harness-conformance.sh --vars-only` exit 0 prints 'PASS deepseek:vars — §5 set accepted in --contract (12 declared)...' and 'PASS pi-agent:vars — ...' and 'summary: 8 pass, 0 fail, 0 skip' / 'HARNESS CONFORMANCE: PASS'. --apply is a named refusal on both: deepseek prints 'FAIL apply — refused — no measured deepseek install ladder in this repo (no pin, no artifact digest, nothing recorded in specs/HARNESS.md)...' then 'DEEPSEEK: FAIL (2)' exit=1; pi-agent prints 'FAIL apply — refused — no measured pi install ladder in this repo...' then 'PI-AGENT: FAIL (1)' exit=1 (measured exit codes: deepseek --apply exit=1, pi-agent --apply exit=1).
Both adapters exist, source harness-vars.sh, document all 12 §5 CF_* names in --help, the six-installer vars-contract test reports 32 pass/0 fail, conformance --vars-only reports 8 pass/0 fail/0 skip with deepseek and pi-agent PASS, and --apply is a named refusal exiting 1 on both.

Overall: PASS ✓
