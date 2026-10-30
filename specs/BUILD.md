# Build, package-cache, and GitHub runner platform

Status: CF-018 design contract, 2026-10-30. Normative requirements below are not a
runner installation, cache-service deployment, or live remote-placement receipt.
Only the minimal local policy helper and hermetic tests described below are
implemented by this row. All production integrations remain NOT VERIFIED.

## Authority and v1 decision

[Deployment options](../docs/DEPLOYMENT-OPTIONS.md#recommended-v1-profile-and-decision-triggers)
CF-016 recommends one disposable project/repository/harness worker boundary,
provider-neutral compute, and reconstructable project/trust-scoped caches.
[NODE](NODE.md#laws), [NODE-LIFECYCLE](NODE-LIFECYCLE.md#3-lifecycle-invocation-and-shared-semantics),
[ENVELOPE](ENVELOPE.md#result-node--reply_to-inbox),
[HARNESS](HARNESS.md#the-contract-every-adapter), and
[DESIGN](../docs/DESIGN.md#4-what-runs-where) remain authority. This extends the
build layer, not harness/model selection, scheduling, or transport. Existing
lifecycle source-baseline line citations are historical: this contract uses
section links and named source functions rather than copying those offsets.

V1 default: builds execute on an explicitly admitted remote project node;
package/module and build caches live on that node, never on the control host.
Use fresh per-job workspaces and trust-separated cache directories. On worker
loss, cold rebuild is correct. Do not require a dedicated shared build/cache
service, Kubernetes, a registry, or a particular cloud vendor. GitHub-hosted CI
is an additional execution mode, not a replacement for Crier dispatch. Public
untrusted PRs use hosted isolated VMs with no private cache or infrastructure
access; self-hosted untrusted execution is disabled in v1.

CF-019 owns durable shared storage, artifact/log persistence backends, retention,
backup and restore objectives. This spec requires evidence export interfaces but
does not select those backends, create a shared mount, or resolve CF-019.

## Runner modes and support boundaries

“Supported mode” here means specified interface, not a certified installation.
No self-hosted OS/image/profile is certified by NODE-LIFECYCLE. Missing required
capabilities block admission; a passing version probe does not certify a runner.

| Mode | Policy and registration | Isolation and lifetime | Qualification |
|---|---|---|---|
| GitHub-hosted standard VM | Workflow selects an approved explicit OS label and pinned tool/action versions; GitHub owns registration and host provisioning. No factory registration credential is needed. | Fresh VM per job except the documented single-CPU exception [G1]. V1 excludes that shared-VM container class. Default untrusted public PR path; no secrets, private dependencies, trusted cache mounts, or control-network access. | Linux VM first; Windows/macOS hosted modes are valid optional profiles only after their native-tool/key tests pass. Record actual image release, architecture and runtime, not merely `*-latest`. No hosted run observed by CF-018. |
| Self-hosted ephemeral, repository scoped | Authorized external registrar requests repository JIT configuration via the GitHub REST API [G2]; pins runner artifact and SHA-256, unique run/attempt name, repository and allowed labels/group. | Exactly one job, then de-register AND destroy the job boundary; a stopped/offline registration is not cleanup. One project/repo/harness per node; trusted reviewed jobs only. | BLOCKED pending approved registration-material delivery and no-root host qualification. No real registration or runner start is implemented here. |
| Self-hosted organization group | Same ephemeral/JIT lifecycle; registrar restricts group access to the exact approved repository/workflows. Labels route jobs but do not authorize access [G3]. | No shared cross-project worker home, cache or daemon. Each allocated worker is still single-project and single-job. | Deferred until group access policy and negative routing tests are observed. Enterprise-wide sharing is not a v1 default. |
| Persistent multi-job self-hosted | Not admitted. | Cleaning a checkout is not a security reset; process/credential contamination can survive [G4]. | Deferred, including public-fork jobs on self-hosted infrastructure. |

GitHub recommends ephemeral runners and assigns them one job; its automatic
registration removal does not wipe disks [G3]. JIT runners perform at most one
job, but reused hardware still requires a clean environment [G4]. Single-job
lifetime belongs to the runner/job boundary; a project cache may survive in a
separately protected project cache area only for the same trust scope. Untrusted
jobs must never share the Bunker UID/home or container daemon of a trusted job.

### Registration and credential boundary

The registrar, outside the worker, owns GitHub App/operator credentials and the
minimum repository Administration permission for repository runner registration
[G2]. Do not copy those credentials, provider keys, inference keys, reusable
control keys, or a PAT into a node. NODE-LIFECYCLE's single Crier-only mode-600
bundle is unchanged; it is not an avenue for runner registration secrets.

JIT configuration contains sensitive runner authentication material. A future
separate approved least-privilege delivery design must define its one-use,
short-lived lifetime, exact repository/job binding, mode-600 private file or
protected input channel, consumption/deletion, log/argv exclusion, revocation,
and read-back. Until that design is approved and tested, self-hosted runner
registration is BLOCKED. Do not use the upstream illustrative `--token` argv
example: it violates this repository's credential-argument rule. Job-scoped
GitHub runtime credentials, if required, need the same explicit approval and
least privilege; they are not operator credentials and are not implicitly
allowed by this spec. No secret-bearing runnable examples are provided here.

### Ephemeral lifecycle, quotas, and cleanup

The future runner controller must implement this state machine without changing
external scheduler admission policy:

1. Validate authorized repository, reviewed workflow/ref, trust, run/attempt,
   host identity, resource budget, pinned image/toolchain, runner version support,
   disk floor and lifecycle `ready`. Reject unknown inputs before registration.
2. Reserve a slot atomically by repository/run/job/attempt. Repeated reconciliation
   reuses that reservation, never registers a duplicate runner. Register only the
   intended repository/group and read back id, labels and ephemeral state.
3. Launch as the ordinary node user in a private fresh job directory. No root,
   sudo, apt, privileged container, host Docker socket, cross-project bind mount,
   or control-host execution fallback. Missing user namespaces/cgroups/rootless
   runtime or required system libraries blocks that profile.
4. Accept at most one matching job. Bind the job to its resolved commit, workflow
   digest, runner id and admission inventory. Capture measured host/runtime,
   command exits, cache decisions, resource usage and artifact hashes.
5. On success, failure, cancellation or deadline: stop intake; preserve sanitized
   logs/results via the future CF-019 interface; terminate the job process tree
   and rootless containers; revoke/delete job credentials and scratch; verify
   GitHub registration absence and exact resource termination independently.
6. On partial teardown or lost heartbeat: mark quarantined, deny new admission,
   reconcile GitHub inventory against owned runner ids and run reservations;
   expire the allocation and delete only owned resources after preserving evidence.
   Removal/read-back failure stays quarantined, never “clean”. Repeating cleanup
   against absence is success without affecting other projects.

Proposed v1 factory limits (not GitHub service limits): one active job per node
and per project; up to four build processes/threads per job; wall budget at most
3600 seconds; registration-to-pickup budget 300 seconds; cleanup budget 300
seconds. A selected profile must explicitly supply positive CPU/memory/disk and
fleet slot budgets and validate them before launch; absent budget means deny,
not unlimited. GitHub-hosted concurrency/minute/spend limits and cache quotas
must be discovered for the actual account before enablement [G5]. Do not assume
free or unlimited capacity. Queue/budget exhaustion defers or refuses remotely;
it never schedules a heavyweight fallback on the control host. Cancelled jobs
release reservations only after teardown read-back. Stale reservations need
reconciliation, not blind deletion.

A local container pool means pre-pulled digest-pinned images on the remote worker
host, not containers on the control host. Allocate a fresh rootless job container
and private volume per job, restrict egress/resources, and reap both on every
terminal path. Shared hosts across trust classes require stronger qualified
isolation; rootless containers alone do not qualify hostile multi-tenancy.
Windows/macOS self-hosted profiles, privileged service-container workflows,
ARC/Kubernetes and persistent warm job containers are deferred.

## Package and build-cache ownership

The project owns lockfiles and build recipes in Git. The node owns disposable
cache bytes. A trusted admission service owns project/repository/trust/ref
classification and budget; job code cannot assign itself a trusted scope.
Separate filesystem principals or an enforcing broker must protect cache roots.
Hashing a namespace is collision avoidance, not authorization.

| Cache class | Owner and required path policy | Restore/verification policy |
|---|---|---|
| npm/pnpm dependency downloads | Pin manager version using project metadata; per-key npm `cache` / pnpm store under private node cache root. Recreate `node_modules` in job scratch. | Lockfile-frozen install; require integrity metadata. npm verifies insertion/extraction and offers `npm cache verify` [P1]. pnpm adapter qualification is prospective; no install ladder is asserted. |
| Python HTTP/wheels | Explicit `PIP_CACHE_DIR` (or approved uv cache path), pinned Python ABI, installer and build environment. Per-job venv, not a cached shared venv. | Hash-locked requirements; no credential-bearing index configuration in cache. pip wheel reuse can hide optional-native-build differences [P2], hence runtime/image/build recipe in keys. uv adapter not qualified here. |
| Go modules and compilation | Explicit `GOMODCACHE` and `GOCACHE` in separate cache-kind namespaces; never ambient user defaults. | `go.sum` verification, `go mod verify` for downloaded modules; compiler/OS/arch/flags/image included for build results [P3]. Do not claim test execution merely from a cached test result. |
| Rust/compiler caches | Explicit project/trust `CARGO_HOME` download area and separate `CARGO_TARGET_DIR`; compiler/linker/features/target pin required. | Locked dependency resolution/checksums; native cache adapter and sccache qualification deferred. Exclude registry credentials and checkout secrets. |
| Container layers | Rootless per-project/trust builder and digest-pinned base image; no shared daemon socket. | Local BuildKit first if qualified; external export/import must specify the exact scoped location [P4]. No credential `COPY`/`ARG`. Dedicated remote builders/registry exports deferred. |

No package manager, compiler, runner or daemon is installed by CF-018. These are
adapter obligations, not an assertion that all listed managers are present.
All tools must be user-space, artifact/digest pinned, idempotent, and checked
with measured values; missing capability is FAIL/BLOCKED. Root-owned system
dependencies cannot be silently installed to make an adapter work.

## Cache identity and trust policy

The minimal implementation in `scripts/build-policy.py` provides canonical keys,
write admission, verified opaque-byte put/get and placement admission. It is an
executable policy kernel, not a package manager or a remote-build service.
The trusted caller supplies this complete string-valued context:

| Field | Exact meaning |
|---|---|
| `project` | Stable factory project id. |
| `repository` | Credential-free canonical repository identity from admission, not an unvalidated clone URL. |
| `trust` | Exactly `trusted` or `untrusted`; determined by reviewed event/ref policy. |
| `ref` | Fully qualified ref scope; PR merge refs do not alias the base branch. |
| `runtime` | Exact compiler/interpreter/ABI/target versions, including native dependencies. |
| `platform` | OS release and architecture. |
| `manager` | Package manager or build engine name. |
| `manager_version` | Exact manager version. |
| `image_digest` | SHA-256 of qualified environment/image inputs, even for non-container profiles. |
| `lock_digest` | SHA-256 of all relevant lockfiles (canonical path/content ordering). |
| `build_digest` | SHA-256 of source tree, recipe, workflow, relevant environment/flags and build inputs. |
| `cache_kind` | `packages`, `modules`, `build`, or another explicitly named adapter class. |

Inputs must be present, nonempty, no whitespace controls or surrounding space;
trust and all three digests are validated; unknown fields fail. The canonical
UTF-8 JSON object uses sorted keys, compact separators and literal Unicode.
Namespace/key = `cf-build-v1/` followed by SHA-256 of that object. Every dimension
changes the namespace, including ref and runtime. This conservative v1 key
sacrifices reuse across source changes for isolation; future dependency-only
keys need a separate policy revision, not broad fallback prefixes.

Reads require the same exact namespace and expected payload SHA-256 from the
trusted caller's manifest/lock provenance. Writes require job trust == target
trust; untrusted-to-trusted and trusted-to-untrusted writes both fail. V1 does
not grant untrusted reads of trusted private bytes. A lower-trust job receives
only its own cache root and context, never a trusted root/manifest. Verified
public package downloads may be fetched independently, not mounted across trust.
An attacker able to replace both the payload and trusted expected digest defeats
integrity; protecting the caller and digest provenance is mandatory.

GitHub cache is repository/ref scoped, immutable per key, and supports prefix and
default-branch fallback; forks may read base-branch caches [G6]. Thus keys are not
an access-control mechanism there either. For hosted untrusted jobs disable
factory cache restore/save entirely in v1. For trusted workflows, use exact-key
restore and accept only a verified exact hit; no broad `restore-keys` or cross-OS
archives. A future adapter must reject prefix hits and bind saved provenance.
Never place secrets/private packages in GitHub caches readable by PR authors.
Use reviewed, commit-SHA-pinned actions; do not run untrusted checkout under
privileged `pull_request_target` or `workflow_run` triggers [G4].

### Minimal helper interface and failure semantics

Run `python3 scripts/build-policy.py OP` with one JSON request on stdin. OP is
`key`, `put`, `get`, or `placement`. `key` takes `context`; `put` additionally takes
`root`, `source`, `sha256`, `job_trust`; `get` takes `context`, `root`, `sha256`.
`placement` takes `weight` (`light`/`heavy`), `observed_host`, `control_host`, and
`admitted_hosts`. Returns one JSON record on success; validation, integrity or
admission failure prints `FAIL build-policy: REASON` to stderr and exits 1.
A missing entry returns `MISS` without creating directories. Put returns
`STORED` or `REUSE`; get returns `HIT` only after rehashing real bytes, with
`sha256` and `bytes`. The helper never executes a build command.

The cache root must already exist, be owned by the caller, private (no group or
other access), and contain no symlink path components. Entries are private
single-blob directories below the hashed namespace, never archives to extract.
Put validates the source and caller-supplied digest before mutation, writes an
exclusive temporary file then atomically publishes, and refuses corrupt existing
entries instead of overwriting them. Identical repeated put reuses bytes without
rewriting. Get is read-only; integrity failure is FAIL, not HIT. No archive path
traversal, shell evaluation or arbitrary job commands are supported. This small
helper assumes one serialized trusted writer per root and bounded small blobs;
production large-object streaming, concurrency, quotas, eviction and authenticated
remote access are future integrations, not implemented claims.

## Eviction and host-loss recovery

Cache size is not durability. Proposed v1 maximum is 5 GiB per project/trust root,
7 days since last verified use, with stricter host budget taking precedence.
The future cache owner measures bytes and free disk before each job/write,
evicts least-recently-verified unleased entries to stay within budget, and then
remeasures NODE's disk floor. Never evict an active lease or canonical source,
credentials, uncommitted work, accepted artifacts, or pending result evidence.
If the floor still fails, refuse new work with measured bytes; no unbounded
retry, broad home deletion, or control-host spillover. Disk limit checks, LRU,
leases and janitor behavior are prospective, not provided by the minimal helper.
GitHub cache eviction/storage/budget policy is independently platform-managed
[G6]; treat every restore as optional, and never rely on retention or a fixed
account quota for correctness.

Corruption: return FAIL, quarantine that entry, prevent reuse, independently
refetch verified dependencies/rebuild in a fresh namespace before retry. Never
“repair” by accepting a new checksum from the suspect worker. Host loss: discard
cache inventory, allocate a new qualified identity, reclone pinned source, restore
lockfiles/tool versions, re-download verified inputs, rebuild cold remotely, and
verify returned bytes on the control host. Cache outage may make a build slower;
missing trusted dependencies or integrity provenance must fail, not downgrade
security. Preserve dispatch idempotency and reconcile prior work per ENVELOPE;
caches are never the only copy of results. CF-019 must resolve durable evidence
availability before production teardown can be accepted.

## Dedicated service versus per-node caches

| Option | Advantages | Cost / trust / failure boundary | Decision |
|---|---|---|---|
| Per-Bunker/project-node caches | Existing ownership model, attributable disk and failure, no shared-service dependency, simple cold recovery. | Cold starts after host loss; duplicate downloads; protected cache area separate from job UID required for trusted reuse. | V1 default; qualification still required. |
| Dedicated remote build + cache service | Central scheduling of heavy builds, potential reuse across workers, centralized quota/metrics. | New authenticated API, tenant/trust authorization, digest provenance, eviction and availability operations; shared compromise blast radius; state/backend dependency overlaps CF-019. | Deferred. Revisit with measured cold/warm latency, bandwidth, hit rate and queue cost, plus isolation/security proof and an owner. |
| Registry/remote BuildKit or language cache service | Tool-native remote reuse, explicit import/export scopes [P4]. | Tool-specific keys, poisoning risk, secret-bearing layers, credentials and backend management. | Deferred adapters; no globally writable caches. |
| GitHub Actions dependency cache | Hosted and self-hosted workflow integration, platform-managed storage. | Branch/fork visibility and prefix fallback are broader than factory trust policy [G6]; limits/billing vary. | Optional trusted-CI adapter after exact-key/provenance tests; not factory durable storage. |
| ARC or container pool controller | Useful at measured scale; ARC is GitHub's Kubernetes recommendation [G3]. | Cluster operations and new isolation/lifecycle dependencies. | Deferred per CF-016; remote per-node rootless jobs do not require a cluster. |

## Placement contract and executable acceptance

All heavyweight work (dependency installation, compilation, image builds, full
suites, packaging) requires a nonempty measured execution-host identity different
from the control host AND present in trusted admitted inventory. Unknown, blank,
control-host, mismatched or missing inventory => FAIL before command launch.
`light` explicitly covers these shell/Python policy fixtures and control-side
artifact hashing only. Callers must not relabel heavy work as light. Hostnames in
untrusted job output are not attestation: future dispatch adapters must acquire
identity over the authenticated node channel and bind it to the result envelope,
then independently verify it on the control side. This helper tests admission
logic, not execution locality; no current dispatcher is wired to it.

`bash tests/build-contract.sh` exercises real helper filesystem operations with
small local bytes: cold MISS, STORED, warm HIT/REUSE without rewrite, stable
canonical keys, isolated project/repository/trust/ref/runtime/platform/manager/
version/image/lock/build/kind dimensions, denied cross-trust writes, corrupt
source/entry rejection, missing/invalid context, private-root/symlink refusal,
and heavy-placement rejection on control/unknown/not-admitted identity.
`bash tests/build-contract.sh --mutation-controls` copies the real helper into
temporary files, deliberately drops key dimensions, allows cross-trust writes,
bypasses integrity and permits control-host placement; each mutant must make the
normal tests fail. It also tests selftest failure propagation in a temporary repo
copy with a failing build-contract script, then reruns the clean contract. No
mutation changes the working helper or live state. `tests/selftest.sh` invokes
the clean contract and accumulates any failure into its nonzero exit.

Prospective infrastructure acceptance (NOT RUN by CF-018): authorized disposable
node only; never an unrelated lab host. Register one JIT runner, read it back,
run one pinned tiny job, reject another repository/job/trust, cancel/timeout a
job and verify process/volume/credential/registration cleanup. Enforce quotas and
failed-cleanup quarantine. Run actual manager cold/warm installs and remote
builds with measured cache hits/bytes, resource usage and host identity; change
every key dimension and verify isolation; corrupt bytes and deny trusted writes
from an untrusted job; destroy host and repeat cold recovery. Assert no build
process starts on the control host using launcher process/transport evidence,
not remote-looking labels. Prove identical artifact bytes with host-recomputed
hashes. These require approved credentials/profile/CF-019 interfaces and separate
implementation; local T3 tests do not satisfy live infrastructure certification.

## Sources

Authoritative external sources fetched 2026-10-30; upstream behavior is not proof
of this factory's deployment. Account limits/capabilities must be rechecked at
implementation time.

- [G1 GitHub-hosted runners](https://docs.github.com/en/actions/concepts/runners/github-hosted-runners): VM-per-job exception, OS modes, changing images.
- [G2 Self-hosted runner REST API](https://docs.github.com/en/rest/actions/self-hosted-runners#create-configuration-for-a-just-in-time-runner-for-a-repository): JIT configuration, permissions, runner inventory/delete surfaces.
- [G3 Self-hosted runner reference](https://docs.github.com/en/actions/reference/runners/self-hosted-runners): ephemeral single-job registration, routing/groups, updates, logs, ARC and non-Kubernetes alternatives.
- [G4 Secure use](https://docs.github.com/en/actions/reference/security/secure-use): untrusted checkout hazards, JIT isolation limits, least privilege, pinned actions.
- [G5 Actions limits](https://docs.github.com/en/actions/reference/limits): platform/account limits, distinct from proposed factory quotas.
- [G6 Dependency cache reference](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching): immutable keys, fallback, branch/fork access, eviction and configurable limits.
- [P1 npm cache](https://docs.npmjs.com/cli/v11/commands/npm-cache): integrity, verification, growth, reconstructability.
- [P2 pip caching](https://pip.pypa.io/en/stable/topics/caching/): HTTP/wheel reuse and optional-native-build caveat.
- [P3 Go build/test caching](https://pkg.go.dev/cmd/go#hdr-Build_and_test_caching) and [module verification](https://pkg.go.dev/cmd/go#hdr-Verify_dependencies_have_expected_content): cache invalidation and dependency verification.
- [P4 BuildKit cache backends](https://docs.docker.com/build/cache/backends/): explicit import/export locations, overwrite warning, secret handling.

Repository implementation references: `scripts/lib.sh::fetch_verified` and
`require_disk`; `scripts/project-node.sh` layer and manifest checks;
`tests/selftest.sh` failure accumulation; `scripts/build-policy.py` policy kernel;
`tests/build-contract.sh` executable acceptance. The row-specific command receipts
and AC matrix belong in [the CF-018 audit](../docs/audits/code-factory-CF-018-20261030.md).
