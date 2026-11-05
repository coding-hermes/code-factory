# 38. specs/HARNESS-MATRIX.md

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/specs/HARNESS-MATRIX.md` |
| Repository | `code-factory` |
| Revision | `3c4c639` |
| Status | **MEASURED — measured inputs and correction recorded; no conformance PASS/FAIL recorded** |

## 1. Purpose and why it matters

- What breaks if this module is absent: The selection rule, variable contract, and switching model are left unspecified. Source says this file "owns the **selection rule**, the **variable contract** and the **switching model**".
- What breaks if it lies: The matrix would make false support or binding claims. Source states: "An unrecorded fallback is indistinguishable from a mistake, and an unrecorded shim is worse." Source also records a prior false absence claim: "The previous revision ... said 'there is no deepseek harness'. That was measured against *our* two trees and then stated as a fact about the world."

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
| Conformance battery (five legs) | `tests/harness-conformance.sh` | `check`, `install`, `vars`, `turn`, `memory` all `PASS` on a real node; `SKIP` acceptable only with named reason | UNKNOWN | **RED: no run recorded** |
| Harness install check | `install-<harness>.sh --check` | "installed? which pin" | UNKNOWN | **RED: no run recorded** |
| Resolution explain | `harness_resolve.py --explain <model> [--lane L]` | "prints the decision and the reason it won" | UNKNOWN | **RED: no run recorded** |

## 4. Metrics emitted

**NONE FOUND for operational metrics** — source defines required DuckBrain record fields and per-run decision fields rather than dispatch rate, latency, failure counts, or liveness: `run_id, lane, harness, harness_version, model_requested, model_served, provider_binding, commit, tick` (I3); `harness_selected, harness_reason (directive|lane|matrix|fallback), model_requested, model_served, provider_binding` (§4).

## 5. Log lines it can generate

**NONE DETECTED as log lines with level** — source gives two refusal strings verbatim:

- `harness_unsupported: <name>; node has: <set>`
- `harness_cannot_host: <harness> <family>`

No log level is shown.

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Unknown or uninstallable harness | `harness_unsupported: <name>; node has: <set>` | `harness_cannot_host`; source says "one is fixed by installing and the other only by changing configuration" | Install the harness |
| Harness exists but cannot reach the model's provider | `harness_cannot_host: <harness> <family>` | `harness_unsupported` | Change configuration or configure the shim |
| Cross-provider run with unrecorded shim/fallback | Source says it is "indistinguishable from a mistake"; "an unrecorded shim is worse" | Recorded decision via `harness_reason` and `provider_binding` | Record `harness_reason` and `provider_binding` on the run |
| `dsh` plugin-layer failure | Source says "plugin layers mean a failure can be at any layer" | Not a single-layer failure; needs per-layer diagnosis | "diagnose per layer" |

## 7. Environment and settings it reads

| Variable | Default | Effect if unset |
|---|---|---|
| `CF_API_KEY_FILE` | no default shown; source rule: "required for a paid provider" | Missing required key path for a paid provider; source also says "a value in argv is a FAIL" |
| `CF_BASE_URL` | "default = node router" | Uses node router |
| `CF_HARNESS_OPTS` | no default shown; source rule: "optional, **and recorded**" | No harness-specific options; source warns "an unrecorded option makes two runs incomparable" |
| `CF_LANE` | no default shown; source rule: "required" | Required value missing |
| `CF_MAX_TURNS` | 40 | Uses default 40 |
| `CF_MODEL` | no default shown; source rule: "required" | Required value missing |
| `CF_NAMESPACE` | no default shown; source rule: "required (I3)" | Required value missing; violates I3 |
| `CF_PROVIDER` | no default shown; source rule: "required" | Required value missing |
| `CF_RUN_ID` | no default shown; source rule: "required; echoed into every memory write" | Required value missing; memory writes lose correlation |
| `CF_SKILLS_DIR` | no default shown; source rule: optional | Optional path not provided; source notes "hermes and omh use it" |
| `CF_TIMEOUT_S` | 1800 | Uses default 1800 |
| `CF_WORKDIR` | no default shown; source rule: "required; must be inside `$HOME`" | Required value missing |

## 8. Evidence of record

- `"Measured inputs: /home/kara/code-factory-reports/spec-crier-harness-support-2026-11-05.md (what crier ships, file:line), /home/kara/code-factory-reports/spec-b
