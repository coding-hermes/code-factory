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
> Treat such a row as UNVERIFIED until both sides carry citations. The generator
> enforces this: a PROVEN state with an uncited side prints as UNVERIFIED.

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
| CT-16 | docsgate → handbook | module status word | read at build | UNVERIFIED |
| CT-17 | conformance → harness | per-leg verdict (check, apply, smoke, vars, memory) | executed | UNVERIFIED |
| CT-18 | handbook → owner | the approval artifact | read | UNVERIFIED |
| CT-19 | node → proxy | chat completion with a node bearer token | http, bearer node token | UNVERIFIED |
| CT-20 | proxy → gateway | forwarded inference with the control-host key | http, 300 s timeout | UNVERIFIED |
| CT-21 | github → node | installation token installed at auth/github.token, mode 0600 | https api, JWT mint | UNVERIFIED |
| CT-22 | node → crier | agent registration + token exchange | https, POST /agents | UNVERIFIED |
| CT-23 | provisioner → bunker | create, exec, cp against the agent container | bunker CLI | UNVERIFIED |

## Contracts in detail

### CT-01 — owner → scheduler

- **Carries:** lane enabled, cadence, weight, pin
- **Mode:** config
- **State:** UNVERIFIED
- **Sends because:** Intent, priorities, approval
- **Receives because:** Whose turn it is; lane admission (tasks vs cooldown); per-lane cadence, weight, pin; settlement of every dispatch
- **Measured defect:** boundary — the producer is a human writing fleet.toml and scheduler.db project rows; the consumer is admission_mode.go:112 admissionModeForProject (M9 §6)
- **Sender guarantee:** the owner declares it — fleet.example.toml:15,35 (per-lane weight, enabled); project admission rows in scheduler.db are the source of record
- **Receiver requirement:** internal/scheduler/admission_mode.go:112 — admissionModeForProject resolves the project row (override → namespace default → cooldown)

### CT-02 — scheduler → crier

- **Carries:** envelope: run_id, corr_id, lane, board, text_b64
- **Mode:** async, bearer + signature
- **State:** PROVEN
- **Sends because:** Whose turn it is; lane admission (tasks vs cooldown); per-lane cadence, weight, pin; settlement of every dispatch
- **Receives because:** Delivery with per-agent signature, leases, replies, idempotency (M10 §2)
- **Measured defect:** CF-354 fixed — crier HandleDeliver delivers the envelope verbatim (M9 §6, M10 §6)
- **Sender guarantee:** internal/bus/dispatch.go:202,266 — BuildDispatch renders run_id/corr_id/lane/board/text_b64 and signs before POST
- **Receiver requirement:** crier internal/registry/handler.go:990 — HandleDeliver accepts the by-id delivery into the durable inbox

### CT-03 — crier → node

- **Carries:** inbox message + lease
- **Mode:** pull, 30 s lease
- **State:** PROVEN
- **Sends because:** Delivery with per-agent signature, leases, replies, idempotency (M10 §2)
- **Receives because:** One project per node; repo clone, seeded prompts/skills, env, identity, bus worker (M2 §2)
- **Measured defect:** the node worker (M2 §6) and the dispatcher (M11 §6) are the two consumers
- **Sender guarantee:** crier internal/registry/handler.go:990 — deliver(): durable inbox write with lease/ack/TTL semantics
- **Receiver requirement:** scripts/node-bus-worker.py:1356,1383 — signed GET /agents/<id>/inbox retrieve, then /inbox/ack

### CT-04 — node → crier

- **Carries:** reply: status, dispatch_id, corr_id, branch, commit, artifacts
- **Mode:** async, signed
- **State:** PARTIAL
- **Sends because:** One project per node; repo clone, seeded prompts/skills, env, identity, bus worker (M2 §2)
- **Receives because:** Delivery with per-agent signature, leases, replies, idempotency (M10 §2)
- **Measured defect:** transport works; settlement reads only `ok` — CF-355 open (M2 §6, M9 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what `node` commits to.
- **Receiver requirement:** RED — what `crier` accepts and rejects is not stated here.
- **To close:** quote the encode site in `node` and the decode/validate site in `crier`, then replace the RED line with those citations.

### CT-05 — foreman → scheduler

- **Carries:** the lane's prompt text and skills it may load
- **Mode:** seeded config
- **State:** UNVERIFIED
- **Sends because:** Turns a board row into a brief; verifies returned evidence; closes rows
- **Receives because:** Whose turn it is; lane admission (tasks vs cooldown); per-lane cadence, weight, pin; settlement of every dispatch
- **Measured defect:** both ends in-repo (load_lane_config.py:31 → spawn.go:1249 buildForemanPrompt); the "3 of 14 lanes disagree" breakage was never measured (M9 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what `foreman` commits to.
- **Receiver requirement:** RED — what `scheduler` accepts and rejects is not stated here.
- **To close:** quote the encode site in `foreman` and the decode/validate site in `scheduler`, then replace the RED line with those citations.

### CT-06 — crier → scheduler

- **Carries:** completion event for a finished run
- **Mode:** async
- **State:** PROVEN
- **Sends because:** Delivery with per-agent signature, leases, replies, idempotency (M10 §2)
- **Receives because:** Whose turn it is; lane admission (tasks vs cooldown); per-lane cadence, weight, pin; settlement of every dispatch
- **Measured defect:** the dispatcher leg works — it always sends `ok`, the field dispatchReplyVerdict reads (M11 §6)
- **Sender guarantee:** crier internal/registry/handler.go:170,1452 — the answering message carries ReplyTo correlation into the scheduler's durable inbox
- **Receiver requirement:** internal/scheduler/dispatch_leg.go:713 — dispatchReplyVerdict reads the correlated payload's ok (first message wins, :428)

### CT-07 — router → gateway

- **Carries:** model choice for a prompt
- **Mode:** in-band
- **State:** UNVERIFIED
- **Sends because:** Which model answers a prompt; lane chains, caps, PAYG ordering
- **Receives because:** Session API, /api/status, dashboard auth, session records
- **Measured defect:** boundary — neither side has an in-repo file:function; the wire was not measured (M12 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what `router` commits to.
- **Receiver requirement:** RED — what `gateway` accepts and rejects is not stated here.
- **To close:** quote the encode site in `router` and the decode/validate site in `gateway`, then replace the RED line with those citations.

### CT-08 — crier → gateway

- **Carries:** hermes-session delivery (message becomes a session turn)
- **Mode:** sync, 30 s
- **State:** PROVEN
- **Sends because:** Delivery with per-agent signature, leases, replies, idempotency (M10 §2)
- **Receives because:** Session API, /api/status, dashboard auth, session records
- **Measured defect:** crier side named — hermesession.go:353 Client.Deliver (M10 §6)
- **Sender guarantee:** crier internal/hermesession/hermesession.go:353 — Client.Deliver; :554 POSTs /api/sessions at the gateway origin
- **Receiver requirement:** hermes gateway/platforms/api_server.py:1763 — POST /api/sessions creates the session row from the delivered message

### CT-09 — node → duckbrain

- **Carries:** R1 run record, R2 fleet index
- **Mode:** http, x-api-key
- **State:** MISSING
- **Sends because:** One project per node; repo clone, seeded prompts/skills, env, identity, bus worker (M2 §2)
- **Receives because:** Namespaced durable memory; run records, findings, recall
- **Measured defect:** node-bus-worker has zero DuckBrain calls (CF-329, M2 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what `node` commits to.
- **Receiver requirement:** RED — what `duckbrain` accepts and rejects is not stated here.
- **To close:** quote the encode site in `node` and the decode/validate site in `duckbrain`, then replace the RED line with those citations.

### CT-10 — node → board

- **Carries:** row event with run_id and outcome
- **Mode:** append
- **State:** BROKEN
- **Sends because:** One project per node; repo clone, seeded prompts/skills, env, identity, bus worker (M2 §2)
- **Receives because:** Append-only record of work and its state; the fleet's plan (M4 §2)
- **Measured defect:** the node worker writes no board rows — no in-repo producer (M4 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what `node` commits to.
- **Receiver requirement:** RED — what `board` accepts and rejects is not stated here.
- **To close:** quote the encode site in `node` and the decode/validate site in `board`, then replace the RED line with those citations.

### CT-11 — node → sessionstore

- **Carries:** every turn, model, tokens
- **Mode:** writes via gateway
- **State:** UNVERIFIED
- **Sends because:** One project per node; repo clone, seeded prompts/skills, env, identity, bus worker (M2 §2)
- **Receives because:** Every model turn, its model, tokens and cost
- **Measured defect:** boundary — both ends are the Hermes runtime, out of scope (M2 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what `node` commits to.
- **Receiver requirement:** RED — what `sessionstore` accepts and rejects is not stated here.
- **To close:** quote the encode site in `node` and the decode/validate site in `sessionstore`, then replace the RED line with those citations.

### CT-12 — node → gitreins

- **Carries:** staged diff
- **Mode:** pre-commit hook
- **State:** UNVERIFIED
- **Sends because:** One project per node; repo clone, seeded prompts/skills, env, identity, bus worker (M2 §2)
- **Receives because:** Pre-commit grading (secrets, lint, tests) and the verdict that lands work (M3 §2)
- **Measured defect:** the hook side is named (install-gitreins.sh:124); hook enforcement — that git invokes it — is unproven (M3 §6, M3 §11)
- **Sender guarantee:** scripts/install-gitreins.sh:124 — the pre-commit hook pins $VENV/bin/gitreins guard --quality-async on every seeded repo
- **Receiver requirement:** RED — what `gitreins` accepts and rejects is not stated here.
- **To close:** quote the encode site in `node` and the decode/validate site in `gitreins`, then replace the RED line with those citations.

### CT-13 — gitreins → board

- **Carries:** verdict that closes a row
- **Mode:** human/foreman action
- **State:** UNVERIFIED
- **Sends because:** Pre-commit grading (secrets, lint, tests) and the verdict that lands work (M3 §2)
- **Receives because:** Append-only record of work and its state; the fleet's plan (M4 §2)
- **Measured defect:** completion requires --evidence-run-id (boardctl update); the verdict→close path was not re-run (M4 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what `gitreins` commits to.
- **Receiver requirement:** RED — what `board` accepts and rejects is not stated here.
- **To close:** quote the encode site in `gitreins` and the decode/validate site in `board`, then replace the RED line with those citations.

### CT-14 — foreman → board

- **Carries:** row created, row closed, evidence
- **Mode:** boardctl
- **State:** UNVERIFIED
- **Sends because:** Turns a board row into a brief; verifies returned evidence; closes rows
- **Receives because:** Append-only record of work and its state; the fleet's plan (M4 §2)
- **Measured defect:** the store is measured (357 rows / 520 events); the foreman write wire is not exercised in this repo (M4 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what `foreman` commits to.
- **Receiver requirement:** RED — what `board` accepts and rejects is not stated here.
- **To close:** quote the encode site in `foreman` and the decode/validate site in `board`, then replace the RED line with those citations.

### CT-15 — foreman → duckbrain

- **Carries:** decisions, findings, goal
- **Mode:** mcp / http
- **State:** UNVERIFIED
- **Sends because:** Turns a board row into a brief; verifies returned evidence; closes rows
- **Receives because:** Namespaced durable memory; run records, findings, recall
- **Measured defect:** boundary — the foreman lane and the duckbrain service are out of scope (M9 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what `foreman` commits to.
- **Receiver requirement:** RED — what `duckbrain` accepts and rejects is not stated here.
- **To close:** quote the encode site in `foreman` and the decode/validate site in `duckbrain`, then replace the RED line with those citations.

### CT-16 — docsgate → handbook

- **Carries:** module status word
- **Mode:** read at build
- **State:** UNVERIFIED
- **Sends because:** Whether a document is citable (sections, locators, facts, earned VERIFIED) — a structural gate, not a truth verifier (M6 §2 F6-2)
- **Receives because:** The readable system description plus its own deficiency register
- **Measured defect:** a structural gate, not a truth gate (M6 §6 F6-2); downgraded from PROVEN — the handbook build reads no MASTER-DOC output, so the receiver half is uncited
- **Sender guarantee:** scripts/master_doc_check.py:263 — prints MASTER-DOC: PASS|FAIL and exits 1 on FAIL
- **Receiver requirement:** RED — what `handbook` accepts and rejects is not stated here.
- **To close:** quote the encode site in `docsgate` and the decode/validate site in `handbook`, then replace the RED line with those citations.

### CT-17 — conformance → harness

- **Carries:** per-leg verdict (check, apply, smoke, vars, memory)
- **Mode:** executed
- **State:** UNVERIFIED
- **Sends because:** Whether a harness is supported, measured per leg on a real node (M5 §2)
- **Receives because:** The coding loop inside the node (hermes, codex, claude-code, opencode, pi, dsh) at pins (M5 §2)
- **Measured defect:** not run this round (needs a live node); vars and memory had no executor (CF-328) (M5 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what `conformance` commits to.
- **Receiver requirement:** RED — what `harness` accepts and rejects is not stated here.
- **To close:** quote the encode site in `conformance` and the decode/validate site in `harness`, then replace the RED line with those citations.

### CT-18 — handbook → owner

- **Carries:** the approval artifact
- **Mode:** read
- **State:** UNVERIFIED
- **Sends because:** The readable system description plus its own deficiency register
- **Receives because:** Intent, priorities, approval
- **Measured defect:** the legacy renderer hardcodes docs/master and does not select the M*.md chapters (M6 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what `handbook` commits to.
- **Receiver requirement:** RED — what `owner` accepts and rejects is not stated here.
- **To close:** quote the encode site in `handbook` and the decode/validate site in `owner`, then replace the RED line with those citations.

### CT-19 — node → proxy

- **Carries:** chat completion with a node bearer token
- **Mode:** http, bearer node token
- **State:** UNVERIFIED
- **Sends because:** One project per node; repo clone, seeded prompts/skills, env, identity, bus worker (M2 §2)
- **Receives because:** The only holder of the provider credential; admits nodes by token, models by allowlist, streams or buffers (M12 §2)
- **Measured defect:** proxy side verified (401 without a token); the node client half is config-wired, no call site in this repo (M12 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what `node` commits to.
- **Receiver requirement:** RED — what `proxy` accepts and rejects is not stated here.
- **To close:** quote the encode site in `node` and the decode/validate site in `proxy`, then replace the RED line with those citations.

### CT-20 — proxy → gateway

- **Carries:** forwarded inference with the control-host key
- **Mode:** http, 300 s timeout
- **State:** UNVERIFIED
- **Sends because:** The only holder of the provider credential; admits nodes by token, models by allowlist, streams or buffers (M12 §2)
- **Receives because:** Session API, /api/status, dashboard auth, session records
- **Measured defect:** external boundary — the upstream is a rumour with one side named; healthy streams are unframed to completion, F12-7 (M12 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what `proxy` commits to.
- **Receiver requirement:** RED — what `gateway` accepts and rejects is not stated here.
- **To close:** quote the encode site in `proxy` and the decode/validate site in `gateway`, then replace the RED line with those citations.

### CT-21 — github → node

- **Carries:** installation token installed at auth/github.token, mode 0600
- **Mode:** https api, JWT mint
- **State:** UNVERIFIED
- **Sends because:** Mints, caches and refreshes GitHub App installation tokens; never a token in argv (M7 §2)
- **Receives because:** One project per node; repo clone, seeded prompts/skills, env, identity, bus worker (M2 §2)
- **Measured defect:** the mint was never run on this host (no App creds); the consumer is the node's credential file, not a function (M7 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what `github` commits to.
- **Receiver requirement:** RED — what `node` accepts and rejects is not stated here.
- **To close:** quote the encode site in `github` and the decode/validate site in `node`, then replace the RED line with those citations.

### CT-22 — node → crier

- **Carries:** agent registration + token exchange
- **Mode:** https, POST /agents
- **State:** UNVERIFIED
- **Sends because:** One project per node; repo clone, seeded prompts/skills, env, identity, bus worker (M2 §2)
- **Receives because:** Delivery with per-agent signature, leases, replies, idempotency (M10 §2)
- **Measured defect:** the in-repo producer half is not established; crier HandleRegister/HandleRegisterByID named (M1 §6)
- **Sender guarantee:** RED — no `file:line` in the model states what `node` commits to.
- **Receiver requirement:** RED — what `crier` accepts and rejects is not stated here.
- **To close:** quote the encode site in `node` and the decode/validate site in `crier`, then replace the RED line with those citations.

### CT-23 — provisioner → bunker

- **Carries:** create, exec, cp against the agent container
- **Mode:** bunker CLI
- **State:** UNVERIFIED
- **Sends because:** Qualifies the host (disk floor), creates the container, mints identity, seeds prompts/skills/env, connects the bus (M1 §2)
- **Receives because:** Hosts agent containers; create/exec/cp; per-agent home
- **Measured defect:** short create/exec/cp calls measured across M1's batteries (M1 §6); downgraded from PROVEN — the daemon's accept side has no in-repo file:function to cite
- **Sender guarantee:** scripts/bunker-provision.sh:504 — the node-create.sh stage drives create/exec/cp against the agent container
- **Receiver requirement:** RED — what `bunker` accepts and rejects is not stated here.
- **To close:** quote the encode site in `provisioner` and the decode/validate site in `bunker`, then replace the RED line with those citations.

