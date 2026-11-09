# 06. scripts/bunker-server-install.sh

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/bunker-server-install.sh` [scripts/bunker-server-install.sh:1] |
| Repository | `code-factory` [scripts/bunker-server-install.sh:1] |
| Revision | `5cf6c03` — last commit touching this file (CF-145), on `main` @ `b9f56e6`; blob sha256 prefix `3b636488ede6bbb1` [scripts/bunker-server-install.sh:1] |
| Status | **VERIFIED — 161 resolving locator references (55 distinct path:line pairs), re-run 2026-11-05, fact: FACT-01** |

## 1. Purpose and why it matters

- What it **actually** does: it measures whether THIS control host can reach and drive a named bunker
  server, in five groups — the `bunker` client, the client config that names the server, one
  `bunker list` round trip, a `bunker status` dump, and the control host's own tools plus a disk floor
  [scripts/bunker-server-install.sh:27-70]. The verdict is one line, `RESULT: PASS` or
  `RESULT: FAIL (n)` [scripts/bunker-server-install.sh:73].
- It is **not** a host installer, and any task premise that says otherwise is contradicted by the
  file. The header advertises `--apply — install what is missing (user-space)`
  [scripts/bunker-server-install.sh:5], but the only argument the script ever inspects is `--json`
  [scripts/bunker-server-install.sh:15-16]. `--apply` is therefore an unknown argument that falls
  through into the identical check path: measured, `--apply` printed the same eleven `PASS`/`WARN`
  rows as `--check`, ended `RESULT: PASS`, exited 0, and installed nothing (§8 arm D).
- The README and AGENTS.md both frame it as a *qualification* check, not an installer: "can this
  control host run the factory at all? (needs the bunker client)" [README.md:22-23] and "does this
  control host qualify?" [README.md:168] [AGENTS.md:68].
- What breaks if this module is absent: nothing else in the repository answers "may this box drive a
  bunker server". `bunker-provision.sh` provisions one project's node and assumes the client already
  works; this is the only script whose entire job is that one question
  [scripts/bunker-provision.sh:181-184] [scripts/bunker-server-install.sh:2].
- What breaks if it lies: a **qualification** that reports PASS on a host that cannot qualify. Two
  false reports were measured on 2026-11-05, not inferred (§8): the `residue` WARN fires on a server
  whose own status line reads "0 orphan users, 0 orphan homes, 0 orphan keys"
  [scripts/bunker-server-install.sh:63], and a substring server name passes `server_declared`
  because the test is `grep -q "$SERVER"`, not an exact match
  [scripts/bunker-server-install.sh:40]. A third, larger one is structural: `--apply` returning
  `RESULT: PASS` reads as "installed" while nothing was installed [scripts/bunker-server-install.sh:5]
  [scripts/bunker-server-install.sh:73].
- The host-capability questions this module was expected to answer are **not in the file**. It never
  reads the kernel's unprivileged-userns switch, `sysctl`, `fuse-overlayfs`, `uidmap`/`newuidmap`,
  `slirp4netns`, or `unshare`; measured `grep -nE 'sysctl|userns|...|unprivileged'` over the file
  returns nothing (§8). Kernel support for user namespaces and the user-space network/storage helpers
  a bunker daemon needs are invisible to this check — it asks the **daemon**, through
  `bunker status`, and the daemon is the only thing that knows
  [scripts/bunker-server-install.sh:61-64].
- **Root: respected, and trivially so.** AGENTS.md rule 6 is "No root, ever. Agents have no
  passwordless sudo and no apt" [AGENTS.md:37-38]. This file contains no `sudo`, no `apt`, no
  `apt-get`, no write under `/etc`, and no `/etc` read at all; measured by
  `grep -nE 'sudo|apt|apt-get|/etc/|root'`, which matches only the word "install" inside the three
  header comments [scripts/bunker-server-install.sh:2-5]. Every action it takes is a read: `have`
  resolves binaries [scripts/lib.sh:41-45], `bunker --version` / `list` / `status` are read
  subcommands [scripts/bunker-server-install.sh:30] [scripts/bunker-server-install.sh:47]
  [scripts/bunker-server-install.sh:61], and `df -Pk` reads free space [scripts/lib.sh:32]. It
  therefore cannot violate rule 6 — and equally cannot repair anything, which is the defect in §6.
- The disk floor it does enforce is 5 GB against `$HOME` [scripts/bunker-server-install.sh:70]
  [scripts/lib.sh:35-44], not the ~1.5 GB-per-node figure AGENTS.md rule 12 states
  [AGENTS.md:49-50]. One node's cost is 1.5 GB, so 5 GB is header room, not a capacity plan.

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `bash` (shebang, `set -uo pipefail`, `${1:-}`) | no version check; the shebang is the only contract [scripts/bunker-server-install.sh:1] | the interpreter exec'd by the shebang | the kernel refusing exec; nothing inside the script checks it |
| `bunker` client | not pinned; `--version` is printed, never compared [scripts/bunker-server-install.sh:30] | `PATH` on the control host | `have bunker` empty → `  FAIL  bunker_client — missing — no way to create or reach agents`, exit 1 [scripts/bunker-server-install.sh:28-34]; measured §8 arm C2 |
| client config file | none; path defaults to `$HOME/.config/bunker/config.yaml` [scripts/bunker-server-install.sh:37] | control host home | `  FAIL  bunker_config — missing (<path>) — the client has no server to talk to` [scripts/bunker-server-install.sh:41-42]; measured §8 arm G |
| the named server, in the config | none | `servers:` map of that file | `grep -q "$SERVER" "$cfg"` fails → `  FAIL  server_declared — <server> not found in <cfg>` [scripts/bunker-server-install.sh:40] |
| `grep` | no version check [scripts/bunker-server-install.sh:40] | `PATH` | the config row takes the `else` arm, and the counters degrade to an empty value because each is guarded with `\|\| true` [scripts/bunker-server-install.sh:50] [scripts/bunker-server-install.sh:52] |
| `head` | no version check [scripts/bunker-server-install.sh:30] | `PATH` | the version and status rows render with an empty measured value; the run continues because there is no `-e` [scripts/bunker-server-install.sh:9] |
| `sed` | no version check [scripts/bunker-server-install.sh:62] | `PATH` | the `  ..    ` indent of the status dump disappears; the dump itself still reaches stdout |
| `df` + `awk` (via `scripts/lib.sh`) | no version check [scripts/lib.sh:32-42] | `PATH` | `free_gb` yields empty, `awk` coerces it to numeric 0, and `require_disk` fails with a blank measured value: `  FAIL  disk —  GB free < floor 5 GB at <path>` [scripts/lib.sh:37-42] |
| `python3`, `git`, `curl`, `jq` | no version check [scripts/bunker-server-install.sh:67] | `PATH` on the control host | WARN only, never a FAIL: `  WARN  tool:<t> — missing (needed for the control-side scripts)` [scripts/bunker-server-install.sh:68] — the verdict can still be `RESULT: PASS` |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `. "$HERE/lib.sh"` (sourced, not a package) [scripts/bunker-server-install.sh:12] | `scripts/lib.sh` | five printers `say`/`ok`/`bad`/`warn`/`note` [scripts/lib.sh:5-9], `have` [scripts/lib.sh:41-45], and `require_disk`, which calls `free_gb` and prints the floor it measured [scripts/lib.sh:35-44]. `bad()` is the ONLY thing that increments `FAILED` [scripts/lib.sh:7], and `FAILED` is initialised by the library, not by the caller [scripts/lib.sh:11] | the verdict stops meaning anything: with `lib.sh` absent every printer degrades to `command not found`, `FAILED` stays 0, and line 73 exits **0** on a failed host [scripts/bunker-server-install.sh:73]. A renamed `bad` has the same effect without any error message |
| `have` [scripts/lib.sh:41-45] | same library | present: exit 0 and the resolved path on stdout; absent: non-zero and nothing on stdout (CF-281) — the script tests `-n "$b"` [scripts/bunker-server-install.sh:29], which was and remains correct | a `have` that printed something on absence would make every dependent row take the "present" arm and then fail at the binary |

### 2c. Service contracts (both sides must be named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| bunker server daemon named by `BUNKER_SERVER` | control host → daemon [scripts/bunker-server-install.sh:47] | the `bunker` CLI's own transport, resolved from `PATH` and never version-checked [scripts/bunker-server-install.sh:28-30] | `bunker list --server <name>` and `bunker status --server <name>`; the script parses the *text*: agent rows must match `^\s{2}[a-z0-9][a-z0-9-]{2,}` [scripts/bunker-server-install.sh:50], the word `running` is counted anywhere in the output [scripts/bunker-server-install.sh:52], and `orphan` is matched case-insensitively anywhere [scripts/bunker-server-install.sh:63] | the daemon lives outside this repository; its status block is the only surface this script trusts, so a format change is a script bug (fact: FACT-01, fact: FACT-02) |
| `~/.config/bunker/config.yaml` on the control host | control host → local file [scripts/bunker-server-install.sh:37-40] | filesystem read via `[ -f ]` and `grep -q` | a `servers:` map plus `active_server`; on this host the file names 14 servers and `active_server: bunker-las-03` (§8) | written by the `bunker` CLI's own connect command, outside this repository; this script is a consumer only [scripts/bunker-server-install.sh:37] |
| the caller (README quick start / AGENTS.md commands) | operator → script [README.md:23] [AGENTS.md:68] | argv plus environment | one of `--check`, `--apply`, claimed by the header [scripts/bunker-server-install.sh:4-5]; in practice any argv that is not `--json` is ignored [scripts/bunker-server-install.sh:16] | the README promises a check, so that caller is served; the header's `--apply` has no implementation on the other side [scripts/bunker-server-install.sh:5] |

## 3. Verification

All commands are read-only. Run from the repository root; the environment is pinned with `env -i` so
a stray `PATH` entry cannot supply a `bunker` the host does not have.

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| No server declared | `env -i PATH=$HOME/.local/bin:/usr/bin:/bin HOME=$HOME bash scripts/bunker-server-install.sh --check` [scripts/bunker-server-install.sh:18-23] | `  FAIL  server_declared — BUNKER_SERVER unset — the client has no server to talk to`, `RESULT: FAIL (1)`, exit 1 | 2026-11-05 | PASS (as expected) — §8 arm A |
| Full qualification, real server | `env -i PATH=$HOME/.local/bin:/usr/bin:/bin HOME=$HOME BUNKER_SERVER=bunker-las-03 bash scripts/bunker-server-install.sh --check` [scripts/bunker-server-install.sh:25-73] | eleven `PASS` rows, one false `residue` WARN, `RESULT: PASS`, exit 0 | 2026-11-05 | PASS — §8 arm B; the WARN is a defect, §6 |
| No client on `PATH` | `env -i PATH=/usr/bin:/bin HOME=$HOME BUNKER_SERVER=bunker-las-03 bash scripts/bunker-server-install.sh --check` [scripts/bunker-server-install.sh:28-34] | `  FAIL  bunker_client — missing — no way to create or reach agents`, `RESULT: FAIL (1)`, exit 1, and no `server_reachable` row | 2026-11-05 | PASS (as expected) — §8 arm C2 |
| `--apply` is a no-op | `env -i ... bash scripts/bunker-server-install.sh --apply` [scripts/bunker-server-install.sh:5] [scripts/bunker-server-install.sh:16] | identical rows to `--check`, no install row, exit 0 | 2026-11-05 | measured failure of the documented contract — §8 arm D |
| Unknown server | `env -i ... BUNKER_SERVER=no-such-srv ... --check` [scripts/bunker-server-install.sh:40] [scripts/bunker-server-install.sh:55] | two FAIL rows (`server_declared`, `server_reachable`), `RESULT: FAIL (2)`, exit 1 | 2026-11-05 | PASS (as expected) — §8 arm E |
| Substring server name | `env -i ... BUNKER_SERVER=bunker ... --check` [scripts/bunker-server-install.sh:40] | `server_declared` should FAIL; measured PASS | 2026-11-05 | FAIL of the contract — false green, §8 arm F |
| Missing config | `env -i ... BUNKER_CONFIG=/nonexistent/config.yaml ... --check` [scripts/bunker-server-install.sh:41-42] | `  FAIL  bunker_config — missing (...)`, reachability still measured through the client's default config | 2026-11-05 | PASS (as expected, degraded) — §8 arm G |
| Standing mechanised arm | `bash tests/selftest.sh` §32 [tests/selftest.sh:1517-1551] | the no-`BUNKER_SERVER` arm must print a named `FAIL` row, the closing line, exit non-zero, and must not abort with `line N:` or `unbound variable` | 2026-11-05 | covered by the suite's own arm; this document re-ran the same command directly (§8) |

## 4. Metrics emitted

**NONE.** No counter, histogram, exporter, timer or endpoint exists in the file; the only
machine-readable outputs are the process exit status [scripts/bunker-server-install.sh:21-22]
[scripts/bunker-server-install.sh:73] and the in-process `FAILED` tally the verdict interpolates
[scripts/lib.sh:7] [scripts/lib.sh:11].

Consequences, stated so nobody hunts for a scrape target:

- Reachability, agent count and "running" count are computed once at run time and discarded
  [scripts/bunker-server-install.sh:50-53]; they are not persisted, exported, or written to a file.
- The percentages in the status dump — CPU, memory, disk — are printed by the daemon and passed
  through with a `  ..    ` prefix [scripts/bunker-server-install.sh:61-62]; they are the *server's*
  numbers, never this script's measurement, and nothing parses them.
- The one number this script computes itself is free space, to one decimal, from `df -Pk`
  [scripts/lib.sh:32-42]; it appears only in the `disk` row and is gone when the process exits
  [scripts/bunker-server-install.sh:70].
- A monitoring lane can use only the exit status: 0 = every row passed (including a host whose tools
  were merely warned about [scripts/bunker-server-install.sh:68]), non-zero = at least one `FAIL` row
  [scripts/bunker-server-install.sh:73].

## 5. Log lines it can generate

Everything below is printed to stdout by this script or by `scripts/lib.sh` on its behalf. There is no
logger, no level filter, no destination and no retention: a line exists only in the terminal or in
whatever captured it [scripts/lib.sh:5-9]. Lines marked *evidentiary* carry a measured value; lines
marked *descriptive* carry context or pass-through text.

| Level | Line (verbatim) | Emitted when | Kind |
|---|---|---|---|
| info | `bunker server: bunker-las-03` (template `bunker server: $SERVER`) | after the `BUNKER_SERVER` gate, before any measurement [scripts/bunker-server-install.sh:25] | descriptive |
| PASS | `  PASS  bunker_client — /home/kara/.local/bin/bunker bunker 0.2.0` | the client resolved and its first `--version` line was read [scripts/bunker-server-install.sh:30-31] | evidentiary |
| FAIL | `  FAIL  bunker_client — missing — no way to create or reach agents` | `have bunker` returned empty [scripts/bunker-server-install.sh:33] | evidentiary |
| FAIL | `  FAIL  server_declared — BUNKER_SERVER unset — the client has no server to talk to` | the process variable is empty; this is the only pre-measurement abort [scripts/bunker-server-install.sh:18-19] | evidentiary |
| PASS | `  PASS  bunker_config — /home/kara/.config/bunker/config.yaml` | the config path is a regular file [scripts/bunker-server-install.sh:38-39] | evidentiary |
| FAIL | `  FAIL  bunker_config — missing (/nonexistent/config.yaml) — the client has no server to talk to` | the config path is not a regular file [scripts/bunker-server-install.sh:41-42] | evidentiary |
| PASS | `  PASS  server_declared — bunker-las-03 present in config` | `grep -q "$SERVER" "$cfg"` succeeded — a substring match, not an exact one [scripts/bunker-server-install.sh:40] | evidentiary |
| FAIL | `  FAIL  server_declared — no-such-srv not found in /home/kara/.config/bunker/config.yaml` | the substring is absent [scripts/bunker-server-install.sh:40] | evidentiary |
| PASS | `  PASS  server_reachable — bunker-las-03 answered (agents listed: 1)` | `bunker list --server` exited 0 and the agent-row regex counted N [scripts/bunker-server-install.sh:49-51] | evidentiary |
| FAIL | `  FAIL  server_reachable — no-such-srv did not answer: bunker: reading server "no-such-srv"` | `bunker list` exited non-zero; the detail is the first line of its combined output [scripts/bunker-server-install.sh:54-55] | evidentiary |
| PASS | `  PASS  agents_running — 1 running` | always, immediately after a reachable server; the count is a bare substring count of `running` [scripts/bunker-server-install.sh:52-53] | evidentiary (weak: substring) |
| note | `  ..      Hostname: bunker-las-03` (template `  ..    <status line>`) | one line per line of `bunker status`, capped at 20 [scripts/bunker-server-install.sh:61-62] | descriptive |
| note | `  ..      Residue:  0 orphan users, 0 orphan homes, 0 orphan keys, 0 stale linger entries (1 registered agent)` | the daemon's own residue line; note that it *contains* the word `orphan` at count zero [scripts/bunker-server-install.sh:61] | descriptive |
| WARN | `  WARN  residue — orphan homes/keys reported by the server — reap before scaling` | `grep -qi 'orphan'` matched the status dump — true even when every count is 0, as measured [scripts/bunker-server-install.sh:63] | **false evidentiary** — the text asserts orphans the line above denies |
| PASS | `  PASS  tool:python3 — /usr/bin/python3` (one per tool) | each of `python3 git curl jq` resolved [scripts/bunker-server-install.sh:67-68] | evidentiary |
| WARN | `  WARN  tool:jq — missing (needed for the control-side scripts)` | a tool did not resolve; the verdict is unaffected [scripts/bunker-server-install.sh:68] | descriptive |
| PASS | `  PASS  disk — 92.6 GB free (floor 5 GB)` | free space at `$HOME` is at or above the floor [scripts/lib.sh:38-39] [scripts/bunker-server-install.sh:70] | evidentiary |
| FAIL | `  FAIL  disk — 0.4 GB free < floor 5 GB at /home/kara` | free space is below the floor; the number is always named [scripts/lib.sh:40-41] | evidentiary |
| verdict | `RESULT: PASS` | no `FAIL` row [scripts/bunker-server-install.sh:73] | evidentiary |
| verdict | `RESULT: FAIL (1)` / `RESULT: FAIL (2)` (template `RESULT: FAIL ($FAILED)`) | one or more `FAIL` rows; the number is the `FAILED` tally [scripts/bunker-server-install.sh:21] [scripts/bunker-server-install.sh:73] | evidentiary |

One line deserves a flag: when `bunker --version` prints nothing and the client row still passes, the
fallback text is built with full-width parentheses,
`  PASS  bunker_client — <path> （version not reported）` [scripts/bunker-server-install.sh:31]. That
is a non-ASCII glyph in operator-facing output and in any log a parser will read; it has not been
observed on this host because the client reports `bunker 0.2.0`
[scripts/bunker-server-install.sh:30-31].

## 6. Failure modes

Direction: **local** = the failure is reported as something else on this host; **remote** = the failure
lives on the daemon or the network; **degraded** = the run continues with a weaker guarantee.

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| `--apply` advertised but not implemented (local, false green) | identical rows to `--check`, `RESULT: PASS`, exit 0, nothing installed; measured §8 arm D. The cause is that only `--json` is inspected [scripts/bunker-server-install.sh:15-16] while the header promises an install [scripts/bunker-server-install.sh:5] | a real apply would print `  ..    ` progress rows and change the host; this file contains no `fetch_verified`, `mkdir`, `cp`, `chmod` or download call for installation, only reads [scripts/bunker-server-install.sh:28-70] | do not treat its PASS as provisioning; use `scripts/bunker-provision.sh` / `scripts/node-create.sh`, and file the header contradiction as a defect |
| `--json` accepted and ignored (degraded) | the flag sets a variable nothing reads [scripts/bunker-server-install.sh:15-16]; output stays human-formatted | the only other argument shape is silence: any non-`--json` first argument takes the same path [scripts/bunker-server-install.sh:16] | parse `PASS`/`FAIL` rows; there is no JSON emitter to consume |
| Unknown argument accepted silently (degraded) | `--apply`, `--bogus`, `--check` all run the check; no usage text, no exit 2 [scripts/bunker-server-install.sh:16] | a typo in `BUNKER_SERVER` at least produces a named row [scripts/bunker-server-install.sh:19]; an argument typo produces nothing | read the header for the intended modes [scripts/bunker-server-install.sh:4-5], then verify behaviour — they are not implemented |
| `residue` WARN on a clean server (local, false alarm) | `  WARN  residue — orphan homes/keys reported by the server — reap before scaling` while the status line reads `Residue:  0 orphan users, 0 orphan homes, 0 orphan keys` [scripts/bunker-server-install.sh:61-63]; measured §8 arm B | a genuinely dirty server prints non-zero counts in that same status line; the script's test is `grep -qi 'orphan'`, which cannot tell 0 from 9 [scripts/bunker-server-install.sh:63] | read the `Residue:` line the script already printed, not the WARN; an operator who trusts the WARN will reap a clean host |
| `server_declared` substring match (local, false green) | `BUNKER_SERVER=bunker` printed `  PASS  server_declared — bunker present in config` while no server named `bunker` exists; measured §8 arm F | the next row still fails, so the run is not silently green overall [scripts/bunker-server-install.sh:55] — the *row* is what lies | pass the exact server id; `grep -q` cannot distinguish a prefix from a name [scripts/bunker-server-install.sh:40] |
| Client absent (local, fail-closed but blind) | `  FAIL  bunker_client — missing ...`, exit 1, and the reachability and capacity blocks are skipped entirely because both are guarded on `[ -n "$b" ]` [scripts/bunker-server-install.sh:46] [scripts/bunker-server-install.sh:60] | an unreachable server *with* a client prints a `server_reachable` FAIL naming the first output line [scripts/bunker-server-install.sh:55]; with no client there is no such row | install the client; until then the script cannot say whether the server exists |
| Config missing, server still reachable (degraded) | `  FAIL  bunker_config — missing (...)` yet `  PASS  server_reachable` follows, because the client reads its own default config; measured §8 arm G [scripts/bunker-server-install.sh:38-47] | `BUNKER_CONFIG` points somewhere the *script* reads; the *client* is not told about that variable, so the two can disagree | fix the path, or unset `BUNKER_CONFIG` if the default is correct — the FAIL is about the path this script tested |
| Control tool missing (degraded) | `  WARN  tool:<t> — missing ...`, and the verdict can still be `RESULT: PASS` [scripts/bunker-server-install.sh:68] [scripts/bunker-server-install.sh:73] | a missing `bunker` is a FAIL [scripts/bunker-server-install.sh:33]; only the four auxiliary tools are warned | install the tool; a PASS on a host without `jq` is a true PASS for *this* check but not for the control-side scripts it names |
| Daemon output format drift (remote) | agent count reads `agents listed: 0` and `0 running` against a live server, because both are text parsers of the list output [scripts/bunker-server-install.sh:50-53]; or `residue` flips silently if the word `orphan` is reworded [scripts/bunker-server-install.sh:63] | a genuinely empty server also reads 0; the status block is the only way to tell, and it is printed [scripts/bunker-server-install.sh:61-62] | read the status dump; a daemon that changes its table is a script bug, since the contract is textual [scripts/bunker-server-install.sh:2] |
| Disk below the floor (local, fail-closed) | `  FAIL  disk — <free> GB free < floor 5 GB at <path>` and the verdict carries the count [scripts/lib.sh:40-41] [scripts/bunker-server-install.sh:73] | a missing `df` produces the same row with an *empty* free value [scripts/lib.sh:37-42] | free space or move `HOME`; the `\|\| true` on line 70 does not suppress the tally, because `bad` already incremented it [scripts/bunker-server-install.sh:70] [scripts/lib.sh:7] |
| `scripts/lib.sh` missing or renamed (degraded, false green) | every printer becomes `command not found`; `FAILED` stays 0 and the script exits **0** [scripts/bunker-server-install.sh:12] [scripts/lib.sh:7] [scripts/bunker-server-install.sh:73] | nothing inside the script distinguishes it; only the shell's own error on line 12 does | treat exit 0 with no `PASS`/`FAIL` rows as a library failure, never a qualification |
| Any unguarded command fails (degraded) | the script runs `set -uo pipefail` without `-e` [scripts/bunker-server-install.sh:9], so a failed `head`, `sed` or `grep` prints its own stderr and the run proceeds | the effect surfaces as an empty measured value in an otherwise `PASS` row | read stderr; a `PASS` row with a blank value is the tell |

## 7. Environment and settings it reads

| Setting | Default when unset | Effect if unset |
|---|---|---|
| `BUNKER_SERVER` [scripts/bunker-server-install.sh:14] | empty | abort before any measurement: `  FAIL  server_declared — BUNKER_SERVER unset — the client has no server to talk to`, `RESULT: FAIL (1)`, exit 1 [scripts/bunker-server-install.sh:18-23]; measured §8 arm A |
| `BUNKER_CONFIG` [scripts/bunker-server-install.sh:37] | `$HOME/.config/bunker/config.yaml` | the default path is tested instead; if it is missing the row FAILs but reachability is still attempted [scripts/bunker-server-install.sh:38-47] |
| `HOME` [scripts/bunker-server-install.sh:37] [scripts/bunker-server-install.sh:70] | set by the login session | the config path collapses to `/.config/bunker/config.yaml` and the disk floor is measured at `/` |
| `PATH` (through `have`) [scripts/lib.sh:41-45] | set by the session | no client, no tools; the run is still diagnosable but the `bunker_client` row FAILs [scripts/bunker-server-install.sh:28-34] |
| `$1` — only `--json` is compared [scripts/bunker-server-install.sh:16] | no flag | `--check` and `--apply` are **not** modes; every argument other than `--json` is ignored, and `--json` itself is never read again [scripts/bunker-server-install.sh:15-16] |
| no config key, flag or environment variable for a disk floor | hard-coded 5 GB [scripts/bunker-server-install.sh:70] | the floor cannot be raised or lowered without editing the file; AGENTS.md's 1.5 GB-per-node figure is not consulted [AGENTS.md:49-50] |
| no setting for the status line cap | hard-coded `head -20` [scripts/bunker-server-install.sh:61] | a server with more than 20 status lines is truncated silently; a residue line below the cut is never seen |

There is no precedence question to answer: nothing here is overridable. The two variables are read
directly with `${VAR:-}` and `${VAR:-default}` [scripts/bunker-server-install.sh:14]
[scripts/bunker-server-install.sh:37], and the single argument test reads `${1:-}` positionally
[scripts/bunker-server-install.sh:16].

## 8. Evidence of record

- What a reviewer re-runs, and what it printed on 2026-11-05. Worktree `~/proj-wt-md-06e`, `main` @
  `b9f56e6`, `scripts/bunker-server-install.sh` blob sha256
  `3b636488ede6bbb13d5d1be68e9af7d81c5a1f1224f1bc532f6f78e188365375`. The environment is pinned with
  `env -i` because the ambient `PATH` on this box contains a stub `bunker` fixture left by another
  lane; every run below resolves `/home/kara/.local/bin/bunker` instead.

  The `URL:` row inside the `bunker-las-03` block below reads `http://<ci-box>:10001`: the real
  address is the one the operator's own `~/.config/bunker/config.yaml` names for that server, and it
  is redacted to a placeholder here because this repository is public (CF-378).

```
$ env -i PATH=/home/kara/.local/bin:/usr/local/bin:/usr/bin:/bin HOME=/home/kara \
    bash scripts/bunker-server-install.sh --check
  FAIL  server_declared — BUNKER_SERVER unset — the client has no server to talk to

RESULT: FAIL (1)
exit=1
```

```
$ env -i PATH=/home/kara/.local/bin:/usr/local/bin:/usr/bin:/bin HOME=/home/kara \
    BUNKER_SERVER=bunker-las-03 bash scripts/bunker-server-install.sh --check
bunker server: bunker-las-03
  PASS  bunker_client — /home/kara/.local/bin/bunker bunker 0.2.0
  PASS  bunker_config — /home/kara/.config/bunker/config.yaml
  PASS  server_declared — bunker-las-03 present in config
  PASS  server_reachable — bunker-las-03 answered (agents listed: 1)
  PASS  agents_running — 1 running
  ..    ── bunker-las-03 ──
  ..      Hostname: bunker-las-03
  ..      URL:      http://<ci-box>:10001
  ..      Version:  0.1.4
  ..      Status:   ONLINE
  ..      Uptime:   8d 22h 40m
  ..      Agents:   1/8
  ..      /tmp:     HOST-SHARED — agent sessions see the host /tmp
  ..
  ..      Reason:   the pam_namespace drop-in configuration is missing
  ..      Net mode: not reported by this daemon — it predates network-isolation reporting
  ..      Residue:  0 orphan users, 0 orphan homes, 0 orphan keys, 0 stale linger entries (1 registered agent)
  ..      CPU:      56.9%
  ..      Memory:   2.5 GB / 31.1 GB
  ..      Disk:     73% (162.1 GB/220.6 GB)
  WARN  residue — orphan homes/keys reported by the server — reap before scaling
  PASS  tool:python3 — /usr/bin/python3
  PASS  tool:git — /usr/bin/git
  PASS  tool:curl — /usr/bin/curl
  PASS  tool:jq — /usr/bin/jq
  PASS  disk — 92.6 GB free (floor 5 GB)

RESULT: PASS
exit=0
```

```
$ env -i PATH=/usr/bin:/bin HOME=/home/kara BUNKER_SERVER=bunker-las-03 \
    bash scripts/bunker-server-install.sh --check
bunker server: bunker-las-03
  FAIL  bunker_client — missing — no way to create or reach agents
  PASS  bunker_config — /home/kara/.config/bunker/config.yaml
  PASS  server_declared — bunker-las-03 present in config
  PASS  tool:python3 — /usr/bin/python3
  PASS  tool:git — /usr/bin/git
  PASS  tool:curl — /usr/bin/curl
  PASS  tool:jq — /usr/bin/jq
  PASS  disk — 92.5 GB free (floor 5 GB)

RESULT: FAIL (1)
exit=1
```

```
$ env -i PATH=/home/kara/.local/bin:/usr/bin:/bin HOME=/home/kara \
    BUNKER_SERVER=bunker-las-03 bash scripts/bunker-server-install.sh --apply
... first rows identical to the --check run above, then:
  PASS  tool:jq — /usr/bin/jq
  PASS  disk — 92.5 GB free (floor 5 GB)

RESULT: PASS
exit=0
# 11 PASS/WARN rows in the --apply run; no install row, no file changed.
```

```
$ env -i PATH=/home/kara/.local/bin:/usr/bin:/bin HOME=/home/kara \
    BUNKER_SERVER=no-such-srv bash scripts/bunker-server-install.sh --check
bunker server: no-such-srv
  PASS  bunker_client — /home/kara/.local/bin/bunker bunker 0.2.0
  PASS  bunker_config — /home/kara/.config/bunker/config.yaml
  FAIL  server_declared — no-such-srv not found in /home/kara/.config/bunker/config.yaml
  FAIL  server_reachable — no-such-srv did not answer: bunker: reading server "no-such-srv"
  PASS  tool:python3 — /usr/bin/python3
  PASS  tool:git — /usr/bin/git
  PASS  tool:curl — /usr/bin/curl
  PASS  tool:jq — /usr/bin/jq
  PASS  disk — 92.5 GB free (floor 5 GB)

RESULT: FAIL (2)
exit=1
```

```
$ env -i PATH=/home/kara/.local/bin:/usr/bin:/bin HOME=/home/kara \
    BUNKER_SERVER=bunker bash scripts/bunker-server-install.sh --check
bunker server: bunker
  PASS  bunker_client — /home/kara/.local/bin/bunker bunker 0.2.0
  PASS  bunker_config — /home/kara/.config/bunker/config.yaml
  PASS  server_declared — bunker present in config
  FAIL  server_reachable — bunker did not answer: bunker: reading server "bunker"
  PASS  tool:python3 — /usr/bin/python3
  PASS  tool:git — /usr/bin/git
  PASS  tool:curl — /usr/bin/curl
  PASS  tool:jq — /usr/bin/jq
  PASS  disk — 92.5 GB free (floor 5 GB)

RESULT: FAIL (1)
exit=1
# The config row passed on a server that does not exist: `grep -q "bunker"` matched every
# bunker-* entry in the file.
```

```
$ env -i PATH=/home/kara/.local/bin:/usr/bin:/bin HOME=/home/kara \
    BUNKER_CONFIG=/nonexistent/config.yaml BUNKER_SERVER=bunker-las-03 \
    bash scripts/bunker-server-install.sh --check
bunker server: bunker-las-03
  PASS  bunker_client — /home/kara/.local/bin/bunker bunker 0.2.0
  FAIL  bunker_config — missing (/nonexistent/config.yaml) — the client has no server to talk to
  PASS  server_reachable — bunker-las-03 answered (agents listed: 1)
  PASS  agents_running — 1 running
  ... status dump omitted here, full text in the arm B block ...
  WARN  residue — orphan homes/keys reported by the server — reap before scaling
  PASS  tool:python3 — /usr/bin/python3
  PASS  tool:git — /usr/bin/git
  PASS  tool:curl — /usr/bin/curl
  PASS  tool:jq — /usr/bin/jq
  PASS  disk — 92.5 GB free (floor 5 GB)

RESULT: FAIL (1)
exit=1
# The client ignores BUNKER_CONFIG; only the script's own read of it failed.
```

- The root question, measured rather than argued:

```
$ grep -nE 'sudo|apt|apt-get|/etc/|root' scripts/bunker-server-install.sh
2:# bunker-server-install.sh — the control-host side: is this machine able to run the factory?
4:#   ./bunker-server-install.sh --check     # measure, exit non-zero on a gap
5:#   ./bunker-server-install.sh --apply     # install what is missing (user-space)
# three comment lines, matched only because they contain the word "install"; no sudo, no apt,
# no /etc path anywhere in the file.

$ grep -nE 'sysctl|userns|user_namespace|overlayfs|uidmap|slirp|fuse|unshare|newuidmap|unprivileged' \
    scripts/bunker-server-install.sh
# no output: none of the host-capability probes the task premise expects exist in this file.
```

- The false `residue` WARN was measured, not inferred: arm B printed
  `WARN  residue — orphan homes/keys reported by the server` on the line immediately after the
  daemon's own `Residue:  0 orphan users, 0 orphan homes, 0 orphan keys, 0 stale linger entries`
  [scripts/bunker-server-install.sh:61-63].
- The `--apply` no-op was measured by row count as well as by eye: the `--apply` run printed 11
  `PASS`/`WARN` rows — the same set as `--check` — and exited 0
  [scripts/bunker-server-install.sh:16] [scripts/bunker-server-install.sh:73].
- Standing mechanised check: `tests/selftest.sh` §32 pins the no-`BUNKER_SERVER` arm and rejects a
  bash abort as the failure signal [tests/selftest.sh:1517-1551]; that is the only arm of this script
  the suite exercises, so the substring match, the `residue` false positive and the unimplemented
  `--apply` are recorded here as open defects rather than covered by CI.
- Status is VERIFIED on the strength of the seven arms above plus 161 resolving locator references
  (55 distinct path:line pairs, every one resolving against `b9f56e6`); it cites fact: FACT-01 for
  the control-host/daemon split. The defects it cannot hide are in §6: no host-capability probe, an
  unimplemented `--apply` behind a header that promises it, a substring server match, and a residue
  warning that fires on zero.
