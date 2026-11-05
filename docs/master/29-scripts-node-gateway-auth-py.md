# 29. scripts/node_gateway_auth.py

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/node_gateway_auth.py` |
| Repository | `code-factory` |
| Revision | `d8c7796` |
| Status | **VERIFIED — measured 2026-11-05 against scratch configs, plus a cross-check against the consumer gate** |

`VERIFIED` here means every claim below was measured and every locator was read at `d8c7796`. It does
not mean the module is correct: §6 records three measured defects in it.

## 1. Purpose and why it matters

- **What it does.** It guarantees that a node's `~/.hermes/config.yaml` carries a `dashboard.basic_auth`
  block. If the block is absent it generates a password on the node with `secrets.token_urlsafe(24)`
  (`scripts/node_gateway_auth.py:63`), writes it to a separate file at mode `600`
  (`scripts/node_gateway_auth.py:65-68`), and appends five lines to the config
  (`scripts/node_gateway_auth.py:72-78`). If the block is already there it changes nothing
  (`scripts/node_gateway_auth.py:51-55`). The password is never printed — stdout carries the fact and
  the paths only (`scripts/node_gateway_auth.py:10-11`); measured: 0 occurrences of the generated
  password in the script's own output (§3 arm 5). That is the credential-on-disk rule the ledger records
  — file paths at mode `600`, never argv values — and this module is one of the tree's implementations
  of it (fact: FACT-05).
- **Why it matters.** A Hermes gateway refuses to bind `0.0.0.0` without that block
  (`scripts/node_gateway_auth.py:4-6`), and the module's docstring states that no stage in the create
  path writes it — the condition board row CF-150 tracks (`.coding-hermes/board/tasks.jsonl:4`).
- **Who calls it: exactly one caller.** `scripts/bunker-provision.sh:487` runs it on the node as
  `python3 $HOME/node_gateway_auth.py $HOME/.hermes/config.yaml $HOME/.node/auth/gateway.pass $AGENT`,
  inside the step-5 block bounded by `scripts/bunker-provision.sh:480-497`. That block is gated on
  `HARNESS=hermes` (`scripts/bunker-provision.sh:481`), stages the script to the node first
  (`scripts/bunker-provision.sh:483`, `scripts/bunker-provision.sh:485`), records the outcome as the
  `gateway_auth` row (`scripts/bunker-provision.sh:490-491`), and deletes the staged copy afterwards
  (`scripts/bunker-provision.sh:495`). It runs **before** the node-plumbing step that invokes
  `node-create.sh` (`scripts/bunker-provision.sh:499-504`).
- **Who does not call it.** `scripts/node-create.sh` and `scripts/project-node.sh` contain zero
  occurrences of either `auth` or `config.yaml` (measured: `grep -n 'auth\|config.yaml'` exits 1 for
  both files). `node-create.sh` stages six files, none of them this script and none a config
  (`scripts/node-create.sh:23`). This is precisely CF-150: the standalone create path
  (`node-create.sh` → `project-node.sh --apply` at `scripts/node-create.sh:121`) never reaches the only
  writer of the block.
- **`install-hermes.sh` reads the block five times and never writes it.** The five occurrences are a
  comment (`scripts/harness/install-hermes.sh:11`), the parser's membership test, comment probe and
  value fetch (`scripts/harness/install-hermes.sh:202`, `:204`, `:206`), and the refusal message
  (`scripts/harness/install-hermes.sh:301`). The file contains no `mkdir` at all (measured:
  `grep -c mkdir` → 0), so nothing in the harness layer creates `~/.hermes` either.
- **It is the only writer in `scripts/`.** The other editor of the same file, `node_env.py`, owns a
  whitelist of five scalars (`scripts/node_env.py:61-67`) and `dashboard.basic_auth` is not among them;
  it reads that path at `scripts/node_env.py:501`. So the tree holds one producer of this block
  (`scripts/node_gateway_auth.py:72-78`) and one consumer of it
  (`scripts/harness/install-hermes.sh:202-210`).
- **What an unprotected node looks like.** `install-hermes.sh --apply` refuses at
  `scripts/harness/install-hermes.sh:301` with
  `FAIL  gateway_start — refused: a public bind needs dashboard.basic_auth in ~/.hermes/config.yaml`,
  and the run ends `HERMES: FAIL (4)` — measured on a fresh HOME and recorded verbatim in
  `docs/audits/cf-dogfood-2026-11-04-gateway-apply.txt:25`. `project-node.sh` folds every adapter
  `FAIL` row into its own counter (`scripts/project-node.sh:455`, `scripts/project-node.sh:458`), so the
  node ends `NODE: FAIL`; `node-create.sh` reports `bad  provision  node reported FAIL`
  (`scripts/node-create.sh:124`); and `verify-node.sh`'s `auth_gate` row can only fire on a gateway that
  came up at all (`scripts/verify-node.sh:61-65`). The gateway never binds, the round trip CF-004
  describes is unreachable, and the failure sits downstream of this module having been skipped.

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `python3` | 3.6 or newer — the source uses f-strings and PEP 526 annotations (`scripts/node_gateway_auth.py:22`, `scripts/node_gateway_auth.py:52`); measured under Python 3.14.4 | `PATH` of the node, invoked as `python3` by the caller (`scripts/bunker-provision.sh:487`) | the caller's exit status: `bunker-provision.sh` prints `bad  gateway_auth  could not ensure dashboard.basic_auth (exit $gw_rc)` (`scripts/bunker-provision.sh:491`) |
| `os` | stdlib (`scripts/node_gateway_auth.py:17`) | same interpreter | import error, exit 1, no row printed |
| `secrets` | stdlib (`scripts/node_gateway_auth.py:18`) | same interpreter | import error, exit 1, no row printed |
| `sys` | stdlib (`scripts/node_gateway_auth.py:19`) | same interpreter | import error, exit 1, no row printed |

No third-party dependency, no network import, no shell call: the module only opens local files
(`scripts/node_gateway_auth.py:16-95`).

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `os` | `os` at `scripts/node_gateway_auth.py:17` | `os.makedirs(dirname(password_file) or ".", exist_ok=True)` (`scripts/node_gateway_auth.py:64`); `os.open(password_file, O_WRONLY \| O_CREAT \| O_TRUNC, 0o600)` (`scripts/node_gateway_auth.py:65`); `os.fdopen(fd, "w")` (`scripts/node_gateway_auth.py:66`); `os.chmod(password_file, 0o600)` and `os.chmod(tmp, 0o600)` (`scripts/node_gateway_auth.py:68`, `scripts/node_gateway_auth.py:82`); `os.replace(tmp, config)` (`scripts/node_gateway_auth.py:83`) | the config write stops being atomic (`os.replace` is the only rename), or the secret lands wider than `600`. The `open` mode at line 65 is subject to umask; the unconditional `chmod` at line 68 is what makes the mode `600` in fact — measured 600 (§3 arm 1) |
| `secrets` | `secrets` at `scripts/node_gateway_auth.py:18` | `secrets.token_urlsafe(24)` returns URL-safe text from the OS CSPRNG (`scripts/node_gateway_auth.py:63`); 24 bytes → 32 characters — measured `chars=33` including the trailing newline (§3 arm 1) | a shorter or non-URL-safe value would still be written verbatim; the module never validates the password's shape or length |
| `sys` | `sys` at `scripts/node_gateway_auth.py:19` | `sys.stderr` (`scripts/node_gateway_auth.py:33`, `scripts/node_gateway_auth.py:45`, `scripts/node_gateway_auth.py:59`), `sys.argv[1:]` (`scripts/node_gateway_auth.py:95`), `sys.exit` (`scripts/node_gateway_auth.py:95`) | the caller's exit-code contract (`scripts/bunker-provision.sh:490-491`) is the only signal it has; redirecting stderr would not change the verdict |

Two platform facts the code depends on and does not validate:

- the **parent directory of the config is assumed to exist.** `os.makedirs` is applied to the password
  file's directory only (`scripts/node_gateway_auth.py:64`); the config's directory is never created,
  and a missing one raises an uncaught `FileNotFoundError` from `open(tmp, "w")`
  (`scripts/node_gateway_auth.py:80`) — measured, §3 arm 8: exit 1 with a traceback and no `FAIL` row.
- the config is **rewritten wholesale** through `config + ".cf-tmp"` (`scripts/node_gateway_auth.py:79`),
  so a read-only directory fails the same way, and any mode the operator had set is replaced by `600`
  (`scripts/node_gateway_auth.py:82`) — measured 644 → 600 in the scratch arm.

### 2c. Service contracts (both sides must be named)

No network peer exists. The real contract is a **file contract** on `~/.hermes/config.yaml`, and both
sides live in this repository:

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| the public-bind gate in `install-hermes.sh` | this module → gate | `~/.hermes/config.yaml` on the node | a top-level `dashboard:` map whose `basic_auth:` map carries two **non-empty strings**, `username` and `password` (`scripts/node_gateway_auth.py:72-78`) | `scripts/harness/install-hermes.sh:66-213` (`check_public_bind_auth`), invoked at `scripts/harness/install-hermes.sh:283`, refusal at `scripts/harness/install-hermes.sh:301` |
| step 5 of `bunker-provision.sh` | caller → this module | `bash -lc` on the node | three positional arguments: config path, password-file path, username (`scripts/node_gateway_auth.py:8`, `scripts/node_gateway_auth.py:36-37`) | `scripts/bunker-provision.sh:486-487` |

That producer/consumer pair was cross-checked rather than assumed: the gate function was extracted
verbatim from `scripts/harness/install-hermes.sh:66-213` into a scratch script and run against the node
layout (`$HOME/.hermes/config.yaml`) this module produces. Result `GATE: PASS`; with the block removed
from the same tree, `GATE: REFUSED (block absent)` (§3 arm 9). The gate's own rules — a non-empty
`username` and `password` string, parsed rather than grepped
(`scripts/harness/install-hermes.sh:202-210`) — are exactly what the appended block satisfies.

## 3. Verification

All arms ran on 2026-11-05 at `d8c7796`, from the repository root, with every config a scratch copy under
`$TMPDIR`; no real gateway config was touched. Each arm is a shell command whose measured result is in
the last column.

| # | Check | Command | Expected | Measured |
|---|---|---|---|---|
| 1 | absent config, full node layout | `python3 scripts/node_gateway_auth.py a/config.yaml a/auth/gateway.pass cf-node` | block added, exit 0 | exit `0`; config mode `600`, password mode `600`, password `33` bytes (32 + newline); `username=cf-node` |
| 2 | second run, same config (idempotence) | the same command again | no rewrite, exit 0 | exit `0`, `PASS  gateway_auth — dashboard.basic_auth already present in a/config.yaml`, config sha256 unchanged `yes` |
| 3 | `dashboard:` block without `basic_auth` | `python3 scripts/node_gateway_auth.py b/config.yaml b/p.pass` on `dashboard:` + `theme: dark` | refuse, file untouched, exit 2 | exit `2`, the `left untouched (a human must reconcile it)` row, sha256 unchanged `yes` |
| 4 | no arguments | `python3 scripts/node_gateway_auth.py` | usage on stderr, exit 2 | exit `2`, `usage: node_gateway_auth.py <config.yaml> <password-file> [username]`, stdout empty |
| 5 | the secret is never printed | capture stdout+stderr of arms 1–2, grep for the password read out of the config | 0 occurrences | password length `32`, occurrences `0` |
| 6 | `basic_auth` under a **sibling** top-level key | config whose `dashboard:` block is followed by `other:` holding `basic_auth:` | should refuse | **exit `0`**, `PASS  gateway_auth — dashboard.basic_auth already present` — a false PASS; the consumer gate on the same file says `GATE: REFUSED (block absent)` (§6 defect 1) |
| 7 | `basic_auth` eight lines below `dashboard:` | config with seven intervening keys before `basic_auth:` | should pass | **exit `2`**, `FAIL  gateway_auth — … has a dashboard block without basic_auth` — a false FAIL; the consumer gate on the same file says `GATE: PASS` (§6 defect 2) |
| 8 | caller shape when `~/.hermes` does not exist | `python3 scripts/node_gateway_auth.py e/.hermes/config.yaml e/.node/auth/gateway.pass cf-node` | a named refusal | **exit `1`** with `FileNotFoundError: … cf-tmp` and no `FAIL` row; the password file **is** written at `600`, the config is absent (§6 defect 3) |
| 9 | producer judged by its consumer | extracted `scripts/harness/install-hermes.sh:66-213` run with `HOME` pointing at the tree arm 1 produced | `GATE: PASS` | `GATE: PASS`; negative control with the block removed from the same tree: `GATE: REFUSED (block absent)` |
| 10 | pre-existing config mode | config written at `644` before the run | untouched or tightened | mode `644` before, `600` after — the module tightens it (`scripts/node_gateway_auth.py:82`) |

Arm 9 is the one that matters for CF-150: it proves that what this module writes is what the gate
accepts, so the missing caller — not the writer — is why a standalone node ends unprotected.

## 4. Metrics emitted

**`none`.** The module emits no counter, gauge, histogram or structured record: its whole observable
surface is six `PASS`/`FAIL` text lines (§5) and its exit code, and it imports nothing but `os`,
`secrets` and `sys` (`scripts/node_gateway_auth.py:17-19`) — no metrics client, no socket, no file other
than the config and the password file. The number that does exist is the exit status, consumed once at
`scripts/bunker-provision.sh:490-491` as the `gateway_auth` row; that row is the only way a run of this
module becomes visible to anything else, which is why §6 defect 1 (a false PASS) cannot be seen
downstream.

## 5. Log lines it can generate

Tagging: **descriptive** lines state what the module did; **evidentiary** lines assert a state a reader
grades, and each evidentiary line pairs with a distinct exit code.

| Tag | Stream | Exit | Line (verbatim) | Emitted when |
|---|---|---|---|---|
| descriptive | stderr | 2 | `usage: node_gateway_auth.py <config.yaml> <password-file> [username]` | fewer than two positional arguments (`scripts/node_gateway_auth.py:30-35`) |
| evidentiary | stderr | 1 | `FAIL  gateway_auth — cannot read {config} ({exc})` | an `OSError` other than `FileNotFoundError` while reading the config (`scripts/node_gateway_auth.py:44-46`) |
| evidentiary | stdout | 0 | `PASS  gateway_auth — dashboard.basic_auth already present in {config}` | the eight-line window after `dashboard:` contains `basic_auth:` (`scripts/node_gateway_auth.py:50-55`) |
| evidentiary | stderr | 2 | `FAIL  gateway_auth — {config}:{idx + 1} has a dashboard block without basic_auth; left untouched (a human must reconcile it)` | a `dashboard:` block whose window holds no `basic_auth:` (`scripts/node_gateway_auth.py:57-60`) |
| descriptive | stdout | 0 | `PASS  gateway_auth — added dashboard.basic_auth (user {username}) to {config}` | the block was appended and the config replaced (`scripts/node_gateway_auth.py:85-87`) |
| descriptive | stdout | 0 | `PASS  gateway_auth — password stored at {password_file}, mode 600 (not printed)` | the password file was written (`scripts/node_gateway_auth.py:88-90`) |

The password value appears in none of them (`scripts/node_gateway_auth.py:10-11`; measured §3 arm 5).
The two `added` / `stored` lines are **descriptive**: they report the write, not a re-read of the file,
so a reader who needs evidence must re-open the config or run the consumer gate.

## 6. Failure modes

Direction is stated for every row: the gap between what the line says and what is true.

| Failure | Presents as | Direction | Recovery |
|---|---|---|---|
| **1. Sibling-key false PASS** — `basic_auth:` falls inside the eight-line window but belongs to another top-level key | `PASS  gateway_auth — dashboard.basic_auth already present in {config}`, exit `0` (`scripts/node_gateway_auth.py:50-55`) | **over-claims protection**: the module says the node is protected, the consumer gate refuses the same file (`GATE: REFUSED`), so `bunker-provision.sh` records `ok  gateway_auth` and the gateway then refuses to bind. Measured §3 arm 6 | reconcile by hand; the check is a substring scan over a fixed window (`scripts/node_gateway_auth.py:50-51`), not a structural parse |
| **2. Window false FAIL** — a real `dashboard.basic_auth` sits beyond the window | the `left untouched (a human must reconcile it)` row, exit `2` (`scripts/node_gateway_auth.py:56-61`) | **under-claims protection**: the consumer gate passes the same file (`GATE: PASS`), yet `scripts/bunker-provision.sh:491` marks the step failed and sets `rc=1`, aborting a provisioning run on a node that is in fact legal. Measured §3 arm 7. The window is `lines[idx : idx + 8]` (`scripts/node_gateway_auth.py:50`) — seven lines after `dashboard:` | reconcile by hand, or move `basic_auth:` to within seven lines of `dashboard:` |
| **3. Missing config directory** — `~/.hermes` absent | a Python traceback on stderr ending `FileNotFoundError: … cf-tmp`, exit `1`, no `FAIL` row (`scripts/node_gateway_auth.py:80`) | **partially applied**: the password file was already written at `600` (`scripts/node_gateway_auth.py:65-68`) while no config exists, so a secret is left on disk with no consumer, and the failure speaks Python instead of the module's own vocabulary. Measured §3 arm 8 | `mkdir -p ~/.hermes` and rerun; the next run regenerates the password, replacing the orphan |
| **4. `dashboard:` present, `basic_auth:` absent** | exit `2` with the `left untouched` row naming config and line (`scripts/node_gateway_auth.py:57`) | **correct refusal**: the module will not guess where to insert a credential into an unfamiliar block | a human edits the block; the module passes on the next run if `basic_auth:` lands inside the window |
| **5. Read error other than an absent file** | `FAIL  gateway_auth — cannot read {config} ({exc})`, exit `1` (`scripts/node_gateway_auth.py:44-46`) | **correct refusal, narrow in scope**: it covers the read only — write errors from `open(tmp, "w")` and `os.replace` (`scripts/node_gateway_auth.py:79-83`) are uncaught and surface as a traceback, the same shape as row 3 | fix the permission or path, rerun |
| **6. An already-listening gateway is never gated** (consumer behaviour that makes this module's absence invisible) | `ok  port` plus `ok  status_probe`, and no `gateway_start` refusal | **a PASS that proves nothing about the public bind**: `check_public_bind_auth` is called at `scripts/harness/install-hermes.sh:283`, inside the not-listening branch opened at `scripts/harness/install-hermes.sh:282`, while a listener on the port is certified by the port and `/api/status` rows at `scripts/harness/install-hermes.sh:234-236`. A gateway bound to `0.0.0.0` without `dashboard.basic_auth` is therefore certified healthy — this is why CF-150 was raised to P1 | stop the listener and rerun `--apply` so the gate is reached |
| **7. A lost password file is not regenerated** | the `already present` row, exit `0`, and nothing written (`scripts/node_gateway_auth.py:48-55`) | **the pass file can vanish silently**: the block short-circuits before generation (`scripts/node_gateway_auth.py:49-55`), so `$HOME/.node/auth/gateway.pass` is a convenience copy and the config is the only authoritative copy of the secret — which is what `bunker-provision.sh:490` means by "password on the node only" | read the password from `~/.hermes/config.yaml`, or delete the `dashboard:` block to force regeneration (that rotates the credential) |

## 7. Environment and settings it reads

- **Environment variables: none.** The module has no `os.environ` reference (measured:
  `grep -c environ` → 0) and imports nothing that reads the environment implicitly.
- **Arguments** come from `sys.argv[1:]` (`scripts/node_gateway_auth.py:95`): `config` first,
  `password_file` second, `username` third or the literal default `"node"`
  (`scripts/node_gateway_auth.py:36-37`). The caller passes the node's agent id as the username
  (`scripts/bunker-provision.sh:487`), so the dashboard user is the agent name in practice.
- **Reads** the config if it exists (`scripts/node_gateway_auth.py:40`); `FileNotFoundError` is treated
  as an empty file, not an error (`scripts/node_gateway_auth.py:42-43`), which is what makes the
  fresh-node case work.
- **Writes** two files, both forced to mode `600`: the password file, created with `O_CREAT|O_TRUNC` at
  `0600` and then `chmod`-ed (`scripts/node_gateway_auth.py:65-68`), and the config, written to
  `config + ".cf-tmp"`, `chmod`-ed, then renamed over the original
  (`scripts/node_gateway_auth.py:79-83`). The password file's directory is created when missing
  (`scripts/node_gateway_auth.py:64`) — an empty dirname falls back to `"."`, so a bare filename stays in
  the current directory.
- **Umask** can only narrow the `open` mode at `scripts/node_gateway_auth.py:65`; the `chmod` at line 68
  sets `600` unconditionally, and the same applies to the config at line 82 (measured: a `644` config
  became `600`).
- **Not configurable:** the block's indentation, key names and placement are literals
  (`scripts/node_gateway_auth.py:74-77`), and there is no flag to accept a caller-chosen password — the
  credential is always generated on the node.

## 8. Evidence of record

- **Tree and date.** All measurements on 2026-11-05 against `d8c7796` in a worktree of `origin/main`,
  Python 3.14.4, scratch configs under `$TMPDIR` only. No gateway config on this host was read or
  written.
- **The four verdict-bearing transcripts, quoted exactly** (the ten arms and their exit codes, modes,
  sha256 equality and streams are tabulated in §3):

  ```
  PASS  gateway_auth — added dashboard.basic_auth (user cf-node) to a/config.yaml
  PASS  gateway_auth — password stored at a/auth/gateway.pass, mode 600 (not printed)
  rc=0
  ```

  ```
  PASS  gateway_auth — dashboard.basic_auth already present in a/config.yaml
  rc=0
  config sha unchanged=yes
  ```

  ```
  FAIL  gateway_auth — <config>:1 has a dashboard block without basic_auth; left untouched (a human must reconcile it)
  rc=2
  config untouched=yes
  ```

  (the path argument is elided as `<config>`; `1` is the line number the module printed, i.e. `idx + 1`
  for a `dashboard:` on line 1 of that scratch file)

  ```
  usage: node_gateway_auth.py <config.yaml> <password-file> [username]
  rc=2
  ```

- **Producer against consumer.** `GATE: PASS` for the config this module produced, and `GATE: REFUSED
  (block absent)` for the same tree with the block removed, using the gate extracted verbatim from
  `scripts/harness/install-hermes.sh:66-213`.
- **Corroborating record already in the tree.** `docs/audits/cf-dogfood-2026-11-04-gateway-apply.txt:25`
  holds the measured unprotected-node refusal from a fresh-HOME `install-hermes.sh --apply`; that line is
  the failure this module exists to prevent. Board row `CF-150`
  (`.coding-hermes/board/tasks.jsonl:4`) is the open work item that would close the caller gap.
- **Not measured.** Whether a bunker agent image already ships `~/.hermes/config.yaml`, and whether
  `node_env.py` and this module have ever run against the same file in one provisioning pass (both write
  it — `scripts/node_env.py:501` and `scripts/node_gateway_auth.py:79-83` — at different steps of
  `bunker-provision.sh`). Both need a live node; they are named here so the next reader does not mistake
  silence for evidence.
