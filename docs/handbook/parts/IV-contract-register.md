# Part IV — Contract register

Every interface that can change the behaviour or correctness of a run, named once.
`CT-nn` is the canonical id used by every chapter; a chapter that names one of these
interfaces must use this id, not one of its own.

A contract is **both-sided** only when the sender's guarantee and the receiver's
requirement are each backed by a `file:line` or a command that was run. Where the model
records only one side, the row is marked **RED** and carries the command that would
close it — a register that reads as complete while half its wires are one-sided is worse
than an honest gap.

| id | from → to | carries | mode | state |
|---|---|---|---|---|
| CT-01 | owner → scheduler | lane enabled, cadence, weight, pin | config | PROVEN |
| CT-02 | scheduler → crier | envelope: run_id, corr_id, lane, board_row, text_b64 | async, bearer + signature | BROKEN |
| CT-03 | crier → node | inbox message + lease | pull, 30 s lease | PROVEN |
| CT-04 | node → crier | reply: in_reply_to, corr_id, run_id, outcome | async, signed | BROKEN |
| CT-05 | foreman → scheduler | the lane's prompt text and skills it may load | seeded config | BROKEN |
| CT-06 | crier → scheduler | completion event for a finished run | async | MISSING |
| CT-07 | router → gateway | model choice for a prompt | in-band | PROVEN |
| CT-08 | crier → gateway | hermes-session delivery (message becomes a session turn) | sync, 30 s | PROVEN |
| CT-09 | node → duckbrain | R1 run record, R2 fleet index | http, x-api-key | MISSING |
| CT-10 | node → board | row event with run_id and outcome | append | BROKEN |
| CT-11 | node → sessionstore | every turn, model, tokens | writes via gateway | PROVEN |
| CT-12 | node → gitreins | staged diff | pre-commit hook | PROVEN |
| CT-13 | gitreins → board | verdict that closes a row | human/foreman action | BROKEN |
| CT-14 | foreman → board | row created, row closed, evidence | boardctl | PROVEN |
| CT-15 | foreman → duckbrain | decisions, findings, goal | mcp / http | PROVEN |
| CT-16 | docsgate → handbook | module status word | read at build | PROVEN |
| CT-17 | conformance → harness | per-leg verdict (check, apply, smoke, vars, memory) | executed | BROKEN |
| CT-18 | handbook → owner | the approval artifact | read | PROVEN |

## Contracts in detail

### CT-01 — owner → scheduler

- **Carries:** lane enabled, cadence, weight, pin
- **Mode:** config
- **State:** PROVEN
- **Sends because:** Intent, priorities, approval
- **Receives because:** Whose turn it is; lane admission (tasks vs cooldown); per-lane cadence, weight, pin
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `scheduler` accepts and rejects is not stated here.
- **To close:** quote the encode site in `owner` and the decode/validate site in `scheduler`, then replace both RED lines with those citations.

### CT-02 — scheduler → crier

- **Carries:** envelope: run_id, corr_id, lane, board_row, text_b64
- **Mode:** async, bearer + signature
- **State:** BROKEN
- **Sends because:** Whose turn it is; lane admission (tasks vs cooldown); per-lane cadence, weight, pin
- **Receives because:** Delivery with per-agent signature, leases, replies, idempotency
- **Measured defect:** crier rejects an unsigned or misnamed body; the scheduler sends text_b64
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `crier` accepts and rejects is not stated here.
- **To close:** quote the encode site in `scheduler` and the decode/validate site in `crier`, then replace both RED lines with those citations.

### CT-03 — crier → node

- **Carries:** inbox message + lease
- **Mode:** pull, 30 s lease
- **State:** PROVEN
- **Sends because:** Delivery with per-agent signature, leases, replies, idempotency
- **Receives because:** One project per node; repo clone, seeded prompts/skills, env, identity, bus worker
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `node` accepts and rejects is not stated here.
- **To close:** quote the encode site in `crier` and the decode/validate site in `node`, then replace both RED lines with those citations.

### CT-04 — node → crier

- **Carries:** reply: in_reply_to, corr_id, run_id, outcome
- **Mode:** async, signed
- **State:** BROKEN
- **Sends because:** One project per node; repo clone, seeded prompts/skills, env, identity, bus worker
- **Receives because:** Delivery with per-agent signature, leases, replies, idempotency
- **Measured defect:** audience is the header X-Crier-Audience, never a body field; sender is stored but not verified
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `crier` accepts and rejects is not stated here.
- **To close:** quote the encode site in `node` and the decode/validate site in `crier`, then replace both RED lines with those citations.

### CT-05 — foreman → scheduler

- **Carries:** the lane's prompt text and skills it may load
- **Mode:** seeded config
- **State:** BROKEN
- **Sends because:** Turns a board row into a brief; verifies returned evidence; closes rows
- **Receives because:** Whose turn it is; lane admission (tasks vs cooldown); per-lane cadence, weight, pin
- **Measured defect:** only 3 of 14 lanes match the shipped prompt; the live foreman prompt is 1,832 chars vs 3,390
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `scheduler` accepts and rejects is not stated here.
- **To close:** quote the encode site in `foreman` and the decode/validate site in `scheduler`, then replace both RED lines with those citations.

### CT-06 — crier → scheduler

- **Carries:** completion event for a finished run
- **Mode:** async
- **State:** MISSING
- **Sends because:** Delivery with per-agent signature, leases, replies, idempotency
- **Receives because:** Whose turn it is; lane admission (tasks vs cooldown); per-lane cadence, weight, pin
- **Measured defect:** CF-337 — nothing writes completions back
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `scheduler` accepts and rejects is not stated here.
- **To close:** quote the encode site in `crier` and the decode/validate site in `scheduler`, then replace both RED lines with those citations.

### CT-07 — router → gateway

- **Carries:** model choice for a prompt
- **Mode:** in-band
- **State:** PROVEN
- **Sends because:** Which model answers a prompt; lane chains, caps, PAYG ordering
- **Receives because:** Session API, /api/status, dashboard auth, session records
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `gateway` accepts and rejects is not stated here.
- **To close:** quote the encode site in `router` and the decode/validate site in `gateway`, then replace both RED lines with those citations.

### CT-08 — crier → gateway

- **Carries:** hermes-session delivery (message becomes a session turn)
- **Mode:** sync, 30 s
- **State:** PROVEN
- **Sends because:** Delivery with per-agent signature, leases, replies, idempotency
- **Receives because:** Session API, /api/status, dashboard auth, session records
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `gateway` accepts and rejects is not stated here.
- **To close:** quote the encode site in `crier` and the decode/validate site in `gateway`, then replace both RED lines with those citations.

### CT-09 — node → duckbrain

- **Carries:** R1 run record, R2 fleet index
- **Mode:** http, x-api-key
- **State:** MISSING
- **Sends because:** One project per node; repo clone, seeded prompts/skills, env, identity, bus worker
- **Receives because:** Namespaced durable memory; run records, findings, recall
- **Measured defect:** node-bus-worker has zero DuckBrain calls (CF-329)
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `duckbrain` accepts and rejects is not stated here.
- **To close:** quote the encode site in `node` and the decode/validate site in `duckbrain`, then replace both RED lines with those citations.

### CT-10 — node → board

- **Carries:** row event with run_id and outcome
- **Mode:** append
- **State:** BROKEN
- **Sends because:** One project per node; repo clone, seeded prompts/skills, env, identity, bus worker
- **Receives because:** Append-only record of work and its state; the fleet's plan
- **Measured defect:** no run_id exists; events do not name an attempt
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `board` accepts and rejects is not stated here.
- **To close:** quote the encode site in `node` and the decode/validate site in `board`, then replace both RED lines with those citations.

### CT-11 — node → sessionstore

- **Carries:** every turn, model, tokens
- **Mode:** writes via gateway
- **State:** PROVEN
- **Sends because:** One project per node; repo clone, seeded prompts/skills, env, identity, bus worker
- **Receives because:** Every model turn, its model, tokens and cost
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `sessionstore` accepts and rejects is not stated here.
- **To close:** quote the encode site in `node` and the decode/validate site in `sessionstore`, then replace both RED lines with those citations.

### CT-12 — node → gitreins

- **Carries:** staged diff
- **Mode:** pre-commit hook
- **State:** PROVEN
- **Sends because:** One project per node; repo clone, seeded prompts/skills, env, identity, bus worker
- **Receives because:** Pre-commit grading (secrets, lint, tests) and the verdict that lands work
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `gitreins` accepts and rejects is not stated here.
- **To close:** quote the encode site in `node` and the decode/validate site in `gitreins`, then replace both RED lines with those citations.

### CT-13 — gitreins → board

- **Carries:** verdict that closes a row
- **Mode:** human/foreman action
- **State:** BROKEN
- **Sends because:** Pre-commit grading (secrets, lint, tests) and the verdict that lands work
- **Receives because:** Append-only record of work and its state; the fleet's plan
- **Measured defect:** verdicts cite commits; boardctl takes an exclusive flock on .lock, and no verdict closes a row
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `board` accepts and rejects is not stated here.
- **To close:** quote the encode site in `gitreins` and the decode/validate site in `board`, then replace both RED lines with those citations.

### CT-14 — foreman → board

- **Carries:** row created, row closed, evidence
- **Mode:** boardctl
- **State:** PROVEN
- **Sends because:** Turns a board row into a brief; verifies returned evidence; closes rows
- **Receives because:** Append-only record of work and its state; the fleet's plan
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `board` accepts and rejects is not stated here.
- **To close:** quote the encode site in `foreman` and the decode/validate site in `board`, then replace both RED lines with those citations.

### CT-15 — foreman → duckbrain

- **Carries:** decisions, findings, goal
- **Mode:** mcp / http
- **State:** PROVEN
- **Sends because:** Turns a board row into a brief; verifies returned evidence; closes rows
- **Receives because:** Namespaced durable memory; run records, findings, recall
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `duckbrain` accepts and rejects is not stated here.
- **To close:** quote the encode site in `foreman` and the decode/validate site in `duckbrain`, then replace both RED lines with those citations.

### CT-16 — docsgate → handbook

- **Carries:** module status word
- **Mode:** read at build
- **State:** PROVEN
- **Sends because:** Whether a document is citable (sections, locators, facts, earned VERIFIED)
- **Receives because:** The readable system description plus its own deficiency register
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `handbook` accepts and rejects is not stated here.
- **To close:** quote the encode site in `docsgate` and the decode/validate site in `handbook`, then replace both RED lines with those citations.

### CT-17 — conformance → harness

- **Carries:** per-leg verdict (check, apply, smoke, vars, memory)
- **Mode:** executed
- **State:** BROKEN
- **Sends because:** Whether a harness is supported, measured per leg on a real node
- **Receives because:** The coding loop inside the node (hermes, codex, claude-code, opencode, pi, dsh)
- **Measured defect:** vars and memory have no executor (CF-328)
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `harness` accepts and rejects is not stated here.
- **To close:** quote the encode site in `conformance` and the decode/validate site in `harness`, then replace both RED lines with those citations.

### CT-18 — handbook → owner

- **Carries:** the approval artifact
- **Mode:** read
- **State:** PROVEN
- **Sends because:** The readable system description plus its own deficiency register
- **Receives because:** Intent, priorities, approval
- **Sender guarantee:** RED — no `file:line` in the model states what this side commits to.
- **Receiver requirement:** RED — what `owner` accepts and rejects is not stated here.
- **To close:** quote the encode site in `handbook` and the decode/validate site in `owner`, then replace both RED lines with those citations.

