# CF2A-01 — Pass-7 integration triage and correction plan

Review base: `176378c1f4ea2685925b4fece04d4bd286d716c4` (`main` at review time). The reviewed artifact is 406 pages, 14,322,225 bytes, SHA-256 `6dd047f5174f325f73a25b0d88843e29e48d63781103d9faba68d05dc1cb7e3f`. Review source package: `/home/kara/.hermes/cache/scratch/pass7/`, nine files. The canonical review record is `CF2A-01-pass7-review-log.json`, SHA-256 `45b7d2244de62681a242b83cf18a913976d89843e59dd562307f1825cacdc810`; the primary correction source is `CF2A-01-pass7-feedback.txt`, SHA-256 `b139c43dcc23a794fab9f1561f00752c492b4caaff0ab42e93171bc4b21e8d44`.

The pass-7 verdict is **NOT YET BUILDABLE END TO END FROM THE DELIVERED SPECIFICATION ALONE**. The review records 20 actionable findings: 9 critical, 10 high and 1 medium. Sixteen findings carry forward immediately prior `P6-*` stable IDs and are re-opened by the current printed revision; four are new current-revision integration findings with `P7-*` stable IDs. The review explicitly closes the older model-caption digest and numbered `n OF 406` page-stamp feedback; no row below re-opens either subissue.

## 1. Evidence grade, resolved decisions and decision slots

### 1.1 Runtime evidence is not page presence

The pass-7 review corrects a standing evidence-grade error. The sixteen P6 disposition rows in Part IX recorded `PASS — independent full-page readback` in the runtime-conformance column. A page readback proves that corrected text is present in the rendered artifact; it does not prove that the described launch, lease, backup, cancellation or publication path executed. Those cells are corrected to **UNVERIFIED — page readback is rendered-source evidence; version-bound execution evidence absent**. The correction changes only the runtime-conformance cell; the disposition, resolving commit and historical readback references remain intact.

The corrected evidence classes are:

| Class | What it proves | What it cannot prove |
|---|---|---|
| Source integration | The named contract text is present at the named source revision | That independent consumers agree on the bytes |
| Rendered-source readback | The corrected text and figure are present in the built PDF | That the described operation ran |
| Version-bound execution | A recorded run executed the named artifact, inputs and negative controls at the named version | Owner acceptance |
| Independent completeness | Cross-contract closure checks pass against one canonical record set | Runtime behaviour under load, recovery or external failure |
| Owner acceptance | The owner has accepted the delivered result | Any of the above by itself |

No pass-7 disposition may use the first two classes as a runtime PASS. The conformance bundle required by P7-13 supplies the executable positive and negative cases; the runtime column remains UNVERIFIED until a separate version-bound execution receipt exists.

### 1.2 Resolved-decision conflict screen

The review states that no new product-direction decision is required. The following corrections nevertheless touch resolved decisions and are constrained as shown. No row may silently reverse a resolved decision by presenting the reversal as an implementation detail.

| Finding | Proposed correction that would conflict | Resolved decision retained | Plan disposition |
|---|---|---|---|
| P7-04 | Amend the no-shared-group rule to create a restricted socket group | Four distinct UIDs with no shared supplementary group | Reject the group amendment. Use explicit ACL plus directory traversal, or a preconnected descriptor passed by the trusted launcher. Fail-closed readiness refuses if neither is specified. |
| P7-07 | Permit publication when the independent judge is unavailable or rejecting | Publication requires an accepted independent judgment; mechanical evidence is separate | Keep the mandatory accepted-judgment baseline. State the decision table; do not widen publication authority by prose. |
| P7-18 | Let Crier allocate `registration_id` | Controller preallocates `registration_id`; Crier allocates `node_id` and `registration_generation` | Keep controller allocation. Correct the allocator sentence and every identity table. A whole-protocol redesign requires an explicit owner decision and is out of scope. |
| P7-15 | Formally revise the accepted body/table/code floors to match the current rendering | The NASA Handbook presentation standard is the accepted standard | Implement the declared floors. A formal standard revision is an owner decision and is not authorized by this plan. |
| P7-13 | Require a reader to infer an unspecified repository checkout for fixtures | The specification must be buildable without reverse-engineering source | Ship a hash-pinned companion bundle with the model, schemas, fixture bytes and expected outputs. No checkout inference. |

### 1.3 Decision slots

Each slot names the options, the fail-closed default and the evidence that closes it. A slot is not closed by a prose preference; it is closed by a selected option propagated through every named consumer and by the stated closure check.

| Slot | Question | Options | Fail-closed default | Closure evidence |
|---|---|---|---|---|
| D1 | How is the identity cycle removed? | A. Layered commitment with hash-exempt bootstrap identities (LCR-1). B. Flat exclusion list only, with `dispatch_id` allocated directly. | A | SC7-01 has no cycle; cold CT-02 then CT-05 computed once; independent encoder and supervisor recompute the same bytes. |
| D2 | How does the foreman reach `control.sock` under four UIDs? | A. Explicit ACL plus directory traversal. B. Preconnected descriptor from the trusted launcher. C. Amend the no-shared-group rule. | A, then B if platform evidence shows A cannot work; C is rejected | Positive readiness probe passes as the foreman; worker-negative arm still refuses; restart and revocation cases pass. |
| D3 | What authorizes a protected publication? | A. Mandatory accepted independent judgment plus mechanical evidence. B. Product-policy exception for unavailable judgment. | A | One publication decision table; every protected effect has an accepted judgment or is denied; F5 and VII agree. |
| D4 | Who allocates enrollment identity? | A. Controller preallocates `registration_id`; Crier allocates `node_id` and generation. B. Whole grant protocol redesign with Crier allocation. | A | Initial request identity, duplicate lookup, replay bytes and renewal are identical across I, IV, VII and M1. |
| D5 | How is backup content separated from lifecycle state? | A. Immutable captured inventory plus mutable operation and release receipts. B. Versioned immutable manifest revisions with explicit linkage. | A | The signed content object never changes after validation; upload, readback, release and retention name separate objects; restore reads the immutable object. |
| D6 | What evidence grade permits a runtime PASS? | A. Version-bound execution record naming artifact, inputs and negative controls. B. Rendered-source readback. | A; B is rendered-source evidence only | Runtime cells remain UNVERIFIED without A; the conformance bundle records which cases actually executed. |
| D7 | How are layout floors handled? | A. Meet the declared body/table/code floors. B. Formally revise the accepted standard. | A | Font census, body/table/code measurements and page census pass against the declared floors. |

## 2. Finding register

Paths beginning `parts/` or `chapters/` are under `docs/handbook/`. The primary target is the section used for the census; every implementation target is owned by exactly one wave in section 5. The new id is local to this plan; the source id is the review's stable identity and is the id that dispositions must cite.

| New id | Source id / severity / pages | Primary target | Correction summary and implementation targets |
|---|---|---|---|
| **P7-01** | P6-LAUNCH-01 · critical · 133, 173, 250, 266 | `parts/IV-contract-register.md` | Publish an acyclic identity graph under LCR-1: preallocate `launch_id`, exclude every derived identity from the bootstrap input domain, then derive `dispatch_id` and `execution_key` once and require recomputation rather than iteration. Targets: `docs/SYSTEM-MODEL.yaml`; `docs/handbook/contract-vectors.json`; `parts/I-system-arrangement.md`; `parts/IV-contract-register.md`; `chapters/M2-dispatch.md`; `chapters/M5-harness.md`; `chapters/M9-scheduler.md`; `chapters/M11-dispatcher.md`. |
| **P7-02** | P6-REQUEST-DIGEST-01 · critical · 35, 37, 275 | `parts/IV-contract-register.md` | Give `request_digest` and the replay digest domain-separated formulas with exact exclusion lists and a complete mapping when they differ; apply them to every new certificate, capability, grant, binding and transfer operation and to readback and deduplication records. Targets: `parts/I-system-arrangement.md` §1.9.10; `parts/IV-contract-register.md` §2.3; `docs/handbook/contract-vectors.json`; `chapters/M10-crier.md`. |
| **P7-03** | P6-CUSTODY-01 · critical · 239, 240 | `chapters/M10-crier.md` | Separate the unsigned response payload, receipt body, `receipt_digest` and outer signed envelope into topologically ordered byte domains; exclude the embedded receipt and its digest from the response hash; state what the response binds and how a client verifies the same bytes. Targets: `chapters/M10-crier.md`; `parts/IV-contract-register.md`; `docs/handbook/contract-vectors.json`. |
| **P7-04** | P6-SOCKET-01 · critical · 37, 120, 121, 133, 173, 208, 250 | `chapters/M1-provisioning.md` | Specify one working mediated access path for `control.sock` under the four-UID no-shared-group profile: explicit ACL plus directory traversal, or a preconnected descriptor from the trusted launcher; define ownership, inheritance, authentication, restart and revocation. Targets: `chapters/M1-provisioning.md` §17.5; `chapters/M5-harness.md` §16.1; `parts/I-system-arrangement.md`; `parts/IV-contract-register.md`. |
| **P7-05** | P6-BOARD-01 · critical · 156, 157, 158, 272, 355, 371 | `chapters/M4-board.md` | Generate the M4 and CT-10 group-claim request, result and marker types from one definition: one bound, one precondition type, one ordering and one GitOID structure; separate group creation from existing-claim renew and release; define marker and wave-plan membership; reconcile private staging failure with published malformed state. Targets: `chapters/M4-board.md`; `parts/IV-contract-register.md` CT-10; `parts/VII-work-derivation.md`; `parts/VI-failure-risk.md` §35.2; `docs/handbook/contract-vectors.json`. |
| **P7-06** | P6-EVIDENCE-01 · critical · 96, 143, 144, 145, 156, 266, 269, 371 | `parts/IV-contract-register.md` | Choose one canonical executable Criterion plus explicit storage and display projections; define phase-discriminated staged, source, integrated, publication and closure records; publish lossless adapters or version the alternatives; state the accepted-object versus observed-tip rule once. Targets: `parts/IV-contract-register.md`; `chapters/M0-shared-contract.md`; `chapters/M3-repository.md`; `chapters/M4-board.md`; `parts/VII-work-derivation.md`; `docs/handbook/contract-vectors.json`. |
| **P7-07** | P6-GATES-01 · critical · 144, 145, 158, 371 | `chapters/M3-repository.md` | State one publication decision table for required and optional judgments, mechanical failures, `needs_work`, unavailable evidence and exceptions; keep the mandatory accepted-judgment baseline; separate recording mechanical checks from granting the protected publication effect; align M3, M4, F5 and VII. Targets: `chapters/M3-repository.md` §17; `chapters/M4-board.md` §15.4; `parts/VII-work-derivation.md`; `parts/II-flows.md`; `docs/handbook/contract-vectors.json`. |
| **P7-08** | P6-MEMORY-01 · critical · 271, 275, 312, 348, 371, 372 | `parts/VII-work-derivation.md` | Remove the round-report and memory cycle with a layered commitment: the summary body omits its own memory reference and `report_digest`; the final report may include the summary digest but not the reverse; publish one role-discriminated envelope and body union with writer and record-type mapping. Targets: `parts/VII-work-derivation.md` §18; `parts/IV-contract-register.md` CT-09; `parts/V-settings.md`; `docs/handbook/contract-vectors.json`. |
| **P7-09** | P6-STATE-01 · high · 35, 38, 132, 173, 250, 271 | `parts/VII-work-derivation.md` | Give total projection tables from execution journal to `LaunchResponse` and from task, wave and round outcome to CT-06 settlement, including uniform unverified, all-fail, empty or zero-budget, cancelled, expired-start, unknown-control and late-evidence cases; add an explicit ambiguity state instead of coercing unknown. Targets: `parts/VII-work-derivation.md`; `parts/IV-contract-register.md`; `chapters/M2-dispatch.md`; `chapters/M5-harness.md`; `chapters/M9-scheduler.md`; `chapters/M11-dispatcher.md`. |
| **P7-10** | P6-LIMITS-01 · high · 132, 269, 270, 311, 360 | `parts/V-settings.md` | Specify the durable deadline origin and the stored absolute and monotonic representation for round, attempt, turn and tick, including restart conversion and reserves; use only actual CT-02 execution fields; make tick, round and postcheck budget equations dimensionally explicit; label or align the older at-least-one-worker card. Targets: `parts/V-settings.md` §12; `chapters/M2-dispatch.md` §15.3; `parts/IV-contract-register.md`; `parts/VII-work-derivation.md`; `docs/handbook/contract-vectors.json`. |
| **P7-11** | P6-BACKUP-01 · critical · 353, 354, 355 | `parts/VI-failure-risk.md` | Keep the immutable captured inventory and cut manifest distinct from backup operation state and signed publication and release receipts, or fully specify immutable versioned manifest revisions and their linkage; define the object named by off-host readback, retention and restore; preserve abort-and-hold and independent current revocation authority. Targets: `parts/VI-failure-risk.md` §35; `parts/V-settings.md`; `docs/handbook/contract-vectors.json`. |
| **P7-12** | P6-METRICS-01 · high · 95, 198, 262, 303, 304 | `chapters/M0-shared-contract.md` | Add exact discriminated event payload schemas or a mandatory typed reference to a separate immutable detail record; keep base labels bounded; separate observation age for source health from event age for activity and backlog; align M7 and readback examples. Targets: `chapters/M0-shared-contract.md`; `chapters/M7-github.md`; `chapters/M12-inference-proxy.md`; `parts/V-settings.md`; `docs/handbook/contract-vectors.json`. |
| **P7-13** | P6-FIXTURES-01 · high · 266, 270, 276, 277, 305, 306, 307, 308, 309, 310, 376, 377, 382 | `docs/handbook/conformance/manifest.json` | Deliver a hash-pinned, version-bound companion bundle beside the PDF: canonical model, machine-readable schemas, executable positive and negative vectors, non-secret fixture bytes and trust, independent expected outputs, and an external sidecar naming the bundle digest and its relation to the PDF bytes; correct the complete CT-02 example; keep shape-only examples visibly separate. Targets: `docs/handbook/conformance/manifest.json`; `docs/handbook/conformance/README.md`; `docs/handbook/conformance/schemas/`; `docs/handbook/conformance/fixtures/`; `docs/SYSTEM-MODEL.yaml`; `docs/handbook/contract-vectors.json`; `chapters/M1-provisioning.md`. |
| **P7-14** | P6-FIGURES-01 · high · 4, 6, 7, 43, 45, 67, 72, 74, 76, 78, 123, 147, 252 | `scripts/gen_handbook_figures.py` | Regenerate every affected drawing from the reconciled contracts; fix actor and consumer directions and trust placement in M2, M4, M12, F12, F14 and F15; expand F13 to show qualification, drain and fence, stage, verified backup, migration and switch, postchecks and allowed rollback or forward-repair branches; label historical drawings and keep the model identity current. Targets: `scripts/gen_handbook_figures.py`; `parts/II-flows.md`; every figure listed in Wave 4. |
| **P7-15** | P6-LAYOUT-01 · high · 2, 6, 7, 10, 11, 42, 43, 45, 46, 67, 173, 186, 276, 303, 400, 406 | `scripts/build_book.py` | Keep the numbered stamp; supply real contents destinations and consistent issue and change furniture; remove caption-only leaves; place the F1 functional paragraph directly below the image; use unique figure IDs and label intentional front duplicates as reprints; meet the declared body, table and code floors; check the embedded technical and code faces against the stated role lock. Targets: `docs/handbook/BOOK.yaml`; `scripts/build_book.py`; `scripts/book_style.py`; `parts/II-flows.md`; `chapters/M6-documentation.md`; `docs/handbook/figures/F1.svg`; `docs/handbook/figures/F10.svg`. |
| **P7-16** | P6-ISSUE-01 · medium · 1, 4, 400, 401, 402, 403, 404, 405, 406 | `parts/IX-disposition-log.md` | Deliver an external sidecar after final pagination for the exact bytes, pages and SHA-256, with source, model, fixture and build identities and seven separately classified acceptance results; retain older build and readback evidence as history; correct the full commit and complete revision and change furniture; disposition this review's exact stable IDs. Targets: `docs/handbook/BOOK.yaml`; `parts/00-overview.md`; `parts/VIII-delivery.md`; `parts/IX-disposition-log.md`; `chapters/M6-documentation.md`; `chapters/M11-dispatcher.md`. |
| **P7-17** | P7-CANCEL-01 · high · 132, 173, 174, 250, 371 | `parts/IV-contract-register.md` | Define a phase-discriminated cancellation request and result: a non-signalling state CAS for proven unstarted work, an incarnation-bound signal and quiescence for known native work, and retained cancel-request, quarantine and readback for ambiguous starts; specify repeat and terminal behavior and the start-release CAS race without requiring unavailable native IDs. Targets: `parts/IV-contract-register.md`; `chapters/M2-dispatch.md`; `chapters/M5-harness.md`; `chapters/M9-scheduler.md`; `chapters/M11-dispatcher.md`; `docs/handbook/contract-vectors.json`. |
| **P7-18** | P7-ENROLLMENT-01 · high · 16, 38, 39, 117, 267, 268, 273, 368 | `chapters/M1-provisioning.md` | Keep controller-preallocated `registration_id` and Crier-only `node_id` and `registration_generation`; correct the VII allocator sentence and every identity table; specify initial request identity before allocation, durable duplicate lookup before the first-generation CAS, response and readback mapping, and continuation steps; replay the original `expected_generation0` bytes and treat renewal as a separate operation. Targets: `chapters/M1-provisioning.md`; `parts/VII-work-derivation.md`; `parts/IV-contract-register.md`; `parts/I-system-arrangement.md`; `docs/handbook/contract-vectors.json`. |
| **P7-19** | P7-CONFIG-01 · high · 27, 28, 262, 263, 264, 273, 289 | `parts/V-settings.md` | Make one authoritative machine-readable `config.update` request and result schema and expand it identically in Part I, M12, Part V and CT-24; state whether scope is inferred or explicit, whether `operation_id` belongs in the request or only the receipt and readback, and how a permitted null-to-returned-ID retry is normalized before deduplication; preserve one global generation, whole-document authorization and file/API single-writer CAS. Targets: `parts/V-settings.md`; `parts/I-system-arrangement.md`; `chapters/M12-inference-proxy.md`; `parts/IV-contract-register.md` CT-24; `docs/handbook/contract-vectors.json`. |
| **P7-20** | P7-EVIDENCE-GRADE-01 · high · 276, 381, 382, 400, 401, 402, 403, 404, 405, 406 | `parts/IX-disposition-log.md` | Reclassify these receipts as rendered-source and readback evidence; runtime remains NOT RUN or UNVERIFIED absent actual qualified execution records; independent completeness requires the cross-contract closure checks in this review, not merely locating text; keep owner acceptance OPEN and maintain all seven release results separately; link each disposition to the exact current finding and artifact while preserving historical receipts. Targets: `parts/IX-disposition-log.md`; `parts/VIII-delivery.md`; `docs/handbook/PASS7-PLAN.md`; `docs/handbook/conformance/manifest.json`. |

### 2.1 Severity census

| Severity | Count | Finding ids |
|---|---:|---|
| Critical | 9 | P7-01, P7-02, P7-03, P7-04, P7-05, P7-06, P7-07, P7-08, P7-11 |
| High | 10 | P7-09, P7-10, P7-12, P7-13, P7-14, P7-15, P7-17, P7-18, P7-19, P7-20 |
| Medium | 1 | P7-16 |
| **Total** | **20** | **P7-01…P7-20** |

### 2.2 Primary-target census

| Target section | Count | Finding ids |
|---|---:|---|
| Front matter / overview | 0 | — |
| Part I — arrangement | 0 | — |
| Part II — flows | 0 as primary; integration owner in Wave 4 | — |
| Part III — modules | 6 | P7-03, P7-04, P7-05, P7-07, P7-12, P7-18 |
| Part IV — contracts | 4 | P7-01, P7-02, P7-06, P7-17 |
| Part V — settings | 2 | P7-10, P7-19 |
| Part VI — failure and risk | 1 | P7-11 |
| Part VII — work derivation | 2 | P7-08, P7-09 |
| Part VIII — delivery | 0 as primary; reissue target in Wave 4 | — |
| Part IX — dispositions | 2 | P7-16, P7-20 |
| Figures and generator | 1 | P7-14 |
| Build and layout scripts | 1 | P7-15 |
| Conformance bundle | 1 | P7-13 |
| **Total** | **20** | **P7-01…P7-20** |

## 3. Circular-hash reconciliation: LCR-1

The first blocker is not a wording dispute. Four families of records currently name a value inside the hash domain that is derived from the digest of that same record. The plan selects **Layered Commitment with hash-exempt bootstrap identities (LCR-1)**. LCR-1 is one rule applied to every affected family, not four local exceptions.

### 3.1 The rule

1. Every hash domain is declared as a closed field list plus an explicit `excluded_derived` list. A field is either covered or excluded; there is no implicit coverage and no domain that covers its own output.
2. Every identity is allocated before it is hashed by the component that owns it. Allocation is durable and idempotent. A derived identifier is never an input to the digest that produces it.
3. Records are constructed in layers. A layer may include the digest of a lower layer. A lower layer may not include the digest of a higher layer, and a record may not include its own digest or signature.
4. The construction order is `content → record → envelope`. The order is normative; readers recompute in the same order and reject a record whose lower-layer digest changes when a higher-layer field changes.
5. Derived identifiers are validated by recomputation, not by iteration. A mismatch is a `CONTRACT_INVALID` refusal; a search for a fixed point is never an allowed recovery.

### 3.2 Layer contract

| Layer | Contents | Excluded from its own hash | May include |
|---|---|---|---|
| L0 content | Immutable caller-supplied payload, preallocated owning identity and nonce | Every derived identity, every digest, every signature, every mutable lifecycle field | Nothing derived |
| L1 record | L0 content, L0 digest, record identity, role and version | The record's own digest and signature; any higher-layer reference | L0 digest and lower-layer digests |
| L2 envelope | L1 record, L1 digest, audience and transport metadata | The envelope signature; the envelope's own digest if one is defined | L1 digest and lower-layer digests |

### 3.3 Bootstrap identity allocation

| Identity | Allocator | First durable use | Hash-exempt rule |
|---|---|---|---|
| `launch_id` | Launching foreman, before admission | CT-02 and the launch commitment | Preallocated; may appear in L0 content; never derived from a launch digest |
| `dispatch_id` | Supervisor, from the launch commitment | Launch confirmation and CT-05 | Derived once from the commitment; excluded from L0 `input_digest` |
| `execution_key` | Supervisor, from `launch_id` and L0 `input_digest` | Launch confirmation and execution journal | Derived once; excluded from L0 `input_digest` |
| `registration_id` | Controller, before the enrollment request | Enrollment grant and request | Preallocated; never allocated by Crier |
| `node_id`, `registration_generation` | Crier, from the accepted grant | Enrollment response and readback | Allocated by Crier; may appear in the response record, never in the request's L0 digest |
| `task_id`, `wave_id`, `claim_id` | Board, before claim construction | CT-10 and the board record | Preallocated; ordering fields are not derived from the record digest |
| `receipt_digest` | Crier, after the unsigned response payload | Custody receipt | Excludes itself and the signature; includes only the unsigned payload digest |
| `report_digest` | Reporter, after the final report body | Final report | Excludes itself and signature; may include the round-summary digest |

### 3.4 Launch construction sequence

The cold-launch sequence is normative and finite:

1. The foreman allocates `launch_id` and a nonce.
2. The foreman builds `LaunchCommitment` from the immutable `BriefInput`, `launch_id`, nonce and the owning supervisor identity. `LaunchCommitment.input_digest` covers only L0 fields; `dispatch_id`, `execution_key`, `input_digest` itself and every signature are excluded.
3. The foreman submits the commitment. The supervisor validates the commitment digest and persists it before deriving anything else.
4. The supervisor derives `execution_key = H("cf.execution-key.v1" || launch_id || input_digest)` and `dispatch_id = "d-" || H("cf.dispatch-id.v1" || launch_id || input_digest)`. Neither derivation includes `dispatch_id` or `execution_key`.
5. The supervisor writes `LaunchConfirmation` containing the commitment, both derived identities and the confirmation digest. The confirmation is the first record that contains the derived values.
6. The foreman materializes `LaunchInput` with the commitment, `dispatch_id` and `execution_key`. `LaunchInput.input_digest` is the commitment's `input_digest`; it is not recomputed over the materialized object. A reader that recomputes it over the materialized object is non-conforming.
7. CT-05 for a worker uses the same commitment and allocation order. No future worker identifier is required at admission.

This sequence removes the cycle `dispatch_id → execution_key → input_digest → dispatch_id` by making `input_digest` a property of L0 only and by allocating every identity before its digest. It preserves `supervisor.v1`, `cf.native.v1` and the sole journal authority.

### 3.5 Crier receipt and response

The response has three separate objects:

1. The unsigned response payload contains the operation result and excludes the receipt, `receipt_digest` and signature.
2. `response_body_digest = H("cf.crier.response-body.v1" || canonical(unsigned payload))`.
3. The receipt body contains `response_body_digest`, lease identity, principal, nonce and timestamps. `receipt_digest = H("cf.crier.receipt.v1" || canonical(receipt body))`, excluding `receipt_digest` and signature.
4. The outer signed envelope contains the unsigned payload, the receipt and `receipt_digest`; the envelope signature covers `receipt_digest` and the envelope metadata. The response hash never covers the embedded receipt or its digest.

A client verifies the envelope signature, recomputes `receipt_digest` from the receipt body, recomputes `response_body_digest` from the unsigned payload, and only then accepts the response. The request and response binding and audience checks remain.

### 3.6 Request and replay digests

`request_digest` and `replay_digest` are separate domains. Both exclude `request_digest`, `replay_digest`, `idempotency_key` where the operation defines it, and every signature. `request_digest` covers the canonical request body; `replay_digest` covers `message_type || canonical(request body without the excluded fields)`. If an operation uses one value for both, the plan requires the one formula to be named and every consumer to use it; the default is two named values with an explicit mapping. Readback and deduplication records store both digests and the excluded-field list they were computed under.

### 3.7 Round memory and final report

The round summary and final report are separate records in a commitment chain:

1. The round-summary body contains the round outcome, wave references and evidence references, but excludes its own memory reference and `report_digest`.
2. `round_summary_digest` is computed over the summary body.
3. The final report body may include the round-summary digest and the summary memory reference; `report_digest` is computed over the final report body excluding itself and its signature.
4. No lower-layer summary digest includes `report_digest`; no final-report digest includes its own memory reference. The memory record digest covers the whole record as stored, with the sync receipt kept separate.

### 3.8 Backup content and lifecycle

The backup content object is immutable after validation. It contains the captured inventory, per-store consistency markers, the cut identity and the content digest. The backup operation record contains state, timestamps, `offhost_readback_ref` and release receipts. The signed publication and release receipts name the immutable content digest and are separate signed objects. A manifest that must acquire lifecycle fields after validation is a different object, not an immutable one; if the implementation chooses versioned immutable revisions, each revision has its own digest and an explicit predecessor link.

### 3.9 LCR-1 closure checks

The strategy is closed only when all of the following hold:

- SC7-01 contains no cycle and the cold CT-02 to CT-05 construction completes in one pass.
- An independent encoder and the supervisor compute the same `input_digest`, `dispatch_id`, `execution_key`, `response_body_digest` and `receipt_digest` from the same fixtures.
- A changed input changes the lower-layer digest and causes a typed refusal; a changed derived identifier causes a recomputation refusal, not a rehash loop.
- Duplicate delivery, restart and changed-input refusal use the same identities and produce the same terminal result.
- The request, custody, memory and backup vectors in `docs/handbook/contract-vectors.json` exercise the excluded-field lists, not only the happy path.

## 4. Repeat and landed-design crosswalk

The sixteen `P6-*` findings are not new. Each maps to an existing P6 disposition row that recorded ADOPTED with page readback. The pass-7 review re-opens the underlying contract because the printed revision still contains the defect; a page-readback PASS does not close a constructive conflict. The crosswalk below prevents duplicate rows and names the prior id that a pass-7 disposition must supersede.

| P7 id | Source stable id | Repeat class | Prior P6 row in IX.9 | P3/P4 antecedent | P5G landed design retained |
|---|---|---|---|---|---|
| P7-01 | P6-LAUNCH-01 | REOPENED — same defect | P6-01 | P4-PROTOCOL-01; P4-RECOVERY-01; P3-INT-01; P3-DISPATCH-01; P3-RECOVERY-01 | P5-A-16/18/19/28; P5-B-01/05/07/10/11/12; P5-C-02/13 |
| P7-02 | P6-REQUEST-DIGEST-01 | REOPENED — same defect | P6-01; P6-08 | P4-PROTOCOL-01; P4-AUTH-01; P3-INT-01; P3-ACCESS-01 | P5-A-16/18/19/28; P5-B-01/03/05/07/10/11/12; P5-C-02/07/12/13 |
| P7-03 | P6-CUSTODY-01 | REOPENED — same defect | P6-02 | P4-PROTOCOL-01; P3-DISPATCH-01; P3-RECOVERY-01 | P5-A-05/07; P5-B-01/03/08; P5-C-06/07/12 |
| P7-04 | P6-SOCKET-01 | REOPENED — same defect | P6-08; P6-09 | P4-DEPLOY-01; P4-AUTH-01; P3-PROVISION-01; P3-SAFETY-01; P3-ACCESS-01 | P5-A-02/07/12/22/23; P5-B-16/23/28/29; P5-C-17/18/33 |
| P7-05 | P6-BOARD-01 | REOPENED — same defect | P6-03 | P4-CLAIM-01; P3-BOARD-01 | P5-A-15/18/19; P5-B-04/20/21/22/23/24/26; P5-C-01/16/38 |
| P7-06 | P6-EVIDENCE-01 | REOPENED — same defect | P6-03; P6-13 | P4-CLAIM-01; P4-PUBLICATION-01; P3-BOARD-01; P3-REPO-01 | P5-A-15/18/19/20; P5-B-04/20/21/22/23/24/25/26/36; P5-C-01/16/34/35/38 |
| P7-07 | P6-GATES-01 | REOPENED — same defect | P6-13 | P4-PUBLICATION-01; P3-REPO-01; P3-WORK-01 | P5-A-20; P5-B-24/25/26/36; P5-C-34/35/38 |
| P7-08 | P6-MEMORY-01 | REOPENED — same defect | P6-04 | P4-MEMORY-01; P3-MEM-01 | P5-A-13/14/17; P5-B-08/09/10; P5-C-28/29/36 |
| P7-09 | P6-STATE-01 | REOPENED — same defect | P6-10 | P4-RECOVERY-01; P3-RECOVERY-01; P3-DISPATCH-01 | P5-A-08/14/16/17/25; P5-B-10/11; P5-C-10/11/14/29/36 |
| P7-10 | P6-LIMITS-01 | REOPENED — same defect | P6-11 | P4-BUDGET-01; P3-CONFIG-02; P3-WORK-01 | P5-A-10/14/17; P5-B-08/28; P5-C-14/30 |
| P7-11 | P6-BACKUP-01 | REOPENED — same defect | P6-06; P5G-07 | P4-BACKUP-01; P3-RECOVERY-02; P3-FLW-02 | P5-A-02/06; P5-B-27; P5-C-26/27; P5G-07 |
| P7-12 | P6-METRICS-01 | REOPENED — same defect | P6-12 | P4-EVENTS-01; P4-CLAIM-01; P3-OPS-01; P3-CONFIG-01 | P5-A-26/33; P5-B-31/38; P5-C-08/32/37 |
| P7-13 | P6-FIXTURES-01 | REOPENED — same defect | P6-16 | P4-DISPOSITION-01; P4-PROTOCOL-01; P3-INT-01; P3-CONSISTENCY-01 | P5-A-16/30/31/32; P5-B-06/33/34/36/37/39; P5-C-31/34/35 |
| P7-14 | P6-FIGURES-01 | REOPENED — same defect | P6-14 | P4-CONSISTENCY-01; P3-CONSISTENCY-01; P3-DIAGRAM-01 | P5-A-13/26/27/28/30/31; P5-B-36/38; P5-C-37 |
| P7-15 | P6-LAYOUT-01 | REOPENED — same defect | P6-15 | P4-LAYOUT-01; P3-LAYOUT-01; P3-LAYOUT-02 | P5-A-30/31; P5-B-33/36 |
| P7-16 | P6-ISSUE-01 | REOPENED — same defect | P6-16 | P4-DISPOSITION-01; P3-CONSISTENCY-01; P3-MODULES-01 | P5-A-30/31/32; P5-B-06/33/34/36/37/39; P5-C-31/34/35 |
| P7-17 | P7-CANCEL-01 | NEW — current integration | P6-01; P6-10 | P4-RECOVERY-01; P4-PROTOCOL-01; P3-RECOVERY-01; P3-DISPATCH-01 | P5-A-08/14/16/17/18/19/25; P5-B-10/11/12; P5-C-02/10/11/13/14/29/36 |
| P7-18 | P7-ENROLLMENT-01 | NEW — current integration | P6-08; P6-09 | P4-AUTH-01; P4-MANAGER-01; P3-ACCESS-01; P3-PROVISION-01 | P5-A-03/04/05/07/08/09/22; P5-B-03/14/18/23; P5-C-06/17/20/21 |
| P7-19 | P7-CONFIG-01 | NEW — current integration | P6-07 | P4-CONFIG-01; P3-CONFIG-01; P3-CONFIG-02 | P5-A-01/04/11/12/32; P5-B-06/18/24/28/30/33; P5-C-03/04/30/33 |
| P7-20 | P7-EVIDENCE-GRADE-01 | NEW — current integration; supersedes the runtime cells | P6-01…P6-16 | P4-DISPOSITION-01; P3-CONSISTENCY-01 | P5-A-30/31/32; P5-B-06/33/34/36/37/39; P5-C-31/34/35 |

### 4.1 Crosswalk rules

- P3 and P4 rows are immutable history. A P7 disposition cites them but never rewrites their status or evidence.
- A P6 row that recorded ADOPTED with page readback remains historically true as a record of what was integrated. It does not close the pass-7 defect; the P7 disposition must say which cell is superseded and why.
- P5G-07 is already correctly UNVERIFIED for live restore and is cited, not reopened.
- The model-caption digest and numbered page stamp are closed. P7-14 keeps the model identity current after corrections; P7-15 keeps the numbered stamp. Neither row may be used to re-open the closed subissues.

## 5. Disjoint integration waves

The waves are sequential at the contract boundary. Wave 1 freezes the canonical records and vectors. Waves 2 and 3 may run in parallel because they share no file. Wave 4 starts only after both integrate. No file appears in more than one wave. `PASS7-PLAN.md` is this triage artifact and is not an implementation target.

### Wave 1 — canonical identity, records, API schemas and conformance bundle

**Owned files (exactly 17):**

- `docs/SYSTEM-MODEL.yaml`
- `docs/handbook/contract-vectors.json`
- `docs/handbook/parts/IV-contract-register.md`
- `docs/handbook/parts/VII-work-derivation.md`
- `docs/handbook/conformance/README.md`
- `docs/handbook/conformance/manifest.json`
- `docs/handbook/conformance/schemas/cf2a.criterion.schema.json`
- `docs/handbook/conformance/schemas/cf2a.evidence.schema.json`
- `docs/handbook/conformance/schemas/cf2a.execution.schema.json`
- `docs/handbook/conformance/schemas/cf2a.board-claim.schema.json`
- `docs/handbook/conformance/schemas/cf2a.memory.schema.json`
- `docs/handbook/conformance/schemas/cf2a.config.schema.json`
- `docs/handbook/conformance/fixtures/launch-commitment.json`
- `docs/handbook/conformance/fixtures/launch-confirmation.json`
- `docs/handbook/conformance/fixtures/custody-request-response.json`
- `docs/handbook/conformance/fixtures/board-group-claim.json`
- `docs/handbook/conformance/fixtures/memory-round-summary.json`

**Lead findings:** P7-01, P7-02, P7-06, P7-08, P7-09, P7-13, P7-17; supply the register and vector entries required by every other finding.

**Contract:** Freeze the LCR-1 layer contract, the bootstrap identity table, the request and replay digest domains, the canonical Criterion and phase-discriminated evidence records, the role-discriminated memory envelope, the total state projection tables, the phase-discriminated cancellation record and the conformance bundle manifest. `docs/handbook/contract-vectors.json` is the single normative vector source; the conformance bundle points to it and does not restate it. Every schema is closed, every fixture is non-secret and every expected output is independent of the PDF.

**Exit evidence:** SC7-01 has no cycle; cold CT-02 then CT-05 computes once; an independent encoder and supervisor recompute the same digests; all six schemas validate their fixtures; the bundle manifest names the model, vector, schema and fixture digests and the PDF relation; a shape-only example is labelled as such and cannot be counted as a positive qualification.

### Wave 2 — control-plane, configuration, custody and recovery modules

**Owned files (exactly 10):**

- `docs/handbook/parts/I-system-arrangement.md`
- `docs/handbook/parts/V-settings.md`
- `docs/handbook/parts/VI-failure-risk.md`
- `docs/handbook/chapters/M1-provisioning.md`
- `docs/handbook/chapters/M2-dispatch.md`
- `docs/handbook/chapters/M5-harness.md`
- `docs/handbook/chapters/M8-safety.md`
- `docs/handbook/chapters/M9-scheduler.md`
- `docs/handbook/chapters/M10-crier.md`
- `docs/handbook/chapters/M11-dispatcher.md`

**Lead findings:** P7-03, P7-04, P7-10, P7-11, P7-18, P7-19; implement the module faces of P7-01, P7-02, P7-09 and P7-17 against Wave 1 records.

**Contract:** Make the mediated socket access executable under the four-UID profile; align dispatch, enrollment, cancellation, deadline, backup and custody behaviour with the canonical records; publish one configuration schema across I, V, M12 and CT-24; keep the immutable backup content separate from lifecycle receipts; preserve Crier custody and Scheduler settlement. Secret values stay out of the book; only scoped secret identities and resolvers are specified.

**Exit evidence:** The positive readiness probe can open the control path as the foreman and the worker-negative arm still refuses; restart and revocation cases pass; custody response verification recomputes the receipt and response digests; enrollment replay uses the original `expected_generation0`; backup upload, readback and release name separate objects; no chapter defines a local deadline or configuration shape.

### Wave 3 — board, publication, provider and telemetry modules

**Owned files (exactly 5):**

- `docs/handbook/chapters/M0-shared-contract.md`
- `docs/handbook/chapters/M3-repository.md`
- `docs/handbook/chapters/M4-board.md`
- `docs/handbook/chapters/M7-github.md`
- `docs/handbook/chapters/M12-inference-proxy.md`

**Lead findings:** P7-05, P7-07, P7-12; implement the module faces of P7-06 and P7-19.

**Contract:** Consume the canonical criterion, evidence, claim and configuration records. Generate the M4 and CT-10 group claim from one definition. Split publication, mechanical policy and model judgment into separately identified artifacts; keep the mandatory accepted-judgment baseline. Instrument the M7 event family with discriminated payloads and separate source-health and activity-age formulas. Do not add a fourth vocabulary appendix.

**Exit evidence:** Criterion round-trip, group-claim duplicate and correction cases, publication decision matrix, exact-route cases and M7–M12 event validation all reference Wave 1 vectors; the publication decision table has no path from unavailable judgment to a protected write; every event payload validates against its schema.

### Wave 4 — integrated figures, presentation, reissue, dispositions and build

**Owned files (exactly 41):**

- `docs/handbook/BOOK.yaml`
- `docs/handbook/parts/00-overview.md`
- `docs/handbook/parts/II-flows.md`
- `docs/handbook/parts/VIII-delivery.md`
- `docs/handbook/parts/IX-disposition-log.md`
- `docs/handbook/chapters/M6-documentation.md`
- `scripts/build_book.py`
- `scripts/book_style.py`
- `scripts/gen_handbook_figures.py`
- `docs/handbook/figures/system-map.svg`
- `docs/handbook/figures/board-lifecycle.svg`
- `docs/handbook/figures/tick-lifecycle.svg`
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

**Lead findings:** P7-14, P7-15, P7-16, P7-20; final integration of every earlier wave.

**Contract:** Regenerate all 32 figures from the integrated model; correct actor and consumer directions and trust placement; repair typography, figure adjacency, contents destinations and table continuations; reissue the artifact with current issue identity and the external sidecar; append one disposition row per P7 finding with source page, correction, resolving commit, built page and the correct evidence class; correct the P6 runtime-conformance cells to UNVERIFIED; preserve P3, P4 and P5G history.

**Exit evidence:** `python3 scripts/handbook_lint.py` is clean; `python3 scripts/build_book.py docs/handbook/CODE-FACTORY-HANDBOOK.pdf` emits the green OK line; 32/32 figures regenerate and are visually inspected; the font census shows the selected body face; no cropped continuation strip; the contents destinations resolve; the current issue and revision furniture are consistent; the external sidecar names the exact PDF bytes and SHA-256; the runtime column is UNVERIFIED for every P6 row; one pass-7 intake row is present; 20 disposition rows cite the exact source ids.

## 6. Integration acceptance and non-claims

Integration is accepted only when:

1. Every P7 row has a landed correction and a pass-7 disposition with source, build and evidence-class references; no row is closed from a commit message or a page readback alone.
2. LCR-1 is propagated through the launch, request, custody, memory, cancellation, backup and report families; the cold-launch and independent-recomputation checks pass; no family retains a local exception.
3. The mediated socket path passes a positive readiness probe for the foreman and a negative probe for the worker under the four-UID profile, with restart and revocation cases.
4. The publication decision table preserves the mandatory accepted independent judgment; no protected effect is authorized by mechanical evidence or unavailable judgment.
5. The canonical Criterion, evidence, memory, configuration and board records have one closed shape each; every chapter example validates against the same schema and vector.
6. The conformance bundle is hash-pinned and version-bound; shape-only examples are visibly separate from actual positive and negative qualification cases; the PDF sidecar names the exact delivered bytes.
7. The final book is rebuilt and visually re-read after integration. Figure topology, direct references, fonts, table continuations, contents destinations, issue identity and disposition completeness are checked in the artifact, not inferred from Markdown.
8. The runtime-conformance column remains UNVERIFIED wherever only rendered-source evidence exists. Owner acceptance remains OPEN.

This plan does not claim runtime conformance, upstream qualification, live deployment, independent completeness beyond the named closure checks, or owner acceptance. It does not authorize a group amendment, a publication exception, a Crier-owned `registration_id`, or a relaxation of the presentation standard. Those are resolved decisions; a change requires an explicit owner ruling.

## 7. Plan self-check

The plan is structurally checked before it is committed:

```sh
python3 scripts/handbook_lint.py
# expected: handbook_lint: clean

python3 - <<'PY'
# structural check: 20 finding rows, 20 crosswalk rows, 9/10/1 severity,
# no duplicate file ownership across waves, exactly one PASS7-INTAKE row,
# and zero P6 runtime cells that still say PASS from page readback.
PY
```

The structural validator is kept as a scratch harness, not a committed build target. It must fail if any of the following is true: a P7 id is missing or duplicated; a severity count differs from 9 critical, 10 high, 1 medium; a crosswalk row is missing; a file appears in two wave lists; the plan omits the LCR-1 strategy; the Part IX runtime column still contains a page-readback PASS; or the intake row count is not one.

The commit contains only `docs/handbook/PASS7-PLAN.md` and `docs/handbook/parts/IX-disposition-log.md`. Prior P3, P4, P5G and P6 dispositions are not rewritten. The only change inside an existing P6 row is the runtime-conformance cell correction required by P7-20; the disposition, resolving commit and historical evidence remain.

## Appendix A — Source package reconciliation

All ten files named in the brief were read before this plan was written, and the manifest's nine member digests were checked against the source directory. No member was missing and every member's byte count matched the manifest.

| Member | Bytes | Role in this triage |
|---|---:|---|
| `CF2A-01-pass7-feedback.txt` | 49,371 | Primary correction source: per-finding problem, consequence, required change and page witnesses. |
| `CF2A-01-pass7-flow-and-coverage.txt` | 25,840 | Flow and page-coverage survey used to confirm affected chapters and figure pages. |
| `CF2A-01-pass7-contract-checks.txt` | 16,457 | Human-readable contract-check results used to separate conflicting shapes from prose drift. |
| `CF2A-01-pass7-contract-checks.json` | 22,086 | Machine-readable contract checks used to keep target sections and check identities consistent. |
| `CF2A-01-pass7-handoff.txt` | 4,773 | Author handoff and review-boundary statement; confirms no runtime or owner-acceptance claim. |
| `CF2A-01-pass7-prior-findings.txt` | 15,164 | Repeat map from current findings to prior `P6-*` ids and partial-resolution state. |
| `CF2A-01-pass7-human-summary.txt` | 2,428 | Verdict, five root blockers and the closed subissues used in section 1. |
| `CF2A-01-pass7-review-log.json` | 122,859 | Canonical 20-finding record; source of ids, severities, pages, previous ids and required changes. |
| `CF2A-01-pass7-manifest.json` | 2,779 | Package identity, source artifact identity, counts and member digests. |
| `CF2A-01-pass7-README.txt` | 615 | Review boundary: no live Factory runtime tests or owner acceptance claimed. |

The source PDF itself was not supplied in the package; the manifest's 406-page identity and SHA-256 are carried in the header above. No claim in this plan depends on re-reading the PDF; the page witnesses are those recorded by the review.

