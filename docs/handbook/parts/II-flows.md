# Part II — Flows

Sixteen flows carry the system from intent to evidence. Each subsection below is one
flow: what starts it, the ordered steps with their actors, the contracts it exercises,
and the failure paths the chapters actually measured. Every step cites the chapter text
or contract row it came from; nothing here is invented, and where a chapter marks a
wire UNVERIFIED, BROKEN or MISSING, the flow says so. The sequence diagrams are
generated from `docs/SYSTEM-MODEL.yaml` by `scripts/gen_handbook_figures.py`.

## 2.1 F1 — Dispatch and settlement

![FIGURE 2.1](figures/F1.svg)

**Starts when:** an admitted tick delivers an envelope to a node's inbox; admission
itself is flow F11. Seven messages turn one board row into one settled attempt.

**Steps:**

1. The scheduler hands crier an envelope carrying run_id, corr_id, lane, board and
   text_b64 (`CT-02`, PROVEN; `internal/bus/dispatch.go:202,266`).
2. The node's bus worker pulls the message and holds a 30-second lease (`CT-03`,
   PROVEN; `scripts/node-bus-worker.py:1356,1383`).
3. The node hands the harness the brief, the workdir and the credentials (M2 §3).
4. The harness returns the diff and the evidence (M5 §2).
5. The node replies with status, dispatch_id, corr_id, branch, commit and artifacts
   (`CT-04`, PARTIAL; `node-bus-worker.py:1176-1192`).
6. Crier correlates the completion into the scheduler's durable inbox (`CT-06`,
   PROVEN; `internal/registry/handler.go:170,1452`).
7. The scheduler settles: the row's state changes and the attempt is recorded
   (`dispatch_leg.go:260-336`, M9 §3).

**Contracts exercised:** `CT-02`, `CT-03`, `CT-04`, `CT-06`.

**Failure paths:** settlement reads only `ok` (`dispatch_leg.go:713-726`); a node reply
carrying `status:"failed"` and no `ok` — the field `node-bus-worker.py:1180` actually
sends — is scored a success (CF-355, M9 §2). An unacked message redelivers after lease
expiry; an empty inbox list is not a lost message (M10 §11).

## 2.2 F2 — Provisioning

![FIGURE 2.2](figures/F2.svg)

**Starts when:** the operator declares a lane — project, harness, pin — and a bare host
must become a node.

**Steps:**

1. The operator declares the lane to the scheduler (M1 §3).
2. The provisioner drives the bunker daemon to create the container, the per-agent home
   and the keys (`scripts/bunker-provision.sh:504`, M1 §3 S2).
3. The provisioner layers the node: base, harness, bus, repo (M1 §3).
4. The node takes its identity and namespace credential (M1 §3).
5. The verifier measures the result — CREATED is not VERIFIED (M1 §12).

**Contracts exercised:** `CT-23` (provisioner → bunker), `CT-22` (node registration).

**Failure paths:** the certification ladder awards VERIFIED per leg — agent, gateway,
auth, artifact, tree, seed — and an unreachable port is UNVERIFIED (exit 3), not FAIL
(M1 §10, CF-224). The node's registration producer half is not established; crier's
`HandleRegister`/`HandleRegisterByID` are named, the wire is UNVERIFIED (M1 §6).

## 2.3 F3 — Memory

![FIGURE 2.3](figures/F3.svg)

**Starts when:** a run ends and someone later needs to find it by project, week or lane.

**Steps:**

1. The node writes an R1 detail record to DuckBrain (`CT-09`, MISSING — CF-329, M2 §6).
2. The node writes an R2 fleet index record (`CT-09`, MISSING).
3. The foreman writes an R3 weekly rollup (`CT-15`, UNVERIFIED boundary, M9 §6).
4. The operator recalls by project, week and lane (M9 §6).

**Contracts exercised:** `CT-09`, `CT-15`.

**Failure paths:** the designed path is broken at the first step — `node-bus-worker.py`
makes zero DuckBrain calls, so no R1 or R2 record exists to recall (CF-329, M2 §6).
The foreman-to-DuckBrain wire is a boundary the chapters did not measure. This flow is
the book's largest designed-but-absent surface; no section of it is padded with
unmeasured detail.

## 2.4 F4 — Documentation

![FIGURE 2.4](figures/F4.svg)

**Starts when:** a module needs an approved document and the foreman opens a skeleton.

**Steps:**

1. The foreman hands the doc gate the skeleton and the sources (M6 §2).
2. A panel seat fills sections and cites `file:line` for every fact (M6 §2).
3. The doc gate returns PASS or named refusals (`CT-16`;
   `scripts/master_doc_check.py:263`).
4. Three panel seats grade independently; splits are reported, never voted away
   (M6 §3 S4).
5. The spine gate checks cross-chapter consistency — canonical CT ids, states, dangling
   references (M6 §3 S9).
6. The handbook reaches the operator with a status per module (`CT-18`, M6 §6).

**Contracts exercised:** `CT-16`, `CT-18`.

**Failure paths:** the doc gate is structural, not a truth verifier — it cannot tell
whether a sentence is true (M6 §2). `CT-16` was downgraded from PROVEN: the handbook
build reads no MASTER-DOC output, so the receiver half is uncited (M6 §6). A panel STOP
exit is process success, not document acceptance (M6 §5).

## 2.5 F5 — Landing

![FIGURE 2.5](figures/F5.svg)

**Starts when:** a worker holds a commit on a node branch and the work must reach main.

**Steps:**

1. The node commits on a node branch; the commit gate grades the staged diff through
   the pre-commit hook (`CT-12`; `scripts/install-gitreins.sh:124`).
2. The gate's verdict returns to the foreman (`CT-13`).
3. The operator-triggered lander merges the branch and proves the commit is an ancestor
   of origin/main (M3 §2).
4. The foreman closes the row with evidence (`CT-14`).

**Contracts exercised:** `CT-12`, `CT-13`, `CT-14`.

**Failure paths:** the hook side is pinned, but that git invokes the hook is unproven
(M3 §6, M3 §11); where the gate is absent the pre-commit hook exits 0 — a silent bypass
that must be disclosed (M3 §10). The verdict-to-close path was not re-run; completion
requires `--evidence-run-id` on `boardctl update` (M4 §6).

## 2.6 F6 — Maintenance

![FIGURE 2.6](figures/F6.svg)

**Starts when:** the provisioner or the safety reaper runs its maintenance pass against
disks, branches, caches and freshness.

**Steps:**

1. The provisioner's layer-00 pass runs `reclaim_disk`, which reaps build caches and
   job directories past the 24-hour TTL (M8 §3 S1).
2. The `node_hygiene` reap removes orphan homes and keys after a 60-minute grace
   (M1 §5).
3. `repo_freshness` measures how far a workdir lags origin (M3 §5).
4. The verifier's `node_freshness` measures branch, HEAD and lag on the node (M1 §11).
5. Safety refuses protected paths before inspection — the repo, `node.json`,
   `crier.json` (M8 §5).

**Contracts exercised:** none — this flow runs procedures, not register wires.

**Failure paths:** the TTL governs age, not citation; the reaper can delete a directory
a module cites as evidence (M8 §2). A gitleaks claim without its `--log-opts` scope is
refused (M8 §2).

## 2.7 F7 — Monitoring

![FIGURE 2.7](figures/F7.svg)

**Starts when:** an operator or a cron asks whether the machine is unwell.

**Steps:**

1. The scheduler serves `GET /api/v1/metrics` — spawns, deferrals, ticks, tick duration
   (M9 §8).
2. The scheduler serves `/api/v1/status` — per-project failure-rate breakdown (M9 §5).
3. Crier serves `/metrics`, default-ON — guard and inbox series (M10 §8).
4. The proxy appends a usage JSONL line per request — node, model, status, bytes
   (M12 §8).

**Contracts exercised:** none — every wire here is an HTTP read.

**Failure paths:** the measured gap is coverage, not correctness — 11 of 13 modules
emit no metrics, so most of the system is answerable only by grepping logs (M9 §8,
model note). The chapters name no per-module counter beyond the four surfaces above.

## 2.8 F8 — Recovery

![FIGURE 2.8](figures/F8.svg)

**Starts when:** a crash, a restart or an orphaned run leaves work in an unknown state.

**Steps:**

1. The dispatcher replays the recorded result on redelivery instead of re-running
   (`dispatcher.py:470-475`, M11 §3 S2).
2. Crier redelivers an unacked message after lease expiry; an empty list is not a lost
   message (M10 §11).
3. The scheduler's `--reap-sessions` closes stale sessions, dry-run without `--apply`
   (M9 §5).
4. `board_read` resolves the board from origin/main when the working copy drifts
   (M4 §3).
5. A `board_lock` ERROR verdict means lock state is unknown: stop and diagnose, never
   write (M4 §3).

**Contracts exercised:** `CT-03` (redelivery), `CT-06` (replayed settlement).

**Failure paths:** the replay ledger only covers a task whose result reached the ledger
before the crash; a result lost with the process is re-run from scratch (M11 §3 S2).
The dispatcher's deadline kill terminates run.sh's process group, not the harness's own
group, so the kill-the-group guarantee is withdrawn (M11 §2).

## 2.9 F9 — Degradation

![FIGURE 2.9](figures/F9.svg)

**Starts when:** a dependency is gone and each component must choose a posture.

**Steps:**

1. The gateway fails: the tick is deferred, not exec-spawned — `no-exec-fallback=true`
   (M9 §5).
2. The load gate defers new spawns while load is at or above the threshold (M9 §3).
3. The guard fails open on provider outage unless policy is FailClosed (M10 §10).
4. The proxy fails closed at startup: no token file or no upstream key exits 2
   (M12 §11).
5. The commit gate absent: the pre-commit hook exits 0 — a silent bypass that must be
   disclosed (M3 §10).

**Contracts exercised:** none directly; each step is a component's documented posture.

**Failure paths:** the postures disagree by design — the proxy fails closed, the guard
fails open, the hook silently passes. The only one of the three that is fail-closed and
measured is the proxy's startup check (M12 §11).

## 2.10 F10 — Teardown and rebuild

![FIGURE 2.10](figures/F10.svg)

**Starts when:** the operator removes a node or a lane and no residue may survive.

**Steps:**

1. `--destroy` requires `--yes` and a named agent (M1 §5).
2. The provisioner removes the container and the per-agent home on the server (M1 §5).
3. The orphan-home reap runs against a live-registry check (M1 §10).
4. A rebuild reapplies the seed from the manifest, naming drift per file (M1 §3 S4).

**Contracts exercised:** `CT-23` (create/exec/cp, in reverse).

**Failure paths:** destroy is operator-gated, not foreman-reachable — the chapters name
no autonomous destroy path (M1 §5). The reaper's grace is 60 minutes; a home reclaimed
inside the grace window is refused (M1 §5). No chapter measures residue left inside the
container image itself; the teardown claim stops at the home and container boundaries.

## 2.11 F11 — Scheduling admission

![FIGURE 2.11](figures/F11.svg)

**Starts when:** a lane's cadence tick fires, and the question is whether it is
admitted — and if not, why not, by name.

**Steps:**

1. The scheduler resolves the admission mode — project override, then namespace
   default, then cooldown (`admission_mode.go:98,112`, M9 §3).
2. Board ownership and workability decide the tasks waiver (M9 §3).
3. Usage pools are reserved, or a capacity denial is emitted (M9 §3).
4. The board-stasis gate excludes an unchanged cooldown builder lane
   (`packer_select.go:474,614`, M9 §3).
5. NOOP-PACING spaces a no-artifact lane, doubling to 8 times the floor
   (`noop_pacing.go:74`, M9 §3).
6. Admitted — the envelope is dispatched (`CT-02`, PROVEN).

**Contracts exercised:** `CT-01` (the configuration being resolved), `CT-02` (the
admitted envelope).

**Failure paths:** refusal is always a named reason — budget hold, cooldown, load gate,
fairness, namespace allocation (M9 §3). The load gate defers rather than drops
(M9 §3). The admission configuration itself is `CT-01`, UNVERIFIED.

## 2.12 F12 — Credential lifecycle

![FIGURE 2.12](figures/F12.svg)

**Starts when:** a token is needed, or an existing one ages toward expiry.

**Steps:**

1. The operator mints from an 0600 App private key — JWT, then installation token
   (M7 §5).
2. The token is written to a 0600 file; the value is never printed (M7 §7).
3. `refresh --node` installs `auth/github.token` on the node (M7 §5).
4. `fleet-gh-scope` mints the per-dispatch scoped token the dispatcher injects
   (M11 §3 S4, M11 §6).
5. The proxy checks the node bearer against the token file — fail-closed admission
   (M12 §6).

**Contracts exercised:** `CT-21` (installation token), `CT-19` (node bearer).

**Failure paths:** the App mint was never run on the documenting host — no App
credentials exist there, so `CT-21` is UNVERIFIED end to end (M7 §6). The node bearer
half of `CT-19` is config-wired with no call site in this repo; the proxy side is
measured (401 without a token, M12 §6).

## 2.13 F13 — Upgrade and migration

![FIGURE 2.13](figures/F13.svg)

**Starts when:** a pinned bump or a schema change must reach the running system.

**Steps:**

1. The operator bumps a pin; the installer fetches a digest-checked artifact (M5 §5).
2. The installed version is read back against the pin, and drift is named (M5 §10).
3. The scheduler's migration stores apply schema change to the 30-table store (M9 §3).
4. `boardctl normalize-statuses` migrates the row vocabulary (M4 §4).

**Contracts exercised:** none — each step is an operator-invoked procedure, not a
register wire.

**Failure paths:** version drift is detected by read-back and named per file (M5 §10);
the chapters name no automatic rollback. Schema migration is a measured 30-table store
(M9 §3); the row-vocabulary migration is a boardctl command with no measured
post-migration state (M4 §4).

## 2.14 F14 — Observability ingestion

![FIGURE 2.14](figures/F14.svg)

**Starts when:** a tick, a turn or a message happens, and must become a visible,
attributed line.

**Steps:**

1. The node records every turn, model, tokens and cost (`CT-11`, boundary, M2 §6).
2. The scheduler serves tick and spawn counters at `/api/v1/metrics` (M9 §8).
3. The proxy appends usage and capture JSONL per request; capture loss is silent
   (M12 §11).
4. The foreman writes decisions, findings and goals to durable memory (`CT-15`,
   UNVERIFIED boundary, M9 §6).
5. The scheduler syncs its DuckBrain namespace every 5 minutes (M9 §5).

**Contracts exercised:** `CT-11`, `CT-15`.

**Failure paths:** capture loss at the proxy is silent — a missing line cannot be
distinguished from a missing request (M12 §11). The node-to-session-store wire is a
boundary both of whose ends are the Hermes runtime, out of scope (M2 §6). This flow,
like F7, inherits the 11-of-13 metric gap.

## 2.15 F15 — Backup and restore

![FIGURE 2.15](figures/F15.svg)

**Starts when:** an artifact must be restored and proven, not merely copied.

**Steps:**

1. `board_drift` compares the checkout's board against origin/main row by row (M4 §7).
2. `--verify-board` checks board consistency at boot (M9 §5).
3. The operator restores into a scratch home and reads back a known row (M9 §5).

**Contracts exercised:** none — all three steps are verification procedures.

**Failure paths:** drift is named row by row, not as a bulk count (M4 §7). The model
defines three steps and the chapters measure none of them end to end; this subsection
is deliberately short rather than padded with unmeasured detail.

## 2.16 F16 — Multi-node fan-out

![FIGURE 2.16](figures/F16.svg)

**Starts when:** one directive must reach several nodes, each with its own receipt.

**Steps:**

1. The scheduler addresses the envelope to each target agent in the registry
   (M11 §3 S4).
2. `bunker exec` runs the harness inside each target container (M11 §3 S1).
3. The dispatcher delivers the reply before ack; a redelivery replays, never re-runs
   (M11 §3 S3).
4. Completion settles per dispatch through crier (`CT-06`, PROVEN).

**Contracts exercised:** `CT-02` (per-target envelopes), `CT-06` (per-dispatch
settlement).

**Failure paths:** the dispatcher's loop is serial — one long job head-of-line-blocks
later agents (M11 §11). The replay guarantee covers only results that reached the
ledger before the crash (M11 §3 S2). The deadline-kill defect of F8 applies per target
(M11 §2).
