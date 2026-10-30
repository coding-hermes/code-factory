# DESIGN — the factory

## 1. Shape

```
                    control host (this machine)
   ┌──────────────────────────────────────────────────────────┐
   │  Hermes foreman  ── designs work, verifies results       │
   │        │                                                 │
   │  task-router     ── ranks model + provider per lane      │
   │        │                                                 │
   │  scheduler       ── decides whose turn, records the tick │
   │        │                                                 │
   │  crier           ── carries the command (durable inbox)  │
   └────────┼─────────────────────────────────────────────────┘
            │  tailnet
   ┌────────┴──────────┐   ┌──────────────────┐   ┌──────────────────┐
   │ node: crier       │   │ node: scheduler  │   │ node: task-router│
   │ repo + harness    │   │ repo + harness   │   │ repo + harness   │
   │ gateway :10800    │   │ gateway :10801   │   │ gateway :10802   │
   └───────────────────┘   └──────────────────┘   └──────────────────┘
```

**Not** a dispatcher of sessions. A node is a place where a repo lives and a harness runs;
the command arrives as a message and the answer comes back as a message.

## 2. Why one node per project

- A node can be destroyed without touching another project's state.
- The repo cache, module cache and build cache belong to one project, so disk pressure is
  attributable.
- A node's failure is local: the scheduler marks one lane degraded, not the fleet.

## 3. The path of one unit of work

1. Foreman writes a brief; the scheduler decides the lane's turn.
2. Scheduler renders a directive (`payload.text`) and dispatches through crier to the node's
   inbox. If no target is declared for the lane, nothing changes — the local path runs.
3. The node's bus worker pulls the message (signed), verifies the brief digest, hands the
   directive to the harness (Hermes gateway, or a foreign CLI).
4. The harness works in the repo, commits to a branch, runs the gate.
5. The node returns a result envelope: host identity, artifact digests, gate exit, branch,
   commit. It **acks** the message only after the result is delivered.
6. The control host pulls the artifacts, recomputes the digests, and only then records the run.
   A mismatch is a failed run, not a warning.

## 4. What runs where

| Concern | Owner | Not this |
|---|---|---|
| Which project works next | scheduler | the node |
| Which model answers | task-router | crier ("crier must not embed vendor harness logic") |
| Which harness executes | node manifest + scheduler target | crier |
| Whether the work is correct | foreman, verified on the control host | the node's own claim |
| Transport | crier | the scheduler's business logic |

## 5. Failure model

- **Node unreachable** → message stays in the inbox; the lane is degraded after N misses.
- **Node dies mid-job** → the lease expires and the message is redelivered; jobs must be
  idempotent (a fresh branch per attempt, or a worktree per dispatch id).
- **Result digest mismatch** → run FAILS; the node is quarantined until `--check` passes.
- **Bus guard blocks the envelope** → the envelope is at fault, not the guard; see
  `specs/ENVELOPE.md` for the reserved key names.
- **Disk exhaustion** → the node refuses new work at the floor rather than filling the host.

## 6. What this design deliberately does not do

- It does not put vendor harness logic in crier.
- It does not let a node grade its own homework.
- It does not hold a request open for the length of a job (crier's delivery budget is 30 s;
  work takes minutes to hours).
- It does not require root anywhere.

## 7. Executable repository contract

The checked-in implementation has three deliberately separate surfaces:

| Surface | Script | Contract |
|---|---|---|
| Node-side layers | `scripts/project-node.sh --check|--apply` | Measures preflight, base, harness, bus identity, and repo layers. `--check` can fail and never writes a manifest. `--apply` writes `$HOME/.node/node.json` only after all required layers pass. |
| Control-host creation | `scripts/node-create.sh --project P --repo URL --harness H` | Reuses or spawns an agent, stages the selected adapter, passes the triple plus ref/id into the node-side script, stops on staging/provision failure, and invokes verification with the manifest artifact. |
| Control-host verification | `scripts/verify-node.sh --agent ID --artifact PATH` | Requires agent reachability, HTTP 200, an explicit `auth_required:true` status, rejected unauthenticated stats, and a recomputed control-host digest equal to the node-side digest. |

The node manifest mirrors `specs/NODE.md`: node id, project, repo origin/ref/path, harness name,
measured adapter version/port, bus agent id/base, creator, and creation time. A second apply keeps
the existing manifest bytes unchanged. The envelope fields and reserved names are defined only by
`specs/ENVELOPE.md`; harness adapter behavior is defined only by `specs/HARNESS.md`.

The repository self-test uses hermetic command fixtures to exercise both green and red arms of the
node creator and verifier. Those fixtures prove control flow and failure semantics only. They do
not impersonate a live bunker, crier, gateway, credential, scheduler tick, or round trip.

## 8. Evidence boundary

Local evidence is limited to shell parsing, source-contract assertions, hermetic node-check failure
fixtures, and fake-command tests for creator/verifier failure handling. A configured bunker server,
crier identity/worker, inference credential, reachable gateway, and production artifact round trip
are unavailable in this worktree. Therefore node creation and end-to-end verification remain
**NOT VERIFIED / BLOCKED** until an operator runs the documented commands on an authorized node and
recomputes the artifact digest from transferred bytes. A fake fixture must never be reported as
live acceptance.
