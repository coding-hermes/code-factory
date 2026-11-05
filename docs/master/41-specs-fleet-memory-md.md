# 41. specs/FLEET-MEMORY.md

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/specs/FLEET-MEMORY.md` |
| Repository | `code-factory` |
| Revision | `6eea792` |
| Status | **RED — design only; the writer it specifies does not exist** |

## 1. Purpose and why it matters

This page specifies how a node's run becomes something the control host can search: three records, two
namespaces, one key grammar. Without it, a run's only trace is the node's scrollback, which dies with
the container — so "what happened across the factory last week in project X on lane Y" can only be
answered by hand.

What breaks if it is ABSENT: the fleet has no memory of its own work; every retrospective is a
re-reading of transcripts, and duplicates like tonight's (three agents documenting the same module)
have no record to check against. What breaks if it LIES: a run recorded with the wrong `model_served`
or `outcome` is worse than no record, because the control host trusts it.

The requirement already exists as an invariant — `specs/HARNESS-MATRIX.md:29` (I3) demands every
harness report the same provenance set — but nothing specifies the records, the namespace split or the
search. This page is that specification. Its own line 4 states the honest state: the node contains
zero DuckBrain calls today.

## 2. Dependencies and library contracts

**DuckBrain HTTP API** (`:3000`, `x-api-key` header, never `Bearer`):

| call | used for | contract this design relies on |
|---|---|---|
| `POST /api/memories` | every write | `key` leads with `/`; `domain` is a closed enum (`event`, `concept`, …); the response returns the stored `id` and echoes `namespace` |
| `GET`/recall with `prefix=` | §5's week and fleet queries | prefix listing is exact and needs no embedding |
| `squash` | §6 retention | collapses a key range; the design assumes it is namespace-local |
| namespaces | `factory` + one per project | a namespace is the isolation boundary — **which the token does not currently enforce** (`specs/FLEET-MEMORY.md:20`, CF-208) |

**Node-side producer** — `scripts/node-bus-worker.py`: the file that would write R1 and R2. It holds
the identity and the signed-read path (`scripts/node-bus-worker.py:273` is its only line matching
"memory", a docstring about the seed, not a write), so §4's table is a plan, not a description.

**Control-host consumer** — the foreman's weekly step (`prompts/foreman.md:36` already requires that it
"write the same DuckBrain record"), and the conformance leg `specs/HARNESS-MATRIX.md:167` (`memory`),
which has never passed.

**Variables** that decide the write (§7): `CF_NAMESPACE`, `CF_RUN_ID`, `CF_LANE`, and the token file.

## 3. Verification

The spec's own acceptance list is `specs/FLEET-MEMORY.md:112` (six statements). Run against today's
tree, five of the six cannot even fail, because there is no writer:

| statement | today | how it would be proven |
|---|---|---|
| 1. one run writes R1 and R2, both read back by key | **RED — no writer exists** | run a lane on a node, then `GET` both keys |
| 2. a control-host query sees a foreign project's run without its R1 | **RED — and unsafe until CF-208** | prefix query from the control host, then a denied R1 read |
| 3. a node cannot read another project's namespace | **RED — CF-208: same token returns 200 for two namespaces** | 403/404 from the foreign namespace |
| 4. R3 counts equal the R2 record count, recomputed | **RED — no R3 writer** | `list_keys` count vs the rollup's attributes |
| 5. the conformance `memory` leg turns green | **RED — never passed** | `tests/harness-conformance.sh` |
| 6. a killed run still leaves a record | **RED — nothing runs to kill** | kill mid-flight, then read both keys |

A specification whose verification cannot fail is a wish. Every row above is a FAIL today, which is
the correct state for a design page — and the reason its status is RED rather than VERIFIED.

## 4. Metrics emitted

None of its own. The counts this design cares about (runs, outcomes, lanes, harnesses, models served)
are the *content* of R3, computed from R2 — not a metrics pipeline. Timing beyond `started_at`/
`ended_at` is deliberately excluded: cost belongs to the scheduler's ledger, and duplicating it here
would create two truths about the same run (`specs/FLEET-MEMORY.md:139`).

## 5. Log lines it can generate

None today — no code path prints anything. The writer this design specifies must print, at minimum:

```
  PASS  run_record — /runs/<lane>/<week>/<run_id> written (namespace <project>)
  PASS  fleet_index — /factory/<project>/<week>/<lane>/<run_id> written
  FAIL  fleet_index — <status> from the index write; the run record exists, the index does not
```

The second line matters more than the first: R2 is the record the rest of the fleet reads, and a run
that writes only R1 is invisible to every query in §5 of the spec. A failed index write must therefore
be a FAIL row, not a WARN — the run happened, but nobody will ever find it.

## 6. Failure modes

| failure | direction | consequence |
|---|---|---|
| node writes R1, index write fails | **fail open to the project, fail closed to the fleet** | the project can find the run; no fleet query can |
| node writes neither (writer absent, as today) | **silent** | the run is unrecorded and indistinguishable from a run that never happened (`specs/FLEET-MEMORY.md:87`) |
| namespace is not scoped (CF-208) | **fail open** | isolation §2 depends on does not hold; any node can read any project |
| worker not staged on a new node (CF-276) | **silent** | the node has no writer at all, and the ladder does not notice |
| rollup typed by hand instead of computed | **fail open** | a plausible number that contradicts R2 |
| index entry carries code or a credential | **leak** | the shared namespace is readable by every project's token |

## 7. Environment and settings it reads

| setting | source | requirement |
|---|---|---|
| `CF_NAMESPACE` | the envelope | required; the project namespace for R1 |
| `CF_RUN_ID` | the envelope (crier) | required; the join key in both records |
| `CF_LANE` | the envelope | required; the lane segment of both keys |
| `DUCKBRAIN_URL` | node config | required; today `:3000` on the control host |
| token file | `~/.node/auth/duckbrain.token`, mode 600 | required; **path only** — a value in argv is a FAIL (AGENTS.md r8) |
| `FLEET_INDEX_NAMESPACE` | node config | default `factory`; named so a test can point it at a scratch namespace |
| week | computed | ISO-8601 `YYYY-Www`, UTC — never local time |

## 8. Evidence of record

- `specs/FLEET-MEMORY.md` (142 lines) — the design authority; line 4 states nothing is implemented.
- `specs/HARNESS-MATRIX.md:29` — I3, the invariant this page operationalises.
- `specs/HARNESS-MATRIX.md:167` — the `memory` conformance leg, never green.
- `prompts/foreman.md:36` — the foreman's obligation to write the record.
- `scripts/node-bus-worker.py:273` — the only "memory" mention in the producer, and it is a docstring.
- Board: CF-208 (namespace scoping), CF-276 (worker not staged), CF-285 (`have()` cannot report
  absence), and the rows filed with this page for R1/R2/R3 and the rollup check.

To re-establish this page's status: `grep -c duckbrain scripts/node-bus-worker.py` returns 0; when it
does not, and the six statements in `specs/FLEET-MEMORY.md:112` have been run, this module can earn
VERIFIED.
