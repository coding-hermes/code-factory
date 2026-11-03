# Verdict: CF-077-QA

**Task:** verify-node.sh and node-create.sh admit a node whose auth gate was never proven closed: WARN on an inconclusive auth probe still exits 0
**Evaluated:** 2026-11-03T15:34:05.662325
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Prove from the repository alone: with a stub curl on PATH returning 404 or 000 for /api/system/stats, scripts/verify-node.sh prints WARN unauth_refused and VERIFY: PASS with rc 0, and scripts/node-create.sh prints NODE CREATED with rc 0 while its only auth evidence is stats -> 404; the true negatives still fail (stats 200 -> VERIFY: FAIL rc 1). The filed row CF-077 carries that probe and a falsifiable criterion.: Extracted the `probe` field verbatim from .coding-hermes/board/tasks.jsonl (row CF-077) and ran it with bash; exit_code 0, output:
  verify stats=401 rc=0 VERIFY: PASS | PASS unauth_refused -> 401
  verify stats=403 rc=0 VERIFY: PASS | PASS unauth_refused -> 403
  verify stats=404 rc=0 VERIFY: PASS | WARN unauth_refused -> 404
  verify stats=000 rc=0 VERIFY: PASS | WARN unauth_refused -> 000
  verify stats=200 rc=1 VERIFY: FAIL (1) | FAIL unauth_refused -> 200 — the node is OPEN to the tailnet
  node-create rc=0 NODE CREATED: f | stats -> 404
All arms match the criterion exactly. Code confirms the mechanism: scripts/verify-node.sh:53-58 `case "$code" in 401|302|403) ok ;; 200) bad ;; *) warn "unauth_refused"` and scripts/lib.sh:7 `warn()` is pure stdout (does not increment FAILED), so the summary at verify-node.sh:66-70 prints `VERIFY: PASS`/exit 0; scripts/node-create.sh:61 `"$HERE/verify-node.sh" ... || bad "verify"` therefore never fails, and node-create.sh:65-67 prints `NODE CREATED`/exit 0. The row carries the probe (tasks.jsonl CF-077.probe) and a falsifiable criterion (reasoning item 2: 'stats 404 -> node-create.sh prints NODE INCOMPLETE and exits 1' — currently false, so it is falsifiable). Repo test suite also run fresh: `bash tests/selftest.sh` -> SELFTEST_RC=0, 'SELFTEST: PASS' (tests/selftest.sh:53); `grep -n verify-node tests/selftest.sh` is empty, confirming no selftest covers this path.
The filed CF-077 row's own probe reproduces exactly as claimed — WARN unauth_refused on 404/000 still yields VERIFY: PASS rc 0 and NODE CREATED rc 0, while stats 200 yields VERIFY: FAIL rc 1 — and the row carries both the probe and a falsifiable criterion.

## Summary

Judge Result: CF-077-QA

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Prove from the repository alone: with a stub curl on PATH returning 404 or 000 for /api/system/stats, scripts/verify-node.sh prints WARN unauth_refused and VERIFY: PASS with rc 0, and scripts/node-create.sh prints NODE CREATED with rc 0 while its only auth evidence is stats -> 404; the true negatives still fail (stats 200 -> VERIFY: FAIL rc 1). The filed row CF-077 carries that probe and a falsifiable criterion.: Extracted the `probe` field verbatim from .coding-hermes/board/tasks.jsonl (row CF-077) and ran it with bash; exit_code 0, output:
  verify stats=401 rc=0 VERIFY: PASS | PASS unauth_refused -> 401
  verify stats=403 rc=0 VERIFY: PASS | PASS unauth_refused -> 403
  verify stats=404 rc=0 VERIFY: PASS | WARN unauth_refused -> 404
  verify stats=000 rc=0 VERIFY: PASS | WARN unauth_refused -> 000
  verify stats=200 rc=1 VERIFY: FAIL (1) | FAIL unauth_refused -> 200 — the node is OPEN to the tailnet
  node-create rc=0 NODE CREATED: f | stats -> 404
All arms match the criterion exactly. Code confirms the mechanism: scripts/verify-node.sh:53-58 `case "$code" in 401|302|403) ok ;; 200) bad ;; *) warn "unauth_refused"` and scripts/lib.sh:7 `warn()` is pure stdout (does not increment FAILED), so the summary at verify-node.sh:66-70 prints `VERIFY: PASS`/exit 0; scripts/node-create.sh:61 `"$HERE/verify-node.sh" ... || bad "verify"` therefore never fails, and node-create.sh:65-67 prints `NODE CREATED`/exit 0. The row carries the probe (tasks.jsonl CF-077.probe) and a falsifiable criterion (reasoning item 2: 'stats 404 -> node-create.sh prints NODE INCOMPLETE and exits 1' — currently false, so it is falsifiable). Repo test suite also run fresh: `bash tests/selftest.sh` -> SELFTEST_RC=0, 'SELFTEST: PASS' (tests/selftest.sh:53); `grep -n verify-node tests/selftest.sh` is empty, confirming no selftest covers this path.
The filed CF-077 row's own probe reproduces exactly as claimed — WARN unauth_refused on 404/000 still yields VERIFY: PASS rc 0 and NODE CREATED rc 0, while stats 200 yields VERIFY: FAIL rc 1 — and the row carries both the probe and a falsifiable criterion.

Overall: PASS ✓
