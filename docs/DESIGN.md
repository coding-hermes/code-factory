# DESIGN — the factory

## 1. Target topology (planned, not deployed proof)

Control-host foreman → scheduler/task-router → Crier → one-project node
(repo + harness) → result message → independent control-host verification.
Provider keys remain on the control host. CF-002 owns the host inference proxy
and node-scoped service identity. That integration is UNIMPLEMENTED / BLOCKED;
CF-005 does not implement its architecture or use node-local provider keys.

One node per project is the intended isolation/accounting unit. It is not proof
of an OS sandbox, resource quotas, secret isolation or safe repository code.

## 2. Planned work lifecycle

The scheduler should render the ENVELOPE.md directive; a signed Crier pull worker
should validate the brief digest, dispatch to the harness/gateway in the intended
workspace, run the gate, publish result provenance and artifacts, then ack after
delivery. The control host should independently verify provenance and bytes.

None of the pull worker, gateway dispatch integration, lease/replay/idempotency,
result publishing, runtime disk admission, quarantine or scheduler exclusion is
implemented by the provisioning scripts. Dirty-repo warning/handling is also
unimplemented; an existing `.git` directory is not proof of a clean or correctly
pinned checkout. These are blocked integration requirements, not effects of
`project-node.sh` or `verify-node.sh`.

## 3. Ownership

| Concern | Owner |
|---|---|
| Turn/admission/quarantine | scheduler (external) |
| Route and actual inference service | task-router + CF-002 host integration |
| Message transport | Crier (external) |
| Node inputs/provisioning checks | this repository |
| Work correctness and result acceptance | control-host foreman, never node self-report |

## 4. Executable repository contract

| Surface | Implemented boundary |
|---|---|
| `scripts/project-node.sh --check|--apply` | Preflight, tool probes, adapter, existing bus identity mode, repo directory/clone, manifest. Existing identity checked before apply mutations; atomic publication checks status; identical reuse preserves bytes. |
| `scripts/node-create.sh --project P --repo URL --harness H` | Validates complete triple/options before any Bunker operation; stages provisioner/helper/adapter, executes quoted validated values, stops on failure, verifies exact manifest path. |
| `scripts/verify-node.sh --agent ID --artifact PATH` | Locally rejects paths outside NODE.md's manifest/dispatch namespace; non-shell no-follow remote snapshot read before any remote shell health probe; control-host digest, status/auth/unauthenticated stats checks. |

NODE.md defines exact input/path grammars and manifest fields. ENVELOPE.md defines
the future protocol and its limited implemented artifact mapping. HARNESS.md
distinguishes historical measurements from current adapter status. The Hermes
adapter deliberately fails `inference_integration` before installation, config/key
reads or gateway startup. Local fake adapters can exercise manifest logic but
cannot remove that live blocker. Crier identity issuance and secure bundle
handling are not implemented; no credential transfer occurs in this path.

Artifact example (planned dispatch producer, implemented verifier mapping):
`~/.node/jobs/local-example/artifacts/test.log` with `--dispatch-id local-example`.
Only `~/.node/node.json` is accepted without a dispatch id. Direct Python argv
opens directory descriptors with `O_NOFOLLOW` and rejects symlink components,
hardlinks, non-regular files and oversized data. Locally recomputing the snapshot
digest proves byte consistency, not authentic dispatch association or safe content.

## 5. Failure model and evidence boundary

Implemented failures return nonzero: invalid creation input before remote work;
unsafe artifact before shell probes; missing/uncertain auth, transfer/digest error;
manifest identity mismatch/write failure; adapter refusal or other required layer
failure. No scheduler quarantine is performed. The manifest must not be mistaken
for current health, and provisioning's disk check does not enforce per-job quotas.

`tests/selftest.sh`, `tests/node-contract.py` and `tests/node-mutations.py` use
local fake commands and temporary HOME/repository/adapter state. The named checker
fixture has a working bootstrap PATH and exactly one intentional missing input,
CRIER_URL (CRIER_BASE remains set). It requires nonzero exit and the anchored exact
`  FAIL  crier_url — ` row, and rejects bootstrap errors. Executable mutations
remove that named failure and inject `FAILED: unbound variable`; both must turn
that same test red. Other mutations exercise input, artifact and manifest controls.

No live Bunker/Crier/gateway/inference/artifact work round trip or provider-key
transfer is claimed. A real authenticated deployment, host-only inference path,
Crier worker, dispatch execution/result publishing and provenance verification
remain NOT VERIFIED / BLOCKED. Local fixture success is never live acceptance.
