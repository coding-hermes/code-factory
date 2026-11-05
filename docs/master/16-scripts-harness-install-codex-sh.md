# 16. scripts/harness/install-codex.sh

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/harness/install-codex.sh` |
| Repository | `code-factory` |
| Revision | `3c4c639` |
| Status | **RED — no verification recorded** |

## 1. Purpose and why it matters

- What breaks if this module is absent: **UNKNOWN** (fill from behaviour, prove it).
- What breaks if it lies: **UNKNOWN** (every self-reporting component has this failure mode).

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
| **UNKNOWN** | — | — | — | **RED** |

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| — | **no check exists** | — | — | **RED** |

## 4. Metrics emitted

**NONE FOUND** — this is a RED field. Dispatch rate, latency, failure counts and liveness are all unanswerable without reading code or grepping logs.

## 5. Log lines it can generate

| Level | Line (verbatim) | Emitted when | Kind |
|---|---|---|---|
| ? | `  FAIL  %s — refused: %s\n` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | ` 2>/dev/null || echo ` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | ` ]; then
    mode=$(stat -c ` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | `CODEX: REFUSED (%s)\n` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | `approval_policy = ` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | `codex-cli 0.166.0` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | `model_provider = ` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | `model_served` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | `sandbox_mode = ` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | `x86_64-unknown-linux-musl` | **UNKNOWN** | descriptive (**unverified as evidence**) |

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| **UNKNOWN** | — | — | — |

## 7. Environment and settings it reads

| Variable | Default | Effect if unset |
|---|---|---|
| `CF_API_KEY` | unknown | **UNKNOWN** |
| `CF_API_KEY_FILE` | unknown | **UNKNOWN** |
| `CF_AS` | unknown | **UNKNOWN** |
| `CF_AS_PID` | unknown | **UNKNOWN** |
| `CF_BASE_URL` | unknown | **UNKNOWN** |
| `CF_CODEX_ARCH` | unknown | **UNKNOWN** |
| `CF_CODEX_PIN` | unknown | **UNKNOWN** |
| `CF_CODEX_SHA256` | unknown | **UNKNOWN** |
| `CF_CODEX_URL` | unknown | **UNKNOWN** |
| `CF_LANE` | unknown | **UNKNOWN** |
| `CF_MAX_TURNS` | unknown | **UNKNOWN** |
| `CF_MODEL` | unknown | **UNKNOWN** |

## 8. Evidence of record

- none yet
