# CF-019 recovered verification — 2026-10-30 13:14:59 tick

Implementation: `3daa92c1fbf6a19eb83078733876c27ac5f49967`, already published on
`feat/code-factory-bankai-20261030` and `wt/CF-019-1151` before this tick.
This tick implements no product code and dispatches no duplicate worker. The
project's exactly-one-row contract takes precedence over wave capacity.

## Acceptance and observed commands

The implementation supplies the source-cited comparison and state classifications
in `specs/STORAGE.md`, its default/adoption triggers, and the recovery protocol in
`docs/STORAGE-RECOVERY.md`. It is a local simulation, not deployed storage.

The foreman independently executed this sequential command chain at the unchanged
implementation commit; the chain exited 0:

```sh
python3 -B tests/recovery-contract.py
bash tests/selftest.sh
scripts/boardctl validate
git diff --check
timeout 180 gitreins guard --full --scope working-tree
```

Observed focused result: 13 tests in 42.689 seconds, `OK`; semantic mutants
`trust-pin`, `artifact-digest`, and `pinned-checkout` each produced assertion-failure
exit 1. The injected recovery child exited 23 and its caller exited 1 with exactly
one failure. The positive recovery retained the pinned earlier commit and a
33-byte artifact with SHA-256
`b1330093b2bcc4d946a4f85ebf8ad9dabef6d5b81ff81fa003de883752663338`;
repeat was unchanged, fresh recovery succeeded, pending work stayed unknown and
unpublished work was unrecoverable.

Observed full result: `SELFTEST: PASS`, including the 11-test ordinary recovery
subset. Board validation: 26 tasks, 50 events, `RESULT: OK`, one existing
headerless-board warning. Full working-tree guard: PASS, secrets/lint/full tests;
secrets used the builtin cross-check, not gitleaks in that scope. The local checks
are acceptance evidence, not a fresh completed Tier-2 evaluation.

## GitReins lifecycle and honest unresolved state

An earlier independent full verdict `8bfde864` is real: task CF-019, exact
implementation commit, top-level/Tier-1/Tier-2 all true, evaluated 12:33:02.
The earlier board transition was only staged and never published.

With no active worker or judge owning this row, this tick created a separate
verification worktree from the published integration tip, recreated/started the
missing local CF-019 lifecycle, and ran `gitreins task complete CF-019`.
This was retroactive verification, not an uninterrupted original lifecycle.
It passed Tier 1 but capped at 15.8/15 iterations (directory `96b34a6d`).
A judge-only retry with process-scoped `GITREINS_MAX_ITERATIONS=30` passed Tier 1
but capped at 30.2/30 (`c9a03625`). Repository config was not changed.

The cached `gitreins-tier2-iteration-cap-exceeded` answer was discovered before
recovery. After two capped broad evaluations, this tick split the original
acceptance into serial ephemeral predicates instead of dispatching product rework:

| Predicate | Original criteria | Tier 1 | Tier 2 |
|---|---|---|---|
| Storage decisions | 1, 2, 4 | PASS | PASS, file/line evidence |
| Executable recovery and trace | 3 | PASS | INCOMPLETE, 30.6/30 iteration cap |

`code-factory-CF-019-131459-judges.json` retains both complete ephemeral output
documents, original byte counts/hashes, capped monolithic summaries, the earlier
full PASS binding and explicit collection totals: 2 collected, 1 passed,
1 unresolved, `all_passed=false`. Personal workstation paths are redacted;
publishing does not truncate the returned documents. Ephemeral outputs omit a
native commit field: the coordinator externally bound them to unchanged HEAD and
tracked source/config, not native per-command working-directory attestation.

Disposition: keep CF-019 `in_progress`. The earlier exact-source PASS is retained,
not erased, but the fresh capped attempts are never relabelled PASS. Remaining
follow-up: finish a bounded runtime merits review (or explicitly disposition the
fresh evaluator infrastructure cap) without weakening the tests or claiming live
storage readiness. No further identical retries were launched.

## Publication and boundaries

The original control checkout contains staged QA rows/events and CF-019 residue.
They were not reset, unstaged or absorbed. This isolated evidence commit advances
only CF-019 on the configured integration branch; `main` is not the target.
Hosted CI query returned no runs and the workflows API returned zero workflows.
That is absent/unverified CI, not green and not an observed failed run.

The pre-commit hook refused this source-less board/evidence diff because its
implicit diff-mode lint arm skipped with `lint=no staged files`. HEAD did not
advance. The explicit `timeout 180 gitreins guard --full --scope staged` had
already passed secrets (gitleaks plus builtin), lint and full tests on all four
staged paths. The bookkeeping-only commit therefore uses the documented
source-less `--no-verify` recovery; no source or config changes bypass a gate.

No Bunker node, provider credentials, storage backend, filesystem mounts, live
service or scheduler configuration was touched. Production host-loss durability,
remote execution, independent failure domains, and owner storage/RPO/RTO decisions
remain unverified. No claim that local directory deletion certifies real host loss.

STATUS: partial; evaluator follow-up open
TIER: T3 local invoked recovery, plus one fresh passing document predicate
EVIDENCE: `python3 -B tests/recovery-contract.py`; `bash tests/selftest.sh`;
`docs/audits/code-factory-CF-019-131459-judges.json`

ch:trace row=CF-019 spec=specs/STORAGE.md#recovery-protocol wave=none:serial-recovery-no-new-worker test=tests/recovery-contract.py::RecoveryContract.test_recover_after_loss_and_repeat doc=docs/STORAGE-RECOVERY.md prompt=none:recovered-existing-worker evidence=docs/audits/code-factory-CF-019-131459-judges.json witness=none:hermetic-local-recovery-only verdict=none:fresh-runtime-review-capped commit=3daa92c1fbf6a19eb83078733876c27ac5f49967 memory=none:ledger-written-at-final-closeout
