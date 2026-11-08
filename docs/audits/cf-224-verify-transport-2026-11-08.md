# CF-224 — evidence: the transport `verify-node.sh` uses to reach a node's gateway

**Row:** CF-224 — *verify-node assumes the node's address is reachable from the control host — true on
a LAN node, false on a bunker, so a green node reports itself unverified.*
**Spec:** `F2 PROVISIONING AND CERTIFICATION` / `M1 PROVISIONING S5` (`docs/handbook/OUTLINE.md`).
**Base revision measured:** `bf16c05` (the tree this row was dispatched against).
**Measured:** 2026-11-08, offline — one fixture node home, one stub transport (`bunker`), one stub
HTTP probe (`curl`). **No bunker, no network, no live node was used**, and nothing below is a claim
about a real node.

## What was wrong (measured, not asserted)

Two behaviours on the base revision `bf16c05:scripts/verify-node.sh`:

1. The gateway leg read `hostname -I` off the node and probed that address **from the control host**
   (`bf16c05:scripts/verify-node.sh:81-86`). There was no way to say how the request reaches the
   node, so on a bunker — where the agent is in its own network namespace and has no LAN address —
   a green node printed `VERIFY: UNVERIFIED`.
2. `--transport` did not exist: the base verifier exits 2 with `unknown arg: --transport`.

The inverse defect is the one that matters more: a node whose only address is loopback **passed**,
because the probe answered on the control host. Nothing in the output named a transport, so nothing
exposed it.

## The contract (see `specs/NODE.md` → "Transport")

| `--transport` | Endpoint (`--transport-address`) | Where the probe runs | Can it produce `VERIFY: PASS`? |
|---|---|---|---|
| `node-address` (default) | none — the node's `hostname -I` address | control host | yes, unless the address is loopback |
| `published-port` | `HOST:PORT` on the bunker host | control host | yes |
| `tunnel` | `HOST:PORT` of an SSH forward on the control host | control host | yes |
| `bunker-exec` | none | inside the node | **never** (counted FAIL) |

`NODE_TRANSPORT` / `NODE_TRANSPORT_ADDRESS` are the environment form (the flags win), so a spawn path
that runs the verifier as a child can declare the same pair without new argv plumbing.

## Command and transcript — base revision vs this tree

Driver (throwaway, not committed): one fixture node home with an applied seed record and a clean
checkout level with its origin, `bunker` stubbed to answer `hostname -I` with `FIXTURE_IP` (or run the
body locally), `curl` stubbed to answer the control-host probe from `CURL_CODE`/`CURL_STATS` and the
in-node loopback probe from `CURL_IN`/`CURL_IN_STATS`. Addresses are TEST-NET (`192.0.2.10`,
`203.0.113.9`); nothing leaves the host.

```
=== ARM A: base revision + --transport ===
rc=2
verify-node: unknown arg: --transport

=== ARM B: base revision, node reports 127.0.0.1, control-host probe 200 — the wrong PASS ===
rc=0
  PASS  agent_alive — ALIVE <fixture>
  PASS  node_ip — 127.0.0.1
  PASS  gateway_reachable — http://127.0.0.1:10800/api/status -> 200
  PASS  auth_gate — auth_required:true (a public bind must not be open)
  PASS  unauth_refused — /api/system/stats -> 401
  PASS  checkout_freshness — branch=main head=… origin_main=… ancestor=true behind=0
  PASS  seed_drift — …: 1 seeded file present and matching
  ..    harness_identity — no ~/.node/node.json on the node, …
VERIFY: PASS

=== ARM C: this tree, same loopback fixture ===
rc=3
  PASS  agent_alive — ALIVE <fixture>
  WARN  node_ip — 127.0.0.1 is a loopback address — the node reports no address this host can use (a bunker node has no LAN address by default)
  WARN  transport — node-address 127.0.0.1:10800 — refused: a probe to a loopback address measures this host, not the node; pass --transport published-port or --transport tunnel
  WARN  gateway_reachable — unverified — no LAN address for cf-fixture (hostname -I -> 127.0.0.1: a request from this host would probe THIS host's loopback, not the node) (transport: node-address)
  WARN  unauth_refused — unverified — no LAN address for cf-fixture (…) (transport: node-address)
VERIFY: UNVERIFIED — gateway_reachable: no LAN address for cf-fixture (…); unauth_refused: no LAN address for cf-fixture (…)

=== ARM D: this tree, node-address on a routable address (LAN behaviour preserved) ===
rc=0
  PASS  transport — node-address 192.0.2.10:10800 — the node's own address, probed from this host (the LAN case; a bunker node has no LAN address by default)
  PASS  gateway_reachable — http://192.0.2.10:10800/api/status -> 200 (transport: node-address)
VERIFY: PASS

=== ARM E: this tree, --transport published-port --transport-address 203.0.113.9:10800 ===
rc=0
  PASS  transport — published-port 203.0.113.9:10800 — a port published on the bunker host, probed from this host (never inside the node)
  PASS  gateway_reachable — http://203.0.113.9:10800/api/status -> 200 (transport: published-port)
VERIFY: PASS

=== ARM F: this tree, published-port that answers nothing (the transport is NAMED, no 000) ===
rc=3
  WARN  gateway_reachable — no published port for cf-fixture:10800 (nothing answered at 203.0.113.9:10800) — the gateway answers 200 INSIDE the node, so this is unverified, not failed (transport: published-port)
VERIFY: UNVERIFIED — gateway_reachable: no published port for cf-fixture:10800 (nothing answered at 203.0.113.9:10800)

=== ARM G: this tree, --transport tunnel --transport-address 127.0.0.1:18080 ===
rc=0
  PASS  transport — tunnel 127.0.0.1:18080 — an SSH forward opened on this host; the probe leaves this host and re-enters the node
  PASS  gateway_reachable — http://127.0.0.1:18080/api/status -> 200 (transport: tunnel)
VERIFY: PASS

=== ARM H: this tree, --transport bunker-exec with the gateway answering 200 inside ===
rc=1
  FAIL  transport — transport bunker-exec runs the probe INSIDE the node (127.0.0.1:10800): it proves the harness answers its own loopback, not that anything outside the node can reach it
  FAIL  gateway_reachable — loopback inside the node -> 200 (transport: bunker-exec) — a request that did not leave the node proves nothing about reachability, so this is a FAIL, not a PASS
  ..    auth_gate and unauth_refused are not attempted: no request from this host reaches the node
VERIFY: FAIL (2)

=== ARM I: flag refusals ===
rc=2 verify-node: --transport must be node-address, published-port, tunnel or bunker-exec (got: bogus)
rc=2 verify-node: --transport published-port needs --transport-address HOST:PORT — the endpoint on THIS host that forwards to the node (nothing is invented)
rc=2 verify-node: --transport-address is used by --transport published-port|tunnel only (got --transport node-address)
```

## Committed, re-runnable arms

The same fixture lives in the suite, so these are not a one-off transcript:

```
$ bash tests/selftest.sh          # §62, terminal line
62. verify-node names its transport, and a probe that never leaves the node is a FAIL (CF-224)
  PASS  pre-fix bf16c05 has no --transport: exit 2, 'unknown arg: --transport' (CF-224 premise)
  PASS  pre-fix bf16c05 certifies a loopback-only node: VERIFY: PASS, exit 0, no transport row (the fixture detects CF-224)
  PASS  a loopback-only node -> exit 3, named transport refusal, VERIFY: UNVERIFIED (never a PASS row)
  PASS  a reachable node-address -> VERIFY: PASS, exit 0, the row names node-address and the measured 200
  PASS  --transport published-port -> VERIFY: PASS, exit 0, the gateway row names the transport and the code
  PASS  no published port -> exit 3, 'no published port for cf-fixture:10800' in the row, and no 000 anywhere in the output
  PASS  --transport tunnel 127.0.0.1:18080 -> VERIFY: PASS, exit 0 (a declared forward, not a node-internal loopback)
  PASS  --transport bunker-exec -> exit 1, named loopback FAIL, VERIFY: FAIL (2) (never PASS, never UNVERIFIED)
  PASS  a bad transport, a missing address and an address with no transport are each exit 2 with a named refusal
```

Measured on this tree (2026-11-08):

- `bash -n scripts/verify-node.sh` → exit 0.
- `bash tests/selftest.sh` → `SELFTEST: PASS` (460 `PASS` rows, 61 intentional fixture `FAIL` rows,
  exit 0).
- `python3 tests/test_node_provisioning.py` → `Ran 23 tests … OK`, exit 0.
- `bash docs/audits/cf198-section-mapping.sh` → `arms_plan=65 arms_tree=65`, `RESULT: OK`.
- `bash docs/audits/cf099-prd-drift-probe.sh --sections-only` → `plan_sections=62
  selftest_sections=62`.

## Not verified here

- **No live bunker node, no published port, no tunnel was opened.** Every arm above is a fixture. The
  claim this evidence supports is narrow: the verifier *can* be told which path the request takes, it
  *names* that path in its rows, it *refuses* a loopback-only node, and it *fails* a probe that never
  left the node. Whether a real `bunker` port publish or a real `ssh -L` forward carries the probe to
  a real gateway is a live obligation nobody has run.
- The transport proves the request came from outside the node. It does **not** prove the declared
  port/tunnel is that node's gateway rather than another listener, and it is not the round trip whose
  artifact digest is recomputed on the control host (CF-004).
- `scripts/node-create.sh` forwards the pair only through the exported environment
  (`NODE_TRANSPORT` / `NODE_TRANSPORT_ADDRESS`); it has no flags of its own for it.

ch:trace row=CF-224 spec=F2/M1.S5 wave=none:serial test=tests/selftest.sh::section-62 doc=docs/OPERATIONS.md,specs/NODE.md prompt=~/.hermes/cache/scratch/code-factory-20261108-133437/brief-CF-224.txt evidence=docs/audits/cf-224-verify-transport-2026-11-08.md witness=none:offline-fixture verdict=none:foreman-runs-judge commit=none:self-referential-hash memory=none:foreman-writes-receipt
