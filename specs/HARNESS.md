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
| Fail | Non-zero exit on failure; never a silent success. |
| Idempotent | Re-running install changes nothing. |

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
