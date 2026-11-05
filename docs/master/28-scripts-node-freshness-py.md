# 28. scripts/node_freshness.py

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/node_freshness.py` |
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
| ? | `--workdir and --agent/--server are exclusive` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | `: m.error,
        ` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | `: m.fetch_error,
        ` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | `ANCESTOR_RC=$?` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | `BARE=$(git rev-parse --is-bare-repository 2>/dev/null)` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | `BEHIND=$(git rev-list --count ` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | `BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | `CMP_REF=$CMP` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | `HEAD_SHA=$(git rev-parse HEAD 2>/dev/null)` | **UNKNOWN** | descriptive (**unverified as evidence**) |
| ? | `ORIGIN_MAIN=$(git rev-parse --verify --quiet ` | **UNKNOWN** | descriptive (**unverified as evidence**) |

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| **UNKNOWN** | — | — | — |

## 7. Environment and settings it reads

**NONE DETECTED**

## 8. Evidence of record

- none yet
