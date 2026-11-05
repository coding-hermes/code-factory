# 22. scripts/lib.sh

| Field | Value |
|---|---|
| Path | `/home/kara/proj-wt-md-22c/scripts/lib.sh` — 65 lines, 12 functions, sourced and never executed [scripts/lib.sh:1] [scripts/lib.sh:3] |
| Repository | `code-factory` |
| Revision | `b31c232` — the `origin/main` tip every locator below was measured against on 2026-11-05 |
| Status | **VERIFIED — all 12 helpers exercised in a scratch shell; one PASS row captured byte-for-byte with `od` and `cat -A`** |

## 1. Purpose and why it matters

- What it is: the repo's only shared shell code — twelve functions in 65 lines [scripts/lib.sh:5-13] [scripts/lib.sh:16-29] [scripts/lib.sh:32-51] [scripts/lib.sh:54-65]. It is sourced at 17 top-level sites by 15 scripts and 2 test harnesses — and once more inside a generated fixture, [tests/selftest.sh:553] — and it is copied onto a node as a staged file by the provisioner [scripts/node-create.sh:23]. There is no other include path: a script either has these helpers or has none.
- Why it is load-bearing: it owns the repo's entire row vocabulary. Every check in every script reports through `ok`/`bad`/`warn`/`note` [scripts/lib.sh:6-9], and the code that grades those scripts greps the row shape rather than any structured output — `project-node.sh` counts a child's failures with `grep -c '^  FAIL'` [scripts/project-node.sh:406] [scripts/project-node.sh:455], and `selftest.sh` asserts the literal row `  FAIL  harness:fixture/a — simulated adapter failure one` [tests/selftest.sh:566]. Change the two leading spaces or the em dash in `ok()`/`bad()` and the regression test that counts failures goes blind instead of red.
- Where the power actually sits: `bad()` is the only thing in lib.sh that moves the counter [scripts/lib.sh:7], and lib.sh never exits, never fails a row helper's status, and never inspects `$FAILED` itself. Each consumer decides separately whether a failure is fatal, in its own last line — `bunker-provision.sh` returns the test at [scripts/bunker-provision.sh:304], `verify-node.sh` exits 1 at [scripts/verify-node.sh:191], `project-node.sh` exits 1 at [scripts/project-node.sh:826], `harness-conformance.sh` exits 1 at [tests/harness-conformance.sh:500]. lib.sh decides whether a failure is **visible**; the consumer decides whether it is **fatal**. A consumer that prints a red row and then forgets `[ "$FAILED" -eq 0 ]` owns a check that can never fail.
- What breaks if it is ABSENT: not "command not found for every row" — measured, the run dies earlier and louder than that. With `lib.sh` deleted and a two-line config, `bunker-provision.sh --config cf-bunker.conf --check` printed two lines and exited **1**: `bunker-provision.sh: line 36: …/lib.sh: No such file or directory`, then `bunker-provision.sh: line 122: ok: command not found`. `ok` was the last statement of `load_config`, so that function returned 127 and the caller's `load_config "$CONFIG" || exit 1` [scripts/bunker-provision.sh:590] converted it into exit 1 before a single row printed. `install-gitreins.sh` without `lib.sh` exits 1 the same way (127 from its first `say`, then a `return 1`). So the absent case is fail-closed on *status* and fail-open on *evidence*: the run is silent, not red, and a wrapper scanning stdout for `BUNKER: PASS` finds neither word. The green-summary-over-red-rows path is real, but it arrives through the counter, not through the missing file — §6.
- What breaks if it LIES: `ok`/`bad`/`warn` are bare `printf`s with no cross-check of the claim they print [scripts/lib.sh:6-8]. `  PASS  disk — 175.3 GB free (floor 1 GB)` is generated from the same `df` the row reports, so that number is measured [scripts/lib.sh:32]; `  PASS  crier_url — …` is whatever string the caller passed. lib.sh supplies the *shape* of evidence, never its substance. And one helper can lie outright with a success status: `fetch_verified` returns **0 after failing to install the file** when `mkdir`/`mv` cannot complete, because its last statement is `chmod … || true` [scripts/lib.sh:26-28] — measured in §6, row 8. Both callers trust that status: [scripts/install-go.sh:139] and [scripts/harness/install-codex.sh:358].
- Blast radius: one host. `FAILED` is an ordinary shell variable in the calling process [scripts/lib.sh:11]; it dies at process exit and does not cross a subshell or a pipe (§3 row 12). Anything that runs a check in `( … )` or `… | cat` and reads `$FAILED` afterwards reads zero no matter how many red rows printed.

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `bash` | any bash with `local`, `${v//pat/rep}` and `$((…))` — the header says "Requires bash" and `shq` uses the pattern-replacement form [scripts/lib.sh:3] [scripts/lib.sh:55] | the interpreter running the consumer; lib.sh is `.`-sourced, never executed, so the consumer's shebang decides [scripts/bunker-provision.sh:36] | **nothing in lib.sh** — a POSIX `sh` that cannot parse `local` fails at the `.`; there is no version probe anywhere in the file |
| `printf`, `local` | bash builtins | — | cannot be absent |
| `mktemp` [scripts/lib.sh:18] | any | `PATH` | measured: without `mktemp` the temp path is empty, `curl -o ''` is a usage error, and `fetch_verified` returns 1 having placed nothing — fails closed |
| `curl` [scripts/lib.sh:19] | any with `-fsSL --max-time -o` | `PATH`, **by bare name**, so `PATH` order decides which binary runs | `fetch_verified` returns 1 carrying `curl:`'s own stderr; the caller's `if ! fetch_verified` branch names the row [scripts/install-go.sh:139] [scripts/harness/install-codex.sh:358] |
| `sha256sum`, `cut` [scripts/lib.sh:20] | coreutils | `PATH` | measured: with `sha256sum` absent, `got` is empty, which cannot equal a 64-hex `want`, so the row reads `digest mismatch for …: want d4e4877b… got ` and returns 1 — a **false refusal**, not a pass |
| `mkdir`, `mv`, `chmod` [scripts/lib.sh:26-28] | coreutils | `PATH` | **not detected at all** — see §6 row 8: the `\|\| true` on `chmod` makes the function return 0 even after `mkdir` was denied and `mv` failed |
| `dirname`, `basename`, `date` [scripts/lib.sh:26] [scripts/lib.sh:49-50] | coreutils | `PATH` | a missing `dirname` yields `mkdir -p ''`, which is a no-op error, and the placement then fails silently as above |
| `df`, `awk` [scripts/lib.sh:32] | any `df -Pk`; any awk with `printf` and `BEGIN` | `PATH` | a failing `df` yields an empty `free_gb`, and `require_disk` prints `FAIL  disk —  GB free < floor …` and returns 1 — measured, fails closed |
| `bunker` CLI [scripts/lib.sh:64] | any | `PATH` | **not** detected — `have` cannot report absence (§6 row 4), so `bunker_exec` fails as the CLI's own 127 from inside the command substitution |

Nothing in this file is pinned, versioned or probed. lib.sh does not refuse to run on a host lacking `curl`, `df` or `bunker`; the first helper that needs one returns non-zero and leaves the naming to its caller.

### 2b. What each helper emits

Every row helper writes to **stdout**; the single line lib.sh sends to stderr is the digest mismatch [scripts/lib.sh:23]. The separator in a row is U+2014 `e2 80 94`, not a hyphen — measured (§3 row 3).

| Helper | Definition | Exact bytes written (measured) | Returns |
|---|---|---|---|
| `say` | [scripts/lib.sh:5] | `one two\n` — all arguments joined by one space, no prefix | 0 |
| `ok` | [scripts/lib.sh:6] | `  PASS  disk — 12.0 GB free\n` — 2 spaces, `PASS`, 2 spaces, name, space, em dash, space, detail | 0 |
| `bad` | [scripts/lib.sh:7] | `  FAIL  crier_url — CRIER_URL unset\n`, **and** `FAILED=$((FAILED+1))` | 0, always |
| `warn` | [scripts/lib.sh:8] | `  WARN  chrome — not on PATH\n` | 0 |
| `note` | [scripts/lib.sh:9] | `  ..    already done: marker\n` — 2 spaces, `..`, 4 spaces, text | 0 |
| `have` | [scripts/lib.sh:13] | `/usr/bin/bash\n` when found, nothing when not | 0, **always** — the `\|\| true` swallows the miss |
| `fetch_verified` | [scripts/lib.sh:16-29] | the file at `dest` with mode `-rwx--x--x`, or one stderr line `digest mismatch for <url>: want <64hex> got <64hex>` [scripts/lib.sh:23] | 0 on a verified **and placed** download, 1 on transport failure or mismatch, and **also 0 when the placement failed** (§6 row 8) |
| `free_gb` | [scripts/lib.sh:32] | `175.3`, with **no trailing newline** | `awk`'s status; non-zero for a failing `df` when the caller set `pipefail` |
| `require_disk` | [scripts/lib.sh:35-44] | `  PASS  disk — 175.3 GB free (floor 1 GB)` or `  FAIL  disk — 175.3 GB free < floor 99999999 GB at .`, through `ok`/`bad` | 0 / 1 |
| `once` | [scripts/lib.sh:47-51] | the sentinel file containing an RFC3339 UTC stamp, or `  ..    already done: <basename>` | 0 when skipped, otherwise its action's status |
| `shq` | [scripts/lib.sh:54-57] | `'plain'`, `'x y'`, `''` (two bytes), and `'a'\''b'` for an apostrophe | 0 |
| `bunker_exec` | [scripts/lib.sh:62-65] | nothing of its own; it re-emits the `bunker exec` argv including the joined `bash -lc` string | `bunker`'s status |

Two argument rules are part of the contract because the bytes depend on them. `ok`/`bad`/`warn` read `$1` and `$2` only — a third argument is silently dropped, measured: `ok "name" "detail" "THIRD"` prints `  PASS  name — detail`. `say`/`note` read `$*` and keep every argument. A one-argument `ok "lonely"` prints `  PASS  lonely — ` with a trailing space and a dangling em dash, and reports no error (§3 row 4).

Only `bad` increments `FAILED` anywhere in lib.sh [scripts/lib.sh:7]; `warn` deliberately does not, so a warned-about gap cannot fail a run. Outside lib.sh, two production statements write the counter, and both are consumers merging a **child's** count back in: `project-node.sh` adds the rows it greps out of the Go installer's log [scripts/project-node.sh:407] and out of the harness adapter's log [scripts/project-node.sh:458]. One test file reimplements the increment in its own local `fail()` [tests/harness/claude-code-install-test.sh:26], which is why that file's rows are not lib.sh rows.

### 2c. Consumers — both sides named

| Consumer | Sources lib.sh at | Calls (first site per helper) | What it relies on |
|---|---|---|---|
| `scripts/bunker-provision.sh` | [scripts/bunker-provision.sh:36] | `say` :178, `ok` :122, `bad` :69, `warn` :83, `note` :179, `have` :181, `shq` :422 | 28 `ok` and 50 `bad` sites; the tally at :303-304 is the run's exit status |
| `scripts/bunker-crier-connect.sh` | [scripts/bunker-crier-connect.sh:21] | `say` :35, `ok` :42, `bad` :36, `warn` :70, `have` :79 | its own `FAILED -ne 0` gate at :94 |
| `scripts/verify-node.sh` | [scripts/verify-node.sh:18] | `say` :38, `ok` :43, `bad` :44, `warn` :70, `shq` :98 | `VERIFY: FAIL ($FAILED)` plus exit 1 at :191 |
| `scripts/github-app-refresh.sh` | [scripts/github-app-refresh.sh:22] | `say` :50, `ok` :98, `bad` :57, `note` :94, `have` :118 | row text only; every refusal is an explicit `exit` |
| `scripts/install-go.sh` | [scripts/install-go.sh:5] | `ok` :77, `bad` :62, `have` :41, `require_disk` :116, `fetch_verified` :139 | `[ "$FAILED" -eq 0 ]` at :161; trusts `fetch_verified`'s status for a Go tarball |
| `scripts/project-node.sh` | [scripts/project-node.sh:35] | `say` :113, `ok` :185, `bad` :112, `warn` :346, `note` :352, `have` :306, `free_gb` :202, `require_disk` :200 | 34 `bad` sites; merges child counts at :407 and :458; exits at :826 |
| `scripts/land-node-branch.sh` | [scripts/land-node-branch.sh:27] | `say` :48, `bad` :47, `note` :105 | `[ "$FAILED" -eq 0 ]` at :255 |
| `scripts/node-create.sh` | [scripts/node-create.sh:16] | `say` :52, `ok` :101, `bad` :26, `warn` :133, `have` :91, `shq` :78 | six `shq`d values for the remote exec; `$FAILED` gate at :138 |
| `scripts/bunker-server-install.sh` | [scripts/bunker-server-install.sh:12] | `say` :20, `ok` :31, `bad` :19, `warn` :63, `have` :28, `require_disk` :70 | `RESULT: PASS` / `RESULT: FAIL ($FAILED)` at :73; note :70 is a `\|\| true` call |
| `scripts/harness/install-opencode.sh` | [scripts/harness/install-opencode.sh:9] | `say` :12, `ok` :16, `bad` :19, `warn` :22, `have` :14 | `[ "$FAILED" -eq 0 ]` at :37 |
| `scripts/harness/install-codex.sh` | [scripts/harness/install-codex.sh:42] | `say` :291, `ok` :213, `bad` :246, `warn` :237, `note` :184, `have` :133, `require_disk` :339, `fetch_verified` :358 | `[ "$FAILED" -eq 0 ]` at :505; trusts `fetch_verified`'s status for a codex tarball |
| `scripts/harness/install-hermes.sh` | [scripts/harness/install-hermes.sh:14] | `say` :215, `ok` :62, `bad` :42, `warn` :295, `note` :243, `have` :26 | `[ "$FAILED" -eq 0 ]` at :307 |
| `scripts/harness/install-claude-code.sh` | [scripts/harness/install-claude-code.sh:36] | `say` :125, `ok` :214, `bad` :191, `warn` :267, `note` :219, `have` :326 | 53 `bad` sites; documents the `have` defect in its own comment at :369 |
| `scripts/install-gitreins.sh` | [scripts/install-gitreins.sh:17] | `say` :38, `ok` :40, `bad` :41 | `[ "$FAILED" -eq 0 ]` at :79 |
| `scripts/github-app-setup.sh` | [scripts/github-app-setup.sh:30] | `say` :92, `ok` :181, `bad` :98, `warn` :201 | row text only; every refusal is an explicit `exit 1` |
| `tests/selftest.sh` | [tests/selftest.sh:5] | `say` :144, `fetch_verified` :147 and :148, `bunker_exec` + `shq` :1817 | greps the row shape at :563 and :566; copies lib.sh into fixtures at :537 and :820 |
| `tests/harness-conformance.sh` | [tests/harness-conformance.sh:27] | `say` :498, `have` :229 | `[ "$FAILED" -eq 0 ]` at :500 |
| `tests/selftest.sh` (generated fixture) | [tests/selftest.sh:553] | `. "$HERE/../lib.sh"` inside a heredoc | proves an adapter child can load the same helpers its parent loaded |

Two helpers have **no production consumer**: `once` [scripts/lib.sh:47] and `bunker_exec` [scripts/lib.sh:62]. A repo-wide grep finds no call site outside comments that happen to contain the word "once", plus the one fixture that exercises `bunker_exec` under a stub `bunker` [tests/selftest.sh:1817]. Their contracts above are therefore measured, not relied upon.

### 2d. Peers — both sides named

| Peer | Direction | Transport | Payload | Other side |
|---|---|---|---|---|
| `bunker` CLI | lib.sh → network | argv: `bunker exec --server <s> <agent> -- bash -lc "<joined args>"` [scripts/lib.sh:64] | one command **string**, so the caller must `shq` every data value it interpolates (fact: FACT-05 is the rule that keeps credentials off this path) | the `bunker` client on `PATH`; no production caller — the fixture is [tests/selftest.sh:1817] |
| the pinned artifact's origin | lib.sh ← network | `curl -fsSL --max-time 120 -o <tmp> <url>` [scripts/lib.sh:19], then `sha256sum` and `cut` on the temp file [scripts/lib.sh:20] | artifact bytes in, 64-hex digest compared to `want` | `scripts/install-go.sh` for the Go tarball [scripts/install-go.sh:139]; `scripts/harness/install-codex.sh` for the codex tarball [scripts/harness/install-codex.sh:358] — both pin the digest in their own file |
| the host filesystem | lib.sh ← kernel | `df -Pk <path>`, field 4 in KB divided by 1048576, one decimal [scripts/lib.sh:32] | free space in GB | `require_disk` callers: [scripts/install-go.sh:116], [scripts/harness/install-codex.sh:339], [scripts/project-node.sh:200] |
| the calling shell itself | lib.sh ↔ consumer | one variable, `FAILED` [scripts/lib.sh:11] | an integer | every consumer's final test, e.g. [scripts/bunker-provision.sh:304], [scripts/verify-node.sh:191], [scripts/project-node.sh:826] |

## 3. Verification

Measured 2026-11-05 in this worktree at `b31c232`, with `PATH` reset to `/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin` so no leftover fixture stub could shadow `curl`.

| # | Check | Command | Expected | Result |
|---|---|---|---|---|
| 1 | parses | `bash -n scripts/lib.sh` | rc 0, no output | **PASS** — rc 0 |
| 2 | static analysis | `shellcheck -S style scripts/lib.sh` (ShellCheck 0.11.0) | rc 0, no findings | **PASS** — rc 0, silent |
| 3 | one PASS row, exact bytes | `bash -c '. scripts/lib.sh; ok "disk" "12.0 GB free"' \| od -An -tx1` | `20 20 50 41 53 53 20 20`, name, `20 e2 80 94 20`, detail, `0a` | **PASS** — ` 20 20 50 41 53 53 20 20 64 69 73 6b 20 e2 80 94` / ` 20 31 32 2e 30 20 47 42 20 66 72 65 65 0a` |
| 4 | all five printers, whitespace visible | `cat -A` over `say`, `ok`, `bad`, `warn`, `note` | the five shapes in §2b, `$` at each line end, em dash as `M-bM-^@M-^T` | **PASS** — `one two$`, `  PASS  disk M-bM-^@M-^T 12.0 GB free$`, `  FAIL  crier_url M-bM-^@M-^T CRIER_URL unset$`, `  WARN  chrome M-bM-^@M-^T not on PATH$`, `  ..    already done: marker$` |
| 5 | counter ownership | `FAILED=0`, then `ok`, `warn`, `note`, `say`, `bad`, `bad`, printing `$FAILED` and `$?` after each | only `bad` moves the counter; every helper returns 0 | **PASS** — `ok 0`, `warn 0`, `note 0`, `say 0`, `bad → 1`, `bad → 2`; `bad rc=0`, so `bad … \|\| { … }` printed `fell through, still running` |
| 6 | `have` cannot fail | `have not-a-real-binary-xyz; echo $?`, then `if have not-a-real-binary-xyz; then …` | rc 0, empty output, `if` branch taken | **PASS (defect confirmed)** — `have(missing) rc=0`, empty output, `GOTCHA: have(missing) is TRUE in an if` |
| 7 | `require_disk` both directions | floor 1 on `.`; floor 99999999 on `.`; on `/nonexistent-path-xyz`; floor `abc` | pass at 175.3 GB, fail above the floor, fail on an unstat-able path, fail on a non-numeric floor | **PASS** — `  PASS  disk — 175.3 GB free (floor 1 GB)`; `  FAIL  disk — 175.3 GB free < floor 99999999 GB at .` rc 1; `  FAIL  disk —  GB free < floor 1 GB at /nonexistent-path-xyz` rc 1; `  FAIL  disk — 174.7 GB free < floor abc GB at .` rc 1 |
| 8 | `fetch_verified`, good and bad digest | correct digest, wrong digest, missing source, all against `file://` URIs | 0 and the file; 1, no file, both digests on stderr; 1 | **PASS** — rc 0 with `-rwx--x--x out/sub/art.txt`; rc 1 with `digest mismatch for file:///…/art.txt: want 000…000 got d4e4877b…` and `dest NOT created`; rc 1 with `curl: (37) Could not open file /nonexistent/xx` |
| 9 | `fetch_verified` when the destination cannot be created | `chmod 500` a directory, then fetch a correct digest underneath it | rc 1, no file | **FAIL — the module returns 0 where the contract requires 1** (defect, §6 row 8): `mkdir: Permission denied`, `mv: cannot move … No such file or directory`, then `RC=0` |
| 10 | `once` skip and failure | `once ./sent/marker say "work ran"`, again, then `once ./sent2/marker false` | runs and stamps; notes `already done`; writes no sentinel when the action fails | **PASS** — `work ran` with sentinel `2026-11-05T16:40:30Z`; second call `  ..    already done: marker`; failing action rc 1 and `sentinel NOT written` |
| 11 | `shq` escaping | `shq ""`, `shq "plain"`, `shq "x y"`, `shq "a'b"` | `''`, `'plain'`, `'x y'`, `'a'\''b'` | **PASS** — exactly those, the empty value measured as the two bytes `' '` by `od -c` |
| 12 | `bunker_exec` argv | stub `bunker` first on `PATH`, `bunker_exec cf-node cf-node "echo hi" "&&" "echo there"` | one `bash -lc` argv element carrying `echo hi && echo there` | **PASS** — `ARGV: [exec] [--server] [cf-node] [cf-node] [--] [bash] [-lc] [echo hi && echo there]` |
| 13 | counter does not cross a subshell or a pipe | `( bad a b ); echo $FAILED` and `bad a b \| cat; echo $FAILED` | the row prints, the parent reads 0 | **PASS** — `parent FAILED after subshell=0`, `parent FAILED after pipe=0` |
| 14 | dependencies absent | strip `mktemp`, then `sha256sum`, from `PATH` and call `fetch_verified` | closed (rc 1, nothing placed) in both cases | **PASS** — no `mktemp`: `curl` usage error, rc 1, no file; no `sha256sum`: `digest mismatch for …: want d4e4877b… got ` rc 1, no file |
| 15 | repo regression test for the row shape | `tests/selftest.sh` §14 "harness-adapter FAIL rows are counted in the node summary (CF-055)" [tests/selftest.sh:528] | a child's `bad` rows must appear in the parent's `NODE: FAIL (n)` | **present, not re-run in this tick** — the arm greps `^  FAIL` [tests/selftest.sh:563] and the literal row [tests/selftest.sh:566]; the full battery is a separate, network-dependent run |
| 16 | repo regression test for the digest | `tests/selftest.sh` §5 "fetch_verified refuses a wrong digest" [tests/selftest.sh:144] | correct digest accepted, `000…` refused [tests/selftest.sh:147] [tests/selftest.sh:149] | **present, not re-run in this tick** — row 8 above measures the same two branches directly |

## 4. Metrics emitted

**None, and the reason is structural rather than an omission.** lib.sh writes no metric file, no counter file and no line protocol. The only mutations it performs outside its own `printf`s are `mktemp`/`mv`/`chmod` inside `fetch_verified` [scripts/lib.sh:18-28] and the `once` sentinel [scripts/lib.sh:50]. The single aggregate is `FAILED`, an integer in the calling shell's memory [scripts/lib.sh:11], which dies when that process exits and does not survive a subshell or a pipe (§3 row 13).

The only cross-process signal this module produces is the free-text summary each consumer prints: `BUNKER: PASS — every row above measured` or `BUNKER: FAIL ($FAILED)` [scripts/bunker-provision.sh:303], `NODE: PASS` or `NODE: FAIL ($FAILED)` [scripts/project-node.sh:826], `VERIFY: FAIL ($FAILED)` [scripts/verify-node.sh:191], `HARNESS CONFORMANCE: PASS` or `HARNESS CONFORMANCE: FAIL ($FAILED)` [tests/harness-conformance.sh:500]. Each carries one count and a name; none carries per-row identity in a parseable form. From logs alone a reader therefore cannot answer: how many distinct rows a run had, which named rows failed on which host over time, or how long any check took. The nearest thing to a machine-readable metric is a consumer counting `grep -c '^  FAIL'` over a captured log [scripts/project-node.sh:455] — a count of lines whose format this file defines, which is exactly why the format is the contract.

## 5. Log lines it can generate

The level column is the row tag, not a severity the module assigns; lib.sh has no vocabulary beyond these four prefixes.

| Level | Line (verbatim, as measured) | Format site | Emitted when | Kind |
|---|---|---|---|---|
| `–` | `one two` | [scripts/lib.sh:5] | any `say` — the caller's own sentence | descriptive |
| `PASS` | `  PASS  disk — 12.0 GB free` | [scripts/lib.sh:6] | any consumer's green row | descriptive |
| `FAIL` | `  FAIL  crier_url — CRIER_URL unset` | [scripts/lib.sh:7] | any consumer's red row; the only line that moves the counter | descriptive |
| `WARN` | `  WARN  chrome — not on PATH` | [scripts/lib.sh:8] | a gap the caller chose not to fail on | descriptive |
| `..` | `  ..    already done: marker` | [scripts/lib.sh:9] | context, or an idempotent skip | descriptive |
| `PASS` | `  PASS  disk — 175.3 GB free (floor 1 GB)` | [scripts/lib.sh:39] | `require_disk` found the floor satisfied — carries the measured number | evidentiary |
| `FAIL` | `  FAIL  disk — 175.3 GB free < floor 99999999 GB at .` | [scripts/lib.sh:41] | `require_disk` found the floor violated — carries the number, the floor and the path | evidentiary |
| `–` (stderr) | `digest mismatch for file:///home/kara/.hermes/cache/scratch/md22/art.txt: want 0000000000000000000000000000000000000000000000000000000000000000 got d4e4877bac978b7952f0d544fc52ebff5411d351d129f1f056fa43f11da9af2b` | [scripts/lib.sh:23] | a pinned download hashed to something other than `want` — carries both digests, so the verdict can be re-derived | evidentiary |
| `..` | `  ..    already done: marker` | [scripts/lib.sh:49] | `once` found its sentinel; the basename is the evidence of what was skipped | descriptive |
| `PASS` | `BUNKER: PASS — every row above measured` | [scripts/bunker-provision.sh:303] | that consumer's own verdict, driven by `$FAILED` | descriptive — a claim about rows, not a measurement |
| `FAIL` | `BUNKER: FAIL ($FAILED)` (the literal source string; the counter is substituted at print time) | [scripts/bunker-provision.sh:303] | same, when the counter is non-zero | evidentiary — the count is checkable against the rows printed above it |
| `PASS` | `NODE: PASS` | [scripts/project-node.sh:826] | the node adapter's own verdict | descriptive |
| `FAIL` | `NODE: FAIL ($FAILED)` | [scripts/project-node.sh:826] | same, with the counter; `selftest.sh` reconciles this number against the printed rows [tests/selftest.sh:563] | evidentiary |
| `PASS` | `HARNESS CONFORMANCE: PASS` | [tests/harness-conformance.sh:500] | the battery's own verdict | descriptive |

The distinction is not pedantry: a `descriptive` row is the caller's assertion about a value it may never have measured, while the `evidentiary` rows either contain the number they are judging (`require_disk`), both halves of a hash comparison (`fetch_verified`), or a count that can be reconciled line-by-line against the rows above it (the `($FAILED)` summaries).

## 6. Failure modes

Direction is stated as "does the run end up green when it should not".

| Failure | Presents as | Direction | Distinguished from / recovery |
|---|---|---|---|
| 1. lib.sh not sourced or not present (`$HERE` wrong, file not staged) | `bunker-provision.sh: line 36: …/lib.sh: No such file or directory`, then `…: line 122: ok: command not found`; measured exit 1, **no rows at all** | **fails OPEN on evidence, closed on status** — the process exits non-zero for an unrelated reason, so a wrapper grepping stdout for `BUNKER: PASS` finds nothing rather than something wrong. The silence is the tell | distinguish a clean run by the missing summary line, never by the exit code. `bash -n` on the consumer does not catch it, because the `.` is runtime. Recovery: assert the summary line exists |
| 2. `bad` called inside `( … )` or on the left of a pipe | the red rows print, the parent's `$FAILED` stays 0, the summary says PASS | **fails OPEN — green summary over red rows.** Measured: `( bad a b ); echo $FAILED` → `0`, `bad a b \| cat` → `0`. Live instance: the `--apply` preflight runs as `( check >/dev/null 2>&1 ) \|\| note "…"` [scripts/bunker-provision.sh:617], so its failures are neither printed nor counted, and `note` does not touch the counter [scripts/lib.sh:9] | this is the hazard `project-node.sh` repaired explicitly by grepping the child's log and adding the count back [scripts/project-node.sh:455-458], with `selftest.sh` §14 as the regression test [tests/selftest.sh:528]. Recovery: never read `$FAILED` for work done in a subshell — count rows out of a captured log |
| 3. a caller writes `bad "x" "why" \|\| exit 1` | the branch never runs; the script continues past a red row | **fails OPEN.** Measured: `bad rc=0`, and `bad x y \|\| { … }` printed `fell through, still running`. Cause: the last command in `bad` is an assignment, which returns 0 [scripts/lib.sh:7] | the same trap under `set -e`: `set -eu` plus `bad a b` does **not** abort — measured. Recovery: `bad …` and `exit 1` on separate lines, or test `$FAILED` |
| 4. `have <x>` used as a presence test | never reports absence: `if have x` is always true, and `$(have x)` is empty but its status is 0 | **fails OPEN.** Measured: `have(missing) rc=0`. Live dead branch: `b=$(have bunker) \|\| { bad "identity" "no bunker client on PATH"; return 1; }` [scripts/bunker-crier-connect.sh:79] can never print that row, so a host without `bunker` fails later as an empty `$b` instead of as the named row | the repo already knows: `install-claude-code.sh` says so in a comment at [scripts/harness/install-claude-code.sh:369] and tests the path instead. Recovery: `p=$(have x); [ -n "$p" ] \|\| bad …`, the pattern at [scripts/project-node.sh:331] |
| 5. a third argument to `ok`/`bad`/`warn` | the detail prints without it, silently | **fails OPEN on content** — a multi-part detail loses text and the row still looks complete. Measured: `ok "name" "detail" "THIRD"` → `  PASS  name — detail` | `note` and `say` keep every argument, so the same habit is harmless there and dangerous in a row |
| 6. `ok "name"` with no detail | `  PASS  lonely — ` — trailing space, dangling em dash, exit 0 | cosmetic, **fails OPEN**: a row that says nothing still counts as green | no error is raised; `printf` supplies the empty `%s` [scripts/lib.sh:6] |
| 7. `FAILED` unset while `set -u` is on | the row prints, then `scripts/lib.sh: line 7: FAILED: unbound variable`, and a non-interactive shell aborts with 1 | **fails CLOSED, mid-row** — the row is printed and the count is lost; a caller that unsets `FAILED` after sourcing loses the counter for the rest of the run | lib.sh initialises it on source (`FAILED=${FAILED:-0}`) [scripts/lib.sh:11], so this needs a consumer to unset it afterwards. Measured: `set -u; unset FAILED; bad x y` → row, then error, rc 1 |
| 8. `fetch_verified` cannot place the file (destination unwritable, `mkdir` denied, `mv` refused) | `mkdir: Permission denied`, `mv: cannot move … No such file or directory`, and the function **returns 0** | **fails OPEN — the worst direction in this file**: the caller is told a digest-verified artifact was installed when nothing exists at `dest`. Cause: `mkdir` and `mv` are unchecked and the last statement is `chmod … \|\| true` [scripts/lib.sh:26-28] | measured on an unmodified `PATH` with a `chmod 500` directory: `RC=0`, `ls: cannot access …`. Both callers branch on this status [scripts/install-go.sh:139] [scripts/harness/install-codex.sh:358], so a failed install surfaces later as a missing binary. Distinguish it from a verification failure by testing `dest` itself after the call, since the status is identical. Recovery: `fetch_verified … && [ -x "$dest" ]` |
| 9. `fetch_verified` digest mismatch | `digest mismatch for <url>: want … got …` on stderr, nothing at `dest`, rc 1 | **fail-closed on integrity** — the artifact is never placed | distinguish a mismatch from a transport failure by the message prefix: `curl:` for transport, `digest mismatch` for the hash. Callers branch on the status, never on the text [scripts/install-go.sh:139] |
| 10. `fetch_verified` succeeds | the artifact at `dest` with mode `-rwx--x--x` | **fails OPEN on permissions** — `mktemp`'s 600 plus `chmod +x` grants execute and traverse to group and other [scripts/lib.sh:28] | measured `-rwx--x--x`; integrity is unaffected, so a caller that cares must `chmod` afterwards |
| 11. `require_disk` with a non-numeric floor, or an unstat-able path | `  FAIL  disk — 174.7 GB free < floor abc GB at .`, or `  FAIL  disk —  GB free < floor 1 GB at /nonexistent-path-xyz`, rc 1 | **fails CLOSED** — a typo'd floor and a broken `df` both refuse rather than admit | the one helper whose direction is safe by construction: `awk` evaluates `f>=m` and both an empty `f` and a non-numeric `m` fall to the false branch [scripts/lib.sh:38] |
| 12. `shq` fed a value containing a newline | the value is quoted correctly, with the newline preserved inside the quotes | neither — quoting is right for a shell word; a consumer that splits on newlines downstream is the bug | `selftest.sh` pins exactly that shape, `"line\n'\\$();\n"`, through `bunker_exec` [tests/selftest.sh:1817] |

## 7. Environment and settings it reads

- **`FAILED`** — the only variable lib.sh reads [scripts/lib.sh:11]. `${FAILED:-0}` makes an unset value zero, and an inherited or pre-set value is **preserved**: measured, `FAILED=7` before sourcing stayed `7`, and one `bad` made it `8`. The test battery relies on that inheritance by passing `FAILED=0` into a child script's environment [tests/selftest.sh:428] [tests/selftest.sh:1339].
- **`PATH`** — `mktemp`, `curl`, `sha256sum`, `cut`, `mkdir`, `mv`, `chmod`, `df`, `awk`, `date`, `dirname`, `basename` and `bunker` are all invoked by bare name [scripts/lib.sh:18-20] [scripts/lib.sh:26-28] [scripts/lib.sh:32] [scripts/lib.sh:49-50] [scripts/lib.sh:64]. Nothing resolves them to an absolute path and nothing verifies them, so the first entry wins. Measured the hard way during this tick: a stale fixture directory left on `PATH` by an earlier session served a stub `curl` and made a correct `file://` download hash to the empty string — a false `digest mismatch` that no line in lib.sh could explain. Probes here therefore reset `PATH` explicitly.
- **Streams** — row text goes to **stdout** (`say`/`ok`/`bad`/`warn`/`note`, [scripts/lib.sh:5-9]); the digest mismatch is the one line written to **stderr** [scripts/lib.sh:23]. Measured: redirecting stdout to `/dev/null` hides every row while `$FAILED` still increments; redirecting stderr hides the mismatch reason while the status stays 1. A `2>&1` capture, which is what the tests use [tests/selftest.sh:562], is the only way to see both.
- **No colour and no TTY detection.** The file contains no `tput`, no ANSI escape, no `TERM` or `NO_COLOR` lookup and no `[ -t 1 ]` test; its only expansions are `FAILED` and the positional parameters. Measured: a `cat -A` capture of a redirected row shows the same bytes a terminal receives, `  PASS  disk M-bM-^@M-^T 12.0 GB free$`. Rows can be committed to a log without stripping anything.
- **`bash` required** [scripts/lib.sh:1] [scripts/lib.sh:3] — the pattern-replacement form in `shq` [scripts/lib.sh:55] and `local` throughout are not POSIX `sh`.
- **Nothing else.** No config file, no default value, no option flag, no locale handling. `free_gb` formats with `awk`'s `%.1f` [scripts/lib.sh:32] and lib.sh never sets or reads `LC_*`; on a host whose numeric locale used a decimal comma the value would be `175,3` and `require_disk`'s comparison would fall to its refuse branch. That locale is not installed here, so it was not measured — the failure direction would be closed.

## 8. Evidence of record

- Revision: worktree `/home/kara/proj-wt-md-22c`, branch `wt/md-22c`, based on `origin/main` at `b31c232`. `scripts/lib.sh` is byte-identical to the tree the probes ran in (`diff -q` → no output).
- Byte capture behind §2b and §3 rows 3-4, in a scratch shell with `PATH` reset:

  ```
  $ bash exercise.sh          # sources scripts/lib.sh; pipes each printer through cat -A
  one two$
    PASS  disk M-bM-^@M-^T 12.0 GB free$
    FAIL  crier_url M-bM-^@M-^T CRIER_URL unset$
    WARN  chrome M-bM-^@M-^T not on PATH$
    ..    already done: marker$
  FAILED=0
  $ bash -c '. scripts/lib.sh; ok "disk" "12.0 GB free"' | od -An -tx1
   20 20 50 41 53 53 20 20 64 69 73 6b 20 e2 80 94
   20 31 32 2e 30 20 47 42 20 66 72 65 65 0a
  ```

  The trailing `FAILED=0` is itself the measurement in §3 row 13: those five rows were emitted through pipelines, so the `FAIL` row printed and the parent shell's counter never moved. Leading indent is two bytes (`20 20`), the gap after `PASS` is two bytes (`20 20`), and the separator is `e2 80 94`.
- Counter ownership, the probe behind §2b's last paragraph and §6 rows 2-3:

  ```
  $ bad "c" "3"; echo rc=$? FAILED=$FAILED
    FAIL  c — 3
  rc=0 FAILED=1
  $ ( bad "inner" "row" ); echo "parent after subshell=$FAILED"
    FAIL  inner — row
  parent after subshell=0
  $ bad "piped" "row" | cat; echo "parent after pipe=$FAILED"
    FAIL  piped — row
  parent after pipe=0
  ```
- The absent-`lib.sh` experiment, which corrects the received claim quoted in §1. `bunker-provision.sh` plus a two-line config in a directory containing no `lib.sh`:

  ```
  $ bash bunker-provision.sh --config cf-bunker.conf --check; echo EXIT=$?
  bunker-provision.sh: line 36: …/nolib/lib.sh: No such file or directory
  bunker-provision.sh: line 122: ok: command not found
  EXIT=1
  ```
- The fail-open install path, §6 row 8, on an unmodified `PATH`:

  ```
  $ chmod 500 ro; bash -c '. scripts/lib.sh; fetch_verified "file://…/art.txt" "…/ro/sub/art.txt" d4e4877…; echo RC=$?'
  mkdir: Permission denied
  mv: cannot move '/home/kara/.hermes/cache/scratch/md25b/tmp.K63kxk0xxB' to '…/ro/sub/art.txt': No such file or directory
  RC=0
  $ ls -l …/ro/sub/art.txt
  ls: cannot access '…/ro/sub/art.txt': No such file or directory
  ```
- Regression tests of record for this contract, present in the tree and not re-run in this tick: `tests/selftest.sh` §5 [tests/selftest.sh:144] (digest both ways) and §14 [tests/selftest.sh:528] (a child's `bad` rows must reach the parent summary). Both are re-runnable, and both fail if the row shape or the counter contract changes; the shape they assert is `  FAIL  harness:fixture/a — simulated adapter failure one` [tests/selftest.sh:566].
- Standing rule this section obeys: a row closes only with a command that can be re-run, never with a commit message (fact: FACT-10).
- Re-running §3: rows 1-14 are single `bash` invocations in a scratch directory with `PATH` set explicitly; rows 15-16 are `bash tests/selftest.sh`, a long battery with network-dependent legs.
