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
census agrees, and the checkout's HEAD is an ancestor of that ref. FAIL names the measured
mismatch, divergent task IDs, missing files or invalid line numbers; a zero-row task board
is always a FAIL. The final verdict is `RESULT: OK` (exit 0) or `RESULT: DRIFT` with a failure
count (exit 1). `--repo <path>` selects the repository resolving the ref; `--no-head` skips
ancestry. `--published-dir <dir>` reads fixture files instead of Git and implies `--no-head`.

Observed on 2026-11-03 before the workdir repair: the registered code-factory workdir
(`~/proj-wt-code-factory-bankai-20261030`) carried 61 tasks rows / 66 events rows against
88 / 124 at `origin/main` `6e8621f`. CF-053, CF-064, CF-065, CF-075 and PERF-014 read
`pending` there while `complete` at `origin/main`. This is a dated observation, not a current
health claim. `scripts/board_drift.py` is the re-runnable tool; `tests/selftest.sh` arm 29
proves its divergent, identical, empty, missing-file and malformed-record fixture paths.

## Current measured state (measured 2026-11-04T01:36Z at tip `f49d85b`)

Every count below is an output value that moves with each folded row, so measure it instead of
quoting an older snapshot. The numbers are still typed by hand — CF-081 tracks replacing this block
with a committed check that derives them and fails on a mismatch.

```sh
wc -l .coding-hermes/board/tasks.jsonl .coding-hermes/board/events.jsonl
scripts/boardctl validate
bash tests/selftest.sh | grep -E 'rows parse|^SELFTEST'
```

- At tip `f49d85b`: 114 task rows, 162 events. `scripts/boardctl validate` prints
  `RESULT: OK (46 warning(s))` — 43 rows carrying a free-form `probe` key, CF-034's free-form
  `guard_result`/`ci_result` prose, and the headerless board (no `board.jsonl`), so header-counter
  checks are skipped.
- `tests/selftest.sh` prints `PASS 114/114 rows parse` and `SELFTEST: PASS` (exit 0; 29 numbered
  sections plus lettered arms 4b and 7b — 31 arms).
  Nineteen `  FAIL` lines appear *inside* negative fixtures that assert a failure arm; count
  `SELFTEST:` and the per-section verdicts, never a raw `grep -c '^  FAIL'`.
- Completion evidence must live in this repository. Two rows (CF-011, CF-013) once cited an
  absolute scratch log outside the tree; the sync lane rebound them to a committed artifact —
  `docs/audits/code-factory-sync-2026-11-03-evidence-rebind.md` records the re-run commands and
  captured output.
- CF-012 is complete on the published tip with `docs/traceability-doctrine.md` and its committed
  evidence artifact; the row's closeout is bound to the board evidence record and GitReins verdict.
- The project wrapper is a dispatch shim; the authoritative board implementation remains the
  external coding-hermes `boardctl` package.
