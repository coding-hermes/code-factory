# Verdict: CF-218

**Task:** Layer 10 grades the toolchain the repo kind needs, Go included
**Evaluated:** 2026-11-05T14:40:49.703644
**Result:** ✗ FAIL

## Pipeline Stages

- ✗ **tier1**
  -   ✗ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ At the worker's own commit: bash tests/selftest.sh exits 0 (full battery, SELFTEST: PASS). scripts/project-node.sh layer 10 grades a Go toolchain for a Go-kind workspace: the go binary, its version read back, and one module resolved through the configured GOPROXY, with a named FAIL row when go is absent instead of a WARN. The graded set is derived from the repository kind actually present (go.mod -> go, Cargo.toml -> cargo, package.json -> node, pyproject.toml/setup.py -> python) or from an explicit kind declaration when no workspace exists yet, never from the fixed list alone. A fixture in tests/selftest.sh proves the same tree FAILS without go on PATH and PASSES with a stub go on PATH. specs/NODE.md's layer 10 cell names the derived set and the Go proxy probe, and the layer 00 cell's claim that no shipped layer measures a Go module proxy is corrected in the same change.: Fresh run of bash tests/selftest.sh at HEAD (containing worker commit 3c4c639): EXIT=0, 'SELFTEST: PASS', 316 PASS rows (the 57 'FAIL' strings in the log are expected negative-fixture output; the harness fails counter reached 0 per tests/selftest.sh:3439). scripts/project-node.sh:391-405 grades tool:go with bad() (FAIL, not WARN) when go is absent, reads 'go version' back into the row, and go_proxy_row (lines 302-326) resolves pinned rsc.io/quote@v1.5.2 through the node's own GOPROXY with a cold GOMODCACHE under a 30s bound, failing with proxy URL + error text. Kind derivation: kind_evidence() (lines 283-296) maps go.mod->go, Cargo.toml->rust, package.json->node, pyproject.toml/setup.py->python from $HOME/repo; --kinds/NODE_KINDS is validated before any layer runs (lines 108-130, unknown kind -> named 'FAIL kinds', exit 1); the generic fallback prints 'WARN kinds — generic fallback' naming itself (lines 337-349). Fixture tests/selftest.sh:3277-3436 (section 49, cf218-kinds) ran 8/8 PASS arms in this run, including RED (same go.mod tree without go on PATH -> exit 1, exactly one FAIL tool:go row, no WARN) and GREEN (same tree with stub go -> tool:go PASS with version read back, go:proxy PASS via stub proxy, exit 0). specs/NODE.md layer 10 cell rewritten to name the derived kind set and the rsc.io/quote@v1.5.2 GOPROXY probe; layer 00 cell's CF-164 claim ('no shipped layer measures a Go module proxy') corrected in the same commit 3c4c639, pointing to layer 10's go_proxy_row.
All sub-requirements verified: selftest exits 0 with SELFTEST: PASS (316 rows), layer 10 derives its graded set from repo kind evidence or --kinds with a named fallback, Go grading covers binary/version/GOPROXY probe with FAIL-not-WARN semantics, the RED/GREEN stub-go fixture passes all 8 arms, and both specs/NODE.md cells were corrected in commit 3c4c639.

## Summary

Judge Result: CF-218

Stage tier1: FAIL
    ✗ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ At the worker's own commit: bash tests/selftest.sh exits 0 (full battery, SELFTEST: PASS). scripts/project-node.sh layer 10 grades a Go toolchain for a Go-kind workspace: the go binary, its version read back, and one module resolved through the configured GOPROXY, with a named FAIL row when go is absent instead of a WARN. The graded set is derived from the repository kind actually present (go.mod -> go, Cargo.toml -> cargo, package.json -> node, pyproject.toml/setup.py -> python) or from an explicit kind declaration when no workspace exists yet, never from the fixed list alone. A fixture in tests/selftest.sh proves the same tree FAILS without go on PATH and PASSES with a stub go on PATH. specs/NODE.md's layer 10 cell names the derived set and the Go proxy probe, and the layer 00 cell's claim that no shipped layer measures a Go module proxy is corrected in the same change.: Fresh run of bash tests/selftest.sh at HEAD (containing worker commit 3c4c639): EXIT=0, 'SELFTEST: PASS', 316 PASS rows (the 57 'FAIL' strings in the log are expected negative-fixture output; the harness fails counter reached 0 per tests/selftest.sh:3439). scripts/project-node.sh:391-405 grades tool:go with bad() (FAIL, not WARN) when go is absent, reads 'go version' back into the row, and go_proxy_row (lines 302-326) resolves pinned rsc.io/quote@v1.5.2 through the node's own GOPROXY with a cold GOMODCACHE under a 30s bound, failing with proxy URL + error text. Kind derivation: kind_evidence() (lines 283-296) maps go.mod->go, Cargo.toml->rust, package.json->node, pyproject.toml/setup.py->python from $HOME/repo; --kinds/NODE_KINDS is validated before any layer runs (lines 108-130, unknown kind -> named 'FAIL kinds', exit 1); the generic fallback prints 'WARN kinds — generic fallback' naming itself (lines 337-349). Fixture tests/selftest.sh:3277-3436 (section 49, cf218-kinds) ran 8/8 PASS arms in this run, including RED (same go.mod tree without go on PATH -> exit 1, exactly one FAIL tool:go row, no WARN) and GREEN (same tree with stub go -> tool:go PASS with version read back, go:proxy PASS via stub proxy, exit 0). specs/NODE.md layer 10 cell rewritten to name the derived kind set and the rsc.io/quote@v1.5.2 GOPROXY probe; layer 00 cell's CF-164 claim ('no shipped layer measures a Go module proxy') corrected in the same commit 3c4c639, pointing to layer 10's go_proxy_row.
All sub-requirements verified: selftest exits 0 with SELFTEST: PASS (316 rows), layer 10 derives its graded set from repo kind evidence or --kinds with a named fallback, Go grading covers binary/version/GOPROXY probe with FAIL-not-WARN semantics, the RED/GREEN stub-go fixture passes all 8 arms, and both specs/NODE.md cells were corrected in commit 3c4c639.

Overall: FAIL ✗
