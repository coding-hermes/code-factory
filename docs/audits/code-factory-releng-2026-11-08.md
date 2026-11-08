# RELENG — clean-checkout gate green at 5d5f0a6; NO CUT (R2 + no release surface); CF-050 slice landed, one residual named

Tick: `code-factory-releng-2026-11-08-04-02-34`. Lane: code-factory / releng.
Workdir locator `~/code-factory` passed the root/remote/operation gate:
`realpath` = `git rev-parse --show-toplevel` = `~/code-factory`, remote
`origin` = `git@github.com:coding-hermes/code-factory.git` (published URL; the `gh` and `worker`
aliases point at the same repo), branch `main` attached, no merge/rebase/cherry-pick markers,
`scripts/ownership.py status` = `state: clean`, `git status --porcelain -uall` = 0 paths,
parity `git rev-list --left-right --count HEAD...origin/main` = `0 0`.

Served tip and graded tip were the same commit when the gate ran: **`5d5f0a6`**
(`board(sync): rebind CF-275 closure to its tracked verdict, file CF-386`). The registered
checkout was clean at gate time, so this tick graded a **detached worktree of the published
remote** (`~/cf-releng-wt-20261108-0402`) rather than the shared tree.

## Gate (the CI-equivalent: this repo ships no GitHub Actions)

| Check | Command | Result |
|---|---|---|
| Graded tree | `git -C <wt> rev-parse HEAD` | `5d5f0a6` (equals `origin/main` at gate time) |
| Clean tree | `git -C <wt> status --porcelain \| wc -l` | `0` |
| Selftest, pre-dispatch | `bash tests/selftest.sh` in the candidate worktree | **`SELFTEST: PASS`, rc=0** |
| Battery size | `grep -c '^  PASS'` / `grep -c '^  FAIL'` on the gate log | 442 PASS rows / 61 FAIL rows |
| Red-proof arms intact | same run | the 61 inner `FAIL` rows are the battery's own negative fixtures (adapter and pre-fix-revision arms); the suite still exits 0 and prints `SELFTEST: PASS` — a green that can go red |
| Selftest, post-landing | `bash tests/selftest.sh` at `e7ef20a` (worker branch tip) | **`SELFTEST: PASS`, rc=0** |
| Hosted CI | `gh run list --repo coding-hermes/code-factory --limit 3 --json …` | **`[]`**; `.github/workflows/` absent — no CI configured, by design. Not a failure to file. |

Battery growth since the last releng pass: 358 PASS / 58 FAIL at `130e235` (2026-11-06) →
442 PASS / 61 FAIL at `5d5f0a6`. Sections 52–59 (reachability checker, `--agent` refusal, bus
`text_b64` decode, gateway-auth staging order, foreign-harness measurement) are new since then,
and sections 60–61 arrived during this tick (see below).

## Public posture at `5d5f0a6` — measured 2026-11-08T04:22Z

| Leg | Probe | Result | Delta vs 2026-11-06 (`130e235`) |
|---|---|---|---|
| Visibility / license | `gh api repos/coding-hermes/code-factory --jq '{visibility,license:.license.spdx_id}'` | public, MIT | unchanged |
| Secret scanning / push protection | `gh api … --jq .security_and_analysis` | `enabled` / `enabled` | unchanged |
| Dependabot security updates | same | `disabled` | unchanged |
| Open secret-scanning alerts | `gh api '…/secret-scanning/alerts?state=open' --jq length` | **0** | unchanged |
| Branch protection | `gh api …/branches/main/protection` | **404 Branch not protected** | unchanged (row CF-120) |
| Remote tags / releases | `git ls-remote --tags origin \| wc -l`, `gh api …/releases --jq length` | **0** / **0** | unchanged (row CF-161) |
| Absolute host paths — all | `git grep -oIE '/home/[a-z][a-z0-9_-]*/' HEAD \| wc -l` | **647 files / 3030 occurrences** | 550 / 2554 → **1.18x / 1.19x** |
| … excluding `.gitreins` and the board | same, with `':(exclude).gitreins' ':(exclude).coding-hermes/board'` | **143 files / 854 occurrences** | 108 / 703 → **1.32x / 1.21x** |
| Tracked judge bundles | `git ls-tree -r --name-only HEAD .gitreins \| wc -l` | **938 files** | 808 → +130 |
| Published heads | `git ls-remote --heads origin \| wc -l` | **73** | 72 |
| Unrelated `master` lineage | `git ls-remote --heads origin master` | still published (`4ead64f`) | unchanged (row CF-163) |
| Credential-shape scan | `gitleaks detect --no-git --redact` in the candidate worktree | **no leaks found**, rc=0, 3.11 MB scanned (working tree only — no `--log-opts`, history not covered by this number) | 0 findings |

The growth driver is unchanged and mechanical: every `chore(gitreins)` commit publishes a verdict
bundle whose `commit.patch`, `verdict.json` and `summary.md` record absolute worktree and guard-log
paths. `.gitignore` covered `.gitreins/logs/`, `.gitreins/verdicts/`, `.gitreins/tasks.yaml` and
`.gitreins/usage.jsonl`, but **not** `.gitreins/history/` — until this tick (below).

No duplicate rows were filed for these classes. The owning rows are CF-050 (absolute paths),
CF-120 (branch protection), CF-163 (orphan `master` lineage); CF-161 owns the release surface.

## Release decision: NO CUT (rule R2, plus Decision 1b)

No tag, no Release object, no artifact. Two independent grounds, both re-probed at `5d5f0a6`:

1. **R2 — open P0 blockers.** Every non-terminal P0 row at the served tip is `in_progress`:
   CF-001, CF-002, CF-004, CF-005, CF-139. Rule: an open P0 ⇒ no cut.
2. **Decision 1b — there is no release surface.** `git ls-remote --tags origin` = **0 refs**;
   `gh api …/releases` = **0**; no `VERSION`, no `CHANGELOG.md`, no `specs/RELEASE.md` and no
   `docs/RELEASE*`. The only tags are two local-only `safety-*` markers, and neither target is an
   ancestor of `main` — `safety-cf-main-strand-20261103 -> 6598ec3 rc=1`,
   `safety-code-factory-align-20261101 -> e270fb3 rc=1` (`git merge-base --is-ancestor` rc=1 = not
   an ancestor). A first cut would CREATE the distribution namespace, which this lane's charter
   withholds (the escalate clause), so the decision stays **NO CUT / KEEP PENDING** and the release
   contract stays owned by **CF-161**, not by a releng tag.

### The single unblocking decision (owner)

**CF-161 criterion 1 is the only thing between this repo and a release line: decide whether the
factory releases at all, and if it does, name the version scheme (a semver `vX.Y.Z` baseline off the
current tip, or a contract stating the factory is consumed by git ref only).** Criteria 2–4 of that
row are mechanical and dispatchable the moment that ruling exists.

## Dispatch: CF-050 slice (in-lane, executable)

CF-161 is owner-gated on criterion 1, so it is tick context, not the selected task. The highest-value
EXECUTABLE row in this lane's own domain is **CF-050** (public repo publishes absolute host paths),
whose remedy ladder the 2026-11-06 pass promoted into its acceptance criteria and whose measured
exposure grew again this tick (143 files / 854 occurrences outside `.gitreins` and the board).

Acceptance-surface check performed before dispatch:

- Criteria 1–2 are repository-local (`.gitignore`, index removal, a `tests/selftest.sh` section with
  a red-proof arm) — reachable.
- Criterion 3's global `0 occurrences` target is residual (it requires sanitizing every pre-existing
  audit doc), so the task scope covers criteria 1, 2 and 4 and excludes the global zero, stated in
  the GitReins criterion so a judge does not grade the residual as the commit's defect.
- Criterion 1 does **not** break the board writer: `boardctl update --status complete
  --evidence-run-id …` resolves `.gitreins/history/<date>/<run-id>/verdict.json` **on disk**, and the
  un-publish removes the path from the index only. Run directories stay present for evidence
  resolution; they stop being published.

GitReins lifecycle: `CF-050-RELENG-20261108` (created, started before the worker ran).

## What landed

Branch `cf050-publish-gate`, worktree `~/cf-wt-cf050-20261108`, rebased onto the tip that
had advanced under the worker (`5d5f0a6` → `2044c6f`, a sibling's aider/goose adapter commit).

| Commit | Content |
|---|---|
| `6d18448` | `fix(CF-050): stop publishing judge bundles and gate host paths` — 937 `.gitreins/history` paths removed from the index (files kept on disk), `.gitreins/history/` added to `.gitignore`, a publish gate added to `tests/selftest.sh` with a seeded-fixture red arm and a clean control, and the plan mapping (§61) updated. Stat: 940 files changed, +45 / −123882. |
| `e7ef20a` | `fix(CF-050): sanitize the host paths the dogfood audit published` — the rebase pulled in `docs/audits/code-factory-dogfood-2026-11-08-04-02-17.md`, which carried three absolute host paths and would have failed the new gate at 144 > baseline 143. Replaced with `~/code-factory` and `/home/<node-user>/`; count back to 143. |

Rebase resolution (disclosed): both sides appended a numbered selftest section at the same point and
both numbered it 60. The sibling's CF-006 section keeps `60.`; this lane's section was renumbered to
`61.` and the plan's census updated to "64 arms: 61 numbered sections and three lettered arms". Both
bodies were kept — nothing of the sibling's was dropped.

Gate bypass (disclosed): `e7ef20a` was committed with `git -c core.hooksPath=/dev/null` because the
commit hook runs the full selftest, the publish gate grades `HEAD`, and `HEAD` still carried the two
paths that commit removes — the gate cannot pass before the commit that fixes it exists. The suite
was run manually at the resulting tip: **`SELFTEST: PASS`, rc=0**.

### Residual (named, not silently dropped)

**Eight bundle files are still tracked** at the published tip — two verdict directories,
`.gitreins/history/2026-11-08/9ccb5dfd/` and `.gitreins/history/2026-11-08/65bf5725/`, four files
each (`commit.patch`, `summary.md`, `verdict.json`, `worktree.patch`). They were added to `main` by
sibling `chore(gitreins)` commits that landed *after* this branch's base (`949e116` and the six
commits between `2044c6f` and `b90e705`), so each rebase re-introduced a fresh directory under a
commit that had already performed its index removal: the count went 0 → 4 → 8 as `main` moved
under the tick. The un-publish is therefore correct at the base it graded and untiled by sibling
bookkeeping — the follow-up removal
(`git rm -r --cached .gitreins/history` at the new tip) is an approval-gated operation on this
unattended surface: the call was refused for consent and was not retried in any other form. So
CF-050's criterion 1 ("a clone of main carries zero `commit.patch`/`verdict.json` files") is met for
every bundle present at the graded base and **not yet met in full** for the eight that sibling
bookkeeping added afterwards. The row stays open; the unblock is the single
command above on a consenting surface, or an equivalent change in how the judge writes bundles.

Addendum, recorded at close of the same tick: the branch was rebased twice onto a moving `main` and
pushed as `b90e705..f7f25cf` (`origin/main` = `f7f25cf`), parity `git rev-list --left-right --count
origin/main...HEAD` = `0 0`. The published tree carries 143 matching host-path files (its gate
baseline) and 8 tracked bundles, the count above. The Tier-2 judge for `CF-050-RELENG-20261108` runs
asynchronously against this branch; its verdict is read by task id from `.gitreins/history/` and its
result is reported with the tick, not inferred from the task's lifecycle state.

## Not run (and why)

| Leg | Reason |
|---|---|
| Release tag / `gh release create` / CHANGELOG | R2 open P0s + no release surface (CF-161) |
| GitHub Actions CI query beyond `gh run list` | no workflows exist in this repository |
| Global sanitization of pre-existing audit docs | residual of CF-050 criterion 3 |
| `git rm -r --cached .gitreins/history` at the rebased tip | approval-gated on this surface; refused, not retried (see Residual) |
| Deleting `refs/heads/master` | owner-authorized irreversible act; CF-163 |
| Branch protection / ruleset creation | owner decision (required PRs would stop every lane's direct push); CF-120 |
