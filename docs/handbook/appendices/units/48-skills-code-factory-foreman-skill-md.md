# 48. skills/code-factory-foreman/SKILL.md — the foreman run contract

| Field | Value |
|---|---|
| Path | `~/code-factory/skills/code-factory-foreman/SKILL.md` |
| Repository | `code-factory` |
| Revision | `8f77667b` |
| Status | **VERIFIED — the run contract is described from its own lines; the admission gate it defers to is cross-checked against the scheduler-side allowlist** |

## 1. Purpose and why it matters

The skill the foreman lane loads: one board row per tick, reproducible evidence before any
completion claim, and the scheduler admission gate consulted before a satellite lane is
created or changed (`skills/code-factory-foreman/SKILL.md:9-15`) [fact: FACT-10]. What
breaks if it is absent: the lane prompt's rules have no operational skill behind them —
no admission gate, no pacing contract, no distinction between source presence, a passing
test, live proof and owner authorization (`:11`). What breaks if it lies: a satellite lane
is created with a guessed workdir root, or the primary's cooldown is reported as a delay
between ticks while work remains (`:37-39`).

## 2. Dependencies and library contracts

| Dependency | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `docs/SCHEDULER-ADMISSION.md` | this repo | the family→workdir allowlist the skill defers to (`skills/code-factory-foreman/SKILL.md:17-19`) | the skill's root list drifts from the admission contract (record 61) |
| `scripts/boardctl` | this repo | board reads/writes, validate before and after (`:13`) | the evidence-binding rule loses its tool |
| `tests/selftest.sh` | this repo | run it and the applicable guard before claiming completion (`:14`) | completions become unaudited claims |
| the scheduler API | coding-hermes/scheduler | enforces the same allowlist server-side [fact: FACT-12] | a client-side allowlist that the server does not enforce would be decoration |

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| every locator on this page resolves | `python3 scripts/master_doc_check.py docs/handbook/appendices/units --only 48- --strict` | `MASTER-DOC: PASS` | 2026-11-22 | PASS |
| the skill's family list matches the admission contract | compare `skills/code-factory-foreman/SKILL.md:21-33` with docs/SCHEDULER-ADMISSION.md:20-33 | the same nine families and roots | 2026-11-22 at `8f77667b` | PASS — qa/pm/sync/dogfood/releng/docs/readme/perf/review, same roots |
| the scheduler side enforces what the skill states | the allowlist constants exist server-side | `satelliteLaneSuffixes`/`satelliteWorkdirRoots` defined | 2026-11-22 | PASS [fact: FACT-12] |

## 4. Metrics emitted

None. The skill's measurable output is the tick report contract it shares with the lane
prompt (row id, change, proof command, blockers) and the pacing state it names:
`admission_mode=tasks` with a six-hour timer fallback only once the board is drained
(`skills/code-factory-foreman/SKILL.md:39`).

## 5. Log lines it can generate

- Nothing by itself — prose. The tick following it produces the report line of `:15`,
  the validate results of `:13` (`RESULT: OK (n warning(s))`), and a refusal record when
  the scheduler rejects a lane: the skill demands the exact API error and family be
  recorded, never an empty allowlist rationalized (`:35-36`).

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Guessed satellite workdir | the scheduler refuses the lane | the skill: derive the root from suffix + primary; never move the lane to dodge a refusal (`:17-19`) | read the admission contract, fix the root |
| Cooldown read as a delay between ticks | the primary idles while work remains | the pacing paragraph: the fallback arms only on a drained board (`:37-39`) | verify the live row and the durable config separately |
| Completion claimed without the suite | a row closes on source presence alone | the run contract separates source presence, local test, live proof and owner authorization (`:11,14`) | run selftest + guard; re-close with evidence |

## 7. Environment and settings it reads

| setting | source | requirement |
|---|---|---|
| `AGENTS.md`, the board, governing specs | repo tree | read before advancing any row (`:9-10`) |
| scheduler lane row + fleet config | live API + durable config | pacing verified in both; DB state alone is not restart-safe (`:39`) |
| `docs/SCHEDULER-ADMISSION.md` | repo docs | the authoritative family/root/cooldown table [fact: FACT-12] |

## 8. Evidence of record

- The skill itself: run contract `skills/code-factory-foreman/SKILL.md:9-15`, admission
  gate `:17-19`, family table `:21-36`, pacing `:37-39`.
- The enforcing pair: the admission contract (record 61) and the scheduler-side allowlist
  constants [fact: FACT-12]; the lane prompt binds the foreman to this skill
  (`prompts/foreman.md:103-104`).
- Closure law shared with the board record: fact: FACT-10.
