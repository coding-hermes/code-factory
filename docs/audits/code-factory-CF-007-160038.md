# CF-007 local review recovery

Tick: `code-factory-2026-10-30-16-00-38`

STATUS: partial — local merits recovered; parent CF-007 remains in_progress.
TIER: T3 — executed local contracts, not live node acceptance.
EVIDENCE: `python3 -B tests/disk-contract.py DiskContract && bash tests/selftest.sh && gitreins guard --full --scope working-tree && scripts/boardctl validate`.

## Scope and selection

The lane's exactly-one-row contract limits this tick to CF-007. Published integration base `37ee7c9d41d1d80741836455f797d70b4b9a1ed6` already contains implementation `19f5038e641be547841db06d66b1603f3fa4ba49`. No implementation worker was dispatched: source was already committed, and the unresolved repo-local obligation was evaluation recovery. Higher-priority live rows require an authorized remote target and secure inference/Crier integration. CF-007's remaining live work is not authorized by this verification tick.

The supplied checkout was divergent and carried unrelated untracked artifacts. It was preserved. Review ran in a new isolated worktree based on the fetched integration branch, with no tracked source/config edits before or during evaluation. The default main branch is behind the integration work; this report is integration-branch delivery, not a main-branch release or deployment.

## Independent command results

| Layer | Command | Result |
|---|---|---|
| Disk contracts | `python3 -B tests/disk-contract.py DiskContract` | Exit 0; 15 tests OK, including semantic refusal-removal mutant |
| Full suite | `bash tests/selftest.sh` | Exit 0; SELFTEST: PASS; measured 48.48 seconds |
| Full working-tree guard | `gitreins guard --full --scope working-tree` | Exit 0; secrets, lint and full tests PASS; working-tree secrets used built-in cross-check, not gitleaks |
| Board | `scripts/boardctl validate` | OK; 27 tasks, 59 events before this tick's update; 27/27 canonical keys. Existing headerless-board and legacy event-without-id warnings remain |
| Frozen checkout | `git diff --exit-code` plus `git rev-parse HEAD` | No tracked changes; HEAD unchanged at the evaluated commit before and after judging |

The refusal mutation removes only the caller's stop condition. The ordinary low-disk regression then fails on observable adapter/clone fall-through; syntax errors or missing bootstrap tools do not count as a valid red control.

## GitReins lifecycle and bound verdict

Fresh `gitreins task create CF-007 ...` and `gitreins task start CF-007` registered the recovery in the isolated control checkout. The earlier local acceptance was partitioned into admission, reclamation, and integration/scope/trace predicates without removing a substantive local obligation. All original live parent obligations remain outside this local merits verdict and remain open on the board.

Mandatory completion ran as:

`GITREINS_MAX_ITERATIONS=60 GITREINS_MAX_TIME=12m gitreins task complete CF-007`

It exited naturally with code 0. Native history id: `f14a8a02`; private verdict-storage handle: `469f9b53`. The native verdict binds task CF-007 to commit `37ee7c9d41d1d80741836455f797d70b4b9a1ed6`. Top-level passed=true, Tier 1 PASS, Tier 2 COMPLETE/PASS, and each of the three criterion items PASS. The accompanying JSON is a redacted projection of that actual verdict, not a synthetic replacement; the native history remains retained privately.

The judge reports running the disk battery and full selftest synchronously. The known self-matching polling mechanism was discovered through the pre-solve lab before recovery (`gitreins-judge-self-matching-poll-hang`, verified answer 3662). The criteria requested synchronous bounded execution rather than broad pgrep polling. No tracked evaluator configuration, source or tests were changed. Earlier capped/interrupted attempts remain historical INCOMPLETE/unobtained evidence; this later PASS does not rewrite those attempts.

The combined tracked scripts/tests/specs/DESIGN/config content fingerprint after review was `9e18e3532e7f037f7716622d4be17cf940b96d30a1ac518379ba30eb053d9bfa`. The native binding and unchanged tracked tree support this review boundary; they are not remote per-command attestation.

## Remaining acceptance and hosted CI

CF-007 remains in_progress. Still open: current measured role footprints and justified role floors, broad build-cache/job/stale-clone reclamation, and live Bunker orphan-home/key/user inventory and explicitly authorized reaping. The default 5 GiB is provisional; the roughly 1.5 GB estimate is historical. No provisioning, live cleanup, credential transfer, runtime quota, scheduler write or remote execution occurred.

These live blockers are retained on CF-007 and the existing infrastructure/authorization rows; no duplicate blocker was manufactured. The next work must obtain the required authorization and collect actual role-sizing/orphan evidence, not redispatch this already-published local implementation or repeat the resolved local judge.

Before publication, a staged `gitreins guard --full` also passed secrets (gitleaks plus built-in cross-check), whole-tree lint and full tests with exit 0. The ordinary pre-commit hook nevertheless blocked this board/docs/manifest-only delta with DEGRADED PASS because it found no staged code for lint; secrets and full tests passed in that hook too. The bookkeeping commit uses the documented non-code-only `--no-verify` exception, disclosed in its commit body. No implementation/config/test gate was bypassed and no hook or shared configuration was changed.

Remote identity: `coding-hermes/code-factory`. Required recent-run query returned `[]`; workflows API returned total_count=0. Hosted CI is ABSENT / UNVERIFIED, not green. No failed hosted run was observed to file as a broken-CI row. Final bookkeeping SHA and fetched branch parity are checked separately after publication.

ch:trace row=CF-007 spec=specs/NODE.md#laws-and-failure-semantics wave=.coding-hermes/waves/code-factory-2026-10-30-16-00-38.json#CF-007 test=tests/disk-contract.py::DiskContract doc=docs/DESIGN.md prompt=none:verification-only-no-worker evidence=docs/audits/code-factory-CF-007-160038-verdict.json witness=none:hermetic-local-only verdict=f14a8a02 commit=37ee7c9d41d1d80741836455f797d70b4b9a1ed6 memory=none:tick-ledger-written-after-publication
