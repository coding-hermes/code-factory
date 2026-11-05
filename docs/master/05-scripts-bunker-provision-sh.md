# 05. scripts/bunker-provision.sh

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/bunker-provision.sh` |
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
| ? | `  %s mode %s\n` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | ` 2>&1; then
      if ` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | ` | head -1 | cut -c1-60))` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | ` | head -5
    fi
    rm -rf ` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | `agent.max_iterations=%s\n` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | `branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | `crier_bearer=$([ -s ` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | `crier_connect` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | `crier_json=$([ -f ` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | `crier_key=$([ -s ` | **UNKNOWN** | descriptive (**unverified as evidence**) |

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| **UNKNOWN** | — | — | — |

## 7. Environment and settings it reads

| Variable | Default | Effect if unset |
|---|---|---|
| `CRIER_AGENT_KEY_FILE` | unknown | **UNKNOWN** |
| `CRIER_AUTH_TOKEN_FILE` | unknown | **UNKNOWN** |
| `CRIER_URL` | unknown | **UNKNOWN** |

## 8. Evidence of record

- none yet
