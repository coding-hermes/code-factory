# CF2A-01 pass-4 triage plan

Review package: CF2A-01 fourth-batch revision audit, received 2026-11-09.
Canonical review record: `CF2A-01-pass4-review-log.json` (16 consolidated findings; 26 prior findings checked).
Source artifact: `CF2A-01-pass3-integrated.pdf`, 275 pages, SHA-256 `841f4626c00730de7940449e60408966c36f152318d5e027893f4f7acc6bd564`.

This plan records implementation ownership only. It does not apply handbook, figure, or script corrections. Target files below are the owning edit surface; waves may read other files for reconciliation but may edit only their listed files. Prior IDs are retained because every pass-4 finding is a residual or integration follow-up to an already dispositioned pass-3 row.

## Finding register

| Plan ID | Source ID | Severity | Pages | Primary target file(s) | One-line correction summary | Repeat of prior row(s) |
|---|---|---:|---|---|---|---|
| P4-01 | P4-CONFIG-01 | P1 | 200–202, 207–208 | `docs/handbook/parts/V-settings.md` | Publish one recursive `factory.v1` configuration model with exact types, requiredness/defaults/ranges/unknown-field policy, resolvable hosts/profile endpoints, canonical project memory, and one subscription vocabulary; validate the worked example and refusal cases. | P3-CONFIG-01 (ADOPTED); P3-CONFIG-02 (ADOPTED) |
| P4-02 | P4-PROTOCOL-01 | P1 | 94–95, 160, 170, 190–191, 250, 256–257 | `docs/handbook/parts/IV-contract-register.md` | Separate registration, round admission/launch, worker execution, result, and return schemas; assign IDs at their owner boundary, normalize outer/inner versions and status domains, and provide concrete examples, errors, legacy mapping, and the selected Crier consumer. | P3-INT-01 (ADOPTED); P3-DISPATCH-01 (ADOPTED); P3-WORK-01 (ADOPTED) |
| P4-03 | P4-MANAGER-01 | P1 | 24–25, 191, 200–202, 206–207 | `docs/handbook/parts/I-system-arrangement.md` | Complete the manager project/global API and adapter contracts, generation relation, authentication/authorization, idempotency digest comparison, freshness/readback, reservation boundaries, transitions, cancellation, and non-circular readiness sequence. | P3-MANAGER-01 (ADOPTED); P3-CONFIG-01 (ADOPTED); P3-SCHED-01 (ADOPTED) |
| P4-04 | P4-CLAIM-01 | P1 | 111, 191, 258 | `docs/handbook/chapters/M4-board.md` | Choose the shared claim authority or remote-ref CAS protocol, normalize claim/lease/fence fields, and define staged row/event publication, commit visibility, partial-write recovery, abandoned claims, and fenced returns before work starts. | P3-BOARD-01 (ADOPTED); P3-RECOVERY-01 (ADOPTED) |
| P4-05 | P4-RECOVERY-01 | P1 | 25, 95, 179, 246–247, 258 | `docs/handbook/parts/VI-failure-risk.md` | Close uncertain native-start recovery with a preassigned or queryable launch identity, reconciliation-before-retry, resource-side generation fences for every protected write, and quarantine/readiness rules when quiescence is unproven. | P3-RECOVERY-01 (ADOPTED); P3-DISPATCH-01 (ADOPTED) |
| P4-06 | P4-BUDGET-01 | P1 | 201, 205, 246–247, 256, 259 | `docs/handbook/parts/V-settings.md` | Define worker-versus-attempt/session/launch accounting, reservation/start/charge/refund transitions and policy values, separate total round allowance from simultaneous capacity, and correct the T3 ledger example. | P3-RECOVERY-01 (ADOPTED); P3-CONFIG-02 (ADOPTED); P3-WORK-01 (ADOPTED) |
| P4-07 | P4-MEMORY-01 | P1 | 4, 11, 35–36, 190, 201, 209–210, 242, 245–246, 257–258 | `docs/handbook/parts/VII-work-derivation.md` | Specify one complete same-namespace local/remote DuckBrain synchronization profile with endpoints/refs, authority, authorization, record and commit schema, merge/conflict/replay operations, freshness, local-only validity, and pre-write versus resulting metadata. | P3-MEM-01 (ADOPTED) |
| P4-08 | P4-DEPLOY-01 | P1 | 23, 86–87, 114, 123, 147, 201, 210–211 | `docs/handbook/chapters/M1-provisioning.md` | Supply one complete versioned qualified deployment profile with exact artifacts/dependencies, host/runtime prerequisites, mounts/identity/networking, secrets references, bootstrap/readback, lifecycle, upgrade, replacement, and removal procedures. | P3-PROVISION-01 (ADOPTED); P3-SAFETY-01 (ADOPTED) |
| P4-09 | P4-AUTH-01 | P1 | 86, 139, 188, 191, 205, 210 | `docs/handbook/chapters/M7-github.md` | Specify trust enrollment, identity/secret interfaces, full actor/resource authorization matrix, provider adapter request/results for GitHub and GitLab, delivery/readback, rotation, expiry, revocation, offboarding, restore, and enforcement of narrower project/Bunker scope. | P3-FORGE-01 (ADOPTED); P3-ACCESS-01 (ADOPTED); P3-PROXY-01 (ADOPTED) |
| P4-10 | P4-PUBLICATION-01 | P1 | 39–40, 103, 111, 191, 250, 252, 256 | `docs/handbook/chapters/M3-repository.md` | Define versioned gate/acceptance policy and evidence/verdict objects across source, integration, and landed trees, including revalidation/equivalence, serialized fresh remote proof, uncertain push handling, and exact published-object closeout. | P3-REPO-01 (ADOPTED); P3-WORK-01 (ADOPTED); P3-CONSISTENCY-01 (ADOPTED) |
| P4-11 | P4-EVENTS-01 | P1 | 201–202, 207, 227, 254 | `docs/handbook/parts/V-settings.md` | Unify event/subscription fields and specify receiver authentication/signing, headers/body/ack, retry/backoff/exhaustion, cursor replay/retention/order, progress extension, and complete metric type/unit/label/sample/reset/unknown/readout semantics. | P3-OPS-01 (ADOPTED); P3-CONFIG-01 (ADOPTED) |
| P4-12 | P4-BACKUP-01 | P1 | 59–60, 147, 201, 247 | `docs/handbook/parts/VI-failure-risk.md` | Define a supported backup profile and per-store checkpoint/marker/capture/failure/validation protocol with RPO/RTO/schedule/retention/destination/key recovery, isolated restore results, revocation preservation, and a real backup figure instead of drift-as-snapshot. | P3-RECOVERY-02 (ADOPTED); P3-FLW-02 (ADOPTED) |
| P4-13 | P4-PROXY-01 | P1 | 188, 191, 232–234 | `docs/handbook/chapters/M12-inference-proxy.md` | Publish the supported inference/stream and Hermes compatibility contract, exact terminal/error/cancel events, deadlines/usage settlement, token administration/defaults, maintained package or replacement interface, and capture failure/redaction/retention behavior. | P3-PROXY-01 (ADOPTED) |
| P4-14 | P4-CONSISTENCY-01 | P2 | 4, 8, 11, 24, 69, 111, 161, 170, 172–173, 181, 191, 242, 246, 252, 258, 265–266 | `scripts/build_book.py`; `docs/handbook/figures/system-map.svg`; `docs/handbook/figures/board-lifecycle.svg`; `docs/handbook/figures/tick-lifecycle.svg`; `docs/handbook/figures/F1.svg`–`F16.svg`; `docs/handbook/figures/module-M0.svg`–`module-M12.svg` | Reconcile current source, figure, table, schema, owner, location, status, and historical/as-built views from one normative model; generate references from shared definitions and report actual PASS/PARTIAL/FAIL/NOT RUN evidence separately from conformance. | P3-CONSISTENCY-01 (ADOPTED); P3-DIAGRAM-01 (ADOPTED) |
| P4-15 | P4-LAYOUT-01 | P2 | 2, 6, 9, 26, 29–32, 49, 71, 87, 133, 140, 180, 189 | `scripts/build_book.py`; `docs/handbook/parts/II-flows.md`; `docs/handbook/figures/F1.svg`; `docs/handbook/figures/F10.svg` | Keep F1 opener/diagram/caption/explanation together or as an explicit adjacent spread, preserve label legibility, remove title-only/caption-only/orphan pages, correct F10 identity, and populate usable contents/folio/revision fields from rendered-output checks. | P3-LAYOUT-01 (ADOPTED); P3-LAYOUT-02 (ADOPTED) |
| P4-16 | P4-DISPOSITION-01 | P2 | 265–266, 274–275 | `docs/handbook/parts/IX-disposition-log.md` | Separate source integration, specification completeness, verification, runtime conformance, and owner acceptance; update imported evidence to the exact source identity and retain residual work without falsely converting a procedure into a passed readback. | P3-CONSISTENCY-01 (ADOPTED); P3-MODULES-01 (ADOPTED) |

All paths above are repository-relative. No file outside the four waves below is implied.

## Resolved-decision conflict guards

No pass-4 finding authorizes reopening or changing a settled product decision. The following findings must be implemented with these guards; a correction that violates one is a conflict and must be rejected during integration:

| Finding(s) | Conflict guard from resolved decision |
|---|---|
| P4-02, P4-04, P4-05, P4-10, P4-14 | Preserve the selected path: project foreman runs inside its Bunker; Crier is the launch/return boundary; Scheduler on the control host records the return. Node-pull or central-dispatcher descriptions are compatibility/legacy partitions, not a new MVP authority. |
| P4-06 | Preserve V2-Q-01/V2-Q-02: a round may complete multiple compatible successive waves, and its total worker allowance spans the whole round; a new wave does not replenish it and the allowance is not the simultaneous-concurrency ceiling. |
| P4-07, P4-05, P4-14 | Preserve V2-Q-03/V2-Q-04: worker, wave, and completed-round memory records remain distinct; DuckBrain outage permits useful work to continue with durable pending entries for later synchronization. |
| P4-07 | DuckBrain is locally available in Git-backed namespace repositories. Do not require the HTTP server for local query/persistence or invent an unrelated memory store; specify shared-view synchronization and freshness separately. |
| P4-01, P4-03, P4-11 | Desired configuration remains user/agent-declared and manager-reconciled; Boardctl remains project-work authority; Factory webhooks emit only, while receivers own interpretation, paging, and repair action. |
| P4-08, P4-09, P4-13 | No universal Bunker mode is selected. Keep deployment profiles capability-qualified; Terminal Jail remains optional and disabled by default; preserve separate platform, forge, memory, and inference credential domains, and cover GitLab without inventing an unconfirmed provider list. |
| P4-16 | The pass-3 ledger state is recorded as 26/26 ADOPTED. P4-DISPOSITION-01's request to downgrade P3-CONSISTENCY-01 is therefore a conflict with prior ledger state, not a permission to silently rewrite it. Track the pass-4 residual as a new P4 disposition and preserve the monotonic history. |

## Proposed parallel integration waves

Each wave owns a disjoint set of files. A wave may read every other handbook source for consistency, but it must not edit another wave's files. Wave 3 is the final rendering/layout wave and runs the full book build after the preceding contract work is integrated.

### Wave 1 — normative control model, contracts, settings, and memory

Owns exactly:

- `docs/handbook/parts/I-system-arrangement.md`
- `docs/handbook/parts/IV-contract-register.md`
- `docs/handbook/parts/V-settings.md`
- `docs/handbook/parts/VII-work-derivation.md`

Primary findings: P4-01, P4-02, P4-03, P4-06, P4-07, P4-11. This wave establishes the schemas and state vocabulary consumed by the module and figure waves.

### Wave 2 — module operations and failure/recovery

Owns exactly:

- `docs/handbook/chapters/M1-provisioning.md`
- `docs/handbook/chapters/M3-repository.md`
- `docs/handbook/chapters/M4-board.md`
- `docs/handbook/chapters/M7-github.md`
- `docs/handbook/chapters/M12-inference-proxy.md`
- `docs/handbook/parts/VI-failure-risk.md`

Primary findings: P4-04, P4-05, P4-08, P4-09, P4-10, P4-12, P4-13. M0/M2/M5/M6/M8/M9/M10/M11 are read-only compatibility references in this wave; no worker may edit them under this fence.

### Wave 3 — flows, figures, consistency generation, and final layout/build

Owns exactly:

- `docs/handbook/parts/II-flows.md`
- `docs/handbook/figures/system-map.svg`
- `docs/handbook/figures/board-lifecycle.svg`
- `docs/handbook/figures/tick-lifecycle.svg`
- `docs/handbook/figures/F1.svg`
- `docs/handbook/figures/F2.svg`
- `docs/handbook/figures/F3.svg`
- `docs/handbook/figures/F4.svg`
- `docs/handbook/figures/F5.svg`
- `docs/handbook/figures/F6.svg`
- `docs/handbook/figures/F7.svg`
- `docs/handbook/figures/F8.svg`
- `docs/handbook/figures/F9.svg`
- `docs/handbook/figures/F10.svg`
- `docs/handbook/figures/F11.svg`
- `docs/handbook/figures/F12.svg`
- `docs/handbook/figures/F13.svg`
- `docs/handbook/figures/F14.svg`
- `docs/handbook/figures/F15.svg`
- `docs/handbook/figures/F16.svg`
- `docs/handbook/figures/module-M0.svg`
- `docs/handbook/figures/module-M1.svg`
- `docs/handbook/figures/module-M2.svg`
- `docs/handbook/figures/module-M3.svg`
- `docs/handbook/figures/module-M4.svg`
- `docs/handbook/figures/module-M5.svg`
- `docs/handbook/figures/module-M6.svg`
- `docs/handbook/figures/module-M7.svg`
- `docs/handbook/figures/module-M8.svg`
- `docs/handbook/figures/module-M9.svg`
- `docs/handbook/figures/module-M10.svg`
- `docs/handbook/figures/module-M11.svg`
- `docs/handbook/figures/module-M12.svg`
- `scripts/build_book.py`

Primary findings: P4-14 and P4-15. This wave consumes the normative contracts and module corrections, regenerates arrangement/flow/module views, and is the only wave authorized to run the full book build.

### Wave 4 — delivery evidence and disposition history

Owns exactly:

- `docs/handbook/parts/VIII-delivery.md`
- `docs/handbook/parts/IX-disposition-log.md`

Primary finding: P4-16. This wave records the new residual dispositions and evidence boundaries without changing the settled pass-3 history or absorbing source corrections owned by Waves 1–3.

## Count by primary target section

Each finding is counted once by its primary edit owner; read-only cross-checks do not create a second count.

| Primary target section | Findings | Plan IDs |
|---|---:|---|
| Part I — System arrangement | 1 | P4-03 |
| Part II — Flows | 0 | — |
| Part III — Modules (M0–M12) | 5 | P4-04, P4-08, P4-09, P4-10, P4-13 |
| Part IV — Contract register | 1 | P4-02 |
| Part V — Settings register | 3 | P4-01, P4-06, P4-11 |
| Part VI — Failure and risk | 2 | P4-05, P4-12 |
| Part VII — Work derivation | 1 | P4-07 |
| Part VIII — Delivery | 0 | — |
| Part IX — Disposition log | 1 | P4-16 |
| Figures / `scripts/build_book.py` | 2 | P4-14, P4-15 |
| **Total** | **16** | **P4-01 through P4-16** |

## Acceptance handoff

1. Preserve all pass-4 source IDs and prior-ID links; do not renumber or erase the 26 pass-3 ADOPTED rows.
2. Apply Wave 1 contracts before treating module prose, figures, or worked examples as authoritative.
3. Keep the four resolved decision families explicit in every affected schema, flow, figure, and disposition.
4. Exercise the handoff's concrete cases: bootstrap/enrollment, desired-state change, two-wave admission, competing claims from separate clones, judge rejection/correction, integrated publication, memory outage/sync, durable Crier return, lost launch acknowledgement, partition/fence, revocation, endpoint replay, and isolated consistent restore.
5. Run `python3 scripts/handbook_lint.py` after each source wave and before commit. Do not run the full book build in this triage pass; Wave 3 owns that final build.
6. Record evidence as edited text, complete design, runtime conformance, and owner acceptance separately. A defined readback procedure is not a passed readback.

pass4 received, 16 findings, plan committed in this change; source record `CF2A-01-pass4-review-log.json`.