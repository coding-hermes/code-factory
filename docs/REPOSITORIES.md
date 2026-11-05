# REPOSITORIES — what the Code Factory is made of, and where each piece lives

Measured on this host 2026-11-04. Every row states what was run to establish it;
a row without a probe is a claim, and claims do not belong in this file.

## The rule this file exists to enforce

The factory is **five repositories and two directories**, and the two directories
are the ones nobody can restore. A piece of the factory that lives only on this
host has no history, no second copy, and no review — it is a single disk away
from not existing. Every row below says which kind it is.

## Versioned — has a remote, can be rebuilt from it

| Repo | Remote | What it contributes | Probe |
|---|---|---|---|
| `code-factory` | `coding-hermes/code-factory.git` | Board (`.coding-hermes/board/`), specs (`ENVELOPE.md`, `NODE.md`, `HARNESS.md`, `HARNESS-MATRIX.md`), provisioning (`scripts/bunker-provision.sh`, `scripts/project-node.sh`), harness installers (`scripts/harness/`), tests (`tests/`), the handbook's subject matter | `git -C ~/code-factory config --get remote.origin.url` |
| `scheduler` | `coding-hermes/scheduler.git` | Decides whose turn it is, renders the directive, dispatches the tick, awaits the reply: `internal/scheduler/dispatch_leg.go`, `internal/bus/dispatch.go` | `git -C ~/coding-hermes-scheduler/coding-herms-scheduler remote -v` |
| `crier` | `crier-dev/crier.git` | The relay on `:8767` — inbox, the injection guard, webhook push (DF-CRIER-157) | `git -C ~/crier config --get remote.origin.url` |
| `task-router` | `coding-hermes/task-router.git` | Model and provider routing (`:9092`/`:9093`); decides which family a lane thinks with | `git -C ~/task-router config --get remote.origin.url` |

## Versioned but unrouted — a local repository with no remote

| Path | State | Why it matters |
|---|---|---|
| `~/gitreins` | branch `wt/DF-2026-20-port`, **no `origin`** | GitReins is the commit gate and the Tier-2 judge. Its history exists on this host and nowhere else; the branch it is parked on is not `main`. |

`git -C ~/gitreins config --get remote.origin.url` returns nothing. That is not
"a repo without a remote yet" — it is the gate that decides whether work lands,
running from a checkout that no other machine can reproduce, on a feature branch.

## Not versioned at all — the two that would hurt

| Path | Contents | Consequence today |
|---|---|---|
| `~/crier-fleet` | `dispatcher.py` (the node-side runner: lease, decode, execute, reply, ledger), `dispatch-ledger.jsonl`, `keys/`, `fleet_agents.json` | The component that actually runs work on every node has **no history and no second copy**. Every hardening fix to it this week (idempotency ledger, base64 both legs, ack-on-delivery, deadline derivation) exists as an edit on one disk. It also holds credentials, so where it is stored is an owner decision, not a default. |
| `~/code-factory-reports` | The handbook build: `handbook/*.html` sources, `*.png`, the rendered `*.pdf`, and every `code-factory-dependency-map-*.html` (v1…v8) | The operations handbook Bane reviews is generated from HTML that exists only here. The PDF is a build artifact of a source tree that has no history — regenerating it after a disk loss is impossible, and the v1…v8 sprawl is what "no version control" looks like. |

## The dependency each row of the chain needs at run time

```
task-router :9092/9093   which model
      ↓
scheduler               whose turn, and the directive  ── fleet.toml, scheduler.db
      ↓
crier :8767             delivery + guard              ── keys, agent registry
      ↓
crier-fleet dispatcher  lease, decode, run, reply     ── NOT VERSIONED
      ↓
bunker node (cf-node)   repo clone + harness + hermes ── provisioned by code-factory scripts
      ↓
board row + DuckBrain   evidence, closure             ── code-factory repo
```

A node is provisioned by `code-factory` (`scripts/bunker-provision.sh`,
`scripts/project-node.sh`) and connected by `scripts/bunker-crier-connect.sh`.
The harness it runs is installed by `scripts/harness/install-{hermes,codex,
opencode,claude-code}.sh`. What is still missing on a fresh node is catalogued
on the board: CF-219 (no installer puts Go on a bunker), CF-220 (nothing seeds
prompts or skills), CF-229 (the `CF_*` variable contract is unwritten), CF-230
(harness selection is not data-driven).

## What "organized" means here

1. **Nothing that runs in production lives only on one disk.** `crier-fleet` is
   the outstanding violation; `code-factory-reports` is the second.
2. **The gate has a remote.** `~/gitreins` on a feature branch with no `origin`
   cannot be audited by anyone else.
3. **Every installer names its refusal.** `scripts/harness/*.sh` already follow
   this (`CF_*` refusals, one measured turn); the four missing items above are
   the gaps in what they install, not in how they refuse.
4. **One row, one sheet.** A finding gets a board row before it gets a document;
   `docs/` explains, the board tracks.
