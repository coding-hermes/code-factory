# 04. scripts/bunker-crier-connect.sh

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/bunker-crier-connect.sh` [scripts/bunker-crier-connect.sh:1] |
| Repository | `code-factory` [scripts/bunker-crier-connect.sh:1] |
| Revision | `384a842a` — current shipped behavior; tree `bb7ac31e` |
| Status | **UPDATED — behavior re-derived from the current script and the CF-214 selftest fixture; the named `probe-04-crier-connect.sh` is not tracked here, so no probe transcript or measurement date is claimed** |

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
  [scripts/bunker-provision.sh:278] [scripts/bunker-provision.sh:272]. The node ladder's bus
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
  2. The in-repo operator documentation had described the pre-CF-214 crier verdicts
     [docs/OPERATIONS.md:48]. The shipped code now treats the host inbox route as the explicit
     acceptance probe: an unsigned 200 yields `CRIER: CONNECTED`, while the optional node-side
     signed probe is reported separately as `PASS  signed_read` [scripts/bunker-crier-connect.sh:46-71]
     [scripts/bunker-crier-connect.sh:51-57]. An inbox 401 is a `FAIL` row naming the refused
     authentication or agent signature.
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
- What breaks if the *verdict* lies (the failure this file exists to prevent): the host `CONNECTED`
  verdict is tied to the exact inbox route returning 200 [scripts/bunker-crier-connect.sh:46-58]
  [scripts/bunker-crier-connect.sh:98-105]. The node's signed probe is optional diagnostic evidence,
  and only its `PASS  signed_read` row proves that the node-side key was exercised
  [scripts/bunker-crier-connect.sh:60-72]. An unsigned 200 therefore yields `CONNECTED` for the
  host route but does not certify a signed read; an unsigned 401 is a `FAIL` row and the run is
  not connected [scripts/bunker-crier-connect.sh:51-57] [scripts/bunker-crier-connect.sh:101-116].
  This is the requirement stated over the measurements, and it matches the bus's own order of
  checks [scripts/node-bus-worker.py:556-557] (fact: FACT-03).

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `bash` | unpinned — no version check in the source [scripts/bunker-crier-connect.sh:19] | shebang `#!/usr/bin/env bash` [scripts/bunker-crier-connect.sh:1]; `lib.sh` itself "Requires bash" [scripts/lib.sh:3] | nothing in this script; a non-bash `sh` fails on `local`/`pipefail` without a named row [scripts/bunker-crier-connect.sh:19-23] |
| `curl` | unpinned [scripts/bunker-crier-connect.sh:29] | `PATH` | **not detected as itself**: `curl … 2>/dev/null \|\| true` reduces any failure to an empty string, which `probe()` renders as `000` [scripts/bunker-crier-connect.sh:29-31] and the health row reports as "(bus not answering)" [scripts/bunker-crier-connect.sh:43] |
| `bunker` client | unpinned [scripts/bunker-crier-connect.sh:84] | `PATH`, and executable for the signed probe path [scripts/bunker-crier-connect.sh:51] | **named since CF-281**: `have()` exits non-zero on absence [scripts/lib.sh:41-45], so the identity step's `if b=$(have bunker)` takes its `else` and prints one `FAIL  identity — no bunker client on PATH — $HOME/.node/crier.json cannot be read from the node` row [scripts/bunker-crier-connect.sh:86-98] and the run still prints its `CRIER:` verdict. Before the fix the status was constant 0, the arm was dead, and the absence surfaced as `FAIL  identity — $HOME/.node/crier.json absent — run --apply` (measured, §8 probe C); `stage`/`apply` name it too, exit 1 [scripts/bunker-crier-connect.sh:120] [scripts/bunker-crier-connect.sh:137] |
| GNU `timeout` | unpinned [scripts/bunker-crier-connect.sh:52] | `PATH` | **not detected**: a missing `timeout` makes the whole `bunker exec` line fail, `\|\| true` swallows it, `via_node` stays empty, and the script silently falls back to the unsigned probe [scripts/bunker-crier-connect.sh:52-55] [scripts/bunker-crier-connect.sh:66] |
| `python3` on the node | unpinned [scripts/bunker-crier-connect.sh:53] | inside the node's `$HOME`, with `$HOME/node-bus-worker.py` present [scripts/bunker-crier-connect.sh:53] | the node-side `if` guard tests the worker file, not `python3`; a missing interpreter yields an empty row → same silent fallback [scripts/bunker-crier-connect.sh:53-55] |
| `mktemp`, `chmod`, `date`, `sed` | coreutils/busybox, unpinned [scripts/bunker-crier-connect.sh:25] [scripts/bunker-crier-connect.sh:111] [scripts/bunker-crier-connect.sh:113] | `PATH` | unchecked; if `mktemp` fails, `"$tmp"` is empty and the following `printf … > "$tmp"` targets an empty path and fails [scripts/bunker-crier-connect.sh:111-113] |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `. "$HERE/lib.sh"` | `scripts/lib.sh`, sourced with the script's own directory as `HERE` [scripts/bunker-crier-connect.sh:20-21] | defines `say`, `ok`, `bad`, `warn`, `have` [scripts/lib.sh:5-9] [scripts/lib.sh:41-45] | every row vanishes or errors; the script has no local fallback definitions [scripts/bunker-crier-connect.sh:21] |
| `bad()` increments `FAILED` | `scripts/lib.sh:7` | each failure both prints `  FAIL …` and bumps the counter the verdict reads [scripts/bunker-crier-connect.sh:61] [scripts/bunker-crier-connect.sh:94] | if `bad` stopped counting, FAIL rows would print and the verdict would fall through to `SIGNED_READ`, i.e. a visibly failed run could still print `CONNECTED` |
| `FAILED=${FAILED:-0}` | `scripts/lib.sh:11` | the variable exists before the first arithmetic test [scripts/bunker-crier-connect.sh:61] | with `set -u` in force [scripts/bunker-crier-connect.sh:19], an undefined `FAILED` aborts the run at the first `[ "$FAILED" … ]` instead of printing a verdict |
| `ok`/`warn` never touch `FAILED`, `bad` does | `scripts/lib.sh:6` [scripts/lib.sh:8] [scripts/lib.sh:7] | the optional `PASS  signed_read` row is reported without changing the verdict [scripts/bunker-crier-connect.sh:68-70], while an inbox `401` goes through `bad "inbox" …` and therefore is a `FAIL` that condemns the run [scripts/bunker-crier-connect.sh:53] | if `ok` counted, every successful signed probe would red a healthy run; if `bad` stopped counting, the 401 would read as `CONNECTED`, since the 401/unsigned-200 distinction is carried by `bad` versus `ok` and not by row text |
| `have()` shape | `scripts/lib.sh:41-45` | **present: exit 0 and the resolved path on stdout; absent: non-zero and nothing on stdout** — absence is reported by STATUS as well as by empty output, since CF-281; it is used both as a command substitution [scripts/bunker-crier-connect.sh:86] [scripts/bunker-crier-connect.sh:119] and as a status test [scripts/bunker-crier-connect.sh:86] | a `have` that printed a message on absence would be executed as a command path in `"$b" cp` [scripts/bunker-crier-connect.sh:124]; the status half is what makes the `no bunker client on PATH` row reachable, which is the branch the pre-fix version could never take |
| `bunker exec --server S AGENT -- bash -lc '<text>'` argv shape | established by `bunker_exec` [scripts/lib.sh:62-65]; this script builds the same shape inline rather than calling it [scripts/bunker-crier-connect.sh:85] | the client splits `--server`, agent, `--`, command | both call sites break together; this script would not inherit a fix made inside `bunker_exec` |

### 2c. Service contracts (both sides must be named)

The bus and the node are separate processes from this script. The crier sources live in a
different repository (`docs/REPOSITORIES.md:19`) and their `file:line` cannot resolve against
this tree, so the peer-side citations below are function names plus the ledger fact that
measured them (fact: FACT-03, fact: FACT-04); every in-repo side carries a resolvable locator.

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| crier bus, `GET <url>/health` [scripts/bunker-crier-connect.sh:40] | script → bus | HTTP GET, `-m $TIMEOUT`, body discarded (`-o /dev/null -w '%{http_code}'`) [scripts/bunker-crier-connect.sh:40] | none; only the status code is read [scripts/bunker-crier-connect.sh:41-44] | crier `cmd/server/main.go` → the `/health` handler registered beside the Mux; it is GET-only, so a HEAD there answers 405 and is not a fault [scripts/project-node.sh:245]. In-repo mirror of the same probe: `scripts/node-bus-worker.py:540-547` |
| crier bus, `GET <url>/agents/<agent>/inbox?limit=1` [scripts/bunker-crier-connect.sh:29] | script → bus, **unsigned** (no bearer, no `X-Agent-*`) [scripts/bunker-crier-connect.sh:29] | HTTP GET over the bus URL [scripts/bunker-crier-connect.sh:29] | no body; the code is printed and matched [scripts/bunker-crier-connect.sh:67-74] | crier `cmd/server/main.go` → `registerRegistryRoutes` registers `/agents/{id}/inbox` GET to `HandleRetrieve`; `internal/registry/handler.go` → `HandleRetrieve` calls `requireAgent` before it parses the query or claims anything, and `internal/registry/agentsig.go` → `authorizeAgent` verifies the ed25519 signature. The 401-before-lookup order is fact: FACT-03, mirrored in-repo with the same ladder wording at `scripts/node-bus-worker.py:555-560`. Because this is the *retrieve* route and not `/inbox/stats`, an authenticated call claims a lease [scripts/node-bus-worker.py:41-44] |
| node bus worker, `python3 $HOME/node-bus-worker.py --check` [scripts/bunker-crier-connect.sh:64] | script → node (via `bunker exec`) → bus | `bunker exec --server <host> <agent> -- bash -lc '<script>'`, 45 s `timeout` [scripts/bunker-crier-connect.sh:62-64] | stdout rows, filtered with `grep -E "PASS  inbox\|FAIL  inbox" \| head -1` [scripts/bunker-crier-connect.sh:64] | `scripts/node-bus-worker.py` → `check()`: prints `node-bus-worker --check — agent=… bus=…` [scripts/node-bus-worker.py:445], signs a GET of `/agents/<id>/inbox/stats` and prints the worker inbox row. The surrounding script converts a worker `PASS  inbox` row into the separate `PASS  signed_read` row [scripts/bunker-crier-connect.sh:66-71]. |
| bunker client → bunker host daemon [scripts/bunker-crier-connect.sh:114] [scripts/bunker-crier-connect.sh:131] | script → node | `bunker cp <local-tmp> <agent>:.node/crier.json --server <host>` then `bunker exec … chmod 600` [scripts/bunker-crier-connect.sh:114-115] | a JSON object with `agent`, `project`, `url` and a timestamp [scripts/bunker-crier-connect.sh:112-113] [scripts/bunker-crier-connect.sh:129-130] | the file is read back through the same client at [scripts/bunker-crier-connect.sh:80] and consumed by the worker's identity precedence `crier.json.agent → node.json.agent → --agent` [scripts/node-bus-worker.py:51-53] [scripts/node-bus-worker.py:339] |
| `$HOME/.node/crier.json` on the node (mode 600) [scripts/bunker-crier-connect.sh:115] | script writes, two readers | file on the node | `{"agent","project","url","staged_at"\|"connected_at"}` [scripts/bunker-crier-connect.sh:112] [scripts/bunker-crier-connect.sh:129] | `scripts/node-bus-worker.py:339` reads it for the agent id and bus URL; the node ladder only checks existence and mode [scripts/project-node.sh:244-249] [specs/NODE.md:62-63] |

## 3. Verification

The current behavior was re-derived from the shipped script and the CF-214 selftest fixture. The
named `probe-04-crier-connect.sh` is not tracked in this repository, so this document does not
claim that it was re-run, does not paste its output, and does not invent a measurement date.

| Check | Command | Expected | Evidence |
|---|---|---|---|
| Parse | `bash -n scripts/bunker-crier-connect.sh` | no output, exit 0 [scripts/bunker-crier-connect.sh:1-169] | current selftest parse arm |
| Argument guard | `bash scripts/bunker-crier-connect.sh --check` | `--server is required (the agent's bunker host)`, exit 2 [scripts/bunker-crier-connect.sh:167-168] | source contract |
| Mode guard | `bash scripts/bunker-crier-connect.sh --agent x --server s` | usage text, exit 2 [scripts/bunker-crier-connect.sh:163-167] | source contract |
| Verdict ladder | the current CF-214 selftest fixture (§8 note) — stub bus + fixture `bunker` | unsigned 200 → `CRIER: CONNECTED`, exit 0; 401 → `FAIL  inbox` naming authentication or agent signature refusal; signed node probe → optional `PASS  signed_read`; 403/404/000 → distinct `FAIL` rows [scripts/bunker-crier-connect.sh:46-71] [scripts/bunker-crier-connect.sh:98-116] | selftest section 40 |
| Idempotence claim | two `--apply` runs | the header still claims rewrite-on-difference, but the existing evidence records two writes [scripts/bunker-crier-connect.sh:17] [scripts/bunker-crier-connect.sh:135-149] | existing documented defect; not re-run here |
| Health row on a non-200 `/health` | stub fixture with `/health` 404 | `FAIL  bus_health` prints the returned code and the existing parenthetical [scripts/bunker-crier-connect.sh:39-44] | source contract; no new transcript claimed |
| Environment reads | `PATH` without `bunker`; inherited `FAILED` | the missing client is named in `FAIL identity`, and `FAILED` can veto a run [scripts/bunker-crier-connect.sh:74-96] [scripts/lib.sh:11] | source contract; no new transcript claimed |

A check that cannot fail would be decoration. Section 40's provisioner arm is falsifiable: it
requires a WARN when the host route is an unsigned 200 and no node-side signed row exists, requires
the quoted `PASS  signed_read` row when the fixture emits one, and runs a scratch copy of the old
`PASS  inbox` certification to prove that it reds.

## 4. Metrics emitted

- **None.** The script opens no counter, histogram, exporter or timing instrument; it prints rows
  and exits [scripts/bunker-crier-connect.sh:94-104] [scripts/bunker-crier-connect.sh:154-169].
  There is no dispatch-rate, attempt-count or latency series to scrape, and nothing persists a
  run's outcome except the identity file's own timestamp
  [scripts/bunker-crier-connect.sh:111-113] [scripts/bunker-crier-connect.sh:142].
- What exists instead is a process-level verdict on the exit code: `0` connected
  [scripts/bunker-crier-connect.sh:104], `1` not connected — returned both by the
  `via_node` branch [scripts/bunker-crier-connect.sh:61-65] and by the final `[ "$FAILED" -eq 0 ]`
  [scripts/bunker-crier-connect.sh:104], `2` usage/argument refusal
  [scripts/bunker-crier-connect.sh:25] [scripts/bunker-crier-connect.sh:163] [scripts/bunker-crier-connect.sh:168], `3` unverified
  [scripts/bunker-crier-connect.sh:102]. The `FAIL` count is also printed once as
  `CRIER: NOT CONNECTED ($FAILED)` [scripts/bunker-crier-connect.sh:63]
  [scripts/bunker-crier-connect.sh:95] — the only aggregate the script ever reports, and it dies
  with the process.

## 5. Log lines it can generate

Rendering is owned by `lib.sh`: `  PASS  %s — %s`, `  FAIL  %s — %s`, `  WARN  %s — %s`, each with
two leading spaces, and `say` prints bare text [scripts/lib.sh:5-9]. Values below are shown as the
source interpolates them.

Historical format examples (not re-run for this revision; values are source-derived and no measurement date is claimed):

- `crier-connect --check — agent=a1 url=http://127.0.0.1:18767` — descriptive (the header; it is
  printed before any measurement) [scripts/bunker-crier-connect.sh:35].
- `  PASS  bus_health — http://127.0.0.1:18767/health -> 200` — evidentiary
  [scripts/bunker-crier-connect.sh:42].
- `  PASS  inbox — http://127.0.0.1:18767/agents/a1/inbox -> 200` — descriptive: it names a 200
  that proves nothing about the key [scripts/bunker-crier-connect.sh:69].
- `  FAIL  inbox — http://127.0.0.1:18767/agents/a1/inbox -> 401 (authentication or agent signature refused)` — evidentiary; the unsigned host route is refused [scripts/bunker-crier-connect.sh:53].
- `  FAIL  inbox — http://127.0.0.1:18767/agents/a1/inbox -> 403 (owner mismatch or guard refused)` — evidentiary [scripts/bunker-crier-connect.sh:71].
- `  FAIL  inbox — http://127.0.0.1:18767/agents/a1/inbox -> 404 (agent is genuinely not registered on the bus)` — evidentiary [scripts/bunker-crier-connect.sh:72].
- `  PASS  identity — node points at http://127.0.0.1:18767 as a1` — evidentiary
  [scripts/bunker-crier-connect.sh:84].
- `CRIER: CONNECTED — a1 at http://127.0.0.1:18767 (inbox route returned 200)` — evidentiary for
  the host route; it does not certify the node key [scripts/bunker-crier-connect.sh:103-105].
- `CRIER: UNVERIFIED — a1 at http://127.0.0.1:18767: signed read succeeded but the required inbox route was not 200` — evidentiary for the signed-only case [scripts/bunker-crier-connect.sh:105-109].
- `CRIER: UNVERIFIED — a1 at http://127.0.0.1:18767: the bus answered an UNSIGNED read, so this node's key and` — evidentiary, followed by the two indented remedy lines
  `        bearer were not exercised. Install /home/kara/.node/agent.key and ~/.node/auth/crier.token`
  and `        and stage the bus worker, then re-run --check.`
  [scripts/bunker-crier-connect.sh:110-114].
- `CRIER: NOT CONNECTED (1)` / `CRIER: NOT CONNECTED (2)` — evidentiary; the number is `$FAILED`
  [scripts/bunker-crier-connect.sh:63] [scripts/bunker-crier-connect.sh:95].

Literal format strings present in the source but not exercised by the probe (the interpolated
values are the script's own variables, never invented here):

- `  PASS  signed_read — node-side signed inbox read accepted: $via_node` — evidentiary, the one
  row that sets `SIGNED_READ=1` [scripts/bunker-crier-connect.sh:68-70].
- `  FAIL  signed_read — the node's own signed probe failed: $via_node` — evidentiary
  [scripts/bunker-crier-connect.sh:68-71].
- `  FAIL  bus_health — $URL/health -> ${health:-000} (bus not answering)` — descriptive, and
  wrong for any non-200 that is an answer [scripts/bunker-crier-connect.sh:43].
- `  FAIL  inbox — $URL/agents/$AGENT/inbox -> $code` — the `*)` arm, and the row an operator sees
  for `000` because `probe()` substitutes `000` for an empty code
  [scripts/bunker-crier-connect.sh:30] [scripts/bunker-crier-connect.sh:57].
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
  `  FAIL  identity — could not write $HOME/.node/crier.json` — evidentiary [scripts/bunker-crier-connect.sh:130] [scripts/bunker-crier-connect.sh:147].
- `crier-connect --apply — agent=$AGENT url=$URL` — descriptive [scripts/bunker-crier-connect.sh:125].
- `unknown argument: $1` — descriptive [scripts/bunker-crier-connect.sh:163].
- `--server is required (the agent's bunker host)` — descriptive [scripts/bunker-crier-connect.sh:168].

There is no logger, level, destination or retention policy: every line goes to stdout/stderr of
the invoking shell and nothing is retained [scripts/bunker-crier-connect.sh:94-104].

## 6. Failure modes

Direction is stated per row: **fail closed** = the run refuses the claim, **degraded** = the run
continues on a weaker path, **open** = the run lets a weaker fact stand.

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Bus does not answer `/health` | `  FAIL  bus_health — … -> 000 (bus not answering)` then `CRIER: NOT CONNECTED (1)`, exit 1 — **fail closed** [scripts/bunker-crier-connect.sh:39-44] [scripts/bunker-crier-connect.sh:98-102] | an inbox `401` is a distinct authentication or agent-signature refusal [scripts/bunker-crier-connect.sh:51-57] | start the bus or fix `--url`; the health row names the URL [scripts/bunker-crier-connect.sh:40-43] |
| Bus answers non-200 on `/health` for a reason other than reachability | Same row, with the returned code printed but the parenthetical still saying "bus not answering" — **degraded diagnosis, fail closed verdict** [scripts/bunker-crier-connect.sh:39-44] | only the returned code distinguishes a 404 from a dead host | read the returned code and fix the health route |
| Unsigned read answers 200 (bus without auth) | `  PASS  inbox — … -> 200`, then `CRIER: CONNECTED … (inbox route returned 200)` and exit 0 — **host-route evidence only; no signed-read claim** [scripts/bunker-crier-connect.sh:46-58] [scripts/bunker-crier-connect.sh:101-105] | a node-side signed probe, when measured, is a separate `PASS  signed_read` row [scripts/bunker-crier-connect.sh:60-72] | install `agent.key` + `auth/crier.token` and stage the worker if node-side proof is required |
| Unsigned read answers 401 | `  FAIL  inbox — … -> 401 (authentication or agent signature refused)` then `CRIER: NOT CONNECTED`, exit 1 — **fail closed** [scripts/bunker-crier-connect.sh:51-57] [scripts/bunker-crier-connect.sh:101-102] | 403 is owner/guard refusal; 404 is an unregistered agent; 000 is no answer | inspect the bus authentication and agent-signature configuration |
| 403 | `  FAIL  inbox — … -> 403 (owner mismatch or guard refused)` → `NOT CONNECTED (1)`, exit 1 — **fail closed** [scripts/bunker-crier-connect.sh:71] | 404 means the id is not on the bus at all [scripts/bunker-crier-connect.sh:72]; 403 means it exists and the signature names someone else [scripts/node-bus-worker.py:558] | the key on the node does not belong to `--agent`; re-stage with the right key |
| 404 | `  FAIL  inbox — … -> 404 (agent is genuinely not registered on the bus)` → `NOT CONNECTED (1)` — **fail closed** [scripts/bunker-crier-connect.sh:72] | 403 is an ownership mismatch, not an absent id [scripts/node-bus-worker.py:558-559] | register the agent on the bus, then `--apply` |
| Node lacks `agent.key`, `auth/crier.token` or `node-bus-worker.py` | No `signed_read` row: the node-side conditional produces no output, `via_node` is empty, and the run proceeds to the host inbox verdict — **degraded evidence** [scripts/bunker-crier-connect.sh:60-72] | the host route can still print `CONNECTED` on 200, but the provisioner must say the signed read was not measured [scripts/bunker-provision.sh:280-289] | install the key/token/worker if node-side proof is required; otherwise treat the host-route result as unsigned |
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
  [scripts/bunker-crier-connect.sh:154-165]. Three ambient variables still change what the script
  does — `PATH`, because every tool it needs is found by command lookup
  [scripts/bunker-crier-connect.sh:51] [scripts/bunker-crier-connect.sh:84]; the control host's
  `HOME`, expanded unescaped in the `UNVERIFIED` remedy text
  [scripts/bunker-crier-connect.sh:112]; and `FAILED`, inherited when the caller exported it
  [scripts/lib.sh:11]. All three are tabulated below with their measured effect (§8 probe C).
  The one variable the script *sets* is `CRIER_URL`, exported into the node-side worker invocation
  so the signed probe measures the same bus [scripts/bunker-crier-connect.sh:53]. Inside that
  remote shell `$HOME` is the *node's* home and resolves the node's `.node/` paths
  [scripts/bunker-crier-connect.sh:85] — a different variable
  from the control host's `HOME` on line 100.

| Setting | Default | Effect if absent |
|---|---|---|
| `--agent` | none [scripts/bunker-crier-connect.sh:23] | `FAIL  agent — AGENT unset` and exit 1 in `--check` [scripts/bunker-crier-connect.sh:36]; `stage`/`apply` build the identity from the empty string anyway [scripts/bunker-crier-connect.sh:112-114] |
| `--server` | none [scripts/bunker-crier-connect.sh:23] | `--server is required (the agent's bunker host)`, exit 2, before any mode runs [scripts/bunker-crier-connect.sh:156] |
| `--url` (alias `--crier-url`) | none [scripts/bunker-crier-connect.sh:158] | `FAIL  url — URL unset` and exit 1 [scripts/bunker-crier-connect.sh:37]; the signed probe is also skipped without it [scripts/bunker-crier-connect.sh:60-67] |
| `--project` | `$AGENT` at write time, `${PROJECT:-$AGENT}` [scripts/bunker-crier-connect.sh:159] [scripts/bunker-crier-connect.sh:125] | the identity carries the agent name as the project |
| `--timeout` | `10` seconds [scripts/bunker-crier-connect.sh:23] [scripts/bunker-crier-connect.sh:160] | applies to both `curl` calls as `-m` [scripts/bunker-crier-connect.sh:29] [scripts/bunker-crier-connect.sh:40]; the node-side `bunker exec` has its own hard-coded 45 s [scripts/bunker-crier-connect.sh:85] |
| `--check` / `--apply` / `--stage` | none [scripts/bunker-crier-connect.sh:161] | usage text, exit 2 [scripts/bunker-crier-connect.sh:167] |
| `-h` / `--help` | — | prints usage and exits 0 [scripts/bunker-crier-connect.sh:162] [scripts/bunker-crier-connect.sh:25] |
| file mode of the identity | `600`, applied by a remote `chmod` after the copy [scripts/bunker-crier-connect.sh:127] [scripts/bunker-crier-connect.sh:144] | a `chmod` failure fails the whole write because it is chained with `&&` [scripts/bunker-crier-connect.sh:126-127] |
| `HOME` (control host) | inherited from the invoking shell; never assigned by the script [scripts/bunker-crier-connect.sh:112] | read only in the `UNVERIFIED` remedy text, unescaped, so it prints the control host's home directory [scripts/bunker-crier-connect.sh:112]. **Unset, `set -u` [scripts/bunker-crier-connect.sh:19] aborts there**: after the first `CRIER: UNVERIFIED …` line and before either remedy line, bash prints `line 112: HOME: unbound variable` and the run exits **1** instead of 3 — the operator loses both remedy lines and the exit code that means "unverified" (measured, §8 probe C). The `CONNECTED` [scripts/bunker-crier-connect.sh:104] and `NOT CONNECTED` [scripts/bunker-crier-connect.sh:95] verdicts never expand it, so a signed success is unaffected (measured: exit 0) |
| `PATH` | inherited; the script writes no default | the only lookup path for `bunker` (`command -v` gate [scripts/bunker-crier-connect.sh:51], `have bunker` [scripts/bunker-crier-connect.sh:84] [scripts/bunker-crier-connect.sh:109]) and for `curl`, `timeout`, `python3`, `mktemp`, `chmod`, `date`, `sed` [scripts/bunker-crier-connect.sh:29] [scripts/bunker-crier-connect.sh:52] [scripts/bunker-crier-connect.sh:111] [scripts/bunker-crier-connect.sh:113]. With no `bunker` on `PATH`, `--check` skips the signed probe [scripts/bunker-crier-connect.sh:51] and names the client: `have()` exits non-zero on absence [scripts/lib.sh:41-45], so the identity step prints `FAIL  identity — no bunker client on PATH — $HOME/.node/crier.json cannot be read from the node` [scripts/bunker-crier-connect.sh:86-98] and the run still reaches its `CRIER: NOT CONNECTED (n)` verdict, exit 1 (before CF-281 the absence surfaced as `FAIL  identity — $HOME/.node/crier.json absent — run --apply`, with no client named). `--apply`/`--stage` name it too (`FAIL  bunker_cli — no bunker client on PATH`), exit 1 [scripts/bunker-crier-connect.sh:120] [scripts/bunker-crier-connect.sh:137]. No `curl` collapses both HTTP codes to `000` [scripts/bunker-crier-connect.sh:29-31]; no `timeout` silently forces the unsigned fallback [scripts/bunker-crier-connect.sh:52-55] (measured, §8 probe C) |
| `FAILED` | `0`, from the library's `${FAILED:-0}` [scripts/lib.sh:11] | the default applies only when the variable is unset or empty, so an exported `FAILED=1` is kept and both verdict tests compare against it [scripts/bunker-crier-connect.sh:74] [scripts/bunker-crier-connect.sh:116]: an all-PASS signed run then prints `CRIER: NOT CONNECTED (1)` and exits 1 (measured, §8 probe C) |

## 8. Evidence of record

The current evidence boundary is explicit: behavior for CF-214 was re-derived from the shipped
script and the real selftest fixture. The named `probe-04-crier-connect.sh` is not tracked in this
repository, so no standalone probe run, transcript, or measurement date is claimed here. The
remaining B/C material below is retained only where it is clearly marked as historical evidence and
is not used to certify the current CF-214 verdict ladder.

**A. Verdict ladder (not re-run here).** The named `probe-04-crier-connect.sh` is not tracked in
this repository. Its prior pasted fixture and transcripts were removed rather than updated from
memory. The current verdict ladder is covered by the real CF-214 selftest fixture in `tests/selftest.sh`
section 40: its curl stub answers the host route with a configured code, and the fixture bunker can
emit a node-side signed row. The source-derived outcomes are:

- host inbox `200`: `PASS  inbox`, then `CRIER: CONNECTED` exit 0;
- host inbox `401`: `FAIL  inbox` naming `authentication or agent signature refused`;
- host inbox `403`, `404`, and `000`: distinct `FAIL  inbox` rows;
- node-side signed success, when the optional probe runs: `PASS  signed_read`; it is not implied by
  the host `200`.

Section 40 also runs the provisioner with the fixture's host `200` and no bunker client, requiring a
WARN that says the host route answered 200 unsigned and that the signed read was not measured. It
then enables the fixture's signed row and requires the provisioner to quote that `PASS  signed_read`
row. Finally it runs a scratch copy containing the old `PASS  inbox` certification and requires that
arm to fail. These are current fixture results, not an invented standalone probe transcript.

**A2. Existing health-row finding.** The source still prints `bus not answering` for every non-200
health code [scripts/bunker-crier-connect.sh:39-44]. This is documented as a known diagnostic defect;
no new transcript is claimed here.


**B. The idempotence claim (historical evidence only).** The older probe is not tracked in this
repository and is not reproduced here. The source still claims rewrite-on-difference at
`scripts/bunker-crier-connect.sh:17`, while `apply()` unconditionally copies the identity file at
`scripts/bunker-crier-connect.sh:135-149`; this remains a documented defect, not a current probe
transcript.

<!-- Historical probe body omitted: the named probe is not a tracked repository artifact. -->


**C. Environment reads (historical evidence only).** The earlier environment probe is not
tracked in this repository and its output is not reproduced here. The source-derived contracts are:
`PATH` without `bunker` names the missing client in the identity row [scripts/bunker-crier-connect.sh:94-96],
unset `HOME` affects only the unsigned-fallback remedy text [scripts/bunker-crier-connect.sh:110-114],
and inherited `FAILED` can veto a success before the final return [scripts/bunker-crier-connect.sh:74-78].
No measurement date or transcript is claimed.


**D. What a reviewer re-runs.** Run `bash -n scripts/bunker-crier-connect.sh` and the CF-214
section 40 selftest. A real node may add `bunker-crier-connect.sh --agent <a> --server <host>
--url <bus> --check`; `CONNECTED` then means the host inbox route returned 200. A node-side
`PASS  signed_read` row is optional evidence that the node key was exercised, and must not be
inferred from the host row [scripts/bunker-crier-connect.sh:60-72] [scripts/bunker-crier-connect.sh:98-116].

**E. Current documentation alignment.** `docs/OPERATIONS.md:48` now describes the 401 `FAIL` row,
the unsigned-200 `CONNECTED` verdict, distinct 403/404/000 failures, and optional `signed_read`
evidence. The old standalone probe is not tracked, so this unit does not claim a run or paste a
transcript for it.
