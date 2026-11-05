# Verdict: CF-242-QA1

**Task:** QA filing: CF-242 section-mapping census cannot see a duplicate-numbered or indented section header
**Evaluated:** 2026-11-05T11:54:23.335229
**Result:** ✗ FAIL

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✗ **tier2**
  - INCOMPLETE

Evaluator error: LLM call failed: 402 Client Error: Payment Required for url: https://api.deepseek.com/v1/chat/completions (provider=openai model=deepseek-v4-flash url=https://api.deepseek.com/v1/chat/completions key=<GITREINS_LLM_API_KEY>)

## Summary

Judge Result: CF-242-QA1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: FAIL
  INCOMPLETE

Evaluator error: LLM call failed: 402 Client Error: Payment Required for url: https://api.deepseek.com/v1/chat/completions (provider=openai model=deepseek-v4-flash url=https://api.deepseek.com/v1/chat/completions key=<GITREINS_LLM_API_KEY>)

Overall: FAIL ✗
