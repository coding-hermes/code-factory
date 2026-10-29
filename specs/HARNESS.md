# SPEC — harness adapters

A **harness** is whatever runs the work inside a node. The factory must not care which.

## The contract (every adapter)

| Obligation | How |
|---|---|
| Install | `scripts/harness/install-<name>.sh --check` reports absence; `--apply` installs user-space. |
| Version | `--check` prints the resolved binary and version, not just "ok". |
| Invoke | Accepts a directive (text) and a working directory; runs unattended. |
| Report | Emits the model it actually served (requested vs served), when it has one. |
| Fail | Non-zero exit on failure; never a silent success. |
| Idempotent | Re-running install changes nothing. |

## Adapters and their measured state

| Harness | Method | State (2026-10-29) |
|---|---|---|
| **hermes** | `python3 -m venv` + `pip install hermes-agent==0.19.0`; `hermes serve --host 0.0.0.0 --port P --skip-build` | **MEASURED working**: 32 s install, `/api/status` 200 over tailnet, 133 JSON-RPC methods, `session.create` + `prompt.submit`. Needs a provider key in `~/.hermes/.env`. |
| **opencode** | standalone binary; `opencode` CLI or server mode | not measured here — the fleet's `examples/agent-ecosystem` runs it in a container |
| **claude-code** | `npm i -g @anthropic-ai/claude-code` (needs node) | not measured here; node absent in base image |
| **codex** | binary; app-server over stdio | not measured here; the scheduler's connector expects an app-server sidecar |
| **aider** | `pip install aider-chat` (venv) | not measured |
| **goose** | binary | not measured |
| **pi-agent** | binary | not measured |

Only **hermes** has a measured install ladder in this repo. The others ship a documented
`--check` and a method, and are marked `UNVERIFIED` until someone runs them — an unverified
installer is not a supported installer, and the script says so out loud.

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
