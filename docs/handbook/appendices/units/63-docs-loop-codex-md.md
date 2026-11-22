# 63. docs/LOOP-CODEX.md — what the operating loop reads

| Field | Value |
|---|---|
| Path | `~/code-factory/docs/LOOP-CODEX.md` |
| Repository | `code-factory` |
| Revision | `8f77667b` |
| Status | **VERIFIED — the loop codex is described from its own sections; its authority chain and stage table are quoted with resolving lines** |

## 1. Purpose and why it matters

The machine-readable half of the handbook's flow sheet: the stages, the commands that
close each, the flows, and the deficiency register an operating loop picks from
(`docs/LOOP-CODEX.md:3,16-67`). Its authority rule is explicit and reversible: it and the
rendered sheet say the same thing, and if they disagree the file is wrong and the sheet
wins — fix it in the same tick (`docs/LOOP-CODEX.md:5`). What breaks if it is absent: a
loop improvises its own stage list and its own closure commands. What breaks if it lies:
a stage is marked closed on a command that no longer proves it — which is why its own
header orders re-measurement: measured state must be re-measured, not quoted, before a
row is closed (`docs/LOOP-CODEX.md:9-11`).

## 2. Dependencies and library contracts

| Dependency | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `specs/HARNESS-MATRIX.md` | this repo | the harness-selection authority the codex names (`docs/LOOP-CODEX.md:7`) | stage S5's exit test disagrees with the matrix |
| `specs/NODE.md` | this repo | the node contract authority (`docs/LOOP-CODEX.md:7`) | the stage ladder drifts from the node contract |
| `docs/MVP-PLAN.md` | this repo | the workstream order authority (record 60) | stages and phases disagree on order |
| the stage exit tests | the named commands (`docs/LOOP-CODEX.md:16-31`) | each stage closes only on its command's output | a stage closes on narrative |

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| every locator on this page resolves | `python3 scripts/master_doc_check.py docs/handbook/appendices/units --only 63- --strict` | `MASTER-DOC: PASS` | 2026-11-22 | PASS |
| the authority line names the three authorities | `sed -n 7p docs/LOOP-CODEX.md` | HARNESS-MATRIX, NODE, MVP-PLAN | 2026-11-22 at `8f77667b` | PASS |
| the stage table is on the named line | `sed -n 16,20p docs/LOOP-CODEX.md` | the table heading + the S0 row with its exit commands | 2026-11-22 | PASS |

## 4. Metrics emitted

None as counters. Its measurable output is the stage table's State column — each stage
closed only by its exit test's output — and the deficiency register, whose rows are
board-ownable findings rather than prose (`docs/LOOP-CODEX.md:44-67`).

## 5. Log lines it can generate

- The exit tests' own lines: the control-host health codes, `BUNKER: PASS`,
  `BUS WORKER: READY`, the landing ancestry proof, the conformance battery's six leg
  families (`docs/LOOP-CODEX.md:20-31`) — each recorded on its own unit page; this record
  cites them as the stage gates, never as its own output.

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| A stage closed on quoted state | "CLOSED" carried forward from an old run | the re-measure rule (`docs/LOOP-CODEX.md:9-11`) | re-run the exit test at the current tip |
| The codex and the rendered sheet disagree | two truths for one flow | the authority rule: the sheet wins, fix the file in the same tick (`docs/LOOP-CODEX.md:5`) | correct this file; never the sheet, in that tick |
| The register read as work | rows picked without board ownership | the register's rows are board findings (`docs/LOOP-CODEX.md:44-67`) | pick via the board; file what is missing |

## 7. Environment and settings it reads

| setting | source | requirement |
|---|---|---|
| service health | scheduler :9090, crier :8767, DuckBrain (`docs/LOOP-CODEX.md:20`) | stage S0 closes only on all three |
| the node | `bunker-provision.sh --check`, the bus worker's `--check` (`:22-24`) | stage gates are the scripts' own check modes |
| the tick protocol | §4 (`docs/LOOP-CODEX.md:70-85`) | what a loop may decide alone is bounded (`:88-91`) |

## 8. Evidence of record

- The codex: sheet-pairing + authority rule `docs/LOOP-CODEX.md:3-5`, re-measure rule
  `:9-11`, authority chain `:7`, stage table `:16-31`, flows `:32-42`, deficiency
  register `:44-67`, tick protocol `:70-85`, decision bounds `:88-93`.
- The unit of progress it names is the board row (record 55's store, `:93-95`); the
  closure law behind every exit test: fact: FACT-10.
- The authorities it defers to are unit-covered here: HARNESS-MATRIX (record 38's spec
  family), NODE (record 40), MVP-PLAN (record 60).
