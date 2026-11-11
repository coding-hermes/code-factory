# 29. scripts/node_gateway_auth.py

| Field | Value |
|---|---|
| Path | `~/code-factory/scripts/node_gateway_auth.py` |
| Repository | `code-factory` |
| Revision | `868e2fc` (the first CF-292 commit) — every locator below is re-pinned to the **post-CF-292 round-2** file, 194 lines; the file's own last-touching commit is the commit that carries this document (self-referential), and its blob is the one measured in §3. The ten original arms were measured 2026-11-05 at `d8c7796` (95 lines) and are kept verbatim; arms 6 and 7 were re-measured 2026-11-08 against the CF-292 file, and the direct-child rule plus the two write/comment arms were added and measured 2026-11-08 against this one |
| Status | **VERIFIED — measured 2026-11-05 against scratch configs, plus a cross-check against the consumer gate; CF-292 re-measured 2026-11-08; CF-292 round 2 (direct-child rule) measured 2026-11-08, 14 in-process arms** |

`VERIFIED` here means every claim below was measured and every locator was read at the revision
above. It does not mean the module is defect-free: §6 records the failure modes, three of them
measured. **CF-292 fixed the two presence-check defects (§6 rows 1 and 2)**: the verdict is now a
structural read of the `dashboard:` block, not a substring scan over a fixed eight-line window, and
`tests/test_node_gateway_auth.py` holds both arms as regressions. **CF-292 round 2 tightened the
depth from "any indented line" to "a direct child of `dashboard:`" (§6 row 1b)** — the first fix
still certified `dashboard: > child: > basic_auth:` as protection, which the consumer gate refuses.

## 1. Purpose and why it matters

- **What it does.** It guarantees that a node's `~/.hermes/config.yaml` carries a `dashboard.basic_auth`
  block. If the block is absent it generates a password on the node with `secrets.token_urlsafe(24)`
  (`scripts/node_gateway_auth.py:148`), writes it to a separate file at mode `600`
  (`scripts/node_gateway_auth.py:150-154`), and appends five lines to the config
  (`scripts/node_gateway_auth.py:164-170`). If a nested `basic_auth:` is already there it changes
  nothing (`scripts/node_gateway_auth.py:117-123`). The password is never printed — stdout carries the
  fact and the paths only (`scripts/node_gateway_auth.py:10-11`); measured: 0 occurrences of the
  generated password in the script's own output (§3 arm 5). That is the credential-on-disk rule the
  ledger records — file paths at mode `600`, never argv values — and this module is one of the tree's
  implementations of it (fact: FACT-05).
- **Presence is a structural read, not a window (CF-292, tightened in round 2).** The block is the
  run of indented, blank and comment lines that follows `dashboard:`; it ends at the first non-blank,
  non-comment line at column 0 (`scripts/node_gateway_auth.py:39-55`). Inside it, `basic_auth` counts
  only when it is a **direct child** of `dashboard:` — its indentation equals the block's child
  indent, computed as the minimum indentation among the block's non-blank, non-comment lines
  (`scripts/node_gateway_auth.py:58-72`), which YAML makes the depth of every sibling and the
  consumer gate reads as `dashboard`'s own mapping (`scripts/node_gateway_auth.py:75-95`). So a
  `basic_auth:` belonging to a sibling top-level key is not protection (it ends the block first), a
  `basic_auth:` hanging off one of dashboard's own child keys is not protection either
  (`dashboard.child.basic_auth` is a different path, and the gate refuses it), and a genuine direct
  child is found however far down the block it sits. `tests/test_node_gateway_auth.py` pins all
  directions, plus the usage, idempotence, mode-`600`, secret-never-printed and both write-failure
  arms.
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
- **Who does not call it.** `scripts/node-create.sh` and `scripts/project-node.sh` contained zero
  occurrences of either `auth` or `config.yaml` (measured at this appendix's revision: `grep -n
  'auth\|config.yaml'` exited 1 for both files). `node-create.sh` staged seven files, none of them
  this script and none a config (`scripts/node-create.sh:23`). That was precisely CF-150: the
  standalone create path (`node-create.sh` → `project-node.sh --apply` at `scripts/node-create.sh:121`)
  never reached the only writer of the block. **Corrected 2026-11-07 (CF-150):** the staged set is
  now eight files and layer 20 does reach the writer — `node-create.sh:26-30` stages
  `node_gateway_auth.py`, and `scripts/project-node.sh` runs it before the harness adapter on
  `--apply` (staging the block, printing one `gateway_auth` row) or reports its presence read-only on
  `--check`; the security shape is unchanged (password generated on the node, mode-600 file, never
  printed, never in argv), and `install-hermes.sh` still refuses the bind without a valid block.
  Evidence: `tests/selftest.sh` §55.
- **`install-hermes.sh` reads the block five times and never writes it.** The five occurrences are a
  comment (`scripts/harness/install-hermes.sh:17`, `:48`), the parser's membership test, comment probe
  and value fetch (`scripts/harness/install-hermes.sh:257`, `:259`, `:261`), and the refusal message
  (`scripts/harness/install-hermes.sh:388`). The file contains no `mkdir` at all (measured:
  `grep -c mkdir` → 0), so nothing in the harness layer creates `~/.hermes` either.
- **It is the only writer in `scripts/`.** The other editor of the same file, `node_env.py`, owns a
  whitelist of five scalars (`scripts/node_env.py:61-67`) and `dashboard.basic_auth` is not among them;
  it reads that path at `scripts/node_env.py:501`. So the tree holds one producer of this block
  (`scripts/node_gateway_auth.py:164-170`) and one consumer of it
  (`scripts/harness/install-hermes.sh:256-266`).
- **What an unprotected node looks like.** `install-hermes.sh --apply` refuses at
  `scripts/harness/install-hermes.sh:388` with
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
| `python3` | 3.6 or newer — the source uses f-strings and PEP 526 annotations (`scripts/node_gateway_auth.py:32`, `scripts/node_gateway_auth.py:121`); measured under Python 3.14.4 | `PATH` of the node, invoked as `python3` by the caller (`scripts/bunker-provision.sh:487`) | the caller's exit status: `bunker-provision.sh` prints `bad  gateway_auth  could not ensure dashboard.basic_auth (exit $gw_rc)` (`scripts/bunker-provision.sh:491`) |
| `os` | stdlib (`scripts/node_gateway_auth.py:27`) | same interpreter | import error, exit 1, no row printed |
| `secrets` | stdlib (`scripts/node_gateway_auth.py:28`) | same interpreter | import error, exit 1, no row printed |
| `sys` | stdlib (`scripts/node_gateway_auth.py:29`) | same interpreter | import error, exit 1, no row printed |

No third-party dependency, no network import, no shell call: the module only opens local files
(`scripts/node_gateway_auth.py:27-190`).

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `os` | `os` at `scripts/node_gateway_auth.py:27` | `os.makedirs(dirname(password_file) or ".", exist_ok=True)` (`scripts/node_gateway_auth.py:150`); `os.open(password_file, O_WRONLY \| O_CREAT \| O_TRUNC, 0o600)` (`scripts/node_gateway_auth.py:151`); `os.fdopen(fd, "w")` (`scripts/node_gateway_auth.py:152`); `os.chmod(password_file, 0o600)` and `os.chmod(tmp, 0o600)` (`scripts/node_gateway_auth.py:154`, `scripts/node_gateway_auth.py:175`); `os.replace(tmp, config)` (`scripts/node_gateway_auth.py:176`) | the config write stops being atomic (`os.replace` is the only rename), or the secret lands wider than `600`. The `open` mode at line 123 is subject to umask; the unconditional `chmod` at line 126 is what makes the mode `600` in fact — measured 600 (§3 arm 1) |
| `secrets` | `secrets` at `scripts/node_gateway_auth.py:28` | `secrets.token_urlsafe(24)` returns URL-safe text from the OS CSPRNG (`scripts/node_gateway_auth.py:148`); 24 bytes → 32 characters — measured `chars=33` including the trailing newline (§3 arm 1) | a shorter or non-URL-safe value would still be written verbatim; the module never validates the password's shape or length |
| `sys` | `sys` at `scripts/node_gateway_auth.py:29` | `sys.stderr` (`scripts/node_gateway_auth.py:102`, `scripts/node_gateway_auth.py:114`, `scripts/node_gateway_auth.py:127`), `sys.argv[1:]` (`scripts/node_gateway_auth.py:194`), `sys.exit` (`scripts/node_gateway_auth.py:194`) | the caller's exit-code contract (`scripts/bunker-provision.sh:490-491`) is the only signal it has; redirecting stderr would not change the verdict |

Two platform facts the code depends on and does not validate:

- the **parent directory of the config is created here, not assumed.** `os.makedirs(config_dir,
  mode=0o700, exist_ok=True)` runs before any write (`scripts/node_gateway_auth.py:137-146`, CF-388),
  so the fresh-node case — `~/.hermes` absent — is a normal path rather than a `FileNotFoundError`
  from `open(tmp, "w")`; the directory holds the gateway credential, hence `0700`. The password
  file's directory is created without an explicit mode (`scripts/node_gateway_auth.py:150`).
- the config is **rewritten wholesale** through `config + ".cf-tmp"` (`scripts/node_gateway_auth.py:171`),
  so any mode the operator had set is replaced by `600` (`scripts/node_gateway_auth.py:175`) — measured
  644 → 600 in the scratch arm — and a read-only directory now fails as a named `FAIL  gateway_auth —
  cannot write …` row with exit 1 (`scripts/node_gateway_auth.py:172-182`), not as a traceback.

### 2c. Service contracts (both sides must be named)

No network peer exists. The real contract is a **file contract** on `~/.hermes/config.yaml`, and both
sides live in this repository:

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| the public-bind gate in `install-hermes.sh` | this module → gate | `~/.hermes/config.yaml` on the node | a top-level `dashboard:` map whose `basic_auth:` map carries two **non-empty strings**, `username` and `password` (`scripts/node_gateway_auth.py:164-170`) | `scripts/harness/install-hermes.sh:121-268` (`check_public_bind_auth`), invoked at `scripts/harness/install-hermes.sh:312` (occupied port) and `scripts/harness/install-hermes.sh:370` (the build path), refusal at `scripts/harness/install-hermes.sh:388` |
| step 5 of `bunker-provision.sh` | caller → this module | `bash -lc` on the node | three positional arguments: config path, password-file path, username (`scripts/node_gateway_auth.py:8`, `scripts/node_gateway_auth.py:105-106`) | `scripts/bunker-provision.sh:486-487` |

The two sides now agree on *membership* as well as on shape. The gate parses the file and asks
whether the `dashboard` mapping holds a `basic_auth` mapping (`scripts/harness/install-hermes.sh:257-266`);
the module approximates that membership test by indentation — a `basic_auth:` at the **child indent**
of the run of lines the `dashboard:` key owns, i.e. a direct child of `dashboard:`
(`scripts/node_gateway_auth.py:58-95`). Before CF-292 it approximated it by *proximity* (an
eight-line window), which is exactly where the two verdicts diverged (§3 arms 6 and 7); before
round 2 it accepted *any* indented line, which certified `dashboard: > child: > basic_auth:` — a
depth-2 path the gate refuses (§3 arm 12).

That producer/consumer pair was cross-checked rather than assumed: the gate function was extracted
verbatim from `scripts/harness/install-hermes.sh:121-268` into a scratch script and run against the node
layout (`$HOME/.hermes/config.yaml`) this module produces. Result `GATE: PASS`; with the block removed
from the same tree, `GATE: REFUSED (block absent)` (§3 arm 9). The gate's own rules — a non-empty
`username` and `password` string, parsed rather than grepped
(`scripts/harness/install-hermes.sh:262-266`) — are exactly what the appended block satisfies.

## 3. Verification

All arms ran on 2026-11-05 at `d8c7796`, from the repository root, with every config a scratch copy under
`$TMPDIR`; no real gateway config was touched. Each arm is a shell command whose measured result is in
the last column. **CF-292 (2026-11-08):** arms 6, 7, 8 and the new arm 11 were re-measured against the
current file (every locator in this document resolves to it); **round 2 (2026-11-08)** added four
in-process arms (rows 12–14 below: the child-key refusal, its four-space pass counterpart, the
comment-before-sibling refusal and the password-file write failure) and re-ran arms 6, 7, 12 and 13
against the consumer gate on the same files; the
2026-11-05 measurements are kept verbatim beside the new ones, because the defect they recorded is
the reason the arms exist. Arms 12–14 run the module and the extracted gate over the *same* scratch
config, which is the only way the producer/consumer claim is a measurement rather than an assumption.

| # | Check | Command | Expected | Measured |
|---|---|---|---|---|
| 1 | absent config, full node layout | `python3 scripts/node_gateway_auth.py a/config.yaml a/auth/gateway.pass cf-node` | block added, exit 0 | exit `0`; config mode `600`, password mode `600`, password `33` bytes (32 + newline); `username=cf-node` |
| 2 | second run, same config (idempotence) | the same command again | no rewrite, exit 0 | exit `0`, `PASS  gateway_auth — dashboard.basic_auth already present in a/config.yaml`, config sha256 unchanged `yes` |
| 3 | `dashboard:` block without `basic_auth` | `python3 scripts/node_gateway_auth.py b/config.yaml b/p.pass` on `dashboard:` + `theme: dark` | refuse, file untouched, exit 2 | exit `2`, the `left untouched (a human must reconcile it)` row, sha256 unchanged `yes` |
| 4 | no arguments | `python3 scripts/node_gateway_auth.py` | usage on stderr, exit 2 | exit `2`, `usage: node_gateway_auth.py <config.yaml> <password-file> [username]`, stdout empty |
| 5 | the secret is never printed | capture stdout+stderr of arms 1–2, grep for the password read out of the config | 0 occurrences | password length `32`, occurrences `0` |
| 6 | `basic_auth` under a **sibling** top-level key | config whose `dashboard:` block is followed by `other:` holding `basic_auth:` | refuse, exit 2 | **FIXED (CF-292).** At `d8c7796`: **exit `0`**, `PASS  gateway_auth — dashboard.basic_auth already present` — a false PASS, while the consumer gate on the same file said `GATE: REFUSED (block absent)` (§6 defect 1). Re-measured 2026-11-08: exit `2`, `FAIL  gateway_auth — …:3 has a dashboard block without basic_auth; left untouched (a human must reconcile it)`, config sha256 unchanged, `GATE: REFUSED (block absent)` — producer and consumer now agree. Regression: `tests/test_node_gateway_auth.py::GatewayAuth::test_basic_auth_under_a_sibling_top_level_key_is_refused` |
| 7 | `basic_auth` below `dashboard:` beyond the old window | config with seven intervening keys before `basic_auth:`, plus a blank line and a `#` comment inside the block | pass, exit 0 | **FIXED (CF-292).** At `d8c7796`: **exit `2`**, `FAIL  gateway_auth — … has a dashboard block without basic_auth` — a false FAIL, while the consumer gate said `GATE: PASS` (§6 defect 2). Re-measured 2026-11-08: exit `0`, `PASS  gateway_auth — dashboard.basic_auth already present in …`, config sha256 unchanged, `GATE: PASS`. Regression: `…::test_deep_nested_basic_auth_passes` |
| 8 | caller shape when `~/.hermes` does not exist | `python3 scripts/node_gateway_auth.py e/.hermes/config.yaml e/.node/auth/gateway.pass cf-node` | a named row, exit 0, directory created | **FIXED (CF-388).** At `d8c7796`: **exit `1`** with `FileNotFoundError: … cf-tmp` and no `FAIL` row; the password file **was** written at `600`, the config absent (§6 defect 3). Re-measured 2026-11-08: exit `0`, both `PASS` rows, `~/.hermes` `700`, config `600`, password file `600` |
| 9 | producer judged by its consumer | extracted `scripts/harness/install-hermes.sh:121-268` run with `HOME` pointing at the tree arm 1 produced | `GATE: PASS` | `GATE: PASS`; negative control with the block removed from the same tree: `GATE: REFUSED (block absent)` |
| 10 | pre-existing config mode | config written at `644` before the run | untouched or tightened | mode `644` before, `600` after — the module tightens it (`scripts/node_gateway_auth.py:175`) |
| 11 | the structural verdicts as regressions, in-process | `/usr/bin/python3 -m unittest discover -s tests -p 'test_node_gateway_auth.py' -v` | 14 arms green; the pre-fix modules red on the structural ones | **Round 2 (2026-11-08):** `Ran 14 tests … OK` (rc `0`) — the ten CF-292 arms plus the four round-2 arms (arm 12's refusal and its four-space pass counterpart, arm 13's comment arm, arm 14's password-write failure). Red proof against `git show 868e2fc:scripts/node_gateway_auth.py` (the first CF-292 fix): `Ran 14 tests … FAILED (failures=1)`, the single failure `test_basic_auth_under_a_child_key_is_refused` — `AssertionError: 0 != 2 : a basic_auth under a child key was certified as protection: PASS  gateway_auth — dashboard.basic_auth already present`. Earlier proof, kept: the ten-arm file against `git show b8fb992:scripts/node_gateway_auth.py` gives `FAILED (failures=4, errors=1)` — arms 3, 4, 7-shaped, the column-0 key and the write-failure arm, exactly the behaviours CF-292 changed |
| 12 | `basic_auth` under a **child key** of `dashboard` (review finding 0) | config `dashboard:` → `theme: dark` → `child:` → `basic_auth:`; consumer gate on the same file | refuse, exit 2 | **FIXED (round 2).** At `868e2fc`: **exit `0`**, `PASS  gateway_auth — dashboard.basic_auth already present` — a false PASS at `dashboard.child.basic_auth`, while the gate said `GATE: REFUSED (block absent)`. Now: exit `2`, the `left untouched (a human must reconcile it)` row, config sha256 unchanged, no password file, `GATE: REFUSED (block absent)`. Regression: `…::test_basic_auth_under_a_child_key_is_refused`; the complementary pass arm is `…::test_basic_auth_at_a_four_space_child_indent_passes` (a direct child at a four-space indent is still protection — the rule is equality with the child indent, not a literal two spaces) |
| 13 | a column-0 comment **between** the block and the next top-level key (review finding 2) | config `dashboard:` → `theme: dark` → `# a note …` → `other:` → `basic_auth:` | refuse, exit 2 | exit `2`, the `left untouched` row, config sha256 unchanged, no password file, `GATE: REFUSED (block absent)` — the comment does not extend the block over the sibling key, which is the symmetric half of arm 9's "a comment inside the block does not end it". Regression: `…::test_column_zero_comment_before_a_sibling_key_does_not_extend_the_block` |
| 14 | the password-file write failure (review finding 1) | password path's parent is a regular file, so `os.makedirs` raises `NotADirectoryError` — forced without a directory mode, so it runs as root too | exit 1, the path named, config untouched, no traceback | exit `1`, stdout empty, `FAIL  gateway_auth — cannot write <password-file> ([Errno 20] Not a directory: '<dir>')`, config sha256 unchanged, blocking file left alone. Regression: `…::test_unwritable_password_file_is_a_named_failure` (the sibling arm `…::test_unwritable_config_directory_is_a_named_failure` covers the config write) |

Arm 9 is the one that matters for CF-150: it proves that what this module writes is what the gate
accepts, so the missing caller — not the writer — is why a standalone node ends unprotected.

## 4. Metrics emitted

**`none`.** The module emits no counter, gauge, histogram or structured record: its whole observable
surface is nine `PASS`/`FAIL`/usage text lines (§5) and its exit code, and it imports nothing but `os`,
`secrets` and `sys` (`scripts/node_gateway_auth.py:27-29`) — no metrics client, no socket, no file other
than the config and the password file. The number that does exist is the exit status, consumed once at
`scripts/bunker-provision.sh:490-491` as the `gateway_auth` row; that row is the only way a run of this
module becomes visible to anything else, which is why §6 defect 1 (a false PASS) could not be seen
downstream before CF-292.

## 5. Log lines it can generate

Tagging: **descriptive** lines state what the module did; **evidentiary** lines assert a state a reader
grades, and each evidentiary line pairs with a distinct exit code.

| Tag | Stream | Exit | Line (verbatim) | Emitted when |
|---|---|---|---|---|
| descriptive | stderr | 2 | `usage: node_gateway_auth.py <config.yaml> <password-file> [username]` | fewer than two positional arguments (`scripts/node_gateway_auth.py:99-104`) |
| evidentiary | stderr | 1 | `FAIL  gateway_auth — cannot read {config} ({exc})` | an `OSError` other than `FileNotFoundError` while reading the config (`scripts/node_gateway_auth.py:113-115`) |
| evidentiary | stdout | 0 | `PASS  gateway_auth — dashboard.basic_auth already present in {config}` | a `basic_auth:` that is a **direct child** of `dashboard:` — the structural read (`scripts/node_gateway_auth.py:58-72`, `scripts/node_gateway_auth.py:75-95`, `scripts/node_gateway_auth.py:117-123`); not a window, not a sibling key's `basic_auth:`, and not one hanging off a child key |
| evidentiary | stderr | 2 | `FAIL  gateway_auth — {config}:{idx + 1} has a dashboard block without basic_auth; left untouched (a human must reconcile it)` | a `dashboard:` block that holds no direct-child `basic_auth:` — including one whose `basic_auth:` belongs to a sibling top-level key, sits after the block ends, or is nested under a child key of `dashboard` (`scripts/node_gateway_auth.py:124-129`) |
| evidentiary | stderr | 1 | `FAIL  gateway_auth — cannot create {config_dir} ({exc})` | the config's parent directory could not be created (`scripts/node_gateway_auth.py:139-146`) |
| evidentiary | stderr | 1 | `FAIL  gateway_auth — cannot write {password_file} ({exc})` | the password file could not be created, written or `chmod`-ed (`scripts/node_gateway_auth.py:155-160`); nothing is appended to the config |
| evidentiary | stderr | 1 | `FAIL  gateway_auth — cannot write {config} ({exc})` | the `.cf-tmp` write, its `chmod`, or the `os.replace` failed (`scripts/node_gateway_auth.py:177-182`); the config on disk is left as it was |
| descriptive | stdout | 0 | `PASS  gateway_auth — added dashboard.basic_auth (user {username}) to {config}` | the block was appended and the config replaced (`scripts/node_gateway_auth.py:184-186`) |
| descriptive | stdout | 0 | `PASS  gateway_auth — password stored at {password_file}, mode 600 (not printed)` | the password file was written (`scripts/node_gateway_auth.py:187-189`) |

The password value appears in none of them (`scripts/node_gateway_auth.py:10-11`; measured §3 arm 5).
The two `added` / `stored` lines are **descriptive**: they report the write, not a re-read of the file,
so a reader who needs evidence must re-open the config or run the consumer gate.

## 6. Failure modes

Direction is stated for every row: the gap between what the line says and what is true.

| Failure | Presents as | Direction | Recovery |
|---|---|---|---|
| **1. Sibling-key false PASS — FIXED (CF-292)** — a `basic_auth:` inside the old eight-line window that belongs to another top-level key | before (`d8c7796`): `PASS  gateway_auth — dashboard.basic_auth already present in {config}`, exit `0`; now: the `left untouched (a human must reconcile it)` row, exit `2`, file byte-identical | **was over-claiming protection**: the module said the node was protected, the consumer gate refused the same file (`GATE: REFUSED`), so `bunker-provision.sh` recorded `ok  gateway_auth` and the gateway then refused to bind (measured §3 arm 6). **Now honest**: the block ends at the sibling top-level key, so the sibling's `basic_auth:` is outside it — the check is a structural read (`scripts/node_gateway_auth.py:39-55`, `scripts/node_gateway_auth.py:75-95`), not a substring scan over a fixed window | nothing to reconcile by hand; the refusal names config and line. Pinned by `tests/test_node_gateway_auth.py::GatewayAuth::test_basic_auth_under_a_sibling_top_level_key_is_refused`, `::test_basic_auth_after_the_block_is_refused` and `::test_top_level_basic_auth_key_is_refused` |
| **1b. Child-key false PASS — FIXED (CF-292 round 2)** — a `basic_auth:` nested under one of `dashboard:`'s own child keys, i.e. `dashboard.child.basic_auth` | at `868e2fc`: `PASS  gateway_auth — dashboard.basic_auth already present in {config}`, exit `0`; now: the `left untouched (a human must reconcile it)` row, exit `2`, file byte-identical | **was over-claiming protection one level further down**: the first CF-292 fix accepted *any* indented `basic_auth:` in the block, so a depth-2 path was certified while the consumer gate — which reads `dashboard.basic_auth` at depth 1 — refused the same file (`GATE: REFUSED (block absent)`; measured §3 arm 12). **Now honest**: membership is indentation equality with the block's child indent, computed as the minimum indentation among the block's non-blank, non-comment lines (`scripts/node_gateway_auth.py:58-72`, `scripts/node_gateway_auth.py:75-95`) | nothing to reconcile by hand; the refusal names config and line. Pinned by `…::test_basic_auth_under_a_child_key_is_refused`, with `…::test_basic_auth_at_a_four_space_child_indent_passes` holding the other direction |
| **2. Window false FAIL — FIXED (CF-292)** — a real `dashboard.basic_auth` sat more than seven lines below `dashboard:` | before (`d8c7796`): the `left untouched (a human must reconcile it)` row, exit `2`; now: `PASS  gateway_auth — dashboard.basic_auth already present in {config}`, exit `0`, file byte-identical | **was under-claiming protection**: the consumer gate passed the same file (`GATE: PASS`), yet `scripts/bunker-provision.sh:491` marked the step failed and set `rc=1`, aborting a provisioning run on a node that was in fact legal (measured §3 arm 7). **Now honest**: the block runs to the first non-blank, non-comment column-0 line, so a nested `basic_auth:` is found however deep it sits and however many blank or comment lines intervene (`scripts/node_gateway_auth.py:39-55`) | nothing to re-indent. Pinned by `…::test_deep_nested_basic_auth_passes` (seven intervening keys, a blank line and a `#` comment) and `…::test_column_zero_comment_does_not_end_the_block` |
| **3. Missing config directory — FIXED (CF-388)** — `~/.hermes` absent | before (`d8c7796`): a Python traceback on stderr ending `FileNotFoundError: … cf-tmp`, exit `1`, no `FAIL` row, while the password file was already written at `600` and no config existed (measured §3 arm 8). Now: exit `0`, both `PASS` rows, directory `0700` | **was partially applied** — a secret on disk with no consumer, and a failure speaking Python instead of the module's own vocabulary. **Now**: the config's parent is created at `0700` before any write (`scripts/node_gateway_auth.py:137-146`), so the fresh-node case is a normal path | nothing: `mkdir -p ~/.hermes` is no longer a precondition (re-measured 2026-11-08, §3 arm 8) |
| **4. `dashboard:` present, direct-child `basic_auth:` absent** | exit `2` with the `left untouched` row naming config and line (`scripts/node_gateway_auth.py:124-129`) | **correct refusal**: the module will not guess where to insert a credential into an unfamiliar block | a human edits the block; the module passes on the next run once a **direct-child** `basic_auth:` is present — at the block's child indent, anywhere inside the block (`…::test_dashboard_block_without_basic_auth_is_refused`) |
| **5. Read or write error** | read: `FAIL  gateway_auth — cannot read {config} ({exc})` (`scripts/node_gateway_auth.py:113-115`); write: `FAIL  gateway_auth — cannot create {config_dir} ({exc})` / `cannot write {password_file} ({exc})` / `cannot write {config} ({exc})` (`:139-146`, `:155-160`, `:177-182`) — all exit `1` | **correct refusal**: each names the path it could not touch instead of speaking Python. Until CF-292 the two write paths were uncaught, so a read-only directory surfaced as a traceback with no `FAIL` row (the shape row 3 used to have); `…::test_unwritable_config_directory_is_a_named_failure` and `…::test_unwritable_password_file_is_a_named_failure` pin both write contracts | fix the permission or path, rerun |
| **6. An already-listening gateway is never gated** (consumer behaviour that makes this module's absence invisible) | `ok  port` plus `ok  status_probe`, and no `gateway_start` refusal | **a PASS that proves nothing about the public bind**: `check_public_bind_auth` is called at `scripts/harness/install-hermes.sh:370`, inside the not-listening branch opened at `scripts/harness/install-hermes.sh:369` (the occupied-port branch calls the same gate at `scripts/harness/install-hermes.sh:312`), while a listener on the port is certified by the port and `/api/status` rows at `scripts/harness/install-hermes.sh:306-316`. A gateway bound to `0.0.0.0` without `dashboard.basic_auth` is therefore certified healthy — this is why CF-150 was raised to P1 | stop the listener and rerun `--apply` so the gate is reached |
| **7. A lost password file is not regenerated** | the `already present` row, exit `0`, and nothing written (`scripts/node_gateway_auth.py:117-123`) | **the pass file can vanish silently**: the block short-circuits before generation (`scripts/node_gateway_auth.py:117-123`), so `$HOME/.node/auth/gateway.pass` is a convenience copy and the config is the only authoritative copy of the secret — which is what `bunker-provision.sh:490` means by "password on the node only" | read the password from `~/.hermes/config.yaml`, or delete the `dashboard:` block to force regeneration (that rotates the credential) |
| **8. `project-node.sh --check` keeps the looser rule** (a sibling surface, outside this unit's fence) | `ok  gateway_auth — dashboard.basic_auth present in {config} (presence only — the adapter's gate is the authority)` on the child-key shape this module now REFUSES (measured 2026-11-08 by running `scripts/project-node.sh:587-601`'s loop over the arm-12 config) | **over-claims presence**: the row says the block is present where `dashboard.basic_auth` is not, i.e. the same defect class as §6 row 1b one surface further out. It authorises nothing — the row's own text defers to the adapter's gate, which refuses the file (`GATE: REFUSED (block absent)`) — so the consequence is a misleading node report, not a public bind | fix `scripts/project-node.sh` to read the same direct-child rule (not in the CF-292 round-2 change set); until then read the adapter's `gateway_start` row as the authority, as the row says |
| **9. Mixed-indent block (invalid YAML) — OPEN, measured** — a hand-written `dashboard:` whose children sit at different indents, e.g. `dashboard:` → `    theme: dark` → `  basic_auth:` | `PASS  gateway_auth — dashboard.basic_auth already present in {config}`, exit `0`; the consumer gate on the same file: `block absent (invalid YAML)`, exit `1` (measured 2026-11-08) | **over-claims presence on malformed input**: the round-2 rule takes the MINIMUM indentation of the block's content lines as the child indent, which is the child indent only for well-formed YAML; the gate pins the FIRST child's indent and requires every sibling at it, so a `basic_auth:` at the minimum can be certified where the gate refuses the file. Bounded: the adapter still refuses the bind, so no node ends publicly unprotected — the cost is a misleading `ok gateway_auth` row (same class as row 8) | close it by using the first content line's indent as the child indent (the gate's own rule) in addition to the minimum, and add a mixed-indent arm; not done in this change because the review prescribed the minimum-indentation rule and nothing in the provisioning path writes mixed indentation |

## 7. Environment and settings it reads

- **Environment variables: none.** The module has no `os.environ` reference (measured:
  `grep -c environ` → 0) and imports nothing that reads the environment implicitly.
- **Arguments** come from `sys.argv[1:]` (`scripts/node_gateway_auth.py:194`): `config` first,
  `password_file` second, `username` third or the literal default `"node"`
  (`scripts/node_gateway_auth.py:105-106`). The caller passes the node's agent id as the username
  (`scripts/bunker-provision.sh:487`), so the dashboard user is the agent name in practice.
- **Reads** the config if it exists (`scripts/node_gateway_auth.py:109`); `FileNotFoundError` is treated
  as an empty file, not an error (`scripts/node_gateway_auth.py:111-112`), which is what makes the
  fresh-node case work.
- **Writes** two files, both forced to mode `600`: the password file, created with `O_CREAT|O_TRUNC` at
  `0600` and then `chmod`-ed (`scripts/node_gateway_auth.py:150-154`), and the config, written to
  `config + ".cf-tmp"`, `chmod`-ed, then renamed over the original
  (`scripts/node_gateway_auth.py:172-182`). The password file's directory is created when missing
  (`scripts/node_gateway_auth.py:150`) — an empty dirname falls back to `"."`, so a bare filename stays in
  the current directory — and the config's directory is created at `0700`
  (`scripts/node_gateway_auth.py:137-146`).
- **Umask** can only narrow the `open` mode at `scripts/node_gateway_auth.py:151`; the `chmod` at line 154
  sets `600` unconditionally, and the same applies to the config at line 175 (measured: a `644` config
  became `600`).
- **Not configurable:** the block's indentation, key names and placement are literals
  (`scripts/node_gateway_auth.py:166-169`), and there is no flag to accept a caller-chosen password — the
  credential is always generated on the node. The presence check reads indentation but has no knob of its
  own: the block boundary, the child indent and the direct-child rule are the three functions at
  `scripts/node_gateway_auth.py:39-95`.

## 8. Evidence of record

- **Tree and date.** The ten original arms were measured on 2026-11-05 against `d8c7796` in a worktree
  of `origin/main`, Python 3.14.4, scratch configs under `$TMPDIR` only. **CF-292** re-measured arms 6,
  7, 8 and 11 on 2026-11-08 against the current file (`b8fb992` + the CF-292 diff), Python 3.14.4,
  scratch configs under `$TMPDIR` only. **CF-292 round 2** re-measured arms 6, 7, 12, 13 and 14 on
  2026-11-08 against this file (`868e2fc` + the round-2 diff), Python 3.14.4, scratch configs under
  `$TMPDIR` only, with the consumer gate extracted verbatim from
  `scripts/harness/install-hermes.sh:125-266`. No gateway config on this host was read or written.
- **The round-2 arms, verbatim, with the gate's verdict on the same file:**

  ```
  === deeper-child ===            (dashboard: > theme: > child: > basic_auth:)
  FAIL  gateway_auth — <config>:1 has a dashboard block without basic_auth; left untouched (a human must reconcile it)
  rc=2  config unchanged=yes   GATE: REFUSED (block absent)

  === comment-then-sibling ===    (dashboard: > theme: > "# a note" > other: > basic_auth:)
  FAIL  gateway_auth — <config>:1 has a dashboard block without basic_auth; left untouched (a human must reconcile it)
  rc=2  config unchanged=yes   GATE: REFUSED (block absent)

  === deep-direct ===
  PASS  gateway_auth — dashboard.basic_auth already present in <config>
  rc=0  config unchanged=yes   GATE: PASS
  ```

  The pre-fix module at `868e2fc` on the first of those files: `PASS  gateway_auth — dashboard.basic_auth
  already present in <config>`, `rc=0` — the false PASS the round-2 rule closes, measured on the same
  config the gate refuses.
- **The two presence arms, verbatim, after the fix** (the two false verdicts recorded below them are the
  2026-11-05 measurements at `d8c7796`, kept because they are what the fix is measured against):

  ```
  FAIL  gateway_auth — <config>:3 has a dashboard block without basic_auth; left untouched (a human must reconcile it)
  rc=2
  config untouched=yes
  ```

  ```
  PASS  gateway_auth — dashboard.basic_auth already present in <config>
  rc=0
  config untouched=yes
  ```

  Both files were then handed to the consumer gate extracted from `scripts/harness/install-hermes.sh`:
  `GATE: REFUSED (block absent)` for the sibling-key config, `GATE: PASS` for the deep one — producer and
  consumer agree on each, which is the whole point of CF-292. Before the fix the same two files gave
  `PASS` / rc `0` and `FAIL` / rc `2` — inverted against the gate in both cases.
- **In-process regressions.** `/usr/bin/python3 -m unittest tests.test_node_gateway_auth -v` →
  `Ran 10 tests … OK`; the same file against the pre-fix module (`git show b8fb992:scripts/node_gateway_auth.py`)
  → `FAILED (failures=4, errors=1)`, red on exactly the behaviours CF-292 changed and green on the five
  arms asserting unchanged behaviour.
- **The four verdict-bearing transcripts of the original measurement, quoted exactly** (the eleven arms
  and their exit codes, modes, sha256 equality and streams are tabulated in §3):

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
  `scripts/harness/install-hermes.sh:121-268`.
- **Corroborating record already in the tree.** `docs/audits/cf-dogfood-2026-11-04-gateway-apply.txt:25`
  holds the measured unprotected-node refusal from a fresh-HOME `install-hermes.sh --apply`; that line is
  the failure this module exists to prevent. Board row `CF-150`
  (`.coding-hermes/board/tasks.jsonl:4`) is the open work item that would close the caller gap.
- **Not measured.** Whether a bunker agent image already ships `~/.hermes/config.yaml`, and whether
  `node_env.py` and this module have ever run against the same file in one provisioning pass (both write
  it — `scripts/node_env.py:501` and `scripts/node_gateway_auth.py:172-182` — at different steps of
  `bunker-provision.sh`). Both need a live node; they are named here so the next reader does not mistake
  silence for evidence.
