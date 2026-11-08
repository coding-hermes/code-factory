# M4 — BOARD

## 1. Identity

| Field | Value |
|---|---|
| Module name | BOARD |
| Path | `/home/kara/code-factory/.coding-hermes/board/tasks.jsonl` + `events.jsonl`; tools `/home/kara/code-factory/scripts/boardctl`, `board_lock.py`, `board_drift.py` |
| Revision | `fbc19cbc807de729e25c358fa7e94207b912f010` (code-factory HEAD; `scripts/board_read.py` was added and `handbook_spine.py` re-lined in `08a2c8a..fbc19cb`; the board store advanced 519→520 events via an uncommitted CF-150 transition) |
| Language / runtime | bash (boardctl wrapper) + Python 3.14.9 (measured) |
| Owner lane | code-factory (control host) |
| Status | **VERIFIED (store)** — 357 rows / **520** events / 0 fixtures, `boardctl validate` `RESULT: OK (7 warning(s))`; **DRIFT (working copy)** — `board_drift` `RESULT: DRIFT (4 failed)`, 1 divergent id (CF-150: workdir `in_progress` vs published `pending`), HEAD == origin/main == `fbc19cb` — the divergence is an uncommitted working-copy transition (event 520, actor `foreman`, 2026-11-07T06:09:41), not a committed divergence, and `board_read.py` resolves it to `origin/main` by design. The `boardctl` verb surface is the external executable's (`/home/kara/.local/bin/boardctl`), not this repo's |

## 2. Purpose, authority and position

The fleet's durable record of what it decided and what it proved. It decides whether a row may
close (a completion REQUIRES `--evidence-run-id` — `boardctl update --help`), whether a re-detected
finding is refused, and whether two board copies have drifted. It may not decide the law itself:
nine board rules exist only as chat, not in any module (CF-344).

**What breaks if this module is absent.** The fleet forgets its decisions and proofs: a row is
the only durable record of a defect, a decision, and the re-runnable command that closes it
(`_facts.md` FACT-10).

**What breaks if it lies.** A row that reports a closeout without the evidence is the mirror of
the "commit message claiming a closeout" defect — a completion without a bound run is refused by
boardctl (`--status complete REQUIRES --evidence-run-id`, `boardctl update --help`).

## 3. Submodule inventory

| Submodule | Unit | Classification | Evidence (invoking line) |
|---|---|---|---|
| S1 write and validate rows | `boardctl` (wrapper), `board_lock.py` | **active** | `scripts/boardctl` is the stable entrypoint (`exec boardctl -C "$ROOT"`); `board_lock.py` adjudicates the lock (`adjudicate`, `:166`) |
| S2 compare board copies | `board_drift.py` | **active** | `python3 scripts/board_drift.py check …` → `RESULT: DRIFT (4 failed)` (see §7) |

**`board_read.py` (new unit, added in `dbf810b`, not in OUTLINE's S1/S2 split — F4-6).** A 125-line
read-only reader (`scripts/board_read.py`) that resolves the board from the **canonical ref
(`origin/main`) first, the working copy only when there is no remote**. It exists because a dirty
workdir previously made a tick refuse to read the board at all (252 pending rows invisible). The
`load()` function returns `(rows, source)` and reports which source it used (`board_read.py:59`, the
canonical-ref loop at `:63-71` tries `origin/main` → `origin/master` → `main` → `HEAD`, falling
back to the worktree only when no ref resolves), so a lane can say "read from origin/main (local copy drifted by N rows)" instead of refusing. It
never refuses: a malformed line is skipped (`parse`, `:46`, the `except json.JSONDecodeError:
continue` at `:54-55`), not a reason to drop the whole
board. Classification: **operator-invoked (optional)** — no cron/scheduler invokes it
(`grep -rn board_read scripts/ tests/` → the unit itself only); a lane reads it on demand.

**`board_lock.py` classifier (B11; re-read in full for CF-259).** `adjudicate`
(`:166-185`) has **four** outcomes, in order:

1. **ABSENT** (`:167-168`) — the lock path does not exist. No lock, no holder, nothing to wait on.
2. **HELD** — a *live* holder is proven by either (a) an open `/proc/<pid>/fd` entry (excluding
   this process) that resolves to the path (`fd_holders`, `:59-80`), or (b) a non-blocking
   exclusive `flock` probe that fails `EWOULDBLOCK`/`EAGAIN` (`flock_probe`, `:83-104`).
3. **ERROR** (`:175-180`) — the `flock` probe could not run: the path could not be opened
   (`probe=open-failed`) or `flock` itself failed with a non-contention errno (`probe=errno-<n>`).
   The line reads `ERROR lock=<path> probe=<detail> is not a clean negative — the lock state is
   UNKNOWN` and `main` (`:188-201`) returns exit **3**. Nothing is proven, so this verdict is
   never permission to write the board.
4. **RESIDUE** (`:181-185`) — the probe ran and proved no holder; the verdict names the two
   hand-derivation counts: `consumers=<n>` (lines matching `flock|fcntl` under `scripts/boardctl*`,
   `consumer_count` `:107-117`) and `commits_after_mtime=<n|unknown>` (board commits after the lock's
   mtime, `git log --since=@<mtime>`, `commits_after_mtime` `:128-156`; `unknown` is never invented).

The classifier never creates, truncates or deletes the lock path (`:28`). **Degraded observation
(B08; repaired by CF-259):** `flock_probe` (`:83-104`) can return an *indeterminate* probe
error (open-failed or a non-contention errno), and before CF-259 `adjudicate` mapped every
non-held probe result to RESIDUE, so a lock this process could not even open printed
`RESIDUE consumers=0 commits_after_mtime=unknown` and exited 0 — a fail-open safety check that
told a lane "no barrier, proceed with the board write". That measurement is now its own outcome:
the probe error is the ERROR verdict at `:175-180` with a non-zero exit (3), and RESIDUE is
reserved for a probe that actually ran and proved the file unheld. The `/proc` scan skipping
inaccessible processes (`:70-71`) stays a clean observation by design and does not by itself
produce ERROR. Operator actions by outcome: ABSENT → proceed (no barrier); HELD → wait (a holder
is live, do not force); ERROR → the lock state is UNKNOWN — stop and diagnose the path
(permissions, filesystem) instead of writing the board on an unproven negative; RESIDUE → the
file is a stale artifact, not a barrier — proceed and file a row to have it removed deliberately.

## 4. Dependencies

**4a. Runtime dependencies**

| Dependency | Version constraint | Where | How absence is detected |
|---|---|---|---|
| external `boardctl` executable | version reports `dev` | `PATH` (`/home/kara/.local/bin/boardctl`, measured) | `scripts/boardctl` exits 127 with "boardctl executable not found on PATH" |
| bash + python3 | any / 3.x | control host | command-not-found |
| jq (append path) | any | control host | jsonl row append via `jq -c . row.json >> file` |

**4b. Library contracts**

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `boardctl` verbs | external executable (this repo's `scripts/boardctl` is a thin wrapper that `exec boardctl -C "$ROOT"`) | 20 subcommands: `init list show next-id create update event header validate sweep-status normalize-statuses normalize-board doctor version stats render import serve install umbrella` | a verb rename breaks every board script; the wrapper does not implement any verb itself |

**4c. Service contracts** — see §6.

## 5. Settings register

| Setting | Default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| `-C <repo-or-board-dir>` | none (wrapper forces `-C "$ROOT"`) | a board dir | which board the verb targets | the wrapper pins it to the repo root so a bare `boardctl` cannot hit the wrong board |
| `update --status complete` | — | requires `--evidence-run-id` | row closeout | a completion without a bound run id is **refused** (`boardctl update --help`; TR-251) |
| `create` / `update` (id, fingerprint) | — | unique id; unique finding fingerprint | row identity | a duplicate id is refused (`task id "…" already exists — create aborted`); a duplicate finding fingerprint is refused |
| `validate [--strict-keys] [--fail-on dangling-dep]` | — | flags | semantic validation strictness | `--strict-keys` tightens key uniformity; `--fail-on dangling-dep` promotes a dangling dependency from warning to failure (`boardctl validate --help`) |

## 6. Contracts in and out

Canonical ids are the register of record (OUTLINE Part IV, CT-01..CT-18). Local ids are
retired; each row carries the CT id its peer chapter cites.

| ID | Peer | Direction | Producer `file:function` | Consumer `file:function` | State |
|---|---|---|---|---|---|
| CT-14 | foreman | in | **external** — the foreman lives outside this repo; `grep -rn boardctl scripts/` matches the wrapper itself (`scripts/boardctl:2,9,11,15,16,21`), `board_lock.py:19,108,110` (its own `consumer_count` grep over the wrapper), `handbook_spine.py:58,75,78,79` (comments naming boardctl as a boundary peer), and `gen_unit_map.py:45` (a name list). No in-repo producer invokes `boardctl create` | the JSONL store `.coding-hermes/board/{tasks,events}.jsonl`, appended via the external `boardctl` binary (a file, not a function) | **UNVERIFIED** — the store is measured (357/520) but the foreman→board write wire is not exercised in this repo |
| CT-13 | gitreins | in | **external** — the judge's verdict file (written by the gitreins binary, not in this repo) | `boardctl update --status complete` (the external binary; completion REQUIRES `--evidence-run-id`) | **UNVERIFIED** — an inherited earlier state read "broken (OUTLINE §IV)"; the gitreins-verdict→board-close path was not re-run |
| CT-10 | node | in | **external** — no in-repo producer writes a board row event: `grep -nE 'boardctl|tasks.jsonl|events.jsonl' scripts/node-bus-worker.py` → 0 matches | the JSONL store (the `boardctl` binary, out of scope) | **broken** — OUTLINE Part IV marks `node → board` broken; the node worker does not write board rows |

All three rows carry no in-repo function on either side because every side is an external peer
(the foreman, the gitreins binary, the `boardctl` binary, and the JSONL store). The honest state
is therefore **UNVERIFIED**/**broken** per OUTLINE, not "works" — a "works" verdict attached to an
unnamed side is a rumour with a verdict. CT-10, CT-13 and CT-14 are
boundary contracts.

## 7. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| store census | `jq -r '.id' .coding-hermes/board/tasks.jsonl | wc -l` | 357 rows | 2026-11-07 | PASS (357) |
| events count | `wc -l .coding-hermes/board/events.jsonl` | 520 lines | 2026-11-07 | PASS (520) |
| drift | `python3 scripts/board_drift.py check --workdir /home/kara/code-factory --ref origin/main` | byte parity, RESULT OK | 2026-11-07 | **DRIFT (4 failed)** — byte parity `tasks.jsonl`/`events.jsonl` **differ** (workdir sha256 `57203cb9…`/`f3d8802e…` vs published `5aa15431…`/`783d556c…`); 357 vs 357 rows, **1 divergent id: CF-150** (workdir `in_progress` vs published `pending`); HEAD=origin/main=`fbc19cb` |
| semantic validate | `scripts/boardctl validate` | RESULT OK with named warnings | 2026-11-07 | **PASS** — `357 tasks, 520 events, 0 fixtures`, `key uniformity 357/357 (0 drift)`, `RESULT: OK (7 warning(s))` |
| lock adjudication | `scripts/board_lock.py` on an absent / unheld / unreadable / held lock | ABSENT / HELD / RESIDUE / ERROR named (`board_lock.py:166-185`) | 2026-11-07 | **PASS** — 0-byte lock → `RESIDUE consumers=0 commits_after_mtime=unknown` exit 0; chmod-000 lock → `ERROR lock=… probe=open-failed …` exit 3 (CF-259); absent path → `ABSENT` exit 0; HELD arm is `tests/selftest.sh` §33 |
| duplicate id refusal | `boardctl create --id CF-357 --title x` | refused | 2026-11-06 | **PASS** — `task id "CF-357" already exists … create aborted` |

**Drift re-measured.** The CF-270
divergence is reconciled (commit `4dc0ef0` closed CF-270 and is in `origin/main`), but a
**different, newer divergence exists**: `board_drift` at HEAD `fbc19cb` returns
`RESULT: DRIFT (4 failed)` with **1 divergent id — CF-150** (workdir `in_progress` vs published
`pending`). The cause is an **uncommitted working-copy transition**, not a committed divergence:
event 520 (`task_id: CF-150`, `actor: foreman`, `2026-11-07T06:09:41`, `status: in_progress`) was
appended to the working copy but not committed, so `origin/main` still carries CF-150 as `pending`.
`HEAD == origin/main == fbc19cb` (the `HEAD ancestry` check PASSES); only the working copy differs.
This is exactly the state `board_read.py` is designed to resolve — it reads the
canonical `origin/main` board when the working copy disagrees. The divergence is not a board defect
to reconcile in-band; it is the panel loop's own runtime state and is documented, not "fixed".

**Census-vs-validation correction (F4-2).** The `jq -r '.id' … | wc -l` check is a **census**,
not integrity validation. The real validation is `boardctl validate`, which returned
`RESULT: OK (7 warning(s))` — the warnings are free-form `guard_result`/`ci_result` values
(outside the `{PASS,FAIL,SKIP}` vocabulary), a priority/title disagreement (CF-150, CF-192,
CF-371), a duplicate event id (line 337), and a headerless board (header checks skipped). Warnings
are distinct from failures; `--strict-keys` and `--fail-on dangling-dep` tighten the gate.

## 8. Metrics

**RED — none (absence-proved).** The board emits no counters or gauges as a service —
`grep -nE 'prometheus|Counter|Gauge|Histogram|/metrics' scripts/board_lock.py scripts/board_drift.py`
→ 0 matches. Row counts are derived by `jq`/`wc`, not emitted. Churn, close-rate and age are all
derived by hand.

## 9. Log lines (verbatim)

`boardctl` is an external binary (`/home/kara/.local/bin/boardctl`, measured — not in
this repo), so these strings carry no in-repo `file:line`; the `validate` and `drift` rows are
quoted from run output (2026-11-07, rev `fbc19cb`); the duplicate-id row is
carried from an earlier capture (N9):

| Level | Line | Emitted when | Kind |
|---|---|---|---|
| — | `boardctl: task id "%s" already exists in tasks.jsonl — create aborted` | duplicate id (captured from `boardctl create --id CF-357`) | evidentiary |
| — | `[warn] tasks.jsonl line %d (task %s): guard_result "%s" is free-form — not in the guard_result vocabulary {PASS,FAIL,SKIP} …` | validate (captured from `boardctl validate`) | evidentiary |
| — | `RESULT: OK` / `RESULT: OK (7 warning(s))` (`board_drift.py` / `boardctl validate`) | drift/validate completes | evidentiary |

## 10. Failure modes, indications and recovery

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Stale lock (RESIDUE, clean scan) | `board_lock.py` → `RESIDUE consumers=<n> commits_after_mtime=<n>` from a clean scan | a held lock (HELD names a live `holder=pid-N`/`flock-eagain`) | the file is not a barrier; proceed and file a row to remove it deliberately — never delete it in-band (CF-119) |
| Stale lock (RESIDUE, degraded probe) | the same `RESIDUE` shape produced from a failed/unreadable `flock_probe` or a `/proc` scan that skipped processes | a clean-scan RESIDUE | **do NOT proceed** — this is an UNKNOWN observation, not proof of staleness (B09). Re-run the probe or establish observation quality before acting; `adjudicate` discards the probe error/detail, so the classifier alone cannot tell the two apart |
| Live holder (HELD) | `board_lock.py` → `HELD holder=pid-N` or `HELD holder=flock-eagain` | a residue | wait; the holder is live, do not force the lock |
| Duplicate id / fingerprint | refused on append (`already exists … create aborted`) | a valid new row | use a new id or resolve the duplicate finding |
| Rule set only in chat | nine board rules have no module home | a written law | **OPEN** — CF-344 |
| Rows duplicating a module's defect table | same defect in two places | a single source of truth | **OPEN** — CF-363 |
| Sibling reversion | a staged stale row copy reverts a closeout | a real change | normalize the sibling's stale copy after a supersession |

## 11. Limits and margins

- Rows are addressed by `id` + `status`, never index (a positional offset is not a durable key).
- `--status complete` without `--evidence-run-id` is refused (`boardctl update --help`, TR-251).
- `boardctl validate` distinguishes warnings from failures; a headerless board skips header checks.
- The `flock_probe` is advisory only: it proves *someone* holds an exclusive flock, not *who* or
  *why*; the `/proc/<pid>/fd` scan is subject to permission/race limits (`:60-61` skips
  un-inspectable pids).

## 12. Cross-references

- F5 LANDING writes the board row a landing closes (M3).
- **M9 SCHEDULER reads board rows as admission gates** — `internal/scheduler/admission_mode.go:230-242`
  is the board-ownership/workability admission decision. **M10 CRIER does not** (B04): a source
  search across crier's Go files finds no `tasks.jsonl`, `board_ownership`, `boardWorkable` or
  board/admission terminology — the bus operates on inbox messages and leases.
- M6 DOCUMENTATION's gate reads `_facts.md`; board rows are the evidence of record.

## 13. Evidence of record

- Store: `.coding-hermes/board/tasks.jsonl` (357 rows), `events.jsonl` (520 lines).
- `docs/UNIT-MAP.yaml:122-138` (M4 S1–S2).
- Board rows: CF-344, CF-363, CF-119, CF-378 (CF-270 is now `complete` in both copies — reconciled, F4-4).
- **Findings:**
  - **F4-1** (carried) — `scripts/boardctl` is a wrapper (`exec boardctl -C "$ROOT"`, exit 127
    when absent); the external `boardctl --help` lists 20 subcommands, version `dev`.
  - **F4-2** — the `jq` id-count is a census, not integrity validation; `boardctl validate` (with
    `--strict-keys` / `--fail-on dangling-dep`) is the validation.
  - **F4-3** (carried) — CT-14/CT-13 (foreman→board / gitreins→board) states corrected from "works"/"broken" to **UNVERIFIED**: every
    side is an external peer, so no in-repo file:function exists to name.
  - **F4-4** (resolved) — the CF-270 divergence is **reconciled**: commit `4dc0ef0` closed CF-270 and
    is in `origin/main`; the earlier pre-reconciliation DRIFT (CF-270 workdir `pending` vs
    published `complete`) is superseded. A *new*, unrelated divergence (CF-150) is F4-6, not a
    CF-270 regression.
  - **F4-5** (B04) — the board-admission gate belongs to M9 alone; crier has no board admission.
  - **F4-6** (new) — `scripts/board_read.py` (added in `dbf810b`) is a new board READ
    unit not in OUTLINE's S1/S2 split; it resolves the board from `origin/main` first, the dirty
    working copy only when no remote exists. And `board_drift` now returns `RESULT: DRIFT (4
    failed)` with 1 divergent id (CF-150: workdir `in_progress` vs published `pending`) — an
    uncommitted working-copy transition (event 520, actor `foreman`), not a committed divergence;
    HEAD == origin/main == `fbc19cb`. Documented, not reconciled in-band.

## 14. Wave-2 redline — review requirements (target behavior vs implementation coverage)

Per the CF2A-01 review handoff (§1.7, §2): **approved target behavior governs this chapter**; the
store census, drift measurements and grep counts in §§1–13 are implementation coverage evidence,
not authority. Resolved architecture applied throughout: the foreman runs inside its Bunker with
Crier as the launch/return boundary (handoff §1.1); DuckBrain memory is a separate system — the
board is **not** the project memory (§2 stands).

**R1 — Per-project placement with Boardctl as the shared engine (required).** The board lives
**in each project repository** — the store at §1 is this repo's instance of a per-project store,
not one central Code Factory board. Boardctl is the separately maintained shared **engine** acting
on that per-project store (the §3 wrapper/§4 dependency rows are the integration seam). The
chapter must state: per-project board identity/root, the pinned supported upstream Boardctl
release and its installation/compatibility contract (the `dev` executable and the public v0.2.0
release are distinct facts; §13's version finding is the coverage evidence), and how copies of a
project repo and its board **synchronize across hosts** — a boundary/dependency must still be a
specified interface (review notes M4, observations and proposals).

**R2 — ONE eligibility/dependency rule shared by every consumer (required).** Exactly one
canonical eligibility/dependency rule must be written and shared by **Boardctl, the board reader,
the scheduler (M9) and the foreman**. Current coverage shows conflicting definitions: the reader
counts blocked/deferred as satisfied dependencies (§13 F4-6 context; `board_read.py` TERMINAL
vocabulary), while the scheduler scanner requires completed-vocabulary prerequisites and excludes
blocked/deferred — and the Figure 0.2 requirement is that blocked/deferred remain **incomplete**.
The normative rule must decide blocked-vs-deferred representation, deferral reason/review/return
path, cancelled prerequisites, fixtures and missing-dependency/cycle handling, and every consumer
must be aligned to it; eligibility is defined separately from open-row count (review notes M4,
proposal "one lifecycle and workability definition").

**R3 — Authoritative revision and copies (required).** The chapter must define which board state
— local working copy, node copy, control-host copy, published ref — is **authoritative** for
scheduling, claims and closeout; bind every read to repository/ref/commit and freshness; assign
the publish-vs-refresh owners (refresh before admission, publish/refresh at lane end); explain
how an uncommitted in-progress claim (the measured CF-150 divergence, §7) stays visible when the
published state still says pending; and define an atomic claim/revision precondition across
dispatchers plus recovery of abandoned claims, so independent clones cannot schedule the same
task. Which actor publishes versus merely refreshes is required content, not optional detail
(review notes M4, proposal "authoritative copies, freshness and claims").

**R4 — Empty vs unreadable/malformed/stale are distinct observations (required).** The reader
contract must return separate, named results for: healthy-empty board, no-workable-items, missing
board, unreadable/stale source, skipped/corrupt rows, and invalid dependencies — and must state
whether partial observation is allowed, what remains visible, what blocks scheduling, and how
alerts/repair work. Current coverage shows the gap: the reader silently skips malformed JSON and
returns success for a missing board (§13 F4-6 context), so an empty list can stand for an
observation failure — that must never satisfy the target contract, and the reader's
skip-vs-error behavior, the scheduler's malformed-work policy and the validation/flight-card
guarantees must be unified (review notes M4, proposal "corrupt or unavailable board semantics").
§7's stale-RESIDUE/ERROR rows are the same distinction applied to locks.

**R5 — Closure bar: accepted verdict + published proof (required).** A row closes only on the
mandatory evidence chain: task/acceptance criteria → run → passing verdict and required checks →
exact tested tree/commit → applicable merged/**published** object and proof → durable artifact
references → authorized completion event — with a named validator for every link, including
non-code tasks and any explicitly permitted exceptions. Mere provenance or the existence of an
evidence directory is **insufficient**; a run id, an optional commit field, or a census of rows
carrying references is not proof of a passing verdict or current-main publication. The upstream
completion gate (provenance + evidence-run requirement, §6 CT-13 row) is a reusable component;
the chapter must assign the checks it does not perform (verdict payload, tree equivalence,
remote-main ancestry) and define malformed/missing/expired/mismatched evidence plus retry/idempotent
closeout behavior (review notes M4, proposal "evidence sufficient for completion").

**R6 — Partial-write recovery (required).** Row updates and event appends are two file writes; a
lock around them is not a transaction. The engine can persist a task row and then fail its audit
event (upstream write path, review notes M4 source findings) — the chapter must define
recoverable partial-result statuses, operation/event identity, replay/deduplication and repair so
callers neither assume nothing happened nor blindly repeat a completion, plus backup/restore
consistency across rows, events, evidence and the git revision, validated before scheduling
resumes.

**R7 — Scheduler-facing reads in the text (required).** M9 reads board rows as its admission
gates — that outgoing contract belongs in this chapter's text and in Figure 3.4 (the figure's
"no outgoing cross-system contract" label is a specification omission to fix, review notes M4
observations). The claim/sync paths between scheduler reads, foreman claims and published state
must be drawn and owned; CT-10/13/14 are direct or mediated paths to be reconciled — a worker
need not mutate the board directly if an explicit foreman contract owns that action (resolved:
the foreman, via Crier, is the return path; the scheduler records).

**R8 — Required board metrics (required).** Task counts by canonical status and by
workable/unmet/unknown eligibility, oldest pending/blocked/deferred ages, claim/transition/closeout
rates, evidence rejections vs independently verified completions, parse/validation failures,
duplicate suppressions, lock wait/contention/unknown outcomes, drift/freshness/publication lag,
conflicts, partial writes and repair/replay results — each with units, bounded dimensions,
emit/collect/readout ownership, empty-denominator policy and acceptance verification (review
notes M4, proposal "required board metrics"). Upstream stats/doctor reports (§4b verb surface)
are reusable components; a grep proving no Prometheus calls is coverage evidence, not the metric
design.

## RED field count: 2 (Metrics §8 — absence-proved; CT-14/CT-13 states UNVERIFIED — every side is an external peer)

## FLIGHT DATA FILE - M4 BOARD

```checklist
TITLE: M4 BOARD
WHO: CONTROL HOST
READ - read the board store; rows and events counted separately
√ PARSE - every line parses; a duplicate id is named, never silently dropped
APPEND - boardctl update with --evidence-run-id on a closed row
√ EVENT - events grow by exactly one row; the store prints the new count
RECONCILE - audit a claimed-done row against its evidence
√ MATCH - the row closes only on evidence tied to the exact tree
```
