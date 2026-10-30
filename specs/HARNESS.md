# SPEC — harness adapters

A harness executes work inside a node. The intended interface is install/check,
measured version, unattended directive+cwd invocation, requested/served model
reporting, explicit nonzero failure and idempotent install. The tracked adapters
are installation/check probes, not implementations of dispatch invocation or
result reporting. See NODE.md and ENVELOPE.md for that boundary.

## Adapters and their measured state

| Harness | Historical method / current state |
|---|---|
| hermes | Historical record: python venv + pip `hermes-agent==0.19.0`, 32 s install, 248 MB venv, `serve --skip-build`, `/api/status` 200 and JSON-RPC probes on an earlier test node. Not reproduced by CF-005 rework; not current inference acceptance. Adapter check/apply now fails `inference_integration` before installation, config/key reads or gateway startup. |
| opencode | Standalone CLI/server method documented; apply refuses as unverified. |
| claude-code | npm method documented; apply refuses as unverified. |
| codex / aider / goose / pi-agent | Planned methods only; no tracked install adapter. |

## Host-only inference custody

Provider keys stay on the control host. No node-side provider key file is required,
read, copied or supported by this provisioning path. CF-002 now supplies a
repository-local, loopback-only host proxy (`scripts/inference-proxy.py`) and
hermetic tests. Deployment, node adapter, identity delivery, Crier transport and
gateway configuration remain UNIMPLEMENTED / BLOCKED. Do not interpret a node-local
provider key as a workaround. The fail-closed Hermes adapter is deliberate, not a
successful install.

The earlier measured ladder is retained as historical evidence only. It is not a
claim that a safe provider path or authenticated gateway is currently deployed.
A future adapter must validate effective auth configuration, verify startup and
inference through the authorized host service, and expose requested/served identity
before node acceptance. No proxy architecture is implemented by CF-005.

## Local fixtures

Tests substitute an executable adapter reporting `PASS  version` solely to exercise
manifest and provisioning control flow. They cannot certify Hermes, Crier, Bunker,
gateway auth, provider routing or a live inference/artifact round trip.

## Host-local inference protocol (CF-002 local tranche)

This stdlib safety boundary is not a production routing registry or Hermes adapter.
Invocation: `python3 scripts/inference-proxy.py --state-dir DIR --port 0`.
DIR is an operator-created absolute uid-owned mode-700 directory outside the repo.
No ancestor may be a symlink. Only 127.0.0.1 is bound; port 0 selects an ephemeral
port. No remote bind switch. Startup names the actual port, never secrets/paths.

### Host policy and custody

DIR contains policy.json, evidence.jsonl and host-only credentials. Policy and
keys must be uid-owned single-link regular files, mode 600, no symlinks. Opens
use directory descriptors and O_NOFOLLOW; devices/FIFOs refuse. The directory is
a trusted host boundary: the host account can replace code/policy/keys/evidence.
No environment credential resolution. Only the state directory is on argv, never
a credential. Key/attestation files contain exactly 32-128 ASCII URL-safe
characters (letters/digits/underscore/hyphen), no newline. This is a deliberately
narrow credential format, not support for every provider credential encoding.
Policy is reread/validated each request; invalid/missing policy
fails closed during rotation. Operators atomically publish policy, revoke an
identity or rotate its token_hash. Revocation affects the next authorization,
not a request already in flight. Issuance/delivery/enrollment are unimplemented.

policy.json is an exact object with version:1, identities:array, routes:array.
Each identity has service_identity, node, project, repository, token_hash (lowercase
SHA-256 of high-entropy bearer), expires_at (integer Unix seconds), revoked:boolean,
allowed (nonempty array of exact {provider,model} pairs). Identifiers/provider/model
use 1-128 ASCII alphanumeric or _ . / : - characters. Repository is an exact
operator-chosen canonical identifier, not a URL to fetch. No wildcards, duplicate
identities/token hashes/pairs or unknown fields. Bearers are 32-128 URL-safe
characters, compared by constant-time digest comparison. Possession proves scope,
not a physical machine identity. Use a cryptographically random service token.

Each route has provider, model, url, key_file, attestation_file, fallback.
Credential names are non-hidden simple basenames within DIR. url is HTTPS with
normal certificate verification, no userinfo/query/fragment, exact path
/v1/chat/completions; HTTP only at numeric 127.0.0.1 for tests. Fallback is an
ordered array of exact {provider,model} pairs referencing routes; no recursive
fallback. ALL candidates must be authorized BEFORE any credential resolution.
Clients cannot choose URL/keys/headers/fallback. Redirects refuse; environment
proxy use is disabled. Only transport or HTTP 502/503/504 errors allow fallback;
authentication/attestation/response errors do not.

### HTTP subset and order

Only POST /v1/chat/completions, application/json, one Content-Length (1-65536),
no Transfer-Encoding/Content-Encoding/Expect. One Authorization: Bearer credential.
Only Host, Authorization, Content-Type, Content-Length, Accept, Accept-Encoding
(identity only), User-Agent and Connection headers; duplicates refuse. Responses
close connections. Socket timeout
5 seconds. Unsupported methods/paths/streaming/tool calls/images/extensions refuse.

Exact body: service_identity, node, project, repository, provider, model, messages;
optional stream:false, temperature (finite 0..2), max_tokens (integer 1..4096).
messages is 1..32 exact {role,content} objects: system/user/assistant role, string
content at most 16000 characters. Duplicate JSON keys/nonfinite numbers/type
confusion/unknown fields refuse. Schema/auth/scope/expiry/revocation/model/fallback
checks and durable intent evidence precede opening ANY upstream credential.
Upstream gets only model/messages/options, host bearer and fresh X-CF-Request-ID,
never service token/scope/client headers. Request IDs are host UUIDs. Upstream
socket timeout 5 seconds; response limit 131072 bytes. Timeouts are per socket
operation, not a total execution deadline. No rate/concurrency/quota guarantee.

### Trusted served-identity attestation

Response/request/config labels are not authoritative actual served identity.
A separately qualified upstream adapter MUST observe actual serving provider/model
after internal routing and send X-CF-Served-Provider, X-CF-Served-Model and
X-CF-Attestation. Attestation is lowercase HMAC-SHA256 with route attestation secret
(distinct from provider key), over sorted compact ASCII JSON of
{request_id,provider,model,body_sha256}; body_sha256 hashes exact response bytes.
request_id is the attempt X-CF-Request-ID. Absent/invalid/replayed attestation,
duplicate headers, unauthorized/mismatched served pair or conflicting body model
refuses. Served MUST equal attempted pair, including fallback. A single assistant
text choice (index 0, stop/length finish_reason, no extra message fields) is
projected to clients; no upstream headers returned. Known resolved credentials in
projected content refuse. This is not a general content-secret classifier.

HMAC authenticates the trusted adapter assertion, not its truthfulness. It cannot
detect secretly rerouting providers. Generic OpenAI endpoints lack this protocol
and refuse. Attestor qualification, private authenticated remote TLS termination,
network topology, node adapter, Crier transport and owner-authorized disposable
node remain BLOCKED. Fake local attestations prove checks, not remote identity.

### Restart-safe evidence and failures

One process holds exclusive advisory flock on uid-owned mode-600 single-link
regular evidence.jsonl. Startup verifies full hash chain, exact record schema,
sequence and newline; corrupt/torn evidence refuses, no repair/truncation.
Records hash canonical JSON plus previous hash. Append checks inode/size, uses
O_APPEND and fsync before acknowledgment; creation fsyncs directory. Write failure
poisons the process; future requests refuse before keys. Restart validates surviving
bytes. A torn append is a blocker. Successful evidence MUST persist before 200.
A final-write failure returns generic 503, never a successful response.

Records: sequence, previous/hash, time_ns, host request UUID, trusted node scope
(or null for unauthenticated denial), requested/attempted/served pair, outcome,
provenance. No prompts/completions/token counts/keys/bearers/provider exceptions.
Attacker strings are never recorded on denial. Durable intent precedes keys and
each attempt records outcome. A crash may leave intent without result (unknown,
never fabricated success); no inference replay/exactly-once guarantee. Fsync success
can precede lost client response. Hash chain is application append-only, not
OS-immutable: host-account deletion/rollback/full rewrite remains possible.
No off-host witness is claimed. Fixed error codes never echo exceptions/body/auth;
HTTP access logs suppressed. Tests exercise actual local HTTP plus key resolver
spies, fallback, attestation, custody, restart/revocation, write/corruption failure
and semantic mutants. No installer proxy configuration is implemented.
