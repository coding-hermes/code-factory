# bunker-daemon — agent-host control (contract page)

## Role

Provisions and controls ephemeral agent hosts ("bunker agents"). A code-factory node is one
bunker agent: one agent, one repo, one harness (`scripts/node_freshness.py:4-5`).

**Source availability: the bunkerd daemon source is NOT on this host** — no daemon
repository exists locally (checked `~/bunker*`; none is the daemon's repo). This
page therefore measures the CLIENT side of the contract only, from this repo's client code
and the installed `bunker` CLI's own output. No server-side route, auth, or error vocabulary
is claimed; anything not observable from the client is named as absent below.

## Routes or commands (client surface)

The `bunker` CLI (gRPC exec transport, per the measured deadline behaviour below):

- `bunker exec --server <server> <agent> -- <argv>` — the ONE remote-execution surface this
  repo uses, wrapped as `bash -lc` by `scripts/lib.sh:107-110` (`bunker_exec`). Whole
  verification batteries are one exec round trip (`scripts/node_freshness.py:32, 38`).
- `bunker list` / `bunker info` — server/agent reach checks before provisioning
  (`scripts/bunker-provision.sh:275-283`).
- `bunker destroy <agent> --server <server>` — teardown (`scripts/bunker-provision.sh:718-720`).
- Client config precedence (from `bunker --help`, CLI 0.3.0): `--config` >
  `$BUNKER_HOME/config.yaml` > `$HOME/.bunker/config.yaml`; `--daemon-config` >
  `$BUNKERD_CONFIG` > `/etc/bunkerd/config.yaml`.

## Auth

**Not measurable from this host** — the daemon's auth mechanism is server-side and its
source is absent. What the client side stages inside the agent is identity material by
convention: `$HOME/.node/agent.key` and `$HOME/.node/auth/crier.token`, written names-only
at mode 600 by the provisioning path (`scripts/bunker-crier-connect.sh:13, 63-64`); the
exec transport itself authenticates however the daemon is configured, which this repo
neither states nor assumes.

## Failure codes (client-observed)

- The exec stream ceiling: one `bunker exec` call carries a hard 300 s CLIENT deadline —
  a larger `--timeout` is spent on the remote side and the call dies client-side
  (`deadline_exceeded … Client.Timeout exceeded while awaiting headers`, measured 5m0.106s
  on a 600 s request). `scripts/bunker_exec.py:31` (`BUNKER_EXEC_CEILING_S = 300`),
  `:33-51` (`exceeds_ceiling`, `ceiling_error` — the single refusal sentence), module
  docstring :1-19 with the 2026-11-21 measurement.
- CLI-level refusals this repo checks: server not listed by `bunker list` (FAIL row
  `server`, `scripts/bunker-provision.sh:283`); client binary absent (FAIL row
  `bunker_cli`, :275); `$HOME/.node/crier.json` absent inside the agent (FAIL row
  `identity`, `scripts/bunker-crier-connect.sh:85-87`).

**Named absences (client side):** no daemon health endpoint is probed anywhere in this
repo — reach is proven by `bunker list`/`bunker info` and by exec round trips (the only
`health` curl in the bunker scripts is the CRIER bus health, not the daemon's:
`scripts/bunker-crier-connect.sh:39-43`). No daemon error vocabulary, status codes, or
auth ladder is documented or inventable here.

## Failure/contract source

- Client call sites (this repo): `scripts/lib.sh:107-110`; `scripts/bunker-provision.sh:275-283, 718-720`;
  `scripts/bunker-crier-connect.sh:13, 39-43, 62-87`; `scripts/node_freshness.py:32-38, 86-90`;
  `scripts/node_seed_drift.py` (same one-round-trip battery shape, ceiling-checked through
  `scripts/bunker_exec.py`).
- Client binary: `bunker version` → `bunker 0.3.0`, commit `0422dae7`, built
  `2026-11-11T12:33:23Z`.
- Daemon contract source: **ABSENT on this host** (no bunkerd repository found).

## Code-factory dependents

- `scripts/lib.sh:107-110` — `bunker_exec`, the shared exec wrapper every node script uses.
- `scripts/bunker_exec.py:31-51` — the ceiling module both freshness/seed-drift probes
  import (CF-247: one definition, one sentence).
- `scripts/bunker-provision.sh` — provision/teardown of one project's bunker from config.
- `scripts/bunker-crier-connect.sh` — puts one bunker agent on the crier bus and proves it.
- `scripts/node_freshness.py`, `scripts/node_seed_drift.py` — one-round-trip node batteries.

## Measured against

Client: `bunker` CLI **0.3.0** (commit `0422dae7`, built 2026-11-11T12:33:23Z, from
`bunker version`). Daemon: source not local — nothing claimed beyond client observation.
Measured 2026-11-22.

Handbook mapping: evidence for I.5 (contract register) and I.9 (services described only from
the client side) per `docs/handbook/OUTLINE.md:46,50-52`.
