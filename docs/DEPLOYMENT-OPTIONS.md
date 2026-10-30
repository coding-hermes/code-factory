# Deployment topology and provider interfaces

Status: decision record for CF-016. This is an architecture recommendation, not an infrastructure deployment receipt. No cloud provider, production topology, storage service, or live deployment is selected or verified here.

## Decision summary

Recommend a provider-neutral v1 deployment model built around isolated, disposable per-project worker hosts (Bunker-managed hosts or equivalent VMs), with the existing control host and scheduler/Crier/task-router remaining separate control-plane services. Use a thin Terraform root configuration to compose small provider-specific modules only when an operator has selected a provider and supplied its requirements. Do not require Kubernetes or Argo CD for v1. Keep durable state and artifact storage behind replaceable interfaces; exact storage selection and acceptance are CF-019.

This recommendation minimizes new operational machinery while preserving an explicit migration path. It is not authorization to provision a Bunker host or to choose a VM/cloud vendor. The current repository already defines one node as one bunker agent, project, and repo, and assigns dispatch, transport, and model choice to external services ([DESIGN](DESIGN.md), [NODE](../specs/NODE.md), [PRD](PRD-code-factory.md)).

## What is owned where

| Plane or component | Responsibility | Owner / boundary |
|---|---|---|
| Foreman and verification | Design work; inspect returned commits and artifacts; decide whether evidence is acceptable | Code Factory operating process on the control host. A worker's self-report is not acceptance evidence. |
| Node factory | Node manifest, user-space provisioning/checks, repo+harness setup, node health and result evidence | Code Factory. It must honor `specs/NODE.md`, `specs/HARNESS.md`, and the no-root/idempotence/digest rules in `AGENTS.md`. |
| Lane scheduling and admission | Which lane runs and when, concurrency/admission/cooldown | Scheduler project. Code Factory consumes its API/contracts; it does not own scheduler policy or live scheduler configuration ([SCHEDULER-ADMISSION](SCHEDULER-ADMISSION.md), [AGENTS](../AGENTS.md)). |
| Dispatch and reply transport | Durable delivery of the versioned command/result envelope | Crier. Envelope vocabulary and consumer behavior are specified in [`specs/ENVELOPE.md`](../specs/ENVELOPE.md); Code Factory must not duplicate transport or bypass its guard. |
| Model/provider routing | Select requested model/provider for a lane and expose served identity when available | task-router. Harness adapters consume the chosen route; neither Terraform nor Crier should choose the model ([PRD](PRD-code-factory.md), [DESIGN](DESIGN.md)). |
| Deployment lifecycle | Create/update/destroy compute and networking; optionally install a Kubernetes control plane | A deployment-provider adapter/module, invoked by an authorized operator or later automation. This task does not implement or authorize it. |
| Durable records and artifacts | State needed after a worker is destroyed; returned artifact bytes and verified digests | Boundary to be specified in CF-019. Control host/Code Factory verifies artifacts; workers cannot be the sole authority for their persistence or digest. |

A Kubernetes control plane, if later adopted, is infrastructure for running workers; it does not replace the scheduler's lane/admission authority, Crier's message authority, or task-router's model-routing authority.

## Deployment alternatives

| Option | Advantages | Costs and risks | Decision trigger |
|---|---|---|---|
| Standalone Bunker-managed hosts / VMs | Closest fit to the current one-agent/one-project node model; per-host failure and disk use are attributable; simple destroy/rebuild boundary; avoids requiring a cluster control plane. Bunker documents per-agent Linux-user isolation, separate homes/SSH keys, rootless Docker, and resource limits ([Bunker project](https://github.com/deployBunker/bunker)). | Host lifecycle, patching, quotas, networking, and replacement remain operator/provider concerns. A VM is not automatically isolated merely because it is remote. Capacity planning and host-loss recovery remain necessary. | Recommended v1 when workloads are modest enough for discrete hosts and operations can tolerate host-level provisioning. Revisit when measured queue delay, host count, or isolation requirements exceed the operational capacity of the Bunker/VM path. |
| Kubernetes / EKS | Declarative scheduling and controllers; standardized workload packaging; EKS manages the Kubernetes control plane and offers managed or self-managed worker-node choices ([EKS concepts](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-concepts.html), [EKS architecture](https://docs.aws.amazon.com/eks/latest/userguide/eks-architecture.html)). | Adds cluster lifecycle, IAM/network policy, admission, node pools, upgrades, observability, and workload-security responsibilities. EKS is specifically an AWS choice and must not be implied as the default. Managed control plane does not mean managed application or worker security. | Consider only after a named operator selects AWS (or another Kubernetes provider), workload scale/multi-tenant policy is measured, and the team explicitly accepts cluster operations and cost. A requirement for Kubernetes-native scheduling/controllers is a further trigger. |
| Argo CD / GitOps | For Kubernetes only, reconciles declared desired state from Git and surfaces drift; deployment history can be tied to Git revisions ([Argo CD overview](https://argo-cd.readthedocs.io/en/stable/)). | Not a compute provider and not a scheduler replacement. Adds another service, access boundary, reconciliation behavior, and operational path; applying it before Kubernetes would be unnecessary. Git credentials and sync policy require explicit design. | Optional after Kubernetes has been selected and operators want continuous declarative reconciliation, drift visibility, and a reviewed Git-based release process. Keep manual/CI apply as a valid alternative for a small v1. |

These options are architectural tradeoffs, not a cost comparison. No current price, regional availability, capacity, or service-level commitment was established; obtain a dated provider quote and owner approval before procurement.

## Logical topology and state classes

```text
Control host / control plane
  Foreman + Code Factory verification and node lifecycle client
  Scheduler (external) ── chooses lane/turn
  task-router (external) ── chooses model/provider
  Crier (external) ── durable command and result transport
             │ private authenticated path; envelope is versioned
             ▼
Disposable worker boundary (one project/repo/harness per node)
  node agent + harness + isolated repo checkout + per-dispatch scratch
             │ result envelope and artifact bytes
             ▼
Control-side verification: recompute digests; accept/reject independently
```

| Data class | Proposed lifetime and treatment | Recovery rule |
|---|---|---|
| Control-plane configuration | Durable, reviewed source/config for the selected deployment; secrets are references or runtime injections, not checked-in values. Scheduler/Crier/task-router configuration stays with those owners. | Reconstruct from reviewed configuration and the owning control-plane services. Do not make workers authoritative for it. |
| Worker host and harness process | Disposable. One project/repo/harness identity per node, with resource limits and a bounded lifecycle. | Quarantine/unroute first, capture required evidence, then replace the host and re-run checks. Re-admit only after an end-to-end round trip. |
| Durable state | Small records that must survive worker destruction: dispatch identity/idempotency, status, node manifest/provenance, and accepted result metadata. Exact database/service and retention policy are unknown and belong to CF-019/implementation. | Back up and restore independently from a worker host; define RPO/RTO before production use. |
| Scratch/workspace | Repo checkout, per-dispatch branch/worktree, temporary files, and active job logs. Treat as ephemeral and project-scoped; do not place the sole copy of accepted work here. | Retry from pinned repo/ref and dispatch idempotency key. Before destroying a failed host, preserve uncommitted work if policy requires it; do not blindly reset or delete. |
| Caches | Reconstructable package/module/build caches. Scope by project and trust domain; never treat as canonical source or accepted output. Cross-project sharing is not assumed. | Evict or rebuild on corruption, trust-boundary change, or host replacement. Performance and isolation tests belong to CF-018. |
| Artifacts | Returned bytes plus declared digest/size and task/run provenance. Durable only after accepted upload to the selected artifact store; the exact store, retention, encryption, and quota are open under CF-019. | The control host retrieves bytes and recomputes each digest. Missing bytes or mismatch is FAIL; do not accept a worker-reported digest alone ([ENVELOPE](../specs/ENVELOPE.md)). |

### Storage choices deferred to CF-019

- Git reclone plus worker-local scratch has the smallest shared-storage dependency and makes disposable hosts straightforward, but increases clone/network work and does not by itself preserve uncommitted work or returned artifacts.
- A Hetzner Storage Box is a network-access storage product with supported protocols and documented limits; Hetzner notes that boxes are hosted on shared host servers and available throughput can vary ([Storage Box overview](https://docs.hetzner.com/storage/storage-box/general/)). Treat it as a candidate for selected durable files or backups only after testing latency, consistency, access controls, outage behavior, and recovery. Do not assume it is a low-latency POSIX workspace or select Hetzner as the deployment vendor.
- A NAS has operator-controlled placement and lifecycle but requires a separately owned availability, backup, networking, and maintenance plan; no NAS target or measurements are known.
- Kubernetes persistent volumes can be provisioned through storage drivers; for example, EKS documents EBS block volumes and EFS file-system integration ([EBS CSI](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html), [EFS CSI](https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html)). They are cluster/provider-coupled and add CSI, access-mode, performance, backup, and failure-domain decisions. Do not select a PV before the Kubernetes option is selected.

This section frames candidates only. CF-019 owns detailed criteria and the storage decision.

## Terraform module boundaries and interfaces

Terraform is an optional provisioning implementation, not the runtime contract. Follow Terraform's recommended composition style: keep modules small, expose explicit inputs/outputs, and pass dependencies from a shallow root rather than hiding network/identity creation inside a worker module ([HashiCorp module composition](https://developer.hashicorp.com/terraform/language/modules/develop/composition), [standard structure](https://developer.hashicorp.com/terraform/language/modules/develop/structure)).

Proposed module seams (no modules are implemented by CF-016):

| Module boundary | Inputs (illustrative contract) | Outputs (illustrative contract) | Must not own |
|---|---|---|---|
| `worker-host` provider adapter | project/node identity; size/profile; region/zone selected by owner; network/subnet/security references; image/version pin; disk floor; expiry/TTL; non-secret secret references | provider-neutral node handle; private endpoint/connection metadata; allocated disk and resource identifiers; lifecycle status | Scheduler admission, Crier envelope, inference/model choice, repo acceptance, secret values |
| `worker-network` | existing network/subnet IDs or explicit network parameters; allowed control-plane sources; egress needs | network/subnet/security-group references | Application-level authorization or public exposure by default |
| `node-bootstrap` | node handle; pinned bootstrap artifact digest; repo/ref/harness; secret reference identifiers; resource limits | measured check results, manifest identity, bootstrap status | Raw credentials in Terraform variables/state/user data/outputs; unverified harness support |
| `durable-storage` (CF-019) | selected backend, encryption/access policy, retention/quota, recovery objectives | storage endpoint/reference and tested capabilities | Scratch lifecycle or node-reported digest trust |
| `artifact-store` (CF-019) | backend, namespace, encryption and retention policy | upload/download interface and immutable object reference | Declaring an artifact valid without control-side digest recomputation |
| root/environment composition | selected provider and explicit module versions; references/outputs connecting modules; environment sizing | deployment inventory and outputs consumed by authorized Code Factory tooling | Provider selection by silent default; external scheduler/Crier/task-router state |

Provider interface principle: Code Factory lifecycle code should operate on a provider-neutral node handle and a small capability contract (`create`, `inspect`, `terminate`; optionally `renew` only where supported), while adapters map that contract to the selected provider's identifiers and errors. Artifact storage should likewise expose byte-oriented `put`, `get`, and metadata/head operations, with digest verification performed by the control host. Define failure states and capability negotiation explicitly; do not make absent capabilities look successful. Concrete schemas, error taxonomy, and acceptance fixtures need implementation/spec work beyond this decision record.

Terraform state can contain sensitive values. HashiCorp recommends remote state with access control/locking rather than version control; remote-state outputs may still grant readers access to the full state snapshot ([Terraform state](https://developer.hashicorp.com/terraform/language/state), [remote-state data source](https://developer.hashicorp.com/terraform/language/state/remote-state-data)). Therefore keep secrets out of input/output values where possible, use a secured backend with locking, restrict state readers, and do not expose secret-bearing state outputs as a routine cross-module API. Backend choice and bootstrap mechanism remain unknown until provider selection.

## Security and failure/recovery boundaries

- **Privilege:** preserve the repo's no-root rule. Bootstrap artifacts run as the node user; a requirement for root/apt is a blocker, not a permission to escalate ([AGENTS](../AGENTS.md), [NODE](../specs/NODE.md)).
- **Credentials:** never pass secrets as argv, place them in public Terraform state, user-data, logs, manifests, board rows, or artifacts. Pass references and retrieve values through an approved runtime secret path. The existing one mode-600 bundle requirement remains the contract; delivery/rotation is not proven by this architecture record ([AGENTS](../AGENTS.md), [OPERATIONS](OPERATIONS.md)).
- **Network:** workers need only documented control-plane and dependency access. Prefer private addressing and least-privilege ingress/egress; no public worker gateway is assumed. Exact firewall rules and identity/authentication design are unknown until providers and Crier transport are selected.
- **Isolation:** one project/repo/harness per node as the current baseline; untrusted tasks require a fresh dispatch workspace and explicit resource limits. A VM or Kubernetes namespace alone does not prove isolation. Validate actual UID, filesystem, process, network, and cache boundaries.
- **Provisioning failure:** failed or partial bootstrap remains quarantined and must not be scheduler-targetable. Preserve logs without secrets, inspect provider state, then retry idempotently or destroy only after evidence is preserved.
- **Worker loss:** message delivery may be retried; use the envelope's dispatch/idempotency identifiers, a fresh attempt workspace, and retain durable result state outside the worker. A result is not complete until delivered and its artifact bytes are independently verified ([ENVELOPE](../specs/ENVELOPE.md), [DESIGN](DESIGN.md)).
- **Control-plane loss:** scheduler/Crier/task-router are separately owned services; Code Factory can report dependency failure and avoid admitting work but cannot restore or silently reconfigure them. Retry policy and outage SLOs remain owner decisions.
- **State/artifact outage or corruption:** fail closed for acceptance; preserve queued work and retry after read/write verification. Restore from the selected backend's tested backup procedure. No RPO/RTO, retention, or backup service has been approved.
- **Kubernetes/Argo failure (if later adopted):** cluster API/control-plane or GitOps reconciliation outage blocks new deployments but must not silently mark a worker/result verified. Keep artifact/result records outside disposable pods; pin deployment revisions and require an explicit rollback procedure.

## Recommended v1 profile and decision triggers

1. Keep the existing control host and external scheduler, Crier, and task-router responsibilities as drawn in the repo design.
2. Use one disposable Bunker-managed host or VM per project/repo/harness, with pinned bootstrap inputs, user-space setup, private network access, measured checks, and explicit quarantine/teardown. The concrete provider and host size require owner selection.
3. Keep job scratch and caches local and disposable; reclone from a pinned repository ref when that is acceptable. Do not put canonical state, the only copy of work, or accepted artifacts on a disposable worker.
4. Introduce explicit durable state and artifact-store interfaces before depending on persistence, but defer the backend selection and detailed storage contract to CF-019.
5. Defer Kubernetes/EKS until an owner names the cloud/provider and the team has measured a need for cluster scheduling, workload density, or policy controls that outweigh cluster operations. Defer Argo CD until Kubernetes exists and continuous reconciliation is explicitly desired.
6. Do not provision, arm a scheduler target, move secrets, or call this profile live based on this record. Operational authorization and end-to-end tests are separate gates.

## Unknowns and owner decisions

- Cloud/provider, region, account/project, VM image, instance type, network topology, and procurement limits: **unknown / owner decision**.
- Bunker host lifecycle API, quotas, cleanup/renew semantics, failure guarantees, and supported environments: **not established by this record**; verify against the chosen Bunker deployment and CF-017.
- Artifact/object store, durable metadata store, encryption/key ownership, retention, quotas, backup/restore RPO/RTO, and data residency: **open for CF-019**.
- Cache service versus per-host caches, cache key/trust domain, and eviction: **open for CF-018**.
- Whether GitHub-hosted or self-hosted runners are required, and their identity/isolation lifecycle: **open for CF-018**.
- Terraform backend, state-locking implementation, CI identity/federation, and module publishing/versioning: **unknown pending provider and workflow decisions**. GitHub OIDC can provide short-lived provider credentials when configured, but the specific claims/policy must be selected and tested; it is not configured here ([GitHub OIDC](https://docs.github.com/en/actions/concepts/security/openid-connect)).
- Kubernetes/EKS cost, availability targets, cluster size, upgrade ownership, storage class, and operator skill/coverage: **not measured**.
- Argo CD project/repository ownership, sync mode, rollback policy, and secrets integration: **not selected**.

## Runnable validation plan

This document can be validated without provisioning. Run from the repository root:

```bash
git diff --check
tests/selftest.sh
scripts/boardctl validate
```

Those commands check whitespace, the repository's script/checker failure fixtures, and board JSONL validity; they do not validate a cloud deployment. After a provider and module implementation are separately approved, add a no-credentials fixture environment and run the following prospective gates:

```bash
: "${TF_ROOT:?set TF_ROOT to the approved Terraform fixture root}"
: "${PROVIDER:?set PROVIDER to the fixture provider name}"
terraform -chdir="$TF_ROOT" fmt -check -recursive
terraform -chdir="$TF_ROOT" init -backend=false -input=false
terraform -chdir="$TF_ROOT" validate
terraform -chdir="$TF_ROOT" plan -refresh=false -input=false \\
  -var-file="tests/fixtures/${PROVIDER}.tfvars" -out=/tmp/cf-plan
```

The implementation's CI must inspect the plan for unintended public ingress, root access, unpinned images/artifacts, secret-bearing state/outputs, and resources outside the fixture scope. Never apply the fixture plan to a live account. A later isolated integration test, in an explicitly authorized disposable account/project, must prove: create twice is idempotent; `inspect` reports measured node identity/disk/network; failed bootstrap remains un-routable; terminate removes only the owned worker; replacement can rebuild from pinned inputs; worker loss/redelivery is idempotent; an artifact round trip recomputes the expected SHA-256 on the control host; and negative cases (bad digest, missing permission, unavailable storage, invalid provider reference) fail nonzero without leaking secrets. These are future gates, not results of CF-016.

## Sources

Repository authority and current boundaries:

- [`AGENTS.md`](../AGENTS.md) — specs-first, no-root, checks, digest verification, secret rules, and ownership boundaries.
- [`docs/PRD-code-factory.md`](PRD-code-factory.md) — requirements and out-of-scope scheduler/model decisions.
- [`docs/DESIGN.md`](DESIGN.md) — control/node topology, responsibilities, round trip, failure model.
- [`specs/NODE.md`](../specs/NODE.md), [`specs/ENVELOPE.md`](../specs/ENVELOPE.md), [`specs/HARNESS.md`](../specs/HARNESS.md) — node, message, and harness contracts.
- [`docs/OPERATIONS.md`](OPERATIONS.md), [`docs/SCHEDULER-ADMISSION.md`](SCHEDULER-ADMISSION.md) — measured vs unverified operational claims and scheduler boundary.

External design references:

- HashiCorp, [Terraform module composition](https://developer.hashicorp.com/terraform/language/modules/develop/composition), [module structure](https://developer.hashicorp.com/terraform/language/modules/develop/structure), [state](https://developer.hashicorp.com/terraform/language/state), [remote-state data](https://developer.hashicorp.com/terraform/language/state/remote-state-data).
- AWS, [EKS Kubernetes concepts](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-concepts.html), [EKS architecture](https://docs.aws.amazon.com/eks/latest/userguide/eks-architecture.html), [EBS CSI](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html), [EFS CSI](https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html).
- Argo Project, [Argo CD overview](https://argo-cd.readthedocs.io/en/stable/).
- Hetzner, [Storage Box overview](https://docs.hetzner.com/storage/storage-box/general/).
- deployBunker, [Bunker project](https://github.com/deployBunker/bunker).
- GitHub, [OpenID Connect](https://docs.github.com/en/actions/concepts/security/openid-connect).
