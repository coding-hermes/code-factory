# Part 0 — Overview

*Read this page before any chapter. It is the only page that asks you to hold the whole
thing at once; everything after it is detail.*

## What this system is for

A code factory turns **a line on a board** into **a commit on main**, without a human
carrying it. The owner writes intent; a scheduler decides whose turn it is; a transport
carries the work to a machine; a harness does it; a judge decides whether to believe it;
and the result comes back as evidence a person can read.

One run is short:

1. **A row exists** — pending, with acceptance criteria someone else can re-run.
2. **A lane is admitted** — the scheduler checks the row is workable, the lane is due,
   and the checkout is free.
3. **A work order is issued** — an envelope with a run id, a correlation id and the task.
4. **A node executes** — it pulls the order, leases it, runs a harness, and produces a
   diff plus evidence.
5. **A verdict is returned** — the judge grades against the criteria, not the prose.
6. **The row closes** — with the commit and the evidence, or it does not close at all.

Everything else in this book exists to make one of those six steps true rather than
merely attempted.

## The system, as a map

![System map](figures/00-system-map.svg)

Boxes are responsibilities. Paths live in the model's `impl` field and are deliberately
volatile — a script can move without the system changing. Colour is the contract state:
solid means the interface works as documented, dashed means it is broken and named,
dotted means it is designed but not built.

Read the map in layers, bottom of the stack upward:

- **control** — who decides (owner, scheduler, policy)
- **transport** — who carries (crier, envelopes, leases)
- **execution** — who does it (node, harness, worker)
- **memory** — who remembers (board, DuckBrain, session store)
- **governance** — who believes it (judge, gates, guards)
- **evidence** — what a human reads (reports, verdicts, this book)

## How a row moves

![Board row lifecycle](figures/00-board-row-lifecycle.svg)

The forward path is the easy half. The half that decides whether a factory is honest is
the other one: a row that cannot proceed goes **blocked** with a named blocker, a row
whose dependency is unmet goes **deferred** rather than burning a tick, and a row whose
worker died goes back to **blocked** instead of quietly vanishing. A board that only ever
moves forward is a board that is lying about something.

## One dispatch, end to end

![F1 dispatch](figures/F1-dispatch.svg)

Seven messages, three systems, one row. Note what each side had to promise: the scheduler
promises a well-formed envelope with a run id; crier promises delivery and a lease; the
node promises an outcome that references the same correlation id. Where any of those
promises is unproven, the contract register (Part IV) marks that side RED.

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

If a chapter and the code disagree, the code is right and the disagreement is a finding.
This book is evidence, not authority.
