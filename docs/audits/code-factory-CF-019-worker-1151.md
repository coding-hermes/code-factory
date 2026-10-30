# CF-019 implementation worker evidence

Scope: storage/recovery contract and executable local crash/reclone simulation.
Branch: `wt/CF-019-1151`. Base: `24d19805583804f56626da31a42949bd4a594fd0`.
No board, wave, AGENTS.md, GitReins task/config, installer, scheduler, Crier or
router edits. No provider credential reads/transfers, provisioning, mounts,
service changes, actual host loss or production recovery certification.

## Acceptance map

1. `specs/STORAGE.md#storage-alternatives`: Git reclone, Hetzner Storage Box,
   operator NAS and Kubernetes PV/EKS compared on latency, availability,
   credentials, cost drivers, portability and failure domains. Primary Git,
   Hetzner, Kubernetes and AWS docs fetched with tools on 2026-10-30. No invented
   price, latency benchmark or availability promise. NAS is a design alternative,
   not a measured appliance. Storage Box snapshot page was fetched at its actual
   `/storage/storage-box/snapshots/` public route after an obsolete guessed
   subroute returned Cannot GET.
2. `specs/STORAGE.md#state-classification`: source/task/accepted metadata/artifact/
   cache/log/secret authority and lifetime; pending dispatches are not results.
3. `specs/STORAGE.md#recovery-protocol` and `docs/STORAGE-RECOVERY.md`: recovery
   order, protected control expectations, unknown in-flight work and unrecoverable
   unpublished edits; executable real-Git tests below.
4. Default: retained full Git commits, fresh local workspaces/cold caches, durable
   records and accepted bytes outside worker failure domain. Shared storage only
   after measured budget/retention/recovery requirements and owner qualification.
   No storage provisioning. Backend procurement, retention and numeric RPO/RTO
   remain explicitly unapproved, not fabricated decisions.

## Discovery and test development

Pre-design cached-answer discovery: POST to the documented local discover API
with `problem_class=git-reclone-host-loss-recovery` returned HTTP 404,
`{"error":"not_found","message":"problem class not found"}`. Corpus search
found no relevant host-loss/reclone answer. The case-insensitive nearby
`go-git-engine-stale-clone-origin-mismatch-silent-wrong-source-import` answer was
read; it discusses checking origin before reuse, not a host-loss solution.
Recovery checks its fixed origin on reuse. No genuinely nontrivial debugging was
needed, so no post-debug solution was submitted and no receipt is claimed.

Tests were authored before the fixture kernel. Initial positive test exited 1
because the kernel did not exist yet; that is only a development red, NOT a
meaningful recovery negative. After implementation, normal positives and precise
negative controls passed. Three compiling private semantic mutants provide the
behavioral red proofs: bypass trusted pin, bypass artifact integrity, substitute
origin/main for the pinned commit. They each cause unittest assertion failures,
not syntax/import/bootstrap errors. Working source was never mutated for proof.

## Focused command and real output

Command: `python3 -B tests/recovery-contract.py`
Exit: 0. Python 3.11.15, Git 2.53.0. Output excerpt from the actual captured run:

```text
observed semantic mutant=trust-pin assertion-failure exit=1
observed semantic mutant=artifact-digest assertion-failure exit=1
observed semantic mutant=pinned-checkout assertion-failure exit=1
observed selftest caller exit=1 recovery-child=23 failures=1
observed rejection=artifact_integrity exit=1
observed rejection=artifact_integrity exit=1
observed rejection=metadata_integrity exit=1
observed rejection=workspace_mismatch exit=1
observed rejection=workspace_mismatch exit=1
observed rejection=trust_pin exit=1
observed rejection=metadata_integrity exit=1
observed rejection=metadata_integrity exit=1
observed rejection=artifact_missing exit=1
observed rejection=commit_missing exit=1
observed rejection=metadata_missing exit=1
observed rejection=metadata_schema exit=1
observed rejection=metadata_schema exit=1
observed rejection=metadata_schema exit=1
observed rejection=metadata_schema exit=1
observed rejection=metadata_schema exit=1
observed rejection=metadata_schema exit=1
observed rejection=metadata_schema exit=1
observed recovery commit=607dca9f0de6761a91ceaf26df1e5c675d4e2ca2 sha256=b1330093b2bcc4d946a4f85ebf8ad9dabef6d5b81ff81fa003de883752663338 bytes=33 repeat=unchanged fresh=recovered pending=unknown unpublished=unrecoverable
Ran 13 tests in 42.406s
OK
```

The commit above is a synthetic fixture commit, NOT the implementation commit.
Fixture commit IDs vary with commit timestamps. The source actually recovered is
asserted equal to the full earlier accepted commit, not merely printed. Artifact
bytes and digest are recomputed by control code against a pre-loss expectation;
changing both metadata and artifact cannot replace the pinned trust source.

Named primary witness:
`tests/recovery-contract.py::RecoveryContract.test_recover_after_loss_and_repeat`.
It pushes accepted source to real bare origin, advances origin/main, creates a
provably absent-from-origin unpushed commit, dirty work and pending job, deletes
only temporary scratch, and checks fresh/repeat recovery and durable file
preservation. Test kernel: `tests/recovery-fixture.py::recover`.

## Full selftest and hygiene

Command: `bash tests/selftest.sh`
Exit: 0. Actual recovery section and terminal summary:

```text
11. Git crash/reclone recovery (hermetic local simulation only)
observed rejection=artifact_integrity exit=1
observed rejection=artifact_integrity exit=1
observed rejection=metadata_integrity exit=1
observed rejection=workspace_mismatch exit=1
observed rejection=workspace_mismatch exit=1
observed rejection=trust_pin exit=1
observed rejection=metadata_integrity exit=1
observed rejection=metadata_integrity exit=1
observed rejection=artifact_missing exit=1
observed rejection=commit_missing exit=1
observed rejection=metadata_missing exit=1
observed rejection=metadata_schema exit=1
observed rejection=metadata_schema exit=1
observed rejection=metadata_schema exit=1
observed rejection=metadata_schema exit=1
observed rejection=metadata_schema exit=1
observed rejection=metadata_schema exit=1
observed rejection=metadata_schema exit=1
observed recovery commit=7e812e8044faecc6d3c776c32ded720f329394bc sha256=b1330093b2bcc4d946a4f85ebf8ad9dabef6d5b81ff81fa003de883752663338 bytes=33 repeat=unchanged fresh=recovered pending=unknown unpublished=unrecoverable
Ran 11 tests in 2.594s
OK
  PASS  recovery contract
SELFTEST: PASS
```

The full command also ran the existing node, mutations, download, board wrapper,
build/cache and inference fixtures. Recovery mutations/caller propagation are in
the focused suite rather than recursively invoked by selftest.

- `git diff --check`: exit 0, no whitespace errors.
- `bash -n tests/selftest.sh`: exit 0.
- `git ls-files '*.sh' -z | xargs -0 -n 1 bash -n`: exit 0.
- `ruff check tests/recovery-contract.py tests/recovery-fixture.py`: exit 0,
  `All checks passed!`.
- `git diff --exit-code 24d1980 -- AGENTS.md .coding-hermes .gitreins/config.yaml specs/HARNESS.md scripts/node-contract.py scripts/node-create.sh scripts/project-node.sh`:
  exit 0. Protected board/config, host-only harness and node grammar/installer
  sources remain unchanged.

Foreman salvage: the implementation worker exited 130 before committing, leaving a coherent staged/unstaged implementation. No surviving worker/test process owned this worktree when salvage began. The foreman independently ran the final formatted recovery suite: 13 tests passed in 214.961 seconds, all three semantic mutants produced assertion failures, and the injected recovery-child failure propagated as caller exit 1. A first chained verification command reached its 300-second tool cap during the existing full selftest; that interrupted run is not a full-suite PASS.

The subsequent independent `bash tests/selftest.sh` printed `SELFTEST: PASS`. `gitreins guard --full --scope working-tree` persisted a full-tree guard log at run `20261030T122700.546200Z`: overall PASS, three guards, zero failed or skipped; lint exit 0 and full-test exit 0. The surrounding interactive-shell pipeline wrapper exited 2 because it expanded away its status variable; this wrapper error is separate from the recorded guard child exits. No code fix or test suppression was used. The secrets cell used the builtin scanner, not gitleaks. Final commit and judge remain foreman-owned, not worker self-report.

## Remaining limitations and gates

T3 only: actual local Git/filesystem/subprocess behavior, not remote execution.
Logical durable/control/scratch roots share one filesystem. No real power loss,
independent storage, backup, network partition, origin GC retention, cluster/PV,
NAS/Storage Box, authorization, malicious repository/concurrent writer security,
LFS/submodule or production restore test was run. The fixture uses Git SHA-1 full
commits and tiny synthetic bytes. It does not certify a production publisher,
ledger authentication/freshness, durable commit/object retention or secret backup.

The trusted control pin is outside the lost scratch worker; replacing control
code/pin defeats it. Pending work is classified unknown without replay and
unpublished edits are unrecoverable; no exactly-once guarantee. Production still
requires owner decisions and implementations for storage/retention/RPO/RTO,
fencing, identities, qualified host rebuild, Crier reconciliation, inference and
independent end-to-end admission. No installer recovery or live certification is
claimed. Original checkout and other repos remain unedited; worktree stays for
foreman verification. No task complete or independent judge was invoked.

## Closeout

ch:trace row=CF-019 spec=specs/STORAGE.md#recovery-protocol wave=none:control-root-manifest-not-in-worker-tree test=tests/recovery-contract.py::RecoveryContract.test_recover_after_loss_and_repeat doc=docs/STORAGE-RECOVERY.md prompt=none:transient-worker-brief evidence=docs/audits/code-factory-CF-019-worker-1151.md witness=none:hermetic-local-recovery-only verdict=none:foreman-judge-pending commit=none:self-referential-hash memory=/project/code-factory/status

STATUS: complete
TIER: T3 (real local Git commit/push/reclone, scratch loss, trusted metadata/artifact verification, repeat recovery and meaningful rejection/caller mutations)
EVIDENCE: docs/audits/code-factory-CF-019-worker-1151.md
