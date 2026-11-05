# 25. scripts/node-bus-worker.py

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/node-bus-worker.py` |
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
| `argparse` | — | **UNKNOWN** | **UNKNOWN** |
| `base64` | — | **UNKNOWN** | **UNKNOWN** |
| `hashlib` | — | **UNKNOWN** | **UNKNOWN** |
| `json` | — | **UNKNOWN** | **UNKNOWN** |
| `os` | — | **UNKNOWN** | **UNKNOWN** |
| `re` | — | **UNKNOWN** | **UNKNOWN** |
| `shlex` | — | **UNKNOWN** | **UNKNOWN** |
| `socket` | — | **UNKNOWN** | **UNKNOWN** |
| `subprocess` | — | **UNKNOWN** | **UNKNOWN** |
| `sys` | — | **UNKNOWN** | **UNKNOWN** |
| `time` | — | **UNKNOWN** | **UNKNOWN** |
| `urllib.error` | — | **UNKNOWN** | **UNKNOWN** |

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
| ? | `FAIL  loop — must be at least 1` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | `FAIL  wait_seconds — must be 0..120 (the bus answers 400 outside it)` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | `key_registry` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | `one of --check, --once, --loop N is required (--dry-run plans a --once)` | **UNKNOWN** | descriptive (**unverified as evidence**) |

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| **UNKNOWN** | — | — | — |

## 7. Environment and settings it reads

| Variable | Default | Effect if unset |
|---|---|---|
| `CRIER_AUTH_TOKEN` | unknown | **UNKNOWN** |

## 8. Evidence of record

- none yet
