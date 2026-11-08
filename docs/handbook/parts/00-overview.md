# Part 0 — Overview

*Read this page before any chapter. It is the only page that presents the whole
system at once; everything after it is detail.*

## What this system is for

A code factory turns **project intent and a line on a board** into **an
independently accepted, published change with retained evidence**, without a human
carrying it. The owner writes intent; a scheduler on the control host decides whose
turn it is; the transport carries the work across the Bunker deployment/execution
boundary; a foreman inside the Bunker runs a harness to do it; a judge decides
whether to believe it; and the result returns through the same transport to the
scheduler, which records it and triggers whatever follows.

One run is one complete unit of work, end to end:

1. **A row exists** — pending, with acceptance criteria someone else can re-run.
2. **A lane is admitted** — the scheduler refreshes the repository and board copies,
   checks the row is workable, and admits the tick by name.
3. **A work order is issued** — an envelope with a run id, a correlation id and the
   task, launched through Crier into the project's Bunker.
4. **A Bunker foreman executes** — it starts the worker, runs the fixed Hermes
   harness, and produces a diff plus evidence.
5. **The work is judged** — a commit guard grades the commit, an independent
   acceptance judgment grades the result, and the change is integrated and
   published.
6. **The row closes** — the foreman's response returns through Crier to the
   scheduler, which records it; the row closes with the commit, the publication
   proof and the evidence, or it does not close at all.

Everything else in this book exists to make one of those six steps true rather than
merely attempted. The module inventories of Part III, the contracts of Part IV and
the settings of Part V exist only in service of this unit of work; none of them is
an end in itself.

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
specification, not an assumed fact.

Read the map in layers, bottom of the stack upward:

- **control** — who decides (owner, scheduler, foreman, credentials)
- **transport** — who carries (crier, gateway, proxy)
- **execution** — who does it (bunker, node, harness, dispatcher, provisioner)
- **memory** — who remembers (board, DuckBrain, session store)
- **governance** — who believes it (judge, gates, guards)
- **evidence** — what a human reads (reports, verdicts, this book)

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

## One dispatch, end to end

![FIGURE 2.1](figures/F1.svg)

Seventeen messages, eight participants, one row. The sequence shows the approved
target and the deployed present side by side: the lane opens with a refresh of the
local and remote repository/board copies **before** eligibility is judged, and a
scheduler-owned board-check verifier distinguishes work, no-work and an unreadable
board — an unreadable board is never mistaken for an empty one. The figure does not
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
| VII | How does a work item get derived, dispatched and judged? |
| VIII | How is the book itself delivered and kept true? |

Approved target behavior governs this book's normative requirements. Source and
deployment evidence show implementation coverage and deviations — where the built
system and the approved target disagree, the disagreement is recorded as a named
deviation with its evidence, not adopted as the requirement. This book is
specification and record, not a proxy for either.
