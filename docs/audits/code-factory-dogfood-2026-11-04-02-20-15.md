# code-factory dogfood walk — tick code-factory-duckbrain-dogfood-2026-11-04-02-20-15

Path walked: `README.md` "Quick start" (lines 15–34) and "Running it against your own infrastructure",
then the node-creation leg on a reachable node host. Lane: `code-factory-duckbrain-dogfood`.

Tip: `origin/main d02916e` (checked out at the registered workdir, attached on `main`, parity
`0 0` against `origin/main` at walk start; no rebase/merge markers).

Provenance: every block below is literal stdout/stderr captured this tick. Nothing is reconstructed
from memory. Redaction is stated at the end of the file: this repository is public, so control-host
names, node-host names, LAN addresses and absolute operator paths are replaced with
`<angle-bracket>` placeholders; no other edit was made.

Barrier state at walk start (recorded, not acted on): `.coding-hermes/board/.lock` is a 0-byte file
dated 2026-11-03 07:40 — no holder (`fuser` empty), no consumer (`grep -rn 'flock\|fcntl'
scripts/boardctl*` and `grep -rln 'board/.lock' scripts/ tests/` return nothing). Per CF-119 and the
project skill it is residue, not an ownership barrier. Untracked `.gitreins/history/2026-11-03/*`
bundles are present; no `gitreins judge` and no `hermes chat` process was alive, so nothing was a
live writer. No sibling lane was `running` (single-project GETs; all code-factory lanes read
`last_tick_status=failed` from earlier slots).

---

## 1. README Quick start, fresh host: all three documented commands

Runner: `env -i PATH=/usr/local/bin:/usr/bin:/bin HOME=<fresh empty dir>` — `CRIER_URL` and
`BUNKER_SERVER` unset, exactly the host the README's own paragraph describes.

```
$ scripts/bunker-server-install.sh --check
scripts/bunker-server-install.sh: line 14: BUNKER_SERVER: set BUNKER_SERVER to your bunker server name
rc=1
```

```
$ ./scripts/project-node.sh --check --project myproject
  PASS  disk_floor — 5 GiB from role-default
node provisioning — project=myproject harness=hermes host=<control-host>
[00] preflight
  PASS  arch — x86_64 (Linux 7.0.0-38-generic)
  PASS  role — worker (floor 5 GiB from role-default)
  PASS  disk — 416.4 GB free (floor 5 GB)
  PASS  mem — 46727 MB
  FAIL  crier_url — CRIER_URL unset — the node has nothing to connect to (export CRIER_URL=http://crier.example:8767)
[10] base
  PASS  tool:python3 — /usr/bin/python3
  PASS  tool:git — /usr/bin/git
  PASS  tool:curl — /usr/bin/curl
  PASS  tool:tar — /usr/bin/tar
  PASS  tool:sha256sum — /usr/bin/sha256sum
  PASS  python:venv — importable
  PASS  tool:jq — /usr/bin/jq
  PASS  tool:rg — /usr/bin/rg
  PASS  tool:node — /usr/bin/node
[20] harness
harness: hermes (pin 0.19.0, port 10800)
  FAIL  python — hermes-agent 0.19.0 requires python >=3.11,<3.14; found 3.14.4
[30] bus
  FAIL  crier_identity — absent — stage a bundle and re-run; a node without an identity is invisible
[40] repo
  FAIL  repo — <fresh-home>/repo absent (pass --repo to clone)
[90] manifest
  ..    manifest is written only when every layer passes

NODE: FAIL (4)
rc=1
```

```
$ scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes
scripts/node-create.sh: line 70: SERVER: set BUNKER_SERVER to your bunker server name
rc=1
```

`--help` on the same two commands:

```
$ scripts/bunker-server-install.sh --help
scripts/bunker-server-install.sh: line 14: BUNKER_SERVER: set BUNKER_SERVER to your bunker server name
rc=1
$ scripts/node-create.sh --help
unknown arg: --help
rc=2
```

### What this contradicts

`README.md:32-34` states: *"On a host with no bunker server, no Crier and no repo, all three
commands reach their checkers and fail with the missing value named."*

Step 2 does exactly that. Steps 1 and 3 do not reach a checker at all: they abort inside bash
parameter expansion (`${BUNKER_SERVER:?…}` at `bunker-server-install.sh:14`, `${SERVER:?…}` at
`node-create.sh:70`) and the message carries the script's own line number. A stranger reading a
`line 14:` bash error cannot tell the factory is healthy-but-unconfigured from the factory being
broken; that is the exact confusion `AGENTS.md` rule 3 and the repo's PASS/FAIL convention exist to
prevent. The paragraph has no command attached, so nothing in `tests/selftest.sh` can contradict it —
this is the same "claim with no probe" class as CF-081.

History: the sentence was authored in `161dc14` (2026-10-30, "every command was re-run from a fresh
archive of the published tip and each failure now names a real value", closing CF-009 among others).
CF-009 and CF-041 are both `complete` and their acceptance criteria were met on their own terms
(CF-009 AC2 wanted the export documented before the command, which `README.md:17-20` now does;
CF-041 AC2 wanted step 2 to use a flag `project-node.sh` accepts, which it now does). Neither row
owns this sentence, and neither row's criteria are re-opened here. Filed as **CF-145**.

Id note: this row was drafted as CF-144 and the append helper renumbered it (`delta=1`) because a
sibling lane consumed CF-144 at `51efb66` ("the closure-evidence rule conflates three tree_fp
instruments") while this walk was in progress. The event written by the helper names CF-145; the
draft id is recorded here so the renumber is explainable.

Reproduction (the row's `probe`, run from the repo root; last line is the wrapper's status, the two
`rcN=` lines are the measurement):

```
unset CRIER_URL BUNKER_SERVER; scripts/bunker-server-install.sh --check 2>&1; echo "rc1=$?"; scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes 2>&1; echo "rc2=$?"
scripts/bunker-server-install.sh: line 14: BUNKER_SERVER: set BUNKER_SERVER to your bunker server name
rc1=1
scripts/node-create.sh: line 70: SERVER: set BUNKER_SERVER to your bunker server name
rc2=1
```

---

## 2. Node-creation leg on a reachable node host (README Quick start step 3, env supplied)

A node host answered (`bunker list --server <node-host>`: one pre-existing agent, free disk
47.4 GB). `CRIER_URL` exported on the control host exactly as `README.md:19` shows.

```
$ CRIER_URL=http://crier.example:8767 BUNKER_SERVER=<node-host> scripts/node-create.sh --project dogfood-public-20261104 --repo https://github.com/github/gitignore --harness hermes --ttl 1h
node-create — project=dogfood-public-20261104 harness=hermes server=<node-host>
  ..    spawning node-dogfood-public-20261104-212331 (ttl 1h)
  PASS  spawn — node-dogfood-public-20261104-212331
  ..    staging scripts
Copied ... project-node.sh, lib.sh, disk_floor.py, reclaim_disk.py, harness/install-hermes.sh
  PASS  staged — project-node.sh + lib.sh + disk_floor.py + reclaim_disk.py + harness/install-hermes.sh
  ..    provisioning inside the node
  PASS  disk_floor — 5 GiB from role-default
node provisioning — project=dogfood-public-20261104 harness=hermes host=<node-host>
[00] preflight
  PASS  arch — x86_64 (Linux 6.12.111+deb13-amd64)
  PASS  role — worker (floor 5 GiB from role-default)
  PASS  disk — 47.4 GB free (floor 5 GB)
  PASS  mem — 29663 MB
  FAIL  crier_url — CRIER_URL unset — the node has nothing to connect to (export CRIER_URL=http://crier.example:8767)
[10] base
  PASS  tool:python3 — /usr/bin/python3
  PASS  tool:git — /usr/bin/git
  PASS  tool:curl — /usr/bin/curl
  PASS  tool:tar — /usr/bin/tar
  PASS  tool:sha256sum — /usr/bin/sha256sum
  PASS  python:venv — importable
  PASS  tool:jq — /usr/bin/jq
  WARN  tool:rg — missing (some repos' tests need node)
  PASS  tool:node — /usr/bin/node
[20] harness
harness: hermes (pin 0.19.0, port 10800)
  PASS  python — 3.13.5 (hermes-agent 0.19.0 requires >=3.11,<3.14)
  FAIL  binary — absent — run --apply
  FAIL  port — nothing on :10800
  FAIL  inference_key — no provider key — a turn dies at 'No inference provider configured'
apply
/home/<node-agent>/node-scripts/harness/install-hermes.sh: line 86: /tmp/hermes-install.log: Permission denied
  FAIL  install — pip failed — /tmp/hermes-install.log
[30] bus
  FAIL  crier_identity — absent — stage a bundle and re-run; a node without an identity is invisible
[40] repo
  ..    cloning https://github.com/github/gitignore @ main
  PASS  repo_clone — /home/<node-agent>/repo @ df40870
[90] manifest
  ..    manifest is written only when every layer passes

NODE: FAIL (6)
  FAIL  provision — node reported FAIL — see the output above
  ..    verifying from the control host
verify node node-dogfood-public-20261104-212331
  PASS  agent_alive — ALIVE <node-host>
  PASS  node_ip — <node-lan-ip>
  FAIL  gateway_reachable — http://<node-lan-ip>:10800/api/status -> 000000 (is the harness running on 0.0.0.0:10800?)
  FAIL  unauth_refused — /api/system/stats -> 000000 — auth refusal not verified

VERIFY: FAIL (2)
  FAIL  verify — round trip failed — node remains unverified
NODE INCOMPLETE (2)
cleanup required: bunker destroy node-dogfood-public-20261104-212331 --server <node-host>
rc=1 elapsed_s=50
```

### 2a. `--ttl` is honoured

`bunker info node-dogfood-public-20261104-212331 --server <node-host>` immediately after the run:

```
  Created At:       2026-11-03T18:23:46-08:00
  Expires At:       2026-11-03T19:23:46-08:00
```

Exactly one hour. The documented `--ttl 1h` does what it says (previous walks never measured this).

### 2b. Layers that changed since the 2026-11-03 dogfood walk

The walk at `01eb0cf` recorded the same shape; today's run adds the staging fix from `77caa02`:

- `PASS  staged — … + reclaim_disk.py` — the staged manifest now carries the resolver
  `reclaim_disk.py` that `27df6ac` (CF-007 AC3) added, i.e. the entry point's new `$HERE/`
  reference is covered by the validator for the spelling it reads.
- `[40] repo` still clones AFTER `[30] bus` failed — repo-with-no-bus, the shape `AGENTS.md`
  rule 9 forbids. That is CF-080, still `pending`, reproduced at this tip.

### 2c. Cleanup

```
$ bunker destroy node-dogfood-public-20261104-212331 --server <node-host>
Destroying agent node-dogfood-public-20261104-212331 (home 256.9 MB; archiving before delete, deadline 12m0s)…
Agent node-dogfood-public-20261104-212331 destroyed.
Removed local SSH key /home/<operator>/.config/bunker/keys/node-dogfood-public-20261104-212331
rc=0
```

`bunker list --server <node-host>` afterwards: 1 agent (the pre-existing one). The dogfood node is
gone; nothing was leaked.

---

## 3. `--staged-files`: the matcher's spelling and scope (CF-087 re-measured at this tip)

No host, no network: `scripts/` copied into scratch, one reference appended per arm, the copy only.
Command in every arm: `bash node-create.sh --staged-files` (this is what `node-create.sh:69` calls
before it stages anything).

```
== arm 0: baseline, unmutated copy ==
project-node.sh
lib.sh
disk_floor.py
reclaim_disk.py
harness/install-hermes.sh
rc=0

== arm 1 (control): literal $HERE/ spelling added to the entry point ==
  FAIL  staged_set — project-node.sh references unstaged nonexistent-control.sh
rc=1

== arm 2: brace spelling ${HERE}/ added to the entry point ==
project-node.sh
lib.sh
disk_floor.py
reclaim_disk.py
harness/install-hermes.sh
rc=0

== arm 3: literal $HERE/ reference added to the shipped lib.sh ==
<fixture>/lib.sh: line 57: <fixture>/nonexistent-from-lib.sh: No such file or directory
project-node.sh
lib.sh
disk_floor.py
reclaim_disk.py
harness/install-hermes.sh
rc=0
```

Arm 1 proves the matcher works for the spelling it reads. Arm 2 (`${HERE}/`) and arm 3 (a
reference in the shipped `lib.sh`, which `project-node.sh:28` sources) both print a green manifest
and exit 0 although the node would die on its first line — arm 3 does so while printing the shell's
own "No such file or directory" on the same run. This is CF-087, still `pending`, reproduced at
`d02916e`; the literal staged array at `node-create.sh:20` is unchanged (CF-087 AC1 wants a derived
set).

---

## 4. Liveness of pending rows, re-measured at this tip

A reproduction of a defect a pending row already owns is liveness confirmation, not a new row.

| Row | Claim re-measured | Result at `d02916e` |
|---|---|---|
| CF-126 (P2) | `node-create` never forwards `CRIER_URL` into the node | Live: exported on the control host, `FAIL crier_url — CRIER_URL unset` inside the node (§2), `node-create.sh:103` still forwards only `NODE_PROJECT`/`NODE_GATEWAY_PORT` |
| CF-127 (P3) | `install-hermes.sh` pip log at a fixed `/tmp/hermes-install.log` | Live: `line 86: /tmp/hermes-install.log: Permission denied`, reported as `pip failed` (§2) |
| CF-080 (P4) | `--apply` clones the workspace after the bus layer failed | Live: `[30] bus` FAIL then `[40] repo` `PASS repo_clone` (§2) |
| CF-087 (P3) | staged-set validator reads one spelling in two of its files | Live: arms 2 and 3 above |
| CF-072 (P4) | the `-> 000000` deformation survives in verify-node.sh | Live: `gateway_reachable — … -> 000000` (§2) |
| CF-119 (P3) | `.coding-hermes/board/.lock` is a phantom barrier | Live: 0-byte, no holder, no consumer (§ barrier state) |

Not filed, recorded only: `WARN  tool:rg — missing (some repos' tests need node)` names `node` as
the hint for a missing `rg` (one-line hint text in `project-node.sh`; cosmetic, second tick it has
been observed).

---

## 5. Gates at this tip, and the board write

```
$ bash tests/selftest.sh
…
SELFTEST: PASS
real 0m9.033s
```

`gh run list --repo coding-hermes/code-factory` returns `[]` — the documented no-workflow state for
this repo, not a finding (`docs/BOARD.md`); the CI-equivalent gate is the selftest above.

The walk itself happened at `d02916e`. Between the walk and the filing, sibling lanes landed
`47a0490`, `51efb66`, `e1b924c` and `db96735` in the same checkout; the row was appended at
`db96735` (parity `0 0` before the write), and the append helper printed:

```
delta=1 width=3 assigning ['CF-145']
rows 118 -> 119 (+1)
prefix_bytes_identical=True unique_ids=119 duplicates=0
readback CF-145 status=pending probe_len=206 ac_len=941
events=174 last=task_created task=CF-145
```

`prefix_bytes_identical=True` is the insert-only proof: every pre-existing line is byte-identical
after the append.

## 6. What a new user would have done next

A stranger following the README gets one working diagnostic (step 2, nine PASS rows and four named
FAIL rows) and two bash aborts (steps 1 and 3). The natural next move — re-export the variables and
re-run — does not help step 3 at all: `node-create.sh` still never forwards `CRIER_URL` into the
node (CF-126), and the node's own harness install dies on a `/tmp` file another agent owns
(CF-127). So on a fresh host the documented path ends with a node that exists, has a cloned repo,
and cannot talk to the bus — exactly the shape `AGENTS.md` rule 9 forbids, which is CF-080.
CF-145 is the cheapest of that set to fix and the one that stops the first five minutes from
looking like a broken product.

---

## Redaction

Replaced with placeholders, nothing else altered: the control-host name, the node-host / bunkerd
server alias, the node's LAN IPv4 address, the node agent's home path, the operator's absolute HOME
paths and the scratch directory of this walk. No credential, token or endpoint is present in any
block above.
