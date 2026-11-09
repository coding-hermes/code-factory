# 18. scripts/harness/install-opencode.sh

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/harness/install-opencode.sh` — 37 lines [scripts/harness/install-opencode.sh:37] |
| Repository | `code-factory` [scripts/harness/install-opencode.sh:1] |
| Revision | `b31c232` — the `origin/main` tip every locator below was measured against; the file's last-touching commit is `d948c16` (2026-10-29, "feat: code-factory node ladder, specs and board") |
| Status | **RED — the adapter installs nothing (`--apply` refuses by design) and its `non_interactive` row cannot pass on a host that has the capability: CF-240 is live at [scripts/harness/install-opencode.sh:25]. Every claim in this document is measured on `b31c232`; the RED is the module's, not the document's.** |

## 1. Purpose and why it matters

- What it is: a **check-only adapter**, not an installer. Its own header says `UNVERIFIED` and promises that `--apply` is refused [scripts/harness/install-opencode.sh:2-6]; the refusal is the whole apply path [scripts/harness/install-opencode.sh:31-34]. There is no download, no pin, no digest and no version selection anywhere in the file.
- Why it matters: layer 20 of node provisioning runs `harness/install-$HARNESS.sh` with `--check` or `--apply`, echoes its output and folds every `  FAIL` row into the node's own counter [scripts/project-node.sh:440-458]. `node-create.sh` stages exactly that file, and its `../lib.sh`, onto the node [scripts/node-create.sh:23] [scripts/node-create.sh:29-38]. Without the adapter, `--harness opencode` stops at layer 20 with `bad "harness:opencode" "no adapter at scripts/harness/install-$HARNESS.sh"` [scripts/project-node.sh:441-442] — provisioning still fails, but it fails naming the missing file, which is the right failure.
- Its stated contract is the spec's four properties a foreign harness must gain: a TTY-free directive, a machine-readable completion, a deterministic workspace, and a login-free version probe [specs/HARNESS.md:70-76]. This adapter probes **one** of them — a non-interactive mode [scripts/harness/install-opencode.sh:25] — and, measured below, reports it wrongly on a host that has it. `version` [scripts/harness/install-opencode.sh:17] covers property 4. Properties 2 and 3 are not measured at all.
- What breaks if it lies: nothing downstream re-derives its rows. `warn` does not touch `FAILED` [scripts/lib.sh:8] while `bad` increments it [scripts/lib.sh:7], so the adapter prints `OPENCODE: PASS` and exits 0 [scripts/harness/install-opencode.sh:36-37] on a host where it could not confirm the capability. Node provisioning reads only the exit code and the `  FAIL` rows [scripts/project-node.sh:455-458], so a wrong `WARN` is structurally invisible to it.
- What breaks if it is absent: nothing claims to install opencode, so nothing regresses — which is the point. The sibling codex adapter has a digest-refusing download ladder in the very library this file sources [scripts/lib.sh:16-29]; this file never calls `fetch_verified`.
- Blast radius: one node, one harness name. The single argument is a mode string [scripts/harness/install-opencode.sh:11]; the only state it mutates is `FAILED` inside its own process [scripts/lib.sh:11]; it writes no file.

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `bash` | ≥4 — `${1:---check}` and `$((…))` only [scripts/harness/install-opencode.sh:1] | the node, via `#!/usr/bin/env bash` [scripts/harness/install-opencode.sh:1] | the kernel's `127` before the script runs; nothing inside it |
| `scripts/lib.sh` | repo HEAD, resolved from the script's own directory [scripts/harness/install-opencode.sh:8-9] | `$HERE/../lib.sh`, and `node-create.sh` rewrites that reference for the staged copy [scripts/node-create.sh:29-38] | **Measured, not detected by the script**: sourcing prints `/…/lib.sh: No such file or directory`, every helper then prints `command not found`, and the run dies at the summary with `FAILED: unbound variable` (exit 1). The script names no file and prints no `FAIL` row (§3 row 8) |
| `opencode` on `PATH` | **no pin** — whatever `command -v` resolves [scripts/lib.sh:41-45] | `PATH` [scripts/harness/install-opencode.sh:14] | `bad "binary" "absent — no opencode in this node"` [scripts/harness/install-opencode.sh:19], `FAILED+1`, exit 1 |
| `$HOME/.opencode/bin/opencode` | any executable bit | the user-space install path [scripts/harness/install-opencode.sh:22] | `warn "user_space_binary"` only [scripts/harness/install-opencode.sh:22] — this row can never fail a run |
| `grep`, `head` | coreutils / grep | `PATH` [scripts/harness/install-opencode.sh:17] [scripts/harness/install-opencode.sh:25] | not detected: a missing `grep` makes the `if` false → `WARN`; a missing `head` yields a `PASS version — ` with an empty value, which the conformance battery rewrites to FAIL [tests/harness-conformance.sh:216-221] |
| the `run` subcommand of `opencode` | ≥1.18.29 measured here (§3 row 3) | provided by the binary, never by this file | **cannot be detected on this host**: the probe reads stdout while the advertisement is on stderr [scripts/harness/install-opencode.sh:25] |

### 2b. Library contracts

`scripts/lib.sh` is the only library. There are no `import`s; the contract is six shell symbols.

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `say` [scripts/lib.sh:5] | lib.sh | `printf '%s\n'` of one line — header and trailer text | nothing parses `say`; a change is cosmetic |
| `ok` [scripts/lib.sh:6] | lib.sh | exactly `  PASS  <name> — <value>`: two leading spaces, two after `PASS`, em dash | the conformance battery greps `  PASS  ` and splits on ` — ` to quote a value [tests/harness-conformance.sh:110-126]; a reworded prefix makes every row unquotable and the battery reports `adapter exited 0 but printed no PASS row to quote` [tests/harness-conformance.sh:227] |
| `bad` [scripts/lib.sh:7] | lib.sh | the same shape plus `FAILED=$((FAILED+1))` | `project-node.sh` counts lines matching `^  FAIL` and adds that count to its own `FAILED` [scripts/project-node.sh:455-458]; a different prefix silently under-counts the node's exit summary |
| `warn` [scripts/lib.sh:8] | lib.sh | `  WARN  <name> — <value>` and **no counter** | a `WARN` can never fail a run. That is the mechanism behind both §6 rows 1-2, and it is a property of the library, not of this adapter |
| `have` [scripts/lib.sh:41-45] | lib.sh | `command -v "$1"` and the path on stdout, else empty output **and a non-zero status** (CF-281) | `binary` and `non_interactive` both depend on the caller's `PATH`, not on the user-space path the next row checks [scripts/harness/install-opencode.sh:14] [scripts/harness/install-opencode.sh:25] |
| `FAILED` [scripts/lib.sh:11] | lib.sh | initialised to 0 if unset; incremented in-process | `project-node.sh` treats the adapter as a child and re-counts `  FAIL` rows precisely because this counter cannot cross the process boundary [scripts/project-node.sh:444-447] |

### 2c. Service contracts (both sides must be named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| `project-node.sh` layer 20 | parent → child process | `"$inst" --check` or `"$inst" --apply`, `NODE_GATEWAY_PORT` in the environment, stdout+stderr captured to a temp file and re-printed [scripts/project-node.sh:448-457] | stdout rows and an exit code; the parent additionally greps `^  FAIL` [scripts/project-node.sh:455] | adapter side [scripts/harness/install-opencode.sh:11] [scripts/harness/install-opencode.sh:37]. The adapter **never reads `NODE_GATEWAY_PORT`** — measured: zero occurrences in the file |
| `tests/harness-conformance.sh` `leg_check` | battery → adapter | `bash "$path" --check 2>&1`, exit code read [tests/harness-conformance.sh:213] | every `PASS` row must carry a measured value [tests/harness-conformance.sh:216-221]; the `version` value is what gets quoted [tests/harness-conformance.sh:224-227] | adapter side [scripts/harness/install-opencode.sh:16-17] |
| the same battery's generation gate | battery → adapter | the battery runs `--version` **itself** and compares the major against the table's generation column [tests/harness-conformance.sh:228-237] | one adapter serves both `opencode` (gen 1) and `opencode-v2` (gen 2) [tests/harness-conformance.sh:92-93] | adapter side: **no generation concept exists**. The gate is the only place a v2 request is refused, and it refuses by naming the adapter's fault (§3 row 7) |
| adapter → `opencode` CLI | caller → binary | `"$p" --version 2>/dev/null \| head -1` [scripts/harness/install-opencode.sh:17]; `"$p" --help 2>/dev/null \| grep -qi` [scripts/harness/install-opencode.sh:25] | version on **stdout** (8 B measured); help on **stderr** (4 285 B measured) | binary side, measured: `opencode --help` exits 0 with 0 B on fd 1 and 4 285 B on fd 2 (§3 row 3) |
| `node-create.sh` staging | control host → node | copies `harness/install-$HARNESS.sh` into the node's `node-scripts` set [scripts/node-create.sh:23] and rewrites the `../lib.sh` reference in the staged pair [scripts/node-create.sh:29-38] | two files on the node | the staged copy is what `project-node.sh` executes; a green run in this worktree proves nothing about the pair that lands on a node |

## 3. Verification

Run on `b31c232`, 2026-11-05, bash 5.3.9, `opencode` 1.18.29 at `/home/kara/.opencode/bin/opencode`. Rows 1-2 differ only in how the caller was launched, and that is the point.

| # | Check | Command | Expected | Last run | Result |
|---|---|---|---|---|---|
| 1 | `--check` with the user-space path on `PATH` | `bash scripts/harness/install-opencode.sh --check` [scripts/harness/install-opencode.sh:11-37] | 3 PASS + 1 WARN, `OPENCODE: PASS`, exit 0 | 2026-11-05 | **PASS — and the WARN is false; see row 3** |
| 2 | the same check from a shell whose `PATH` lacks `~/.opencode/bin` | `bash -c 'bash scripts/harness/install-opencode.sh --check'` [scripts/harness/install-opencode.sh:14] | internally consistent rows | 2026-11-05 | **PASS (measured) — and self-contradictory: `FAIL binary` next to `PASS user_space_binary` for the same file, exit 1** |
| 3 | the stream split behind CF-240 | `opencode --help >o 2>e`; `opencode run --help >r 2>s` [scripts/harness/install-opencode.sh:25] | the help text is somewhere greppable | 2026-11-05 | **CONFIRMED: help is stderr-only (0 B stdout / 4 285 B stderr); the adapter's exact pipeline is NOMATCH, the same pipeline with `2>&1` is MATCH** |
| 4 | `--apply` | `bash scripts/harness/install-opencode.sh --apply` [scripts/harness/install-opencode.sh:31-34] | one `FAIL apply` refusal, exit 1 | 2026-11-05 | **PASS — refuses, names `specs/HARNESS.md` as the place to record a ladder, installs nothing** |
| 5 | `--help` | `bash scripts/harness/install-opencode.sh --help` [scripts/harness/install-opencode.sh:11] | usage text | 2026-11-05 | **FAIL (measured): there is no help path. `--help` falls through to the check and exits 0** |
| 6 | an unknown mode | `bash scripts/harness/install-opencode.sh --appply` [scripts/harness/install-opencode.sh:11] | a refusal naming the argument | 2026-11-05 | **FAIL (measured): byte-identical to row 1, exit 0 — a typo in a `--apply` call reads as a green check** |
| 7 | a v2 request through the battery's own gate | `PATH=~/.opencode/bin:$PATH bash tests/harness-conformance.sh --only opencode-v2` [tests/harness-conformance.sh:228-237] | FAIL for the generation, SKIP for the turn | 2026-11-05 | **PASS — the battery refuses v2 and names the adapter's missing gate; the adapter itself has none** |
| 8 | a missing `scripts/lib.sh` | the adapter copied alone into an empty tree and run there [scripts/harness/install-opencode.sh:9] | a named failure | 2026-11-05 | **FAIL (measured): `command not found` ×6, then `FAILED: unbound variable`, exit 1, no `FAIL` row** |
| 9 | what npm calls a v2 | `curl -s https://registry.npmjs.org/opencode2`; `…/opencode-ai/latest` [specs/HARNESS-MATRIX.md:194] | nothing installable | 2026-11-05 | **CONFIRMED: `opencode2` is a `security holding package`, versions `0.0.0-stage` and `0.0.1-security`, latest `0.0.1-security`; `opencode-ai@latest` is `1.19.5`** |
| 10 | the test file the module brief names | `tests/harness/vars-test.sh` on this base | a runnable test | 2026-11-05 | **ABSENT on `origin/main`. It exists only on the unmerged branch `wt/cf-vars` (commit `5764b24`, "one CF_* contract … 57 standalone checks"), which is not an ancestor of `origin/main`. The two tests in that directory here are for claude-code and codex** [tests/harness/claude-code-install-test.sh:1-4] |

Rows 1 and 2, verbatim:

```
$ bash scripts/harness/install-opencode.sh --check      # PATH includes ~/.opencode/bin
harness: opencode (UNVERIFIED adapter)
  PASS  binary — /home/kara/.opencode/bin/opencode
  PASS  version — 1.18.29
  PASS  user_space_binary — /home/kara/.opencode/bin/opencode
  WARN  non_interactive — could not confirm a non-interactive mode

OPENCODE: PASS
exit=0
```

```
$ bash -c 'bash scripts/harness/install-opencode.sh --check'   # default PATH
harness: opencode (UNVERIFIED adapter)
  FAIL  binary — absent — no opencode in this node
  PASS  user_space_binary — /home/kara/.opencode/bin/opencode
  WARN  non_interactive — could not confirm a non-interactive mode

OPENCODE: FAIL (1)
exit=1
```

Row 3, the measurement that decides CF-240:

```
$ opencode --help >o 2>e; echo "rc=$?"; wc -c o e
rc=0
0 o
4285 e
$ opencode --help 2>/dev/null | grep -qi 'run\|exec\|serve' && echo MATCH || echo NOMATCH
NOMATCH
$ opencode --help 2>&1 | grep -qi 'run\|exec\|serve' && echo MATCH || echo NOMATCH
MATCH
$ opencode run --help >r 2>s; echo "rc=$? stdout=$(wc -c <r) stderr=$(wc -c <s)"
rc=0 stdout=0 stderr=3053
```

The capability is advertised in that stderr stream, in the command list:

```
Commands:
  opencode completion          generate shell completion script
  opencode acp                 start ACP (Agent Client Protocol) server
  opencode mcp                 manage MCP (Model Context Protocol) servers
  opencode [project]           start opencode tui                                          [default]
  opencode attach <url>        attach to a running opencode server
  opencode run [message..]     run opencode with a message
```

**CF-240 verdict — LIVE, not fixed.** The row at [scripts/harness/install-opencode.sh:25] is `"$p" --help 2>/dev/null | grep -qi 'run\|exec\|serve'`. `2>/dev/null` discards the only stream the text is on, so the pipeline can never see it and the `else` branch [scripts/harness/install-opencode.sh:28] is the only reachable outcome on any 1.x binary. The fix is the one the battery already describes [tests/harness-conformance.sh:243-248]. The source has not moved since `d948c16`; the unmerged `wt/cf-vars` rewrite of this file kept the same `2>/dev/null`, so the defect survives the in-flight fix too.

## 4. Metrics emitted

**NONE.** The adapter has no counter, no timer, no structured line, no state file and no endpoint. Its complete output vocabulary is four row shapes and two terminal strings [scripts/lib.sh:5-8] [scripts/harness/install-opencode.sh:33-37], and the only number it produces is `$FAILED`, which counts the `bad` calls it made in this process and dies with it [scripts/lib.sh:7] [scripts/lib.sh:11].

That matters for §6: because `warn` does not increment `FAILED` [scripts/lib.sh:8], the exit code is a metric of *the rows that chose to be failures*, not of capability. A caller cannot compute "how much of the foreign-harness contract this host satisfies" from anything here — one of the four required properties is probed, and that probe can only produce a `WARN`.

The nearest real measurement lives outside the module: one tab-separated row per leg in the battery's `results.tsv`, reflected into the generated `docs/HARNESS-CONFORMANCE.md` matrix [tests/harness-conformance.sh:82] [tests/harness-conformance.sh:387-419]. Support is defined by green legs in that battery, not by anything this adapter prints — `--check` alone is explicitly not support (fact: FACT-08) [specs/HARNESS-MATRIX.md:35-37].

## 5. Log lines it can generate

Every line is a literal from the source or from a run on 2026-11-05. "evidentiary" means the line is the measurement; "descriptive" means it narrates intent and proves nothing alone.

| Level | Line (verbatim) | Emitted when | Kind |
|---|---|---|---|
| stdout | `harness: opencode (UNVERIFIED adapter)` [scripts/harness/install-opencode.sh:12] | first line of every run, including `--apply` | descriptive — the file's own admission that it is not certified |
| stdout | `  PASS  binary — /home/kara/.opencode/bin/opencode` [scripts/harness/install-opencode.sh:16] | `command -v opencode` resolves | evidentiary — names the absolute path it will test, measured |
| stdout | `  FAIL  binary — absent — no opencode in this node` [scripts/harness/install-opencode.sh:19] | nothing named `opencode` on `PATH` | evidentiary — and it is a statement about `PATH`, not about the node: row 2 of §3 prints it beside a PASS for the same file |
| stdout | `  PASS  version — 1.18.29` [scripts/harness/install-opencode.sh:17] | `--version` printed something on stdout | evidentiary, measured — but the value is `head -1` of stdout with stderr discarded, so a binary that prints its version on stderr yields `PASS  version — ` with nothing after the dash |
| stdout | `  PASS  user_space_binary — /home/kara/.opencode/bin/opencode` [scripts/harness/install-opencode.sh:22] | `$HOME/.opencode/bin/opencode` has any execute bit | evidentiary — existence and mode, measured; proves nothing about `PATH` |
| stdout | `  WARN  user_space_binary — not installed under $HOME` [scripts/harness/install-opencode.sh:22] | that path is absent or not executable | descriptive of a gap — and it can never fail a run |
| stdout | `  PASS  non_interactive — a run/exec/serve mode is advertised` [scripts/harness/install-opencode.sh:26] | stdout of `--help` matched `run\|exec\|serve` | evidentiary **in principle**, and **unreachable on every opencode measured here**: never observed, because the text is on stderr [scripts/harness/install-opencode.sh:25] |
| stdout | `  WARN  non_interactive — could not confirm a non-interactive mode` [scripts/harness/install-opencode.sh:28] | the probe found nothing — which is every 1.x run on this host | **descriptive and, measured, false here**: `opencode run --help` exits 0 (§3 row 3). This is the line CF-240 is about |
| stdout | `  FAIL  apply — refused — the opencode install ladder is unmeasured here. Measure it, record it in specs/HARNESS.md, then implement this leg.` [scripts/harness/install-opencode.sh:32] | `--apply` | evidentiary — a refusal that names the missing work and the file to record it in, measured |
| stdout | `OPENCODE: PASS` [scripts/harness/install-opencode.sh:37] | `FAILED == 0` — i.e. no `bad` call, WARNs included | **self-report, not evidence**: measured to print while the capability row is a false WARN |
| stdout | `OPENCODE: FAIL (1)` [scripts/harness/install-opencode.sh:33] [scripts/harness/install-opencode.sh:37] | at least one `bad` | evidentiary for the count; the parent re-counts from the rows, not from this line [scripts/project-node.sh:455-458] |

## 6. Failure modes

Direction is from the adapter's frame: **adapter → operator** (the report is wrong), **operator → adapter** (a wrong argument is accepted), **adapter → node** (provisioning fails), **adapter → binary** (the probe misreads the CLI).

| Failure | Presents as | Direction | Distinguished from | Recovery |
|---|---|---|---|---|
| The capability probe reads the wrong stream (CF-240) | `WARN  non_interactive — could not confirm a non-interactive mode` on a host where `opencode run` works [scripts/harness/install-opencode.sh:28] | adapter → operator | A binary that genuinely has no non-interactive mode: the same WARN, and `opencode --help 2>&1 \| grep -qi 'run\|exec\|serve'` returns NOMATCH. That is the only discriminator, and it is not in the script | Change [scripts/harness/install-opencode.sh:25] to capture `2>&1`, and print the matched token so the row carries a value. The battery already describes this exact fix [tests/harness-conformance.sh:243-248] |
| A WARN cannot fail the run | `OPENCODE: PASS`, exit 0, with the capability unconfirmed [scripts/harness/install-opencode.sh:37] | adapter → operator | A real pass: rows say `PASS non_interactive`, which on this host never appears | Read the rows, never the exit code. `project-node.sh` cannot help: it counts `  FAIL` only [scripts/project-node.sh:455] |
| `--help` is not a help flag | The full check runs and exits 0 (§3 row 5) [scripts/harness/install-opencode.sh:11] | operator → adapter | A real check, which is byte-identical | Add a usage path; until then, treat any output beginning `harness: opencode` as a measurement, not documentation |
| A mistyped mode is accepted | `--appply` runs the check and exits 0 (§3 row 6) [scripts/harness/install-opencode.sh:11] | operator → adapter | A real `--apply`, which prints `FAIL apply` and exits 1 | Refuse any `$1` that is not `--check` or `--apply`; a typo in an apply call currently reads as a green check |
| The `binary` row depends on how the caller was launched | `FAIL binary — absent` beside `PASS user_space_binary` for the same file (§3 row 2) [scripts/harness/install-opencode.sh:14] [scripts/harness/install-opencode.sh:22] | adapter → operator | A node with no opencode at all: both rows red | Probe the user-space path too, or say in the row that it is a `PATH` question. A login shell here resolves it because `~/.profile` exports the directory |
| No pin, no install | `PASS version — <whatever is first on PATH>`; `--apply` always refuses [scripts/harness/install-opencode.sh:17] [scripts/harness/install-opencode.sh:31-34] | adapter → node | The codex adapter, which pins and refuses a digest mismatch through `fetch_verified` [scripts/lib.sh:16-29] | A node cannot be built with `--harness opencode`: layer 20 in apply mode collects the refusal and the node ends `FAIL` [scripts/project-node.sh:449-458]. That is honest, and it means this harness is not provisionable |
| A generation it cannot serve | The adapter itself has no answer; the battery answers for it: `adapter passes on opencode 1.18.29 but this harness is the v2 generation — the adapter has no generation gate` (§3 row 7) [tests/harness-conformance.sh:228-237] | adapter → operator | A v1 host, where the same battery row passes the generation gate and only the WARN remains | Record the generation in the adapter and refuse a mismatch in writing. Nothing else in the tree distinguishes the two: both ids point at this one file [tests/harness-conformance.sh:92-93] |
| A "v2" install that resolves to a squatted package | Nothing here — there is no install path. A naive `npm i opencode2` gets a `security holding package` at `0.0.1-security` with no binary (§3 row 9) [specs/HARNESS-MATRIX.md:194] | operator → registry | A real v1 install, which puts a 184 MB binary on disk and answers `--version` | Do not install a v2. The matrix states the non-claim: no artefact exists [specs/HARNESS-MATRIX.md:52] [specs/HARNESS-MATRIX.md:194] |
| `scripts/lib.sh` missing on the node | Six `command not found` lines, then `FAILED: unbound variable`, exit 1 (§3 row 8) [scripts/harness/install-opencode.sh:9] | adapter → node | A clean refusal, which names the file and prints a `FAIL` row | Stage the pair, which `node-create.sh` does by rewriting the `../lib.sh` reference [scripts/node-create.sh:29-38]. Confirm the staged copy, not the worktree copy |

## 7. Environment and settings it reads

| Setting | Default | Effect |
|---|---|---|
| `$1` (mode) | `--check` [scripts/harness/install-opencode.sh:11] | Only the literal string `--apply` changes behaviour [scripts/harness/install-opencode.sh:31]; every other value — including `--help` and `--appply` — runs the check and exits 0 |
| `HOME` | the caller's | Read only for `$HOME/.opencode/bin/opencode` [scripts/harness/install-opencode.sh:22]; the row is a `WARN` when absent |
| `PATH` | the caller's | Decides `binary` [scripts/harness/install-opencode.sh:14] and gates the capability probe on a non-empty result [scripts/harness/install-opencode.sh:25] |
| `FAILED` | unset → 0 [scripts/lib.sh:11] | Incremented by `bad` only; decides the trailer and the exit code [scripts/harness/install-opencode.sh:36-37] |
| `NODE_GATEWAY_PORT` | set by the parent, never read here [scripts/project-node.sh:450-452] | The adapter is launched with it and ignores it — measured: zero occurrences. Harmless today; it means the adapter cannot report the port it was told about |
| `CF_*` (§4 contract) | none | This file reads **no** `CF_*` variable — measured: zero occurrences. The contract lives only on the unmerged `wt/cf-vars` branch, where the same file parses it via `cf_parse_args` (§3 row 10) |

There is no configuration file, no flag beyond the mode, no environment override, and no default that this document had to invent.

## 8. Evidence of record

- **Measured here, 2026-11-05**, on `b31c232` with bash 5.3.9, `opencode` 1.18.29 at `/home/kara/.opencode/bin/opencode` (184 666 240 B, mtime 2026-10-03): §3 rows 1-9. Artifacts under `/home/kara/.hermes/cache/scratch/md18c/` — `nolib/` (row 8, the adapter copied alone), `hc/` and `hc2/` (two battery runs: the first from a default `PATH`, the second with `~/.opencode/bin` prepended, each with its `results.tsv`), and the capture files `/tmp/o.err`, `/tmp/r.err`, `/tmp/v.out` written by row 3. Rows 1-8 need no network, no credential and no node. The document carries 128 `path:line` locators, 50 of them distinct, and every one resolves inside the file it names.
- **CF-240 is live and unfixed.** The board row is `CF-240` in `.coding-hermes/board/tasks.jsonl` — "install-opencode.sh's non_interactive row can never pass: it greps stdout while opencode writes --help to stderr", status `pending`, filed 2026-11-05T04:15:37Z. Its four acceptance criteria are all unmet at [scripts/harness/install-opencode.sh:25]: the row does not read both streams; there is no fixture either way; there is no version/generation refusal; and the stdout-only grep is not swept from siblings in this change. Cited by id per fact: FACT-09.
- **The repo's own witness disagrees with the module.** The battery already detects the false WARN and writes a NOTE saying exactly this — `its probe greps stdout and opencode writes help to stderr` [tests/harness-conformance.sh:243-248] — but a NOTE is not a FAIL, so the battery stays green while the adapter row stays wrong. Same class of gap as the WARN: a mechanism that cannot fail is decoration.
- **Generation, measured three ways**: the binary is `1.18.29` (major 1, §3 rows 1-3); the battery maps both `opencode` and `opencode-v2` onto this one adapter and refuses v2 with an explicit message (§3 row 7) [tests/harness-conformance.sh:92-93]; and the npm name a v2 would come from is a squatting stub — `opencode2`'s own description field is `security holding package`, its only versions are `0.0.0-stage` and `0.0.1-security`, while the real package `opencode-ai` is at `1.19.5` (§3 row 9), matching what the matrix already recorded [specs/HARNESS-MATRIX.md:52] [specs/HARNESS-MATRIX.md:194].
- **Not measured, and not claimed**: nothing about a real node. `--apply` refuses by design [scripts/harness/install-opencode.sh:31-34], so no install ladder exists to measure; and the battery's smoke leg for opencode was not run here, so no claim is made that a turn succeeds — the table marks that surface as measured elsewhere (the last column of [tests/harness-conformance.sh:92]), and this document does not borrow that measurement.
- **A file the brief expected and this base does not have**: `tests/harness/vars-test.sh` (§3 row 10). Its 57 checks target the `CF_*` contract implemented on the unmerged branch `wt/cf-vars` (`5764b24`, not an ancestor of `origin/main`), so it cannot witness anything about the file documented here. Recorded as a finding, not silently omitted.
