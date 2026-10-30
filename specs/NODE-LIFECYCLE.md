# SPEC — Bunker node installation and configuration lifecycle

Status: design contract for future implementation. This specification does not claim that the
lifecycle is implemented or that a live Bunker host has been qualified. Every host-specific,
provider-specific, or live service claim not backed by a cited repository measurement is labelled
NOT VERIFIED or BLOCKED. Do not infer a Bunker command or capability from this document.

## 1. Purpose and authority

Define a safe, repeatable lifecycle for installing, configuring, validating, renewing, destroying,
and rebuilding one Code Factory node: one Bunker agent, one project, one repository, one harness,
and one Crier identity. `specs/NODE.md` defines node identity and layers; `specs/ENVELOPE.md`
defines dispatch/result messages; `specs/HARNESS.md` defines adapter obligations. This file
extends those contracts with lifecycle and evidence rules. If a script disagrees with a spec,
resolve the spec first and change the script in the same implementation change, per `AGENTS.md`
rule 1.

This is not an authorization to provision infrastructure, connect to a host, or handle real
credentials. The current source boundary and missing live operations are documented in
`docs/OPERATIONS.md` §§1–11 and `docs/THREAT-MODEL.md` §§2–6.

## 2. Evidence labels and source baseline

Use these labels in this spec, implementation output, and test reports:

- **SOURCE-OBSERVED:** present in checked-in code or documentation. It says nothing about a live
  host unless explicitly measured there.
- **RECORDED MEASUREMENT (not independently reproduced):** a result recorded in the repo, not a
  current host guarantee.
- **NOT VERIFIED:** no suitable repo evidence or independent current measurement exists.
- **BLOCKED:** a required prerequisite/capability is absent or unverified; do not proceed through
  that gate.
- **PASS / FAIL:** emitted by a runnable check with its measured value; no missing/uncertain
  result may be downgraded to a warning for admission decisions.

Current source baseline:

| Surface | Source evidence | Status/boundary |
|---|---|---|
| Control-host qualification | `scripts/bunker-server-install.sh:14-66` checks a `bunker` executable, a configured server name, `bunker list`/`status`, control tools, and free disk. | SOURCE-OBSERVED check only. Its usage comment mentions `--apply` (`:4-5`), but implementation only reads `--json` (`:14-16`) and performs checks; it does not implement apply. Live server and control-host readiness: NOT VERIFIED. |
| Node provisioning/check | `scripts/project-node.sh:24-37,39-75,77-127` parses `--check|--apply`, makes `$HOME/.node`, checks disk/memory/network/tools, runs a harness adapter, requires `$HOME/.node/crier.json` mode 600, optionally clones a repo, and writes a manifest after zero recorded failures. | SOURCE-OBSERVED. `--check` is not read-only because `mkdir -p "$STATE"` runs in both modes (`:39`). Provisioning is incomplete; see `docs/OPERATIONS.md:38-63`. |
| Creation orchestration | `scripts/node-create.sh:12-65` creates/reuses a Bunker agent, stages scripts, invokes node apply, then runs the control-side verifier. | SOURCE-OBSERVED. It uses shell interpolation (`:52-53`), does not deliver a Crier bundle, and continues to verification after a failed provisioning attempt. Not production-ready (`docs/OPERATIONS.md:53-63`; `docs/THREAT-MODEL.md:61`). |
| Verification | `scripts/verify-node.sh:31-74` checks agent exec, obtains an IP, probes `/api/status`, probes unauthenticated stats, and optionally compares a remote digest with downloaded bytes. | SOURCE-OBSERVED partial probes. Authentication uncertainty can be WARN (`:45-58`); artifact is optional (`:60-71`). This is not a full result-envelope or dispatch round trip (`docs/OPERATIONS.md:104-115`). |
| User-space helpers | `scripts/lib.sh:15-29` has pinned SHA-256 fetch; `:31-44` measures disk and fails below a floor; `:46-51` has a sentinel-based `once` helper. | SOURCE-OBSERVED helpers. They do not make every current script idempotent or verify every download. |
| Hermes harness | `scripts/harness/install-hermes.sh:4-5` records a test-node result: Python 3.12.3, Hermes Agent 0.19.0, approximately 32 seconds and 248 MB venv. Script installs a version-pinned package (`:16-18,50-59`), checks `/api/status` (`:33-41`), and checks for an inference-key assignment without printing its value (`:43-48`). | RECORDED MEASUREMENT only, not independently reproduced. Exact OS, architecture, Bunker image, firewall, and current health: NOT VERIFIED. Package version pin is not an artifact digest. |
| Other harnesses | `scripts/harness/install-opencode.sh:4-6,31-34` and `install-claude-code.sh:4-6,33-40` refuse unmeasured apply. `specs/HARNESS.md:20-30` records Hermes as the only measured ladder. | Hermes only has a recorded install ladder. Others are NOT VERIFIED and apply is blocked. |
| Lifecycle operations | `docs/OPERATIONS.md:150-158,171-188` states no checked-in renewal, destroy, rebuild, or teardown command; no documented secure bundle transfer. | Renew/destroy/rebuild and Bunker TTL semantics: BLOCKED / NOT VERIFIED. No command may be guessed. |
| Credential policy | `AGENTS.md:37-41`, `docs/THREAT-MODEL.md:68`, and `docs/OPERATIONS.md:160-168` require a single mode-600 bundle, deletion after use, and no secrets in argv/logs/board/specs/tests. | Policy is SOURCE-OBSERVED; secure transfer, consumption/deletion, rotation/revocation, and runtime isolation are NOT VERIFIED. |

### Host-profile support decision

No host profile is currently certified. The node script checks `uname -m`, Linux kernel text,
`/proc/meminfo`, and a tool list (`scripts/project-node.sh:42-66`), but does not allowlist a
Linux distribution/version or enforce a supported architecture. `specs/NODE.md:26-31` describes
requirements, not an OS compatibility matrix. The Hermes row above is a recorded adapter
measurement; it does not identify a reproducible Bunker host image. Therefore:

| Profile | Status | Admission rule |
|---|---|---|
| Named Linux distribution + release + architecture + Bunker image | NOT VERIFIED: none is pinned and evidenced by the inspected source. | BLOCKED until a profile is named, documented, and tested on a disposable host. |
| Generic Linux/Bunker agent with the tools required by `specs/NODE.md:26-31` | Requirements are documented; compatibility is NOT VERIFIED. | Do not call this supported solely because the checks happen to pass. |
| Hermes 0.19.0 adapter on a test node | RECORDED MEASUREMENT at `specs/HARNESS.md:18-20`; OS/image profile missing. | Adapter candidate only; host profile and live node remain unqualified. |
| OpenCode, Claude Code, Codex, aider, goose, pi-agent | See `specs/HARNESS.md:20-30` and adapter scripts. | NOT VERIFIED; `--apply` must remain refused unless and until an install ladder is measured and recorded. |

A future support record MUST name distribution and release, architecture, Bunker image identifier,
required user-space tool versions, harness adapter/pin, measured disk/memory values, and exact
passing validation evidence. Never widen the support label from a different profile's result.

## 3. Lifecycle invocation and shared semantics

The eventual lifecycle interface is a control-host lifecycle client plus node-side checks. This
spec intentionally does not assign command names, flags, or Bunker CLI syntax to operations that
have no verified implementation. Existing entry points are exactly those listed in
`docs/OPERATIONS.md:44-50,171-188`; new interfaces require a separately reviewed implementation
change and help/contract tests before being documented as runnable commands.

For every implemented lifecycle operation, define both `--check` and `--apply` semantics:

- `--check` MUST be read-only: no directory creation, file changes, network mutation, agent
  creation, scheduler mutation, or secret transfer. It emits one `PASS`, `FAIL`, or `WARN` row per
  required probe, includes measured values and exit status, and exits nonzero for any failed
  prerequisite. WARN is allowed only for explicitly optional, non-admission requirements.
- `--apply` MUST first run the same preflight checks. It may make only the requested state
  transition. After each mutation, it MUST verify the exact resulting state with an independent
  read/probe; a successful command or version string is not proof (`AGENTS.md:31-39`).
- Idempotence: repeating apply against the target state MUST leave state unchanged and exit 0.
  A partial/mixed state must be reconciled without deleting user work or broadening privilege.
  Append operations require a stable sentinel or read-before-write check (`AGENTS.md:35-36`).
- Scope: every command MUST bind to a fully qualified node handle and verify that the handle's
  manifest project/node identity matches the requested target before mutating. Ambiguous identity,
  wrong project, unknown state, unsupported capability, or failed read-back => FAIL and quarantine.
- Output/logging: stdout/stderr may contain paths, identifiers, versions, measured resources, and
  redacted error classes; never secret values, secret-bearing environment dumps, bundle bytes, or
  secret-bearing command lines. Preserve a sanitized failure log outside the bundle.
- No shell interpolation of user-controlled project, repo, ref, harness, node id, artifact path, or
  credentials. Inputs must be validated and transported as structured data/argv, not composed into
  a shell string. This is a design requirement motivated by `scripts/node-create.sh:50-53` and
  `scripts/verify-node.sh:60-65`, not a claim that those paths already comply.
- No root, sudo, or apt. All node-owned software and state MUST be under the agent user's `$HOME`
  (`AGENTS.md:37-39`; `specs/NODE.md:33-40`). A required privileged step blocks the profile.

## 4. Node identity and manifest contract

The canonical node manifest remains `$HOME/.node/node.json` as in `specs/NODE.md:5-17`. Before
implementation, its schema MUST be reconciled with the script's current emitted fields
(`scripts/project-node.sh:107-117`); neither shape is currently validated against a schema. The
manifest MUST contain only non-secret identity/provenance data:

- node id and project id;
- canonical repository origin, pinned ref and resolved commit, checkout path;
- harness name, resolved version, and gateway port;
- Crier endpoint/identity reference (never credential bytes or secret);
- host-profile identifier and measured architecture/OS/kernel;
- creation/update timestamps and lifecycle state;
- source revision/digest for the provisioning inputs and each applied layer;
- non-secret last-check summary with measured values and check timestamp.

Manifest writes MUST be atomic (temporary file in the same directory, flush/close, rename),
owner-only where supported, and only after all required layer checks pass. Preserve an existing
manifest on failure. Never report it as current/healthy merely because it exists. `node_id`,
project, repo origin/ref, and harness in a pre-existing manifest must match the requested target
before reuse. Current script writes directly and omits harness version (`scripts/project-node.sh:104-119`);
these are documented discrepancies to resolve during implementation, not new runtime behavior.

## 5. Lifecycle states and transitions

A node lifecycle manager MUST expose these state values in its own durable, non-secret record or
manifest; these are Code Factory states, not claimed Bunker states:

| State | Meaning | Work admission |
|---|---|---|
| `absent` | No owned node resource is confirmed. | Deny. |
| `creating` | Create/provision requested; prerequisites are being applied. | Deny. |
| `configuring` | Identity, base tools, harness, bus, repo or supervisor setup incomplete. | Deny. |
| `validating` | All layers appear configured; control-host probes and round-trip test pending. | Deny. |
| `ready` | All required checks pass and a fresh end-to-end round trip is independently verified. | Admit only the named project/lane after external scheduler target read-back. |
| `degraded` | A health probe, expiry, resource floor, or dependency check failed. | Deny new work; retain in-flight evidence. |
| `quarantined` | Security/integrity failure, unknown identity, digest mismatch, secret-handling failure, or unsafe partial install. | Deny; require operator-reviewed recovery and full revalidation. |
| `renewing` | An explicitly supported renewal is in progress. | Deny new work unless an implementation proves uninterrupted safe service; default is deny. |
| `destroying` | Target is disarmed and owned resources/evidence are being handled. | Deny. |
| `destroyed` | Resource termination and credential revocation have been independently read back. | Deny. |

Allowed path: `absent → creating → configuring → validating → ready`. A check failure from any
active state transitions to `degraded` or `quarantined` according to the table above. Renewal is
`ready → renewing → validating → ready` only when the provider adapter explicitly advertises and
has measured a renewal capability; otherwise renewal is BLOCKED and replace/rebuild is required.
Destruction is `ready|degraded|quarantined → destroying → destroyed`; any uncertain external
read-back leaves `destroying` or `quarantined`, never `destroyed`. Rebuild is a new identity and
fresh provisioning from a trusted manifest/input snapshot, not an in-place trust reset.

Only `ready` is work-admissible. A node-side PASS alone is insufficient: control host must verify
the node and the end-to-end Crier→harness→result/artifact path; scheduler target enablement is
separate external state and must be read back. Basis: `specs/NODE.md:22-31,37-40`,
`specs/ENVELOPE.md:47-49,61-68`, `docs/DESIGN.md:34-65`, and `docs/OPERATIONS.md:96-115`.

## 6. Prerequisites and installation layers

Provision in this order, preserving `specs/NODE.md:22-31` layer ordering and DESIGN's “bus before
workspace” rule (`AGENTS.md:42-43`):

| Order | Layer | Required checks before layer PASS | Existing evidence / gaps |
|---|---|---|---|
| 00 | Control-host / target preflight | Explicit target server; client/config presence; server read-only reachability; caller authorization; target identity and quota; no unrelated concurrent writer; input validation. | Existing qualification in `scripts/bunker-server-install.sh:14-63`. Provider authorization, quota, and current target state: NOT VERIFIED. Its `--apply` is absent. |
| 01 | Host profile and capacity | OS/release/architecture allowlisted; non-root UID; available memory and free disk measured; configurable floor; Crier and required package-source probes. | Current node checks disk, `MemAvailable >=1024 MB`, arch, Crier/PyPI HTTP 200 (`scripts/project-node.sh:42-56`). No distro allowlist; Go proxy listed by `specs/NODE.md:26` is not checked there. |
| 10 | Base user-space tools | `python3` with `venv`, `git`, `curl`, `tar`, `sha256sum`; report resolved paths/versions; install only pinned and digest-checked artifacts. Optional dependencies never silently become hard prerequisites. | Current checks in `scripts/project-node.sh:58-66`; `fetch_verified` in `scripts/lib.sh:15-29`. Current Hermes pip package is version-pinned but not digest-verified (`scripts/harness/install-hermes.sh:50-56`). |
| 20 | Harness | Selected adapter is allowlisted and measured; `--check` reports path/version and actual service readiness; apply is idempotent; auth configuration is effective and tested; user-space only. | Hermes recorded in `specs/HARNESS.md:16-36`. Other adapters explicitly unmeasured. Basic-auth substring check is weak (`install-hermes.sh:61-69`); effective config validation is NOT VERIFIED. |
| 30 | Crier bus identity + node supervisor | One node-scoped identity bundle is installed safely, mode checked, consumed, removed; bus worker/supervisor health and pull/reply path measured. | Current script only checks `$HOME/.node/crier.json` exists and mode 600 (`project-node.sh:77-84`). Bundle intake, worker, supervisor, and message flow are absent/unverified (`docs/OPERATIONS.md:40,96-102`). |
| 40 | Repository/workspace | Repo origin is approved; ref resolves to an immutable commit; checkout identity and cleanliness known; no reset of existing uncommitted work. | Current shallow clone (`project-node.sh:86-102`) does not pin/record resolved commit in a stable verified manner; private repo auth procedure is BLOCKED (`docs/OPERATIONS.md:65-67,92-94`). |
| 90 | Independent validation | Control-host gateway/auth probe, Crier dispatch/result correlation, one bounded task, artifact retrieval, recomputed host-side SHA-256/byte count, independent foreman review. | Optional partial artifact check only (`verify-node.sh:60-71`); no checked-in end-to-end dispatch result round trip (`docs/OPERATIONS.md:104-115`). Must remain BLOCKED until proven. |

A layer is PASS only when its check identifies the value it measured and an independently
re-runnable probe confirms it. Failed preflight prevents all mutations. A failed layer prevents
manifest promotion to `ready`, scheduler admission, and claims of “installed”.

### Dependency and host capability boundaries

The source indicates expected commands and `python3 -m venv`, but does not establish which are
preinstalled or installable on each Bunker host. User-space Python/bootstrap artifact acquisition,
compiler availability, system libraries, `systemd --user`, `nohup`, filesystem semantics, cgroup
limits, firewall controls, and Bunker agent UID/home lifecycle are NOT VERIFIED. The spec requires
an implementation to detect and report each required capability; it does not authorize apt/root,
assume systemd, or name a host image. Missing capability = BLOCKED with the exact measured value.

## 7. Configuration and credential bundle

### Configuration

Non-secret configuration (project id, repo origin/ref, harness, port, disk floor, host-profile id,
Crier endpoint, and non-secret credential references) must be validated against an explicit schema
before mutation. Reject blank values, unknown harness/profile, invalid port/ref/project syntax,
control characters, duplicate node ownership, and mismatched existing manifest. No secret is
accepted as a command-line option or interpolated into a command string.

A per-node Crier credential bundle is one regular file, mode `0600`, owned by the node account,
created in a private directory with restrictive permissions. It contains only the node-scoped
Crier identity material and the minimum non-secret routing metadata required for bus setup. It
MUST NOT contain an operator credential, provider API key, personal credential, or reusable
control-host key. Do not put provider keys in the worker environment, Hermes `.env`, repo, manifest,
command args, logs, test fixtures, or bundle. A worker must not inherit/control-read operator or
provider credentials. This extends `AGENTS.md:39-41` and addresses `docs/THREAT-MODEL.md:68`.

If the harness cannot run without a provider credential and no approved mechanism supplies
inference without copying a provider/operator key to the node, node install is BLOCKED. Do not
work around this by copying `$HOME/.hermes/.env`; the existence check in
`scripts/harness/install-hermes.sh:43-48` is not authorization to transfer the key. The approved
provider-neutral inference mechanism is NOT VERIFIED and requires a separate owner decision and
secure integration design.

### Bundle transport, consumption, and deletion

The bundle's schema, producing system, authenticated delivery channel, and any Bunker file-transfer
command are NOT VERIFIED. No Bunker command is specified here. Before a real deployment, an
approved secure delivery mechanism must be selected and tested; until then bundle delivery is
BLOCKED. Do not use argv, shell literals, logs, board rows, source control, or chat to transfer it.

Required consumer behavior once that mechanism exists:

1. Receive exactly one bundle file in a private staging directory; fail if absent, duplicated,
   symlinked, non-regular, wrong owner, wrong permissions, malformed, or unexpected fields exist.
2. Verify mode is exactly `600` before opening; do not print or copy its contents to diagnostics.
3. Install the minimum Crier identity needed at `$HOME/.node/crier.json` with mode `600`, then
   independently verify owner, mode, syntax, and a non-secret authenticated Crier probe.
4. Start/configure the Crier worker using an approved service mechanism; verify it can receive and
   return a correlated synthetic message before marking the bus layer PASS.
5. Delete the staged bundle in a finally-style cleanup path after success or failure; verify the
   path is absent and report only `bundle_removed=true|false`. If deletion cannot be verified,
   transition to `quarantined`, block admission, and require rotation/revocation of that identity.
6. Do not claim the target identity has been revoked by deleting a file or destroying an agent.
   External revocation requires a separately verified read-back.

Tests use synthetic, non-secret fixtures only. Tests MUST NOT contain credential-looking real
values or inspect actual host credentials. Capture argv/log/process evidence using a synthetic
sentinel value and assert that the sentinel never appears in those surfaces.

## 8. Node supervisor contract

“Supervisor” means a future node-local component responsible for the lifecycle of the bus worker
and harness gateway; it is not the Bunker server daemon and not the external scheduler. No such
node supervisor is present in the tracked scripts, and the available Bunker process/service
capabilities are NOT VERIFIED (`docs/OPERATIONS.md:96-102,171-188`). Do not assume a Bunker
supervisor command, systemd availability, restart behavior, or TTL semantics.

A future supervisor MUST:

- start only after required configuration and credential checks pass; never start work in
  `creating`, `configuring`, `validating`, `degraded`, `quarantined`, `renewing`, or teardown;
- run as the node user with only the node-scoped Crier identity; never inherit provider/operator
  secrets;
- monitor explicit liveness probes for both Crier worker and harness service; distinguish process
  alive from endpoint/authenticated function healthy;
- restart only declared idempotent services with bounded exponential backoff and a finite
  consecutive-failure threshold; after threshold, mark `degraded`, stop accepting new work, retain
  logs without secrets, and expose last exit/probe/time;
- never acknowledge a dispatch before result delivery (`specs/ENVELOPE.md:61-68`); retain
  correlation/idempotency state across a crash to prevent duplicate execution;
- enforce disk floor before accepting each job, not only during provisioning; reject below-floor
  work with the measured free value (`specs/NODE.md:37-46`);
- exit cleanly on destroy/rebuild after stopping intake and preserving required work/evidence;
- expose a read-only health/status report to the control host without secrets.

How it is launched, supervised across agent restarts, logged, and stopped is implementation- and
host-profile-specific. Each chosen mechanism and its lifecycle guarantees are NOT VERIFIED until a
hermetic test and a disposable-host integration test both pass. A missing supported supervisor
mechanism blocks production readiness.

## 9. Validate, renew, destroy, rebuild

### Validate / admission

Validation is a non-mutating operation except for a clearly isolated synthetic end-to-end test that
uses a fresh, unique dispatch id and cleans up only its own artifacts. It runs every required check
from §6 and returns per-check measured results. The control host must probe the private gateway and
require `/api/status → 200` plus an explicit protected-route unauthenticated refusal; unknown status
is FAIL, not WARN. Current `verify-node.sh` is not yet fail-closed for all auth cases
(`:45-58`). Then perform one Crier round trip: verify dispatch id, correlation/idempotency key,
brief digest, result status, commit/artifact provenance, artifact byte count, and host-recomputed
digest. A missing artifact, mismatched digest, unrecognized host identity, stale result, or failed
gate is FAIL and quarantines the node. Only after this may the separate scheduler owner enable and
read back a target; scheduler capability and target APIs are external and NOT VERIFIED here.

### Renew

Renewal MUST be capability-negotiated, not assumed. The adapter must report whether a specific
resource supports safe renewal and the current/renewed expiry values. If unsupported, ambiguous, or
not measured, return BLOCKED without mutation. Before supported renewal: disarm admission, drain or
preserve work/results, confirm no active dispatch, renew only the exact owned handle, read back the
new expiry, and rerun full validation including a new end-to-end round trip before readmitting.

Current `node-create.sh` defaults to `--ttl 6h` (`:12,31-35`), but no renewal procedure or TTL
semantics are established. Do not use that TTL as proof of lease duration, renewal capability, or
automatic deletion.

### Destroy

Destroy is irreversible and MUST require an explicit exact node identity and ownership confirmation.
Before termination: disarm/read back scheduler target using its approved owner procedure; stop new
Crier intake; reconcile in-flight dispatches; preserve required branch/result/artifact evidence;
stop supervisor, worker, and gateway; revoke node Crier identity; verify revocation; request
provider-side termination only through a documented, authorized adapter; then independently read
back that the exact resource is absent and old identity/auth no longer works. If any step is
unknown or unverified, stop in `destroying`/`quarantined`; do not report `destroyed`. No Bunker
termination, scheduler disarm, Crier revocation, or artifact-retention command is provided by this
spec. All are BLOCKED / NOT VERIFIED (`docs/OPERATIONS.md:150-158`).

### Rebuild

Rebuild creates a new node lifecycle from immutable, non-secret inputs: project, approved repo
origin, resolved commit/ref policy, supported host profile, measured resource floor, harness pin,
and new node identity. It MUST NOT reuse stale credentials, copy provider/operator credentials,
blindly reuse an old agent handle, or reset/delete a dirty repo. Preserve/reconcile uncommitted work
and in-flight evidence before discarding any prior node. Require a fresh Crier identity, full
installation, validation, independent artifact round trip, revocation/read-back of old identity,
and explicit scheduler target read-back before returning to `ready`.

No destroy-and-recreate workflow exists in the repo (`docs/OPERATIONS.md:150-158`; PRD CF-110 at
`docs/PRD-code-factory.md:18-20`). Rebuild is BLOCKED until those components are implemented and
tested. Never equate “same agent name” with same node identity or successful rebuild.

## 10. Failure quarantine and recovery

[STORAGE](STORAGE.md#recovery-protocol) extends this design with durable authority,
retained immutable commits, independent artifact expectations and pending-work
reconciliation. [The local proof](../docs/STORAGE-RECOVERY.md) simulates scratch
loss/reclone only; it does not implement lifecycle rebuild or certify host loss.

| Failure | Required action |
|---|---|
| Host/server identity mismatch, unsupported profile, target capability unknown | Fail preflight; no mutation; preserve sanitized evidence. |
| Disk/memory or dependency floor fails | Refuse install/new work with measured value; clean only known disposable caches under explicit policy; remeasure before retry. |
| Partial provisioning, failed post-mutation probe, wrong/dirty repo | State `degraded` or `quarantined`; no scheduler admission; preserve existing repo/work; retry only idempotent layer after reconciliation. |
| Bundle mode/schema/ownership/deletion failure or secret leak suspicion | State `quarantined`; stop worker/admission; preserve sanitized logs only; rotate/revoke identity through verified owner path; no automatic retry. |
| Gateway unauthenticated protected probe succeeds or is inconclusive | Immediately quarantine and close network exposure through the approved operator path; do not continue tests against an exposed service. |
| Crier absent, worker unhealthy, envelope guard rejects, or message correlation mismatch | Deny work; do not bypass the guard; preserve message/idempotency evidence and retry only after correction. |
| Node exits mid-job or reply delivery uncertain | Do not ack as complete; retain dispatch idempotency record; reconcile redelivery against prior result before retry. |
| Artifact missing, byte count/hash mismatch, gate failure, stale or unbound result | Run FAIL; quarantine node; independently preserve/recompute bytes; do not accept node self-report. |
| Renewal/destroy/revocation result cannot be read back | Remain `renewing`, `destroying`, or `quarantined`; never infer success from CLI exit alone. |

A failure repair must not erase evidence, force a clean checkout, create another node, or re-enable a
target before ownership and exact resource state are established. This contract follows
`specs/NODE.md:48-54`, `specs/ENVELOPE.md:47-68`, `docs/DESIGN.md:57-65`, and
`docs/THREAT-MODEL.md:72-84`.

## 11. Runnable validation and test map

Commands below distinguish existing runnable checks from future hermetic fixtures and blocked live
proof. Run local commands only in the repository; no cloud, remote host, Bunker mutation, real
credential, deployment, or scheduler/Crier operation is authorized by CF-017.

| Test/gate | Runnable command or fixture contract | Expected evidence | Current status |
|---|---|---|---|
| Shell parser for tracked scripts | `bash -n` over tracked `*.sh` (the repo selftest currently globs scripts and tests at `tests/selftest.sh:9-12`). | PASS for every script; exact file list. | Existing selftest gate. |
| Node checker fail path | `tests/selftest.sh` exercises empty PATH and requires nonzero plus `FAIL` (`:14-17`). | The check is able to fail, not just print green. | Existing hermetic fixture. |
| Pinned-download negative path | `tests/selftest.sh` creates local file fixture and proves correct digest accepted and wrong digest rejected (`:19-25`). | Wrong digest rejected; no output artifact on mismatch per `scripts/lib.sh:21-24`. | Existing hermetic fixture. |
| Credential source scan | `tests/selftest.sh` scans script/spec/doc literals (`:27-32`). | No literal assignment found. | Existing narrow static check; does not prove runtime argv/log hygiene, history absence, or bundle deletion. |
| Board JSONL validity (read-only) | `scripts/boardctl validate` | `RESULT: OK` or explicit validation failure; no board mutation. | Existing external boardctl wrapper; command availability is prerequisite (`scripts/boardctl`; `docs/BOARD.md`). |
| Whitespace and patch hygiene | `git diff --check` | Exit 0, no whitespace errors. | Runnable local gate. |
| Configured shell lint | `bash -n` for every tracked shell file (use the repository's actual configured shell syntax lint if one is defined; do not substitute a guessed linter). | Exit 0 and exact checked paths. | No separate shellcheck configuration established by this spec; shellcheck availability/configuration must be discovered, not assumed. |
| GitReins working-tree guard | `timeout 900 gitreins guard` on staged intended changes; inspect full stdout/exit and require all configured lanes actually ran. | PASS, not `DEGRADED PASS`; no skipped required gates. | Must run for this commit. If timed out/unavailable/skipped, disclose; do not relabel as green. |
| `--check` purity and fail path (future hermetic test) | Run each lifecycle checker twice against temporary HOME/config fixtures: once valid, once with one required prerequisite absent; snapshot filesystem before/after check. | Valid fixture passes; invalid fixture fails with measured reason; both leave byte-identical filesystem and no processes. | Not yet implemented; required before declaring new `--check` contract implemented. |
| `--apply` idempotence (future hermetic test) | Fake provider/Bunker adapter with a recorded operation ledger; apply twice; assert second run performs zero create/install/append mutations and exits 0. Inject failure after each layer. | Correct transition and verification after each mutation; failures stop before ready; retry does not duplicate resources or overwrite user work. | Not yet implemented; no actual Bunker API assumed. |
| Host-profile matrix (future hermetic test) | Fixture each allowlisted profile and unknown distro/arch; no external calls. | Every supported profile passes; unknown profile fails closed. | No profiles currently certified: NOT VERIFIED. |
| Manifest (future hermetic test) | Schema-valid/invalid fixtures; existing wrong-project manifest; atomic-write failure injection. | No secret fields; exact identity binding; bad input rejected; existing manifest preserved on failure; no partial manifest. | Current output schema mismatch/unvalidated (`project-node.sh:107-119` vs `specs/NODE.md:5-17`). |
| Bundle handling (future hermetic test) | Synthetic non-secret file with mode/owner/path variants; capture test child argv, environment allowlist, stdout/stderr and filesystem after success/failure. | Exactly one mode-600 regular bundle accepted; wrong mode/symlink/duplicate rejected; sentinel absent from argv/logs; bundle absent after all exits; incomplete deletion quarantines. | No bundle transfer/consumer exists; BLOCKED. |
| Supervisor (future hermetic test) | Fake worker/harness executables return healthy, crash, timeout, and restart-loop responses under a fake service adapter. | Bounded retries, correct state change, stop-intake on threshold, no secret logs, idempotent stop. | Supervisor absent; service-manager capability NOT VERIFIED. |
| Renewal/destroy/rebuild adapter (future hermetic test) | Fake adapter advertises capability on/off; inject timeout, wrong handle, stale read-back, and revocation failure. | Unsupported returns BLOCKED without mutation; supported operations are scoped/idempotent; unknown read-back never yields ready/destroyed. | Bunker capabilities NOT VERIFIED; no live command. |
| Actual disposable-host integration (not run in CF-017) | Only after explicit owner authorization, selected profile, and approved credential channel exist; use dedicated disposable node and synthetic Crier message. | Install/configure/check → Crier round trip → host-recomputed artifact digest → renewal if supported → destroy/revoke read-back → rebuild with fresh identity. | BLOCKED; no live infrastructure or secrets touched. |

The current `tests/selftest.sh` also checks local board JSONL parseability (`:34-42`) and the
board wrapper fail-closed behavior (`:44-52`). It is narrow and does not prove installation,
secret deletion, supervisor behavior, live host compatibility, Crier, scheduler, or end-to-end
execution. Future implementation MUST add hermetic test fixtures before adding live gates; every
check must have a negative arm as required by `AGENTS.md:28-30`.

## 12. Open implementation gates

The following are explicit blockers, not inferred support:

1. Name and test at least one exact Bunker Linux host profile; current platform matrix is empty.
2. Establish an authorized, read-only target inspection and an approved provider adapter contract;
   document real capabilities and error/read-back semantics without guessing Bunker CLI syntax.
3. Design and test secure delivery of a Crier-only mode-600 bundle, including guaranteed deletion
   and external revocation read-back.
4. Resolve inference without copying provider/operator keys onto the worker; until then Hermes
   task execution is BLOCKED even though an adapter install was recorded.
5. Implement node-local bus worker/supervisor and prove start/stop/restart/quarantine behavior on
   the selected profile.
6. Make checks pure and installs idempotent; reconcile the current manifest schema and atomicity;
   resolve unsafe shell construction and warning-only auth checks in the implementation phase.
7. Implement independent Crier dispatch/result validation and mandatory host-side artifact digest
   verification before scheduler admission.
8. Establish explicit renewal capability, destructive-operation authorization, revocation, and
   rebuild rules. Current TTL `6h` does not establish renewal semantics.

Until each relevant gate is implemented and measured, lifecycle status remains BLOCKED/NOT
VERIFIED. This specification is not a deployment receipt.

## 13. Source index

- `AGENTS.md:24-50,64-89` — design authority, check/idempotence/no-root/download/credential/disk rules and command inventory.
- `specs/NODE.md:1-54` — node manifest, layers, laws, disk floor, failure semantics.
- `specs/ENVELOPE.md:1-68` — dispatch/result, reserved fields, idempotency and acknowledgement contract.
- `specs/HARNESS.md:1-46` — harness contract and recorded/unverified adapter state.
- `docs/DESIGN.md:24-74` — node model, bus-first work path, ownership and failure model.
- `docs/OPERATIONS.md:1-188` — current operational boundaries, missing lifecycle operations, secure bundle gap, test and command inventory.
- `docs/THREAT-MODEL.md:1-111` — trust boundaries, existing control limitations, abuse cases and fail-closed rules.
- `docs/PRD-code-factory.md:7-34` — CF-101..CF-112 acceptance requirements, including credential bundle and destroy/recreate.
- `scripts/bunker-server-install.sh:1-66`, `scripts/node-create.sh:1-66`, `scripts/project-node.sh:1-128`, `scripts/verify-node.sh:1-75`, `scripts/lib.sh:1-57`, `scripts/harness/install-hermes.sh:1-75`, `scripts/harness/install-opencode.sh:1-38`, `scripts/harness/install-claude-code.sh:1-44` — current implementation evidence and gaps.
- `tests/selftest.sh:1-56` — existing hermetic checks and limits.
