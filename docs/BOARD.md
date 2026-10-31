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

## Current measured state (2026-10-31)

- `scripts/boardctl validate`: 24 task rows, 37 events, no key drift, `RESULT: OK`; warning: the
  board has no optional header, so header-counter checks are skipped.
- `tests/selftest.sh`: `PASS 24/24 rows parse` and `SELFTEST: PASS`.
- CF-012 is complete on the published tip with `docs/traceability-doctrine.md` and its committed
  evidence artifact; the row's closeout is bound to the board evidence record and GitReins verdict.
- The project wrapper is a dispatch shim; the authoritative board implementation remains the
  external coding-hermes `boardctl` package.
