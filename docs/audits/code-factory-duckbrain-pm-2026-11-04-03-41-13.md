# PM lane — tick `code-factory-duckbrain-pm-2026-11-04-03-41-13`

Lane: `code-factory-duckbrain-pm`. Locator `~/code-factory`; the scheduler row for
`code-factory-pm`, `code-factory-duckbrain-pm` and every sibling of this family registers the same
workdir. All numbers below were measured at the tip each one names; the doc snapshot lands pinned to
`7989ba3`, the commit that carries these edits is `1ef9256`.

## Identity and ownership gate

| Probe | Result |
|---|---|
| `realpath` == `git rev-parse --show-toplevel` | `~/code-factory` — equal |
| remote | `origin` = `git@github.com:coding-hermes/code-factory.git` (the registered project remote) |
| branch / operation markers in `$(git rev-parse --absolute-git-dir)` | `main`; no `MERGE_HEAD`/`rebase-merge`/`CHERRY_PICK_HEAD`/`REVERT_HEAD`/`BISECT_*` |
| tracked porcelain at tick start | 0 paths (50 untracked = `.gitreins/history/2026-11-03/*` bundles) |
| parity | `git rev-list --left-right --count origin/main...HEAD` = `0 0` at `7989ba3` |
| `board/.lock` | 0 bytes, mtime 2026-11-03 07:40 — adjudicated residue by `CF-119` (holder-proof classifier ships); recorded, not deleted |
| live writer census (`checkout-writer-census.sh`) | `CENSUS_EMPTY=1` at 22:44; at 22:46 a foreign `bash`+`sleep` pair (pid 2774671/2774673, started 22:45:25) sat in the repo cwd — a sibling lane holding a bounded wait |

**Family barrier, and the transport used.** Four siblings of this family were `running` in the same
scheduler slot (`code-factory-duckbrain-dogfood`, `code-factory-perf`, `code-factory-readme`,
`code-factory-review`, all `*-2026-11-04-03-41-13`), and two of them landed commits on
`origin/main` while this tick ran (`d3b06a8`, `de014b2`). Per the family rule, board writes and
worker dispatch were therefore not taken: **no board row, event or status field was written, and no
worker was dispatched.** The doc work was done on a dedicated clone of `origin/main`, the commit was
made and pushed from that clone, and the GitReins lifecycle ran in the same clone so the verdict
binds the judged commit.

## Red arm → green arm

The lane's instrument is `bash docs/audits/cf099-prd-drift-probe.sh`, run from the repository root.

| Arm | Command | Output | rc |
|---|---|---|---|
| RED (parent `7989ba3`) | `bash docs/audits/cf099-prd-drift-probe.sh` | `DRIFT: plan says 31 sections, tests/selftest.sh has 33` | 1 |
| GREEN (`1ef9256`) | `bash docs/audits/cf099-prd-drift-probe.sh` | `measured: tip=7989ba3 rows=130 events=209 sections=33 open_blockers=CF-001 CF-002 CF-004 CF-080 CF-110 CF-112 CF-131 CF-132 CF-133 CF-136 CF-137 CF-138 CF-139` / `OK: milestone, plan snapshot and layer arms agree at 1ef9256` | 0 |

Re-measured inputs behind the edited cell: `grep -cE '^say "[0-9]+\.' tests/selftest.sh` = **33**
numbered sections plus the lettered `§4b` and `§7b` → **35 arms**; `bash tests/selftest.sh` =
`SELFTEST: PASS`, **103** `PASS` rows, **19** intentional negative-fixture `FAIL` rows, `fails=0`, at
loadavg 7.91; `git show 7989ba3:.coding-hermes/board/tasks.jsonl | wc -l` = **130**,
`…/events.jsonl | wc -l` = **209**.

## Contradictions found (claim vs tree)

| # | Claim before this tick | Tree truth | Disposition |
|---|---|---|---|
| 1 | `docs/ACCEPTANCE-PLAN.md` "Current state": "carries 31 sections … so the tree carries 33 arms", snapshot pinned to `4bf29e9` (129 rows / 199 events) | 33 numbered sections, 35 arms; selftest prints 103 `PASS` rows, not 99 | **corrected** — cell now states 33 sections / 35 arms / 103 `PASS` / 19 `FAIL` pinned to `7989ba3` (130/209). Owned by `CF-155` (pending; its AC-1 target number is stale at 30 and must be re-measured to 33 when it is fixed) |
| 2 | PRD milestone Status block lists the dispatch defects that stop a leg: `CF-131`, `CF-132`, `CF-133`, `CF-136`, `CF-139` | `CF-137` (a failed dispatch is never acked → redelivers the same failure forever) and `CF-138` (the dispatcher kills every real task at 243 s while the scheduler budgets 15 m 40 s) are open P1 rows that stop the "commit produced on a node" leg and were **absent from the list** | **corrected in the PRD; not caught by the probe** — see the fail-open proof below |
| 3 | The plan's requirement↔test matrix reads in one direction only: it says which sections prove which CF-101–CF-112 requirement, never which sections prove no requirement | 23 of the 35 arms are named by no `Verified by` cell; they are governed by board rows (`CF-088`, `CF-085`, `CF-091`, `CF-114`, `CF-127`, `CF-093`, `CF-145`, `CF-119`, `CF-077`) | **added** — a reverse-direction paragraph names the split, the governing row for each, and the rule that an unnamed section is untracked test surface. `CF-155` AC-2 wants this as per-section table rows plus a gate; that repair is left to the row |

## The probe's blind spot, proved (evidence for `CF-115`)

At the fixed tree the probe is green. Renaming an **open** blocker out of the milestone list does
not turn it red:

```
d=$(mktemp -d); git clone -q --shared "$PWD" "$d/repo"
sed -i 's/`CF-002` (P0:/`CF-998` (P0:/' "$d/repo/docs/PRD-code-factory.md"
cd "$d/repo" && bash docs/audits/cf099-prd-drift-probe.sh
# rc=0, and the measured line lists CF-998 as an "open blocker" without complaint
```

`CF-002` is a real open P0 blocker; `CF-998` is not on the board at all, and every id the probe
cannot find simply passes its `jq` lookup. This is the `CF-115` class (a milestone that certifies a
list it never validates), reproduced at the current tip — recorded here as liveness evidence for
that pending row rather than filed as a new row.

## Dedupe before filing

No row was filed. The classes this tick touched are already owned:

| Row | Status | Class |
|---|---|---|
| `CF-155` | pending, P4 | the plan's stale section count + the reverse-direction table and a gate that can fail on the drift |
| `CF-115` | pending, P4 | the probe certifies legs it never measures (empty/omitted open-defect list) |
| `CF-121` | pending, P3 | the probe's snapshot leg is a tautology against the tip the plan names |
| `CF-083` | pending, P3 | 9 of 12 PRD requirements carry no test |

This tick's edits satisfy `CF-155` AC-2's count leg only; its table rows and gate (AC-2 remainder,
AC-3) remain open, so the row stays `pending` and nothing was reopened or renumbered.

## Gates at the landed commit

| Gate | Command | Result |
|---|---|---|
| drift probe | `bash docs/audits/cf099-prd-drift-probe.sh` | `OK … at 1ef9256`, rc 0 |
| suite | `bash tests/selftest.sh` | `SELFTEST: PASS`, rc 0, 103 `PASS` rows |
| board | `bash scripts/boardctl validate` | `RESULT: OK (3 warning(s))` — pre-existing free-form fields |
| scope | `git show --name-only HEAD` | `docs/ACCEPTANCE-PLAN.md`, `docs/PRD-code-factory.md` only |
| push | `git ls-remote gh refs/heads/main` vs clone `HEAD` | `1ef9256` = `1ef9256`, parity `0 0` |
| GitReins | `gitreins task complete CF-PM-20261104` in the clone holding the judged HEAD | verdict `ffa54c0f`, `task_id=CF-PM-20261104`, `commit=1ef925614e21d9f00a4153cd94357e3bc0bea76f`, `passed=true` |

CI: `gh run list --repo coding-hermes/code-factory` returns no workflow runs for this repository —
the documented no-GitHub-Actions state, not a failure. The CI-equivalent gate is `tests/selftest.sh`
above.

## Close-out

Implementation commit `1ef9256` (docs only), pushed to `origin/main` and verified by parity `0 0`.
The GitReins task ran a full `create → start → complete` lifecycle in the lane clone so its verdict
could not bind a sibling's commit; the canonical root's dangling `in_progress` record for the same id
was deleted after the verdict landed. This evidence file and the verdict bundle publish in the
follow-up `chore(gitreins)` commit; the board is untouched by this tick.
