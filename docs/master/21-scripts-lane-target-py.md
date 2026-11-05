# 21. scripts/lane_target.py

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/lane_target.py` |
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
| `dataclasses` | — | **UNKNOWN** | **UNKNOWN** |
| `json` | — | **UNKNOWN** | **UNKNOWN** |
| `os` | — | **UNKNOWN** | **UNKNOWN** |
| `re` | — | **UNKNOWN** | **UNKNOWN** |
| `shutil` | — | **UNKNOWN** | **UNKNOWN** |
| `subprocess` | — | **UNKNOWN** | **UNKNOWN** |
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

| Level | Line (verbatim) | Emitted when | Kind |
|---|---|---|---|
| ? | `: str(exc)}
                ok = False
            rows.append({` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | `PATH_EXISTS=0` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | `PATH_EXISTS=1` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | `repo_url: 1 rejected, 0 accepted` | **UNKNOWN** | descriptive (**unverified as evidence**) |

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| **UNKNOWN** | — | — | — |

## 7. Environment and settings it reads

**NONE DETECTED**

## 8. Evidence of record

- none yet
