# M4 — BOARD

## 1. Identity

| Field | Value |
|---|---|
| Module name | BOARD |
| Path | `/home/kara/code-factory/.coding-hermes/board/tasks.jsonl` + `events.jsonl`; tools `/home/kara/code-factory/scripts/boardctl`, `board_lock.py`, `board_drift.py`, `board_read.py` |
| Revision | `dbf810b7adfa5231a8828f415e1dad6de26a4263` (code-factory HEAD == origin/main == gh/main, round-19 re-stamp; one commit past the round-18 stamp `ce2f875`). `git diff --name-only ce2f875..HEAD` = `prompts/foreman.md`, `scripts/board_read.py` (dbf810b "board_read: the board is always readable"). `board_read.py` is a new board unit M4 now documents (§3 S3); `prompts/foreman.md` is the lane prompt that invokes it. `boardctl`, `board_lock.py`, `board_drift.py` are not in that diff, so all three are byte-identical across `ce2f875..HEAD` |
| Language / runtime | bash (boardctl wrapper) + Python 3.14.9 (measured) |
| Owner lane | code-factory (control host) |
| Status | **VERIFIED (store)** — 357 rows / **519** events / 0 fixtures, `boardctl validate` `RESULT: OK (7 warning(s))`; **DRIFT reconciled** — `board_drift` `RESULT: OK`, byte parity identical on both files, 0 divergent ids, HEAD == origin/main == `dbf810b` — both re-measured this round; `board_read.py` (new, dbf810b) measured: `--source` → `{"source": "origin/main", "rows": 357}`, summary `dispatchable : 252` (92 complete / 13 in_progress / 252 pending). The `boardctl` verb surface is the external executable's (`/home/kara/.local/bin/boardctl`), not this repo's |

## 2. Purpose, authority and position

The fleet's durable record of what it decided and what it proved. It decides whether a row may
close (a completion REQUIRES `--evidence-run-id` — enforced at runtime, `boardctl update BX-1
--status complete` → `boardctl: evidence run required: completion REFUSED … --evidence-run-id is
REQUIRED when setting status "complete" (TR-251)`), whether a re-detected
finding is refused, and whether two board copies have drifted. It may not decide the law itself:
nine board rules exist only as chat, not in any module (CF-344).

**What breaks if this module is absent.** The fleet forgets its decisions and proofs: a row is
the only durable record of a defect, a decision, and the re-runnable command that closes it
(`_facts.md` FACT-10).

**What breaks if it lies.** A row that reports a closeout without the evidence is the mirror of
the "commit message claiming a closeout" defect — a completion without a bound run is refused by
boardctl (`update <id> --status complete` without `--evidence-run-id` → `evidence run required:
completion REFUSED … (TR-251)`, captured this round).

## 3. Submodule inventory

| Submodule | Unit | Classification | Evidence (invoking line) |
|---|---|---|---|
| S1 write and validate rows | `boardctl` (wrapper), `board_lock.py` | **operator-invoked (optional)** | no in-repo unit/cron/timer invokes them — `grep -rn 'boardctl\|board_lock' prompts/ config/` → 0 matches; only `tests/selftest.sh:458-462` (boardctl) and `:1789,1819` (board_lock) exercise them, and a test harness is not production. The foreman lane (external to this repo) is the intended operator |
| S2 compare board copies | `board_drift.py` | **operator-invoked (optional)** | no in-repo invoker — `grep -rn board_drift prompts/ config/` → 0 matches; only `tests/selftest.sh:1440` exercises it. This round's `RESULT: OK` is a manual run, not activation (sol B27) |
| S3 read the board | `board_read.py` | **active (lane-invoked)** | invoked by the foreman lane prompt `prompts/foreman.md:42` (`python3 scripts/board_read.py --next 10`); the foreman is the `code-factory` project's lane (prompts/foreman.md:1-3). Self-contained read: `grep -nE 'boardctl|board_lock|board_drift' scripts/board_read.py` → 0 matches — it reads `origin/main:.coding-hermes/board/tasks.jsonl` via `git show` directly (`board_read.py:63-66`) |

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

The classifier never creates, truncates or deletes the lock path (`:21`). **Degraded observation
(B08, sol):** `flock_probe` (`:73-94`) can return an *indeterminate* probe error (open-failed or a
non-contention errno), and the `/proc` scan skips inaccessible processes (`:58-61`); `adjudicate`
(`:149-158`) maps every non-held probe result to RESIDUE, so RESIDUE includes degraded observation,
not only positively-established staleness. Operator actions by outcome: ABSENT → proceed (no
barrier); HELD → wait (a holder is live, do not force); RESIDUE → the file is likely a stale
artifact, not a barrier — proceed and file a row to have it removed deliberately, but a RESIDUE
verdict from a failed/unreadable probe (not from a clean scan) is an UNKNOWN observation, not a
proof of staleness.

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
| `update --status complete` | — | requires `--evidence-run-id` | row closeout | a completion without a bound run id is **refused** (`evidence run required: completion REFUSED … --evidence-run-id is REQUIRED when setting status "complete" (TR-251)` — captured from `boardctl update BX-1 --status complete` this round; the `--help` synopsis lists `[--evidence-run-id RUN]` but does not state the requirement) |
| `create` / `update` (id, fingerprint) | — | unique id; unique finding fingerprint | row identity | a duplicate id is refused (`task id "…" already exists — create aborted`); a duplicate finding fingerprint is refused |
| `validate [--strict-keys] [--fail-on dangling-dep]` | — | flags | semantic validation strictness | `--strict-keys` tightens key uniformity; `--fail-on dangling-dep` promotes a dangling dependency from warning to failure (`boardctl validate --help`) |

**`board_drift.py` verification selectors (sol B12, added this round — the boardctl register is not the whole surface).** `scripts/board_drift.py:193-199` exposes the comparison-authority controls; `check()` runs `git rev-parse HEAD` and `merge-base --is-ancestor HEAD <ref>` (the `HEAD ancestry` row) to bind the comparison to a revision:

| Setting | Default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| `--workdir` | the script's parent's parent (`board_drift.py:194`) | a checkout dir | the *workdir* board copy compared | a wrong workdir compares a different (possibly stale) local board |
| `--ref` | `origin/main` (`:196`) | a git ref | the *published* board copy compared (checked out at that ref) | a different ref compares against a non-canonical published state |
| `--repo` | none (`:197`) | a path | the repo whose ref/ancestry is checked | unset uses the workdir's own repo; a wrong repo checks ancestry against the wrong history |
| `--published-dir` | none (`:198`) | a path | an explicit published-board dir in place of the ref checkout | points the comparison at a board dir that is not the canonical published copy |
| `--no-head` | false (`:199`, `store_true`) | flag | **removes the HEAD/revision binding** — without it the check compares bytes but does not prove the published copy is an ancestor/HEAD of the checkout | dropping HEAD ancestry lets a drift pass on two byte-identical *stale* copies that both lag the canonical HEAD |

**`board_read.py` read controls (added round 19 — dbf810b introduced this unit; it reads, never writes).** `board_read.py:91-96` parses four CLI switches; `load()` (`:59-70`) resolves the board from `origin/main` → `origin/master` → `main` → `HEAD` → worktree, and `main()` prints the source it used:

| Setting | Default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| `--root` | `.` (`:92`) | a checkout dir | which repo's board is read | a wrong root reads a different (or empty) board |
| `--json` | false (`:93`, `store_true`) | flag | print the canonical board as one JSON doc | without it a human summary prints instead |
| `--next` | 5 (`:94`) | int | how many dispatchable rows the summary lists | 0 lists none |
| `--source` | false (`:95`, `store_true`) | flag | print only `{source, rows}` | without it the full summary prints |

## 6. Contracts in and out

Canonical ids are the register of record (OUTLINE Part IV, CT-01..CT-18). Rows that are
cross-system contracts carry their CT id; an interface with no canonical entry is listed with a
`(local)` tag and is not a peer to any CT row, so it cannot be matched against another chapter.

| ID | Peer | Direction | Producer `file:function` | Consumer `file:function` | State |
|---|---|---|---|---|---|
| CT-14 | foreman | in | **external** — the foreman lives outside this repo; `grep -rn boardctl scripts/` matches the wrapper itself (`scripts/boardctl:2,9,11,15,16,21`), `board_lock.py:18,98,100` (its own `consumer_count` grep over the wrapper), `handbook_spine.py:58,71,74,75` (comments naming boardctl as a boundary peer), and `gen_unit_map.py:45` (a name list). No in-repo producer invokes `boardctl create` | the JSONL store `.coding-hermes/board/{tasks,events}.jsonl`, appended via the external `boardctl` binary (a file, not a function) | **UNVERIFIED** — the store is measured (357/519) but the foreman→board write wire is not exercised in this repo |
| CT-13 | gitreins | in | **external** — the judge's verdict file (written by the gitreins binary, not in this repo) | `boardctl update --status complete` (the external binary; completion REQUIRES `--evidence-run-id`) | **UNVERIFIED** — round-3 carried "broken (OUTLINE §IV)" as an inherited state; the gitreins-verdict→board-close path was not re-run this round |
| CT-10 | node | in | **external** — no in-repo producer writes a board row event: `grep -nE 'boardctl|tasks.jsonl|events.jsonl' scripts/node-bus-worker.py` → 0 matches | the JSONL store (the `boardctl` binary, out of scope) | **broken** — OUTLINE Part IV marks `node → board` broken; the node worker does not write board rows |

All three rows carry no in-repo function on either side because every side is an external peer
(the foreman, the gitreins binary, the `boardctl` binary, and the JSONL store). The honest state
is therefore **UNVERIFIED**/**broken** per OUTLINE, not "works" — a "works" verdict attached to an
unnamed side is a rumour with a verdict (grok 11 / deepseek 1). CT-10, CT-13 and CT-14 are
boundary contracts.

## 7. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| store census | `jq -r '.id' .coding-hermes/board/tasks.jsonl | wc -l` | 357 rows | 2026-11-06 | PASS (357) |
| events count | `wc -l .coding-hermes/board/events.jsonl` | 519 lines | 2026-11-06 | PASS (519) |
| drift | `python3 scripts/board_drift.py check --workdir /home/kara/code-factory --ref origin/main` | byte parity, RESULT OK | 2026-11-06 | **PASS** — `RESULT: OK`; byte parity `tasks.jsonl`/`events.jsonl` **identical** (sha256 `5aa15431…` / `783d556c…`); 357 vs 357 rows, **0 divergent ids: none**; HEAD=origin/main=`ce2f875` |
| semantic validate | `scripts/boardctl validate` | RESULT OK with named warnings | 2026-11-06 | **PASS** — `357 tasks, 519 events, 0 fixtures`, `key uniformity 357/357 (0 drift)`, `RESULT: OK (7 warning(s))` |
| lock adjudication | `python3 scripts/board_lock.py <lock>` against ABSENT/HELD/RESIDUE fixtures | ABSENT / HELD / RESIDUE named (`board_lock.py:149-158`) | 2026-11-06 | **PASS** — a scratch fixture returned `ABSENT`, `RESIDUE consumers=0 commits_after_mtime=unknown`, and `HELD holder=pid-<n>` (a child held an exclusive flock) all rc 0 |
| duplicate id refusal | `boardctl create --id CF-357 --title x` | refused | 2026-11-06 | **PASS** — `task id "CF-357" already exists … create aborted` |
| board read (canonical ref) | `python3 scripts/board_read.py --source` | `{"source": "origin/main", "rows": 357}` | 2026-11-06 | **PASS** — source=origin/main, 357 rows; `--next 10` summary names `dispatchable : 252 pending rows` (92 complete / 13 in_progress / 252 pending) |

**Drift re-measured (reconciled this round).** The CF-270 divergence the round-10 draft reported
as live was **already reconciled before this round's derivation**: commit `4dc0ef0` ("board: close
CF-270") and `8ae4f82` are both in `origin/main`, so `board_drift` at HEAD `ce2f875` returns
`RESULT: OK` — 357 vs 357 rows, 0 divergent ids, HEAD == origin/main. The round-10 draft's
`RESULT: DRIFT (4 failed)` with 1 divergent id (CF-270, workdir=`pending` vs published=`complete`)
and its 518-events count were a **pre-reconciliation snapshot presented as current**; both are
superseded. The instruction the round-10 draft itself issued — "`board_drift` must be re-run
after that merge" — is now executed: it returns OK.

**Census-vs-validation correction (F4-2).** The `jq -r '.id' … | wc -l` check is a **census**,
not integrity validation. The real validation is `boardctl validate`, which this round returned
`RESULT: OK (7 warning(s))` — the warnings are free-form `guard_result`/`ci_result` values
(outside the `{PASS,FAIL,SKIP}` vocabulary), a priority/title disagreement (CF-150, CF-192,
CF-371), a duplicate event id (line 337), and a headerless board (header checks skipped). Warnings
are distinct from failures; `--strict-keys` and `--fail-on dangling-dep` tighten the gate.

## 8. Metrics

**RED — none (absence-proved this round).** The board emits no counters or gauges as a service —
`grep -nE 'prometheus|Counter|Gauge|Histogram|/metrics' scripts/board_lock.py scripts/board_drift.py scripts/board_read.py`
→ 0 matches. Row counts are derived by `jq`/`wc`, not emitted. Churn, close-rate and age are all
derived by hand.

## 9. Log lines (verbatim)

`boardctl` is an external binary (`/home/kara/.local/bin/boardctl`, measured this round — not in
this repo), so these strings carry no in-repo `file:line`; they are quoted from the run output
captured this round (2026-11-06, rev `ce2f875`) with the commands named (N9):

| Level | Line | Emitted when | Kind |
|---|---|---|---|
| — | `boardctl: task id "%s" already exists in tasks.jsonl — create aborted` | duplicate id (captured from `boardctl create --id CF-357`) | evidentiary |
| — | `[warn] tasks.jsonl line %d (task %s): guard_result "%s" is free-form — not in the guard_result vocabulary {PASS,FAIL,SKIP} …` | validate (captured from `boardctl validate`) | evidentiary |
| — | `RESULT: OK` / `RESULT: OK (7 warning(s))` (`board_drift.py` / `boardctl validate`) | drift/validate completes | evidentiary |
| — | `board source : %s   (%d rows)` (`board_read.py:116`) | summary | descriptive — names the source read |
| — | `{"source": "%s", "rows": %d}` (`board_read.py:106`, `--source`) | `--source` flag | evidentiary — machine-readable, names the ref actually read |

## 10. Failure modes, indications and recovery

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Stale lock (RESIDUE, clean scan) | `board_lock.py` → `RESIDUE consumers=<n> commits_after_mtime=<n>` from a clean scan | a held lock (HELD names a live `holder=pid-N`/`flock-eagain`) | the file is not a barrier; proceed and file a row to remove it deliberately — never delete it in-band (CF-119) |
| Stale lock (RESIDUE, degraded probe) | the same `RESIDUE` shape produced from a failed/unreadable `flock_probe` or a `/proc` scan that skipped processes | a clean-scan RESIDUE | **do NOT proceed** — this is an UNKNOWN observation, not proof of staleness (sol B09). Re-run the probe or establish observation quality before acting; `adjudicate` discards the probe error/detail, so the classifier alone cannot tell the two apart |
| Live holder (HELD) | `board_lock.py` → `HELD holder=pid-N` or `HELD holder=flock-eagain` | a residue | wait; the holder is live, do not force the lock |
| Duplicate id / fingerprint | refused on append (`already exists … create aborted`) | a valid new row | use a new id or resolve the duplicate finding |
| Rule set only in chat | nine board rules have no module home | a written law | **OPEN** — CF-344 |
| Rows duplicating a module's defect table | same defect in two places | a single source of truth | **OPEN** — CF-363 |
| Sibling reversion | a staged stale row copy reverts a closeout | a real change | normalize the sibling's stale copy after a supersession |

## 11. Limits and margins

- Rows are addressed by `id` + `status`, never index (a positional offset is not a durable key).
- `--status complete` without `--evidence-run-id` is refused (`evidence run required: completion
  REFUSED … (TR-251)` — the enforcement string, not the `--help` synopsis).
- `boardctl validate` distinguishes warnings from failures; a headerless board skips header checks.
- The `flock_probe` is advisory only: it proves *someone* holds an exclusive flock, not *who* or
  *why*; the `/proc/<pid>/fd` scan is subject to permission/race limits (`:60-61` skips
  un-inspectable pids).
- `board_read.py` never refuses: it reads the canonical ref (`origin/main`) first, falls back to the
  worktree only when no remote ref exists, and always prints the source (`:59-70`, `:116`). "The
  board is behind `origin/main`" is a reading instruction (read the ref), not a reason to refuse
  (dbf810b's own commit message).

## 12. Cross-references

- F5 LANDING writes the board row a landing closes (M3) — **flow chapter not written** (OUTLINE Part II, all 16 flows MISSING).
- **M9 SCHEDULER reads board rows as admission gates** — `internal/scheduler/admission_mode.go:230-243`
  is the board-ownership/workability admission decision. **M10 CRIER does not** (B04): a source
  search across crier's Go files finds no `tasks.jsonl`, `board_ownership`, `boardWorkable` or
  board/admission terminology — the bus operates on inbox messages and leases.
- M6 DOCUMENTATION's gate reads `_facts.md`; board rows are the evidence of record.

## 13. Evidence of record

- Store: `.coding-hermes/board/tasks.jsonl` (357 rows), `events.jsonl` (519 lines).
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
    is in `origin/main`; `board_drift` at HEAD `ce2f875` returns `RESULT: OK` (357 vs 357, 0
    divergent ids, byte parity identical, HEAD == origin/main). The round-10 draft reported the
    pre-reconciliation DRIFT as current; that reading is superseded. The events count is 519, not 518.
  - **F4-5** (new, B04) — the board-admission gate belongs to M9 alone; crier has no board admission.
  - **F4-6** (new, sol B27) — S1/S2 re-classified from **active** to **operator-invoked (optional)**: a repo-wide grep finds no in-repo unit/cron/timer invoking `boardctl`/`board_lock`/`board_drift` (only `tests/selftest.sh` exercises them); a writer's manual run proves observation, not production activation. The foreman lane (external) is the intended caller.
  - **F4-7** (new, round 18) — `board_drift.py`'s comparison-authority controls (`--workdir`, `--ref`, `--repo`, `--published-dir`, `--no-head`, `:193-199`) registered in §5 (sol B12); the completion `--evidence-run-id` requirement re-cited to the runtime refusal string (`evidence run required: completion REFUSED … (TR-251)`) instead of `boardctl update --help`, which lists `[--evidence-run-id RUN]` but does not state the requirement (grok #9).
  - **F4-8** (new, round 19) — commit dbf810b added `scripts/board_read.py` (125 lines), a board READ unit, and it is **not in the OUTLINE's M4 submodule list** (`OUTLINE.md:164` names only S1 write/validate + S2 compare) nor in `docs/UNIT-MAP.yaml` (M4 S1–S2 only). A read unit is a third responsibility the outline has no home for; documented here as S3. It is the only M4 unit with a production (lane) invoker — `prompts/foreman.md:42` instructs the foreman lane to run `python3 scripts/board_read.py --next 10` — so the round-18 blanket claim "no in-repo unit/cron/timer invokes boardctl/board_lock/board_drift" must be scoped: it holds for boardctl/board_lock/board_drift but **not** for board_read.py (active, lane-invoked).

## RED field count: 2 (Metrics §8 — absence-proved; the Contracts-in-and-out field (§6) — not-measured: CT-14/CT-13/CT-10 are boundary contracts whose wires were never measured)

**RED accounting — the single rule, cited to OUTLINE Part VII.3 (`OUTLINE.md:266-282`) this round (grok #3 / sol B01).** A RED is a *schema field* (§1–§13) whose evidence is incomplete:
- **not measured** — an unread body, an unrun ladder, an untabulated log inventory, an unminted credential, or a contract wire never exercised. This is **UNVERIFIED** and a named RED (`OUTLINE.md:277-278`).
- **absence proved** — a field filled by a command whose output establishes the absence (e.g. `grep -nE 'prometheus|Counter|Gauge|Histogram|/metrics' … → 0 matches` for §8). This is a *filled* field with a RED value (`OUTLINE.md:271-273`).

A **boundary contract** (CT-10/CT-13/CT-14) whose far side is an external peer is a **not-measured RED, not an exemption** (sol B01): the honest `UNVERIFIED`/`broken` state is retained as blocking, and the "no in-repo producer/consumer exists" grep is the *annotation* on that state, not a completion of it — no in-repo measurement can exercise the foreman→board, gitreins→board or node→board wire, so the §6 field stays RED. Round-17's "terminal state, not a RED" reading is **superseded** (grok #3 / sol B01) and deleted here, so the acceptance rule has one formulation document-wide.

**CROSS-SECTION DEPENDENCY (round 18 — resolved).** This chapter now applies the same strict rule M1/M2/M3/M9/M12 already adopted: boundary/local contract `UNVERIFIED`/`broken` states are RED (not-measured), cited to OUTLINE Part VII.3. The round-17 divergence (M4 "terminal, not RED" vs M1/M2/M3 "RED, not exemptions") is closed.
