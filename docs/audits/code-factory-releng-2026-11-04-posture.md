# code-factory — releng lane: tree, gate and public posture

Tick: `code-factory-releng-2026-11-04-10-22-25` (releng lane, family `code-factory`).
Measured 2026-11-04T05:22–05:35 -05:00 from a fresh clone of the public remote
`git@github.com:coding-hermes/code-factory.git`, checked out at published `main` =
`a564cda740decd0355feebe24f52d02d24690021` (`chore(gitreins): publish the PERF-016-RESTORE verdict (PASS at c5f7b2f)`).

## Why the clone

The registered checkout `/home/kara/code-factory` passed the root/remote/operation gate
(`realpath` == `git rev-parse --show-toplevel`, remote
`git@github.com:coding-hermes/code-factory.git`, attached `main`, no rebase/merge/cherry-pick
markers, `gate_violations=0`), and `scripts/board_lock.py` answered `RESIDUE
consumers=0 commits_after_mtime=232` for `.coding-hermes/board/.lock` (a 0-byte file with no
holder and no consumer — not a held lock).

It nevertheless carried 88 untracked `.gitreins/history/**` verdict-bundle paths, and four
sibling family lanes reported `running` from the scheduler API at gate time
(`code-factory-docs` 10-01-07, `code-factory-docs-qa` 09-53-51, `code-factory-perf` 09-53-51,
`code-factory-sync` 09-53-51). No process on the host had a cwd at or under the checkout
(`scripts/checkout-writer-census.sh` → `CENSUS_EMPTY=1`) and no `hermes chat` process existed, so
the untracked bundles are unpublished judge output rather than a live writer — but the family is
shared, so the lane's clone transport was used: the registered checkout was **not** read for state
beyond the gate, not written, and not cleaned. Scheduler locator and published tip were equal
(`a564cda`), so nothing was skipped by cloning.

## Gate (the CI-equivalent: this repo ships no GitHub Actions)

| Check | Command | Result |
|---|---|---|
| Gate at the graded tree | `bash tests/selftest.sh` in the clone at `a564cda` | **`SELFTEST: PASS`, rc=0**, 194 `PASS` rows, 17 s (05:25:28→05:25:45) |
| Red-proof arms intact | same run | the battery's own negative fixtures print their named `FAIL` rows and still exit 0 overall (the gate proves it can go red) |
| Workflow state | `gh run list --repo coding-hermes/code-factory --limit 3 --json …` | `[]`; `.github/workflows` absent — **no CI to query, by design** |
| Board at the graded tree | `wc -l .coding-hermes/board/{tasks,events}.jsonl` | 173 task rows / 340 events at `a564cda`; **174 rows / 341 events** at the landed tip `19e74be` (the sync lane filed CF-199 and published a verdict bundle while this tick ran) |
| Gate re-run after the rebase | `bash tests/selftest.sh` at `ef40b56` (my commit on `19e74be`) | **`SELFTEST: PASS`, rc=0** — the first push was rejected as non-fast-forward, so the commit was rebased onto the six sibling landings and the gate re-run at the rebased head |

## Public posture at `a564cda`

| Leg | Command | Result |
|---|---|---|
| Visibility / license | `gh api repos/coding-hermes/code-factory --jq '{private,visibility,license:.license.spdx_id}'` | `private=false`, `public`, `MIT` — **LICENSE present** (MIT, 2026 coding-hermes contributors) |
| Secret scanning | same `--jq` on `security_and_analysis` | `secret_scanning=enabled`, `push_protection=enabled` — **on** |
| Non-provider patterns / validity checks / dependabot | same | `disabled` / `disabled` / `disabled` |
| Branch protection | `gh api repos/coding-hermes/code-factory/branches/main/protection` | **HTTP 404, rc=1 — ABSENT** (row **CF-120**, still pending) |
| Repo rulesets | `gh api repos/coding-hermes/code-factory/rulesets --jq 'length'` | **0** |
| Credential shapes in the tree | `git grep -oIE '(ghp_\|github_pat_\|sk-\|AKIA\|xoxb-\|BEGIN …PRIVATE KEY)' HEAD` | **0 hits** |
| Absolute host paths | `git grep -oIE '/home/[a-z][a-z0-9_-]*/' HEAD` | **331 files / 1267 hits** (row **CF-050**) |
| … same, excluding `.gitreins` | `… -- . ':(exclude).gitreins'` | 48 files / 157+ hits |
| … excluding `.gitreins` and the board | `… ':(exclude).coding-hermes/board'` | 46 files / **157 hits** |
| Unrelated published lineage | `git ls-remote origin refs/heads/master` | `4ead64f`, **772 commits**, still published (row **CF-163**, P1) |
| Published branches | `git ls-remote --heads origin \| wc -l` | **60** |

Read against the rows already on the board, the posture legs are unchanged in kind and worse in
degree: **no new row is filed** here. What is new is the measurement date and tip.

- **CF-050** was filed on 2026-11-03 at `e1e4bed2` with "27 tracked files, 102 hits". At `a564cda`
  the same probe returns **331 files / 1267 hits** — a ~12x growth in under a day, because every
  `chore(gitreins)` commit publishes another `commit.patch`/`verdict.json` carrying absolute host
  and worktree paths. Excluding `.gitreins`, authored docs alone moved 10 → 46 files.
- **CF-163** (P1) reproduces exactly as filed: `master` is an unrelated lineage of 772 internal
  commits (`.hermes`, `monitoring`, `worktrees`, `get-h3`, `crier-fleet`) fetchable from any clone.
- **CF-120** reproduces exactly as filed: no branch protection and no ruleset on the public `main`
  that nineteen lanes push to directly.

## Release decision: nothing to tag

No release was cut and no tag was pushed. The repo currently exposes **zero** release tags
(`git ls-remote --tags origin | wc -l` → 0; the only local tags are the `safety-*` markers, which
resolve from no clone of the remote). There is no VERSION file, no CHANGELOG and no version scheme,
so "tag from a green commit" has no defined artifact to tag — that is **CF-161**, still pending.
Cutting a tag here would invent a version, and a release/tag row is owner-gated decision work: it
needs explicit authorization naming target, version and baseline SHA. Recorded as
`NO TAG / KEEP PENDING`, owner = repository owner.

## Not run (and why)

| Leg | Reason |
|---|---|
| Reading or writing the registered checkout's board | family clone transport (88 untracked verdict bundles + 4 sibling lanes `running`) |
| `git push` from the registered checkout | not the lane's root this tick; all writes happen in the clone |
| Release tag / CHANGELOG | no release contract (CF-161) and no owner authorization |
| GitHub Actions CI | no workflows exist in this repository |

## Verification addendum — resumed pass (`2026-11-04T05:56-05:00`)

This pass resumed tick `code-factory-releng-2026-11-04-10-22-25` **after** the first execution of the
same tick id had already landed and recorded its receipt (`/code-factory/status/2026-11-04-releng`,
DuckBrain record `ccd77cf6-77f5-411d-b5a2-e3a349b47f0b`, tip `ed883b2`). A resumed tick verifies and
reports; it does not re-execute. So this pass selected no row, dispatched no worker, filed no row,
and minted no second GitReins task for the closed work. It re-measured the receipt's claims at a
**newer** published tip and added the legs the first pass did not run.

Re-verified at published `main` = `d93d98b` (`board: event 354 — QA re-verification of CF-195 at the
published tip`), measured from a throwaway clone; the registered checkout `/home/kara/code-factory`
was again left untouched (it is behind the published tip and still carries untracked
`.gitreins/history/**` bundles; a `gitreins guard` process from a sibling lane was live on the host
during this pass).

| Claim from the first pass | Command (this pass, at `d93d98b`) | Result |
|---|---|---|
| Gate green at the graded tree | `bash tests/selftest.sh` | **`SELFTEST: PASS`, rc=0**, 195 `PASS` rows, 50 intentional negative-fixture `FAIL` rows (~18 s) — also green at `8571bfc` |
| Board valid | `bash scripts/boardctl validate` | `RESULT: OK (4 warning(s))`; the duplicate-event-id 336 warning is the documented legacy residue owned by **CF-196** |
| Evidence artifact published | `git cat-file -e c2e9d43^{commit}`, `git merge-base --is-ancestor c2e9d43 HEAD` | present, ancestor, rc=0 |
| Verdict bundle published | `.gitreins/history/2026-11-04/b4c0b5c4/verdict.json` | `task_id=RELENG-2026-11-04`, `passed=true`, commit `c2e9d43` — resolves from `origin` |
| Branch protection absent (CF-120) | `gh api repos/coding-hermes/code-factory/branches/main/protection` | `HTTP 404 "Branch not protected"`; `rulesets` → `0` |
| Secret scanning on (posture) | `gh api repos/coding-hermes/code-factory --jq '.security_and_analysis'` | `secret_scanning=enabled`, `push_protection=enabled`; non-provider patterns / validity checks / dependabot `disabled` |
| License / visibility | same API call | `license=MIT`, `private=false`, `visibility=public` |
| Zero release tags (CF-161) | `git ls-remote --tags origin \| wc -l` | **0**; no `VERSION`, no `CHANGELOG*` in the tree |
| `master` lineage still published (CF-163) | `git ls-remote origin refs/heads/master` | `4ead64f` — unchanged; 60 published heads |
| CI state | `gh run list --repo coding-hermes/code-factory --limit 3 --json …` | `[]` — no workflows in the repo; the gate is the CI-equivalent |
| Board census | `wc -l` + `jq -r .id \| sort \| uniq -d` | 176 task rows / 355 events; 61 `complete` / 8 `in_progress` / 107 `pending`; **0 duplicate ids** |

### Legs this pass added

1. **The committed credential-shape arm is unusable as written — corrected here.** A bare `sk-`
   pattern matches **275** substrings in the published tree at `d93d98b`, all inside board JSONL
   words (`task-`, `risk-`), so the "0 hits" cell in the first pass cannot be reproduced from its
   own command. The bounded key shapes
   (`ghp_[A-Za-z0-9]{20,}`, `github_pat_[A-Za-z0-9_]{20,}`, `sk-[A-Za-z0-9]{20,}`,
   `AKIA[0-9A-Z]{16}`, `xoxb-[0-9A-Za-z-]{20,}`, `BEGIN [A-Z ]*PRIVATE KEY`) return **0 hits** at
   `d93d98b` — that is the arm to quote from now on (RE2 has no lookbehind, so bound the key shape
   rather than prefixing the pattern).
2. **Absolute host paths, same class, re-measured**: 349 files / 1304 hits across the whole tree;
   **48 files** excluding `.gitreins` and the board (first pass: 331 / 1267 and 46 at `a564cda`).
   Growth is driven by published `chore(gitreins)` bundles. Owned by **CF-050** / **CF-086** — not
   re-filed.
3. **CF-190 reproduced live**: `git ls-remote git@github.com:coding-hermes/code-factory.git
   refs/heads/main` → `git@github.com: Permission denied (publickey)`. Every leg of this pass used
   the https remote instead (clone, fetch, push). Row stays `pending`; no refile — liveness
   confirmation only.
4. **Release decision unchanged**: `NO TAG / KEEP PENDING`. Zero published tags, no version
   artifact, **CF-161** still `pending`, and tag/cut rows remain owner-gated decision work naming
   target, version and baseline SHA.

Negative claims scoped to this pass: no board row created, no worker dispatched, no new GitReins
task, no release tag, no write to the registered checkout.

## Verification addendum — third pass (`2026-11-04T06:00–06:15-05:00`)

This is a **third** execution of tick `code-factory-releng-2026-11-04-10-22-25` (the first execution
landed `c2e9d43` + verdict `RELENG-2026-11-04`; the second wrote the "resumed pass" addendum above and
published verdict `RELENG-ADD-2026-11-04-1022` at `ef9003b`). It resumed after context compaction with
no report emitted, so it **verified and reported** rather than re-executing: no row selected, no worker
dispatched, no row filed, no release tag, no write to the registered checkout.

Measured from a fresh clone of the **https** remote at published `main` = `3f9eb7b`
(`chore(gitreins): publish the RELENG-ADD-2026-11-04-1022 verdict (PASS at ef9003b)`), loadavg
`13.66 10.47 9.50` (host busy — the timing note matters only for wall-clock claims, none are made here).

| Leg | Command (this pass) | Result |
|---|---|---|
| Gate at the graded tree | `bash tests/selftest.sh` | **`SELFTEST: PASS`, rc=0**, **195** `^  PASS` rows, **50** `^  FAIL` rows — every FAIL is a negative fixture (board-parser red proofs, `disk_floor` resolver-removal arm), not a product red |
| Board valid | `bash scripts/boardctl validate` | `RESULT: OK (4 warning(s))`, rc=0 — CF-034 free-form `ci_result`, duplicate event id 336 (CF-196), headerless board, probe outside canon |
| Board census | `wc -l` + `jq -r .id \| sort \| uniq -d` | **176** task rows / **356** events; `complete=61 in_progress=8 pending=107`; **0 duplicate task ids** — and **1 duplicate EVENT id (336)**, the CF-196 residue this section's own validator row names |
| Published tip moved during the tick | `git fetch origin`, `git log HEAD..origin/main` | `3f9eb7b` → **`fe4a24ee`** (`docs(DESIGN): stop presenting three unshipped legs … Addresses CF-202`) — `git diff --name-only 3f9eb7b fe4a24ee -- tests/ scripts/ specs/` = **0**, so the gate numbers above hold at `fe4a24ee` too |
| Release tags | `git ls-remote --tags origin \| wc -l`; `ls VERSION CHANGELOG*` | **0** tags; no `VERSION`, no `CHANGELOG*` |
| CI | `gh run list --repo coding-hermes/code-factory --limit 3 --json …` | `[]` — no workflows ship in this repo; the selftest is the CI-equivalent. **Nothing to flag.** |
| Posture | `gh api repos/coding-hermes/code-factory` | `public`, `private=false`, `license=MIT`, `archived=false`, `default_branch=main` |
| Secret scanning | `--jq .security_and_analysis` | `secret_scanning=enabled`, `push_protection=enabled`; non-provider patterns / validity checks / dependabot security updates `disabled` |
| Open secret-scanning alerts | `… /secret-scanning/alerts?state=open --jq length` | **0** |
| Branch protection / rulesets | `… /branches/main/protection`; `… /rulesets --jq length` | **HTTP 404 "Branch not protected"**; rulesets **0** — reproduces **CF-120** |
| Unrelated lineage | `git ls-remote https://github.com/coding-hermes/code-factory.git refs/heads/master` | `4ead64f` still published; **60** published heads — reproduces **CF-163** (P1) |
| Absolute host paths | `git grep -oIE '/home/[a-z][a-z0-9_-]*/' HEAD` | **1311** hits whole tree, **162** excluding `.gitreins` and the board (last pass: 1304 / 157) — reproduces **CF-050 / CF-086**, not re-filed |

Open rows this pass re-confirmed without refiling: **CF-050** (P3), **CF-120** (P3), **CF-161** (P3,
no release contract), **CF-163** (P1, public `master` lineage), **CF-190** (P4, publish transport).

### New leg 1 — the corrected credential arm still self-matches; scope it, don't widen it

The previous addendum replaced the bare `sk-` pattern with bounded key shapes and quoted **0 hits**.
Re-running that exact combined pattern at `3f9eb7b` returns **2 hits**, and both are the phrase
`BEGIN PRIVATE KEY` with **no key body**:

```
git grep -oIE '(ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|xoxb-[0-9A-Za-z-]{20,}|BEGIN [A-Z ]*PRIVATE KEY)' HEAD
HEAD:.coding-hermes/board/events.jsonl:BEGIN PRIVATE KEY
HEAD:.gitreins/history/2026-11-04/65139ce7/commit.patch:BEGIN PRIVATE KEY
```

Both are this lane's own audit text quoting the pattern (event 355's `detail` and the patch that
publishes it) — the probe matches its own subject. The arm to quote from now on requires the PEM
header with its dashes (`-----BEGIN [A-Z ]*PRIVATE KEY-----`), which returns **0 hits** at `3f9eb7b`;
authored-source credential shapes are therefore **0**, and the class of "audit text poisons its own
probe" is the recurring defect worth naming. No row filed: the posture leg is green, the defect was in
this lane's probe.

### New leg 2 — the publish transport is INTERMITTENT, not deterministically unauthenticated (CF-190 widened)

CF-190 asserts the configured SSH remote exits non-zero with `Permission denied (publickey)` while
https reaches the remote. Eleven probes of the same command at this tip, in two spellings, show
**three outcomes**, so the row's premise is only partly reproducible and the failure mode is wider
than filed:

| Probe form (20 s cap) | Runs | Outcomes |
|---|---|---|
| `git ls-remote git@github.com:coding-hermes/code-factory.git refs/heads/main` (plain) | 6 | 1 × rc=0 success, 1 × rc=128 `Permission denied (publickey)`, 4 × rc=124 (hung, cut by `timeout`) |
| `GIT_SSH_COMMAND='ssh -o BatchMode=yes' …` | 5 | 2 × rc=0, 1 × rc=128 `Permission denied (publickey)`, 2 × rc=124 |
| `https://github.com/…` | 4 | rc=0 on every attempt |
| **Total over `git@github.com`** | **11** | **3 success, 2 auth refusals, 6 hangs** |

`ssh -G github.com` resolves to the host's default identity files, `SSH_AUTH_SOCK` is
`/run/user/1000/openssh_agent` and `ssh-add -l` answers **"The agent has no identities"**, so identity
selection depends on files under a load-saturated host; `core.sshCommand` is unset and no `url.*.insteadOf`
rewrite exists. This clone itself succeeded over `git@github.com` at 05:58, which is why "SSH is broken"
must not be recorded as a boolean. Practical rule for lanes: publish over the **https** remote, always
re-verify `rev-list --left-right --count origin/main...HEAD`, and never read a successful `git push`
invocation as proof of a landed commit. Recorded against CF-190 (widened by the hangs); **no new row**.

### Release decision (unchanged): NO TAG / KEEP PENDING

Zero published tags, no version artifact, and **CF-161** remains `pending`. A tag/cut is owner-gated
decision work naming target, version and baseline SHA; inventing a version from this tree would be a
release claim with no contract behind it.

Negatives scoped to this pass: no board row created, no worker dispatched, no release tag pushed, no
write to the registered checkout `/home/kara/code-factory` (left with its untracked `.gitreins/history`
bundles and 25-commit lag, untouched by this lane).

### Correction — tier-2 judge findings against this section's first draft

The tier-2 verdict for task `RELENG-ADD3-2026-11-04-1022` (run directory
`.gitreins/history/2026-11-04/5f2ae5e4/`, printed id `579d4b53`, `commit=3f22e1f`, `passed=false`)
returned **FAIL / INCOMPLETE** on two grounds. Both were defects in this lane's record, not in the
tree, and both are fixed or superseded here rather than argued with:

1. **"0 duplicate ids" was false as written.** The census command printed above counts
   `tasks.jsonl` ids only, but the cell read as a whole-board claim, and the board's events log
   carries **one duplicate EVENT id (336)**, the CF-196 residue that the row above it explicitly
   names — a summary contradicting its own row. The cell now distinguishes the two counts. The
   second pass's census cell (earlier in this file) carries the same ambiguous phrasing; it is left
   byte-identical as that pass's record and is superseded by this one.
2. **A criterion threshold this lane invented was unreachable.** The graded task required
   "200 or more `^  PASS` rows"; the suite prints **195**, as this section itself states, so the leg
   could never pass and the judge was right to fail it. The re-judge (`RELENG-ADD3-R1`) carries the
   measured number instead of a guess.

Lesson kept for the lane: quote a census with its SCOPE in the cell (`task ids` vs `event ids`), and
never put a predicted count into an acceptance criterion — put the observed one, or none.

### Fourth pass — re-fire of this tick, verification only (tip `27938ca`)

The scheduler delivered tick `code-factory-releng-2026-11-04-10-22-25` again at 06:35-05:00, after
passes 1–3 had already landed. Nothing was re-reviewed: the third pass's claims were checked against
the surviving artifacts, and because the published tip moved past this lane's last gate
(`b16efce` → `27938ca`, two docs/board commits from the CF-202 closure), the gate was re-run at the
new tip instead of being asserted from the older record.

| Leg | Command | Result at `27938ca` |
|---|---|---|
| gate | `bash tests/selftest.sh` | `SELFTEST: PASS`, rc=0, 195 `^  PASS` rows |
| board validity | `bash scripts/boardctl validate` | `RESULT: OK (4 warning(s))` — CF-034 free-form `guard_result`/`ci_result`, duplicate EVENT id 336 (CF-196), headerless board |
| board census | `wc -l .coding-hermes/board/{tasks,events}.jsonl` | 177 task rows / 361 events |
| CI | `gh run list --repo coding-hermes/code-factory --limit 3` | `[]` — no workflows ship, so selftest is the CI-equivalent gate; nothing to file |
| parity | `git rev-list --left-right --count origin/main...HEAD` | `0 0` before and after this pass |
| CF-202 | `jq -c 'select(.id=="CF-202")' .coding-hermes/board/tasks.jsonl` | `complete`, `commit_hash=4fd46d6` — the row the two newer commits closed |

Public posture re-probed at 06:36-05:00 and unchanged from the third pass: `public`, `license=MIT`,
`archived=false`, `default_branch=main`; `secret_scanning=enabled`, `push_protection=enabled`;
secret-scanning alerts = **1 total, `state: resolved`** (Slack token, 2026-11-02), **0 open**; branch
protection **404 "Branch not protected"** and rulesets **0** (CF-120 carries it); **0 published tags**.

Release decision unchanged: **NO TAG**. No version artifact, no CHANGELOG, CF-161 still `pending`.

Negatives scoped to this pass: no board row created or closed, no board event appended, no worker
dispatched, no release tag pushed, no write to any other checkout.
