# CF-479 — the working-room arm could not refuse on this host

Measured on the readme lane tick `code-factory-readme-2026-11-17-02-40-53`, re-verified at
`origin/main` `feda6bd4`. The arm under test is
`tests/test_node_provisioning.py::NodeFootprint.test_working_room_shortfall_is_a_refusal`.

ch:trace row=CF-479 spec=docs/ACCEPTANCE-PLAN.md#requirement-to-test-matrix test=tests/test_node_provisioning.py::NodeFootprint.test_working_room_shortfall_is_a_refusal doc=docs/audits/cf479-working-room-arm-evidence.md prompt=none:lane-brief evidence=docs/audits/cf479-working-room-arm-evidence.md witness=path@origin:docs/audits/cf479-working-room-arm-evidence.md verdict=none:not-yet-judged commit=none:self-referential-hash memory=/project/code-factory/readme-audit-2026-11-17-02-40-53

## 1. The defect

`setUp` builds its fixture with `tempfile.TemporaryDirectory()`, so the measured volume is whatever
`TMPDIR` points at. On this host `TMPDIR` is a 1.8 TiB volume, and the arm demanded a fixed
`--working-room-mib 1000000` (977 GiB) while expecting a refusal. The demand fit, the check passed,
and the assertion inverted:

```
$ python3 -m unittest tests.test_node_provisioning.NodeFootprint.test_working_room_shortfall_is_a_refusal
FAIL: test_working_room_shortfall_is_a_refusal (tests.test_node_provisioning.NodeFootprint)
  File "tests/test_node_provisioning.py", line 580, in test_working_room_shortfall_is_a_refusal
    self.assertNotEqual(result.returncode, 0)
AssertionError: 0 == 0
Ran 1 test ... FAILED (failures=1)
```

The same demand measured at a fixture root on `$TMPDIR`:

```
$ python3 scripts/node_hygiene.py footprint --root "$T" --modcache "$T" --working-room-mib 1000000
  PASS  footprint — 0.0 MiB measured at "$T": repo 0.0 MiB, ... modcache 0.0 MiB
  PASS  footprint:room — 1000000.0 MiB required (0.0 MiB + 1000000 MiB working room),
        1824544.5 MiB free, headroom 824544.5 MiB
rc=0
```

So the refusal branch is unreachable on any volume with more than ~977 GiB free, and because
`bash tests/selftest.sh` §58 runs this battery, the whole Tier-1 gate is red on such a host. The
product code is correct: `scripts/node_hygiene.py` refuses exactly when the demand exceeds the free
space it measures. The arm, not the product, hard-coded one machine's disk size.

## 2. The fix

The arm derives its demand from the volume the fixture actually runs on
(`shutil.disk_usage(self.root).free // 1048576` — `shutil` is already imported at line 36) and
asserts BOTH directions:

- at `free_mib // 2` the same command exits 0 and prints `PASS  footprint:room` — the acceptance
  direction, which the old arm never exercised;
- at `free_mib + 1024` the command exits nonzero and prints `FAIL  footprint:room` / `short` — the
  refusal the row asks for, now always above the measured free space.

## 3. Proof, three runs

GREEN — fixed arm, same host, same `TMPDIR`:

```
$ python3 -m unittest tests.test_node_provisioning.NodeFootprint
test_components_add_up_and_admission_passes ... ok
test_total_above_the_floor_is_a_refusal ... ok
test_working_room_shortfall_is_a_refusal ... ok
Ran 4 tests ... OK     (rc=0)
```

RED CONTROL — the arm still fails when the behaviour it guards is removed. Applying
`if True:` in place of `if free >= required:` in `scripts/node_hygiene.py` (refusal path
unreachable) and re-running the fixed arm:

```
$ python3 -m unittest tests.test_node_provisioning.NodeFootprint.test_working_room_shortfall_is_a_refusal
FAIL: test_working_room_shortfall_is_a_refusal
AssertionError: 0 == 0
FAILED (failures=1)     (rc=1)
```

`scripts/node_hygiene.py` was restored from the index afterwards (`git diff` on it is empty), so the
red control is a measurement of the guard, not a change that ships.

ORIGINAL RED at the published tip — the unfixed arm at `feda6bd4`, quoted in §1 above.

## 4. The repository gate

```
$ bash tests/selftest.sh
...
SELFTEST: PASS
EXIT=0
```

71 numbered sections, run for real on this host in the landing tree (377 s), with the same `TMPDIR`
that made the old arm fail. §58's battery is the arm this row is about.
