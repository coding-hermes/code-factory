# Part 0 — Overview

*Read this page before any chapter. It is the only page that presents the whole
system at once; everything after it is detail.*

## The governing product definition

A person tells their agent what project or work they want. The agent turns that
intent into a Boardctl-backed plan — a project decomposed into initiatives and
board tasks, each with acceptance criteria and dependencies another reader can
re-run. The Code Factory builds the requested project end to end and produces an
integrated, usable result demonstrated against the project's acceptance
criteria. That is the product. Every component, contract, setting and flow in
this book exists in service of it.

The Factory's foundation is a deterministic infrastructure-as-code management
layer. It holds the declared desired state of the Factory's own infrastructure,
observes actual state, maps and manages the settings of its participating
systems, and continuously reconciles drift and failures so the project execution
environment remains available and correct. This management layer is a
foundational component of the product — not an optional integration and not one
more flow among the sixteen of Part II. The division of labor is absolute: LLM
foremen and workers plan and implement project work; the infrastructure
convergence mechanism is deterministic code. No infrastructure maintenance step
depends on a model improvising the manual sequence of many tools.

Two control loops run continuously, and the book is organized around them:

- **The project delivery loop** — conversational intent → project/initiative
  plan and Boardctl tasks → ready deployment → scheduled Bunker foreman rounds →
  compatible worker waves within a total-worker budget → independent
  verification, integration and publication → task/wave/round memory and
  evidence → accepted project outcome.
- **The infrastructure control loop** — versioned desired configuration →
  authenticated API or declared-file update → validation and authorization →
  deterministic diff/plan → supported provisioning/configuration adapters →
  effective-state readback → continuous monitoring and reconciliation, including
  repair/replacement and Crier/scheduler binding updates.

The first loop is what the user experiences; the second is what keeps the first
possible. The managed scope of the infrastructure loop covers the infrastructure
and configuration itself, secrets and access, network and deployment profiles,
hosting and runtime lifecycle, service and application readiness, board and
local/shared memory integration, capacity, routing and recovery. Foremen and
workers perform project reasoning and implementation **on** that maintained
foundation — they never maintain it by hand.

## The representative unit of work

The representative job is a **foreman round**, not a single board row. A round
covers a scope of board work — such as an initiative — and may complete many
tasks through successive waves. One round, end to end:

1. **Intent exists as work** — eligible board rows with acceptance criteria,
   dependencies and claims, on a board refreshed before eligibility is judged.
2. **A lane is admitted** — the scheduler checks deployment readiness, refreshes
   the repository and board copies, distinguishes work, no-work and an unreadable
   board, and admits the round by name.
3. **A round is issued** — an identified foreman-round request and its
   total-worker allowance are delivered through Crier into the project's Bunker,
   launching the foreman inside it.
4. **Waves execute within a budget** — the foreman recalls project memory,
   selects and claims eligible work, partitions compatible tasks into waves and
   launches workers within the round's configurable total-worker budget. The
   budget is a cap across all waves of the round, not a quota to be exhausted
   and not a per-wave allowance: a new wave does not reset or replenish it. The
   foreman launches no unnecessary worker merely to use the remaining cap.
5. **Work is verified independently** — each worker's commit meets a Git commit
   guard, its result meets a separate independent acceptance judgment, and the
   foreman verifies integrated and published results before counting them.
6. **Memory and board record everything** — every worker has a DuckBrain entry
   describing what it did, each wave gets a foreman entry, and the round ends
   with a distinct round summary; board task state is updated with evidence.
7. **The round returns and settles** — the foreman's correlated report (all
   waves, outcomes, evidence, budget use, remaining work, stop reason) returns
   through Crier to the scheduler, which records it durably and triggers
   whatever follows.

Everything else in this book exists to make one of those seven steps true rather
than merely attempted. Completion of one task, a quiet board, green formatting
or successful transport is never sufficient evidence that the **project** is
done; project acceptance is judged against the requested outcome, including
runnable, integrated behavior and deployment where that belongs to the project's
scope.

## Entry, exit and the MVP boundary

A project enters the loop when conversational intent has become Boardctl work
with acceptance criteria and the target deployment is ready. It exits when an
accepted project outcome exists: an integrated, usable result demonstrated
against those criteria, with publication proof and retained evidence at the
task, wave and round level. Perpetual maintenance of delivered work is kept
distinct from delivery.

The MVP boundary is fixed: Hermes is the fixed MVP harness; the Task Router is
future and not part of the MVP, placed after Node and before Harness; Terminal
Jail is optional and disabled by default, enabled only by explicit operator
configuration with no unguarded fallback when enabled. The deterministic
management/reconciliation service is a required target component of this
definition; it is specified in Parts I, IV and V and marked
TARGET-UNIMPLEMENTED — it is not yet built, and its implementation language and
storage are deliberately undecided.

## The system, as a map

![FIGURE 0.1](figures/system-map.svg)

Boxes are responsibilities, and each box carries a role/host boundary: a BUNKER tag
marks a component that executes inside the Bunker deployment/execution boundary;
untagged components run on the control host. Paths live in the model's `impl` field
and are deliberately volatile — a script can move without the system changing.
Colour is never used; line style is the contract state: solid means the interface
works as documented, dashed means it is broken and named, dotted means it is
designed but not built. Wires carry both a contract id and, where one exists, a
named signal — the envelope, the lease, the foreman's durable return.

Two resolved placement decisions are drawn on the map and govern every chapter. The
project foreman runs **inside its Bunker**; Crier is the launch/return boundary, and
the foreman's response returns through Crier to the scheduler on the control host,
which records it and triggers subsequent processing. DuckBrain is installed **in
every Bunker** and exposes the same logical project memory data/view as the
controller — the physical shared-service or replication topology remains an open
specification, not an assumed fact. DuckBrain memory is locally available in
Git-backed namespace repositories on each machine: losing the HTTP server does not
imply losing local memory access, and a disconnected server is never a reason to
invent a separate memory store.

The six layer names on the map — control, transport, execution, memory,
governance, evidence — are explanatory groupings that aid reading. They may
evolve as the design becomes complete; they are not a frozen architecture and
not a limit on the services the Factory may require. The Factory
management/reconciliation service and its desired/observed state store are part
of the arrangement (Part I §1.1) and registered in `docs/SYSTEM-MODEL.yaml`; the
map sheet regenerates from that model, and until that regeneration lands the
figure above does not yet draw the manager box — a named deviation, not a
concealed one.

## How a row moves

![FIGURE 0.2](figures/board-lifecycle.svg)

The forward path is the easy half. The half that decides whether a factory is honest is
the other one. A claimed row is started by the foreman and its worker — not by the
review plumbing; the commit then meets a Git commit guard, and its result meets a
separate, independent acceptance judgment; only after integration and publication
does the row complete, and completion is bound to retained evidence, never to a tool's
internal status word. A row that cannot proceed goes **blocked** with a named
blocker; a row whose dependency is unmet goes **deferred**, and the figure names the
return trigger that makes a deferred row dispatchable again; a row whose worker died
goes back to **blocked** instead of quietly vanishing; a review that requests
changes returns the row to the worker as rework. A board that only ever
moves forward is a board that is lying about something.

## One round, end to end

![FIGURE 2.1](figures/F1.svg)

The sequence shows the approved target and the deployed present side by side: the lane opens
with a refresh of the local and remote repository/board copies **before** eligibility is
judged, and a scheduler-owned board-check verifier distinguishes work, no-work and an
unreadable board — an unreadable board is never mistaken for an empty one. The figure does not
conceal the integration gap: the PRE and POST lane hooks that exist today run after
admission and after outcome recording respectively, and the figure says so on the
steps where it happens. Inside the Bunker, the MVP routes the node directly to the
fixed Hermes harness; a future Task Router is drawn between Node and Harness,
marked as not part of the MVP, and is never silently equated with the separate
model/provider route. Each side's promises are contractual: the scheduler promises a
well-formed envelope with a run id; crier promises delivery and a lease; the foreman
promises a durable response that returns through Crier. Where any of those promises
is unproven, the contract register (Part IV) marks that side RED.

## How to read the rest

| Part | Question it answers |
|---|---|
| I | What is the arrangement, and why this shape? |
| II | How does each flow actually run, step by step? |
| III | What is each module, what does it own, what breaks it? |
| IV | What does each side of each wire promise, and is it proven? |
| V | What is every setting, its default, and its consequence? |
| VI | What fails, and what would catch it? |
| VII | How does work get derived, dispatched and judged? |
| VIII | How is the book itself delivered and kept true? |

Approved target behavior governs this book's normative requirements. Source and
deployment evidence show implementation coverage and deviations — where the built
system and the approved target disagree, the disagreement is recorded as a named
deviation with its evidence, not adopted as the requirement. This book is
specification and record, not a proxy for either.
