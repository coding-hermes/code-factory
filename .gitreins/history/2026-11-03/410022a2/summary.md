# Verdict: CF-077

**Task:** verify-node.sh auth probe fails open: 404/000/500 are WARN and VERIFY PASS; node-create.sh admits the node
**Evaluated:** 2026-11-03T16:32:37.977297
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ Fix is present in the graded tree: scripts/verify-node.sh exits non-zero and prints a FAIL naming the measured status code when /api/system/stats answers anything other than 401, 302 or 403 (404, 000 and 500 all FAIL); the auth_gate leg fails closed when /api/status lacks auth_required true; scripts/node-create.sh exits 1 and prints NODE INCOMPLETE when the auth probe is inconclusive and prints NODE CREATED only when every auth leg passed; tests/selftest.sh carries stub-curl fixture sections asserting both directions (401 and 403 pass, 404, 000 and 500 fail with a named FAIL row) and the suite prints SELFTEST: PASS; docs/OPERATIONS.md and docs/THREAT-MODEL.md state the enforced behaviour.: scripts/verify-node.sh:53-58 — case 401|302|403 -> ok; 200 -> bad; *) -> bad "unauth_refused — /api/system/stats -> $code — auth refusal not verified" (so 404/000/500 are named FAIL rows), and line 74 exits 1 when FAILED>0. auth_gate leg verify-node.sh:43-47 requires the boolean auth_required:true regex, else bad "auth_gate" (fails closed). scripts/node-create.sh:111-116 — verify-node.sh failure calls incomplete() which prints "NODE INCOMPLETE ($FAILED)" and exits 1; "NODE CREATED: $AGENT" only on FAILED==0. tests/selftest.sh:482-546 (section 17) builds stub bunker+curl fixtures and asserts 401/302/403 -> PASS exit 0, 404/000/500/200 -> named FAIL row + 'VERIFY: FAIL (1)' exit 1, plus a pre-fix (bbb0719) detector control and auth-marker negatives; :548-566 (section 18) asserts node-create refused/missing-marker -> 'NODE INCOMPLETE (1)' exit 1 and closed -> 'NODE CREATED: f' exit 0. Ran `bash tests/selftest.sh` (guards.test_command): exit=0, output ends 'SELFTEST: PASS', with 'PASS auth stats 401/302/403 -> PASS, exit 0', 'PASS auth stats 404/000/500 -> FAIL, exit 1', 'PASS node-create refused/missing-marker -> NODE INCOMPLETE (1), exit 1', 'PASS node-create closed -> NODE CREATED: f, exit 0'. docs/OPERATIONS.md:82,84 and docs/THREAT-MODEL.md:33,47,65,93 document the enforced fail-closed behaviour (no WARN path, both legs mandatory, NODE INCOMPLETE vs NODE CREATED).
All fail-closed auth-probe changes are present in verify-node.sh, node-create.sh, selftest.sh and both docs, and `bash tests/selftest.sh` exits 0 printing SELFTEST: PASS with both directions asserted.

## Summary

Judge Result: CF-077

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ Fix is present in the graded tree: scripts/verify-node.sh exits non-zero and prints a FAIL naming the measured status code when /api/system/stats answers anything other than 401, 302 or 403 (404, 000 and 500 all FAIL); the auth_gate leg fails closed when /api/status lacks auth_required true; scripts/node-create.sh exits 1 and prints NODE INCOMPLETE when the auth probe is inconclusive and prints NODE CREATED only when every auth leg passed; tests/selftest.sh carries stub-curl fixture sections asserting both directions (401 and 403 pass, 404, 000 and 500 fail with a named FAIL row) and the suite prints SELFTEST: PASS; docs/OPERATIONS.md and docs/THREAT-MODEL.md state the enforced behaviour.: scripts/verify-node.sh:53-58 — case 401|302|403 -> ok; 200 -> bad; *) -> bad "unauth_refused — /api/system/stats -> $code — auth refusal not verified" (so 404/000/500 are named FAIL rows), and line 74 exits 1 when FAILED>0. auth_gate leg verify-node.sh:43-47 requires the boolean auth_required:true regex, else bad "auth_gate" (fails closed). scripts/node-create.sh:111-116 — verify-node.sh failure calls incomplete() which prints "NODE INCOMPLETE ($FAILED)" and exits 1; "NODE CREATED: $AGENT" only on FAILED==0. tests/selftest.sh:482-546 (section 17) builds stub bunker+curl fixtures and asserts 401/302/403 -> PASS exit 0, 404/000/500/200 -> named FAIL row + 'VERIFY: FAIL (1)' exit 1, plus a pre-fix (bbb0719) detector control and auth-marker negatives; :548-566 (section 18) asserts node-create refused/missing-marker -> 'NODE INCOMPLETE (1)' exit 1 and closed -> 'NODE CREATED: f' exit 0. Ran `bash tests/selftest.sh` (guards.test_command): exit=0, output ends 'SELFTEST: PASS', with 'PASS auth stats 401/302/403 -> PASS, exit 0', 'PASS auth stats 404/000/500 -> FAIL, exit 1', 'PASS node-create refused/missing-marker -> NODE INCOMPLETE (1), exit 1', 'PASS node-create closed -> NODE CREATED: f, exit 0'. docs/OPERATIONS.md:82,84 and docs/THREAT-MODEL.md:33,47,65,93 document the enforced fail-closed behaviour (no WARN path, both legs mandatory, NODE INCOMPLETE vs NODE CREATED).
All fail-closed auth-probe changes are present in verify-node.sh, node-create.sh, selftest.sh and both docs, and `bash tests/selftest.sh` exits 0 printing SELFTEST: PASS with both directions asserted.

Overall: PASS ✓
