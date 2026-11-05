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
| Install | `scripts/harness/install-<name>.sh --check` reports absence; `--apply` installs user-space. |
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
| **pi-agent** | binary | not measured |

Hermes certifies only `$HOME/hermes-venv/bin/hermes` at `HERMES_PIN` (default `0.19.0`).
A PATH-provided binary is labelled host-provided and FAILs the binary row, even if its
version matches. `--apply` creates the venv and installs `hermes-agent==$HERMES_PIN`
when the venv binary is absent, regardless of PATH. A venv version mismatch is named
and reinstalls the pin; only a matching venv binary earns "already installed".

**hermes** and **codex** have measured install ladders in this repo (`install-hermes.sh`,
`install-codex.sh`, both proved by a script that can go red). The others ship a documented
`--check` and a method, and are marked `UNVERIFIED` until someone runs them — an unverified
installer is not a supported installer, and the script says so out loud.

## Conformance is measured, not claimed

`tests/harness-conformance.sh` runs three legs per harness — the adapter's own `--check`, a real
smoke turn that must leave a file containing a token the battery chose (bytes re-read on the
control host), and, only with `--install`, the adapter's `--apply` in a throwaway `$HOME` followed
by a post-apply `--check`. It prints `PASS`/`FAIL`/`SKIP` with the measured value and regenerates
`docs/HARNESS-CONFORMANCE.md` with `--write-doc`.

A `SKIP` names the exact credential or binary that is missing, and it is not evidence of support:
this spec's table is a claim about a method, the matrix is a measurement of a host, and only the
matrix may be quoted as "works here". A harness named in the tables above with no adapter file is
a `FAIL`, never a skip. `tests/selftest.sh` §44 keeps the battery itself able to fail.

Codex certifies only `$HOME/.local/codex/<pin>/bin/codex`; the same host-provided-versus-owned
rule as hermes applies, and `--apply` refuses by name on any arch whose artefact digest it has
not measured (the pin covers `x86_64-unknown-linux-musl` only). `tests/harness/codex-install-test.sh`
is its proof: refusals, the digest floor, idempotence, the version-mismatch arm, and — when a
credential exists — one real turn.

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
