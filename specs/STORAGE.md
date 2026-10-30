# SPEC — storage and host-loss recovery

Status: CF-019 contract. Only the local crash/reclone simulation in
`tests/recovery-contract.py` is implemented. No backend, mount, backup service,
installer recovery, Bunker operation or production disaster recovery is certified.

## Default and authority

Use Git reclone at a trusted full immutable commit into fresh worker-local job
scratch, with project/trust-scoped disposable caches per [BUILD](BUILD.md).
Do not require a shared writable checkout, NAS, Storage Box or Kubernetes PV.
Keep authoritative task records, accepted metadata and artifact bytes outside the
worker's host failure domain. This is a topology recommendation, not a claim
that an off-host persistence service has been deployed. Production admission is
BLOCKED until its owner qualifies persistence, access and restore.

[NODE](NODE.md), [ENVELOPE](ENVELOPE.md#correlation-and-idempotency),
[HARNESS](HARNESS.md#host-only-inference-custody),
[NODE-LIFECYCLE](NODE-LIFECYCLE.md#10-failure-quarantine-and-recovery) and
[deployment options](../docs/DEPLOYMENT-OPTIONS.md) remain authority. No change to
node URL/ref grammar, credentials, scheduler, Crier or task-router is implied.
A production recovery adapter must support immutable commit resolution separately
from the existing installer's branch-like ref input; no such adapter exists.

## State classification

“Durable” means must survive worker-host loss, not “a file happened to exist”.
“Reconstructable” requires surviving trusted inputs; “ephemeral” has no recovery
promise. None of these labels certifies a selected service's durability.

| Class | Classification and authority | Loss / acceptance rule |
|---|---|---|
| Source | Published Git objects and retained full commit refs: durable at approved origin; worker clone: reconstructable. | Retain accepted commits against branch deletion/force-push/GC. Fetch and verify the exact commit; never substitute current branch tip. Git LFS/submodules need separately pinned, retained bytes and qualification. |
| Unpushed commits, dirty/untracked edits | Ephemeral, potentially valuable but not recoverable from origin. | Preserve if accessible before teardown. After actual loss mark lost/unrecoverable; no inferred success or fake reconstruction. |
| Task state | Board/design history and control acceptance ledger: durable under their owning service; local job journal: not authoritative. | Dispatch/correlation/idempotency, attempt identity, pinned inputs, terminal decision and evidence references must outlive node. A queued dispatch is intent, not acceptance or proof of execution. |
| Pending/in-flight dispatches | Durable transport/control intent where the owning service guarantees it; process progress is ephemeral. | Unknown after loss until reconciled with delivered accepted results. Do not replay side effects blindly. Exactly-once is NOT guaranteed. |
| Artifacts | Accepted immutable bytes, sizes, digests and provenance: durable off-worker. Unexported job output: ephemeral. | Independent control-side read/hash before acceptance and after restore. Missing bytes, wrong size/digest or missing trusted metadata => FAIL. |
| Caches / tool installs | Reconstructable from verified source, lockfiles, tool/image pins and available dependencies; not canonical. | Cold rebuild; cache loss may hurt time, never correctness. An unavailable dependency blocks reconstruction. No shared venv/checkouts or cross-trust write root. |
| Logs | Sanitized accepted gate/result/audit logs: durable artifacts with retention policy. Temporary stdout/debug/process logs: ephemeral. | Export required evidence before accepting result; missing required logs fail verification. Never retain credentials/prompts by default. |
| Secrets | Host-only provider keys and recovery/key-management authority: durable in separately approved secret custody, never in Git/artifact/workspace/metadata. Node-scoped credentials: revocable ephemeral grants. | Operator must restore host custody via approved procedure and issue fresh scoped identity; no credential copying from lost workers. No secret reads/transfers in this fixture. |
| Node manifest / configuration | Reviewed non-secret input pins and inventory: durable control record; node-local manifest: reconstructable, not current health. | New identity and independent checks required; restoring old manifest does not establish readiness. |

## Storage alternatives

All latency and availability below are qualitative mechanisms, NOT measured
SLOs, benchmarks or service guarantees. No current prices are claimed. Compare
cost drivers with a dated quote and a workload measurement before procurement.
Primary sources were fetched on 2026-10-30; source links are not deployment proof.

| Choice | Latency / availability | Credentials / trust | Cost drivers | Portability / failure domain |
|---|---|---|---|---|
| Git reclone + local scratch (default) [G] | Network fetch/cold dependency setup on replacement, then local file I/O. Origin/network outage blocks new recovery; existing complete clones can remain readable. Does not preserve dirty edits or artifacts. | Approved credential-free origin identity and full commit from control ledger; private repo auth needs a separately approved scoped path. No provider keys on node. | Clone bandwidth, local disk, duplicate dependency downloads, cold compute time, origin hosting/retention and separate evidence store. | Ordinary Git across providers; origin deletion/GC/account compromise is distinct from worker loss. Pin alone is not object retention. Local clones must not borrow lost-worker objects. |
| Hetzner Storage Box [H] | Network round trips per operation; host bandwidth is shared and variable. RAID/checksums protect disks, not host/site/account loss. Snapshot data remains on the Box. No workspace latency or availability measured. | Sub-account confined to subdirectory; main account can access all. Independently verify SSH host key, encrypted protocol, scoped identity/revocation; never embed credentials in commands or source. No mounts configured here. | Capacity tier, snapshot changed blocks, transfer/network path, client operations, independent backup and restore testing. Obtain quote; no invented price. | Standard transfer protocols aid export; not automatically a low-latency POSIX build disk. Several disks on one host, plus network/provider/account are correlated failure domains. Same-Box snapshots are not independent backups. |
| Operator NAS [N] | LAN proximity may reduce RTT; metadata workloads, link saturation, outage/reconnect and locking behavior require measurement. Availability depends on appliance, power, network and operator coverage. | Per-project/trust export and least-privilege principal; encrypted authenticated transport, ACLs, server identity and revocation need qualification. Avoid globally writable shared roots. | Appliance/disks, replication, power, network, maintenance/on-call, backup copies, capacity and restore labor. | Protocol export can be portable, appliance snapshots/ACLs may not be. A NAS on the worker host or same power/site cannot cover that failure. RAID is not a backup. |
| Kubernetes PV / EKS [K,A] | Pod-independent volume lifetime, not automatic cross-host/site durability. Local PV has node affinity; remote driver attach/topology/IOPS/throughput constrain recovery. No mount/failover time measured. | Kubernetes RBAC, CSI controller IAM/secret custody and workload authorization; no cloud credentials in job artifacts. PV access modes are not a substitute for tenant authorization. | Cluster/CSI operations, allocated capacity, provisioned IOPS/throughput, snapshots, data transfer and regional replication. EKS adds provider-specific costs. | PVC API is portable; StorageClass/driver/topology and snapshot restore are backend-specific. Delete reclaim policy can delete underlying storage; Retain needs explicit operator recovery. RWO is single-node mounting, not single-pod fencing. Multi-writer filesystems require explicit support. |

[N] is an operator-owned design alternative, not a named appliance or a measured
NAS service. [K] covers NFS-backed PVs and local PV affinity. A PV does not turn
NAS, local disk or EBS into a multi-site backup. EBS CSI requires IAM and a
snapshot controller for snapshot functionality [A]; Kubernetes selection remains
conditional per CF-016. No AWS/Hetzner vendor is silently chosen.

### Adoption triggers

Retain local scratch even when introducing durable shared storage. Adopt an
artifact/record backend independently from sharing job filesystems.

1. Measure cold clone/install time, bytes and recovery duration for the actual
   repository; adopt scoped remote caches only if repeated cold-start cost
   breaches an owner-approved budget and warm-hit/isolation tests improve it.
2. Consider Box/NAS for off-worker evidence/backup when volume or multi-host
   retrieval exceeds the approved control-store capacity/retention budget. Name
   a storage owner and qualify identity, encryption, read-after-write, atomic
   publication, concurrent writes, outage, quota, corruption and independent
   restore before depending on it. Shared writable source trees remain denied.
3. Consider PVs only after Kubernetes is explicitly selected and a named
   workload needs persistent volumes. Pin StorageClass/CSI, topology, reclaim
   policy, fencing, access modes and independently restorable snapshots; test
   loss of pod, node, volume and cluster as separate failures.
4. If agreed RPO/RTO or site-loss requirements exceed a single durable host's
   capability, adopt an independent replicated/backup failure domain and repeat
   restore drills. A shared mount alone does not satisfy this trigger.

No thresholds, SLOs, retention or procurement budget have been approved. Record
those decisions, not arbitrary numbers, before production storage acceptance.

## Durable acceptance and trust

Normative future publication order: retain commit at approved origin; upload
immutable artifact bytes under project/dispatch/attempt/object identity; control
retrieves exact bytes and recomputes digest/size against the accepted expectation;
then atomically publish a durable accepted record with full commit, repository,
dispatch/idempotency/correlation ids, attempt, artifact references/digests/sizes,
gate evidence and decision provenance. Read back the record and referenced bytes
before declaring accepted. A partially uploaded object or pending record never
means completed. No cross-store transaction or publisher is implemented here.

The control ledger's authentication/authorization and backup/witness protect the
expected digest. A worker-supplied digest paired with worker-supplied bytes is
not independent expectation. Protect against rollback/freshness as well as byte
corruption in production. A trusted checksum does not prove semantic correctness,
malware safety, serving-model identity, or validity of the original acceptance.
Storage credentials are not provider keys, and require separate authorization.

## Recovery protocol

1. Deny admission to lost/uncertain node through the owning operator path; retain
   evidence and reconcile old identity/lease. No automatic external mutations
   are provided here. A partitioned node may still be alive: fence before retry.
2. Read trusted durable input and acceptance records. Verify their integrity,
   identity and freshness against control authority. Missing/corrupt records
   mean UNKNOWN/BLOCKED, never create defaults from scratch-worker output.
3. Reconcile dispatches: accepted record plus available verified commit/artifacts
   can be recovered without re-execution. Pending/no terminal record is UNKNOWN;
   consult Crier/control owners and external side-effect witnesses, then authorize
   a new attempt only after deduplication/fencing. Do not turn retries into an
   exactly-once promise. Local process completion is not accepted result delivery.
4. Allocate fresh identity and fresh workspace; retrieve exact retained full
   commit from approved origin, verify commit object/HEAD/cleanliness. No forced
   reset of surviving edits, no shallow branch-tip substitution, no object
   alternates dependent on lost storage. Restore pinned tools and cold caches
   only after their own verified input gates. Do not execute restored source as
   part of this local proof.
5. Control independently retrieves accepted artifacts, hashes actual bytes and
   checks trusted expected size/digest. Missing commit/object/artifact/metadata
   fails nonzero; do not repair by computing a new expected hash from suspect
   bytes. Unknown or lost unpushed changes are explicitly unrecoverable.
6. Repeat validation/recovery without changing durable records or rewriting a
   correct recovered workspace. A wrong/dirty existing destination refuses.
   Full lifecycle/gateway/bus/artifact checks and owner admission read-back are
   still required for a real replacement; installers do not implement this.

## Executable local contract

`python3 -B tests/recovery-contract.py` uses only stdlib plus real Git. It owns a
private temporary tree with separate `durable`, `control` and `scratch` roots.
It publishes a tiny source commit to a bare origin, independently accepts fixed
artifact bytes and pins metadata SHA-256 in control memory before loss. It
creates unpushed/dirty work and a pending job, deletes ONLY its own scratch tree,
and recovers the older full accepted commit into a fresh workspace even after
origin main has advanced. The control-side verifier rehashes actual artifact
bytes against the previously pinned digest, not a freshly derived expectation.

The verifier is a fixture function, not a production recovery CLI or node
adapter. Its child mode is test-only. Synthetic local paths are intentionally
outside NODE's production URL grammar; NODE and installers remain unchanged.
Git runs with private HOME, no global/system config, hooks/templates disabled,
no inherited Git/credential environment and only file transport. No credentials,
network backend, package installs or workload execution are involved.

Tests require real successful recovery, byte/inode/mtime-stable repeat, a second
fresh recovery, missing-commit failure, changed/missing artifact failure,
corrupt/missing/structurally invalid metadata failure, trust-pin rejection and
unknown/unrecoverable outcomes. Errors must match exact intended failure codes,
not merely nonzero syntax/import/bootstrap failures. Semantic private-copy
mutations must make ordinary tests fail, and a disposable copy of the actual
selftest must fail when the recovery contract fails. See the runnable procedure
and limitations in [STORAGE-RECOVERY](../docs/STORAGE-RECOVERY.md).

This simulates worker-host loss by directory deletion on ONE local filesystem.
It proves no independent-disk durability, power-loss/fsync semantics, live
failover, remote locality, real credentials, backups, production RPO or RTO.

## Production decisions still required

Owner must approve repository/object retention (including unreferenced commits),
metadata/artifact/log retention and deletion, privacy/data residency, encryption
and key recovery, quotas, storage procurement, independent backup failure domain,
restore drills and numeric RPO/RTO. RPO is measured from last durable publication;
unpublished work has no recovery promise. RTO includes fencing, allocation,
clone, cold dependencies, verification and admission, not just clone time.
Control-host loss requires independent control records/secret custody backups;
this fixture simulates worker loss with control/durable roots surviving only.

## Primary sources

- [G] [Git clone](https://git-scm.com/docs/git-clone): no-local avoids local-copy optimizations; shared/alternates clones depend on source object retention.
- [H] [Hetzner Storage Box overview](https://docs.hetzner.com/storage/storage-box/general/): RAID disks on one host, sub-account scope, protocols, same-Box snapshots and shared variable throughput.
- [K] [Kubernetes persistent volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/): lifecycle, reclaim policy, access modes and node affinity. [Storage classes](https://kubernetes.io/docs/concepts/storage/storage-classes/) define backend provisioner/topology policy.
- [A] [Amazon EKS EBS CSI](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html): IAM, snapshot-controller and platform constraints.
