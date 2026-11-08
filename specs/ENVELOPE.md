# SPEC — dispatch and result envelope

The one wire contract between the control host and a node. Versioned, small, and hostile to
ambiguity.

## Dispatch (control host → node inbox)

```json
{
  "env_version": 1,
  "dispatch_id": "uuid",
  "corr_id": "lane-<ts>-<seq>",
  "issued_at": "2026-10-29T18:40:00Z",
  "reply_to": "mdp-collector",
  "lane": "crier",
  "text_b64": "<base64 of the UTF-8 directive — e.g. You are the foreman for lane crier. …>",
  "brief": {"digest": "<cf-brief-v1: sha256 over the canonical object of text, gate, repo, ref, workdir, vars>", "bytes": 4211},
  "route": {"provider": "xkiro", "model": "openai/gpt-6.1-sol", "harness": "hermes"},
  "vars": {"CF_MODEL": "openai/gpt-6.1-sol", "CF_PROVIDER": "xkiro",
           "CF_API_KEY_FILE": "/home/node/.node/keys/xkiro.key",
           "CF_WORKDIR": "/home/node/crier", "CF_NAMESPACE": "crier", "CF_RUN_ID": "lane-<ts>-<seq>",
           "CF_LANE": "crier", "CF_MAX_TURNS": 40},
  "limits": {"wall_s": 3600, "max_artifacts": 50},
  "gate": {"cmd": "go test ./...", "expect_exit": 0}
}
```

**The instruction is mandatory, and `text_b64` is how it travels.** A dispatch must carry an
instruction — `text_b64` (base64 of the UTF-8 directive) or, for older senders, one of the plain
members below. A dispatch with neither is a bug: the receiving side has no instruction and will
either invent one or run the JSON as a prompt.

The encoding exists because the reply relay's control-key guard (see *Reserved field names*)
refuses prose that would otherwise be re-injected, and a real directive routinely quotes JSON
bodies and board rows. So the directive goes on the wire base64-encoded, and the guard sees opaque
text. The decoding rule is therefore part of the contract, not an implementation detail:

- A receiver **MUST** decode `text_b64` first, to UTF-8, and **MUST NOT** consult another member
  while `text_b64` is present.
- A `text_b64` that does not decode — bad base64, bytes that are not UTF-8, or a decoded body that
  is empty or whitespace — is a **named refusal** (`text_b64`), never a silent fallback. Falling
  back would run a different instruction than the one that was sent, and hide a corrupted dispatch.
- Only when `text_b64` is **absent** does the receiver fall back to the plain members, in this
  order: `task`, `text`, `prompt`, `message`, `body` (first non-empty string wins). Plain `text` is
  the historical member; the others are tolerated for older senders.
- `brief.digest` is the node's only in-flight integrity check, so it covers **every member that can
  change what the node executes**, not just the prose it reads: the decoded directive text, `gate`,
  `repo`, `ref`, `workdir` and `vars`. The digest is `sha256` over the **cf-brief-v1 canonical
  object**, serialized as canonical JSON — keys sorted, `,`/`:` separators, no insignificant
  whitespace, UTF-8 with non-ASCII **not** `\u`-escaped — and then hashed:

```json
{"gate": {"cmd": "<gate.cmd>", "expect_exit": 0, "timeout_s": null},
 "ref": "<ref-or-null>", "repo": "<repo-or-null>", "scheme": "cf-brief-v1",
 "text": "<decoded directive text>", "vars": {"<CF_NAME>": "<value>"},
 "workdir": "<workdir-or-null>"}
```

- `gate` is `null` when the dispatch carries no gate, and `vars` is `null` when it carries no §5
  set. Equivalent spellings hash the same, so a sender never fails over a formality: member order is
  irrelevant, and a `gate` with no `expect_exit` hashes exactly like `expect_exit: 0` (the value the
  node compares against anyway), and a falsy `timeout_s` hashes like `null` (the node falls back to
  the wall limit either way). `scripts/node-bus-worker.py` implements this as `brief_digest()`,
  and a sender gets the value it must send without importing that file:

```
python3 scripts/node-bus-worker.py --print-brief-digest dispatch.json    # '-' or no value: stdin
```

  which prints one lowercase hex line, or exits 2 naming why the dispatch has no digestable
  instruction.

- **The legacy text-only digest is refused when a gate is present.** A `brief.digest` equal to
  `sha256` of the directive text alone — the pre-CF-275 definition — binds the prose and nothing
  else, so it would let a brief whose `gate.cmd` was rewritten in flight verify and then run. It is
  still accepted on a brief that carries **no** gate: nothing outside the text executes, so the
  digest is complete for that purpose. A brief that carries a `gate` with **no** digest at all is
  refused too — an unbound executable is never run. Both refusals keep the named `brief_digest` row
  (results are posted, the message is acked) and the detail text names the scheme. What the digest
  does **not** cover: `dispatch_id`, `corr_id`, `issued_at`, `reply_to`, `lane`, `route`, `limits`
  and `brief.bytes` — none of them changes an executed command, and `brief.bytes` is a length hint,
  not an authorization. A mismatch is a refusal, not a warning.

**`vars` carries the harness variable contract** (`specs/HARNESS-MATRIX.md` §5). It is optional:
a dispatch without it runs with no `CF_*` in the harness child's environment. When it is present,
the node exports exactly that set and nothing else — every `CF_*` in the node's own environment is
scrubbed first, so two lanes on one node cannot contaminate each other. A name outside §5, or a
credential VALUE where `CF_API_KEY_FILE` expects a path, is a named refusal, and the refused value
is never copied into a log or a reply.

## Result (node → reply_to inbox)

```json
{
  "env_version": 1,
  "dispatch_id": "uuid",
  "corr_id": "lane-<ts>-<seq>",
  "in_reply_to": "<relay message id the dispatch arrived under>",
  "status": "completed | failed | refused",
  "ok": true,
  "reply_b64": "<base64 of the UTF-8 report the scheduler records on the tick>",
  "host_identity": "node-host-1",
  "harness": {"name": "hermes", "served_model": "openai/gpt-6.1-sol"},
  "vars": {"CF_MODEL": {"set": true, "len": 17}, "CF_API_KEY_FILE": {"set": true, "len": 27},
           "CF_HARNESS_OPTS": {"set": false, "len": 0}},
  "exit_codes": [0, 0],
  "gate_exit": 0,
  "branch": "node/crier/<dispatch_id>",
  "commit": "<sha>",
  "artifacts": [{"path": "test.log", "sha256": "…", "bytes": 68}],
  "wall_s": 14.9,
  "finished_at": "2026-10-29T18:41:00Z"
}
```

`host_identity` is the node's hostname, **not** the control host's. The control host recomputes
every digest from the bytes it pulls; a reported digest that cannot be recomputed is unverified,
and unverified is FAIL.

**`vars` is the run receipt for the §5 contract**: one entry per declared variable, `set` plus the
`len` of the value that was passed — never the value itself, because a value can be a credential.
It is what makes two runs comparable: the same lane, model and options show the same receipt, and
a run whose receipt differs can be diffed instead of guessed at.

### `ok` is the verdict; `status` is the node's own classification

`status` says what the node thinks happened. **`ok` is the field the scheduler reads**, and its
**absence reads as success** (`dispatchReplyVerdict`, `internal/scheduler/dispatch_leg.go`). A
result that says `"status": "failed"` and omits `ok` is therefore closed as a **completed** tick —
the failure is invisible to the control host, which is the defect this rule exists to prevent.

So, for every result:

- `status: "completed"` ⇔ `"ok": true`.
- `status: "failed"` or `"refused"` ⇒ `"ok": false`, **plus a reason** the scheduler can record:
  `error` (a short string; the scheduler's verdict reads it before anything else) and `reply_b64`
  (the node's own words, which become the tick's text). A failing gate must name the gate and its
  exit code, not just its own exit status.
- A gate that could **not run** (no `cmd`, or a command the node could not start) is a FAILED
  result too: the node's own row for it is a FAIL, and a result may not claim `ok: true` for a
  brief whose gate never produced an exit code.
- A failure is still **delivered and then acked**. Withholding the ack would only loop the work.

`reply_b64` travels base64, and for the same reason the directive does: the relay's control-key
pre-match refuses prose that quotes JSON (`stringified_json`, `403 GUARD_BLOCKED`), and a real
report quotes board rows and curl bodies. The scheduler decodes `reply_b64` first
(`dispatchReplyText`), so this is the one field whose text reaches the tick row.

### The path home

1. The node executes the dispatch (harness, then `gate`).
2. It **POSTs the result envelope into the inbox named by the dispatch's `reply_to`** — the
   scheduler's own bus identity, which the scheduler sets on every dispatch it hands out:
   `POST /agents/<reply_to>/inbox`, with the envelope as the body's **`payload` object** (crier
   requires `payload` to be present and to be a JSON object — `docs/openapi.yaml` →
   `inboxDeliver`), `sender` naming the producing agent (it must equal `X-Agent-ID` on a
   service-authenticated recipient), `request_id` carrying the `corr_id`, and `idempotency_key`
   as the retry key below.
3. Only **after** that delivery is accepted does the node **ack** the dispatch message.

A blank `reply_to` is a named refusal at the node, not a request to `/agents//inbox`: a result
addressed to nobody is a silent loss.

### Correlation semantics

- `corr_id` is the scheduler's join key and the node echoes it **verbatim**; `dispatch_id` is the
  node's and is echoed too.
- `in_reply_to` is the relay message id the dispatch arrived under. The scheduler correlates on
  **`in_reply_to` first**, then on `corr_id`, then on the original dispatch echoed inside `task`
  (`correlateDispatchReply`, `dispatch_leg.go`). It is the identity of the hand-out that decides,
  never the arrival order.
- **A result that names neither key never completes a tick.** The awaiting tick keeps polling,
  then records `no correlated reply for corr=<the one it waited for>` and expires. The message is
  not silently dropped either: it is *named* in the tick detail
  (`[dispatch-inbox] seen=N correlated=0 uncorrelated=N keys=<the keys it claimed> acked=…
  deferred=…`) and settled — acked when it can belong to nobody, **deferred** when its identity
  names another in-flight hand-out, which is then left for its owner.
- Corollary for the node: never rewrite, truncate or regenerate the correlation identity. A
  result whose `corr_id` was "helpfully" fixed up is residue that completes nothing.

### Durable delivery, and the delivery budget

- crier's blocking budget (`timeout_ms`, default **30000 ms**, range `0..120000`,
  `internal/registry/handler.go`) bounds a **blocking** delivery to a webhook or session
  recipient. It does **not** bound an inbox delivery: an inbox recipient is a durable store — the
  message is written and remains retrievable until it is acked or expires.
- A delivery whose **answer** is lost (relay unreachable, connection dropped, `504` from budget
  exhaustion) stored nothing on the relay's side, so it is **not** a delivered result. The node
  must retry, and it must not redo the work: the result is recorded in the node's seen-cache at
  **execution** time, so a redelivered dispatch re-delivers the recorded result.
- Every delivery carries an `idempotency_key` derived from the **dispatch alone** (never from the
  attempt count or the clock). A retry inside the relay's deduplication window
  (`CR_IDEMPOTENCY_WINDOW_S`, 24 h by default) is answered with the **first** accept — same
  message id, nothing stored — so retrying is safe and produces exactly one result. crier caps the
  key at 128 characters.
- A result that reaches the inbox **after** the scheduler's own await window is still delivered
  and still in the inbox — not dropped — but it does not retroactively complete that tick: the
  tick was already recorded as expired and the late message is settled and named as above.

### Ack after delivery

- The dispatch message is acked **only after** its result's delivery is accepted. A crash between
  execution and delivery, a refused delivery, or a lost answer leaves the message unacked, so the
  relay returns it and the result is re-sent.
- Acknowledgement is **per message**, not per batch: one result that failed to deliver must not
  leave an unrelated message unacked, and one accepted result must not ack a message whose own
  delivery never landed.
- This is at-least-once delivery of the result with exactly-once *storage* of it (the idempotency
  key), not exactly-once execution of the work.

## Reserved field names (crier guard)

crier's prompt-injection guard rejects any JSON whose keys match
`"(system|instructions|prompt|tools|schema)"\s*:` — `403 GUARD_BLOCKED`, `matched_pattern=control_keys`.
That is why this envelope says `env_version`, never `schema`, and why a field carrying a tool list
must be named something else (e.g. `capabilities`).

Authors must not work around this by renaming to opaque keys; the envelope vocabulary is fixed
here, and any new field is added to this spec first.

## Correlation and idempotency

- `corr_id` is the scheduler's join key; `dispatch_id` is the node's.
- Every dispatch carries an `idempotency_key`; a redelivered message must be recognised and the
  previous result returned rather than the work being done twice.
- A node acks a dispatch **only after** the result message is delivered. A crash between
  execution and delivery causes redelivery — hence idempotency, not exactly-once.
- The two directions have **separate** idempotency keys: the dispatch's (minted by the scheduler)
  keeps the work from being handed out twice, and the result's (derived from the dispatch by the
  node, `scripts/node-bus-worker.py` `delivery_key()`) keeps one result from being STORED twice
  when a delivery is retried. They are not interchangeable and neither is ever regenerated.
