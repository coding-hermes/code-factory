# Verdict: CF-151-L1

**Task:** The landed CF-151 tree carries the node-scoped credential row, its binding selftest arm, and a section census that agrees with the working tree
**Evaluated:** 2026-11-04T09:12:59.302188
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ README.md Status row 3 scopes the contradiction to the node and labels the control-host run; tests/selftest.sh section 37 refuses the verbatim pre-fix row and passes on the reworded one; docs/ACCEPTANCE-PLAN.md pins 37 sections and bash docs/audits/cf099-prd-drift-probe.sh --sections-only exits 0; bash tests/selftest.sh prints SELFTEST: PASS rc 0; scripts/boardctl validate prints RESULT: OK; no secrets or endpoints added: README.md:77 row now opens "This is a NODE state, not measurable from the control host", names the node-scoped measurement (`~/node-scripts/project-node.sh --check --project <p>`, layer 20) and labels the control-host run as "this host's own key" ("control-host evidence only ... prints `PASS inference_key`"). tests/selftest.sh:1547-1592 section 37 `cf151-node-credential-scope` defines cf151_row_scope() with three offenses (unlabelled-control-host-fail, missing-control-host-label, missing-node-scoped-measurement) and runs a verbatim pre-fix fixture; actual run output: "37. the node credential row scopes its contradiction to the node (CF-151) / PASS node credential row labels control-host evidence and names the node measurement / PASS pre-fix node credential row refused (unlabelled-control-host-fail ... missing-control-host-label ... missing-node-scoped-measurement)". docs/ACCEPTANCE-PLAN.md:5 pins "carries 37 sections ... 40 arms"; `bash docs/audits/cf099-prd-drift-probe.sh --sections-only` -> "measured: plan_sections=37 selftest_sections=37", RC=0. `bash tests/selftest.sh` -> "SELFTEST: PASS", RC=0. `bash scripts/boardctl validate` -> "RESULT: OK (3 warning(s))", RC=0 (warnings are pre-existing CF-034 free-form fields + headerless board). Secrets/endpoints: grep over all 56 added lines for sk-/ghp_/AKIA/PRIVATE KEY/http(s):// /api_key=/bearer returned 0 hits; diff touches only README.md, docs/ACCEPTANCE-PLAN.md, tests/selftest.sh.
All six sub-claims verified with live command output: node-scoped README row, section 37 positive+negative arms, 37/37 section census rc 0, SELFTEST: PASS rc 0, boardctl RESULT: OK, and no secrets or endpoints added.

## Summary

Judge Result: CF-151-L1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ README.md Status row 3 scopes the contradiction to the node and labels the control-host run; tests/selftest.sh section 37 refuses the verbatim pre-fix row and passes on the reworded one; docs/ACCEPTANCE-PLAN.md pins 37 sections and bash docs/audits/cf099-prd-drift-probe.sh --sections-only exits 0; bash tests/selftest.sh prints SELFTEST: PASS rc 0; scripts/boardctl validate prints RESULT: OK; no secrets or endpoints added: README.md:77 row now opens "This is a NODE state, not measurable from the control host", names the node-scoped measurement (`~/node-scripts/project-node.sh --check --project <p>`, layer 20) and labels the control-host run as "this host's own key" ("control-host evidence only ... prints `PASS inference_key`"). tests/selftest.sh:1547-1592 section 37 `cf151-node-credential-scope` defines cf151_row_scope() with three offenses (unlabelled-control-host-fail, missing-control-host-label, missing-node-scoped-measurement) and runs a verbatim pre-fix fixture; actual run output: "37. the node credential row scopes its contradiction to the node (CF-151) / PASS node credential row labels control-host evidence and names the node measurement / PASS pre-fix node credential row refused (unlabelled-control-host-fail ... missing-control-host-label ... missing-node-scoped-measurement)". docs/ACCEPTANCE-PLAN.md:5 pins "carries 37 sections ... 40 arms"; `bash docs/audits/cf099-prd-drift-probe.sh --sections-only` -> "measured: plan_sections=37 selftest_sections=37", RC=0. `bash tests/selftest.sh` -> "SELFTEST: PASS", RC=0. `bash scripts/boardctl validate` -> "RESULT: OK (3 warning(s))", RC=0 (warnings are pre-existing CF-034 free-form fields + headerless board). Secrets/endpoints: grep over all 56 added lines for sk-/ghp_/AKIA/PRIVATE KEY/http(s):// /api_key=/bearer returned 0 hits; diff touches only README.md, docs/ACCEPTANCE-PLAN.md, tests/selftest.sh.
All six sub-claims verified with live command output: node-scoped README row, section 37 positive+negative arms, 37/37 section census rc 0, SELFTEST: PASS rc 0, boardctl RESULT: OK, and no secrets or endpoints added.

Overall: PASS ✓
