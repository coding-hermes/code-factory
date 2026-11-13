# P5G-08-R1 immutable brief evidence

This artifact records the reconciled executable contract and deterministic negative vector. It does
not claim live supervisor qualification.

STATUS: complete
TIER: T1
EVIDENCE: docs/handbook/contract-vectors.json#CV-01-B; docs/handbook/contract-vectors.json#CV-01-G; tests/test_brief_digest_binding.py

The two remaining defects were closed here. The receiver no longer carried a competing flat
`node-dispatch.v1`/`cf-brief-v1` digest: `scripts/node-bus-worker.py` now projects every dispatch
onto the single `cf.brief-input.v1` BriefInput object and hashes its RFC 8785 JCS UTF-8 bytes.
Effectful gate, criteria, repo, ref, workdir, vars, directive, skills and attachment members are
inside that projection. Missing input is `BRIEF_UNAVAILABLE`; a digest or brief_ref mismatch is
`DIGEST_MISMATCH`; both refuse before gate or harness side effects, then post the result and ack.
`cf-brief-v1` is retired and senders must use `--print-brief-digest`.

CV-01-B remains the positive vector. Its exact `related_objects.brief_input_canonical_json` bytes
hash to `aa0776211ad78cfe469f9dc192e1cfebdadc863acb05e887fdcaa11a2712874a`, and its CAS reference
has the same suffix. CV-01-G is the committed negative control: it changes only `criteria[0].argv`
by appending `--extra-token`, leaves the declared CV-01-B digest, and records the recomputed
canonical bytes, digest and ref. It expects `DIGEST_MISMATCH` with no gate, harness, reservation or
attempt start.

Commands and observed output:

1. `python3 tests/test_brief_digest_binding.py`
   exit 0; six PASS rows, including bound gate/harness execution, gate and criteria mutations,
   brief_ref mismatch, missing digest, sender/node agreement and effectful-member coverage.
2. `bash tests/selftest.sh`
   exit 0; final output `SELFTEST: PASS`.
3. `python3 tests/test_node_bus_staging.py`
   exit 0; staging battery passed.
4. `python3 tests/test_bus_result_delivery.py`
   exit 0; seven PASS rows, including result delivery and refusal behavior.
5. `python3 -m json.tool docs/handbook/contract-vectors.json >/dev/null`
   exit 0; contract vectors parse.
6. The CV-01-B and CV-01-G canonical JSON strings, their brief-input digests, brief_ref suffixes and
   dispatch canonical digest were recomputed with real SHA-256 checks before closeout.

The prefix-control hook remains available through `CF_BUS_WORKER_SOURCE` and
`CF_BRIEF_DIGEST_PREFIX_CONTROL=1`; it must point to a saved historical worker revision to prove
the old gate-execution defect. No live supervisor qualification is claimed.

ch:trace row=P5G-08-R1 spec=docs/handbook/OUTLINE.md#f1-dispatch-and-settlement wave=none:serial-worker test=tests/test_brief_digest_binding.py doc=docs/handbook/chapters/M2-dispatch.md prompt=none:ephemeral-brief evidence=docs/handbook/evidence/P5G-08-brief-digest.md witness=none:no-live-supervisor-witness verdict=local-hermetic-gates-pass commit=to-be-set-by-foreman memory=none:not-written
STATUS: complete
TIER: T1
EVIDENCE: docs/handbook/contract-vectors.json#CV-01-G; tests/test_brief_digest_binding.py; specs/ENVELOPE.md
