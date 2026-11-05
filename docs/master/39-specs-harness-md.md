# 39. specs/HARNESS.md

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/specs/HARNESS.md` |
| Repository | `code-factory` |
| Revision | `3c4c639` |
| Status | **RED — no verification recorded** |

## 1. Purpose and why it matters

- What breaks if this module is absent: **UNKNOWN** — source defines “A **harness** is whatever runs the work inside a node. The factory must not care which.” (`file:3`) and points to `specs/HARNESS-MATRIX.md` for selection authority (`file:5`), but does not state what breaks if this spec file is absent.
- What breaks if it lies: **UNKNOWN** — source says “Conformance is measured, not claimed” (`file:45`) and a `SKIP` “is not evidence of support” (`file:53`), but does not name the operational breakage if this spec lies.

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `hermes-agent` | `0.19.0` (`file:26`, `file:34`) | `$HOME/hermes-venv/bin/hermes` (`file:34`) | `scripts/harness/install-<name>.sh --check` reports absence (`file:15`) |
| `codex` release tarball | `rust-v0.166.0`, read back as `codex-cli 0.166.0` (`file:29`) | `$HOME/.local/codex/<pin>/bin/codex` (`file:58`) | `scripts/harness/install-codex.sh` / `--check` (`file:15`, `file:60`) |

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
| Harness conformance battery | `tests/harness-conformance.sh` (`file:47`) | Three legs: adapter’s own `--check`; real smoke turn leaves a file containing a token; with `--install`, `--apply` in throwaway `$HOME` followed by post-apply `--check`; prints `PASS`/`FAIL`/`SKIP` and regenerates `docs/HARNESS-CONFORMANCE.md` (`file:47-51`) | **UNKNOWN** — not recorded in this file | **RED — no recorded result** |
| Codex install proof | `tests/harness/codex-install-test.sh` (`file:60`) | Refusals, digest floor, idempotence, version-mismatch arm, and one real turn when a credential exists (`file:60-62`) | **UNKNOWN** — not recorded in this file | **RED — no recorded result** |

## 4. Metrics emitted

**NONE FOUND** — this is a RED field. Source records measured state such as 32 s install, `/api/status` 200 over tailnet, and 133 JSON-RPC methods (`file:26`), and codex 7 s install with `model_served` read from codex’s own rollout record (`file:29`), but no metric names are emitted by this module. Dispatch rate, latency, failure counts and liveness are unanswerable from this file.

## 5. Log lines it can generate

**EXPLICIT STRING ONLY** — `No inference provider configured` (`file:68`), level not visible. No structured log line is recorded; RED for a full operational log line.

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Version mismatch | `--check` prints ownership and measured version; mismatch names both measured value and the pin and FAILs (`file:16`) | A matching venv binary earns “already installed” (`file:38`) | For hermes, a venv version mismatch is named and reinstalls the pin (`file:37-38`) |
| Host-provided binary | PATH-provided binary is labelled host-provided and FAILs the binary row, even if version matches (`file:35`) | Owned venv binary `$HOME/hermes-ven
