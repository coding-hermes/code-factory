# 60. docs/MVP-PLAN.md — the workstream order

| Field | Value |
|---|---|
| Path | `~/code-factory/docs/MVP-PLAN.md` |
| Repository | `code-factory` |
| Revision | `8f77667b` |
| Status | **VERIFIED — the plan is described from its own sections; its exit-test discipline and phase table are quoted with resolving lines** |

## 1. Purpose and why it matters

The shortest path to one landed result: a single lane of a single project runs on a
bunker, returns a result, the control host lands it, and the board row closes on evidence
anyone can re-run — "every exit test is a command whose output is the proof"
(`docs/MVP-PLAN.md:3-5`) [fact: FACT-10]. It works backwards from the finish line: a
must-be-true table naming, per row, the state today and the board row that owns the gap
(`docs/MVP-PLAN.md:11-22`). What breaks if it is absent: work is sequenced by whatever
looks interesting. What breaks if it lies: a phase is declared done on narrative instead
of its exit test — the exact failure the plan's own vocabulary refuses.

## 2. Dependencies and library contracts

| Dependency | Provider | Contract relied on | If it changes |
|---|---|---|---|
| the board | tasks.jsonl rows named per table cell (`docs/MVP-PLAN.md:11-22`) | each gap has exactly one owning row | two rows claim the same gap |
| `scripts/land-node-branch.sh` | this repo | the landing proof (ancestry + file-in-tree) the finish line requires (row 1, `docs/MVP-PLAN.md:13`) | a landing is claimed on merge success alone |
| `scripts/node-bus-worker.py` | this repo | the result producer (row 3: `ok`/`error`/`reply_b64`/`in_reply_to` under an idempotency key, `docs/MVP-PLAN.md:17`) | the result shape drifts from the envelope |
| `scripts/bunker-provision.sh` | this repo | row 4: provisioning as declared inputs (`docs/MVP-PLAN.md:19`) | the provisioned node stops matching the contract |

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| every locator on this page resolves | `python3 scripts/master_doc_check.py docs/handbook/appendices/units --only 60- --strict` | `MASTER-DOC: PASS` | 2026-11-22 | PASS |
| the exit-test rule is on the named line | `sed -n 3,5p docs/MVP-PLAN.md` | goal + "every exit test is a command whose output is the proof" | 2026-11-22 at `8f77667b` | PASS |
| the phases section exists | `sed -n 30p docs/MVP-PLAN.md` | the `## Phases` heading | 2026-11-22 | PASS |

## 4. Metrics emitted

None as counters. Its measurable output is the backwards table: eight must-be-true rows,
each carrying its own state-today cell that names what is measured and what is merely
shipped (`docs/MVP-PLAN.md:11-22`), and the phases that turn those rows into an order.

## 5. Log lines it can generate

- Nothing — a plan. The lines it points at belong to the exit tests: a landing proof row,
  an inbox result row, a tick row naming the lane — each carried by its own unit record,
  quoted here only as the proof a phase must produce.

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| A phase declared done on narrative | "P0 complete" with no command | the exit-test rule (`docs/MVP-PLAN.md:5`) | run the phase's exit test; quote its output |
| Two rows owning one gap | duplicated work, one stale | the table names one row per gap (`docs/MVP-PLAN.md:11-22`) | supersede one row explicitly |
| "shipped" read as "measured on a live node" | row 4's hazard | the cell states shipped-and-unmeasured explicitly (`docs/MVP-PLAN.md:19`) | keep the distinction in the cell until measured |

## 7. Environment and settings it reads

| setting | source | requirement |
|---|---|---|
| the finish line | one lane, one bunker, one landed result (`docs/MVP-PLAN.md:3`) | scope discipline: nothing outside these four moves |
| the funnel diagnosis | crier routes per lane, not per project (`docs/MVP-PLAN.md:7-9`) | the four moves fix routing, result, refresh, landing |
| deferred scope | explicit out-of-scope section (`docs/MVP-PLAN.md:145`) | deferral is named, not silent |

## 8. Evidence of record

- The plan: goal + proof rule `docs/MVP-PLAN.md:3-5`, funnel diagnosis `:7-9`, backwards
  table `:11-22`, phases `:30`, provisioning detail `:78`, harness workstream `:100`,
  explicit deferrals `:145`.
- The closure law behind "evidence anyone can re-run": fact: FACT-10; the board store the
  rows live in: fact: FACT-09 (record 55 carries the contract).
- The authority chain this plan sits under: `specs/HARNESS-MATRIX.md`, `specs/NODE.md`,
  and this plan, per docs/LOOP-CODEX.md:7 (record 63).
