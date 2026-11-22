# 54. docs/OPERATIONS.md — the operator runbook

| Field | Value |
|---|---|
| Path | `~/code-factory/docs/OPERATIONS.md` |
| Repository | `code-factory` |
| Revision | `8f77667b` |
| Status | **VERIFIED — the runbook is described from its own lines; its measured-value rules are the same discipline the readiness labels and probes carry** |

## 1. Purpose and why it matters

The operator-side runbook for the node lifecycle, and the repo's most explicit honesty
document: it opens by declaring itself a design/runbook, NOT an installation receipt, and
splits every claim into MEASURED (repository evidence), CHECK LOCALLY (an exact read-only
command), BLOCKED (a prerequisite is absent — do not proceed past that gate) and NOT YET
(designed but unexercised through the production path) (`docs/OPERATIONS.md:3`,
`:13-18`). What breaks if it is absent: operators treat designed behavior as live
operations. What breaks if it lies: a measured-once value is quoted as current health —
the runbook's labels exist to make that distinction impossible to skip.

## 2. Dependencies and library contracts

| Dependency | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `scripts/node-create.sh` | this repo | refuses before any bunker call when `CRIER_URL` is unset, naming the row (`docs/OPERATIONS.md:24`) | the preflight contract loses its name |
| `scripts/bunker-crier-connect.sh` | this repo | the identity ladder: route check first, signed read as additional evidence (`docs/OPERATIONS.md:50`) | the runbook and the connect script disagree on proof |
| `scripts/verify-node.sh` | this repo | the control-host ladder: agent, gateway, auth, artifact, tree, seed (`docs/OPERATIONS.md:148`) | verification steps stop matching the ladder |
| `scripts/node-bus-worker.py` | this repo | the brief digest is the dispatch's trust boundary; the node must not execute a brief field the digest does not bind (`docs/OPERATIONS.md:167`) | an executed member escapes the digest |

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| every locator on this page resolves | `python3 scripts/master_doc_check.py docs/handbook/appendices/units --only 54- --strict` | `MASTER-DOC: PASS` | 2026-11-22 | PASS |
| the four readiness labels are on the named lines | `sed -n 13,18p docs/OPERATIONS.md` | MEASURED / CHECK LOCALLY / BLOCKED / NOT YET, each with its rule | 2026-11-22 at `8f77667b` | PASS |
| the implementation-boundary paragraph is still honest | `sed -n 11p docs/OPERATIONS.md` | names BLOCKED/NOT-YET classes rather than claiming live operations | 2026-11-22 | PASS |

## 4. Metrics emitted

None — a runbook emits nothing. Its measurable surface is the commands it prescribes:
each carries an expected value (an HTTP code, a row name, a mode), and the runbook's rule
is that a measurement is bound to the host and time it was taken on, never quoted as
current health (`docs/OPERATIONS.md:15`).

## 5. Log lines it can generate

- Nothing by itself. The lines an operator following it sees are the scripts': the
  `FAIL crier_url` preflight row (`docs/OPERATIONS.md:24`), the connect ladder's
  distinct 401/403/404/000 rows and optional `signed_read` PASS (`:50`), the gateway
  auth row naming the config path and measured mode (`:92`), and the verify ladder's
  `FAIL seed_drift — the record declares no files` refusal (`:148`).

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| A historical measurement quoted as current health | "the node answered 200" from an old probe | the MEASURED label's rule: not proof of the current host (`docs/OPERATIONS.md:15`) | re-run the exact CHECK LOCALLY command |
| Designed behavior treated as live | dispatch/rebuild called operations | the boundary paragraph: creation/dispatch/rebuild are BLOCKED or NOT YET until gates are observed (`docs/OPERATIONS.md:11`) | read the boundary before executing |
| A WARN read as approval to expose the gateway | an unverified node admitted to work | `:94`: a WARN leaves the node unverified; require both legs | fix the auth gate, then re-verify |

## 7. Environment and settings it reads

| setting | source | requirement |
|---|---|---|
| `BUNKER_SERVER`, `CRIER_URL` | operator environment | environment-specific, never committed or pasted into tickets (`docs/OPERATIONS.md:24`) |
| node credentials | mode-600 files the scripts stage; passwords generated on the node, never printed or passed in argv (`docs/OPERATIONS.md:92`) [fact: FACT-05] | the runbook names paths, never values |
| bus proof | route 200 + optional signed read (`docs/OPERATIONS.md:50`) [fact: FACT-04] | an unsigned answer is not proof of delivery |

## 8. Evidence of record

- The runbook: status boundary `docs/OPERATIONS.md:3`, model `:5`, lifecycle `:7`,
  implementation boundary `:11`, labels `:13-18`, preflight `:24`, connect ladder
  `:50`, gateway auth `:92-94`, verify ladder `:148`, digest boundary `:167`.
- The measured controls it cites: the bus signature+bearer rule [fact: FACT-03] via the
  connect record (04), the credential discipline [fact: FACT-05], and the inbox-200
  ladder [fact: FACT-04].
- The gates it prescribes are fixture-proven by the battery: `tests/selftest.sh` §55
  drives the gateway-auth refusal and pass states (`docs/OPERATIONS.md:11,92`).
