# CF-007 — local disk admission tranche

STATUS: partial
TIER: T3 — executed synthetic local observations, never live nodes

## Scope and implementation

This change is based on published integration `ed2f921` plus the inherited
foreman dispatch commit `e4fa1cc`. Only the isolated CF-007 branch was modified.
NODE's laws were amended before the implementation. No board/lifecycle update,
AGENTS.md edit, service/scheduler change, credential transfer, live node probe,
provisioning or orphan cleanup was performed.

- `scripts/disk-policy.py` validates decimal GiB floors and C-locale POSIX df
  output, requires successful bounded observation and compares integer KiB/bytes
  by exact rational cross-multiplication. Display uses exact decimal GiB, not a
  rounded threshold. Empty/negative/nonfinite/exponent/non-ASCII floors refuse.
- `scripts/lib.sh` forwards helper failure and increments FAILED. The provisioning
  caller exits immediately on disk denial, before `.node` creation, adapter apply,
  clone or manifest publication. Check does not create `.node`.
- `NODE_DISK_FLOOR=0` explicitly removes the positive capacity floor; it still
  requires valid successful measurement. Existing zero-floor fixtures now use
  deterministic fake df rather than observing the host's real free space.
- Only `--apply --reclaim-disposable` enables cleanup after a valid low reading.
  It can unlink eligible flat blobs in the fixed, explicitly enrolled
  `$HOME/.node/disposable-cache-v1` only. No recursion, arbitrary target option,
  `.node/jobs`, Git repos/clones, evidence, manifests or credentials are eligible.
  Ownership/mode/device/type/name/single-link checks, no-follow directory walking,
  bounded whole-directory prevalidation, advisory exclusive flock and per-unlink
  identity recheck fail closed. The helper also rejects a reclaim root different
  from HOME. The namespace is never created/enrolled automatically.
- Both absent/empty namespace and successful removal require a second observation.
  Unsafe namespace, cleanup error, second-measurement error or still-low space
  denies admission. No cleanup occurs in check mode or ordinary apply.
- `node-create.sh` stages the helper and stops if that copy fails; this path was
  exercised through a fake Bunker executable, never real Bunker.

STORAGE's reconstructable-cache/ephemeral-scratch classification is reused, not
expanded to durable job evidence. The account and cooperating cache producers
are trusted. This is not a hostile-same-uid sandbox: producers must honor the
same directory flock and must not mislabel valuable bytes as disposable blobs.
An I/O error or uncooperative race can leave partial cleanup; admission still
fails. The disk reading does not reserve capacity or implement runtime quotas.

## Executed verification

All logs are retained outside the repository under configured `$TMPDIR`, using
`cf007-` filenames. Public evidence below is sanitized; private receipt identifiers,
host details and temporary absolute paths are deliberately omitted.

1. RED, before implementation:
   `python3 -B tests/disk-contract.py DiskContract.test_low_disk_stops_before_install_clone_and_state`
   exited 1. With synthetic 1048576 KiB free and floor 5 GiB, baseline printed
   disk FAIL but still called the fake adapter and Git clone. The assertion failed
   because the side-effect marker existed. A preliminary just-below-floor run
   also exposed baseline rounding to `5.0 GB` and erroneous disk PASS.
   Log: `$TMPDIR/cf007-red.log` (the explicit fall-through control).
2. GREEN:
   `python3 -B tests/disk-contract.py DiskContract` exited 0, 15 tests passed.
   Log: `$TMPDIR/cf007-focused.log`.
   Coverage includes 5242879/5242880/5242881 KiB against 5 GiB, fractional floors,
   zero override, malformed/failed/timed-out df, malformed floors, pre-install
   rejection, no state/manifest on denial, reclaim-still-low, reclaim-enables-pass,
   second-observation failure, check/default-apply no cleanup, absent namespace,
   outside sentinels, unsafe names/modes/types, symlinked HOME/ancestor/state/cache/
   leaf, hardlinks, FIFO, entry bound, lock contention, caller-selected path denial,
   unchanged empty-cache repeats and byte-identical repeated manifest publication.
3. Behavioral negative gate:
   `DiskContract.test_refusal_removal_mutation_breaks_exact_regression` copies the
   actual scripts/tests privately, replaces only the caller's immediate refusal
   with ignored failure, and runs the exact ordinary RED regression above.
   Mutant exits 1 on the side-effect assertion and shows successful fake adapter
   and clone calls. Syntax/import failure is not accepted as mutation rejection.
4. `bash tests/selftest.sh` exited 0 and printed `SELFTEST: PASS`, including the
   new disk battery and existing node, mutation, build, inference, recovery and
   lane contracts. Log: `$TMPDIR/cf007-selftest.log`. The existing Hermes adapter
   inference-refusal tests remain green; its implementation was not changed.
5. `ruff check scripts/disk-policy.py tests/disk-contract.py tests/node-contract.py`
   and `ruff format --check` on the same three files both passed.
   `python3 -m py_compile` on those files passed with `PYTHONPYCACHEPREFIX` set
   under scratch. `bash -n` passed for all four changed shell files.
   `git diff --check` and staged diff whitespace checks passed.
6. Unfiltered ShellCheck still reports existing SC1091 source-resolution info,
   SC2015 conditional idioms and SC2088 intentional quoted artifact grammar.
   Comparison against private copies from `e4fa1cc` confirmed unchanged SC2015/
   SC2088 diagnostics; SC1091 differs only with private-copy source discovery.
   `shellcheck --exclude=SC1091,SC2015,SC2088 scripts/lib.sh scripts/project-node.sh scripts/node-create.sh tests/selftest.sh`
   passed. No implementation hook/config was disabled or weakened.
7. `gitreins guard --full` exited 0: Tier 1 PASS, whole-tree full mode,
   secrets/lint/tests passed, zero failed or skipped guards. Its detailed log
   confirms configured selftest actually executed, including all 15 disk tests
   and `SELFTEST: PASS`, rather than a source-extension short circuit.
   Logs: `$TMPDIR/cf007-guard.log` and `$TMPDIR/cf007-guard-full-detail.log`.

Pre-solve discovery returned not_found; the prescribed answer corpus keywords
had no hits. After debugging, the mechanism was submitted with cadence post-debug
using the served API schema. The private receipt was read back: accepted queue
entry, deferred by host-load gate at observation time, not a verified lab answer.
Receipt and readback remain private in scratch; no lab result is claimed.

## Parent acceptance still blocked

No current role-specific node footprint, role floor justification, live disk
measurement, Bunker orphan-home/key/user census or authorized reaping was performed.
The historical ~1.5 GB estimate remains historical and default 5 GiB provisional.
Broader build-cache/job-directory/stale-clone reclamation is NOT implemented by
this deliberately flat cache policy. Live cleanup/provisioning, scheduler admission,
per-job/runtime quotas and a real node/inference round trip require separate
owner-authorized work. CF-007 parent is not complete. Foreman judge is pending.

ch:trace row=CF-007 spec=specs/NODE.md#laws-and-failure-semantics wave=.coding-hermes/waves/code-factory-2026-10-30-15-20-22.json#CF-007 test=tests/disk-contract.py::DiskContract doc=docs/DESIGN.md prompt=none:transient-worker-brief evidence=docs/audits/code-factory-CF-007-152022-worker.md witness=none:hermetic-local-fixtures verdict=none:foreman-judge-pending commit=none:self-referential-hash memory=/project/code-factory/status
