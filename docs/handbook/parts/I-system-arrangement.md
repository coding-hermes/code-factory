# Part I — System arrangement

![System map](figures/system-map.svg)

The factory is 27 components on six layers, joined by 23 contracts (`CT-01`…`CT-23`,
Part IV) and exercised by 16 flows (Part II). A box on the map is a responsibility, not
a path; the path that implements a box lives in its `impl` note and may move without the
system changing. Solid lines are interfaces that work as documented, dashed lines are
broken and named, dotted lines are designed but not built.

The stack reads bottom-up: control decides, transport carries, execution does the work,
memory remembers, governance decides whether to believe the result, and evidence is what
a human finally reads. Five components sit in control, four in transport, six in
execution, three in memory, eight in governance, one in evidence. Six of the 27 — the
operator, the task-router, the gateway, the bunker daemon, DuckBrain and the session
store — sit outside the 13 module chapters (M0–M12) and are documented as boundary
peers; the remaining 21 each key to one module chapter in Part III.

## 1.1 Control plane — decides what should happen

### OPERATOR

- **Module:** none — the human boundary peer.
- **Owns:** intent, priorities, approval. Does not execute work.
- **Fed by:** `CT-18`, the approval artifact (UNVERIFIED).
- **Feeds:** `CT-01` — lane enabled, cadence, weight and pin, declared in
  `fleet.example.toml:15,35` and the scheduler.db project rows; the consumer is
  `admission_mode.go:112` `admissionModeForProject` (M9 §6). State: UNVERIFIED, a
  boundary contract.
- **Impl:** human.

### SCHEDULER

- **Module:** M9 (`docs/handbook/chapters/M9-scheduler.md`), the control plane's clock
  and admission authority.
- **Owns:** whose turn it is — lane admission, tasks-versus-cooldown, per-lane cadence,
  weight and pin, and settlement of every dispatch. Does not run work and does not know
  what a diff contains.
- **Fed by:** `CT-01` (lane configuration, UNVERIFIED), `CT-05` (the foreman's lane
  prompt text, UNVERIFIED), `CT-06` (completion events, PROVEN).
- **Feeds:** `CT-02` — the dispatch envelope; `internal/bus/dispatch.go:202,266`
  `BuildDispatch` renders run_id, corr_id, lane, board and text_b64 and signs before
  POST (M9 §6). State: PROVEN.
- **Impl:** `coding-hermes-scheduler` (Go; 57-flag entrypoint, 43 HTTP routes mounted at
  `internal/api/server.go:289-370`, a 30-table SQLite store — M9 §1, §3).

### FOREMAN (Hermes)

- **Module:** none of its own; its behaviour is seeded config consumed by the scheduler.
- **Owns:** turning a board row into a brief, verifying returned evidence, closing rows.
  Does not grade its own homework — a judge seat does.
- **Fed by:** nothing in the register names an inbound wire.
- **Feeds:** `CT-05` — the lane's prompt text and skills it may load; both ends are
  in-repo (`load_lane_config.py:31` → `spawn.go:1249` `buildForemanPrompt`), state
  UNVERIFIED because the disagreement was never measured (M9 §6). `CT-14` — row create,
  close and evidence via boardctl; the store is measured (357 rows, 520 events), the
  foreman write wire is not exercised (M4 §6). `CT-15` — decisions, findings and goals
  to DuckBrain, a boundary wire (M9 §6).
- **Impl:** `prompts/foreman.md`, `skills/code-factory-foreman`.

### GITHUB CREDENTIALS

- **Module:** M7 (`docs/handbook/chapters/M7-github.md`).
- **Owns:** minting, caching and refreshing GitHub App installation tokens; never a
  token in argv (M7 §2). Does not mint the per-dispatch scoped token or the node tokens
  (M7 §12).
- **Fed by:** nothing in the register names an inbound wire.
- **Feeds:** `CT-21` — an installation token installed at `auth/github.token`, mode
  0600. State: UNVERIFIED; the mint was never run on the documenting host (no App
  credentials), and the consumer is a credential file, not a function (M7 §6).
- **Impl:** `scripts/github-app-setup.sh`, `scripts/github-app-token.py`,
  `scripts/github-app-refresh.sh`.

### SCOPE MINTER

- **Module:** M11 (`docs/handbook/chapters/M11-dispatcher.md`).
- **Owns:** the per-dispatch scoped GitHub token the dispatcher injects (M11 §3 S4). A
  separate minter from M7's `github-app-token.py` (M7 §12).
- **Fed by / feeds:** no register row; the token travels dispatcher-side and is not a
  measured wire.
- **Impl:** `~/.hermes/scripts/fleet-gh-scope.py`.

## 1.2 Transport — carries the decision

### CRIER (bus)

- **Module:** M10 (`docs/handbook/chapters/M10-crier.md`).
- **Owns:** delivery with per-agent signature, leases, replies, idempotency (M10 §2).
  Does not decide, does not execute, holds no board admission (M4 §12 B04).
- **Fed by:** `CT-02` — the scheduler's signed envelope, accepted by
  `internal/registry/handler.go:990` `HandleDeliver` into the durable inbox, verbatim
  after the CF-354 fix (M10 §6). `CT-04` — the node's reply (PARTIAL). `CT-22` — agent
  registration; crier's `HandleRegister`/`HandleRegisterByID` are named, the node-side
  producer is not established (M1 §6).
- **Feeds:** `CT-03` — inbox message plus a 30-second lease, pulled by
  `scripts/node-bus-worker.py:1356,1383` with a signed GET and cleared by `/inbox/ack`
  (PROVEN). `CT-06` — the completion event; `internal/registry/handler.go:170,1452`
  carries ReplyTo correlation into the scheduler's durable inbox (PROVEN). `CT-08` —
  hermes-session delivery; `internal/hermesession/hermesession.go:353` `Client.Deliver`
  POSTs `/api/sessions` at the gateway origin (PROVEN).
- **Impl:** `crier` (Go).

### GUARD

- **Module:** M10; drawn in the governance layer because that is its function.
- **Owns:** the pipeline pattern pre-scan → payload render → LLM router verdict →
  escalation → sanitize quarantine on every delivered message (M10 §3 S2). A false pass
  lets an untrusted directive reach a node (M10 §2).
- **Fed by / feeds:** no register row — the guard sits inside crier's delivery path, not
  beside it. Its failure posture is measured: fail-open on provider outage unless policy
  is FailClosed (M10 §10).
- **Impl:** crier `internal/guard/guard.go`.

### TASK-ROUTER

- **Module:** none — boundary peer.
- **Owns:** which model answers a prompt; lane chains, caps, PAYG ordering. Does not
  carry work.
- **Fed by:** nothing in the register names an inbound wire.
- **Feeds:** `CT-07` — the model choice for a prompt, in-band. State: UNVERIFIED;
  neither side has an in-repo `file:function` and the wire was not measured (M12 §6).
- **Impl:** `task-router`.

### HERMES GATEWAY

- **Module:** none — boundary peer.
- **Owns:** the session API, `/api/status`, dashboard auth, session records. Does not
  schedule and does not store the ledger.
- **Fed by:** `CT-07` (model choice, UNVERIFIED), `CT-08` — the delivered message
  becomes a session row at `hermes gateway/platforms/api_server.py:1763` (PROVEN), and
  `CT-20` — forwarded inference with the control-host key (UNVERIFIED).
- **Feeds:** nothing in the register names an outbound wire.
- **Impl:** `hermes gateway`.

### INFERENCE PROXY

- **Module:** M12 (`docs/handbook/chapters/M12-inference-proxy.md`).
- **Owns:** the only holder of the provider credential; admits nodes by token, models by
  allowlist, streams or buffers (M12 §2). No anonymous paid path; a node never sees a
  provider key (M12 §2).
- **Fed by:** `CT-19` — chat completion with a node bearer token. The proxy half is
  measured (401 without a token); the node client half is config-wired with no call site
  in this repo (M12 §6).
- **Feeds:** `CT-20` — forwarded inference upstream, 300-second timeout. The upstream is
  a rumour with one side named, and healthy streams are unframed to completion (M12 §6).
  Fail-closed at startup: no token file or no upstream key exits 2 (M12 §11).
- **Impl:** `~/.hermes/scripts/cf-inference-proxy.py`.

## 1.3 Execution — does the work

### BUNKER DAEMON

- **Module:** none — boundary peer.
- **Owns:** hosting agent containers; create/exec/cp; per-agent home. Does not own
  credentials or config.
- **Fed by:** `CT-23` — create, exec, cp against the agent container, driven by
  `scripts/bunker-provision.sh:504` (M1 §6). The calls were measured across M1's
  batteries; the daemon's accept side has no in-repo `file:function` to cite, so the row
  is UNVERIFIED.
- **Impl:** `bunker`.

### NODE

- **Module:** M2 (`docs/handbook/chapters/M2-dispatch.md`), the node half of the bus.
- **Owns:** one project per node; repo clone, seeded prompts/skills, env, identity, bus
  worker (M2 §2). Does not decide what to work on.
- **Fed by:** `CT-03` — the leased inbox message (`node-bus-worker.py:1356,1383`); the
  dispatcher is the second consumer of the same contract (M2 §6, M11 §6). `CT-21` — the
  installation token file.
- **Feeds:** `CT-04` — the reply, shape `:1176-1192` (PARTIAL: the transport works, but
  the scheduler's `dispatchReplyVerdict` at `dispatch_leg.go:713-726` reads only `ok`,
  while the node sends `status:"failed"` with no `ok` at `node-bus-worker.py:1180` —
  CF-355, a failed run recorded as success). `CT-09` — DuckBrain records, MISSING:
  `node-bus-worker.py` makes zero DuckBrain calls (CF-329, M2 §6). `CT-10` — board row
  events, BROKEN: the node worker writes no board rows and no in-repo producer exists
  (M4 §6). `CT-11` — turns to the session store, a boundary wire (M2 §6). `CT-12` — the
  staged diff, via the pre-commit hook pinned at `scripts/install-gitreins.sh:124`
  (hook enforcement unproven, M3 §6). `CT-19` — inference through the proxy. `CT-22` —
  agent registration, producer half not established (M1 §6).
- **Impl:** `scripts/project-node.sh`, `scripts/node-bus-worker.py`.

### HARNESS

- **Module:** M5 (`docs/handbook/chapters/M5-harness.md`).
- **Owns:** the coding loop inside the node — hermes, codex, claude-code, opencode, pi,
  dsh — at pins (M5 §2). Does not write the board.
- **Fed by:** `CT-17` — the conformance battery's per-leg verdict (check, apply, smoke,
  vars, memory), UNVERIFIED: not run this round because it needs a live node, and vars
  and memory had no executor (CF-328, M5 §6).
- **Impl:** `scripts/harness/*`.

### DISPATCHER

- **Module:** M11 (`docs/handbook/chapters/M11-dispatcher.md`).
- **Owns:** running the work inside the agent's container via `bunker exec` — start
  detached, poll with short calls, kill on deadline — and keeping the replay ledger
  (M11 §2, 538 lines of Python). May not decide admission or what the work is (M11 §2).
- **Fed by:** the same `CT-03` inbox crier serves; the scope minter (`M11 §3 S4`) mints
  its per-dispatch token.
- **Feeds:** its completion reaches the scheduler through crier — it always sends `ok`,
  the field `dispatchReplyVerdict` reads (M11 §6, under `CT-06`).
- **Named defects:** the ledger replays a recorded result instead of re-running a
  redelivery (`dispatcher.py:470-475`) only for a task whose result reached the ledger
  before the crash (M11 §3 S2). The deadline kill terminates run.sh's process group, not
  the harness's own group, so the kill-the-group guarantee is withdrawn (M11 §2).
- **Impl:** `~/crier-fleet/dispatcher.py`.

### PROVISIONER

- **Module:** M1 (`docs/handbook/chapters/M1-provisioning.md`).
- **Owns:** qualifying the host against a disk floor, creating the container, minting
  identity, seeding prompts/skills/env, connecting the bus (M1 §2). Does not certify the
  result — the verifier does (M1 §12).
- **Fed by:** the operator's destroy/rebuild directives (M1 §5).
- **Feeds:** `CT-23` — create/exec/cp against the agent container (UNVERIFIED, see
  BUNKER DAEMON). The hygiene reap removes orphan homes and keys after a 60-minute
  grace (M1 §5); the seed reapplies from the manifest and names drift per file (M1 §3).
- **Impl:** `scripts/bunker-provision.sh`, `scripts/project-node.sh`,
  `scripts/node-create.sh`.

### LANDER

- **Module:** M3 (`docs/handbook/chapters/M3-repository.md`).
- **Owns:** merging a worker branch and proving the commit is an ancestor of origin/main
  (M3 §2). Operator-triggered — the envelope names branch and commit, it does not call
  the lander (M3 §2).
- **Fed by / feeds:** no register row; the landing act is a human or foreman action on
  the merged tree, not a bus wire.
- **Impl:** `scripts/land-node-branch.sh`.

## 1.4 Memory — remembers what happened

### BOARD

- **Module:** M4 (`docs/handbook/chapters/M4-board.md`).
- **Owns:** the append-only record of work and its state; the fleet's plan (M4 §2). Not
  a run log — rows are reused across attempts.
- **Fed by:** `CT-10` — node row events, BROKEN: no in-repo producer (M4 §6). `CT-13` —
  the verdict that closes a row; completion requires `--evidence-run-id` and the
  verdict-to-close path was not re-run (M4 §6). `CT-14` — foreman writes, UNVERIFIED
  (M4 §6).
- **Feeds:** nothing in the register names an outbound wire; `board_read` resolves the
  board from origin/main when the working copy drifts (M4 §3).
- **Impl:** `.coding-hermes/board/tasks.jsonl`, `scripts/boardctl`.

### DUCKBRAIN

- **Module:** none — boundary peer.
- **Owns:** namespaced durable memory; run records, findings, recall. Does not own the
  plan or the code.
- **Fed by:** `CT-09` — node run records, MISSING (CF-329, M2 §6). `CT-15` — foreman
  decisions and findings, UNVERIFIED boundary (M9 §6).
- **Feeds:** recall by project, week and lane (Part II, F3).
- **Impl:** `duckbrain`.

### SESSION STORE

- **Module:** none — boundary peer.
- **Owns:** every model turn, its model, tokens and cost. Not the plan, not the product.
- **Fed by:** `CT-11` — node turns, written via the gateway; both ends are the Hermes
  runtime and out of scope (M2 §6). The scheduler's `--reap-sessions` closes stale
  sessions, dry-run without `--apply` (M9 §5).
- **Impl:** `~/.hermes/state.db`.

## 1.5 Governance — decides whether to believe it

### COMMIT GATE (gitreins)

- **Module:** M3 (`docs/handbook/chapters/M3-repository.md`).
- **Owns:** pre-commit grading — secrets, lint, tests — and the verdict that lands work
  (M3 §2). Does not decide what to build.
- **Fed by:** `CT-12` — the staged diff; the hook side is pinned at
  `scripts/install-gitreins.sh:124` (`$VENV/bin/gitreins guard --quality-async`), but
  that git invokes the hook is unproven (M3 §6, M3 §11).
- **Feeds:** `CT-13` — the verdict that closes a row (UNVERIFIED, see BOARD). Where the
  gate is absent the pre-commit hook exits 0 — a silent bypass that must be disclosed
  (M3 §10).
- **Impl:** `gitreins`.

### DOC GATE

- **Module:** M6 (`docs/handbook/chapters/M6-documentation.md`).
- **Owns:** whether a document is citable — sections, locators, facts, earned VERIFIED.
  A structural gate, not a truth verifier; it cannot tell whether a sentence is true
  (M6 §2).
- **Fed by:** the foreman's skeleton and seat fills (Part II, F4).
- **Feeds:** `CT-16` — the module status word, printed by
  `scripts/master_doc_check.py:263` (`MASTER-DOC: PASS|FAIL`, exit 1 on FAIL).
  Downgraded from PROVEN: the handbook build reads no MASTER-DOC output, so the receiver
  half is uncited (M6 §6).
- **Impl:** `scripts/master_doc_check.py`.

### CONFORMANCE BATTERY

- **Module:** M5 (`docs/handbook/chapters/M5-harness.md`).
- **Owns:** whether a harness is supported, measured per leg on a real node (M5 §2).
  Does not install anything by itself.
- **Fed by / feeds:** `CT-17` — the per-leg verdict into the harness record (UNVERIFIED,
  see HARNESS).
- **Impl:** `tests/harness-conformance.sh`.

### NODE VERIFIER

- **Module:** M1 (`docs/handbook/chapters/M1-provisioning.md`).
- **Owns:** the certification ladder — agent, gateway, auth, artifact, tree, seed — with
  VERIFIED earned per leg (M1 §11). An unreachable port is UNVERIFIED (exit 3), not FAIL
  (M1 §10, CF-224).
- **Fed by / feeds:** no register row; verification is a procedure over the node, not a
  standing wire.
- **Impl:** `scripts/verify-node.sh`.

### SAFETY

- **Module:** M8 (`docs/handbook/chapters/M8-safety.md`).
- **Owns:** reaping build caches and expired job dirs; refusing a gitleaks claim without
  its `--log-opts` scope (M8 §2). The TTL governs age, not citation — it can delete a
  directory a module cites as evidence (M8 §2). Protected paths — the repo, `node.json`,
  `crier.json` — are refused before inspection (M8 §5).
- **Fed by / feeds:** no register row; the reaper runs against hosts and job dirs.
- **Impl:** `scripts/reclaim_disk.py`, `scripts/check_scan_scope.py`.

### DOC PANEL

- **Module:** M6 (`docs/handbook/chapters/M6-documentation.md`).
- **Owns:** three seats grading a module independently; splits are reported, never voted
  away (M6 §3 S4). A STOP exit is process success, not document acceptance (M6 §5).
- **Fed by / feeds:** no register row; the panel consumes drafts and returns findings.
- **Impl:** `scripts/panel_loop.py`, `scripts/master_doc_panel.py`.

### SPINE GATE

- **Module:** M6 (`docs/handbook/chapters/M6-documentation.md`).
- **Owns:** cross-chapter consistency — canonical CT ids cited, producer/consumer and
  state agreement, dangling references, count claims (M6 §3 S9). It checks locator
  presence, not that the cited line exists (M6 §3 S9).
- **Fed by / feeds:** no register row; the gate runs over the book set.
- **Impl:** `scripts/handbook_spine.py`.

## 1.6 Evidence — what a human reads

### HANDBOOK

- **Module:** M6 (`docs/handbook/chapters/M6-documentation.md`).
- **Owns:** the readable system description plus its own deficiency register. Not the
  source of truth — code beats this document wherever they disagree.
- **Fed by:** `CT-16` — the module status word (UNVERIFIED, see DOC GATE).
- **Feeds:** `CT-18` — the approval artifact to the operator. State: UNVERIFIED; the
  legacy renderer hardcodes `docs/master` and does not select the M*.md chapters
  (M6 §6).
- **Impl:** `scripts/gen_nasa_handbook.py`, `scripts/build_book.py`.

## 1.7 The contract surface, as a count

Of the 23 register rows, 4 are PROVEN (`CT-02`, `CT-03`, `CT-06`, `CT-08` — all of them
crier wires), 1 is PARTIAL (`CT-04`, the reply whose settlement reads only `ok`), 1 is
BROKEN (`CT-10`, the node-to-board wire with no producer), 1 is MISSING (`CT-09`, the
node-to-DuckBrain wire with zero call sites), and 16 are UNVERIFIED. The map's dashed
and dotted lines carry the other 19 rows; a reader who wants the closing command for any one
of them finds it in Part IV.
