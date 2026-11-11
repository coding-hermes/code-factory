# Perf audit — gate, node provision, clone, build

- **Row:** PERF-017
- **Run id:** `code-factory-perf-2026-11-11-10-34-12`
- **Candidate tree:** `ea1fda5eadc0b042f26ac543191aeab45e60ce7e`, tree `eb52d9ad2d02f6f7200a7e5ade83f783d9ba1fd9`
- **Measured:** 2026-11-11T10:35Z–11:10Z (UTC)
- **Chapter this row changes:** `III.M5.S3` — toolchain, gate and node entry (`scripts/project-node.sh`)

All four paths were measured in an **immutable clone** detached at `ea1fda5`, because the canonical
checkout was held by live workers (two sibling ticks were running `tests/selftest.sh` in it while this
audit ran). Nothing in this audit wrote to `/home/kara/code-factory`.

## Load caveat — read this before quoting any number

Load average moved from **4.61 to 34.58** during the window (16 cores), with **three concurrent gate
runs from sibling ticks**. The node arm demonstrates the size of the distortion on the same tree, same
command: `0.35–0.39 s CPU` at load 21, `0.41–0.53 s CPU` at load 34.6.

Therefore: the **before/after deltas below are upper bounds and are not claimed as regressions**, while
the **structural counts (lines added, call sites, interpreter launches) are contention-free** and are
what the proposal rests on.

## The four paths

| # | Metric | Command | Before | Now | Verdict |
|---|---|---|---|---|---|
| M1 | gate CPU (user+sys) | `/usr/bin/time -p bash tests/selftest.sh` | **16.89 s** @ `2bb114fd` (PERF-016, 2026-11-04) | **163.88 s** / **177.11 s** | **+9.7×** — assertions only +2.8× |
| M2 | node `--check`, all layers | `/usr/bin/time -p bash scripts/project-node.sh --check --project demo` | 0.16 s CPU (PERF-013, `d5f7fb2`) | 0.41 s CPU (median of 6) | upper bound, load-sensitive |
| M3 | clone, depth 1, file:// fixture (30 files) | `/usr/bin/time -p git clone --depth 1 file://<fixture>.git <dir>` | 0.01 s CPU | 0.02 s CPU (median of 3) | unchanged |
| M4 | handbook build → PDF | `/usr/bin/time -p python3 scripts/build_book.py --out <pdf>` | **none recorded** | **111.23 s** / **107.86 s** CPU | first baseline |

### M1 — gate, raw

| run | real | user | sys | CPU | rows | result | load |
|---|---|---|---|---|---|---|---|
| 1 | 180.99 | 97.57 | 66.31 | 163.88 | 545 PASS / 61 FAIL rows | `SELFTEST: PASS` | 4.61 |
| 2 | 197.64 | 107.07 | 70.04 | 177.11 | 545 PASS / 61 FAIL rows | `SELFTEST: PASS` | 10.85 |
| 3 | — | — | — | — | — | **killed by harness timeout at 420 s, no data** | 17.6 |

`sys` is **40 % of CPU** (66.31 of 163.88). The gate is syscall/spawn-bound, not compute-bound.

### M2 — node provision

| arm | CPU (3–6 samples) | real | result |
|---|---|---|---|
| `--check`, all layers | 0.35, 0.36, 0.39, 0.41, 0.48, 0.53 | 0.35–2.60 | `NODE: FAIL (5)` — expected: this host has no Crier/bunker; the checkers name the missing value |
| `--check --layers 00` | 0.19, 0.21, 0.24 | 0.19–0.29 | same FAIL, one layer measured |
| `--apply --repo file://<fixture> --ref main` | 0.62 | 0.65 | `NODE: FAIL (3)`, 6 layer rows |

`HOME` was redirected to a scratch fixture home for every arm, so `--apply` could not write host state.

### M3 — clone

| arm | CPU | real | files |
|---|---|---|---|
| fixture, depth 1, `file://` | 0.01–0.02 | 0.04–0.05 | 30 |
| this repo, depth 1, `file://` | 0.72 | 0.47 | 467 (`head` = `36104ad`) |

### M4 — build (first recorded baseline)

| run | real | CPU | output |
|---|---|---|---|
| 1 | 135.11 | 111.23 | 10,601,237 bytes · 282 pages · `check.py` green |
| 2 | 144.98 | 107.86 | 10,601,237 bytes · 282 pages · `check.py` green |

Byte-identical output size across both runs — the build is deterministic, so a future regression in
either time or size is detectable.

## Why the gate grew 9.7× — contention-free attribution

`git diff --stat 2bb114fd ea1fda5 -- tests/selftest.sh` → **5,627 insertions, 55 deletions**, over
**90 commits**.

| structural quantity | @ `2bb114fd` | @ `ea1fda5` | change |
|---|---|---|---|
| asserted rows | 193 | 545 | ×2.82 |
| `project-node.sh` call sites | 25 | 65 | ×2.60 |
| — of which pass `--layers` | 0 | **19** | — |
| — of which do not | 25 | **46** | ×1.84 |
| `python3` invocations | 28 | 152 | ×5.43 |
| `python3 -B <file>` launches | — | 106 | — |

Per asserted row the gate went from **0.088 s** (16.89 / 193) to **0.30 s** (163.88 / 545) — a **3.4×**
per-row regression, which is the real finding: coverage grew 2.8×, cost grew 9.7×.

Heaviest individual suite launches (each timed once, multiplied by its launch count in
`tests/selftest.sh`; 21 distinct targets timed, covering most of the 106 launches):

| suite | CPU per run | launches | projected |
|---|---|---|---|
| `tests/test_node_provisioning.py` | 18.11 | 1 | 18.1 |
| `tests/test_bus_result_delivery.py` | 8.55 | 2 | 17.1 |
| `tests/test_harness_memory.py` | 3.86 | 1 | 3.9 |
| `tests/test_lane_target.py` | 3.35 | 1 | 3.4 |
| `tests/test_harness_resolve.py` | 1.50 | 1 | 1.5 |
| `tests/test_reclaim.py` | 1.05 | 1 | 1.1 |
| **timed subtotal** | | | **50.0 s ≈ 30 % of the gate** |

`tests/test_node_provisioning.py` was inspected and is **not** redundant: its cold build is *expected to
fail* (`GOPROXY=off`, empty `GOMODCACHE`), and its warm build is the offline-reproducibility assertion
itself. No change is proposed there.

## Proposal — one change (PERF-017)

**Scope the 46 unscoped `project-node.sh` call sites in `tests/selftest.sh` to the layers each assertion
actually reads.**

Justification, measured on the same tree and host minutes apart:

| arm | CPU (3 samples) | median |
|---|---|---|
| `--check --project demo` (all layers) | 0.41, 0.48, 0.53 | **0.48** |
| `--check --project demo --layers 00` | 0.19, 0.21, 0.24 | **0.21** |

Per site: **0.27 s CPU**. Across 46 unscoped sites: **≈ 12.4 s CPU**, i.e. **7.6 %** of the 163.88 s
gate — recovered without dropping a single assertion, because each site only reads the layer it names.
The mechanism already exists and is proven at 19 call sites (`--layers 00`, `--layers 40`, `--layers 20`);
this row extends it to the rest.

Chapter: `III.M5.S3`.

**Acceptance criteria (all re-runnable by a stranger):**

1. `for i in 1 2 3; do /usr/bin/time -p bash tests/selftest.sh; done` before and after, CPU (user+sys)
   recorded for all six runs — the after-median must be **≥ 10 s lower** than the before-median.
2. `bash tests/selftest.sh` still ends `SELFTEST: PASS` and still asserts **≥ 545** rows.
3. Every changed call site names its layers and carries a one-line comment stating which asserted row
   reads that layer (`# row: <NODE: ...> reads layer NN`).
4. No site may drop a layer whose failure the gate previously observed — proven by mutating the layer's
   input at one converted site and showing the gate still fails.

## Findings filed with this row

- **F-A** gate CPU +9.7× (16.89 → 163.88–177.11 s) while assertions grew +2.8× (193 → 545): per-row cost
  0.088 → 0.30 s. Reported by PERF-016's own command, on a newer tree.
- **F-B** the handbook build had **no recorded baseline** anywhere in `docs/audits`. It is 108–111 s CPU —
  larger than the gate was a week ago. Baseline recorded above.
- **F-C** PERF-013 and PERF-015 premises are stale: PERF-013 measures a 2.49 s gate and PERF-015 claims
  0.345 s (20 % of the gate). 20 % of today's gate is 33 s. Both are superseded by PERF-017; neither
  should be executed as written.
- **F-D** node/clone/build timings track load (same tree, same command: 0.35 s CPU at load 21 → 0.53 s at
  load 34.6). Prior perf rows recorded no load average, so their single-shot numbers are not
  reproducible. Every number in this audit carries its load.
- **F-E** CI: `gh run list --repo coding-hermes/code-factory --limit 3` returns `[]` — the repo has **no
  GitHub Actions runs at all**. The gate is `tests/selftest.sh` plus the gitreins guard, run locally.
  This is not a breakage; it is the reason a gate CPU regression is invisible to any dashboard.

## Reproduce

```bash
S=/tmp/perf-audit && mkdir -p "$S" && cd "$S"
git clone --no-hardlinks --quiet /home/kara/code-factory tree
git -C tree checkout --quiet --detach ea1fda5

# M1 gate (3 samples; each ~3 min)
cd tree && for i in 1 2 3; do /usr/bin/time -p bash tests/selftest.sh; done

# M2 node — all layers vs one layer
for i in 1 2 3; do /usr/bin/time -p bash scripts/project-node.sh --check --project demo; done
for i in 1 2 3; do /usr/bin/time -p bash scripts/project-node.sh --check --project demo --layers 00; done

# M3 clone
/usr/bin/time -p git clone --depth 1 "file://$PWD" "$S/self-clone"

# M4 build
/usr/bin/time -p python3 scripts/build_book.py --out "$S/handbook.pdf"
```

Read CPU as `user + sys` (GNU `time -p` prints `sys 0.12` with a single space).
