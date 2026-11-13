# P5G-08-R1 immutable brief evidence

This artifact records the reconciled contract and deterministic negative vector. It is a
specification and local evidence artifact, not a claim of live supervisor qualification.

STATUS: partial
TIER: T1
EVIDENCE: docs/handbook/contract-vectors.json (CV-01-B negative_vector)

The normative contract is anchored at `docs/handbook/OUTLINE.md#f1-dispatch-and-settlement`.
Two reachable layers are now named rather than conflated:

- The Factory foreman/manager owns the immutable `cf.brief-input.v1` object, its RFC 8785 JCS
  bytes, `brief_digest`, and `brief_ref`. `worker-brief.v1` carries those references; the
  supervisor resolves them, refuses `BRIEF_UNAVAILABLE` or `DIGEST_MISMATCH` before reservation
  or native start, and replays an identical `(project_id,round_id,task_id,attempt_id,brief_digest)`
  retry without a second start.
- `scripts/node-bus-worker.py` is a separate reachable flat-dispatch adapter. Its `brief.digest`
  scheme is explicitly `node-dispatch.v1`: lowercase SHA-256 over compact sorted-key UTF-8 JSON
  containing decoded directive text, normalized gate, repo, ref, workdir and vars. It does not
  receive or resolve the supervisor BriefInput CAS object, and no digest from one scheme is valid
  for the other. A mismatch, missing digest beside a gate, or legacy text-only digest beside a
  gate is refused as `brief_digest` before project/workdir/vars validation, harness start, or gate
  execution; the refusal is posted and the delivery is acked. Gate-less legacy text-only input is
  retained only for the reachable adapter's documented compatibility path.

CV-01-B remains the positive supervisor vector. Its
`related_objects.brief_input_canonical_json` hashes to
`aa0776211ad78cfe469f9dc192e1cfebdadc863acb05e887fdcaa11a2712874a`, and its CAS reference is
`cas+sha256://code-factory/aa0776211ad78cfe469f9dc192e1cfebdadc863acb05e887fdcaa11a2712874a`.
The committed negative vector changes only `task.title` to
`Prove the execution contract (tampered)`. Its canonical UTF-8 JCS bytes hash to
`bf068162c543a64b47f2d9f53b64fd6c752ab0e5f14af7959cb5c43f2c9faed2`; the corresponding ref is
`cas+sha256://code-factory/bf068162c543a64b47f2d9f53b64fd6c752ab0e5f14af7959cb5c43f2c9faed2`.
The expected supervisor result is `DIGEST_MISMATCH` with no reservation or native start.

The executable receiving-side battery remains `tests/test_brief_digest_binding.py` (B1-B6),
including the effectful gate mutation B2, legacy-gate refusal B3, and missing-digest refusal B5.
Its pre-fix control must point at a saved historical worker source; the current worker is not a
pre-fix source and is not falsely reported as one. No external supervisor witness was available.

ch:trace row=P5G-08-R1 spec=docs/handbook/OUTLINE.md#f1-dispatch-and-settlement wave=none:serial-worker test=tests/test_brief_digest_binding.py::BriefDigestBindingTest.test_b2_altering_only_gate_cmd_is_refused_and_the_gate_never_runs doc=docs/handbook/chapters/M2-dispatch.md prompt=none:ephemeral-brief evidence=docs/handbook/evidence/P5G-08-brief-digest.md witness=none:no-live-supervisor-witness verdict=none:foreman-runs-gitreins commit=none:not-yet-committed memory=none:not-written
STATUS: partial
TIER: T1
EVIDENCE: docs/handbook/contract-vectors.json#CV-01-B.negative_vector; docs/handbook/evidence/P5G-08-brief-digest.md
