# M0 — SHARED CONTRACT

## 0. Set-wide chapter crosswalk (numbering prep)

The chapters are filed under module ids M0–M12. Set-wide numbering (global §3.x) is applied
at build time; the builder keys on this table. Local `## n.` section numbers below are
per-module and are not global numbers.

| Module id | Intended global chapter number |
|---|---|
| M0 | 3.1 |
| M1 | 3.2 |
| M2 | 3.3 |
| M3 | 3.4 |
| M4 | 3.5 |
| M5 | 3.6 |
| M6 | 3.7 |
| M7 | 3.8 |
| M8 | 3.9 |
| M9 | 3.10 |
| M10 | 3.11 |
| M11 | 3.12 |
| M12 | 3.13 |

## 1. Identity

| Field | Value |
|---|---|
| Module name | SHARED CONTRACT (`scripts/lib.sh`) |
| Path | `/home/kara/code-factory/scripts/lib.sh` |
| Revision | `fbc19cbc807de729e25c358fa7e94207b912f010` (code-factory HEAD; `scripts/lib.sh` byte-identical since `47d68b4` — no file M0 cites changed in `08a2c8a..fbc19cb`) |
| Language / runtime | bash 5.3.9 (measured: `bash --version`); sourced, never executed |
| Owner lane | code-factory (node-side + control-host shell) |
| Status | **VERIFIED** — `lib.sh` (78 lines) read in full; every cited line re-verified |

The variable contract (`scripts/harness/harness-vars.sh`, 318 lines) is **not** part of M0.
OUTLINE M0.S1 is the *shell* contract only; `harness-vars.sh` is M5.S5 (see §12).

## 2. Purpose, authority and position

The shared shell substrate every node-side module sources. It decides what a shell script may
print (`ok`/`bad`/`warn`/`note`, `lib.sh:6-9`; `say()` is `:5` and is not one of the four
verdict helpers), what a pinned download may accept
(`fetch_verified`), what a disk floor may admit (`require_disk`), and what a credential *mode*
may look like (via M5.S5, not here). It may not decide anything about a run itself: it never
reads the directive, never spawns a harness, never touches the bus.

**What breaks if this module is absent.** Every installer and checker fails on undefined
`ok`/`bad`/`FAILED` before doing anything. Seventeen shell scripts source `lib.sh` — 11 direct
(`grep -rl '\. "$HERE/lib.sh"' scripts/` → 11) plus 6 in `scripts/harness/` that source
`$HERE/../lib.sh` (`grep -rlE '\. "\$HERE/(\.\./)?lib\.sh"' scripts/` → 17). Both counts are verified.

**What breaks if it lies.** `fetch_verified` (`lib.sh:19-42`) is the pinned-download primitive
every installer relies on; a false digest match installs a wrong or tampered binary and reports
PASS. `require_disk` (`lib.sh:48-57`) is the disk floor; a false "enough space" lets the
provisioner proceed onto a host it must refuse.

## 3. Submodule inventory

| Submodule | File | Classification | Evidence (invoking line) |
|---|---|---|---|
| S1 shell contract | `lib.sh` | **active** | sourced by 17 scripts — `grep -rlE '\. "\$HERE/(\.\./)?lib\.sh"' scripts/` → 17 |

`harness-vars.sh` is **not** an M0 submodule (M5.S5, OUTLINE M5).

**Exported helper inventory (B09 — every helper in `lib.sh`):**

| Helper | `lib.sh` | Inputs → output / exit | Caller obligations |
|---|---|---|---|
| `say()` | `:5` | args → prints verbatim | none |
| `ok()` / `bad()` / `warn()` / `note()` | `:6-9` | `bad` increments the per-script `FAILED` counter (`:7`) | treat PASS/FAIL rows as descriptive, not proof (F0-4) |
| `have()` | `:13` | `command -v` **or `true`** — an absent binary yields an **empty, success** result | caller must test the *empty* result, not the exit code; empty `have` output = "not found" |
| `fetch_verified()` | `:19-42` | url/dest/digest → 0 on digest-verified install, 1 on any failure; the verified artifact is made executable best-effort — `chmod +x "$dest" 2>/dev/null || true` (`:40`), so a **failed chmod is swallowed** and the install still returns 0 (the exit code is the INSTALL, not the chmod — `lib.sh:18`) | the pinned-download primitive (F0-2) |
| `free_gb()` | `:45` | path → `%.1f` GB free | used by `require_disk` only |
| `require_disk()` | `:48-57` | path/floor → `ok` or `bad` + return 1 | the disk-floor admission |
| `once()` | `:60-64` | sentinel + command → runs command only if sentinel absent, then writes a timestamped sentinel | **no concurrency lock**: `:62` checks then `:63` runs with no `flock` — two racers both run; the sentinel is `date -u` text, not a digest |
| `shq()` | `:67-70` | value → single-quoted shell token | quotes empties and apostrophes for remote-shell composition |
| `bunker_exec()` | `:75-78` | server/agent/cmd… → `bunker exec … -- bash -lc "<joined>"` | joins remaining args as trusted shell text; interpolated data must pass `shq` first (`:72-74`) |

## 4. Dependencies

**4a. Runtime dependencies**

| Dependency | Version constraint | Where | How absence is detected |
|---|---|---|---|
| bash | >= 4 | node + control host | `set -u` + undefined helper aborts the caller |
| curl | any | node + control host | `curl -fsSL` nonzero → `fetch_verified` returns 1 (`lib.sh:22`) |
| sha256sum | any | with curl | digest mismatch → return 1 (`lib.sh:24-27`) |
| mktemp | any | with curl | a failed `mktemp` (`:21`) leaves `tmp` unset — `fetch_verified` then acts on an empty path, not a named refusal (no `mktemp` failure branch exists) |
| rm | any | with curl | `rm -f` at `:22/:25/:31/:36` is best-effort cleanup, never a refusal |
| cut / dirname / mkdir / mv | any | with curl | `mkdir -p` failure → named stderr + return 1 (`:30-34`); `mv` failure → named stderr + return 1 (`:35-39`) |
| chmod | any | with curl | **best-effort**: `chmod +x "$dest" 2>/dev/null || true` (`:40`) — a failed chmod is swallowed; the artifact is left non-executable and the install still returns 0 |
| df / awk | any | with curl | `free_gb` (`:45`) depends on `df`+`awk`; a missing `df` yields an empty `free` and `require_disk`'s awk admission (`:51`) mis-decides the floor |

**4b. Library contracts** — `lib.sh` imports nothing; it is the bottom of the shell stack.

**4c. Service contracts** — see §6.

## 5. Settings register

`lib.sh` carries one tunable constant and no env-var surface:

| Setting | Default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| `fetch_verified` `--max-time` | 120 s (`lib.sh:22`, hardcoded) | fixed | download stall ceiling | a download stalling past 120 s fails with rc 1; lowering it rejects slow-but-valid mirrors |

`FAILED` (`lib.sh:11`) is a per-script failure counter, not a setting. The CF_* variable
contract settings (`CF_MAX_TURNS`, `CF_TIMEOUT_S`, `CF_API_KEY_FILE`, …) live in M5.S5, not here.

## 6. Contracts in and out

M0 has **no entry in the canonical register** (CT-01..CT-18, OUTLINE Part IV). `lib.sh` is the
bottom of the shell stack and exposes no cross-system wire contract: its only outbound call is a
local library composition (`bunker_exec`), not an interface two chapters describe from opposite
ends. That edge is listed below with a `(local)` tag — it is not a canonical id and has no peer
chapter row to agree with.

| ID | Peer | Direction | Producer `file:function` | Consumer `file:function` | State |
|---|---|---|---|---|---|
| (local) | bunker CLI | out | `lib.sh:75` `bunker_exec` (composes `bunker exec … -- bash -lc`) | **external** — the `bunker` binary's exec handler, not in this repo | **UNVERIFIED (boundary)** — `bunker` is an external peer with no in-repo function to name; the composed command is nameable, the far side is not, so no "works" verdict is attached to an unnamed side (F0-1) |

## 7. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| syntax | `bash -n scripts/lib.sh` | exit 0 | 2026-11-06, rev `08a2c8a` | PASS |
| who sources it (direct) | `grep -rl '\. "$HERE/lib.sh"' scripts/` | 11 files | 2026-11-06 | PASS (11) |
| who sources it (total) | `grep -rlE '\. "\$HERE/(\.\./)?lib\.sh"' scripts/` | 17 files | 2026-11-06 | PASS (17) |
| fetch_verified fails closed | staged probe `ffc_probe.sh` — source lib.sh, fetch `http://127.0.0.1:1/nothing` with a wrong digest | rc 1, no artifact left | 2026-11-06 | **PASS** — `curl: (7) … Could not connect`, `rc=1`, `no artifact left` |

The probe is not shipped as a file in this repo; the complete invocation (B25) is the two lines
that reproduce it against a refused loopback URL:

```
$ printf '#!/bin/bash\n. /home/kara/code-factory/scripts/lib.sh\nfetch_verified http://127.0.0.1:1/nothing "$1" deliberately-wrong-digest\nprintf "rc=%s artifact=" "$?"; [ -e "$1" ] && echo yes || echo no\n' > /tmp/ffc_probe.sh && chmod +x /tmp/ffc_probe.sh
$ bash /tmp/ffc_probe.sh /tmp/ffc-artifact   # → curl: (7) … ; rc=1 artifact=no
```

An independent verifier reproduced `fetch_rc=1 artifact_present=no` from this same helper
(`round5_verifier_probe.py`); the probe artifact itself is not a repo file. The source-count
commands above are the corrected expressions (B05).

## 8. Metrics

**RED — none (absence-proved).** `lib.sh` emits no counters, gauges or histograms —
`grep -nE 'prometheus|Counter|Gauge|Histogram|/metrics' scripts/lib.sh` → 0 matches (the only
writes are `printf` rows and the `FAILED` integer at `lib.sh:11`). Sourcing frequency and refusal
rate are answerable only by the static greps above.

## 9. Log lines (verbatim)

| Level | Line | Emitted when | Kind |
|---|---|---|---|
| — | `  PASS  %s — %s` (`lib.sh:6`) | `ok` called | **descriptive** — printed unconditionally from two args; proves nothing alone |
| — | `  FAIL  %s — %s` (`lib.sh:7`) | `bad` called, `FAILED` incremented | **descriptive** (same reason) |
| — | `  WARN  %s — %s` (`lib.sh:8`) | `warn` called | descriptive |
| — | `  ..    %s` (`lib.sh:9`) | `note` called | descriptive |
| — | `digest mismatch for %s: want %s got %s` (`lib.sh:26`, stderr) | `fetch_verified` digest mismatch | **evidentiary** — only after the sha256 comparison failed |
| — | `cannot create destination directory %s for %s` (`lib.sh:32`, stderr) | `mkdir -p` of the artifact dir fails | **evidentiary** (B24) |
| — | `cannot move verified download into place at %s for %s` (`lib.sh:37`, stderr) | `mv` of the verified artifact fails | **evidentiary** (B24) |

## 10. Failure modes, indications and recovery

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Digest mismatch | `digest mismatch for %s` on stderr, return 1 | a download/network failure (`curl` exit, no message) | inspect URL and expected hash; the artifact was never moved into place (`:24-38`) |
| Disk floor trip | `  FAIL  disk — <free> GB free < floor` (`:54`) | a `free_gb` failure | free space or lower the floor deliberately |
| Shell injection via `bunker_exec` | a composed `bash -lc` string runs interpolated data | a quoted `shq` call | every interpolated value must pass `shq` before composition (`:72-74`) |

## 11. Limits and margins

- `fetch_verified` `--max-time 120` (`:22`): a download stalling past 120 s fails.
- `shq` (`:67-70`) quotes empty strings and apostrophes for remote-shell composition; it is not a
  sandbox — `bunker_exec` (`:75-78`) joins remaining args into `bash -lc` text, so a caller that
  skips `shq` on interpolated data can inject shell.
- No measured concurrency/throughput limits exist; the helpers are synchronous and single-threaded.

## 12. Cross-references

- F2 PROVISIONING uses `require_disk` (M1) and `fetch_verified` (M5).
- M1 PROVISIONING sources `lib.sh`, resolves `bunker` via `have` (`:13`).
- **M5 HARNESS owns `harness-vars.sh` (M5.S5).** The variable contract is **not** sourced by every
  installer: `install-hermes.sh`, `install-opencode.sh`, `install-deepseek.sh`,
  `install-pi-agent.sh` source it; `install-codex.sh` sources it conditionally (`:47`) then
  re-implements a divergent copy; `install-claude-code.sh` sources `../lib.sh` (`:36`), not
  `harness-vars.sh`, and documents its own CF_* handling inline. See M5 §11.
- The CF_* contract is specified at `specs/HARNESS-MATRIX.md` §5 and enforced at
  `scripts/harness/harness-vars.sh` (M5.S5).

## 13. Evidence of record

- Code: `scripts/lib.sh` (78 lines) — read in full.
- Commands run: `bash -n scripts/lib.sh`; `grep -rl '\. "$HERE/lib.sh"' scripts/` (11);
  `grep -rlE '\. "\$HERE/(\.\./)?lib\.sh"' scripts/` (17); `ffc_probe.sh` (fetch_verified fails
  closed, rc 1, no artifact).
- **Findings:**
  - **F0-1** (carried) — `bunker_exec` (`lib.sh:75-78`) invokes the **bunker CLI**, not crier.
  - **F0-4** (carried) — `ok`/`bad` PASS/FAIL rows are descriptive, not evidentiary.
  - **F0-5** (now owned by M5 §11) — the CF_* variable contract is not a single implementation:
    `install-codex.sh` duplicates the validator; `install-claude-code.sh` sources `lib.sh` not
    `harness-vars.sh`.

## 14. Wave-2 redline — review requirements (target behavior vs implementation coverage)

Per the CF2A-01 review handoff (§1.7, §2): **approved target behavior governs this chapter**; the
source locators, grep counts and probe transcripts in §§1–13 are implementation coverage
evidence, not authority. Source snapshots, deployed effective behavior, historical observations
and approved requirements are distinct record classes and are never interchangeable. Every
requirement below that the measured snapshot does not satisfy is a requirement on the next
revision, not a defect in the evidence.

**R1 — Stable public interface independent of filenames (required).** The supported integration
surface is the helper name/signature set in §3 — not `lib.sh` line numbers. Every `lib.sh:NN`
locator in this chapter identifies the measured revision only; it changes with any edit and is not
part of the contract. Public surface: `say`, `ok`, `bad`, `warn`, `note`, `have`,
`fetch_verified`, `free_gb`, `require_disk`, `once`, `shq`, `bunker_exec`, plus the `FAILED` /
`WARNED` counters with their documented semantics. Everything else in the file is internal. A
signature change, output-format change or status-meaning change is a breaking public-interface
change requiring a version/compatibility statement and caller reconciliation — the compatibility
policy is itself required content (review notes M0, open question 2).

**R2 — Complete per-helper contracts: who calls, why, inputs, outputs, exit codes, side effects,
result propagation (required).** Each public helper carries one stable contract entry: purpose and
the reason a caller reaches for it; which caller roles/scripts invoke it; required and optional
inputs with types, allowed forms, defaults/units and validation preconditions; returned values,
exit codes, printed output; failure and warning conditions; state changes and side effects; and
the caller's obligations — including how the caller must **propagate the result** (a caller that
ignores a returned 1 or an empty `have` result violates the contract). §3's inventory table is
the seed, not the finished depth: an integrating agent must be able to use the documented
interface from this chapter alone, without reverse-engineering the source (review notes M0,
acceptance criterion "handbook sufficient for integration"). Caller/dependency flow is required
content: installers and verification scripts source this module; the helpers call local tools
(`curl`, `sha256sum`, `mktemp`, `df`/`awk`) and cross the Bunker boundary via `bunker_exec` — the
direction of control and responsibility must be readable from the chapter.

**R3 — The newer final-verdict helper; warnings/UNVERIFIED are separate from accepted success
(required, user-approved for inclusion).** The current shared contract defines `verdict(label,
mode)` and a warning counter that the §3 inventory predates; both belong in the public surface.
Required semantics: **check mode** — any recorded failure → `FAIL`; warnings without failure →
`UNVERIFIED`; no failure and no warning → `PASS`. **Action mode** — a warning is advice about an
operation already attempted and does not by itself change a successful result. The caller must
**use the returned result**, not a printed row. Two boundaries are fixed: a printed `PASS` row
never proves a check ran (§9's descriptive/evidentiary split), and this helper summarizes
setup/check results only — it is **not** the GitReins acceptance judge (M3) and **not** board
closure (M4). Audit action/check/final-result semantics so a warning can never be silently folded
into an accepted success.

**R4 — Valid worked examples (required).** The chapter must carry a short caller-to-helper
example showing all three outcome classes and the caller consuming the returned result, e.g.
(target shape; the shipped file is the coverage reference):

```
. ./scripts/lib.sh
have curl            || bad "deps" "curl not found"
fetch_verified "$URL" "$DEST" "$DIGEST" \
  && ok "fetch" "digest verified" \
  || bad "fetch" "refused: digest mismatch or download failure"
verify_all && verdict "setup" check   # FAIL | UNVERIFIED | PASS — branch on it:
case "$?" in 0) proceed ;; 3) warn "setup" "warnings present — unverified, not accepted" ;;
              *) fail-fast with the recorded failures ;;
esac
```

Success, warning/unverified and failure paths must each be shown with the caller's distinct
handling (review notes M0, proposal accepted as method).

**R5 — Required invocation/outcome/duration/error telemetry with collection and readout
(required).** The module must specify (not merely lack) per-helper invocation counters, outcome
classes (success / failure / warning / refusal-by-reason), durations where operationally useful,
and error categories — with an explicitly assigned emission owner (shared helper vs caller),
a collection point, an operator readout, and failure behavior when telemetry itself cannot be
written. §8's absence-proved RED describes the current snapshot only; per-script `FAILED`/`WARNED`
variables are per-process state, **not** fleet-level telemetry, and do not satisfy this
requirement (review notes M0, user-directed change 2). Metric meaning/type/unit and bounded
dimensions follow the cross-cutting metrics standard (handoff §2).

## RED field count: 1 (Metrics §8)

## FLIGHT DATA FILE - M0 SHARED CONTRACT

```checklist
TITLE: M0 SHARED CONTRACT
WHO: NODE OPERATOR
SELFTEST - run the full battery: bash tests/selftest.sh
√ EXIT 0 - every section prints PASS; a FAIL names its fixture
HELPERS - source lib.sh and fire ok/bad/warn/note once each
√ FORMAT - exactly one prefixed line per call, exit status preserved
DISK FLOOR - call require_disk on a host below the floor
√ REFUSAL - named refusal, nonzero exit, nothing written
```
