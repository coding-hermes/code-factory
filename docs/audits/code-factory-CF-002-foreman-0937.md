# CF-002 foreman verification — 2026-10-30 09:37 tick

Scheduler identity: `code-factory-2026-10-30-09-37-27`.
Status: partial, local implementation tranche only. The parent CF-002 row stays
in_progress; original live acceptance is not satisfied.

## Selection and ownership

The project lane requires exactly one row per tick, so the concurrency ceiling
of 12 is not a target. CF-001 requires external scheduler/Crier arming and an
authorized live target. CF-002 is the next P0 repository-local implementation seam.
Its absent depends_on field normalizes to an empty array; no dependency was
invented or bypassed. Other rows were not advanced.

Created and started GitReins task CF-002 before implementation. Its four criteria
explicitly grade the repository-local custody, authentication, attestation,
allowlist, evidence and test tranche, not the original live node criterion.
Dispatch state was published at 683fca166ef34c50a01a6ccf9439c1e7f6adb40e.

One worker used isolated branch wt/CF-002-0937. Session
20261030_045943_8a6c76 exited 0. The immutable session_model_usage ledger records
56 calls on requested gpt-6.1-sol / openai-codex and one auxiliary custom
zai-org/GLM-4.7-Flash call (not a second coding worker). The worker's own cwd was
verified before source edits. Foreman did not implement the multi-file change.

## Published implementation

Worker commit: 114cc2c97d2be3343c7197f05ffeccc025e92e47.
Fast-forward merged into feat/code-factory-bankai-20261030, not main.
Worker and integration branches were independently pushed/fetched and verified
at zero ahead; integration parity was 0/0. The implementation changes exactly
10 proxy/test/spec/audit paths. AGENTS.md, installer refusal and GitReins gate
configuration are unchanged by the implementation.

## Independent observed execution

The foreman reran these, rather than accepting worker self-report:

| Command | Observed result |
|---|---|
| python3 -B tests/inference-contract.py | Exit 0; 16 real local HTTP/CLI contract tests. |
| python3 -B tests/inference-mutations.py | Exit 0; 16 semantic mutants rejected on assertions, unchanged control passes; selftest propagates injected inference exit 23. |
| bash tests/selftest.sh | SELFTEST: PASS, independently in worker and merged integration trees. |
| scripts/boardctl validate | OK; 24 tasks, 43 events before verification bookkeeping; existing headerless-board warning only. |
| ruff check scripts/inference-proxy.py tests/inference-contract.py tests/inference-mutations.py | All checks passed. |
| ruff format --check on those three files | 3 files already formatted. |
| git diff --check | Exit 0. |
| timeout 180 gitreins guard --full --scope working-tree | PASS on worker and merged tree: secrets builtin cross-check, lint, full tests. Working-tree scope explicitly does not run gitleaks. Worker commit-time staged source guard also ran. |
| COVERAGE_FILE=<temporary-file> coverage run --include='*/scripts/inference-proxy.py' tests/inference-contract.py; coverage report -m | 397 statements, 28 missed, 93% displayed. In-process measurement; subprocess CLI coverage is not combined. Misses: 587-588, 629, 633-659, 663. |

Negative controls cover scoped identity, expiry/revocation, bearer hash,
provider/model/fallback allowlists, authorization-before-key-resolution,
attestation signature and served pair, credential response echo, private file
mode/single-link/no-follow, durable success evidence/fsync/hash chain, redirects
and environment proxies. Actual CLI and real loopback HTTP are exercised;
synthetic credentials are not real upstream inference.

## CI and evidence boundaries

Origin is coding-hermes/code-factory. Required gh run list returned [] before
work and after implementation publication. GitHub reports zero workflows and
zero check runs for implementation 114cc2c. CI is ABSENT, not GREEN; there is no
recent unrelated failing run to file as broken-CI work. Final bookkeeping SHA
must be checked separately after publication.

Initial board-only dispatch commit was refused by the global hook because no
source was staged (DEGRADED PASS lint=no staged files). The already observed
full working-tree guard passed. The documented per-command repository hooks
path was used only for that bookkeeping commit; no configuration was changed.
The worker fixed its Python formatting failure and reran source gates without
bypass. Runtime history/bytecode artifacts remain unstaged.

Worker post-debug contribution sub_0bd6da describes stdlib http.client's implicit
Accept-Encoding: identity meeting a strict header allowlist. Foreman readback
of the exact queue item now reports complete/done. This is a lab contribution,
not deployed inference proof.

## Still open on CF-002

No real credentials were read/transferred and no node, host, live service or
provider was provisioned/reconfigured/called. The proxy is deliberately
loopback-only and is not wired into a working Hermes node adapter. Remaining:
owner-authorized disposable isolated remote node; private authenticated TLS
endpoint/topology; independently qualified actual-serving attestor; service-token
issuance/delivery/deletion/rotation integration; node adapter and Crier/gateway
transport; live remote model/usage evidence. The existing CF-002 row owns these
blockers; no duplicate blocker row is needed.

HMAC authenticates the trusted adapter's assertion, not its truthfulness. Generic
provider endpoints lacking that protocol refuse. Hash-chained fsynced evidence is
application append-only, not immutable against host-account rollback/full rewrite.
No off-host witness, production concurrency/rate quotas or total wall deadline is
claimed. These limitations prevent full CF-002 completion.

## Pre-judge trace

STATUS: partial
TIER: T3 local executed boundary only
EVIDENCE: worker audit plus independently rerun commands above

ch:trace row=CF-002 spec=specs/HARNESS.md#host-only-inference-custody wave=.coding-hermes/waves/code-factory-2026-10-30-09-37-27.json#CF-002 test=tests/inference-contract.py::InferenceContract.test_http_success_and_evidence doc=docs/THREAT-MODEL.md prompt=none:transient-worker-brief evidence=docs/audits/code-factory-CF-002-foreman-0937.md witness=none:hermetic-local-only verdict=none:judge-pending commit=114cc2c97d2be3343c7197f05ffeccc025e92e47 memory=/project/code-factory/status

The foreman will run GitReins task complete CF-002 on the published merged tree
with this pre-judge evidence. A later verdict/closeout is a separate commit; no
future verdict or self-referential commit hash is asserted here.

## Final evaluation and disposition

No monolithic Tier-2 PASS was obtained. Both `gitreins task complete CF-002`
and its unchanged `--force` retry ran Tier 1 successfully, then hit the per-process
iteration cap 30 (30.5 and 30.8 used). CLI ids 23721bbc / 0540aea2 map to
history directories 94db1665 / dd42ccf9. Their exact verdicts are preserved in
`code-factory-CF-002-split-judges-0937.json`, not relabeled as merits failures or
passes. The task lifecycle flips complete before judging; that state is not
acceptance evidence. The completed local-tranche task is retained for audit.

During the first run a sibling PM writer added CF-025 and CF-026 in board-only
commit 200af57de4872044dec1ff0e6367c1b7607732a5. No source/spec/test/gate config
changed relative to pre-judge 09ab9e8; both full verdicts identify 200af57.
The sibling commit was preserved and published, not reverted or attributed to
this tick. Current board therefore has 26 rows, not the initial 24. Only CF-002
was advanced by this foreman tick.

Six bounded criteria were then collected sequentially in an isolated checkout of
published 200af57, with HEAD/tree and tracked-byte fingerprints checked before
and after every judge. Five passed Tier 1/Tier 2 COMPLETE: identity, transport,
served-identity/fallback, journal, contract/installer boundary. Journal's first
cap-starved attempt was retained; unchanged retry passed. The sixth, tests-trace,
remained iteration-cap incomplete after an unchanged retry (30.8 then 30.5 used).
Its retry additionally reports Tier-1 tests timed out at the evaluator's 120-second
step budget, so that run is DEGRADED/FAIL at Tier 1, not a clean gate. The exact
failure is retained; it does not override or erase independent full-guard passes.
Its final partial text verifies selftest/board/implementation ancestry, but leaves
mutation-source/trace review unfinished. This is not a sixth PASS and not a
fully accepted local tranche. Independent foreman execution of all 16 semantic
mutants and the full selftest is separate passing evidence, not a replacement
for the incomplete evaluator. No repeated cap raise or gate-config edit was made.

The aggregate retains native bounded/redacted evidence and each truncation flag,
plus earlier journal/tests-trace attempts and both full capped verdicts. Its
commit binding is explicitly external; the ephemeral schema has no native commit
field. Transport judge prose cites the worker checkout; source equivalence with
the frozen published tree was independently checked, rather than claiming a native
per-command frozen-checkout attestation.

The foreman then reran `bash tests/selftest.sh` and
`timeout 300 gitreins guard --full --scope working-tree` on the final bookkeeping
candidate: SELFTEST: PASS (16 inference tests in 18.236 seconds), full guard PASS,
and board validation OK (26 tasks / 47 events, existing headerless warning).
A comparison against 200af57 confirms all task rows other than CF-002 are
unchanged. These fresh independent passes do not relabel the evaluator's timeout.
Concurrent readme-probe artifacts and runtime history/bytecode are left unstaged.

CF-002 remains in_progress. Local code/tests are delivered, but tests-trace merits
and the previously named authorized live node/TLS/attestor/adapter/token/Crier
acceptance remain open. Existing CF-002 owns those follow-ups; no duplicate row
was manufactured. CI remains absent, not green. Final board bookkeeping is a
separate published commit and must have its own remote parity/check-run readback.

STATUS: partial
TIER: T3 local executed; five of six bounded Tier2 criteria passed, one capped
EVIDENCE: docs/audits/code-factory-CF-002-split-judges-0937.json

ch:trace row=CF-002 spec=specs/HARNESS.md#host-only-inference-custody wave=.coding-hermes/waves/code-factory-2026-10-30-09-37-27.json#CF-002 test=tests/inference-contract.py::InferenceContract.test_http_success_and_evidence doc=docs/THREAT-MODEL.md prompt=none:transient-worker-brief evidence=docs/audits/code-factory-CF-002-split-judges-0937.json witness=none:hermetic-local-only verdict=run:CF002-SPLIT-0937 commit=200af57de4872044dec1ff0e6367c1b7607732a5 memory=/project/code-factory/status
