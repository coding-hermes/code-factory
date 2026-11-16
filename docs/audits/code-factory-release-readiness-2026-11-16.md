# Release readiness — code-factory, pass 2026-11-16 (tick `code-factory-releng-2026-11-16-13-17-49`)

**Decision: NO-GO for any tag or Release.** This is a first publication on a channel that has
never been used (zero GitHub Release objects), and no repository-owned release contract exists.
The code gates are green at the candidate below; the decision is about authority and contract, not
about code quality.

## Target and identity

| Item | Measured value | How |
|---|---|---|
| Forge repository | `coding-hermes/code-factory` (public, MIT) | `gh repo view --json nameWithOwner,visibility,licenseInfo` |
| Forge default branch | `main` | `gh repo view --json defaultBranchRef` |
| Release remote alias | `origin` (`git@github.com:coding-hermes/code-factory.git`) | `git remote -v` |
| Other remotes | `gh` (https) and `worker` (ssh) → the same repository | `git remote -v` |
| Canonical checkout | `$HOME/code-factory` (HEAD == origin/main, clean) | `git rev-parse`, `git status --porcelain` |
| Candidate (green) | `74c973afc7eae1647db1a16be31e2137d483e4df` | `git ls-remote origin refs/heads/main` |
| Existing remote tags | **none** — `git ls-remote --tags origin` is empty | `git ls-remote --tags origin` |
| Existing GitHub Releases | **none** — `gh release list` is empty | `gh release list --repo coding-hermes/code-factory` |

Local-only `safety-code-factory-align-20261101` and `safety-cf-main-strand-20261103` are working
tags that were never pushed; they are not release identity.

## Why this is a first publication, and why that is an owner gate

`gh release list` returns zero rows. The publisher/asset path has therefore never executed on this
repository, whatever the commit count says. Per the release lane's own contract, a first
publication requires an explicit owner statement naming the version and the baseline SHA — a lane
template that recites "create the tag, then `gh release create`" is not that statement.

The repository also has no release contract to execute:

- no version surface (`VERSION`, `pyproject.toml`, `package.json`, `go.mod`, `Cargo.toml` — none tracked);
- no `CHANGELOG.md` and no release-notes source;
- no release tooling (`Makefile` release target, `goreleaser.yml`, `Dockerfile`, `scripts/release*` — none);
- no tag-triggered workflow: `.github/workflows/selftest.yml` runs on `push`/`pull_request` and does not publish.

**Proposed version, stated separately from the decision: `v0.1.0`.** It is a proposal only. The
commit census below does not authorize it.

## Commit census

Baseline: there is no tag and no changelog anchor on the remote, so the census runs over the whole
history of the default branch (`git log --no-merges`, 1 247 commits).

| Class | Count | Rule |
|---|---|---|
| `feat:` | 39 | minor |
| `fix:` / `perf:` | 141 | patch (material) |
| `docs:` / `test:` / `chore:` / `ci:` / `build:` / `style:` / `refactor:` / `revert:` | 481 | non-material |
| Non-conventional subjects | 586 | inspected: dominated by `board:` (465) and bookkeeping (`handbook` 29, `sync` 8, `cf2a` 7, …) |
| `BREAKING CHANGE` / `type!:` | **0** | no major proposal is on the table |

Total classifies to 1 247. No breaking declaration exists anywhere in the history.

## Gates

| Gate | State | Receipt |
|---|---|---|
| Hosted CI at candidate | **GREEN** | run `43887027423` on `74c973af` — jobs `secrets (gitleaks): success`, `selftest: success` |
| Hosted CI history (20 runs) | 8 success / 11 failure / 1 cancelled; every run from `2026-11-16T01:34Z` through `7d1dac3e` failed (16 failures + 1 cancelled) on the same two deterministic arms | `gh run list --limit 25 --json createdAt,conclusion,headSha` |
| Repo self-test `bash tests/selftest.sh` | PASS, exit 0 | Tier-1 guard log `guard-20261116T143316.429273Z.log` (tests lane, full mode) at the fix tree; hosted job repeats it |
| Conformance bundle runner | clean — 13 pinned artifacts, 18 bindings, 16 negative arms, 12 digest checks | `python3 <runner.program> docs/handbook/conformance/manifest.json` |
| Handbook spine | `chapters=13 canonical contracts=18 findings=0` | `python3 scripts/handbook_spine.py` |
| Tree secret scan | clean | `gitleaks dir --config .gitleaks.toml .` |
| GitReins (candidate chain) | **no release-grade PASS.** Newest verdict scoring the chain is `11f21136` at `dfdd4845` — `passed: false` (tier-1 reds that are now fixed, tier-2 INCOMPLETE on its resource cap). `cae10cdd` at `772120fa` is false; the newest true verdict, `e946ef98` at `176378c1`, is far behind | `.gitreins/history/2026-11-16/*/verdict.json` |
| Dogfood | **UNVERIFIED for this candidate.** Newest walk is `docs/audits/code-factory-dogfood-2026-11-08-04-02-17.md` pinned to `40db7d8c`, eight days behind | file header |

The two reds that had held main hostage were measured, named and fixed in this pass:

1. `F841` unused `revision` in `scripts/build_book.py:1022` — fixed in `303e7515` (sibling commit, same
   root cause as this lane's first attempt; this lane kept theirs and dropped its duplicate).
2. `CF-050 publish paths — baseline 0, current 2` for `docs/handbook/PASS7-PLAN.md` and
   `docs/handbook/conformance/manifest.json` — fixed in `74c973af`: both absolute `/home/<user>/`
   paths are now `$HOME/...`, meaning and digests unchanged (the conformance runner still reports a
   clean bundle, which is the check that would have caught a digest drift).

## Public posture

| Item | Finding |
|---|---|
| License | MIT, present in `LICENSE` and on the forge |
| Secret scanning / push protection | enabled / enabled; Dependabot security updates **disabled** |
| Secret-scanning alerts | 1 historical (`slack_api_token`, 2026-11-02 → resolved 2026-11-04), 0 open |
| Branch protection on `main` | **absent** — `gh api .../branches/main/protection` returns 404 "Branch not protected" |
| Host-home paths in the published tree | 2 found, both fixed at `74c973af`; the CF-050 gate is green |
| Remote refs | 95 non-default branches; 926 commits unreachable from `main` |
| Secret history on `origin/master` (772 commits ahead of `main`) | **547 gitleaks findings across 64 commits** in `origin/main..origin/master`: `sk-api-key` 509, `generic-api-key` 27, `private-key` 5, `slack-bot-token` 3, `github-pat` 3 — concentrated in `monitoring/.coding-hermes/board/tasks.jsonl` (524) plus scanner fixtures under `.hermes/scripts/` |
| Internal endpoints in the published tree | none beyond documentation of `CRIER_URL`/`BUNKER_SERVER` variables; no live host, port or credential is named |

The `origin/master` figures are why a first tag is not a code decision: a tag brands the whole remote,
not only the default-branch tree. Whether those 547 hits are live credentials or redacted fixtures
must be settled by an owner-side scan before any Release object exists.

## Known issues (to carry into the eventual release notes)

- `CF-450` — hosted CI red: two deterministic arms, both fixed here; the row closes on run `43887027423`.
- `CF-451` — `ruff format` drift on 18 tracked python files: any commit staging one of them is refused by
  the tier-1 lint lane until the tree is formatted (pending, P3).
- `CF-445` — selftest section 56's `pi-agent --check` arm flaked once in two runs at one commit (pending).
- `CF-444` — the tier-2 judge can wedge past `hook_timeout` and produce no verdict artifact (pending).
- `CF-389` / `CF-181` — verdict artifacts are not tracked in the published tree, so verdict-binding
  sweeps read vacuously at any ref (pending).
- `CF-452` — this readiness decision and its unblock path (filed by this pass).
- `CF-453` — public-remote posture: stale branches and the `origin/master` secret history (filed by this pass).

## Blockers and unblock path

1. **Owner authorization for a first publication.** A statement naming the version and the baseline
   SHA. Nothing in this lane, this prompt, or the board substitutes for it.
2. **A repository-owned release contract** committed to the tree: version scheme and version surface,
   what a tag means, where release notes come from, what triggers publication, and the artifact
   procedure (build, checksums, install smoke).
3. **`origin/master` exposure settled** — scan and classify the 547 findings, then delete or retain the
   lineage deliberately (owner-run; this lane does not delete refs).
4. **Branch protection decided** — `main` currently accepts direct pushes with no required checks.

## What this pass mutated

- `74c973af` — the two path spellings in `docs/handbook/PASS7-PLAN.md` and
  `docs/handbook/conformance/manifest.json` (pushed to `origin/main`, hosted CI green).
- This artifact, plus the board rows it names (pushed separately).
- Nothing else: no tag, no Release, no branch deletion, no force-move, no dependency change.

## Re-measurement — tick `code-factory-releng-2026-11-16-16-59-41` (candidate `8f05a4a9`)

Decision unchanged: **NO-GO**. Zero remote tags and zero GitHub Releases still; still no release
contract in the tree. The measurements below replace the ones above wherever they disagree.

| Item | Pass 13:17 at `74c973af` | This pass at `8f05a4a9` | How |
|---|---|---|---|
| Candidate | `74c973af` | `8f05a4a961c8e378559af479b502c2453360a3a1` | `git ls-remote origin refs/heads/main` |
| Hosted CI at candidate | run `43887027423` green | run `43936119176` green (jobs `secrets (gitleaks)`, `selftest` both success) | `gh run list --json databaseId,headSha,conclusion` |
| Repo self-test | guard log at the fix tree | **PASS, exit 0 from a clean clone** — `git clone` of `origin` into a scratch dir, `bash tests/selftest.sh`, 815 log lines, final line `SELFTEST: PASS` | `git clone … && bash tests/selftest.sh; echo EXIT=$?` |
| Tree secret scan | `gitleaks dir` at the working copy | **clean** — `gitleaks dir --redact --config .gitleaks.toml .` on the clean clone: `scanned ~4407264 bytes (4.41 MB)`, `no leaks found`, exit 0 | same |
| Remote non-default branches | 95 | **97** (98 heads total; `origin/main` is the default) | `git ls-remote --heads` |
| Commits unreachable from `main` | 926 | **928** | `git rev-list --count <non-main tips> --not origin/main` |
| `origin/main..origin/master` secret history | 547 findings / 64 commits | **547 / 64, unchanged** — `sk-api-key` 509, `generic-api-key` 27, `private-key` 5, `slack-bot-token` 3, `github-pat` 3; 524 of them in `monitoring/.coding-hermes/board/tasks.jsonl` | `gitleaks git --log-opts=origin/main..origin/master --report-format json` |
| `origin/master` anonymous reachability | lineage counted only | **confirmed 200** — `https://raw.githubusercontent.com/coding-hermes/code-factory/master/.hermes/fleet.toml` returns HTTP 200, so the internal fleet config on that ref is publicly fetchable | `curl -s -o /dev/null -w '%{http_code}'` |
| Branch protection on `main` | absent (404) | **still absent (404)** | `gh api repos/coding-hermes/code-factory/branches/main/protection` |
| Secret scanning / push protection | enabled / enabled | **enabled / enabled**, 0 open alerts; non-provider patterns **disabled**, validity checks **disabled**, Dependabot security updates **disabled** | `gh api repos/...` → `security_and_analysis` |
| Remote/local tags | 0 remote, 2 local `safety-*` | **same** — `git ls-remote --tags` empty, `git tag` lists only the two unpushed `safety-*` working tags | both |

### Correction to this artifact's own posture claim

The table above said *"Internal endpoints in the published tree: none beyond documentation of
`CRIER_URL`/`BUNKER_SERVER` variables; no live host, port or credential is named."* **That claim is
false, and it was false when it was written.** `docs/handbook/appendices/units/36-scripts-verify-node-sh.md`
publishes a live private host three times — the address `192.168.123.66` (lines 100, 101, 109) and its
gateway port `:10800` (lines 101, 109) — and the file was already present at `74c973af`. It entered at
`5186ee07` and `014ddca5` (the CF-050 gate fix) rewrote `/home/<user>/` paths in that same file without
noticing the address.

The tree is right and the prose was wrong. Filed as **CF-470**: the CF-050 publish gate tests
`/home/<user>/` spellings only, so private IPv4 ranges and gateway ports pass it. That is the same
argument CF-050 already settled for host-home paths; the pattern set simply never grew to cover them.

### What this pass mutated

- This appended section, and the board rows it refreshes (`CF-452`, `CF-453`) plus the new `CF-470`.
- Nothing else: no tag, no Release, no ref deletion, no version surface, no dependency change.
- The clean clone, the gitleaks JSON report and the selftest log live under
  `~/.hermes/cache/scratch/cfdb-releng-20261116T165941/`, outside the published tree.
