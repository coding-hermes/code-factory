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
  "text": "You are the foreman for lane crier. Work the board at <ref>. Report a verdict.",
  "brief": {"digest": "<sha256 of the task text>", "bytes": 4211},
  "route": {"provider": "xkiro", "model": "openai/gpt-6.1-sol", "harness": "hermes"},
  "vars": {"CF_MODEL": "openai/gpt-6.1-sol", "CF_PROVIDER": "xkiro",
           "CF_API_KEY_FILE": "/home/node/.node/keys/xkiro.key",
           "CF_WORKDIR": "/home/node/crier", "CF_NAMESPACE": "crier", "CF_RUN_ID": "lane-<ts>-<seq>",
           "CF_LANE": "crier", "CF_MAX_TURNS": 40},
  "limits": {"wall_s": 3600, "max_artifacts": 50},
  "gate": {"cmd": "go test ./...", "expect_exit": 0}
}
```

**`text` is mandatory.** A dispatch without `text` is a bug: the receiving side has no
instruction and will either invent one or run the JSON as a prompt. `brief.digest` proves the
node got the task it was given; a mismatch is a refusal, not a warning.

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
