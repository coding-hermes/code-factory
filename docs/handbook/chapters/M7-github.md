# M7 — GITHUB

## 1. Identity

| Field | Value |
|---|---|
| Module name | GITHUB |
| Path | `~/code-factory/scripts/` — `github-app-setup.sh`, `github-app-token.py`, `github-app-refresh.sh` |
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

### III.M7.S1 — App credential check

`--check` is fail-closed on repository evidence. The minter resolves the target from `--repo` or the `GITHUB_APP_REPO` key in the pointer file, performs both the installation-coverage request and `GET /repos/<owner>/<name>` with the fresh token, and includes the repository and HTTP status in the PASS row. If neither source names a repository, it emits `FAIL repo_read — no repository named, so the read was not measured ...` and exits non-zero; it never prints a PASS sentence claiming it reads the target repo. This behavior is covered by the hermetic local-stub fixture `tests/test_github_app_check.py`, with unreadable 403, readable 200, and no-repository arms recorded in `docs/audits/code-factory-CF-319-fix-2026-11-13.md`.

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

The canonical register is Part IV, CT-01 through CT-30 plus CT-06R. CT-21 covers
credential delivery; M7-C1 below is the external provider exchange, not another CT
identifier. Its mint remains UNVERIFIED at the measured revision.

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

Mapping state is `REGISTERED → INSTALLED → PAIRED → ISSUABLE → ACTIVE`, with `ACTIVE → RENEWING → ACTIVE`, and any live state to `SUSPENDED` or `OFFBOARDED`. Credentials have their own staged/active/revoked/expired states (§16). Issuance refuses an unmapped repository, excessive permission, expired installation, stale generation or missing customer authorization before any token request. Delivery writes an owner-only file through the Bunker control channel, reads back mode, scope digest and expiry without printing the value, and removes temporary control-host copies. Renewal overlaps only when both credentials are valid; compromise or scope reduction revokes the old credential explicitly and records provider confirmation. Restore reissues or revokes according to the recorded generation and never resurrects a revoked credential.

The supported operation contract covers register, install/pair, check, issue, deliver, refresh, revoke and offboard. Each result names provider, mapping generation, repository scope, permission scope, expiry headroom and refusal reason. Git clone/fetch, branch push and protected-main/merge permissions are distinct; M3 requests only the operation it owns. M7 does not mint M11 dispatch credentials or M12 proxy node tokens.

The authorization matrix is explicit at the resource boundary:

| Actor | Resource / operation | Required scope and result |
|---|---|---|
| controller issuer | register/pair an app or installation | customer authorization for the named forge/owner; creates mapping generation, never a repository token |
| project foreman | request clone/fetch, branch push or protected-main/merge | only the project and operation named by M3; a broader installation is narrowed in the request body |
| Bunker node | clone/fetch and use a delivered runtime credential | its `bunker_ref`, project, repository and expiry must match the mapping; it cannot mint, rotate, widen scope or merge protected main |
| operator / owner | approve, rotate, revoke or offboard | explicit owner authorization; readback is required for every state change |
| provider adapter | exchange, refresh or revoke | control-host issuer credential only; provider response supplies id, scope and expiry; generation is adapter metadata |

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
only a read-only credential and a scoped mutation-broker capability. Forge write tokens remain at the broker (Part I §1.9.3).

Delivery is two-phase: write an owner-only file through the Bunker control channel,
read back its mode, scope digest and provider expiry, then activate the mapping.
Read/fetch, worker-branch push and protected-main/merge are separate permissions;
M3 requests the minimum one. Renewal requires issuer expiry metadata and a declared
headroom margin, not file age. Scope reduction, compromise, provider revocation,
expiry, mapping-generation change and offboarding explicitly revoke the old
credential, record provider confirmation, remove the node copy and invalidate the
cache. Restore replays the mapping but never reactivates a recorded revocation.
All operations emit the common M0 event and are projected by §18/V.10. Base metric
labels remain module/operation/outcome/project; provider, Bunker and refusal reason
appear only in the registered bounded views below. A request for a second project,
wider permission or different Bunker is refused before any provider call.

Acceptance cases cover trust enrollment, GitHub least-privilege issuance, GitLab
project scope, allowed and denied operations across two projects, renewal before
expiry, scope reduction, leaked-token revocation, offboarding and restore without
credential resurrection.

## 16. Provider exchanges and rotation (P5-C-20/21)

The target supports GitHub App installation tokens and GitLab project access tokens
only. Group/deploy tokens are not equivalent; requests selecting them return
PROVIDER_MODE_UNSUPPORTED. Customer authorization is an administrator-signed enrollment
record with provider host, numeric project/repository IDs, installation ID, allowed
roles, expiry and authorization_ref, committed before issuance. The issuer verifies
it against provider reads, not a caller-supplied owner name. API calls use TLS hostname
validation and secret-store headers, never token argv. Provider behavior is an external
conformance requirement, not a measured mint in this chapter. [CT-21; GitHub REST,
“Create an installation access token for an app”; GitLab Project access tokens API]

Decision slot B-FORGE-ADAPTERS: the selected option is GitHub App plus GitLab project
access tokens, with the provider-specific exchanges below. The alternatives are a
GitHub-only MVP or an owner-approved additional adapter carrying this complete
normalized contract and positive/negative vectors. The fail-closed default supports
only the two named adapters; an unregistered provider, token mode or capability mapping
returns PROVIDER_MODE_UNSUPPORTED/CAPABILITY_UNMAPPED before a provider call. Adding
an adapter never silently generalizes GitHub semantics.

| Adapter | Enrollment / issue / check / revoke |
|---|---|
| GitHub | Customer installs its own App and selects repositories. Issuer uses its App JWT for `GET /app/installations/{installation_id}`, checks account.id and installation.repository_selection against enrollment, then `POST /app/installations/{installation_id}/access_tokens` with exactly `{repository_ids: [integer], permissions: {contents: read or write}}`. Response 201 supplies token, expires_at, permissions and repositories; returned repository IDs and permissions must equal the requested restriction. Runtime token checks use `GET /installation/repositories`; revocation is `DELETE /installation/token` authenticated by that token, expected 204. API version header is `X-GitHub-Api-Version: 2022-11-28`; unsupported version refuses qualification. |
| GitLab | Customer authorizes a project Owner/admin issuer for `GET /api/v4/projects/{id}` and project access-token administration. `POST /api/v4/projects/{id}/access_tokens` carries `{name: operation_id, scopes: [read_repository or write_repository], access_level: 20 or 30, expires_at: YYYY-MM-DD}`. Token result includes id, token, scopes, access_level and expires_at; issuer verifies project binding with `GET /api/v4/projects/{id}/access_tokens/{token_id}` and a repository read using the minted token. Revocation is `DELETE /api/v4/projects/{id}/access_tokens/{token_id}`, expected 204; follow-up metadata must report revoked or 404 under issuer auth. |

Clone/fetch uses GitHub contents:read or GitLab read_repository/Reporter (20).
Worker-branch publication uses contents:write or write_repository/Developer (30),
held only by the broker. Main publication uses the same minimal repository write
scope plus a provider protected-branch rule authorizing only the broker identity;
force-push and bypass-admin privileges are disabled. A provider rejecting that rule
returns PROTECTED_REF_UNSUPPORTED; it does not receive a broader token. Branch/ref
restrictions are enforced by the broker even when the provider token spans all refs.
GitLab expiry is provider-date-granular; the issuer additionally enforces the shorter
local capability TTL. No provider field is named mapping_generation: the adapter
adds its pinned mapping generation and SHA-256 of canonical scope to the normalized
result. Provider 401/403/404/409/429/5xx map to AUTH_FAILED/SCOPE_DENIED/
BINDING_NOT_FOUND/PROVIDER_CONFLICT/RATE_LIMITED/PROVIDER_UNAVAILABLE. Network loss
is ISSUANCE_UNKNOWN; only 429/5xx are retryable after lookup/reconciliation, never
blindly minting twice. Error bodies are redacted and carry provider request ID.

Rotation records `{operation_id,mapping_id,generation,old_ref,new_ref,state,
provider_id,expires_at,activation_receipt,error}` durably; references/receipt/error
are nullable only before produced. Credential states are `mint_intent`, `mint_unknown`,
`staged`, `active`, `revoke_pending`, `revoked`, `expired`. Unique operation_id plus
request digest deduplicates retries. The issuer commits intent, mints, stores the
secret durably, delivers a staged file (0600), and verifies id/scope/expiry. Consumer
activation is an atomic pointer swap plus fsynced receipt keyed by operation_id;
lost acknowledgement reads that receipt rather than minting again. Mapping CAS
then selects the new reference and enters ACTIVE. Old credential overlap is at most
60 s. GitHub renewal starts with 300 s headroom; GitLab provider tokens use
Part I §1.9.7's at-most-one-day expiry and twelve-hour renewal margin. The 300 s
margin in V.9 governs proxy/local capabilities, not GitLab provider-date expiry.
Failed staging leaves the old credential
active only while valid and scope unchanged. Compromise/scope reduction first denies
old capabilities in the independent authority; overlap is zero. Remote revocation
failure remains revoke_pending and blocks takeover that needs denial proof.
Expired credentials become expired on trusted issuer time, not falsely provider-revoked.
A mint with lost provider response stays mint_unknown: GitLab reconciles by the
unique operation name; GitHub has no guaranteed token-recovery API, so the issuer
waits the provider maximum lifetime or suspends the installation with denial proof
before retry. Restore uses VI.35's independent authority checkpoint and current
revocation set from F15, never backup expiry or a backup-local watermark alone.

## 17. Resource-side mutation fencing (P5-C-17)

The independent authority and broker in Part I §1.9.3 are mandatory, not a client-side
preflight. The authority's serializable `begin-effect` transaction compares the full
Fence, active lease and revocation sequence and inserts the unique effect ID. Epoch
advance and revocation acquire that same project gate. Advance cannot complete while
an effect is pending/unknown; this is a safety block during partition, not a timeout
that grants a replacement permission. The broker retains the gate through remote
readback by leaving the durable effect pending, not by holding a network mutex.

| Resource | Atomic enforcement and effect completion |
|---|---|
| Git publication | Only the broker has forge write credentials; node credentials are read-only. A push request gives repository_id, ref, expected old OID, new OID, evidence digest and Fence. Broker checks the permitted ref, records begin-effect, pushes with exact ref CAS (no blind force), then reads the remote ref. Matching new OID finishes applied; old OID plus proven no pending transport permits refusal/retry; any other/unknown result holds the gate. Provider hooks are not assumed on hosted GitHub. |
| Board | The broker is the sole canonical ref writer. Boardctl validates claim/fence/expected revision under the same effect gate, stages row+event+operation marker in one Git tree and publishes with ref CAS. Partial local staging is not canonical success; uncertain publication makes the board UNAVAILABLE until readback. No direct worker push can bypass it. |
| Memory | Local offline drafts are permitted, canonical publication is not. Broker validates writer namespace, Fence and each record digest before a single canonical-ref CAS. Stale records go to quarantine evidence, not the namespace index. Canonical acknowledgement follows remote ref and record readback. |
| Crier | Binding/delivery mutation obtains an authority effect grant. In one durable Crier transaction the handler checks registration generation, fence and unique grant ID, consumes the grant, updates binding/custody and writes receipt. The authority holds advance until receipt readback. Duplicate grant returns the stored result; altered payload is EFFECT_CONFLICT. |
| Scheduler | Binding, admission and other project mutations obtain an authority effect grant. In one durable scheduler transaction the handler authenticates the broker and validates the full Fence, binding generation and unique grant ID, consumes the grant, changes state and writes its receipt. The authority blocks advance until receipt readback; duplicate grant returns its stored result and altered payload is EFFECT_CONFLICT. |

The protected resource authenticates the broker principal, not a worker-asserted epoch.
An old broker is itself fenced by the controller authority record. During broker
replacement its outstanding grants are resolved and its provider credentials revoked
with denial proof before a new broker gets credentials; an unreachable old broker
therefore blocks replacement, rather than creating two privileged writers. The broker
never delivers its write credentials to workloads. Existing direct node write tokens
must be revoked and tested denied before this profile is ready. An unmanaged forge
administrator bypass invalidates the guarantee and readiness, as Part I specifies.
Authority outage returns AUTHORITY_UNAVAILABLE; stale fence returns STALE_OWNER with
no new effect. Metrics count these refusals and age of unresolved effects (V.10).
Acceptance races epoch advance against each resource write, partitions the former
owner, and proves either one completed old effect before advance or a refused write,
never an old effect after replacement activation. These are required tests, not
runtime evidence supplied by this source wave.

### 17.1 Deterministic fencing procedure

TARGET-UNIMPLEMENTED; runtime UNVERIFIED. This is an independently checkable
specification example, not a claim that the authority, broker or participants exist.
Part I §§1.9.3–1.9.3a define the only authority protocol: an enrolled controller
requests acquire/advance, but the independent operator-owned authority issues the
Fence and serializes its non-reused epoch with begin/finish and revocations. Requests
use `cf2a.v1` and `authority.v1`; the three Git-backed broker operations use
`broker.v1`. Crier and scheduler consume authority effect grants in their own durable
transactions, not as additional `broker.v1` operation enums. A participant must
verify a grant's authenticity, resource, complete Fence and input digest and consume
its unique ID atomically with the mutation and receipt; an online preflight without
that transaction and the authority's durable pending-effect gate is insufficient.
The broker holds the exclusive write credential and effect gate across each remote
CAS and readback; no worker or old broker may bypass it. Advance and begin serialize
at the authority, so a grant accepted before advance must be resolved first.

Execute the same ordered scenario independently for each table row (do not carry
state between rows). `F7={authority_id:auth-1,project_id:code-factory,epoch:7,
owner_id:manager-1}` is live; `F8` differs only in epoch=8 and owner_id=manager-2.
The authority is reachable, the old owner is isolated, the broker is authenticated,
all grants are unique, and each row's old/new values stand for exact distinct bytes
or durable records. Start with active=F7, no pending effect, and the row's `before`.

1. F7 begins effect `old-1` for that row; authority durably marks it pending before
   any resource mutation. The mutation's acknowledgement is lost: its outcome is
   unknown, so the resource value is not assumed. An advance request to F8 returns
   `EFFECT_UNRESOLVED`; active remains F7, F8 is not activated, and no new-owner
   effect is admitted. Neither lease expiry nor an unreachable owner resolves it.
2. Reconcile the original operation, without blind retry. For this example only,
   authoritative readback proves `old-1` applied and the resource equals `old`;
   `finish-effect` durably records that result. If proof is unavailable, remain
   blocked; alternatively, only proven remote denial plus reconciliation sufficient
   to exclude a late effect can resolve it. A receipt alone is not denial proof.
3. The authority atomically advances F7 to F8 and fences F7 after all pending or
   unknown effects resolve. A new F7 operation returns `STALE_OWNER`, creates no
   effect and leaves `old` unchanged. An unavailable authority instead returns
   `AUTHORITY_UNAVAILABLE` with no write; it never uses a cached allow.
4. F8 begins `new-1`, changes the resource from `old` to `new` using that row's
   atomic boundary, and finishes only after its durable readback/receipt. Final
   active=F8, effect `new-1`=applied, and resource=`new`. A retry of an identical
   grant replays its receipt; changed payload for the same grant is `EFFECT_CONFLICT`.
   For the opposite race, let advance commit before F7 begins: F7 returns
   `STALE_OWNER` and the resource remains `before`; F8 can then write from `before`.

| Resource | Before | Old | New | Atomic boundary / readback |
|---|---|---|---|---|
| Git publication | git-A | git-B | git-C | broker ref CAS and remote ref readback |
| Board | board-A | board-B | board-C | row/event/marker tree ref CAS and remote readback |
| Memory | memory-A | memory-B | memory-C | namespace ref CAS and record readback |
| Crier | crier-A | crier-B | crier-C | grant consumption, binding/custody and receipt in one transaction |
| Scheduler | scheduler-A | scheduler-B | scheduler-C | grant consumption, admission/binding and receipt in one transaction |

Run `python3 docs/audits/p5g03_fencing_check.py`: it checks these five rows and
executes both orderings and the unknown-effect recovery model against the stated
oracles. It is a specification model, not a production conformance test.

ch:trace row=P5G-03 spec=docs/handbook/chapters/M7-github.md#17-resource-side-mutation-fencing-p5-c-17 wave=none:serial test=docs/audits/p5g03_fencing_check.py doc=docs/handbook/chapters/M7-github.md prompt=none:external-brief evidence=docs/audits/p5g03-fencing.md witness=none:specification-only-runtime-unimplemented verdict=none:foreman-pending commit=none:implementation-not-yet-frozen memory=none:foreman-pending

## 18. Closed capabilities and credential telemetry

`Capability` is the closed enum `contents_read`, `contents_write`, `issues_read`,
`issues_write`, `pulls_read`, `pulls_write`, `actions_read`, `actions_write`,
`statuses_write`, `secrets_write`. `cf.forge-grant.v1` is
`{schema_version:"cf.forge-grant.v1",grant_id:ID,principal_id:ID,project_id:ID,
bunker_id:ID,forge_host:Text,repository_ids:UInt[],capabilities:Capability[],
not_before:Time,not_after:Time,max_after:Time,generation:PosInt,
parent_token_fingerprint:SHA,policy_digest:SHA}`. repository_ids is unique/sorted,
capabilities unique/bytewise sorted, and not_before < not_after ≤ max_after. A grant
contains no bearer value. `cf.forge-token.v1` adds token_ref:SecretRef,
token_fingerprint:SHA, grant_id and the exact minted repository/capability/expiry
subset. `cf.forge-readback.v1` is `{grant_id,provider_credential_id,repository_ids,
capabilities,expires_at,observed_at,mapping_generation}`.
`cf.forge-quiescence.v1` is `{grant_id,observed_at,active_attempt_ids:ID[],
external_effect_refs:EvidenceRef[],remote_revocation_id:ID|null,
outcome:quiescent/unknown}`.

The adapter mapping is explicit: GitHub contents read/write maps to
contents_read/contents_write, issues to issues_*, pull_requests to pulls_*, actions
to actions_*, commit_statuses:write to statuses_write and secrets:write to
secrets_write. GitLab read_repository maps to contents_read; write_repository maps
to contents_write; Reporter/Developer is provider role metadata, never an implied
issue/pull/actions grant. Any unmapped provider permission returns
CAPABILITY_UNMAPPED. The normalized result's permission_scope is this Capability
set, not provider strings.

Lifecycle enforcement is:

1. **Issue** authenticates the manager grant/fence and computes requested ∩ granted ∩
   adapter-supported. A missing required capability returns SCOPE_REFUSED before the
   provider call; expiry is bounded by grant.not_after, max_after and §16. The issuer
   stores only token_ref/fingerprint plus the normalized readback.
2. **Check** performs provider readback and compares exact repository/capability sets,
   expiry and mapping generation. A mismatch enters quarantine with
   READBACK_MISMATCH; installation-wide coverage never substitutes for token scope.
3. **Deliver** writes the mode-0600 per-attempt bundle and returns its
   scope_digest/expiry receipt. A worker starts only when required capabilities are
   proven and expiry exceeds its remaining bounded wall plus renewal margin;
   otherwise TOKEN_EXPIRING/DELIVERY_NOT_PROVEN. No token value enters telemetry.
4. **Renew** creates a child grant with a new grant_id/generation and expiry no later
   than max_after, re-narrows against the current parent, activates the new token,
   then fences/revokes the old one. Loss of readback is RENEWAL_REFUSED, never an
   expiry extension.
5. **Revoke** first denies new use and fences live attempts, obtains
   cf.forge-quiescence.v1, deletes the node bundle, proves deletion/401 or provider
   revocation, then records the audit tombstone. Unknown quiescence or remote denial
   is QUIESCENCE_UNKNOWN/REVOCATION_UNKNOWN and blocks replacement that requires
   denial proof. Expiry alone is not revocation.

All five operations emit Part V `factory.telemetry.v1` before acknowledgement with
module M7, event_type `credential-issue`, `credential-check`, `credential-delivery`,
`credential-renew` or `credential-revoke`, operation issue/verify/deliver/renew/revoke,
the closed global outcome set, reason, duration_ms and source_event_id. The event
identity is FactoryIdentity; the payload adds bounded provider, bunker_id, grant_id,
request_id, expiry_headroom_seconds, mapping_generation and partial_activation_id as
applicable. Missing task/attempt IDs are null only for control-plane
enrollment/revocation. No token value enters telemetry.

At emission and at scrape, base counters use exactly
`factory_operations_total{module,operation,outcome,project}` and durations use
`factory_operation_duration_seconds{module,operation,project}`. A successful revoke
has outcome cancelled and reason cancelled. Global accepted comes only from an
explicit accepted custody receipt. Derived registered views are
`factory_credential_expiry_headroom_seconds{module,project,provider,bunker}`
(minimum live headroom gauge),
`factory_credential_scope_refusals_total{module,project,provider,operation,reason}`
(bounded refusal-code counter), `factory_mapping_stale{module,project,provider,bunker}`
(0/1 gauge), and `factory_partial_activations{module,project,provider,bunker}` (current
gauge). Provider/Bunker/reason are permitted only in those views.

The collector polls every 10 s, persists module/source_event_id/source_seq checkpoints,
deduplicates retries/restarts and derives freshness from the last new source event,
not a successful scrape. Missing source observations are unavailable, never zero.
CV-11-A requires all five operations at emission and scrape with one duplicate event
adding no count; CV-11-B requires missing observation to retain FactoryIdentity and
ready=false.

## 19. Incomplete callbacks and provider outage (P6-12, P6-13)

A provider callback is evidence about an effect, not the commit point of the
effect. M7 persists a `cf.forge-attempt.v1` record before the first provider
mutation. The record contains `schema_version:string="cf.forge-attempt.v1"`,
`forge_attempt_id:ID`, `operation_id:ID`, `idempotency_key:string[1,200]`,
`repository_id:ID`, `effect:create|merge|push|release|publish`,
`target_ref:GitRef`, `expected_old_oid:GitOid|null`,
`candidate_oid:GitOid`, `candidate_tree_digest:sha256`,
`release:{tag:string,commit_oid:GitOid,tree_digest:sha256,asset_digests:sha256[]}|null`,
`state:prepared|sent|applied|refused|unknown|superseded`,
`provider_receipt:object|null`, `readback_refs:EvidenceRef[]`,
`created_at:Time`, `updated_at:Time` and `policy_generation:PosInt`. Asset
digests are bytewise sorted and unique. The provider request, response headers
and body digest are evidence references; tokens and signed URLs are excluded.
The idempotency identity is `(repository_id,effect,idempotency_key)`. An
identical replay returns the existing attempt. Changed canonical input under
that identity returns `IDEMPOTENCY_KEY_REUSED` without a provider mutation.

`prepared` becomes `sent` only after the durable begin-effect and fenced
authorization. An exact provider readback of repository, ref/tag, commit, tree
and every asset digest makes the attempt `applied`; an explicit scope or policy
denial makes it `refused`. A timeout, connection loss, 5xx, lost response or
missing callback leaves `unknown`. `unknown` does not undo `applied`, does not
become success and does not authorize a blind second mutation. Recovery first
reads the provider by the original identity. A matching readback settles the
original attempt; a proven absent effect may be retried with the same effect id;
a different remote object returns `PROVIDER_DIVERGENCE` and preserves both
identities. A newer candidate marks the old attempt `superseded` only after the
old effect is resolved. Provider readback, not callback arrival, is the
publication commit point.

Callbacks use a separate `cf.forge-callback.v1` record with `callback_id:ID`,
`forge_attempt_id:ID|null`, `repository_id:ID`, `provider_event_id:string`,
`received_at:Time`, `payload_digest:sha256`, `signature_state:verified|invalid|
unsupported`, `state:accepted|incomplete|orphan|duplicate|rejected` and
`evidence_ref:EvidenceRef`. An unsigned or invalid-signature callback is
rejected. A valid callback without a matching durable attempt is `orphan`; one
missing repository, effect, object or digest identity is `incomplete`. Neither
state advances publication. The receiver stores the bounded raw payload digest,
returns `202 CALLBACK_PENDING` for an incomplete/orphan callback and schedules
provider readback. Replayed `provider_event_id` with identical bytes is
`duplicate`; changed bytes are `CALLBACK_CONFLICT`. Callback processing emits no
second publication counter.

M7's reconciliation worker runs every 30 seconds with exponential retry bounded
by the operation deadline. It reads exact repository/tag/commit/tree/asset state
through the same broker credential and writes the resulting `publication.v1`
state. During an outage, existing `applied` evidence remains valid for its exact
remote object; new closeout requiring an unobserved effect remains unsettled.
Provider unavailability is `PROVIDER_UNAVAILABLE`, not a test, judge or push
failure, and does not erase independent mechanical evidence. Restored provider
access resumes from durable attempts and callbacks; no callback backlog is
required to reconstruct an already readable remote effect.

Decision slot `B-PUBLICATION-UNCERTAINTY` offers (a) exact provider readback as
the authority with callbacks as hints, or (b) a provider-signed callback log with
a proven complete replay and equivalence battery. The fail-closed default is (a);
an incomplete callback or unavailable provider never certifies publication.
Evidence includes lost-response, incomplete-callback, duplicate-callback,
provider-outage, restart-during-readback and exact-applied-readback fixtures.
[M3 §§17.2–17.3; M4 §15.4; CV-12-A; V.10.]

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
