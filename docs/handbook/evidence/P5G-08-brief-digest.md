# P5G-08 immutable brief evidence

This artifact records the handbook acceptance surface for the immutable worker brief. It is a
specification/evidence artifact, not a claim of live supervisor qualification.

STATUS: partial
TIER: T1
EVIDENCE: docs/handbook/contract-vectors.json (CV-01-B)

The normative contract is anchored at `docs/handbook/OUTLINE.md#f1-dispatch-and-settlement`.
The Factory foreman/manager owns BriefInput construction, immutable storage and replay; the
worker receives the exact stored byte object. `cf.brief-input.v1` is the sole digest input and
`worker-brief.v1` carries its `brief_ref` and `brief_digest`.

The independently checkable vector is CV-01-B. Its `related_objects.brief_input_canonical_json`
is the exact UTF-8 byte string. Its SHA-256 is
`aa0776211ad78cfe469f9dc192e1cfebdadc863acb05e887fdcaa11a2712874a`, and its CAS reference is
`cas+sha256://code-factory/aa0776211ad78cfe469f9dc192e1cfebdadc863acb05e887fdcaa11a2712874a`.
A verifier can recompute the digest with SHA-256 over those bytes, without reading a mutable
prompt, skill path or task-board row.

ch:trace row=P5G-08 spec=docs/handbook/OUTLINE.md#f1-dispatch-and-settlement wave=none:serial test=tests/test_brief_digest_binding.py doc=docs/handbook/chapters/M2-dispatch.md prompt=none:worker-owned evidence=docs/handbook/evidence/P5G-08-brief-digest.md witness=docs/handbook/contract-vectors.json#CV-01-B verdict=none:foreman-runs-gitreins commit=none memory=none:foreman-writes
