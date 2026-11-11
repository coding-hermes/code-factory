# Sync lane 2026-11-03 (23:48 slot) — CF-077 evidence rebound, README gate-row count corrected, ledger drift filed

Tick: `code-factory-duckbrain-sync-2026-11-03-23-48-25`
Measured at `origin/main` `b1359cc910365964cb9860adbacaeebb7f7f2b36` (board and events byte-identical to the working tree).

## Identity and ownership gate

```
$ realpath ~/code-factory
~/code-factory
$ git -C ~/code-factory rev-parse --show-toplevel
~/code-factory
$ git rev-parse --abbrev-ref HEAD            -> main
$ git remote -v                              -> origin git@github.com:coding-hermes/code-factory.git
$ ls <abs-git-dir> | grep -E '^(rebase-merge|rebase-apply|MERGE_HEAD|CHERRY_PICK_HEAD|REVERT_HEAD|index.lock)$'
MARKERS: none
$ sha256sum .coding-hermes/board/tasks.jsonl vs git show origin/main:...
f91a5303c1e2d32fcd36d521485ee76af5a2d4eb803b39681d7d85069869aa35  (both)
$ rev-parse HEAD origin/main -> b1359cc910365964cb9860adbacaeebb7f7f2b36 (both)
```

Sibling census (`GET /api/v1/projects/<lane>` for all 19 `code-factory*` lanes): no lane reported
`status=running` under a different tick id. `code-factory-duckbrain-sync` reports `running` with
`latest_tick.id = code-factory-duckbrain-sync-2026-11-03-23-48-25`, which is this tick, so it is not
a second instance and not a barrier.

## Board census

| Measure | Value |
|---|---|
| Task rows parsed | 103 (line by line, `jq -c .` clean, 103 unique ids, no blank lines) |
| Events parsed | 146 (`audit` 25, `task_completed` 45, `task_created` 72, `task_updated` 4) |
| Status split | 38 `complete`, 64 `pending`, 1 `in_progress` |
| Rows vs last commit | byte-identical to `origin/main` (sha256 above) |

## Drift found

| # | Row / file | Drift | Measured |
|---|---|---|---|
| 1 | `CF-077` | `complete`, but `commit_hash` named `1dfb58b8aac966fa858e274992e01bad27d0632b`, a commit **no ref reaches** (`git for-each-ref --contains 1dfb58b8` → empty) — a completion bound to an unlanded commit | The identical subject and content did land: `1232f7a04ce8bcfa94fd46166b3f05f1d1c55ffc` "fix: fail closed when the auth probe cannot prove the gateway is closed. Addresses CF-077." and `git merge-base --is-ancestor 1232f7a04 origin/main` passes |
| 2 | `README.md` status table | claimed the pinned-interpreter check "prints four" gate rows; it prints five on a host with the hermes binary installed (`version` row added at line 60) | `HERMES_PYTHON_BIN=python3.12 scripts/harness/install-hermes.sh --check` → rows `python, binary, version, port, inference_key`, `HERMES: FAIL (1)`, rc 1. The recorded artifact `docs/audits/cf092-install-check-arms.txt` measured four because its fixture had no `hermes` binary (`FAIL binary — absent`) |
| 3 | `CF-034`, `CF-041` | `complete` with no `task_completed` event — the append-only ledger cannot show when or on what evidence they closed | `comm -23` between complete ids and `task_completed.task_id` → `CF-034 CF-041` |
| 4 | `CF-053` | `complete` while `worker_status=pending` and `commit_hash=null`; its only evidence entry is an out-of-repo `run_id` | `jq 'select(.status=="complete" and .worker_status=="pending")'` → `CF-053` |
| 5 | `CF-005` | the board's only `in_progress` row, untouched since 2026-10-29T18:40:00Z, while all five acceptance artifacts exist at this tip | `specs/NODE.md`, `specs/ENVELOPE.md`, `specs/HARNESS.md`, `docs/DESIGN.md`, `scripts/node-create.sh`, `scripts/verify-node.sh` all `EXISTS`; `tests/selftest.sh` covers the empty-PATH FAIL arm AC2 names |

Checked and **not** drift: `CF-011`/`CF-013` still carry the pruned scratch-log path, but a second
`detail.evidence` run (`sync-20261103-cf011` / `sync-20261103-cf013`) already rebinds them to the
committed `docs/audits/code-factory-sync-2026-11-03-evidence-rebind.md` — the superseded entry is
deliberately preserved history. `CF-012`'s `docs/traceability-doctrine.md` exists. The `CF-101..CF-112`
ids in `docs/ACCEPTANCE-PLAN.md` are PRD requirement ids, not board rows.

For every `complete` row, the evidence names a command: zero rows lack a command reference, and every
one of the 38 `commit_hash` values except `CF-077`'s resolves in this repository.

## Fixes applied

1. `CF-077` — only that row's line rewritten: `commit_hash` `1dfb58b8…` → `1232f7a04ce8bcfa94fd46166b3f05f1d1c55ffc`.
   Byte-preserving (a single SHA substitution on one line; the script asserted exactly one occurrence,
   re-parsed the file, and proved `diff_keys == ["commit_hash"]` and `changed == 1`).
2. `README.md` — the state cell and the command cell of the "Hermes in a bunker" row now state the
   measured count in both arms: four with no `hermes` binary (the recorded arm, `cf092-install-check-arms.txt`)
   and five once `~/.local/bin/hermes` exists, with the 2026-11-03 re-measurement quoted.
3. `CF-130` filed (`pending`, P3) for findings 3–5, with a probe that names each condition today:

```
$ bash cf130-probe.sh
stale_inprogress=CF-005
complete_without_completion_event=CF-034 CF-041
complete_with_worker_status_pending=CF-053
```

The sync lane did **not** flip `CF-005` itself: its AC1 ("the specs agree with the scripts") is a
judgement no mechanical probe settles, so the decision belongs to a row, not a bookkeeping edit.

## Residue disclosed, not cleaned

| Path | State | Why it is not a barrier |
|---|---|---|
| `.coding-hermes/board/.lock` (untracked) | 0 bytes, mtime 2026-11-03T07:40:02-05:00 | `fuser -v` shows no holder; no `flock`/`fcntl` consumer exists in `scripts/`; board commits landed at 17:08, after the lock's mtime. Residue, left in place (not deleted) |
| 13 untracked `.gitreins/history/2026-11-03/*` bundles | earlier ticks' verdict bundles (06fdc0aa … ec0267ca) | Not this tick's evidence; a sibling lane published its own bundle at `b1359cc`. Left in place |

## Gates at this tree

```
$ bash scripts/boardctl validate
RESULT: OK (44 warning(s))
$ bash tests/selftest.sh
SELFTEST: PASS
```

The 44 validate warnings are the documented pre-existing classes (free-form `probe` keys, the
headerless board); `CF-130` adds one more `probe` warning of that same class and no new class.

ch:trace row=CF-130 spec=docs/ACCEPTANCE-PLAN.md wave=none:sync-tick-no-manifest test=tests/selftest.sh::selftest doc=docs/audits/code-factory-sync-2026-11-03-2348.md prompt=prompts/sync.md evidence=docs/audits/code-factory-sync-2026-11-03-2348.md witness=docs/audits/code-factory-sync-2026-11-03-2348.md verdict=none:sync-lane judge task SYNC-20261103-2348 memory=none:recorded-after-closeout-in-duckbrain
