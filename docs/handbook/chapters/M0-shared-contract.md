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
| Path | `~/code-factory/scripts/lib.sh` |
| Revision | `fbc19cbc807de729e25c358fa7e94207b912f010` (code-factory HEAD; `scripts/lib.sh` byte-identical since `47d68b4` — no file M0 cites changed in `08a2c8a..fbc19cb`) |
| Language / runtime | bash 5.3.9 (measured: `bash --version`); sourced, never executed |
| Owner lane | code-factory (node-side + control-host shell) |
| Status | **SOURCE COVERAGE ONLY** — the earlier 78-line full-read claim is superseded; the P5 snapshot `fb11e92c1580b98e2e8d64cb9a81cdcb3ef64f02` has 110 lines (`wc -l scripts/lib.sh`). Historical read/test rows do not qualify the new §16 ABI (P5-B-39). |

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

**What breaks if it lies.** `fetch_verified` (`lib.sh:51-74`) is the pinned-download primitive
every installer relies on; a false digest match installs a wrong or tampered binary and reports
PASS. `require_disk` (`lib.sh:80-89`) is the disk floor; a false "enough space" lets the
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
| `have()` | `:41-45` | `command -v` — **present: exit 0 and the resolved path on stdout; absent: non-zero and NOTHING on stdout** (never an error message there: callers execute the result as a path, `"$b" cp …`) | either test now reports absence the same way — `if have x`, `have x && …`, and `p=$(have x); [ -n "$p" ]`; the status used to be constant 0, so status-guards written with it were dead code (CF-281) |
| `fetch_verified()` | `:51-74` | url/dest/digest → 0 on digest-verified install, 1 on any failure; the verified artifact is made executable best-effort — `chmod +x "$dest" 2>/dev/null || true` (`:72`), so a **failed chmod is swallowed** and the install still returns 0 (the exit code is the INSTALL, not the chmod — `lib.sh:50`) | the pinned-download primitive (F0-2) |
| `free_gb()` | `:77` | path → `%.1f` GB free | used by `require_disk` only |
| `require_disk()` | `:80-89` | path/floor → `ok` or `bad` + return 1 | the disk-floor admission |
| `once()` | `:92-96` | sentinel + command → runs command only if sentinel absent, then writes a timestamped sentinel | **no concurrency lock**: `:94` checks then `:95` runs with no `flock` — two racers both run; the sentinel is `date -u` text, not a digest |
| `shq()` | `:99-102` | value → single-quoted shell token | quotes empties and apostrophes for remote-shell composition |
| `bunker_exec()` | `:107-110` | server/agent/cmd… → `bunker exec … -- bash -lc "<joined>"` | joins remaining args as trusted shell text; interpolated data must pass `shq` first (`:104-106`) |

## 4. Dependencies

**4a. Runtime dependencies**

| Dependency | Version constraint | Where | How absence is detected |
|---|---|---|---|
| bash | >= 4 | node + control host | `set -u` + undefined helper aborts the caller |
| curl | any | node + control host | `curl -fsSL` nonzero → `fetch_verified` returns 1 (`lib.sh:54`) |
| sha256sum | any | with curl | digest mismatch → return 1 (`lib.sh:56-59`) |
| mktemp | any | with curl | a failed `mktemp` (`:53`) leaves `tmp` unset — `fetch_verified` then acts on an empty path, not a named refusal (no `mktemp` failure branch exists) |
| rm | any | with curl | `rm -f` at `:54/:57/:63/:68` is best-effort cleanup, never a refusal |
| cut / dirname / mkdir / mv | any | with curl | `mkdir -p` failure → named stderr + return 1 (`:62-66`); `mv` failure → named stderr + return 1 (`:67-71`) |
| chmod | any | with curl | **best-effort**: `chmod +x "$dest" 2>/dev/null || true` (`:72`) — a failed chmod is swallowed; the artifact is left non-executable and the install still returns 0 |
| df / awk | any | with curl | `free_gb` (`:77`) depends on `df`+`awk`; a missing `df` yields an empty `free` and `require_disk`'s awk admission (`:83`) mis-decides the floor |

**4b. Library contracts** — `lib.sh` imports nothing; it is the bottom of the shell stack.

**4c. Service contracts** — see §6.

## 5. Settings register

`lib.sh` carries one tunable constant and no env-var surface:

| Setting | Default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| `fetch_verified` `--max-time` | 120 s (`lib.sh:54`, hardcoded) | fixed | download stall ceiling | a download stalling past 120 s fails with rc 1; lowering it rejects slow-but-valid mirrors |

`FAILED` (`lib.sh:11`) is a per-script failure counter, not a setting. The CF_* variable
contract settings (`CF_MAX_TURNS`, `CF_TIMEOUT_S`, `CF_API_KEY_FILE`, …) live in M5.S5, not here.

## 6. Contracts in and out

M0's outbound Bunker execution edge is CT-23, shared with M1; the shell helper ABI
itself is local. Part IV §IV.2.4 is the 31-entry identity registry. Historical local
labels are import aliases only, not alternate target contract IDs.

| ID | Peer | Direction | Producer `file:function` | Consumer `file:function` | State |
|---|---|---|---|---|---|
| CT-23 | bunker CLI | out | `lib.sh:107` `bunker_exec` | external public CLI/protocol; M1 §17 and Part I §1.9.5 | UNVERIFIED — source composition exists; no version-bound target end-to-end qualification record |

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
$ printf '#!/bin/bash\n. ~/code-factory/scripts/lib.sh\nfetch_verified http://127.0.0.1:1/nothing "$1" deliberately-wrong-digest\nprintf "rc=%s artifact=" "$?"; [ -e "$1" ] && echo yes || echo no\n' > /tmp/ffc_probe.sh && chmod +x /tmp/ffc_probe.sh
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
| — | `digest mismatch for %s: want %s got %s` (`lib.sh:58`, stderr) | `fetch_verified` digest mismatch | **evidentiary** — only after the sha256 comparison failed |
| — | `cannot create destination directory %s for %s` (`lib.sh:64`, stderr) | `mkdir -p` of the artifact dir fails | **evidentiary** (B24) |
| — | `cannot move verified download into place at %s for %s` (`lib.sh:69`, stderr) | `mv` of the verified artifact fails | **evidentiary** (B24) |

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
- M1 PROVISIONING sources `lib.sh`, resolves `bunker` via `have` (`:41-45`).
- **M5 HARNESS owns `harness-vars.sh` (M5.S5).** The variable contract is **not** sourced by every
  installer: `install-hermes.sh`, `install-opencode.sh`, `install-deepseek.sh`,
  `install-pi-agent.sh` source it; `install-codex.sh` sources it conditionally (`:47`) then
  re-implements a divergent copy; `install-claude-code.sh` sources `../lib.sh` (`:36`), not
  `harness-vars.sh`, and documents its own CF_* handling inline. See M5 §11.
- The CF_* contract is specified at `specs/HARNESS-MATRIX.md` §5 and enforced at
  `scripts/harness/harness-vars.sh` (M5.S5).

## 13. Evidence of record

- Historical full-read claim: 78 lines, tied only to the old identity note; it is
  superseded by the P5 source inventory (110 lines at `fb11e92c1580b98e2e8d64cb9a81cdcb3ef64f02`).
  No claim that the current target ABI was runtime-verified follows from that old read.
- Commands run: `bash -n scripts/lib.sh`; `grep -rl '\. "$HERE/lib.sh"' scripts/` (11);
  `grep -rlE '\. "\$HERE/(\.\./)?lib\.sh"' scripts/` (17); `ffc_probe.sh` (fetch_verified fails
  closed, rc 1, no artifact).
- **Findings:**
  - **F0-1** (carried) — `bunker_exec` (`lib.sh:107-110`) invokes the **bunker CLI**, not crier.
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
ignores a returned 1, or that treats an empty `have` result as a success when the status says
otherwise, violates the contract; since CF-281 the two agree). §3's inventory table is
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

## 15. Normative integration contract (P3-12, P3-13)

The following contract is the supported M0 interface. Source line numbers in §§1–13 remain measured coverage and are not wire identifiers.

| Helper | Required input | Result and exit contract | Caller obligation |
|---|---|---|---|
| `have` | executable name, non-empty shell word | present: exit 0 and one resolved path on stdout; absent: nonzero and empty stdout | test the exit status or the captured path before invoking it; an empty result is refusal, not success |
| `fetch_verified` | URL, destination path, 64-hex digest | exit 0 only after download, digest comparison, destination move, and executable postcondition; any network, digest, directory, move, or chmod failure returns nonzero and leaves no accepted artifact | do not use the destination until rc 0; record URL, expected digest and measured digest |
| `require_disk` | existing root and positive floor in GiB | exit 0 only when the measured free value is at least the floor; otherwise exit 1 and print the measured value | stop before creating dependent state; a missing measurement is failure, not zero free space |
| `once` | sentinel path and command vector | exit 0 after the command and sentinel write; a present sentinel skips the command; command or sentinel failure is nonzero | use a per-operation identity when concurrent callers are possible; this helper is not a lock |
| `shq` / `bunker_exec` | values to quote; server, agent and command vector | `shq` emits one safe shell token; `bunker_exec` returns the bunker command's status and output | quote every data value before composition; never treat composed output as proof of remote execution |

`ok`, `bad`, `warn`, and `note` are reporting primitives. `FAILED` and `WARNED` are per-process counters. `verdict(label, mode)` is the final local result: check mode returns 0 for PASS, 3 for UNVERIFIED when warnings exist without failures, and 1 for FAIL when any failure exists; action mode preserves a successful operation despite advisory warnings. A caller branches on the returned status, never on a printed PASS row. `verdict` does not judge a commit or close a board row.

A portable caller is:

```sh
. ./scripts/lib.sh
if ! have curl >/dev/null; then bad deps "curl not found"; verdict setup check; exit $?
fi
if fetch_verified "$URL" "$DEST" "$DIGEST"; then ok fetch "digest verified"; else bad fetch "download or digest refused"; fi
verify_all() {
  # The caller supplies the complete local verification battery.
  command -v verify_all_impl >/dev/null 2>&1 || return 1
  verify_all_impl
}
if verify_all; then :; else bad setup "verification failed"; fi
verdict setup check
case $? in 0) exit 0 ;; 3) warn setup "unverified; admission remains closed"; exit 3 ;; *) exit 1 ;; esac
```

The target telemetry contract is one event per helper invocation with `helper`, `operation_id`, `outcome` (`success`, `failure`, `warning`, `refusal`), `reason`, duration in milliseconds and measured values where applicable. The shared helper emits local rows; the owning caller persists structured events and exposes counters and readout. A telemetry-write failure is itself a failure fact and cannot turn a failed check into PASS. Acceptance cases are: absent `curl` refuses before download; a wrong digest leaves no destination; a warning returns UNVERIFIED; and a successful fetch records the expected digest.

## 16. P5 helper ABI and telemetry profile

This section resolves P5-B-31 and P5-B-32. It is target behavior, not a claim that the
historical `scripts/lib.sh` snapshot implements it. Part IV §IV.2 supplies the shared
types, canonical bytes and error record; M1 §17 supplies filesystem durability.

The ABI version is `cf.shell.v1`. Sourcing initializes unset `FAILED` and `WARNED` to
integer zero, preserves existing nonnegative integers, and returns 2 without replacing
invalid values. Repeated sourcing neither resets counters nor emits output. The caller
explicitly assigns both counters to zero at the start of one operation, never midway
through a battery. Except where stated below, a helper returns 0, writes nothing to
stderr, and changes no filesystem state. Wrong arity/type returns 2, emits
`FAIL usage — <helper>: <reason>` on stderr, increments `FAILED` once and performs no
requested operation. Newline, CR and NUL in a reporting argument are rejected; an empty
measurement string is allowed, an empty label is not.

| Signature (exact positional arity) | Required behavior |
|---|---|
| `say(text)`; `note(text)` | one string; stdout is text plus LF, or `  ..    ` plus text plus LF; counters unchanged |
| `ok(label, measurement)`; `bad(label, measurement)`; `warn(label, measurement)` | two strings; exactly one stdout row `  PASS  <label> — <measurement>`, `  FAIL  ...`, or `  WARN  ...` plus LF; only `bad` increments FAILED, only `warn` increments WARNED, by one |
| `have(name)` | one executable basename without slash or whitespace; stdout is resolved executable path plus LF and rc 0, or empty stdout and rc 1 if absent; no counter change |
| `free_gb(path)` | one existing directory; decimal GiB (available bytes / 1073741824), one fractional digit, C locale, LF; rc 1 and empty stdout on measurement error; admission compares unrounded bytes, not this display value |
| `require_disk(path, floor)` | floor is decimal GiB in (0,4096]; compares available bytes with ceiling(floor × 1073741824); one `ok` row on success, one `bad` row and rc 1 on insufficient/unmeasurable capacity |
| `verdict(label, mode)` | mode is exactly `check` or `action`; FAILED>0 prints `<label>: FAIL (<n>)`, rc 1; otherwise check with WARNED>0 prints `<label>: UNVERIFIED`, rc 3; otherwise prints `<label>: PASS`, rc 0; no counter change |
| `shq(value)` | one string, including empty; emits one POSIX single-quoted token with embedded apostrophes encoded by closing/escaped/reopening quotes, no LF; no execution |
| `bunker_exec(server, agent, command...)` | at least three arguments; server/agent are Part IV IDs; command fragments are explicitly trusted shell syntax, data passes through `shq`; stdout/stderr and exit status are those of Bunker; no independent PASS |
| `fetch_verified(url, destination, digest)` | exactly three strings; HTTPS URL or explicit offline `file:` URL, absolute destination and SHA-256; at most 120 s download; verifies temporary bytes and executable mode 0700 before atomic rename; rc 1 on network/hash/chmod/fsync/rename error |
| `once(sentinel, command...)` | at least two arguments; absolute sentinel and nonempty argv; execs argv directly without eval; returns command status on failure, 1 on persistence failure, 0 on authenticated skip/success |

`fetch_verified` uses an O_EXCL temporary regular file in the destination directory,
rejects a symlink destination/parent, and fsyncs the verified/chmodded temporary file
before rename and the parent afterward. Before rename, every error removes the temporary
file and preserves any previous destination byte-for-byte. A post-rename directory-fsync
failure returns 1 with `PERSISTENCE_UNAVAILABLE`; the new destination is quarantined as
unaccepted, not used, and the recovery record names both digests. It never unlinks a
previous valid destination merely because the new download fails. Acceptance tests cover
an absent destination and a pre-existing executable on each failure arm.

`once` locks `<sentinel>.lock` with exclusive flock before reading. Its sentinel is a
mode-0600 JCS object `{schema:"cf.once.v1", command_digest:SHA, completed_at:Time}`;
command_digest hashes the JCS argv array, with cwd and effective non-secret environment
included in a surrounding `{argv,cwd,env}` object. An existing malformed sentinel or a
different command digest returns 1 `SENTINEL_CONFLICT` without execution. The caller
uses an operation-idempotent command: if execution succeeds but sentinel persistence
fails, retry may invoke it again. The helper cannot promise exactly-once external effects.
The sentinel uses file/directory fsync and atomic rename. Failed actions call `bad`
before `verdict ... action`; advisory warnings cannot erase a failed command. Check-mode
warning reduction applies to readiness and conformance; action-mode advice does not certify
readiness. [Contract basis: M0 §§14–15; M5 §16.]

### 16.1 Shared event and metric vocabulary (CT-30)

Each owning module persists a `cf.telemetry.v1` JSONL event before acknowledging a
state-changing operation: `event_id:ID`, `operation_id:ID`, `module:M0..M6`,
`event_type:Enum`, `outcome:success/failure/warning/refusal/unknown`, `reason:ID`,
`duration_ms:UInt`, `observed_at:Time`, `measurements:{name:finite-number}`.
The closed event_type set is `helper`, `provision`, `enrollment`, `readiness`, `dispatch`,
`lease`, `duplicate`, `cancellation`, `gate`, `publication`, `projection`, `board-read`,
`claim`, `repair`, `lifecycle`, `conformance`, `document-stage`. IDs and generations occur
in event records, never metric labels. Secret values, prompt text and credential paths
are excluded. Events use the operation journal's fsync transaction or durable outbox;
outbox append failure is `PERSISTENCE_UNAVAILABLE` and withholds success. Delivery failure
retains the outbox and does not undo an already committed operation.

The collector exposes authenticated, read-only `GET /factory/v1/metrics` (Prometheus
text) and `GET /factory/v1/events?after=<sequence>&limit=<1..1000>` (Part IV response,
ordered events and next sequence). Scrape period is 15 s. Event duplicates are suppressed
by event_id; counters are reconstructed from the retained checkpoint plus events, not
reset on process restart. Histograms are cumulative seconds buckets
0.01, 0.1, 1, 5, 30, 120, 600, 3600, +Inf. The metrics use the closed label sets below. Operation instruments use module,
event_type and outcome only; board counts additionally use the closed M4 status enum
and eligibility enum. Project/task/generation/error text never appears in a metric label.

| Instrument | Type / units | Definition |
|---|---|---|
| `cf_operations_total` | counter / operations | terminal event count by the three labels |
| `cf_operation_duration_seconds` | histogram / seconds | terminal duration_ms / 1000 by module and event_type |
| `cf_queue_depth` | gauge / messages | pending custody messages summed over configured projects |
| `cf_oldest_pending_seconds` | gauge / seconds | maximum age of pending work; empty queue = 0 |
| `cf_projection_lag_seconds` | gauge / seconds | oldest unacknowledged board/memory outbox event age; empty outbox = 0 |
| `cf_certification_age_seconds` | gauge / seconds | maximum age among active bindings; absent bindings omit sample |
| `cf_board_tasks` | gauge / tasks | count by status and eligibility (`eligible`, `unmet`, `unknown`) |
| `cf_observation_timestamp_seconds` | gauge / Unix seconds | last successful source observation by module |
| `cf_recovery_pending` | gauge / operations | unresolved recovery records by module |

An unavailable observation omits the affected gauge and emits outcome=unknown; it never
manufactures zero. Samples older than 60 s are stale. Alerts fire for observation age
above 60 s for 60 s, queue age above 120 s for 120 s, projection age above 300 s for
60 s, any unresolved recovery for 60 s, and certification age above 86400 s immediately.
Events retain 90 days and counters/checkpoints 400 days; acceptance evidence follows
M3 §17's longer roots. Ratios with zero denominator are unknown. These are specified
defaults, not measured fleet thresholds. A collector restart, unavailable source and
replayed event are required negative/positive conformance cases.

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
