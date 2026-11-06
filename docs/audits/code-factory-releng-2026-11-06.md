# RELENG — clean-checkout gate green at 130e235; posture exposure grew 2.0x in two days; no tag (R2 + no release surface)

Tick: `code-factory-releng-2026-11-06-11-09-45`. Lane: code-factory / releng.
Measured 2026-11-06T11:11–11:27Z from a clean clone of the published remote
`git@github.com:coding-hermes/code-factory.git`, checked out at published `main` =
`130e23553fc2e0b227ca5ba59074feec7c300bef` (`board: publish the CF-225 verdict bundle`).
`git rev-list --left-right --count gh/main...HEAD` = `0 0` at the gate.

## Why the clone (the registered checkout was not touched)

The registered checkout at `~/code-factory` passed the root/remote/operation gate — `realpath` equals
`git rev-parse --show-toplevel`, remote is the published URL, branch `main` attached, no
merge/rebase/cherry-pick/bisect markers — but carried **2355 untracked paths** outside any scratch
root: 2354 under `.gitreins/rescued-20261105/` plus one unpublished `CF-229-REQUEUE` verdict bundle
(`.gitreins/history/2026-11-06/2ede201e/`, `passed: true`, commit `2b68a82`). `scripts/board_lock.py`
answered `RESIDUE consumers=0 commits_after_mtime=347` (a 0-byte lock file with no holder).
Six prior audit events record the rescued bundle as `residue_left_untouched`, and no code-factory
family lane reported `running` at gate time, so this is recorded residue rather than a live writer —
but the family shares one repo, so this lane used the clone transport. The registered checkout was
**not** read for state, not written, and not cleaned; the rescued bundles and the uncommitted verdict
stay where their owners left them.

## Gate (the CI-equivalent: this repo ships no GitHub Actions)

| Check | Command | Result |
|---|---|---|
| Graded tree | `git rev-parse HEAD` in the clone | `130e235` (equals `gh/main`) |
| Clean tree | `git status --porcelain \| wc -l` | `0` |
| Selftest | `bash tests/selftest.sh` | **`SELFTEST: PASS`, rc=0** — 358 `PASS` rows, 39 s (11:11:49Z → 11:12:28Z) |
| Red-proof arms intact | same run | 58 `FAIL` rows are the battery's own negative fixtures (board-parse and gateway fixtures); the suite still exits 0, so a green that can go red |
| Hosted CI | `gh run list --repo coding-hermes/code-factory --limit 5` | `[]`, `.github/workflows` absent — **no CI configured, by design**; not a failure to file |
| Board at the graded tree | `wc -l .coding-hermes/board/{tasks,events}.jsonl` | 351 tasks / 494 events at `130e235`; 352 / 496 at this tick's carrier |

## Public posture at `130e235` — the deltas

| Leg | Probe | Result | Delta vs 2026-11-04 (`a564cda`) |
|---|---|---|---|
| Visibility / license | `gh api repos/coding-hermes/code-factory --jq '{private,visibility,license:.license.spdx_id}'` | public, MIT | unchanged |
| Secret scanning / push protection | same API on `security_and_analysis` | `enabled` / `enabled` | unchanged |
| Non-provider patterns / validity checks / Dependabot | same | `disabled` / `disabled` / `disabled` | unchanged |
| Open secret-scanning alerts | `gh api '…/secret-scanning/alerts?state=open' --jq length` | **0** | unchanged |
| Working-tree secrets | `gitleaks detect --no-git --redact` — scope: working tree only; no `--log-opts`, so no revision range and history is **not** covered by this number | **0 findings** (2.5 MB scanned) | unchanged |
| Working-tree secrets on the orphan lineage | `gitleaks detect --no-git --redact` in a checkout of `gh/master` — same working-tree-only scope, no `--log-opts`; the 547 figure filed on CF-163 is a history scan and is not comparable | **32 findings** in the `master` tree | previously unmeasured |
| Branch protection | `gh api …/branches/main/protection` | **404 Branch not protected**; rulesets `0` | unchanged (row CF-120) |
| Remote tags / releases | `git ls-remote --tags`, `gh api …/releases --jq length` | **0** / **0** | unchanged |
| Absolute host paths — all | `git grep -oIE '/home/[a-z][a-z0-9_-]*/' HEAD \| wc -l` | **550 files / 2554 occurrences** | 331 / 1267 → **2.0x** |
| … excluding `.gitreins` and the board | same with `':(exclude).gitreins' ':(exclude).coding-hermes/board'` | **108 files / 703 occurrences** | 46 / 157 → **4.5x** |
| Tracked judge bundles | `git ls-tree -r --name-only HEAD .gitreins \| wc -l` | **808 files** | grows every `chore(gitreins)` commit |
| Unrelated `master` lineage | `git rev-list --left-right --count gh/master...gh/main` | `772 753` — disjoint | unchanged (row CF-163) |
| Internal corpus on `master` | `git ls-tree -r --name-only gh/master \| wc -l` | 441 files, **332** under `.hermes/`, `monitoring/`, `.coding-hermes/` | unchanged |
| Anonymous reachability of `master` | `curl -s -o /dev/null -w '%{http_code}' https://raw.githubusercontent.com/coding-hermes/code-factory/master/.hermes/fleet.toml` | **200** from an unauthenticated client | newly proved this tick |
| Published heads | `git ls-remote --heads \| wc -l` | **72** | 60 → 72 |
| Tailnet addresses in the tree | `git grep -nIE '100\.(6[4-9]\|[7-9][0-9]\|1[01][0-9]\|12[0-7])\.[0-9]+\.[0-9]+' HEAD` excluding the board | **5 occurrences / 3 files** | **not owned by any row — filed as CF-378** |

Read against the rows already on the board, the posture legs are unchanged in kind and worse in
degree. No duplicate rows were filed for the three existing classes; instead their owning rows now
carry the 2026-11-06 measurement **and the ordered remedy ladder as acceptance criteria**, so the
next foreman can dispatch them instead of re-deriving the diagnosis:

- **CF-050** (absolute host paths) — revised criteria: stop publishing `.gitreins/history/`, add a
  selftest publish gate with a proved-red arm, target `0` occurrences outside board/audits, use
  `~`/`/home/<user>/` placeholders. The growth driver is mechanical: every verdict bundle commits
  `commit.patch` and `verdict.json`, both recording absolute worktree and guard-log paths.
- **CF-163** (P1, orphan `master` lineage) — revised criteria: anonymous fetch of an internal path
  must stop returning 200; deleting a published ref is an owner-authorized irreversible act; sweep
  every published head before closing; preserve the lineage in a private mirror if it must survive.
- **CF-120** (no branch protection) — revised criteria plus the explicit owner-decision requirement,
  because required PRs would stop every lane's direct push to `main`.
- **CF-378** (new, P3) — tailnet control-plane addresses published in three docs; distinct class from
  CF-050 (an IP literal is not removed by a path-placeholder fix), so it needed its own row.

## Release decision: NO TAG (rule R2, plus Decision 1b)

No tag, no Release object, no artifact. Two independent grounds:

1. **R2 — an open P0 blocker exists.** `CF-001` (scheduler→crier dispatch armed but never run),
   `CF-002` (node inference credential), `CF-004` (round trip through the node's own gateway),
   `CF-005` (node specs + installers) and `CF-139` (dispatches carry no instruction) are all
   `in_progress`.
2. **Decision 1b — there is no release surface.** `git ls-remote --tags` = 0 and
   `gh api …/releases` = 0; there is no `VERSION`, no `CHANGELOG`, and no version scheme in `specs/`
   (that gap is `CF-161`, pending). The only local tags are two `safety-*` markers that resolve from
   no clone of the remote. The repo's own `docs/OPERATIONS.md` still calls node creation, dispatch,
   rebuild and end-to-end operation **BLOCKED / NOT YET**, so a tag would certify a product state the
   repository itself denies.

Recorded as `NO TAG / KEEP PENDING`; the release contract is owned by CF-161, not by a releng tag.

## Not run (and why)

| Leg | Reason |
|---|---|
| Reading or writing the registered checkout's board | family clone transport (2355 untracked residue paths, recorded disposition, shared repo) |
| `git push` from the registered checkout | not this lane's root this tick; all writes happened in the clone and were pushed `HEAD:main` |
| Release tag / `gh release create` / CHANGELOG | R2 open P0 + no release surface (CF-161) |
| GitHub Actions CI | no workflows exist in this repository |
| Deleting `refs/heads/master` | owner-authorized irreversible act; filed as CF-163 criteria |

## Carrier

Board and audit writes were made in the clone and pushed to the published remote as
`HEAD:main`; parity was re-proved after the push. A clone carries no commit-time hooks, so the
configured checks were run manually at the carrier tree (`bash tests/selftest.sh`) and the result is
quoted above — the CF-031 precedent for board-and-docs-only commits.

## Pass 2 addendum — same tick id, re-delivered after the carrier landed

This is the **second pass of tick `code-factory-releng-2026-11-06-11-09-45`**, not a new tick. The
scheduler delivered the same id again after the first pass had already pushed its carrier
`2787611` (11:29:48Z, board event `496` = audit/CF-050, board event `495` = task_created/CF-378).
Per the re-delivery rule this pass did **not** re-run the sweep and did **not** re-cut: it verified
the earlier pass's durable claims at the served tip and closed the two legs the cutting pass could
not close. Measured 2026-11-06T11:34:37–11:39Z.

### Gate at the SERVED tip (not only at the graded sha)

The earlier pass graded `130e235`. The served tip is `2787611`. The delta between them is
`.coding-hermes/board/tasks.jsonl`, `.coding-hermes/board/events.jsonl` and this document — **zero
BUILD-INPUT files**, so the suite result stands by tree identity. This pass re-proved it empirically
in a second clean clone of the published remote at `2787611`:

| Check | Command | Result |
|---|---|---|
| Graded tree | `git rev-parse HEAD` in a fresh clone | `2787611` = `origin/main` |
| Clean tree | `git status --porcelain \| wc -l` | `0` |
| Selftest | `bash tests/selftest.sh` | **`SELFTEST: PASS`, rc=0**, 40 s (11:34:37Z → 11:35:29Z), 359 `PASS`-bearing lines; the 105 `FAIL`-token lines are the battery's own negative fixtures/expectations (loose grep — the earlier pass's stricter `^FAIL` count was 58) |
| Delta classification | `git diff --name-only 130e235..2787611` | board ×2 + this doc — all non-build |

### Posture re-measured at `2787611` (every row of the table above reproduces)

| Leg | Result at `2787611` | vs `130e235` |
|---|---|---|
| Visibility / license / default branch | public, MIT, `main` | unchanged |
| Secret scanning / push protection | `enabled` / `enabled` | unchanged |
| Non-provider patterns / validity checks / Dependabot security updates | `disabled` / `disabled` / `disabled` | unchanged (owner-only settings, no row can execute them) |
| Open secret-scanning alerts (`?state=open`) | **0** | unchanged |
| Branch protection `main` | **404 Branch not protected** | unchanged (CF-120) |
| Remote tags / Release objects | **0** / **0** | unchanged (CF-161) |
| Hosting CI | `gh run list` = `[]`; `.github/workflows` 404 | unchanged — no CI configured, not a failure |
| Absolute host paths — all | **550 files / 2554 occurrences** | identical to the earlier pass |
| … excluding `.gitreins` + board | **108 files / 703 occurrences** | identical |
| Tracked judge bundles | `.gitreins` = 808 files | unchanged |
| Working-tree secrets | `gitleaks detect --no-git --redact` → **0 findings** (2.53 MB) | unchanged |
| Unrelated `master` lineage | `4ead64f`, `772 754` vs `main`, 441 files / 327 internal | unchanged (CF-163) |
| **Anonymous reachability** | `raw.githubusercontent.com/.../master/.hermes/fleet.toml` → **200**; `.../master/monitoring/.coding-hermes/board/tasks.jsonl` → **200** (unauthenticated) | the board path is newly probed this pass, and it is live: a stranger can fetch the fleet's own operational board |
| Published heads | **72** | unchanged |

**One new measurement.** The tailnet-address class (CF-378) is larger than the earlier pass's
`5 occurrences / 3 files` when the judge bundles are included: `17 occurrences / 11 files`. Outside
`.gitreins` the count is exactly the earlier `5 / 3`
(`docs/handbook/appendices/units/05-scripts-bunker-provision-sh.md` ×3,
`06-scripts-bunker-server-install-sh.md` ×1, `docs/MASTER-DOC-SCHEMA.md` ×1); the other **12 of 17
ride `.gitreins/history/*/commit.patch|worktree.patch`**. Those bundles re-publish the same literals
(`100.69.3.13`, `100.78.165.52`, `100.97.236.14`), so they are drained by the CF-050 fix (stop
publishing `.gitreins`) rather than by a separate edit, and CF-378's scope is extended by note to say
so instead of opening a duplicate row.

### Legs this pass closed

| Leg | State before | Now |
|---|---|---|
| Gate on the SERVED tip | only the graded parent `130e235` was measured | `2787611` cloned clean, `SELFTEST: PASS` rc=0 |
| Delivery to the owner thread | the first pass left no send receipt anywhere (no `message_id` in the doc, the board event, or DuckBrain) | sent via `hermes send` to the scheduler-resolved thread; `message_id` recorded in the board audit event for this pass |
| Durable memory | no `code-factory` DuckBrain key existed for any 2026-11-06 releng tick (newest releng key was 2026-11-04) | record written under `/project/code-factory/foreman/ticks/code-factory-releng-2026-11-06-11-09-45` and read back |
| Carrier CI | n/a — the repository ships no workflows (`gh api .../contents/.github/workflows` = 404, `gh run list` = `[]`) | re-proved absent, not assumed |

### Release decision: unchanged — NO TAG

Re-checked at `2787611`: five P0 rows are still `in_progress` (`CF-001`, `CF-002`, `CF-004`,
`CF-005`, `CF-139`) and three more P0 rows are open `pending` (`CF-227`, `CF-229`, `CF-252`); the
release surface is still absent (`git ls-remote --tags` = 0, `gh api .../releases` = 0, no `VERSION`,
no `CHANGELOG`, version scheme still owned by `CF-161`). Decision 1 rule **R2** fires and Decision 1b
independently forbids an invented first tag. No tag, no Release object, no artifact.
