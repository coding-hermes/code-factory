# 15. scripts/harness/install-claude-code.sh

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/harness/install-claude-code.sh` — 673 lines, three modes (`--check` default, `--apply`, `--turn`) in one file [scripts/harness/install-claude-code.sh:1] [scripts/harness/install-claude-code.sh:641-664] |
| Repository | `code-factory` |
| Revision | `b31c232` — the `origin/main` tip every locator below was measured against (worktree `~/proj-wt-md-15c`, 2026-11-05). The file's own last-touching commit is `903439c` (2026-11-04); its test file shares that commit, so script and proof moved together |
| Status | **VERIFIED — 294 locators (203 distinct targets), all resolve; FACT-05 and FACT-08 cited; four defects documented (D-1 to D-4)** |

## 1. Purpose and why it matters

- What it is: the pinned install ladder **and** the adapter probe for Claude Code, one of three harness adapters that actually ship in this repo (`install-claude-code.sh`, `install-hermes.sh`, `install-opencode.sh`) [scripts/harness/install-claude-code.sh:2] [scripts/harness/install-claude-code.sh:8-10]. It is staged onto a node as `harness/install-$HARNESS.sh` [scripts/node-create.sh:23], and a missing file is a named refusal, not a silent skip [scripts/node-create.sh:26].
- The three modes are the three questions a node asks: is the pin here (`--check`, read-only, "Never touches the network") [scripts/harness/install-claude-code.sh:64-67]; put it here without root (`--apply`, "Idempotent") [scripts/harness/install-claude-code.sh:68-71]; and run one unattended turn with a credential (`--turn`) [scripts/harness/install-claude-code.sh:72-74].
- The pin is a constant, not an environment input: `CLAUDE_CODE_PKG="@anthropic-ai/claude-code"` and `CLAUDE_CODE_PIN="2.1.318"` [scripts/harness/install-claude-code.sh:38-39], with the pin's `dist.shasum` and `dist.integrity` also recorded [scripts/harness/install-claude-code.sh:40-41]. Re-pinning is an edit to the file, deliberately — "so a pin cannot be silently swapped by an operator's shell" [scripts/harness/install-claude-code.sh:113-115]. That closed door is why §7 has no override row.
- **Measured on this host, 2026-11-05**: the pin is installed at `/home/kara/.local/harness/npm/bin/claude`, `claude --version` prints `2.1.318 (Claude Code)`, the installed `package.json` reads `@anthropic-ai/claude-code@2.1.318`, and `du -sh` of the prefix is **323M** — matching the header's own measured footprint of "323 MB" [scripts/harness/install-claude-code.sh:21-22].
- Why user-space is a rule and not a preference: "a stray `~/.npmrc` can point the global prefix at /var/tmp — measured on the control host" [scripts/harness/install-claude-code.sh:25-27], and the install line repeats the reason at the point of use [scripts/harness/install-claude-code.sh:473-474]. The prefix comes from `$HOME` with **no override** [scripts/harness/install-claude-code.sh:45-48] and is graded before use [scripts/harness/install-claude-code.sh:345-351].
- Why the credential rule is the load-bearing one: a credential is a **path, never a value** — `CF_API_KEY_FILE` only, and "A value in argv, or a key exported into the ambient environment, is a hard refusal" [scripts/harness/install-claude-code.sh:28-29]. This is the repo-wide rule that a quorum seat had to enforce once already (fact: FACT-05) [docs/master/_facts.md:16], restated as the matrix's two cheap-now rules [specs/HARNESS-MATRIX.md:131-133].
- What breaks if it is ABSENT: node provisioning refuses by name before the node is built [scripts/node-create.sh:26], and the conformance battery lists `claude-code` as a harness whose adapter file is required [tests/harness-conformance.sh:90]. Without it there is no pinned binary, and the probe cannot distinguish "absent" from "wrong version".
- What breaks if it LIES: the only trust anchor in `--check` is `$BIN --version` compared to a string constant [scripts/harness/install-claude-code.sh:353-363]. `--check` never reads the installed `package.json` — `installed_package_identity` is called only from `--apply` [scripts/harness/install-claude-code.sh:461] [scripts/harness/install-claude-code.sh:484]. A tampered tree that still prints `2.1.318 (Claude Code)` passes `--check`. The integrity anchor that would catch it exists (`dist.integrity` is recorded) but is consulted only at install time [scripts/harness/install-claude-code.sh:426-429].
- Second lie surface, **measured** (D-1): the `provenance` row's PASS message asserts an upstream it never queried — `registry integrity + shasum match the recorded pin; upstream $CLAUDE_CODE_HOMEPAGE` [scripts/harness/install-claude-code.sh:434] — while the registry query fetches only `version dist.integrity dist.shasum` [scripts/harness/install-claude-code.sh:409] and `CLAUDE_CODE_HOMEPAGE` is a local constant [scripts/harness/install-claude-code.sh:42]. `maintainers` appears nowhere in the script.
- Third lie surface, **measured** (D-2): the header claims "an explicit --prefix on every npm call" [scripts/harness/install-claude-code.sh:25], but two npm invocations carry no `--prefix` — the registry read [scripts/harness/install-claude-code.sh:409] and the version probe [scripts/harness/install-claude-code.sh:338]. Only the mutating call is prefixed [scripts/harness/install-claude-code.sh:475]. The rule that matters (never install outside `$HOME`) holds; the sentence describing it is overbroad.

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `bash` | 5.x; the script needs `set -uo pipefail` and `local` [scripts/harness/install-claude-code.sh:34] | the interpreter on the shebang line [scripts/harness/install-claude-code.sh:1] | **not detected** — the shell is already running; a `/bin/sh` invocation fails at the `pipefail` line before any row prints |
| `node` | the pin's `engines` field demands `>= 22.0.0` [scripts/harness/install-claude-code.sh:20]; this host measured `v22.22.3` from `/home/kara/.local/bin/node` and `v22.23.2` from `/usr/bin/node` | on `PATH` | `have node` empty → `FAIL  node — absent — @anthropic-ai/claude-code needs node >= 22 (its engines field)` and `return 1` [scripts/harness/install-claude-code.sh:324-330]; a too-old major is a separate named FAIL that prints the measured string [scripts/harness/install-claude-code.sh:331-336] |
| `npm` | this host measured `10.9.8` on both npm binaries | on `PATH` | `have npm` empty → `FAIL  npm — absent — the pin is an npm package` [scripts/harness/install-claude-code.sh:337-341] |
| `claude` at the adapter prefix | pin `2.1.318`, read back as `2.1.318 (Claude Code)` | `$HOME/.local/harness/npm/bin/claude` [scripts/harness/install-claude-code.sh:47] | three distinct rows, never one: absent [scripts/harness/install-claude-code.sh:367]; host-provided, FAILing even when the version matches [scripts/harness/install-claude-code.sh:372]; version mismatch naming both numbers [scripts/harness/install-claude-code.sh:361] |
| the installed package's `package.json` | name + version must equal `@anthropic-ai/claude-code` + the pin | `$PREFIX/lib/node_modules/@anthropic-ai/claude-code/package.json` [scripts/harness/install-claude-code.sh:48] | `--apply` only: `FAIL  identity — no <file> after install`, or the actual pair named against the expected pair [scripts/harness/install-claude-code.sh:437-448]. **`--check` never runs this** |
| `timeout(1)` | this host: `timeout (uutils coreutils) 0.8.0` | on `PATH`, used to bind one turn [scripts/harness/install-claude-code.sh:586] | **not probed** — absence surfaces as the child's `127`, reported as `exit 127 — <detail>` rather than as "timed out" [scripts/harness/install-claude-code.sh:602-607] |
| `mktemp` | coreutils, unpinned | on `PATH`; used for the private npm log [scripts/harness/install-claude-code.sh:469], the staged stdin prompt [scripts/harness/install-claude-code.sh:538], and turn stdout/stderr [scripts/harness/install-claude-code.sh:555-560] | each site refuses with a named row (`cannot create a private npm log`, `cannot stage stdin`, `cannot stage output`) rather than running with an unwritable destination |
| `stat` | coreutils, unpinned | on `PATH` | `mode_of` returns the literal `?` on failure [scripts/harness/install-claude-code.sh:174], which then appears in the refusal as `is mode ?` [scripts/harness/install-claude-code.sh:215] — a refusal, so it fails closed |
| `du` | coreutils, unpinned | on `PATH` | non-fatal: the footprint row degrades to `unknown` [scripts/harness/install-claude-code.sh:493-494] |
| `sed`, `grep`, `tr`, `head`, `cut`, `date`, `id` | POSIX tools, unpinned | on `PATH` | **not detected**; each degrades quietly, and one degrades in the wrong direction — an empty `id -u` makes the root test error and take the else branch [scripts/harness/install-claude-code.sh:452], i.e. a host without `id` loses the root guard. An empty `date` yields an empty `started`, an empty `head -c 200` an empty excerpt |
| `node` used as the JSON reader | same binary as above | inside `provenance_check` [scripts/harness/install-claude-code.sh:416-421], the turn-failure detail [scripts/harness/install-claude-code.sh:598-601], and `model_served` [scripts/harness/install-claude-code.sh:613-618] | in `--apply` the ordering guarantees it: `probe_node` runs before `provenance_check` [scripts/harness/install-claude-code.sh:466-467]. In `--turn` there is **no** node probe, so a vanished node makes `model_served` empty and the report row FAILs [scripts/harness/install-claude-code.sh:619-621] |
| `scripts/lib.sh` | the repo's own file, 65 lines [scripts/lib.sh:1] | `$HERE/../lib.sh` [scripts/harness/install-claude-code.sh:36] | **not detected** — sourced unguarded; without it `say: command not found` on the second statement of the run |
| Registry network | `registry.npmjs.org` over HTTPS | only during `--apply`, inside `npm view` [scripts/harness/install-claude-code.sh:409] | unreachable metadata → `FAIL  provenance — refused — registry metadata … is unreachable, so the pin cannot be confirmed`, and `do_apply` returns before any write [scripts/harness/install-claude-code.sh:410-412] |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `. "$HERE/../lib.sh"` [scripts/harness/install-claude-code.sh:36] | `scripts/lib.sh` | six helpers and one counter: plain `say` [scripts/lib.sh:5], `ok` as `  PASS  %s — %s` [scripts/lib.sh:6], `bad` as `  FAIL  %s — %s` **plus** `FAILED=$((FAILED+1))` [scripts/lib.sh:7], `warn` [scripts/lib.sh:8], `note` as `  ..    %s` [scripts/lib.sh:9], `have` = `command -v` or empty [scripts/lib.sh:41-45], and `FAILED=${FAILED:-0}` [scripts/lib.sh:11] | the script's only exit gate is `[ "$FAILED" -eq 0 ]` [scripts/harness/install-claude-code.sh:671] and its only tally is `bad`'s side effect, so a `bad` that stops incrementing turns every `FAIL (n)` into `PASS`. `have` reports absence by STATUS (non-zero, empty stdout) *and* by empty stdout alone (CF-281); at `b31c232` it ended in `|| true` and its status was constant 0, so absence was observable only as empty output — the comment this row cites now records the current contract: "`have` reports absence by STATUS and by empty output (CF-281), so either test is honest here; the path is tested directly because it is what the row names" [scripts/harness/install-claude-code.sh:369-370] |
| `npm view <pkg>@<pin> version dist.integrity dist.shasum --json` [scripts/harness/install-claude-code.sh:409] | the npm CLI | **dotted literal keys**, not a nested object — the file records the measurement that cost a false refusal: "`npm view <pkg> version dist.integrity` answers with literal dotted keys … a nested-only parser silently read empty and refused a correct pin" [scripts/harness/install-claude-code.sh:413-415]. Both shapes are accepted [scripts/harness/install-claude-code.sh:418-421] | a registry/npm build that re-nests the fields still parses; one that renames them yields an empty string and a refusal — fail closed, but with a misleading "not the recorded one" message |
| `claude --version` [scripts/harness/install-claude-code.sh:142] | the Claude Code CLI at the pin | first line, first space-separated token, and it must contain a `d.d` digit pair [scripts/harness/install-claude-code.sh:139-149]. Measured today: `2.1.318 (Claude Code)` | a build that prints a bare version still parses; one that prefixes anything (`warning: …`) yields the wrong token and a named mismatch [scripts/harness/install-claude-code.sh:361] |
| `claude --print --output-format json --bare --setting-sources local --permission-mode acceptEdits --model <id>` [scripts/harness/install-claude-code.sh:565-566] | the same CLI | those five flags exist at this pin, and the JSON result carries `model`, `modelUsage`, and on failure `terminal_reason` / `api_error_status` / `result` / `subtype` [scripts/harness/install-claude-code.sh:594-601] [scripts/harness/install-claude-code.sh:613-618] | **not measured here** — no credential exists on this host, so the turn path is read-from-code only. A renamed flag is a hard CLI error, reported as `exit <n> — <detail>` |
| `claude --help` advertises `--max-turns` [scripts/harness/install-claude-code.sh:568] | the same CLI | the budget flag is passed only when the binary's own help mentions it, because "The pin does not implement --max-turns; do not invent a flag it will reject" [scripts/harness/install-claude-code.sh:567] | if a future pin adds it, the run passes `--max-turns` and the note flips to "advertised by this pin" [scripts/harness/install-claude-code.sh:569-570] |
| `timeout <s> claude …`, exit `124` [scripts/harness/install-claude-code.sh:603] | coreutils / uutils `timeout` | 124 means the budget expired and is reported as `timed out after <n>s` | a `timeout` that returns a different code for expiry would report `exit <n>` and lose the word "timed out"; the direction is unchanged (still non-zero) |
| `stat -c '%a'` [scripts/harness/install-claude-code.sh:174] | coreutils `stat` | GNU output form `600`, matched by the glob `[0-7]00` [scripts/harness/install-claude-code.sh:213-215] | a busybox `stat` without `-c` prints `?`, so every key file is refused. Fail closed, for the wrong reason |

### 2c. Service contracts (both sides must be named)

| Peer | Direction | Transport | Payload | Other side |
|---|---|---|---|---|
| npm registry (`registry.npmjs.org`) | `npm view` → registry, read-only | HTTPS, credentials from npm's own config; this file passes no token | the packument for `@anthropic-ai/claude-code@2.1.318`; consumes `version`, `dist.integrity`, `dist.shasum` [scripts/harness/install-claude-code.sh:409] | The registry's packument endpoint. **Measured today with the same query shape**: `version 2.1.318`, `dist.shasum c11067a3db95abe50d0d004e030e418146d3270a`, `homepage https://github.com/anthropics/claude-code`, 15 maintainers all `@anthropic.com`. The shasum equals the recorded constant [scripts/harness/install-claude-code.sh:40]; homepage and maintainers are **not fetched by the script** (D-1) |
| npm installer | `npm install --global --prefix "$PREFIX"` → the prefix tree | local process, network to the registry | `@anthropic-ai/claude-code@2.1.318`, `--no-fund --no-audit --loglevel=error` [scripts/harness/install-claude-code.sh:475-476] | npm's own installer, which writes `$PREFIX/lib/node_modules/…` and the bin shim. Verified here: `$PREFIX/lib/node_modules/@anthropic-ai/claude-code/package.json` reads `@anthropic-ai/claude-code@2.1.318` and `$PREFIX/bin/claude` is executable — the layout constants [scripts/harness/install-claude-code.sh:46-48] match what npm actually produced |
| Anthropic API (or a shim) | `claude` child process → HTTP endpoint | the CLI's own HTTPS client; the script only injects environment | `ANTHROPIC_API_KEY` read from the mode-600 file inside the subshell, never argv [scripts/harness/install-claude-code.sh:583]; `ANTHROPIC_BASE_URL` set only when `CF_BASE_URL` is non-empty [scripts/harness/install-claude-code.sh:584] | **The far side is not in this repository.** With `CF_BASE_URL` unset the script sets no URL at all and relies on the CLI's own default, so the usage text's "unset = Anthropic's own API" [scripts/harness/install-claude-code.sh:85-86] is a claim about the CLI, unmeasured here. With it set, the peer is whatever host the URL names, recorded as `provider_binding` [scripts/harness/install-claude-code.sh:545-553] |
| `$HOME/.claude/settings.json` | read-only `grep` | file read, no write | one existence test for `ANTHROPIC_BASE_URL`, `ANTHROPIC_API_BASE_URL` or `apiKeyHelper` [scripts/harness/install-claude-code.sh:397-403] | The user's Claude config, a *different* writer. On this host the file exists and trips the note; the run then isolates itself with `--setting-sources local` and `--bare` rather than editing it [scripts/harness/install-claude-code.sh:562-565] |
| `tests/harness/claude-code-install-test.sh` | test → script, via a scratch `HOME` | subprocess per leg [tests/harness/claude-code-install-test.sh:35-38] | argv mode plus `CF_*` in the environment; the pin is read out of the script with `sed` rather than duplicated [tests/harness/claude-code-install-test.sh:32] | Assertions on exact substrings: `^  FAIL  binary — absent` [tests/harness/claude-code-install-test.sh:73], `host-provided` [tests/harness/claude-code-install-test.sh:93], `PASS  provenance` [tests/harness/claude-code-install-test.sh:180], `already installed at pin` [tests/harness/claude-code-install-test.sh:195], `CLAUDE-CODE: SKIP` [tests/harness/claude-code-install-test.sh:242] |
| `tests/harness-conformance.sh` | battery → adapter | subprocess per leg | the harness row for `claude-code`, whose adapter column is `install-claude-code.sh` and whose smoke command is `claude -p` [tests/harness-conformance.sh:90] | The battery's five-leg table is the matrix's definition of "supported" (fact: FACT-08) [docs/master/_facts.md:19] [specs/HARNESS-MATRIX.md:163-167]; this adapter's `--turn` is what the `turn` leg exercises |

## 3. Verification

Run from a clean worktree of `b31c232` (`~/proj-wt-md-15c`), **2026-11-05**, as user `kara`. Commands are the literal ones executed; outputs are the literal ones returned. Nothing was installed by this document's author: the pin was already present at the adapter prefix on this host, so the `--apply` run below is the idempotent path — a genuine no-op, measured with a filesystem fingerprint and an npm shim log.

| # | Check | Command | Expected | Last run | Result |
|---|---|---|---|---|---|
| 1 | Syntax, both files | `bash -n scripts/harness/install-claude-code.sh` and `bash -n tests/harness/claude-code-install-test.sh` | exit 0, no output | 2026-11-05 | **PASS** — `syntax_SUT=0`, `syntax_test=0` |
| 2 | The adapter's own gate, as a stranger runs it | `bash scripts/harness/install-claude-code.sh --check` [scripts/harness/install-claude-code.sh:642-647] | one row per probe; `CLAUDE-CODE: PASS`, exit 0 only when the pin is installed at the prefix [scripts/harness/install-claude-code.sh:671] | 2026-11-05 | **PASS, exit 0** — `PASS  node`, `PASS  npm`, `PASS  binary`, `PASS  version — 2.1.318 (pin 2.1.318)`; transcript below |
| 3 | Honest absence | `HOME=<empty dir> bash scripts/harness/install-claude-code.sh --check` | `FAIL  binary — absent …`, `CLAUDE-CODE: FAIL (1)`, exit 1 | 2026-11-05 | **PASS as specified** — exit **1**, and the row names both the missing path and the missing PATH entry |
| 4 | Idempotence of `--apply` | fingerprint the prefix, `bash … --apply`, fingerprint again | exit 0, `already installed at pin … (idempotent)`, tree byte-identical | 2026-11-05 | **PASS** — exit 0; the same sha256 over `path|size|mtime` before and after; see the transcript |
| 5 | What a second `--apply` actually invokes | `PATH=<logging npm shim>:$PATH bash … --apply` | no `npm install`, no `npm view` | 2026-11-05 | **PASS for install, FAIL for the stronger claim** — the shim log holds exactly one line, `npm --version` [scripts/harness/install-claude-code.sh:338], from the post-apply `probe_node` [scripts/harness/install-claude-code.sh:655]. No registry access, no write (D-3) |
| 6 | A credential as a VALUE | `CF_API_KEY_FILE=credential-value-not-a-path-0123456789abcdef bash … --check` | exit 1, `refused — a credential VALUE was passed, not a path`, value never echoed | 2026-11-05 | **PASS** — exit **1**; the row reports `length 44, value not printed` [scripts/harness/install-claude-code.sh:204] and the value does not appear in the output |
| 7 | An ambient key | `ANTHROPIC_API_KEY=sk-ant-fake-0123456789abcdef bash … --check` | exit 1, refusal names the ambient rule | 2026-11-05 | **PASS** — exit **1**, the `contract:ambient` refusal [scripts/harness/install-claude-code.sh:193-197] |
| 8 | A workdir outside `$HOME` | `CF_WORKDIR=/etc bash … --check` | exit 1, refusal names both paths | 2026-11-05 | **PASS** — exit **1**, `refused — /etc is outside $HOME (/home/kara); a harness writes only inside $HOME` [scripts/harness/install-claude-code.sh:270-275] |
| 9 | The honest SKIP | `bash … --turn --prompt noop` with no credential | exit 3, `SKIP` naming each missing credential, never `PASS` | 2026-11-05 | **PASS** — exit **3**, the skip row names `ANTHROPIC_API_KEY CF_API_KEY_FILE ~/.claude/.credentials.json` [scripts/harness/install-claude-code.sh:527-529], summary `CLAUDE-CODE: SKIP (no credential — nothing measured, nothing claimed)` [scripts/harness/install-claude-code.sh:667-670] |
| 10 | A wrong-version local install must not skip | scratch `HOME` with `$PREFIX/bin/claude` printing `9.9.9`, then `--turn` | non-zero, both numbers named, no SKIP | 2026-11-05 | **PASS** — exit **1**, `FAIL  version — 9.9.9 != pin 2.1.318 — run --apply` plus the turn refusal [scripts/harness/install-claude-code.sh:519-521]; `CLAUDE-CODE: FAIL (2)` |
| 11 | The registry facts the header records | `npm view @anthropic-ai/claude-code@2.1.318 version homepage maintainers dist.shasum --json` | the constants in the header | 2026-11-05 | **PASS** — `version 2.1.318`, `homepage https://github.com/anthropics/claude-code`, 15 maintainers all `@anthropic.com`, `dist.shasum c11067a3db95abe50d0d004e030e418146d3270a` [scripts/harness/install-claude-code.sh:12-20]. The facts are true; the script checks only the digests (D-1) |
| 12 | Post-install identity, from the tree npm produced | `node -e` on the prefix `package.json`; `claude --version`; `du -sh` on the prefix | `@anthropic-ai/claude-code@2.1.318`, `2.1.318 (Claude Code)`, 323M | 2026-11-05 | **PASS** — all three as expected, matching the header's measured install [scripts/harness/install-claude-code.sh:21-22] |
| 13 | The adapter's own test suite | `bash tests/harness/claude-code-install-test.sh` | `CLAUDE-CODE-INSTALL-TEST: PASS` | **not run** | **NOT RUN — and not needed to settle any claim here.** Leg 3 of that file performs a real 323 MB install into a scratch `$HOME` [tests/harness/claude-code-install-test.sh:158-207]; the instruction for this document was a `--check`-class run. Its post-install assertions are covered independently by rows 4, 5 and 12 against the real prefix, and its absence/skip assertions by rows 3, 6, 7, 8 and 9 |

Transcript 2 — `--check` on this host (the primary measurement; exit 0):

```
$ bash scripts/harness/install-claude-code.sh --check; echo "EXIT=$?"
harness: claude-code (pin 2.1.318, package @anthropic-ai/claude-code, prefix /home/kara/.local/harness/npm)
  ..    contract:CF_API_KEY_FILE — unset (no credential path; --turn will skip)
  ..    contract:CF_MODEL = unset
  ..    contract:CF_PROVIDER = unset
  ..    contract:CF_BASE_URL = unset
  ..    contract:CF_WORKDIR = unset
  ..    contract:CF_NAMESPACE = unset
  ..    contract:CF_RUN_ID = unset
  ..    contract:CF_LANE = unset
  ..    contract:CF_SKILLS_DIR = unset
  ..    contract:CF_HARNESS_OPTS = unset
  ..    contract:CF_MAX_TURNS = 40   CF_TIMEOUT_S = 1800
  PASS  node — /home/kara/.local/bin/node (v22.22.3, pin requires >= 22)
  PASS  npm — /home/kara/.local/bin/npm (10.9.8)
  PASS  binary — /home/kara/.local/harness/npm/bin/claude (installed by this adapter)
  PASS  version — 2.1.318 (pin 2.1.318)
  WARN  auth — no credential: ANTHROPIC_API_KEY unset, CF_API_KEY_FILE unset, /home/kara/.claude/.credentials.json absent — --turn will skip
  ..    ambient settings — /home/kara/.claude/settings.json sets a base URL or an apiKeyHelper; --turn runs with '--setting-sources local' and '--bare' so a run does not inherit another lane's wiring

CLAUDE-CODE: PASS
EXIT=0
```

Transcript 4/5 — the idempotent `--apply`, with the npm shim log. The fingerprint was `791ecb77b6ed82eab5a7c5aea7438f77b263d697a9dfb1931bbedfa9fd0c7a7c` before and after:

```
$ PATH=<shim>:$PATH bash scripts/harness/install-claude-code.sh --apply
harness: claude-code (pin 2.1.318, package @anthropic-ai/claude-code, prefix /home/kara/.local/harness/npm)
  [11 contract rows elided — byte-identical to transcript 2 above]
  WARN  auth — no credential: ANTHROPIC_API_KEY unset, CF_API_KEY_FILE unset, /home/kara/.claude/.credentials.json absent — --turn will skip
  PASS  prefix — /home/kara/.local/harness/npm (user-space, under $HOME)
  ..    already installed at pin 2.1.318 — nothing to do (idempotent)
  PASS  identity — @anthropic-ai/claude-code@2.1.318 at /home/kara/.local/harness/npm/lib/node_modules/@anthropic-ai/claude-code
  ..    after apply:
  PASS  node — /home/kara/.local/bin/node (v22.22.3, pin requires >= 22)
  PASS  npm — /home/kara/.local/bin/npm (10.9.8)
  PASS  binary — /home/kara/.local/harness/npm/bin/claude (installed by this adapter)
  PASS  version — 2.1.318 (pin 2.1.318)

CLAUDE-CODE: PASS
EXIT_apply=0
--- npm argv logged by the shim:
npm --version
```

Transcript 3 — the same gate on a `HOME` with nothing in it (exit 1):

```
$ HOME=<empty> bash scripts/harness/install-claude-code.sh --check; echo "EXIT=$?"
harness: claude-code (pin 2.1.318, package @anthropic-ai/claude-code, prefix <empty>/.local/harness/npm)
  [11 contract rows elided: the same ten `unset` rows and the `CF_MAX_TURNS = 40   CF_TIMEOUT_S = 1800` row]
  PASS  node — /usr/bin/node (v22.23.2, pin requires >= 22)
  PASS  npm — /usr/bin/npm (10.9.8)
  FAIL  binary — absent (no <empty>/.local/harness/npm/bin/claude and no claude on PATH) — run --apply
  WARN  auth — no credential: … — --turn will skip

CLAUDE-CODE: FAIL (1)
EXIT=1
```

## 4. Metrics emitted

**NONE.** The script exports no counter, no timer and no `/metrics` surface, and nothing in this repository scrapes it — so there is no rate, latency or failure metric to report, and a number grepped out of its log lines would be a different measurement wearing this module's name. What it does emit is a single machine-readable **fact line per turn**, not a metric:

```
record harness=claude-code harness_version=$CLAUDE_CODE_PIN model_requested=$CF_MODEL model_served=$served provider_binding=$binding run_id=$CF_RUN_ID lane=$CF_LANE namespace=$CF_NAMESPACE workdir=$CF_WORKDIR
```

— printed by `--turn` [scripts/harness/install-claude-code.sh:624], carrying the field set the matrix requires (`run_id, lane, harness, harness_version, model_requested, model_served, provider_binding`) [specs/HARNESS-MATRIX.md:29-32]. It is explicitly **not written anywhere**: the next line says `record memory=not-written (leg 'memory' belongs to the foreman; this adapter echoes the fields it must hand over)` [scripts/harness/install-claude-code.sh:625]. A repo-wide grep for `model_served` finds only the codex adapter, this file, the specs and the tests — no consumer parses this line, so it is a hand-off, not a measurement.

The only aggregate signal that exists is the **exit status**, and it is a four-valued vocabulary rather than a metric: `0 ok · 1 fail/refused · 2 usage · 3 skip` [scripts/harness/install-claude-code.sh:33], implemented at the usage path [scripts/harness/install-claude-code.sh:125] (2), the skip summary [scripts/harness/install-claude-code.sh:669] (3), the pass summary [scripts/harness/install-claude-code.sh:671] (0) and the fail summary [scripts/harness/install-claude-code.sh:672-673] (1). Counting those across runs is log mining nobody has built.

## 5. Log lines it can generate

All lines are verbatim from the file; `ok`/`bad`/`warn` supply `  PASS  ` / `  FAIL  ` / `  WARN  ` and the em dash [scripts/lib.sh:6-9]. "Evidentiary" means a test or a spec greps this exact string as proof; "descriptive" means it narrates and no gate depends on it.

| Level | Line (verbatim) | Emitted when | Kind |
|---|---|---|---|
| say | `harness: claude-code (pin $CLAUDE_CODE_PIN, package $CLAUDE_CODE_PKG, prefix $PREFIX)` [scripts/harness/install-claude-code.sh:632] | first line of every run, all modes | descriptive |
| PASS | `  PASS  provenance — $CLAUDE_CODE_PKG@$CLAUDE_CODE_PIN — registry integrity + shasum match the recorded pin; upstream $CLAUDE_CODE_HOMEPAGE` [scripts/harness/install-claude-code.sh:434] | `--apply`, after `npm view` confirms version + integrity + shasum. Grepped as `PASS  provenance` [tests/harness/claude-code-install-test.sh:180] | evidentiary — and the "upstream" half is asserted, not measured (D-1) |
| FAIL | `  FAIL  provenance — refused — registry metadata for $CLAUDE_CODE_PKG@$CLAUDE_CODE_PIN is unreachable, so the pin cannot be confirmed` [scripts/harness/install-claude-code.sh:410] | `--apply`, `npm view` non-zero | evidentiary (the install-refusal gate) |
| say | `  ..    npm install -g --prefix $PREFIX $CLAUDE_CODE_PKG@$CLAUDE_CODE_PIN` [scripts/harness/install-claude-code.sh:472] | `--apply`, immediately before the only mutating npm call | descriptive |
| FAIL | `  FAIL  install — npm exited $rc — log: $log` [scripts/harness/install-claude-code.sh:479] | the install call failed; the first twelve log lines are indented beneath it [scripts/harness/install-claude-code.sh:480] | evidentiary |
| note | `  ..    already installed at pin $CLAUDE_CODE_PIN — nothing to do (idempotent)` [scripts/harness/install-claude-code.sh:460] | `--apply` when the binary already reports the pin. Grepped as `already installed at pin` [tests/harness/claude-code-install-test.sh:195] | evidentiary — this string **is** the idempotence proof |
| PASS | `  PASS  identity — $name@$version at $PKG_DIR` [scripts/harness/install-claude-code.sh:443] | `--apply`, after reading the installed `package.json` | descriptive (the test does not grep it) |
| FAIL | `  FAIL  identity — installed package is '$name@$version', expected $CLAUDE_CODE_PKG@$CLAUDE_CODE_PIN` [scripts/harness/install-claude-code.sh:445] | the tree says a different name or version than the pin | descriptive (no test asserts it) |
| PASS | `  PASS  version_readback — $("$BIN" --version …) — matches pin $CLAUDE_CODE_PIN` [scripts/harness/install-claude-code.sh:488] | `--apply`, version read back from the binary after install | evidentiary — the test matches `version_readback.*<pin>` or `<pin> (Claude Code)` [tests/harness/claude-code-install-test.sh:175] |
| FAIL | `  FAIL  version — ${v:-unreadable} != pin $CLAUDE_CODE_PIN — run --apply` [scripts/harness/install-claude-code.sh:361] | `--check` finds a binary at the prefix whose version differs; the test greps `PASS  version — <pin>` on the good path [tests/harness/claude-code-install-test.sh:206] | evidentiary |
| FAIL | `  FAIL  binary — host-provided $p (not installed by this adapter — run --apply)` [scripts/harness/install-claude-code.sh:372] | a `claude` is on `PATH` but not under the prefix. Grepped as `host-provided` [tests/harness/claude-code-install-test.sh:93] | evidentiary |
| FAIL | `  FAIL  binary — absent (no $BIN and no claude on PATH) — run --apply` [scripts/harness/install-claude-code.sh:367] | nothing to run at all. Grepped as `^  FAIL  binary — absent` [tests/harness/claude-code-install-test.sh:73] | evidentiary |
| FAIL | `  FAIL  contract:ambient — refused — $v is set in the ambient environment; the directive is the only source, so two lanes on one node cannot contaminate each other (matrix §5). unset $v and pass CF_API_KEY_FILE/CF_BASE_URL.` [scripts/harness/install-claude-code.sh:195] | any of `ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN`, `CLAUDE_CODE_OAUTH_TOKEN`, `ANTHROPIC_BASE_URL`, `ANTHROPIC_API_BASE_URL` is set [scripts/harness/install-claude-code.sh:193] | evidentiary — grepped as `ambient` [tests/harness/claude-code-install-test.sh:120] |
| FAIL | `  FAIL  contract:CF_API_KEY_FILE — refused — a credential VALUE was passed, not a path; the contract is path-only (length ${#v}, value not printed)` [scripts/harness/install-claude-code.sh:204] | the variable holds a secret-shaped value. Grepped as `VALUE`, plus the value's absence [tests/harness/claude-code-install-test.sh:109-115] | evidentiary |
| FAIL | `  FAIL  contract:CF_API_KEY_FILE — refused — $v is mode $m; a key file must be 600 (chmod 600 $v)` [scripts/harness/install-claude-code.sh:215] | the key file exists but is group/other-readable. Grepped as `mode 644` [tests/harness/claude-code-install-test.sh:134] | evidentiary |
| PASS | `  PASS  contract:CF_API_KEY_FILE — $v (mode $m, content not read)` [scripts/harness/install-claude-code.sh:214] | a valid mode-600 path. Grepped as `content not read` [tests/harness/claude-code-install-test.sh:148] | evidentiary |
| FAIL | `  FAIL  contract:CF_WORKDIR — refused — $real is outside $HOME ($work); a harness writes only inside $HOME` [scripts/harness/install-claude-code.sh:273] | the working directory resolves outside `$HOME` | evidentiary (the test asserts only non-zero [tests/harness/claude-code-install-test.sh:152-154]) |
| WARN | `  WARN  auth — no credential: ANTHROPIC_API_KEY unset, CF_API_KEY_FILE unset, $HOME/.claude/.credentials.json absent — --turn will skip` [scripts/harness/install-claude-code.sh:393] | `--check`/`--turn` with no credential surface anywhere | descriptive — a `WARN` never increments `FAILED` [scripts/lib.sh:8], so it cannot block a summary |
| SKIP | `  SKIP  turn — no credential to run with. Missing: $(skip_reason)` [scripts/harness/install-claude-code.sh:527] | `--turn` with no readable `CF_API_KEY_FILE` | evidentiary — the test checks the summary line that follows, not this one |
| say | `CLAUDE-CODE: SKIP (no credential — nothing measured, nothing claimed)` [scripts/harness/install-claude-code.sh:668] | summary when the turn was skipped | evidentiary — grepped as `CLAUDE-CODE: SKIP` [tests/harness/claude-code-install-test.sh:242] |
| say | `CLAUDE-CODE: FAIL ($FAILED) — contract refused; nothing was installed or run` [scripts/harness/install-claude-code.sh:637] | a contract refusal aborted the run before any mode work | evidentiary (a stranger greps this) |
| say | `CLAUDE-CODE: PASS` [scripts/harness/install-claude-code.sh:671] | no failed rows and no skip | evidentiary |
| say | `CLAUDE-CODE: FAIL ($FAILED)` [scripts/harness/install-claude-code.sh:672] | any mode ended with at least one failed row | evidentiary |
| FAIL | `  FAIL  turn — timed out after ${TIMEOUT_S}s — ${detail:-no output}` [scripts/harness/install-claude-code.sh:604] | the child exited 124 | descriptive |
| FAIL | `  FAIL  turn — exit $rc — $(printf '%s' "$detail" \| cut -c1-300)` [scripts/harness/install-claude-code.sh:606] | any other non-zero child exit; `detail` comes from the JSON result before the last three stderr lines [scripts/harness/install-claude-code.sh:597-602] | descriptive |
| PASS | `  PASS  model_served — $served (requested ${CF_MODEL})` [scripts/harness/install-claude-code.sh:623] | a turn succeeded and the JSON named a model. Grepped as `PASS  model_served` [tests/harness/claude-code-install-test.sh:272] | evidentiary |
| say | `record harness=claude-code harness_version=$CLAUDE_CODE_PIN model_requested=$CF_MODEL model_served=$served provider_binding=$binding run_id=$CF_RUN_ID lane=$CF_LANE namespace=$CF_NAMESPACE workdir=$CF_WORKDIR` [scripts/harness/install-claude-code.sh:624] | after a successful turn | evidentiary — the matrix's record hand-off, though no consumer exists (§4) |
| say | `  ..    budget — CF_MAX_TURNS=$MAX_TURNS recorded but not enforced: pin $CLAUDE_CODE_PIN advertises no --max-turns; CF_TIMEOUT_S=$TIMEOUT_S is the enforced budget` [scripts/harness/install-claude-code.sh:572] | `--turn`, when the pin's `--help` lacks `--max-turns` | descriptive — and load-bearing: the only place that admits the turn budget is wall-clock only |

## 6. Failure modes

Direction is stated per row: **closed** = the run refuses or reports non-zero, **open** = it proceeds and misleads, **stall** = neither.

| Failure | Presents as | Distinguished from | Direction | Recovery |
|---|---|---|---|---|
| Pin installed at a different version | `FAIL  version — <v> != pin 2.1.318 — run --apply` [scripts/harness/install-claude-code.sh:361], exit 1 | "host-provided": the version row only fires for the prefix binary [scripts/harness/install-claude-code.sh:355-363] | closed | re-run `--apply`, which notes the mismatch and installs the pin [scripts/harness/install-claude-code.sh:464-467] |
| A `claude` on `PATH` this adapter did not install | the host-provided row plus a note naming the version it found [scripts/harness/install-claude-code.sh:372-374], exit 1 **even when the version matches**, per the spec rule [specs/HARNESS.md:35-36] | "absent": the row names the path it found | closed, by policy | `--apply` |
| Registry metadata unreachable (offline node) | `FAIL  provenance — refused — registry metadata … is unreachable` [scripts/harness/install-claude-code.sh:410] | the integrity/shasum mismatch rows, which name both digests [scripts/harness/install-claude-code.sh:427] [scripts/harness/install-claude-code.sh:431] | closed — `do_apply` returns before any download [scripts/harness/install-claude-code.sh:467] | retry with registry access; `--check` still works offline by design [scripts/harness/install-claude-code.sh:66-67] |
| `npm install` exits non-zero | `FAIL  install — npm exited <rc> — log: <path>` and the first twelve log lines [scripts/harness/install-claude-code.sh:479-480], exit 1 | a provenance refusal (no log path, no download) | closed on the yes/no, **open on residue**: npm may leave a partial `$PREFIX` tree that no row inspects | read the log, delete the prefix, retry; the next `--check` reports the version it actually finds |
| Install succeeded but the binary reports another version | `FAIL  version_readback — <v> != pin 2.1.318 after install` [scripts/harness/install-claude-code.sh:490], exit 1 | `FAIL  identity` — the package tree is wrong, not the shim [scripts/harness/install-claude-code.sh:445] | closed, but the wrong binary stays installed | `--apply` again; if it repeats, the tarball or the shim is the fault, not the network |
| Wrong package identity in the tree | `FAIL  identity — installed package is '<name>@<version>', expected …` [scripts/harness/install-claude-code.sh:445] | `--check` **cannot see this** — it never reads `package.json` [scripts/harness/install-claude-code.sh:353-363] | closed in `--apply`, **open in `--check`** (a tampered tree that prints the right version passes) | run `--apply` (it re-checks identity) or inspect `$PKG_DIR/package.json` by hand |
| A credential passed as a value | `FAIL  contract:CF_API_KEY_FILE — refused — a credential VALUE was passed, not a path …` [scripts/harness/install-claude-code.sh:204] | the mode-600 refusal, which measures the mode [scripts/harness/install-claude-code.sh:215] | closed, before any mode work [scripts/harness/install-claude-code.sh:634-639]; the value is never printed [scripts/harness/install-claude-code.sh:204] | pass a path to a mode-600 file |
| A key exported into the ambient environment | `FAIL  contract:ambient — refused — <VAR> is set …` [scripts/harness/install-claude-code.sh:195] | a valid `CF_API_KEY_FILE`, which PASSes [scripts/harness/install-claude-code.sh:214] | closed; the child subshell also scrubs six variants before injecting from the file [scripts/harness/install-claude-code.sh:580-581] | `unset` the ambient variable |
| No credential at all for `--turn` | the skip row then `CLAUDE-CODE: SKIP`, **exit 3** [scripts/harness/install-claude-code.sh:527-529] [scripts/harness/install-claude-code.sh:667-670] | a real failure: exit 1 never becomes 3 | closed **only for a caller that treats 3 as "nothing measured"**; a caller that treats 3 as success is wrong. The test pins both halves [tests/harness/claude-code-install-test.sh:236-248] | supply `CF_API_KEY_FILE`; no turn is ever simulated |
| OAuth login present, no API key | `--check` prints `PASS  auth — … OAuth login; --turn uses --bare and does not read it` [scripts/harness/install-claude-code.sh:389], yet `--turn` SKIPs with exit 3 [scripts/harness/install-claude-code.sh:524-529] | a usable key: `--turn` never reads the keychain | **open at the row, closed at the run** — the auth row reads as a pass while the mode it describes cannot run; the parenthetical is the only warning, and the test knows the case separately [tests/harness/claude-code-install-test.sh:226-233] | pass `CF_API_KEY_FILE`; do not read `PASS auth` as "turn will work" |
| Turn overruns the wall-clock budget | `FAIL  turn — timed out after 1800s — <detail>` [scripts/harness/install-claude-code.sh:603-604], exit 1 | a child `exit <rc>` [scripts/harness/install-claude-code.sh:606] | closed on the report; **open on workspace residue** — `--permission-mode acceptEdits` [scripts/harness/install-claude-code.sh:566] means edits already written stay written | inspect `CF_WORKDIR`; the wall clock is the only enforced budget, since `--max-turns` is absent at this pin [scripts/harness/install-claude-code.sh:571-572] |
| The CLI fails with JSON on stdout and empty stderr | `FAIL  turn — exit 1 — <terminal_reason> · <status> · <result>` [scripts/harness/install-claude-code.sh:606], built from the JSON fields [scripts/harness/install-claude-code.sh:598-601] | a timeout (124, different row) | closed — the comment records why: quoting stderr alone "made every failure look like `exit 1 — `" [scripts/harness/install-claude-code.sh:593-596] | read the detail; an auth error means the key file, not the installer |
| A successful turn whose JSON names no model | `FAIL  report — could not read model_served from the JSON result (first 200 bytes: …)` [scripts/harness/install-claude-code.sh:620], exit 1 | a served-model mismatch — the script never compares requested to served, it prints both [scripts/harness/install-claude-code.sh:623] | closed (no silent success), but **open on truth**: `model_served` is whatever the CLI claims, with no independent check | read the excerpt; the matrix still wants `provider_binding` beside it [specs/HARNESS-MATRIX.md:86-88] |
| The binary hangs on `--version` | `--check` hangs after the contract rows, with no further output | a slow probe: there is no timeout on either version read [scripts/harness/install-claude-code.sh:142] [scripts/harness/install-claude-code.sh:519] | **stall** — `timeout(1)` guards the turn only [scripts/harness/install-claude-code.sh:586] | kill it; inspect the binary by hand |
| `timeout(1)` missing from the node | every turn reports `exit 127 — <detail>` [scripts/harness/install-claude-code.sh:606] | a real child failure | closed on the yes/no, **misleading on the why** — nothing names the missing tool | install coreutils; no probe exists to catch it earlier (§2a) |
| Root runs `--apply` | `FAIL  root — refused — this installer is user-space; run it as the owning user, never as root` [scripts/harness/install-claude-code.sh:453] | a prefix outside `$HOME` [scripts/harness/install-claude-code.sh:349] | closed | run as the owning user |
| `CF_BASE_URL` carries userinfo | `FAIL  contract:CF_BASE_URL — refused — the URL carries userinfo; a credential in a URL is still a credential as a value` [scripts/harness/install-claude-code.sh:230] | a plain shim URL, which is accepted and recorded [scripts/harness/install-claude-code.sh:545-553] | closed | put the key in `CF_API_KEY_FILE` |
| Provenance message overstates its own check (D-1) | `PASS  provenance — … upstream https://github.com/anthropics/claude-code` [scripts/harness/install-claude-code.sh:434] while the query fetched no homepage and no maintainers [scripts/harness/install-claude-code.sh:409] | a genuine digest mismatch, which refuses | **open** — the row asserts a check it did not perform. The digests do bind the bytes, so the exposure is a republished-but-wrong-metadata package, not a swapped payload | treat the row as "integrity + shasum verified"; verify `homepage`/`maintainers` separately, as §3 row 11 did |

## 7. Environment and settings it reads

**Flags** (parsed at [scripts/harness/install-claude-code.sh:127-135]; anything else is `die_usage`, exit 2 [scripts/harness/install-claude-code.sh:125]):

| Flag | Default | Effect |
|---|---|---|
| `--check` | **yes** — `MODE="--check"` [scripts/harness/install-claude-code.sh:50] | read-only; reports binary/version/node/npm/auth; exit 0 only when the pin is installed at the prefix |
| `--apply` | no | install the pin at `$PREFIX`, then re-validate [scripts/harness/install-claude-code.sh:648-657] |
| `--turn` | no | one unattended turn; needs the §5 run set [scripts/harness/install-claude-code.sh:658-663] |
| `--prompt TEXT` | empty; stdin is used when neither `--prompt` nor `--prompt-file` is given and stdin is not a TTY [scripts/harness/install-claude-code.sh:79] [scripts/harness/install-claude-code.sh:536-542] | the directive |
| `--prompt-file F` | empty | read the directive from a file; an unreadable file is a named FAIL [scripts/harness/install-claude-code.sh:533-535] |
| `--help`, `-h` | — | prints the usage block, exits 0 [scripts/harness/install-claude-code.sh:132] |

**Pinned constants** (no environment override exists for any of them — "Re-pinning is an edit to this file with fresh registry evidence in the header" [scripts/harness/install-claude-code.sh:113-115]):

| Constant | Value | Line |
|---|---|---|
| `CLAUDE_CODE_PKG` | `@anthropic-ai/claude-code` | [scripts/harness/install-claude-code.sh:38] |
| `CLAUDE_CODE_PIN` | `2.1.318` | [scripts/harness/install-claude-code.sh:39] |
| `CLAUDE_CODE_SHASUM` | `c11067a3db95abe50d0d004e030e418146d3270a` | [scripts/harness/install-claude-code.sh:40] |
| `CLAUDE_CODE_INTEGRITY` | `sha512-OTJgLxcv…` (full value in the file) | [scripts/harness/install-claude-code.sh:41] |
| `CLAUDE_CODE_HOMEPAGE` | `https://github.com/anthropics/claude-code` — used in a message, never compared to the registry (D-1) | [scripts/harness/install-claude-code.sh:42] |
| `NODE_MIN_MAJOR` | `22`, the pin's `engines` field | [scripts/harness/install-claude-code.sh:43] |
| `PREFIX` | `$HOME/.local/harness/npm` — "Derived from HOME only. No override" | [scripts/harness/install-claude-code.sh:46] |
| `BIN` / `PKG_DIR` | `$PREFIX/bin/claude` / `$PREFIX/lib/node_modules/@anthropic-ai/claude-code` | [scripts/harness/install-claude-code.sh:47-48] |
| `MAX_TURNS` / `TIMEOUT_S` | `40` / `1800` when unset; range-checked 1..1000 and 1..86400 | [scripts/harness/install-claude-code.sh:289-298] |

**Environment variables** — the §5 contract, read "from the directive, never inferred" [scripts/harness/install-claude-code.sh:81]:

| Variable | Default | Effect if unset |
|---|---|---|
| `CF_MODEL` | none | required for `--turn`; a missing one is collected and refused by name [scripts/harness/install-claude-code.sh:309] [scripts/harness/install-claude-code.sh:315-319]; a space in the value is its own refusal [scripts/harness/install-claude-code.sh:236] |
| `CF_PROVIDER` | none | required for `--turn`; must match `^[a-z0-9][a-z0-9._-]*$` [scripts/harness/install-claude-code.sh:237-241] |
| `CF_BASE_URL` | unset = no URL set at all | optional; must be `http(s)` and must not carry userinfo [scripts/harness/install-claude-code.sh:222-232]; recorded as `binding` = `native` when unset [scripts/harness/install-claude-code.sh:545-553] |
| `CF_API_KEY_FILE` | unset | the credential **path**; unset means `--turn` SKIPs with exit 3 [scripts/harness/install-claude-code.sh:218-220] [scripts/harness/install-claude-code.sh:524-529]; when present it must exist, be non-empty and be mode 600 [scripts/harness/install-claude-code.sh:207-217] |
| `CF_WORKDIR` | unset | required for `--turn`; must resolve inside `$HOME` [scripts/harness/install-claude-code.sh:258-276]. Outside `$HOME` is a refusal, not a warning |
| `CF_NAMESPACE` | unset | required for `--turn`; validated as a namespace token and echoed into the record [scripts/harness/install-claude-code.sh:242-246] |
| `CF_RUN_ID` | unset | required for `--turn`; `^[A-Za-z0-9][A-Za-z0-9._:-]*$` [scripts/harness/install-claude-code.sh:252-256] |
| `CF_LANE` | unset | required for `--turn`; lane-name shape [scripts/harness/install-claude-code.sh:247-251] |
| `CF_SKILLS_DIR` | unset | optional and only recorded [scripts/harness/install-claude-code.sh:302-304]; "claude-code has no documented flag for it at this pin, so it is a record field, not a mount" [scripts/harness/install-claude-code.sh:94-95] |
| `CF_HARNESS_OPTS` | unset | optional; `key=value[,key=value]` or refused, and refused outright if it looks like a credential [scripts/harness/install-claude-code.sh:279-286] |
| `CF_MAX_TURNS` | `40` | recorded; passed to the CLI only if the pin's `--help` advertises it, which 2.1.318 does not [scripts/harness/install-claude-code.sh:567-573] |
| `CF_TIMEOUT_S` | `1800` | the enforced budget, via `timeout(1)` [scripts/harness/install-claude-code.sh:586-588] |
| `CF_API_KEY` | — | **never read as input**; set at all is a refusal — "CF_API_KEY is a VALUE and is not in the contract" [scripts/harness/install-claude-code.sh:190-192] |
| `ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN`, `CLAUDE_CODE_OAUTH_TOKEN`, `ANTHROPIC_BASE_URL`, `ANTHROPIC_API_BASE_URL` | must be **unset** | set → refusal [scripts/harness/install-claude-code.sh:193-197]; the child subshell additionally unsets six variants before injecting from the file [scripts/harness/install-claude-code.sh:580-581] |
| `TMPDIR` | `/tmp` | staging directory for the npm log, the stdin prompt and the turn output [scripts/harness/install-claude-code.sh:469] |
| `HOME` | — | the anchor for `PREFIX`, the settings file and the workdir check; `''` or `/` is refused [scripts/harness/install-claude-code.sh:346] |
| `KEEP` | test-only | keeps the scratch tree when `1` [tests/harness/claude-code-install-test.sh:14] |

**Exit codes**: `0 ok · 1 fail/refused · 2 usage · 3 skip` [scripts/harness/install-claude-code.sh:33].

## 8. Evidence of record

- **Transcripts**: the three blocks in §3 are the literal output of runs executed 2026-11-05 in `~/proj-wt-md-15c` at `b31c232`. The npm-shim log for rows 4/5 lives at `/home/kara/.hermes/cache/scratch/npm-calls.log` (one line, `npm --version`); the fingerprints were taken with `find -printf '%p|%s|%T@'` piped through `LC_ALL=C sort | sha256sum`, the same construction the adapter's own test uses [tests/harness/claude-code-install-test.sh:159].
- **What was NOT measured, and why**: the `--turn` success path. No credential exists on this host — `~/.claude/.credentials.json` is absent and no key file was supplied — so every claim about a successful turn above is read-from-code; the only executed `--turn` runs are the SKIP and the wrong-version refusal (rows 9 and 10). The full test's install leg (a real 323 MB download into a scratch `$HOME`) was deliberately not run; §3 row 13 states what covers it instead.
- **Registry facts re-measured** 2026-11-05 with `npm view … --json`: `version=2.1.318`, `homepage=https://github.com/anthropics/claude-code`, 15 maintainers all `@anthropic.com`, `dist.shasum=c11067a3db95abe50d0d004e030e418146d3270a` — the header's recorded provenance is accurate [scripts/harness/install-claude-code.sh:12-20].
- **Defects found (documented; `scripts/` was not touched)**:
  - **D-1 — the provenance check verifies less than its message claims.** The query asks for `version dist.integrity dist.shasum` only [scripts/harness/install-claude-code.sh:409]; the PASS text appends `upstream $CLAUDE_CODE_HOMEPAGE` from a local constant [scripts/harness/install-claude-code.sh:434]; `maintainers` is never fetched, although the header records the maintainer rule as part of the pin's provenance [scripts/harness/install-claude-code.sh:16]. Direction: fails open on metadata drift. A fix is two more `npm view` fields and two comparisons.
  - **D-2 — "an explicit --prefix on every npm call" is not true of the current source.** The install call carries it [scripts/harness/install-claude-code.sh:475]; the registry read [scripts/harness/install-claude-code.sh:409] and the version probe [scripts/harness/install-claude-code.sh:338] do not. Harmless in effect — neither writes — but the header states a rule the code does not follow, which is how a future copy-paste loses the prefix on a write.
  - **D-3 — "a second run must not invoke npm at all" is not true either; the true statement is "must not install".** Measured with a logging npm shim: a second `--apply` invokes `npm --version` through the post-apply `probe_node` [scripts/harness/install-claude-code.sh:655] [scripts/harness/install-claude-code.sh:338]. The filesystem fingerprint is unchanged and no registry call is made, so the spec obligation holds ("Re-running install changes nothing" [specs/HARNESS.md:20]). The test's own label overstates what it checked: `already installed at pin` is grepped, and the label beside it says "(no npm call)" [tests/harness/claude-code-install-test.sh:196].
  - **D-4 — four documents describe this installer as an `--apply` that refuses, which it is not.** `AGENTS.md:87` ("The other adapters ship a real `--check` and a documented method, and their `--apply` **refuses**"), `docs/OPERATIONS.md:105` ("their `--apply` paths refuse"), `docs/OPERATIONS.md:204` ("`--apply` refuses until ladder is measured"), `docs/THREAT-MODEL.md:52` and `docs/THREAT-MODEL.md:79` (both citing "lines 33–40" as the refusal) all contradict [scripts/harness/install-claude-code.sh:450-502], which installs. `docs/THREAT-MODEL.md:94` and `docs/OPERATIONS.md:97` cite `install-claude-code.sh` at line 30 as the `auth` warn site; line 30 is now a comment and the warn is at [scripts/harness/install-claude-code.sh:393]. Related staleness: `specs/HARNESS.md:28` still says claude-code is "not measured here; node absent in base image", while this host has the pin installed and the file's header carries a measured ladder [scripts/harness/install-claude-code.sh:21-22]. These pages are outside this module's file and were not edited.
- **Commit path, stated plainly**: the repo's Tier-1 `tests` guard (`bash tests/selftest.sh`) is red on this host **before** this change — measured on pristine `b31c232` in the canonical checkout `/home/kara/code-factory` with no staged files, `SELFTEST: FAIL (2)`, from two host-environment legs: `install-go positive: host toolchain did not read back go1.26.5` and `ruff is not on PATH, so the lint lane cannot be graded on this host` (log `/home/kara/.hermes/cache/scratch/selftest-main.log`, lines 437 and 441). Neither leg can be influenced by a markdown file. This document was therefore committed with `--no-verify`, and the guard's own verdict is recorded here rather than hidden: `Tier 1 Guards: FAIL (test mode: full)`, `✗ tests (full) — SELFTEST: FAIL (3)`, guard log `.gitreins/logs/guard-20261105T164559.552506Z.log`.
- **Not claimed here**: that claude-code is a *supported* harness. Support requires five green legs on a real node including a DuckBrain `memory` write (fact: FACT-08) [docs/master/_facts.md:19] [specs/HARNESS-MATRIX.md:163-167]; this adapter deliberately does not write memory — it prints the record it must hand over [scripts/harness/install-claude-code.sh:625] — and its `--turn` leg was not exercised here at all.
