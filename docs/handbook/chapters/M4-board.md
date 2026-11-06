# M4 — BOARD

## 1. Identity

| Field | Value |
|---|---|
| Module name | BOARD |
| Path | `/home/kara/code-factory/.coding-hermes/board/tasks.jsonl` + `events.jsonl`; tools `/home/kara/code-factory/scripts/boardctl`, `board_lock.py`, `board_drift.py` |
| Revision | `943ef984dc093e5780605ac6e54cd043122126ef` (code-factory HEAD, 2026-11-06) |
| Language / runtime | bash (boardctl wrapper) + Python 3.14.9 (measured) |
| Owner lane | code-factory (control host) |
| Status | **VERIFIED at store level** (357 rows / 515 events / 0 fixtures, `boardctl validate` RESULT OK with 7 warnings — measured this round); **board parity is now DRIFT, not PASS**: `board_drift` returns `RESULT: DRIFT (4 failed)` because `origin/main` advanced 3 commits past HEAD (CF-051 closeout landed in `b82a5df`), so the working tree's CF-051 `pending` disagrees with the published `complete` (B3). The `boardctl` verb surface is the external executable's (`/home/kara/.local/bin/boardctl`), not this repo's |

## 2. Purpose, authority and position

The fleet's durable record of what it decided and what it proved. It decides whether a row may
close (a completion REQUIRES `--evidence-run-id` — `boardctl --help:25`), whether a re-detected
finding is refused, and whether two board copies have drifted. It may not decide the law itself:
nine board rules exist only as chat, not in any module (CF-344).

**What breaks if this module is absent.** The fleet forgets its decisions and proofs: a row is
the only durable record of a defect, a decision, and the re-runnable command that closes it
(`_facts.md` FACT-10).

**What breaks if it lies.** A row that reports a closeout without the evidence is the mirror of
the "commit message claiming a closeout" defect — a completion without a bound run is refused by
boardctl (`--status complete REQUIRES --evidence-run-id`, `boardctl --help:25`).

## 3. Submodule inventory

| Submodule | Unit | Classification | Evidence (invoking line) |
|---|---|---|---|
| S1 write and validate rows | `boardctl` (wrapper), `board_lock.py` | **active** | `scripts/boardctl` is the stable entrypoint (`exec boardctl -C "$ROOT"`); `board_lock.py` adjudicates the lock (`adjudicate`, `:149`) |
| S2 compare board copies | `board_drift.py` | **active** | `python3 scripts/board_drift.py check …` → `RESULT: DRIFT (4 failed)` this round (see §7) |

**`board_lock.py` classifier (B11, read in full this round).** `adjudicate` (`:149-158`) has
**three** outcomes, in order:

1. **ABSENT** (`:150-151`) — the lock path does not exist. No lock, no holder, nothing to wait on.
2. **HELD** — a *live* holder is proven by either (a) an open `/proc/<pid>/fd` entry (excluding
   this process) that resolves to the path (`fd_holders`, `:49-70`), or (b) a non-blocking
   exclusive `flock` probe that fails `EWOULDBLOCK`/`EAGAIN` (`flock_probe`, `:73-94`).
3. **RESIDUE** (`:158`) — the file exists but no live holder is proven; the verdict names the two
   hand-derivation counts: `consumers=<n>` (lines matching `flock|fcntl` under `scripts/boardctl*`,
   `consumer_count` `:97-107`) and `commits_after_mtime=<n|unknown>` (board commits after the lock's
   mtime, `git log --since=@<mtime>`, `commits_after_mtime` `:118-146`; `unknown` is never invented).

The classifier never creates, truncates or deletes the lock path (`:21`). Operator actions by
outcome: ABSENT → proceed (there is no barrier); HELD → wait (a holder is live, do not force);
RESIDUE → the file is a stale artifact, not a barrier — proceed and file a row to have the residue
removed deliberately.

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
| `update --status complete` | — | requires `--evidence-run-id` | row closeout | a completion without a bound run id is **refused** (`boardctl --help:25`; TR-251) |
| `create` / `update` (id, fingerprint) | — | unique id; unique finding fingerprint | row identity | a duplicate id is refused (`task id "…" already exists — create aborted`); a duplicate finding fingerprint is refused |
| `validate [--strict-keys] [--fail-on dangling-dep]` | — | flags | semantic validation strictness | `--strict-keys` tightens key uniformity; `--fail-on dangling-dep` promotes a dangling dependency from warning to failure (`boardctl validate --help`) |

## 6. Contracts in and out

| ID | Peer | Direction | Producer `file:function` | Consumer `file:function` | State |
|---|---|---|---|---|---|
| M4-C1 | foreman | in | **external** — the foreman lives outside this repo; `grep -rn boardctl scripts/` matches only `board_lock.py:98/:100` (a grep over the wrapper) and `gen_unit_map.py:45` (a name list). No in-repo producer invokes `boardctl create` | the JSONL store `.coding-hermes/board/{tasks,events}.jsonl`, appended via the external `boardctl` binary (a file, not a function) | **UNVERIFIED** — the store is measured (357/515) but the foreman→board write wire is not exercised in this repo |
| M4-C2 | gitreins | in | **external** — the judge's verdict file (written by the gitreins binary, not in this repo) | `boardctl update --status complete` (the external binary; completion REQUIRES `--evidence-run-id`) | **UNVERIFIED** — round-3 carried "broken (OUTLINE §IV)" as an inherited state; the gitreins-verdict→board-close path was not re-run this round |

Both rows carry no in-repo function on either side because every side is an external peer (the
foreman, the gitreins binary, the `boardctl` binary, and the JSONL store). The honest state is
therefore **UNVERIFIED**, not "works" — a "works" verdict attached to an unnamed side is a rumour
with a verdict (grok 11 / deepseek 1).

## 7. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| store census | `jq -r '.id' .coding-hermes/board/tasks.jsonl | wc -l` | 357 rows | 2026-11-06 | PASS (357) |
| events count | `wc -l .coding-hermes/board/events.jsonl` | 515 lines | 2026-11-06 | PASS (515) |
| drift | `python3 scripts/board_drift.py check --workdir /home/kara/code-factory --ref origin/main` | byte parity, RESULT OK | 2026-11-06 | **DRIFT (4 failed)** — `tasks.jsonl` bytes differ, `events.jsonl` bytes differ, CF-051 `pending`(workdir) vs `complete`(published), 357 vs 357 rows with 1 divergent id (CF-051); HEAD=`943ef98` is an **ancestor** of `origin/main=6bb3ac8`, not equal (B3) |
| semantic validate | `scripts/boardctl validate` | RESULT OK with named warnings | 2026-11-06 | **PASS** — `357 tasks, 515 events, 0 fixtures`, `key uniformity 357/357 (0 drift)`, `RESULT: OK (7 warning(s))` |
| lock adjudication | `scripts/board_lock.py` on a held/unheld lock | ABSENT / HELD / RESIDUE named (`board_lock.py:149-158`) | 2026-11-06 | UNVERIFIED — the classifier was read in full but not exercised against a held/unheld fixture this round |
| duplicate id refusal | `boardctl create --id CF-357 --title x` | refused | 2026-11-06 | **PASS** — `task id "CF-357" already exists … create aborted` |

**Drift is a moving target (B3).** A byte-parity check against `origin/main` cannot be quoted as a
standing PASS: `origin/main` advanced 3 commits after this chapter was stamped (CF-051's closeout
in `b82a5df`, plus `0c1f20e`/`6bb3ac8`), so the working tree's CF-051 `status:"pending"` now
diverges from the published `status:"complete"`. The honest row is the DRIFT result above, re-stamped
with its date; re-run `board_drift` after the merge that carries this chapter.

**Census-vs-validation correction (F4-2).** The `jq -r '.id' … | wc -l` check is a **census**,
not integrity validation. The real validation is `boardctl validate`, which this round returned
`RESULT: OK (7 warning(s))` — the warnings are free-form `guard_result`/`ci_result` values
(outside the `{PASS,FAIL,SKIP}` vocabulary), a priority/title disagreement (CF-150, CF-192,
CF-371), a duplicate event id (line 337), and a headerless board (header checks skipped). Warnings
are distinct from failures; `--strict-keys` and `--fail-on dangling-dep` tighten the gate.

## 8. Metrics

**RED — none (absence-proved this round).** The board emits no counters or gauges as a service —
`grep -nE 'prometheus|Counter|Gauge|Histogram|/metrics' scripts/board_lock.py scripts/board_drift.py`
→ 0 matches. Row counts are derived by `jq`/`wc`, not emitted. Churn, close-rate and age are all
derived by hand.

## 9. Log lines (verbatim)

`boardctl` is an external binary (`/home/kara/.local/bin/boardctl`, measured this round — not in
this repo), so these strings carry no in-repo `file:line`; they are quoted from the run output
captured this round (2026-11-06, rev `943ef98`) with the commands named (N9):

| Level | Line | Emitted when | Kind |
|---|---|---|---|
| — | `boardctl: task id "%s" already exists in tasks.jsonl — create aborted` | duplicate id (captured from `boardctl create --id CF-357`) | evidentiary |
| — | `[warn] tasks.jsonl line %d (task %s): guard_result "%s" is free-form — not in the guard_result vocabulary {PASS,FAIL,SKIP} …` | validate (captured from `boardctl validate`) | evidentiary |
| — | `RESULT: OK` / `RESULT: OK (7 warning(s))` (`board_drift.py` / `boardctl validate`) | drift/validate completes | evidentiary |

## 10. Failure modes, indications and recovery

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Stale lock (RESIDUE) | `board_lock.py` → `RESIDUE consumers=<n> commits_after_mtime=<n>` | a held lock (HELD names a live `holder=pid-N`/`flock-eagain`) | the file is not a barrier; proceed and file a row to remove it deliberately — never delete it in-band (CF-119) |
| Live holder (HELD) | `board_lock.py` → `HELD holder=pid-N` or `HELD holder=flock-eagain` | a residue | wait; the holder is live, do not force the lock |
| Duplicate id / fingerprint | refused on append (`already exists … create aborted`) | a valid new row | use a new id or resolve the duplicate finding |
| Rule set only in chat | nine board rules have no module home | a written law | **OPEN** — CF-344 |
| Rows duplicating a module's defect table | same defect in two places | a single source of truth | **OPEN** — CF-363 |
| Sibling reversion | a staged stale row copy reverts a closeout | a real change | normalize the sibling's stale copy after a supersession |

## 11. Limits and margins

- Rows are addressed by `id` + `status`, never index (a positional offset is not a durable key).
- `--status complete` without `--evidence-run-id` is refused (`boardctl --help:25`, TR-251).
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

- Store: `.coding-hermes/board/tasks.jsonl` (357 rows), `events.jsonl` (515 lines).
- `docs/UNIT-MAP.yaml:122-138` (M4 S1–S2).
- Board rows: CF-344, CF-363, CF-119, CF-378, CF-051 (the divergent row this round).
- **Findings:**
  - **F4-1** (carried) — `scripts/boardctl` is a wrapper (`exec boardctl -C "$ROOT"`, exit 127
    when absent); the external `boardctl --help` lists 20 subcommands, version `dev`.
  - **F4-2** — the `jq` id-count is a census, not integrity validation; `boardctl validate` (with
    `--strict-keys` / `--fail-on dangling-dep`) is the validation.
  - **F4-3** (carried) — M4-C1/M4-C2 states corrected from "works"/"broken" to **UNVERIFIED**: every
    side is an external peer, so no in-repo file:function exists to name.
  - **F4-4** (new, B3) — the round-5 drift row asserted `HEAD==origin/main`; re-measured this round
    it is `RESULT: DRIFT (4 failed)` with HEAD an ancestor of a moved `origin/main` (CF-051). The
    row is re-stamped with the honest DRIFT result, not a standing PASS.
  - **F4-5** (new, B04) — the board-admission gate belongs to M9 alone; crier has no board admission.

## RED field count: 3 (Metrics §8 — absence-proved; M4-C1/M4-C2 contract states UNVERIFIED; §7 drift DRIFT — a check against a moving `origin/main` cannot be a standing PASS)
