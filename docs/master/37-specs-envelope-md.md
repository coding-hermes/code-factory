# 37. specs/ENVELOPE.md

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/specs/ENVELOPE.md` |
| Repository | `code-factory` |
| Revision | `3c4c639` (spec unchanged since — `git diff 3c4c639 -- specs/ENVELOPE.md` is empty) |
| Status | **VERIFIED — the comparison is complete: 23 of the 24 fields the spec defines disagree with at least one implementation** |

VERIFIED here means *this document's comparison* is finished and re-derivable — every field is read on both
sides with a resolving locator. It is **not** a claim that the spec is correct: the spec is the wrong side on
15 of the 24 fields, crier on 1, the scheduler on 19 (several fields have more than one wrong side; §2e
counts them). The finding is CF-216 ("the spec matches neither implementation"), and this page is its
field-level proof.

## 1. Purpose and why it matters

- What breaks if this module is absent: the control host and the node have no common wire contract —
  `ENVELOPE.md:3` "The one wire contract between the control host and a node."
- What breaks if it lies: a `brief.digest` mismatch is a refusal, not a warning (`ENVELOPE.md:26`); a
  reported digest that cannot be recomputed is unverified, and unverified is FAIL (`ENVELOPE.md:48-49`).
- What this module found: there is not *one* wire contract. There are three dialects that share a
  vocabulary and no field list — the spec's flat JSON object, crier's inbox body (`payload` + `sender` +
  `request_id` + `idempotency_key`), and the scheduler's payload object (`kind`, `lane`, `corr_id`,
  `scheduler_id`, `issued_at`, `board`, `workdir`, `reply_to`, `text_b64`, `limits`). The repository's own
  node script speaks a fourth (`text`, `brief`, `dispatch_id`, `gate`). No pair of them is equal.

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

The spec is prose and declares no dependency; the contract it describes cannot execute without these.

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| a crier relay at the node's declared URL | unversioned (wire shape versioned only by the spec's `env_version`, which nothing sends) | `node.json` `bus.base` / `crier.json` `url`, per the identity precedence at [scripts/node-bus-worker.py:50] | `bus_health` refusal: `GET /health` ≠ 200 → FAIL [scripts/node-bus-worker.py:1046] |
| bearer token **and** per-agent ed25519 key | — | `CRIER_AUTH_TOKEN` (or a 600-mode file) and `$HOME/.node/*.key` | `signing_key` refusal [scripts/node-bus-worker.py:1016] and `bus_bearer` refusal [scripts/node-bus-worker.py:1036] |

`specs/ENVELOPE.md` names no credential and no header. crier requires both on every agent-scoped read
[fact: FACT-03] — the envelope is not the authentication surface and the spec does not say so.

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `encoding/json` (both sides) | Go stdlib | the **member names are the contract**; `payload()` exists so the wire shape is deterministic and diffable (`/home/kara/sched-base-check/internal/bus/dispatch.go:170`) | a rename fails the build only where a test pins it — the sender's key set is pinned (`:183`), the correlator pins just the three keys it matches, and nothing pins the node's result shape (§3) |
| `base64` (both sides) | stdlib | the inbox entry carries `payload` as **base64 of the JSON object** (crier `Payload []byte`, `/home/kara/crier/internal/registry/types.go:110`), decoded by the node before parsing [scripts/node-bus-worker.py:1100] | a raw-JSON payload would be a parse refusal at the node (`payload` row, [scripts/node-bus-worker.py:1098]) |
| `hashlib` / `sha256` | Python stdlib | the only digest this repository computes is `sha256(text)` for `brief.digest` [scripts/node-bus-worker.py:823] | nothing else verifies a digest, so a change here is invisible to the control host |

### 2c. Service contracts (both sides must be named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| control host (scheduler) | → node inbox | HTTP `POST /agents/{id}/inbox`, bearer + `X-Agent-*` ed25519 headers (`X-Agent-Body-SHA256` optional) [scripts/node-bus-worker.py:16] | `{payload:{…}, sender, request_id, idempotency_key}` — the payload object is what the node calls the dispatch (`/home/kara/sched-base-check/internal/bus/dispatch.go:215`) | receiver: crier `Handler.deliverAuthenticated` (`/home/kara/crier/internal/registry/handler.go:1101`); sender: `bus.Client.Dispatch` (`/home/kara/sched-base-check/internal/bus/dispatch.go:304`) |
| node | → `reply_to` inbox | same endpoint, same headers | `{payload:{in_reply_to \| corr_id, ok, reply_b64 \| reply, error_b64}}` (`/home/kara/crier-fleet/dispatcher.py:501`) | receiver: scheduler `SlotPool.awaitDispatchReply` (`/home/kara/sched-base-check/internal/scheduler/dispatch_leg.go:324`) and `correlateDispatchReply` (`:402`) |

Readings, with revisions (read-only; no checkout was written):
`crier` = `/home/kara/crier` at `f2b051a2`; `sched` = `/home/kara/sched-base-check` at `d9282770`, an
ancestor of `origin/main` (`5d8f5e0f`). `internal/bus/dispatch.go` is byte-identical between the two
scheduler revisions; `internal/scheduler/dispatch_leg.go` is cited at the on-disk revision (`d9282770`),
where `correlateDispatchReply` sits at `:402` and is the same function that sits at `:668` on `origin/main`.
`node` = [scripts/node-bus-worker.py:921] in this repository; the live node script is
`/home/kara/crier-fleet/dispatcher.py`.

### 2d. Field-by-field comparison — the 24 fields the spec defines

Codes in the last column: **S** the spec must change, **C** crier must change, **D** the scheduler
dispatcher must change, **N** the node implementation must change.

| # | Field (spec type, required, meaning) | crier | scheduler | wrong |
|---|---|---|---|---|
| 1 | `env_version` int, req — envelope version | no member; the body decodes non-strictly so an unknown top-level key is discarded before storage (`/home/kara/crier/internal/registry/handler.go:1152`), and a body with no `payload` member is a 400 (`:1169`) — the spec's flat body never reaches an inbox | not sent; `payload()` starts at `kind` and never emits a version (`/home/kara/sched-base-check/internal/bus/dispatch.go:176`), and its shape test refuses unknown keys (`/home/kara/sched-base-check/internal/bus/dispatch_test.go:183`) | S D |
| 2 | `dispatch_id` uuid, req — the node's join key | no member; the relay mints its own `id` per accepted delivery (`/home/kara/crier/internal/registry/types.go:107`) and that is what the node sees [scripts/node-bus-worker.py:1098] | not sent; `corr_id` is reused as `request_id` and `idempotency_key` (`/home/kara/sched-base-check/internal/bus/dispatch.go:283`), so `dispatch.get("dispatch_id")` is `""` [scripts/node-bus-worker.py:780] | S D |
| 3 | `corr_id` string, req — the scheduler's join key | no such member; crier's passthrough is `request_id`, echoed to the sender (`/home/kara/crier/internal/registry/handler.go:96`) | sent as `payload.corr_id` (`/home/kara/sched-base-check/internal/bus/dispatch.go:179`) **and** as `request_id`/`idempotency_key` (`:283`) — meaning agrees with the spec, nesting does not | S |
| 4 | `issued_at` RFC3339, req — when the host dispatched | no member; crier stamps `created_at` itself on the stored entry (`/home/kara/crier/internal/registry/types.go:110`) | sent as `payload.issued_at`, RFC3339Nano (`/home/kara/sched-base-check/internal/bus/dispatch.go:181`) | S |
| 5 | `reply_to` string, req — **the inbox answers go to** | the member exists but means the opposite thing: "the Crier message id (or correlation id) this message answers… It is NEVER an address" (`/home/kara/crier/internal/registry/handler.go:170`) | sent as `payload.reply_to`, the bus identity the answer must be addressed to (`/home/kara/sched-base-check/internal/bus/dispatch.go:189`), honoured by the live node (`/home/kara/crier-fleet/dispatcher.py:159`) — the spec's meaning, at the scheduler's level | S C |
| 6 | `lane` string, req — whose work this is | no member; the payload is opaque to crier (`/home/kara/crier/internal/registry/handler.go:78`) | sent as `payload.lane` (`/home/kara/sched-base-check/internal/bus/dispatch.go:178`) | S |
| 7 | `text` string, **mandatory** — the instruction | no member; the guard scans the raw payload bytes, not named fields (`/home/kara/crier/internal/guard/guard.go:178`) | sends **`text_b64`**, not `text` (`/home/kara/sched-base-check/internal/bus/dispatch.go:202`) because the relay's `stringified_json` prematch refuses prose that quotes JSON (`/home/kara/crier/internal/guard/patterns.go:47`); the in-repo node reads `text` only and refuses the dispatch [scripts/node-bus-worker.py:810] | S D |
| 8 | `brief` {digest, bytes}, req — proves the node got the task | no member | no member; the only digest in the tree is `brief_digest` on a different seam (`/home/kara/sched-base-check/internal/execution/parent.go:119`, carried by `ForemanInvocation`, `/home/kara/sched-base-check/internal/execution/foreman.go:13`), and no control-host code recomputes a digest for a dispatch | S D |
| 9 | `route` {provider, model, harness}, req — who runs it | partial and misnamed: crier has `model`/`provider` **selection hints** (`/home/kara/crier/internal/registry/handler.go:161`), no `harness`, and the scheduler never sets them | not sent; harness choice lives on the node (`node.json` `harness.cmd`), not in the dispatch [scripts/node-bus-worker.py:55] | S D |
| 10 | `limits` {wall_s, max_artifacts}, req — budget | no member | `payload.limits.wall_s` only, and only when `WallS > 0` (`/home/kara/sched-base-check/internal/bus/dispatch.go:204`); `max_artifacts` is emitted by nothing, though the node honours `wall_s` [scripts/node-bus-worker.py:944] | S D |
| 11 | `gate` {cmd, expect_exit}, req — the acceptance gate | no member | never sent — no `"gate"` key exists in `internal/bus` or `internal/scheduler` (only the word "gate" in comments); the node implements the gate in full [scripts/node-bus-worker.py:905] | S D |
| 12 | `idempotency_key` string, req **by the prose** (`ENVELOPE.md:64`), absent from the spec's example (`ENVELOPE.md:9`) | member, and it dedupes: a second delivery of the same key answers with the first accept and stores nothing (`/home/kara/crier/internal/registry/handler.go:112`) | sent, equal to `corr_id` (`/home/kara/sched-base-check/internal/bus/dispatch.go:284`) | S |
| 13 | `env_version` (result) int, req | carried opaquely inside `payload`; no envelope member | never read — no `env_version` in any non-test scheduler source, so no version is checked on either leg | D |
| 14 | `dispatch_id` (result) uuid, req | carried opaquely | never read; the correlator matches `in_reply_to`, `corr_id`, or an echoed `task.corr_id` (`/home/kara/sched-base-check/internal/scheduler/dispatch_leg.go:402`) and never `dispatch_id` | D |
| 15 | `status` completed \| failed \| refused | carried opaquely | never read. Success is the boolean `ok`, and **absence of `ok` is a success** (`/home/kara/sched-base-check/internal/scheduler/dispatch_leg.go:442`). The in-repo node sends `status` and no `ok` [scripts/node-bus-worker.py:925], so a `failed` or `refused` result from it correlates on `corr_id` and is then read as success. The live dispatcher sends `ok` and `in_reply_to` (`/home/kara/crier-fleet/dispatcher.py:501`), so the live path is not bitten — the repository's own node is | D N |
| 16 | `host_identity` string, req — **the node's** hostname | carried opaquely | never read; no `host_identity` in any non-test scheduler source, so the dispatch row cannot record which node ran the work | D |
| 17 | `harness` {name, served_model}, req | carried opaquely | never read | S N D |
| 18 | `exit_codes` list, req — every exit | carried opaquely | never read | N D |
| 19 | `gate_exit` int, req | carried opaquely | never read; `gate_exit` is `null` when no gate was dispatched [scripts/node-bus-worker.py:929] and nothing distinguishes it from "gate passed" | D |
| 20 | `branch` `node/crier/<dispatch_id>`, req | carried opaquely | never read; the node reports the clone's *current* branch via `rev-parse --abbrev-ref HEAD` [scripts/node-bus-worker.py:930] — the branch is never created and never named per the spec | S N D |
| 21 | `commit` sha, req | carried opaquely | never read; the node's value is `rev-parse HEAD` and matches the spec's type exactly [scripts/node-bus-worker.py:931] | D |
| 22 | `artifacts` [{path, sha256, bytes}], req | carried opaquely | never read; the node emits a constant `[]` [scripts/node-bus-worker.py:932], so no artifact is ever listed or hashed | S N D |
| 23 | `wall_s` float, req | carried opaquely | never read; the node emits `round(seconds, 1)` [scripts/node-bus-worker.py:933], which matches the spec | D |
| 24 | `finished_at` RFC3339, req | carried opaquely | never read; the node emits UTC `%Y-%m-%dT%H:%M:%SZ` [scripts/node-bus-worker.py:934], which matches the spec | D |
| + | `kind: "work.dispatch"` — **not in the spec** | not a member; it rides inside the payload | emitted (`/home/kara/sched-base-check/internal/bus/dispatch.go:177`) and pinned closed by a test (`/home/kara/sched-base-check/internal/bus/dispatch_test.go:183`), while `ENVELOPE.md:58-59` says "any new field is added to this spec first" | S D |

### 2e. What the count means, per side

- **23 of 24** spec fields disagree with at least one implementation. The single exception is
  `idempotency_key` (row 12), where both implementations already agree with the spec's *prose* — and the
  spec's own example omits it.
- **crier disagrees with the spec on 12 of the 24**: the 11 dispatch rows, plus the `payload`-required rule
  that turns the spec's flat example into a 400. In 10 of those 11 there is no crier member at all
  (`env_version`, `dispatch_id`, `corr_id`, `issued_at`, `lane`, `text`, `brief`, `route`, `limits`,
  `gate`) — but that is the spec's placement problem, not crier's: crier transports an arbitrary `payload`
  object without an opinion and discards what sits beside it
  (`/home/kara/crier/internal/registry/handler.go:1152`). Crier is **wrong on one**: `reply_to`, where the
  same name means provenance instead of an address. It is blameless on the 12 result fields.
- **the scheduler disagrees on 19**: all 12 result fields, plus 7 dispatch fields (`env_version`,
  `dispatch_id`, `text`, `brief`, `route`, `limits.max_artifacts`, `gate`). It agrees on `corr_id`,
  `issued_at`, `reply_to`, `lane`, `idempotency_key` — with `corr_id`/`lane`/`reply_to`/`issued_at` nested
  under `payload` and `issued_at` source-correct.
- **the spec is the wrong side on 15**: 14 of them also disagree with an implementation; the fifteenth is
  its own self-contradiction over `idempotency_key`. Concretely: the flat example that crier answers 400
  (`/home/kara/crier/internal/registry/handler.go:1169`); `reply_to` defined as an address while crier's
  identically-named member is provenance; `text` with no encoding rule although the only sender that works
  against the live guard encodes it (`/home/kara/sched-base-check/internal/bus/dispatch.go:202`); and
  `brief`, `route.harness`, `route.served_model`, `limits.max_artifacts`, `gate`, `branch` naming and
  `artifacts` naming mechanisms that no code produces on either side.
- **the node disagrees with the spec on 5** (`harness.served_model`, `exit_codes` cardinality, `status` vs
  `ok`, `branch`, `artifacts`) and with the scheduler on one that matters most: the scheduler sends
  `text_b64`, the repository's node reads `text` [scripts/node-bus-worker.py:810], so **the in-repo node
  cannot execute a single dispatch the scheduler sends.** The live node script does
  (`/home/kara/crier-fleet/dispatcher.py:135`), which is why the fleet works and this repository's node
  script does not.
- The spec's reserved-name section is also wrong about the guard (`ENVELOPE.md:53-54`): the 403 body is
  `{"error":"GUARD_BLOCKED","guard":{…}}` with `matched_patterns` as an **array**
  (`/home/kara/crier/internal/registry/handler.go:424`, `/home/kara/crier/internal/guard/types.go:46`) —
  there is no `matched_pattern` member. And `control_keys` does not by itself reject a payload under the
  cap: the prematch only enriches the guard prompt and is merged into the evidence
  (`/home/kara/crier/internal/guard/guard.go:264`); the decision is the guard model's unless the payload is
  over `maxPayloadBytes` (`:198`). The refusals actually measured in this project were `stringified_json`,
  not `control_keys`: the scheduler's own comment names the pattern and the attempt count
  (`/home/kara/sched-base-check/internal/bus/dispatch.go:196`), and the refusals it produced are in the
  round-trip log (`/home/kara/code-factory-reports/crier-scheduler-roundtrip-2026-11-05.md:76`).

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| both readings exist at the cited revisions | `git -C /home/kara/crier log -1 --format=%h`; `git -C /home/kara/sched-base-check log -1 --format=%h` | `f2b051a2`, `d9282770` | 2026-11-05 | PASS |
| every locator on this page resolves | `python3 scripts/master_doc_check.py docs/master --only 37- --strict` | `MASTER-DOC: PASS` | 2026-11-05 | PASS |
| the scheduler's dispatch shape is pinned | `git -C /home/kara/sched-base-check show origin/main:internal/bus/dispatch_test.go` | a closed key set, `:183-195` | 2026-11-05 | PASS — it pins the scheduler's dialect and rejects the spec's |
| the correlator's accepted shapes are pinned | `sed -n 442,462p /home/kara/sched-base-check/internal/scheduler/dispatch_leg_test.go` | a table of `in_reply_to` / `corr_id` / `task` echoes | 2026-11-05 | PASS — `TestCorrelateDispatchReply_IdentityNotArrival` (`:449`) |
| the node's result shape is pinned against anything | `git -C /home/kara/sched-base-check grep -n exit_codes -- internal` | a test naming the spec's result fields | 2026-11-05 | FAIL — no scheduler test names `exit_codes` or `host_identity`; the correlator's table pins only the three keys it matches, so `status` and `ok` can diverge without a failing build (CF-133 AC3 still open) |
| the round trip runs | `CRIER_LIVE_URL=… go test ./internal/scheduler -run TestLiveTickDispatchLeg` in the scheduler repo | `→ completed` | 2026-11-05 (report §2) | PASS — the scheduler's dialect completes a tick (`/home/kara/code-factory-reports/crier-scheduler-roundtrip-2026-11-05.md:368`) |

There is no test in either implementation that compares the wire to `specs/ENVELOPE.md`. This page's
evidence is the readings above, which any reviewer re-runs with the commands in the table — never a commit
message [fact: FACT-10].

## 4. Metrics emitted

The spec defines none. What exists is Crier's guard counter, split by decision
(`/home/kara/crier/internal/registry/dispatch.go:325`, `:334`, `:341`) and the node's PASS/FAIL measurement
rows. Nothing counts dispatches, `brief.digest` mismatches, refused hand-outs, or correlation failures —
so "how often does the envelope lie" is unanswerable from metrics and answerable only by reading the
inboxes, which is what the round-trip report had to do.

## 5. Log lines it can generate

- `PASS  brief_digest — <label> sha256(text) … matches the brief (N bytes)` [scripts/node-bus-worker.py:837]
  and `FAIL  brief_digest — … the brief was altered in flight; refused, not run`
  [scripts/node-bus-worker.py:826] — only on the node, and only when a sender ever sends `brief`.
- `FAIL  brief — … carries no text — a dispatch without an instruction is a bug` [scripts/node-bus-worker.py:812]
  — the line a scheduler-shaped dispatch produces today, because the scheduler sends `text_b64`.
- `BUS WORKER: IDLE` [scripts/node-bus-worker.py:1092] / `BUS WORKER: READY` [scripts/node-bus-worker.py:671] — the liveness pair; the spec
  defines no liveness signal, which is why a node that is up but never dispatched looks identical to a node
  that is down.
- crier: `guard: check failed, delivering without guard metadata` (`/home/kara/crier/internal/registry/dispatch.go:316`)
  — the fail-open path the spec never mentions; and the 403 `GUARD_BLOCKED` body above.

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Dispatch missing `text` | The node refuses and posts a `status: refused` result [scripts/node-bus-worker.py:810] | A dispatch whose `text` is present but base64 (`text_b64`), which this node refuses with the *same* row — the two are indistinguishable in the log | None automatic; the two sides must agree on the key (CF-133/CF-139) |
| `brief.digest` mismatch | Refusal, not a warning [scripts/node-bus-worker.py:824] | A digest that was never sent: no sender sends one, so the check is dead code today (§2d row 8) | Send `brief`; then the refusal path becomes live |
| Reported digest cannot be recomputed | Nothing: the control host recomputes no digest (`ENVELOPE.md:47-49` describes an unimplemented rule) | — | Implement the recomputation; until then "unverified is FAIL" is prose only |
| A failed node result read as success | The node sends `status: failed` with no `ok`; the correlator matches on `corr_id` and `dispatchReplyVerdict` treats an absent `ok` as success (`/home/kara/sched-base-check/internal/scheduler/dispatch_leg.go:442`) | The live dispatcher, which sends `ok: false` and is read correctly (`/home/kara/crier-fleet/dispatcher.py:501`) | Send `ok` from every node, or teach the correlator `status` |
| JSON key matches a reserved pattern | `403 GUARD_BLOCKED` with `guard.matched_patterns` as an array (`/home/kara/crier/internal/registry/handler.go:424`) — not `matched_pattern=control_keys` | A `stringified_json` block, which is what was actually measured — named with its 82 refused attempts at (`/home/kara/sched-base-check/internal/bus/dispatch.go:196`), visible as `403 GUARD_BLOCKED` in (`/home/kara/code-factory-reports/crier-scheduler-roundtrip-2026-11-05.md:76`) | Rename to the approved vocabulary, or base64 the prose as the scheduler now does (`/home/kara/sched-base-check/internal/bus/dispatch.go:192`) |
| Crash between execution and result delivery | Redelivery; the node's seen-cache returns the recorded result instead of re-running (`/home/kara/crier-fleet/dispatcher.py:365`) | A genuine second attempt, which a fresh `idempotency_key` produces — and nothing on the wire distinguishes the two beyond that key | Return the previous result (implemented in the live dispatcher and in [scripts/node-bus-worker.py:803]) |
| Ack before the result is delivered | Not possible in either implementation: the node acks last and leaves the message unacked when the POST failed [scripts/node-bus-worker.py:1150] | — | The spec's rule (`ENVELOPE.md:66-67`) is the one rule both sides already honour |

## 7. Environment and settings it reads

The spec reads no environment. The implementations do:

| setting | source | requirement |
|---|---|---|
| agent, project, relay URL, clone path, harness | `crier.json` → `node.json` → argv, in that precedence [scripts/node-bus-worker.py:50] | all five resolve or the node refuses by name |
| ed25519 private key | `$HOME/.node/*.key`, PKCS#8 PEM, mode 600 [scripts/node-bus-worker.py:1016] | required; a fabricated key authenticates nothing |
| shared bearer | `CRIER_AUTH_TOKEN` or a 600-mode file [scripts/node-bus-worker.py:1036] | required even for a signed read |
| `CR_REQUIRE_AGENT_SIG` | crier server env, on by default [scripts/node-bus-worker.py:13] | the signature is not optional on a default server |
| `CR_GUARD_PATTERNS_EXTRA` | crier server env, JSON array of `{name, pattern, class}` (`/home/kara/crier/internal/guard/patterns.go:66`) | a duplicate name replaces a built-in — an operator can silently retire `control_keys` |

## 8. Evidence of record

- `specs/ENVELOPE.md` (67 lines) at revision `3c4c639`; unchanged in `70db164` (verified by diff).
- crier `/home/kara/crier` at `f2b051a2` — `internal/registry/handler.go`, `internal/registry/dispatch.go`,
  `internal/registry/types.go`, `internal/guard/patterns.go`, `internal/guard/guard.go`,
  `internal/guard/types.go`.
- scheduler `/home/kara/sched-base-check` at `d9282770` (ancestor of `origin/main` `5d8f5e0f`) —
  `internal/bus/dispatch.go`, `internal/bus/dispatch_test.go`, `internal/scheduler/dispatch_leg.go`,
  `internal/execution/parent.go`, `internal/execution/foreman.go`.
- node: [scripts/node-bus-worker.py:921] (result), [scripts/node-bus-worker.py:776] (refusal); live node
  `/home/kara/crier-fleet/dispatcher.py:135` and `:501`.
- Board: CF-133 "the running dispatcher speaks a result dialect the ENVELOPE spec does not define"
  [.coding-hermes/board/tasks.jsonl:108]; CF-139 "the scheduler dispatches an envelope with no
  instruction" [.coding-hermes/board/tasks.jsonl:114].
- Measured round trip, reply shapes and the five uncorrelated replies:
  `/home/kara/code-factory-reports/crier-scheduler-roundtrip-2026-11-05.md:258`.
- A second, competing brief contract in the same scheduler (`schema_version`, `brief_digest` over canonical
  JSON, invocation-id idempotency) at `/home/kara/sched-base-check/internal/execution/parent.go:98` — it is
  not on the bus, it is not the spec, and it should not be mistaken for either.
