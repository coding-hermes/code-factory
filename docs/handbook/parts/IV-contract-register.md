# Part IV — Contract register

Every interface that can change the behaviour or correctness of a run, named once.
`CT-nn` is the canonical id used by every chapter; a chapter that names one of these
interfaces must use this id, not one of its own.

A contract is **both-sided** only when the sender's guarantee and the receiver's
requirement are each backed by a `file:line` or a command that was run. Where the model
records only one side, the row is marked **RED** and carries the command that would
close it — a register that reads as complete while half its wires are one-sided is worse
than an honest gap.

> CAUTION: a row whose State reads PROVEN while its sender guarantee or receiver
> requirement reads RED is self-contradictory — one side is measured, the other is not.
> Treat such a row as UNVERIFIED until both sides carry citations.

| id | from → to | carries | mode | state |
|---|---|---|---|---|
| CT-01 | owner → scheduler | lane enabled, cadence, weight, pin | config | UNVERIFIED |
| CT-02 | scheduler → crier | envelope: run_id, corr_id, lane, board, text_b64 | async, bearer + signature | PROVEN |
| CT-03 | crier → node | inbox message + lease | pull, 30 s lease | PROVEN |
| CT-04 | node → crier | reply: status, dispatch_id, corr_id, branch, commit, artifacts | async, signed | PARTIAL |
| CT-05 | foreman → scheduler | the lane's prompt text and skills it may load | seeded config | UNVERIFIED |
| CT-06 | crier → scheduler | completion event for a finished run | async | PROVEN |
| CT-07 | router → gateway | model choice for a prompt | in-band | UNVERIFIED |
| CT-08 | crier → gateway | hermes-session delivery (message becomes a session turn) | sync, 30 s | PROVEN |
| CT-09 | node → duckbrain | R1 run record, R2 fleet index | http, x-api-key | MISSING |
| CT-10 | node → board | row event with run_id and outcome | append | BROKEN |
| CT-11 | node → sessionstore | every turn, model, tokens | writes via gateway | UNVERIFIED |
| CT-12 | node → gitreins | staged diff | pre-commit hook | UNVERIFIED |
| CT-13 | gitreins → board | verdict that closes a row | human/foreman action | UNVERIFIED |
| CT-14 | foreman → board | row created, row closed, evidence | boardctl | UNVERIFIED |
| CT-15 | foreman → duckbrain | decisions, findings, goal | mcp / http | UNVERIFIED |
| CT-16 | docsgate → handbook | module status word | read at build | PROVEN |
| CT-17 | conformance → harness | per-leg verdict (check, apply, smoke, vars, memory) | executed | UNVERIFIED |
| CT-18 | handbook → owner | the approval artifact | read | UNVERIFIED |
| CT-19 | node → proxy | chat completion with a node bearer token | http, bearer node token | UNVERIFIED |
| CT-20 | proxy → gateway | forwarded inference with the control-host key | http, 300 s timeout | UNVERIFIED |
| CT-21 | github → node | installation token installed at auth/github.token, mode 0600 | https api, JWT mint | UNVERIFIED |
| CT-22 | node → crier | agent registration + token exchange | https, POST /agents | UNVERIFIED |
| CT-23 | provisioner → bunker | create, exec, cp against the agent container | bunker CLI | PROVEN |

## Contracts in detail

### CT-01 — owner → scheduler

- **Carries:** lane enabled, cadence, weight, pin
- **Mode:** config
- **State:** UNVERIFIED
- **Sends because:** Intent, priorities, approval
- **Receives because:** Whose turn it is; lane admission (tasks vs cooldown); per-lane cadence, weight, pin; settlement of every dispatch
- **Measured defect:** boundary — the producer is a human writing fleet.toml and scheduler.db project rows; the consumer is admission_mode.go:112 admissionModeForProject (M9 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `scheduler` accepts and rejects is not stated here.

### CT-02 — scheduler → crier

- **Carries:** envelope: run_id, corr_id, lane, board, text_b64
- **Mode:** async, bearer + signature
- **State:** PROVEN
- **Sends because:** Whose turn it is; lane admission (tasks vs cooldown); per-lane cadence, weight, pin; settlement of every dispatch
- **Receives because:** Delivery with per-agent signature, leases, replies, idempotency (M10 §2)
- **Measured defect:** CF-354 fixed — crier HandleDeliver delivers the envelope verbatim (M9 §6, M10 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `crier` accepts and rejects is not stated here.

### CT-03 — crier → node

- **Carries:** inbox message + lease
- **Mode:** pull, 30 s lease
- **State:** PROVEN
- **Sends because:** Delivery with per-agent signature, leases, replies, idempotency (M10 §2)
- **Receives because:** One project per node; repo clone, seeded prompts/skills, env, identity, bus worker (M2 §2)
- **Measured defect:** the node worker (M2 §6) and the dispatcher (M11 §6) are the two consumers
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `node` accepts and rejects is not stated here.

### CT-04 — node → crier

- **Carries:** reply: status, dispatch_id, corr_id, branch, commit, artifacts
- **Mode:** async, signed
- **State:** PARTIAL
- **Sends because:** One project per node; repo clone, seeded prompts/skills, env, identity, bus worker (M2 §2)
- **Receives because:** Delivery with per-agent signature, leases, replies, idempotency (M10 §2)
- **Measured defect:** transport works; settlement reads only `ok` — CF-355 open (M2 §6, M9 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `crier` accepts and rejects is not stated here.

### CT-05 — foreman → scheduler

- **Carries:** the lane's prompt text and skills it may load
- **Mode:** seeded config
- **State:** UNVERIFIED
- **Sends because:** Turns a board row into a brief; verifies returned evidence; closes rows
- **Receives because:** Whose turn it is; lane admission (tasks vs cooldown); per-lane cadence, weight, pin; settlement of every dispatch
- **Measured defect:** both ends in-repo (load_lane_config.py:31 → spawn.go:1249 buildForemanPrompt); the "3 of 14 lanes disagree" breakage was never measured (M9 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `scheduler` accepts and rejects is not stated here.

### CT-06 — crier → scheduler

- **Carries:** completion event for a finished run
- **Mode:** async
- **State:** PROVEN
- **Sends because:** Delivery with per-agent signature, leases, replies, idempotency (M10 §2)
- **Receives because:** Whose turn it is; lane admission (tasks vs cooldown); per-lane cadence, weight, pin; settlement of every dispatch
- **Measured defect:** the dispatcher leg works — it always sends `ok`, the field dispatchReplyVerdict reads (M11 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `scheduler` accepts and rejects is not stated here.

### CT-07 — router → gateway

- **Carries:** model choice for a prompt
- **Mode:** in-band
- **State:** UNVERIFIED
- **Sends because:** Which model answers a prompt; lane chains, caps, PAYG ordering
- **Receives because:** Session API, /api/status, dashboard auth, session records
- **Measured defect:** boundary — neither side has an in-repo file:function; the wire was not measured (M12 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `gateway` accepts and rejects is not stated here.

### CT-08 — crier → gateway

- **Carries:** hermes-session delivery (message becomes a session turn)
- **Mode:** sync, 30 s
- **State:** PROVEN
- **Sends because:** Delivery with per-agent signature, leases, replies, idempotency (M10 §2)
- **Receives because:** Session API, /api/status, dashboard auth, session records
- **Measured defect:** crier side named — hermesession.go:353 Client.Deliver (M10 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `gateway` accepts and rejects is not stated here.

### CT-09 — node → duckbrain

- **Carries:** R1 run record, R2 fleet index
- **Mode:** http, x-api-key
- **State:** MISSING
- **Sends because:** One project per node; repo clone, seeded prompts/skills, env, identity, bus worker (M2 §2)
- **Receives because:** Namespaced durable memory; run records, findings, recall
- **Measured defect:** node-bus-worker has zero DuckBrain calls (CF-329, M2 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `duckbrain` accepts and rejects is not stated here.

### CT-10 — node → board

- **Carries:** row event with run_id and outcome
- **Mode:** append
- **State:** BROKEN
- **Sends because:** One project per node; repo clone, seeded prompts/skills, env, identity, bus worker (M2 §2)
- **Receives because:** Append-only record of work and its state; the fleet's plan (M4 §2)
- **Measured defect:** the node worker writes no board rows — no in-repo producer (M4 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `board` accepts and rejects is not stated here.

### CT-11 — node → sessionstore

- **Carries:** every turn, model, tokens
- **Mode:** writes via gateway
- **State:** UNVERIFIED
- **Sends because:** One project per node; repo clone, seeded prompts/skills, env, identity, bus worker (M2 §2)
- **Receives because:** Every model turn, its model, tokens and cost
- **Measured defect:** boundary — both ends are the Hermes runtime, out of scope (M2 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `sessionstore` accepts and rejects is not stated here.

### CT-12 — node → gitreins

- **Carries:** staged diff
- **Mode:** pre-commit hook
- **State:** UNVERIFIED
- **Sends because:** One project per node; repo clone, seeded prompts/skills, env, identity, bus worker (M2 §2)
- **Receives because:** Pre-commit grading (secrets, lint, tests) and the verdict that lands work (M3 §2)
- **Measured defect:** the hook side is named (install-gitreins.sh:124); hook enforcement — that git invokes it — is unproven (M3 §6, M3 §11)
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `gitreins` accepts and rejects is not stated here.

### CT-13 — gitreins → board

- **Carries:** verdict that closes a row
- **Mode:** human/foreman action
- **State:** UNVERIFIED
- **Sends because:** Pre-commit grading (secrets, lint, tests) and the verdict that lands work (M3 §2)
- **Receives because:** Append-only record of work and its state; the fleet's plan (M4 §2)
- **Measured defect:** completion requires --evidence-run-id (boardctl update); the verdict→close path was not re-run (M4 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `board` accepts and rejects is not stated here.

### CT-14 — foreman → board

- **Carries:** row created, row closed, evidence
- **Mode:** boardctl
- **State:** UNVERIFIED
- **Sends because:** Turns a board row into a brief; verifies returned evidence; closes rows
- **Receives because:** Append-only record of work and its state; the fleet's plan (M4 §2)
- **Measured defect:** the store is measured (357 rows / 520 events); the foreman write wire is not exercised in this repo (M4 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `board` accepts and rejects is not stated here.

### CT-15 — foreman → duckbrain

- **Carries:** decisions, findings, goal
- **Mode:** mcp / http
- **State:** UNVERIFIED
- **Sends because:** Turns a board row into a brief; verifies returned evidence; closes rows
- **Receives because:** Namespaced durable memory; run records, findings, recall
- **Measured defect:** boundary — the foreman lane and the duckbrain service are out of scope (M9 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `duckbrain` accepts and rejects is not stated here.

### CT-16 — docsgate → handbook

- **Carries:** module status word
- **Mode:** read at build
- **State:** PROVEN
- **Sends because:** Whether a document is citable (sections, locators, facts, earned VERIFIED) — a structural gate, not a truth verifier (M6 §2 F6-2)
- **Receives because:** The readable system description plus its own deficiency register
- **Measured defect:** a structural gate, not a truth gate (M6 §6 F6-2)
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `handbook` accepts and rejects is not stated here.

### CT-17 — conformance → harness

- **Carries:** per-leg verdict (check, apply, smoke, vars, memory)
- **Mode:** executed
- **State:** UNVERIFIED
- **Sends because:** Whether a harness is supported, measured per leg on a real node (M5 §2)
- **Receives because:** The coding loop inside the node (hermes, codex, claude-code, opencode, pi, dsh) at pins (M5 §2)
- **Measured defect:** not run (needs a live node); vars and memory had no executor (CF-328) (M5 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `harness` accepts and rejects is not stated here.

### CT-18 — handbook → owner

- **Carries:** the approval artifact
- **Mode:** read
- **State:** UNVERIFIED
- **Sends because:** The readable system description plus its own deficiency register
- **Receives because:** Intent, priorities, approval
- **Measured defect:** the legacy renderer hardcodes docs/master and does not select the M*.md chapters (M6 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `owner` accepts and rejects is not stated here.

### CT-19 — node → proxy

- **Carries:** chat completion with a node bearer token
- **Mode:** http, bearer node token
- **State:** UNVERIFIED
- **Sends because:** One project per node; repo clone, seeded prompts/skills, env, identity, bus worker (M2 §2)
- **Receives because:** The only holder of the provider credential; admits nodes by token, models by allowlist, streams or buffers (M12 §2)
- **Measured defect:** proxy side verified (401 without a token); the node client half is config-wired, no call site in this repo (M12 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `proxy` accepts and rejects is not stated here.

### CT-20 — proxy → gateway

- **Carries:** forwarded inference with the control-host key
- **Mode:** http, 300 s timeout
- **State:** UNVERIFIED
- **Sends because:** The only holder of the provider credential; admits nodes by token, models by allowlist, streams or buffers (M12 §2)
- **Receives because:** Session API, /api/status, dashboard auth, session records
- **Measured defect:** external boundary — the upstream is a rumour with one side named; healthy streams are unframed to completion, F12-7 (M12 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `gateway` accepts and rejects is not stated here.

### CT-21 — github → node

- **Carries:** installation token installed at auth/github.token, mode 0600
- **Mode:** https api, JWT mint
- **State:** UNVERIFIED
- **Sends because:** Mints, caches and refreshes GitHub App installation tokens; never a token in argv (M7 §2)
- **Receives because:** One project per node; repo clone, seeded prompts/skills, env, identity, bus worker (M2 §2)
- **Measured defect:** the mint was never run on this host (no App creds); the consumer is the node's credential file, not a function (M7 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `node` accepts and rejects is not stated here.

### CT-22 — node → crier

- **Carries:** agent registration + token exchange
- **Mode:** https, POST /agents
- **State:** UNVERIFIED
- **Sends because:** One project per node; repo clone, seeded prompts/skills, env, identity, bus worker (M2 §2)
- **Receives because:** Delivery with per-agent signature, leases, replies, idempotency (M10 §2)
- **Measured defect:** the in-repo producer half is not established; crier HandleRegister/HandleRegisterByID named (M1 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `crier` accepts and rejects is not stated here.

### CT-23 — provisioner → bunker

- **Carries:** create, exec, cp against the agent container
- **Mode:** bunker CLI
- **State:** PROVEN
- **Sends because:** Qualifies the host (disk floor), creates the container, mints identity, seeds prompts/skills/env, connects the bus (M1 §2)
- **Receives because:** Hosts agent containers; create/exec/cp; per-agent home
- **Measured defect:** short create/exec/cp calls measured across M1's batteries (M1 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `bunker` accepts and rejects is not stated here.

