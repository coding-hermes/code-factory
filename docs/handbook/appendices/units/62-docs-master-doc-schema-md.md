# 62. docs/MASTER-DOC-SCHEMA.md — the record schema

| Field | Value |
|---|---|
| Path | `~/code-factory/docs/MASTER-DOC-SCHEMA.md` |
| Repository | `code-factory` |
| Revision | `8f77667b` |
| Status | **VERIFIED — the schema is described from its own fields and cross-checked against the gate that enforces it, read at this revision** |

## 1. Purpose and why it matters

What every module section must contain: not prose about a component but a claim with its
evidence attached, in a fixed order, so a reader can understand it, reproduce it, and see
whether it is currently true (`docs/MASTER-DOC-SCHEMA.md:5-8`). Its RED rule is the
census's backbone: a section that cannot fill a required field is not "incomplete" — it
is RED, and the empty field is the finding (`docs/MASTER-DOC-SCHEMA.md:7-8`). What breaks
if it is absent: records become prose with statuses. What breaks if it lies: the gate and
the schema drift — a record shaped to the schema that the gate refuses (or worse, accepts
without evidence). The gate enforces exactly what the schema declares: eight required
sections, VERIFIED earned by at least three resolving locators plus a ledger fact, and
index status rows cross-checked against the gate's own computation (`fact: FACT-13`).

## 2. Dependencies and library contracts

| Dependency | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `scripts/master_doc_check.py` | this repo | enforces the schema: required sections (`scripts/master_doc_check.py:25-31`), the VERIFIED rules (`:127-138`), index agreement (`:240-258`) [fact: FACT-13] | the schema documents a gate that no longer exists |
| `_facts.md` ledger | this dir | every `fact: FACT-nn` citation must exist in the ledger (`docs/MASTER-DOC-SCHEMA.md` §8 rule; gate `:135-138`) | a record cites a fact the ledger does not carry |
| `scripts/master_doc_skeleton.py` | this repo | writes skeletons with the eight headings and status RED | skeletons teach a shape the gate rejects |
| the status vocabulary | this schema | `VERIFIED` / `UNVERIFIED` / `FAILING` — never blank, never "done" (`docs/MASTER-DOC-SCHEMA.md:21`) | a fourth status word slips past the gate's regex |

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| every locator on this page resolves | `python3 scripts/master_doc_check.py docs/handbook/appendices/units --only 62- --strict` | `MASTER-DOC: PASS` | 2026-11-22 | PASS |
| the gate enforces the eight sections the schema names | compare `scripts/master_doc_check.py:25-31` with this schema's section headings | the same eight titles | 2026-11-22 at `8f77667b` | PASS [fact: FACT-13] |
| the RED rule is on the named line | `sed -n 7,8p docs/MASTER-DOC-SCHEMA.md` | the RED-is-the-finding rule | 2026-11-22 | PASS |

## 4. Metrics emitted

None. The schema's measurable output is the gate's summary line — modules, VERIFIED
count, errors, warnings, facts in the ledger — which exists because the schema demands
checkable structure, not because the schema counts anything itself.

## 5. Log lines it can generate

- Through the gate it shapes: `MASTER-DOC: PASS`/`FAIL` and the per-record
  `<file> <status> n error(s) n warning(s)` rows (`scripts/master_doc_check.py:220-263`),
  plus the named refusals a VERIFIED stamp must answer — "VERIFIED with N locator(s)",
  "cites unknown fact(s)", and the index-claims disagreement (`:131-138,247`).

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| A field filled with prose instead of evidence | a "complete-looking" record | the schema: an empty field is RED, prose is not evidence (`docs/MASTER-DOC-SCHEMA.md:7-8`) | leave the field RED until a command fills it |
| A status word outside the vocabulary | the gate cannot parse the stamp | the three-word rule, never blank, never "done" (`docs/MASTER-DOC-SCHEMA.md:21`) | use VERIFIED/UNVERIFIED/FAILING |
| Schema and gate drift | records pass one and fail the other | the gate is derived from the template, never invented (`scripts/master_doc_check.py:12-14` comment) [fact: FACT-13] | change schema and gate in the same commit |

## 7. Environment and settings it reads

| setting | source | requirement |
|---|---|---|
| the module root | `docs/handbook/appendices/units` (gate default; `CF_MASTER_DIR` overrides) | the schema governs the records that live there |
| the facts ledger | `_facts.md` beside the records | the only source a `fact:` citation may name |
| locators | `file:line` pairs resolving in this repo | a locator that names no file is a gate error |

## 8. Evidence of record

- The schema: claim-with-evidence rule `docs/MASTER-DOC-SCHEMA.md:5-8`, identity fields
  `:12-21` (status vocabulary `:21`), verification rules `:59-70`, metrics-RED rule
  `:72-77`, failure modes `:93`, evidence of record `:98`, worked example `:105-153`.
- The enforcing gate: `scripts/master_doc_check.py:25-31` (sections), `:127-138`
  (VERIFIED rules), `:240-258` (index cross-check) [fact: FACT-13].
- The census this schema makes possible: the units index (00-INDEX.md) and CF-360's
  system-shaped extension, which inherits every rule on this page.
