# Verdict: CF-372

**Task:** install-deepseek.sh and install-pi-agent.sh: contract-conforming adapters
**Evaluated:** 2026-11-06T01:05:20.891302
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ After the commit: scripts/harness/install-deepseek.sh and scripts/harness/install-pi-agent.sh exist, source harness-vars.sh, and document every §5 CF_* name in --help; tests/harness/vars-contract-test.sh covers six installers and reports zero FAIL rows; tests/harness-conformance.sh --vars-only prints summary: 8 pass, 0 fail, 0 skip naming deepseek and pi-agent as PASS; --apply on both adapters is a named refusal, not a silent success.: All sub-claims verified with fresh command output. (a) Files exist and are executable: `ls -la` -> install-deepseek.sh 4847B, install-pi-agent.sh 5660B, both -rwxr-xr-x. (b) Both source the contract: install-deepseek.sh:18 `. "$HERE/harness-vars.sh"`, install-pi-agent.sh:17 same (plus lib.sh at :17/:16). (c) --help documents all 12 §5 names in BOTH adapters — per-name grep counts on `--help` output: CF_MODEL=2, CF_PROVIDER=2, CF_BASE_URL=3, CF_API_KEY_FILE=3, CF_WORKDIR=3, CF_NAMESPACE=2, CF_RUN_ID=2, CF_LANE=2, CF_SKILLS_DIR=2, CF_HARNESS_OPTS=2, CF_MAX_TURNS=3, CF_TIMEOUT_S=3 — matching CFV_DECLARED at scripts/harness/harness-vars.sh:28. (d) tests/harness/vars-contract-test.sh:26-27 INSTALLERS=(install-hermes.sh install-opencode.sh install-claude-code.sh install-codex.sh install-deepseek.sh install-pi-agent.sh) = six; run output: 'vars-contract: 32 pass, 0 fail, 1 skip' / 'VARS CONTRACT: PASS', exit_code=0, and `grep -c '^  FAIL'` = 0, with per-installer PASS sections for install-deepseek.sh and install-pi-agent.sh (each: --help lists all 12, credential VALUE refused, --api-key refused, ambient key refused, 12/12 flags recorded). (e) `bash tests/harness-conformance.sh --vars-only` exit_code=0 prints 'PASS deepseek:vars — §5 set accepted in --contract (12 declared)...' and 'PASS pi-agent:vars — §5 set accepted in --contract (12 declared)...' followed by 'summary: 8 pass, 0 fail, 0 skip' / 'HARNESS CONFORMANCE: PASS'. (f) --apply is a named refusal on both, measured exit codes: deepseek prints 'FAIL apply — refused — no measured deepseek install ladder in this repo (no pin, no artifact digest, nothing recorded in specs/HARNESS.md)...' then 'DEEPSEEK: FAIL (2)', exit=1; pi-agent prints 'FAIL apply — refused — no measured pi install ladder in this repo (no pin, no artifact digest...)...' then 'PI-AGENT: FAIL (1)', exit=1 — neither is a silent success. (g) `bash -n` on both scripts: exit 0.
Both adapters exist, source harness-vars.sh, document all 12 §5 CF_* names in --help, the six-installer vars-contract battery reports 32 pass/0 fail, conformance --vars-only reports 8 pass/0 fail/0 skip with deepseek and pi-agent PASS, and --apply is a named refusal exiting 1 on both.

## Summary

Judge Result: CF-372

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ After the commit: scripts/harness/install-deepseek.sh and scripts/harness/install-pi-agent.sh exist, source harness-vars.sh, and document every §5 CF_* name in --help; tests/harness/vars-contract-test.sh covers six installers and reports zero FAIL rows; tests/harness-conformance.sh --vars-only prints summary: 8 pass, 0 fail, 0 skip naming deepseek and pi-agent as PASS; --apply on both adapters is a named refusal, not a silent success.: All sub-claims verified with fresh command output. (a) Files exist and are executable: `ls -la` -> install-deepseek.sh 4847B, install-pi-agent.sh 5660B, both -rwxr-xr-x. (b) Both source the contract: install-deepseek.sh:18 `. "$HERE/harness-vars.sh"`, install-pi-agent.sh:17 same (plus lib.sh at :17/:16). (c) --help documents all 12 §5 names in BOTH adapters — per-name grep counts on `--help` output: CF_MODEL=2, CF_PROVIDER=2, CF_BASE_URL=3, CF_API_KEY_FILE=3, CF_WORKDIR=3, CF_NAMESPACE=2, CF_RUN_ID=2, CF_LANE=2, CF_SKILLS_DIR=2, CF_HARNESS_OPTS=2, CF_MAX_TURNS=3, CF_TIMEOUT_S=3 — matching CFV_DECLARED at scripts/harness/harness-vars.sh:28. (d) tests/harness/vars-contract-test.sh:26-27 INSTALLERS=(install-hermes.sh install-opencode.sh install-claude-code.sh install-codex.sh install-deepseek.sh install-pi-agent.sh) = six; run output: 'vars-contract: 32 pass, 0 fail, 1 skip' / 'VARS CONTRACT: PASS', exit_code=0, and `grep -c '^  FAIL'` = 0, with per-installer PASS sections for install-deepseek.sh and install-pi-agent.sh (each: --help lists all 12, credential VALUE refused, --api-key refused, ambient key refused, 12/12 flags recorded). (e) `bash tests/harness-conformance.sh --vars-only` exit_code=0 prints 'PASS deepseek:vars — §5 set accepted in --contract (12 declared)...' and 'PASS pi-agent:vars — §5 set accepted in --contract (12 declared)...' followed by 'summary: 8 pass, 0 fail, 0 skip' / 'HARNESS CONFORMANCE: PASS'. (f) --apply is a named refusal on both, measured exit codes: deepseek prints 'FAIL apply — refused — no measured deepseek install ladder in this repo (no pin, no artifact digest, nothing recorded in specs/HARNESS.md)...' then 'DEEPSEEK: FAIL (2)', exit=1; pi-agent prints 'FAIL apply — refused — no measured pi install ladder in this repo (no pin, no artifact digest...)...' then 'PI-AGENT: FAIL (1)', exit=1 — neither is a silent success. (g) `bash -n` on both scripts: exit 0.
Both adapters exist, source harness-vars.sh, document all 12 §5 CF_* names in --help, the six-installer vars-contract battery reports 32 pass/0 fail, conformance --vars-only reports 8 pass/0 fail/0 skip with deepseek and pi-agent PASS, and --apply is a named refusal exiting 1 on both.

Overall: PASS ✓
