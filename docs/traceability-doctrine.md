# Traceability doctrine

This repository uses `ch:trace` markers to connect a board row to the specification,
execution, documentation, evidence, and closeout decision that a reviewer can resolve
again. A marker is one line of space-separated `key=value` fields. Values are single
tokens: they contain no whitespace, and a value that needs a compound description uses
`-`, `_`, `:`, `/`, `#`, `.`, `@`, or `::` rather than spaces.

## Marker fields

### Marker fields

Every marker has these fields, in this order. A field is not omitted: when the field is
absent, use an explicit `none:<reason>` value. The reason is a short, stable,
single-token explanation; `none` by itself is not a valid absence value.

| Field | Meaning | Typical value |
| --- | --- | --- |
| `row` | The exact board row identifier. | `CF-012` |
| `spec` | Repository-relative specification path and optional anchor that states the requirement. | `docs/traceability-doctrine.md#marker-fields` |
| `wave` | The execution wave identifier, or the explicit serial-worker value. | `none:serial` |
| `test` | The reproducible test command and named target, separated by `::`. | `tests/selftest.sh::selftest` |
| `doc` | The repository-relative document changed or audited. | `docs/traceability-doctrine.md` |
| `prompt` | The repository-relative prompt or task brief that supplied the work. | `prompts/docs.md` |
| `evidence` | The repository-relative produced artifact that contains the supporting output. | `docs/audits/example.md` |
| `witness` | An independently resolvable external or repository witness, or an explicit absence reason. | `path@origin:README.md` or `none:docs-only` |
| `verdict` | The review result or an explicit open-finding state. | `pass:verified` or `none:open-finding` |
| `commit` | The published commit that contains the result, or an explicit open state. | `0123456789abcdef0123456789abcdef01234567` or `none:open` |
| `memory` | A resolvable memory or handoff reference, or an explicit absence reason. | `/project/code-factory/audit-2026-10-31` or `none:foreman-closeout-pending` |

A complete marker therefore looks like this (the line itself remains one token per
field):

`ch:trace row=CF-012 spec=docs/traceability-doctrine.md#marker-fields wave=none:serial test=tests/selftest.sh::selftest doc=docs/traceability-doctrine.md prompt=prompts/docs.md evidence=docs/audits/example.md witness=none:docs-only verdict=none:open-finding commit=none:open memory=none:foreman-closeout-pending`

`none:<reason>` is an explicit value, not a claim that the field was forgotten. For
example, `witness=none:no-live-service` says why no witness exists, while
`witness=none:docs-only` says that this work intentionally has no external execution.
The reason must not contain secrets, credentials, or whitespace.

## Closure rules

1. Nothing closes by reference. A marker, row, verdict, commit message, or link to
   another record cannot substitute for the artifact or witness it claims.
2. Evidence is a produced artifact or an external witness. Another board row, verdict,
   or marker is not evidence. A useful evidence pointer names the exact
   repository-relative artifact, not only its containing directory.
3. An open finding uses `verdict=none:open-finding` and `commit=none:open`.
   It must not use a guessed, future, or unrelated commit.
4. A verdict that closes a finding must bind to a published commit. The commit value is
   the full commit identifier, and the published repository must resolve it; a local
   unpushed commit or a commit mentioned only in prose does not close the finding.
5. No witness is represented as `witness=none:<reason>`. Do not turn a lack of live
   access into a positive execution claim.
6. Exact repository-relative artifacts and external pointers must be resolvable by a
   reviewer. A path must exist at the referenced published tree or in the evidence
   artifact; an external pointer must identify its source and stable target. If it
   cannot be resolved, the finding remains open and the marker names the absence with
   `none:<reason>`.
7. A docs-only check may prove local parsing or repository content, but it does not
   prove live remote execution, deployment, or an external service round trip.

## Falsifiable examples

The following examples are deliberately small. They show the marker contract; each
claim is falsifiable by running the named test and resolving the named artifact.

Open finding (the local selftest passed, but no live witness or published closeout
commit is claimed):

`ch:trace row=CF-012 spec=docs/traceability-doctrine.md#closure-rules wave=none:serial test=tests/selftest.sh::selftest doc=docs/traceability-doctrine.md prompt=prompts/docs.md evidence=docs/audits/example-open.md witness=none:docs-only verdict=none:open-finding commit=none:open memory=none:foreman-closeout-pending`

Completed finding (the referenced artifact, witness, and published commit all exist
in this repository's published history):

`ch:trace row=CF-038 spec=README.md#the-lanes wave=none:serial test=tests/selftest.sh::selftest doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-23-28-00.md witness=path@origin:README.md verdict=pass:evidence commit=415b59e598e2762d8a4b4a16f62889f3528c289f memory=none:no-memory-record`

These examples contain no secrets or personal/internal endpoints. This documentation
change itself does not prove live remote execution; such a claim requires a separate
resolvable witness and evidence artifact.
