# code-factory sync lane — 2026-11-06T22:32Z (tick `code-factory-sync-2026-11-06-22-32-19`)

Duties: (1) the board parses and its row count matches the published ref, (2) every `complete` row's
closure evidence still resolves, (3) the docs' status tables agree with the board. All three were
measured on `388c7cbe2ff496362e66b8e516f86a12a626e9a5` (`origin/main` at 22:33Z); two drifts were found
and fixed in this commit.

## Where the pass ran, and why

The registered checkout `~/code-factory` is **writer-barriered**: HEAD `943ef98` is
behind-only (1 behind / 0 ahead of `origin/main`), and the working tree carries a live sibling's
handbook workstream — `M docs/MASTER-DOC-SCHEMA.md`, `M docs/handbook/README.md`, and 47 untracked
paths under `docs/handbook/_panel/` and `docs/handbook/chapters/`. Nothing under
`.coding-hermes/board/` is dirty there. That candidate was not committed to, reverted or boarded.

Every measurement below was taken in `git worktree add --detach <scratch>/wt origin/main`, a clean tree
of the published ref. `git show <ref>:.coding-hermes/board/...` reads agree with the worktree reads:
the board is byte-clean in the registered checkout as well.

## 1. Board parse and ref parity — clean

| Measurement | Command | Result |
| --- | --- | --- |
| line-by-line parse (published) | `git show origin/main:.coding-hermes/board/tasks.jsonl \| jq -c .` | rc 0 |
| line-by-line parse (worktree) | `jq -c . .coding-hermes/board/tasks.jsonl` | rc 0 |
| task rows | `wc -l` | **357** both trees |
| events | `wc -l` | **515** both trees |
| status split | `jq -r .status \| sort \| uniq -c` | 88 complete, 13 in_progress, 256 pending, 0 blocked |
| duplicate task ids | `scripts/boardctl validate` (carries a duplicate-id check; §board duplicate-id arm) | none reported |
| max event id | `jq -r .id \| sort -n \| tail -1` | 515 |

`python3 scripts/board_drift.py check --workdir <wt> --ref origin/main` → **`RESULT: OK`**, byte parity
on both files, `357 vs 357 rows; 0 divergent ids`, HEAD ancestry pass.

`bash scripts/boardctl validate` → **`RESULT: OK (7 warning(s))`**, key uniformity 357/357 rows, 0 drift.
The seven warnings are the known set: CF-034's free-form `guard_result` and `ci_result`, CF-150 and
CF-192 title-carries-P3-while-priority-P1, CF-371 title-carries-P1-while-priority-P3, duplicate event
id 336, and the headerless board.

## 2. Closure evidence — two rows repaired

Instrument: `python3 docs/audits/cf181-verdict-binding-sweep.py` → `complete_rows=88`,
`verdict_artifacts_checked=58`, `orphan_count=1` (CF-077, binding `1dfb58b8`, owned by pending CF-181 —
unchanged from the 10:19Z marker).

Grading the **latest** `detail.evidence` entry per complete row (per `code-factory-sync-data` →
evidence classes):

| Class | Count | Rows |
| --- | --- | --- |
| bare repo-relative path, resolves at `origin/main` | 93 | — |
| anchored `file::anchor`, file + anchor both hit | 1 | — |
| **unbound** (run_id/ts, no `artifacts`) | **3 → 1** | CF-225, CF-227 (repaired here), CF-288 (stays) |
| missing (no resolvable path) | 0 | — |
| no evidence entry at all | 0 | — |
| `commit_hash` null | 1 | CF-245 |

Every non-null `commit_hash` on a complete row is a real commit object AND an ancestor of
`origin/main` (`git cat-file -e <sha>^{commit}`, `git merge-base --is-ancestor <sha> origin/main`):
`bad_commit=0`.

**Fix 1 — rebind CF-225 and CF-227.** Both rows were closed today with an evidence entry naming only
`run_id` + `ts`, while their verdict bundles are tracked in the same commit:

| Row | run_id | commit_hash | artifact now bound |
| --- | --- | --- | --- |
| CF-225 | `2d2bac34` | `7686bc8` | `.gitreins/history/2026-11-06/2d2bac34/verdict.json` |
| CF-227 | `a159384e` | `dc73199` | `.gitreins/history/2026-11-06/a159384e/verdict.json` |

Both artifacts are `git cat-file -e origin/main:<path>` clean, and each `verdict.json` binds the row's
own `commit_hash` with `passed: true` — so the rebind adds a pointer that corroborates the closure rather
than a second claim. The rewrite was per line: a round-trip serialisation of each untouched row was
byte-identical to the stored line *before* the edit (the serializer convention was proved, not assumed),
the file stayed at 357 rows, and `git diff -U0` shows exactly 2 changed lines.

CF-288 (`336a8021`) stays unbound: it was recorded as real in the 10:19Z marker, and its verdict bundle
is tracked, so the repair is available to whatever row owns that closure.

## 3. Docs vs board — one contradiction, fixed

No doc in `docs/` or `README.md` carries a table row pairing a `CF-nnn` id with a status word
(`grep -rnEi '^\| *`?CF-[0-9]+' docs/ README.md | grep -Ei '\| *(complete|pending|in.progress|blocked|done) *\|'`
→ 0 matches), so there is no board-status/table contradiction to reconcile.

The state numbers are another matter. `docs/ACCEPTANCE-PLAN.md:13` is honest at the tip it names —
at `2f07051` the board really is 350 rows / 489 events (80 complete, 13 in_progress, 256 pending,
1 blocked) — and it already carries the current arm count (53 numbered + 3 lettered = 56, matching
`bash docs/audits/cf198-section-mapping.sh` → `arms_plan=56 arms_tree=56`, `RESULT: OK`).

**Fix 2 — `docs/RUMSFELD.md` was the last document contradicting the committed instrument.** Its
measurements table still read "3,657 lines, 52 numbered sections + 3 lettered = 55 arms, 291 PASS
assertions", and its requirement-7 row read "55 arms". Measured at `388c7cb`: `tests/selftest.sh` is
4,687 lines, carries 53 numbered sections (`grep -cE '^say "[0-9]+\.'`) plus 3 lettered arms
(`grep -cE '^say "[0-9]+[a-z]\.'`) = 56, and a clean-worktree run prints **380 `PASS` rows**
(`grep -c '^  PASS'`). Both count citations and the "Rejected findings" entry that argues the count
were corrected to 53/56 and to the measured PASS-row number with its command named; the argument's
shape (numbered arms plus lettered arms) is unchanged.

## Instrument results at this tip

| Instrument | Result |
| --- | --- |
| `bash tests/selftest.sh` (clean worktree of `origin/main`) | **`SELFTEST: PASS`**, rc 0, 380 `PASS` rows / 58 `FAIL` rows (every `FAIL` a negative fixture), `PASS  357/357 rows parse` |
| `bash docs/audits/cf198-section-mapping.sh` | `RESULT: OK`, `arms_plan=56 arms_tree=56` |
| `bash docs/audits/cf099-prd-drift-probe.sh` | `OK: milestone, plan snapshot and layer arms agree at 388c7cb` — note it measures `sections=53` and still prints OK while CF-121 (pending) owns the class that says its snapshot leg compares the plan to the tip the plan itself names |
| `python3 docs/audits/cf181-verdict-binding-sweep.py` | `complete_rows=88`, `verdict_artifacts_checked=58`, `orphan_count=1` (CF-077 → CF-181) |
| `git ls-tree -r --name-only HEAD \| grep -c '^\.github/workflows/'` | 0 — no CI workflows exist; `gh run list --repo coding-hermes/code-factory` returns `[]`; **`ci=SKIP` is this repo's healthy state** |

## Open items (not fixed here, with the owner that already holds each class)

- **CF-245** is `complete` with `commit_hash: null`. It is a verification closeout whose fix landed in
  the *scheduler* repo, so no in-repo commit exists to bind; the board has no field for that shape
  (CF-047 owns the `detail.evidence` field doctrine, CF-074 the closure-evidence gate). Whether an
  existing row already owns the null-commit case could not be established in this pass — the ownership
  census command was refused by the unattended approval gate, so the question is left **unresolved,
  not retracted**, and no row was filed on a guess.
- **CF-288** remains unbound; its tracked verdict bundle makes the repair mechanical for its owner.
- The registered checkout is 1 behind `origin/main` with a live sibling's handbook workstream in the
  tree; it was left untouched.
- `docs/RUMSFELD.md`'s inventory line still cites "`scripts/` 42 files / 13,944 lines; `docs/` 165 /
  27,835; `specs/` 7 / 949; `tests/` 7 / 5,507" — not re-derived in this pass, so it is neither
  confirmed nor corrected here.

## What this commit changes

Two board rows rebound and two docs files corrected: **0 rows added, 0 events added, 0 rows deleted**,
no status transition, max event id untouched. Every count in this receipt is a measurement of
`origin/main` at `388c7cb` (the tree the pass ran on); this commit was then rebased onto `b82a5df` — a
sibling's CF-051 verdict closeout that landed mid-pass — so a reader at the tip should re-read the board
and expect that base's figures plus nothing from this change.
