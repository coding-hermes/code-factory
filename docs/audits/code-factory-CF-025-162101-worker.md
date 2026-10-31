# CF-025 worker evidence — check-mode HOME purity

## Scope and verified premise

Task: CF-025, wave `code-factory-2026-10-30-16-21-01`.
Integration base: `9d8f0a064215627df81783e5fd8a2a20b05fe558`.

This is T3 hermetic local execution, not live-node acceptance. No provisioning,
installation, root operation, real Crier/Bunker/provider call or credential access
was performed. All prerequisite commands/adapters are disposable local fixtures.
Temporary source copies, HOME trees and logs use `TMPDIR`; fixture logs live
outside the observed HOME. No private endpoint or personal host path is evidence.

Reverification contradicted part of the dispatch premise: at the integration
base, `project-node.sh` already gates state creation on apply mode after disk
admission, and NODE.md already says check does not create `.node`. The missing
work was dedicated preservation/mutation evidence and an explicit whole-HOME
contract, not another production mkdir fix. Production scripts are unchanged;
CF-007 disk admission and reclaim behavior is preserved.

## Changes and falsifiable oracles

- `tests/check-purity.py` reuses `NodeContract`'s existing fake curl, git, df,
  memory observation and healthy version-reporting adapter. Real Python/venv
  bootstrap remains available; no check layer is bypassed.
- `CheckPurity.test_seeded_success_preserves_home`: all implemented prerequisites
  pass, child exit 0 and `NODE: PASS`. Seeded binary content, symlink, empty
  directory, identity, repo and preexisting manifest survive two checks.
- `CheckPurity.test_missing_crier_url_preserves_home`: remove only `CRIER_URL`,
  retaining `CRIER_BASE` and the other prerequisites; child exit 1 with exactly
  `FAIL  crier_url` and `NODE: FAIL (1)`. HOME survives two checks. The fixture
  asserts real disk, adapter and Python/venv PASS rows and rejects bootstrap,
  import, command-not-found and syntax-error decoys.
- `CheckPurity.test_empty_home_no_state`: initially empty HOME remains empty,
  with no `.node`. Existing identity/repo prerequisites cannot be met on an
  empty HOME, so this arm requires exactly those two named layer failures,
  not an impossible healthy-empty-node result.
- `CheckPurity.test_apply_may_create_state_after_admission`: apply creates mode
  700 `.node` after a successful disk observation, even though missing identity
  later returns exit 1. No manifest is published on that failure.
- Snapshot covers root and hidden entries using lstat: bytes, types, permission
  bits, uid/gid, link count, inode, size, mtime and ctime. Symlinks are not
  followed. Only atime is excluded because observation itself can update it.
- `tests/selftest.sh` executes `CheckPurity` and increments its failure count on
  nonzero fixture exit. NODE.md's script-boundary section now states both mode
  semantics, scratch-log boundary, atime exclusion and local-only proof limits.

## Executed commands and observed results

Run from the worker checkout; scratch is supplied through `TMPDIR`.

1. `git diff --quiet 9d8f0a064215627df81783e5fd8a2a20b05fe558 -- scripts/project-node.sh scripts/disk-policy.py scripts/lib.sh`
   returned 0 before edits: production matches the integration base.
2. `ruff format tests/check-purity.py` formatted the new fixture before mutation
   anchors were used. `ruff check tests/check-purity.py` returned 0, reporting
   `All checks passed!`; `ruff format --check tests/check-purity.py` returned 0.
3. `bash -n tests/selftest.sh` returned 0.
4. `python3 -B tests/check-purity.py CheckPurity` returned 0: four tests passed.
   Observed success, exact single missing-config failure, unchanged empty HOME,
   and apply-only state creation. Each check-mode case runs twice.
5. `python3 -B tests/check-purity.py PurityMutations` returned 0: one control test
   passed, running unchanged and two mutated private source copies. Initial run
   completed in 153.266 seconds. Both unchanged fixture/full-selftest commands
   returned 0; the full suite printed `SELFTEST: PASS`.
6. `bash tests/selftest.sh` returned 0 and printed `SELFTEST: PASS`, including
   the new check-purity section. Existing disk suite: 15 tests passed, including
   disk refusal mutation. Board parser printed `27/27 rows parse`.

### Runnable mutation evidence

`PurityMutations.test_runnable_mutations_and_selftest_propagation` copies the
current scripts, tests, specs, docs and board fixture into disposable scratch.
It does not modify the checkout. `selftest.sh` explicitly selects `CheckPurity`,
so full-suite mutation controls do not recurse. Children run synchronously with
30-second script and 180-second full-suite deadlines.

Before introducing the mutations, unchanged source passes both:

- `python3 -B tests/check-purity.py CheckPurity`
- `bash tests/selftest.sh`

Each mutation inserts a check-only action before preflight, leaving bootstrap
and the actual check layers runnable:

- Directory mutant: `if [ "$MODE" = check ]; then mkdir -p "$STATE"; fi`
- File mutant: `if [ "$MODE" = check ]; then printf mutation > "$HOME/check-created"; fi`

For each mutant, `bash -n` returns 0; the same fixture returns 1 with
`AssertionError` / `HOME changed`. The full selftest also returns 1, contains
that assertion and `FAIL  check purity contract`, prints `SELFTEST: FAIL`, and
must not print `SELFTEST: PASS`. This behaviorally proves invocation and failure
propagation, rather than relying on a source-text grep. No production change
was necessary to make the unmodified control pass.

## Pre-solve and remaining boundary

Mandatory distinctive-token corpus lookup and exact-class discovery were both
performed before design; neither returned an applicable cached answer. No new
nontrivial debugging method was discovered, so no post-debug submission was
made and no receipt/status is claimed. Private discovery transport details are
intentionally excluded from this public artifact.

## Final pre-commit verification

After the final fixture output change, reran:

`ruff format --check tests/check-purity.py && ruff check tests/check-purity.py && bash -n scripts/project-node.sh tests/selftest.sh && python3 -B tests/check-purity.py CheckPurity && python3 -B tests/check-purity.py PurityMutations && git diff --check && gitreins guard --full --scope working-tree`

The entire command returned 0. Four purity tests passed in 0.842 seconds; the
mutation/propagation control passed in 141.417 seconds with the same unchanged,
directory and file outcomes above. The missing-URL child printed its named
`FAIL  crier_url` and `NODE: FAIL (1)`; success printed `NODE: PASS`.

GitReins reported `Tier 1 Guards: PASS` with full/working-tree/whole-tree scope,
zero failed or skipped guards, lint clean and `tests (full)` exit 0. Its native
local log is `.gitreins/logs/guard-20261030T163333.117384Z.log` (not added to the
public artifact). Readback confirms the executed suite ended with the new
purity section and `SELFTEST: PASS`. Secret scanning was the builtin cross-check;
gitleaks did not run in working-tree scope. This is a guard result, not a judge.

Publication is branch-only and the implementation SHA/push readback is bound by
the worker's final response; this commit cannot cite its own SHA. The foreman
owns judging and task transitions; this worker does not create, start, complete
or judge GitReins tasks, or alter task/config state. Only the three prepared
foreman board/event/wave paths are included unchanged in the implementation
commit; `.coding-hermes/board/.lock` is excluded. No other row is repaired.

Live harness behavior, network reachability, remote provisioning, authenticated
bus/inference and artifact round trips remain unverified. No live proof is
claimed; the independent foreman judge is pending.
