# FLEET-MEMORY — how a run becomes searchable, across every node and every week

Status: **PARTIAL — the node has a real DuckBrain adapter seam, but live transport is UNVERIFIED.**
`scripts/node-bus-worker.py` exports R1 then R2 when `DUCKBRAIN_URL` and a mode-600 token are configured,
reads each record back by exact key, and records a named `UNVERIFIED` result when transport or
configuration is unavailable. The conformance battery remains hermetic fixture evidence unless a real
node and readback are measured. This page fixes the shape before the remaining deployment work.

## 1. The question this answers

*"What happened across the factory last week, in project X, on lane Y, with harness Z?"* — asked from
the control host, by the foreman or by a human, without ssh-ing into a bunker and without reading 40
transcripts by hand.

A run that is not written down did not happen as far as the fleet is concerned. Today the fleet's
memory of a node run is the node's own scrollback, which dies with the container.

## 2. One namespace, as the operator specified — and what currently blocks it

The design target is the operator's: **all factory nodes write to ONE namespace**, with the project and
the ISO week carried in the key, so the control host can ask "what happened across the fleet last week"
in a single query (owner, session `20261104_135659_747f8c` msg 6637174: *"all factory nodes write to the
same namespace but different tables per project and might be different tables per week per project …
the goal is that the main hermes can search for things that have hapend across the fleet"*).

    /factory/<project>/<YYYY-Www>/<lane>/<run_id>

**The blocker is measured, not architectural.** DuckBrain's token is not scoped to a namespace today
(CF-208: the same token returns 200 for `code-factory` *and* `tatara`). In a single shared namespace,
any node holding a token could read every project's runs — including the security projects.

So the implementation order is fixed:

1. scope the token to a namespace (CF-208), then
2. point every node at the one `factory` namespace, which is the design above.

Until step 1 lands, a per-project namespace is a **temporary deviation**, not the design: R2 is written
to `<project>`'s namespace and the query in §5 spans them by iterating namespaces. Any implementation
that reads this page must say which of the two states it is in — `factory` (target) or
`per-project` (interim) — in its own record, because the two produce different key spaces.

## 3. The three records

### R1 — the run record (project namespace, required by I3)

Written by the node, at the end of every run, into the project's own namespace (`CF_NAMESPACE`).

    key:  /runs/<lane>/<YYYY-Www>/<run_id>
    domain: event

Content is whatever the run produced: the envelope, the tool summary, the diff stat, the gate result.
This is the detailed record and it stays with the project.

### R2 — the fleet index (shared `factory` namespace)

Written by the same node, same run, immediately after R1. **A pointer, not a copy**: enough to find
the run, nothing that leaks the work.

    key:  /factory/<project>/<YYYY-Www>/<lane>/<run_id>
    domain: event

Required fields, all strings unless noted:

| field | why it is here |
|---|---|
| `run_id` | the join key back to R1 and to the bus envelope |
| `project` | which project's namespace holds R1 |
| `lane` | which lane ran |
| `week` | ISO week `YYYY-Www`, duplicated out of the key so a filter does not have to parse |
| `harness`, `harness_version` | I3's provenance; a run whose harness is unknown is not comparable |
| `model_requested`, `model_served`, `provider_binding` | the three that differ in practice — a label is not a lane |
| `commit` | the SHA the run started from |
| `tick` | the scheduler tick, or `-` when the run came from crier directly |
| `board_row` | `CF-nnn` when the run was dispatched for a row |
| `outcome` | `PASS` \| `FAIL` \| `UNVERIFIED` — never blank, never "ok" |
| `artifact_digests` (list) | sha256 of what the run produced, so the control host can recompute |
| `started_at`, `ended_at` | ISO-8601, UTC |
| `node` | the agent id, e.g. `<agent-id>` |

**Forbidden in R2:** source code, diffs, prompt text, credentials, absolute paths outside `$HOME`.
The index must be safe to read from a machine that is not entitled to the project's work.

### R3 — the weekly rollup (shared `factory` namespace)

Written by the **foreman on the control host**, once per project per week, after the week closes.

    key:  /factory/<project>/<YYYY-Www>/_rollup
    domain: concept

Counts computed *from R2*, never typed by hand: runs, outcomes by class, distinct lanes, distinct
harnesses, distinct models served, board rows touched, rows filed. A rollup that disagrees with the R2
records for its week is a defect (see §7).

## 4. Who writes what

| writer | writes | when | namespace |
|---|---|---|---|
| node-bus-worker (`scripts/node-bus-worker.py`) | R1, then R2 | end of every run, success **or** failure | project, then `factory` |
| foreman on the control host | R3 | weekly, after the window closes | `factory` |
| scheduler | nothing | — | — |

A run that fails before producing an outcome still writes both records with `outcome: FAIL` and the
reason. **A missing record is indistinguishable from a run that never happened; that is the failure
mode this design exists to prevent.**

## 5. How the control host searches

1. **By week:** `list_keys` with prefix `/factory/<project>/<YYYY-Www>/` — cheap, exact, no embedding.
2. **By fleet and week:** prefix `/factory/` plus a filter on the `week` attribute. This is the query
   the owner asked for: *everything that happened last week, every project*.
3. **By meaning:** semantic `recall` over the `factory` namespace for "why did the crier connect fail
   on Thursday" — the embedding text of R2 is the one-line summary, so recall lands on the run, not
   on prose.
4. **Drill-down:** the `run_id` from R2 fetches R1 from the project's namespace, where the detail is.

R2's embedding text is deliberately short — `"<project>/<lane> <outcome> <week>: <one-line summary>"` —
because a long document in an index makes every recall return the index instead of the answer.

## 6. Retention

- R1: kept 12 weeks per project, then squashed into that week's R3 and dropped.
- R2: kept 12 weeks, same schedule — the index is a window, not an archive.
- R3: kept indefinitely. It is the only record that survives a year.

`squash` is DuckBrain's own operation; the schedule is the foreman's job, and it must be a named row
in the weekly run, not a cron nobody reads.

## 7. Verification — what has to be true before this page says "implemented"

1. One real node run writes **both** R1 and R2, and both read back by key with the fields intact.
2. A control-host query with prefix `/factory/` returns a run from a project the querying agent is
   not a member of, **without** granting that agent the project's R1.
3. A node cannot read another project's namespace: the read fails with 403/404 — this requires CF-208
   fixed first, and until it is, statement 2 is unsafe by construction.
4. R3's counts equal the number of R2 records for that project and week, recomputed independently.
5. `tests/harness-conformance.sh`'s `memory` leg turns green on a real node, for a real turn — the leg
   is specified in `specs/HARNESS-MATRIX.md` §6 and has never passed.
6. A failed run leaves a record. Kill a run mid-flight and prove both records exist with
   `outcome: FAIL`.

## 8. Open defects this design inherits

| id | what | effect on this page |
|---|---|---|
| CF-208 | the DuckBrain token is not scoped to a namespace | §3's isolation claim is unenforceable until it is fixed |
| CF-276 | `node-create.sh` does not stage `node-bus-worker.py` | the writer may not exist on a fresh node at all |
| CF-285 | `lib.sh have()` cannot report absence | a missing writer will not be detected by the ladder |
| — | no node writes DuckBrain today | the whole page is design, and says so in line 3 |

## 9. What this is not

It is not a logging system: logs stay on the node, this is the record of what happened. It is not a
metrics pipeline: it carries no timings beyond start/end, because a run's cost is the scheduler's
ledger, not this one. And it is not a substitute for the board: the board says what is *planned*, this
says what *ran*.
