# Storage recovery: local proof and operator handoff

Status: CF-019. [STORAGE](../specs/STORAGE.md) is the storage/recovery authority.
Recommended default: retained full Git commits, disposable local workspaces and
caches, and separately protected off-worker authoritative records/artifact bytes.
No shared writable checkout. No storage provider is selected or provisioned.

## Run the proof

From the repository root, with Python 3 stdlib, Git and the existing selftest
prerequisites available:

```bash
python3 -B tests/recovery-contract.py
python3 -B tests/recovery-contract.py RecoveryContract.test_recover_after_loss_and_repeat
bash tests/selftest.sh
git diff --check
```

The first command runs normal recovery assertions and private-copy mutations,
including the real selftest caller with an injected failing recovery child. The
selftest runs `RecoveryContract` only, avoiding recursive caller/mutation runs.
Every command must exit 0 for its positive suite; the suite asserts meaningful
nonzero exits for negative recovery children and the mutated selftest. A line
saying PASS without successful assertions is not the oracle.

## Fixture and independent trust

`tests/recovery-contract.py::RecoveryContract.setUp` creates a private temporary
root. Everything it deletes is its own `scratch` subtree, never a real worker,
checkout, service, host, Bunker instance or live backend. The helper does not
delete anything. Standard temporary-directory cleanup removes the fixture only.

```text
fixture/
  control/                 isolated HOME; trusted metadata pin kept by test caller
  durable/
    origin.git/            real bare Git, retained accepted commit plus newer main
    accepted.json          accepted checkpoint and pending-dispatch snapshot
    gate.log               accepted synthetic artifact bytes
  scratch/lost-worker/     clone, unpushed commit, dirty files, pending job
  recovered-a/             fresh exact-commit checkout after scratch deletion
  recovered-b/             second fresh recovery
```

These are separate logical roots on ONE local filesystem, not independently
provisioned disks. “Durable” in this simulation means deliberately surviving the
scratch deletion; no power-loss, media-loss or off-host durability is measured.

The trusted test caller knows fixed synthetic artifact bytes before acceptance.
It checks stored bytes against that independent expectation and pins exact
checkpoint bytes with SHA-256 before deleting scratch. Recovery receives that
previously saved pin, not a digest derived from the possibly changed checkpoint.
The checkpoint binds full SHA-1 commit (fixture explicitly selects Git SHA-1),
fixture repository identity, dispatch, artifact basename/size/SHA-256 and pending
intent. The helper validates the pin, exact JSON shape/types and duplicate keys
before trusting contents; the origin is a fixed fixture path, not a URL supplied
by the recovered record. It reads/hashes durable artifact bytes on the control
side. Tampering with artifact AND its newly computed digest in metadata fails
against the old control pin. Replacing the control authority itself is outside
this threat model and defeats the pin; production needs protected authenticated
records, freshness and independent backups, not just checksums.

`tests/recovery-fixture.py::recover` is a test kernel/child, not a supported
production CLI. It restricts recovery destinations to a single fixture basename,
uses no shell, reads bounded regular single-link metadata/artifact files and
runs real Git with file-only transport, private HOME, global/system config off,
no inherited Git environment, empty template, disabled hooks and optional locks
off. No SSH, credential helper, provider configuration or network access is
needed. The fixture is trusted, serialized and caller-owned; hostile concurrent
filesystem writers, malicious Git repositories and full OS isolation are not
qualified. Do not point it at production data. Local Git paths here do NOT widen
NODE's production origin/ref grammar.

## Falsifiable checks

| Test method in `RecoveryContract` | What must actually happen |
|---|---|
| `test_recover_after_loss_and_repeat` | Real source is committed/pushed; main advances; scratch containing unpushed/dirty work and pending job is removed. Fresh checkout equals the older accepted full commit/content, no borrowed alternates or unpublished files. Actual artifact SHA-256/size match pinned expectations. Repeat preserves all file bytes/inodes/mtimes; second fresh recovery returns same result; durable files remain unchanged. |
| `test_missing_commit` | A syntactically valid full commit absent from real Git produces exit 1 and exactly `FAIL recovery:commit_missing`. |
| `test_changed_artifact`, `test_missing_artifact` | Same-length changed bytes fail digest verification; absent bytes fail as missing. No newly computed digest is accepted as expectation. |
| `test_corrupt_metadata`, `test_missing_metadata` | Checkpoint corruption/missing data fails integrity/missing, never defaults. |
| `test_metadata_and_artifact_cannot_redefine_expectation` | Matching forged artifact plus forged digest/size in changed metadata cannot bypass the old trusted control pin. |
| `test_pinned_but_invalid_metadata`, `test_invalid_trust_pin` | Even a pinned malformed/duplicate-key/short-ref/wrong-repository/ambiguous-dispatch record fails schema; invalid or wrong pins fail explicitly. |
| `test_dirty_or_wrong_workspace_not_overwritten` | Existing dirty or non-repository destination refuses without overwriting surviving edits. |
| `test_artifact_rechecked_on_repeat` | A previous success cannot hide later durable artifact corruption. |

Negative tests assert exit exactly 1, empty success stdout and the exact intended
stderr code. Import, syntax, argparse or Git bootstrap failures cannot satisfy
those assertions. `MutationControls.test_private_semantic_mutations` copies the
helper privately, compiles each mutant, bypasses the metadata-pin guard, bypasses
artifact integrity, or substitutes `origin/main` for pinned checkout. Ordinary
contract tests must show assertion failures (not unittest ERROR/bootstrap failure).
`MutationControls.test_selftest_propagates_recovery_failure` copies only the real
selftest inputs, injects a valid recovery child exiting 23 and requires caller
exit 1 with exactly one accumulated failure. No working source is mutated.

## Interpreting loss honestly

The real bare origin does not contain the unpushed commit; the tests prove this
before deletion. That commit and dirty edits are unrecoverable under this policy.
The pending job has no accepted terminal evidence: it is UNKNOWN, not failed,
completed or automatically replayed. The helper reports those classifications;
it does not implement dispatch reconciliation or execute a job. No exactly-once,
Crier delivery, fencing or side-effect deduplication guarantee follows.

An accepted checkpoint is input to this restore test, not proof that a production
publisher exists or that its original result was correct. A hash checks bytes,
not semantic correctness. Missing commit, artifact, record or trust authority is
a BLOCKER for acceptance, not permission to manufacture a replacement record.

## Production recovery handoff (not executable here)

Before provisioning storage, the owner must select independent origin retention,
metadata/artifact/log store, authentication, encryption, custody, quotas, privacy,
retention and numeric RPO/RTO. Test protected publication/read-back and restore
from a failure domain independent of worker and control loss. Include malicious
or stale records, object loss, access denial, quota, network outage and partial
publication. Same-host RAID/snapshots are not independent backups.

After a real node/host loss: deny/fence old admission through its owner, preserve
records, reconcile pending attempts with Crier/control and side-effect witnesses,
restore accepted commits/evidence, then authorize fresh node identity and cold
rebuild. Renew scoped identities without copying host provider keys. Full
NODE-LIFECYCLE checks, host-only inference, bus/result/artifact round trip and
external admission read-back still block production readiness. Existing node
installers do not restore arbitrary pinned commits, task state, secrets or lost
jobs. No commands for those unimplemented operations are invented here.

Current primary docs, qualitative tradeoffs and adoption triggers are in
[STORAGE](../specs/STORAGE.md#storage-alternatives). No clone/restore benchmark,
service SLA, procurement quote, RPO/RTO or actual host-loss certification is
provided by this local proof. Row-specific observed output is in
[the CF-019 worker audit](audits/code-factory-CF-019-worker-1151.md).
