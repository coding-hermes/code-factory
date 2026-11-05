# 17. scripts/harness/install-hermes.sh

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/harness/install-hermes.sh` |
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
| `json` | — | **UNKNOWN** | **UNKNOWN** |
| `pathlib` | — | **UNKNOWN** | **UNKNOWN** |
| `re` | — | **UNKNOWN** | **UNKNOWN** |
| `sys` | — | **UNKNOWN** | **UNKNOWN** |

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
      exit 1
    fi
    ` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | `
      exit 1
    fi
  else
    note ` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | `
    if pip_log=$(umask 077; mktemp ` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | ` 2>&1
    rc=$?
    if [ ` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | ` 2>&1 &
      sleep 6
      code=$(curl -s -o /dev/null -w ` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | `$VENV/bin/hermes` | **UNKNOWN** | descriptive (**unverified as evidence**) |

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| **UNKNOWN** | — | — | — |

## 7. Environment and settings it reads

| Variable | Default | Effect if unset |
|---|---|---|
| `HERMES_PIN` | unknown | **UNKNOWN** |
| `HERMES_PYTHON_BIN` | unknown | **UNKNOWN** |

## 8. Evidence of record

- none yet
