# PERF-016 — resolve the git binary once instead of PATH-probing it on every spawn

Audit of the change tracked by board row `PERF-016`. Measurement-only lane
(`code-factory-perf`), tick `code-factory-perf-2026-11-04-09-53-51`.

## What the change is

`scripts/lane_target.py` and `tests/test_lane_target.py` launch every git call as a bare
`git` in `argv`. CPython's `execvp` therefore walks `PATH` and issues one failing `execve`
per entry before it reaches the real binary. The change resolves the binary once at import
time (`shutil.which("git")`) and reuses it for every `_git` call.

Two files, no output change, no assertion change, no exit-code change.

## Result, in one line

The resolvable result is the syscall count, **not** CPU: `execve` attempts drop
**2401 → 168** and `ENOENT` PATH probes **2294 → 61**, while the paired CPU ranges
overlap, so no CPU win is claimed.

## Method

Two fresh clones of the published tip `2bb114fd`, one at tip (`base`) and one with the
patch applied (`patch`). Arms alternated back-to-back **inside one window**. Timing with
`/usr/bin/time -p`; `user+sys` is the reported CPU figure. Load average was read before and
after every arm.

```
bash paired.sh <root-with-base-and-patch-clones> <out-dir>
```

Unit arm: `python3 -B tests/test_lane_target.py` (40 tests).
Gate arm: `bash tests/selftest.sh` (the repo's CI-equivalent gate; this repo ships no GitHub
Actions workflow).

Load regime for the whole window: **6.84 → 8.50 (1-minute average)**.

| Group | unit base CPU | unit patch CPU | gate base CPU | gate patch CPU |
|---|---|---:|---:|---:|
| 1 | 1.83 s | 1.85 s | 18.48 s | 16.71 s |
| 2 | 1.88 s | 1.64 s | 16.46 s | 16.11 s |
| 3 | 1.53 s | 1.56 s | 15.74 s | 15.83 s |
| **mean** | **1.747 s** | **1.683 s** (−3.7 %) | **16.89 s** | **16.22 s** (−4.0 %) |

Ranges **overlap** in both arms — unit base min 1.53 < patch max 1.85; gate base min 15.74 <
patch max 16.71. Per the row's acceptance criterion 1, that means **no CPU win is claimed**.
The percentages are quoted only so the reader can see they are inside the noise band; the
series' measured instrument floor on this gate is ~1.4 s CPU across windows, which is larger
than either delta.

## Deterministic arm (acceptance criterion 4)

```
d=$(mktemp -d); strace -f -e trace=execve -o "$d/x.log" python3 -B tests/test_lane_target.py >/dev/null 2>&1; echo "execve=$(grep -c 'execve(' "$d/x.log") enoent=$(grep -c ENOENT "$d/x.log")"
```

| Tree | `execve` attempts | of which `ENOENT` |
|---|---:|---:|
| base `2bb114fd` | **2401** | **2294** |
| + PERF-016 | **168** | **61** |

Requirement was ≤ 500 attempts from a baseline ≥ 2500, and ≤ 200 `ENOENT` from ~2294.
Both hold with margin. This is the invariant that has reproduced identically in six
independent load regimes across five tips.

## Gate health (acceptance criteria 2 and 3)

| Check | base | patch |
|---|---|---|
| `python3 -B tests/test_lane_target.py` | `Ran 40 tests`, `OK`, rc 0 | `Ran 40 tests`, `OK`, rc 0 |
| `bash tests/selftest.sh` | `SELFTEST: PASS`, rc 0 | `SELFTEST: PASS`, rc 0 |
| `^  PASS` rows | 193 | 193 |
| `^  FAIL` rows | 50 | 50 |
| of which echoed expected refusals | 31 | 31 |
| of which genuine fixture failures | 19 | 19 |

The 31 "echoed" rows are `FAIL  gateway_start …` lines the auth fixture prints as assertion
evidence after matching them against the installer's output; the arm itself prints `PASS` and
never increments the failure counter. Counting `^  FAIL` across tips therefore compares
coverage shape, not health.

PASS row text is identical between the two trees except one dynamic field:

```
PASS  flock-held lock -> HELD (HELD holder=pid-####)
```

i.e. the board-lock adjudicator reports the live holder's PID. No row was added, removed or
re-worded by this change.

## What was measured vs what was projected

- **Measured**: execve/ENOENT counts (2401 → 168 / 2294 → 61), 40 tests `OK`, gate green with
  193 PASS rows and identical row text, paired CPU in one quoted regime.
- **Projected / not claimed**: any CPU speedup. One earlier regime (load 11–21) did resolve a
  −13 % unit / −11 % gate delta; six regimes later, four are inside the noise band. The honest
  framing is syscall hygiene: each `tests/test_lane_target.py` run stops issuing ~2294 failing
  `execve` calls.
- **Remaining floor**: the gate is spawn-bound and this change removes failing `execve` calls,
  not spawns. It does not touch the largest sections (§10 installer matrix, §11 unit test
  wall time, §16 node-create fixtures), so no material gate speedup should be expected from it.

## Reproduce

```
git clone https://github.com/coding-hermes/code-factory.git base
git clone base patch
git -C patch apply PERF-016-git-binary-resolve.patch    # 852 B, sha256 2bc926cb…234eed
```

Then run the unit arm and the gate arm in both clones, alternating, and read `user+sys` from
`/usr/bin/time -p`. Quote the load average beside every number: the same gate costs ~15.7 s
CPU at load 6.8 and ~18.5 s at load 8.3 on this host.
