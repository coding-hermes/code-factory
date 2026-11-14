# code-factory — releng lane report, 2026-11-14

Tick: `code-factory-releng-2026-11-14-11-02-54`.
Lane: releng — release readiness and the state of the tree.
Verdict: **NO CUT. The tree is red at the published tip and the repository has no hosted CI at all, so
no exact-SHA gate can certify a tag. This is also a first-publication case (0 tags, 0 Releases), which
needs an owner decision on the version scheme before anything is tagged (CF-161).**

## 1. Identity and certified candidate

| Item | Value |
| --- | --- |
| Release remote | `origin` — `git@github.com:coding-hermes/code-factory.git` |
| Forge / client | GitHub / `gh` |
| Forge repo | `coding-hermes/code-factory` — `private=false`, `visibility=public`, MIT |
| Forge default branch | `main` (`gh repo view --json defaultBranchRef`) |
| Certified candidate | `771802962c4f76e836e6149c918b32d5888ff5b0` — `origin/main` at the final re-anchor of this pass |
| Verification tree | detached worktree at `origin/main`, shared checkout not used |
| Prior release baseline | **none** — `git ls-remote --tags origin` returns 0 refs; `gh release list` is empty |

The shared checkout moved twice during this pass (`aacce7fe` → `fce3b06a` → `99ea07d7`) while a
sibling P5G-07 lane committed and pushed. All numbers below were measured in the detached worktree
at the candidate, not in the shared checkout, so they describe the commit a cloner gets.

Two local tags exist (`safety-cf-main-strand-20261103`, `safety-code-factory-align-20261101`) and
neither is published; no clone of the remote can resolve them. That is the CF-161 finding, still open.

## 2. Commit census

No tag exists, so the census range is the whole of `main` (first release, no baseline):

| Field | Value |
| --- | --- |
| Commits on `main` | 1229 |
| First / tip authored | `2026-10-29 13:53:07` / `2026-11-14 06:52:34` |
| `feat` | 38 |
| `fix` | 124 |
| `perf` | 5 |
| `test` | 13 |
| `docs` | 246 |
| `chore` | 183 |
| `board` | 437 |
| `handbook` | 29 |
| `merge` / `sync` / `style` / `harness` | 30 / 8 / 8 / 3 |
| Non-conventional subjects | 83 |
| `type!:` subjects | 0 |
| `BREAKING CHANGE` bodies | 0 |

Bump rule: first publication has no baseline to bump from; material change is 38 `feat` + 124 `fix`,
so the semver-consistent first tag is **`v0.1.0`** (pre-1.0, no declared public API). Per CF-161 AC1
the version scheme itself is an **owner decision** and is not being assumed here.

## 3. Build and gate

```
git worktree add --detach <scratch>/cf-releng-wt origin/main
cd <scratch>/cf-releng-wt && bash tests/selftest.sh
```

| Field | Value |
| --- | --- |
| Tree under test | `99ea07d7` (detached at `origin/main`, clean) |
| Sections | 68 |
| `PASS` rows | 554 |
| Verdict line | `SELFTEST: FAIL (3)` |
| Exit code | 1 |

The three counted failures — each is an assertion, not quoted fixture output:

1. `§15 CF-276` — `staged node-bus-worker.py is not usable at the crier probe path`
2. `§54 CF-354` — `the dispatch encoding on the receiving side (tests/test_bus_dispatch_encoding.py)`
3. `§57 CF-275` — `the brief digest binding on the receiving side (tests/test_brief_digest_binding.py)`

Direct pytest run of the two receiving-side suites at the candidate:

```
python3 -m pytest tests/test_bus_dispatch_encoding.py tests/test_brief_digest_binding.py -q
3 failed, 8 passed, 2 skipped, 12 subtests passed
AttributeError: 'RecordingIdentity' object has no attribute 'harness_version'
  scripts/node-bus-worker.py:1239
```

This is CF-434 (open, P1, unowned). The same three failures reproduce at the previous tip
`aacce7fe`, so they are not caused by the two bookkeeping commits that landed mid-pass.

`§61` publish-path gate (CF-050) is green at the candidate: baseline 0, current 0.

## 4. Hosted CI — ABSENT

| Probe | Value |
| --- | --- |
| `gh api repos/coding-hermes/code-factory/actions/workflows --jq .total_count` | `0` |
| `gh api repos/coding-hermes/code-factory/actions/runs --jq .total_count` | `0` |
| `.github/` directory in the published tree | absent |

There is no workflow, so there is no exact-SHA hosted gate to be green at a tag. Recorded as
ABSENT/UNVERIFIED, not green. Local self-test and GitReins do not substitute for it. Filed as
CF-435.

## 5. GitReins

Latest verdicts bind to commits behind the candidate and are **degraded evidence**, not
release-grade:

| Field | Value |
| --- | --- |
| Verdict file | `.gitreins/history/2026-11-14/c541dab7/verdict.json` (`6d624689`) |
| tier1 | `passed=false` — `lint` PASS, `secrets` PASS, `tests` FAIL |
| tier2 | `INCOMPLETE` (evaluation ended before the criterion was judged) |
| `pass_class` / `merge_recommendation` | `judged` / `no_concerns_found` |

A top-level tier-2 `no_concerns_found` beside a red tier-1 `tests` stage and an INCOMPLETE tier-2
criterion is not a release-grade pass. No verdict exists for the candidate `99ea07d7`.

## 6. Dogfood

Newest battery artifact is `docs/audits/code-factory-dogfood-2026-11-08-04-02-17.md`. There is no
dogfood run at the candidate; classified **STALE**, not PASS.

## 7. Public posture

| Item | Measured | Status |
| --- | --- | --- |
| LICENSE | MIT (`licenseInfo.key=mit`, `LICENSE` tracked) | OK |
| gitleaks, working tree at the candidate (`gitleaks dir . --no-banner --redact`) | `no leaks found`, 4.14 MB scanned, rc=0 — a directory scan: `--log-opts` does not apply and no revision range is claimed | OK |
| gitleaks, `main` history (`--log-opts=origin/main`, 1173 commits) | `no leaks found`, 32.47 MB scanned, rc=0 | OK |
| gitleaks, `master` history (`--log-opts=gh/master`, 736 commits scanned) | `leaks found: 547` | **FAIL — CF-163 (P1, open)** |
| `master` ref | 772 commits, **not** an ancestor of `main` (`gh/main...gh/master` = 1229 / 772) | **FAIL — internal lineage published** |
| Secret scanning | `enabled` | OK |
| Secret scanning push protection | `enabled` | OK |
| Secret scanning non-provider patterns | `disabled` | gap |
| Secret scanning validity checks | `disabled` | gap |
| Branch protection on `main` | `404 Branch not protected` | **FAIL — filed as CF-436** |
| Dependabot security updates | `disabled` | **FAIL — filed as CF-436** |
| `§61` host-home publish gate at candidate | baseline 0 / current 0 | OK |
| Release tooling | no Makefile, no `release*` script, no goreleaser/Dockerfile, no VERSION/CHANGELOG, no pyproject/package.json | **absent — CF-161** |

The product history on `main` is clean. The public posture failure is the second lineage: every
clone of this public repo can fetch `master` and its 547 secret-scan hits. Removing a ref is an
irreversible owner-authorized act (CF-163 AC1), so it was not touched.

## 8. Decision

**No release is cut. No tag is created and no Release object is published.**

Blockers, in unblock order:

1. **CF-434 (P1, open)** — red `tests` stage at the candidate; 3 named tests fail. Nothing can be
   certified while the tree's own gate is red, and every worker verdict in this repo inherits it.
2. **CF-276 (P1, open)** — `node-create.sh` stages `node-bus-worker.py` where the crier probe cannot
   use it; third counted self-test failure.
3. **CF-435 (filed this pass, P1)** — no hosted CI exists, so a tag can never be exact-SHA verified.
4. **CF-161 (P3, open)** — no release contract: no version scheme, no VERSION/CHANGELOG, and two
   unpublished local `safety-*` markers. AC1 is an owner decision.
5. **CF-163 (P1, open)** — the `master` lineage publishes internal material with 547 secret hits.
6. **CF-436 (filed this pass, P3)** — `main` is unprotected and Dependabot security updates are off.

First publication is also, by itself, an owner-confirmation case: the repository has zero tags and
zero Release objects, so publishing `v0.1.0` opens a distribution channel that has never existed.
Proposed scheme, awaiting the owner: `v0.1.0`, pre-1.0 semver, tag only on a commit whose selftest,
hosted CI, and tier-1 GitReins `tests` stage are all green.

## 9. What was not mutated

No tag created or moved. No GitHub Release created. No branch deleted. `master` untouched. No
worker dispatched (the tier-1 `tests` stage is red for every commit, so a dispatched worker could not
earn a green verdict — CF-434 is the prerequisite, not a parallel task). The only writes are this
artifact and the two board rows named above.

## 10. Reproduce

```bash
git ls-remote --tags origin | wc -l                       # 0
gh api repos/coding-hermes/code-factory/actions/workflows --jq .total_count   # 0
gh release list --repo coding-hermes/code-factory --limit 5                   # empty
gh api repos/coding-hermes/code-factory/branches/main/protection              # 404
git rev-list --count gh/master                            # 772
gitleaks detect --source . --redact -c .gitleaks.toml --log-opts=gh/master    # prior-pass receipt: 547
bash tests/selftest.sh                                    # final clean-tree probe: SELFTEST: FAIL (4)
python3 -m pytest tests/test_bus_dispatch_encoding.py tests/test_brief_digest_binding.py -q
```

## 11. Final re-anchor correction

The published tip advanced from `99ea07d7` to `77180296` with bookkeeping/docs commits during this
pass, then this report carrier advanced it to `3a3872cb`. The report header and final decision are bound
to `771802962c4f76e836e6149c918b32d5888ff5b0`; `3a3872cb6989bcefd616d678c0d56e04b9108772` is the
report-only carrier. The clean detached selftest at `77180296` was re-run and returned exit 1 with
`SELFTEST: FAIL (4)`: the two receiving-side suites fail through `AttributeError: RecordingIdentity`
missing `harness_version` in `scripts/node-bus-worker.py:1239`, and the CF-150 occupied-port arm also
fails when auth is absent. This final result supersedes the earlier three-failure summary above.

The final commit census is 1232 commits total (1175 non-merge), with 38 feat, 125 fix, 5 perf, 247
docs, 13 test, 183 chore, 439 board, 29 handbook, 153 other/non-conventional; no bang-marked breaking
subjects or `BREAKING CHANGE:` footers were found. The repository still has 0 published tags, 0 GitHub
Releases, no release tooling or version manifest, no `.github/workflows`, and no exact-SHA hosted CI.
No tag or Release was created. The final report carrier is docs-only and its own exact-SHA hosted CI is
ABSENT (no workflows exist), not green. The report artifact's final remote SHA-256 is recorded by the
carrier readback; board row mutation and DuckBrain memory write/readback were not completed in this tick.


## 12. Gate repair pass (same tick id, re-fired)

Pass 1 published this file while recording `SELFTEST: FAIL (4)` at `054f6818`. One of those four was
this artifact itself: section 34 (`scripts/check_scan_scope.py`, CF-163 AC3) failed with
`RESULT: FAIL (3 violation(s))` naming the posture table at lines 125-127, because those rows quoted
secret-scanner runs without the literal `--log-opts` scope the checker requires. The repair names the scope
in the rows above; the checker's rule was not weakened, and no other conclusion changed. It landed as
`70651a51` (`docs(releng): name the scan scope in the 2026-11-14 posture table`).

| Probe | At `054f6818` (pass 1) | At `70651a51` (this pass) |
| --- | --- | --- |
| `bash tests/selftest.sh` from a clean worktree | `SELFTEST: FAIL (4)` | `SELFTEST: PASS`, 68 sections, 563 `PASS` lines, rc=0 |
| `python3 -B scripts/check_scan_scope.py .` | `RESULT: FAIL (3 violation(s))` | `RESULT: OK` — 22 claims name their `--log-opts` |
| `gitleaks dir . --no-banner --redact` (clean worktree; `--log-opts` n/a — not a history scan) | `no leaks found`, 4.14 MB | `no leaks found`, 4.14 MB (4,142,749 bytes, 1.27s) |
| `gitleaks detect --source . --redact -c .gitleaks.toml --log-opts=origin/main` | clean, 1173 commits, 32.47 MB | clean, 1175 commits, 32.48 MB (32,478,690 bytes, 1.47s) |

Structural build, re-derivable: this repo ships no compiled artefact (0 `.go`/`.rs`/`.c` files, no
`Makefile`, no `go.mod`/`package.json`/`pyproject.toml`), so "builds" means the interpreters accept the
tree. `bash -n` over all 45 tracked `*.sh` → 0 failures; `python3 -m py_compile` over all 79 tracked
`*.py` → 0 failures, with one pre-existing cosmetic `SyntaxWarning` at `scripts/build_book.py:457`
(`"\s"` inside an embedded JS string; not a gate).

What closed the red between passes was the sibling CF-434 row, not this lane: `4d93aab4` ("CF-434:
stage harness_memory with the node transport; mirror identity fields in fixtures") landed at
13:30:45Z with its own green tier-1, repairing the staging leg (CF-276) and the two receiving-side
suites that pass 1 reported. This pass re-verified that commit from a clean worktree rather than
trusting the sibling's claim.

Release decision — **NO CUT**, unchanged, with the mechanical blocker now retired. The red gate pass 1
cited is gone, so the two load-bearing blockers are the only ones left:

1. CF-161 (P3, open) — the release contract is an OWNER DECISION ("what a version means, which commits
   are taggable, and whether the factory releases at all"). Zero tags exist; a first version number
   cannot be invented by a lane.
2. CF-435 (P1, open) — the repo has no hosted CI (0 workflows, 0 runs), so no exact-SHA hosted check
   can certify a tag. The local tier-1 guard that produced the `PASS` above is not that check.

The green precondition was recorded as a note on CF-161 so the owner's decision is the only thing
between this tree and a first tag. Posture was re-measured and is unchanged from section 7: secret
scanning and push protection enabled; non-provider patterns, validity checks and Dependabot security
updates disabled (CF-436); `main` unprotected, 404 (CF-436); the published `master` lineage still
carries 547 findings across 736 scanned commits (CF-163, P1). License MIT, public, no wiki.

No tag, no GitHub Release, no board row flipped complete by this lane.
