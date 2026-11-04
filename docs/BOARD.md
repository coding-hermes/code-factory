# Board operation contract

The project board is Git-tracked JSONL:

- `.coding-hermes/board/tasks.jsonl` — task rows (one JSON object per line).
- `.coding-hermes/board/events.jsonl` — append-only audit events.

Use the repository entrypoint from the repository root:

```sh
scripts/boardctl validate
scripts/boardctl list --json --all
scripts/boardctl show CF-001 --events
scripts/boardctl create --id CF-009 --title "..." --priority P1 \
  --reasoning "..." --acceptance-criteria "1. ..."
scripts/boardctl update CF-009 --status in_progress
scripts/boardctl event --type audit --task-id CF-009 --actor foreman \
  --detail-text "..."
```

`scripts/boardctl` is a project-owned entrypoint, not a second board engine. It invokes the
coding-hermes `boardctl` executable with this repository as its board root. This keeps the
JSONL parser, schema checks, evidence binding, event format and concurrent-write handling in the
canonical tool rather than implementing a weaker duplicate here. The executable must be installed
and on `PATH`; absence fails closed with exit 127. Its upstream project/release is the source of
truth for installation and updates. Do not copy private fleet binaries or credentials into this
public repo.

## Write rules

1. Validate before and after a batch of board edits: `scripts/boardctl validate`.
2. Use `create` to add a row and `update` to change a row's status; do not rewrite either JSONL
   file wholesale or edit them with ad-hoc scripts.
3. A `complete` status requires a bound run/evidence artifact accepted by the CLI. A commit message
   is not completion evidence.
4. Record meaningful transitions with `event`; do not include credentials, private endpoints or
   raw sensitive logs in a public board.
5. Keep task IDs unique and acceptance criteria falsifiable. `tests/selftest.sh` checks row parsing;
   the boardctl validator is the schema/consistency gate.

## Publish-drift census

Before editing a checkout's board, run the offline, read-only repository check (local refs
must already be current; the check never fetches):

```sh
python3 scripts/board_drift.py check --workdir <path> --ref origin/main
```

PASS means both board files are readable and byte-identical to the published ref, the task
census agrees, and the workdir's HEAD is an ancestor of that ref **as resolved in the workdir**.
FAIL names the measured mismatch, divergent task IDs, missing files or invalid line numbers; a
zero-row task board is always a FAIL. The final verdict is `RESULT: OK` (exit 0) or
`RESULT: DRIFT` with a failure count (exit 1).

The two legs read Git from two different flags, and naming one does not satisfy the other:

- the **published bytes** come from `--repo <path>` — `git -C <repo> show <ref>:<file>`
  (`scripts/board_drift.py:98,111`); `--repo` defaults to the workdir;
- the **HEAD/ancestry leg** is measured in `--workdir` — `git rev-parse HEAD`,
  `git rev-parse --verify <ref>^{commit}` and `git merge-base --is-ancestor HEAD <ref>` all run
  with `-C <workdir>` (`scripts/board_drift.py:167–172`).

So a workdir that carries no ref named `<ref>` prints `FAIL HEAD ancestry — git rev-parse
--verify origin/main^{commit}: exit 128` and `RESULT: DRIFT (1 failed)` even when `--repo` names
a repository that has the ref; the identical run with `--no-head` prints `RESULT: OK`. Measured
on 2026-11-04 against a workdir fixture holding byte-identical 126-row board files with no
`origin/main` ref (CF-129; transcript `docs/audits/code-factory-docs-2026-11-04-CF-129.md`).
Pass `--no-head` when the ref lives only in `--repo`. `--published-dir <dir>` reads fixture files
instead of Git and implies `--no-head`.

Observed on 2026-11-03 before the workdir repair: the registered code-factory workdir
(`~/proj-wt-code-factory-bankai-20261030`) carried 61 tasks rows / 66 events rows against
88 / 124 at `origin/main` `6e8621f`. CF-053, CF-064, CF-065, CF-075 and PERF-014 read
`pending` there while `complete` at `origin/main`. This is a dated observation, not a current
health claim. `scripts/board_drift.py` is the re-runnable tool; `tests/selftest.sh` arm 29
proves its divergent, identical, empty, missing-file and malformed-record fixture paths.

## Current measured state (measured 2026-11-04T01:58Z, on the tree this commit lands)

Every count below is an output value that moves with each folded row, so measure it instead of
quoting an older snapshot. The numbers are still typed by hand — CF-081 tracks replacing this block
with a committed check that derives them and fails on a mismatch.

```sh
wc -l .coding-hermes/board/tasks.jsonl .coding-hermes/board/events.jsonl
scripts/boardctl validate
bash tests/selftest.sh | grep -E 'rows parse|^SELFTEST'
```

- **Re-measured 2026-11-04T03:01Z at tip `dae4e7a`:** 127 task rows, 193 events — 40 `complete`,
  5 `in_progress`, 82 `pending`. `scripts/boardctl validate` prints `RESULT: OK (3 warning(s))`
  (CF-034's free-form `guard_result`/`ci_result` plus the headerless board); the 44 `probe`-key
  warnings are gone because CF-129 relanded canon keys (`key uniformity: 127/127 rows`).
  `tests/selftest.sh` prints `SELFTEST: PASS`, `PASS 127/127 rows parse`, 92 `PASS` rows, 30
  numbered sections plus lettered arms `4b`/`7b`, at loadavg 15.60.
- At this tree (earlier snapshot, 116 task rows, 168 events): `scripts/boardctl validate` prints
  `RESULT: OK (47 warning(s))` — 44 rows carrying a free-form `probe` key, CF-034's free-form
  `guard_result`/`ci_result` prose, and the headerless board (no `board.jsonl`), so header-counter
  checks are skipped.
- `tests/selftest.sh` prints `PASS 116/116 rows parse` and `SELFTEST: PASS` (exit 0; 29 numbered
  sections plus lettered arms 4b and 7b — 31 arms).
  Nineteen `  FAIL` lines appear *inside* negative fixtures that assert a failure arm; count
  `SELFTEST:` and the per-section verdicts, never a raw `grep -c '^  FAIL'`.
- A `complete` row must bind the commit that carried it, not only an evidence artifact: CF-053
  reached `complete` with `commit_hash: null` and `worker_status: pending`, and now carries
  `80fca8b` (the commit that closed it) with the repoint re-verified by
  `scripts/lane_target.py scan` over the 19 code-factory lanes (`bad: 0`, `ok: true`).
- Two rows (CF-034, CF-041) are `complete` and commit-bound but carry no `task_completed` event;
  event 168 (audit, 2026-11-04) records the gap and CF-130 owns the reconciliation. No completion
  transition was minted for either id, because the log must not record a transition its writer did
  not witness.
- The CI-equivalent gate is not deterministic under load: `tests/selftest.sh` returned
  `SELFTEST: FAIL (1)` once in four runs at one tip on an unchanged tree, on the auth-marker arm.
  CF-142 tracks the reproduction and requires 20 consecutive agreeing runs plus a recorded loadavg.
  Before believing a single red, re-run it; before believing a single green, note the load.
- Completion evidence must live in this repository. Two rows (CF-011, CF-013) once cited an
  absolute scratch log outside the tree; the sync lane rebound them to a committed artifact —
  `docs/audits/code-factory-sync-2026-11-03-evidence-rebind.md` records the re-run commands and
  captured output.
- CF-012 is complete on the published tip with `docs/traceability-doctrine.md` and its committed
  evidence artifact; the row's closeout is bound to the board evidence record and GitReins verdict.
- The project wrapper is a dispatch shim; the authoritative board implementation remains the
  external coding-hermes `boardctl` package.
