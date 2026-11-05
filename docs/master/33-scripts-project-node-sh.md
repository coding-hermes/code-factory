# 33. scripts/project-node.sh

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/project-node.sh` [scripts/project-node.sh:1] |
| Repository | `code-factory` [scripts/project-node.sh:1] |
| Revision | `f63acd3` — `git rev-parse HEAD` of the tree this document was measured against |
| Status | **VERIFIED — 8 sections, every claim carries a resolving locator, one real `--check` run on this host (exit 1, `NODE: FAIL (4)`) and three layer-40 fixtures recorded in §3** |

## 1. Purpose and why it matters

- What it is: the node-side provisioning entry point — "provision ONE node, from inside that node", running on the agent rather than the control host because the control host stages it [scripts/project-node.sh:2] [scripts/project-node.sh:4]. It grades five layers in order — `00` preflight, `10` base, `20` harness, `30` bus, `40` repo — then `90` manifest [scripts/project-node.sh:11] [scripts/project-node.sh:12].
- Why the boundary matters: the control host stages exactly six files into `~/node-scripts` [scripts/node-create.sh:23] and then invokes this script with env plus argv [scripts/node-create.sh:121]. Everything this script needs it resolves relative to its own `$HERE`, computed with shell builtins only so a broken `PATH` still yields real FAIL rows [scripts/project-node.sh:30] [scripts/project-node.sh:32]. The contract is checked from both ends: `node-create.sh` parses this file for every `$HERE/...` reference and refuses to stage a set that would leave one unresolved [scripts/node-create.sh:28] [scripts/node-create.sh:43].
- What fails closed, and why that is the point: an unknown or empty kind list is a named FAIL **before any layer runs**, because a typo that fell through to the fixed base set produced the original bug — "a node would print PASS while grading nothing the repo needs" [scripts/project-node.sh:106] [scripts/project-node.sh:109] [scripts/project-node.sh:112]. The fixed base set is now the explicitly-labelled `generic` fallback only, and the row says so [scripts/project-node.sh:343] [scripts/project-node.sh:346].
- Second lie it is written against: checkout freshness. A node one commit behind `origin/main`, or carrying a local edit that blocks its own fast-forward, "printed PASS at every layer" (cf-node, HEAD `7f22d02` vs `origin/main` `04fc398`) — so layer 40 now measures branch, worktree, ancestry and lag and records them [scripts/project-node.sh:478] [scripts/project-node.sh:481].
- Third: a harness adapter runs as a child process, so its FAIL rows never reached the parent counter (CF-055); the parent now captures the adapter output, re-emits it unchanged and folds its `  FAIL` rows into its own count [scripts/project-node.sh:444] [scripts/project-node.sh:455] [scripts/project-node.sh:458].
- What breaks if it is absent: `node-create.sh` reports `bad "provision"` and the node is never graded at all [scripts/node-create.sh:122] [scripts/node-create.sh:124]; the control-host verifier proves the gateway and the checkout from outside but does not grade the node's own toolchain, bus identity or disk floor [scripts/verify-node.sh:2] [scripts/verify-node.sh:10].
- What breaks if it lies: a node that prints `NODE: PASS` while ungraded, stale or identity-less is admitted; the failure semantics make each of those a layer FAIL by policy [specs/NODE.md:173] [specs/NODE.md:175].

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `bash` | not pinned | the kernel runs the shebang; arrays are used in the floor resolution [scripts/project-node.sh:1] [scripts/project-node.sh:171] | nothing inside the script — the interpreter load is the only gate [scripts/project-node.sh:1] |
| `scripts/lib.sh` | same revision as this file | `$HERE/lib.sh`, sourced unguarded [scripts/project-node.sh:35] | no probe: the `.` fails, then `ok`/`bad`/`warn`/`note` are undefined, every row degrades to raw shell errors, and the run aborts on the unset `FAILED` counter — measured exit 1 with zero rows (§6) [scripts/project-node.sh:35] |
| `git` | not pinned | on `PATH`; used by layer 40 and by the inline freshness probe [scripts/project-node.sh:330] [scripts/project-node.sh:513] | `FAIL tool:git — missing` from the layer 10 loop [scripts/project-node.sh:331] |
| `python3` | not pinned (this host: 3.14.9) | on `PATH` [scripts/project-node.sh:331] | preflight: `WARN disk_floor — python3 absent, using built-in … default … GiB` and the floor falls back to the built-in role default [scripts/project-node.sh:161] [scripts/project-node.sh:164]; layer 10 then reports `FAIL tool:python3 — missing` [scripts/project-node.sh:331] |
| `curl` | not pinned | on `PATH`; carries the `reach:` probes [scripts/project-node.sh:246] | `FAIL tool:curl — missing` [scripts/project-node.sh:331]; without it every reach row reads `-> 000` [scripts/project-node.sh:250] |
| `tar`, `sha256sum` | not pinned | on `PATH` | `FAIL tool:tar — missing` / `FAIL tool:sha256sum — missing` [scripts/project-node.sh:330] [scripts/project-node.sh:331] |
| `mktemp` | not pinned | on `PATH`; adapter log [scripts/project-node.sh:448], Go probe dir [scripts/project-node.sh:307], freshness scratch [scripts/project-node.sh:733] | no probe — measured: with an empty `PATH` layer 20 printed `mktemp: command not found` and contributed **zero** FAIL rows (§6) |
| `awk` | not pinned | on `PATH`; `free_gb` and the memory read [scripts/lib.sh:32] [scripts/project-node.sh:233] | no probe — measured rows `FAIL disk —  GB free < floor 5 GB` and `FAIL mem —  MB < 1024` |
| `df` | not pinned | on `PATH`; `free_gb` [scripts/lib.sh:32] | no probe — same measured disk row |
| `stat` | not pinned | on `PATH`; identity mode [scripts/project-node.sh:469] | no probe — a failure would surface as raw shell output in the middle of layer 30 |
| `hostname`, `uname` | not pinned | on `PATH`; run banner and manifest `node_id` [scripts/project-node.sh:189] [scripts/project-node.sh:196] | no probe — measured `host=` empty and `PASS arch —  ()` with an empty `PATH` |
| `/proc/meminfo` | kernel | readable [scripts/project-node.sh:233] | `FAIL mem — 0 MB < 1024` when the read yields nothing [scripts/project-node.sh:234] |
| `node` | any; version read back | only when the resolved kind set contains `node` [scripts/project-node.sh:359] | `FAIL tool:node — missing — kind node needs a Node runtime` [scripts/project-node.sh:362] |
| `cargo` | any; version read back | only when the kind set contains `rust` [scripts/project-node.sh:377] | `FAIL tool:cargo — missing — kind rust needs a Cargo toolchain` [scripts/project-node.sh:380] |
| `go` | `$GO_INSTALL_ROOT/current/bin/go`, else `PATH` [scripts/project-node.sh:414] [scripts/project-node.sh:418] | only when the kind set contains `go` | `FAIL tool:go — missing — kind go needs a Go toolchain on PATH …` [scripts/project-node.sh:421] |
| `scripts/disk_floor.py` | same revision | `$HERE/disk_floor.py`, preflight [scripts/project-node.sh:166] | `FAIL disk_floor — resolver missing or unreadable: …` [scripts/project-node.sh:167] |
| `scripts/reclaim_disk.py` | same revision | `$HERE/reclaim_disk.py`, `--apply` only [scripts/project-node.sh:207] | `FAIL disk_floor — reclaimer missing or unreadable: …` [scripts/project-node.sh:208] |
| `scripts/install-go.sh` | same revision | `$HERE/install-go.sh`, `--apply` with kind `go` [scripts/project-node.sh:399] | `FAIL tool:go — installer missing or not executable: …` [scripts/project-node.sh:400] |
| `harness/install-<harness>.sh` | same revision | `$HERE/harness/install-$HARNESS.sh`, layer 20 [scripts/project-node.sh:440] | `FAIL harness:$HARNESS — no adapter at scripts/harness/install-$HARNESS.sh` [scripts/project-node.sh:442] |
| `scripts/node_freshness.py` | same revision, **in the clone** | `$RP/scripts/node_freshness.py` [scripts/project-node.sh:491] | absence is handled, not failed: the inline fallback measures the same four arms with the git CLI alone [scripts/project-node.sh:495] |
| a reachable crier | peer service | `$CRIER_URL/health` [scripts/project-node.sh:244] | `FAIL reach:$CRIER/health — -> $c` [scripts/project-node.sh:250] |

### 2b. Library contracts

| Contract | Provider | Contract relied on | If it changes |
|---|---|---|---|
| row helpers | `scripts/lib.sh:5` | `say`/`ok`/`bad`/`warn`/`note` print the fixed `  PASS  %s — %s` shape, and `bad()` increments `FAILED` [scripts/lib.sh:7] | the closing `NODE: FAIL ($FAILED)` would under-report exactly the CF-055 class [scripts/project-node.sh:826] |
| `have()` | `scripts/lib.sh:13` | prints the path, or **nothing** when the command is absent; callers test emptiness [scripts/project-node.sh:331] | a helper that printed an error string would flip every "missing" row to PASS |
| `free_gb()` | `scripts/lib.sh:32` | one decimal GiB from `df -Pk`, compared numerically by `awk` [scripts/project-node.sh:203] | a unit change moves the floor silently — the number is the refusal's evidence |
| `require_disk()` | `scripts/lib.sh:35` | prints the `disk` row itself and returns 1 below the floor [scripts/lib.sh:41] | check mode uses only the return code to add the reclaim note and keeps measuring [scripts/project-node.sh:200] |
| `disk_floor.py resolve --explain` | `scripts/disk_floor.py:165` | one JSON object with `floor_gib` and `source`, read by two separate `json.load(sys.stdin)` calls [scripts/project-node.sh:178] [scripts/project-node.sh:179] | a renamed key yields an empty floor and `FAIL disk_floor — resolver returned no number` [scripts/project-node.sh:181] |
| `disk_floor.py` precedence and refusal | `scripts/disk_floor.py:13` | `--cli` > `NODE_DISK_FLOOR` > config `[disk]` > built-in role default; malformed values exit non-zero rather than lower a floor [scripts/disk_floor.py:16] | a fallback on a typo would admit a node below policy, so the parent treats any non-zero exit as `FAIL disk_floor` [scripts/project-node.sh:174] |
| `reclaim_disk.py run --root --json` | `scripts/reclaim_disk.py:123` | human lines, then a final JSON line carrying `reclaimed_mib` [scripts/project-node.sh:217] [scripts/project-node.sh:218] | the parent strips the last line as JSON and would fail closed with `reclaimer returned no reclaimed size` [scripts/project-node.sh:219] |
| `reclaim_disk.py` PROTECTED | `scripts/reclaim_disk.py:22` | never reaps `repo`, `.node/node.json`, `.node/crier.json`, `.node/floor.toml` | reclaim runs on the same host that must keep the identity layer 30 requires [scripts/project-node.sh:467] |
| `node_freshness.py --workdir --json` | `scripts/node_freshness.py:49` | JSON object on stdout, rows on stderr, exit `0` PASS / `1` drift-or-dirty [scripts/node_freshness.py:648]; keys `branch`, `head`, `origin_main`, `behind`, `ancestor`, `dirty_files`, `differing_files`, `result`, `reason` [scripts/node_freshness.py:644] | the parent builds a single row from nine TAB-separated fields and prints `branch=? head=? …` when any key is missing [scripts/project-node.sh:740] |
| harness adapter CLI | `scripts/harness/install-hermes.sh:12` | invoked `--check` or `--apply` with `NODE_GATEWAY_PORT` in the environment [scripts/project-node.sh:449] [scripts/project-node.sh:452] | a flag rename makes the adapter exit non-zero silently — layer 20 counts only rows, not exit codes [scripts/project-node.sh:455] |
| git plumbing exit codes | `git` | `merge-base --is-ancestor` yields 0 ancestor / 1 diverged / other unmeasurable, three distinct outcomes [scripts/project-node.sh:588] [scripts/project-node.sh:593] [scripts/project-node.sh:598] | collapsing "unmeasurable" into "diverged" is refused: it is its own FAIL text [scripts/project-node.sh:599] |
| `git ls-remote --exit-code` | `git` | exit 2 means the ref does not exist; any other non-zero means the repository could not be reached [scripts/project-node.sh:707] [scripts/project-node.sh:711] | the two remedies differ — `pass --ref <branch-or-tag>` versus a deploy key [scripts/project-node.sh:712] [scripts/project-node.sh:714] |
| the Go proxy under test | node's own toolchain | `go env GOPROXY` read first, `GOPROXY` env as fallback [scripts/project-node.sh:304] [scripts/project-node.sh:305]; `go mod download` with a cold `GOMODCACHE`, `GOTOOLCHAIN=local`, `GOSUMDB=off`, empty `GOFLAGS` under a 30 s bound [scripts/project-node.sh:313] | a warm cache or a checksum-database failure would prove the cache or a second network instead of the proxy [scripts/project-node.sh:308] |

### 2c. Service contracts (both sides must be named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| control-host provisioner | this script, as a staged child | `bunker exec` of `~/node-scripts/project-node.sh --apply` with `NODE_PROJECT`, `NODE_GATEWAY_PORT`, `CRIER_URL` in the environment [scripts/node-create.sh:121] | argv `--project --harness --repo --ref`, and the six staged files the script resolves under `$HERE` [scripts/node-create.sh:23] | `scripts/node-create.sh:staged_files()` — validates every `$HERE/...` reference in this file against the staged set before copying [scripts/node-create.sh:21] [scripts/node-create.sh:41] |
| crier bus `/health` | outbound probe | HTTP `GET` with `--max-time 8` [scripts/project-node.sh:248] | status code must be `200` [scripts/project-node.sh:250] | crier's health handler is GET-only, so a `HEAD` there answers `405` and is not a fault — the reason the method differs per URL [scripts/project-node.sh:242] [scripts/project-node.sh:243] |
| crier bus, authenticated reads | outbound, later | HTTP with bearer plus per-agent signature [fact: FACT-03] | this script proves only that an identity **file** exists at mode 600 [scripts/project-node.sh:467] [scripts/project-node.sh:469] | crier verifies the ed25519 signature before it looks the agent up [fact: FACT-03]; the identity is staged by `bunker-crier-connect.sh`, which copies the bundle and chmods it 600 in the same step [scripts/bunker-crier-connect.sh:114] [scripts/bunker-crier-connect.sh:115] |
| PyPI simple index | outbound probe | HTTP `HEAD` with `--max-time 8` [scripts/project-node.sh:245] | `200` [scripts/project-node.sh:250] | no local source in this repo: PyPI's own index; `HEAD` is used because the `GET` of a ~48 MB index returns `000` inside the 8 s budget on a healthy link [scripts/project-node.sh:241] |
| the project's origin repository | outbound clone / fetch / compare | `git clone --depth 1 --branch`, `git ls-remote --exit-code`, `git fetch origin` [scripts/project-node.sh:702] [scripts/project-node.sh:707] [scripts/project-node.sh:572] | ref name, then HEAD-vs-`origin/main` ancestry and lag [scripts/project-node.sh:588] [scripts/project-node.sh:602] | the project repo's default branch and deploy-key access; a private repo without a key is named as an access failure, not a missing ref [scripts/project-node.sh:714] |
| check verdict record | this script → control host | files at `$STATE/freshness.json` and `$STATE/node.json` [scripts/project-node.sh:735] [scripts/project-node.sh:781] | the probe's own `status` plus the ladder's `PASS`/`WARN`/`FAIL` [scripts/project-node.sh:762] [scripts/project-node.sh:801] | `scripts/verify-node.sh` and the manifest reader consume `freshness` — `status` is the check's verdict, `ladder` is the provisioning verdict, and a dirty tree is `FAIL` in one and `WARN` in the other [specs/NODE.md:30] [specs/NODE.md:31] |

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| Full grading on this host | `bash scripts/project-node.sh --check --project cf-node` [scripts/project-node.sh:6] | every layer prints rows and the last line is `NODE: PASS` or `NODE: FAIL (n)`; exit equals 0 or 1 [scripts/project-node.sh:826] | 2026-11-05 | **measured `NODE: FAIL (4)`, exit 1** — the node's own preconditions are absent here (below) |
| Layer 40, clean checkout | `HOME=<tmp> bash scripts/project-node.sh --check --project demo --layers 40` [scripts/project-node.sh:20] | `PASS freshness` with `behind=0 ancestor=true`, `NODE: PASS`, exit 0 | 2026-11-05 | **measured `NODE: PASS`, exit 0** |
| Layer 40, one uncommitted path | same, after editing a tracked file | `WARN freshness` and exit 0 — dirty is a finding, not a refusal [specs/NODE.md:177] | 2026-11-05 | **measured `NODE: PASS`, exit 0**, with `check verdict: FAIL (1 uncommitted path(s))` on the record line |
| Layer 40, one commit behind | same, after pushing to origin | `FAIL freshness` naming `behind=1`, `NODE: FAIL (1)`, exit 1 | 2026-11-05 | **measured `NODE: FAIL (1)`, exit 1** |
| Broken `PATH` | `env -i PATH=/nonexistent HOME=$HOME NODE_PROJECT=t /bin/bash scripts/project-node.sh --check` [tests/selftest.sh:15] | named FAIL rows, non-zero exit, and no `unbound variable` bootstrap crash [tests/selftest.sh:20] | 2026-11-05 | **measured `NODE: FAIL (11)`, exit 1**, with `FAIL tool:` rows present |
| Missing `--project` | `bash scripts/project-node.sh --check` | one stderr line and exit 2 [scripts/project-node.sh:82] | 2026-11-05 | **measured exit 2** |
| Unknown kind | `bash scripts/project-node.sh --check --project cf-node --layers 10 --kinds cobol` | named `FAIL kinds` before any layer runs, exit 1 [scripts/project-node.sh:127] | 2026-11-05 | **measured `NODE: FAIL (1)`, exit 1** |
| Malformed floor | `env HOME=<tmp> NODE_DISK_FLOOR=999999 bash scripts/project-node.sh --check --project fixture` [tests/selftest.sh:520] | `FAIL disk_floor` naming the value, exit 1, before any install [scripts/project-node.sh:174] | 2026-11-05 | **measured `NODE: FAIL (1)`, exit 1** |

Measured run on this host (verbatim, `EXIT=1`):

```
PASS  disk_floor — 5 GiB from role-default
node provisioning — project=cf-node harness=hermes host=karaHermes-mde-7840hs
[00] preflight
  PASS  arch — x86_64 (Linux 7.0.0-38-generic)
  PASS  role — worker (floor 5 GiB from role-default)
  PASS  disk — 147.5 GB free (floor 5 GB)
  PASS  mem — 47420 MB
  FAIL  crier_url — CRIER_URL unset — the node has nothing to connect to (export CRIER_URL=http://crier.example:8767)
[10] base
  PASS  tool:python3 — …/venv/bin/python3
  PASS  tool:git — /usr/bin/git
  PASS  tool:curl — /usr/bin/curl
  PASS  tool:tar — /usr/bin/tar
  PASS  tool:sha256sum — /usr/bin/sha256sum
  PASS  python:venv — importable
  WARN  kinds — generic fallback — no --kinds/NODE_KINDS and no kind marker in /home/kara/repo — grading the fixed base set only, so a Go/Rust/Node repo would go ungraded
  ..    census: bash scripts/project-node.sh --check --project <p> --layers 10 grades one node — markers go.mod→go, Cargo.toml→rust, package.json→node, pyproject.toml|setup.py→python; CF-218 counted 61 distinct fleet repo origins: go 27, node 22, python 16, rust 5
  PASS  tool:jq — /usr/bin/jq
  PASS  tool:rg — /usr/bin/rg
  PASS  tool:node — /home/kara/.local/bin/node
[20] harness
harness: hermes (pin 0.19.0, port 10800)
  FAIL  python — hermes-agent 0.19.0 requires python >=3.11,<3.14; found 3.14.9
[30] bus
  FAIL  crier_identity — absent — stage a bundle and re-run; a node without an identity is invisible
[40] repo
  FAIL  repo — /home/kara/repo absent (pass --repo to clone)
[90] manifest
  ..    manifest is written only when every layer passes

NODE: FAIL (4)
EXIT=1
```

That run is the measurement, not a defect: this host has no `CRIER_URL`, no `$HOME/.node/crier.json`, no `$HOME/repo`, and its `python3` is 3.14.9 against an adapter bound of `>=3.11,<3.14` [scripts/harness/install-hermes.sh:20]. Four FAIL rows, four absent preconditions — the script refuses rather than grading a tree it does not have.

Layer 40 on a scratch origin, three directions (verbatim rows):

```
# clean clone
  PASS  repo — /tmp/…/home/repo @ e15cc9c
  PASS  freshness — branch=main head=e15cc9cb0ed7 origin_main=e15cc9cb0ed7 behind=0 ancestor=true
NODE: PASS
# one uncommitted path
  WARN  freshness — branch=main head=e15cc9cb0ed7 origin_main=e15cc9cb0ed7 behind=0 ancestor=true dirty=f.txt — a local edit on the node is a finding: it blocks the node's fast-forward and the fix belongs upstream (not repaired here)
  ..    check verdict: FAIL (1 uncommitted path(s)) (fixture mode: nothing recorded)
NODE: PASS
# one commit behind origin/main
  FAIL  freshness — branch=main head=e15cc9cb0ed7 origin_main=b7f669abcd72 behind=1 ancestor=true differing=g.txt — behind 1 commit(s) vs origin/main
NODE: FAIL (1)
```

Empty `PATH` (verbatim, first and last rows, `EXIT=1`):

```
  WARN  disk_floor — python3 absent, using built-in worker default 5 GiB
  FAIL  tool:python3 — missing
  …
NODE: FAIL (11)
```

## 4. Metrics emitted

**NONE** — and the reason is structural rather than incidental.

- The script exports nothing: no counter, histogram, timestamp or duration is emitted. Its only counter is in-process — `FAILED`, incremented by `bad()` [scripts/lib.sh:7] [scripts/lib.sh:11] — and it leaves the process exactly once, in the final line `NODE: FAIL ($FAILED)` [scripts/project-node.sh:826].
- The two files it writes are **state, not metrics**: `$HOME/.node/freshness.json` (the checkout measurement, tagged with the ladder verdict) [scripts/project-node.sh:762] and `$HOME/.node/node.json` (the manifest, `--apply` and all-green only) [scripts/project-node.sh:781] [scripts/project-node.sh:807].
- The only time bounds are refusal budgets, not measurements: `--max-time 8` on each reach probe [scripts/project-node.sh:246] and a 30 s bound on the Go proxy probe [scripts/project-node.sh:306]. Neither is reported as a latency.
- Consequence: dispatch rate, provisioning duration, per-layer failure distribution and node liveness are not answerable from this module — they would have to be parsed out of the closing line of each run.

## 5. Log lines it can generate

| Level | Line (verbatim) | Emitted when | Kind |
|---|---|---|---|
| stderr | `usage: $0 --check\|--apply [--project P] [--harness H] [--repo URL] [--ref R] [--role worker\|builder\|full] [--disk-floor GIB] [--layers 00,10,20,30,40] [--kinds go,rust,node,python,generic]` [scripts/project-node.sh:56] | no mode, a malformed `--layers`, or `--layers`/`--kinds` with no value [scripts/project-node.sh:72] [scripts/project-node.sh:88] | descriptive |
| stderr | `unknown arg: $1` [scripts/project-node.sh:78] | an argument matches no case [scripts/project-node.sh:78] | descriptive |
| stderr | `--project is required (a node belongs to exactly one project)` [scripts/project-node.sh:82] | mode set but `PROJECT` empty after parsing, including `NODE_PROJECT` [scripts/project-node.sh:82] | descriptive |
| stderr | `unknown role: $ROLE (expected worker\|builder\|full)` [scripts/project-node.sh:154] | role is not `worker`, `builder` or `full` [scripts/project-node.sh:150] | descriptive |
| PASS | `  PASS  disk_floor — ${FLOOR_GIB} GiB from ${FLOOR_SRC}` [scripts/project-node.sh:185] | the resolver answered with a number and its source [scripts/project-node.sh:178] | evidentiary |
| WARN | `  WARN  disk_floor — python3 absent, using built-in ${ROLE} default ${FLOOR_GIB} GiB` [scripts/project-node.sh:164] | no `python3` on `PATH`, so the floor came from the built-in role default [scripts/project-node.sh:161] | evidentiary |
| note | `node provisioning — project=$PROJECT harness=$HARNESS host=$(hostname)` [scripts/project-node.sh:189] | always, before layer 00 [scripts/project-node.sh:189] | descriptive |
| note | `SCOPE: layers $LAYERS (fixture mode — not a node certification)` [scripts/project-node.sh:191] | `--layers` was passed [scripts/project-node.sh:191] | descriptive |
| note | `  SKIP  layer 00 (out of scope)` [scripts/project-node.sh:254] | that numbered layer is not in the `--layers` scope [scripts/project-node.sh:254] | descriptive |
| note | `  SKIP  layer 90 (fixture mode: no manifest)` [scripts/project-node.sh:777] | scoped run: no manifest is ever written [scripts/project-node.sh:774] | evidentiary |
| note | `  ..    census: bash scripts/project-node.sh --check --project <p> --layers 10 grades one node — markers go.mod→go, Cargo.toml→rust, package.json→node, pyproject.toml\|setup.py→python; …` [scripts/project-node.sh:352] | every layer 10 run, so the kind-count claim can be re-measured [scripts/project-node.sh:350] | descriptive |
| WARN | `  WARN  kinds — $KIND_SRC — grading the fixed base set only, so a Go/Rust/Node repo would go ungraded` [scripts/project-node.sh:346] | no `--kinds` and no marker in `$RP`, so the generic fallback is in force [scripts/project-node.sh:343] | evidentiary |
| FAIL | `  FAIL  tool:go — missing — kind go needs a Go toolchain on PATH (go is the largest repo class in the fleet: 27 of 61 origins)` [scripts/project-node.sh:421] | kind `go` resolved and neither the owned pin nor `PATH` yields a binary [scripts/project-node.sh:420] | evidentiary |
| FAIL | `  FAIL  reach:$u — -> $c` [scripts/project-node.sh:250] | a crier or PyPI probe did not answer 200 [scripts/project-node.sh:250] | evidentiary |
| FAIL | `  FAIL  crier_identity — absent — stage a bundle and re-run; a node without an identity is invisible` [scripts/project-node.sh:471] | `$STATE/crier.json` is not a file [scripts/project-node.sh:467] | evidentiary |
| FAIL | `  FAIL  crier_mode — $m (must be 600)` [scripts/project-node.sh:469] | the identity exists at a mode other than 600 [scripts/project-node.sh:469] | evidentiary |
| WARN | `  WARN  freshness — $fs_row — a local edit on the node is a finding: it blocks the node's fast-forward and the fix belongs upstream (not repaired here)` [scripts/project-node.sh:748] | dirty tree with `behind=0` and `ancestor=true` [scripts/project-node.sh:746] | evidentiary |
| FAIL | `  FAIL  freshness — $fs_row — ${fs_reason:-checkout freshness could not be measured}` [scripts/project-node.sh:751] | drift, or a measurement that produced no verdict [scripts/project-node.sh:750] | evidentiary |
| note | `  ..    check verdict: $fs_result — recorded in $STATE/freshness.json` [scripts/project-node.sh:756] | layer 40 produced a verdict in an unscoped run [scripts/project-node.sh:754] | evidentiary |
| note | `  ..    manifest is written only when every layer passes` [scripts/project-node.sh:821] | no manifest is present and this was not an all-green apply [scripts/project-node.sh:820] | evidentiary |
| note | `NODE: PASS` / `NODE: FAIL ($FAILED)` [scripts/project-node.sh:826] | last line of every run; exit 0 or 1 follows it [scripts/project-node.sh:826] | evidentiary |

## 6. Failure modes

Direction is the whole point here: **fail-closed** = the node is refused, **fail-open** = the node is admitted, **no-row** = the run continues with nothing printed.

| Failure | Presents as | Direction | Distinguished from | Recovery |
|---|---|---|---|---|
| No `--project`, or `NODE_PROJECT` empty | `--project is required (a node belongs to exactly one project)`, exit 2 [scripts/project-node.sh:82] | fail-closed | an unknown argument, which prints `unknown arg:` and also exits 2 [scripts/project-node.sh:78] | pass `--project P` or export `NODE_PROJECT` [scripts/project-node.sh:37] |
| Unknown `--role` | `unknown role: $ROLE (expected worker\|builder\|full)`, exit 2 [scripts/project-node.sh:154] | fail-closed | a valid role whose floor fails later [scripts/project-node.sh:150] | pass `--role worker\|builder\|full` |
| Unknown or empty kind list | `  FAIL  kinds — unknown kind 'cobol' — expected a subset of go,rust,node,python,generic`, then `NODE: FAIL (1)`, exit 1 **before any layer runs** [scripts/project-node.sh:127] [scripts/project-node.sh:129] | fail-closed | the labelled `generic` fallback, which is a WARN and keeps grading [scripts/project-node.sh:346] | correct `--kinds`/`NODE_KINDS` [scripts/project-node.sh:110] |
| Malformed `--layers` | `usage:` line, exit 2 [scripts/project-node.sh:88] | fail-closed | a valid subset, which runs scoped and prints `SCOPE:` [scripts/project-node.sh:191] | use a subset of `00,10,20,30,40` [scripts/project-node.sh:93] |
| Disk floor resolver missing or unreadable | `  FAIL  disk_floor — resolver missing or unreadable: $HERE/disk_floor.py`, exit 1 [scripts/project-node.sh:167] | fail-closed | the no-`python3` path, which warns and substitutes the built-in default [scripts/project-node.sh:164] | restore `scripts/disk_floor.py` in the staged set [scripts/node-create.sh:23] |
| Malformed floor value | `  FAIL  disk_floor — FAIL disk-floor: NODE_DISK_FLOOR: 999999 GiB exceeds the maximum of 4096 GiB`, exit 1 [scripts/project-node.sh:174] | fail-closed | a low but valid floor, which admits the node [scripts/project-node.sh:185] | fix the value; a typo must never lower a floor [scripts/disk_floor.py:16] |
| Below floor after reclaim (`--apply`) | `  FAIL  disk — $free GB free after reclaim < floor …`, then `NODE: FAIL (disk admission)`, exit 1 [scripts/project-node.sh:227] [scripts/project-node.sh:228] | fail-closed | below floor in `--check`, which prints the same `disk` FAIL plus a reclaim note and keeps measuring [scripts/project-node.sh:200] | free disk or change the floor with `--disk-floor` [scripts/project-node.sh:172] |
| `CRIER_URL` unset | `  FAIL  crier_url — CRIER_URL unset — the node has nothing to connect to (export CRIER_URL=http://crier.example:8767)` [scripts/project-node.sh:237] | fail-closed, but late: the run continues and refuses only at the summary [scripts/project-node.sh:826] | a reachable URL that answers non-200, which fails `reach:` instead [scripts/project-node.sh:250] | export `CRIER_URL` before provisioning [scripts/node-create.sh:121] |
| Crier or PyPI unreachable | `  FAIL  reach:$u — -> 000` for each URL [scripts/project-node.sh:250] | fail-closed at the summary | a `405` from crier is not a fault — the probe uses `GET` there and `HEAD` on PyPI for exactly that reason [scripts/project-node.sh:242] | fix egress, or point `CRIER_URL` at a live bus |
| A base tool absent | `  FAIL  tool:$t — missing` for each of `python3 git curl tar sha256sum` [scripts/project-node.sh:331] | fail-closed at the summary | optional helpers, which are WARN-only [scripts/project-node.sh:356] | install the tool; no layer is skipped [scripts/project-node.sh:330] |
| Kind toolchain absent | `  FAIL  tool:node` / `tool:cargo` / `tool:go`, each naming why that kind needs it [scripts/project-node.sh:362] [scripts/project-node.sh:380] [scripts/project-node.sh:421] | fail-closed | the pre-CF-218 WARN shape, kept only under the generic fallback [scripts/project-node.sh:374] | `--apply` installs the owned Go pin [scripts/project-node.sh:403]; node and cargo are the operator's |
| Harness adapter absent | `  FAIL  harness:$HARNESS — no adapter at scripts/harness/install-$HARNESS.sh` [scripts/project-node.sh:442] | fail-closed | an adapter that exists but prints no rows (next row) | stage the adapter for the selected `--harness` [scripts/node-create.sh:23] |
| Adapter present but unrunnable | **no row**: measured with an empty `PATH`, layer 20 printed `mktemp: command not found`, ran an empty command, and added 0 to `FAILED` [scripts/project-node.sh:448] [scripts/project-node.sh:458] | **no-row / fail-open** — a real hole: only the child's `  FAIL` rows are counted, its exit code is not [scripts/project-node.sh:455] | a genuinely missing adapter, which does print a FAIL row [scripts/project-node.sh:442] | fix `mktemp`/the adapter path; until then the summary can under-count layer 20 |
| Identity absent | `  FAIL  crier_identity — absent — stage a bundle and re-run; a node without an identity is invisible` [scripts/project-node.sh:471] | fail-closed | identity present but world-readable, a different row [scripts/project-node.sh:469] | stage the bundle with `bunker-crier-connect.sh`, which chmods 600 [scripts/bunker-crier-connect.sh:116] |
| Identity mode not 600 | `  FAIL  crier_mode — $m (must be 600)` [scripts/project-node.sh:469] | fail-closed | absence, above; the mode is checked, the contents never are [scripts/project-node.sh:467] | `chmod 600 ~/.node/crier.json` |
| No checkout in `--check` | `  FAIL  repo — $RP absent (pass --repo to clone)` [scripts/project-node.sh:720] | fail-closed | `--apply` with `--repo`, which clones instead [scripts/project-node.sh:699] | clone separately, or run `--apply --repo URL` |
| Clone ref not found | `  FAIL  repo_clone — ref '$REF' was not found; pass --ref <branch-or-tag>` [scripts/project-node.sh:712] | fail-closed | repository access failure, which keeps the clone's own last line [scripts/project-node.sh:714] | pass a real `--ref`; the default is `main` [scripts/project-node.sh:40] |
| Clone fails after the ref resolved | `  FAIL  repo_clone — … (clone failed after ref '$REF' resolved)` [scripts/project-node.sh:708] | fail-closed | an access failure, which `ls-remote` reports with a different exit code [scripts/project-node.sh:711] | read the clone's last line, which the row carries [scripts/project-node.sh:706] |
| Dirty checkout | `  WARN  freshness — … dirty=… — a local edit on the node is a finding …`, and the run still ends `NODE: PASS` [scripts/project-node.sh:748] | **fail-open by policy** — the node may be mid-task [specs/NODE.md:177] | drift, which is a FAIL [scripts/project-node.sh:751] | take the edit upstream; it is never repaired here [scripts/project-node.sh:729] |
| Behind or diverged | `  FAIL  freshness — … behind=1 …`, exit 1 [scripts/project-node.sh:751] | fail-closed | dirty-only, which is a WARN [scripts/project-node.sh:746] | a diverged tree cannot fast-forward; fix upstream and re-run |
| Freshness unmeasurable | the same FAIL text with `${fs_reason:-checkout freshness could not be measured}` [scripts/project-node.sh:751] | fail-closed — an unmeasurable node is not a PASS [scripts/project-node.sh:750] | a measured PASS, which carries `behind=0 ancestor=true` [scripts/project-node.sh:744] | make `git` and the origin remote work on the node |
| Clone directory exists, HEAD unborn | `  PASS  repo — $RP @ ` with an empty revision, then `FAIL freshness … unborn HEAD (no commits)` [scripts/project-node.sh:696] | **no-row on the `repo` row**, fail-closed only through freshness — measured: a `.git` with no checkout still satisfies `-d "$RP/.git"` | a real checkout, which prints a short sha [scripts/project-node.sh:696] | clone properly, or delete `$RP` and let `--apply` clone [scripts/project-node.sh:702] |
| `lib.sh` absent | **raw shell errors and no rows at all**: `project-node.sh: line 35: …/lib.sh: No such file or directory`, then `ok:` / `say:` / `bad:` `command not found` down the file, ending in `FAILED: unbound variable` — at `458` with the adapter present, `826` without it, `168` when `disk_floor.py` is missing too — and exit **1** [scripts/project-node.sh:35] [scripts/project-node.sh:458] [scripts/project-node.sh:826] | **fail-closed, with no diagnostics — and by accident, not by check**: nothing probes `$HERE/lib.sh`; the node is refused only because `set -u` [scripts/project-node.sh:29] hits the unset counter, whose `FAILED=${FAILED:-0}` initialiser lives in the file that is missing [scripts/lib.sh:11] | the fail-open this is one flag away from — the same copy with line 29 reduced to `set -o pipefail` adds 0 to an empty counter, takes the PASS branch and exits **0**; and a missing tool, which layer 10 names as a row [scripts/project-node.sh:331] | the staged set must include `lib.sh` [scripts/node-create.sh:23]; the abort line is not fixed (`168` when `disk_floor.py` is missing too, `458` with the adapter present, `826` otherwise) so nothing names the cause — a real probe is still owed [scripts/project-node.sh:168] [scripts/project-node.sh:458] |
| A layer failed under `--apply` | `  ..    manifest is written only when every layer passes` [scripts/project-node.sh:821] | fail-closed for the manifest: no `node.json` is written [scripts/project-node.sh:780] | an all-green `--apply`, which writes it [scripts/project-node.sh:817] | fix the FAIL rows and re-run `--apply` |

## 7. Environment and settings it reads

| Variable | Default | Read at | Effect if unset |
|---|---|---|---|
| `NODE_PROJECT` | empty [scripts/project-node.sh:37] | before argument parsing [scripts/project-node.sh:37] | `--project` is mandatory, so an empty value exits 2 [scripts/project-node.sh:82] |
| `NODE_HARNESS` | `hermes` [scripts/project-node.sh:38] | adapter path [scripts/project-node.sh:440] | layer 20 looks for `harness/install-hermes.sh` |
| `NODE_REF` | `main` [scripts/project-node.sh:40] | clone and manifest [scripts/project-node.sh:702] | a repo whose default branch is not `main` fails `repo_clone`, naming `--ref` as the remedy [scripts/project-node.sh:712] |
| `NODE_GATEWAY_PORT` | `10800` [scripts/project-node.sh:41] | passed to the adapter, copied into the manifest [scripts/project-node.sh:449] [scripts/project-node.sh:809] | the adapter binds 10800 [scripts/harness/install-hermes.sh:17] |
| `NODE_ROLE` | `worker` [scripts/project-node.sh:42] | floor default and the `role` row [scripts/project-node.sh:150] | role `worker`, floor 5 GiB [scripts/project-node.sh:151] |
| `NODE_KINDS` | unset [scripts/project-node.sh:47] | kind set, with `KINDS_SET` recording that it was declared [scripts/project-node.sh:49] | kinds are derived from `$HOME/repo` markers, else the labelled generic fallback [scripts/project-node.sh:338] [scripts/project-node.sh:343] |
| `NODE_DISK_FLOOR` | unset; second in the chain [scripts/disk_floor.py:13] | inside the resolver, not in this script [scripts/disk_floor.py:129] | the chain falls through to config, then the role default [scripts/disk_floor.py:16] |
| `CRIER_URL` | empty [scripts/project-node.sh:235] | preflight bus probe [scripts/project-node.sh:236] | `FAIL crier_url` and, as measured here, a refused node [scripts/project-node.sh:237] |
| `CRIER_BASE` | `http://crier.example:8767` [scripts/project-node.sh:810] | manifest `bus.base` only [scripts/project-node.sh:810] | the manifest records the example URL; the probe still used `CRIER_URL` |
| `GO_INSTALL_ROOT` | `$HOME/go-toolchain` [scripts/project-node.sh:414] | Go binary resolution [scripts/project-node.sh:415] | the owned pin is looked for at `$HOME/go-toolchain/current/bin/go`, then `PATH` [scripts/project-node.sh:418] |
| `GOPROXY` | unset; only a fallback [scripts/project-node.sh:305] | the Go proxy row when `go env GOPROXY` is empty [scripts/project-node.sh:304] | the row prints `via unset` and the download is attempted with no proxy |
| `HOME` | unset is not handled [scripts/project-node.sh:50] | `$STATE`, `$RP` and every disk read [scripts/project-node.sh:50] [scripts/project-node.sh:53] [scripts/project-node.sh:202] | paths expand wrongly; a provisioned node home is assumed |
| `USER` | `node` [scripts/project-node.sh:808] | manifest `repo.path` [scripts/project-node.sh:808] | the manifest records `/home/node/repo` |
| `PATH` | inherited | every tool lookup, the helpers' probes and the adapters [scripts/lib.sh:13] | an empty `PATH` still yields named FAIL rows and exit 1 — measured `NODE: FAIL (11)` [tests/selftest.sh:15] |
| `TMPDIR` | inherited | `mktemp` for the adapter log, the Go probe and freshness scratch [scripts/project-node.sh:448] | scratch lands in the system temp dir; an unusable temp is a `no-row` failure (§6) |
| `HERMES_PIN`, `HERMES_PYTHON_BIN` | `0.19.0`, `python3` [scripts/harness/install-hermes.sh:18] | read by the child adapter, and therefore decide layer 20's verdict | the adapter grades the pinned version and the default interpreter — measured `FAIL python — hermes-agent 0.19.0 requires python >=3.11,<3.14; found 3.14.9` [scripts/harness/install-hermes.sh:47] |

## 8. Evidence of record

- Source read in full at commit `f63acd3`: 826 lines of `scripts/project-node.sh`. Every row above resolves to a line in that file, `scripts/lib.sh`, or the peer file that owns the other side of the contract.
- The node is one project's node: `--project` is mandatory and a node belongs to exactly one project [scripts/project-node.sh:82] [fact: FACT-01] [fact: FACT-02].
- Credentials travel as files at mode 600, never as argv values [fact: FACT-05]; layer 30 grades presence and mode of `$HOME/.node/crier.json` and never reads its contents [scripts/project-node.sh:467] [scripts/project-node.sh:469]; the bundle is staged at 600 by its owner [scripts/bunker-crier-connect.sh:115].
- The identity check is necessary but not sufficient: crier verifies a per-agent signature before it looks the agent up, so a present identity with a wrong key still answers 401 downstream [fact: FACT-03].
- Runs recorded in this document, all on 2026-11-05 from this host: `--check --project cf-node` → `NODE: FAIL (4)`, exit 1; `--layers 40` clean → `NODE: PASS`, exit 0; dirty → `NODE: PASS`, exit 0 with a WARN row; behind → `NODE: FAIL (1)`, exit 1; empty `PATH` → `NODE: FAIL (11)`, exit 1; no `--project` → exit 2; `--kinds cobol` → `NODE: FAIL (1)`, exit 1; `NODE_DISK_FLOOR=999999` → `NODE: FAIL (1)`, exit 1; `lib.sh` removed from an otherwise complete staged set → exit 1 with zero rows and no `NODE:` summary, and the same copy with line 29's `-u` dropped → exit 0 (§6).
- Self-test arms that exercise this module and can go red: section 2 (empty `PATH`) [tests/selftest.sh:14], section 13 (floor refused before any install) [tests/selftest.sh:518], section 14 (adapter FAIL rows counted, CF-055) [tests/selftest.sh:528], section 20 (reclaim before refusal, `--check` never reaps) [tests/selftest.sh:938], section 47 (checkout freshness can go RED, CF-244) [tests/selftest.sh:2829], section 49 (layer 10 grades the repo's kind, Go included, CF-218) [tests/selftest.sh:3284].
- This document's own gate: `python3 scripts/master_doc_check.py docs/master --only 33- --strict` → `MASTER-DOC: PASS`.
