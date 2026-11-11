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
TARGET-UNIMPLEMENTED — it is not yet built. Its language remains open; its
single-writer, fsync-acknowledged transactional JSONL persistence profile and
crash/recovery requirements are fixed in Part I §1.9.2.

## The system, as a map

![FIGURE 0.1](figures/system-map.svg)

Boxes are responsibilities, and every box carries an explicit host/trust-domain
enclosure: solid control-host, long-dash Bunker, fine-dash independent authority,
dotted external trust domain, and a double enclosure for dual-instance components.
Layer panels are explanatory groupings, never substitutes for those boundaries.
Paths live in the model's `impl` field and are deliberately volatile — a script
can move without the system changing. Colour is never used; wire line style is
the contract state: solid means the interface works as documented, dashed means
it is broken and named, dotted means it is designed but not built. Wires carry
both a contract id and, where one exists, a named signal — the envelope, the
lease, the foreman's durable return.

The map is generated from `docs/SYSTEM-MODEL.yaml`, not drawn as a second
inventory. This issue derives 33 components, six layers, 16 flows and 31 typed
contracts (`CT-01` through `CT-30`, plus return leg `CT-06R`) from model SHA-256
`86bab48ff85ea8adbd35b6071f96608c678a4e6434c99de76fb8fe1827cb2098`. The figure
and BOOK caption carry that identity so a model edit cannot silently leave a
stale map.

Two resolved placement decisions are drawn on the map and govern every chapter. The
project foreman runs **inside its Bunker**; Crier is the launch/return boundary, and
the foreman's response returns through Crier to the scheduler on the control host,
which records it and triggers subsequent processing. DuckBrain is installed **in
every Bunker** and exposes the same logical project memory data/view as the
controller using the selected same-namespace shared-Git profile (Part V, supported
memory profile; F3). Local-only requires the shared repository specified there;
it is not a disconnected multi-Bunker deployment. DuckBrain memory is locally available in
Git-backed namespace repositories on each machine: losing the HTTP server does not
imply losing local memory access, and a disconnected server is never a reason to
invent a separate memory store.

The six layer names on the map — control, transport, execution, memory,
governance, evidence — are explanatory groupings that aid reading. They may
evolve as the design becomes complete; they are not a frozen architecture and
not a limit on the services the Factory may require. The Factory
management/reconciliation service and its desired/observed state store are part
of the arrangement (Part I §1.1) and registered in `docs/SYSTEM-MODEL.yaml`.
`CF2A-01/P5-A` is the target model revision; the rendered issue identifies the
model digest and derives its component/contract totals from that exact input.

## How a row moves

![FIGURE 0.2](figures/board-lifecycle.svg)

The forward path is the easy half. The half that decides whether a factory is honest is
the other one. A **pending** row becomes **in_progress** through an atomic group
claim; release returns it to pending only after quiescence. Completion requires an
accepted verdict, integrated publication and retained evidence, never a tool's
internal status word. **Blocked** and **deferred** are open, nonterminal states:
neither satisfies a prerequisite. A blocker must carry its identity, evidence and
unblock condition; deferral must carry its return condition and owner.
Cancellation first enters **cancel_requested**, denies new claims, and reaches
**cancelled** only after every child is quiescent; cancellation also leaves all
prerequisites unsatisfied. **Complete** and **cancelled** are the only closed
states. An authorized reopen returns either to pending with reopened evidence,
residual work and a new row revision; it never silently rewrites a historical
completion.

## One round, end to end

![FIGURE 2.1](figures/F1.svg)

The sequence shows the approved target with implementation gaps named rather than
silently promoted to requirements. The lane refreshes the repository and board
**before** eligibility; `board-check` distinguishes work, no-work and an
unreadable board, so an unreadable board is never mistaken for an empty one.
`round-admission.v1` admits the total round allowance once; waves consume it and
never replenish it. The resident Node supervisor retrieves signed custody,
launches the Bunker foreman, and returns correlated evidence. CT-05 is
`worker-brief.v1` with launch-custody identity and fences; CT-04 is
`worker-result.v1`; CT-06R carries `round-report.v1` back to the scheduler's
durable settlement. The board closeout binds the accepted verdict and publication
proof, while memory records local commit and remote synchronization separately.
Where a promise remains unproven, the contract register (Part IV) marks that
side RED; legacy transport success is coverage evidence, not a second contract.

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

## Issue authority and compatibility

The target revision is `CF2A-01/P5-A`; implementation evidence has its own source
revision and never changes a requirement. Part IV §IV.1 supplies the canonical
`cf2a.v1` envelope and contract identities; Part V supplies `factory.v1` desired
configuration and the same-namespace memory profile. Part I §1.9 supplies precise
manager, adapter and concurrency refinements; Part II supplies ordered execution.
The machine-readable model declares this revision and precedence. Conflicts
without an explicit resolution in this issue are `SPEC_CONFLICT`: build acceptance
stops rather than consulting implementation code as an alternative authority.
Legacy chapter examples are coverage evidence, not an alternate wire protocol.

The P5-A resolution chooses Part IV's more complete outer envelope/body cards,
Part V's global `factory.v1` configuration/API and local-commit memory semantics.
`manager.v1`, `round-request.v1`, seeded-prompt CT-05 and M*-C* aliases are not
parallel target contracts. Part I §1.9.6 defines compatibility translation.
Owner acceptance remains joint across waves; structural lint alone does not
approve this target revision.
