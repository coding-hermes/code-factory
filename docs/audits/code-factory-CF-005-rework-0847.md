# CF-005 rework — local contract and mutation evidence

## Scope and verdict

STATUS: complete for all six revised repository-local CF-005 criteria.
TIER: T3 local executable contract/mutation verification, invoked with
`bash tests/selftest.sh`, `python3 tests/node-contract.py`, and
`python3 tests/node-mutations.py`. This label is not a GitReins Tier-2 judge
verdict. No task-complete or judge command was run; foreman review is pending.

Base: `b2c315ef0457618b374e0655a97989f4ef4c1267`.
Branch: `wt/CF-005-REWORK-0847`.
All fake Bunker/curl/git/adapter/resource fixtures are local temporary test state,
not live nodes, identities, service measurements or provider-key transfers.

## Baseline failures reproduced before and during implementation

Read the exact reopened CF-005 row and the six findings in
`cf005-quorum-review-2026-10-30.md` before editing. New tests were written before
production changes. The initial regression run exited 1 on creator inputs,
artifact verification, manifest write failure and reuse. Its first named-check
fixture also unintentionally omitted CRIER_BASE, producing two failures; that
fixture was corrected to keep CRIER_BASE set while omitting only CRIER_URL.
That test-construction mistake is not counted as a production defect.

Reproduce the historical source defects without modifying the checkout:

```bash
python3 tests/node-mutations.py --baseline b2c315e
```

Observed output (command exits 0 only because these expected baseline failures
were reproduced, not because historical scripts passed):

```text
BASELINE b2c315e test_creator_preconditions_and_exact_triple: exit=1 assertion failure reproduced
BASELINE b2c315e test_forbidden_manifest_paths_without_dispatch_option: exit=1 assertion failure reproduced
BASELINE b2c315e test_manifest_write_failure: exit=1 assertion failure reproduced
BASELINE b2c315e test_manifest_identity_and_byte_idempotence: exit=1 assertion failure reproduced
BASELINE bootstrap: exit=1; substring FAIL accepted FAILED: unbound variable
```

The forbidden-path baseline uses only options understood by the old verifier,
so an unknown `--dispatch-id` flag cannot masquerade as a safe denial. Fake Bunker
never reads a real secret; old path overreach is detected by recorded calls.
The bootstrap replay uses an empty temporary HOME, not an operator's HOME.
The old writer printed manifest PASS after a filesystem write failure; the old
reuse path accepted a different identity. Historical key requirements and spec
drift are source findings, not claims that credentials or live services were
inspected.

## Acceptance mapping

1. NODE/ENVELOPE/HARNESS, DESIGN and THREAT-MODEL now distinguish implemented
   provisioning checks from planned Crier pull, gateway dispatch, ack/replay,
   quarantine, dirty-repo handling and runtime admission. Historical install
   measurements are labeled historical. README and OPERATIONS received only
   directly related policy/command corrections: no node provider-key requirement
   or old installer/startup claim remains there. Historical audits stay intact.
2. Selftest invokes `NodeContract.test_named_check`: bootstrap PATH works,
   temporary repo/bus identity and fake healthy adapter/resources exist, CRIER_BASE
   stays set and only CRIER_URL is absent. It requires nonzero exit, exactly the
   anchored `  FAIL  crier_url` check name before ` — `, and no unbound-variable
   error. Removing the failure and inserting a bootstrap-error decoy each produce
   an assertion failure in that same executable test.
3. Creator validates required project/repo/harness and node options before any
   Bunker call. Invalid inputs record zero calls, including missing repo/harness,
   traversal, metacharacters, credential-bearing URLs and unsupported harnesses.
   Positive fake spawn/provision captures the exact project/repo/harness triple.
   NODE.md documents a deliberately narrow HTTPS/SSH Git-origin grammar, not an
   overly broad URL parser. Staged `node-contract.py` enforces node-side identity.
4. Verifier allows exact manifest or matching dispatch/artifact namespace only.
   Secret/config/traversal/shell denials occur locally with zero Bunker calls.
   Direct remote Python argv performs bounded no-follow descriptor-relative reads
   before any remote shell. Local symlink-parent/leaf, hardlink and FIFO fixtures
   refuse before shell probes. Both valid artifact and bootstrap manifest pass
   local byte-digest checks. No real secret is read or transferred.
5. Apply checks manifest identity before mutation, refuses project/repo/harness
   mismatch or malformed/unsafe state, and checks atomic publication status.
   A directory at the manifest path and a forced writer exit 19 both fail closed;
   neither emits manifest PASS. Identical re-apply preserves exact bytes and
   timestamp. Auth, digest mismatch and provision failure regressions are retained.
6. Full selftest, focused tests, meaningful executable mutations, board validation
   and full working-tree guard pass. Clean committed-tree rerun is required in the
   worker closeout; branch remote parity is verified after publishing. No board,
   wave, GitReins config/lifecycle, AGENTS.md or other repository was changed.

## Runnable focused and mutation checks

```bash
python3 tests/node-contract.py
python3 tests/node-mutations.py
bash tests/selftest.sh
scripts/boardctl validate
git diff --check
gitreins guard --full --scope working-tree
```

Observed focused result: `Ran 11 tests` / `OK`.
Observed executable mutation output:

```text
PASS local mutation named-failure-removed: control=0 mutant=1 assertion=test_named_check
PASS local mutation bootstrap-error-decoy: control=0 mutant=1 assertion=test_named_check
PASS local mutation repo-precondition-removed: control=0 mutant=1 assertion=test_creator_preconditions_and_exact_triple
PASS local mutation artifact-local-scope-removed: control=0 mutant=1 assertion=test_artifact_denials_before_remote_shell
PASS local mutation artifact-nofollow-removed: control=0 mutant=1 assertion=test_artifact_symlink_hardlink_and_positive
PASS local mutation manifest-write-status-ignored: control=0 mutant=1 assertion=test_manifest_writer_error_is_not_pass
PASS local mutation manifest-identity-ignored: control=0 mutant=1 assertion=test_manifest_identity_and_byte_idempotence
MUTATIONS: PASS (7 local executable controls; no live proof)
```

Every mutation first runs its unchanged positive control, verifies the mutation
anchor exists, then requires nonzero plus the named unittest AssertionError.
All modifications happen in private copies. The bootstrap decoy is rejected by
the real named-check assertions; a parser error in the runner cannot satisfy the
mutation harness. Formatting changed two mutation text anchors during development;
the runner correctly failed `mutation target absent`, then anchors were corrected
and all seven controls rerun successfully.

Full selftest observed `SELFTEST: PASS`, including 11 node tests, all seven mutation
controls, existing 10 build/cache tests, checksum red/green arms, shell syntax,
credential-pattern scan, board JSONL parsing and missing-boardctl negative control.
Board validation observed:

```text
rows: 24 tasks, 39 events, 0 fixtures
key uniformity: 24/24 rows carry only canon keys (0 drift)
[warn] headerless board (no board.jsonl)
RESULT: OK (1 warning(s))
```

The warning is inherited; this worker did not alter the board. `git diff --check`
exited 0 without output. `gitreins guard --help` confirmed `--full` and
`--scope working-tree`; the actual full guard reported:

```text
Tier 1 Guards: PASS  (test mode: full, scope: working-tree, whole tree)
  secrets — clean (builtin cross-check; gitleaks not run (working-tree scope))
  lint — ok
  tests (full)
```

Earlier guard runs failed on newly added Python style/unused imports, then on
formatting. Fixed the source/tests (not gate configuration) and reran successfully.
This guard ran the real full selftest, not a supported-extension short circuit.

## Pre-solve discovery and contribution

Before design, local pre-solve discover for
`shell-dispatch-artifact-manifest-boundary` returned HTTP 404 `not_found`.
Mechanism keyword search of the answer corpus found unrelated shell harness
material, no matching answer used. The foreman had already checked the
substring false-positive class. After debugging, inspected the real
`SubmitProblemRequest` schema, submitted the solved mechanism with top-level
`cadence: post-debug` and object `context`, and read back submission
`sub_dfa46c`: HTTP 200, matching problem class, pending/queued. No answer or solver
completion is claimed. Service addresses and private runtime state are omitted.

## Remaining live blockers and limits

- CF-002 host inference proxy/node-scoped identity integration is unimplemented.
  Hermes check/apply intentionally fails `inference_integration` before install,
  config/key reads or gateway start. No proxy architecture was added here.
- Crier identity issuance/bundle lifecycle, pull worker, gateway dispatch,
  result publishing/ack/deduplication, authenticated provenance, quarantine and
  scheduler admission still need implementation and independent live evidence.
- No Bunker node was provisioned; no live service was changed. Direct Python argv
  compatibility with a real Bunker, actual gateway auth and a full inference/result
  round trip remain unverified. Fake success is never live acceptance.
- Manifest identity does not attest an existing checkout's remote/ref/cleanliness.
  Artifact scope/digest does not prove honest job execution or benign contents.
  HOME is a trusted account root; no sandbox/egress/resource quota is established.
- Commit/push/parity and clean-tree test output belong to the final immutable
  worker report; the artifact cannot embed its own containing commit hash.

ch:trace row=CF-005 spec=specs/NODE.md#script-boundary-and-manifest-mapping wave=.coding-hermes/waves/code-factory-2026-10-30-08-47-08.json#CF-005 test=tests/node-contract.py::NodeContract.test_named_check doc=docs/audits/code-factory-CF-005-rework-0847.md prompt=none:transient-worker-brief evidence=docs/audits/code-factory-CF-005-rework-0847.md witness=none:hermetic-local-only verdict=none:foreman-judge-pending commit=none:self-referential-hash memory=none:foreman-owned
