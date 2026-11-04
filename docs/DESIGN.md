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

This section is the design, and the table states what this repository actually ships for each step.
`specs/NODE.md` is the contract a node is graded against; where the two disagree the spec wins
(`AGENTS.md` rule 1). A step marked **not shipped** is design intent owned by the board row named
beside it, and it must not be read as behaviour: nothing below is measured by a shipped script
unless the cell says so.

| # | Step | State in this tree |
|---|---|---|
| 1 | Foreman writes a brief; the scheduler decides the lane's turn. | **Not this repo.** The lanes live in the scheduler; `AGENTS.md` says this repo consumes the scheduler, crier and the task-router. |
| 2 | Scheduler renders a directive (`payload.text`) and dispatches through crier to the node's inbox. If no target is declared for the lane, nothing changes — the local path runs. | **Not this repo.** No script under `scripts/` reads, writes or waits on a crier inbox: `grep -rniE 'envelope\|ack\|inbox\|lease\|redeliver' scripts/ --include=*.sh --include=*.py` returns four hits and none is a consumer (the word boundary is `ack`, not any `ack` substring — without `\b` the same pattern also matches "back"/"backend"/"fall back" and returns 12). Arming the dispatch leg is CF-001 (`in_progress`); the target-removed fallback is CF-112. |
| 3 | The node's bus worker pulls the message (signed), verifies the brief digest, hands the directive to the harness (Hermes gateway, or a foreign CLI). | **Not shipped.** No bus worker exists. Layer 30 stats a file and starts nothing: `scripts/project-node.sh:245-249` tests `-f $HOME/.node/crier.json` and its mode `600`, and `specs/NODE.md` § Layers ("A node-side bus worker") states the layer opens no socket. Whether a worker runs on a node is **not measured** by this repo; CF-068 owns the file-existence weakness. |
| 4 | The harness works in the repo, commits to a branch, runs the gate. | **Partly shipped.** Layer 20 starts the adapter (`scripts/project-node.sh:228`), layer 40 clones at the pinned ref (`:265`) and runs no build, layer 90 writes the manifest (`:294-312`). No shipped script commits for the harness or runs a gate on a node: that is the harness's own run, and it is **not measured** here. |
| 5 | The node returns a result envelope: host identity, artifact digests, gate exit, branch, commit. It **acks** the message only after the result is delivered. | **Not shipped.** `specs/ENVELOPE.md` defines the shape; nothing in this tree produces, consumes or acks one, and there is no reader to ack to. CF-004 owns the round trip. |
| 6 | The control host pulls the artifacts, recomputes the digests, and only then records the run. A mismatch is a failed run, not a warning. | **Not shipped as a gate.** `scripts/verify-node.sh:60-70` compares one artifact's sha256 when `--artifact` is supplied — optional, operator-invoked, recording nothing and consumed by no automation. No run recorder exists. CF-107 owns it. |

So two legs are demonstrated nowhere in this repository: a node-side bus worker (step 3) and a
control-host digest recomputation that decides a run (step 6). `docs/ACCEPTANCE-PLAN.md` records
directives arriving at a node and executing there (its CF-137 / CF-139 bullet) — that is evidence
about the scheduler → crier → node transport, not about either leg above.

## 4. What runs where

| Concern | Owner | Not this |
|---|---|---|
| Which project works next | scheduler | the node |
| Which model answers | task-router | crier ("crier must not embed vendor harness logic") |
| Which harness executes | node manifest + scheduler target | crier |
| Whether the work is correct | foreman, verified on the control host | the node's own claim |
| Transport | crier | the scheduler's business logic |

## 5. Failure model

Each bullet separates the design intent from what this tree does today; no bullet below is
measured by a shipped script unless it says so.

- **Node unreachable** → design: the message stays in the inbox and the lane is degraded after N
  misses. No inbox is shipped here (§3 step 2) and the degradation is the scheduler's; neither half
  is measured by this repository.
- **Node dies mid-job** → design: the lease expires and the message is redelivered; jobs must be
  idempotent (a fresh branch per attempt, or a worktree per dispatch id). No lease or redelivery
  consumer exists under `scripts/`; idempotence is required of the harness by `AGENTS.md` rule 5 and
  is not enforced by anything here.
- **Result digest mismatch** → design: the run FAILS and the node is quarantined until `--check`
  passes. Not shipped: `scripts/verify-node.sh:60-70` prints a named `artifact_digest` row and a
  non-zero exit when `--artifact` is supplied, records no run, and no automation reads its status
  (CF-107, CF-004). No quarantine path exists — **not measured**.
- **Bus guard blocks the envelope** → crier's guard rejects reserved keys, so the envelope is at
  fault, not the guard; see `specs/ENVELOPE.md` for the reserved key names (CF-131 tracks its false
  positive on a legitimate completion reply).
- **Disk exhaustion** → **shipped**: layer 00 measures free space against the configured floor and,
  under `--apply`, reaps build caches, job dirs and stale clones before refusing
  (`scripts/project-node.sh:144-176`, `specs/NODE.md` § Disk floor).

## 6. What this design deliberately does not do

- It does not put vendor harness logic in crier.
- It does not let a node grade its own homework.
- It does not hold a request open for the length of a job (crier's delivery budget is 30 s;
  work takes minutes to hours).
- It does not require root anywhere.
