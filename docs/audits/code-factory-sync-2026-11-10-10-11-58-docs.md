# Code-factory sync audit: LOOP-CODEX harness status

Row: `CF-SYNC-2026-11-10-10-11-58-docs`

## Measured published reference

The published reference measured for this reconciliation was:

`origin/main = 8fb37a282f71feea0cc6f3fba68270aa56c67952`

Board measurements were taken from the board files at that exact published ref:

- Task rows: `444`
- Events: `652`
- Status split: `126 complete / 14 in_progress / 304 pending`
- Board validator: `RESULT: OK` with `91` existing warnings
- `cf198`: `RESULT: OK arms_plan=68 arms_tree=68`

## Source commands and outputs

```text
$ git rev-parse origin/main
8fb37a282f71feea0cc6f3fba68270aa56c67952

$ git show origin/main:.coding-hermes/board/tasks.jsonl | wc -l
444

$ git show origin/main:.coding-hermes/board/events.jsonl | wc -l
652

$ git show origin/main:.coding-hermes/board/tasks.jsonl | jq -s 'map(.status) | {complete: map(select(. == "complete")) | length, in_progress: map(select(. == "in_progress")) | length, pending: map(select(. == "pending")) | length}'
{"complete":126,"in_progress":14,"pending":304}

$ bash docs/audits/cf198-section-mapping.sh
...
arms_plan=68 arms_tree=68
RESULT: OK
```

The measured S5 source check was:

```text
$ grep -n 'S5\|1 of 7\|six in flight\|CF-225.*CF-227.*CF-228' docs/LOOP-CODEX.md
25:| **S5** harness matrix | `tests/harness-conformance.sh` prints five legs per harness, `PASS` or `SKIP` naming the missing credential | **Hermes measured; foreign-harness implementations have landed for claude-code, codex and pi, but live-node conformance remains unverified** — see `CF-225`, `CF-227`, `CF-228` (complete; fixture or installer evidence, live-node residuals retained) |
```

## Contradiction and reconciliation

The stale S5 status said `1 of 7 — hermes measured; six in flight`. That statement contradicted the measured published board: `CF-225`, `CF-227`, and `CF-228` are complete and carry implementation or fixture/installer evidence, while their live-node residuals remain explicitly unverified. The status sheet therefore had to distinguish landed foreign-harness work from unavailable live-node conformance rather than retain the six-in-flight count.

The exact replacement in `docs/LOOP-CODEX.md` is:

`Hermes measured; foreign-harness implementations have landed for claude-code, codex and pi, but live-node conformance remains unverified — see CF-225, CF-227, CF-228 (complete; fixture or installer evidence, live-node residuals retained)`

The remaining open work measured at the same ref is:

- `CF-249` — `in_progress`: a real foreman directive still needs to make the node harness run and record what it was doing.
- `CF-210` — `pending`: dispatch targets remain per-lane while the design requires every project lane to funnel through its project's bunker.
- `CF-392` — `pending`: a node run still cannot declare its own artifact set; `verify-node` returns one file.

This is a documentation reconciliation only. It does not claim live-node conformance or close any residual row.

ch:trace row=CF-SYNC-2026-11-10-10-11-58-docs spec=docs/handbook/OUTLINE.md#part-iii-modules wave=none:sync-audit test=docs/audits/code-factory-sync-2026-11-10-10-11-58-docs.md::measured-reconciliation doc=docs/LOOP-CODEX.md prompt=worker-brief.txt evidence=docs/audits/code-factory-sync-2026-11-10-10-11-58-docs.md witness=none:live-node-conformance-not-available verdict=none:memory-only-or-docs-reconciliation commit=none:pending-closeout memory=none:unverified

STATUS: partial
TIER: T0
EVIDENCE: docs/audits/code-factory-sync-2026-11-10-10-11-58-docs.md