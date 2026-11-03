# PERF-014 — the lane-target suite rebuilt its fixture repo per test

Repo `/home/kara/code-factory`, branch `main`. Brief tip `400a5ab`; this work started at `254c46e`
(docs/board only on top of `400a5ab`) and was committed on `77caa02` (see "A sibling landed while
this ran"). Working tree clean at start apart from 11 pre-existing untracked `.gitreins/history/*`
and `.coding-hermes/board/.lock` artifacts that this task did not create and did not touch.
Files changed: `tests/test_lane_target.py` and this document. `scripts/`, `tests/selftest.sh`,
`specs/`, `README.md` and `.coding-hermes/board/*` untouched.

Target: section 11 of `tests/selftest.sh` (`python3 -B tests/test_lane_target.py`) from 0.213 s CPU
to <= 0.12 s CPU with no test, name or assertion removed or relaxed.

Host: 16 cores, shared (fleet ticks + a JVM at ~200 %) — loadavg was 8.5–19.8 throughout, which is
why every number below is given as a set of runs rather than a single figure. CPU is
`user+sys` from `/usr/bin/time -p`.

## Before

Brief attribution, measured at `400a5ab`:

```sh
cd /home/kara/code-factory
for i in 1 2 3; do /usr/bin/time -p python3 -B tests/test_lane_target.py >/dev/null; done
```

Re-measured here at `254c46e` before any edit (identical file; `254c46e` touches only
`docs/` + the board):

```text
real 0.23  user 0.11  sys 0.11
real 0.25  user 0.12  sys 0.10
real 0.23  user 0.11  sys 0.10
```

CPU `user+sys`: **0.22 / 0.22 / 0.21 s**, `Ran 22 tests … OK`.

Full gate at `254c46e` (34 `PASS` rows):

```sh
for i in 1 2 3; do /usr/bin/time -p bash tests/selftest.sh; done
```

```text
real 1.55  user 0.71  sys 0.82   SELFTEST: PASS   34 PASS rows
real 1.55  user 0.73  sys 0.79   SELFTEST: PASS   34 PASS rows
real 1.55  user 0.72  sys 0.82   SELFTEST: PASS   34 PASS rows
```

CPU: **1.53 / 1.52 / 1.54 s**.

## What changed

`tests/test_lane_target.py` only. Four `setUp` builds of the same throwaway repo
(`git init` + write README + `git add` + `git commit` + `git remote add`, ×4 tests) plus a fifth
identical build inside `test_scan_mixed_rows` became one fixture built on first use:

- `fixture()` (line 64) memoises a `root`/`home`/`repo` triple for the process, `atexit`-cleaned.
  `VerifyLocal.test_real_checkout_verifies` and `ScanProjects.test_scan_mixed_rows` share it; both
  only read it (`verify_local` and `scan` spawn git but never write to the target).
- Build cost is two spawns, not four: `git init -q -b main` + `git commit -q --allow-empty -m init`.
  The README write and `git add` are gone because `scripts/lane_target.py` never reads the working
  tree — `verify_local` asks for `rev-parse --show-toplevel`, the remote list, `remote get-url` and
  `rev-parse --abbrev-ref HEAD`. An empty commit satisfies `attached_branch` exactly as the README
  commit did.
- The `origin` remote is written as the stanza `git remote add` writes, appended to `.git/config`
  in-process instead of spending a third spawn. It is not trusted blindly: `test_real_checkout_verifies`
  asserts `remotes["origin"] == "https://example.invalid/o/r.git"` and the scan test requires the
  `ok-local` row to pass `has_remote`, both read back through git (mutation M2 proves this).
- Fixture git calls set `maintenance.AUTO=false` via `GIT_CONFIG_*`. `git commit` otherwise spawns
  `git maintenance run --auto --detach` — the 5 `git-core` children visible in the before trace,
  1 per commit. That child is housekeeping the tests never read; it is 0 after.

Tests that need their own state keep their own throwaway directory, unchanged in intent:
`test_home_repo_rejected_as_standin_locator` still does `git init` on a fresh directory used as both
target and `$HOME` (line 177), `test_missing_dir_fails` uses a path that does not exist (line 188),
`test_non_git_dir_fails` still verifies a plain non-git directory (line 194).

Test inventory unchanged: **22 test methods before, 22 after**, same names in the same order, and
the same 36 `assert*` call sites (`diff` of the extracted method names is empty).

The diff also carries a mechanical `black` reflow of pre-existing long lines in this file. The
repo's Tier 1 guard runs its bundled `black` over every changed Python file, and
`tests/test_lane_target.py` was never black-clean (the committed version at `77caa02` fails
`black --check` too) — so touching it puts the whole file under the formatter. Nothing was added,
removed or re-worded by it: the 22 method names, their order and the 36 `assert*` call sites are
byte-identical before and after the reflow, and the suite plus both mutation arms were re-run on
the formatted file (numbers below are the formatted file's).

## After

```sh
cd /home/kara/code-factory
for i in 1 2 3; do /usr/bin/time -p python3 -B tests/test_lane_target.py >/dev/null; done
```

```text
real 0.13  user 0.07  sys 0.04   Ran 22 tests … OK
real 0.12  user 0.07  sys 0.04   Ran 22 tests … OK
real 0.13  user 0.07  sys 0.05   Ran 22 tests … OK
```

CPU: **0.11 / 0.11 / 0.12 s** (formatted file, loadavg 6.6–10.3). An earlier three-run set at
loadavg 19.8, before the black reflow, read 0.12 / 0.12 / 0.12 s.
Five more runs in a quieter window (loadavg 8.5–9.0), before/after paired in the same minute:

```text
run  before (old file)   after (this file)
1    0.11+0.11 = 0.22    0.06+0.05 = 0.11
2    0.11+0.10 = 0.21    0.06+0.05 = 0.11
3    0.12+0.10 = 0.22    0.07+0.04 = 0.11
4    0.11+0.11 = 0.22    0.07+0.05 = 0.12
5    0.15+0.09 = 0.24    0.07+0.04 = 0.11
```

Median after: **0.11 s** (0.213 → 0.11–0.12 s, −44 %).

### Full gate, era 1 (`254c46e`, 34 `PASS` rows — the shape the brief specifies)

Paired in one window (old test file vs this one, both on throwaway copies of the `254c46e` tree,
loadavg 8–10):

```text
BEFORE (old file)  real 1.60  user 0.66  sys 0.83   SELFTEST: PASS   34 PASS rows
AFTER  (this file) real 1.55  user 0.61  sys 0.82   SELFTEST: PASS   34 PASS rows
BEFORE (old file)  real 1.60  user 0.69  sys 0.82   SELFTEST: PASS   34 PASS rows
AFTER  (this file) real 1.50  user 0.66  sys 0.81   SELFTEST: PASS   34 PASS rows
BEFORE (old file)  real 1.72  user 0.70  sys 0.85   SELFTEST: PASS   34 PASS rows
AFTER  (this file) real 1.38  user 0.64  sys 0.74   SELFTEST: PASS   34 PASS rows
```

CPU: **1.43 / 1.47 / 1.38 s** against **1.49 / 1.51 / 1.55 s** for the unchanged file, 34 `PASS`
rows and `SELFTEST: PASS` in every run. An earlier, quieter window read 1.42 / 1.41 / 1.36 s; one
busier window (sys time 0.82–0.86 for arms this diff does not touch) read 1.46 / 1.49 / 1.51 s.
The host's noise is larger than this delta — the paired runs, not the absolutes, are the evidence.

### Full gate, era 2 (`77caa02`, current `main`, 40 `PASS` rows)

While this task ran, a sibling landed `77caa02` ("stage every script the node entry point runs —
addresses CF-075") which adds `§16` to `tests/selftest.sh`: 6 more `PASS` rows and ~0.4–0.9 s. The
gate therefore emits **40** rows now, not 34, and the brief's `<= 1.47 s` no longer describes the
current tree for reasons unrelated to this diff. Paired measurement at that tip, same minute, old
test file vs this one, both in throwaway copies of the tree:

```text
gate BEFORE (old test file)  run1 0.87+1.13 = 2.00   40 PASS rows  SELFTEST: PASS
                             run2 0.88+1.13 = 2.01   40 PASS rows  SELFTEST: PASS
                             run3 0.84+1.14 = 1.98   40 PASS rows  SELFTEST: PASS
gate AFTER  (this test file) run1 0.87+1.05 = 1.92   40 PASS rows  SELFTEST: PASS
                             run2 0.80+1.01 = 1.81   40 PASS rows  SELFTEST: PASS
                             run3 0.78+1.06 = 1.84   40 PASS rows  SELFTEST: PASS
```

The live checkout with this change (formatted file, same day) measures the same thing:

```text
real 1.87  user 0.76  sys 1.05   SELFTEST: PASS   40 PASS rows
real 1.90  user 0.77  sys 0.99   SELFTEST: PASS   40 PASS rows
real 1.88  user 0.81  sys 0.96   SELFTEST: PASS   40 PASS rows
```

CPU **1.81 / 1.76 / 1.77 s** with 40 `PASS` rows and `SELFTEST: PASS`; this diff accounts for
~0.1 s of it, the sibling's `§16` for the rest.

## Git spawn count

`strace -f -c -e trace=execve python3 -B tests/test_lane_target.py`:

```text
before:  1293 execve calls, 1254 errors   → 38 successful git execs
          = 33 × /usr/bin/git + 5 × /usr/lib/git-core/git (the commit-time `maintenance run --auto`
after:    586 execve calls,  570 errors   → 15 successful git execs
          = 15 × /usr/bin/git, zero children
```

Per class (`strace -f -e trace=execve -o …` on `python3 -B tests/test_lane_target.py <Class>`):

| Class | git execs before | after |
|---|---|---|
| `ParseLocal` / `ParseRemote` / `VerifyRemote` | 0 | 0 |
| `ScanProjects` | 9 (8 + 1 maintenance child) | 6 |
| `VerifyLocal` | 29 (25 + 4 children) | 11 |
| whole suite | 38 | 15 |

Where the 15 go: 2 build (`init`, `commit`) + 1 stand-in `$HOME` `init` + 12 verification spawns
(`verify_local` = 4 on a repo with one remote [toplevel, remote, get-url, abbrev-ref], 3 on the
remote-less stand-in home, 1 on the non-git dir; two of those 4-spawn runs are the two entry points
under test, `verify_local` itself and `scan → verify`).

## Per-arm attribution (reproduced)

Method (the brief's was bash `times` stamps before every output row): a throwaway copy of the tree
at `254c46e` whose `tests/selftest.sh` has `say()` replaced by a stamper reading
`EPOCHREALTIME` (µs). Each row's number is the wall time since the previous row, i.e. what the arm
that produced the row cost. Wall clock includes I/O wait, so numbers run a little above the brief's
CPU figures; the ranking and the section-11 delta are the same. The instrumented copy is scratch
only — `tests/selftest.sh` in the repo is untouched.

| Arm | before (ms) | after (ms) | brief (CPU) |
|---|---|---|---|
| §15 `documented shape exits 0 on a passing fixture` | 247 | 215 | 225 |
| §11 `python3 -B tests/test_lane_target.py` | **221** | **127** | 213 |
| §15 `documented shape exits 1 on a failed check` | 219 | 189 | 199 |
| §3 layer-00 unreachable-crier fixture | 131 | 128 | 143 |
| §15 masking arm `--layers 30,40` | 80 | 93 | 83 |
| §14 adapter red / green | 61 / 35 | 70 / 34 | 79 / 41 |
| §4b resolved-ref clone failure | 67 | 69 | 76 |
| §4 missing ref / private repo | 68 / 35 | 63 / 36 | 65 / 39 |
| §12 disk-floor suite | 48 | 52 | 59 |
| §13 floor refusal | 45 | 48 | 56 |
| §5 correct / wrong digest | 29 / 14 | 31 / 14 | 36 / 19 |
| §10 unsupported-Python refusal | 29 | 28 | 36 |
| §8 boardctl (3 rows) | 2 / 8 / 9 | 2 / 8 / 9 | 29 / 11 |
| §9 prompts (2 rows) | 4 / 15 | 4 / 15 | 22 |
| §2 empty-PATH (2 rows) | 16 / 3 | 15 / 3 | — |
| §1 nine `bash -n` rows | 4–6 each | 4–6 each | ~10 |

`§16` did not exist at `254c46e`. A second instrumented pass at `77caa02` was discarded: loadavg
passed 19 mid-run and every arm inflated (e.g. §4 822 ms, §15 1009 ms), including the arms this
diff does not touch — the run above was taken at loadavg ~4–9 and reproduces the brief's shape.

## AGENTS.md rule 2 — the arm can still go red

A check that cannot fail is decoration, so the refactor was proved against mutated copies of
`scripts/lane_target.py`. The repo's `scripts/` was never edited; each arm got its own scratch tree
holding a copy of `scripts/lane_target.py` and a copy of the test file, so the test file's
`sys.path.insert("..", "scripts")` resolves to the mutant without any `PYTHONPATH` tricks.

```sh
S=$(mktemp -d)                      # scratch, outside the repo
# M1: delete the stand-in-$HOME check
#   lane_target.py:  "        resolved != home_real,"  ->  "        True,  # MUTANT"
# M2: stop reading the origin URL out of git
#   lane_target.py:  '            urls[name] = got.stdout.strip()'  ->  '            urls[name] = "MUTANT"'
```

M1, this diff's test file:

```text
test_home_repo_rejected_as_standin_locator (__main__.VerifyLocal.test_home_repo_rejected_as_standin_locator) ... FAIL
FAIL: test_home_repo_rejected_as_standin_locator
  File ".../m1/tests/test_lane_target.py", line 186, in test_home_repo_rejected_as_standin_locator
    self.assertFalse(checks["not_home_repo"])
AssertionError: True is not false
Ran 22 tests … FAILED (failures=1)          rc=1
```

M1, the **pre-refactor** test file (same mutation, same tree layout):

```text
FAIL: test_home_repo_rejected_as_standin_locator (__main__.VerifyLocal.test_home_repo_rejected_as_standin_locator)
Ran 22 tests … FAILED (failures=1)          rc=1
```

M2 (`urls[name] = "MUTANT"`), this diff's file:

```text
FAIL: test_real_checkout_verifies (__main__.VerifyLocal.test_real_checkout_verifies)
Ran 22 tests … FAILED (failures=1)          rc=1
```

M2, the pre-refactor file: `FAIL: test_real_checkout_verifies … rc=1` — identical. M2 also proves
the shared fixture is real: the hand-written `[remote "origin"]` stanza is what
`test_real_checkout_verifies` reads back through `git remote get-url`, and it also has to satisfy
`scan`'s `has_remote` check.

Controls (unmutated `scripts/lane_target.py` copied into the same scratch layout):

```text
new test file → Ran 22 tests … OK   rc=0
old test file → Ran 22 tests … OK   rc=0
```

Red-ness is therefore unchanged by the refactor: same mutation, same failing test, both before and
after, and the green arms still pass.

## Honest floor — what cannot move

Section 11 is now **15 git execs** and **0.11–0.12 s CPU** on this host. The remaining cost is
almost entirely process creation, and it does not decompose further without dropping a check:

- **Fixed base ≈ 0.05 s.** Measured by running the three spawn-free classes:
  `python3 -B tests/test_lane_target.py ParseLocal` = 0.05 s user+sys, the same for `ParseRemote`
  and `VerifyRemote`. That is interpreter start plus `unittest`, and `lane_target`'s own imports
  (`argparse`, `dataclasses`, `typing` — the last one is why the test file does not import `typing`
  itself). Not addressable from a test file.
- **≈ 4.6 ms per git spawn** on this host (probe: 15 × `git rev-parse --show-toplevel` = 0.08 s
  wall / 0.05 s CPU above a bare interpreter). 15 spawns ≈ 0.065–0.07 s.
- **12 of the 15 spawns are the code under test**, not setup: `verify_local` issues 4 git calls per
  repo with a remote (3 without) and the suite verifies four trees — the shared fixture through
  `verify_local`, the same fixture through `scan → verify`, the stand-in `$HOME` repo, and the
  non-git dir. Sharing one verification between `test_real_checkout_verifies` and
  `test_scan_mixed_rows` would save 4 spawns and remove the only proof that `scan` actually
  verifies each local row; that is a weakening, so it was not done.
- The two remaining setup spawns (`git init`, `git commit`) are irreducible: `verify_local` returns
  `attached_branch` False unless HEAD resolves, and an unborn branch makes
  `rev-parse --abbrev-ref HEAD` exit 128.
- Therefore 15 is the floor and ~0.11 s is this host's measured value for it. The brief's 0.12 s is
  met, but with almost no margin: two samples taken earlier in the session, while loadavg spiked
  past 14, read 0.13–0.14 s; the paired before-arm in the same windows also inflated (0.22 → 0.25 s).
  Under load this arm sits on the line rather than comfortably under it.

Arms that cannot move at all without dropping an assertion or scoping a documented command
(unchanged by this diff, listed so the next perf row does not re-derive them): §15's two
documented-shape arms must run the README command unscoped (they exist to prove the documented line
behaves); §3/§4/§4b/§14/§16 all wrap `scripts/project-node.sh`; §12/§13 are separate Python suites;
§5, §8, §9, §10 are single small commands; §1's nine `bash -n` rows are nine interpreter launches by
construction.

Pre-existing gap, not introduced and not fixed here: no test asserts `attached_branch` False (a
detached HEAD), in either the old or the new file. It is unchanged coverage, recorded so the shared
fixture is not mistaken for having removed it.

## Reproduction

```sh
cd /home/kara/code-factory

# section 11, three runs (CPU = user+sys)
for i in 1 2 3; do /usr/bin/time -p python3 -B tests/test_lane_target.py >/dev/null; done

# full gate, three runs
for i in 1 2 3; do /usr/bin/time -p bash tests/selftest.sh; done

# git spawns
strace -f -c -e trace=execve python3 -B tests/test_lane_target.py
strace -f -e trace=execve -o /tmp/t.strace python3 -B tests/test_lane_target.py && \
  grep -v '= -1' /tmp/t.strace | grep -c 'execve(".*git'    # 15

# before/after at a fixed tip, without touching the worktree
git archive HEAD | tar -x -C /tmp/before-tree && \
  ( cd /tmp/before-tree && for i in 1 2 3; do /usr/bin/time -p python3 -B tests/test_lane_target.py >/dev/null; done )

# red proof (rule 2): scratch tree = copy of scripts/lane_target.py + copy of the test file,
# mutate the copy ("resolved != home_real," -> "True,"), run the copy
python3 -B "$S/m1/tests/test_lane_target.py"   # rc=1, FAIL test_home_repo_rejected_as_standin_locator
```

Per-arm attribution: copy the tree, replace `say()` in the copy's `tests/selftest.sh` with

```sh
_prev_us=${EPOCHREALTIME//[.,]/}
say() { local _now=${EPOCHREALTIME//[.,]/}; \
  printf '[delta %d ms] %s\n' $(( (_now - _prev_us) / 1000 )) "$*"; _prev_us=$_now; }
```

and run `bash <copy>/tests/selftest.sh 2>&1 | grep '^\[delta'`.

## Foreman verification (independent of the worker's runs)

Measured by the foreman after commit `0aadc9e`, on the 40-row tree, with the old and new test file
alternated in the same minute so host load hits both equally. The host was under a sibling lane's
load (loadavg 11–20) throughout, which is why the paired columns — not the absolutes — are the
evidence.

Section 11, six interleaved reps of `python3 -B tests/test_lane_target.py` (new = `HEAD`,
old = `git show 0aadc9e^:tests/test_lane_target.py` dropped into a `git archive HEAD` copy):

```text
rep   new (this file)   old (pre-PERF-014)
1     0.10              0.22
2     0.12              0.20
3     0.10              0.19
4     0.11              0.19
5     0.10              0.19
6     0.11              0.21
median 0.105           0.195      (−0.09 s, −46 %)
```

Whole gate, five interleaved pairs of `bash tests/selftest.sh` on the same pair of trees (each
1.70–2.05 s CPU, 40 `PASS` rows and `SELFTEST: PASS` in all ten runs):

```text
pair   new     old
1      1.70    1.77
2      1.74    2.05
3      1.80    1.88
4      1.98    1.90
5      2.00    1.84
min/median   1.70 / 1.80     1.77 / 1.88
```

The new tree is cheaper in 4 of 5 pairs; the delta is ~0.08 s of CPU, i.e. the section-11 cut
minus the noise the current host adds to both sides.

Per-arm attribution of the 40-row gate (bash `times` stamps before every output row, one run at
loadavg 19, total 1.735 s — shares are the signal, absolutes track host load):

| Section | CPU (s) | Note |
|---|---|---|
| §15 documented-shape arms (0.238 green + 0.194 red + 0.082 masking) | 0.524 | protected: run the documented command unscoped |
| §16 node-create staged-set rows (6 rows, from `77caa02`) | 0.345 | added by a foreign commit mid-tick; filed as PERF-015 |
| §3 layer-00 unreachable-crier fixture | 0.133 | |
| §11 lane-target suite | 0.106 | was 0.213 before this change |
| §14 adapter red + green | 0.103 | |
| §4 + §4b clone classification | 0.162 | |
| §1 `bash -n` × 10 | 0.054 | |
| §12 / §13 disk-floor suites | 0.098 | |
| §5 / §10 / §8 / §9 / §2 / §6 / §7 | 0.122 | |

Conclusion: the cut this row asked for is real and measured (−0.09 s on the arm, −46 %, 38 → 15 git
execs, and the full gate cheaper in 4 of 5 paired runs with the assertions unchanged). The gate's
absolute number is now set by two things this diff does not touch: the two documented-command arms
that must stay unscoped (0.524 s) and §16, which a sibling commit added while this row ran at ~3×
this cut (0.345 s, PERF-015).

