# CF2A-01 pass-3 triage plan

Review package: CF2A-01 third-batch full-document buildability audit, received 2026-11-09.
Canonical review record: `CF2A-01-pass3-review-log.json` (26 findings; 50 prior findings cross-checked).
This file is a planning artifact. It does not apply any handbook, figure, script, or manifest correction.

## Finding register

The `P3-nn` number is the plan identity. The source finding ID is retained for traceability. Target files are the primary ownership seam; adjacent prose or figures are cross-checked by the owning wave, not silently assigned to another wave.

| Plan ID | Source ID | Severity | Target file(s) | One-line correction summary | Repeats / prior disposition |
|---|---|---:|---|---|---|
| P3-01 | P3-FLW-01 | P2 | `docs/handbook/parts/II-flows.md`; `docs/handbook/figures/F2.svg` | Add the Factory manager to F2, route verification/readiness to its real owner, and define the readiness identity/version handed to Scheduler. | V2-FLW-11; V2-ARCH-01 |
| P3-02 | P3-LAYOUT-01 | P2 | `docs/handbook/parts/II-flows.md`; `docs/handbook/figures/F10.svg` | Replace F10's duplicate Figure 2.1 caption with its unique Figure 2.10 identity and reconcile generated references. | V2-FLW-09; V2-FLW-11 |
| P3-03 | P3-INT-01 | P1 | `docs/handbook/parts/IV-contract-register.md` | Replace citation/request placeholders with complete versioned observable contracts, examples, errors, state, idempotency and persistence boundaries, including CT-06R. | V2-ARCH-03; V2-FLW-03; V2-WRK-03 |
| P3-04 | P3-CONFIG-01 | P1 | `docs/handbook/parts/V-settings.md` | Publish the complete canonical settings schema, native mappings, precedence, validation, generation conflicts, activation and effective-readback API. | V2-SET-01; V2-SET-02; V2-SET-03; V2-SET-05 |
| P3-05 | P3-CONFIG-02 | P2 | `docs/handbook/parts/V-settings.md` | Separate repository identity from credential references, correct convergence/readback evidence, and preserve total-round budget across successive waves independently of concurrency. | V2-SET-07; V2-SET-08 |
| P3-06 | P3-MEM-01 | P1 | `docs/handbook/parts/V-settings.md`; `docs/handbook/parts/VII-work-derivation.md` | Specify one supported same-namespace local/remote memory profile with record identity, durable local acknowledgement, synchronization, conflicts, freshness and recovery. | V2-FLW-05; V2-WRK-04; V2-SET-05 |
| P3-07 | P3-WORK-01 | P1 | `docs/handbook/parts/VII-work-derivation.md` | Make the target round/worker/wave/result/memory protocol fully versioned and replace conflicting legacy narratives with an explicit compatibility mapping. | V2-FLW-03; V2-WRK-02; V2-WRK-03; V2-WRK-04 |
| P3-08 | P3-RECOVERY-01 | P1 | `docs/handbook/parts/VI-failure-risk.md` | Define durable reservation/launch/attempt accounting, resource-side fencing, stale-owner replacement and crash-point recovery without double debit or duplicate publication. | V2-ARCH-01; V2-ARR-07; V2-WRK-04 |
| P3-09 | P3-OPS-01 | P1 | `docs/handbook/parts/V-settings.md` | Add versioned Factory event/subscription delivery contracts and independent metric collection/readout semantics, leaving receiver interpretation external. | V2-OPS-01; V2-OPS-02; V2-SET-08 |
| P3-10 | P3-DISPATCH-01 | P1 | `docs/handbook/parts/II-flows.md`; `docs/handbook/chapters/M2-dispatch.md`; `docs/handbook/chapters/M10-crier.md`; `docs/handbook/chapters/M11-dispatcher.md` | Select or partition execution consumers around one normative Crier launch/return path with durable identity, leases, cancellation, deduplication and late-result rules. | M2 prior review; CT-03; CT-04 |
| P3-11 | P3-BOARD-01 | P1 | `docs/handbook/parts/VII-work-derivation.md`; `docs/handbook/chapters/M4-board.md` | Supply canonical eligibility, cross-clone compare-and-set claim/fence, evidence validation and idempotent partial-write recovery separate from scheduler admission. | M4 prior review; CT-10; CT-13; CT-14 |
| P3-12 | P3-MODULES-01 | P1 | `docs/handbook/chapters/M0-shared-contract.md`; `docs/handbook/chapters/M1-provisioning.md`; `docs/handbook/chapters/M2-dispatch.md`; `docs/handbook/chapters/M3-repository.md`; `docs/handbook/chapters/M4-board.md`; `docs/handbook/chapters/M5-harness.md`; `docs/handbook/chapters/M6-documentation.md`; `docs/handbook/chapters/M7-github.md`; `docs/handbook/chapters/M8-safety.md`; `docs/handbook/chapters/M9-scheduler.md`; `docs/handbook/chapters/M10-crier.md`; `docs/handbook/chapters/M11-dispatcher.md`; `docs/handbook/chapters/M12-inference-proxy.md` | Replace redline-to-author instructions with actual contracts, schemas, state/sequence tables, configuration cards, examples and falsifiable acceptance cases in every affected module. | Standing buildable-specification standard |
| P3-13 | P3-M0-01 | P2 | `docs/handbook/chapters/M0-shared-contract.md` | Make the `have()` caller agree with its absent-executable result contract and define every helper used by the executable example. | M0 prior review |
| P3-14 | P3-REPO-01 | P1 | `docs/handbook/chapters/M3-repository.md` | Define one gate/publication policy with evidence binding, integration serialization, remote proof freshness, authorized exceptions and recovery states. | M3 prior review; F5; CT-12; CT-13 |
| P3-15 | P3-PROVISION-01 | P1 | `docs/handbook/chapters/M1-provisioning.md`; `docs/handbook/chapters/M5-harness.md` | Supply one qualified reproducible MVP profile plus explicit profile support, bootstrap, artifact, credential, registration, readiness, migration and rollback contracts. | M1 prior review; M5 prior review; F2; F10 |
| P3-16 | P3-FORGE-01 | P1 | `docs/handbook/chapters/M7-github.md` | Define provider-neutral and GitHub/GitLab-specific mappings, permissions, issuer ownership, secure delivery, renewal, scope reduction, revocation and restore behavior. | M7 prior review; F12 |
| P3-17 | P3-PROXY-01 | P1 | `docs/handbook/chapters/M12-inference-proxy.md` | Define node-token lifecycle, supported model API/stream errors, authorization/accounting, capture policy and deployable source/replacement contract. | M12 prior review; CT-19; CT-20 |
| P3-18 | P3-SCHED-01 | P1 | `docs/handbook/chapters/M9-scheduler.md` | Specify typed route/admission/hook/settlement transitions and normalize scheduler execution settlement against foreman acceptance/publication/closeout. | M9 prior review; F1; F11 |
| P3-19 | P3-SAFETY-01 | P1 | `docs/handbook/chapters/M8-safety.md` | Qualify the Bunker baseline, specify optional guarded execution and safe cleanup lease/reference races, and correct the cache/job TTL scope. | M8 prior review; F6; Terminal Jail decision |
| P3-20 | P3-CONSISTENCY-01 | P2 | `docs/handbook/parts/VI-failure-risk.md`; `docs/handbook/parts/VIII-delivery.md` | Normalize stale tables, figures, statuses, labels and gate claims to one dated normative path, removing contradictory legacy prose. | Cross-section consistency standard |
| P3-21 | P3-MANAGER-01 | P1 | `docs/handbook/parts/I-system-arrangement.md` | Turn the deterministic IaC manager from a catalog of future work into a versioned resource/API, reconciliation, allocation, adapter, readiness and recovery contract. | V2-MISSION-01; V2-ARCH-01; V2-ARCH-03; V2-SET-08 |
| P3-22 | P3-RECOVERY-02 | P1 | `docs/handbook/parts/VI-failure-risk.md` | Define consistent backup capture/checkpoint, artifact manifest, retention/destination, key/revocation handling, isolated restore ordering and recovery bounds. | V2-FLW-08; F8; F10; F15 |
| P3-23 | P3-ACCESS-01 | P1 | `docs/handbook/chapters/M1-provisioning.md` | Define controller/Bunker enrollment, trust, principal/resource authorization, credential delivery/readback, rotation, revocation, offboarding and restore enforcement. | V2-FLW-07; V2-SET-04 |
| P3-24 | P3-FLW-02 | P2 | `docs/handbook/parts/II-flows.md`; `docs/handbook/figures/F1.svg`; `docs/handbook/figures/F2.svg`; `docs/handbook/figures/F3.svg`; `docs/handbook/figures/F5.svg`; `docs/handbook/figures/F6.svg`; `docs/handbook/figures/F7.svg`; `docs/handbook/figures/F8.svg`; `docs/handbook/figures/F9.svg`; `docs/handbook/figures/F10.svg`; `docs/handbook/figures/F11.svg`; `docs/handbook/figures/F12.svg`; `docs/handbook/figures/F13.svg`; `docs/handbook/figures/F14.svg`; `docs/handbook/figures/F15.svg`; `docs/handbook/figures/F16.svg` | Reconcile all sixteen diagrams to the selected normative initiator, receiver, order, branches, proof-before-activation and recovery semantics. | V2-FLW-11; V2-FLW-06 |
| P3-25 | P3-DIAGRAM-01 | P2 | `docs/handbook/figures/system-map.svg`; `docs/handbook/figures/board-lifecycle.svg`; `docs/handbook/figures/tick-lifecycle.svg`; `docs/handbook/figures/module-M0.svg`; `docs/handbook/figures/module-M1.svg`; `docs/handbook/figures/module-M2.svg`; `docs/handbook/figures/module-M3.svg`; `docs/handbook/figures/module-M4.svg`; `docs/handbook/figures/module-M5.svg`; `docs/handbook/figures/module-M6.svg`; `docs/handbook/figures/module-M7.svg`; `docs/handbook/figures/module-M8.svg`; `docs/handbook/figures/module-M9.svg`; `docs/handbook/figures/module-M10.svg`; `docs/handbook/figures/module-M11.svg`; `docs/handbook/figures/module-M12.svg` | Regenerate arrangement and module views from the reconciled model with explicit manager, state, credential boundaries, locations, directions, IDs and target-versus-evidence legends. | V2-ARR-02; V2-ARR-04; V2-ARR-05; M4 Figure 3.4 |
| P3-26 | P3-LAYOUT-02 | P2 | `scripts/build_book.py`; `docs/handbook/parts/II-flows.md` | Keep figure explanations and headings with their content, add navigable folios/field values, split illegible diagrams, and eliminate title-only/orphan sheets without padding. | V2-LAYOUT-01; V2-SET-07; V2-DLV-04; NASA handbook authoring standard |

## Findings that are constrained by resolved user decisions

These are flagged for bounded application, not rejected and not applied by this triage commit. The implementation wave must preserve the decision text in the canonical review record and must not reopen it as a design question.

| Finding(s) | Resolved decision constraint |
|---|---|
| P3-01, P3-21 | The Factory manager is a required deterministic management/orchestration layer; it is not replaced by Scheduler or Boardctl. Boardctl remains project-work authority, while desired configuration remains user/agent-declared and manager-reconciled. |
| P3-04, P3-05, P3-21 | Configuration authority is the declared configuration file managed by the user/agent; the manager reconciles current state. Do not make Boardctl the configuration authority or silently rewrite desired capacity/access intent. |
| P3-05, P3-07, P3-08 | The total-worker budget belongs to the entire foreman round, spans successive compatible waves, is a cap rather than a concurrency ceiling, and is not replenished by a new wave. Retry/resume accounting must be explicit. |
| P3-06, P3-07, P3-08, P3-24 | Preserve distinct worker, wave and completed-round memory records and their correlations. A service outage permits useful work to continue with durable pending entries for later synchronization; scheduler/Git history is not a substitute for those records. |
| P3-06 | DuckBrain is locally available in Git-backed namespace repositories. Do not require HTTP availability for local queries/persistence and do not invent a separate unrelated memory store; specify synchronization and controller-visible freshness separately. |
| P3-10, P3-18, P3-24 | The project foreman runs inside its Bunker, and Crier is the launch/return boundary to the control-host Scheduler. Any node-pull or central-dispatcher description must be explicitly partitioned or marked migration/legacy, never silently made a competing MVP authority. |
| P3-15, P3-23 | No universal Bunker execution mode is selected. Specify a qualified profile and per-profile support/readiness/readback; platform examples do not establish universal Kubernetes, Compose, homelab or standalone support. |
| P3-19 | Bunker baseline protection is required independently. Terminal Jail remains optional and disabled by default; when enabled, Hermes must use the guarded path with no unguarded fallback. |
| P3-09 | Factory responsibility ends at configurable event delivery. Receivers own interpretation, paging, logging and external repair-agent action; the Factory must not silently acquire that role. |
| P3-16, P3-17, P3-23 | Preserve separate forge, platform/bus, memory and inference identity domains, and cover GitLab in addition to GitHub without inventing an unconfirmed provider list. |

## Proposed parallel integration waves

These are future integration seams. No two waves own the same file. A wave may read other files for reconciliation but may edit only its ownership list. The present triage commit edits only `PASS3-PLAN.md` and the intake row in `parts/IX-disposition-log.md`; it does not execute these source corrections.

### Wave 1 — control model, contracts, settings and work authority

Owns exactly:

- `docs/handbook/parts/I-system-arrangement.md`
- `docs/handbook/parts/IV-contract-register.md`
- `docs/handbook/parts/V-settings.md`
- `docs/handbook/parts/VII-work-derivation.md`

Primary findings: P3-03, P3-04, P3-05, P3-06, P3-07, P3-09, P3-11, P3-21. This wave defines the manager/configuration/memory/round/claim contracts before prose and drawings are reconciled.

### Wave 2 — flows, figures and pagination

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
- `scripts/build_book.py`

Primary findings: P3-01, P3-02, P3-10, P3-24, P3-25, P3-26. This wave consumes Wave 1's selected contracts but owns all flow/figure/layout changes.

### Wave 3 — module contract chapters and failure/recovery

Owns exactly:

- `docs/handbook/chapters/M0-shared-contract.md`
- `docs/handbook/chapters/M1-provisioning.md`
- `docs/handbook/chapters/M2-dispatch.md`
- `docs/handbook/chapters/M3-repository.md`
- `docs/handbook/chapters/M4-board.md`
- `docs/handbook/chapters/M5-harness.md`
- `docs/handbook/chapters/M6-documentation.md`
- `docs/handbook/chapters/M7-github.md`
- `docs/handbook/chapters/M8-safety.md`
- `docs/handbook/chapters/M9-scheduler.md`
- `docs/handbook/chapters/M10-crier.md`
- `docs/handbook/chapters/M11-dispatcher.md`
- `docs/handbook/chapters/M12-inference-proxy.md`
- `docs/handbook/parts/VI-failure-risk.md`

Primary findings: P3-08, P3-12, P3-13, P3-14, P3-15, P3-16, P3-17, P3-18, P3-19, P3-20, P3-22, P3-23. Module owners must implement the selected contracts and recovery semantics without editing Wave 1/2 files.

### Wave 4 — delivery reconciliation and disposition evidence

Owns exactly:

- `docs/handbook/parts/VIII-delivery.md`
- `docs/handbook/parts/IX-disposition-log.md`

Primary findings: P3-20 (delivery-side consistency evidence). This wave records disposition/proof and keeps delivery acceptance, publication proof and owner acceptance distinct; it does not absorb source corrections from Waves 1–3.

## Count by primary target section

| Section | Findings |
|---|---:|
| Part I — System arrangement | 1 |
| Part II — Flows and figures | 6 |
| Part III — Modules (M0–M12) | 9 |
| Part IV — Contract register | 1 |
| Part V — Settings register | 4 |
| Part VI — Failure and risk | 3 |
| Part VII — Work derivation | 2 |
| Part VIII — Delivery | 0 |
| Part IX — Disposition log | 0 |
| **Total** | **26** |

Primary-section accounting assigns each finding once: P3-01/02/10/24/26 to Part II; P3-03 to Part IV; P3-04/05/06/09 to Part V; P3-07/11 to Part VII; P3-08/20/22 to Part VI; P3-12/13/14/15/16/17/18/19/23 to Part III; and P3-21 to Part I. P3-25 is a Part II/figures integration finding and is counted with Part II. P3-20 also requires the Part VIII consistency readback, but its primary owner is Part VI.

## Acceptance handoff for the next revision

1. Preserve all 26 `P3-nn` identities and source IDs in later dispositions.
2. Resolve the Wave 1 normative contracts before treating diagram arrows or module prose as authoritative.
3. Render and inspect every affected flow/module figure; a green source build alone does not close visual findings.
4. Exercise positive, refusal, retry, restart, duplicate, stale-owner, outage and partial-recovery examples for each contract family.
5. Keep unresolved or target-unimplemented claims explicit, and record the exact revised artifact identity and evidence in Part IX.
