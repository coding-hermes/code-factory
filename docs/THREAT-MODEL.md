# Threat model — public code-factory

Status: source-grounded and hermetic-local assessment, not deployment attestation.
No live credentials or services were inspected. NODE.md, ENVELOPE.md, HARNESS.md
and DESIGN.md are the authority for current versus planned behavior.

## Assets, actors and trust boundaries

Protect control-host authority and provider credentials, node identity/project
binding, repository/branch integrity, result/artifact provenance, and shared disk
and compute availability. Briefs, repo code, model output, supplied paths and
node claims are untrusted. A compromised node can fabricate every response.
The external scheduler, Crier, task-router, Bunker and gateway are not implemented
here and their deployment security is unverified.

Provider credentials stay on the control host. Node-side provider key files are
unsupported, never a PASS prerequisite and never read by the Hermes adapter.
CF-002 owns the host inference proxy and node-scoped identity; integration is
UNIMPLEMENTED / BLOCKED. Existing policy text about a node credential bundle
applies only to future authorized node-scoped service identities, not provider
keys. Bundle issuance/intake/deletion/rotation is not implemented in this path.

## Existing controls (source, not live proof)

| Boundary | Implemented control | Limitation |
|---|---|---|
| Public input → creator | `node-create.sh` + `node-contract.py`: required project/repo/harness and options validated before any Bunker call; only explicit hermes for creation, narrow Git origin grammar from NODE.md. Values still cross `bash -lc` using Bash `%q`. | This is quoted/validated shell construction, not absence of shell strings or a general Git URL parser. Fake Bunker captures exact triple; no live API compatibility proof. |
| Node reuse → apply | `project-node.sh` calls `manifest-check` before adapter/clone; mismatched or malformed project/repo/harness (and other stable identity fields) refuses. | Matching manifest is not attestation of an existing repo's remote, revision or cleanliness. Dirty-repo warnings/handling unimplemented. |
| Layers → manifest | Required checks must pass; `manifest-write` publishes a mode-600 temporary file atomically without overwriting an existing identity; writer failure becomes FAIL, not PASS. | Node account controls state and can lie; no signed manifest. Existing-state precheck is not an OS sandbox. |
| Artifact input → remote work | Exact manifest exception or `~/.node/jobs/ID/artifacts/NAME` with matching dispatch id; strict filename and sensitive-name denial locally before any Bunker operation. | Lexical dispatch binding is not authenticated envelope validation. Arbitrary config/secret files cannot be requested, but an allowed log can still contain sensitive content. |
| Remote path → file read | Direct Python argv, no remote shell until successful artifact snapshot. Directory-fd walk uses `O_NOFOLLOW`; final file must be regular with one link, <=16 MiB. Reject symlinks, hardlinks, FIFOs and traversal. | HOME is a trusted account root. A compromised account/node can copy or forge contents and change files; the read is a bounded snapshot, not provenance. |
| Node bytes → control host | Remote snapshot reports SHA-256 plus base64 bytes; local verifier recomputes SHA-256 and fails on malformed snapshot, transfer error or mismatch. | Equal hashes establish byte consistency only, not actual gate execution, freshness, branch/commit identity, safety or authenticity. |
| Gateway → acceptance | `verify-node.sh` requires 200 status, JSON boolean `auth_required:true`, and 401/302/403 for unauthenticated stats. Missing auth and unknown outcomes are FAIL, never WARN. | Probes are not complete effective-auth validation. Hermes apply/check is blocked before gateway start pending CF-002, rather than trusting a `basic_auth` substring. |
| Download → execution | `lib.sh` `fetch_verified` rejects wrong digest and deletes bad temporary bytes. | Does not establish provenance of every dependency. Historical pip version pin is not artifact-hash enforcement; current Hermes adapter refuses install. |
| Resource checks → provision | `require_disk` measures free GiB and floor; project-node checks memory and provisioning reachability. | No per-job admission, CPU/memory/artifact quota enforcement or runtime disk checks. |
| State → bus | Existing `.node/crier.json` must be mode 600 and bus base supplied. | File presence/mode does not authenticate Crier identity or establish worker operation. |

## Planned controls, explicitly unimplemented

ENVELOPE.md specifies text/brief digest, reserved key behavior, result correlation,
idempotency and ack-after-result-delivery. There is no tracked Crier pull worker,
message signature verifier, gateway dispatch execution, result publisher, lease
loop, deduplication store, quarantine or scheduler exclusion in these scripts.
No bus/gateway/inference work round trip is demonstrated here.

Future runtime integration must authenticate dispatch/result provenance and bind
expected project, repo, commit and artifact set; independently rerun gates; enforce
resource admission and sandbox repository/harness execution with limited egress.
One project per node alone is not filesystem/credential isolation. Quarantine and
dirty-repo handling are planned policies, not consequences of a verifier failure.

## Hermetic proof and mutation boundary

`tests/selftest.sh` executes `tests/node-contract.py`: fake Bunker/curl/git/adapter,
temporary HOME and harmless local artifact bytes. Invalid creation input records
zero Bunker calls. Artifact lexical denials record zero Bunker calls; unsafe
filesystem types never reach remote shell probes. Exact project/repo/harness argv,
valid manifest and dispatch artifact, identity mismatch, writer error and identical
re-apply are tested. Existing auth/digest/provision failure tests remain fail-closed.

`tests/node-mutations.py` executes altered private copies: named failure removed,
bootstrap-error decoy, repo validation removed, local artifact scope removed,
no-follow removed, manifest write status ignored and identity check ignored.
Each first runs an unchanged positive control and then requires an assertion
failure from the mutant, not a parser/bootstrap failure of the test runner.
These are local tests, never live Bunker/Crier/provider proof. The literal-assignment
scan is not a complete secret scanner or proof of runtime/history hygiene.

## Residual risks and readiness decisions

- Provider proxy/node identity/auth integration remains CF-002's live blocker.
- External gateway auth, Bunker exec semantics, Crier guard behavior and transport
  policy need independent live evidence from the exact deployed revision.
- Git clone/build/harness work is untrusted code; no runtime sandbox/egress policy
  or quotas are established. SSH access, if separately authorized, is not installed
  or copied here. Repo inputs exclude embedded HTTPS credentials.
- Artifact filename/symlink limits prevent accidental verifier overreach but do
  not detect secrets deliberately copied into an allowed artifact by job code.
- A file snapshot and matching manifest cannot prove an honest node, current
  checkout or successful job. Complete result validation is unimplemented.
- No live provisioning, service change, provider-key transfer, inference call,
  Crier round trip, quarantine or production readiness is claimed by this review.
