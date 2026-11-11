# PERF-013 — node fixtures ran every layer to assert one

Worktree: `~/code-factory-wt-perf013`, branch `perf/perf-013-layer-scope`,
HEAD `d5f7fb2` (= `origin/main`), clean at start. `scripts/project-node.sh` and
`tests/selftest.sh` only; the board was not touched.

## Before (foreman's measurements)

Source: perf lane tick `code-factory-perf-2026-11-03-14-51-11` at `d5f7fb2`.

- `bash tests/selftest.sh` cost **2.58 / 2.49 / 2.49 s** user+sys per run (34 `PASS` rows,
  loadavg ~4.9). At `b365792`, before sections 14 (`bb99a5c`) and 15 (`d088bc6`) landed, it was
  1.38–1.44 s CPU.
- `tests/selftest.sh` invokes `scripts/project-node.sh` 13 times (~8 real runs). A full run costs
  0.23–0.26 s CPU; layers 00–30 only, 0.18 s; the layer-40 work the repo fixtures actually assert
  (`git clone --depth 1 file://`) costs 0.01 s.
- So ~2.1 s of the 2.49 s gate (85%) was layer work no fixture asserts.

Re-measured on this worktree at `d5f7fb2` before any edit (confirms the foreman's numbers on this
host):

```sh
cd ~/code-factory-wt-perf013
for i in 1 2 3; do /usr/bin/time -p bash tests/selftest.sh >/tmp/b$i.log 2>/tmp/b$i.err; \
  echo "run$i rc=$? $(grep -E '^(real|user|sys) ' /tmp/b$i.err | tr '\n' ' ')PASS=$(grep -c '^  PASS' /tmp/b$i.log)"; done
```

```text
run1 rc=0 real 2.61 user 1.26 sys 1.24 PASS=34
run2 rc=0 real 2.41 user 1.26 sys 1.19 PASS=34
run3 rc=0 real 2.39 user 1.27 sys 1.18 PASS=34
```

CPU (user+sys): **2.50 / 2.45 / 2.45 s**.

## After

```sh
cd ~/code-factory-wt-perf013
for i in 1 2 3; do /usr/bin/time -p bash tests/selftest.sh >/tmp/f$i.log 2>/tmp/f$i.err; \
  rc=$?; echo "run$i rc=$rc $(grep -E '^(real|user|sys) ' /tmp/f$i.err | tr '\n' ' ')PASS_ROWS=$(grep -c '^  PASS' /tmp/f$i.log) summary=$(tail -1 /tmp/f$i.log)"; done
```

```text
run1 rc=0 real 1.69 user 0.72 sys 0.91 PASS_ROWS=34 summary=SELFTEST: PASS
run2 rc=0 real 1.59 user 0.69 sys 0.87 PASS_ROWS=34 summary=SELFTEST: PASS
run3 rc=0 real 1.55 user 0.69 sys 0.86 PASS_ROWS=34 summary=SELFTEST: PASS
```

CPU (user+sys): **1.63 / 1.56 / 1.55 s** — mean 2.47 → 1.58 s, **−36 %**, with the same 34 `PASS`
rows and `SELFTEST: PASS` in all three runs.

## What changed

`scripts/project-node.sh` gains `--layers <list>` (a comma-separated subset of `00,10,20,30,40`;
a single value is a list of one). It validates every element **before any layer runs** (empty list,
unknown element or stray comma → usage line on stderr, exit 2, no `[00]` row), prints one
`SCOPE: layers <list> (fixture mode — not a node certification)` line, replaces each skipped
layer with `  SKIP  layer NN (out of scope)`, and never writes `$HOME/.node/node.json` — layer 90
prints `  SKIP  layer 90 (fixture mode: no manifest)` instead. A scoped run that excludes `00` also
skips the disk-floor resolver, since nothing measures or consumes the floor and a fixture installs
nothing. `specs/NODE.md` documents the surface and the N-4 consequence.

Measured per-run cost of the shapes involved (`user+sys`, best of 3, this host):

| Run shape | CPU |
|---|---|
| unscoped `--check` (full node run) | 0.16 s |
| unscoped `--apply` + clone (full node run) | 0.17 s |
| `--layers 00` (preflight only) | 0.09 s |
| `--layers 20` | 0.01 s |
| `--layers 30,40` | 0.02 s |
| `--layers 40` (clone) | 0.02 s |

## Per-fixture layer sets

| `tests/selftest.sh` fixture | Rows it asserts | `--layers` |
|---|---|---|
| §3 unreachable Crier → one `000` | layer-00 `reach:` FAIL (exactly once) | `00` |
| §4 missing ref | layer-40 `repo_clone` classification | `40` |
| §4 private-repo arm | layer-40 `repo_clone` deploy-key hint | `40` |
| §4b resolved-ref clone failure | layer-40 `repo_clone` + the stub-git call log | `40` |
| §14 adapter FAIL rows counted (red) | layer-20 adapter rows vs `NODE: FAIL (n)` | `20` |
| §14 passing adapter (green) | layer-20 adapter rows, `NODE: PASS`, exit 0 | `20` |
| §15 bus-vs-clone masking (old shape) | layer-30 bus FAIL **and** layer-40 clone success (the read-back must succeed) | `30,40` |

Every assertion kept its exact form: same `grep -Fxc` expected strings, same rc expectations, same
`NODE:` summary matching. No assertion was rewritten to suit a number.

## Left unscoped, and why

- **§15, the two documented-shape arms** (red and green) run `project-node.sh --apply --project
  myproject --repo … --ref main` **as written in the README**. Adding `--layers` would stop them
  being the documented command, and that is the whole point of the arms. They cost 0.14 s each and
  are the single largest remaining line item.
- **§2 empty PATH** asserts a whole-checker property ("the node checker FAILS on an empty PATH",
  with named `FAIL` rows, not a bootstrap crash). Measured cost of the run: **0.00 s** (nothing but
  failing `command -v`/fork lookups run), so scoping it would buy no measurable time.
- **§13 malformed floor** exits inside the fail-closed floor resolver, *before* any layer runs
  (0.04 s). There is nothing to scope, and this is the coverage the scoped path deliberately drops.

## Acceptance

### A — `bash tests/selftest.sh`

```text
  PASS  resolved main clone failure names the ref without missing-ref or private-repo hints
  PASS  adapter FAIL rows counted: 2 rows -> NODE: FAIL (2)
  PASS  passing adapter keeps NODE: PASS and exit 0
  PASS  old shape exits 0 on a failed check (NODE: FAIL (1)) — the defect is real
  PASS  documented shape exits 1 on a failed check (NODE: FAIL (1))
  PASS  documented shape exits 0 on a passing fixture (NODE: PASS)

SELFTEST: PASS
```

rc=0, `grep -c '^  PASS'` = **34** in each of the three runs above — unchanged from before, so no
fixture was dropped or added.

### B — a scoped run never certifies

Fixture: copied `scripts/` tree with a passing `harness/install-fixture.sh`, a stub `curl`
answering 200, a local repo, and a crier bundle `{"agent":"fixture","role":"worker"}` at
`$HOME/.node/crier.json` **mode 600**.

```sh
# scoped, every layer in scope, green in scope
env PATH=… HOME=$H NODE_PROJECT=demo NODE_HARNESS=fixture CRIER_URL=http://fixture.invalid:8767 \
  NODE_DISK_FLOOR=1 bash $H/scripts/project-node.sh --apply --repo file://$H/home/repo --ref main --layers 00,10,20,30,40
# unscoped, same fixture
env … bash $H/scripts/project-node.sh --apply --repo file://$H/home/repo --ref main
```

```text
--- scoped, all five layers in scope, green ---
SCOPE: layers 00,10,20,30,40 (fixture mode — not a node certification)
  SKIP  layer 90 (fixture mode: no manifest)
NODE: PASS
node.json: ABSENT

--- scoped --layers 20,40, green in scope ---
SCOPE: layers 20,40 (fixture mode — not a node certification)
  SKIP  layer 00 (out of scope)
  SKIP  layer 10 (out of scope)
[20] harness
  SKIP  layer 30 (out of scope)
[40] repo
  SKIP  layer 90 (fixture mode: no manifest)
NODE: PASS
node.json: ABSENT

--- unscoped, same fixture ---
[90] manifest
wrote $H/home/.node/node.json
  PASS  manifest — $H/home/.node/node.json
NODE: PASS
node.json: PRESENT mode=664   (crier bundle mode: 600)
```

Both directions hold: green-in-scope `--apply` does not write the manifest, and the same fixture
unscoped does — so the check can fail if the safety ever regresses.

### C — unscoped parity (`NODE: FAIL (3)`)

```sh
h=$(mktemp -d); HOME="$h" ./scripts/project-node.sh --apply --project perfprobe \
  --repo https://github.com/github/gitignore --ref main
```

```text
  FAIL  crier_url — CRIER_URL unset — the node has nothing to connect to (export CRIER_URL=http://crier.example:8767)
  FAIL  python — hermes-agent 0.19.0 requires python >=3.11,<3.14; found 3.14.9
  FAIL  crier_identity — absent — stage a bundle and re-run; a node without an identity is invisible

NODE: FAIL (3)
```

Three `^  FAIL` rows and `NODE: FAIL (3)`; rc=1. The layer-40 clone succeeded in the same run
(`PASS  repo_clone — …/repo @ 6bb5af7`), so the three rows are the node's own verdicts, not a
network shortfall.

### D — bad input

```sh
go --check --layers 20,77   # rc=2
go --check --layers ''      # rc=2
```

```text
usage: …/scripts/project-node.sh --check|--apply [--project P] [--harness H] [--repo URL] [--ref R] [--role worker|builder|full] [--disk-floor GIB] [--layers 00,10,20,30,40]
lines with [00]: 0
```

Both exit 2, print the usage line to stderr, and print no `[00]` row. (`--layers 20,`, `--layers
'20 40'` and a trailing `--layers` with no value also exit 2 the same way.)

### E — both directions for every scoped fixture

Each fixture was run red and green with the same scoped command; "row" is the exact string the
selftest asserts, counted with `grep -Fxc`.

| Fixture / scope | Red arm | Green arm |
|---|---|---|
| §3 `--layers 00` | closed crier → rc=1, one `reach:` `000` row | crier 200 → rc=0, 0 `FAIL` rows, `NODE: PASS` |
| §4 `--layers 40` (missing ref) | `file://trunk.git` (no `main`) → rc=1, row=1, no deploy-key hint | `file://main.git` → rc=0, one `PASS  repo_clone` |
| §4 `--layers 40` (private) | stub git: auth required → rc=1, deploy-key hint=1 | real git + local origin → rc=0, one `PASS  repo_clone` |
| §4b `--layers 40` | stub refuses the clone after `ls-remote` → rc=1, row=1, call log=2 lines | real clone → rc=0, one `PASS  repo_clone` |
| §14 `--layers 20` | failing adapter → rc=1, 2 `FAIL` rows, `NODE: FAIL (2)` | passing adapter → rc=0, 0 `FAIL` rows, `NODE: PASS` |
| §15 `--layers 30,40` | no bundle → masking arm rc=0 while `NODE: FAIL (1)`, `repo/` cloned (read-back works) | bundle 600 → rc=0, `NODE: PASS` |

All twelve arms returned the expected rc and row counts; the scoped runs also printed
`SCOPE: layers … (fixture mode — not a node certification)` and the expected `SKIP` rows, e.g.

```text
SCOPE: layers 30,40 (fixture mode — not a node certification)
  SKIP  layer 00 (out of scope)
  SKIP  layer 10 (out of scope)
  SKIP  layer 20 (out of scope)
  SKIP  layer 90 (fixture mode: no manifest)
```

### F — measured floor: 1.55 s CPU, not below 1.2 s

Three consecutive runs: 1.63 / 1.56 / 1.55 s user+sys. The target of <1.2 s is **not** met, and it
is not reachable by fixture scoping under this brief. Measured attribution of what is left:

| Remaining cost | CPU |
|---|---|
| §15's two documented-shape arms (must stay unscoped: they run the documented command) | 0.28 s |
| `tests/test_lane_target.py` (0.21 s) + `tests/test_disk_floor.py` (0.04 s) — separate suites, outside this diff | 0.25 s |
| §3's `--layers 00` run — dominated by the floor resolver's three `python3` spawns (`disk_floor.py` + two JSON reads), which layer 00 genuinely needs | 0.09 s |
| the four `--layers 40`/`30,40`/`20` fixture runs, §13's fail-closed floor check, §2 | ~0.15 s |
| residual: 9 `bash -n` interpreter launches, board JSONL parse, `boardctl` (3 invocations), README/prompt greps, `git init`/`commit`/`clone --bare` per fixture section, `fetch_verified` digest work | ~0.8 s |

For scale: a throwaway copy of `tests/selftest.sh` that *also* put `--layers 30,40` on the two
documented-shape arms measured 1.19–1.24 s CPU. That is the ceiling of this technique — it lands on
the 1.2 s line and only by no longer running the documented command, which the brief forbids. The
honest floor with the constraint is ~1.55 s, so the numbers above are reported as measured rather
than chased by dropping or weakening assertions.

## Unscoped behaviour is unchanged

`git show HEAD:scripts/project-node.sh` and the new script were run against identical fixtures and
their output diffed: green `--check`, green `--apply` (manifest body compared with `created_at`
masked), `--apply` with a local clone, missing ref, private repo, `CRIER_URL` unset, `--role
builder`, malformed floor, empty `PATH`, and the argument-error surfaces. All identical except the
script path, `bash: line N` diagnostics (the file grew) and the usage line, which now ends in
`[--layers 00,10,20,30,40]`. Row order, `SKIP`-free layer headers, manifest behaviour and exit
codes are unchanged.

## Reproduction of the safety/direction probes

The per-fixture probes are ordinary bash fixtures of the same shape as `tests/selftest.sh`
(copied `scripts/`, stub `curl`, stub `git`, fixture adapter, local bare origins); no network, no
root, no new dependencies. Their decisive commands are the `--layers` invocations tabulated above,
run from the worktree; each prints its rc and its asserted row, which is what the tables record.
