# CF2A-01 conformance bundle

This directory is the companion bundle that pass-7 finding P7-13 requires. It exists so a
reader can check a record without inferring anything from a repository checkout: the
closed schema for its shape, the fixture for its bytes and a pinned digest for its
identity are all here, and one command asserts all three.

It is version-bound to the pass-7 wave-1 freeze of `docs/SYSTEM-MODEL.yaml` and
`docs/handbook/contract-vectors.json`. It points at the vector file and never restates
it — `contract-vectors.json` remains the single normative source of executable cases.

## What is here

| Path | What it is |
|---|---|
| `manifest.json` | the pin: digest of the model, the vector file, every schema and every fixture; the binding table, the negative arms, the digest checks and the runner program |
| `schemas/` | six closed JSON Schemas (draft 2020-12), one per record family |
| `fixtures/` | five non-secret fixture documents carrying real canonical bytes and their digests |
| `README.md` | this file |

| Schema | Validates |
|---|---|
| `cf2a.criterion.schema.json` | `cf.criterion.v1`, the executable acceptance criterion |
| `cf2a.evidence.schema.json` | `cf.evidence.v1`, one record, five phase-discriminated subjects |
| `cf2a.execution.schema.json` | `cf.launch-commitment.v1`, `cf.launch-confirmation.v1`, `cf.launch-input.v1`, `cf.launch-response.v1`, `worker-result.v1`, `cf.settlement.v1`, `cf.cancellation.v1` |
| `cf2a.board-claim.schema.json` | `cf.group-claim.v1`, the bounded ordered group claim |
| `cf2a.memory.schema.json` | `cf.memory-record.v1` with the role-discriminated body union |
| `cf2a.config.schema.json` | `cf.config.v1`, the configuration document with explicit origins |

## How to check it

From the repository root:

```bash
jq -r '.runner.program' docs/handbook/conformance/manifest.json > /tmp/run.py
python3 /tmp/run.py docs/handbook/conformance/manifest.json
```

or, without a temporary file:

```bash
python3 -c "$(jq -r '.runner.program' docs/handbook/conformance/manifest.json)" \
  docs/handbook/conformance/manifest.json
```

Either form prints one line per failure and a verdict. The last line of a passing run is:

```
conformance bundle: clean — 13 pinned artifacts, 18 bindings, 16 negative arms, 12 digest checks
```

Exit 0 means all four of these held:

1. Every pinned digest matched the file on disk — the model, the vector file, all six
   schemas and all five fixtures.
2. Every positive binding validated: each `(schema, fixture, pointer)` triple in
   `manifest.bindings` resolves to a record the named schema accepts.
3. Every negative arm was refused: each mutation in `manifest.negative_arms` produces a
   record the named schema rejects. An arm that is accepted is a failure, which is what
   makes this a gate rather than a demonstration.
4. Every digest check recomputed from the fixture bytes: the record digests cover the
   record minus their own field, and the layer-crossing digests prefix their domain tag
   exactly as the register states.

Requires `jsonschema>=4.18`. Nothing else: no network, no service, no repository history.

## What a pass does and does not mean

A pass means the schemas, fixtures and digest statements in this freeze agree with each
other. It is an offline conformance result for the specification, in the `FIXTURE-PASS`
sense of IV §IV.2.4.

It is not evidence that any deployment implements the contract. That needs a
version-bound execution receipt naming the producer and consumer releases, the config
digest and the observed outcomes — the bundle says so in
`manifest.checks_this_bundle_cannot_make`, and no page readback substitutes for it.

## Shape-only material

Two things in this bundle look like evidence and are not, and both are labelled:

* the repeated `a` digest used in IV §IV.3 protocol examples is a placeholder for wire
  shape;
* the ed25519 key in `fixtures/custody-request-response.json` is a deterministic test key
  derived from the published seed string `cf2a-conformance-ed25519-test-key/v1`. It signs
  this fixture's transcript and nothing else, and it authorizes nothing.

Neither may be counted as a positive qualification.

## Relation to the PDF

This bundle pins source digests, not PDF bytes. The repository does not contain the
rendered handbook; it is built with `scripts/build_book.py`. `manifest.pdf_relation`
records the last build known at freeze time and states the rule plainly: a PDF built from
other sources, or from these sources after any pinned digest changes, is a different
artifact and the manifest must be re-frozen before it may be cited. Reissuing the PDF with
the corrected figures and dispositions belongs to wave 4 (P7-14, P7-16).

## If a digest drifts

A `digest drift` line names the file whose bytes changed. Do not edit the recorded digest
to match reality: decide which one is wrong. If the source is right, the change is a new
freeze and the whole manifest is rebuilt — the recorded digests are a statement about a
specific set of bytes, and repointing one of them silently redefines the artifact everyone
else is checking against.

## Vectors behind these fixtures

| Fixture | Vectors |
|---|---|
| `fixtures/launch-commitment.json` | `CV-16-A`, `CV-16-B`, `CV-02-A`, `CV-24-A` |
| `fixtures/launch-confirmation.json` | `CV-16-A`, `CV-21-A`, `CV-21-B`, `CV-22-A`, `CV-23-A` |
| `fixtures/custody-request-response.json` | `CV-17-A`, `CV-17-B`, `CV-17-C`, `CV-18-A`, `CV-18-B` |
| `fixtures/board-group-claim.json` | `CV-19-A`, `CV-19-B`, `CV-25-A`, `CV-25-B` |
| `fixtures/memory-round-summary.json` | `CV-01-C`, `CV-20-A`, `CV-20-B`, `CV-20-C` |
