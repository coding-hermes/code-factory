# 37. specs/ENVELOPE.md

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/specs/ENVELOPE.md` |
| Repository | `code-factory` |
| Revision | `3c4c639` |
| Status | **RED — no verification recorded** |

## 1. Purpose and why it matters

- What breaks if this module is absent: Without this envelope, the control host and node have no common wire contract — `ENVELOPE.md:3` “The one wire contract between the control host and a node.”
- What breaks if it lies: A `brief.digest` mismatch is a refusal, not a warning (`ENVELOPE.md:26`); a reported digest that cannot be recomputed is unverified, and unverified is FAIL (`ENVELOPE.md:48-49`).

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| — | — | — | **RED: none identified mechanically** |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| — | — | **RED: no imports detected** | — |

### 2c. Service contracts (both sides must be named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| control host | → node inbox | UNKNOWN | Dispatch JSON: `env_version`, `dispatch_id`, `corr_id`, `issued_at`, `reply_to`, `lane`, `text`, `brief`, `route`, `limits`, `gate` (`ENVELOPE.md:9-21`) | node inbox — no file:function (`ENVELOPE.md:6`) |
| node | → reply_to inbox | UNKNOWN | Result JSON: `env_version`, `dispatch_id`, `status`, `host_identity`, `harness`, `exit_codes`, `gate_exit`, `branch`, `commit`, `artifacts`, `wall_s`, `finished_at` (`ENVELOPE.md:31-44`) | reply_to inbox — no file:function (`ENVELOPE.md:28`) |

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| — | **no check exists** | — | — | **RED** |

## 4. Metrics emitted

**NONE FOUND** — this is a RED field. Dispatch rate, latency, failure counts and liveness are all unanswerable without reading code or grepping logs.

## 5. Log lines it can generate

- `"(system|instructions|prompt|tools|schema)"\s*:` — `403 GUARD_BLOCKED`, `matched_pattern=control_keys` (`ENVELOPE.md:54`)

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Dispatch missing `text` | Receiving side has no instruction and will either invent one or run the JSON as a prompt (`ENVELOPE.md:24-25`) | Dispatch with `text` present (`ENVELOPE.md:16`) | **UNKNOWN** — source only declares `text` mandatory (`ENVELOPE.md:24`) |
| `brief.digest` mismatch | Mismatch is a refusal, not a warning (`ENVELOPE.md:26`) | Digest proves the node got the task it was given (`ENVELOPE.md:25-26`) | **UNKNOWN** |
| Reported digest cannot be recomputed | Unverified, and unverified is FAIL (`ENVELOPE.md:48-49`) | Recomputable digest from bytes pulled by control host (`ENVELOPE.md:47-48`) | **UNKNOWN** |
| JSON key matches reserved pattern | crier guard rejects with `403 GUARD_BLOCKED`, `matched_pattern=control_keys` (`ENVELOPE.md:53-54`) | Keys not matching `"(system|instructions|prompt|tools|schema)"\s*:` (`ENVELOPE.md:54`) | Rename field to approved vocabulary, e.g. `capabilities` (`ENVELOPE.md:55-56`) |
| Crash between execution and result delivery | Causes redelivery (`ENVELOPE.md:66-67`) | Idempotency, not exactly-once (`ENVELOPE.md:67`) | Recognise redelivery by `idempotency_key`; return previous result (`ENVELOPE.md:64-65`) |
| Redelivered message not recognised | Work being done twice (`ENVELOPE.md:64-65`) | Recognised via `idempotency_key` (`ENVELOPE.md:64`) | Return previous result (`ENVELOPE.md:65`) |

## 7. Environment and settings it reads

**NONE DETECTED**

## 8. Evidence of record

- Source file `/home/kara/code-factory/specs/ENVELOPE.md` at revision `3c4c639`.
