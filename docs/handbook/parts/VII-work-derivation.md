# Part VII — Work derivation

A row is the unit of work; this part follows one row from the moment it is written to the
moment it closes. Every hop names the contract that carries it, and every contract cites
the chapter that measured it. The chain is: a row is filed, a tick admits it, the bus
carries it, a harness executes it under a brief, a judge grades the result, and the row
closes on evidence — or it does not close at all.

## VII.1 The chain, as a table

| Hop | Actor decides | Contract | Carries | Measured in |
|---|---|---|---|---|
| file | the foreman files a row | CT-14 | row created, evidence bound at close | M4 §6 |
| admit | the scheduler | CT-01 | lane enabled, cadence, weight, pin | M9 §6 |
| envelope | the scheduler | CT-02 | run_id, corr_id, lane, board, text_b64 | M9 §6 |
| lease | crier | CT-03 | inbox message plus a 30 s lease | M2 §6 |
| execute | the node / dispatcher | CT-04 | reply: status, dispatch_id, corr_id, branch, commit | M2 §6 |
| settle | the scheduler | CT-06 | completion event correlated to the run | M9 §6 |
| grade | gitreins | CT-12 | the staged diff, guarded at commit | M3 §6 |
| close | the board | CT-13 | a verdict that closes a row | M4 §6 |

One hop may refuse. A refusal names a reason; a silent drop is a defect, not a decision.

## VII.2 The board row lifecycle

The board is two JSONL stores, `tasks.jsonl` (rows) and `events.jsonl` (transitions), in
`.coding-hermes/board/` (M4 §1). At the 2026-11-07 measurement the store held 357 rows and
520 events (M4 §7). A row moves `pending` → `in_progress` → `complete`, and the non-forward
states are part of the design: `blocked` carries a named blocker, `deferred` carries an
unmet dependency (M4 §12; the front-matter overview, figures/board-lifecycle.svg).

Three rules govern the write path:

- **Closeout requires evidence.** `boardctl update --status complete` refuses without
  `--evidence-run-id` (M4 §5, TR-251). A completion is bound to a run the board can name.
- **Identity is unique.** A duplicate id is refused (`task id "…" already exists — create
  aborted`), and so is a duplicate finding fingerprint (M4 §5).
- **The lock is classified, never assumed.** `board_lock.py adjudicate` (`:166-185`)
  returns one of four verdicts — ABSENT, HELD, ERROR, RESIDUE (M4 §3). ERROR means the
  lock state is unknown, exits 3, and is never permission to write (M4 §3, CF-259).

The read path has its own rule: the board lives in git, `origin/main` is the canonical
store, and the working copy is a cache other writers are allowed to dirty.
`scripts/board_read.py load` (`:59-70`) resolves `origin/main` → `origin/master` → `main`
→ `HEAD` and falls back to the worktree only when no ref resolves; it never refuses, and
it reports which source it used (M4 §3; prompts/foreman.md, "Read your own board first").
The prompt rule is explicit: a dirty worktree is a reading instruction, not a reason to
refuse, and a tick that reports "board read prohibited" while 252 rows are dispatchable is
the defect (prompts/foreman.md).

## VII.3 Admission — tasks versus cooldown

Admission is the scheduler's authority: it decides when a lane's cadence tick fires and
whether the tick is admitted (M9 §2). The decision is an ordered procedure, and the order
is the contract (M9 §3, "Ordered admission procedure"):

1. Mode precedence: a project mode wins, then the namespace mode, then `cooldown`
   (`admission_mode.go:98-107`).
2. Board ownership: an explicit override wins, otherwise filesystem workdir containment
   (`:177-184`).
3. Board workability: a tasks-mode lane with a workable owned board earns the cooldown
   waiver; an empty workdir, a non-owned board or an unreadable board returns false, which
   falls the lane back to its cooldown pin rather than refusing dispatch (`:230-243`).
4. Last-tick failure: a project whose last tick failed stands the waiver down and paces on
   the full cooldown (SCHED-GAP-214).
5. Usage-pool reservation: disabled enforcement, an unavailable authority and a capacity
   denial are three distinct outcomes with distinct caller obligations
   (`usage_pool_policy.go:26-63`).
6. Board-stasis gate: a cooldown BUILDER lane whose board is unchanged since its previous
   completed tick is excluded from selection, and no cooldown is consumed
   (`packer_select.go:474`, flag default true, SCHED-GAP-1678).
7. Load gate: above the threshold, new spawns are deferred, not dropped
   (`load_gate.go:63`, SCHED-GAP-125).
8. NOOP-PACING: a tasks-admitted lane that produces no artifact has its next admission
   spaced by `cooldown_floor_s`, doubling to 8× the floor, and any artifact resets the
   streak (`noop_pacing.go:59, :74`; M9 §3).

The design intent of the two modes is the trade the numbers name: `tasks` mode admits on
work — a workable board row dispatches now, and the waiver replaces the wait. `cooldown`
mode admits on time — the lane paces itself, and stasis or failure stretches the gap. The
measured defect that motivated step 8 ran 76 spawns a day with 63 dry-run ticks and no
artifact, because a no-op tick burned nothing and reset no counter (M9 §3, the
NOOP-PACING finding). The readback rule at settlement belongs to the same authority and
is the honest edge of it: `dispatchReplyVerdict` (`dispatch_leg.go:713-726`) reads only
`payload["ok"]`, and the absence of a verdict is treated as success (M9 §2; CF-355 open).

## VII.4 Dispatch — envelope, lease, execution

The admitted tick becomes an envelope: run_id, corr_id, lane, board reference and a
`text_b64` directive, signed and POSTed to the bus (CT-02; M9 §6). Crier grants a lease on
retrieve (CT-03), and two consumers exist: the node worker (M2) and the dispatcher (M11).

The node worker's refusals come before any network work. It refuses a dispatch with no
`text` directive and a dispatch whose `brief.digest` does not match `sha256(text)` — a
brief altered in flight is refused, not run (`node-bus-worker.py:1036-1042, :1044-1052`;
M2 §11). Settlement is ordered: execute, deliver each result, write the seen-cache only
after delivery succeeds, ack last (M2 §11, B10). The real reply fields are
`env_version, dispatch_id, corr_id, status, host_identity, harness, vars, exit_codes,
gate_exit, branch, commit, artifacts, wall_s, finished_at` (`node-bus-worker.py:1176-1192`;
M2 §6) — there is no `run_id`/`outcome` field, and the register row that said otherwise was
stale (M2 §6).

The dispatcher (M11) is the other consumer: one loop per agent per box, executing inside
the agent's container via `bunker exec`. Its job model is start detached, poll with short
calls, kill on deadline (`dispatcher.py:215-331`), and its ledger replays a recorded result
instead of re-running a redelivery (`:470-475`; M11 §3). The deadline kill terminates
run.sh's process group; whether it reaches the GNU-timeout group holding the harness is
unverified, so the descendant-termination guarantee is withdrawn until a test proves it
(M11 §10, F11-8). Its known margins are named the same way: a redelivery replay is not
unconditionally crash-safe, because the task runs before the ledger write (`:479` vs
`:481`; F11-3), and the serial loop head-of-line-blocks later agents (F11-5).

## VII.5 The worker brief — variable contract, commit discipline, guards

A dispatched directive becomes a run only if the harness accepts its brief. The variable
contract is `harness-vars.sh`: `CFV_DECLARED` lists 12 variables and `CFV_REQUIRED` 6, and
`--contract` mode refuses the run when a required variable is missing or malformed (M5 §5).
The rules that matter to a brief writer:

- **Credentials are paths, never values.** `CF_API_KEY_FILE` must be a path with mode
  `[0-7]00`; a key value in the environment is refused, and `CF_BASE_URL` carrying
  `user:pass@` is refused (M5 §5).
- **The write boundary is `$HOME`.** `CF_WORKDIR` must resolve inside it (M5 §5).
- **Commits are composed in a file and written with `git commit -F <file>`.** The brief
  requires a commit message that survives shell quoting, carries the co-author trailer,
  and describes what changed; the harness flight data file grades exactly this — "a commit
  lands carrying the co-author trailer" (M5, FLIGHT DATA FILE). A commit message is
  never evidence: "never claim a row complete unless a command someone else can re-run
  demonstrates the acceptance criteria" (prompts/foreman.md, Ground rules).
- **Work is isolated in a worktree.** The landing gate runs in a detached worktree at the
  node's commit, so it measures the node's tree and not main's (M3 §11); the lander merges
  the envelope's exact commit, never the branch tip (M3, appendix unit 20). A lane works in
  its own checkout for the same reason two writers may not share one index.
- **Guards run at commit.** The pre-commit hook invokes `gitreins guard --quality-async`
  against the already-staged changes, and tier-1 (`gitleaks detect --no-git`) grades the
  working tree while the guard grades staged files only (M3 §5, §6; CT-12). A guard that
  did not run is a named condition: the hook exits 0 when `.gitreins/config.yaml` is
  absent, and a bypass of `core.hooksPath` must be disclosed in the commit message when
  used (M3 §10, "by design but dangerous — the bypass must be disclosed"; quorum 5/5).
- **Hooks are not proven by presence.** A generated hook file does not prove git invokes
  it; the effective `core.hooksPath` must resolve, and the rejecting-commit fixture that
  proves a refused commit cannot advance HEAD is the missing evidence (M3 §11, B11).

## VII.6 Judge and verdict readback

The judge is a gate, not a correspondent. The staged diff goes to gitreins (CT-12, M3 §6),
and the verdict that comes back is what closes a row (CT-13, M4 §6). The readback rules:

- **The verdict names criteria.** A grade is PASS or FAIL "with named criteria, never a
  silent skip" (M5, FLIGHT DATA FILE). A verdict that cannot name what it graded is
  not a verdict.
- **The verdict line is a row-count contract.** The harness adapter's verdict is decided
  by row counts — every row `PASS` makes `PASS` with exit 0, one `WARN` row makes
  `UNVERIFIED` with exit 3, any `FAIL` row makes `FAIL (n)` with exit 1 (M5 §6). A summary
  line that contradicts its own rows was the defect; the fix held the contract in both
  directions with a red control, so the pass is not reachable by deleting the warning
  mechanism (M5 §6, CF-384).
- **Readback mismatches are findings, not interpretations.** The control-plane half reads
  only `ok` while the node sends `status` — a failed result can be recorded as a pass, and
  the row stays open until the two fields agree (M2 §6, M9 §2; CF-355). The mirror rule
  holds on the worker side: a false `ok` for a failed run records a pass for work that
  never happened (M2 §2).
- **A verdict file readback is a surface, not a courtesy.** Closing work requires reading
  the verdict and binding it: the board's own completion verb refuses a closeout that does
  not name the run id that proves it (M4 §5).

## VII.7 Closeout

Closeout is a landing plus a board transition, in that order. The landing proves ancestry
before it pushes: the merge target is the envelope's commit, the pushed object is the merge
it just created, and the fast-forward path checks the merge tip against the envelope before
anything moves (`land-node-branch.sh:238-265`; M3, appendix unit 20). The evidentiary rows
are `LANDED: <branch> @ <commit>` on success and `LAND: REFUSED — <reason>` on any failed
precondition (M3 §9).

The board transition carries the run id. A row closes `complete` only with
`--evidence-run-id`, the event log grows by exactly one line, and the closing evidence must
tie to the exact tree the run produced (M4 §5, FLIGHT DATA FILE). Rows that cannot proceed
go `blocked` with a named blocker and the one command that unblocks them, and the
classification comes before the receipt: a dirty checkout held by a live worker is a
stand-down, not a block, because "nothing is wrong, something is working"
(prompts/foreman.md, "Before you block").

What each hop must be able to prove, in one line per hop:

| Hop | The proof that must exist |
|---|---|
| file | a row with acceptance criteria someone else can re-run |
| admit | the tick line names admitted or deferred, never dropped (M9, FLIGHT DATA FILE) |
| dispatch | a run id and a corr id, in the envelope and in the reply |
| execute | a digest-verified brief, a bounded wall, a signed reply |
| grade | a verdict with named criteria and an exit that matches its rows |
| close | a landed commit, an evidence run id, one new event |

> CAUTION: a hop that cannot produce its proof is a finding to file, not a prose
> placeholder. Any RED field the row touches stays RED until a command proves it
> (prompts/foreman.md, "Rules that come from the document").
