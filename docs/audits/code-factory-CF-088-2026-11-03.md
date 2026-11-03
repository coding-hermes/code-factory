# CF-088 — the selftest board arm accepted any valid JSON

Tick: `code-factory-2026-11-03-19-32-27` · fix commit `64057d5` · GitReins verdict `627fe92b`
(run dir `.gitreins/history/2026-11-03/d0f1236d/`, tier1 PASS, tier2 PASS/COMPLETE).

## Premise (measured at `80fca8b`)

`tests/selftest.sh` section 7 (old lines 159-183) ran one Python parser over
`.coding-hermes/board/tasks.jsonl` and passed when `json.loads` succeeded on each newline-terminated
line. Valid JSON that is not a board row therefore passed: `null`, `[]`, `"fixture"`, `42`, an
object with no `id`, a row with no `status`, a duplicate `id`, or a status outside the closed
vocabulary (`pending | in_progress | blocked | complete`, AGENTS.md §The board). `scripts/boardctl
validate` rejects all of these, so the gate greened boards the project's own validator refuses.

## Fix (`64057d5`, one file: `tests/selftest.sh`, +101/−18)

- Section 7 now calls a shared `board_arm` function. One Python process per board (PERF-012
  preserved: no per-row `python3`), newline-terminated records only (unchanged `while read`
  semantics), empty board still 0/0.
- Rejected classes, each naming the 1-based line: non-object record, malformed JSON, missing/empty
  or non-string `id`, duplicate `id` (both line numbers), missing `status` (error, not warning),
  `status` outside the closed vocabulary. Every offending record is reported in one run.
- `python3` absent -> `FAIL  board parser: python3 missing`, exit 1 (fail closed, unchanged shape).
- New numbered section 7b builds nine `mktemp` fixtures (null/array/string/number/missing-id/
  duplicate-id/bad-status/missing-status/malformed) and asserts each prints a gate FAIL and the
  `FAIL  2 of 3 rows parse` line, plus a 4-record fixture proving all line numbers are reported at
  once, plus a clean 2-row positive control. No boardctl dependency: the arm is self-contained.

## Acceptance commands (run by the foreman at `64057d5`)

```
$ bash -n tests/selftest.sh                  # rc=0
$ bash tests/selftest.sh                     # rc=0, 27.1 s
  ...
  7. the board is valid JSONL
    PASS  85/85 rows parse
  7b. board gate rejects invalid records with line-numbered FAIL rows (CF-088)
    PASS  null fixture rejected, exit 1
    FAIL  board line 2: expected JSON object, got null
    ...
    PASS  missing python3 -> named FAIL, exit 1
  SELFTEST: PASS
$ scripts/boardctl validate                  # rc=0
  RESULT: OK (28 warning(s))
```

## Independent foreman probe (not the worker's transcript)

The new `board_arm` was extracted from the shipped file and run over seven fixtures; the PRE-FIX
parser was extracted verbatim from `80fca8b:tests/selftest.sh` and run over the same bytes:

| fixture | new arm | pre-fix arm |
|---|---|---|
| clean 2-row board | PASS `2/2 rows parse`, rc 0 | — |
| `null` | FAIL `board line 2: expected JSON object, got null`, rc 1 | `3 3`, rc 0 |
| `[]` | FAIL `board line 2: expected JSON object, got []`, rc 1 | `3 3`, rc 0 |
| `"fixture"` | FAIL `board line 2: expected JSON object, got "fixture"`, rc 1 | `3 3`, rc 0 |
| duplicate id | FAIL `board duplicate id 'CF-001': lines 1 and 2`, rc 1 | `3 3`, rc 0 |
| `status":"done"` | FAIL `board line 2: invalid status "done"`, rc 1 | `3 3`, rc 0 |
| missing status | FAIL `board line 2: missing status`, rc 1 | `3 3`, rc 0 |
| missing id | FAIL `board line 2: missing id`, rc 1 | `3 3`, rc 0 |
| real board | PASS `85/85 rows parse`, rc 0 | — |

`PROBE_FAILS=0`: every class separates the fixed arm from the pre-fix arm, and the clean control
goes green.

## Guard / CI

- Manual Tier 1 guard at the landed tree: `Tier 1 Guards: PASS (test mode: full, whole tree)` —
  secrets clean (gitleaks + builtin), lint ok, `bash tests/selftest.sh` PASS. Guard log
  `.gitreins/logs/guard-20261103T194210.927999Z.log`.
- Guard position disclosed: the tick ran in a fresh clone, which has no installed Git hooks, so
  the configured checks were run manually (CF-031 precedent). The change is shell/test-only, so
  GitHub Actions: none configured in this repo — `ci: SKIP`, not green-by-evidence.

## Evidence binding

- Implementation commit `64057d5` (rebased onto `a9d0cc8`; pre-rebase identical-tree commit
  `7b544f3`, tree `810bde9f8a19e78aa07d78b42f066e861b04fc5b`). The commit body's trace names the
  worker's pre-amend identical-tree commit `cc64d374`, which is not published; the tree it names
  is exactly the landed tree.
- GitReins verdict `627fe92b`, task `CF-088`, `passed: true`, `commit: 64057d5…`,
  run dir `.gitreins/history/2026-11-03/d0f1236d/`.
