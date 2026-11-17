# PERF-018 — fixture HOMEs re-provision the JS toolchain; share the XDG cache across the isolation boundary

Lane tick: `code-factory-perf-2026-11-17-02-40-53`
Measured tree: `7c35513d` (`tests/selftest.sh` sha256 unchanged from HEAD; measurement made in a
`git clone --no-hardlinks` of that commit, so the working checkout was never instrumented)
Comparison base: `docs/audits/code-factory-perf-2026-11-11-PERF-017.md` (PERF-017, tree `ea1fda5`)

## Metric

Gate wall clock for `bash tests/selftest.sh`: `real` from `/usr/bin/time -p`, with every `say()`
row stamped by `EPOCHREALTIME` so a change can be attributed to a step.

## Before / after

Same commit, same tree, same command family, arms interleaved back to back:

| arm | wall `real` | user | sys | loadavg at start | PASS | FAIL |
|---|---|---|---|---|---|---|
| baseline (pristine fixtures) | **273.18 s** | 133.27 | 84.65 | 19.91 | 583 | 62 |
| shared XDG toolchain cache | **240.36 s** | 132.84 | 78.86 | 17.35 (rose to 51.90 during the arm) | 583 | 62 |

Delta: **-32.82 s wall (-12.0%)**, CPU -6.22 s. The second arm ran under *heavier* load than the
baseline arm, so the wall delta is if anything conservative.

An earlier, load-unmatched pair on the same commit showed the same direction and a larger spread:
325.00 s -> 264.25 s (**-60.75 s, -18.7%**), CPU 230.61 s -> 226.27 s. Load during the baseline arm
of that pair peaked at 40.58, during the XDG arm at 28.90.

Identical verdicts: both interleaved arms produced 645 `PASS`/`FAIL` rows, 583 PASS / 62 FAIL. After
stripping fixture commit SHAs, `tmp.XXXX` names and random pid suffixes, the row sets are equal —
two rows differ only in a random suffix, none dropped, none added.

## Commands (re-runnable)

```bash
# arms; identical except for the XDG passthrough described below
STAMP=stamp_base.txt /usr/bin/time -p bash tests/selftest_base.sh
STAMP=stamp_xdg.txt  /usr/bin/time -p bash tests/selftest_xdg.sh

# per-row wall attribution
python3 row_delta.py stamp_base.txt stamp_xdg.txt
```

Both arm scripts are `tests/selftest.sh` of `7c35513d` with one instrumentation change: `say()` also
writes `EPOCHREALTIME|text` to `$STAMP`. Wall stamps are used instead of the `times` builtin because
a forked subshell inherits the parent's cumulative CPU, so `times` deltas alternate by hundreds of
seconds and cannot attribute a step.

## Profile evidence — the hot path is a per-fresh-HOME toolchain provision

Micro A/B, one adapter check, alternating reps, cache pre-warmed once:

| arm | rep 1 | rep 2 | bytes written into the fixture HOME |
|---|---|---|---|
| throwaway `HOME`, ambient XDG | **11.29 s** | **8.12 s** | 230 MB |
| throwaway `HOME`, shared `XDG_CACHE_HOME`/`XDG_DATA_HOME` | **0.16 s** | **0.30 s** | 4.0 KB |

Command (per rep):

```bash
env -i PATH="$PATH" HOME="$HOME_ARM" /bin/bash scripts/harness/install-claude-code.sh --check
```

Output is the same 15 rows with and without the shared cache; the only textual difference is the
fixture HOME path interpolated into the `binary — absent` FAIL row and the `auth` SKIP row. Same
`--check` verdict, same exit code.

Hot path (line numbers at `7c35513d`) — the isolation call sites that scrub `XDG_*` along with
`HOME`, so the first `node --version` inside each fixture re-provisions the toolchain instead of
hitting the shim's cache:

- `tests/selftest.sh:6984`, `:7006` — adapter `--check` / `--apply` under a fresh `HOME`
- `tests/selftest.sh:7412`, `:7434`, `:7446`, `:7453` — `verify-node.sh` under a fresh `HOME`
- `tests/harness-node-e2e.sh:56`, `:58`, `:96` — adapter check / help / apply legs
- `tests/harness-node-e2e.sh:269`, `:276` — node fixtures
- `tests/harness-conformance.sh:364` — conformance probe

Twelve sites, one shape: `env -i PATH="$PATH" HOME=<throwaway>`.

Per-row gate attribution, `row_delta.py` over the two stamped runs (top savers):

```
4.69s  21.54 -> 16.85  dsh-install-test.sh is green (43 rows)
3.48s   9.06 ->  5.58  no binary row and no binary anywhere -> SKIP naming the absence
3.40s   4.87 ->  1.47  CF-214: the auth row follows the mode the node reported
2.72s   4.09 ->  1.38  CF-214: one 600 bundle in, installed at 600, gone from both sides
2.01s   3.07 ->  1.06  CF-214: a failed install and an undeletable bundle are both named FAIL rows
1.52s  16.36 -> 14.83  with the adapter's binary row removed the manifest arm goes RED
```

The savings are spread across every adapter-backed step rather than concentrated in one, which is
what a per-fixture provision cost looks like; a single hot loop would show up as one row.

## The change (one thing, and only this)

Let the toolchain cache cross the isolation boundary; leave `HOME` isolation intact.

```bash
# at the top of each entry script (tests/selftest.sh, tests/harness-node-e2e.sh,
# tests/harness-conformance.sh)
CF_TOOLCHAIN_CACHE="${CF_TOOLCHAIN_CACHE:-${TMPDIR:-/tmp}/cf-toolchain-cache}"
mkdir -p "$CF_TOOLCHAIN_CACHE/xdg-cache" "$CF_TOOLCHAIN_CACHE/xdg-data"
export CF_TOOLCHAIN_CACHE

# at each of the twelve `env -i` sites
env -i PATH="$PATH" \
  XDG_CACHE_HOME="$CF_TOOLCHAIN_CACHE/xdg-cache" \
  XDG_DATA_HOME="$CF_TOOLCHAIN_CACHE/xdg-data" \
  HOME=<throwaway> ...
```

Why this is safe:

- `HOME` isolation is unchanged — fixtures still get an empty home, so anything asserting home
  cleanliness still sees a clean home (it now stays at ~4 KB instead of 230 MB, which is stricter).
- The cache holds downloaded toolchain artifacts, not fixture state; no fixture-specific file is
  written to `XDG_*` by the adapters measured here.
- A cold cache degrades to today's behaviour: the first probe pays one provision (~9 s, 230 MB) per
  cache lifetime instead of per fixture.
- No assertion moved: 583 PASS / 62 FAIL both sides, identical row set.

## Not claimed

- CPU is essentially unchanged (-1.9% to -6.2% across the two pairs). The win is blocked wall time,
  i.e. provisioning work that should never have happened per fixture. Do not expect a CPU-side win.
- The 62 FAIL rows are pre-existing on this commit in both arms and are out of scope here.
- Concurrent runs sharing one `$CF_TOOLCHAIN_CACHE` were not measured; if the foreman runs parallel
  gates, give each run its own cache dir or accept first-run contention.
