# 16. scripts/harness/install-codex.sh

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/harness/install-codex.sh` — 507 lines, four modes in one file [scripts/harness/install-codex.sh:1] [scripts/harness/install-codex.sh:8-11] |
| Repository | `code-factory` |
| Revision | `b31c232` — the `origin/main` tip every locator below was measured against (worktree `~/proj-wt-md-16c`, 2026-11-05); the file's own last-touching commit is `20d1252` (2026-11-04, "feat(harness): install-codex.sh — a pinned codex, the CF_* refusals, and one measured turn") |
| Status | **VERIFIED — 409 locators, all resolve; facts cited** |

## 1. Purpose and why it matters

- What it is: the codex adapter for code-factory — one script that reports (`--check`), installs (`--apply`), exercises one real turn (`--turn`) and probes the stdio sidecar (`--app-server`) [scripts/harness/install-codex.sh:8-11], with a three-value exit contract: `0 PASS · 1 FAIL · 2 REFUSED` [scripts/harness/install-codex.sh:13].
- Why it exists: the adapter already lived in crier (`internal/harness/codex/codex.go`) and neither the host had a binary nor this repo an installer, so the file's header states the gap it closes and that the ladder was measured rather than documented [scripts/harness/install-codex.sh:4-6].
- Why it matters to the node: `scripts/node-create.sh` stages `harness/install-$HARNESS.sh` as part of the set it ships to a bunker and refuses the spawn when the named adapter is missing [scripts/node-create.sh:23] [scripts/node-create.sh:26]. Codex is the second of the four adapters that actually ship — the directory holds `install-claude-code.sh`, `install-codex.sh`, `install-hermes.sh`, `install-opencode.sh` — and `specs/HARNESS.md` records it as the second harness whose install is **MEASURED** rather than asserted [specs/HARNESS.md:29].
- Why the credential story is the interesting one: codex's credential is a JSON file, not an environment variable [scripts/harness/install-codex.sh:37-39]. The installer therefore (a) refuses a credential that arrives as an argv value [scripts/harness/install-codex.sh:98-99], (b) refuses `CF_API_KEY` and `OPENAI_API_KEY` in the ambient environment [scripts/harness/install-codex.sh:125-130], (c) accepts a key only as a **path** to a mode-600 file inside `$HOME`, and never prints its value [scripts/harness/install-codex.sh:194-214], and (d) for a turn, **never reads or copies the host's `$HOME/.codex/auth.json`**: with no key file it uses that login in place and says so as ambient state [scripts/harness/install-codex.sh:237] [scripts/harness/install-codex.sh:456] [scripts/harness/install-codex.sh:483], and with a key file it writes a *new* `auth.json` into an isolated `CODEX_HOME` that is deleted on exit [scripts/harness/install-codex.sh:439-453]. That is the correct shape of the rule (a copied credential is a shared credential) — and it is also the branch that is **dead** (§6, D-1): line 442 mis-expands `$VAR[CF_RUN_ID]` and the shell dies before anything is written.
- What breaks if it is ABSENT: `node-create.sh --harness codex` fails its own staged-set row — `  FAIL  staged_set — missing scripts/harness/install-codex.sh` [scripts/node-create.sh:26] — so a codex node cannot be provisioned at all, and the crier adapter has nothing to talk to.
- What breaks if it LIES: measured, and it is the sharpest failure in this file. `--check` on this host prints `CODEX: PASS` and exits 0 [scripts/harness/install-codex.sh:333] while the credential-bearing `--turn` path cannot execute a single turn: it aborts with `line 442: VAR: unbound variable` before writing `config.toml` or `auth.json` [scripts/harness/install-codex.sh:442]. The check grades the binary, the pin, the exec contract and auth-file *existence*, and never touches that line — so a green check is compatible with a dead key path, which is exactly the report an operator would trust.
- A second, smaller lie: the `--check` header's claim that the app-server path is measured is true, but the row it emits on every healthy host is a `WARN`, so a PASS verdict always carries at least one warning [scripts/harness/install-codex.sh:272] [scripts/harness/install-codex.sh:333].

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `bash` | measured here 5.3.9; the script needs `set -uo pipefail`, `declare -A` and `coproc` [scripts/harness/install-codex.sh:40] [scripts/harness/install-codex.sh:66] [scripts/harness/install-codex.sh:408] | the interpreter on the shebang line [scripts/harness/install-codex.sh:1] | **not detected** — the shell is already running; a `sh` without `pipefail` or `declare -A` fails on the first unbound expansion, not as a named row |
| `scripts/lib.sh` | the repo's own file, 65 lines [scripts/lib.sh:1] | `$HERE/../lib.sh`, resolved from the script's own directory [scripts/harness/install-codex.sh:41-42] | **not detected**: sourced without a guard [scripts/harness/install-codex.sh:42]. Measured by copying the file alone into an empty tree: `line 42: …/lib.sh: No such file or directory`, then `say: command not found`, `ok: command not found`, `have: command not found`, `bad: command not found`, and finally `FAILED: unbound variable`, exit 1 — a bootstrap crash, not rows |
| `curl` | unpinned; used only through `fetch_verified` [scripts/lib.sh:19] | on `PATH` for `--apply` | `fetch_verified` returns 1 when curl fails, so the leg reports `  FAIL  download — download or digest check failed for <url> (want sha256 <want>)` [scripts/harness/install-codex.sh:358-362]. **Anything that shadows `curl` is believed**: a fixture `curl` earlier on `PATH` produced `digest mismatch … got e3b0c442…` (the sha256 of an empty file) and 5 spurious test FAILs (§6, D-9) |
| `sha256sum` | coreutils, unpinned | on `PATH` for `--apply` and for the artifact digest [scripts/lib.sh:20] [scripts/harness/install-codex.sh:496] | **not detected**: inside `fetch_verified` an absent `sha256sum` yields an empty `got`, which fails the comparison and presents as a digest mismatch — the same row a corrupted download produces [scripts/lib.sh:21-24] |
| `tar` | unpinned; must handle `tzf` and `xzf` of a `.tar.gz` | on `PATH` for `--apply` [scripts/harness/install-codex.sh:364] [scripts/harness/install-codex.sh:369] | **not detected as itself**: `tar tzf` producing nothing becomes `  FAIL  layout — tarball has no top-level codex-<target> member` [scripts/harness/install-codex.sh:365-367], which names the artefact, not the missing tool |
| `install` (coreutils) | unpinned | on `PATH` for `--apply` [scripts/harness/install-codex.sh:372] | `  FAIL  install — cannot place <bin>` [scripts/harness/install-codex.sh:372] |
| `stat` | GNU `stat -c` [scripts/harness/install-codex.sh:201] [scripts/harness/install-codex.sh:236] | on `PATH` | For the key file: empty mode → `  FAIL  credential — cannot read the mode of <path>` [scripts/harness/install-codex.sh:204]. For the host login the failure is swallowed to `?` and still warns [scripts/harness/install-codex.sh:236-237] |
| `git` | measured here 2.53.0 | on `PATH`; the workdir must be a work tree [scripts/harness/install-codex.sh:224] | **fail closed by name**: `  FAIL  workdir — <dir> is not a git work tree — codex refuses 'Not inside a trusted directory' and crier does not pass --skip-git-repo-check` [scripts/harness/install-codex.sh:227] |
| `timeout` (coreutils) | unpinned | on `PATH` for `--doctor` and `--turn` [scripts/harness/install-codex.sh:280] [scripts/harness/install-codex.sh:466] | **not detected**: an absent `timeout` makes the command fail to start, which `--turn` records as `  FAIL  turn_exit — exit 127 — …` [scripts/harness/install-codex.sh:474] |
| `mktemp`, `umask` | coreutils / shell builtin | `--apply` scratch dir, mode 700 [scripts/harness/install-codex.sh:356] | `  FAIL  download — cannot create a temp dir` [scripts/harness/install-codex.sh:356] |
| `uname` | unpinned | `--check` and `--apply` target selection [scripts/harness/install-codex.sh:157-158] [scripts/harness/install-codex.sh:309] | **not detected**: an empty `uname -s` falls through `case "$os/$arch"` to `return 1`, which reads as "no artefact for this platform" [scripts/harness/install-codex.sh:164-167] |
| `df` + `awk` | via `require_disk`/`free_gb` [scripts/lib.sh:32] [scripts/lib.sh:35-44] | `--apply` only | `  FAIL  disk — <n> GB free < floor 1.0 GB at <path>` [scripts/lib.sh:41]; an absent `awk` makes the comparison fail and reports the same row with an empty number |
| `sed`, `grep`, `find`, `head`, `tr` | unpinned | used for version parsing, the member name, the `thread.started` id and the rollout lookup [scripts/harness/install-codex.sh:139] [scripts/harness/install-codex.sh:364] [scripts/harness/install-codex.sh:476] [scripts/harness/install-codex.sh:484] | **not detected**: each collapses to an empty value, i.e. to a FAIL that names the missing *data* rather than the missing tool |
| `codex` at the pin | `0.166.0` — measured here as `codex-cli 0.166.0` from `/home/kara/.local/codex/0.166.0/bin/codex` | `$HOME/.local/codex/<pin>/bin/codex` first, else `PATH` [scripts/harness/install-codex.sh:52-55] [scripts/harness/install-codex.sh:133] | `  FAIL  binary — absent — run --apply (pin 0.166.0, <target>)` on a bare box [scripts/harness/install-codex.sh:317]; a `PATH` binary is a different FAIL — `host-provided <path> — not installed by this adapter, so the pin is unowned` [scripts/harness/install-codex.sh:315] |
| No node, npm, python, database, container | — | — | Verified by reading the whole file: the only outbound call is the tarball fetch [scripts/harness/install-codex.sh:352] [scripts/harness/install-codex.sh:358]; there is no `python`, no `docker`, no SQL and no socket. The header says the tarball was chosen over npm precisely to keep node out of a node-less image [scripts/harness/install-codex.sh:31-33] |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `. "$HERE/../lib.sh"` [scripts/harness/install-codex.sh:42] | `scripts/lib.sh` | Five printers and one shared counter: `say` = `printf '%s\n'` [scripts/lib.sh:5], `ok` = `  PASS  %s — %s` [scripts/lib.sh:6], `bad` = `  FAIL  %s — %s` **plus** `FAILED=$((FAILED+1))` [scripts/lib.sh:7], `warn` = `  WARN  %s — %s` [scripts/lib.sh:8], `note` = `  ..    %s` [scripts/lib.sh:9], and `FAILED=${FAILED:-0}` [scripts/lib.sh:11] | Every verdict in the file is `[ "$FAILED" -eq 0 ]` [scripts/harness/install-codex.sh:333] and the only tally is `bad`'s side effect [scripts/lib.sh:7]. Renaming `bad`, or dropping the increment, prints the same FAIL rows and exits `CODEX: PASS`. The test's whole refusal contract greps for `CODEX: REFUSED` and substrings, not exit alone [tests/harness/codex-install-test.sh:59-67] |
| `fetch_verified <url> <dest> <want>` [scripts/lib.sh:16-29] | `scripts/lib.sh` | Downloads with `curl -fsSL --max-time 120`, compares the sha256 of the temp file, and on mismatch prints `digest mismatch for %s: want %s got %s` to **stderr** and returns 1 [scripts/lib.sh:19-25]; on match it moves the file into place and chmods it [scripts/lib.sh:26-28] | The installer treats any non-zero as a hard stop with no retry: `bad "download" "download or digest check failed for $url (want sha256 $want)"` then exit 1 [scripts/harness/install-codex.sh:358-362]. The helper accepts any scheme curl does — the test drives it with `file://` [tests/harness/codex-install-test.sh:184] — so TLS is **not** part of the helper's guarantee; the digest is the only integrity check, and `CF_CODEX_SHA256` can replace it (§7) |
| `have codex` [scripts/lib.sh:13] via `bin_for_run` [scripts/harness/install-codex.sh:133] | `scripts/lib.sh` | Prints the resolved path when `command -v` succeeds, silent otherwise [scripts/lib.sh:13] | `bin_for_run` prefers the pinned `$BIN` and falls back to whatever `PATH` answers [scripts/harness/install-codex.sh:133]. That fallback is how a host-provided binary enters every mode, and the two modes grade it differently (§6, D-6) |
| `require_disk "$HOME" 1.0` [scripts/harness/install-codex.sh:339] | `scripts/lib.sh` | Prints `  PASS  disk — <n> GB free (floor <floor> GB)` or `  FAIL  disk — …` and returns 1 below the floor [scripts/lib.sh:35-44]; the floor is the constant at [scripts/harness/install-codex.sh:56] | `--apply` stops on return 1 with `CODEX: FAIL (<n>)` [scripts/harness/install-codex.sh:339]. Nothing else is installed or removed first — the check is the first statement after the arch refusal |
| `codex --version` [scripts/harness/install-codex.sh:136-141] | the pinned CLI | Output is `<name> <version>` on one line; the script takes the **last whitespace field** of the first line [scripts/harness/install-codex.sh:139-140] | Measured here: `codex-cli 0.166.0` → `0.166.0`, equal to the pin [scripts/harness/install-codex.sh:49] [scripts/harness/install-codex.sh:143]. A build that prints a bare `0.166.0` still parses; one that decorates the tail (`0.166.0 (build x)`) would fail the pin comparison and be reported as `  FAIL  version — … != pin 0.166.0` [scripts/harness/install-codex.sh:322] |
| `codex exec --help` / `codex exec resume --help` / `codex app-server --help` [scripts/harness/install-codex.sh:245] [scripts/harness/install-codex.sh:255] [scripts/harness/install-codex.sh:269] | the pinned CLI | The help text contains the three literals `--json`, `--sandbox`, `--skip-git-repo-check`, and `exec resume` exits 0 [scripts/harness/install-codex.sh:247-263] | These are **text** assertions, not behaviour: a help page that still advertises a removed flag passes [scripts/harness/install-codex.sh:248-259] |
| `codex doctor --json` [scripts/harness/install-codex.sh:280-287] | the pinned CLI | Emits a JSON object carrying `"overallStatus": "<word>"`, parsed with `sed` and mapped `ok\|pass` → PASS, empty → WARN, anything else → WARN [scripts/harness/install-codex.sh:282-287] | Parsed with `sed`, not a JSON parser, so a re-serialised field (`"overallStatus":"ok"` without the space) still matches the `: *` pattern; a renamed key yields `  WARN  doctor — doctor --json output carried no overallStatus`. Only reached under `--deep` [scripts/harness/install-codex.sh:325] |

### 2c. Service contracts (both sides named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| GitHub release host | installer → `github.com` | HTTPS through `curl -fsSL --max-time 120` [scripts/lib.sh:19] | `https://github.com/openai/codex/releases/download/rust-v0.166.0/codex-x86_64-unknown-linux-musl.tar.gz`, 121,764,138 bytes, sha256 `a0bf572d…3978` [scripts/harness/install-codex.sh:50-51] [scripts/harness/install-codex.sh:352] | The published release asset for `rust-v0.166.0`. **Measured today from this host**: the downloaded tarball's sha256 equals the file's constant exactly, and its single member `codex-x86_64-unknown-linux-musl` extracts to a binary byte-identical (`cmp`) to the installed `$HOME/.local/codex/0.166.0/bin/codex` (§3, check 7) |
| `codex` CLI, `exec` mode | installer → installed binary | `execve` of `$BIN` with `--json -s <sandbox> -c model_provider=… -m <model> -- <prompt>`, cwd = `CF_WORKDIR`, stdout captured to a file [scripts/harness/install-codex.sh:465-473] | prompt text plus the pinned model, provider and sandbox [scripts/harness/install-codex.sh:460] [scripts/harness/install-codex.sh:467] | The pinned binary itself; the contract it must honour is asserted from its own `--help` [scripts/harness/install-codex.sh:243-265] and from the JSON event it emits, `{"type":"thread.started","thread_id":…}` [scripts/harness/install-codex.sh:476] |
| `codex` CLI, app-server | installer ↔ installed binary | JSON-RPC over stdio through a `coproc`; one `initialize` request written to the coprocess stdin, one line read back with a 30 s deadline [scripts/harness/install-codex.sh:408-411] | `{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"clientInfo":{"name":"code-factory","version":"0.1.0"}}}` [scripts/harness/install-codex.sh:409] | The binary's `app-server` subcommand, labelled `[experimental]` in `codex --help`; the script's own header records that **nothing in crier uses it** [scripts/harness/install-codex.sh:22-29] and the check row warns rather than passes [scripts/harness/install-codex.sh:272] |
| crier adapter | crier → a codex binary's `exec` | JSON lines on stdout | `thread.started` / `thread_id`, then `exec resume <id>` for the continue path [scripts/harness/install-codex.sh:17-20] | `crier internal/harness/codex/codex.go` — **not present in this tree** (there is no `internal/` directory here), so this side of the contract cannot be verified from this repository; the only in-tree statement of it is the comment [scripts/harness/install-codex.sh:4] [scripts/harness/install-codex.sh:23-26]. This module's `--turn` is the local stand-in: it parses the same event the same way [scripts/harness/install-codex.sh:476-478] |
| OpenAI-compatible endpoint | codex → provider | HTTPS, codex's own client and its own config | the model id and the key from `auth.json` | Not in this tree, and **not named by this file**: `CF_BASE_URL` is collected and validated but never read again (§6, D-7), so whichever endpoint codex defaults to is the one used [scripts/harness/install-codex.sh:67] [scripts/harness/install-codex.sh:107] |
| `$HOME/.codex/auth.json` (host login) | installer → codex | read **in place**, never copied; the script only `stat`s it for its mode [scripts/harness/install-codex.sh:236] | mode 600 on this host; contents never read [scripts/harness/install-codex.sh:237] | codex's own auth loader — outside this tree. The installer's contract with it is only "it exists, and if it does not, an unattended turn will fail at auth" [scripts/harness/install-codex.sh:239] |
| DuckBrain namespace (`CF_NAMESPACE`) | **no direction** — declared, never used | — | — | Declared required by the variable contract [specs/HARNESS-MATRIX.md:124] and by this file's `REQUIRED` list [scripts/harness/install-codex.sh:71], but no line of the script writes, reads or echoes it [scripts/harness/install-codex.sh:68] [scripts/harness/install-codex.sh:110] [scripts/harness/install-codex.sh:173] |
| `tests/harness/codex-install-test.sh` | suite → installer | `execve` with a scratch `HOME` and a clean credential environment; `bash -n` first [tests/harness/codex-install-test.sh:69-71] [tests/harness/codex-install-test.sh:41] | flags, `CF_*` variables, `CF_CODEX_URL`/`CF_CODEX_SHA256` pointing at a locally built mirror tarball [tests/harness/codex-install-test.sh:182-196] | This is the only automated caller in the tree: `tests/selftest.sh` exercises `install-hermes.sh` and never mentions codex (§6, D-10) |
| `tests/harness-conformance.sh` | battery → installer's `--check` | `bash "$path" --check`, output captured and every PASS row required to carry a measured value [tests/harness-conformance.sh:213-226] | the adapter's own exit status and rows | The battery's matrix row for codex names a *different* smoke shape — `codex exec --skip-git-repo-check -s workspace-write "<prompt>"` [tests/harness-conformance.sh:91] — while the installer's own turn deliberately omits that flag [scripts/harness/install-codex.sh:221-227] [scripts/harness/install-codex.sh:466-472] |

## 3. Verification

Run from a clean worktree of `b31c232` (`~/proj-wt-md-16c`), 2026-11-05. Every command below was executed; the transcripts are literal output. The host is Linux x86_64, bash 5.3.9, git 2.53.0, `codex-cli 0.166.0` at `/home/kara/.local/codex/0.166.0/bin/codex`.

| # | Check | Command | Expected | Last run | Result |
|---|---|---|---|---|---|
| 1 | The module's own gate on this host | `bash scripts/harness/install-codex.sh --check` [scripts/harness/install-codex.sh:306-333] | named rows, `CODEX: PASS`, exit 0 only when `FAILED=0` [scripts/harness/install-codex.sh:333] | 2026-11-05 | **exit 0**, `CODEX: PASS`; five PASS rows, one note, two WARN rows (transcript 1) |
| 2 | Same gate on a box with no binary | `HOME=<empty> PATH=/usr/local/bin:/usr/bin:/bin bash … --check` | `FAIL  binary — absent`, three dependent FAILs, `CODEX: FAIL (4)`, exit 1 | 2026-11-05 | **as specified** — exit 1, 4 named FAILs (transcript 2) |
| 3 | A second `--apply` must be a no-op | `bash scripts/harness/install-codex.sh --apply` twice [scripts/harness/install-codex.sh:340-350] | `already installed`, `PASS install … unchanged`, exit 0 | 2026-11-05 | **as specified** — exit 0, binary untouched (transcript 3); the test asserts inode+mtime+size are identical across runs [tests/harness/codex-install-test.sh:209-218] |
| 4 | The sidecar probe | `bash scripts/harness/install-codex.sh --app-server` [scripts/harness/install-codex.sh:403-423] | `PASS app_server — initialize answered: <userAgent>`, exit 0 | 2026-11-05 | **exit 0**, answered in well under the 30 s deadline (transcript 4) |
| 5 | The file's own proof, hermetic half | `bash tests/harness/codex-install-test.sh --hermetic` [tests/harness/codex-install-test.sh:258-259] | 11 refusal cases, the whole install ladder against a fake `$HOME` and a local mirror, live legs skipped by name | 2026-11-05 | **26 passed, 0 failed, 1 skipped — `RESULT: PASS`, exit 0** on a clean `PATH` (transcript 5). On the sandbox `PATH` of this session the same command reported `21 passed, 5 failed` because a fixture `curl` shadowed the real one — a test-hygiene defect, D-9, not an installer defect |
| 6 | The live half | `bash tests/harness/codex-install-test.sh` (no `--hermetic`) | C1 sidecar, C2 one real turn with `CF-227-TOKEN-7f3a9c` [tests/harness/codex-install-test.sh:285-293] | **not run** | Deliberately not run: C2 spends a real model turn against the host login. Its own C1 leg is covered here as check 4, and its C2 leg is the one path this document could not exercise without spending a credential |
| 7 | The pin is real, and the installed binary is that pin | `/usr/bin/curl -fsSL -o codex.tar.gz https://github.com/openai/codex/releases/download/rust-v0.166.0/codex-x86_64-unknown-linux-musl.tar.gz; sha256sum codex.tar.gz; tar tzf …; tar xzf …; cmp <member> $HOME/.local/codex/0.166.0/bin/codex` [scripts/harness/install-codex.sh:51] [scripts/harness/install-codex.sh:364] | tarball sha256 = the constant; one top-level member; member identical to the installed binary | 2026-11-05 | **PASS** — `a0bf572d2f93f056c6712a6da348e96078dc84f3885fd7be67807ef389cb3978`, member `codex-x86_64-unknown-linux-musl`, `cmp` → `IDENTICAL`, both `codex-cli 0.166.0` (transcript 6) |
| 8 | The credential-bearing turn path | `HOME=<fake> CF_API_KEY_FILE=<mode-600 file inside it> CF_RUN_ID=… bash … --turn` with a stub `codex` [scripts/harness/install-codex.sh:425-457] | an isolated `CODEX_HOME` under `$HOME/.cache/cf-codex/<run-id>`, a written `config.toml` and `auth.json`, one turn | 2026-11-05 | **BROKEN — defect D-1**: `/…/install-codex.sh: line 442: VAR: unbound variable`, exit 1; no `config.toml`, no `auth.json`, no turn (transcript 7) |
| 9 | Containment of `CF_WORKDIR` and `CF_API_KEY_FILE` | same files reached through `$HOME/../escape` [scripts/harness/install-codex.sh:191] [scripts/harness/install-codex.sh:220] [scripts/harness/install-codex.sh:200] | a refusal naming `$HOME` | 2026-11-05 | **BROKEN — defect D-4**: both rows PASS on a directory that is outside `$HOME` (transcript 8) |
| 10 | Which `CODEX_HOME` the host-login turn really uses | ambient `CODEX_HOME=<elsewhere>` + stub binary that prints what it was handed [scripts/harness/install-codex.sh:456] [scripts/harness/install-codex.sh:470] | the row's claim — `$HOME/.codex` | 2026-11-05 | **BROKEN — defect D-5**: the row says `$HOME/.codex`, the child saw `CODEX_HOME=<elsewhere>` (transcript 9) |
| 11 | What the dead branch would do if line 442 were fixed | the same installer copied to scratch with `${VAR[CF_RUN_ID]}` substituted, then run as check 8 with `CF_RUN_ID=../../victim` [scripts/harness/install-codex.sh:442-453] | isolation under `$HOME/.cache` | 2026-11-05 | **two more defects**, D-2 and D-3: the run deleted `$HOME/victim` (traversal through `rm -rf`), and the `auth.json` it wrote did not parse as JSON (transcript 10). Labelled a patched copy — never as shipped behaviour |
| 12 | Every locator and the document's shape | `python3 scripts/master_doc_check.py docs/master --only 16- --strict` | `MASTER-DOC: PASS` | 2026-11-05 | **PASS** (transcript 11) |

Transcript 1 — check 1, the primary measurement, as delivered:

```
$ bash scripts/harness/install-codex.sh --check; echo "EXIT=$?"
harness: codex (pin 0.166.0, mode --check)
  PASS  binary — /home/kara/.local/codex/0.166.0/bin/codex (installed by this adapter)
  PASS  version — 0.166.0 (pin 0.166.0)
  PASS  exec_contract — exec --json (the adapter's thread.started event)
  PASS  exec_contract — exec -s/--sandbox (the mode is never inherited from config)
  PASS  exec_contract — exec resume <id> (continue a thread)
  ..      exec --skip-git-repo-check is advertised; crier does not pass it, so CF_WORKDIR must be a clone
  WARN  app_server — [experimental] app-server subcommand present — crier@6422c851 does not use it (exec mode); probe with --app-server
  WARN  auth — $HOME/.codex/auth.json exists (mode 600) — a host login is ambient state, not a directive; fine for a measured turn, not for a node

CODEX: PASS
EXIT=0
```

Transcript 2 — check 2, an empty `$HOME` and a minimal `PATH`:

```
$ HOME=$(mktemp -d) PATH=/usr/local/bin:/usr/bin:/bin bash scripts/harness/install-codex.sh --check; echo "EXIT=$?"
harness: codex (pin 0.166.0, mode --check)
  FAIL  binary — absent — run --apply (pin 0.166.0, x86_64-unknown-linux-musl)
  FAIL  version — unreadable — no binary
  FAIL  exec_contract — unverified — no binary
  FAIL  app_server — unverified — no binary
  WARN  auth — no CF_API_KEY_FILE and no $HOME/.codex/auth.json — an unattended turn will fail at auth

CODEX: FAIL (4)
EXIT=1
```

Transcript 3 — check 3, a second `--apply`. The `path_env` WARN is an artefact of the isolated `PATH` used for this run: with `$HOME/.local/bin` present the same row prints `  PASS  path_env — $HOME/.local/bin is on PATH` (measured in the same session, the only difference between the two runs):

```
$ bash scripts/harness/install-codex.sh --apply; echo "EXIT=$?"
harness: codex (pin 0.166.0, mode --apply)
  PASS  disk — 174.7 GB free (floor 1.0 GB)
  ..    already installed: /home/kara/.local/codex/0.166.0/bin/codex (0.166.0) — nothing to do
  PASS  install — /home/kara/.local/codex/0.166.0/bin/codex (0.166.0) unchanged
  PASS  version — 0.166.0 (pin 0.166.0)
  PASS  path — /home/kara/.local/bin/codex -> /home/kara/.local/codex/0.166.0/bin/codex
  PASS  path_env — $HOME/.local/bin is on PATH
  WARN  auth — $HOME/.codex/auth.json exists (mode 600) — a host login is ambient state, not a directive; fine for a measured turn, not for a node

CODEX: PASS
EXIT=0
```

Transcript 4 — check 4:

```
$ bash scripts/harness/install-codex.sh --app-server; echo "EXIT=$?"
harness: codex (pin 0.166.0, mode --app-server)
  ..    binary /home/kara/.local/codex/0.166.0/bin/codex (0.166.0)
  PASS  app_server — initialize answered: code-factory/0.166.0 (Ubuntu 26.4.0; x86_64) unknown (code-factory; 0.1.0)

CODEX: PASS
EXIT=0
```

Transcript 5 — check 5, excerpt of the hermetic half under a clean `PATH` (all 26 PASS rows are in the run; the elision is marked):

```
$ PATH=/usr/local/bin:/usr/bin:/bin bash tests/harness/codex-install-test.sh --hermetic; echo "EXIT=$?"
codex installer test (CF-227) — installer: …/scripts/harness/install-codex.sh
  PASS  bash -n is clean
…
  PASS  A8 a CF_API_KEY_FILE that is mode 644 is refused — refused and named the reason
  PASS  A9 a mode-600 key file inside $HOME is accepted, and its value is never printed
  PASS  A10 an arch with no measured artefact is refused, not faked — refused and named the reason
  PASS  A11 a CF_WORKDIR that is not a git work tree is refused — refused and named the reason
…
  PASS  B2 a digest mismatch FAILs the download leg and names both digests
  PASS  B2 a mismatched download installs nothing
  PASS  B3 --apply installs the pin and reads the version back
  PASS  B3 the binary lives under $HOME/.local/codex/0.166.0 (user-space, no root)
  PASS  B3 the ~/.local/bin shim points at the pin
  PASS  B4 a second --apply is a no-op (exit 0, binary unchanged: 32917184 1793896847 550)
  PASS  B5 --check PASSes a binary this adapter installed and names the path it measured
  PASS  B6 a version mismatch names both the measured value and the pin and FAILs
  PASS  B7 a PATH binary is labelled host-provided and FAILs the binary leg
…
  SKIP  C — --hermetic: the live legs were not run

codex installer test: 26 passed, 0 failed, 1 skipped
RESULT: PASS
EXIT=0
```

Transcript 6 — check 7, the pin reproduced from the release host and compared byte-for-byte:

```
$ sha256sum codex.tar.gz
a0bf572d2f93f056c6712a6da348e96078dc84f3885fd7be67807ef389cb3978  codex.tar.gz
$ tar tzf codex.tar.gz
codex-x86_64-unknown-linux-musl
$ sha256sum codex-x86_64-unknown-linux-musl /home/kara/.local/codex/0.166.0/bin/codex
b8a11fedf24b2dfb59a70c9e52b030f9a508dcd49cd2dd0d41956f4c785156b8  codex-x86_64-unknown-linux-musl
b8a11fedf24b2dfb59a70c9e52b030f9a508dcd49cd2dd0d41956f4c785156b8  /home/kara/.local/codex/0.166.0/bin/codex
$ cmp codex-x86_64-unknown-linux-musl /home/kara/.local/codex/0.166.0/bin/codex && echo IDENTICAL
IDENTICAL
$ ls -l /home/kara/.local/bin/codex
lrwxrwxrwx 1 kara kara 41 Nov  4 22:35 /home/kara/.local/bin/codex -> /home/kara/.local/codex/0.166.0/bin/codex
```

Transcript 7 — check 8, the shipped `--turn` with a key file (fake `$HOME`, stub binary, no network):

```
$ HOME=<fake> CF_API_KEY_FILE=<fake>/keys/provider.key CF_MODEL=… CF_RUN_ID=… bash scripts/harness/install-codex.sh --turn
harness: codex (pin 0.166.0, mode --turn)
  PASS  credential — CF_API_KEY_FILE is a mode 600 file inside $HOME (value not read)
  PASS  workdir — /…/home/work is a git work tree
  WARN  binary — host-provided /…/stub/codex (0.166.0) — the pin is unowned
/…/scripts/harness/install-codex.sh: line 442: VAR: unbound variable
RC=1
```

Transcript 8 — check 9, the same files addressed through `$HOME/../escape`:

```
$ HOME=/…/probe2/home … CF_WORKDIR=/…/probe2/home/../escape CF_API_KEY_FILE=/…/probe2/home/../keys/k bash scripts/harness/install-codex.sh --check
harness: codex (pin 0.166.0, mode --check)
  PASS  credential — CF_API_KEY_FILE is a mode 600 file inside $HOME (value not read)
  PASS  workdir — /…/probe2/home/../escape is a git work tree
  FAIL  binary — absent — run --apply (pin 0.166.0, x86_64-unknown-linux-musl)
  …
CODEX: FAIL (4)
```

Transcript 9 — check 10, the ambient `CODEX_HOME` a host-login turn really receives:

```
  PASS  turn_home — $HOME/.codex (host login; the model and provider are still pinned on argv)
--- what codex was handed:
CODEX_HOME_SEEN=/home/kara/.hermes/cache/scratch/c16probe4-ELSEWHERE
```

Transcript 10 — check 11, the patched copy: the traversal, and the `auth.json` it wrote:

```
  PASS  turn_home — /…/home/.cache/cf-codex/../../victim (isolated config + key, mode 600, deleted on exit)
…
== P1 traversal: $HOME/victim after the run ==
sentinel GONE — rm -rf reached $HOME/victim
$HOME/victim does not exist
== P2 the auth.json the turn was handed ==
mode=600
0000000   {   "   O   P   E   N   A   I   _   A   P   I   _   K   E   Y
0000020   "   :   "   s   k   -   c   1   6   -   p   r   o   b   e   3
0000040   -   n   o   t   -   a   -   r   e   a   l   -   k   e   y  \n
0000060   "   }  \n
parses as JSON: NO — JSONDecodeError: Invalid control character at: line 1 column 48 (char 47)
```

## 4. Metrics emitted

**NONE.** No counter, histogram, gauge, span or duration is emitted: the file contains no `date`, no timing arithmetic and no machine-readable record, and its entire vocabulary is `say`/`ok`/`bad`/`warn`/`note` text [scripts/lib.sh:5-9] over row strings [scripts/harness/install-codex.sh:306-333]. The only countable quantity is `FAILED`, a shell variable incremented by `bad` [scripts/lib.sh:7] and consumed exactly twice — the verdict text `CODEX: FAIL ($FAILED)` and the exit status `[ "$FAILED" -eq 0 ]` [scripts/harness/install-codex.sh:333]. The only numbers it *prints* are measured values, not metrics: the free-space figure and its 1.0 GB floor [scripts/harness/install-codex.sh:56] [scripts/lib.sh:39], the digest it enforced [scripts/harness/install-codex.sh:363], the read-back version [scripts/harness/install-codex.sh:321], and the artifact's sha256 [scripts/harness/install-codex.sh:496]. Why none is appropriate: this is a one-shot installer and prober run by hand or by a provisioning step, with no rate, queue or latency to instrument, and no long-lived process to scrape; its durable record is the operator's terminal plus the exit status [scripts/harness/install-codex.sh:13]. Whether a node carries the pin is answerable only by re-running `--check` or by the conformance battery quoting its rows [tests/harness-conformance.sh:213-226]; nothing aggregates it. The one install-time number in the tree — "7 s install" — is a claim in the harness matrix, not something this file measures [specs/HARNESS.md:29].

## 5. Log lines it can generate

All rows are `printf` output; the format strings and spacing live in `lib.sh` [scripts/lib.sh:5-9]. Tag = **evidentiary** when the line appears in a run recorded in §3, **descriptive** when it is a literal string in the file that no recorded run reached. There is no level, logger, timestamp or destination; everything is stdout except the digest-mismatch line, which `fetch_verified` writes to stderr [scripts/lib.sh:23].

| Level | Line (verbatim) | Emitted when | Kind |
|---|---|---|---|
| none | `harness: codex (pin 0.166.0, mode --check)` | first statement of every run; the two values every later row is judged against [scripts/harness/install-codex.sh:291] | evidentiary |
| PASS | `  PASS  binary — /home/kara/.local/codex/0.166.0/bin/codex (installed by this adapter)` | `$BIN` is executable [scripts/harness/install-codex.sh:313] | evidentiary |
| FAIL | `  FAIL  binary — absent — run --apply (pin 0.166.0, x86_64-unknown-linux-musl)` | neither the pin nor a `PATH` binary exists; the target triple is appended [scripts/harness/install-codex.sh:317] | evidentiary |
| FAIL | `  FAIL  binary — host-provided /home/kara/.local/bin/codex — not installed by this adapter, so the pin is unowned (run --apply)` | a `PATH` binary exists but the pinned path does not [scripts/harness/install-codex.sh:315] | descriptive |
| PASS | `  PASS  version — 0.166.0 (pin 0.166.0)` | the read-back version equals the pin [scripts/harness/install-codex.sh:321] | evidentiary |
| FAIL | `  FAIL  version — 0.165.0 != pin 0.166.0` | the read-back disagrees; both values are named [scripts/harness/install-codex.sh:322] | evidentiary (observed by the test's mismatch arm [tests/harness/codex-install-test.sh:234]) |
| FAIL | `  FAIL  version — unreadable — no binary` | there was nothing to ask [scripts/harness/install-codex.sh:327] | evidentiary |
| PASS | `  PASS  exec_contract — exec --json (the adapter's thread.started event)` | `exec --help` contains `--json` [scripts/harness/install-codex.sh:248] | evidentiary |
| PASS | `  PASS  exec_contract — exec -s/--sandbox (the mode is never inherited from config)` | `exec --help` contains `--sandbox` [scripts/harness/install-codex.sh:252] | evidentiary |
| PASS | `  PASS  exec_contract — exec resume <id> (continue a thread)` | `exec resume --help` exits 0 [scripts/harness/install-codex.sh:256] | evidentiary |
| FAIL | `  FAIL  exec_contract — exec --json missing — crier cannot read the thread id` | the flag is gone from the help text [scripts/harness/install-codex.sh:249] | descriptive |
| FAIL | `  FAIL  exec_contract — exec -s/--sandbox missing — the delivery would inherit ~/.codex/config.toml` | the flag is gone from the help text [scripts/harness/install-codex.sh:253] | descriptive |
| FAIL | `  FAIL  exec_contract — exec resume missing — crier's continue path cannot work` | `exec resume --help` fails [scripts/harness/install-codex.sh:258] | descriptive |
| note | `  ..      exec --skip-git-repo-check is advertised; crier does not pass it, so CF_WORKDIR must be a clone` | the help text advertises the flag — the note explains why the workdir must still be a clone [scripts/harness/install-codex.sh:262] | evidentiary |
| WARN | `  WARN  app_server — [experimental] app-server subcommand present — crier@6422c851 does not use it (exec mode); probe with --app-server` | the subcommand exists — a warning on every healthy host [scripts/harness/install-codex.sh:272] | evidentiary |
| FAIL | `  FAIL  app_server — no app-server subcommand (a sidecar consumer could not be served)` | `app-server --help` produced nothing [scripts/harness/install-codex.sh:273] | descriptive |
| PASS | `  PASS  app_server — initialize answered: code-factory/0.166.0 (Ubuntu 26.4.0; x86_64) unknown (code-factory; 0.1.0)` | `initialize` answered with a `userAgent` [scripts/harness/install-codex.sh:416-417] | evidentiary |
| FAIL | `  FAIL  app_server — no initialize answer within 30 s (sidecar exited or spoke another protocol)` | the read deadline expired [scripts/harness/install-codex.sh:418] | descriptive |
| FAIL | `  FAIL  app_server — unexpected initialize answer: <120 chars>` | a line arrived that carries no `userAgent` [scripts/harness/install-codex.sh:419] | descriptive |
| WARN | `  WARN  auth — $HOME/.codex/auth.json exists (mode 600) — a host login is ambient state, not a directive; fine for a measured turn, not for a node` | no key file, but the host login exists [scripts/harness/install-codex.sh:237] | evidentiary |
| WARN | `  WARN  auth — no CF_API_KEY_FILE and no $HOME/.codex/auth.json — an unattended turn will fail at auth` | neither credential surface exists [scripts/harness/install-codex.sh:239] | evidentiary |
| PASS | `  PASS  credential — CF_API_KEY_FILE is a mode 600 file inside $HOME (value not read)` | the path, file type, readability, home containment, mode and non-emptiness all pass [scripts/harness/install-codex.sh:194-213] | evidentiary |
| PASS | `  PASS  workdir — /…/home/../escape is a git work tree` | the workdir is a work tree — **and this row can be wrong about containment**, D-4 [scripts/harness/install-codex.sh:225] | evidentiary |
| FAIL | `  FAIL  workdir — <dir> is not a git work tree — codex refuses 'Not inside a trusted directory' and crier does not pass --skip-git-repo-check` | `git rev-parse --is-inside-work-tree` failed [scripts/harness/install-codex.sh:227] | evidentiary (test A11) |
| PASS | `  PASS  disk — 174.7 GB free (floor 1.0 GB)` | `require_disk` above the floor [scripts/lib.sh:39] [scripts/harness/install-codex.sh:339] | evidentiary |
| FAIL | `  FAIL  disk — <n> GB free < floor 1.0 GB at <path>` | below the floor; `--apply` stops here [scripts/lib.sh:41] [scripts/harness/install-codex.sh:339] | descriptive |
| note | `  ..    already installed: /home/kara/.local/codex/0.166.0/bin/codex (0.166.0) — nothing to do` | a second `--apply` at the pin [scripts/harness/install-codex.sh:343] | evidentiary |
| PASS | `  PASS  install — /home/kara/.local/codex/0.166.0/bin/codex (0.166.0) unchanged` | the same second run [scripts/harness/install-codex.sh:344] | evidentiary |
| note | `  ..    /…/bin/codex reports 0.165.0 != pin 0.166.0 — replacing` | the installed binary drifts; `$PREFIX` is removed and re-fetched [scripts/harness/install-codex.sh:347-348] | descriptive |
| note | `  ..    fetching https://github.com/openai/codex/releases/download/rust-v0.166.0/codex-x86_64-unknown-linux-musl.tar.gz` | the download begins, URL printed in full [scripts/harness/install-codex.sh:355] | descriptive |
| PASS | `  PASS  install — /…/bin/codex (read back 0.166.0)` | the extracted binary reports the pin [scripts/harness/install-codex.sh:376] | descriptive (observed in the test's B3 [tests/harness/codex-install-test.sh:197]) |
| FAIL | `  FAIL  install — installed binary reads back '0.165.0' != pin 0.166.0 — removed` | the artefact does not match the pin; the prefix is deleted [scripts/harness/install-codex.sh:380] | descriptive |
| PASS | `  PASS  download — sha256 matches the pin (a0bf572d2f93f056c6712a6da348e96078dc84f3885fd7be67807ef389cb3978)` | `fetch_verified` returned 0 [scripts/harness/install-codex.sh:363] | descriptive |
| FAIL | `  FAIL  download — download or digest check failed for <url> (want sha256 <want>)` | curl failed **or** the digest differed — one row for both [scripts/harness/install-codex.sh:360] | evidentiary (test B2) |
| FAIL | `  FAIL  layout — tarball has no top-level codex-<target> member` | `tar tzf` matched nothing [scripts/harness/install-codex.sh:366] | descriptive |
| FAIL | `  FAIL  install — extraction failed for <member>` | `tar xzf` failed [scripts/harness/install-codex.sh:370] | descriptive |
| FAIL | `  FAIL  install — cannot place <bin>` | `install -m 0755` failed [scripts/harness/install-codex.sh:372] | descriptive |
| PASS | `  PASS  path — /home/kara/.local/bin/codex -> /home/kara/.local/codex/0.166.0/bin/codex` | the shim was (re)linked to the pin [scripts/harness/install-codex.sh:387] | evidentiary |
| WARN | `  WARN  path — /home/kara/.local/bin/codex is a host-provided file — left alone; put /…/0.166.0/bin first on PATH instead` | a real file occupies the shim path and is never overwritten [scripts/harness/install-codex.sh:389] | descriptive |
| PASS | `  PASS  path_env — $HOME/.local/bin is on PATH` | the shim directory is on `PATH` [scripts/harness/install-codex.sh:394] | evidentiary |
| WARN | `  WARN  path_env — $HOME/.local/bin is not on PATH — export PATH="$HOME/.local/bin:$PATH"` | it is not, and the remedy is printed [scripts/harness/install-codex.sh:395] | evidentiary |
| note | `  ..    CF_API_KEY_FILE unset — the turn will use the host login at $HOME/.codex/auth.json (ambient, named as such)` | a turn with no key file [scripts/harness/install-codex.sh:184] | evidentiary |
| PASS | `  PASS  turn_home — $HOME/.codex (host login; the model and provider are still pinned on argv)` | the host-login branch — **and this row does not notice an ambient `CODEX_HOME`**, D-5 [scripts/harness/install-codex.sh:456] | evidentiary |
| PASS | `  PASS  turn_home — /…/.cache/cf-codex/<run-id> (isolated config + key, mode 600, deleted on exit)` | the key-file branch — unreachable as shipped, D-1 [scripts/harness/install-codex.sh:454] | descriptive (observed only on the patched copy) |
| WARN | `  WARN  binary — host-provided <path> (0.166.0) — the pin is unowned` | `--turn` found a `PATH` binary and **proceeds**, where `--check` FAILs — D-6 [scripts/harness/install-codex.sh:430] | evidentiary |
| note | `  ..    one turn: model=gpt-5.6-luna provider=openai workdir=/… timeout=300s` | immediately before the turn; note the provider is the *mapped* id, not the `CF_PROVIDER` value [scripts/harness/install-codex.sh:463] [scripts/harness/install-codex.sh:432] | evidentiary |
| PASS | `  PASS  turn_exit — exit 0` | the turn exited 0 [scripts/harness/install-codex.sh:474] | evidentiary |
| FAIL | `  FAIL  turn_exit — exit <n> — <first 300 bytes of stderr>` | the turn failed; stderr is folded onto one line [scripts/harness/install-codex.sh:474] | descriptive |
| PASS | `  PASS  thread — stub-thread (parsed from the thread.started event, as crier does)` | a `thread_id` was parsed from `--json` [scripts/harness/install-codex.sh:477] | evidentiary |
| FAIL | `  FAIL  thread — no thread.started thread_id in --json output` | no such event [scripts/harness/install-codex.sh:478] | descriptive |
| PASS | `  PASS  model_served — requested gpt-5.6-luna → served gpt-5.6-luna` | the rollout record's `thread_settings.model` [scripts/harness/install-codex.sh:485-488] | descriptive |
| WARN | `  WARN  model_served — requested gpt-5.6-luna → served unknown (no rollout record found); exec --json does not report it` | no rollout file matched the thread id [scripts/harness/install-codex.sh:490] | evidentiary |
| PASS | `  PASS  artifact — /…/codex-turn.txt contains the fixed token (sha256 <64 hex>)` | the artifact's bytes equal the token [scripts/harness/install-codex.sh:496] | descriptive |
| FAIL | `  FAIL  artifact — /…/codex-turn.txt was not written` | no file appeared [scripts/harness/install-codex.sh:501] | evidentiary |
| FAIL | `  FAIL  <leg> — refused: <reason>` | any refusal, immediately before the verdict line [scripts/harness/install-codex.sh:74] | evidentiary (every refusal case in the test) |
| none | `CODEX: REFUSED (<leg>)` | the last line of any refused run, exit 2 [scripts/harness/install-codex.sh:75-76] | evidentiary |
| none | `CODEX: PASS` | `FAILED=0` [scripts/harness/install-codex.sh:333] | evidentiary |
| none | `CODEX: FAIL (4)` | the verdict carries the count — the only aggregate the file produces [scripts/harness/install-codex.sh:333] | evidentiary |
| none | `digest mismatch for <url>: want <a> got <b>` | `fetch_verified`'s **stderr** line, which the installer's FAIL row swallows because it captures nothing [scripts/lib.sh:23] [scripts/harness/install-codex.sh:360] | evidentiary (test B2 greps for it [tests/harness/codex-install-test.sh:186]) |

## 6. Failure modes

Direction is the module's measured behaviour. **fail closed** = the run stops or exits non-zero; **fail open** = the artifact is still produced from a weaker source; **degraded** = the run continues with a missing row.

| Failure | Presents as | Direction | Distinguished from | Recovery |
|---|---|---|---|---|
| **D-1** a key file is supplied for a turn | `line 442: VAR: unbound variable`, exit 1, after three PASS rows [scripts/harness/install-codex.sh:442] | **fail closed, but as a shell crash** — no row names the missing thing, no `CODEX:` verdict is printed, and `trap cleanup` has nothing to clean [scripts/harness/install-codex.sh:439-440] | A refusal exits **2** with `CODEX: REFUSED (<leg>)` [scripts/harness/install-codex.sh:75-76]; this exits 1 with a bash diagnostic. A turn that ran and failed auth prints `FAIL turn_exit — exit …` [scripts/harness/install-codex.sh:474] | none available in the file: the branch is unreachable as written. `--turn` with no key file uses the host login and works [scripts/harness/install-codex.sh:456]; fix `$VAR[CF_RUN_ID]` → `${VAR[CF_RUN_ID]}` first, then D-2 and D-3 |
| **D-2** (behind D-1) the key file ends with a newline — the shape `printf '%s\n'` produces, and the one the test itself creates [tests/harness/codex-install-test.sh:113] | `auth.json` contains a raw newline inside the JSON string; `JSONDecodeError: Invalid control character` (measured on the patched copy, transcript 10) | **fail closed at the turn, misdiagnosed**: codex would report an auth/parse failure, not "your key file has a trailing newline" | The installer's only content check is `grep -q '[^A-Za-z0-9._-]'`, which is per-line and therefore blind to the trailing newline by construction [scripts/harness/install-codex.sh:210-212] | strip the newline when writing (`printf`/`tr -d '\n'`) [scripts/harness/install-codex.sh:452]; or write the file with no trailing newline |
| **D-3** (behind D-1) `CF_RUN_ID` is attacker- or caller-controlled and is interpolated into `rm -rf` | `PASS turn_home — …/.cache/cf-codex/../../victim`, then `$HOME/victim` deleted, sentinel and all (transcript 10) | **fail closed on isolation**: the credential directory is created *outside* the intended root, and the EXIT trap deletes whatever that path resolves to [scripts/harness/install-codex.sh:443] [scripts/harness/install-codex.sh:439] | A normal run id creates exactly `$HOME/.cache/cf-codex/<id>` and nothing else | sanitise the id (allow `[A-Za-z0-9._-]` only) or refuse an id containing `/` or `..`; nothing in the file does either [scripts/harness/install-codex.sh:111] |
| **D-4** `$HOME/../<dir>` used as `CF_WORKDIR` or `CF_API_KEY_FILE` | `PASS workdir — …/home/../escape is a git work tree` and `PASS credential — … is a mode 600 file inside $HOME` for a path **outside** `$HOME` (transcript 8) | **fail open on containment**: both guards are textual prefix tests on the unnormalised string [scripts/harness/install-codex.sh:191] [scripts/harness/install-codex.sh:220] [scripts/harness/install-codex.sh:200] | `/etc` is refused correctly (test A4) because it does not start with `$HOME/`; the bypass needs the `$HOME/` prefix plus `..` | resolve with `realpath`/`readlink -f` and compare, or refuse any path containing `/..` |
| **D-5** `CODEX_HOME` already exported | the row says `turn_home — $HOME/.codex`, the child receives the ambient value (transcript 9); the rollout lookup still reads `$HOME/.codex` [scripts/harness/install-codex.sh:483] | **fail open on provenance**: the turn may use a credential home the row denies, and `model_served` then looks in the wrong tree and warns [scripts/harness/install-codex.sh:490] | The key-file branch sets `CODEX_HOME` explicitly and is immune [scripts/harness/install-codex.sh:466] — if it ran at all | add `-u CODEX_HOME` next to `-u OPENAI_API_KEY` in the host-login invocation [scripts/harness/install-codex.sh:470] |
| **D-6** a host-provided binary is on `PATH` | `--check` prints `FAIL binary — … the pin is unowned` and exits 1 [scripts/harness/install-codex.sh:315]; `--turn` prints `WARN binary — host-provided …` and runs it [scripts/harness/install-codex.sh:429-430] | **fail open in `--turn`** against a **fail closed in `--check`** for the same condition — the operator sees a red check and a green turn | A pinned `$BIN` makes both modes PASS [scripts/harness/install-codex.sh:313] | `--apply`, which installs the pin and relinks the shim [scripts/harness/install-codex.sh:385-397] |
| **D-7** `--base-url`, `--namespace`, `--lane`, `--max-turns` supplied | rows PASS or are silently ignored; the turn runs against codex's default endpoint [scripts/harness/install-codex.sh:107] [scripts/harness/install-codex.sh:110-114] | **fail open and silent**: three of them are *required* by the variable contract [specs/HARNESS-MATRIX.md:124-126] and the script enforces their presence [scripts/harness/install-codex.sh:71] [scripts/harness/install-codex.sh:177-182], but none is ever read again — so a lane that sets a router endpoint gets the public one | Nothing distinguishes "accepted" from "used": there is no row for any of the four | read the source: `grep -n CF_BASE_URL` returns only the declaration, the flag arm and the presence loop |
| **D-8** `--help` | the usage block stops mid-sentence at `and \`codex exec resume <id>\` continues a thread.` [scripts/harness/install-codex.sh:80] | **degraded**: exit 0 and a partly useful block, but the pin, credential and sidecar paragraphs — everything after line 20 — are cut off | Nothing else prints usage; an unknown flag prints its own one-liner first [scripts/harness/install-codex.sh:119] | read the header directly (lines 3-39), or widen the `sed` range [scripts/harness/install-codex.sh:80] |
| **D-9** a `curl` that is not the real one shadows the real one | the test's B3/B4/B5 fail with `digest mismatch … got e3b0c442…` — the sha256 of an empty file — while A1-A11 and B1/B2/B6/B7 pass | **fail closed, misattributed**: five FAILs that name the installer's download leg rather than the shadowing tool | A real digest corruption also fails B2 by design, but B2 passes here and only the *valid* digest case fails, which is the tell | run the suite with a clean `PATH`; the suite itself does not sanitise `PATH` for the apply legs [tests/harness/codex-install-test.sh:41] [tests/harness/codex-install-test.sh:49-53] |
| **D-10** nothing runs this suite automatically | `tests/selftest.sh` exercises `install-hermes.sh` only; no reference to codex or to `tests/harness/harness-conformance` exists in that file | **fail open**: the tree's gate is green while the codex ladder is unrun, which is how D-1 survived to `origin/main` | The battery would catch it only through `--check`, which never reaches line 442 [tests/harness-conformance.sh:213] | add the hermetic half to `tests/selftest.sh`, or run it in CI |
| No binary at all | `FAIL binary — absent`, plus three dependent FAILs, `CODEX: FAIL (4)`, exit 1 [scripts/harness/install-codex.sh:317] [scripts/harness/install-codex.sh:327-330] | **fail closed** and honest: four rows, one cause | A `PATH`-only binary gives one FAIL and three PASSes [scripts/harness/install-codex.sh:315] | `--apply` (needs the arch and the network) [scripts/harness/install-codex.sh:336-382] |
| Unsupported arch | `  FAIL  arch — refused: no measured codex artefact for aarch64/Linux in rust-v0.166.0 — this installer pins x86_64-unknown-linux-musl only` [scripts/harness/install-codex.sh:337-338] | **fail closed before anything is downloaded** | `--check` on the same arch only *warns* `no codex artefact for aarch64/Linux in rust-v0.166.0 — --apply would refuse` and continues to grade the binary [scripts/harness/install-codex.sh:309] | run on x86_64, or ship a digest for that target — the file will not guess one [scripts/harness/install-codex.sh:153-167] |
| Digest mismatch or unreachable release | `  FAIL  download — download or digest check failed for <url> (want sha256 <want>)`, exit 1, nothing installed [scripts/harness/install-codex.sh:358-362] [tests/harness/codex-install-test.sh:189-191] | **fail closed, no retry** — the header states a mismatch is a hard failure, never a retry [scripts/harness/install-codex.sh:32-34] | `fetch_verified` prints the wanted and the received digest on stderr [scripts/lib.sh:23] — the only place the *received* value appears; the installer's own row does not carry it | re-download; if it persists, the pin is wrong or the release was re-cut |
| Installed binary reports the wrong version | `  FAIL  version — installed binary reads back '0.165.0' != pin 0.166.0 — removed`; `$PREFIX` is deleted [scripts/harness/install-codex.sh:378-381] | **fail closed and self-cleaning**: nothing is left that would read as installed | The stale-pin arm replaces instead of failing, and says `replacing` [scripts/harness/install-codex.sh:347-349] | fix the download, re-run `--apply` |
| Disk below 1.0 GB | `  FAIL  disk — <n> GB free < floor 1.0 GB at <home>` then `CODEX: FAIL (1)`, exit 1 [scripts/lib.sh:41] [scripts/harness/install-codex.sh:339] | **fail closed before any write** | A download failure happens after the temp dir exists [scripts/harness/install-codex.sh:356] | free space; the floor is a constant, not a flag [scripts/harness/install-codex.sh:56] |
| Turn runs but writes nothing | `  FAIL  artifact — <workdir>/<TURN_FILE> was not written`, `CODEX: FAIL (1)` [scripts/harness/install-codex.sh:501] | **fail closed**: the turn is the proof, and the artifact is the turn | A file with the wrong bytes is `does not contain the fixed token` [scripts/harness/install-codex.sh:498] | read the captured stderr the FAIL row folded onto its line [scripts/harness/install-codex.sh:474]; the capture files are removed at the end of the mode [scripts/harness/install-codex.sh:503] |
| `lib.sh` missing beside the script | `line 42: …/lib.sh: No such file or directory` then `say: command not found` ×3 and `FAILED: unbound variable`, exit 1 (measured) | **fail closed as a crash**, not as rows — the report is unreadable and unattributable from its text | Every other failure here is a named `  FAIL  <key> —` row [scripts/lib.sh:7] | restage the script with the repo's `scripts/lib.sh` [scripts/node-create.sh:23] |

## 7. Environment and settings it reads

| Setting | Where read | Default | Effect of missing |
|---|---|---|---|
| `--check` / `--apply` / `--turn` / `--app-server` | first bare mode word in the loop [scripts/harness/install-codex.sh:94] | `--check` [scripts/harness/install-codex.sh:61] | a bare invocation is a check; nothing is installed or run |
| `--deep` | sets `DEEP=1` [scripts/harness/install-codex.sh:95] | `0` [scripts/harness/install-codex.sh:62] | `doctor --json` is not run; it is the only consumer [scripts/harness/install-codex.sh:325] |
| `--api-key-file <path>` / `CF_API_KEY_FILE` | `VAR[CF_API_KEY_FILE]` [scripts/harness/install-codex.sh:67] [scripts/harness/install-codex.sh:108] | empty | `--check`/`--apply` warn and continue [scripts/harness/install-codex.sh:237-239]; `--turn` notes the host login will be used [scripts/harness/install-codex.sh:183-185]. This is the **only** setting that changes where the credential comes from |
| `--model <id>` / `CF_MODEL` | [scripts/harness/install-codex.sh:66] [scripts/harness/install-codex.sh:105] | empty, and required whenever any `CF_*` is supplied [scripts/harness/install-codex.sh:171-182] | refusal `the CF_* set … is incomplete; missing: CF_MODEL …`, exit 2 [scripts/harness/install-codex.sh:180-182] |
| `--provider <id>` / `CF_PROVIDER` | [scripts/harness/install-codex.sh:66] [scripts/harness/install-codex.sh:106] | empty; mapped through `codex_provider` — `openai`, `openai-codex`, `codex` all become `openai`, anything else passes through [scripts/harness/install-codex.sh:146-151] | same refusal; an unmapped name is forwarded to codex verbatim |
| `--base-url <url>` / `CF_BASE_URL` | [scripts/harness/install-codex.sh:67] [scripts/harness/install-codex.sh:107] | empty; **accepted, validated, never used** (D-7) [scripts/harness/install-codex.sh:173] | no effect — the turn goes wherever codex defaults |
| `--workdir <dir>` / `CF_WORKDIR` | [scripts/harness/install-codex.sh:68] [scripts/harness/install-codex.sh:109] | empty; required with any `CF_*` | refusal on absence, on anything outside `$HOME` by prefix, and on a non-work-tree [scripts/harness/install-codex.sh:219-228]. Containment is a prefix test (D-4) [scripts/harness/install-codex.sh:220] |
| `--namespace <ns>` / `CF_NAMESPACE` | [scripts/harness/install-codex.sh:68] [scripts/harness/install-codex.sh:110] | empty; required with any `CF_*` | presence is enforced, content is never used (D-7) |
| `--run-id <id>` / `CF_RUN_ID` | [scripts/harness/install-codex.sh:69] [scripts/harness/install-codex.sh:111] | empty; required with any `CF_*` | required and then used only to name the isolated `CODEX_HOME` — at the line that crashes (D-1) and without sanitising (D-3) [scripts/harness/install-codex.sh:442] |
| `--lane <name>` / `CF_LANE` | [scripts/harness/install-codex.sh:69] [scripts/harness/install-codex.sh:112] | empty; required with any `CF_*` | presence is enforced, content is never used (D-7) |
| `--skills-dir <dir>` / `CF_SKILLS_DIR` | [scripts/harness/install-codex.sh:70] [scripts/harness/install-codex.sh:113] | empty, optional | documented as **accepted and unused**, because codex has its own `AGENTS.md` convention [scripts/harness/install-codex.sh:64-65] |
| `--max-turns <n>` / `CF_MAX_TURNS` | [scripts/harness/install-codex.sh:70] [scripts/harness/install-codex.sh:114] | empty, optional; no default, where the contract gives 40 [specs/HARNESS-MATRIX.md:129] | validated as an integer only — `CF_MAX_TURNS must be an integer, got '<v>'` [scripts/harness/install-codex.sh:186-187] — and never otherwise used |
| `--timeout-s <n>` / `CF_TIMEOUT_S` | `TIMEOUT_S` [scripts/harness/install-codex.sh:60] [scripts/harness/install-codex.sh:115] | `300` [scripts/harness/install-codex.sh:60] — the variable contract's budget default is 1800 [specs/HARNESS-MATRIX.md:129] | the turn's wall clock is `timeout "$TIMEOUT_S"` [scripts/harness/install-codex.sh:466] |
| `CF_CODEX_PIN` | `PIN="${CF_CODEX_PIN:-0.166.0}"` [scripts/harness/install-codex.sh:49] | `0.166.0` | changes `RELEASE`, `PREFIX`, `BIN` and the refusal text at once [scripts/harness/install-codex.sh:50-55]. Nothing re-derives the digest: `SHA256` is a constant for one release [scripts/harness/install-codex.sh:51], so a repinned run downloads a different version and fails the digest unless `CF_CODEX_SHA256` is *also* set |
| `CF_CODEX_SHA256` | `want="${CF_CODEX_SHA256:-$SHA256}"` [scripts/harness/install-codex.sh:353] | the constant [scripts/harness/install-codex.sh:51] | replaces the enforced digest. Together with the URL override this leaves **no** integrity check: whatever the caller names is what gets installed |
| `CF_CODEX_URL` | `url="${CF_CODEX_URL:-https://…}"` [scripts/harness/install-codex.sh:352] | the GitHub release URL | the test drives it with `file://` [tests/harness/codex-install-test.sh:184], which proves the loader is scheme-agnostic and that the digest is the only gate |
| `CF_CODEX_ARCH` | `arch="${CF_CODEX_ARCH:-$(uname -m)}"` [scripts/harness/install-codex.sh:157] | `uname -m` | overrides the target lookup; only `Linux/x86_64` has a measured digest, so anything else refuses by name [scripts/harness/install-codex.sh:164-167] [scripts/harness/install-codex.sh:337-338] |
| `CF_TURN_TOKEN` | `TURN_TOKEN="${CF_TURN_TOKEN:-CF-227-TOKEN-7f3a9c}"` [scripts/harness/install-codex.sh:58] | `CF-227-TOKEN-7f3a9c` | changes the token the turn must write, and therefore the artifact assertion [scripts/harness/install-codex.sh:460] [scripts/harness/install-codex.sh:495] |
| `CF_TURN_FILE` | `TURN_FILE="${CF_TURN_FILE:-codex-turn.txt}"` [scripts/harness/install-codex.sh:59] | `codex-turn.txt` | changes the file name the turn must create, inside `CF_WORKDIR` [scripts/harness/install-codex.sh:459-460]. Note `CF_TURN_FILE` is **not** in the `CF_*` table and no flag sets it |
| `CF_API_KEY`, `OPENAI_API_KEY` | refused when non-empty [scripts/harness/install-codex.sh:125-130] | must be absent | a run with either set exits **2** with `credential_ambient`, before any row — the environment is not a credential channel, so two lanes on one node cannot contaminate each other [scripts/harness/install-codex.sh:123-124] |
| `HOME` | `INSTALL_ROOT`, `PREFIX`, `BIN`, `SHIM` [scripts/harness/install-codex.sh:52-55]; containment [scripts/harness/install-codex.sh:191] | inherited, never defaulted | an empty `HOME` makes every path relative (`/.local/codex/…`), which `$HOME/*` patterns will not match — `inside_home` then refuses every workdir |
| `CODEX_HOME` | **not cleared** for the host-login turn [scripts/harness/install-codex.sh:470]; set explicitly for the key-file turn [scripts/harness/install-codex.sh:466] | inherited in the first case | the child uses the ambient value while the row claims `$HOME/.codex`, and `model_served` keeps looking in `$HOME/.codex` (D-5) [scripts/harness/install-codex.sh:483] |
| `TMPDIR` | `mktemp -d` under `umask 077` [scripts/harness/install-codex.sh:356]; the test's scratch root [tests/harness/codex-install-test.sh:35] | system temp | only affects where the download is staged; it is removed on every exit path [scripts/harness/install-codex.sh:359] [scripts/harness/install-codex.sh:373] |
| `PATH` | `have codex` [scripts/harness/install-codex.sh:133]; the `path_env` row [scripts/harness/install-codex.sh:393-396] | inherited | decides whether a host-provided binary answers, and therefore whether `--check` is red (D-6) — and, as D-9 shows, whether the right `curl` answers |
| `scripts/harness/harness-vars.sh` | sourced when present [scripts/harness/install-codex.sh:47] | absent in this tree | dead branch today: the file does not exist, and its CF-229 contract is not landed [scripts/harness/install-codex.sh:44-46] |
| `specs/HARNESS-MATRIX.md §4` as cited | three citations name §4 [scripts/harness/install-codex.sh:38] [scripts/harness/install-codex.sh:64] [scripts/harness/install-codex.sh:181] | — | §4 in that file is "The resolution rule"; the variable contract the script means is **§5** [specs/HARNESS-MATRIX.md:111]. A stale citation, and the reason the comments and the table disagree about which variables are required |

The only secret-adjacent values in this file are the key file's path and its contents. The path is echoed (never the contents) in PASS and FAIL rows [scripts/harness/install-codex.sh:197-213]; the value is read exactly once, by `cat`, into a `chmod 600` temporary inside an isolated `CODEX_HOME` that an EXIT trap deletes [scripts/harness/install-codex.sh:452] [scripts/harness/install-codex.sh:440] — and that whole branch does not execute (D-1). This matches the fleet's rule that credentials travel as mode-600 file paths, never as argv values [docs/master/_facts.md:16] (fact: FACT-05).

## 8. Evidence of record

- **Measured 2026-11-05**, clean worktree of `b31c232` (`~/proj-wt-md-16c`), Linux x86_64, bash 5.3.9, git 2.53.0: every transcript in §3 is literal terminal output, and every command in §3 was executed in the order listed. Checks 1-5, 7 and 12 pass; checks 8-11 are the measurements that produced D-1 through D-5; check 6 was deliberately not run because its C2 leg spends a real model turn against the host login [tests/harness/codex-install-test.sh:287-289].
- **The install itself is measured, not asserted**: the release tarball downloaded today hashes to the constant in the file, and the member it contains is byte-identical to the binary in `$HOME/.local/codex/0.166.0/bin/` (transcript 6). So "the pin" in this document means a digest that was re-derived from the release host on the day of writing, not a number copied from the header.
- **The suite that covers this file**: `tests/harness/codex-install-test.sh`, 303 lines, in two halves — hermetic (every refusal, the whole install ladder against a locally built mirror tarball whose digest the test computes itself, `--hermetic` skips the live legs by name) and live (one real turn whose artifact must equal `CF-227-TOKEN-7f3a9c`) [tests/harness/codex-install-test.sh:7-18] [tests/harness/codex-install-test.sh:285]. Its hermetic half is green here (transcript 5) and covers none of D-1 through D-5: every turn case it runs either supplies no key file (so the crashing branch is never entered) or skips [tests/harness/codex-install-test.sh:274-277].
- **A skipped leg is the honest shape and a green leg that never ran is not** — the file's own rule for its live half [tests/harness/codex-install-test.sh:13-16], and the same discipline this document applies to check 6, which is recorded as not run rather than as passed.
- **The evidence discipline this document follows** — a row closes only with a re-runnable command, never a summary — is the project's own rule [docs/master/_facts.md:21] (fact: FACT-10), and a harness counts as supported only when the battery's legs pass on a real node [docs/master/_facts.md:19] (fact: FACT-08). On that second test this file is **not yet supported**: its `--check` passes, but the credential-bearing turn path cannot run (D-1).

Defects measured while filling this section (documented, **not** fixed — `scripts/` and `tests/` are out of scope for this task):

**CF-277 landed after this audit** validates `CF_RUN_ID` at admission as a bare identifier (`^[A-Za-z0-9][A-Za-z0-9._-]*$`, at most 128 chars) and makes the turn home a fresh `mktemp -d` directory under `${XDG_CACHE_HOME:-$HOME/.cache}/cf-codex` that the EXIT trap removes only when the path is one leaf under that root — closing D-1 and D-3 below, while D-2 and D-4 through D-11 stand as measured.

1. **D-1 — the key-file turn branch is dead: `$VAR[CF_RUN_ID]` instead of `${VAR[CF_RUN_ID]}`.** Line 442 interpolates `$VAR` (a variable that does not exist) followed by the literal text `[CF_RUN_ID]`, and `set -u` turns that into `line 442: VAR: unbound variable`, exit 1 [scripts/harness/install-codex.sh:442]. Every `--turn` with `CF_API_KEY_FILE` set dies there — measured — before `config.toml` or `auth.json` is written and before `codex` is invoked. The branch that isolates the credential, the one the file's header advertises [scripts/harness/install-codex.sh:37-39] [scripts/harness/install-codex.sh:435-437], is therefore unreachable; only the ambient host-login branch works [scripts/harness/install-codex.sh:456]. The hermetic test cannot see it because its only turn case runs without a key file.
2. **D-2 — a newline-terminated key file produces invalid `auth.json`.** The construction at [scripts/harness/install-codex.sh:452] concatenates the key file's bytes into a JSON string with `cat`, so a trailing newline (what `printf '%s\n'` writes, and what the test itself creates [tests/harness/codex-install-test.sh:113]) lands as a raw control character inside the string. Measured on the patched copy: `JSONDecodeError: Invalid control character at: line 1 column 48`. The only content guard is a per-line `grep` [scripts/harness/install-codex.sh:210-212], which is structurally blind to it.
3. **D-3 — `CF_RUN_ID` reaches `rm -rf` unsanitised.** `turn_home="$HOME/.cache/cf-codex/<id>"` [scripts/harness/install-codex.sh:442], then `rm -rf "$turn_home"` [scripts/harness/install-codex.sh:443], then the EXIT trap removes the same path again [scripts/harness/install-codex.sh:439-440]. With `CF_RUN_ID=../../victim` the patched copy deleted `$HOME/victim` and its sentinel (transcript 10). The id is a plain string from argv/env with no character check [scripts/harness/install-codex.sh:111].
4. **D-4 — `inside_home` is a textual prefix test, so `$HOME/../x` passes as "inside `$HOME`".** `case "$1" in "$HOME"/*)` [scripts/harness/install-codex.sh:191] is applied to the raw string for both the workdir [scripts/harness/install-codex.sh:220] and the key file [scripts/harness/install-codex.sh:200]. Measured: `$HOME/../escape` and `$HOME/../keys/k` both PASS, on a directory that is a sibling of `$HOME` (transcript 8). `/etc` is refused, so the guard looks sound until a path carries the prefix and climbs out.
5. **D-5 — an ambient `CODEX_HOME` is inherited, and the row denies it.** The host-login invocation clears only `OPENAI_API_KEY` [scripts/harness/install-codex.sh:470], while the row printed above it claims `$HOME/.codex` [scripts/harness/install-codex.sh:456]. Measured with a stub: the child received `CODEX_HOME=<ambient value>` (transcript 9). The rollout lookup then still reads `$HOME/.codex/sessions` [scripts/harness/install-codex.sh:483], so `model_served` can warn for a turn that in fact ran elsewhere [scripts/harness/install-codex.sh:490].
6. **D-6 — the same condition is FAIL in `--check` and WARN in `--turn`.** A host-provided binary fails the check's `binary` leg [scripts/harness/install-codex.sh:315] and only warns in the turn [scripts/harness/install-codex.sh:429-430]. Measured in one session: `--check` printed `FAIL binary — …`, the turn printed `WARN binary — …` and then ran it.
7. **D-7 — the CF_* contract is enforced and then not consumed, and two defaults diverge.** `CF_NAMESPACE`, `CF_RUN_ID` and `CF_LANE` are *required* by the variable contract [specs/HARNESS-MATRIX.md:124-126] and the script refuses a run that omits them [scripts/harness/install-codex.sh:71] [scripts/harness/install-codex.sh:177-182] — and no code path reads any of the three afterwards: `grep -n` returns only the declaration, the flag arm and the presence loop. `CF_BASE_URL`, optional with "default = node router" in the contract [specs/HARNESS-MATRIX.md:121], is settable and equally unused [scripts/harness/install-codex.sh:107], so a lane that names a node router gets codex's default endpoint and no row saying which one was used. `CF_MAX_TURNS` has no default here where the contract gives 40, and the turn's own timeout default is 300 s [scripts/harness/install-codex.sh:60] where the contract gives 1800 [specs/HARNESS-MATRIX.md:129].
8. **D-8 — `usage()` cuts the header off mid-sentence.** `sed -n '3,20p'` [scripts/harness/install-codex.sh:80] runs nine lines past the end of the mode list, ending inside the `exec` paragraph; the pin rationale, the npm trade-off and the whole credential contract (lines 21-39) never print. Measured: `--help` exits 0 and stops at `and \`codex exec resume <id>\` continues a thread.`. The one place an operator would look for the auth rules is the one place they are invisible.
9. **D-9 — the test suite inherits `PATH`, so a shadowing `curl` produces five spurious FAILs.** `clean_env` unsets credentials only [tests/harness/codex-install-test.sh:41], while B1 and B7 isolate `PATH` by hand [tests/harness/codex-install-test.sh:177] [tests/harness/codex-install-test.sh:245]. Measured in a session whose `PATH` carried a fixture `curl`: `21 passed, 5 failed` with `digest mismatch … got e3b0c442…` (the sha256 of an empty file) on B3/B4/B5, and `26 passed, 0 failed, 1 skipped` once `PATH` was clean. The failure names the installer's download leg, not the shadowing tool.
10. **D-10 — no suite runs this installer.** `tests/selftest.sh` exercises `install-hermes.sh` repeatedly and never names codex [tests/selftest.sh:317]; `tests/harness-conformance.sh` would exercise `--check` only, which cannot reach line 442 [tests/harness-conformance.sh:213]. The hermetic half of `codex-install-test.sh` is the sole coverage, and it is not wired into anything that runs on commit — which is how D-1 shipped.
11. **D-11 — the battery's matrix row and the installer disagree about the turn's own flags.** `tests/harness-conformance.sh` records codex's non-interactive surface as `codex exec --skip-git-repo-check -s workspace-write "<prompt>"` [tests/harness-conformance.sh:91], while the installer deliberately does **not** pass `--skip-git-repo-check` and instead refuses a workdir that is not a git tree [scripts/harness/install-codex.sh:221-228]. Two statements of one contract; the installer's is the stricter and the one measured here.
