# 26. scripts/node-create.sh

| Field | Value |
|---|---|
| Path | `~/code-factory/scripts/node-create.sh` — 139 lines [scripts/node-create.sh:1] |
| Repository | `code-factory` |
| Revision | `b31c232` — the `origin/main` tip every locator below was measured against; the file's own last-touching commit is `50e5f5b` (2026-11-05, "feat(go): install a digest-pinned user-space toolchain — let Go-kind nodes fetch modules") |
| Status | **VERIFIED — 215 locator citations (102 distinct file:line pairs), all resolve; cites fact: FACT-01, FACT-02, FACT-04; CF-276 confirmed and the staged set measured item by item (§2c); four defects recorded in §8** |

## 1. Purpose and why it matters

- What it is: the **control-host orchestrator** for one node. It takes a project + repo + harness
  triple and performs four stages in order — spawn (or reuse) an agent, stage the provisioning
  scripts *into* that agent, run `project-node.sh --apply` inside it, then verify from the control
  host [scripts/node-create.sh:7-8] [scripts/node-create.sh:93-138]. It is an orchestrator, not a
  provisioner: every check that decides whether the node is good lives in `project-node.sh`
  (staged) or `verify-node.sh` (invoked), and this script's own judgement is only the exit status
  it derives from their rows [scripts/node-create.sh:121-135].
- The four stages, and the line that marks each: spawn/reuse [scripts/node-create.sh:96-104]; stage
  — `mkdir`, then one `bunker cp` per file, then `chmod` [scripts/node-create.sh:108-116]; provision
  — one `bunker exec` carrying the provisioner and its arguments
  [scripts/node-create.sh:120-125]; verify — `verify-node.sh` from *this* host
  [scripts/node-create.sh:127-135]. No `--agent` means a new agent named
  `node-$PROJECT-$(date +%H%M%S)` [scripts/node-create.sh:97]; a supplied `--agent` is reused, never
  respawned [scripts/node-create.sh:102-104].
- Why it matters: it is the only path from "a project" to "a node that can run that project's
  lanes". The foreman runs on the node, never on the control host (fact: FACT-01), and one bunker
  serves one project (fact: FACT-02). Its only in-tree caller is the config-driven provisioner,
  which runs it as step 6 with credentials already in place [scripts/bunker-provision.sh:500-504].
- What breaks if it is ABSENT: the config-driven provisioner prints
  `  FAIL  node_create — node-create.sh reported FAIL — see its rows; continuing with the identity`
  and carries on to write the node's identity anyway, with `rc=1`
  [scripts/bunker-provision.sh:507-511]. So absence does not stop a provision — it produces a node
  that has an identity and no provisioned layers, and the only failure marker is the parent's exit
  code. Nothing downstream re-checks that the layers ever ran.
- What breaks if it LIES: `NODE CREATED` is printed from a counter, not from a re-measurement
  [scripts/node-create.sh:137-138], and `warn` does not increment that counter
  [scripts/lib.sh:8]. The `verify` arm that exits **3** is treated as a warning, so a node with no
  transport from the control host prints `NODE CREATED` and exits 0 — measured (§3 row 6). The
  header calls the control-host verify the thing that makes the round trip meaningful
  [scripts/node-create.sh:7-8], and that is exactly the leg which can be skipped by design.
- Idempotence: reuse is keyed on `--agent` alone [scripts/node-create.sh:102], not on the node's
  state; a second run against the same agent re-stages and re-provisions over whatever is there
  [scripts/node-create.sh:106-125]. There is no drift check of the node before overwriting.
- Blast radius of one run: one agent on one server [scripts/node-create.sh:18], six staged files
  (§2c), one clone inside the node [scripts/project-node.sh:699-704], and — on failure after a
  spawn — a retained agent plus the exact destroy command to remove it
  [scripts/node-create.sh:51-56] [scripts/node-create.sh:11-12].

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

How absence is *detected* is the column that matters: this script probes almost nothing itself, so
most absences surface as a misattributed row or a bare `command not found`.

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `bash` with arrays and `[[ =~ ]]` | unpinned; a `local -a` array at [scripts/node-create.sh:23] and `${x//a/b}` at [scripts/node-create.sh:38] | control host, on `PATH` | the shebang only [scripts/node-create.sh:1]; no version probe anywhere |
| `bunker` CLI | 0.2.0 measured here (`bunker version` → `bunker 0.2.0`, commit `3f66c4e6`) | `PATH`, resolved at [scripts/node-create.sh:163] | **named since CF-281**: `have` now exits non-zero on absence [scripts/lib.sh:41-45], so `b=$(have bunker) || { … }` fires and the run prints one `  FAIL  bunker_cli — no bunker client on PATH — install the bunker client; …` row followed by `NODE INCOMPLETE (1)`, exit 1, before anything is spawned. Measured before the fix: `b=$(have bunker)` could not fail (the status was constant 0), so the run reached the spawn with an empty `$b` and reported `  FAIL  spawn — …: line 171: : command not found` — an absent client reported as a failed spawn |
| `scripts/lib.sh` | in-tree | `$HERE/lib.sh`, sourced at [scripts/node-create.sh:16] | **unguarded**. Measured with the file removed: `line 16: …/lib.sh: No such file or directory`, then `line 26: bad: command not found`, exit 1 — a script that cannot report its rows |
| the staged set: `project-node.sh`, `install-go.sh`, `lib.sh`, `disk_floor.py`, `reclaim_disk.py`, `harness/install-$HARNESS.sh` | in-tree | `$HERE/<file>`, checked one by one at [scripts/node-create.sh:25-27] | named and counted: `  FAIL  staged_set — missing scripts/disk_floor.py`, exit 1, before any bunker call (measured, §3 row 4). The *runtime* check runs at [scripts/node-create.sh:84], which also exits 1 before any transport |
| `scripts/verify-node.sh` | in-tree | `$HERE/verify-node.sh`, invoked at [scripts/node-create.sh:130] | **not probed**. Measured with the file removed: `line 130: …/verify-node.sh: No such file or directory`, the shell returns 127, and the `*)` arm folds it into `  FAIL  verify — round trip failed — node remains unverified` → `NODE INCOMPLETE (1)`, exit 1. Fail-closed, but the row names the round trip, not the missing file |
| `bash`, `mkdir`, `chmod` **on the node** | any | inside the agent, via `bunker exec … bash -lc` [scripts/node-create.sh:108] [scripts/node-create.sh:114] [scripts/node-create.sh:121] | not detected by name: the `bunker exec` returns non-zero and the owning stage prints `  FAIL  staged — …` [scripts/node-create.sh:109] or `  FAIL  provision — node reported FAIL …` [scripts/node-create.sh:124] |
| `date`, `tail` | coreutils | control host, on `PATH` | not probed. `date +%H%M%S` builds the agent id [scripts/node-create.sh:97] and `tail -1` builds the spawn failure row from `/tmp/spawn.log` [scripts/node-create.sh:99] |
| `CRIER_URL` | none — no default | environment, read at [scripts/node-create.sh:73] | named refusal before any bunker call: `  FAIL  crier_url — CRIER_URL unset or empty — export CRIER_URL=http://crier.example:8767`, exit 1 (measured, §3 row 8) |
| `BUNKER_SERVER` | empty default [scripts/node-create.sh:18] | environment | `  FAIL  server_declared — BUNKER_SERVER unset — no agent host to create the node on` followed by `NODE INCOMPLETE (1)`, exit 1, and **no** cleanup line because nothing was spawned (measured, §3 row 9) |

### 2b. Library contracts

No imports; the file sources one library [scripts/node-create.sh:16]. Each symbol it relies on is
named, with the contract it depends on.

| Symbol | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `say` | [scripts/lib.sh:5] | `printf '%s\n' "$*"` — one line, no level prefix | the stage narration loses its `  ..    ` shape; nothing parses it |
| `ok` / `warn` / `note` | [scripts/lib.sh:6] [scripts/lib.sh:8] [scripts/lib.sh:9] | print only; **do not** touch `FAILED` | a `warn` that started counting would turn the CF-224 arm [scripts/node-create.sh:133] into a failure |
| `bad` | [scripts/lib.sh:7] | prints `  FAIL  <check> — <msg>` **and** increments `FAILED` | this is the whole verdict mechanism: the final line reads `$FAILED` [scripts/node-create.sh:138]. A `bad` that stopped counting would let `NODE CREATED` print after a refusal |
| `FAILED` | [scripts/lib.sh:11] | `${FAILED:-0}` — taken from the environment if the caller exported it | an exported non-zero `FAILED` would make the first `incomplete()` fire on an all-green run; the counter is process-local, which is why the parent folds a child's rows into its own process instead [scripts/bunker-provision.sh:508] |
| `have` | [scripts/lib.sh:41-45] | present: exit 0 and the resolved path on stdout; absent: **non-zero** and nothing on stdout (CF-281) | the contract the guard at [scripts/node-create.sh:163] now relies on; a caller that tests only emptiness still works, and one that tests the status now gets the truth |
| `shq` | [scripts/lib.sh:54-57] | single-quotes a value, escaping an embedded `'` as `'\''` | six data values are escaped before they cross into the node's shell — project, port, crier URL, harness, repo, ref [scripts/node-create.sh:78-83]. If it regressed to plain quoting, a hostile `--repo` or `--ref` would become code in the node's shell [scripts/node-create.sh:121] |

### 2c. Service contracts (both sides named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| `bunkerd` on `$SERVER`, via the `bunker` client | script → node host | `bunker spawn <agent> --server <s> --ttl <ttl>` [scripts/node-create.sh:99] | the agent id it just generated, and the TTL string as given | the daemon itself; the client documents its peer as "the active bunkerd server" and validates `--ttl` **locally, before the RPC**. In-repo qualification of the server half: [scripts/bunker-server-install.sh:1-8] |
| same | script → node | `bunker cp <local> <agent>:node-scripts/<file> --server <s>`, once per staged file [scripts/node-create.sh:111] | an absolute local path → a destination path inside the agent | the client's contract is `<agent-id>:/path`, copied over SCP with the per-agent key it saved at spawn. **Not measured**: this script passes a *relative* destination (`node-scripts/<file>`), not the documented absolute form; no node was created here, so whether the client resolves it against the agent's home is unverified (§8 defect 4) |
| same | script → node | `bunker exec --server <s> <agent> -- bash -lc '<text>'` — three calls [scripts/node-create.sh:108] [scripts/node-create.sh:114] [scripts/node-create.sh:121] | (1) `mkdir -p ~/node-scripts/harness`; (2) `chmod +x` on three of the six; (3) the provisioning command | the client documents `--` as the separator between its own flags and the remote command, and `bash -lc` is the remote shell — so every data value in (3) must already be `shq`-quoted [scripts/node-create.sh:78-83] |
| `project-node.sh` **on the node** | script → node, then node-internal | the third `exec` above [scripts/node-create.sh:121] | `NODE_PROJECT='…' NODE_GATEWAY_PORT='…' CRIER_URL='…' ~/node-scripts/project-node.sh --apply --project '…' --harness '…' --repo '…' --ref '…'` — all six values quoted, three also passed as environment | [scripts/project-node.sh:59-80] parses exactly these flags; the manifest it writes is [scripts/project-node.sh:780-817]. This script captures nothing: the node's rows go straight to the operator's terminal |
| `verify-node.sh` **on the control host** | script → local process | direct invocation, `--agent --server --port` [scripts/node-create.sh:130] | agent id, server name, port (default 10800) | [scripts/verify-node.sh:20-35]: it re-reads `BUNKER_SERVER` from the environment and refuses when empty **before** it looks at `--server`, so passing `--server` here does not remove the caller's obligation to export it [scripts/verify-node.sh:35] |
| crier bus | **no direct edge** | — | — | this script never contacts crier. The only crier traffic in a create happens inside `project-node.sh` layer 00 — `GET $CRIER/health` and `HEAD https://pypi.org/simple/` [scripts/project-node.sh:244-251] — whose GET-only nature is documented at [docs/master/04-scripts-bunker-crier-connect-sh.md:90] (fact: FACT-03 for the 401-before-lookup ordering) |
| `$HOME/node-bus-worker.py` on the node | **a contract this script does not satisfy** | — | the connect script's node-side probe guards on `-f "$HOME/node-bus-worker.py"` and runs `python3 … --check` under a 45 s timeout [scripts/bunker-crier-connect.sh:53] | nothing in the staged set puts that file there — see the manifest below and §8 defect 1 |

**The staged set, item by item — what actually lands on the node.** Every item is named in the array
literal at [scripts/node-create.sh:23], copied one per iteration of the loop at
[scripts/node-create.sh:110-113], and checked for existence at
[scripts/node-create.sh:25-27]. The measured `--staged-files` output is in §3; this table is that
output, resolved.

| # | Staged item | Line that stages it | Lands at, inside the node | Read on the node by |
|---|---|---|---|---|
| 1 | `project-node.sh` | [scripts/node-create.sh:23], copied at [scripts/node-create.sh:111] | `~/node-scripts/project-node.sh` | the provisioning `exec` [scripts/node-create.sh:121] |
| 2 | `install-go.sh` | [scripts/node-create.sh:23], copied at [scripts/node-create.sh:111] | `~/node-scripts/install-go.sh` | the Go-kind apply path [scripts/project-node.sh:399-403] |
| 3 | `lib.sh` | [scripts/node-create.sh:23], copied at [scripts/node-create.sh:111] | `~/node-scripts/lib.sh` | sourced by the entry point [scripts/project-node.sh:35] and by the adapter [scripts/harness/install-hermes.sh:14] |
| 4 | `disk_floor.py` | [scripts/node-create.sh:23], copied at [scripts/node-create.sh:111] | `~/node-scripts/disk_floor.py` | layer 00's floor resolver [scripts/project-node.sh:166-173] |
| 5 | `reclaim_disk.py` | [scripts/node-create.sh:23], copied at [scripts/node-create.sh:111] | `~/node-scripts/reclaim_disk.py` | layer 00's reclaimer, apply mode only [scripts/project-node.sh:207-212] |
| 6 | `harness/install-$HARNESS.sh` (here `harness/install-hermes.sh`) | [scripts/node-create.sh:23], copied at [scripts/node-create.sh:111] | `~/node-scripts/harness/install-hermes.sh` | the harness layer's adapter [scripts/project-node.sh:440-458] |
| — | **`node-bus-worker.py` — not staged** | absent from the array literal at [scripts/node-create.sh:23]; nothing else under `scripts/` copies it | — | **the connect probe expects `$HOME/node-bus-worker.py`** [scripts/bunker-crier-connect.sh:53] and finds nothing |

Two details of the staging leg that the manifest alone does not show: `chmod +x` covers only three
of the six — the entry point, the Go installer and `harness/*.sh` — and deliberately not `lib.sh`
(sourced) or the two `.py` files (invoked through `python3`) [scripts/node-create.sh:114]; and the
destination directory is created before the first copy, or the stage fails as a whole
[scripts/node-create.sh:108-109].

**How the staged set is validated, and the limit of that validation.** `staged_files` scans only two
files for `$HERE/…` references — the entry point and the selected adapter
[scripts/node-create.sh:30] — substitutes the chosen harness into `$HARNESS`
[scripts/node-create.sh:38], resolves the adapter's `../lib.sh` to a root-relative name
[scripts/node-create.sh:39-40], and fails when a reference is not in the array
[scripts/node-create.sh:41-44]. A dependency that neither of those two files names by `$HERE/` is
invisible to the check — which is exactly why `node-bus-worker.py`, referenced from a *third* script
on a path this validator never reads, is not caught (measured both ways, §3 rows 4 and 5).

## 3. Verification

The module's own check is `--staged-files`, documented in the header as the flag that validates
runtime references and prints the staging manifest **without bunker**
[scripts/node-create.sh:13], and implemented to exit before any transport or environment probe
[scripts/node-create.sh:72]. The repository suite asserts the same thing twice: the six-item count
is a literal in the `--ref` section [tests/selftest.sh:1651], and the staged-set section drives the
manifest into a fixture and mutates it to prove the check can go red
[tests/selftest.sh:657-704].

| # | Check | Command | Expected | Last run | Result |
|---|---|---|---|---|---|
| 1 | staging manifest | `bash scripts/node-create.sh --staged-files` | six lines, exit 0, no `bunker` and no `CRIER_URL` needed | 2026-11-05 | **PASS** — six lines, exit 0; identical with `CRIER_URL` and `BUNKER_SERVER` unset |
| 2 | the manifest is harness-dependent | `… --staged-files --harness opencode` | the last line becomes `harness/install-opencode.sh` | 2026-11-05 | **PASS** |
| 3 | full create against a stub transport | the real script + a stub `bunker` + a stub `verify-node.sh` | nine transport calls, `PASS` rows, `NODE CREATED`, exit 0 | 2026-11-05 | **PASS** — transcript 2 |
| 4 | a staged item removed | move `disk_floor.py` away, then `--staged-files` | `FAIL staged_set — missing scripts/disk_floor.py`, exit 1 | 2026-11-05 | **PASS** (refuses) |
| 5 | a `$HERE` reference outside the set | append `echo "$HERE/node-bus-worker.py"` to a scratch `project-node.sh`, then `--staged-files` | `FAIL staged_set — project-node.sh references unstaged node-bus-worker.py`, exit 1 | 2026-11-05 | **PASS** — the validator *can* see this shape, but only from the two files it scans |
| 6 | verify answers 3 (CF-224) | stub `verify-node.sh` exits 3 | `WARN verify`, `NODE CREATED`, exit 0 | 2026-11-05 | **PASS** — and this is the fail-open arm |
| 7 | verify answers 1 | stub `verify-node.sh` exits 1 | `FAIL verify`, `NODE INCOMPLETE (1)`, cleanup line, exit 1 | 2026-11-05 | **PASS** |
| 8 | `CRIER_URL` unset | `env -u CRIER_URL … --project demo` | named refusal, exit 1, no bunker call | 2026-11-05 | **PASS** |
| 9 | `BUNKER_SERVER` empty | `BUNKER_SERVER= … --agent X` | `FAIL server_declared`, `NODE INCOMPLETE (1)`, exit 1, **no** cleanup line | 2026-11-05 | **PASS** |
| 10 | no `--project` | `CRIER_URL=… BUNKER_SERVER=…` with no flags | the usage line, exit 2 | 2026-11-05 | **PASS** |
| 11 | unknown argument | `--bogus` | `unknown arg: --bogus`, exit 2 | 2026-11-05 | **PASS** |
| 12 | `--harness codex` | `--staged-files --harness codex` | the validator should pass | 2026-11-05 | **FAILS** — `  FAIL  staged_set — harness/install-codex.sh references unstaged harness/harness-vars.sh`, exit 1 (§8 defect 2) |
| 13 | the repository suite, this module's sections | sections 16 and 35 extracted verbatim and run standalone | every leg `PASS`, `EXTRACT: PASS` | 2026-11-05 | **PASS** — transcript 5 |
| 14 | a real node: spawn → stage → provision → verify against a bunker host | `… --repo … --harness hermes` with the real client | `NODE CREATED`, exit 0 | never | **not run** — this task forbids creating a node; row 3 stubs the transport, so nothing here witnesses a real `bunker cp` |

Transcript 1 (rows 1-2), literal:

```
$ bash scripts/node-create.sh --staged-files
project-node.sh
install-go.sh
lib.sh
disk_floor.py
reclaim_disk.py
harness/install-hermes.sh
EXIT=0
$ bash scripts/node-create.sh --staged-files --harness opencode
project-node.sh
install-go.sh
lib.sh
disk_floor.py
reclaim_disk.py
harness/install-opencode.sh
EXIT=0
```

Transcript 2 (row 3) — the real script, a stub `bunker` that only records argv, and a stub
`verify-node.sh`:

```
$ PATH=$FX/bin:$PATH CRIER_URL=http://crier.example:8767 BUNKER_SERVER=cf-host \
    bash ./node-create.sh --project demo --repo git@example:demo.git --agent node-demo-1
node-create — project=demo harness=hermes server=cf-host
  PASS  spawn — reusing node-demo-1
  ..    staging scripts
  PASS  staged — project-node.sh + install-go.sh + lib.sh + disk_floor.py + reclaim_disk.py + harness/install-hermes.sh
  ..    provisioning inside the node
  PASS  provision — node reports PASS
  ..    verifying from the control host
  PASS  verify — round trip proven from the control host

NODE CREATED: node-demo-1
manifest: /home/<uid>/.node/node.json
EXIT=0
```

The transport calls behind it, verbatim from the stub's log — nine lines, six of them copies:

```
exec --server cf-host node-demo-1 -- bash -lc mkdir -p ~/node-scripts/harness
cp …/scripts/project-node.sh node-demo-1:node-scripts/project-node.sh --server cf-host
cp …/scripts/install-go.sh node-demo-1:node-scripts/install-go.sh --server cf-host
cp …/scripts/lib.sh node-demo-1:node-scripts/lib.sh --server cf-host
cp …/scripts/disk_floor.py node-demo-1:node-scripts/disk_floor.py --server cf-host
cp …/scripts/reclaim_disk.py node-demo-1:node-scripts/reclaim_disk.py --server cf-host
cp …/scripts/harness/install-hermes.sh node-demo-1:node-scripts/harness/install-hermes.sh --server cf-host
exec --server cf-host node-demo-1 -- bash -lc chmod +x ~/node-scripts/project-node.sh ~/node-scripts/install-go.sh ~/node-scripts/harness/*.sh
exec --server cf-host node-demo-1 -- bash -lc NODE_PROJECT='demo' NODE_GATEWAY_PORT='10800' CRIER_URL='http://crier.example:8767' ~/node-scripts/project-node.sh --apply --project 'demo' --harness 'hermes' --repo 'git@example:demo.git' --ref 'main'
```

Transcript 3 (rows 4, 5, 12), literal:

```
$ bash ./node-create.sh --staged-files            # disk_floor.py moved away
  FAIL  staged_set — missing scripts/disk_floor.py
EXIT=1
$ bash ./node-create.sh --staged-files            # scratch project-node.sh references the worker
  FAIL  staged_set — project-node.sh references unstaged node-bus-worker.py
EXIT=1
$ bash ./node-create.sh --staged-files --harness codex
  FAIL  staged_set — harness/install-codex.sh references unstaged harness/harness-vars.sh
EXIT=1
```

Transcript 4 (rows 6-9), literal:

```
$ ./node-create.sh …            # verify-node.sh stub: exit 3
  WARN  verify — UNVERIFIED — the node answers inside itself but this host has no transport to it (CF-224); the node is not marked failed

NODE CREATED: node-demo-114124
manifest: /home/<uid>/.node/node.json
EXIT=0
$ ./node-create.sh …            # verify-node.sh stub: exit 1
  FAIL  verify — round trip failed — node remains unverified
NODE INCOMPLETE (1)
cleanup required: bunker destroy node-demo-114124 --server cf-host
EXIT=1
$ env -u CRIER_URL BUNKER_SERVER=cf-host ./node-create.sh --project demo
  FAIL  crier_url — CRIER_URL unset or empty — export CRIER_URL=http://crier.example:8767
EXIT=1
$ CRIER_URL=http://crier.example:8767 BUNKER_SERVER= ./node-create.sh --project demo --agent node-demo-1
  FAIL  server_declared — BUNKER_SERVER unset — no agent host to create the node on
NODE INCOMPLETE (1)
EXIT=1
```

Transcript 5 (row 13), the repository suite's own legs for this module, extracted verbatim:

```
16. node-create staged set covers the disk floor and names missing dependencies
  PASS  staged disk floor resolves: 4096 GiB from env; admission refuses before installs
  PASS  missing disk floor -> one countable FAIL row, NODE: FAIL (1), exit 1
  PASS  disk floor omitted from scratch manifest -> validation exit 1
  PASS  owned failure names spawned agent and explicit-server destroy command
  PASS  reused agent failure does not request destruction
  PASS  copy-failure failure names spawned agent and explicit-server destroy command
  PASS  crier_url handoff preserves exported URL and shell metacharacters
  PASS  crier_url refusal rejects unset and empty bus before bunker invocation
35. node-create accepts and forwards --ref (CF-153)
  PASS  --staged-files --ref master -> exit 0, same seven-file staged set
  PASS  ref 'master' crosses the transport as --ref 'master'
  PASS  ref 're'lease' crosses the transport as --ref 're'\''lease'

EXTRACT: PASS
EXIT=0
```

## 4. Metrics emitted

**None.** This script emits no counter, no status file, no JSON and no metric of any kind — it has
one process-local counter, `FAILED`, which `bad` increments and the last line reads
[scripts/lib.sh:7] [scripts/node-create.sh:138]. Nothing is written on the control host: the only
file it touches there is `/tmp/spawn.log`, a fixed path that each run truncates and that nobody
removes [scripts/node-create.sh:99]. The one durable artifact a create produces is not this
script's — it is the node's manifest, written by the provisioner at
[scripts/project-node.sh:781-817], and only when every layer passed [scripts/project-node.sh:780].

So the only measurable state after a create is the manifest inside the node and the staged files
under `~/node-scripts`, and both require a `bunker exec`. Create rate, per-stage duration, the
failure/stage breakdown and time-to-ready are all unanswerable from any store, because this path
records nothing. A countable create would need one row per stage with its duration and outcome;
none exists today.

## 5. Log lines it can generate

All of these go to stdout through `say`/`ok`/`warn`/`bad`/`note` [scripts/lib.sh:5-9], except the
ones marked *stderr*. The "level" is the literal row prefix — there is no logging framework here, so
the prefix is the only severity. **Kind** is assigned as: *evidentiary* = the line is the result of a
transport call or a child process that actually ran and could have failed; *descriptive* = narration,
or a restatement of a value this script already decided, with nothing measured behind it.

| Level | Line (verbatim) | Emitted when | Kind |
|---|---|---|---|
| stdout | `node-create — project=$PROJECT harness=$HARNESS server=$SERVER` | first row after the server gate [scripts/node-create.sh:93] | descriptive |
| stdout | `  ..    spawning $AGENT (ttl $TTL)` | no `--agent` was given [scripts/node-create.sh:98] | descriptive |
| stdout | `  PASS  spawn — $AGENT` | `bunker spawn` returned 0 [scripts/node-create.sh:101] | evidentiary |
| stdout | `  PASS  spawn — reusing $AGENT` | `--agent` was given; no call was made [scripts/node-create.sh:103] | descriptive — proves nothing about the agent |
| stdout | `  ..    staging scripts` | before the staging leg [scripts/node-create.sh:107] | descriptive |
| stdout | `  PASS  staged — project-node.sh + install-go.sh + lib.sh + disk_floor.py + reclaim_disk.py + harness/install-hermes.sh` | every `cp` in the loop returned 0; the `+` is the manifest joined on its newlines [scripts/node-create.sh:116] | evidentiary — it is the list of copies that succeeded |
| stdout | `  ..    provisioning inside the node` | before the provisioning `exec` [scripts/node-create.sh:119] | descriptive |
| stdout | `  PASS  provision — node reports PASS` | the node's `project-node.sh` exited 0 [scripts/node-create.sh:122] | descriptive — it repeats the node's own claim; the node's rows printed just above are the evidence |
| stdout | `  FAIL  provision — node reported FAIL — see the output above` | the node's `project-node.sh` exited non-zero [scripts/node-create.sh:124] | evidentiary — a child ran and failed |
| stdout | `  ..    verifying from the control host` | before `verify-node.sh` [scripts/node-create.sh:128] | descriptive |
| stdout | `  PASS  verify — round trip proven from the control host` | `verify-node.sh` exited 0 [scripts/node-create.sh:132] | evidentiary — the only externally witnessed green |
| stdout | `  WARN  verify — UNVERIFIED — the node answers inside itself but this host has no transport to it (CF-224); the node is not marked failed` | `verify-node.sh` exited 3 [scripts/node-create.sh:133] | evidentiary of the *absence* of proof — and it does not touch the counter |
| stdout | `  FAIL  verify — round trip failed — node remains unverified` | `verify-node.sh` exited anything else, 127 included [scripts/node-create.sh:134] | evidentiary |
| stdout | `NODE INCOMPLETE ($FAILED)` | any failure path that falls through to the summary [scripts/node-create.sh:52] | evidentiary — the number is the counted `FAIL` rows |
| stdout | `cleanup required: bunker destroy %q --server %q` | the same, **only** when this run spawned the agent [scripts/node-create.sh:53-54] | evidentiary — the binding is `SPAWNED`, set at [scripts/node-create.sh:100] |
| stdout | `NODE CREATED: $AGENT` | `FAILED` is 0 at the end [scripts/node-create.sh:138] | evidentiary of the counter, not of the node |
| stdout | `manifest: /home/<uid>/.node/node.json` | immediately after `NODE CREATED` [scripts/node-create.sh:138] | descriptive — a literal string, not an interpolation |
| stdout | `usage: $0 --project P --repo URL [--ref R] [--harness H] [--agent ID]` | no `--project`, after the URL, staging and server gates [scripts/node-create.sh:89] | descriptive |
| stderr | `unknown arg: $1` | an argv element matches no case [scripts/node-create.sh:69] | evidentiary |
| stdout | `  FAIL  bunker_cli — no bunker client on PATH — install the bunker client; without it no agent can be spawned, staged or verified (nothing was attempted)` | an absent client at [scripts/node-create.sh:163], followed by `NODE INCOMPLETE (1)` and exit 1 — **reachable since CF-281**, because `have` now returns non-zero [scripts/lib.sh:41-45] | evidentiary |
| stdout | `  FAIL  crier_url — CRIER_URL unset or empty — export CRIER_URL=http://crier.example:8767` | `CRIER_URL` empty [scripts/node-create.sh:74] | evidentiary |
| stdout | `  FAIL  server_declared — BUNKER_SERVER unset — no agent host to create the node on` | `BUNKER_SERVER` empty [scripts/node-create.sh:86] | evidentiary |
| stdout | `  FAIL  staged_set — missing scripts/$file` | a named staged file is absent on the control host [scripts/node-create.sh:26] | evidentiary — names the file |
| stdout | `  FAIL  staged_set — $source references unstaged $ref` | a `$HERE` reference is outside the manifest [scripts/node-create.sh:43] | evidentiary — names both sides |
| stdout | `  FAIL  staged — cannot create node-scripts directory` | the `mkdir` exec failed [scripts/node-create.sh:109] | evidentiary |
| stdout | `  FAIL  staged — copy failed: $file` | one `cp` failed [scripts/node-create.sh:112] | evidentiary — names the file |
| stdout | `  FAIL  staged — cannot set script permissions` | the `chmod` exec failed [scripts/node-create.sh:115] | evidentiary |
| stdout | `  FAIL  spawn — $(tail -1 /tmp/spawn.log)` | `bunker spawn` returned non-zero; the client log's last line is the whole diagnosis [scripts/node-create.sh:99] | evidentiary but lossy — one line, from a shared path |

The node's own rows also reach the operator through this script: it never captures the provisioning
`exec` or `verify-node.sh` [scripts/node-create.sh:121] [scripts/node-create.sh:130], so a create's
transcript is a superset of two other modules' output.

## 6. Failure modes

Direction is the fail-open / fail-closed sense: what the failure does to the *next* stage and to the
exit status.

| Failure | Direction | Presents as | Distinguished from | Recovery |
|---|---|---|---|---|
| The `bunker` client is not on `PATH` | fail-closed and **named since CF-281** | one `  FAIL  bunker_cli — no bunker client on PATH — …` row, then `NODE INCOMPLETE (1)`, exit 1, with no spawn attempted [scripts/node-create.sh:163] [scripts/lib.sh:41-45] (measured before the fix: no named row at all — `  FAIL  spawn — …: line 171: : command not found`, exit 1, an absent client reported as a failed spawn) | a real spawn refusal prints the client's own last line instead [scripts/node-create.sh:171] | install the client; the row names it and says nothing was attempted |
| `lib.sh` missing or unreadable | **fails with no rows at all** | `line 16: …/lib.sh: No such file or directory`, then `line 26: bad: command not found`, exit 1 — no `FAIL` row and no counter | a staged-set failure prints a named `FAIL` row | restore `scripts/lib.sh` beside the script; the shebang cannot help — the source is unguarded [scripts/node-create.sh:16] |
| `CRIER_URL` unset | **fail-closed, earliest** | named `FAIL crier_url`, exit 1, before `staged_files` and before any transport [scripts/node-create.sh:73-76] | `--staged-files` succeeds in the same environment, because it exits first [scripts/node-create.sh:72] | export the bus URL; nothing was touched |
| `BUNKER_SERVER` unset | fail-closed | `FAIL server_declared` + `NODE INCOMPLETE (1)`, exit 1, and **no** cleanup line because nothing was spawned [scripts/node-create.sh:85-88] | an unset server can never be discovered *after* a spawn — this gate precedes it [scripts/node-create.sh:96] | export the server name |
| `--project` missing | fail-closed, but late | the usage line and exit 2 — reached only after the URL, staging and server gates [scripts/node-create.sh:89] | an unset `BUNKER_SERVER` masks it entirely: measured, `FAIL crier_url` printed instead | pass `--project`; expect a different row first if the environment is also incomplete |
| A staged file is absent on the control host | fail-closed, before any transport | `FAIL staged_set — missing scripts/<file>`, exit 1 [scripts/node-create.sh:26] [scripts/node-create.sh:84] | a `cp` failure happens after the manifest was accepted and prints `FAIL staged — copy failed` instead [scripts/node-create.sh:112] | restore the file in `scripts/`; the row names it |
| `bunker spawn` fails | fail-open to the parent, fail-closed here | `FAIL spawn — <last log line>`, **exit 1 with no `NODE INCOMPLETE` and no cleanup line** [scripts/node-create.sh:99] | a post-spawn failure prints `NODE INCOMPLETE (n)` plus the destroy command [scripts/node-create.sh:51-56] | read `/tmp/spawn.log`; an invalid `--ttl` is refused by the client *before* the RPC, so the last line says so |
| A `cp` fails mid-stage | fail-closed; the agent is retained | `FAIL staged — copy failed: <file>` + `NODE INCOMPLETE (1)` + `cleanup required: bunker destroy <agent> --server <server>` [scripts/node-create.sh:112] [scripts/node-create.sh:54] | the same failure with `--agent` supplied prints no cleanup line, because this run did not spawn that agent | run the printed destroy command, or re-run with `--agent` to retry staging in place |
| The node's provisioning exits non-zero | **fail-open to the verify stage** | `FAIL provision — node reported FAIL`, and the run **continues** to `verify-node.sh` [scripts/node-create.sh:124]; if verify then passes, the summary is still `NODE INCOMPLETE (1)` because the counter carried the provision failure | a verify failure adds its own `FAIL verify` row [scripts/node-create.sh:134] | read the node's rows above the FAIL — they are the provisioner's, unfiltered |
| `verify-node.sh` answers 3 (CF-224) | **fail-open by design** | `WARN verify — UNVERIFIED …`, then `NODE CREATED` and **exit 0** [scripts/node-create.sh:133] [scripts/node-create.sh:138] | a real verify failure is `FAIL verify` with exit 1 | read exit 0 plus a WARN row as "node exists, round trip unproven"; publish a transport or accept a local-only node |
| `verify-node.sh` absent | fail-closed, misattributed | `line 130: …: No such file or directory`, then `FAIL verify — round trip failed`, exit 1 (measured) | a genuine round-trip failure prints the verifier's own rows first | restore `scripts/verify-node.sh`; the row names the round trip, not the file [scripts/node-create.sh:130] |
| `--harness codex` | **fail-closed before any work** | `FAIL staged_set — harness/install-codex.sh references unstaged harness/harness-vars.sh`, exit 1 — and that file exists nowhere in `scripts/harness/` [scripts/harness/install-codex.sh:47] | `--harness hermes` and `--harness opencode` validate clean (§3 row 2) | add `harness/harness-vars.sh` to the staged set, or teach the validator to ignore a reference the adapter itself guards with `[ -f ]` [scripts/harness/install-codex.sh:47] |
| The node has no `$HOME/node-bus-worker.py` | **fail-open, silently degraded** | nothing at all in this script: the create prints `PASS` at every stage, and the degradation surfaces later, when the connect probe's `if` yields no output and the run falls back to an unsigned read [scripts/bunker-crier-connect.sh:53] [scripts/bunker-crier-connect.sh:46-48] | a signed probe that fails prints `FAIL inbox` and stops the connect — an absent file prints **nothing** | stage the worker; see §8 defect 1 (CF-276). Until then a "successfully created" node cannot do the one thing fact: FACT-04 measures |

## 7. Environment and settings it reads

| Variable | Default | Effect if unset |
|---|---|---|
| `CRIER_URL` | **none** — empty counts as unset | hard refusal: `FAIL crier_url`, exit 1, before any staging or transport [scripts/node-create.sh:73-76]. It is the only variable whose absence stops the run at the gate; it is then escaped [scripts/node-create.sh:80] and forwarded both as an environment assignment and, inside the same command text, as the value the node's own layer 00 reads [scripts/node-create.sh:121] |
| `BUNKER_SERVER` | empty [scripts/node-create.sh:18] | `FAIL server_declared` + `NODE INCOMPLETE (1)`, exit 1 [scripts/node-create.sh:85-88]. This is the script's own `--server` for all three verbs; unlike `verify-node.sh` it never re-reads the variable later [scripts/verify-node.sh:35] |
| `NODE_REF` | `main` [scripts/node-create.sh:18] | the node clones `main`; `--ref` overrides it. The header names this as the remedy when a repo's default branch is not `main` [scripts/node-create.sh:9-10], and the value is escaped like every other datum [scripts/node-create.sh:83] |
| `FAILED` | `0` [scripts/lib.sh:11] | taken from the environment if the caller exported it — `NODE CREATED` is then unreachable on an all-green run [scripts/node-create.sh:138]. `bunker-provision.sh` calls this script as a child, so its own counter is not shared [scripts/bunker-provision.sh:504] |
| `PATH` | inherits the caller's | decides whether `bunker`, `date` and `tail` exist [scripts/node-create.sh:91] [scripts/node-create.sh:97] [scripts/node-create.sh:99]; no `PATH` is ever set for the remote side — the node gets whatever its login shell has [scripts/node-create.sh:121] |
| `TMPDIR` | not read | the spawn log is the fixed path `/tmp/spawn.log`, truncated per run and never removed [scripts/node-create.sh:99] |
| `HOME` | not read | the manifest message is the literal string `/home/<uid>/.node/node.json`, not an interpolation [scripts/node-create.sh:138]; the real path is resolved on the node by the provisioner [scripts/project-node.sh:50] |

`CRIER_QUOTED` is **assigned, never read as input** — it is the escaped form of `CRIER_URL`
[scripts/node-create.sh:80], alongside `PROJECT_QUOTED`, `PORT_QUOTED`, `HARNESS_QUOTED`,
`REPO_QUOTED` and `REF_QUOTED` [scripts/node-create.sh:78-83]. Settings that are flags rather than
variables, with their defaults on one line [scripts/node-create.sh:18]: `--project` (empty, required
unless `--staged-files`), `--repo` (empty; an empty repo is legal and means "no clone" at
[scripts/project-node.sh:699]), `--ref` (`main`), `--harness` (`hermes`), `--agent` (empty → spawn),
`--ttl` (`6h`), `--port` (`10800`, forwarded to both the node and the verifier), and `--staged-files`
(off; exits before every gate [scripts/node-create.sh:72]).

## 8. Evidence of record

- **Measured 2026-11-05** in a fresh worktree of `b31c232` (`~/proj-wt-md-26c`), bash 5.x, with the
  real `bunker` client present (0.2.0) but never invoked against a host. Every create transcript in
  §3 comes from a fixture: a copy of `scripts/`, a stub `bunker` that only records argv, and a stub
  `verify-node.sh`. **No node was created**, per this task's constraint.
- **The staged set, as measured**: seven items, exactly
  `project-node.sh install-go.sh lib.sh disk_floor.py reclaim_disk.py harness/harness-vars.sh
  harness/install-hermes.sh`, in that order, from `bash scripts/node-create.sh --staged-files`
  (exit 0). `harness/harness-vars.sh` joined the set with CF-229, when the adapters began sourcing
  the shared §5 contract. The repository suite pins the same count as a literal — "same seven-file
  staged set" [tests/selftest.sh:1667] — so changing the set is a suite change too, which is part of
  why the gap below has survived. **Corrected 2026-11-07 (CF-150):** the set is **eight** items —
  `node_gateway_auth.py` joined it so layer 20 can stage `dashboard.basic_auth` before the harness
  adapter — and the suite literal moved with it (`tests/selftest.sh` §35 now pins eight).
- **CF-276 is CONFIRMED on its three legs.** (a) `docs/OPERATIONS.md:209` says of
  `scripts/node-bus-worker.py` that "it is staged by provisioning" [docs/OPERATIONS.md:209].
  (b) The staged set at [scripts/node-create.sh:23] does not contain it, the `cp` loop copies only
  what that array holds [scripts/node-create.sh:110-113], the `chmod` list does not name it either
  [scripts/node-create.sh:114], and nothing else under `scripts/` copies it — the config-driven
  provisioner merely delegates here [scripts/bunker-provision.sh:504], so it inherits the same set.
  (c) The connect script's node-side signed probe requires `$HOME/node-bus-worker.py` and produces no
  row without it [scripts/bunker-crier-connect.sh:53]. The same conclusion was reached
  independently at [docs/master/25-scripts-node-bus-worker-py.md:16] and on the board at
  [.coding-hermes/board/tasks.jsonl:250].
- **Which of the node's own probes would look for the file, and what it finds.** Exactly one:
  `bunker-crier-connect.sh`'s signed read, guarded by `-f "$HOME/node-bus-worker.py"`
  [scripts/bunker-crier-connect.sh:53]. The other candidates are worth ruling out explicitly,
  because none of them looks: the provisioning ladder's bus layer checks `$HOME/.node/crier.json`
  and its mode, never the worker [scripts/project-node.sh:467-471]; `verify-node.sh` checks
  liveness, the gateway, the auth gate, checkout freshness and seed drift, not the bus worker
  [scripts/verify-node.sh:40-45] [scripts/verify-node.sh:109-188]; and this script probes nothing on
  the node at all. The file is therefore expected only on a path the create never walks, and its
  absence is invisible to the create's own green.
- **Defects found while measuring** (out of scope for this task; nothing was fixed):

| # | Defect | Evidence |
|---|---|---|
| 1 | **CF-276 stands: the node's bus worker is never staged, and the validator cannot notice.** A freshly created node cannot produce the signed bus read that fact: FACT-04 measures, because the row `bunker-crier-connect.sh` uses to set `SIGNED_READ=1` comes from a file no create puts on the node | [scripts/node-create.sh:23] [scripts/bunker-crier-connect.sh:53] [.coding-hermes/board/tasks.jsonl:250]. Already filed as CF-276 |
| 2 | **`--harness codex` cannot be provisioned at all.** The adapter sources `$HERE/harness-vars.sh` if it exists [scripts/harness/install-codex.sh:47]; the file does not exist in `scripts/harness/`, and the validator treats any `$HERE` reference as a staged-file requirement [scripts/node-create.sh:41-44]. The runtime is content with the file being absent and the validator refuses the whole run — a gate stricter than the code it guards | measured: `  FAIL  staged_set — harness/install-codex.sh references unstaged harness/harness-vars.sh`, exit 1. **Not yet filed** |
| 3 | **The `bunker client missing` guard was dead; it is now a named row (CF-281).** `have()` used to end in `|| true` [scripts/lib.sh:41-45], so `b=$(have bunker)` always succeeded and the refusal at [scripts/node-create.sh:163] never fired. Measured before the fix, with the client off `PATH`: the run proceeded and reported the absence as `  FAIL  spawn — ./node-create.sh: line 171: : command not found` — the operator was told a spawn failed when no client existed. Fixed: the same run now prints one `  FAIL  bunker_cli — no bunker client on PATH — …` row and `NODE INCOMPLETE (1)`, exit 1, with no spawn attempted | measured both ways; **CF-281** |
| 4 | **The `cp` destination is relative; the client documents an absolute one.** The staged copy uses `<agent>:node-scripts/<file>` [scripts/node-create.sh:111], while `bunker cp --help` states the destination form is `<agent-id>:/path` and gives only absolute examples. Whether the client resolves the relative form against the agent's home was **not measured** — no host was touched | [scripts/node-create.sh:111]. **Not measured; not filed** |
