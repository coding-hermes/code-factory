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
| Working-tree secrets | `gitleaks detect --no-git --redact` → **0 findings** (2.53 MB); working-tree scope only, so no `--log-opts` revision range is claimed for this row | unchanged |
| Unrelated `master` lineage | `4ead64f`, `772 754` vs `main`, 441 files / 327 internal | unchanged (CF-163) |
| **Anonymous reachability** | `raw.githubusercontent.com/.../master/.hermes/fleet.toml` → **200**; `.../master/monitoring/.coding-hermes/board/tasks.jsonl` → **200** (unauthenticated) | the board path is newly probed this pass, and it is live: a stranger can fetch the fleet's own operational board |
| Published heads | **72** | unchanged |

**One new measurement.** The tailnet-address class (CF-378) is larger than the earlier pass's
`5 occurrences / 3 files` when the judge bundles are included: `17 occurrences / 11 files`. Outside
`.gitreins` the count is exactly the earlier `5 / 3`
(`docs/handbook/appendices/units/05-scripts-bunker-provision-sh.md` ×3,
`06-scripts-bunker-server-install-sh.md` ×1, `docs/MASTER-DOC-SCHEMA.md` ×1); the other **12 of 17
ride `.gitreins/history/*/commit.patch|worktree.patch`**. Those bundles re-publish the same literals
(the three addresses pass 2 printed here were removed by pass 3 — see the correction section), so they
are drained by the CF-050 fix (stop publishing `.gitreins`) rather than by a separate edit, and
CF-378's scope is extended by note to say so instead of opening a duplicate row.

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

## Pass 3 correction — the tailnet census published in pass 2 was an undercount

Third delivery of the same tick id, measured 2026-11-06T11:38–11:52Z at the served tip `e8d1248`
(= `origin/main`). Pass 3 did **not** re-run the sweep, did **not** re-cut, and did **not** replay the
suite: `git diff --name-only 130e235..e8d1248` and `git diff --name-only 2787611..e8d1248` both list
only `.coding-hermes/board/{tasks,events}.jsonl` plus this document — zero BUILD-INPUT files, so pass
1's `SELFTEST: PASS` and pass 2's re-proof stand by tree identity. The gate itself did **not** stand,
which is the first finding below.

Re-anchored after the fact: two sibling commits landed between that measurement and this carrier —
`c3f7932` (the doc scope repair) and `417449d` (a CF-229 harness test). Neither touches a quantified
surface: the census re-reads 45 occurrences / 14 files and 2555 / 550 at the rebased tip, identical to
the figures in this section, and the carrier is gated there rather than at the sha that was measured.

What it did do is re-measure the figure a later audit would have to trust, and both quantity and
scope in pass 2's published census are wrong.

| Scope | pass 2 published | measured at pass 2's OWN tip `2787611` | measured at served tip `e8d1248` |
|---|---|---|---|
| all tracked files | 17 occurrences / 11 files | **36 / 13** | **45 / 14** |
| under `.gitreins/` | 12 (implied by the split) | 17 / 8 bundles | 17 / 8 bundles |
| under `.coding-hermes/board/` | not counted | 12 / 2 | **18 / 2** |
| neither | "exactly 5 / 3" | 7 / 4 | **10 / 4** |

Per-file at `e8d1248`. This section deliberately does **not** reprint an address, because reprinting
is what has been driving the growth:

| Path | Occurrences |
|---|---|
| `.coding-hermes/board/tasks.jsonl` | 13 |
| `docs/handbook/appendices/units/05-scripts-bunker-provision-sh.md` | 5 |
| `.coding-hermes/board/events.jsonl` | 5 |
| `docs/audits/code-factory-releng-2026-11-06.md` (this file) | 3 |
| `.gitreins/history/…` (8 verdict bundles) | 17 |
| `docs/handbook/appendices/units/06-scripts-bunker-server-install-sh.md` | 1 |
| `docs/MASTER-DOC-SCHEMA.md` | 1 |

Two findings follow, and the second is the one that matters:

1. **The published total was the judge-bundle subtotal.** `17 / 11` is exactly the `.gitreins` count at
   both tips, so pass 2 appears to have published a scoped count as the total — an inference from the
   numbers only, because the command that produced it was not recorded. A reader of that figure would
   have concluded the class was half its real size and would have looked in the wrong place.
2. **The audit chain is now the fastest-growing contributor, and this lane authors it.** Between
   `2787611` and `e8d1248` the class grew by nine occurrences — this document +3, board
   `tasks.jsonl` +3 (the CF-378 note), board `events.jsonl` +3 (pass 2's own audit event) — every one
   of them written by pass 2 of this tick, to prove that addresses were exposed. A sweep that prints
   an address to prove an address is exposed makes the exposure worse. CF-378's remedy scope is
   therefore widened: scrubbing `docs/audits/*.md` and board event detail text is part of the fix, not
   an afterthought, and later censuses publish counts and paths only.

Measured after this commit's own scrub the class re-reads **42 occurrences / 13 files**: this document
no longer contributes any, because the three literals pass 2 printed were replaced by a count reference
above. The board copies (18) and the judge bundles (17) are the remedy rows' work; the share this lane
could remove without editing another lane's artifact, it has now removed.

Host paths re-measured at the served tip for the same reason: **2555 occurrences / 550 files**
(pass 2: 2554 / 550 at `2787611`). The one-occurrence delta is the scratch path inside board event
`497` — same mechanism.

**Evidence-boundary correction.** Pass 2's addendum states "Measured 2026-11-06T11:34:37–11:39Z", but
its commit landed at `11:37:46Z` and the selftest leg it quotes ran `11:34:37→11:35:29Z`. A
measurement window cannot end after the artifact that reports it was frozen; the corrected window is
`11:34:37–11:37:27Z`, the instant board event `497` closed.

### The served tip was gate-RED, and pass 2 published it as green

The most material finding of this pass is not in the census: it is that `e8d1248` — the tip a reader
is served — **fails the repository's own gate**. `bash tests/selftest.sh` there ends
`SELFTEST: FAIL (1)`, the failing arm being
`FAIL  audit-scope: docs/audits/code-factory-releng-2026-11-06.md:143 gitleaks claim names no --log-opts`
— pass 2's own "Working-tree secrets" row, which named a scan result without naming the scan scope.

The regression is isolated to pass 2's carrier by grading each ref's document with the repository's own
checker (`scripts/check_scan_scope.py`, which requires any line naming `gitleaks` to name `--log-opts`
on the same line):

| Ref | Carrier | `check_scan_scope.py` |
|---|---|---|
| `2787611` | pass 1 | `OK  audit-scope: 2 gitleaks claim(s) name their --log-opts` → `RESULT: OK` |
| `e8d1248` | pass 2 | `FAIL  audit-scope: …:143 gitleaks claim names no --log-opts` → `RESULT: FAIL (1 violation(s))` |

Pass 2's "SELFTEST: PASS" was true of `2787611`, the tree it measured, and it was published as the state
of the tip it was writing to. It never gated its own carrier: it measured before writing the addendum,
committed through a clone (which carries no commit-time hooks), and pushed. A green measured at the
parent is not a green at the carrier — this is the posture-doc trap in its ordinary form, a bookkeeping
commit that adds a scanner line without the scope flag and reds a tip whose code commit was green.

Repair: the row now names its scope — but this pass did not land that repair. A **sibling foreman**
committed it at `c3f7932` ("name the scan scope on the releng pass-2 working-tree secrets row") while
this pass was preparing its own edit of the same line; this pass dropped its duplicate text and kept
the sibling's. Two lanes reaching the same defect from opposite directions, minutes apart, is the
strongest form of the finding: `e8d1248` was red on the published default branch and no lane had gated
it. What this pass contributes is the per-ref isolation above, the corrected census, the corrected
measurement window, and a re-gate of the rebased carrier through the repository's own pre-commit guard.

Release decision unchanged and re-checked at `e8d1248`: **NO TAG** — rule **R2** (P0 rows
`CF-001`, `CF-002`, `CF-004`, `CF-005`, `CF-139` still `in_progress`; `CF-227`, `CF-229`, `CF-252`
still `pending`) plus Decision 1b (0 published tags, 0 Release objects, no `VERSION`, no `CHANGELOG`,
release surface owned by `CF-161`). Hosted CI re-probed and still absent by design — `gh run list` =
`[]`, `gh api …/contents/.github/workflows` = 404 — so there is no run to file against and nothing to
report as a failure.

## Pass 4 — the served tip is gate-green, and CF-378 was fixed rather than re-audited

Fourth delivery of the same tick id. Opened 2026-11-06T12:09Z at the served tip `b2d187f`
(`git rev-list --left-right --count origin/main...HEAD` = `0 0`), closed at `84ae65f`. Pass 4 did not
re-run the release sweep, did not re-derive the decision, and did not append a fifth census
correction: it closed the one leg pass 3 left open and then spent the tick landing the fix that
`CF-378` had been describing for three passes.

### 1. Pass 3's open leg: the repository's own gate, at the served tip

Pass 3 proved `e8d1248` was gate-RED, recorded that it did not land the repair (a sibling foreman did,
at `c3f7932`), and gated its own carrier only through the commit-time guard — never through the suite.
This pass ran the gate itself at the tip it was served:

    bash tests/selftest.sh   # at b2d187f
    SELFTEST: PASS           # rc=0, 492-line log

The tree a reader is served is therefore the tree the gate measured. Tree identity could not have
carried pass 1's green forward: `c3f7932..b2d187f` is not bookkeeping-only, because `417449d` adds a
harness test.

### 2. The lane's published census recipe was under-measuring by 73%

The posture table this lane works from grades the tailnet class with `100\.6[4-9]\.[0-9]+\.[0-9]+`,
which covers only `100.64–100.69` — one tenth of the CGNAT /10, which runs `100.64–100.127`. At
`b2d187f` the narrow pattern reads **12 occurrences / 6 files**; the corrected range reads
**45 / 15**. Pass 3's published 42/13 used the corrected range (`CF-378`'s AC1 already carried it), so
pass 3's census stands and the defect is in the recipe, not in the figure. Corrected pattern:

    100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.[0-9]+\.[0-9]+

### 3. `CF-378` landed: docs scrubbed, and the class now has a gate

One worker was dispatched against `CF-378` (agent `coding-hermes-worker`), which committed `5dc48b8`;
the fleet harvester then rebased it onto two sibling commits as `84ae65f`. `git diff --name-only
5dc48b8 84ae65f` lists 8 paths, all under `.coding-hermes/` or `.gitreins/` — **zero build inputs**,
so the gate measured at `5dc48b8` stands at the rebased tip by tree identity.

| Path | Change |
|---|---|
| `docs/handbook/appendices/units/05-scripts-bunker-provision-sh.md` | 5 literals → placeholders |
| `docs/handbook/appendices/units/06-scripts-bunker-server-install-sh.md` | 1 literal → placeholder |
| `docs/MASTER-DOC-SCHEMA.md` | 1 literal → placeholder |
| `tests/selftest.sh` | +68 lines: arm at L159–225, inside section 6 |

The three doc files now use `<crier-host>` / `<ci-box>` forms that keep the surrounding commands
runnable, each with one sentence pointing at the operator's own config. The arm grades every tracked
file except `.coding-hermes/board` and `.gitreins`, prints exactly one PASS row, and on violation one
FAIL row naming `path:line` and never the address — a gate that prints what it forbids republishes the
class in every log it reds. A run that grades 0 files is a FAIL, not a green. Its red proof is a
seeded git repo whose literal is assembled from octet variables at run time (writing the address into
the suite would put the class straight back, since `selftest.sh` is itself tracked and graded), plus
an out-of-range subnet that must stay green, so the arm proves its boundary and not merely a hit.

Measured at `84ae65f`:

| Scope | Occurrences | Files |
|---|---|---|
| outside `.coding-hermes/` and `.gitreins` — the fix's scope | **0** | **0** |
| AC1's original exclusion list (board only) | 17 | 8 bundles |
| whole tracked tree | 38 | 12 |

Split of the 38: board **19**, `.gitreins` **19**, docs **0**. Both remaining shares belong to other
rows — `.gitreins/history/*/commit.patch` republishes whole patches, so it re-carries every literal
any commit ever held (`CF-050`).

**AC1 was defective as written, and this pass amends it instead of faking a close.** Its probe
excluded only `.coding-hermes/board`, so it could never reach 0 while `.gitreins` is another row's
surface. `CF-378`'s criterion 1 now also excludes `.gitreins`, with the amendment recorded in the
criterion text and the row note; as amended it reads 0. The row stays `pending` rather than being
closed by this lane: its remaining exposure lives on `CF-050`'s surface and pass 4 does not speak for
that row.

### 4. Posture re-measured at `84ae65f`

| Item | Reading |
|---|---|
| visibility / license | public / MIT |
| secret scanning, push protection | enabled / enabled |
| Dependabot security updates | disabled (owner-scoped) |
| branch protection | ABSENT — HTTP 404, an owner decision, not foreman work |
| workflows dir / workflow runs | absent / `[]` — healthy, not absent CI |
| published heads | 72; unrelated `master` lineage of 772 commits (`CF-163`) |
| release tags / Release objects | 0 / 0 |
| absolute host paths | 2555 occurrences / 550 files (`CF-050`) |
| credential shapes | 21 |

### 5. Release decision — unchanged

**NO TAG.** Rule **R2** — P0 rows `CF-001`, `CF-002`, `CF-004`, `CF-005`, `CF-139` still
`in_progress`; `CF-227`, `CF-252` still `pending` (`CF-229` was closed by a sibling lane during this
pass) — plus Decision 1b: 0 published tags, 0 Release objects, no `VERSION`, no `CHANGELOG`, release
surface owned by `CF-161`. Hosted CI remains absent by design: no `.github/workflows`, `gh run list` =
`[]`, so there is no run to file against.
