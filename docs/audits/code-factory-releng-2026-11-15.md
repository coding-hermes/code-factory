# code-factory — releng lane report, 2026-11-15

Tick: `code-factory-releng-2026-11-15-12-25-30`.
Lane: releng — release readiness and the state of the tree.
Verdict: **NO CUT.** The tree is green and the hosted gate now exists and is green at the exact tip,
but a first publication is an owner decision with no release contract in the repo (CF-161), the public
repository still publishes an internal `master` lineage with 547 secret-shaped hits (CF-163, P1 open),
and main carries neither branch protection nor a release script. Nothing was tagged and no Release was
created; the repository still has **0 tags and 0 Releases**.

## 1. Identity and certified candidate

| Item | Value |
| --- | --- |
| Release remote | `origin` — `git@github.com:coding-hermes/code-factory.git` |
| Forge / client | GitHub / `gh` |
| Forge repo | `coding-hermes/code-factory` — `visibility=public`, `private=null`, MIT |
| Forge default branch | `main` |
| Certified candidate | `91ab2abfec192b7f67ade160af065ee8cdaf8e43` — `origin/main` at measurement (2026-11-15T13:2xZ) |
| Verification tree | detached worktree `<scratch>/cf-releng-wt-1115` at `origin/main`, shared checkout not used for grading |
| Prior release baseline | **none** — `git ls-remote --tags origin` returns 0 refs, `gh release list` is empty, `gh api …/tags` length 0 |

Two local tags exist (`safety-cf-main-strand-20261103`, `safety-code-factory-align-20261101`); neither is
published, so no clone of the remote can resolve them (CF-161).

## 2. Commit census

No tag exists, so the census range is the whole of `main` (first release, no baseline):

| Field | Value |
| --- | --- |
| Commits on `main` | 1268 |
| First / tip authored | `2026-10-29 13:53:07` / `2026-11-15 07:11:27` |
| `board` | 453 |
| `docs` | 256 |
| `chore` | 185 |
| `fix` | 131 |
| `feat` | 38 |
| `merge` / `handbook` | 31 / 29 |
| `test` | 13 |
| `sync` / `style` / `perf` | 8 / 8 / 5 |
| Non-conventional subjects | 84 |
| `type!:` subjects | 0 |
| `BREAKING CHANGE` bodies | 0 |

Bump rule: a first publication has no baseline. Material change is 38 `feat` + 131 `fix`, so the
semver-consistent first tag would be **`v0.1.0`** (pre-1.0, no declared public API) — the 2026-11-14
pass reached the same number from the same rule. Per CF-161 AC1 the version scheme itself is an
**owner decision** and is not assumed here.

## 3. Build and gate

```
git worktree add --detach <scratch>/cf-releng-wt-1115 origin/main
cd <scratch>/cf-releng-wt-1115 && bash tests/selftest.sh
```

| Run | Command | Result |
| --- | --- | --- |
| A (first) | `bash tests/selftest.sh` | `SELFTEST: FAIL (1)`, exit 1 — 562 PASS lines, one red section |
| B (re-run) | `bash tests/selftest.sh` (260 s) | **`SELFTEST: PASS`**, exit 0 — 563 PASS lines |
| Arm alone | `bash tests/harness/adapter-check-classification-test.sh` | `RESULT: PASS` — 6 passed, 0 failed, 0 skipped |

The single red in run A was section 56's nested arm:

```
56. a foreign harness is measured in a node, and verify-node.sh re-measures what the manifest records (CF-006)
  FAIL  the adapter --check classification test did not pass (exit 1)
    |   FAIL  pi-agent: --check did not reach PASS beside a credential file (rc=3)
```

The same arm passes standalone (6/6) and passes inside run B at the same commit, so this is a
**flake in the section-56 arm, not a deterministic red**: 1 red in 2 full-suite runs at `91ab2abf`.
It is filed as CF-445 rather than being allowed to sit unnamed. The suite is therefore green at the
candidate, with a known one-in-two flake in one arm.

### Hosted gate (new since the 2026-11-14 pass)

CF-435 landed `.github/workflows/selftest.yml` on 2026-11-15 01:15, so an exact-SHA hosted gate now
exists where the 2026-11-14 pass recorded 0 workflows / 0 runs.

| Field | Value |
| --- | --- |
| Workflow run | `43712877605` (`selftest.yml`, event `push`, branch `main`) |
| Head SHA | `91ab2abf` — the certified candidate |
| `secrets` (secret-scan job) | completed/success, 12:15:13Z → 12:15:20Z |
| `selftest` | completed/success, 12:15:13Z → 12:17:16Z |
| Coverage note | the job installs the same two host pins the control host carries (go1.26.5, ruff 0.15.22) and runs the full `bash tests/selftest.sh`; it does not provision a node, reach a bunker, or call a model |

`gh run view --log` for that run returned no log body in this environment, so the job conclusions are
quoted from the run's job metadata (`--json jobs`), not from the job log text.

### gitreins

| Field | Value |
| --- | --- |
| Run | `.gitreins/history/2026-11-15/2a51f23a/verdict.json` |
| Commit | `91ab2abfec192b7f67ade160af065ee8cdaf8e43` |
| merge_recommendation | `no_concerns_found` |

## 4. Release tooling

Checked at the candidate and in the repository root — **none present**:

| Probe | Result |
| --- | --- |
| `Makefile` | absent |
| `goreleaser.yml` / `.goreleaser.yml` | absent |
| `Dockerfile` | absent |
| `pyproject.toml` / `package.json` | absent |
| `CHANGELOG.md` / `VERSION` | absent |
| `scripts/release*`, `scripts/*release*` | absent |
| `docs/RELEASE.md`, `specs/RELEASE.md`, `docs/release*` | absent |

This is a shell + spec + board repository: the releasable artifact is the tree itself, and no script,
version file, changelog or release document exists to publish it. A tag cut today would be a label on
a commit with no artifact path and no notes source — that is CF-161, still open.

## 5. Public posture

| Check | Measured | Status |
| --- | --- | --- |
| License | `LICENSE` — MIT License, `license.spdx_id=MIT` | PASS |
| Secret scanning | `security_and_analysis.secret_scanning.status=enabled` | PASS |
| Push protection | `secret_scanning_push_protection.status=enabled` | PASS |
| Dependabot security updates | `disabled` | **FAIL** — CF-436 |
| Branch protection | `branches/main/protection` → 404 "Branch not protected" | **FAIL** — CF-120 / CF-436 |
| Repository rulesets | `repos/.../rulesets` → `[]`; `repos/.../rules/branches/main` → `[]` | **FAIL** — no rule of any kind |
| `SECURITY.md` / `CONTRIBUTING.md` / `CODE_OF_CONDUCT.md` | absent | gap (no row yet) |
| Root scan config | present (the dot-prefixed scanner config); CI applies it to the tree | PASS |
| Tracked tree at HEAD | secret-scan job on `91ab2abf` success; ABS-path arm reports 0 | PASS |
| Published `master` lineage | tip `4ead64f`, **772** commits not reachable from `main`, publicly fetchable | **FAIL** — CF-163 (P1) |

### The public `master` lineage (CF-163 re-measured)

CF-163 is still live at this candidate. Re-measured now, not quoted from the row:

| Measurement | Value |
| --- | --- |
| `git ls-remote gh refs/heads/master` | `4ead64fee7b2bb8f66639cbc3b1de606a9ffcef3` |
| Commits on `master` not reachable from `main` | **772** |
| `git merge-base --is-ancestor gh/master origin/main` | false |
| `gitleaks git --log-opts=origin/main..gh/master` | **547 leaks**, exit 1, 35.6 s, 48.58 MB scanned |
| Commits carrying hits | **64** |
| Rules | 509 `sk-api-key`, 27 `generic-api-key`, 5 `private-key`, 3 `slack-bot-token`, 3 `github-pat` |
| Noisiest files | `monitoring/.coding-hermes/board/tasks.jsonl` (524), `.hermes/scripts/test_secret_scrub.py` (6), `…scan-git-secrets.py` (6) |

Every count matches the 2026-11-06 re-verification of the same row, so the corpus has not changed —
but neither has it been removed. Deleting a published ref is an owner-authorized irreversible act
(CF-163 AC1), so this lane does not touch it.

## 6. Board state behind the decision

| Row | Priority | Status | What it blocks |
| --- | --- | --- | --- |
| CF-161 | P3 | pending | The release contract: version scheme, taggable commits, whether the factory releases at all. AC1 is an **owner decision** and the closing event must record it. |
| CF-163 | P1 | pending | Public posture: 772 internal commits + 547 hits published on `master`. Needs owner authorization to delete the ref. |
| CF-436 | P3 | pending | main unprotected, Dependabot security updates disabled. |
| CF-120 | P3 | pending | No branch protection / no ruleset on the public repo every lane pushes to. |
| P5G-30 | P1 | pending | The spec's own release gates and disposition evidence. |

CF-435 (hosted CI) is now closed by measurement rather than by claim: the workflow exists and both
jobs are green at the candidate.

## 7. Decision

**NO CUT.** In order:

1. **First publication has no authorization.** 0 tags, 0 Releases, no `VERSION`, no `CHANGELOG`, no
   release script or document, and CF-161 AC1 makes the version scheme an explicit owner decision.
   A tick doing the release steps is not that authorization.
2. **The public posture is compromised at the same remote.** `master` publishes 772 commits of
   internal fleet material (`.hermes/`, `monitoring/`, `crier-*`, `get-h3/`, `worktrees/`) with 547
   secret-shaped hits across 64 commits. Tagging a first public release while that lineage is
   fetchable brands a release on a repository that leaks its own operators' corpus.
3. **No release artifact path exists.** With no Makefile, goreleaser config, Dockerfile, package
   manifest or release doc, `gh release create` would attach nothing but auto-generated source
   archives — the notes would come from memory, not from board rows.
4. **The gate itself is good enough to tag from, once (1) and (2) are answered.** Tree green at
   `91ab2abf`, hosted `secrets` + `selftest` green at the same SHA, gitreins `no_concerns_found`.
   The only remaining red is a known 1-in-2 flake in section 56's pi-agent arm (CF-445), which does
   not fail the gate deterministically.

### What flips this to CUT

- CF-161 AC1 answered by the owner: version scheme + "does the factory release?" recorded in the row,
  plus a `docs/RELEASE.md` (or `specs/RELEASE.md`) and a `scripts/release.sh` that produces the
  artifact and notes from board rows.
- CF-163 resolved or explicitly accepted by the owner (delete `master`, or preserve it in a private
  mirror named in the row).
- Recommended before tagging, not blocking: CF-436/CF-120 protection on `main` so the tag's commit
  cannot be force-pushed out from under the release.

## 8. Reproduction

```bash
gh release list --repo coding-hermes/code-factory --limit 5      # empty
gh api repos/coding-hermes/code-factory/tags --jq length         # 0
git ls-remote --tags gh                                          # nothing
gh run view 43712877605 --repo coding-hermes/code-factory --json jobs \
  --jq '.jobs[] | "\(.name) :: \(.status)/\(.conclusion)"'
gh api repos/coding-hermes/code-factory --jq \
  '{ss:.security_and_analysis.secret_scanning.status,pp:.security_and_analysis.secret_scanning_push_protection.status,dep:.security_and_analysis.dependabot_security_updates.status}'
gh api repos/coding-hermes/code-factory/branches/main/protection  # 404
gh api repos/coding-hermes/code-factory/rulesets                  # []
git rev-list --count gh/master ^origin/main                       # 772
gitleaks git --log-opts="origin/main..gh/master" --config .gitleaks.toml \
  --no-banner --redact                                            # 547 leaks, exit 1
git worktree add --detach /tmp/cf-releng origin/main
cd /tmp/cf-releng && bash tests/selftest.sh                       # SELFTEST: PASS
```

Evidence artifacts from this pass (host scratch, not tracked): `cf-selftest-1115.log` (run A),
`cf-selftest-1115-rerun.log` (run B), `cf-adapter56.log` (arm alone), and the master-lineage
secret-scan report `cf-master-gitleaks.json` — 547 findings, produced by the `--log-opts=origin/main..gh/master` scan above.

## 9. Re-fire of this tick (2026-11-15T14:10Z)

The same tick id fired a second time, about eighty minutes after the pass recorded above. This section
does not re-derive the audit; it records the material-identity check and the measurements taken at the
second firing, so a later reader can tell "nothing changed" from "nobody looked".

| Check | Measurement at the re-fire | Identity with §1–§7 |
| --- | --- | --- |
| `origin/main` | `3e21bbc4b65063c2c71188727ba1b5d39f5aa5f3` | unchanged — no new commits since the pass |
| Product paths, `91ab2abf..3e21bbc4` | **0** changed (the diff is board JSONL + this audit file only) | the certified product tree is still `91ab2abf`'s |
| Selftest, clean detached worktree at `3e21bbc4` | `SELFTEST: PASS`, exit 0, 563 `PASS` lines | green |
| Hosted CI at `3e21bbc4` | run `43721375277`: `secrets` job — gitleaks `dir` scan whose scope is the checkout's working tree, no `--log-opts` (history not scanned) — success 13:53:41→13:53:48Z; `selftest` job success 13:53:41→13:55:40Z | green, job-level |
| `git ls-remote --tags gh` / `gh release list` | 0 refs / empty | unchanged |
| Rulesets / `branches/main/protection` / Dependabot | `0` / HTTP 404 / `disabled` | unchanged (CF-436, CF-120 live) |
| Secret scanning, push protection, license | `enabled`, `enabled`, MIT | unchanged |
| `gh/master` | `4ead64f`, **772** commits not reachable from `main`, not an ancestor of it | unchanged (CF-163 live) |
| Release tooling at the tip | `Makefile`, goreleaser config, `Dockerfile`, `VERSION`, `CHANGELOG.md`, `scripts/release*`, `docs/RELEASE.md`, `specs/RELEASE.md` — all absent | unchanged (CF-161 open) |

Commit census, re-measured with the same rule as §2 (`--no-merges`, whole of `main`, 1211 subjects —
§2's 1268 counts merges too):

```
feat=38  fix=130  perf=5  chore=185  docs=254  board=454  handbook=29  test=13  sync=8  style=8
type!: subjects = 0        BREAKING CHANGE footers = 0        non-conventional subjects = 53
```

Same bump rule as §2, so the same candidate number: **`v0.1.0`**, and the scheme itself is still
CF-161 AC1's owner decision.

**Decision unchanged: NO CUT**, for the same three reasons in §7 — no owner release contract (CF-161),
the public `master` lineage still fetchable at the same remote (CF-163, P1), and no artifact path to
attach. Nothing was tagged and no Release was created. No board row was changed by this firing: the
pass above already filed CF-445, and CF-161 / CF-163 / CF-436 / CF-120 / P5G-30 were re-read live and
are still `pending`. This firing adds the audit section and no product change.

One gate note, because it is evidence the host gate is live rather than assumed: the commit hook
rejected this section's first draft twice. The CI row above originally named the secret-scan job and
its scanner without naming a scan scope, and section 34's posture-doc checker (CF-163 AC3,
`scripts/check_scan_scope.py`) fails any line that names gitleaks without `--log-opts`. The row now
records the CI job's real scope — a `dir` scan over the working tree, history not scanned — and
`python3 scripts/check_scan_scope.py` returns `OK`. The hook did its job on a docs-only change.

