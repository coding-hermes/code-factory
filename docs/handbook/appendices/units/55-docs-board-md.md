# 55. docs/BOARD.md — the board operation contract

| Field | Value |
|---|---|
| Path | `~/code-factory/docs/BOARD.md` |
| Repository | `code-factory` |
| Revision | `8f77667b` |
| Status | **VERIFIED — the contract is described from its own sections; its rules are the ones the board tooling and the evidence checker enforce** |

## 1. Purpose and why it matters

How the fleet remembers what it decided and what it proved: the board is Git-tracked JSONL
— task rows in `.coding-hermes/board/tasks.jsonl`, append-only audit events in
`.coding-hermes/board/events.jsonl` (`docs/BOARD.md:3-6`) [fact: FACT-09]. The contract's
hard rule is closure evidence: a `complete` status requires a bound run/evidence artifact
accepted by the CLI, and a commit message is not completion evidence
(`docs/BOARD.md:38-39`) [fact: FACT-10]. What breaks if it is absent: every lane invents
its own row vocabulary and "done" stops being checkable. What breaks if it lies: rows
close on prose and the board becomes a diary instead of an evidence store.

## 2. Dependencies and library contracts

| Dependency | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `scripts/boardctl` | this repo | the project-owned entrypoint into the canonical board tool — parser, schema checks, evidence binding, concurrent-write handling (`docs/BOARD.md:14-23`) | a weaker duplicate board engine appears in this repo |
| `scripts/board_evidence_check.py` | this repo | prints closure-evidence findings; the same rule the contract states (`docs/BOARD.md:59`) | evidence rules exist only in prose |
| `scripts/board_lock.py` | this repo | adjudicates whether the lock is held and by whom (§ Board lock adjudication, `docs/BOARD.md:63`) | a live lock is read as residue or vice versa |
| `scripts/board_drift.py` | this repo | the re-runnable publish-drift census; a health claim cites it, not a memory (`docs/BOARD.md:145`) | drift is asserted without an instrument |

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| every locator on this page resolves | `python3 scripts/master_doc_check.py docs/handbook/appendices/units --only 55- --strict` | `MASTER-DOC: PASS` | 2026-11-22 | PASS |
| the live board validates under the contract's own tool | `bash scripts/boardctl validate` | `RESULT: OK (n warning(s))` | 2026-11-22 at `8f77667b` | PASS — validate ran clean (warnings only, see commit body) |
| the closure rule is on the named lines | `sed -n 38,39p docs/BOARD.md` | "A complete status requires a bound run/evidence artifact … A commit message is not completion evidence." | 2026-11-22 | PASS |

## 4. Metrics emitted

None as counters. The board's measurable state is row/event counts and status
distributions — read with the contract's own commands (`boardctl list --json --all`,
`board_evidence_check.py`, `board_drift.py check`) — and the publish-drift census section
tells the reader which instrument produced any quoted figure (`docs/BOARD.md:110-145`).

## 5. Log lines it can generate

- Through `boardctl`: `RESULT: OK (n warning(s))` on validate, per-row listings, and the
  refusal lines for a duplicate id or a malformed row — the CLI is the only writer, so
  these rows are the write path's whole voice (`docs/BOARD.md:14-23`).
- Through the evidence checker: the named per-row findings of `docs/BOARD.md:49-59` —
  the two accepted evidence shapes and what an empty list is.

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| A row closed on a commit message | `complete` with no bound artifact | the contract's rule + the checker's findings (`docs/BOARD.md:38-39,59`) | reopen; bind the run/evidence artifact |
| A held lock read as residue (or the reverse) | a stale `.lock` judgement | `board_lock.py` prints one verdict line naming holder or consumers (`docs/BOARD.md:63`) | re-run the adjudicator before touching the lock |
| Working copy treated as canonical | local edits read as decisions | the board lives in git; readers use the canonical ref (record 46's protocol) | read from the ref; publish through boardctl |

## 7. Environment and settings it reads

| setting | source | requirement |
|---|---|---|
| the board store | `.coding-hermes/board/tasks.jsonl` + `events.jsonl` (`docs/BOARD.md:3-6`) [fact: FACT-09] | append-only, one JSON object per line |
| the boardctl executable | on `PATH`; absence fails closed with exit 127 (`docs/BOARD.md:25`) | never a second, weaker parser in this repo |
| the measured-state section | newest snapshot names the tip it was measured at (`docs/BOARD.md:148`) | numbers are pinned to a tip; re-measure rather than quote |

## 8. Evidence of record

- The contract: store paths `docs/BOARD.md:3-6`, write rules `:29-46`, closure evidence
  shapes `:49-59`, lock adjudication `:63`, publish-drift census `:110-145`, measured
  state `:148`.
- The enforcing tools are unit-covered on the script side: boardctl, board_drift.py,
  board_lock.py, board_evidence_check.py (records 02/03 and the census's script rows).
- The closure law and the store identity: fact: FACT-09 and fact: FACT-10; the foreman
  prompt restates both for the lane (`prompts/foreman.md:83-85`).
