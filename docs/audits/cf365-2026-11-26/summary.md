CF-365 — deployed-bus probe: one scheduler dispatch consumed by cf-node --once
Date: 2026-11-26 UTC. Workdir: ~/code-factory (shared checkout, main @ 5ae9e3e4).
Redaction: tailnet address literals and host-home paths replaced (<host>, ~) per CF-378/CF-050;
real values live in the operator's ~/.bunker/config.yaml. The node's own credentials were
staged from the control-host copies (~/crier-fleet/keys/cf-node.key + the fleet bearer) and
never printed.

Outcome: row 19 measured — FAIL by its own rule. Every bus leg it names was observed against
the deployed bus (READY + reply 201 + ack 204, fetch 200 with queue_depth 1 -> 0, verify and
gate PASS), but the harness leg is part of the row's stated cycle and it failed: the child ran
and exited 1 ("No inference provider configured"; the worker's terminal line was
BUS WORKER: FAIL, exit=1). A failed leg therefore grades the row FAIL, not PASS. The envelope (status failed, ok false, in_reply_to
1bf326c88357a8b6632fadfd, host dev) was delivered to the scheduler inbox (201, message
bd3d4fe79f58c59107c657ea) and read back there.

How the node was re-established (the 2026-11-25/26 attempt found none):
1. bunker-las-03 (the roster's server) and bunker-las-02 both refuse spawn with
   slice-limits: containment landing did not converge — memory.swap.max = "max", want "0"
   (verbatim in probe-spawn-raw.out / probe-spawn-las02-raw.out).
2. dedi-2 spawns cleanly: node-create.sh --project code-factory --repo
   https://github.com/coding-hermes/code-factory.git --harness hermes --ttl 2h
   (probe-spawn-dedi2-raw.out: gateway :10800 -> 200, auth gate enforced, clone @ 5ae9e3e).
3. The agent is named cf-node directly (`bunker spawn cf-node`), then
   node-create.sh --agent cf-node stages + provisions into it (probe-stage-cfnode-raw.out).
4. Identity staged on the node: ~/.node/agent.key (0600), ~/.node/auth/crier.token (0600),
   ~/.node/crier.json {agent cf-node, project code-factory, url http://127.0.0.1:8767},
   ~/.node/node.json {project code-factory, repo ~bunker-cf-node/repo}.
   The bus is reached over an ssh reverse tunnel (dedi-2 is not on the tailnet; the node
   cannot reach the crier's tailnet address — measured 000 — and the control host's
   firewall blocks its public :8767/:28767 from non-tailnet sources). The worker's own
   --check proves the deployed registry accepts the node's key: key_registry PASS
   (public 69743c3431d89e10…), signed stats read 200 (probe-cfnode-check.out, READY).
5. Roster re-pointed cf-node -> dedi-2 (fleet-agents-repoint.txt, before copy included).

What the consumption window measured:
- First delivery attempt (roster stale): consumed by the fleet dispatcher in <2s, which
  exec'd the absent agent on bunker-las-03, reported FAILED and acked — verbatim in
  dispatcher-steal.txt. The prior probe's warning, now measured.
- Second delivery with the dispatcher paused for the window: full cycle, verbatim in
  probe-cfnode-once.out. Stats before 0 -> after delivery 1 -> after --once 0.

Side effects disclosed:
- One probe result message sits in the scheduler inbox (bd3d4fe79f58c59107c657ea); nothing
  consumes that inbox on a schedule, it expires on its store TTL.
- The destroyed probe node: `bunker destroy cf-node --server dedi-2` (node-destroy.txt).
- The tunnel process was closed after capture.
