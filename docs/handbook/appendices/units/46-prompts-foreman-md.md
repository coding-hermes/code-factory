# 46. prompts/foreman.md — the foreman's operating instruction

| Field | Value |
|---|---|
| Path | `~/code-factory/prompts/foreman.md` |
| Repository | `code-factory` |
| Revision | `8f77667b` |
| Status | **VERIFIED — the lane prompt is described from its own lines; its board and evidence rules are the same contract the board record enforces** |

## 1. Purpose and why it matters

This is the prompt the scheduler hands the code-factory foreman lane: it tells the agent
what a tick is. Its first rule is the unit of progress — "move exactly ONE board row
forward per tick" (`prompts/foreman.md:5`) — and its evidence rule is the repo's closure
law: never claim a row complete unless a command someone else can re-run demonstrates the
acceptance criteria; a commit message is not evidence (`prompts/foreman.md:84-85`)
[fact: FACT-10]. What breaks if it is absent: every lane tick improvises its own
definition of done. What breaks if it lies: the foreman reads a dirty working copy as the
canonical board or blocks on a reading instruction — the prompt names the board protocol
explicitly (`prompts/foreman.md:47-70`).

## 2. Dependencies and library contracts

| Dependency | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `scripts/board_read.py` | this repo | reads the canonical ref, falls back to the working copy only without a remote, and prints which source it used (`prompts/foreman.md:42-67`) | the "board source" report line loses its meaning |
| `scripts/ownership.py` + `prompts/unblock.md` | this repo | classify before blocking: `held-by-live-worker` → stand down; `residue` → dispose (`prompts/foreman.md:59-70`) | a dirty checkout becomes a spurious blocked receipt |
| `skills/code-factory-foreman/SKILL.md` | this repo | the admission/cooldown contract the prompt defers to (`prompts/foreman.md:76`) | two authorities disagree on lane creation |
| `skills/code-factory-bunker/SKILL.md` | this repo | provisioning/destroying is that skill's job, never ad hoc (`prompts/foreman.md:79`) | a foreman hand-edits a node |

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| every locator on this page resolves | `python3 scripts/master_doc_check.py docs/handbook/appendices/units --only 46- --strict` | `MASTER-DOC: PASS` | 2026-11-22 | PASS |
| the cited rules are on the named lines | `grep -n "ONE board row\|commit message is not evidence\|append only" prompts/foreman.md` | hits at :5, :84-85, :83 | 2026-11-22 at `8f77667b` | PASS — all three named lines carry the rules |
| the handbook section it mandates exists | `sed -n 15,23p prompts/foreman.md` + `ls docs/handbook/OUTLINE.md` | the parts list matches the outline file | 2026-11-22 | PASS |

## 4. Metrics emitted

None — a prompt emits nothing. Its compliance surface is the tick reports it requires:
row id, what changed, the proving command, what is still open (`prompts/foreman.md:13`),
plus the board-source line the board protocol adds.

## 5. Log lines it can generate

- `board source: origin/main (N rows)` — the reading instruction's report line; a tick
  that cannot name which copy it read has not followed the prompt (`prompts/foreman.md:52`).
- `STOOD DOWN` with the owner pid — the held-by-live-worker outcome, explicitly NOT a
  blocked receipt (`prompts/foreman.md:64-65`).
- The four-line report at `prompts/foreman.md:13` is the tick's own output contract.

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Dirty working copy read as canonical | rows edited by a sibling appear/disappear | `board_read.py` prints which source it used (`prompts/foreman.md:63-67`) | re-read from the canonical ref; report the source |
| "board read prohibited" while rows are dispatchable | a tick refuses work on a stale workdir | the prompt names this as a defect in the tick, not diligence (`prompts/foreman.md:65-67`) | follow the reading instruction and proceed |
| Complete claimed on prose | a row closes with a commit message | the closure law: a re-runnable command is the evidence (`prompts/foreman.md:84-85`) | reopen the row; bind the command |

## 7. Environment and settings it reads

| setting | source | requirement |
|---|---|---|
| the board store | `.coding-hermes/board/tasks.jsonl`, append-only, one JSON object per line (`prompts/foreman.md:83`) [fact: FACT-09] | the board lives in git; the working copy is a cache |
| `specs/HARNESS-MATRIX.md` §8 backlog | the prompt carries the backlog table and its picking rule (`prompts/foreman.md:89-110`) | a backlog row is never picked ahead of P0/P1 but never dropped |
| lane identity | the scheduler names the lane this prompt serves | the prompt is per-lane; the other 11 prompts under `prompts/` serve their own lanes |

## 8. Evidence of record

- The prompt itself: unit-of-progress `prompts/foreman.md:5`, handbook mandate `:15-23`,
  board protocol `:42-67`, classify-before-block `:59-70`, closure law `:84-85`,
  backlog carry rule `:89-110`.
- The contract it enforces is the board's own: fact: FACT-09 names the store, fact:
  FACT-10 the closure rule; docs/BOARD.md record (55) carries the enforcing side.
- Sibling prompts (`prompts/docs.md`, `prompts/qa.md`, `prompts/sync.md`, …) are the
  per-lane operating prompts of the same family; this record covers the foreman's, and
  the census names the rest with their lanes.
