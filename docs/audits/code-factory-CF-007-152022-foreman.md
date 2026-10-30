# CF-007 foreman tick — local tranche, parent remains open

Tick: `code-factory-2026-10-30-15-20-22`.

STATUS: partial
TIER: T3 — independently executed local fixtures and repository gates, not live nodes.

## Selection and publication

Exactly one row advanced: CF-007, pending to in_progress. The one-row lane contract limits the wave budget to one serial implementation. The wave manifest records the priority/dependency and infrastructure classifications. The supplied stale checkout and unrelated untracked evidence were preserved. The fresh published integration branch, not stale main, was the base.

One isolated worker exited 0. Immutable session usage verified the requested gpt-6.1-sol/openai-codex execution; a separate title-generation model is not an implementation seat. The worker's implementation is `19f5038e641be547841db06d66b1603f3fa4ba49`, published to `wt/CF-007-152022` and `feat/code-factory-bankai-20261030`. Both fetched refs equaled that SHA after implementation publication. This is integration-branch delivery, NOT a main-branch release or deployment. The final board/audit commit is a subsequent bookkeeping SHA, not this implementation SHA.

## Independently executed evidence

| Gate | Command | Observed result |
|---|---|---|
| Focused disk battery | `python3 -B tests/disk-contract.py DiskContract` | Exit 0, 15 tests OK; semantic refusal mutant fails the exact ordinary regression on adapter/clone fall-through |
| Full repository suite | `bash tests/selftest.sh` | Exit 0, SELFTEST: PASS, including disk, existing node/mutation/build/inference/recovery/lane contracts |
| Python lint | `ruff check scripts/disk-policy.py tests/disk-contract.py tests/node-contract.py` | All checks passed |
| Python format | `ruff format --check scripts/disk-policy.py tests/disk-contract.py tests/node-contract.py` | Three files already formatted |
| Changed shell syntax | `for f in scripts/lib.sh scripts/project-node.sh scripts/node-create.sh tests/selftest.sh; do bash -n "$f"; done` | Exit 0 |
| Full whole-tree guard | `gitreins guard --full` | Tier 1 PASS, secrets/lint/tests, no skips |
| Board | `boardctl -C . validate` | OK; existing headerless-board and legacy event-without-id warnings retained |
| Retention | compare all non-CF-007 rows to pre-tick snapshot | All 26 other rows unchanged; 27 task rows retained |

The code refuses invalid/unknown/below-floor disk before state creation, adapter installation, clone and manifest publication. Admission uses exact integer/rational comparison, not rounded display. Only explicitly opted-in apply may reclaim the documented flat disposable-cache namespace. Check never reclaims. Fixtures exercise boundaries, malformed inputs, failed/timed-out observations, remeasurement, unsafe paths/types/links/permissions, lock contention, outside/durable sentinels, copy failure and idempotence. The deployed Hermes inference-refusal adapter was not changed.

## GitReins lifecycle and evaluator failure

`gitreins task create CF-007 ...` and `gitreins task start CF-007` ran before implementation. The same owning isolated control checkout retained task state throughout. After publication and worker trace validation, mandatory `gitreins task complete CF-007` ran against the exact implementation SHA.

The first native artifact is `.gitreins/history/2026-10-30/8df4cdca/verdict.json`, CLI handle `110c037e`: task CF-007, commit `19f5038e641be547841db06d66b1603f3fa4ba49`, Tier 1 PASS, Tier 2 INCOMPLETE, top-level passed=false. The precise failure was iteration cap 15 reached at 15.5 used; there were no completed merits items. A completed tasks.yaml state is NOT a merits PASS.

One unchanged-code/unchanged-criteria bounded retry used process-scoped `GITREINS_MAX_ITERATIONS=60 gitreins task complete CF-007 --force`; no tracked evaluator config or acceptance was relaxed. It launched a background selftest and repeatedly polled a partial three-line log with `pgrep -f selftest.sh`. At attribution, the evaluator's only descendant was its polling shell/sleep, no owned selftest process remained, the partial log was static, and the poll shell itself contained the search string. The exact known pre-solve class `gitreins-judge-self-matching-poll-hang` was discovered before diagnosing this mechanism. Increasing the cap again would only extend a defective poll.

The foreman deliberately terminated that exact tracked retry after observing the stale/self-matching poll; this was NOT a natural completion or a successful evaluation. No second merits verdict is claimed. The first cap artifact and private retry log remain retained. Public evidence is this redacted projection; native artifacts contain operator-local paths and are not copied into public docs. The current local tranche therefore has independent tests/full guard PASS but unresolved GitReins merits review. Do not promote the strongest green layer over this incomplete evaluator layer.

Pre-dispatch bookkeeping guard returned DEGRADED PASS solely because lint had no staged source; tests/secrets ran. Changed implementation and final full whole-tree guards, not that bookkeeping result, are the substantive gate evidence. The initial bookkeeping commit used a local hooks path after the explicit checks; implementation hooks were not bypassed.

## Hosted CI

Remote identity was derived as `coding-hermes/code-factory`. Required `gh run list --repo coding-hermes/code-factory --limit 3 --json status,conclusion,displayTitle,headBranch,createdAt` returned `[]`. Workflows API returned total_count=0; exact implementation SHA runs returned total_count=0. Hosted CI is ABSENT / UNVERIFIED, never green. No observed failed run exists to file as a new broken-CI row. Recheck the final bookkeeping SHA after its push separately.

## Remaining acceptance and next action

CF-007 remains in_progress. Current measured role footprints and justified role floors, broad build-cache/job/stale-clone reclamation, and live Bunker orphan-home/key/user inventory and authorized reaping are NOT established. Default 5 GiB remains provisional and ~1.5 GB historical. No host cleanup, provisioning, credential transfer, runtime quotas, scheduler policy change or remote work round trip occurred. Existing CF-002/CF-003/CF-020 authorization and integration gates remain authoritative; no duplicate blocker row was created.

Resume with a bounded evaluator that executes tests synchronously or tracks its exact process/completion marker instead of broad pgrep. Preserve the already published implementation; do not redispatch duplicate code. Then obtain explicit infrastructure authorization before any live sizing or orphan cleanup. A local tranche merits PASS, if later obtained, still cannot close the full parent acceptance.

ch:trace row=CF-007 spec=specs/NODE.md#laws-and-failure-semantics wave=.coding-hermes/waves/code-factory-2026-10-30-15-20-22.json#CF-007 test=tests/disk-contract.py::DiskContract doc=docs/DESIGN.md prompt=none:transient-worker-brief evidence=docs/audits/code-factory-CF-007-152022-foreman.md witness=none:hermetic-local-only verdict=110c037e commit=19f5038e641be547841db06d66b1603f3fa4ba49 memory=/project/code-factory/status
