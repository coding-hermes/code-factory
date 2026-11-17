# Dogfood — the node-create leg (README "Quick start" step 3)

Tick `code-factory-dogfood-2026-11-17-10-10-24`, third delivery, at `db42390d` (= `origin/main`,
parity 0/0, clean tree). Companion to `2026-11-17-dogfood-path.md`, which walked steps 1 and 2 and
left this leg **unverified**. This record is that leg, walked against real hosts.

## The promise this leg tests

`README.md` "Quick start" step 3:

> `scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes`
>
> On a host with no bunker server, no Crier and no repo, all three commands reach their checkers and
> fail with the missing value named. That is the honest result on a fresh host, and every message
> tells you which value to supply.

The actor here is not missing infrastructure: it is a host where steps 1 and 2 have a live answer.
So the question is narrower than "does it refuse politely" — it is **whether the documented command
can produce a node at all**, which is what the repo's own Status table still lists as unmeasured
("No created node has been measured live by this repository").

## What was used

| Input | Value |
|---|---|
| `CRIER_URL` | a live crier answering on the loopback port the fleet uses (`:8767`) |
| `BUNKER_SERVER` | `bunker-las-03` (arm 1), then `bunker-las-02` (arm 2) — both `ONLINE`, both `0/8` agents |
| `--repo` | `https://github.com/github/gitignore` — the public fixture the repo's own Status table already uses for the clone measurement |
| `--harness` | `hermes` |
| `--ttl` | `2h` (shorter than the 6h default, so a probe agent cannot outlive its usefulness) |

Both hosts answered `bunker status --server`: `bunker-las-03` up 5d 13h, disk 78 %; `bunker-las-02`
disk 64 %. `bunker-las-01` and `bunker-las-04` were `OFFLINE` (`dial tcp … i/o timeout`) and were not
used.

## Arm 0 — the manifest, before any bunker call

`scripts/node-create.sh --staged-files --project dogfood-probe --repo <fixture> --harness hermes`
exits 0 in 0.42 s and prints a 14-file staging manifest (`project-node.sh`, `lib.sh`,
`disk_floor.py`, `reclaim_disk.py`, `node_gateway_auth.py`, `node_hygiene.py`, `gomodcache.py`,
`deploy_key.py`, `node-bus-worker.py`, `install-go.sh`, `install-node.sh`,
`harness/harness-vars.sh`, `harness/harness_memory.py`, `harness/install-hermes.sh`). This leg holds
up: it validates the runtime references without needing a host.

## Arm 1 — `bunker-las-03`, the documented command, unmodified

```
node-create — project=dogfood-probe harness=hermes server=bunker-las-03
  ..    spawning node-dogfood-probe-061457 (ttl 2h)
  FAIL  spawn — failed; log=/mnt/ssd/tmp/cf-spawn-node-dogfood-probe-061457-HAmFH3.log; final
        diagnostic: bunker: spawn agent: internal: spawn node-dogfood-probe-061457 failed at stage
        slice-limits: containment landing did not converge within 40 reads: containment landing:
        memory.swap.max = "max", want "0" (bar swap)
```

rc 1, 27.19 s wall.

## Arm 2 — `bunker-las-02`, the SAME command, only `BUNKER_SERVER` changed

```
node-create — project=dogfood-probe harness=hermes server=bunker-las-02
  ..    spawning node-dogfood-probe-062006 (ttl 2h)
  FAIL  spawn — failed; log=/mnt/ssd/tmp/cf-spawn-node-dogfood-probe-062006-maOBKj.log; final
        diagnostic: bunker: spawn agent: internal: spawn node-dogfood-probe-062006 failed at stage
        slice-limits: containment landing did not converge within 5 reads: containment landing:
        memory.swap.max = "max", want "0" (bar swap)
```

rc 1, 20.59 s wall.

## What held up

- The gate order is honest: the script refused to spawn without both env values on earlier arms, and
  with both supplied it reached bunkerd rather than dying in its own argument parsing.
- The failure is **not swallowed**: rc is 1, the row is prefixed `FAIL`, the bunkerd log path is
  printed and the final diagnostic is quoted. (The swallowed-failure class in this script is
  `CF-056`; this is not that.)
- Nothing is left behind at the agent level: `bunker --server <host> list` reports `No agents found`
  on both hosts after both failures, so the refused spawn did not strand an object a user must clean.
- The manifest arm (`--staged-files`) is fast, deterministic and host-free.

## Where it broke — for the reader who is the user

The failure is a **host containment prerequisite** that appears nowhere in this repository. Two
independent ONLINE hosts, two different read budgets (40 and 5), the same unsatisfiable assertion:
bunkerd's per-agent slice asks for `memory.swap.max = 0`, the host reports `"max"`, and containment
never lands. So on this fleet the documented step 3 cannot complete anywhere — not a flaky host, not
a code path in this repo.

What that costs a stranger walking the docs literally:

1. **Step 1 cannot warn.** `bunker-server-install.sh --check` qualifies the *control* host — bunker
   CLI present, crier reachable, disk floor. It never asks whether the *target* server can spawn, so
   the documented path has no step where this is discoverable before step 3.
2. **The message is a stage name, not a remedy.** `slice-limits`, `containment landing` and
   `bar swap` are bunkerd's vocabulary. Nothing in the row, the README or `docs/OPERATIONS.md` says
   "enable cgroup v2 swap accounting on the host", "try another `--server`", or "check
   `bunker status --server <name>` first" — `grep -rn 'slice-limits\|containment landing\|swap.max'`
   over the tree returns 0 hits.
3. **The retry counter reads like a flake.** "within 40 reads" vs "within 5 reads" for a
   deterministic misconfiguration invites a retry loop; each attempt costs 20–30 s and fails the same
   way.

What a new user would have done next, absent a doc: run it again, then assume the repo is broken and
file a bug against the factory — which is exactly the wrong owner for this failure.

## Unverified / not claimed

- **Slice-level residue below the agent list** was not measured. With no agent there is no exec path
  into the hosts, and `bunker reap` / `bunker homes` reject `--server`, so they can only act on the
  active server. Recorded as unverified, not as clean.
- **The host-side fix** (cgroup v2 swap accounting so the write lands and reads back `0`) is an ops
  action on hosts this lane does not own; nothing here proves that setting is the only cause.
- **A successful node create was not observed.** This record is the honest result of trying, twice,
  on the only two hosts that answer.

## Rows filed

| Row | P | What it owns |
|---|---|---|
| `CF-489` | P1 | No ONLINE node host in this fleet can spawn: step 3 dies at `slice-limits` on both answering hosts. Evidence + the host setting named + the doc no longer implying a working path. |
| `CF-490` | P2 | The spawn refusal is unclassified passthrough: no `FAIL host` class, no remedy line, and the prerequisite appears in no document. Fixture + docs, one commit. |

Chapters changed: `III.M1.S1` (qualify the host) and `III.M1.S2` (create the container), both noted
on the rows.

## Reproduce

```bash
export CRIER_URL=http://127.0.0.1:8767          # a live crier
export BUNKER_SERVER=<an ONLINE bunker server>  # bunker status --server <name> first
scripts/node-create.sh --project dogfood-probe \
  --repo https://github.com/github/gitignore --harness hermes --ttl 2h
```

Transcripts, unedited except for the `~` substitution noted in the evidence `INDEX.md`:
`.coding-hermes/evidence/code-factory-dogfood-2026-11-17-10-10-24/step3-*`, with the two launchers
(`step3-nodecreate-las03.sh`, `step3-nodecreate-las02.sh`) beside them so the arms can be re-run
byte-for-byte.
