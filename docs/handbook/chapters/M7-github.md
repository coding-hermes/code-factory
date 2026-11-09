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

Authenticates the fleet to the forge without a long-lived token in argv. M7 is **forge credential
management**: per-owner/instance app registration/installation, token minting scoped to the
repositories and permissions a job requires, delivery to Bunker nodes, and the full
issue/expire/renew/revoke/decommission lifecycle. It is not the installation of a Git server on a
Bunker, and it does not decide which repos the fleet may touch — that is the app installation
scope. (It does **not** mint the per-dispatch scoped token M11 consumes, nor the node tokens M12
admits — see §12.)

**Forge coverage is an extensible contract, not a GitHub-only assumption.** GitHub is the
confirmed MVP forge; the module defines a forge/auth **contract** (register / install / pair /
authorize / issue / deliver / refresh / revoke / offboard) with provider adapters behind it, and
GitLab is the required first equivalent. Ambiguous dictated forge names are **resolved before any
product is named** — an unrecognized or phonetically ambiguous host name is a clarification
question, not a silent substitution.

**What breaks if this module is absent.** The fleet cannot authenticate without a human PAT — or
a token leaks into `ps` output (FACT-05: credentials travel as file paths, never argv values).

**What breaks if it lies.** A mint that prints the token value is a leak; a refresh that serves a
stale token while reporting fresh silently pushes with an expired credential.

**Required behavior (normative).** Approved target behavior governs; the script audit in §3–§13
is implementation coverage, not the requirement.

- **Per-owner/instance app identity.** Each owner/deployment registers and installs its **own**
  app — account/organization prerequisites, registration versus installation, authorization, key
  generation, repository selection, setup pairing and success checks are specified steps. The
  customer-owned app model is not silently replaced by a shared fleet identity.
- **Mappings, not conventions.** Versioned mapping tables bind forge host/owner, app and
  installation ids, repository ids, project/lane/job role, Bunker server/node, credential
  reference, required permissions, issuer/renewal owner and effective state. Unmapped or
  excessive scope is denied **before issuance**.
- **Token narrowing is a mint-time duty.** Token requests are narrowed to the required
  repositories and permissions in the request body. **Checking installation coverage alone does
  not narrow the token** — a mint without a repository/permission restriction inherits the
  installation's full repo set and granted permissions, which is a defect, not a default.
- **Signing authority stays on the control side.** The App signing key never leaves the
  control-host credential issuer; nodes receive only the scoped runtime credentials and Git/client
  configuration they need, through a defined delivery/activation contract.
- **Complete lifecycle with triggers.** Deployment/onboarding/rebuild/resume, pre-dispatch
  validity checks, renewal-before-expiry, **permission-change detection** (app or installation
  permission/repo changes reconcile or revoke existing caches), cache validity, and
  decommission/offboarding are each specified with owner, trigger, success/failure/unknown
  results and recovery. **Token-file age alone is not validity**: issuer expiry metadata,
  remaining-lifetime margin, revocation and scope identity are checked before reuse; expiry proof
  is different from explicit revocation, and a new mint or file replacement is not revocation
  evidence.
- **Credential domains are separate.** M7's app-token helper, M11's per-dispatch scope helper and
  the node credential consumers are distinct producers with distinct policies; **none of them is
  proxy-token issuance** (M12's inference node tokens are a separate domain). Naming a helper is
  naming one path, not collapsing the domains.
- **Complete settings, mappings and metrics.** Every credential operation carries its settings
  (paths, modes, margins, endpoints), its mapping row and its metrics (issue/check/delivery/
  renew/revoke outcomes and durations, expiry headroom, refused scopes, stale mappings, partial
  activations) — grep absence in the current scripts is coverage evidence, not the metric design.

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

## 15. Normative forge credential contract (P3-12, P3-16)

M7 defines one provider-neutral credential interface with GitHub and GitLab adapters. A mapping row is `schema: cf.forge-mapping.v1` with `forge_host`, `provider`, `owner`, `app_id`, `installation_id` or GitLab application/project binding, `repository_ids`, `role`, `permissions`, `issuer_ref`, `consumer_ref`, `bunker_ref`, `expires_at`, `scope_digest` and `generation`. The signing key remains on the control host. GitHub App installation tokens and GitLab project/group tokens are separate adapter credentials; provider-specific API details are not silently generalized.

The lifecycle is `REGISTERED → INSTALLED → PAIRED → ISSUABLE → DELIVERED → ACTIVE → RENEWING → REVOKED → OFFBOARDED`. Issuance refuses an unmapped repository, excessive permission, expired installation, stale generation or missing customer authorization before any token request. Delivery writes an owner-only file through the Bunker control channel, reads back mode, scope digest and expiry without printing the value, and removes temporary control-host copies. Renewal overlaps only when both credentials are valid; compromise or scope reduction revokes the old credential explicitly and records provider confirmation. Restore reissues or revokes according to the recorded generation and never resurrects a revoked credential.

The supported operation contract covers register, install/pair, check, issue, deliver, refresh, revoke and offboard. Each result names provider, mapping generation, repository scope, permission scope, expiry headroom and refusal reason. Git clone/fetch, branch push and protected-main/merge permissions are distinct; M3 requests only the operation it owns. M7 does not mint M11 dispatch credentials or M12 proxy node tokens.

The authorization matrix is explicit at the resource boundary:

| Actor | Resource / operation | Required scope and result |
|---|---|---|
| controller issuer | register/pair an app or installation | customer authorization for the named forge/owner; creates mapping generation, never a repository token |
| project foreman | request clone/fetch, branch push or protected-main/merge | only the project and operation named by M3; a broader installation is narrowed in the request body |
| Bunker node | clone/fetch and use a delivered runtime credential | its `bunker_ref`, project, repository and expiry must match the mapping; it cannot mint, rotate, widen scope or merge protected main |
| operator / owner | approve, rotate, revoke or offboard | explicit owner authorization; readback is required for every state change |
| provider adapter | exchange, refresh or revoke | control-host issuer credential only; provider response must include provider id, scope, expiry and generation |

Enrollment is `schema: cf.forge-trust.v1`: `forge_host`, `provider`, `owner`,
`app_id`, `installation_id` or GitLab binding, `controller_identity`,
`bunker_ref`, `authorization_ref`, `public_key_fingerprint`, `mapping_generation`
and `expires_at`. The controller proves the provider/owner binding and key
fingerprint, performs a signed provider read, and records the installation scope
before issuance. A secret reference is `schema: cf.secret-ref.v1` with `ref`,
`owner`, `purpose`, `mode`, `expires_at`, `generation` and `revocation_ref`; the
secret store resolves it only for the issuer, and delivery returns mode, digest,
scope and expiry without the value.

Provider adapters return one normalized result, `schema: cf.forge-credential-result.v1`,
with `request_id`, `provider`, `mapping_generation`, `credential_ref`,
`repository_scope`, `permission_scope`, `expires_at`, `scope_digest`,
`provider_credential_id`, `state` and `error`. GitHub requests use the App
installation endpoint with an explicit `repositories`/repository-id restriction
and `permissions` body; GitLab requests use a project/group or deploy-token
binding with explicit project and role scopes. The adapter must reject an
unconfirmed provider mode rather than inventing one. GitHub App signing authority
and any GitLab application secret remain on the control host; the node receives
only the resulting scoped credential.

Delivery is two-phase: write an owner-only file through the Bunker control channel,
read back its mode, scope digest and provider expiry, then activate the mapping.
Read/fetch, worker-branch push and protected-main/merge are separate permissions;
M3 requests the minimum one. Renewal requires issuer expiry metadata and a declared
headroom margin, not file age. Scope reduction, compromise, provider revocation,
expiry, mapping-generation change and offboarding explicitly revoke the old
credential, record provider confirmation, remove the node copy and invalidate the
cache. Restore replays the mapping but never reactivates a recorded revocation.
All operations emit outcome and duration metrics with bounded labels for provider,
project, bunker, operation and refusal reason; M7 collects/readbacks them. A request
for a second project, wider permission or different Bunker is refused before any
provider call.

Acceptance cases cover trust enrollment, GitHub least-privilege issuance, GitLab
project scope, allowed and denied operations across two projects, renewal before
expiry, scope reduction, leaked-token revocation, offboarding and restore without
credential resurrection.

## RED field count: 4 (Metrics §8 — absence-proved; §1 mint UNVERIFIED; M7-C1 contract state UNVERIFIED — consumer is an external API; §9 inventory 2 of 103 helper call sites — the descriptive rows not tabulated one-per-site)

## FLIGHT DATA FILE - M7 GITHUB

```checklist
TITLE: M7 GITHUB
WHO: CONTROL HOST
MINT - mint the App installation token
√ FILE - token lands in auth/github.token, mode 0600, never in argv
SCOPE - read fleet-repo-scope.json before a job requests a token
√ SCOPED - the repo is listed; an unlisted repo is refused before minting
REFRESH - re-mint after expiry and confirm the old token is rejected
√ ROTATES - new token works, old token 401s
```
