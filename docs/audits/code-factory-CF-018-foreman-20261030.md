# CF-018 foreman verification

Scheduler tick: `code-factory-2026-10-30-07-47-56`.
Implementation: `e17f559aa36363843c3d9779f8dc2f5b7cad54c4`.
Target branch: `feat/code-factory-bankai-20261030` (not `main`).
Worker branch: `wt/CF-018`; fast-forward merged and both remote refs independently verified.

Exactly one board row advanced. The project-specific one-row tick contract takes precedence over composing a multi-row wave. CF-016 is complete, satisfying CF-018's declared dependency. Higher-priority live tasks require authorized disposable-node/credential prerequisites; the existing listed lab agent was not treated as disposable or modified.

## Independent observed checks

Executed on the merged implementation, not inferred from the worker report:

| Command | Result |
|---|---|
| `bash tests/build-contract.sh --mutation-controls` | Exit 0; 10 clean tests passed, seven semantic mutations rejected with assertion failures, and injected build-contract exit 23 propagated as selftest exit 1. |
| `bash tests/selftest.sh` | Exit 0, `SELFTEST: PASS`, including 10 BUILD contract tests and existing creator/verifier negative fixtures. |
| `scripts/boardctl validate` | Exit 0; 23 tasks, no key drift. Existing headerless-board warning remains. |
| `timeout 180 gitreins guard --full --scope working-tree` | Exit 0; full secrets, lint and tests PASS. Working-tree secrets scan used the builtin cross-check, not gitleaks. Separate judge Tier 1 ran gitleaks and builtin secrets checks. |
| `git diff --check 28df3aa..wt/CF-018` | Exit 0. |
| `git fetch origin` and `git rev-list --left-right --count origin/wt/CF-018...wt/CF-018` | `0 0`. |
| `git fetch origin` and `git rev-list --left-right --count origin/feat/code-factory-bankai-20261030...HEAD` | `0 0` after implementation push. |

The source audit and acceptance matrix are in [the worker audit](code-factory-CF-018-20261030.md). That artifact's SHA-256 at verification was `ed1db4f3a8c8e7c1daf52c660bf16915137fb6cfb18f1514b3ebc8580793baff`.

The bookkeeping-only commit hook refused its first attempt with DEGRADED PASS because lint had no staged source files; secrets and full tests passed. HEAD did not advance. A fresh `timeout 180 gitreins guard --full --scope working-tree` then passed secrets, lint and full tests. The board/docs-only closeout uses the documented foreman no-verify commit path after that independent full gate; the degraded hook is not counted as full lint evidence.

## GitReins lifecycle and verdict readback

Task `CF-018` was created and started before worker dispatch. The worker committed before `gitreins task complete CF-018` ran on the merged target branch.

The initial verdict `f37ae7d9` (history directory `327950d1`) was INCOMPLETE: configured iteration cap 15 exhausted at 15.5; Tier 1 passed. This is retained as unresolved evaluation history, not relabeled as a merits pass.

Pre-solve discovery for `gitreins-tier2-iteration-cap-exceeded` returned a cached answer describing the environment override. The installed resolver was checked for `GITREINS_MAX_ITERATIONS`. Rejudged unchanged implementation using:

```sh
gitreins task start CF-018
GITREINS_MAX_ITERATIONS=30 gitreins judge CF-018
```

Merit verdict `21da6024`, history directory `fe6e26b4`, was read from disk:

```json
{
  "task_id": "CF-018",
  "passed": true,
  "commit": "e17f559aa36363843c3d9779f8dc2f5b7cad54c4",
  "tier1_passed": true,
  "tier2_passed": true,
  "verdict": "COMPLETE"
}
```

The criterion item is nested under `stages.tier2.steps[0].data.items` and is PASS with file/line and rerun evidence for all original acceptance clauses. The empty top-level `items` is not a missing criterion verdict. No repository evaluator policy was changed.

After the passing merit verdict, `gitreins task complete CF-018 --force --skip-tier2` restored completed lifecycle state. Its verdict `21030ade` is Tier-1-only bookkeeping and does not replace merit verdict `21da6024`.

## CI and evidence boundaries

`gh run list --repo coding-hermes/code-factory --limit 3 --json status,conclusion,displayTitle,headBranch,createdAt` returned `[]`. The workflows API returned zero workflows; the exact implementation check-runs API returned zero checks. Hosted CI is absent/unverified, not green; there is no recent failed run to intake.

No runner was registered, package manager installed, infrastructure changed, or remote heavyweight job executed. Local tests prove policy/kernel behavior and failure propagation, not actual physical placement. Approved self-hosted credential delivery, no-root host qualification, native cache integration, teardown, and live remote identity attestation remain prospective. CF-019 retains durable-storage scope. The integration branch still requires its separate landing to `main`.

DuckBrain namespace `code-factory`, key `/project/code-factory/status`, record `ddccb934-a059-49c3-bbfa-f451061b60ea` was written and read back by exact UUID. Memory supplements the repository evidence; it does not replace it.

STATUS: complete (specification and hermetic contract scope only)
TIER: T3 (local commands invoked and observed)
EVIDENCE: docs/audits/code-factory-CF-018-20261030.md and independent commands above

ch:trace row=CF-018 spec=specs/BUILD.md#placement-contract-and-executable-acceptance wave=none:serial-one-row-lane test=tests/build-contract.sh::test_heavy_remote_admission doc=specs/BUILD.md prompt=none:transient-worker-brief evidence=docs/audits/code-factory-CF-018-foreman-20261030.md witness=none:hermetic-contract-only verdict=21da6024 commit=e17f559aa36363843c3d9779f8dc2f5b7cad54c4 memory=/project/code-factory/status
