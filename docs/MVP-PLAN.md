# MVP plan — one lane, one bunker, one landed result

**Goal.** A single lane of a single project runs on a bunker, returns a result, the control host
lands it, and the board row closes on evidence anyone can re-run. Nothing in this plan is a
version bump; every exit test is a command whose output is the proof.

**Why this shape.** The control host works today. The break is the funnel: crier routes per
lane instead of per project, nothing produces a result, nothing refreshes the clone, and nothing
lands the commit. Four moves, two of them wiring.

## Working backwards from the finish line

| # | must be true | state today | row |
|---|---|---|---|
| 1 | The board row is `complete` with a sha that `origin/main` contains, produced on a bunker | no path from a node commit to `main` | CF-213 |
| 2 | The commit is in the control host's tree and the next dispatch reads it | nothing fetches project repos (119 enabled lanes) | CF-212 |
| 3 | The result that named the commit reached the scheduler's inbox and completed the tick | consumer exists (`bus/inbox.go`, `dispatch_leg.go`); no producer | CF-211 |
| 4 | The node produced the result inside its own clone | clone present (`af67c3b`), no harness, no identity, no credentials | CF-150, CF-214 |
| 5 | The directive reached the node with its lane identity | mapping keyed per lane, 1 of 17 wired; 82 × 403 on the only attempt | CF-210 |
| 6 | crier routed the project to that bunker | crier up; routes per lane; guard refuses reserved keys | CF-210, CF-131 |
| 7 | The scheduler chose the lane and recorded the tick | works today on the control host (local projects) | — |
| 8 | The foreman wrote a brief the node can execute | works today | — |

Read top-down: 1–4 are **missing**, 5–6 are **miswired**, 7–8 are **working**.

## Phases

### P0 — a node that can answer (exit test: `bunker-provision.sh --check` all green)

1. `bunker-provision.sh --apply` on `cf-node`: identity, auth bundle, harness, clone at the
   configured `REF`, and every declared DuckBrain namespace (`NAMESPACES=a,b` — the first is
   primary, each is probed). (CF-214; the harness pin and the missing `dashboard.basic_auth` stay
   open under CF-150.) The node environment is **declared**, not hand-edited: `NODE_ENV_FILE`
   plus `CONFIG_SET_*` name the provider key (by file path), the model pin, the bind and the
   port, and `scripts/node_env.py --apply` writes them before the harness layer starts a
   gateway, so a rebuilt node is the same node.
2. `bunker-crier-connect.sh --apply`: inbox answers **200** for the project's agent id.
3. Exit evidence: the `--check` output, pasted, with its five rows green.

### P1 — one directive, no inference needed (exit test: node shows the digest it verified)

1. Map the project (not the lane) to the bunker; carry the lane id inside the payload (CF-210).
2. Send one directive through crier; the node pulls it, verifies the brief digest, writes the
   receipt. No model call — this proves routing, delivery and identity without the proxy.
3. Exit evidence: scheduler tick row + node receipt + the digest recomputed on the control host.

### P2 — one task, one result (exit test: tick completes from the node's own result)

1. A producer posts the result envelope to crier → scheduler inbox (CF-211).
2. Negative cases first: wrong `corr_id` must not ack; a failing gate must complete the tick
   **FAILED** with the node's reason.
3. Exit evidence: `ticks.status=completed`, `corr_id` matches, reply text carries the node's
   summary and shá.

### P3 — land it (exit test: `origin/main` contains the shá, board row closed)

1. Landing step: merge the node branch, run the project gate, push, refuse on dirty tree / red
   gate / non-ancestor commit (CF-213).
2. Refresh the control-host clone to the landed commit before the next dispatch (CF-212), and
   re-run `--check` as the evidence.
3. Exit evidence: `git merge-base --is-ancestor <sha> origin/main` = 0, board row `complete`,
   digest recomputed.

## Provisioning contract (P0 detail)

```bash
scripts/bunker-provision.sh --config <project>.conf --check     # read-only, names every value
scripts/bunker-provision.sh --config <project>.conf --apply     # idempotent
scripts/bunker-crier-connect.sh --agent <a> --server <s> --url <crier> --check
scripts/bunker-provision.sh --config <project>.conf --destroy --yes
```

The same config declares the node's environment — `NODE_ENV_FILE` (a profile of
`ENV_<NAME>=<value>` or `@<path>`, see `config/node.env.example`) and one `CONFIG_SET_*` key per
config scalar — and the provisioner applies it on the node before the harness layer, so the
environment is reviewable and a second run changes nothing.

The config is data (`KEY=VALUE`, parsed, never sourced), names token **files** rather than
values, and the command line always wins. See `skills/code-factory-bunker/SKILL.md`.

## Out of scope for the MVP (explicitly deferred)

- the restricted inference proxy — the node's config points at it, so P2 must either re-point it
  for the test or run harness-less on P1 (CF-207);
- a second harness adapter — only Hermes has a measured ladder (CF-150);
- publishing the template — `master` lineage, branch protection and the release contract gate
  any publish (CF-163, CF-120, CF-161, CF-209);
- DuckBrain per-key namespace scoping — the bunker uses one namespace per project, which is
  enough for one project and no more (CF-208).
