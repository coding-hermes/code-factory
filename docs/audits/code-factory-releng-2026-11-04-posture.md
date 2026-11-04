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
