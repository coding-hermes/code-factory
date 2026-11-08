# Part II — Flows

Sixteen flows carry the system from intent to evidence. Each subsection below is one
flow and follows one fixed contract: what starts it (**trigger**), who acts and where
(**actors and location**), what must already hold (**prerequisites**), what arrives
(**inputs**), the ordered calls (**steps**), what changes on disk or in memory
(**state and artifacts**), how it refuses and recovers (**refusal, failure and
recovery**), what configuration governs it (**settings**), who owns its numbers
(**metric owner**), and what makes it done (**completion proof**). Every step cites
the chapter text or contract row it came from; nothing here is invented, and where a
chapter marks a wire UNVERIFIED, BROKEN or MISSING, the flow says so. Where the
handbook has no measured metric for a flow, the metric-owner line names the gap
rather than inventing a counter. The sequence diagrams are generated from
`docs/SYSTEM-MODEL.yaml` by `scripts/gen_handbook_figures.py`.

## 2.1 F1 — Dispatch and settlement

![FIGURE 2.1](figures/F1.svg)

**Trigger:** a lane's cadence tick opens, following admission (F11).

**Actors and location:** the scheduler on the control host; crier as the
launch/return boundary; the node, foreman, harness and per-Bunker DuckBrain inside
the project's Bunker; the board in the project repo, with local and remote copies on
both sides of the boundary.

**Prerequisites:** the lane is enabled and configured (`CT-01`); the repository and
board copies were refreshed before eligibility; the board-check verifier found work;
admission reserved capacity.

**Inputs:** the dispatch envelope — run_id, corr_id, lane, board, text_b64
(`CT-02`, PROVEN; `internal/bus/dispatch.go:202,266`); the lane prompt text
(`CT-05`, UNVERIFIED); the board revision checked at admission.

**Steps:**

1. The scheduler refreshes the local and remote repository/board copies before
   eligibility and records the revision checked. Integration gap shown, not
   concealed: today's PRE lane hook runs after admission, not here.
2. The scheduler's board-check verifier distinguishes WORK, NO-WORK and UNREADABLE;
   no-work routes to cooldown/defer; an unreadable board is diagnosed, never
   dispatched as if it were empty.
3. The scheduler hands crier the envelope (`CT-02`, PROVEN).
4. The node's bus worker — inside its Bunker — pulls the message and holds a
   30-second lease (`CT-03`, PROVEN; `scripts/node-bus-worker.py:1356,1383`).
5. The Bunker foreman starts: it prepares the brief and the workspace for the worker.
6. The MVP harness is fixed: the foreman invokes Hermes directly. A future Task
   Router would sit between Node and Harness and is drawn NOT PART OF MVP.
7. The harness returns the diff and the evidence (M5 §2).
8. The commit guard (Tier 1) grades the commit; the independent acceptance judgment
   (Tier 2) grades the result against the criteria (M3 §2, M9 §6).
9. The foreman writes decisions and findings through its Bunker's DuckBrain — the
   instance that must expose the same logical memory view as the controller
   (`CT-15`, UNVERIFIED boundary, M9 §6).
10. The foreman publishes results and board changes (`CT-14`, UNVERIFIED, M4 §6).
11. The foreman's response enters the durable return leg through Crier (`CT-06R`,
    UNVERIFIED).
12. Crier correlates the completion into the scheduler's durable inbox (`CT-06`,
    PROVEN; `internal/registry/handler.go:170,1452`); the scheduler records it and
    triggers subsequent processing.
13. The POST lane hook runs after outcome recording and cannot change that tick's
    result — the second half of the hook-phase gap, shown where it happens.
14. The end-of-lane sync reconciles the local and remote board copies; completion is
    evidence-bound.

**State and artifacts:** the envelope and reply in the durable inboxes; the worker
branch and commit; the guard and judge verdicts; the published change on main; board
row events; DuckBrain records; the recorded tick outcome.

**Refusal, failure and recovery:** settlement reads only `ok`
(`dispatch_leg.go:713-726`); a node reply carrying `status:"failed"` and no `ok` —
the field `node-bus-worker.py:1180` actually sends — is scored a success (CF-355,
M9 §2). An unacked message redelivers after lease expiry; an empty inbox list is not
a lost message (M10 §11). A failed POST step never changes the recorded outcome; its
failure must stay visible in Factory completion rather than being absorbed (M9 §3).

**Settings:** lane cadence, weight and pin (`CT-01`, `fleet.example.toml:15,35`);
admission mode; lane hook plan (PRE/POST steps and their fail-open/fail-closed
posture, `scripts/hooks/hooks.example.toml`); lease and reply deadlines.

**Metric owner:** the scheduler's tick/spawn/deferral counters at
`GET /api/v1/metrics` (M9 §8) cover settlement; no measured metric yet covers the
foreman return leg or the sync result — a named gap, not a satisfied requirement.

**Completion proof:** a recorded outcome correlated by run id, an accepted verdict,
integration/publication proof and reconciled board copies with the row closed
against retained evidence (`CT-13`/`CT-14` discipline, M4 §6). Transport completion
alone is not acceptance.

## 2.2 F2 — Provisioning

![FIGURE 2.2](figures/F2.svg)

**Trigger:** the operator declares a lane — project, harness, pin — and a bare host
must become a node.

**Actors and location:** the operator and the provisioner on the control host; the
bunker daemon and the resulting node inside the Bunker deployment/execution
boundary.

**Prerequisites:** the host meets the disk floor; the lane declaration exists; the
Bunker deployment profile (fresh image-backed or persistent container) is chosen for
this Bunker.

**Inputs:** the lane declaration (project, harness, pin); the node manifest (prompts,
skills, env); the seed repo and embedded board; Crier registration material; the
per-Bunker DuckBrain namespace credential.

**Steps:**

1. The operator declares the lane to the scheduler (M1 §3).
2. The provisioner drives the bunker daemon to create the container, the per-agent home
   and the keys (`scripts/bunker-provision.sh:504`, M1 §3 S2).
3. The provisioner layers the node: base, harness, bus, repo (M1 §3) — including the
   exact Hermes build, the tools and settings, and the embedded board.
4. The provisioner installs DuckBrain in the Bunker — every Bunker carries one, and it
   must expose the same logical memory view as the controller (resolved decision 2).
5. The node takes its identity and namespace credential (M1 §3).
6. The verifier measures the result — CREATED is not VERIFIED (M1 §12).

**State and artifacts:** the container and per-agent home; `node.json` and
`crier.json`; the seeded repo and board; the namespace credential; the verifier's
per-leg ladder record.

**Refusal, failure and recovery:** the certification ladder awards VERIFIED per leg —
agent, gateway, auth, artifact, tree, seed — and an unreachable port is UNVERIFIED
(exit 3), not FAIL (M1 §10, CF-224). The node's registration producer half is not
established; crier's `HandleRegister`/`HandleRegisterByID` are named, the wire is
UNVERIFIED (M1 §6). A partial failure re-runs from the manifest: the seed reapplies
and names drift per file (M1 §3 S4).

**Settings:** disk floor; container profile and per-Bunker Factory configuration with
setup/readback; harness pin; registry and namespace credentials.

**Metric owner:** none measured — the chapters name no provisioning counter; the
verifier's per-leg ladder is the record of record (M1 §11).

**Completion proof:** a verifier ladder with every leg VERIFIED and a readback of the
effective host/isolation/resource settings — install success alone is insufficient
(M1 §12, M1 §6).

## 2.3 F3 — Memory

![FIGURE 2.3](figures/F3.svg)

**Trigger:** a run ends and someone later needs to find it by project, week or lane.

**Actors and location:** the node and foreman inside their Bunkers, each writing
through its own DuckBrain instance; the operator recalling from the controller side.

**Prerequisites:** the DuckBrain namespace exists and is configured per project; the
writer holds the namespace credential (M1 §3).

**Inputs:** run records with run correlation (R1 detail, R2 fleet index); foreman
decisions, findings and goals (R3 rollup); recall queries by project, week and lane.

**Steps:**

1. The node writes an R1 detail record to DuckBrain (`CT-09`, MISSING — CF-329, M2 §6).
2. The node writes an R2 fleet index record (`CT-09`, MISSING).
3. The foreman writes an R3 weekly rollup through its Bunker's instance (`CT-15`,
   UNVERIFIED boundary, M9 §6).
4. The operator recalls by project, week and lane (M9 §6).

**State and artifacts:** namespaced append-only records with namespace-local Git
history; retrieved records are pointers requiring verification, not verified facts.

**Refusal, failure and recovery:** the designed path is broken at the first step —
`node-bus-worker.py` makes zero DuckBrain calls, so no R1 or R2 record exists to
recall (CF-329, M2 §6). A per-Bunker instance cut off from the controller view is a
shared-view consistency failure; the offline/reconnect behavior is unspecified and
remains an open requirement, not a handled case.

**Settings:** namespace selection (explicit per project — an omitted namespace falls
back to sticky active configuration); HTTP/MCP auth (`x-api-key`); sync cadence for
cron-side writers (M9 §5).

**Metric owner:** none measured — no recall-quality or sync-lag counter exists; the
gap is named in M9 §8.

**Completion proof:** a read-after-write check — the written record is retrievable
under the intended namespace with its run correlation intact; a working service alone
does not prove the structured run-record sync exists.

## 2.4 F4 — Documentation

![FIGURE 2.4](figures/F4.svg)

**Trigger:** a module needs an approved document and the foreman opens a skeleton.

**Actors and location:** the foreman on the control host; the doc gate, panel seats
and spine gate as build-time checks; the handbook builder rendering to the delivered
PDF.

**Prerequisites:** the module chapter exists in the build manifest; sources with
citable locators are available.

**Inputs:** the skeleton and source set; seat drafts; the cross-chapter set for spine
consistency.

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

**State and artifacts:** the chapter draft; gate refusal lists; the panel split
record; the built PDF with printed page, figure and table numbering.

**Refusal, failure and recovery:** the doc gate is structural, not a truth verifier —
it cannot tell whether a sentence is true (M6 §2). `CT-16` was downgraded from
PROVEN: the handbook build reads no MASTER-DOC output, so the receiver half is
uncited (M6 §6). A panel STOP exit is process success, not document acceptance
(M6 §5); a reviewer stopping on budget or no-progress proves nothing about the
document (M6 §6).

**Settings:** panel seat budget and model pins; the build manifest (`BOOK.yaml`);
print constraints (page size, fonts, the 2.05 mm label floor).

**Metric owner:** none measured — gate outcomes are per-run exit codes, not counters.

**Completion proof:** owner acceptance of the built artifact — staged, revisioned
output whose rendered pages passed structural, visual and fit checks; a zero-exit
checker alone is not acceptance.

## 2.5 F5 — Landing

![FIGURE 2.5](figures/F5.svg)

**Trigger:** a worker holds a commit on a node branch and the work must reach main.

**Actors and location:** the worker and foreman inside the Bunker; the commit gate
grading the commit; the foreman closing the row; the merged tree landing on the
control side.

**Prerequisites:** a worker branch commit exists; the pre-commit hook is installed in
the seeded repo; the row's acceptance criteria are gradable.

**Inputs:** the staged diff (`CT-12`); the gate verdict (`CT-13`); the branch and
commit ids; the evidence run id.

**Steps:**

1. The worker commits on a node branch; the commit gate grades the staged diff through
   the pre-commit hook (`CT-12`; `scripts/install-gitreins.sh:124`).
2. The gate's verdict returns to the foreman (`CT-13`).
3. The foreman merges the branch and proves the commit is an ancestor of origin/main
   (M3 §2); rerunning the gates on the merged tree belongs to the same owner (M3 §2).
4. The foreman closes the row with evidence (`CT-14`).

**State and artifacts:** the merged commit on main; the gate verdict records; the
board row closed with its evidence run id; the published tree.

**Refusal, failure and recovery:** the hook side is pinned, but that git invokes the
hook is unproven (M3 §6, M3 §11); where the gate is absent the pre-commit hook exits
0 — a silent bypass that must be disclosed (M3 §10). The verdict-to-close path was
not re-run; completion requires `--evidence-run-id` on `boardctl update` (M4 §6). A
best-effort refresh warning cannot silently establish publication proof (M3 §2).

**Settings:** GitReins pin and hook installation; gate policy — mandatory versus
optional checks, and the owner-waiver rule for judged-versus-Tier-1-only passes
(M3 §2).

**Metric owner:** none measured — no landing or gate-latency counter exists.

**Completion proof:** the commit is an ancestor of origin/main **and** the board row
is closed bound to the accepted verdict and retained evidence; either alone is
insufficient.

## 2.6 F6 — Maintenance

![FIGURE 2.6](figures/F6.svg)

**Trigger:** the provisioner or the safety reaper runs its maintenance pass against
disks, branches, caches and freshness.

**Actors and location:** the provisioner and safety reaper on the control host
against node hosts and job dirs; freshness probes against nodes and checkouts.

**Prerequisites:** the maintenance window/pass is scheduled; protected paths are
declared before inspection.

**Inputs:** TTL configuration for caches and job dirs; the live agent registry; the
protected-path list; gitleaks scan-scope claims.

**Steps:**

1. The provisioner's layer-00 pass runs `reclaim_disk`, which reaps build caches and
   job directories past the 24-hour TTL (M8 §3 S1).
2. The `node_hygiene` reap removes orphan homes and keys after a 60-minute grace
   (M1 §5).
3. `repo_freshness` measures how far a workdir lags origin (M3 §5).
4. The verifier's `node_freshness` measures branch, HEAD and lag on the node (M1 §11).
5. Safety refuses protected paths before inspection — the repo, `node.json`,
   `crier.json` (M8 §5).

**State and artifacts:** reaped directories with their measured freed bytes; the
freshness readings; refusal records for protected paths.

**Refusal, failure and recovery:** the TTL governs age, not citation; the reaper can
delete a directory a module cites as evidence (M8 §2). A gitleaks claim without its
`--log-opts` scope is refused (M8 §2). A refused protected path stops the pass for
that path; it does not abort the remaining targets.

**Settings:** cache and job TTLs; the hygiene grace period; the protected-path list;
the scan-scope requirement.

**Metric owner:** the reaper's own freed-byte accounting is measured per pass; no
fleet-level maintenance metric is served anywhere (M9 §8 gap).

**Completion proof:** the pass's own record — what was reaped, what was refused, and
the measured (not merely logical) freed bytes (M8 §2).

## 2.7 F7 — Monitoring

![FIGURE 2.7](figures/F7.svg)

**Trigger:** an operator or a cron asks whether the machine is unwell.

**Actors and location:** read-only HTTP surfaces on the scheduler, crier and proxy.

**Prerequisites:** the surfaces are running and reachable; the reader is authorized
where auth applies.

**Inputs:** HTTP reads — metrics and status endpoints; the proxy's usage JSONL.

**Steps:**

1. The scheduler serves `GET /api/v1/metrics` — spawns, deferrals, ticks, tick duration
   (M9 §8).
2. The scheduler serves `/api/v1/status` — per-project failure-rate breakdown (M9 §5).
3. Crier serves `/metrics`, default-ON — guard and inbox series (M10 §8).
4. The proxy appends a usage JSONL line per request — node, model, status, bytes
   (M12 §8).

**State and artifacts:** the served series and the appended JSONL; nothing in this
flow mutates the system.

**Refusal, failure and recovery:** the measured gap is coverage, not correctness — 11
of 13 modules emit no metrics, so most of the system is answerable only by grepping
logs (M9 §8, model note). A stats error that degrades queue counters to zero cannot
prove emptiness (M10 §6).

**Settings:** the metrics default-ON flags; scrape targets and cadence.

**Metric owner:** the scheduler, crier and proxy own their own series; the other ten
modules have no owner because they have no counter — the flow's named gap.

**Completion proof:** a read that returns attributable series with names, types and
collection meaning defined — not a port that happens to answer.

## 2.8 F8 — Recovery

![FIGURE 2.8](figures/F8.svg)

**Trigger:** a crash, a restart or an orphaned run leaves work in an unknown state.

**Actors and location:** the dispatcher and crier on their hosts; the scheduler on
the control host; the foreman against the board.

**Prerequisites:** the crash site is identified; no writer is mutating the affected
state.

**Inputs:** the replay ledger; crier's unacked inbox messages; the board lock state;
the session store's stale sessions.

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

**State and artifacts:** replayed results marked as replays; redelivered messages with
their lease state; reaped or retained sessions; the reconciled board.

**Refusal, failure and recovery:** the replay ledger only covers a task whose result
reached the ledger before the crash; a result lost with the process is re-run from
scratch (M11 §3 S2). The dispatcher's deadline kill terminates run.sh's process
group, not the harness's own group, so the kill-the-group guarantee is withdrawn
(M11 §2). Unknown-start reconciliation is a required behavior, not an implemented
one (M11 §2).

**Settings:** lease TTLs; reap dry-run/apply flags; replay-ledger retention.

**Metric owner:** redelivery counts exist in crier's inbox series (M10 §8); no
counter covers replay-ledger hits or orphaned runs.

**Completion proof:** the affected row and run are in a named state with a recorded
reason — never silently dropped; the proof is the reconciled board row plus the
replay/redelivery record.

## 2.9 F9 — Degradation

![FIGURE 2.9](figures/F9.svg)

**Trigger:** a dependency is gone and each component must choose a posture.

**Actors and location:** every component locally, at its own boundary.

**Prerequisites:** the dependency outage is detectable by the component itself.

**Inputs:** the failing dependency's error signal (gateway down, provider outage,
missing token file, absent gate).

**Steps:**

1. The gateway fails: the tick is deferred, not exec-spawned — `no-exec-fallback=true`
   (M9 §5).
2. The load gate defers new spawns while load is at or above the threshold (M9 §3).
3. The guard fails open on provider outage unless policy is FailClosed (M10 §10).
4. The proxy fails closed at startup: no token file or no upstream key exits 2
   (M12 §11).
5. The commit gate absent: the pre-commit hook exits 0 — a silent bypass that must be
   disclosed (M3 §10).

**State and artifacts:** deferred ticks with named reasons; guard quarantine state;
proxy startup refusals; undisclosed bypasses — which is the defect.

**Refusal, failure and recovery:** the postures disagree by design — the proxy fails
closed, the guard fails open, the hook silently passes. The only one of the three
that is fail-closed and measured is the proxy's startup check (M12 §11). Recovery is
the dependency's own recovery plus the next cadence tick; nothing re-queues the
degraded interval's work automatically.

**Settings:** `no-exec-fallback`; the guard's fail-open/FailClosed policy; the load
threshold; hook installation completeness.

**Metric owner:** deferral counters on the scheduler (M9 §8); guard posture is
visible in crier's `/metrics` (M10 §8); the silent hook bypass is invisible by
definition — the gap is the finding.

**Completion proof:** each degraded interval is attributable — a named reason on a
deferred tick or a disclosed posture — never an unexplained silence.

## 2.10 F10 — Teardown and rebuild

![FIGURE 2.10](figures/F10.svg)

**Trigger:** the operator removes a node or a lane and no residue may survive.

**Actors and location:** the operator and provisioner on the control host; the bunker
daemon on the affected host.

**Prerequisites:** destroy is operator-gated; the target agent is named; nothing
active holds the node's work.

**Inputs:** the agent name and `--yes`; the seed manifest for rebuild.

**Steps:**

1. `--destroy` requires `--yes` and a named agent (M1 §5).
2. The provisioner removes the container and the per-agent home on the server (M1 §5).
3. The orphan-home reap runs against a live-registry check (M1 §10).
4. A rebuild reapplies the seed from the manifest, naming drift per file (M1 §3 S4).

**State and artifacts:** the removed container and home; the registry's live check
record; the rebuilt node's seed-diff report.

**Refusal, failure and recovery:** destroy is operator-gated, not foreman-reachable —
the chapters name no autonomous destroy path (M1 §5). The reaper's grace is 60
minutes; a home reclaimed inside the grace window is refused (M1 §5). No chapter
measures residue left inside the container image itself; the teardown claim stops at
the home and container boundaries.

**Settings:** the destroy flags; the grace period; the seed manifest.

**Metric owner:** none measured — teardown has no counter; the refusal records are
the trace.

**Completion proof:** the registry no longer lists the agent, the home is gone, and a
rebuild's seed diff names every restored file — readback, not intention.

## 2.11 F11 — Scheduling admission

![FIGURE 2.11](figures/F11.svg)

**Trigger:** a lane's cadence tick fires, and the question is whether it is
admitted — and if not, why not, by name.

**Actors and location:** the scheduler on the control host, reading the board's local
copy with the remote copy refreshed first.

**Prerequisites:** the lane is enabled (`CT-01`); the repository and board copies were
refreshed before eligibility — the approved target — and the checked revision is
recorded.

**Inputs:** the resolved admission configuration (`CT-01`, UNVERIFIED); the board's
workability signal; usage-pool state; the tick cadence.

**Steps:**

1. The repo/board refresh precedes eligibility; the revision checked is recorded (see
   F1's gap note for where today's PRE hook actually runs).
2. The scheduler resolves the admission mode — project override, then namespace
   default, then cooldown (`admission_mode.go:98,112`, M9 §3).
3. Board ownership and workability decide the tasks waiver — WORK, NO-WORK and
   UNREADABLE are distinct outcomes; an unreadable board is never treated as no work
   (M9 §3).
4. Usage pools are reserved, or a capacity denial is emitted (M9 §3).
5. The board-stasis gate excludes an unchanged cooldown builder lane
   (`packer_select.go:474,614`, M9 §3).
6. NOOP-PACING spaces a no-artifact lane, doubling to 8 times the floor
   (`noop_pacing.go:74`, M9 §3).
7. Admitted — the envelope is dispatched (`CT-02`, PROVEN).

**State and artifacts:** the admission decision with its named reason; pool
reservations; the checked board revision; the admitted envelope.

**Refusal, failure and recovery:** refusal is always a named reason — budget hold,
cooldown, load gate, fairness, namespace allocation (M9 §3). The load gate defers
rather than drops (M9 §3). The admission configuration itself is `CT-01`, UNVERIFIED.

**Settings:** cadence, weight, pin and mode per lane (`fleet.example.toml:15,35`);
cooldown and stasis thresholds; pool sizes.

**Metric owner:** the scheduler's admission and deferral counters (M9 §8) are the
owner; the workability scan's three outcomes are not separately counted — named gap.

**Completion proof:** an admission or refusal record carrying its reason and the board
revision it was based on.

## 2.12 F12 — Credential lifecycle

![FIGURE 2.12](figures/F12.svg)

**Trigger:** a token is needed, or an existing one ages toward expiry.

**Actors and location:** the operator and the M7 minting scripts on the control host;
the scope minter dispatcher-side; the proxy checking node bearers at the Bunker
boundary.

**Prerequisites:** the GitHub App private key exists at 0600; the token file paths and
their consumers are configured.

**Inputs:** the App private key; installation id; the scope request for per-dispatch
tokens; the node bearer token file.

**Steps:**

1. The operator mints from an 0600 App private key — JWT, then installation token
   (M7 §5).
2. The token is written to a 0600 file; the value is never printed (M7 §7).
3. `refresh --node` installs `auth/github.token` on the node (M7 §5).
4. `fleet-gh-scope` mints the per-dispatch scoped token the dispatcher injects
   (M11 §3 S4, M11 §6).
5. The proxy checks the node bearer against the token file — fail-closed admission
   (M12 §6).

**State and artifacts:** 0600 token files at named paths; the per-dispatch scoped
token; the proxy's admission decision log.

**Refusal, failure and recovery:** the App mint was never run on the documenting host
— no App credentials exist there, so `CT-21` is UNVERIFIED end to end (M7 §6). The
node bearer half of `CT-19` is config-wired with no call site in this repo; the proxy
side is measured (401 without a token, M12 §6). An expired file is not detected by
age alone — validity needs expiry proof, distinct from explicit revocation (M7 §6).

**Settings:** key and token file paths and modes; refresh cadence; scope templates
per dispatch; node-token TTL.

**Metric owner:** none measured — no credential-age or refresh-failure counter
exists; the gap is named in M7 §6.

**Completion proof:** a readback of the installed credential's scope and expiry from
the consumer side — the file's existence and age are not validity.

## 2.13 F13 — Upgrade and migration

![FIGURE 2.13](figures/F13.svg)

**Trigger:** a pinned bump or a schema change must reach the running system.

**Actors and location:** the operator invoking installers and migrations; the
scheduler applying its schema stores; boardctl migrating row vocabulary.

**Prerequisites:** the new pin's artifact is published and digest-checked; the schema
migration set is versioned.

**Inputs:** pin manifests; migration scripts; the row-vocabulary mapping.

**Steps:**

1. The operator bumps a pin; the installer fetches a digest-checked artifact (M5 §5).
2. The installed version is read back against the pin, and drift is named (M5 §10).
3. The scheduler's migration stores apply schema change to the 30-table store (M9 §3).
4. `boardctl normalize-statuses` migrates the row vocabulary (M4 §4).

**State and artifacts:** the installed artifact with its digest; the migrated store;
the normalized board; drift reports per file.

**Refusal, failure and recovery:** version drift is detected by read-back and named
per file (M5 §10); the chapters name no automatic rollback. Schema migration is a
measured 30-table store (M9 §3); the row-vocabulary migration is a boardctl command
with no measured post-migration state (M4 §4).

**Settings:** the pin set per component; migration ordering; dry-run modes.

**Metric owner:** none measured — no upgrade-success or drift counter exists.

**Completion proof:** read-back against the pin at every upgraded component plus a
post-migration state check; installation output alone is not the proof.

## 2.14 F14 — Observability ingestion

![FIGURE 2.14](figures/F14.svg)

**Trigger:** a tick, a turn or a message happens, and must become a visible,
attributed line.

**Actors and location:** the node inside its Bunker writing turns; the scheduler and
proxy serving/appending on their hosts; the foreman writing memory through its
Bunker's DuckBrain.

**Prerequisites:** the emitters are enabled; the sinks (session store, JSONL files,
DuckBrain namespaces) exist.

**Inputs:** per-turn records; scheduler counters; proxy request records; foreman
decisions and findings.

**Steps:**

1. The node records every turn, model, tokens and cost (`CT-11`, boundary, M2 §6).
2. The scheduler serves tick and spawn counters at `/api/v1/metrics` (M9 §8).
3. The proxy appends usage and capture JSONL per request; capture loss is silent
   (M12 §11).
4. The foreman writes decisions, findings and goals to durable memory through its
   Bunker's DuckBrain (`CT-15`, UNVERIFIED boundary, M9 §6).
5. The scheduler syncs its DuckBrain namespace every 5 minutes (M9 §5).

**State and artifacts:** session rows; served metric series; usage/capture JSONL
lines; DuckBrain records.

**Refusal, failure and recovery:** capture loss at the proxy is silent — a missing
line cannot be distinguished from a missing request (M12 §11). The node-to-session-store
wire is a boundary both of whose ends are the Hermes runtime, out of scope (M2 §6).
This flow, like F7, inherits the 11-of-13 metric gap.

**Settings:** metric endpoint toggles; JSONL paths and retention; DuckBrain sync
cadence and namespaces.

**Metric owner:** the three emitters above own their own series; every other module
is a named gap (M9 §8).

**Completion proof:** an attributed line exists for the event at every enabled
emitter — verified by sampling the sink, not by trusting the emitter's exit code.

## 2.15 F15 — Backup and restore

![FIGURE 2.15](figures/F15.svg)

**Trigger:** an artifact must be restored and proven, not merely copied.

**Actors and location:** the operator running verification procedures; the scheduler's
boot check against its board store.

**Prerequisites:** a backup exists; a scratch environment is available for the
restore drill.

**Inputs:** the backup artifact; the known row/record to read back; the board's
origin/main copy.

**Steps:**

1. `board_drift` compares the checkout's board against origin/main row by row (M4 §7).
2. `--verify-board` checks board consistency at boot (M9 §5).
3. The operator restores into a scratch home and reads back a known row (M9 §5).

**State and artifacts:** the drift report row by row; the boot verification result;
the scratch-restore readback.

**Refusal, failure and recovery:** drift is named row by row, not as a bulk count
(M4 §7). The model defines three steps and the chapters measure none of them end to
end; this subsection is deliberately short rather than padded with unmeasured detail.

**Settings:** backup cadence and locations; the boot verification flag; scratch-home
provisioning.

**Metric owner:** none measured — no restore-drill counter or durability series
exists.

**Completion proof:** a known row read back from the restored copy, byte-identical
where the model requires it — a copied file is not a restored one.

## 2.16 F16 — Multi-node fan-out

![FIGURE 2.16](figures/F16.svg)

**Trigger:** one directive must reach several nodes, each with its own receipt.

**Actors and location:** the scheduler addressing envelopes; the dispatcher executing
inside each target's Bunker container; crier settling per dispatch.

**Prerequisites:** every target agent is registered and reachable; per-target
credentials exist.

**Inputs:** the directive text; the target registry; per-dispatch scoped tokens.

**Steps:**

1. The scheduler addresses the envelope to each target agent in the registry
   (M11 §3 S4).
2. `bunker exec` runs the harness inside each target container (M11 §3 S1).
3. The dispatcher delivers the reply before ack; a redelivery replays, never re-runs
   (M11 §3 S3).
4. Completion settles per dispatch through crier (`CT-06`, PROVEN).

**State and artifacts:** per-target envelopes and replies; the replay ledger's
per-target entries; per-dispatch settlement records.

**Refusal, failure and recovery:** the dispatcher's loop is serial — one long job
head-of-line-blocks later agents (M11 §11). The replay guarantee covers only results
that reached the ledger before the crash (M11 §3 S2). The deadline-kill defect of F8
applies per target (M11 §2).

**Settings:** target registry contents; per-target deadlines; ledger retention.

**Metric owner:** settlement counters per dispatch (M9 §8, `CT-06`); no fan-out
width or completion-ratio counter exists.

**Completion proof:** one settled receipt per target — a fleet-wide count is the
per-target receipts, each correlated by its own dispatch id, never an aggregate
assumption.
