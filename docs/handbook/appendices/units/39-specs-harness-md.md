# 39. specs/HARNESS.md

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/specs/HARNESS.md` |
| Repository | `code-factory` |
| Revision | `6eea792` |
| Status | **VERIFIED — the adapter inventory and every `--check` leg measured at this revision; smoke legs quoted from the battery's own record, not re-run** |

The central question this module answers is not "what is a harness". It is **which harnesses are
supported for real** — an installer exists on disk *and* that installer's `--check` passes — versus
**which are only named**. The spec itself supplies the test: "The others ship a documented
`--check` and a method, and are marked `UNVERIFIED` until someone runs them — an unverified
installer is not a supported installer, and the script says so out loud" (`specs/HARNESS.md:41`).
Applied at this revision the rule sorts nine names into four buckets: **two supported for real**
(`codex`, `claude-code`, both `--check` exit 0 against a binary the adapter itself installed), **one
installable but failing its own check here** (`hermes`, refused at the interpreter row), **one whose
installer refuses by design** (`opencode`), and **five named-only** (`aider`, `goose`, `pi-agent`,
`deepseek`/`dsh`, `opencode-v2`) — of which `aider` and `goose` are also invisible to the only
mechanism that could refute them.

## 1. Purpose and why it matters

- **What breaks if this module is absent:** the factory loses its definition of "runs the work
  inside a node" and every adapter loses its six obligations (install, version, invoke, report,
  fail, idempotent — `specs/HARNESS.md:13`). Without it, `scripts/harness/*.sh` are four unrelated
  installers and `tests/harness-conformance.sh` has nothing to certify against; the selection rule
  and the `CF_*` contract would still live in `specs/HARNESS-MATRIX.md:7`, but the per-adapter
  obligations that make a selection executable would not exist.
- **What breaks if it lies:** a node gets created on a harness that cannot install, and the failure
  surfaces as a dead tick rather than a refused one. That is already the live state for part of the
  table: the spec's §"Adapters and their measured state" names `aider` (`specs/HARNESS.md:30`) and
  `goose` (`specs/HARNESS.md:31`) as harnesses that "ship a documented `--check`", and **no such
  file exists** — `scripts/harness/` holds exactly four installers, and neither `aider` nor `goose`
  is in the conformance battery's harness table (`tests/harness-conformance.sh:89`), so they produce
  no row at all. A reader who trusts §2 will believe two harnesses are checkable that are entirely
  invisible to the only mechanism that could refute them.
- The spec knows this failure mode and legislates against it: "A harness named in the tables above
  with no adapter file is a `FAIL`, never a skip" (`specs/HARNESS.md:55`). The battery does that for
  `deepseek` and `pi-agent` (`docs/HARNESS-CONFORMANCE.md:43`, `docs/HARNESS-CONFORMANCE.md:46`) —
  but only because those two are in *its* table, which is the opposite direction of the guarantee:
  the battery's table is not derived from the spec's table, so the promise holds only where someone
  remembered to add the row.
- Definition used throughout, and the reason "supported" is a measurement and not an adjective:
  "A harness counts as supported only when the conformance battery's legs pass on a real node"
  (fact: FACT-08).

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| bash (arrays, `<&3` fd reads, `local -n`-free code) | 4+ | every adapter and the battery | `bash -n` syntax gate in the battery, `tests/harness-conformance.sh:209` |
| `curl` + `sha256sum` | any | codex `--apply` download; `fetch_verified` digest check | `  FAIL  download — download or digest check failed for …` (`scripts/harness/install-codex.sh:360`), gated by `scripts/lib.sh:16` |
| python `>=3.11,<3.14` | 3.12.13 measured present | `$HOME/hermes-venv` for hermes; any python3 for the codex/claude adapters' YAML and JSON helpers | `  FAIL  python — hermes-agent 0.19.0 requires python >=3.11,<3.14; found 3.14.4` (`scripts/harness/install-hermes.sh:59`) |
| node `>=22` + npm | v22.22.3 / 10.9.8 measured present | claude-code only; installed under `$HOME/.local/harness/npm` | `scripts/harness/install-claude-code.sh:43`, `:333` |
| `df`, `mktemp`, `unzip`/`tar` | any | codex disk floor and tarball extraction | `scripts/lib.sh:32`, `scripts/harness/install-codex.sh:56` |
| `jq` | any | battery credential probes (`~/.codex/auth.json`, `~/.pi/agent/auth.json`) | malformed probe output, `tests/harness-conformance.sh:143` |
| `ss` | any | hermes listener check; absent → WARN, `/api/status` 200 becomes the evidence | `scripts/harness/install-hermes.sh:295` |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `scripts/lib.sh` | this repo | `say/ok/bad/warn/note` print exactly `  PASS  <leg> — <value>`; `bad()` increments `FAILED`; `fetch_verified()` refuses a digest mismatch | the battery's `adapter_row()` greps `  PASS  <name>` at column 0 and would quote nothing — `tests/harness-conformance.sh:108` |
| `tests/harness-conformance.sh` `HARNESSES` table | this repo | six pipe-separated fields `id\|adapter\|binary\|generation\|smoke-cmd\|measured` | adding a harness without adding an adapter flips its `check` and `apply` rows to FAIL by construction (`tests/harness-conformance.sh:206`) |
| codex `exec --json` event stream | codex-cli 0.166.0 | `{"type":"thread.started","thread_id":…}` on stdout; `exec resume <id>` continues it | `model_served` and `thread` become unreadable (`scripts/harness/install-codex.sh:480`) |
| codex rollout JSONL | codex-cli 0.166.0 | `sessions/*<thread_id>.jsonl` carries `"thread_settings":{…"model":"…"}` | `model_served` degrades to `requested … → served unknown (no rollout record found)` (`scripts/harness/install-codex.sh:490`) |
| claude `-p --output-format json` | @anthropic-ai/claude-code 2.1.318 | a JSON result carrying the served model | `  FAIL  report — could not read model_served from the JSON result …` (`scripts/harness/install-claude-code.sh:620`) |
| npm registry metadata | registry.npmjs.org | `dist.integrity` + `dist.shasum` for the pin, re-read before install | `  FAIL  provenance — refused — …` (`scripts/harness/install-claude-code.sh:427`) |

### 2c. Service contracts (both sides must be named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| hermes gateway | adapter → node | HTTP on `:$NODE_GATEWAY_PORT` | `GET /api/status` → 200 (never `/health`, which 302s to login) | `scripts/harness/install-hermes.sh:236`, `:284` |
| crier harness adapters | spec → crier | Go package per harness | codex `exec` create/resume; the `pi` id (not `pi-agent`) | `specs/HARNESS-MATRIX.md:52`, `specs/HARNESS-MATRIX.md:53` |
| npm registry | claude-code adapter | HTTPS | pin metadata, then `npm install -g --prefix` | `scripts/harness/install-claude-code.sh:409`, `:472` |
| GitHub releases | codex adapter | HTTPS, digest-pinned | `codex-x86_64-unknown-linux-musl.tar.gz` at `rust-v0.166.0` | `scripts/harness/install-codex.sh:157`, `:337` |

**Per-requirement binding** — the contract at `specs/HARNESS.md:13` binds to these artifacts, and
this is where the "supported for real" question becomes mechanical:

| Obligation (spec line) | Implemented by | Can go red in |
|---|---|---|
| Install (`:15`) | `scripts/harness/install-hermes.sh:270`, `scripts/harness/install-codex.sh:358`, `scripts/harness/install-claude-code.sh:476`; **refused** by `scripts/harness/install-opencode.sh:31` | `tests/harness-conformance.sh:325` (apply leg), `tests/harness/codex-install-test.sh:2`, `tests/harness/claude-code-install-test.sh:156` |
| Version (`:16`) | `scripts/harness/install-hermes.sh:227`, `scripts/harness/install-codex.sh:315`, `scripts/harness/install-claude-code.sh:358`, `scripts/harness/install-opencode.sh:17` | `tests/harness-conformance.sh:224` |
| Invoke (`:17`) | battery smoke legs `tests/harness-conformance.sh:181`; adapter-owned turns `scripts/harness/install-codex.sh:427`, `scripts/harness/install-claude-code.sh:566` | `tests/harness-conformance.sh:321` |
| Report (`:18`) | `scripts/harness/install-codex.sh:488`, `scripts/harness/install-claude-code.sh:623` | `docs/HARNESS-CONFORMANCE.md:19` (codex turn died before reporting) |
| Fail (`:19`) | exit 0/1 per adapter; `CODEX: REFUSED (<leg>)` exits 2 (`scripts/harness/install-codex.sh:75`) | `tests/selftest.sh:2589` §45 |
| Idempotent (`:20`) | `scripts/harness/install-hermes.sh:279`, `scripts/harness/install-codex.sh:343`, `scripts/harness/install-claude-code.sh:460` | `tests/harness/claude-code-install-test.sh:7` (case c) |

## 3. Verification

The battery is one script with three legs per harness — the adapter's own `--check`, a real smoke
turn that must leave a file containing a token the battery chose, and (only with `--install`) the
adapter's `--apply` in a throwaway `$HOME` (`tests/harness-conformance.sh:4`). **Measured rows
below are the adapter legs re-run at this revision; the smoke rows are quoted from the committed
matrix of record, which was generated at `10a796f` and no adapter or battery file has changed
between `10a796f` and `6eea792`.**

| Harness | Check command | Measured at `6eea792` | Exit | Verdict |
|---|---|---|---|---|
| codex | `bash scripts/harness/install-codex.sh --check` | `  PASS  binary — /home/kara/.local/codex/0.166.0/bin/codex (installed by this adapter)` · `  PASS  version — 0.166.0 (pin 0.166.0)` · `CODEX: PASS` | 0 | **supported for real** |
| claude-code | `bash scripts/harness/install-claude-code.sh --check` | `  PASS  binary — /home/kara/.local/harness/npm/bin/claude (installed by this adapter)` · `  PASS  version — 2.1.318 (pin 2.1.318)` · `CLAUDE-CODE: PASS` | 0 | **supported for real** (no turn recorded) |
| hermes | `bash scripts/harness/install-hermes.sh --check` | `  FAIL  python — hermes-agent 0.19.0 requires python >=3.11,<3.14; found 3.14.4` | 1 | **installable, not conformant here** |
| hermes (knob) | `HERMES_PYTHON_BIN=python3.12 bash scripts/harness/install-hermes.sh --check` | `  PASS  python — 3.12.13 (hermes-agent 0.19.0 requires >=3.11,<3.14)` · `  FAIL  binary — host-provided /home/kara/.local/bin/hermes (not installed by this adapter — run --apply)` · `  FAIL  version — 0.22.5+3030.g770a952 != pin 0.19.0` · `  FAIL  port — nothing on :10800` · `HERMES: FAIL (3)` | 1 | **installer real, host state not** |
| opencode | `bash scripts/harness/install-opencode.sh --check` | `  FAIL  binary — absent — no opencode in this node` · `  PASS  user_space_binary — /home/kara/.opencode/bin/opencode` (1.18.29) · `OPENCODE: FAIL (1)` | 1 | **not supported** |
| pi-agent | no file `scripts/harness/install-pi-agent.sh` | `  FAIL  pi-agent:check — no adapter at scripts/harness/install-pi-agent.sh — the harness is named and cannot be certified` (`docs/HARNESS-CONFORMANCE.md:46`) | — | **named only** |
| deepseek | no file `scripts/harness/install-deepseek.sh` | `  FAIL  deepseek:check — no adapter at scripts/harness/install-deepseek.sh — the harness is named and cannot be certified` (`docs/HARNESS-CONFORMANCE.md:43`) | — | **named only** |
| opencode-v2 | shares `scripts/harness/install-opencode.sh` | `  FAIL  opencode-v2:check — adapter passes on opencode 1.18.29 but this harness is the v2 generation — the adapter has no generation gate` (`docs/HARNESS-CONFORMANCE.md:40`) | — | **named only, no artefact** |
| aider, goose | no file | **no row exists** — absent from `tests/harness-conformance.sh:89` | — | **named only, unmeasured by anything** |

Smoke legs as recorded in the matrix of record (`docs/HARNESS-CONFORMANCE.md:17`):

| Harness | Smoke row | Reading |
|---|---|---|
| hermes | `  PASS  hermes:smoke — smoke.txt contains CF-CONF-hermes-b61ec2 (21 B, sha256 0b0c8e36fd2b…, exit 0; token sha256 0b0c8e36fd2b…)` | a real turn wrote the chosen token |
| opencode | `  PASS  opencode:smoke — smoke.txt contains CF-CONF-opencode-d4914b (24 B, …)` | the *binary* works; only the installer is refused |
| codex | `  FAIL  codex:smoke — turn exited 124 and wrote no smoke.txt after 1 attempt(s) — ERROR: Reconnecting... waiting for network` | transport failure, not an adapter defect |
| claude-code | `  SKIP  claude-code:smoke — binary \`claude\` absent from PATH` | **misleading**: the binary exists at `$HOME/.local/harness/npm/bin/claude` and `--check` PASSes; the adapter creates no shim |
| opencode-v2 | `  SKIP  opencode-v2:smoke — no opencode 2.x binary on PATH (measured 1.18.29 is v1); …` | correct: there is no v2 artefact to smoke |
| pi-agent / deepseek | `SKIP` naming the credential / `binary absent` | a SKIP is explicitly not support (`specs/HARNESS.md:53`) |

Battery-wide: `tests/harness-conformance.sh` exits non-zero on any FAIL, and `--write-doc`
regenerates `docs/HARNESS-CONFORMANCE.md` (`tests/harness-conformance.sh:387`). The battery's own
ability to go red is proved by `tests/selftest.sh:2589` — **§45, not §44 as the spec claims** (see
§6). Adapter-specific proofs: `tests/harness/codex-install-test.sh` (refusals, digest floor,
idempotence, version-mismatch arm, one live turn) and `tests/harness/claude-code-install-test.sh`
(absent-binary honesty, credential-as-value refusal, idempotence, one live turn).

## 4. Metrics emitted

No rate, latency or liveness metric is emitted by any adapter. What exists is three counters and
one record line, all of them quoted rather than scraped:

- `FAILED` — incremented by `bad()` in `scripts/lib.sh:7`, rendered in the adapter's last line as
  `HERMES: FAIL ($FAILED)` / `CODEX: FAIL ($FAILED)` / `OPENCODE: FAIL ($FAILED)`.
- The battery's summary: `summary: <n> pass, <n> fail, <n> skip` (`tests/harness-conformance.sh:499`),
  built from the TSV result file it appends per leg (`tests/harness-conformance.sh:82`) — the only
  machine-readable artefact the verification path leaves behind.
- Per-leg measured values, which are the actual assertions: bytes and sha256 of the smoke artefact,
  the version read back from the binary, and `model_served`.
- The hand-over record, emitted by the claude-code adapter and not by the others:
  `record harness=claude-code harness_version=2.1.318 model_requested=… model_served=… provider_binding=… run_id=… lane=… namespace=… workdir=…` (`scripts/harness/install-claude-code.sh:624`), followed by
  `record memory=not-written (leg 'memory' belongs to the foreman; this adapter echoes the fields it must hand over)` (`scripts/harness/install-claude-code.sh:625`).
- Install duration and footprint exist only as one-shot measurements in comments — `32 s` and
  `248 MB` for hermes (`scripts/harness/install-hermes.sh:4`), `8 s` and `323 MB` for claude-code
  (`scripts/harness/install-claude-code.sh:21`) — never as an emitted metric.

## 5. Log lines it can generate

Rows are produced by `lib.sh` and are the parser's contract: `printf '  PASS  %s — %s\n'`
(`scripts/lib.sh:6`), `  FAIL  ` (`:7`), `  WARN  ` (`:8`), `  ..    ` (`:9`).

Adapter verdict lines. The trailing count is `$FAILED` printed literally as a number, so the
template is given with `(<n>)` where the source has the variable (`scripts/lib.sh:7`); lines marked
*measured* are the exact bytes this run produced at `6eea792`, the rest are the source templates
with their line locators.

```
HERMES: PASS
HERMES: FAIL (3)                                    # measured
```
```
CODEX: PASS                                         # measured
CODEX: FAIL (<n>)
CODEX: REFUSED (<leg>)                              # becomes CODEX: REFUSED (arch) on a non-x86_64 host
```
```
CLAUDE-CODE: PASS                                   # measured
CLAUDE-CODE: FAIL ($FAILED) — contract refused; nothing was installed or run
```
```
OPENCODE: PASS
OPENCODE: FAIL (1)                                  # measured
```

Leg rows, verbatim. The hermes rows were produced by the two runs in §3 at `6eea792`; the
adapter rows without a comment are the source's own templates with the same rendering; the
`<harness>:<leg>` rows are copied from the matrix of record.

```
  FAIL  python — hermes-agent 0.19.0 requires python >=3.11,<3.14; found 3.14.4                 # measured, default run
  PASS  python — 3.12.13 (hermes-agent 0.19.0 requires >=3.11,<3.14)                           # measured, knob run
  FAIL  binary — host-provided /home/kara/.local/bin/hermes (not installed by this adapter — run --apply)   # measured, knob run
  FAIL  version — 0.22.5+3030.g770a952 != pin 0.19.0                                            # measured, knob run
  FAIL  port — nothing on :10800                                                                # measured, knob run
  PASS  inference_key — a provider key is present in ~/.hermes/.env (value not read)             # measured, knob run
  FAIL  inference_key — no provider key — a turn dies at 'No inference provider configured'      # template
  FAIL  apply — refused — the opencode install ladder is unmeasured here. Measure it, record it in specs/HARNESS.md, then implement this leg.   # template
  FAIL  pi-agent:check — no adapter at scripts/harness/install-pi-agent.sh — the harness is named and cannot be certified   # matrix of record
  FAIL  pi-agent:apply — no adapter at scripts/harness/install-pi-agent.sh — nothing can install this harness                # matrix of record
  SKIP  claude-code:smoke — binary `claude` absent from PATH                                                                 # matrix of record
  SKIP  codex:apply — not attempted: --install was not requested (this battery installs nothing without it)                   # matrix of record
  PASS  hermes:smoke — smoke.txt contains CF-CONF-hermes-b61ec2 (21 B, sha256 0b0c8e36fd2b…, exit 0; token sha256 0b0c8e36fd2b…)   # matrix of record
  FAIL  codex:smoke — turn exited 124 and wrote no smoke.txt after 1 attempt(s) — ERROR: Reconnecting... waiting for network       # matrix of record
```

Battery footer, as the source emits it (`tests/harness-conformance.sh:499`) — the numbers are the
run's own counters, so only the shape is quotable:

```
summary: <n> pass, <n> fail, <n> skip
HARNESS CONFORMANCE: FAIL (<n>)
```

`PASS` replaces `FAIL (<n>)` only when no leg FAILed (`tests/harness-conformance.sh:500`); a SKIP
never fails the run, which is precisely why a matrix full of SKIPs still prints `HARNESS
CONFORMANCE: PASS`.

Refusal strings an operator will actually meet, verbatim: `  FAIL  credential_argv — refused: a credential may never travel as an argument (AGENTS.md r8) — pass --api-key-file <path> instead` (`scripts/harness/install-codex.sh:99`) and `  FAIL  gateway_start — refused: a public bind needs dashboard.basic_auth in ~/.hermes/config.yaml — block absent (config check failed)` (`scripts/harness/install-hermes.sh:301`).

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| **Spec names a harness that nothing else in the tree names** — `aider`, `goose` | No log line at all: no adapter file, no battery row. The spec says they "ship a documented `--check`" (`specs/HARNESS.md:30`, `specs/HARNESS.md:31`) while `scripts/harness/` contains only hermes/codex/claude-code/opencode and `tests/harness-conformance.sh:89` lists seven ids, neither of them. `README.md:115` says they "ship no installer yet (CF-006)" — true of `aider` and `goose`, while the same sentence is stale about `codex`, which does have one (`scripts/harness/install-codex.sh:2`). | `pi-agent`/`deepseek`, which are *also* installer-less but at least produce a red row. Silence vs. a named FAIL is the difference between "nobody looked" and "this cannot be certified". | Add `install-aider.sh`/`install-goose.sh`, or delete both rows from `specs/HARNESS.md:30`. A spec row the battery cannot see is a claim with no refuter. |
| **A verification claim pointing at the wrong section** | The spec says "`tests/selftest.sh` §44 keeps the battery itself able to fail" (`specs/HARNESS.md:56`); §44 is `44. the node bus worker names the refusal it cannot proceed past (CF-215)` (`tests/selftest.sh:2518`) and the battery's red-proof is §45, `45. the harness conformance battery can go red (fixture mode)` (`tests/selftest.sh:2589`). | A battery that is genuinely unproven — here the proof exists, one section later (`tests/selftest.sh:2588` carries the `ch:trace` to `harness-conformance-battery`). | Correct the citation to §45. A locator that resolves to the wrong test is worse than a missing one: it reads as verified. |
| **Spec row is stale relative to a measured install** | `opencode` is "not measured here" (`specs/HARNESS.md:27`) while the matrix of record shows `  PASS  opencode:smoke — smoke.txt contains CF-CONF-opencode-d4914b (24 B, …)` (`docs/HARNESS-CONFORMANCE.md:20`). `claude-code` is "not measured here; node absent in base image" (`specs/HARNESS.md:28`) while node v22.22.3/npm 10.9.8 are present, the adapter is pinned at 2.1.318 and measured at 8 s (`scripts/harness/install-claude-code.sh:21`), and its `--check` PASSes at this revision. | A harness that was never tried. Both of these *were* tried; only the spec's prose is behind the tree. | Re-measure and rewrite the two rows. Take the state from the battery, never from memory. |
| **`--apply` refuses by design, so the harness can never be installed** | `  FAIL  apply — refused — the opencode install ladder is unmeasured here.` (`scripts/harness/install-opencode.sh:32`), with the banner `harness: opencode (UNVERIFIED adapter)` (`scripts/harness/install-opencode.sh:12`). The binary works when the host already has it. | A broken installer. This one is honest and injective: it refuses rather than half-installing, which is exactly what `specs/HARNESS.md:43` demands. | It stays named-only until someone measures the ladder and writes the leg. "An unverified installer is not a supported installer." |
| **A generation the tree cannot tell apart** | `opencode-v2` shares `install-opencode.sh`, which probes `opencode` with no version gate, so `--check` passes on a v1 binary: `  FAIL  opencode-v2:check — adapter passes on opencode 1.18.29 but this harness is the v2 generation — the adapter has no generation gate` (`docs/HARNESS-CONFORMANCE.md:40`). There is no v2 artefact to install: npm `opencode2` resolves to `0.0.1-security`, a squatted holding package, and `opencode-ai@latest` is 1.19.5 (`specs/HARNESS-MATRIX.md:52`; re-measured 2026-11-05 with `npm view opencode2 version` → `0.0.1-security`). | A real v2 that simply is not installed. Here the *harness* does not exist, so no install could help. | Keep the row as a permanent FAIL, or drop `opencode-v2` from `tests/harness-conformance.sh:93` until an artefact exists. Two harnesses pointing at one installer with one generation is a mis-certification waiting to happen. |
| **The default interpreter refuses before anything else is measured** | `  FAIL  python — …found 3.14.4`, exit 1, and the adapter stops at `check_python_compatibility \|\| exit 1` (`scripts/harness/install-hermes.sh:216`) — binary, version, port and inference key are never reached. | A missing hermes install. The refusal is about the interpreter, and the battery names the knob: "the adapter refused `python3` (Python 3.14.9); python3.12 is on PATH, so `HERMES_PYTHON_BIN=python3.12` reaches the binary/version/port rows" (`docs/HARNESS-CONFORMANCE.md:53`). | `HERMES_PYTHON_BIN=python3.12`. Measured: with the knob the python row PASSes and the three downstream FAILs appear — which is the point, those are the real state. |
| **A host-provided binary masquerading as the pin** | `  FAIL  binary — host-provided /home/kara/.local/bin/hermes (…)` plus `  FAIL  version — 0.22.5+3030.g770a952 != pin 0.19.0`. | A correct install at the wrong version. Documented as intentional: a PATH binary "is labelled host-provided and FAILs the binary row, even if its version matches" (`specs/HARNESS.md:35`). | `--apply`, which creates `$HOME/hermes-venv` and installs `hermes-agent==$HERMES_PIN` regardless of PATH (`scripts/harness/install-hermes.sh:258`). |
| **The battery reports "absent from PATH" for a binary it installed** | `  SKIP  claude-code:smoke — binary \`claude\` absent from PATH` (`docs/HARNESS-CONFORMANCE.md:33`) while the same adapter's `--check` PASSes on `$HOME/.local/harness/npm/bin/claude` and creates no shim (no `SHIM`/`.local/bin` reference anywhere in `scripts/harness/install-claude-code.sh`); `opencode` has the same shape via `$HOME/.opencode/bin/opencode` (1.18.29 measured). | A real absence. Reading this SKIP as "claude-code is not installed" is the trap. | Put the adapter prefix on PATH, or have the adapter link a shim the way codex does (`scripts/harness/install-codex.sh:55`). Until then the smoke leg cannot ever pass for a correctly installed claude-code. |
| **Three names for two missing harnesses — `dsh`, `deepseek`, `pi-agent`** | The battery names `deepseek` (`tests/harness-conformance.sh:94`) and `pi-agent` (`tests/harness-conformance.sh:95`), both with no adapter file, so both print `no adapter at scripts/harness/install-<id>.sh`. The matrix names the real packages: `@deepseek-ai/dsh` 0.2.1-rc.5, "absent from both repos" with an installer still owed (`specs/HARNESS-MATRIX.md:183`), and `oh-my-pi (omp)` as `@oh-my-pi/pi-coding-agent`, where crier's adapter is named `pi`, "so the spelling `pi-agent` fails" (`specs/HARNESS-MATRIX.md:53`). `specs/HARNESS.md` names `pi-agent` (`specs/HARNESS.md:32`) and neither `dsh` nor `deepseek`. | `opencode`, whose adapter at least exists and refuses (`scripts/harness/install-opencode.sh:32`). Here there is no file to refuse, so the FAIL is structural rather than a measured refusal. | One id, one installer, one row. Today three files use three names for two harnesses that no installer in this tree can produce. |
| **A PASS with no measured value** | Guarded, not merely warned: `emit()` rewrites an empty PASS to FAIL with `guard: a PASS carried no measured value` (`tests/harness-conformance.sh:72`) and an empty SKIP to `guard: a SKIP did not name what is missing` (`:73`). | A real PASS. | None needed — this is the one failure mode the tree already closes. |

## 7. Environment and settings it reads

| Variable | Default | Effect if unset |
|---|---|---|
| `HERMES_PIN` | `0.19.0` (`scripts/harness/install-hermes.sh:17`) | Pin defaults to 0.19.0; a venv at another version is named and reinstalled |
| `HERMES_PYTHON_BIN` | `python3` (`scripts/harness/install-hermes.sh:19`) | `python3` is used, and on a 3.14 host every downstream row is skipped by the early exit |
| `NODE_GATEWAY_PORT` | `10800` (`scripts/harness/install-hermes.sh:16`) | Port 10800 is probed and started; a node on another port reads as `  FAIL  port — nothing on :10800` |
| `CF_CODEX_PIN` | `0.166.0` (`scripts/harness/install-codex.sh:49`) | The digest is bound to 0.166.0 only; a different pin without a re-measured digest fails the check |
| `CF_CODEX_ARCH` | `uname -m` (`scripts/harness/install-codex.sh:157`) | Architecture is measured; any target other than x86_64-linux-musl refuses by name (`scripts/harness/install-codex.sh:337`) |
| `CF_TURN_TOKEN` / `CF_TURN_FILE` | `CF-227-TOKEN-7f3a9c` / `codex-turn.txt` (`scripts/harness/install-codex.sh:58`) | The adapter's own `--turn` proves a fixed token; the battery does not need these (it chooses its own) |
| `CF_TIMEOUT_S` | `300` in the adapter, `1800` for a claude turn (`scripts/harness/install-codex.sh:60`, `scripts/harness/install-claude-code.sh:290`) | A hung turn is cut at the default and reported as exit 124 |
| `CLAUDE_CODE_PIN` | `2.1.318`, a constant, **not** overridable (`scripts/harness/install-claude-code.sh:39`) | There is no knob: the pin moves only by editing the adapter |
| `CF_API_KEY_FILE` | unset | A credential arrives as a path at mode 600; nothing else is accepted, and `CF_API_KEY`/`OPENAI_API_KEY` in the ambient environment are refusals (`scripts/harness/install-codex.sh:126`) |
| `CF_MODEL` `CF_PROVIDER` `CF_WORKDIR` `CF_NAMESPACE` `CF_RUN_ID` `CF_LANE` | unset | Required for a turn; refused as `the CF_* set from specs/HARNESS-MATRIX.md §4 is incomplete` (`scripts/harness/install-codex.sh:181`) |
| `HC_TIMEOUT` / `HC_APPLY_TIMEOUT` | `300` / `600` (`tests/harness-conformance.sh:34`) | A smoke turn or an install is cut at those values |
| `HC_WORK_ROOT` | `$HOME/.harness-conformance` (`tests/harness-conformance.sh:54`) | Results, smoke artefacts and scratch HOMEs land under `$HOME`; nothing goes to a system temp dir by design |
| `HC_KEEP_APPLY` | unset | The scratch `$HOME` from `--install` is removed; setting it preserves the tree for inspection |

## 8. Evidence of record

- **Matrix of record:** `docs/HARNESS-CONFORMANCE.md` — generated by
  `tests/harness-conformance.sh --write-doc` at `2026-11-05T04:21:11Z` on `karaHermes-mde-7840hs`,
  commit `10a796f` at run time and committed in `0bbb18d`; no file under `scripts/harness/` or
  `tests/harness-conformance.sh` changed between `10a796f` and `6eea792` (`git log 10a796f..HEAD --
  scripts/harness/ tests/harness-conformance.sh` is empty).
- **Adapter legs re-measured for this module at `6eea792`:** `install-codex.sh --check` → exit 0,
  `CODEX: PASS`; `install-claude-code.sh --check` → exit 0, `CLAUDE-CODE: PASS`;
  `install-hermes.sh --check` → exit 1 on python 3.14.4, and with `HERMES_PYTHON_BIN=python3.12` →
  exit 1 with three named FAILs; `install-opencode.sh --check` → exit 1, `OPENCODE: FAIL (1)`.
- **Absence measured, not assumed:** `ls scripts/harness/` → `install-claude-code.sh
  install-codex.sh install-hermes.sh install-opencode.sh`; no `install-aider.sh`,
  `install-goose.sh`, `install-pi-agent.sh`, `install-deepseek.sh`.
- **Artefact measurement:** `npm view opencode2 version` → `0.0.1-security`; `npm view opencode-ai
  version` → `1.19.5`; `$HOME/.opencode/bin/opencode --version` → `1.18.29`.
- **Red-proof of the battery:** `tests/selftest.sh:2589` (§45, fixture adapters, fixture `$HOME`, no
  credential, no network), with its trace at `tests/selftest.sh:2588`.
- **Adapter proofs:** `tests/harness/codex-install-test.sh` (hermetic refusals + digest floor +
  version-mismatch arm, live turn optional) and `tests/harness/claude-code-install-test.sh` (four
  named proofs, each able to FAIL).
- **Per-adapter measured ladders:** hermes 32 s / 248 MB (`scripts/harness/install-hermes.sh:4`);
  codex 7 s, `codex-cli 0.166.0`, real turn with `model_served` from the rollout
  (`specs/HARNESS.md:29`); claude-code 8 s / 323 MB, `claude --version` → `2.1.318 (Claude Code)`
  (`scripts/harness/install-claude-code.sh:21`).
- Not re-run here, by choice: the smoke legs. They spend real provider tokens, and the committed
  matrix already carries them with their bytes and sha256; the rows above quote it rather than
  paraphrase it.
