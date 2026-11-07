# M7 — GITHUB

## 1. Identity

| Field | Value |
|---|---|
| Module name | GITHUB |
| Path | `/home/kara/code-factory/scripts/` — `github-app-setup.sh`, `github-app-token.py`, `github-app-refresh.sh` |
| Revision | `fbc19cbc807de729e25c358fa7e94207b912f010` (code-factory HEAD; no M7-cited file (`github-app-*.sh`, `github-app-token.py`) changed in `08a2c8a..fbc19cb`) |
| Language / runtime | bash 5.3.9 + Python 3.14.9 (measured) |
| Owner lane | code-factory (control host) |
| Status | **UNVERIFIED** — CLI surface measured (`github-app-token.py` exits 2 with no command); the settings/control regions read (`:107-117`, `:300-372`, `:579`; `github-app-refresh.sh:37-53,104-174`); mint not run (no App creds on this host) |

## 2. Purpose, authority and position

Authenticates the fleet to the forge without a long-lived token in argv. It decides how a GitHub
**App installation token** is minted, cached and refreshed. It may not decide which repos the fleet
may touch — that is the App installation scope. (It does **not** mint the per-dispatch scoped token
M11 consumes, nor the node tokens M12 admits — see §12.)

**What breaks if this module is absent.** The fleet cannot authenticate without a human PAT — or
a token leaks into `ps` output (FACT-05: credentials travel as file paths, never argv values).

**What breaks if it lies.** A mint that prints the token value is a leak; a refresh that serves a
stale token while reporting fresh silently pushes with an expired credential.

## 3. Submodule inventory

| Submodule | Unit | Classification | Evidence (invoking line) |
|---|---|---|---|
| S1 app credentials | `github-app-setup.sh`, `github-app-token.py`, `github-app-refresh.sh` | **operator-invoked** | `grep -rn 'github-app-token\|github-app-refresh\|github-app-setup' scripts/ config/` finds no timer/cron/scheduler invocation — only `github-app-setup.sh:201/:284` printing manual refresh instructions (B43); an operator runs the mint/refresh on demand |

## 4. Dependencies

**4a. Runtime dependencies**

| Dependency | Version constraint | Where | How absence is detected |
|---|---|---|---|
| python3 | 3.x | control host | `command -v python3` empty → `bad "python3"` (`github-app-refresh.sh:60`) |
| GitHub App private key | an RSA `.pem`, mode **exactly 0600** (`github-app-token.py:344-352`) | control host | `GITHUB_APP_PRIVATE_KEY_FILE` unset → named problem (`:330-333`); mode != 0600 → refused (`:344-348`) |

**4b. Library contracts**

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| GitHub App API (JWT mint + installation token) | github.com | `POST /app/installations/{id}/access_tokens` (`github-app-token.py:371`) | an API change breaks the mint |

**4c. Service contracts** — see §6.

## 5. Settings register

| Setting | Default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| subcommand | none | `check` / `token` / `jwt` / `manifest` | which credential operation runs | a bare invocation performs **no** mint — prints usage, exits 2 |
| `GITHUB_APP_ID` | unset | numeric (`:295`, `:304-305`) | the App identity | unset or non-numeric → named problem; no mint |
| `GITHUB_APP_INSTALLATION_ID` | unset | numeric (`:307`, `:316-320`) | the installation scope | unset or non-numeric → named problem |
| `GITHUB_APP_PRIVATE_KEY_FILE` | unset | a path, mode **exactly 0600** (`:326-358`) | the RSA signing key | absent/0600-only/parse-failure all refused by name |
| `--env-file` | `GITHUB_APP_ENV_FILE` or `DEFAULT_ENV_FILE` = `~/.config/code-factory/github-app.env` (`:45`, argparse `:110`) | a path | the App's identity source | absent env file → mint fails |
| `--api-base` | `GITHUB_API_BASE` or `DEFAULT_API` = `https://api.github.com` (`:47`, argparse `:115`) | a URL | API endpoint (tests point it local) | a wrong base breaks the mint |
| token destination | `args.out` or `GITHUB_APP_TOKEN_FILE` or `DEFAULT_TOKEN_FILE` (`:579`) | a path | where the token is written | a wrong path writes the credential to the wrong place |
| `--if-older` | 0 (`:719-723`) | seconds | no-op while destination younger than N | 0 = always re-mint |
| refresh controls | `--env-file --token-file --node --server --min-age --git-credentials --api-base --local --dry-run --quiet` (`github-app-refresh.sh:37-53`) | per-flag | local vs node install, write/no-write | **`--dry-run` prevents mutation** (exits before mint/write at `:106` and `:154`); **`--quiet` suppresses selected output only** (`say_q` at `:55`) and does **not** prevent minting — the two flags are distinct controls (B16); `--node` installs into `$NODE:$HOME/.node/auth/github.token` (`:145-174`) |

**Lifecycle controls, individually registered (B14).**

| Setting | Default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| `MIN_AGE` | **2400 s** (`:28`) | non-negative int (spelling validated `:53`: `''|*[!0-9]*` → exit 2) | skip the mint while the destination token is younger than this | a too-large value serves a near-expiry token while reporting fresh |
| `ENV_FILE` | `$GITHUB_APP_ENV_FILE` or `~/.config/code-factory/github-app.env` (`:24`) | a path | the App identity source | absent file → `bad env_file`, exit 1 before any mint (`:57`) |
| `TOKEN_FILE` | `~/.config/code-factory/github.token` (`:58`, after flag/env resolution) | a path | local-mode token destination | a wrong path mints the credential to the wrong place |
| `GIT_CREDENTIALS` | `~/.git-credentials` (`:29`) | a path | the credential-store rewrite target | the store is rewritten **only when it already exists** (`:131`) — the script never creates a second store |
| `--local` / `--node` | local (`:30`, `:103`) | mode | where the token lands | local writes `TOKEN_FILE`; node mints on this host, installs into `$NODE:$HOME/.node/auth/github.token`, then deletes the local copy (`:145-174`) |
| `--min-age` | 2400 (`:28`) | seconds | refresh no-op window | `--min-age` vs token lifetime (3600 s) determines when a refresh is a no-op |
| mode-600 check | — | exactly `600` | token-file privacy before the store is rewritten | `bad "mode"` exits 1 **before** the credential store rewrite (`:127-130`, CF-320) |
| `JWT_BACKDATE` / `JWT_LIFETIME` | 60 s / 540 s (`:50-51`) | seconds | JWT exp/iat window | GitHub rejects exp >10 min out |
| `TIMEOUT` | 20 s (`:52`) | seconds | HTTP timeout | too short fails the mint |

## 6. Contracts in and out

M7 has **no entry in the canonical register** (CT-01..CT-18, OUTLINE Part IV): the GitHub App
installation-token mint is a node→github.com credential exchange, not one of the 18 cross-system
contracts, and no peer chapter describes it from the opposite end. It is listed below as a local
edge; the mint was never run on this host (no App creds), so the state is UNVERIFIED.

| ID | Peer | Direction | Producer `file:function` | Consumer `file:function` | State |
|---|---|---|---|---|---|
| M7-C1 | GitHub | out | `github-app-token.py:362` `mint()` (JWT → installation token; POST at `:371`) | **external service** — `github.com`'s `POST /app/installations/{id}/access_tokens` API operation, not an in-repo `file:function` | **UNVERIFIED** — the mint was never run (no App creds on this host); the consumer is an external API, so the state is UNVERIFIED, not "works" (B42) |

## 7. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| shell parse | `for f in scripts/github-app-*.sh; do bash -n "$f"; done` | exit 0 | 2026-11-06 | PASS (in 20/20 sweep) |
| python compile | `python3 -m py_compile scripts/github-app-token.py` | exit 0 | 2026-11-06 | PASS |
| CLI surface | `python3 -B scripts/github-app-token.py` | usage, exit 2 | 2026-11-06 | **PASS** (exit 2, usage) |
| token mint | `python3 scripts/github-app-token.py token` with `GITHUB_APP_ID` + `GITHUB_APP_INSTALLATION_ID` + `GITHUB_APP_PRIVATE_KEY_FILE` set (or `--env-file`); the mint-and-write path is `github-app-token.py:598-606` | fresh token, value not printed | not run | **UNVERIFIED** (no App creds on this host) |

## 8. Metrics

**RED — none (absence-proved).** No counters or gauges.
`grep -nE 'prometheus|Counter|Gauge|Histogram|/metrics' scripts/github-app-token.py
scripts/github-app-refresh.sh scripts/github-app-setup.sh` → 0 matches. Token refresh count and mint
latency are answerable only by reading the refresh log.

## 9. Log lines (verbatim)

**Scope (B09, measured).** `grep -rcE '\b(ok|bad|warn|note|say)\s+"' scripts/github-app-*.sh` sums to **103** helper call sites across the three scripts. The 2 rows below are the evidentiary no-op/refusal rows; the generic per-row helper surface is not inventoried one-per-site — the uncovered count is a named RED on this field.

| Level | Line | Emitted when | Kind |
|---|---|---|---|
| — | `  PASS  %s — %s` / `  FAIL  %s — %s` (`lib.sh:6-7`) | setup/refresh rows | descriptive (see M0 F0-4) |
| — | `refresh — (no-op) %s was not rewritten … ~%ss left` (`github-app-refresh.sh:120`) | no-op refresh | evidentiary |

## 10. Failure modes, indications and recovery

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Token in argv | `ps` shows the value | a file-path credential | by design prevented — token never printed; refresh uses the cached file |
| No command selected | usage, exit 2 | a real mint | pass `check`/`token` with the required file-path args |
| Mode not 600 after mint | `bad "mode" … expected 600` (`:127-128`), exit 1 before rewriting the store | a secure token file | `chmod 600` the token file, re-run |
| Key file not 0600 | `… is mode %04o; a private key must be 0600` (`github-app-token.py:344-348`) | a valid key | `chmod 600` the `.pem` |
| Node credential law incomplete | rotation-on-compromise, owner-only minting, per-project scoping unstated | a written law | **OPEN** — CF-347 |

## 11. Limits and margins

- `check` mints in memory only; `token` writes a private credential file — distinct operations.
- The refresh script verifies the minter's self-report against two `file_state` reads and names a
  disagreement (`:112-116`); a FAIL row stops the run **before** the credential store is rewritten
  (CF-320, `:123-131`).

## 12. Cross-references

- **Credential domains are separate (B16).** M7's `github-app-token.py`
  mints **installation tokens**. The per-dispatch scoped token M11 injects is minted by a
  *different* tool: `dispatcher.py:68` loads `fleet-gh-scope.py`, whose `mint_scoped`
  (`fleet-gh-scope.py:81-94`) invokes `~/.hermes/scripts/gh-app-token.py` (`:52`) — not M7's file.
- **M7 does not produce the node tokens M12 admits.** `cf-inference-proxy.py:48` loads
  `TOKENS_PATH` (`~/.hermes/secrets/cf-node-tokens.json`) and compares incoming bearer tokens
  against it (`:115-123`); the producer of that mapping is not established in any code read
  (see M12 §6).
- M1 PROVISIONING writes the node's `auth/github.token`.

## 13. Evidence of record

- Code read: `github-app-token.py:45-52, 107-117, 300-372, 579, 719-723`; `github-app-refresh.sh:20-60, 104-175`;
  `fleet-gh-scope.py:14-52, 81-94`; `dispatcher.py:62-98`.
- `docs/UNIT-MAP.yaml:208-220` (M7 S1).
- Board rows: CF-347, CF-378 (P3, complete).
- **Findings:**
  - **F7-1** (carried) — `python3 scripts/github-app-token.py` prints usage and exits 2; it
    performs no mint. `check` and `token` are separate operations; no App credentials exist here.
  - **F7-2** — the settings register was one row; the credential lifecycle controls are now registered.
  - **F7-3** (new) — M7 does **not** mint the per-dispatch scoped token, and M7/M1 do **not**
    produce the node tokens: the scoped token comes from `fleet-gh-scope.py` →
    `~/.hermes/scripts/gh-app-token.py` (a separate minter), and the node-token producer for M12 is
    unknown.

## RED field count: 4 (Metrics §8 — absence-proved; §1 mint UNVERIFIED; M7-C1 contract state UNVERIFIED — consumer is an external API; §9 inventory 2 of 103 helper call sites — the descriptive rows not tabulated one-per-site)
