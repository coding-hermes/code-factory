# SPEC — harness adapters

A harness executes work inside a node. The intended interface is install/check,
measured version, unattended directive+cwd invocation, requested/served model
reporting, explicit nonzero failure and idempotent install. The tracked adapters
are installation/check probes, not implementations of dispatch invocation or
result reporting. See NODE.md and ENVELOPE.md for that boundary.

## Adapters and their measured state

| Harness | Historical method / current state |
|---|---|
| hermes | Historical record: python venv + pip `hermes-agent==0.19.0`, 32 s install, 248 MB venv, `serve --skip-build`, `/api/status` 200 and JSON-RPC probes on an earlier test node. Not reproduced by CF-005 rework; not current inference acceptance. Adapter check/apply now fails `inference_integration` before installation, config/key reads or gateway startup. |
| opencode | Standalone CLI/server method documented; apply refuses as unverified. |
| claude-code | npm method documented; apply refuses as unverified. |
| codex / aider / goose / pi-agent | Planned methods only; no tracked install adapter. |

## Host-only inference custody

Provider keys stay on the control host. No node-side provider key file is required,
read, copied or supported by this provisioning path. CF-002 owns the host inference
proxy and node-scoped service identity. That integration and gateway configuration
are UNIMPLEMENTED / BLOCKED here; do not interpret a node-local provider key as a
workaround. The fail-closed Hermes adapter is deliberate, not a successful install.

The earlier measured ladder is retained as historical evidence only. It is not a
claim that a safe provider path or authenticated gateway is currently deployed.
A future adapter must validate effective auth configuration, verify startup and
inference through the authorized host service, and expose requested/served identity
before node acceptance. No proxy architecture is implemented by CF-005.

## Local fixtures

Tests substitute an executable adapter reporting `PASS  version` solely to exercise
manifest and provisioning control flow. They cannot certify Hermes, Crier, Bunker,
gateway auth, provider routing or a live inference/artifact round trip.
