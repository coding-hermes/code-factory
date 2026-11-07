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
  "status": "completed | failed | refused",
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
