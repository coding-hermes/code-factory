# 04. scripts/bunker-crier-connect.sh

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/bunker-crier-connect.sh` [scripts/bunker-crier-connect.sh:1] |
| Repository | `code-factory` [scripts/bunker-crier-connect.sh:1] |
| Revision | `7f9ca12` — last commit touching this file; the tree measured here is `9ecb70c` |
| Status | **VERIFIED — the verdict ladder and the environment reads reproduced against a stub bus on 2026-11-05; 4 defects measured against the file's own claims; 265 resolving locators (100 distinct); fact: FACT-03 fact: FACT-04** |

## 1. Purpose and why it matters

- What it is: a control-host script that puts **one** bunker agent on the crier bus and then
  proves it — `--check` measures only, `--apply` writes the identity file then probes, `--stage`
  writes the identity file and defers the probe [scripts/bunker-crier-connect.sh:2-7].
  It is deliberately not part of provisioning: "connecting is its own failure surface (identity
  not accepted, route missing, guard refusing) and it must be re-runnable without touching the
  clone, the harness or the credentials" [scripts/bunker-crier-connect.sh:9-11].
- The three measurements `--check` makes are the bus `/health` code
  [scripts/bunker-crier-connect.sh:40-44], the agent's inbox route
  [scripts/bunker-crier-connect.sh:52-74], and the node's own identity file against the host
  just probed [scripts/bunker-crier-connect.sh:80-88].
- What breaks if it is ABSENT: the other route probes in this repository are the node-side
  worker, which requires the key and bearer to already be on the node and is invoked per node
  [scripts/node-bus-worker.py:41-44], and the provisioning path, which probes the route once,
  during `--apply`, as a side effect of provisioning
  [scripts/bunker-provision.sh:238] [scripts/bunker-provision.sh:272]. The node ladder's bus
  layer only asserts that `$HOME/.node/crier.json` exists at mode 600 — it starts no worker and
  opens no socket [specs/NODE.md:62-63] [scripts/project-node.sh:244-249]. So without this
  script the control host cannot distinguish "a file exists on the node" from "this agent's
  inbox answers", and cannot re-check that after the fact.
- What breaks if it LIES, measured rather than supposed — four contradictions between the file
  and itself:
  1. It says "Idempotent: rewrites the identity file only when a value differs"
     [scripts/bunker-crier-connect.sh:17], but `apply()` unconditionally copies the file — there
     is no comparison anywhere in the function
     [scripts/bunker-crier-connect.sh:129-132]. Two consecutive `--apply` runs against a stub
     node produced **two** `bunker cp` calls (probe B, §8), and the second write restamped
     `connected_at` [scripts/bunker-crier-connect.sh:129-130]. A reader who trusts line 17 will
     treat the file's mtime and `connected_at` as connection events; they are invocation events.
  2. The in-repo operator documentation still says it "prints `CRIER: CONNECTED` only on `200`"
     [docs/OPERATIONS.md:48], and the acceptance plan repeats "reports CONNECTED only on a 200
     inbox" [docs/ACCEPTANCE-PLAN.md:146]. The code is stricter: an unsigned 200 now yields
     `CRIER: UNVERIFIED` and exit 3 [scripts/bunker-crier-connect.sh:96-102]. The documentation
     understates the gate; a reader who trusts it would accept an unauth bus as a working key.
  3. The health row labels *every* non-200 "(bus not answering)"
     [scripts/bunker-crier-connect.sh:43], so a bus that answers `404` on `/health` is described as
     unreachable. Measured by pointing the stub's `/health` at 404 (§8 probe A2), the row reads
     `FAIL  bus_health — … -> 404 (bus not answering)`. The inbox-404 case of probe A does **not**
     exercise this: its stub answers `/health` 200, so that transcript's health row is
     `PASS  bus_health — … -> 200` (§8, case 5).
  4. A missing `bunker` client is named by `--check`, and the verdict line survives (CF-281). The
     identity step used to be
     `b=$(have bunker) || { bad "identity" "no bunker client on PATH"; return 1; }`, but `have()`
     then ended in `|| true` [scripts/lib.sh:41-45] and exited 0 with empty output: the `||` arm was
     dead, and an absent client was measured (§8 probe C, `PATH=/usr/bin:/bin`) as
     `FAIL  identity — $HOME/.node/crier.json absent — run --apply` — an absent *client* reported as
     an absent *file*, with the one mode that needs the client as its remedy. `have()` now reports
     absence by status, and the step is an `if`/`else` [scripts/bunker-crier-connect.sh:86-98]: one
     `FAIL  identity — no bunker client on PATH — $HOME/.node/crier.json cannot be read from the
     node` row, and the run still reaches its `CRIER:` verdict instead of returning past it.
- What breaks if the *verdict* lies (the failure this file exists to prevent): `CONNECTED` is a
  claim about a signature, so it is printed only when the node's own signed probe returned a
  `PASS  inbox` row [scripts/bunker-crier-connect.sh:57] [scripts/bunker-crier-connect.sh:96-97];
  an unsigned 200 and the normal unsigned 401 both fall to `UNVERIFIED` with exit 3
  [scripts/bunker-crier-connect.sh:91-102]. That is the requirement stated over a measurement,
  and it matches the bus's own order of checks [scripts/node-bus-worker.py:556-557]
  (fact: FACT-03).

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `bash` | unpinned — no version check in the source [scripts/bunker-crier-connect.sh:19] | shebang `#!/usr/bin/env bash` [scripts/bunker-crier-connect.sh:1]; `lib.sh` itself "Requires bash" [scripts/lib.sh:3] | nothing in this script; a non-bash `sh` fails on `local`/`pipefail` without a named row [scripts/bunker-crier-connect.sh:19-23] |
| `curl` | unpinned [scripts/bunker-crier-connect.sh:29] | `PATH` | **not detected as itself**: `curl … 2>/dev/null \|\| true` reduces any failure to an empty string, which `probe()` renders as `000` [scripts/bunker-crier-connect.sh:29-31] and the health row reports as "(bus not answering)" [scripts/bunker-crier-connect.sh:43] |
| `bunker` client | unpinned [scripts/bunker-crier-connect.sh:79] | `PATH`, and executable for the signed probe path [scripts/bunker-crier-connect.sh:51] | **named since CF-281**: `have()` exits non-zero on absence [scripts/lib.sh:41-45], so the identity step's `if b=$(have bunker)` takes its `else` and prints one `FAIL  identity — no bunker client on PATH — $HOME/.node/crier.json cannot be read from the node` row [scripts/bunker-crier-connect.sh:86-98] and the run still prints its `CRIER:` verdict. Before the fix the status was constant 0, the arm was dead, and the absence surfaced as `FAIL  identity — $HOME/.node/crier.json absent — run --apply` (measured, §8 probe C); `stage`/`apply` name it too, exit 1 [scripts/bunker-crier-connect.sh:120] [scripts/bunker-crier-connect.sh:137] |
| GNU `timeout` | unpinned [scripts/bunker-crier-connect.sh:52] | `PATH` | **not detected**: a missing `timeout` makes the whole `bunker exec` line fail, `\|\| true` swallows it, `via_node` stays empty, and the script silently falls back to the unsigned probe [scripts/bunker-crier-connect.sh:52-55] [scripts/bunker-crier-connect.sh:66] |
| `python3` on the node | unpinned [scripts/bunker-crier-connect.sh:53] | inside the node's `$HOME`, with `$HOME/node-bus-worker.py` present [scripts/bunker-crier-connect.sh:53] | the node-side `if` guard tests the worker file, not `python3`; a missing interpreter yields an empty row → same silent fallback [scripts/bunker-crier-connect.sh:53-55] |
| `mktemp`, `chmod`, `date`, `sed` | coreutils/busybox, unpinned [scripts/bunker-crier-connect.sh:25] [scripts/bunker-crier-connect.sh:111] [scripts/bunker-crier-connect.sh:113] | `PATH` | unchecked; if `mktemp` fails, `"$tmp"` is empty and the following `printf … > "$tmp"` targets an empty path and fails [scripts/bunker-crier-connect.sh:111-113] |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `. "$HERE/lib.sh"` | `scripts/lib.sh`, sourced with the script's own directory as `HERE` [scripts/bunker-crier-connect.sh:20-21] | defines `say`, `ok`, `bad`, `warn`, `have` [scripts/lib.sh:5-9] [scripts/lib.sh:41-45] | every row vanishes or errors; the script has no local fallback definitions [scripts/bunker-crier-connect.sh:21] |
| `bad()` increments `FAILED` | `scripts/lib.sh:7` | each failure both prints `  FAIL …` and bumps the counter the verdict reads [scripts/bunker-crier-connect.sh:61] [scripts/bunker-crier-connect.sh:94] | if `bad` stopped counting, FAIL rows would print and the verdict would fall through to `SIGNED_READ`, i.e. a visibly failed run could still print `CONNECTED` |
| `FAILED=${FAILED:-0}` | `scripts/lib.sh:11` | the variable exists before the first arithmetic test [scripts/bunker-crier-connect.sh:61] | with `set -u` in force [scripts/bunker-crier-connect.sh:19], an undefined `FAILED` aborts the run at the first `[ "$FAILED" … ]` instead of printing a verdict |
| `ok`/`warn` never touch `FAILED` | `scripts/lib.sh:6` [scripts/lib.sh:8] | the 401 row can be a WARN that does not condemn the run [scripts/bunker-crier-connect.sh:70] | a `warn` that counted would turn the hardened-bus answer into `NOT CONNECTED` and lose the distinction the file is built on |
| `have()` shape | `scripts/lib.sh:41-45` | **present: exit 0 and the resolved path on stdout; absent: non-zero and nothing on stdout** — absence is reported by STATUS as well as by empty output, since CF-281; it is used both as a command substitution [scripts/bunker-crier-connect.sh:86] [scripts/bunker-crier-connect.sh:119] and as a status test [scripts/bunker-crier-connect.sh:86] | a `have` that printed a message on absence would be executed as a command path in `"$b" cp` [scripts/bunker-crier-connect.sh:124]; the status half is what makes the `no bunker client on PATH` row reachable, which is the branch the pre-fix version could never take |
| `bunker exec --server S AGENT -- bash -lc '<text>'` argv shape | established by `bunker_exec` [scripts/lib.sh:62-65]; this script builds the same shape inline rather than calling it [scripts/bunker-crier-connect.sh:52-53] [scripts/bunker-crier-connect.sh:80] | the client splits `--server`, agent, `--`, command | both call sites break together; this script would not inherit a fix made inside `bunker_exec` |

### 2c. Service contracts (both sides must be named)

The bus and the node are separate processes from this script. The crier sources live in a
different repository (`docs/REPOSITORIES.md:19`) and their `file:line` cannot resolve against
this tree, so the peer-side citations below are function names plus the ledger fact that
measured them (fact: FACT-03, fact: FACT-04); every in-repo side carries a resolvable locator.

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| crier bus, `GET <url>/health` [scripts/bunker-crier-connect.sh:40] | script → bus | HTTP GET, `-m $TIMEOUT`, body discarded (`-o /dev/null -w '%{http_code}'`) [scripts/bunker-crier-connect.sh:40] | none; only the status code is read [scripts/bunker-crier-connect.sh:41-44] | crier `cmd/server/main.go` → the `/health` handler registered beside the Mux; it is GET-only, so a HEAD there answers 405 and is not a fault [scripts/project-node.sh:245]. In-repo mirror of the same probe: `scripts/node-bus-worker.py:540-547` |
| crier bus, `GET <url>/agents/<agent>/inbox?limit=1` [scripts/bunker-crier-connect.sh:29] | script → bus, **unsigned** (no bearer, no `X-Agent-*`) [scripts/bunker-crier-connect.sh:29] | HTTP GET over the bus URL [scripts/bunker-crier-connect.sh:29] | no body; the code is printed and matched [scripts/bunker-crier-connect.sh:67-74] | crier `cmd/server/main.go` → `registerRegistryRoutes` registers `/agents/{id}/inbox` GET to `HandleRetrieve`; `internal/registry/handler.go` → `HandleRetrieve` calls `requireAgent` before it parses the query or claims anything, and `internal/registry/agentsig.go` → `authorizeAgent` verifies the ed25519 signature. The 401-before-lookup order is fact: FACT-03, mirrored in-repo with the same ladder wording at `scripts/node-bus-worker.py:555-560`. Because this is the *retrieve* route and not `/inbox/stats`, an authenticated call claims a lease [scripts/node-bus-worker.py:41-44] |
| node bus worker, `python3 $HOME/node-bus-worker.py --check` [scripts/bunker-crier-connect.sh:53] | script → node (via `bunker exec`) → bus | `bunker exec --server <host> <agent> -- bash -lc '<script>'`, 45 s `timeout` [scripts/bunker-crier-connect.sh:52-53] | stdout rows, filtered with `grep -E "PASS  inbox\|FAIL  inbox" \| head -1` [scripts/bunker-crier-connect.sh:53] | `scripts/node-bus-worker.py` → `check()`: prints `node-bus-worker --check — agent=… bus=…` [scripts/node-bus-worker.py:445], signs a GET of `/agents/<id>/inbox/stats` (chosen because it leases nothing) [scripts/node-bus-worker.py:569-577] and prints `  PASS  inbox — GET … -> 200 (…)` [scripts/node-bus-worker.py:584-589]. That `PASS  inbox` row is the *only* input that sets `SIGNED_READ=1` [scripts/bunker-crier-connect.sh:56-57] |
| bunker client → bunker host daemon [scripts/bunker-crier-connect.sh:114] [scripts/bunker-crier-connect.sh:131] | script → node | `bunker cp <local-tmp> <agent>:.node/crier.json --server <host>` then `bunker exec … chmod 600` [scripts/bunker-crier-connect.sh:114-115] | a JSON object with `agent`, `project`, `url` and a timestamp [scripts/bunker-crier-connect.sh:112-113] [scripts/bunker-crier-connect.sh:129-130] | the file is read back through the same client at [scripts/bunker-crier-connect.sh:80] and consumed by the worker's identity precedence `crier.json.agent → node.json.agent → --agent` [scripts/node-bus-worker.py:51-53] [scripts/node-bus-worker.py:339] |
| `$HOME/.node/crier.json` on the node (mode 600) [scripts/bunker-crier-connect.sh:115] | script writes, two readers | file on the node | `{"agent","project","url","staged_at"\|"connected_at"}` [scripts/bunker-crier-connect.sh:112] [scripts/bunker-crier-connect.sh:129] | `scripts/node-bus-worker.py:339` reads it for the agent id and bus URL; the node ladder only checks existence and mode [scripts/project-node.sh:244-249] [specs/NODE.md:62-63] |

## 3. Verification

All rows were run on 2026-11-05 against revision `7f9ca12` in worktree `~/proj-wt-md-04`; the two
environment/health rows added below were re-run in worktree `~/proj-wt-fix04` at `b9f56e6`, which
carries the same script.

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| Parse | `bash -n scripts/bunker-crier-connect.sh` | no output, exit 0 — a syntax error makes bash print a diagnostic and exit non-zero without running anything [scripts/bunker-crier-connect.sh:1-157] | 2026-11-05 | PASS (exit 0) |
| Argument guard | `bash scripts/bunker-crier-connect.sh --check` | `--server is required (the agent's bunker host)` on stdout, exit 2 [scripts/bunker-crier-connect.sh:156] | 2026-11-05 | PASS (exit 2) |
| Mode guard | `bash scripts/bunker-crier-connect.sh --agent x --server s` | usage text (lines 2–20 of the file, so two code lines leak into it [scripts/bunker-crier-connect.sh:25]), exit 2 [scripts/bunker-crier-connect.sh:155] | 2026-11-05 | PASS (exit 2) |
| Verdict ladder, 5 cases | `bash probe-04-crier-connect.sh` (§8) — stub bus + stub `bunker` | unsigned 200 → `CRIER: UNVERIFIED`, exit 3; unsigned 401 → `CRIER: UNVERIFIED`, exit 3; signed `PASS  inbox` → `CRIER: CONNECTED`, exit 0; 403 → `CRIER: NOT CONNECTED (1)`, exit 1; 404 → `CRIER: NOT CONNECTED (1)`, exit 1 [scripts/bunker-crier-connect.sh:94-104] | 2026-11-05 | PASS (5/5 `RESULT: PASS`, probe exit 0) |
| Idempotence claim | `bash probe-04b-apply-rewrite.sh` (§8) — two `--apply` runs | the header claims the identity is rewritten only when a value differs [scripts/bunker-crier-connect.sh:17]; a copy-counting stub client is expected to show 1 write if the claim holds | 2026-11-05 | **FAIL — 2 writes**: the claim at line 17 is false for `apply()` [scripts/bunker-crier-connect.sh:129-132] |
| Health row on a non-200 `/health` | probe A2 (§8) — stub answers 404 on `/health`, 404 on `/agents/*` | `FAIL  bus_health — … -> 404 (bus not answering)`, the defect at [scripts/bunker-crier-connect.sh:43], then `NOT CONNECTED (2)`, exit 1 | 2026-11-05 | PASS (row reproduced) |
| Environment reads | probe C (§8) — `HOME` unset, `bunker` off `PATH`, exported `FAILED=1` | `HOME` unset aborts at line 100 as `HOME: unbound variable`, exit 1; an absent `bunker` is reported as `$HOME/.node/crier.json absent`, exit 1; `FAILED=1` vetoes an all-PASS run as `NOT CONNECTED (1)` [scripts/bunker-crier-connect.sh:100] [scripts/bunker-crier-connect.sh:82] [scripts/lib.sh:11] | 2026-11-05 | PASS (3/3 rows reproduced) |

A check that cannot fail would be decoration; each row above has an outcome the current code
does not produce when it is broken. The 5-case probe flips on the verdict block alone: moving
`SIGNED_READ=1` out of the `PASS  inbox` arm [scripts/bunker-crier-connect.sh:56-59] makes case
3 print `UNVERIFIED` instead of `CONNECTED`.

## 4. Metrics emitted

- **None.** The script opens no counter, histogram, exporter or timing instrument; it prints rows
  and exits [scripts/bunker-crier-connect.sh:94-104] [scripts/bunker-crier-connect.sh:155-157].
  There is no dispatch-rate, attempt-count or latency series to scrape, and nothing persists a
  run's outcome except the identity file's own timestamp
  [scripts/bunker-crier-connect.sh:113] [scripts/bunker-crier-connect.sh:130].
- What exists instead is a process-level verdict on the exit code: `0` connected
  [scripts/bunker-crier-connect.sh:97], `1` not connected — returned both by the
  `via_node` branch [scripts/bunker-crier-connect.sh:61-65] and by the final `[ "$FAILED" -eq 0 ]`
  [scripts/bunker-crier-connect.sh:104], `2` usage/argument refusal
  [scripts/bunker-crier-connect.sh:25] [scripts/bunker-crier-connect.sh:155-156], `3` unverified
  [scripts/bunker-crier-connect.sh:102]. The `FAIL` count is also printed once as
  `CRIER: NOT CONNECTED ($FAILED)` [scripts/bunker-crier-connect.sh:63]
  [scripts/bunker-crier-connect.sh:95] — the only aggregate the script ever reports, and it dies
  with the process.

## 5. Log lines it can generate

Rendering is owned by `lib.sh`: `  PASS  %s — %s`, `  FAIL  %s — %s`, `  WARN  %s — %s`, each with
two leading spaces, and `say` prints bare text [scripts/lib.sh:5-9]. Values below are shown as the
source interpolates them.

Observed verbatim in the 2026-11-05 probe run (`--agent a1 --server s1 --url http://127.0.0.1:18767`):

- `crier-connect --check — agent=a1 url=http://127.0.0.1:18767` — descriptive (the header; it is
  printed before any measurement) [scripts/bunker-crier-connect.sh:35].
- `  PASS  bus_health — http://127.0.0.1:18767/health -> 200` — evidentiary
  [scripts/bunker-crier-connect.sh:42].
- `  PASS  inbox — http://127.0.0.1:18767/agents/a1/inbox -> 200` — descriptive: it names a 200
  that proves nothing about the key [scripts/bunker-crier-connect.sh:69].
- `  WARN  inbox — http://127.0.0.1:18767/agents/a1/inbox -> 401 — expected for an unsigned read (crier checks the signer before it looks the agent up); the signed probe needs agent.key + crier.token on the node` — descriptive (the normal hardened-bus answer) [scripts/bunker-crier-connect.sh:70].
- `  FAIL  inbox — http://127.0.0.1:18767/agents/a1/inbox -> 403 (owner mismatch or guard refused)` — evidentiary [scripts/bunker-crier-connect.sh:71].
- `  FAIL  inbox — http://127.0.0.1:18767/agents/a1/inbox -> 404 (agent is genuinely not registered on the bus)` — evidentiary [scripts/bunker-crier-connect.sh:72].
- `  PASS  identity — node points at http://127.0.0.1:18767 as a1` — evidentiary
  [scripts/bunker-crier-connect.sh:84].
- `CRIER: CONNECTED — a1 at http://127.0.0.1:18767 (signed read accepted)` — evidentiary; the only
  success line [scripts/bunker-crier-connect.sh:97].
- `CRIER: UNVERIFIED — a1 at http://127.0.0.1:18767: the bus answered an UNSIGNED read, so this node's key and` — evidentiary, followed by the two indented remedy lines
  `        bearer were not exercised. Install /home/kara/.node/agent.key and ~/.node/auth/crier.token`
  and `        and stage the bus worker, then re-run --check.`
  [scripts/bunker-crier-connect.sh:99-101].
- `CRIER: NOT CONNECTED (1)` / `CRIER: NOT CONNECTED (2)` — evidentiary; the number is `$FAILED`
  [scripts/bunker-crier-connect.sh:63] [scripts/bunker-crier-connect.sh:95].

Literal format strings present in the source but not exercised by the probe (the interpolated
values are the script's own variables, never invented here):

- `  PASS  inbox — signed read accepted on the node: $via_node` — evidentiary, the one row that
  sets `SIGNED_READ=1` [scripts/bunker-crier-connect.sh:57].
- `  FAIL  inbox — the node's own signed probe failed: $via_node` — evidentiary
  [scripts/bunker-crier-connect.sh:58].
- `  FAIL  bus_health — $URL/health -> ${health:-000} (bus not answering)` — descriptive, and
  wrong for any non-200 that is an answer [scripts/bunker-crier-connect.sh:43].
- `  FAIL  inbox — $URL/agents/$AGENT/inbox -> $code` — the `*)` arm, and the row an operator sees
  for `000` because `probe()` substitutes `000` for an empty code
  [scripts/bunker-crier-connect.sh:30] [scripts/bunker-crier-connect.sh:73].
- `  FAIL  identity — $HOME/.node/crier.json absent — run --apply` — descriptive; `$HOME` is
  escaped, so the operator sees the literal text [scripts/bunker-crier-connect.sh:82].
- `  FAIL  identity — node points elsewhere: $json` and
  `  FAIL  identity — node identity names a different agent: $json` — evidentiary, they carry the
  file's contents [scripts/bunker-crier-connect.sh:85] [scripts/bunker-crier-connect.sh:87].
- `  FAIL  identity — no bunker client on PATH — $HOME/.node/crier.json cannot be read from the
  node` — descriptive, and reachable since CF-281: `have()` reports absence by status
  [scripts/lib.sh:41-45], so the identity step's `if` test takes its `else`
  [scripts/bunker-crier-connect.sh:86-98]. Before the fix the status was constant 0, the arm was
  dead, and an absent client was reported as the `absent` row above (measured, §8 probe C).
- `  PASS  identity — staged $HOME/.node/crier.json (agent=$AGENT url=$URL)` and
  `  PASS  identity — wrote $HOME/.node/crier.json (agent=$AGENT)` — evidentiary for the two write
  modes [scripts/bunker-crier-connect.sh:116] [scripts/bunker-crier-connect.sh:133].
- `  FAIL  identity — could not stage $HOME/.node/crier.json` and
  `  FAIL  identity — could not write $HOME/.node/crier.json` — evidentiary [scripts/bunker-crier-connect.sh:118] [scripts/bunker-crier-connect.sh:135].
- `crier-connect --apply — agent=$AGENT url=$URL` — descriptive [scripts/bunker-crier-connect.sh:125].
- `unknown argument: $1` — descriptive [scripts/bunker-crier-connect.sh:151].
- `--server is required (the agent's bunker host)` — descriptive [scripts/bunker-crier-connect.sh:156].

There is no logger, level, destination or retention policy: every line goes to stdout/stderr of
the invoking shell and nothing is retained [scripts/bunker-crier-connect.sh:94-104].

## 6. Failure modes

Direction is stated per row: **fail closed** = the run refuses the claim, **degraded** = the run
continues on a weaker path, **open** = the run lets a weaker fact stand.

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Bus does not answer `/health` | `  FAIL  bus_health — … -> 000 (bus not answering)` then `CRIER: NOT CONNECTED (1)`, exit 1 — **fail closed** [scripts/bunker-crier-connect.sh:43] [scripts/bunker-crier-connect.sh:95] | `401` on the inbox route is a live bus refusing an unsigned read, not an unreachable one [scripts/bunker-crier-connect.sh:70] | start the bus or fix `--url`; the health row names the URL [scripts/bunker-crier-connect.sh:42-43] |
| Bus answers non-200 on `/health` for a reason other than reachability | Same row, with the code printed but the parenthetical still saying "bus not answering" — **degraded diagnosis, fail closed verdict** [scripts/bunker-crier-connect.sh:43] | nothing in the output separates a 404 from a dead host; only the printed number does | read the number, not the parenthetical; §8 probe A2 reproduces this (probe A's inbox-404 case answers `/health` 200, so its health row is PASS) |
| Unsigned read answers 200 (bus without auth) | `  PASS  inbox — … -> 200`, then `CRIER: UNVERIFIED …` and exit 3 — **fail closed on the claim** [scripts/bunker-crier-connect.sh:69] [scripts/bunker-crier-connect.sh:96-102] | a signed read prints `PASS  inbox — signed read accepted on the node: …` instead [scripts/bunker-crier-connect.sh:57] | install `agent.key` + `auth/crier.token` on the node and re-run `--check` [scripts/bunker-crier-connect.sh:100-101] |
| Unsigned read answers 401 (hardened bus, the normal case) | `  WARN  inbox — … -> 401 — expected for an unsigned read …`, then `CRIER: UNVERIFIED`, exit 3 — **fail closed on the claim, WARN not FAIL** [scripts/bunker-crier-connect.sh:70] [scripts/bunker-crier-connect.sh:99-102] | a genuine auth fault on the *signed* path prints `FAIL  inbox — the node's own signed probe failed: …` [scripts/bunker-crier-connect.sh:58] | same as above; fact: FACT-03 is the 401-is-by-design measurement |
| 403 | `  FAIL  inbox — … -> 403 (owner mismatch or guard refused)` → `NOT CONNECTED (1)`, exit 1 — **fail closed** [scripts/bunker-crier-connect.sh:71] | 404 means the id is not on the bus at all [scripts/bunker-crier-connect.sh:72]; 403 means it exists and the signature names someone else [scripts/node-bus-worker.py:558] | the key on the node does not belong to `--agent`; re-stage with the right key |
| 404 | `  FAIL  inbox — … -> 404 (agent is genuinely not registered on the bus)` → `NOT CONNECTED (1)` — **fail closed** [scripts/bunker-crier-connect.sh:72] | 403 is an ownership mismatch, not an absent id [scripts/node-bus-worker.py:558-559] | register the agent on the bus, then `--apply` |
| Node lacks `agent.key`, `auth/crier.token` or `node-bus-worker.py` | No row for the missing item: the node-side `if` simply produces no output, `via_node` is empty, and the run falls through to the unsigned probe — **degraded** [scripts/bunker-crier-connect.sh:52-55] [scripts/bunker-crier-connect.sh:66] | the fallback still prints a verdict and exits 3 rather than claiming success [scripts/bunker-crier-connect.sh:96-102] | install the key/token/worker; `--check` will then say which of them made the signed read fail [scripts/bunker-crier-connect.sh:58] |
| Unsigned fallback probe runs against a bus that accepts it | The GET is `/agents/<id>/inbox?limit=1` — the *retrieve* route, which claims a lease — so one waiting dispatch is hidden from the worker for the lease window — **degraded, with a side effect** [scripts/bunker-crier-connect.sh:29] [scripts/node-bus-worker.py:41-44] | the node-side worker deliberately reads `/inbox/stats`, "a signed read that leases nothing", for exactly this reason [scripts/node-bus-worker.py:569-571] | prefer the signed path; on an unauth bus, expect one message to be leased by the check |
| No `bunker` client on the control host | `  FAIL  identity — no bunker client on PATH — $HOME/.node/crier.json cannot be read from the node`, then the `CRIER:` verdict — **fail closed and named since CF-281** [scripts/bunker-crier-connect.sh:86-98] [scripts/lib.sh:41-45]. Before the fix the same run printed `  FAIL  identity — $HOME/.node/crier.json absent — run --apply`: the missing client was reported as a missing file | `stage`/`apply` name it too, `FAIL  bunker_cli — no bunker client on PATH` [scripts/bunker-crier-connect.sh:120] [scripts/bunker-crier-connect.sh:137]; an absent client still skips the signed probe silently [scripts/bunker-crier-connect.sh:51] | install the client; the bus rows above still run without it [scripts/bunker-crier-connect.sh:40-74]; measured in §8 probe C |
| Identity file absent on the node | `  FAIL  identity — $HOME/.node/crier.json absent — run --apply`, exit 1 — **fail closed** [scripts/bunker-crier-connect.sh:82] | empty output from the client is coerced to the word `absent`, so a transport failure reads the same way [scripts/bunker-crier-connect.sh:80] | `--apply` or `--stage` [scripts/bunker-crier-connect.sh:107-140] |
| Identity names another agent or another URL | `FAIL  identity — node points elsewhere: $json` / `… names a different agent: $json`, exit 1 — **fail closed; the JSON is printed so a transport failure can be recognised** [scripts/bunker-crier-connect.sh:85-87] | the pass case prints `node points at … as …` [scripts/bunker-crier-connect.sh:84] | re-run `--apply` with the intended `--agent`/`--url` |
| Write of the identity file fails | `  FAIL  identity — could not write $HOME/.node/crier.json`, temp removed, exit 1 — **fail closed** [scripts/bunker-crier-connect.sh:135-137] | a successful write prints `wrote … (agent=…)` [scripts/bunker-crier-connect.sh:133] | check `bunker cp` reachability and the node's home permissions |
| `--apply` succeeds but the probe fails | The file stays on the node and the exit code is non-zero; the node now holds an identity claim that was never proven — **open on the artifact, closed on the verdict** [scripts/bunker-crier-connect.sh:131-139] | a `--stage` run says so in its own row (`staged …`) and never probes [scripts/bunker-crier-connect.sh:116] | re-run `--check` after fixing the cause; do not read the file's presence as a connection |
| Re-running `--apply` when nothing changed | A second `bunker cp` and a new `connected_at`, contradicting "rewrites … only when a value differs" — **degraded honesty**: the timestamp records the invocation, not a connection [scripts/bunker-crier-connect.sh:17] [scripts/bunker-crier-connect.sh:129-132] | `--stage` has the same property with `staged_at` [scripts/bunker-crier-connect.sh:112-113] | measured in §8 probe B (2 writes for 2 runs); treat the timestamp as "last time an operator ran this" |
| `lib.sh` does not define `FAILED` | `set -u` aborts at the first arithmetic test instead of printing a verdict — **fail closed, no diagnostic** [scripts/bunker-crier-connect.sh:19] [scripts/bunker-crier-connect.sh:94] [scripts/lib.sh:11] | a defined counter always produces one of the three `CRIER:` lines [scripts/bunker-crier-connect.sh:94-102] | restore `FAILED=${FAILED:-0}` in the library |
| Usage text is requested | Lines 2–20 are printed, which includes `set -uo pipefail` and the `HERE=` assignment — **cosmetic leak** [scripts/bunker-crier-connect.sh:25] [scripts/bunker-crier-connect.sh:19-20] | `-h` exits 0, a bare wrong argument exits 2 [scripts/bunker-crier-connect.sh:150-151] | read the first 16 lines only |

## 7. Environment and settings it reads

- No *setting* arrives through a dedicated variable: every setting is a flag on the command line
  [scripts/bunker-crier-connect.sh:142-153]. Three ambient variables still change what the script
  does — `PATH`, because every tool it needs is found by command lookup
  [scripts/bunker-crier-connect.sh:51] [scripts/bunker-crier-connect.sh:79]; the control host's
  `HOME`, expanded unescaped in the `UNVERIFIED` remedy text
  [scripts/bunker-crier-connect.sh:100]; and `FAILED`, inherited when the caller exported it
  [scripts/lib.sh:11]. All three are tabulated below with their measured effect (§8 probe C).
  The one variable the script *sets* is `CRIER_URL`, exported into the node-side worker invocation
  so the signed probe measures the same bus [scripts/bunker-crier-connect.sh:53]. Inside that
  remote shell `$HOME` is the *node's* home and resolves the node's `.node/` paths
  [scripts/bunker-crier-connect.sh:53] [scripts/bunker-crier-connect.sh:80] — a different variable
  from the control host's `HOME` on line 100.

| Setting | Default | Effect if absent |
|---|---|---|
| `--agent` | none [scripts/bunker-crier-connect.sh:23] | `FAIL  agent — AGENT unset` and exit 1 in `--check` [scripts/bunker-crier-connect.sh:36]; `stage`/`apply` build the identity from the empty string anyway [scripts/bunker-crier-connect.sh:112-114] |
| `--server` | none [scripts/bunker-crier-connect.sh:23] | `--server is required (the agent's bunker host)`, exit 2, before any mode runs [scripts/bunker-crier-connect.sh:156] |
| `--url` (alias `--crier-url`) | none [scripts/bunker-crier-connect.sh:146] | `FAIL  url — URL unset` and exit 1 [scripts/bunker-crier-connect.sh:37]; the signed probe is also skipped without it [scripts/bunker-crier-connect.sh:51-53] |
| `--project` | `$AGENT` at write time, `${PROJECT:-$AGENT}` [scripts/bunker-crier-connect.sh:112] [scripts/bunker-crier-connect.sh:129] | the identity carries the agent name as the project |
| `--timeout` | `10` seconds [scripts/bunker-crier-connect.sh:23] [scripts/bunker-crier-connect.sh:148] | applies to both `curl` calls as `-m` [scripts/bunker-crier-connect.sh:29] [scripts/bunker-crier-connect.sh:40]; the node-side `bunker exec` has its own hard-coded 45 s [scripts/bunker-crier-connect.sh:52] [scripts/bunker-crier-connect.sh:80] |
| `--check` / `--apply` / `--stage` | none [scripts/bunker-crier-connect.sh:149] | usage text, exit 2 [scripts/bunker-crier-connect.sh:155] |
| `-h` / `--help` | — | prints usage and exits 0 [scripts/bunker-crier-connect.sh:150] [scripts/bunker-crier-connect.sh:25] |
| file mode of the identity | `600`, applied by a remote `chmod` after the copy [scripts/bunker-crier-connect.sh:125] [scripts/bunker-crier-connect.sh:142] | a `chmod` failure fails the whole write because it is chained with `&&` [scripts/bunker-crier-connect.sh:124-125] |
| `HOME` (control host) | inherited from the invoking shell; never assigned by the script [scripts/bunker-crier-connect.sh:100] | read only in the `UNVERIFIED` remedy text, unescaped, so it prints the control host's home directory [scripts/bunker-crier-connect.sh:100]. **Unset, `set -u` [scripts/bunker-crier-connect.sh:19] aborts there**: after the first `CRIER: UNVERIFIED …` line and before either remedy line, bash prints `line 100: HOME: unbound variable` and the run exits **1** instead of 3 — the operator loses both remedy lines and the exit code that means "unverified" (measured, §8 probe C). The `CONNECTED` [scripts/bunker-crier-connect.sh:97] and `NOT CONNECTED` [scripts/bunker-crier-connect.sh:95] verdicts never expand it, so a signed success is unaffected (measured: exit 0) |
| `PATH` | inherited; the script writes no default | the only lookup path for `bunker` (`command -v` gate [scripts/bunker-crier-connect.sh:51], `have bunker` [scripts/bunker-crier-connect.sh:79] [scripts/bunker-crier-connect.sh:109]) and for `curl`, `timeout`, `python3`, `mktemp`, `chmod`, `date`, `sed` [scripts/bunker-crier-connect.sh:29] [scripts/bunker-crier-connect.sh:52] [scripts/bunker-crier-connect.sh:111] [scripts/bunker-crier-connect.sh:113]. With no `bunker` on `PATH`, `--check` skips the signed probe [scripts/bunker-crier-connect.sh:51] and names the client: `have()` exits non-zero on absence [scripts/lib.sh:41-45], so the identity step prints `FAIL  identity — no bunker client on PATH — $HOME/.node/crier.json cannot be read from the node` [scripts/bunker-crier-connect.sh:86-98] and the run still reaches its `CRIER: NOT CONNECTED (n)` verdict, exit 1 (before CF-281 the absence surfaced as `FAIL  identity — $HOME/.node/crier.json absent — run --apply`, with no client named). `--apply`/`--stage` name it too (`FAIL  bunker_cli — no bunker client on PATH`), exit 1 [scripts/bunker-crier-connect.sh:120] [scripts/bunker-crier-connect.sh:137]. No `curl` collapses both HTTP codes to `000` [scripts/bunker-crier-connect.sh:29-31]; no `timeout` silently forces the unsigned fallback [scripts/bunker-crier-connect.sh:52-55] (measured, §8 probe C) |
| `FAILED` | `0`, from the library's `${FAILED:-0}` [scripts/lib.sh:11] | the default applies only when the variable is unset or empty, so an exported `FAILED=1` is kept and both verdict tests compare against it [scripts/bunker-crier-connect.sh:61] [scripts/bunker-crier-connect.sh:94]: an all-PASS signed run then prints `CRIER: NOT CONNECTED (1)` and exits 1 (measured, §8 probe C) |

## 8. Evidence of record

Everything below was run on 2026-11-05 against `scripts/bunker-crier-connect.sh` at its last
touching commit `7f9ca12`. Probes A and B were run in worktree `~/proj-wt-md-04` at `9ecb70c`;
probes A2 and C were re-run in worktree `~/proj-wt-fix04` at `b9f56e6`, which carries the same
script (no commit between `7f9ca12` and `b9f56e6` touches it). Every probe is hermetic: a stub bus
on loopback and a stub `bunker` on `PATH`; none writes to the repository and none touches a real
node.

**A. Verdict ladder (5 cases).** Stub bus answers 200 to `/health` and the case's code to
`/agents/*`; stub `bunker` returns the identity JSON for the `crier.json` read, and either
nothing or a synthetic `PASS  inbox` row for the signed probe. Copy to a scratch dir and run
`bash probe-04-crier-connect.sh /home/kara/code-factory 18767`:

```bash
#!/usr/bin/env bash
set -uo pipefail
REPO="${1:-$HOME/code-factory}"; PORT="${2:-18767}"; T=$(mktemp -d); SRV=0
trap '[ "$SRV" -gt 1 ] && kill "$SRV" 2>/dev/null; rm -rf "$T"' EXIT
cat > "$T/bus.py" <<'PY'
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
inbox_code = int(sys.argv[2])
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        code = 200 if self.path == "/health" else inbox_code
        self.send_response(code); self.send_header("Content-Type", "application/json")
        self.end_headers(); self.wfile.write(b'{"queue_depth":0}')
    def log_message(self, *a): pass
HTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
PY
cat > "$T/bunker" <<'SH'
#!/bin/sh
case "$*" in
  *crier.json*) printf '{"agent":"a1","project":"p","url":"%s","connected_at":"2026-11-05T00:00:00Z"}\n' "$STUB_URL" ;;
  *) if [ "${PASS_SIGNED:-0}" = 1 ]; then printf '  PASS  inbox — GET /agents/a1/inbox/stats -> 200 (signed read accepted; queue_depth 0, leased_count 0)\n'; fi ;;
esac
SH
chmod +x "$T/bunker"
run_case() { local name="$1" code="$2" signed="$3" want="$4" wantline="$5" out rc
  python3 "$T/bus.py" "$PORT" "$code" & SRV=$!
  for _ in $(seq 1 50); do (exec 3<>/dev/tcp/127.0.0.1/$PORT) 2>/dev/null && break; sleep 0.1; done
  out=$(cd "$REPO" && PATH="$T:$PATH" PASS_SIGNED="$signed" STUB_URL="http://127.0.0.1:$PORT" \
    bash scripts/bunker-crier-connect.sh --agent a1 --server s1 \
    --url "http://127.0.0.1:$PORT" --timeout 2 --check 2>&1); rc=$?
  kill "$SRV" 2>/dev/null; wait "$SRV" 2>/dev/null; SRV=0
  echo "### $name"; echo "$out"; echo "--- exit=$rc (want $want)"
  if [ "$rc" = "$want" ] && grep -qF "$wantline" <<<"$out"; then echo "RESULT: PASS"; else echo "RESULT: FAIL"; fi; }
run_case "unsigned 200" 200 0 3 "CRIER: UNVERIFIED"
run_case "unsigned 401" 401 0 3 "CRIER: UNVERIFIED"
run_case "signed read accepted" 200 1 0 "CRIER: CONNECTED"
run_case "403 owner mismatch" 403 0 1 "CRIER: NOT CONNECTED"
run_case "404 not registered" 404 0 1 "CRIER: NOT CONNECTED"
```

Observed, verbatim, for the signed case and the 404 case:

```
crier-connect --check — agent=a1 url=http://127.0.0.1:18767
  PASS  bus_health — http://127.0.0.1:18767/health -> 200
  PASS  inbox — signed read accepted on the node:   PASS  inbox — GET /agents/a1/inbox/stats -> 200 (signed read accepted; queue_depth 0, leased_count 0)
  PASS  identity — node points at http://127.0.0.1:18767 as a1

CRIER: CONNECTED — a1 at http://127.0.0.1:18767 (signed read accepted)
```

```
crier-connect --check — agent=a1 url=http://127.0.0.1:18767
  PASS  bus_health — http://127.0.0.1:18767/health -> 200
  FAIL  inbox — http://127.0.0.1:18767/agents/a1/inbox -> 404 (agent is genuinely not registered on the bus)
  PASS  identity — node points at http://127.0.0.1:18767 as a1

CRIER: NOT CONNECTED (1)
```

**A2. The `/health` parenthetical, measured on its own.** Same stub bus and stub `bunker`, with
`/health` answered 404 instead of 200 (`/agents/*` also 404). Output verbatim:

```
crier-connect --check — agent=a1 url=http://127.0.0.1:18791
  FAIL  bus_health — http://127.0.0.1:18791/health -> 404 (bus not answering)
  FAIL  inbox — http://127.0.0.1:18791/agents/a1/inbox -> 404 (agent is genuinely not registered on the bus)
  PASS  identity — node points at http://127.0.0.1:18791 as a1

CRIER: NOT CONNECTED (2)
--- exit=1
```

The parenthetical is the defect at [scripts/bunker-crier-connect.sh:43]: a bus that answered is
described as one that did not. Probe A's case 5 above does not show this — its `/health` is
answered 200, so that transcript's first row is `PASS  bus_health — … -> 200`. The two use the same
harness; only the stub's `/health` code differs.

**B. The idempotence claim (falsified).** Same stub bus, a `bunker` stub that logs every `cp`:

```bash
#!/usr/bin/env bash
# 04 probe b: does --apply rewrite $HOME/.node/crier.json unconditionally?
set -uo pipefail
REPO="${1:-$HOME/code-factory}"; PORT="${2:-18768}"; T=$(mktemp -d); SRV=0
trap '[ "$SRV" -gt 1 ] && kill "$SRV" 2>/dev/null; rm -rf "$T"' EXIT

cat > "$T/bus.py" <<'PY'
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200); self.end_headers(); self.wfile.write(b'{}')
    def log_message(self, *a): pass
HTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
PY
python3 "$T/bus.py" "$PORT" & SRV=$!
for _ in $(seq 1 50); do (exec 3<>/dev/tcp/127.0.0.1/$PORT) 2>/dev/null && break; sleep 0.1; done

cat > "$T/bunker" <<'SH'
#!/bin/sh
case "$1" in
  cp)   echo "CP $2 -> $3" >> "$STUB_LOG" ;;
  exec) case "$*" in *crier.json*) printf '{"agent":"a1","project":"p","url":"%s"}\n' "$STUB_URL" ;; esac ;;
esac
SH
chmod +x "$T/bunker"

for i in 1 2; do
  (cd "$REPO" && PATH="$T:$PATH" STUB_LOG="$T/calls" STUB_URL="http://127.0.0.1:$PORT" \
     bash scripts/bunker-crier-connect.sh --agent a1 --server s1 \
     --url "http://127.0.0.1:$PORT" --timeout 2 --apply >/dev/null 2>&1)
  echo "apply run $i exit=$?"
done
echo "--- bunker cp calls observed: $(grep -c '^CP ' "$T/calls" 2>/dev/null || echo 0)"
cat "$T/calls" 2>/dev/null
```

Observed:

```
apply run 1 exit=3
apply run 2 exit=3
--- bunker cp calls observed: 2
CP /mnt/bulk/scratch/tmp.cjsEs27O9w -> a1:.node/crier.json
CP /mnt/bulk/scratch/tmp.kPoOksamwi -> a1:.node/crier.json
```

Two runs, two writes: `apply()` has no "value differs" comparison
[scripts/bunker-crier-connect.sh:129-132], so line 17's claim is contradicted by the file's own
measurement.

**C. Environment reads.** One ambient variable changed per run against the same stub bus. Output
verbatim; the `$ …` lines name the invocation, and the stub `bunker` and stub bus are on `PATH` as
in probe A.

```
$ env -u HOME bash scripts/bunker-crier-connect.sh … --check     # bus answers 401 to the unsigned read
crier-connect --check — agent=a1 url=http://127.0.0.1:18791
  PASS  bus_health — http://127.0.0.1:18791/health -> 200
  WARN  inbox — http://127.0.0.1:18791/agents/a1/inbox -> 401 — expected for an unsigned read (crier checks the signer before it looks the agent up); the signed probe needs agent.key + crier.token on the node
  PASS  identity — node points at http://127.0.0.1:18791 as a1

CRIER: UNVERIFIED — a1 at http://127.0.0.1:18791: the bus answered an UNSIGNED read, so this node's key and
scripts/bunker-crier-connect.sh: line 100: HOME: unbound variable
--- exit=1 (with HOME set this run prints both remedy lines and exits 3)
```

```
$ PATH=/usr/bin:/bin bash scripts/bunker-crier-connect.sh … --check   # no bunker client
crier-connect --check — agent=a1 url=http://127.0.0.1:18791
  PASS  bus_health — http://127.0.0.1:18791/health -> 200
  WARN  inbox — http://127.0.0.1:18791/agents/a1/inbox -> 401 — expected for an unsigned read (crier checks the signer before it looks the agent up); the signed probe needs agent.key + crier.token on the node
  FAIL  identity — $HOME/.node/crier.json absent — run --apply

CRIER: NOT CONNECTED (1)
--- exit=1 (the absent client is reported as an absent file, not as an absent client)
```

```
$ FAILED=1 bash scripts/bunker-crier-connect.sh … --check             # every row PASS, no signed read
crier-connect --check — agent=a1 url=http://127.0.0.1:18791
  PASS  bus_health — http://127.0.0.1:18791/health -> 200
  PASS  inbox — http://127.0.0.1:18791/agents/a1/inbox -> 200
  PASS  identity — node points at http://127.0.0.1:18791 as a1

CRIER: NOT CONNECTED (1)
--- exit=1 (no CONNECTED line despite three PASS rows and no FAIL)
```

`HOME` is reached only on the `UNVERIFIED` path, which is why the same unset variable leaves a
signed run untouched: under `env -u HOME` with a `PASS  inbox` row the run prints
`CRIER: CONNECTED …` and exits 0 (measured). `FAILED` is the one inherited value that can veto a
success, and it does so before `SIGNED_READ` is consulted
[scripts/bunker-crier-connect.sh:94-97].

**D. What a reviewer re-runs.** §3 in order: `bash -n`, the two argument guards, probe A, probe A2,
probe B, probe C.
A reviewer with a real node adds `bunker-crier-connect.sh --agent <a> --server <host> --url <bus>
--check` and expects either `CONNECTED` (signed read accepted) or `UNVERIFIED` exit 3 — never
`CONNECTED` on an unsigned answer [scripts/bunker-crier-connect.sh:96-102] (fact: FACT-04 is that
measured 200 on `cf-node`).

**E. Documentation that has not caught up.** [docs/OPERATIONS.md:48] and
[docs/ACCEPTANCE-PLAN.md:146] both state that `CONNECTED` is printed on a bare 200, which the
code no longer does; both also cite line ranges (`:26-68`, `:89-104`) that predate the signed-read
change [scripts/bunker-crier-connect.sh:91-104]. This module records the code's behaviour, and
those two rows are the correction owed to them.
