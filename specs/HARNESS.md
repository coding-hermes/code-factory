# SPEC — harness adapters

A **harness** is whatever runs the work inside a node. The factory must not care which.

> **Which harness runs which model, and what it must be given:** `specs/HARNESS-MATRIX.md`.
> That file is the authority for selection (`directive > model family > policy fallback`), the
> `CF_*` variable contract, the invariant that the foreman is always Hermes, and the DuckBrain
> record every harness writes. This file is the per-adapter contract; where they differ, the
> matrix wins for selection and this file wins for the adapter's own obligations.

## The contract (every adapter)

| Obligation | How |
|---|---|
| Install | `scripts/harness/install-<name>.sh --check` reports absence; `--apply` installs user-space and prints the `binary` row it placed, so the node manifest can record where the harness lives (see "A node records the harness it measured"). |
| Version | `--check` prints the binary's ownership and measured version; a version mismatch names both the measured value and the pin and FAILs, not just "ok". |
| Invoke | Accepts a directive (text) and a working directory; runs unattended. |
| Report | Emits the model it actually served (requested vs served), when it has one. |
| Fail | Non-zero exit on failure; never a silent success. Every adapter ends with the verdict line defined in "The verdict line" below, including a ladder that stops early. |
| Idempotent | Re-running install changes nothing. |

<a id="verdict-line"></a>

### The verdict line

Every adapter ends its output with **one** verdict line, and that line is decided by the row counts
it just printed — never by `$FAILED` alone (CF-141):

| Line | When | Exit |
|---|---|---|
| `<LABEL>: FAIL (n)` | at least one `  FAIL` row; `n` is that count | 1 |
| `<LABEL>: UNVERIFIED` | at least one `  WARN` row and no `  FAIL` row | **3** |
| `<LABEL>: PASS` | no `FAIL` and no `WARN` row — every contract row PASSed | 0 |

`<LABEL>` is the harness name in capitals (`HERMES`, `CODEX`, `CLAUDE-CODE`, `OPENCODE`,
`PI-AGENT`, `DEEPSEEK`). `UNVERIFIED` exits **3**, not 0: nothing was certified, and a caller that
reads "exit 0" as support would read an unmeasured ladder as a supported one. It is the same status
`verify-node.sh` uses for an unverified manifest (`VERIFY: UNVERIFIED`), so a node and an adapter
answer "measured?" the same way.

There is one implementation — `verdict()` in `scripts/lib.sh` — and `warn()` counts the rows it
prints, so six adapters cannot drift. A `WARN` row is a measurement of absence (a surface the build
does not advertise, an install this repo does not own), which is why it cannot sit beside `PASS`:
before this rule an adapter whose own banner said `UNVERIFIED adapter` printed `OPENCODE: PASS` and
exited 0 with two `WARN` rows above the verdict. `tests/selftest.sh` §59 keeps the rule falsifiable
(three arms on one stub adapter, plus the real adapter on the row's probe and the pre-fix adapter
`d4f2600` as the red control).

The row-count rule is the `--check` rule, because `--check` is the certification claim a caller acts
on. The modes that DO something (`--apply`, `--turn`, `--app-server`) pass `action` to `verdict()`:
there a `WARN` is advice about a run that already happened (a `$HOME/.local/bin` PATH hint, a
`model_served` the harness did not report), so only `FAIL` rows decide and a measured
install still ends exit 0. Without that split `install-codex.sh --apply` — a harness this repo has
measured — would report `UNVERIFIED` for a successful install merely because it also warned that
`$HOME/.local/bin` is not on `PATH`.

Two lines are deliberately **not** verdicts, because nothing was measured: a usage/contract refusal
exits 2 with a named reason (`CODEX: REFUSED (<leg>)`, `OPENCODE: FAIL (n) — contract refused;
nothing was installed or run`), and claude-code's `--turn` without a credential exits 3 as
`CLAUDE-CODE: SKIP (…)`. A ladder that stops early still reaches the verdict for the rows it did
print: `install-hermes.sh` refusing an out-of-range interpreter prints `FAIL python — …` and then
`HERMES: FAIL (1)`, not a bare exit with no summary.

## Which conditions are notes, and which are WARNs

The verdict rule above says a `WARN` row cannot sit beside `PASS`. That makes the CLASS of each row a
substantive decision, and CF-384 settled it for the two codex rows that had been warning about facts
the adapter does not need — a healthy host therefore could not reach `CODEX: PASS`:

| Row (adapter) | Condition measured | Class | Why |
|---|---|---|---|
| `app_server` (codex) | the `[experimental]` app-server subcommand is **present** | `..` note | crier@6422c851 runs **exec** mode and starts no sidecar — its own doc comment names "two verified surfaces: exec create / exec resume", and `grep -rn app-server` over crier returns nothing. A sidecar existing cannot block any run this repo dispatches, so it is an environment FACT the row records (with its text, and the `--app-server` pointer) and it does not move the verdict. |
| `app_server` (codex) | the subcommand is **absent** | `FAIL` (unchanged) | the mirror case, and strictly stronger than a `WARN`: a consumer that wanted the sidecar could not be served, and the row names that. |
| `auth` (codex) | no `CF_API_KEY_FILE`, but `$HOME/.codex/auth.json` **exists** | `..` note | an ambient host login. A credential exists, a turn can authenticate, and where the host's login came from is not something this adapter certifies — the row is printed so the provenance stays visible, and it is a note so a working host is not reported unproven for it. |
| `auth` (codex) | **neither** a key file nor a host login | `WARN` (unchanged) | a genuine blocker: an unattended turn fails at auth, and "nothing to authenticate with" is exactly the absence this row exists to name. It keeps `CODEX: UNVERIFIED` with exit 3. |
| any other adapter's row | any `WARN` | `WARN` (unchanged) | the rule above applies verbatim: `<LABEL>: UNVERIFIED`, exit 3. |

The question a row answers is **"does the absence of the thing this row reports stop a run of the
surface the adapter is measured on?"** If it does, the row is a `WARN` and the verdict moves; if the
row reports a fact the adapter does not need, it is a note. Classification is a **call-site** decision
per row — `warn()` and `verdict()` in `scripts/lib.sh` are untouched, so a generic `WARN` row still
makes `--check` `UNVERIFIED` with exit 3, and no other adapter's rows changed. Deleting the warning
mechanism would be a different change and is not what this table authorises.

`tests/harness/codex-install-test.sh` keeps the decision falsifiable in both directions, which is why
the pair exists rather than one arm: **B5** runs `--check` on the pinned binary in a home with a host
login and requires `CODEX: PASS` with exit 0, both rows printed as notes and **zero** `WARN` rows;
**B5b** runs the same pinned binary in a home with no credential surface at all and requires the named
`WARN auth` row and `CODEX: UNVERIFIED` with exit 3. B5 alone would pass an adapter that deleted its
warnings; B5b alone would pass the defect the row was raised on.

## Adapters and their measured state

| Harness | Method | State (2026-10-29) |
|---|---|---|
| **hermes** | Python `>=3.11,<3.14`; `python3 -m venv` + `pip install hermes-agent==0.19.0`; `hermes serve --host 0.0.0.0 --port P --skip-build` | **MEASURED working**: 32 s install, `/api/status` 200 over tailnet, 133 JSON-RPC methods, `session.create` + `prompt.submit`. Needs a provider key in `~/.hermes/.env`. |
| **opencode** | standalone binary; `opencode` CLI or server mode | not measured here — the fleet's `examples/agent-ecosystem` runs it in a container |
| **claude-code** | `npm i -g @anthropic-ai/claude-code` (needs node) | not measured here; node absent in base image |
| **codex** | release tarball `codex-x86_64-unknown-linux-musl.tar.gz` from `rust-v0.166.0`, sha256-pinned, installed under `$HOME/.local/codex/<pin>`; **exec** mode (`codex exec --json -s <mode> -m <model> -- <text>`, `exec resume <id>`) | **MEASURED** (CF-227, 2026-11-04, `scripts/harness/install-codex.sh`): 7 s install, version read back `codex-cli 0.166.0`, idempotent second `--apply`, and one real turn wrote a fixed token with `model_served` read from codex's own rollout record. The **app-server** sidecar is `[experimental]` and **nothing in crier uses it** — `codex.go` names "two verified surfaces: exec create / exec resume", and `grep -rn app-server` over crier is empty; `--app-server` probes it anyway (an `initialize` over stdio answers with a `userAgent`). |
| **aider** | `pip install aider-chat` (venv) | not measured |
| **goose** | binary | not measured |
| **pi-agent** | `scripts/harness/install-pi-agent.sh`; binary `pi`, non-interactive surface `pi -p --no-session "<prompt>"` | not measured as an install (no pin, no artefact digest); the adapter ships a documented `--check`/`--contract` and refuses `--apply` by name |
| **deepseek** | `scripts/harness/install-deepseek.sh`; the conformance row probes the binary `deepseek` (the matrix names DeepSeek's own harness at npm `@deepseek-ai/dsh`, CLI `dsh`, absent from both trees) | not measured (no binary, no ladder); the adapter ships a documented `--check`/`--contract` and refuses `--apply` by name |

Hermes certifies only `$HOME/hermes-venv/bin/hermes` at `HERMES_PIN` (default `0.19.0`).
A PATH-provided binary is labelled host-provided and FAILs the binary row, even if its
version matches. `--apply` creates the venv and installs `hermes-agent==$HERMES_PIN`
when the venv binary is absent, regardless of PATH. A venv version mismatch is named
and reinstalls the pin; only a matching venv binary earns "already installed".

**hermes** and **codex** have measured install ladders in this repo (`install-hermes.sh`,
`install-codex.sh`, both proved by a script that can go red). `opencode`, `claude-code`,
`deepseek` and `pi-agent` ship a documented `--check`/`--contract` and a method, and are marked
`UNVERIFIED` until someone runs them; `aider` and `goose` ship no adapter file at all. An
unverified installer is not a supported installer, and the script says so out loud.

## Conformance is measured, not claimed

`tests/harness-conformance.sh` runs three legs per harness — the adapter's own `--check`, a real
smoke turn that must leave a file containing a token the battery chose (bytes re-read on the
control host), and, only with `--install`, the adapter's `--apply` in a throwaway `$HOME` followed
by a post-apply `--check`. It prints `PASS`/`FAIL`/`SKIP` with the measured value and regenerates
`docs/HARNESS-CONFORMANCE.md` with `--write-doc`.

The smoke leg resolves the binary from the adapter's own measurement (the `PASS binary` row that
`--check` printed), and falls back to `PATH` only when the adapter names no path, or names one that
is not executable. A harness binary is not required to be on `PATH`: an installer is free to put it
under a `$HOME` prefix (claude-code: `~/.local/harness/npm/bin`), and such a binary is owned and
measured even though `command -v` cannot see it. A battery that re-resolved it with `command -v`
alone reported `SKIP ... absent from PATH` for a harness this repo had just installed, which is a
false negative, not a measurement. The row quotes the path it resolved and the rule it used, and the
turn is launched with that path's directory first on `PATH`, so a binary that is resolved but never
invoked cannot look green; a genuinely absent binary is still a `SKIP` that names the absence.

A `SKIP` names the exact credential or binary that is missing, and it is not evidence of support:
this spec's table is a claim about a method, the matrix is a measurement of a host, and only the
matrix may be quoted as "works here". A harness named in the tables above with no adapter file is
a `FAIL`, never a skip. `tests/selftest.sh` §44 keeps the battery itself able to fail.

Codex certifies only `$HOME/.local/codex/<pin>/bin/codex`; the same host-provided-versus-owned
rule as hermes applies, and `--apply` refuses by name on any arch whose artefact digest it has
not measured (the pin covers `x86_64-unknown-linux-musl` only). `tests/harness/codex-install-test.sh`
is its proof: refusals, the digest floor, idempotence, the version-mismatch arm, and — when a
credential exists — one real turn.

Opencode's adapter measures three things it used to guess at, and `--apply` still refuses by name
(no ladder is recorded here). It resolves the binary from the `$HOME` prefix its own installer uses
(`~/.opencode/bin/opencode`) before `PATH`, so an owned binary that `command -v` cannot see is
named and measured rather than reported absent; it prints `version` only as `PASS` when the probe
returned a value, and warns by name otherwise, because a `PASS` with no measured value is a lie the
battery rewrites into a `FAIL`; and it prints a `generation` row (`v1`/`v2` from the measured
major), because opencode v1 and v2 share a binary name and the conformance table's `opencode-v2`
row must never be certified by a v1 binary — the battery quotes that row when the generations
disagree instead of asserting the adapter has no gate. Its `non_interactive` row reads `--help`
from stdout **and** stderr: the real binary writes help to stderr only (measured on 1.18.29: 4285 B
on stderr, 0 B on stdout), so a stdout-only probe reported "could not confirm" for a surface the
same bytes advertised. `tests/harness/opencode-install-test.sh` is the proof, offline: the
refusals, the absent-binary failure path, a stub whose help goes to stderr only, the v1/v2
generation rows, an unmeasurable version, a binary advertising no surface, the `--apply` refusal,
and the owned-prefix resolution — with the pre-fix adapter (`45bd4bd`) run against the same stub as
the red control that turns the `non_interactive` arm green only because it changed.

## A node records the harness it measured

The battery above certifies a HOST. The two measurements below are the node's, and both were
missing: `~/.node/node.json` carried `harness{name, port}` only, and `verify-node.sh` never opened
it — so a node provisioned with one harness and running another, or with the harness binary gone,
still printed `VERIFY: PASS`.

**1. The manifest records the build, not the pin.** Layer 20 of `project-node.sh` captures the
adapter's output; `harness_measurement` reads the adapter's own `PASS version` and `PASS binary`
rows back out of it (one parser — a second `--version` parse would be a second answer to "which
build is on this node"), and layer 90 writes them into `node.json`:

```json
"harness": {"name": "codex", "port": 10800,
            "adapter": "scripts/harness/install-codex.sh",
            "version": "0.166.0", "version_row": "0.166.0 (pin 0.166.0)",
            "version_source": "the adapter's own `PASS version` row in --apply",
            "binary": "/home/<uid>/.local/codex/0.166.0/bin/codex"}
```

`version` is the value the adapter MEASURED, never the pin copied from a default. When the adapter
printed no version row the field is `null` and carries `version_reason`: a null without a reason is
junk, and a version nobody read is worse than a named absence. Because the manifest is built from
that log, every adapter's `--apply` prints the `binary` row it placed — a `$HOME`-owned pin
(codex) or venv binary (hermes) is normally not on `PATH` at all, and a verifier that resolved the
NAME would measure whatever else the host happens to have.

**2. `verify-node.sh` re-measures it — leg 7, `harness_identity`** (two `bunker exec` round trips:
the manifest, then the binary it names, taken as a positional argument so a value from the node
cannot be re-parsed as shell):

| Manifest says | Node answers | Verdict |
|---|---|---|
| `codex 0.166.0` at `<path>` | `<path> --version` contains `0.166.0` | `PASS harness_identity — codex 0.166.0 (manifest) measured at <path> — codex-cli 0.166.0` |
| `codex 0.166.0` at `<path>` | a different version | `FAIL` naming both values; `VERIFY: FAIL` |
| `codex …` at `<path>` | nothing executable there | `FAIL` — the harness the node claims is not on the node |
| `codex` with `version: null` and a reason | — | `WARN` + `VERIFY: UNVERIFIED` (exit 3): an unknown build is not a measured one |
| no `node.json` (unprovisioned) | — | a `..` note naming what was NOT checked — not a `PASS` row |

The last row is why the leg can be added without lying about fixtures: absence is reported as
absence, and `VERIFY: PASS` is unreachable for a node whose manifest disagrees with its binary.

**The measured / unverified boundary.** `tests/harness-node-e2e.sh` drives this slice offline
end to end: the real adapters, the real `project-node.sh --apply` (unscoped, so it writes
`node.json`), the real `verify-node.sh`, one stub transport and one stub HTTP probe. Its arms are
the adapter `--check`/`--help` surface, the three unmeasured ladders refusing `--apply` by name and
installing nothing, a codex node whose manifest records name+version+binary measured by the
adapter, `VERIFY: PASS` with `harness_identity`, four red arms (tampered version, absent binary,
null version → `UNVERIFIED`, absent manifest → note), and the manifest's own binary answering a
directive non-interactively with JSONL events and the directive's token in an artifact.

What that does **not** prove, and this file does not claim: the fixture `codex` is a script, not
the pinned musl artefact, and no model is called. It proves the WIRING — adapter measurement →
manifest → directive → machine-readable events → verifier — not the real turn. The real turn for a
foreign harness is the conformance battery's smoke leg (a token the battery chose, bytes re-read on
the control host) and the CF-227 codex measurement in the table above. Running this slice against
a real node (`project-node.sh --apply --harness codex`, then `verify-node.sh --agent <id>`) is
**UNVERIFIED** at this commit: the host that wrote it had no reachable bunker server
(`bunker: server "bunker-las-03" is offline`). It is a named open leg, not a completed one.

## Why hermes first

- It needs no node/npm (the backend runs `--skip-build`), and node is absent from the base image.
- It already exposes a gateway, so the same code path serves "local CLI" and "remote command".
- Its failure mode is explicit (`No inference provider configured`), not a half-run.

## What a foreign harness must gain to be first-class

1. A way to accept a directive without a human TTY (no interactive prompts).
2. A machine-readable completion (exit code + files, or a JSON result) — not a pretty-printed
   transcript.
3. A deterministic workspace: it must not roam outside the repo it was given.
4. A version probe that does not require a login.

Until an adapter has those, the node should not be created with it.
