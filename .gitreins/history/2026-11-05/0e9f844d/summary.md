# Verdict: CF-218

**Task:** Layer 10 grades the toolchain the repo kind needs, Go included
**Evaluated:** 2026-11-05T14:34:45.424222
**Result:** ✗ FAIL

## Pipeline Stages

- ✗ **tier1**
  -   ✗ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ At the worker's own commit: bash tests/selftest.sh exits 0 (full battery, SELFTEST: PASS). scripts/project-node.sh layer 10 grades a Go toolchain for a Go-kind workspace: the go binary, its version read back, and one module resolved through the configured GOPROXY, with a named FAIL row when go is absent instead of a WARN. The graded set is derived from the repository kind actually present (go.mod -> go, Cargo.toml -> cargo, package.json -> node, pyproject.toml/setup.py -> python) or from an explicit kind declaration when no workspace exists yet, never from the fixed list alone. A fixture in tests/selftest.sh proves the same tree FAILS without go on PATH and PASSES with a stub go on PATH. specs/NODE.md's layer 10 cell names the derived set and the Go proxy probe, and the layer 00 cell's claim that no shipped layer measures a Go module proxy is corrected in the same change.: Ran bash tests/selftest.sh at worker commit 3c4c639 in a detached worktree: final line 'SELFTEST: PASS', 316 '  PASS' rows, zero unexpected failures, and section 49 (CF-218) green on all 8 arms including 'go.mod workspace without go -> exit 1 and ONE FAIL tool:go row (not a WARN)' and 'the same tree with a go that resolves the pinned module -> go rows PASS, exit 0'. Code verified in scripts/project-node.sh@3c4c639: kind_evidence() (lines 283-297) maps go.mod->go, Cargo.toml->rust, package.json->node, pyproject.toml|setup.py->python from $HOME/repo; --kinds/NODE_KINDS validated before any layer (live check: '--kinds go,cobol' -> 'FAIL kinds — unknown kind 'cobol'', exit 1); generic fallback prints 'WARN kinds — generic fallback' naming itself (live check). Go grading (lines ~392-404 + go_proxy_row 302-326): live check on a go-free PATH with a go.mod workspace gave exit 1 with exactly one 'FAIL tool:go — missing — kind go needs a Go toolchain on PATH' and no WARN; with a stub go, 'PASS tool:go — … (go version go1.99.0 fixture/amd64)' and 'PASS go:proxy — rsc.io/quote@v1.5.2 resolved via https://proxy.fixture.invalid,direct', exit 0; the probe uses a cold GOMODCACHE, 30s bound, and its FAIL row names the proxy URL and error text. specs/NODE.md@3c4c639 line 40 (layer 10 cell) names the derived kind set and the GOPROXY probe of pinned rsc.io/quote@v1.5.2; line 39 (layer 00 cell) now says the Go proxy 'is **not** measured by this layer… graded one layer later… supersedes the CF-164 statement', correcting the prior 'not measured by this or any shipped layer' claim in the same commit.
CF-218 verified at commit 3c4c639: selftest exits 0 with SELFTEST: PASS (316 PASS rows, CF-218 section fully green), layer 10 derives its graded set from repo kind evidence or --kinds with a named fallback, grades go binary/version/GOPROXY module resolution with a FAIL (not WARN) when go is absent, and specs/NODE.md layers 10 and 00 were both corrected in the same change.

## Summary

Judge Result: CF-218

Stage tier1: FAIL
    ✗ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ At the worker's own commit: bash tests/selftest.sh exits 0 (full battery, SELFTEST: PASS). scripts/project-node.sh layer 10 grades a Go toolchain for a Go-kind workspace: the go binary, its version read back, and one module resolved through the configured GOPROXY, with a named FAIL row when go is absent instead of a WARN. The graded set is derived from the repository kind actually present (go.mod -> go, Cargo.toml -> cargo, package.json -> node, pyproject.toml/setup.py -> python) or from an explicit kind declaration when no workspace exists yet, never from the fixed list alone. A fixture in tests/selftest.sh proves the same tree FAILS without go on PATH and PASSES with a stub go on PATH. specs/NODE.md's layer 10 cell names the derived set and the Go proxy probe, and the layer 00 cell's claim that no shipped layer measures a Go module proxy is corrected in the same change.: Ran bash tests/selftest.sh at worker commit 3c4c639 in a detached worktree: final line 'SELFTEST: PASS', 316 '  PASS' rows, zero unexpected failures, and section 49 (CF-218) green on all 8 arms including 'go.mod workspace without go -> exit 1 and ONE FAIL tool:go row (not a WARN)' and 'the same tree with a go that resolves the pinned module -> go rows PASS, exit 0'. Code verified in scripts/project-node.sh@3c4c639: kind_evidence() (lines 283-297) maps go.mod->go, Cargo.toml->rust, package.json->node, pyproject.toml|setup.py->python from $HOME/repo; --kinds/NODE_KINDS validated before any layer (live check: '--kinds go,cobol' -> 'FAIL kinds — unknown kind 'cobol'', exit 1); generic fallback prints 'WARN kinds — generic fallback' naming itself (live check). Go grading (lines ~392-404 + go_proxy_row 302-326): live check on a go-free PATH with a go.mod workspace gave exit 1 with exactly one 'FAIL tool:go — missing — kind go needs a Go toolchain on PATH' and no WARN; with a stub go, 'PASS tool:go — … (go version go1.99.0 fixture/amd64)' and 'PASS go:proxy — rsc.io/quote@v1.5.2 resolved via https://proxy.fixture.invalid,direct', exit 0; the probe uses a cold GOMODCACHE, 30s bound, and its FAIL row names the proxy URL and error text. specs/NODE.md@3c4c639 line 40 (layer 10 cell) names the derived kind set and the GOPROXY probe of pinned rsc.io/quote@v1.5.2; line 39 (layer 00 cell) now says the Go proxy 'is **not** measured by this layer… graded one layer later… supersedes the CF-164 statement', correcting the prior 'not measured by this or any shipped layer' claim in the same commit.
CF-218 verified at commit 3c4c639: selftest exits 0 with SELFTEST: PASS (316 PASS rows, CF-218 section fully green), layer 10 derives its graded set from repo kind evidence or --kinds with a named fallback, grades go binary/version/GOPROXY module resolution with a FAIL (not WARN) when go is absent, and specs/NODE.md layers 10 and 00 were both corrected in the same change.

Overall: FAIL ✗
