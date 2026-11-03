# Concurrency of the code-factory selftest gate (CF-117)

Measured 2026-11-03 on the perf lane worktree (`wt/PERF-015`). Pre-fix tree
`25d1e71`; fixed tree is this commit. The concurrent probe receipts below were
measured on exactly this commit's `tests/selftest.sh` and
`docs/audits/cf089-census-standin.py`; this document was written after those runs
and changes nothing else. Host load 15-25 throughout (four lanes share it), so
every wall time below is quoted beside the load average it was taken at.

Row: **CF-117** — "two gate runs at one HEAD red each other: the census fixtures
bind literal ports 19022-19029, and a second unexplained arm reddens under
concurrency". Both halves are answered here: the first is fixed, the second is
explained and attributed to a different, already-filed defect (CF-072) that this
row is not allowed to touch.

## What the gate shares between two runs

`bash tests/selftest.sh` runs eight census arms (§22-§27) that each start
`docs/audits/cf089-census-standin.py` — a real HTTP fixture serving 866 rows with
`offset=500` failing in the selected mode — and drive
`docs/audits/cf089-census-recipe.sh` (the README census block, verbatim) against
it through real `curl` and `jq`. Until this change the fixture was started on a
**literal** port: 19022 (fetch), 19023 (broken), 19024/19025/19026
(missing-projects, wrong-projects, nonjson), 19027 (short), 19028 (healthy),
19029 (nototal).

Ports are host-global. Four code-factory lanes run this same suite in the same
scheduler slot, so two gate instances on this host want the same eleven socket
addresses at the same moment. Nothing in the suite serialises them.

## Defect A — the literal census ports (fixed here)

Two distinct failure shapes, both reproduced deterministically at `25d1e71`
(script: `cf117-prefix-proof.sh`, kept in the lane scratch dir, not committed):

```
-- stand-in at this HEAD has no --port-file: 0 hits
-- A: run 1 takes literal 19022 (mode healthy)
-- B: run 2 starts on the SAME literal port (mode fetch); its own bind must fail
       ~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^
   OSError: [Errno 98] Address already in use
-- B's readiness poll would instead have hit A's server:
   curl_status=200
-- A released the port; B's mid-arm fetch (curl 7):
   curl: (7) Failed to connect to 127.0.0.1 port 19022 after 0 ms: Could not connect to server
```

1. **The loser never starts.** `HTTPServer(("127.0.0.1", 19022), H)` raises
   `OSError: [Errno 98] Address already in use`; `cf089_run` then reports
   `fixture did not start: ...` and the arm goes red at `rc=99`.
2. **The loser starts without a server.** The readiness poll is a `curl` against
   the port, not against *its own* server. If the other run holds the port, the
   poll answers `200` from the **other** run's fixture (`curl_status=200` above),
   so `cf089_run` proceeds believing it is ready. When the other run's fixture
   exits and releases the port, the mid-arm fetch dies with
   `curl: (7) Failed to connect to 127.0.0.1 port 1902x`.

Two-arm control receipt, as filed on the row (two simultaneous whole-gate runs in
two fresh clones of `25d1e71`): arm A `rc=1 SELFTEST: FAIL (7)` with all seven
census assertion rows red on `Failed to connect to 127.0.0.1
port 1902{2,3,4,5,6,7,9}`, arm B `rc=0 SELFTEST: PASS`. The winner keeps the
whole census section; the loser loses it entirely.

## The fix

`docs/audits/cf089-census-standin.py`

* keeps `--port` unchanged (default 18999, so `cf089-make-transcript.sh` still
  works as documented);
* adds `--port-file PATH`: after `HTTPServer(("127.0.0.1", port), H)` binds, it
  writes `server.server_port` to `PATH.tmp`, `fsync`s it and `os.replace`s it onto
  `PATH`, so a reader never sees a half-written or stale-readable file;
* prints the chosen port to stdout as well, so a killed-before-publish failure is
  still diagnosable from `server.log`.

With `--port 0` the kernel assigns an ephemeral port, so no two runs can want the
same one. Fixture semantics are untouched: 866 rows, 502 at `offset=500`, the same
eight modes, two code-factory rows at index 0 and 600.

`tests/selftest.sh` (`cf089_run`, §22-§27)

* starts the stand-in with `--port 0 --port-file "$tmpd/port"`, inside the same
  `timeout 20s` bound;
* waits for that file to be non-empty **and** for the readiness `curl` to answer
  on the published port, inside the same `50 x 0.05 s` budget, still bailing out
  early if the fixture process dies;
* uses the published port for the readiness probe, for the `BASE` handed to the
  census recipe, and in the `fixture did not start on port ...` text;
* call sites are `cf089_run fetch|broken|missing-projects|wrong-projects|nonjson|
  short|healthy|nototal`, and the §24 loop no longer increments a literal port, so
  no port literal remains in the suite (grep for `1902` in `tests/selftest.sh`:
  no hits).

Every expected message is byte-identical to before (`census: fetch failed at
offset=500`, `census: HTTP 502 at offset=500; refusing to count`, `census: missing
or invalid .projects array at offset=500`, `census: rows received=865 != total
reported=866; refusing to count`, `census: the scheduler answered without a
total; refusing to count`), as is every `PASS` row name and its assertion
strength. No row was deleted, renamed, weakened or skipped: the file still has 53
`say "  PASS` sites, and the sorted row-name set is identical to both `25d1e71`
and the reviewed HEAD.

## Post-fix receipts

Gate syntax (acceptance A):

```
bash -n tests/selftest.sh -> rc=0
py_compile -> rc=0
```

One whole gate at load average 13.08 falling to 11.91 (acceptance B):

```
rc=0 wall_ms=10963 SELFTEST: PASS
PASS rows printed: 88  FAIL rows: 19
```

The 19 `FAIL` lines are *echoed child output* — the board-validator fixtures print
their expected `FAIL  board line 2: ...` lines as evidence while their own
assertion row passes. Gate verdict is `SELFTEST: PASS`, `rc=0`. §22-§27 and §28:

```
22. census refuses a failed fetch at a later offset
  PASS  census fetch failure -> offset=500, exit 1, no census printed
23. census refuses a non-2xx page
  PASS  census HTTP 502 -> offset=500, exit 1, no census printed
24. census requires a projects array even on HTTP 200
  PASS  census missing-projects -> named .projects refusal, exit 1, no census printed
  PASS  census wrong-projects -> named .projects refusal, exit 1, no census printed
  PASS  census nonjson -> named .projects refusal, exit 1, no census printed
25. census compares all received rows with the first reported total
  PASS  census short page -> rows received=865, total reported=866, exit 1, no census printed
26. healthy census counts matching rows on both sides of the page boundary
  PASS  census healthy -> 2 matching rows, exact row format, exit 0
27. census still refuses a missing total
  PASS  census missing total -> named refusal, exit 1, no census printed
28. README census and executable mirror agree except for BASE
  PASS  census README/mirror byte parity (BASE parameterisation only)
```

Two-arm concurrent control (`cf117-probe.sh`: two simultaneous whole-gate runs in
two fresh clones of this HEAD), four rounds, verbatim:

```
a_rc=0 a_summary=SELFTEST: PASS unique_red_rows=1
    disk_floor — resolver missing or unreadable: /var/tmp/hermes-scratch/tmp.CeVKOFhPtF/scripts/disk_floor.py
b_rc=0 b_summary=SELFTEST: PASS unique_red_rows=1
    disk_floor — resolver missing or unreadable: /var/tmp/hermes-scratch/tmp.nSPktABBNJ/scripts/disk_floor.py
port_red_lines=0
loadavg=14.72 16.03 18.78 6/9373 1749346

a_rc=1 a_summary=SELFTEST: FAIL (1) unique_red_rows=2
    auth marker {"status":"ok"} was not refused (exit 0)
    disk_floor — resolver missing or unreadable: /var/tmp/hermes-scratch/tmp.S3sbTB72HA/scripts/disk_floor.py
b_rc=0 b_summary=SELFTEST: PASS unique_red_rows=1
    disk_floor — resolver missing or unreadable: /var/tmp/hermes-scratch/tmp.VEbrsTgrpH/scripts/disk_floor.py
port_red_lines=0
loadavg=15.71 16.14 18.75 6/9426 1761619

a_rc=0 a_summary=SELFTEST: PASS unique_red_rows=1
    disk_floor — resolver missing or unreadable: /var/tmp/hermes-scratch/tmp.jd9Dx20nUu/scripts/disk_floor.py
b_rc=0 b_summary=SELFTEST: PASS unique_red_rows=1
    disk_floor — resolver missing or unreadable: /var/tmp/hermes-scratch/tmp.mhaDcxQ8Ah/scripts/disk_floor.py
port_red_lines=0
loadavg=13.97 15.49 18.36 8/9459 1782129

a_rc=0 a_summary=SELFTEST: PASS unique_red_rows=1
    disk_floor — resolver missing or unreadable: /var/tmp/hermes-scratch/tmp.YmdpL9m2R3/scripts/disk_floor.py
b_rc=0 b_summary=SELFTEST: PASS unique_red_rows=1
    disk_floor — resolver missing or unreadable: /var/tmp/hermes-scratch/tmp.FRTHNwj8lW/scripts/disk_floor.py
port_red_lines=0
loadavg=14.00 15.44 18.32 7/9426 1789258
```

`port_red_lines=0` in every round: no bind failure and no
`Failed to connect to 127.0.0.1 port 190` line survives in either arm. The
`disk_floor` entry is the suite's intentional row whose path changes per run, so
it is never byte-identical across runs.

Round 2's single extra red is **not** a port red and is not caused by this
change; it is the unrelated shared-path defect documented under "Residual" below.

Census arms specifically, three further rounds of the same two-arm control with
logs kept, per arm (an arm being one whole gate instance):

```
== round 1 wall=19s loadavg=12.43 14.39 17.65
   arm a rc=0 SELFTEST: PASS census_pass=9 census_fail=0 port_red=0
   arm b rc=0 SELFTEST: PASS census_pass=9 census_fail=0 port_red=0
   census row-name diff a-vs-b: identical
== round 2 wall=14s loadavg=15.25 14.97 17.79
   arm a rc=0 SELFTEST: PASS census_pass=9 census_fail=0 port_red=0
   arm b rc=0 SELFTEST: PASS census_pass=9 census_fail=0 port_red=0
   census row-name diff a-vs-b: identical
== round 3 wall=11s loadavg=14.44 14.81 17.70
   arm a rc=0 SELFTEST: PASS census_pass=9 census_fail=0 port_red=0
   arm b rc=1 SELFTEST: FAIL (1) census_pass=9 census_fail=0 port_red=0
      RED   FAIL  auth stats 403 did not produce named PASS (exit 1)
   census row-name diff a-vs-b: identical
```

All nine census rows (§22-§27 plus §28 mirror parity) pass in both arms of every
round, and the two arms' census row sets are identical — the property the ports
defect destroyed.

## Residual — §17 shares `/tmp/node-status.json` (CF-072, not fixed here)

`scripts/verify-node.sh:42` writes the gateway status body to the **fixed** path
`/tmp/node-status.json` and line 45 greps that same path:

```
42:code=$(curl -s -o /tmp/node-status.json -w '%{http_code}' --max-time 8 "$url" ...)
45:  grep -Eq '"auth_required"[[:space:]]*:[[:space:]]*true[[:space:]]*[,}]' /tmp/node-status.json ...
```

§17's fixture drives that real script (`cf077_run`) fourteen times per gate run,
each with a different `STATUS_BODY`. Two concurrent gate runs therefore write and
read one host-global file: run A can grep run B's body. A body *without*
`auth_required` then reports `auth_gate` as passing, `verify-node.sh` exits 0, and
the assertion row `auth marker {"status":"ok"} -> named auth_gate FAIL` goes red —
and symmetrically a body *with* `auth_required` can be read as missing it, which
reds `auth stats <code>` rows.

Proof by injection (the stub answers exactly as §17's stub does, plus a
write→return delay so the real read-after-write window is observable):

```
== leg2: 7/12 concurrent A-arms returned exit 0 while their own body carried no auth_required
== leg2 sample arm-A output with cross-talk:
     PASS  auth_gate — auth_required:true (a public bind must not be open)
   VERIFY: PASS
```

That is the whole defect: 7 of 12 arms that must refuse read another run's body
and certified a gate they never measured.

It is **pre-existing and independent of this change**: the same reds occur at
`25d1e71`, where `scripts/verify-node.sh` is byte-identical to this HEAD, e.g.

```
a_rc=0 a_summary=SELFTEST: PASS unique_red_rows=1
b_rc=1 b_summary=SELFTEST: FAIL (1) unique_red_rows=2
    auth stats 401 did not produce named PASS (exit 1)
```

Three observable shapes, all from the one path: `auth marker {"status":"ok"} was
not refused (exit 0)`, `auth stats 401 did not produce named PASS (exit 1)`,
`auth stats 403 did not produce named PASS (exit 1)`.

It is left as it is here, deliberately, for two reasons:

1. **Scope.** This row's change set is three files (`cf089-census-standin.py`,
   `tests/selftest.sh`, this document); `scripts/verify-node.sh` is outside it,
   and no assertion may be loosened to hide the race.
2. **Ownership.** The defect is already filed as **CF-072** (P4, pending), whose
   acceptance criteria name it exactly: "verify-node.sh writes its status body to
   a per-run `mktemp` path (removed on exit), not `/tmp/node-status.json`, and the
   auth_gate grep reads that path", alongside the `|| echo 000` sweep at
   `verify-node.sh:42,53`. Fixing half of CF-072 from this row would leave that
   row half-landed for its own worker.

The correct remedy, for whoever takes CF-072: bind the body path per invocation
(`status_body=$(mktemp)` plus `trap 'rm -f "$status_body"' EXIT`, then `curl -o
"$status_body"` and grep `"$status_body"`) — one file, no assertion change. No
lock or serialisation was added to `tests/selftest.sh` instead, because a lock
would make the gate green while the same race still hands real operators a wrong
`VERIFY: PASS`.

So the gate is concurrency-safe **for the census section this row owns**, and two
concurrent runs still red each other roughly a third of the time through CF-072's
path until that row lands.

## Reproduction

```
bash -n tests/selftest.sh && python3 -m py_compile docs/audits/cf089-census-standin.py
bash tests/selftest.sh                                   # SELFTEST: PASS, rc=0
bash ~/.hermes/cache/scratch/cfp-20261103/cf117-probe.sh # two concurrent gates, this HEAD
```

Deterministic single-port proofs (pre-fix and post-fix) live in
`~/.hermes/cache/scratch/cfp-20261103/cf117-prefix-proof.sh`, the two-arm census
identity run in `cf117-leg1.sh`, and the §17 injection proof in
`cf117-evidence.sh`.
