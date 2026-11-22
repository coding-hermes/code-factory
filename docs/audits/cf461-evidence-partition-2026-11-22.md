# CF-461 — closure-evidence partition at 342cbf20 (2026-11-22)

Row: CF-461. Chapter: III.M4.S1. Instrument:
`docs/audits/cf461-evidence-partition.py`. Board: `origin/main` (615 rows,
224 complete) as published at commit `342cbf20be1d66cae684e9faf319847e85ddf517`.

The partition reuses `scripts/board_evidence_check.py`'s own evidence-shape and
resolution rules, so the two instruments cannot drift: its finding count equals the
gate's for the same history store (measured: 66 unresolved + 4 zero-evidence = 70,
which is the checker's `checked 224 complete rows, 70 unresolved`).

## Denominators (both stores, named)

| store | value |
|---|---|
| committed board | `.coding-hermes/board/tasks.jsonl`, 615 rows, 224 complete |
| committed event log | `.coding-hermes/board/events.jsonl`, tracked, 0 ignored lines |
| GitReins history store | the registered checkout's `.gitreins/history`, 243 run dirs |

The history store is git-untracked, so the same committed tree reports a larger
finding population in a checkout that has no run directories (a fresh clone or CI)
by construction. This artifact grades the registered checkout's store; a CI-shaped
count is a different population and must not be compared to it as a ratio.

## Class counts

| class | count | owning action |
|---|---|---|
| resolvable | 154 | none — the evidence resolves in a named store |
| artifact-lost | 8 | rebind to the verdict artifact that exists (step 1 below) |
| never-judged | 58 | re-judge at the row's own commit before the close counts as acceptance |
| zero-evidence | 4 | NOT this row's — owned by CF-513 (listed for completeness only) |

## 1. Artifact-lost rows — REBIND candidates

Each row cites a run that resolves nowhere, while a verdict artifact for the same
row id exists under the history store. `commit-match` means the candidate verdict
graded exactly the commit the row binds; `commit-differs` means the candidate graded
a different tree and is a rebind candidate only if the row's commit is an ancestor
of the graded commit (assert with `git merge-base --is-ancestor` before rebinding).

| row | cited pointer(s) | candidate run | passed | commit binding | graded commit |
|---|---|---|---|---|---|
| CF-007 | `222a8b0` | `2026-11-14/74cbc641` | True | commit-differs | `87b74b72` |
| CF-050 | `code-factory-releng-2026-11-03-11-39-44,72863b1f` | `2026-11-11/82869669` | False | commit-match | `1d65602b` |
| CF-226 | `d87850d4` | `2026-11-09/8569c2e5` | False | commit-differs | `f08bb4cf` |
|  | `` | `2026-11-09/d4e31bf8` | False | commit-differs | `899bfe5c` |
|  | `` | `2026-11-09/f92f631f` | False | commit-match | `b8fb9920` |
| CF-401 | `0f9484e7` | `2026-11-09/599f1b59` | False | commit-differs | `b4bea63a` |
|  | `` | `2026-11-09/c78d1397` | True | commit-match | `2bdcef9a` |
| CF-402 | `2cecc44e,7266c435` | `2026-11-09/7266c435` | True | commit-match | `9bd994be` |
| CF-404 | `907d6d89` | `2026-11-10/3bf4b96a` | True | commit-match | `cd431e52` |
| CF-411 | `602295a9` | `2026-11-10/5673492b` | False | commit-match | `f81e1201` |
| PERF-018 | `code-factory-perf-2026-11-17-02-40-53,24b65cde` | `2026-11-17/24b65cde` | True | commit-match | `e24d2e97` |

## 2. Never-judged rows — no verdict artifact exists for the row id

These rows were closed without any judge run present under the history store. The
owning action is a re-judge at the row's own commit (or a reopen if the commit no
longer carries the claimed change); a close without a verdict is not acceptance.

- `CF-008` — cited `963a3b3b`
- `CF-011` — cited `code-factory-pm-20261031-114422-cf011,sync-20261103-cf011,CF-045-2026-11-14-selftest`
- `CF-012` — cited `CF012-FOREMAN-20261031-1025`
- `CF-013` — cited `code-factory-pm-20261031-114422-cf013,sync-20261103-cf013,CF-045-2026-11-14-selftest`
- `CF-034` — cited `code-factory-readme-2026-10-31-20-00-26-cf034`
- `CF-037` — cited `d701c539`
- `CF-038` — cited `code-factory-readme-2026-10-30-23-28-00-cf038,25d05620`
- `CF-041` — cited `code-factory-dogfood-2026-11-03-08-10-14,9a957be6`
- `CF-051` — cited `code-factory-dogfood-2026-11-03-11-41-54,6fb779ad`
- `CF-052` — cited `222a8b0`
- `CF-064` — cited `cddf1a3d`
- `CF-082` — cited `e2bd149d`
- `CF-089` — cited `2566eeb5`
- `CF-090` — cited `b99b7a52`
- `CF-092` — cited `85a9f4c3`
- `CF-096` — cited `7c2c8c8d`
- `CF-097` — cited `b427397d`
- `CF-114` — cited `5bf7e7d7`
- `CF-115` — cited `c448bd9d`
- `CF-127` — cited `54dce109`
- `CF-128` — cited `46d622ac`
- `CF-141` — cited `d1db81f0`
- `CF-150` — cited `71cc322f`
- `CF-153` — cited `code-factory-dogfood-2026-11-04-02-39-16,a516e16f`
- `CF-157` — cited `c602b132`
- `CF-167` — cited `a257fbd6`
- `CF-170` — cited `1851f8e9`
- `CF-182` — cited `360388a9`
- `CF-192` — cited `a43b1573`
- `CF-197` — cited `c884d5d4`
- `CF-198` — cited `efce6b5c,393261da`
- `CF-219` — cited `3f14d5b8`
- `CF-230` — cited `86c1c325`
- `CF-244` — cited `210c8cb9`
- `CF-245` — cited `a6e7120a`
- `CF-257` — cited `bd8315a0`
- `CF-259` — cited `0ae5eef6`
- `CF-270` — cited `ce8bbfbc`
- `CF-275` — cited `adbcd66a`
- `CF-277` — cited `3b40fb2a`
- `CF-280` — cited `c2c24292`
- `CF-291` — cited `7af789d3`
- `CF-303` — cited `1c00c57d`
- `CF-307` — cited `21b706ef`
- `CF-320` — cited `87ce8fa8`
- `CF-323` — cited `b68e5407`
- `CF-354` — cited `d18975d7`
- `CF-370` — cited `08b7fa1f,08b7fa1f`
- `CF-378` — cited `e060b303`
- `CF-379` — cited `3d8734a9`
- `CF-382` — cited `737c86d3`
- `CF-470` — cited `43936119176`
- `CF-504` — cited `9c314d90`
- `CF-517` — cited `96c7dd52,69a1f953`
- `P5G-16` — cited `d51510f2`
- `PERF-012` — cited `code-factory-perf-2026-11-03-10-56-35-selftest-board-30row`
- `PERF-014` — cited `code-factory-perf-2026-11-03-14-51-11,code-factory-perf-2026-11-03-16-08-21`
- `QA-CODE-FACTORY-2` — cited `3251e0c5`

## 3. Zero-evidence rows — excluded here, owned by CF-513

Measured, and it does NOT match CF-513's title: CF-513 states that two rows carry no
evidence (P5G-34, CF-422) after three of five were repaired. The gate reports FOUR:

- `CF-289`
- `CF-305`
- `CF-422`
- `P5G-34`

CF-289 and CF-305 are therefore still zero-evidence; that correction belongs on CF-513
and is recorded in this tick's handoff rather than acted on from CF-461.

## Reproduce

```
python3 docs/audits/cf461-evidence-partition.py . .coding-hermes/board/tasks.jsonl ~/code-factory/.gitreins/history
python3 scripts/board_evidence_check.py --history-root ~/code-factory/.gitreins/history
```

## What this artifact does NOT do

It does not rebind any row and does not close CF-461. Rebinding rewrites
`detail.evidence` on the rows above and is a separate, reviewable step: this tick ran
under a live evaluator hold on the canonical checkout, so no board file was written.

