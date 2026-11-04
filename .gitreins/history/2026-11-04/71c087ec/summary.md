# Verdict: CF-150-DOC1

**Task:** docs(NODE): layer 20 does not establish a started gateway
**Evaluated:** 2026-11-04T03:08:48.924645
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ specs/NODE.md layer 20 must stop claiming the ladder establishes the harness gateway; it must name the basic_auth gate at scripts/harness/install-hermes.sh:96-102 and say the node-side gateway is not measured. Acceptance: bash tests/selftest.sh passes and the file quotes the refusal text of the shipped script.: (1) Claim removed: HEAD~1 specs/NODE.md:28 read `| 20 harness | the chosen harness + its gateway/CLI | base |`; new specs/NODE.md:28 reads `the harness binary plus the adapter's own gate rows, printed verbatim (python, binary, version, port, inference_key, and gateway_start when that block runs); gateway_start is a refusal on any node whose ~/.hermes/config.yaml carries no dashboard.basic_auth` — no longer claims the ladder establishes the gateway. (2) Gate named: specs/NODE.md:36-40 bullet cites `scripts/harness/install-hermes.sh:93-102`; verified that range is exactly the gate block (93 `if ! (command -v ss ...)`, 94 `if grep -q 'basic_auth' "$HOME/.hermes/config.yaml"`, 100 the refusal, 102 `fi`). (3) Not measured: specs/NODE.md:45-46 states `Whether a bunker agent image already ships that file is **not measured** by this repo.` (4) Refusal text quoted: specs/NODE.md:40 `FAIL gateway_start — refused: a public bind needs dashboard.basic_auth in ~/.hermes/config.yaml` matches scripts/harness/install-hermes.sh:100 byte-for-byte (grep -o of the string returned identical output from both files). (5) Tests: `bash tests/selftest.sh` -> EXIT_CODE=0, final line `SELFTEST: PASS` (93 PASS lines; the FAIL strings in the log are expected fixture output inside passing tests, e.g. 'board line 2: expected JSON object, got null'). Lint `bash -n $(git ls-files "*.sh")` -> LINT_OK. Supporting claims also verified: scripts/project-node.sh:228 runs the adapter with `--apply`, and scripts/node-create.sh:20 stages exactly five files with no config.yaml. docs/OPERATIONS.md §1 carries the same statement citing install-hermes.sh:100.
specs/NODE.md layer 20 no longer claims the gateway, names the basic_auth gate at install-hermes.sh:93-102, marks the node-side gateway not measured, quotes the shipped refusal text verbatim, and bash tests/selftest.sh exits 0 with SELFTEST: PASS.

## Summary

Judge Result: CF-150-DOC1

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ specs/NODE.md layer 20 must stop claiming the ladder establishes the harness gateway; it must name the basic_auth gate at scripts/harness/install-hermes.sh:96-102 and say the node-side gateway is not measured. Acceptance: bash tests/selftest.sh passes and the file quotes the refusal text of the shipped script.: (1) Claim removed: HEAD~1 specs/NODE.md:28 read `| 20 harness | the chosen harness + its gateway/CLI | base |`; new specs/NODE.md:28 reads `the harness binary plus the adapter's own gate rows, printed verbatim (python, binary, version, port, inference_key, and gateway_start when that block runs); gateway_start is a refusal on any node whose ~/.hermes/config.yaml carries no dashboard.basic_auth` — no longer claims the ladder establishes the gateway. (2) Gate named: specs/NODE.md:36-40 bullet cites `scripts/harness/install-hermes.sh:93-102`; verified that range is exactly the gate block (93 `if ! (command -v ss ...)`, 94 `if grep -q 'basic_auth' "$HOME/.hermes/config.yaml"`, 100 the refusal, 102 `fi`). (3) Not measured: specs/NODE.md:45-46 states `Whether a bunker agent image already ships that file is **not measured** by this repo.` (4) Refusal text quoted: specs/NODE.md:40 `FAIL gateway_start — refused: a public bind needs dashboard.basic_auth in ~/.hermes/config.yaml` matches scripts/harness/install-hermes.sh:100 byte-for-byte (grep -o of the string returned identical output from both files). (5) Tests: `bash tests/selftest.sh` -> EXIT_CODE=0, final line `SELFTEST: PASS` (93 PASS lines; the FAIL strings in the log are expected fixture output inside passing tests, e.g. 'board line 2: expected JSON object, got null'). Lint `bash -n $(git ls-files "*.sh")` -> LINT_OK. Supporting claims also verified: scripts/project-node.sh:228 runs the adapter with `--apply`, and scripts/node-create.sh:20 stages exactly five files with no config.yaml. docs/OPERATIONS.md §1 carries the same statement citing install-hermes.sh:100.
specs/NODE.md layer 20 no longer claims the gateway, names the basic_auth gate at install-hermes.sh:93-102, marks the node-side gateway not measured, quotes the shipped refusal text verbatim, and bash tests/selftest.sh exits 0 with SELFTEST: PASS.

Overall: PASS ✓
