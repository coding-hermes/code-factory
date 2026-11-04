# Verdict: CF-151

**Task:** README Status row 3 must state a node-scoped credential state and cite a command that measures the node, not the control host's key
**Evaluated:** 2026-11-04T09:09:36.086581
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ README.md Status row 3 no longer asserts FAIL inference_key as the contradicting measurement of a NODE state without labelling the control-host scope; the row names a node-scoped measurement (or explicitly separates control-host from node state); tests/selftest.sh carries a new arm (numbered past 36) that FAILs on the pre-fix wording and PASSes on the reworded README; bash tests/selftest.sh prints SELFTEST: PASS rc 0; scripts/boardctl validate prints RESULT: OK; no secrets, endpoints or personal data added to this public repo: README.md:77 reworded: opens 'This is a NODE state, not measurable from the control host', names the node-scoped measurement 'the node's ~/node-scripts/project-node.sh --check --project <p> echoes the adapter's rows through its layer 20, so an unkeyed node prints FAIL inference_key for its own missing key', and explicitly separates scope: 'Run on the control host, the same gate measures this host's own key, not a node's — control-host evidence only ... prints PASS inference_key ... so a PASS there cannot witness the node's missing key.' tests/selftest.sh:1547-1593 adds section 37 'the node credential row scopes its contradiction to the node (CF-151)' (numbered past 36) with cf151_row_scope() plus a verbatim pre-fix fixture. RED proof reproduced by running the arm's function directly: pre-fix row from 276b0b0 -> rc=1 emitting 'unlabelled-control-host-fail / missing-control-host-label / missing-node-scoped-measurement'; current README.md -> rc=0. Fresh test run: `bash tests/selftest.sh` -> exit_code 0, output '37. the node credential row scopes its contradiction to the node (CF-151) / PASS node credential row labels control-host evidence and names the node measurement / PASS pre-fix node credential row refused' and 'SELFTEST: PASS' (122 PASS lines). `bash scripts/boardctl validate` -> exit_code 0, 'RESULT: OK (3 warning(s))' (warnings are pre-existing CF-034 free-form fields, unrelated). Lint guard `bash -n $(git ls-files '*.sh')` -> LINT OK. Secret/endpoint scan of the new row (sed -n '77p' README.md | grep -oiE 'https?://|email|sk-|ghp_|IPv4') returned no matches; the only path cited is the in-repo docs/audits/code-factory-CF-064.probe.txt, and the added ch:trace line at README.md:227 contains no credentials.
README Status row 3 now scopes the inference_key contradiction to the node with the control-host run explicitly labelled, selftest section 37 proves RED on the pre-fix wording and GREEN on the reword, and both bash tests/selftest.sh (SELFTEST: PASS, rc 0) and scripts/boardctl validate (RESULT: OK) pass with no secrets added.

## Summary

Judge Result: CF-151

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ README.md Status row 3 no longer asserts FAIL inference_key as the contradicting measurement of a NODE state without labelling the control-host scope; the row names a node-scoped measurement (or explicitly separates control-host from node state); tests/selftest.sh carries a new arm (numbered past 36) that FAILs on the pre-fix wording and PASSes on the reworded README; bash tests/selftest.sh prints SELFTEST: PASS rc 0; scripts/boardctl validate prints RESULT: OK; no secrets, endpoints or personal data added to this public repo: README.md:77 reworded: opens 'This is a NODE state, not measurable from the control host', names the node-scoped measurement 'the node's ~/node-scripts/project-node.sh --check --project <p> echoes the adapter's rows through its layer 20, so an unkeyed node prints FAIL inference_key for its own missing key', and explicitly separates scope: 'Run on the control host, the same gate measures this host's own key, not a node's — control-host evidence only ... prints PASS inference_key ... so a PASS there cannot witness the node's missing key.' tests/selftest.sh:1547-1593 adds section 37 'the node credential row scopes its contradiction to the node (CF-151)' (numbered past 36) with cf151_row_scope() plus a verbatim pre-fix fixture. RED proof reproduced by running the arm's function directly: pre-fix row from 276b0b0 -> rc=1 emitting 'unlabelled-control-host-fail / missing-control-host-label / missing-node-scoped-measurement'; current README.md -> rc=0. Fresh test run: `bash tests/selftest.sh` -> exit_code 0, output '37. the node credential row scopes its contradiction to the node (CF-151) / PASS node credential row labels control-host evidence and names the node measurement / PASS pre-fix node credential row refused' and 'SELFTEST: PASS' (122 PASS lines). `bash scripts/boardctl validate` -> exit_code 0, 'RESULT: OK (3 warning(s))' (warnings are pre-existing CF-034 free-form fields, unrelated). Lint guard `bash -n $(git ls-files '*.sh')` -> LINT OK. Secret/endpoint scan of the new row (sed -n '77p' README.md | grep -oiE 'https?://|email|sk-|ghp_|IPv4') returned no matches; the only path cited is the in-repo docs/audits/code-factory-CF-064.probe.txt, and the added ch:trace line at README.md:227 contains no credentials.
README Status row 3 now scopes the inference_key contradiction to the node with the control-host run explicitly labelled, selftest section 37 proves RED on the pre-fix wording and GREEN on the reword, and both bash tests/selftest.sh (SELFTEST: PASS, rc 0) and scripts/boardctl validate (RESULT: OK) pass with no secrets added.

Overall: PASS ✓
