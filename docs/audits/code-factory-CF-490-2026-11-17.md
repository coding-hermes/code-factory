# CF-490 — a spawn-stage refusal is classified as a host-capability refusal

Branch `cf490-host-spawn-class`, base `70d02621` (origin/main), an isolated worktree under the
scratch cache. Date 2026-11-17.

Everything below is a transcript of a command that was run in this worktree. Nothing here claims a
live bunker run: the live refusals are quoted from the two measurements recorded on the board row,
and every gate in this file is an offline fixture.

## 1. The finding (measured twice, 2026-11-17, main checkout)

`scripts/node-create.sh` (spawn stage) handed back bunkerd's internal vocabulary with no class and
no next action:

```
FAIL  spawn — failed; log=/mnt/ssd/tmp/cf-spawn-node-dogfood-probe-061457-HAmFH3.log; final diagnostic: bunker: spawn agent: internal: spawn node-dogfood-probe-061457 failed at stage slice-limits: containment landing did not converge within 40 reads: containment landing: memory.swap.max = "max", want "0" (bar swap)
```

The second measurement of the same unsatisfiable state printed `within 5 reads`, so the number reads
like a flake counter while the refusal is deterministic. `grep -rn
'slice-limits\|containment landing\|swap.max'` over the tree returned 0 hits, and neither README
"Quick start" nor `docs/OPERATIONS.md` said the TARGET server has to be spawn-capable: step 1
(`bunker-server-install.sh --check`) qualifies the CONTROL host only.

## 2. What changed

- `scripts/node-create.sh` — spawn failure branch: when the final diagnostic names the container
  slice (`slice-limits`, `containment landing`, `bar swap`, `memory.swap.max`) the run prints one
  `FAIL host — <server> cannot spawn an agent: <stage>` row plus exactly one remedy line naming the
  host setting and the `bunker status --server <name>` preflight, and keeps the per-run log path and
  the final diagnostic (CF-056). Every other spawn refusal keeps the plain `FAIL spawn` row.
- `tests/selftest.sh` — the stub bunker gains `FIXTURE_SPAWN_DIAG` (default unchanged, so CF-056
  still measures its quota arm), and §16 gains the `cf490-host-spawn-class` fixture: post-fix arm +
  a red control against the pre-fix script at `70d02621`.
- `README.md`, `docs/OPERATIONS.md` — the target-server prerequisite beside step 3 / the node
  preflight, each citing the fixture.
- `docs/handbook/chapters/M1-provisioning.md` — new `III.M1.S1` (target-server spawn capability) and
  a `III.M1.S2` paragraph on the refusal class, plus a §7 verification row and a §10 failure-mode
  row.

Re-runnable proof script for this file: `docs/audits/cf490-host-spawn-proof.sh` (three arms + the
two doc greps; prints `CF490-PROOF: PASS` and exits 0).

## 3. (a) pre-fix run — same diagnostic, no class

```
$ bash docs/audits/cf490-host-spawn-proof.sh     # ARM A section
=== ARM A — pre-fix (70d02621:scripts/node-create.sh), slice-limits diagnostic ===
node-create — project=fixture harness=hermes server=fixture-server
  ..    spawning node-fixture-072445 (ttl 6h)
  FAIL  spawn — failed; log=/mnt/ssd/tmp/tmp.PVJPRh7n4F/runtime/cf-spawn-node-fixture-072445-SVE5ZZ.log; final diagnostic: bunker: spawn agent: internal: spawn node-fixture-000000 failed at stage slice-limits: containment landing did not converge within 40 reads: containment landing: memory.swap.max = "max", want "0" (bar swap)
rc=1  FAIL-host rows=0  FAIL-spawn rows=1  remedy lines=0
PASS  pre-fix refusal is unclassified: no host class, no remedy, diagnostic kept
```

rc of the node-create call: **1**; `FAIL host` rows **0**; remedy lines **0**.

## 4. (b) post-fix run — the classified row

```
$ bash docs/audits/cf490-host-spawn-proof.sh     # ARM B section
=== ARM B — post-fix (this tree), same slice-limits diagnostic ===
node-create — project=fixture harness=hermes server=fixture-server
  ..    spawning node-fixture-072446 (ttl 6h)
  FAIL  host — fixture-server cannot spawn an agent: slice-limits; log=/mnt/ssd/tmp/tmp.PVJPRh7n4F/runtime/cf-spawn-node-fixture-072446-QtQy7O.log; final diagnostic: bunker: spawn agent: internal: spawn node-fixture-000000 failed at stage slice-limits: containment landing did not converge within 40 reads: containment landing: memory.swap.max = "max", want "0" (bar swap)
  ..    remedy: fixture-server must let bunkerd land its per-agent slice — enable cgroup v2 swap accounting on that host so memory.swap.max can be set to 0; preflight the target from here with: bunker status --server fixture-server
rc=1  FAIL-host rows=1  FAIL-spawn rows=0  remedy lines=1  log=...
PASS  one FAIL host row (fixture-server, stage slice-limits) + one remedy line, log file exists, diagnostic verbatim
```

rc **1**; `FAIL host` rows **1**; `FAIL spawn` rows **0**; remedy lines **1**; the named log file
exists; the final diagnostic appears verbatim.

## 5. (c) red-control run — the fixture can fail

Arm A above IS the red control: the same stub, the same env, the SAME assertion set, run against the
real pre-fix tree (`git show 70d02621:scripts/node-create.sh` + the `project-node.sh` of the same
revision), which prints only the bare `FAIL spawn` row. Inside the suite that arm is a first-class
fixture row:

```
  PASS  CF-490 host spawn refusal -> one FAIL host row (fixture-server, stage slice-limits) + one remedy line, log /mnt/ssd/tmp/tmp.aYDfNbgtdA/runtime/cf-spawn-node-fixture-072521-yPWXcX.log and the diagnostic kept verbatim
  PASS  CF-490 red control: the pre-fix script prints only the bare FAIL spawn row (0 host rows, 0 remedy lines) — this fixture can fail
```

Non-host refusal (CF-056 regression arm, quota exhausted) still unclassified:

```
$ bash docs/audits/cf490-host-spawn-proof.sh     # ARM C section
=== ARM C — quota refusal keeps the FAIL spawn row (CF-056) ===
node-create — project=fixture harness=hermes server=fixture-server
  ..    spawning node-fixture-072447 (ttl 6h)
  FAIL  spawn — failed; log=/mnt/ssd/tmp/tmp.PVJPRh7n4F/runtime/cf-spawn-node-fixture-072447-SXexR0.log; final diagnostic: fixture spawn refused: quota exhausted
rc=1  FAIL-host rows=0  FAIL-spawn rows=1
PASS  a non-host refusal is still the plain FAIL spawn row
```

The suite's own CF-056 fixture also stays green:
`PASS  CF-056 spawn/staging failure names unique log … and emits no provision PASS`.

## 6. (d) documentation greps

```
grep -c 'target server must be spawn-capable' README.md -> 2 (rc=0)
grep -c 'cf490-host-spawn-class' README.md -> 2 (rc=0)
grep -c 'target server must be spawn-capable' docs/OPERATIONS.md -> 1 (rc=0)
grep -c 'cf490-host-spawn-class' docs/OPERATIONS.md -> 1 (rc=0)
```

## 7. Gates

```
$ bash -n scripts/node-create.sh   # rc=0
$ bash -n tests/selftest.sh        # rc=0
$ bash tests/selftest.sh > "$TMPDIR/cf490-selftest.log" 2>&1; echo RC=$?
SELFTEST: PASS
EXIT=0
RC=0
```

598 `PASS` fixture rows; the suite verdict is `SELFTEST: PASS`. The 61 `  FAIL` lines in the log are
inside captured fixture output (the negative arms whose whole point is to print a FAIL); no fixture
row itself failed.

`ruff` host condition (board row CF-487): `which ruff` -> `~/.local/bin/ruff`, `ruff
--version` -> `0.15.22`, i.e. the version that passes the section 51 tracked-python lint arm. The arm
is green in this run; nothing in this row touches a tracked `.py` file.

## 8. What is NOT verified

- No live bunker run. The `FAIL host` classification is proven against a stub whose diagnostic is the
  verbatim live text; that a real host's `bunkerd` prints the same text is the recorded measurement
  on the board row, not something this fixture can re-measure.
- The host fix itself (cgroup v2 swap accounting so `memory.swap.max` can be 0) is a host-owner step
  outside this repository. Nothing here enables it, and the remedy line says so.
- `bunker status --server <name>` is named as the preflight but was not run here: there is no bunker
  server in this worktree's environment.
