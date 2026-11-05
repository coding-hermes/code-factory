# 15. scripts/harness/install-claude-code.sh

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/harness/install-claude-code.sh` |
| Repository | `code-factory` |
| Revision | `3c4c639` |
| Status | **RED — no verification recorded** |

## 1. Purpose and why it matters

- The script is a “pinned, user-space installer and adapter probe for Claude Code (CF-225)”: `--check` is read-only, `--apply` installs the pin under `$HOME/.local/harness/npm`, and `--turn` runs one unattended turn in `CF_WORKDIR` (`install-claude-code.sh --check ... / --apply ... / --turn ...`).
- What breaks if this module is absent: there is no installer/probe for the Claude Code pin; in `--turn` the script explicitly refuses when the pin is not installed: `bad "turn" "refused — the pin is not installed at $BIN; run --apply first"`.
- What breaks if it lies: `UNKNOWN` — every self-reporting component has this failure mode. The script does provide its own read-back rule: “the version is read back from the installed binary after install, and a mismatch names both numbers” (`install-claude-code.sh` header).

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `bash` | not stated; shebang is `#!/usr/bin/env bash` | script interpreter on `PATH` | shell cannot run the script |
| `node` | `>= 22` (`NODE_MIN_MAJOR=22`) | `have node` on `PATH` | `probe_node`: `bad "node" "absent — $CLAUDE_CODE_PKG needs node >= $NODE_MIN_MAJOR (its engines field)"` |
| `npm` | not stated; only presence is checked | `have npm` on `PATH` | `probe_node`: `bad "npm" "absent — the pin is an npm package"` |
| `timeout` | not stated | on `PATH` during `--turn` | not explicitly detected before use |
| `stat` | not stated | on `PATH` | `mode_of()` uses `stat -c '%a' ... 2>/dev/null || echo '?'`; bad mode then fails key-file check |
| `grep`, `sed`, `du`, `head`, `tail`, `tr`, `cut`, `mktemp`, `id`, `date`, `cat` | not stated | on `PATH` during relevant modes | not explicitly detected before use |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `"$HERE/../lib.sh"` | `scripts/lib.sh` in this repository | Functions/variables used by this script: `say`, `ok`, `bad`, `note`, `warn`, `have`, `FAILED`, `SKIPPED` | The script’s checks, exit-code reporting, and summary lines fail if names or exit/error semantics change |

### 2c. Service contracts (both sides must be named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| `registry.npmjs.org` | outbound, this script is the client | `npm view ... --json` against the npm registry | Package metadata for `@anthropic-ai/claude-code@2.1.318`: `version`, `dist.integrity`, `dist.shasum` | `scripts/harness/install-claude-code.sh:provenance_check()` |
| `@anthropic-ai/claude-code` CLI (`$BIN`) | outbound, this script is the caller | subprocess `timeout "$TIMEOUT_S" "$BIN" ...`, stdin/stdout | CLI flags `--print --output-format json --bare --setting-sources local --permission-mode acceptEdits --model ...`; JSON result parsed for `terminal_reason`, `api_error_status`, `result`, `modelUsage`, `model` | `scripts/harness/install-claude-code.sh:do_turn()` |

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| Source-defined `--check` | `scripts/harness/install-claude-code.sh --
