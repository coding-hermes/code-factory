# 33. scripts/project-node.sh

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/project-node.sh` |
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
| `git` | unknown | unknown | **RED** |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `json` | — | **UNKNOWN** | **UNKNOWN** |

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
| ? | `
      if git clone --depth 1 --branch ` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | `
    FAILED=$((FAILED + adapter_fails))
  fi
else
  say ` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | `
    else
      bad ` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | `  %s  %s — %s` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | `  WARN  disk_floor — python3 absent, using built-in ${ROLE} default ${FLOOR_GIB} GiB` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | ` 2>&1
    else
      NODE_GATEWAY_PORT=` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | ` 2>&1
    fi
    rc=$?
    adapter_fails=` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | ` 2>&1
  rc=$?
  if [ ` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | ` 2>&1; then
        ok ` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | ` 2>/dev/null)` | **UNKNOWN** | descriptive (**unverified as evidence**) |

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| **UNKNOWN** | — | — | — |

## 7. Environment and settings it reads

| Variable | Default | Effect if unset |
|---|---|---|
| `CRIER_BASE` | unknown | **UNKNOWN** |
| `CRIER_URL` | unknown | **UNKNOWN** |

## 8. Evidence of record

- none yet
