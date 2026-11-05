# 07. scripts/bunker_config_gen.py

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/bunker_config_gen.py` |
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
| `__future__` | — | **UNKNOWN** | **UNKNOWN** |
| `argparse` | — | **UNKNOWN** | **UNKNOWN** |
| `hashlib` | — | **UNKNOWN** | **UNKNOWN** |
| `os` | — | **UNKNOWN** | **UNKNOWN** |
| `re` | — | **UNKNOWN** | **UNKNOWN** |
| `sqlite3` | — | **UNKNOWN** | **UNKNOWN** |
| `sys` | — | **UNKNOWN** | **UNKNOWN** |
| `typing` | — | **UNKNOWN** | **UNKNOWN** |

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

**NONE DETECTED** — RED: an operator has nothing to read when this fails.

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| **UNKNOWN** | — | — | — |

## 7. Environment and settings it reads

| Variable | Default | Effect if unset |
|---|---|---|
| `CRIER_URL` | unknown | **UNKNOWN** |

## 8. Evidence of record

- none yet
