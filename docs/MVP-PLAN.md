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
| 3 | The result that named the commit reached the scheduler's inbox and completed the tick | consumer exists (`bus/inbox.go`, `dispatch_leg.go`) and the producer now ships — `scripts/node-bus-worker.py` posts `ok`/`error`/`reply_b64`/`in_reply_to` under an idempotency key (`CF-211` complete 2026-11-08) — but no live node has exercised it | CF-211 |
| 4 | The node produced the result inside its own clone | clone present (`af67c3b`); `scripts/bunker-provision.sh` now installs identity, the auth bundle and the harness as declared inputs, while the node baseline that raised `CF-214` measured FAIL on auth_github, auth_duckbrain, harness and crier 401, and no re-measure has been published since — `CF-214` closed 2026-11-10 at `d5ca56f1` (provisioner, crier-connect and the doc locators shipped), so the cell now reads **shipped and unmeasured on a live node**, not unbuilt | CF-150, CF-214 |
| 5 | The directive reached the node with its lane identity | mapping keyed per lane, 1 of 17 wired; 82 × 403 on the only attempt | CF-210 |
| 6 | crier routed the project to that bunker | crier up; routes per lane; guard refuses reserved keys | CF-210, CF-131 |
| 7 | The scheduler chose the lane and recorded the tick | works today for local projects — `sqlite3 ~/.hermes/coding-hermes/scheduler.db "select count(*) from ticks"` and a `tick_dispatch` row naming the lane; NOT proven for a remote lane | — |
| 8 | The foreman wrote a brief the node can execute | the brief is written today, and the seeder that puts prompts and declared skills on a node ships (`CF-220` complete), but no lane has consumed one end to end (S3 remains OPEN in sheet 2.4; `CF-249` owns the residual) | CF-220 |

Read top-down: 1–2 are **missing**, 3 now has a producer but **no live run**, 4 is **shipped**
and still unmeasured on a live node (`CF-214` closed 2026-11-10 at `d5ca56f1`; the re-measure
has no owner row yet), 5–6 are **miswired**, 7–8 are **working**. (Re-measured against
the board at `3d1b642` on 2026-11-08: `CF-211` closed the producer leg; `CF-150` was already
`complete` at that pin and so owns none of item 4, which `CF-214` owned until it closed on 2026-11-10.)

## Phases

### P0 — a node that can answer (exit test: `bunker-provision.sh --check` all green)

1. `bunker-provision.sh --apply` on `cf-node`: identity, auth bundle, harness, clone at the
   configured `REF`, and every declared DuckBrain namespace (`NAMESPACES=a,b` — the first is
   primary, each is probed). (CF-214; the harness pin stays open, while `dashboard.basic_auth` no
   longer does: `CF-150` is `complete` (its subject was exactly that staging; `scripts/node_gateway_auth.py`
   is wired into `bunker-provision.sh`, evidence run `71cc322f`) and `CF-388` closed the fresh-node
   staging failure — `CF-292` is also `complete` (board `commit_hash` `ee13de4`, an ancestor of
   `origin/main`: presence is now the indented/blank/comment run after `dashboard:` with the
   direct-child rule, pinned by `tests/test_node_gateway_auth.py`), so the surviving auth-gate
   defects are `CF-193` and `CF-194`, both pending, plus the three residual shapes `CF-395` names.)
   The node environment is **declared**, not hand-edited: `NODE_ENV_FILE`
   plus `CONFIG_SET_*` name the provider key (by file path), the model pin, the bind and the
   port, and `scripts/node_env.py --apply` writes them before the harness layer starts a
   gateway, so a rebuilt node is the same node.
2. `bunker-crier-connect.sh --apply`: inbox answers **200** for the project's agent id.
3. Exit evidence: the `--check` output, pasted, with its five rows green.

### P1 — one directive, no inference needed (exit test: node shows the digest it verified)

1. Map the project (not the lane) to the bunker; carry the lane id inside the payload (CF-210).
2. Send one directive through crier; the node pulls it, verifies the brief digest, writes the
   receipt. No model call — this proves routing, delivery and identity without the proxy.
3. The node consumes it with its **own** credentials: `scripts/node-bus-worker.py` (CF-215) reads
   `/agents/<id>/inbox` with the bearer *and* the per-agent ed25519 signature, verifies
   `brief.digest`, runs the harness inside the clone, posts the result with its `corr_id` and
   acks last. Its `--check` is the row-by-row evidence that the node can do this at all.
4. Exit evidence: scheduler tick row + node receipt + the digest recomputed on the control host.

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

## Harness workstream — five harnesses, one memory, one foreman

The MVP needs one harness to prove the shape (Hermes, measured). The fleet needs the matrix, and
it is being built in parallel rather than after: `specs/HARNESS-MATRIX.md` is the design authority
— the foreman is **always** Hermes, a worker's harness follows its **model family**
(`claude-*` → claude-code, openai → codex, pi → pi/omp, OSS models → opencode, anything else →
Hermes), and **every** harness writes the same DuckBrain record with
`run_id / lane / harness / model_requested / model_served / commit`.

Rows, in the order they unblock each other:

| Row | What it closes |
|---|---|
| **CF-229** | the `CF_*` variable contract — every installer and every invocation takes the declared set, and a credential in `argv` is refused |
| **CF-230** | the resolution rule — directive > matrix > policy fallback, with `harness_selected`/`harness_reason` recorded |
| **CF-231** | one memory shape — the DuckBrain record every harness writes, read back by the battery |
| **CF-227** | codex: the adapter exists in crier, the binary and the installer do not |
| **CF-225** | claude-code: no adapter in crier, no installer here |
| **CF-228** | pi: the adapter is named `pi`; oh-my-pi needs bun |
| **CF-226** | deepseek-harness (`dsh`, npm `@deepseek-ai/dsh` 0.2.1-rc.5) is real and was absent from both repos — installer at a pinned RC; **landed** in `scripts/harness/install-dsh.sh` (measured install + one measured turn, per-layer plugin diagnosis, the RC pin re-measured by `--pin-status`, and the crier adapter deferred by a recorded decision); the earlier "not a thing" was true of our trees, not of the world |
| **CF-232** | the docs still said the foreman runs on the control host (fixed) |
| `CRIER-HARNESS-9/10/11/12` | crier's side: the pi-agent alias, the opencode-v2 decision, claude-code, and unknown names failing at load |

**Support is measured, not claimed.** `tests/harness-conformance.sh` runs three legs per harness today
(`check`, `apply`, `smoke`); the `vars` and `memory` legs are the targets in CF-229/CF-231 and are not yet wired into it and writes `docs/HARNESS-CONFORMANCE.md`; a harness
counts as supported when all five are `PASS` on a real node, or `SKIP` with the missing credential
named. This is what keeps the alignment from drifting after today: the matrix is regenerated by a
test, so a harness that stops working turns the document red.

### Backlog carried by the loop (not MVP, filed so it is not lost)

| Row | What |
|---|---|
| CF-233 | cross-provider matrix: which harness can host which provider, and the shim that makes it work |
| CF-234 | switching as configuration: one file, `--explain`, effective next tick, no reprovision |
| CF-235 | oh-my-hermes: is OMH the supported provider path (13 providers), and is it the right upstream |
| CF-236 | a harness swap must be measurable before a family default moves |
| CF-237 | generate the capability table from probes instead of documentation |

`prompts/foreman.md` names them, with the rule that a backlog row never displaces a P0/P1 but is
never dropped either.
The per-project configs are generated, not typed: `scripts/bunker_config_gen.py --server <host>
--prefix code-factory` writes one `<project>.conf` from the scheduler's `projects` table, refuses
a phantom repo or a duplicate agent by name, and `--check` names every drifted key.

## Out of scope for the MVP (explicitly deferred)

- the restricted inference proxy — the node's config points at it, so P2 must either re-point it
  for the test or run harness-less on P1 (CF-207);
- ~~a second harness adapter~~ — **in scope now, as its own workstream**: see §Harness workstream
  below and `specs/HARNESS-MATRIX.md` (CF-225 … CF-231);
- publishing the template — `master` lineage, branch protection and the release contract gate
  any publish (CF-163, CF-120, CF-161, CF-209);
- DuckBrain per-key namespace scoping — the bunker uses one namespace per project, which is
  enough for one project and no more (CF-208).
