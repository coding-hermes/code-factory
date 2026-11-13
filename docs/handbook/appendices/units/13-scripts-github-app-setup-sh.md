# 13. scripts/github-app-setup.sh

| Field | Value |
|---|---|
| Path | `~/code-factory/scripts/github-app-setup.sh` — 297 lines, three modes (`--check`, `--apply`, `--manifest`) [scripts/github-app-setup.sh:1] [scripts/github-app-setup.sh:76] |
| Repository | `code-factory` |
| Revision | `dad2749` (worktree `~/proj-wt-md-28e`, clean) |
| Status | **VERIFIED** — 21 arms executed on 2026-11-05 against a local GitHub API stub (§3); 267 locator citations (150 distinct file:line pairs), all resolve; cites fact: FACT-05, FACT-10; `python3 scripts/master_doc_check.py docs/master --only 13- --strict` → `MASTER-DOC: PASS` |

## 1. Purpose and why it matters

- What it is: the **first-install walkthrough** for the fleet's GitHub App credential. It has three modes and no daemon: `--check` measures an existing install, `--apply` collects the answers, writes the pointer file and then measures, `--manifest` prints the App manifest JSON for the browser flow [scripts/github-app-setup.sh:4] [scripts/github-app-setup.sh:151]. The reason it exists at all is stated in the header: a PAT is one person's whole scope and never expires, while an App installation token is scoped to named repositories and dies in one hour [scripts/github-app-setup.sh:9-13].
- **It cannot create the App, and says so.** Registering a GitHub App is a browser authorization click; the private key is a one-time download [scripts/github-app-setup.sh:15-19]. The script prints four numbered browser steps instead of pretending otherwise [scripts/github-app-setup.sh:121-147].
- **Who creates each piece, and how the script measures it.** This table is the whole module:

| Piece | Created by | Verified how | Recorded where |
|---|---|---|---|
| App id | human, App settings → About | a JWT signed with the key must be accepted by `POST /app/installations/<id>/access_tokens`; a 401 is reported as an App-id/key mismatch [scripts/github-app-token.py:383] | `GITHUB_APP_ID` in the pointer file [scripts/github-app-setup.sh:264] |
| Installation id | human, the install click | the same POST must answer 200/201; a 404 is reported as "installation does not belong to App, or the App is not installed" [scripts/github-app-token.py:393] | `GITHUB_APP_INSTALLATION_ID` [scripts/github-app-setup.sh:265] |
| Private key | human, one-time download | mode must be 0600, the PEM must parse as RSA, and the modulus must be ≥2048 bits [scripts/github-app-token.py:342] [scripts/github-app-token.py:196] | the **path** only, `GITHUB_APP_PRIVATE_KEY_FILE` [scripts/github-app-setup.sh:266] |
| Declared permissions | human, App settings | read back from the mint response **and** from `GET /apps/<slug>` [scripts/github-app-token.py:466] [scripts/github-app-token.py:478] | not recorded |
| Repo coverage | human, install page | `GET /installation/repositories` must list the target [scripts/github-app-token.py:504] | `GITHUB_APP_REPO`, read by the minter from the pointer file |
| Read access | nobody | `GET /repos/<owner>/<name>` **with the freshly minted token** must answer 200 [scripts/github-app-token.py:539] | not recorded |
| Refresh armed | human, systemd timer | a timer file exists or `crontab -l` mentions it [scripts/github-app-setup.sh:197] | not recorded |

- What breaks if this module is absent: the credential would have to be hand-written, and the only consumer that checks for it refuses with `env_file … absent — run scripts/github-app-setup.sh --apply once` [scripts/github-app-refresh.sh:57]. Nothing else in the tree writes `~/.config/code-factory/github-app.env`: `GITHUB_APP_ENV_FILE` is read by three programs and written by this one [scripts/github-app-setup.sh:32] [scripts/github-app-token.py:45] [scripts/github-app-refresh.sh:24].
- What breaks if it lies — answered exactly, because this is the pattern the repo keeps finding:
  - **The success path is a real read, not a recorded intention.** `--apply` prints `READY` only after the minter has minted a token and read the repo with it [scripts/github-app-setup.sh:278] [scripts/github-app-token.py:566]. Measured: the stub saw `POST …/access_tokens`, `GET /installation/repositories`, `GET /repos/coding-hermes/code-factory` before the READY line (§3 arm 5).
  - **`--check` now fails closed when no repository is named.** The minter reads `GITHUB_APP_REPO` from the pointer file, performs the coverage and repository read, and emits a named `repo_read` FAIL when neither `--repo` nor the pointer names a repository. The setup summary names the repository and `-> 200` only after that measured read; the no-repo arm exits non-zero without a false PASS claim (CF-319; transcript in the CF-319 audit file).
  - **The count in the verdict is not a count.** The no-config arm hard-codes `FAIL (1)` [scripts/github-app-setup.sh:176]; other failing arms print an unnumbered `GITHUB APP SETUP: FAIL` [scripts/github-app-setup.sh:208]; and `lib.sh`'s `FAILED` counter is incremented by `bad` and never read here [scripts/lib.sh:7].
- What it does **not** claim, and must not be read as claiming: it does not create the App, does not mint or store a token, does not write `~/.git-credentials`, and does not install the refresh timer — its own WARN tells the operator to arm one elsewhere [scripts/github-app-setup.sh:201].
- Secrets: nothing secret is printed, by construction and by measurement. The file contains no `printf` of the key, the JWT or the token; it prints the key **path** and the token **path** [scripts/github-app-setup.sh:266] [scripts/github-app-setup.sh:270]. The stub's token string `ghs_STUBTOKENNOTREAL` appeared 0 times in the captured stdout of every arm (§3). This matches the fleet rule that credentials travel as file paths at mode 600, never as values in argv or logs [docs/master/_facts.md:16] (fact: FACT-05).

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `bash` | needs `set -uo pipefail` and arrays [scripts/github-app-setup.sh:28] [scripts/github-app-setup.sh:157] | the shebang interpreter [scripts/github-app-setup.sh:1] | not detected — the shell is already running |
| `scripts/lib.sh` | the repo's 65-line helper file [scripts/lib.sh:1] | beside the script, `$HERE/lib.sh` [scripts/github-app-setup.sh:30] | not detected as a row: sourcing is unguarded, so a lone copy dies with `No such file or directory` before any row prints |
| `python3` | any 3.x that the minter supports; the file needs no third-party module [scripts/github-app-token.py:29] | on `PATH`, resolved by `command -v` [scripts/github-app-setup.sh:97] | `  FAIL  python3 — python3 is required (it signs the App JWT)` then exit 1 [scripts/github-app-setup.sh:98]; measured, §3 arm 16 |
| `github-app-token.py` | 768 lines, the single implementation of verification [scripts/github-app-token.py:1] | beside the script, `$HERE/github-app-token.py` [scripts/github-app-setup.sh:99] | `  FAIL  minter — <path> is missing` then exit 1 [scripts/github-app-setup.sh:100]; measured, §3 arm 17 |
| `git` | any | on `PATH`, only for the default repo [scripts/github-app-setup.sh:72] | not detected as a row: the failure is swallowed by `|| true` [scripts/github-app-setup.sh:72], and the effect is the missing repo — which silently removes the read-back (D-1) |
| `stat` | coreutils | on `PATH`, for both file modes [scripts/github-app-setup.sh:179] [scripts/github-app-setup.sh:250] | absence yields `?`, which fails the `= 600` comparison and prints `is mode ?, expected 600` [scripts/github-app-setup.sh:183] |
| `crontab` | any cron | on `PATH`, only when the systemd timer file is absent [scripts/github-app-setup.sh:198] | not detected: `2>/dev/null` hides it and the row degrades to the refresh WARN [scripts/github-app-setup.sh:201] |
| `sed`, `dirname`, `mktemp`, `mv`, `chmod`, `mkdir` | coreutils / sed | on `PATH` | not detected; `mktemp`/`mv` failure in `--apply` leaves no env file and no row of its own [scripts/github-app-setup.sh:259-272] |
| `openssl` or any crypto library | **not required** — RSA parse and RS256 signing are stdlib [scripts/github-app-token.py:153] [scripts/github-app-token.py:207] | — | — |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `. "$HERE/lib.sh"` [scripts/github-app-setup.sh:30] | `scripts/lib.sh` | Four helpers: `say` = `printf '%s\n'` [scripts/lib.sh:5]; `ok` = `  PASS  %s — %s` [scripts/lib.sh:6]; `bad` = `  FAIL  %s — %s` plus `FAILED=$((FAILED+1))` [scripts/lib.sh:7]; `warn` = `  WARN  %s — %s` [scripts/lib.sh:8] | The row **format** is the contract, not the counter: this module never reads `$FAILED` and decides on a local `rc` [scripts/github-app-setup.sh:164] [scripts/github-app-setup.sh:210]. Dropping `bad`'s increment changes nothing here, while changing the `  FAIL  ` prefix breaks every operator grep that counts rows |
| `"$PY" "$MINTER" check --env-file … [--repo …] [--slug …] --api-base …` [scripts/github-app-setup.sh:156] | `scripts/github-app-token.py` subcommand `check` [scripts/github-app-token.py:702] | Exit 0 = every row measured; 1 = a named FAIL; 2 = usage error [scripts/github-app-token.py:29]. Rows are printed by the child on **stdout** and are inherited unchanged; the parent adds only `verification` and `refresh` [scripts/github-app-setup.sh:189] | A change in the child's exit convention turns `PASS  verification` into a lie without any row changing shape; a change to the row prefix would desynchronise the two scripts' logs in one run (both are printed into the same stream) |
| `--repo` default = `os.environ.get("GITHUB_APP_REPO", "")` [scripts/github-app-token.py:708] | the environment of the calling shell, or the pointer file's `GITHUB_APP_REPO` | The verifier resolves the explicit flag first, then the pointer-file value, then the environment default | CF-319 closes D-1: the setup script and minter now read back the value written by `--apply` |
| `read_env_file` grammar: `KEY=VALUE`, `#` comments, one `=` partition, surrounding quotes stripped, never sourced [scripts/github-app-token.py:88] | the env file this script writes [scripts/github-app-setup.sh:261] | The writer emits bare `KEY=VALUE` with no quoting and no trailing spaces [scripts/github-app-setup.sh:264-270], which the reader round-trips exactly (measured: the `--apply` file is re-read by `--check` in the next arm, §3 arms 5 and 6) | A value containing `=` survives (partition on first `=`); a value containing a newline cannot be expressed at all |
| `load_rsa_key(path)` → `(n, e, d)` [scripts/github-app-token.py:153] | the PEM GitHub downloads | Accepts both `RSA PRIVATE KEY` (PKCS#1) and `PRIVATE KEY` (PKCS#8, what OpenSSL 3 writes) [scripts/github-app-token.py:179]; refuses `ENCRYPTED` keys by name [scripts/github-app-token.py:160]; refuses anything under 2048 bits [scripts/github-app-token.py:196] | A key format outside these two labels is refused as `does not parse as an RSA private key (…)` even when OpenSSL accepts it; the measured key here was PKCS#8 from OpenSSL 3.5.5 and parsed (§3 arm 5) |
| `api()` → `(status, payload)`, `0` means no answer [scripts/github-app-token.py:235] | `urllib.request` with a 20 s timeout [scripts/github-app-token.py:252] | Status is the only thing rows quote; a connection failure becomes `0` and is rendered as `-> 0 — no answer` [scripts/github-app-token.py:557] | A proxy that returns HTML with a 200 makes `_maybe_json` return `None` and the row reads `— no answer` while the status is 200 [scripts/github-app-token.py:262] |

### 2c. Service contracts (both sides named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| `POST /app/installations/<installation_id>/access_tokens` | this script → GitHub API, via the minter | HTTPS, `Authorization: Bearer <JWT>` signed RS256 with the App key; `Accept: application/vnd.github+json`, `X-GitHub-Api-Version: 2022-11-28` [scripts/github-app-token.py:238] | empty body; response must carry `token`, `expires_at`, `permissions` [scripts/github-app-token.py:373] | GitHub's App-token endpoint. Stub-observed as request 1 of 4 in the READY arm (§3 arm 5) |
| `GET /apps/<slug>` | this script → GitHub API | HTTPS, **unauthenticated** (stub log: `auth=no`) [scripts/github-app-token.py:480] | response `permissions` is compared against the declared set; `contents` must be `write` [scripts/github-app-token.py:492] | GitHub's public App metadata; only reached when a slug is known — `--slug` or the env file's `GITHUB_APP_SLUG` [scripts/github-app-token.py:478] |
| `GET /installation/repositories?per_page=100` | this script → GitHub API | HTTPS, `Authorization: Bearer <installation token>` | `repositories[].full_name` must contain `OWNER/NAME` [scripts/github-app-token.py:511] | GitHub's installation listing; request 3 of 4 in the READY arm |
| `GET /repos/<owner>/<name>` | this script → GitHub API | HTTPS, same installation token | any 200 satisfies `repo_read`; 401/403 is reported as "cannot read: does not cover it, or contents is not granted" [scripts/github-app-token.py:547] | GitHub's repo endpoint; request 4 of 4 in the READY arm and the **only** row that proves the credential works |
| `~/.config/code-factory/github-app.env` | this script → file (write, atomic `mktemp` + `mv`) [scripts/github-app-setup.sh:259]; minter → file (read) [scripts/github-app-token.py:88]; refresh → file (existence only) [scripts/github-app-refresh.sh:57] | local file, mode 600 enforced on both sides [scripts/github-app-setup.sh:272] [scripts/github-app-token.py:346] | six `KEY=VALUE` pointers, no secret [scripts/github-app-setup.sh:262-270] | This script is the only writer in the tree; the minter is the only reader that parses it |
| `~/.config/systemd/user/cf-github-app-refresh.timer` | this script → file (existence test only) [scripts/github-app-setup.sh:197] | local `-f` test | none read | Nothing in this repo creates that file: `github-app-refresh.sh` contains no timer or crontab code [scripts/github-app-refresh.sh:13-17], and the skill it points at contains no mention of a timer (D-2) |
| The operator's terminal | this script ↔ stdin | `[ -t 0 ]` guard, then `IFS= read -r` [scripts/github-app-setup.sh:216] | one line per missing answer, prompted with `printf … >&2` [scripts/github-app-setup.sh:219] | `--apply` when a flag is omitted; a non-tty refuses rather than guessing (§3 arm 11) |

## 3. Verification

All arms were run in a clean worktree of `dad2749` on 2026-11-05, with `HOME` pointed at a scratch directory and `GITHUB_APP_ENV_FILE`/`GITHUB_API_BASE` unset unless the arm says otherwise. **No real App was created and no call left the host**: where an HTTP peer was needed, a local stub answered the four endpoints of §2c and logged every request (method, path, whether an `Authorization` header was present — never its value). The stub is not part of the repo; its log lines are labelled as such.

| # | Check | Command | Expected | Last run | Result |
|---|---|---|---|---|---|
| 1 | **The measured state: `--check` with no config** | `HOME=<scratch> bash scripts/github-app-setup.sh --check` | one FAIL, browser steps, exit 1 [scripts/github-app-setup.sh:167] | 2026-11-05 | **exit 1**, `GITHUB APP SETUP: FAIL (1) — no env file, nothing measured`; no HTTP request is possible on this path because the function returns before the minter is called |
| 2 | Env file present, mode 644, key absent | same, with a hand-written env file | `FAIL env_file` + the minter's key row [scripts/github-app-setup.sh:183] | 2026-11-05 | two FAIL rows from two processes, then `GITHUB APP: FAIL (1)` — **the counts disagree** (D-5) |
| 3 | Env file 600, key absent | same | one key FAIL | 2026-11-05 | `  PASS  env_file` then `  FAIL  private_key_file — … does not exist — move the downloaded .pem there` |
| 3b | **Everything good except the env file mode** (644, valid key, stub grants all) | `--check` with the file chmod 644 | one FAIL, no success line | 2026-11-05 | `  FAIL  env_file — … is mode 644, expected 600`, then the minter prints `GITHUB APP: PASS`, then `GITHUB APP SETUP: FAIL`, exit 1 — **one run, two opposite verdicts** (D-6) |
| 4 | Key exists at 600 but is not a key | same | parse refusal, no network | 2026-11-05 | `  FAIL  private_key_file — … does not parse as an RSA private key (Incorrect padding)` |
| 5 | **`--apply`, every piece good, against the stub** | `--apply --slug code-factory --repo coding-hermes/code-factory --app-id 123456 --installation-id 12345678 --key-file <pkcs8> --api-base http://127.0.0.1:18081` | env file at 600, then mint + read, then `READY` [scripts/github-app-setup.sh:280] | 2026-11-05 | **exit 0**, `GITHUB APP SETUP: READY — every piece verified, and a fresh installation token reads coding-hermes/code-factory`; 4 requests logged (Transcript 2) |
| 6 | `--check` re-reads what `--apply` wrote, timer armed, repo given as a URL | `--check --repo https://github.com/coding-hermes/code-factory.git` with `cf-github-app-refresh.timer` planted | every row PASS, exit 0 [scripts/github-app-setup.sh:66] | 2026-11-05 | `  PASS  refresh — a refresh timer/cron entry is armed for this host` and `SETUP: PASS — … reads coding-hermes/code-factory` — the URL form is normalised |
| 7 | Mint ok, repo read 404 | `--check --repo … --api-base <stub repo404>` | one FAIL, `repo_read` [scripts/github-app-token.py:557] | 2026-11-05 | every other row PASS, `  FAIL  repo_read — GET /repos/coding-hermes/code-factory -> 404 — Not Found`, `SETUP: FAIL`, exit 1 |
| 8 | App declares `contents:read` | `--check --api-base <stub readonly>` | two FAILs under one piece name [scripts/github-app-token.py:474] [scripts/github-app-token.py:492] | 2026-11-05 | `FAIL permission:contents — granted 'read', need 'write'` **and** `FAIL permission:contents — the App itself declares contents='read'; fix the App, not the token`; the second source is why the name repeats (D-6) |
| 9 | **`--check` with no `--repo`, outside git, env file names the repo** | staged copy of the three files in a non-git dir, `--check --env-file <env with GITHUB_APP_REPO>` | the pointer-file repo is read | 2026-11-13 | **FIXED — the minter reads `GITHUB_APP_REPO`, emits coverage and `repo_read`, and the summary names the repo and `-> 200`; CF-319 Arm B** |
| 10 | Same, with `GITHUB_APP_REPO` **exported** | `GITHUB_APP_REPO=coding-hermes/code-factory … --check` | the read returns | 2026-11-13 | `PASS installation_covers`, `PASS repo_read`, 4 requests — legacy environment resolution remains supported |
| 11 | `--apply` with no tty and missing answers | `… --apply --slug s --repo o/n < /dev/null` | three refusals, nothing written [scripts/github-app-setup.sh:217] | 2026-11-05 | `FAIL APP_ID`, `FAIL INSTALLATION_ID`, `FAIL KEY_FILE` — note the doubled dash and upper-case name; exit 1; directory empty |
| 12 | `--apply` with a non-numeric App id | `--app-id abc` | refused before writing [scripts/github-app-setup.sh:241] | 2026-11-05 | `  FAIL  app_id — --app-id 'abc' is not the numeric App ID`, `nothing written`, exit 1 |
| 13 | `--apply` with the key at 644 | `--key-file <644 key>` | refuses, does **not** chmod [scripts/github-app-setup.sh:252] | 2026-11-05 | refusal names the mode and the command to run; the file was still `644` afterwards — the refusal is real |
| 14 | Refresh detection, both arms | plant `~/.config/systemd/user/cf-github-app-refresh.timer`, then remove it | PASS row vs WARN row [scripts/github-app-setup.sh:199] [scripts/github-app-setup.sh:201] | 2026-11-05 | `PASS refresh — a refresh timer/cron entry is armed for this host` / `WARN refresh — no refresh timer …`; **both exit 0** (D-2) |
| 15 | `--apply` where verification fails | `--apply … --api-base <stub repo404>` | env file written, no success claim [scripts/github-app-setup.sh:288] | 2026-11-05 | `GITHUB APP SETUP: INCOMPLETE — the env file was written but verification FAILED;`, exit 1, env file left at 600 — a record, not a claim |
| 16 | A malformed env file | env file with a line that is not `KEY=VALUE` | refused as data, not executed [scripts/github-app-token.py:96] | 2026-11-05 | `  PASS  env_file` **and** `  FAIL  env_file — … is unreadable as KEY=VALUE data (line is not KEY=VALUE: …)` in one run (D-6) |
| 17 | No `python3` / no minter | isolated `PATH`; staged copy without the minter | exit 1 with a named row | 2026-11-05 | `  FAIL  python3 — python3 is required (it signs the App JWT)`; `  FAIL  minter — …/github-app-token.py is missing` |
| 18 | Idempotence | run `--apply` twice with the same answers | nothing changes, exit 0 [AGENTS.md:35] | 2026-11-05 | md5 identical before/after, mode still 600, exit 0 |
| 19 | Manifest and argument errors | `--manifest --name code-factory --org coding-hermes`; `-h`; `--bogus` | JSON; help; usage error | 2026-11-05 | manifest JSON with `default_permissions` of the three; `-h` exit 0 but prints three shell lines (D-4); `unknown argument: --bogus` exit 2 |
| 20 | The doc gate | `python3 scripts/master_doc_check.py docs/master --only 13- --strict` | `MASTER-DOC: PASS` | 2026-11-05 | **PASS**, 0 errors 0 warnings |

Transcript 1 — arm 1, the state this module is in on a host with no App:

```
$ HOME=<scratch> bash scripts/github-app-setup.sh --check; echo "EXIT=$?"
github-app-setup --check — env file <scratch>/.config/code-factory/github-app.env

  FAIL  env_file — <scratch>/.config/code-factory/github-app.env does not exist yet

  Nothing is configured, so nothing can be verified. The pieces a person creates
  by hand are: the App (its id), the installation (its id), the private key file at
  mode 600, and the installation's coverage of the target repo.

… (BROWSER STEPS and PERMISSIONS blocks elided) …

GITHUB APP SETUP: FAIL (1) — no env file, nothing measured
EXIT=1
```

Transcript 2 — arm 5, `--apply` against the stub. This is the only proof in the document that the success path performs a read:

```
$ bash scripts/github-app-setup.sh --apply --slug code-factory --repo coding-hermes/code-factory \
    --app-id 123456 --installation-id 12345678 --key-file <pkcs8> --api-base http://127.0.0.1:18081
github-app-setup --apply — writing <home>/.config/code-factory/github-app.env

… (browser-step disclaimer and PERMISSIONS block elided) …

  PASS  env_file — <home>/.config/code-factory/github-app.env written, mode 600 (no secret in it: it names the key path)

verifying the pieces against the GitHub API (a real call; the token is never printed)

  PASS  private_key_file — <key>, mode 600, parses as RSA 2048-bit
  PASS  token_mint — installation 12345678 answered 201; token expires 2026-11-05T23:00:00Z (permissions read back, never the token)
  PASS  permission:contents — write (need write — clone and push commits; a push is a contents write)
  PASS  permission:metadata — read (need read — mandatory for every App; resolves the repo and the installation)
  PASS  permission:pull_requests — write (need write — open the PR a protected main requires (CF-163))
  PASS  app_slug — /apps/code-factory -> 200 (declared permissions: contents:write,metadata:read,pull_requests:write)
  PASS  installation_covers — installation grants coding-hermes/code-factory (of 2 repositories)
  PASS  repo_read — GET /repos/coding-hermes/code-factory with a fresh token -> 200

GITHUB APP: PASS — every piece measured, a fresh token reads coding-hermes/code-factory -> 200

GITHUB APP SETUP: READY — every piece verified, and a fresh installation token reads coding-hermes/code-factory

the token expires in 3600s, so armed the refresh next:
  scripts/github-app-token.py token            # mint one now, mode 600
  scripts/github-app-refresh.sh --local        # and keep this host fresh
EXIT=0

# the stub's request log for the same run (stub instrumentation, not the module's output):
POST /app/installations/12345678/access_tokens auth=yes 2022-11-28
GET /apps/code-factory auth=no 2022-11-28
GET /installation/repositories?per_page=100 auth=yes 2022-11-28
GET /repos/coding-hermes/code-factory auth=yes 2022-11-28
```

Transcript 3 — historical arm 9, the pre-CF-319 no-repo false-green control:

```
$ /bin/bash <staged>/github-app-setup.sh --check --env-file <env> --api-base http://127.0.0.1:18081
github-app-setup --check — env file <env>

  PASS  env_file — <env> present, mode 600
  PASS  private_key_file — <key>, mode 600, parses as RSA 2048-bit
  PASS  token_mint — installation 12345678 answered 201; token expires 2026-11-05T23:00:00Z (permissions read back, never the token)
  PASS  permission:contents — write (need write — clone and push commits; a push is a contents write)
  PASS  permission:metadata — read (need read — mandatory for every App; resolves the repo and the installation)
  PASS  permission:pull_requests — write (need write — open the PR a protected main requires (CF-163))
  PASS  app_slug — /apps/code-factory -> 200 (declared permissions: contents:write,metadata:read,pull_requests:write)
  FAIL  repo_read — no repository named, so the read was not measured (pass --repo OWNER/NAME or set GITHUB_APP_REPO)

GITHUB APP: FAIL (1)
  FAIL  verification — one or more pieces above are missing or wrong — see the named rows
  WARN  refresh — no refresh timer on this host — a node will lose push rights 3600s after provisioning (scripts/github-app-refresh.sh --node <agent> --server <host>; see skills/code-factory-bunker/SKILL.md)

GITHUB APP SETUP: FAIL
EXIT=1

# the pre-CF-319 stub saw exactly two requests — a mint and an unauthenticated metadata read:
POST /app/installations/12345678/access_tokens auth=yes 2022-11-28
GET /apps/code-factory auth=no 2022-11-28
```

What these runs do **not** establish: no arm reached the real `api.github.com`; the 401/403 mint branches [scripts/github-app-token.py:383] [scripts/github-app-token.py:404] and the "installation does not cover this repo" branch [scripts/github-app-token.py:526] were read from source, not triggered, because all three need GitHub to hold an App this run must not create. The refresh row was driven by planting the systemd timer file, not by a live timer; the crontab half of the same test [scripts/github-app-setup.sh:198] was not exercised.

## 4. Metrics emitted

**NONE.** There is no counter, histogram, gauge, span, duration or machine-readable record: the module has no `date`, no `time`, no JSON output and no exit-code taxonomy beyond 0/1/2 [scripts/github-app-setup.sh:210] [scripts/github-app-token.py:29]. Its entire output vocabulary is five `printf` formats from `lib.sh` [scripts/lib.sh:5-9] plus the minter's own three [scripts/github-app-token.py:70-79]. The one countable-looking thing is a trap: `lib.sh` increments `FAILED` on every `bad` [scripts/lib.sh:7], and this module never reads it — the verdict is a local `rc`, and the only count it ever prints is the literal `1` in the no-config arm [scripts/github-app-setup.sh:176] [scripts/github-app-setup.sh:210]. Why that is acceptable here: this is an operator-run, one-shot install step with no rate, queue or latency to instrument; its durable record is the operator's terminal and the mode-600 pointer file it writes. Why it is still a defect: every downstream report that wants "are the fleet's App credentials healthy" has to re-run `--check` per host and parse prose, because the PASS row carries neither a timestamp nor a count.

## 5. Log lines it can generate

All lines are stdout `printf` output through `lib.sh`'s two-space gutter [scripts/lib.sh:5-9] or the minter's identical formats [scripts/github-app-token.py:70-79]. Tag = **evidentiary** when the exact line was emitted by an arm recorded in §3; **descriptive** when it is a literal format string in the file that no recorded arm reached. Placeholders in `<angle brackets>` are the runtime values; the text around them is verbatim.

| Level | Line (verbatim) | Emitted when | Kind |
|---|---|---|---|
| info | `github-app-setup --check — env file <path>` | start of every check [scripts/github-app-setup.sh:165] | evidentiary |
| FAIL | `  FAIL  env_file — <path> does not exist yet` | no pointer file at all [scripts/github-app-setup.sh:168] | evidentiary |
| info | `GITHUB APP SETUP: FAIL (1) — no env file, nothing measured` | the same arm, as its verdict [scripts/github-app-setup.sh:176] | evidentiary |
| PASS | `  PASS  env_file — <path> present, mode 600` | file exists at the right mode [scripts/github-app-setup.sh:181] | evidentiary |
| FAIL | `  FAIL  env_file — <path> is mode 644, expected 600 (chmod 600 <path>)` | any mode other than 600 [scripts/github-app-setup.sh:183] | evidentiary |
| PASS | `  PASS  verification — every hand-made piece measured green by github-app-token.py` | the child exited 0 [scripts/github-app-setup.sh:190] | evidentiary |
| FAIL | `  FAIL  verification — one or more pieces above are missing or wrong — see the named rows` | the child exited non-zero [scripts/github-app-setup.sh:192] | evidentiary |
| PASS | `  PASS  refresh — a refresh timer/cron entry is armed for this host` | timer file or crontab match [scripts/github-app-setup.sh:199] | evidentiary |
| WARN | `  WARN  refresh — no refresh timer on this host — a node will lose push rights 3600s after provisioning (scripts/github-app-refresh.sh --node <agent> --server <host>; see skills/code-factory-bunker/SKILL.md)` | neither exists; **does not fail the run** [scripts/github-app-setup.sh:201] | evidentiary |
| info | `GITHUB APP SETUP: PASS — the App credential is real, scoped, and reads <repo>` | `rc = 0`; the read is *not* implied (arm 9) [scripts/github-app-setup.sh:206] | evidentiary |
| info | `GITHUB APP SETUP: FAIL` | `rc ≠ 0`, with no count [scripts/github-app-setup.sh:208] | evidentiary |
| info | `github-app-setup --apply — writing <path>` | start of every apply [scripts/github-app-setup.sh:227] | evidentiary |
| PASS | `  PASS  env_file — <path> written, mode 600 (no secret in it: it names the key path)` | after the atomic write [scripts/github-app-setup.sh:273] | evidentiary |
| info | `verifying the pieces against the GitHub API (a real call; the token is never printed)` | before the mint [scripts/github-app-setup.sh:276] | evidentiary |
| info | `GITHUB APP SETUP: READY — every piece verified, and a fresh installation token reads <repo>` | the mint **and** the read passed [scripts/github-app-setup.sh:280] | evidentiary |
| info | `GITHUB APP SETUP: INCOMPLETE — the env file was written but verification FAILED;` | apply's write succeeded, its verification did not [scripts/github-app-setup.sh:288] | evidentiary |
| FAIL | `  FAIL  APP_ID — not a terminal and --APP_ID was not given — refusing to guess it` | `--apply` with no tty and no flag; the name is doubled and upper-cased by construction [scripts/github-app-setup.sh:217] | evidentiary |
| FAIL | `  FAIL  app_id — --app-id 'abc' is not the numeric App ID` | non-numeric id [scripts/github-app-setup.sh:241] | evidentiary |
| FAIL | `  FAIL  private_key_file — <path> is mode 644; refusing to chmod a key you may have placed for another purpose — run: chmod 600 <path>` | apply, key not at 600 [scripts/github-app-setup.sh:252] | evidentiary |
| FAIL | `  FAIL  python3 — python3 is required (it signs the App JWT)` | no interpreter [scripts/github-app-setup.sh:98] | evidentiary |
| FAIL | `  FAIL  minter — <path> is missing` | `github-app-token.py` not beside the script [scripts/github-app-setup.sh:100] | evidentiary |
| FAIL | `unknown argument: --bogus` | unrecognised argv; help follows, exit 2 [scripts/github-app-setup.sh:92] | evidentiary |
| PASS | `  PASS  private_key_file — <path>, mode 600, parses as RSA 2048-bit` | key accepted (minter row) [scripts/github-app-token.py:442] | evidentiary |
| PASS | `  PASS  token_mint — installation <id> answered 201; token expires <ts> (permissions read back, never the token)` | mint answered [scripts/github-app-token.py:460] | evidentiary |
| FAIL | `  FAIL  token_mint — 401 — the JWT was rejected: App id <id> does not own the key at GITHUB_APP_PRIVATE_KEY_FILE, or the clock is off` | wrong key for the App, or clock skew [scripts/github-app-token.py:383] | descriptive |
| FAIL | `  FAIL  installation_id — 404 for installation <id> — it does not belong to App <id>, or the App is not installed yet (open the install URL and click Install)` | the installation does not exist under that App [scripts/github-app-token.py:393] | descriptive |
| FAIL | `  FAIL  token_mint — 201 answered without a token field` | a 2xx with no `token` [scripts/github-app-token.py:379] | evidentiary |
| FAIL | `  FAIL  permission:contents — granted 'read', need 'write' — clone and push commits; a push is a contents write. Raise it in App settings -> Permissions and accept the installation prompt` | the minted token lacks the permission [scripts/github-app-token.py:474] | evidentiary |
| PASS | `  PASS  permission:contents — write (need write — clone and push commits; a push is a contents write)` | granted as required [scripts/github-app-token.py:470] | evidentiary |
| PASS | `  PASS  app_slug — /apps/<slug> -> 200 (declared permissions: contents:write,metadata:read,pull_requests:write)` | slug resolved, permissions echoed [scripts/github-app-token.py:485] | evidentiary |
| FAIL | `  FAIL  app_slug — /apps/<slug> -> 404 (no public App with that slug)` | slug typo or private-only App [scripts/github-app-token.py:501] | descriptive |
| PASS | `  PASS  installation_covers — installation grants <owner>/<name> (of <n> repositories)` | target is in the installation's list [scripts/github-app-token.py:523] | evidentiary |
| FAIL | `  FAIL  installation_covers — installation does not cover <owner>/<name> (it covers: <list>) — add the repo on the App's installation settings page` | the list is printed, so the fix is named [scripts/github-app-token.py:528] | descriptive |
| PASS | `  PASS  repo_read — GET /repos/<owner>/<name> with a fresh token -> 200` | **the only row that proves the credential works** [scripts/github-app-token.py:545] | evidentiary |
| FAIL | `  FAIL  repo_read — GET /repos/<owner>/<name> -> 404 — Not Found` | any non-200/non-401/403, message passed through [scripts/github-app-token.py:557] | evidentiary |
| info | `GITHUB APP: PASS — every piece measured, a fresh token reads coding-hermes/code-factory -> 200` | the child's verdict; printed even when no read ran (arm 9) [scripts/github-app-token.py:566] | evidentiary |
| info | `GITHUB APP: FAIL (1) — nothing was minted; every piece above must be created before a token can exist` | an input problem stopped the run before the key was read [scripts/github-app-token.py:431] | evidentiary |
| info | `GITHUB APP: FAIL (1) — no token was minted` | the mint itself failed [scripts/github-app-token.py:455] | evidentiary |
| FAIL | `  FAIL  env_file — <path> is unreadable as KEY=VALUE data (line is not KEY=VALUE: '<text>')` | malformed pointer file, refused as data [scripts/github-app-token.py:292] | evidentiary |

No level, logger, timestamp or destination exists: everything above is stdout, with two consequences worth naming. First, **the parent and the child write into the same stream** — `  PASS  env_file` from the setup script and `  FAIL  env_file` from the minter appear in one run with the same piece name and opposite verdicts (arm 16). Second, the piece name `env_file` is reused for three questions across the two paths: present-and-600 on check [scripts/github-app-setup.sh:181], written-and-600 on apply [scripts/github-app-setup.sh:273], and parseable-as-data inside the minter [scripts/github-app-token.py:292].

## 6. Failure modes

Direction is the module's measured behaviour. `fail closed` = non-zero exit and no success line; `fail open` = a weaker state reported as acceptable; `degraded` = the run continues with a missing or misleading row.

| Failure | Presents as | Direction | Distinguished from | Recovery |
|---|---|---|---|---|
| No pointer file at all | `  FAIL  env_file — … does not exist yet` then `GITHUB APP SETUP: FAIL (1) — no env file, nothing measured` [scripts/github-app-setup.sh:168] | **fail closed, and honest about scope**: zero API calls, and the verdict says nothing was measured | A file that exists but is malformed prints `PASS env_file` first and then the minter's parse refusal (arm 16) | `--apply` after the four browser steps |
| Pointer file at the wrong mode | `  FAIL  env_file — … is mode 644, expected 600` [scripts/github-app-setup.sh:183] | **fail closed on the module's verdict, degraded in the log**: the minter still runs, still prints `GITHUB APP: PASS`, and the run ends `SETUP: FAIL` (arm 3b) — one run, two verdicts, and a reader who greps for PASS finds one | A file at 600 with a bad key fails inside the minter instead [scripts/github-app-token.py:346] | `chmod 600 <file>`, re-run |
| Key missing, unparsable, encrypted, or <2048 bits | one `FAIL private_key_file` naming the reason; no token is requested [scripts/github-app-token.py:326] | **fail closed before any network call** — measured: arms 3 and 4 produced no request | A key that parses but does not match the App fails later at the mint with 401 [scripts/github-app-token.py:383] | move the downloaded `.pem` to the path in the file, `chmod 600` |
| App id and key disagree, or the clock is skewed | `  FAIL  token_mint — 401 — the JWT was rejected: …` [scripts/github-app-token.py:383] | **fail closed**; the row names both candidate causes and cannot tell them apart | A wrong installation id answers 404, not 401 [scripts/github-app-token.py:393] | re-check the App id; compare the host clock |
| Installation id belongs to another App / App not installed | `  FAIL  installation_id — 404 for installation …` [scripts/github-app-token.py:393] | **fail closed** | 401 is the key/id mismatch; 403 is a permission refusal [scripts/github-app-token.py:404] | open the install URL and install, then re-read the id from the URL |
| App lacks `contents:write` (or any required permission) | up to two FAILs under `permission:<name>`, one from the token and one from `/apps/<slug>` [scripts/github-app-token.py:474] [scripts/github-app-token.py:492] | **fail closed**, with the remedy in the row ("Raise it in App settings … accept the installation prompt") | A permission that is granted but not declared cannot happen: the token cannot exceed the App's set [scripts/github-app-setup.sh:112] | change the App's permission, then accept the pending installation prompt |
| Installation does not cover the target repo | `  FAIL  installation_covers — … (it covers: <list>)` [scripts/github-app-token.py:528] | **fail closed**, and the list makes the fix obvious | A repo that is covered but unreadable fails at `repo_read` [scripts/github-app-token.py:547] | add the repo on the installation settings page |
| Repo read fails | `  FAIL  repo_read — GET /repos/… -> 404 — Not Found` [scripts/github-app-token.py:557] | **fail closed** — this is the row the whole module exists to produce | A 401/403 here is reported as "cannot read: does not cover it, or contents is not granted", which is a permission story, not a missing-repo story | fix whichever of the two rows above is red first |
| **D-1** No `--repo` and no resolvable `git remote` | **FIXED (CF-319):** `FAIL repo_read — no repository named, so the read was not measured ...`, exit 1; the setup wrapper also fails rather than printing a repo-read PASS | **fail closed**: a pointer-file `GITHUB_APP_REPO` is now read back and measured; a truly absent target is named and refuses success | `tests/test_github_app_check.py` Arm C and the committed CF-319 transcript |
| **D-2** No refresh timer | `  WARN  refresh — no refresh timer on this host — a node will lose push rights 3600s after provisioning …` and then `SETUP: PASS`, exit 0 [scripts/github-app-setup.sh:201] | **fail open**: the credential is correct for 3600 s and then the node cannot push; the verdict does not change. Worse, the suggested remedy does not fix it: `github-app-refresh.sh --node … --server …` mints and installs one token [scripts/github-app-refresh.sh:5-7] and contains no timer or crontab code at all [scripts/github-app-refresh.sh:13-17], and the skill the row points at never mentions a timer [skills/code-factory-bunker/SKILL.md:1] | A planted `cf-github-app-refresh.timer` flips the same row to `PASS refresh` (arm 14) | write the timer unit by hand; the repo does not ship one |
| **D-3** `--apply` on a non-tty with a missing flag | `  FAIL  APP_ID — not a terminal and --APP_ID was not given — refusing to guess it` ×3, `FAIL — missing answers, nothing written` [scripts/github-app-setup.sh:217] | **fail closed and honest**, but **degraded as an interface**: `--yes` exists, sets `ASSUME_YES`, and is read nowhere [scripts/github-app-setup.sh:43] [scripts/github-app-setup.sh:90], so there is no non-interactive path that says "I accept"; the row's name is also doubled and upper-cased (`--APP_ID`), which reads like a different flag | A tty invocation prompts instead [scripts/github-app-setup.sh:219] | pass all five flags explicitly; `--yes` has no effect |
| **D-4** `-h`, or any usage error | help text ends with three lines of shell source: `set -uo pipefail`, `HERE="$(cd …)"`, `. "$HERE/lib.sh"` | **degraded — cosmetic**: `usage` prints lines 2-30 of the file [scripts/github-app-setup.sh:63] while the comment block ends at line 27 [scripts/github-app-setup.sh:27], so the range overshoots by three lines | The manifest output is unaffected [scripts/github-app-token.py:656] | read the file's header instead; the range is a one-number fix |
| **D-5** Any verdict that quotes a count | `GITHUB APP SETUP: FAIL (1)` for a run with one row, and `FAIL` with no number for runs with two [scripts/github-app-setup.sh:176] [scripts/github-app-setup.sh:208] | **degraded**: the number is a literal, not a tally; `lib.sh`'s `FAILED` is incremented and never read [scripts/lib.sh:7] | The child's counts (`GITHUB APP: FAIL (2)`) are real, and are a *different* population — they count only its own rows (arm 2) | count the `  FAIL  ` rows yourself |
| **D-6** Two processes, one piece name | `  PASS  env_file` followed by `  FAIL  env_file` in one run (arm 16); `permission:contents` twice in arm 8 | **degraded — diagnostic ambiguity**: a grep by piece name returns contradictory verdicts, and a log parser that keeps the last one is wrong half the time | The detail text always differs, so a human can tell them apart; a script cannot | match on the detail, or fix the names |
| Malformed pointer file | `  FAIL  env_file — … is unreadable as KEY=VALUE data (line is not KEY=VALUE: '…')` [scripts/github-app-token.py:292] | **fail closed**: the file is parsed as data and never sourced [scripts/github-app-token.py:89] | A file that is merely chmod-wrong still parses | fix the line; the reader names it, quoted, truncated to 40 characters |
| `--apply` verifies unsuccessfully | `GITHUB APP SETUP: INCOMPLETE — the env file was written but verification FAILED;` plus the browser steps again, exit 1 [scripts/github-app-setup.sh:288] | **fail closed on the claim, open on the record**: the pointer file is deliberately left in place to be repaired and re-checked [scripts/github-app-setup.sh:256-258]. This is the *opposite* of the repo's recurring defect — it records first and refuses to say READY, and only `--check` can ever print a passing line | A missing answer or a bad key never reaches the write at all [scripts/github-app-setup.sh:239] [scripts/github-app-setup.sh:248] | fix the named rows and re-run `--check`; no rewrite needed |
| `python3` or the minter absent | `  FAIL  python3 — …` / `  FAIL  minter — …` then exit 1 [scripts/github-app-setup.sh:98] [scripts/github-app-setup.sh:100] | **fail closed before any mode runs** — including before `--manifest`, which also needs the minter [scripts/github-app-setup.sh:152] | A `lib.sh`-less copy fails with a shell error instead of a row, one line earlier [scripts/github-app-setup.sh:30] | install python3, restage the script with its sibling |

## 7. Environment and settings it reads

| Setting | Where read | Default | Effect of missing |
|---|---|---|---|
| `GITHUB_APP_ENV_FILE` | `ENV_FILE="${GITHUB_APP_ENV_FILE:-…}"` [scripts/github-app-setup.sh:32] | `$HOME/.config/code-factory/github-app.env` | the default path is written and checked; the same variable is honoured by both consumers [scripts/github-app-token.py:110] [scripts/github-app-refresh.sh:24] |
| `GITHUB_APP_TOKEN_FILE` | `TOKEN_FILE="${GITHUB_APP_TOKEN_FILE:-…}"` [scripts/github-app-setup.sh:33] | `$HOME/.config/code-factory/github.token` | the default path is recorded as a pointer and never verified — no row tests it [scripts/github-app-setup.sh:270] |
| `GITHUB_API_BASE` | `API_BASE="${GITHUB_API_BASE:-https://api.github.com}"` [scripts/github-app-setup.sh:41] | `https://api.github.com` | always passed to the child as `--api-base` [scripts/github-app-setup.sh:157]; the child reads the same variable itself [scripts/github-app-token.py:115] |
| `--api-base` | argv [scripts/github-app-setup.sh:89] | inherits the variable above | the only way to point a run at a stub; used by every arm in §3 |
| `GITHUB_APP_REPO` (**environment**) | the child's `--repo` default [scripts/github-app-token.py:708] | empty | exported, it supplies the repo for `--check` and re-enables the read rows (arm 10); the setup script never sets or exports it, and the pointer file's key of the same name is inert (D-1) |
| Mode | argv `--check` \| `--apply` \| `--manifest` [scripts/github-app-setup.sh:78] | none — `[ -n "$MODE" ] \|\| usage 2` [scripts/github-app-setup.sh:95] | no mode prints usage and exits 2; there is no default mode, so a bare invocation cannot silently check |
| `--env-file`, `--token-file`, `--key-file` | argv, `~` expanded by `expand_tilde` [scripts/github-app-setup.sh:65] | see the two variables above; key defaults to `$HOME/.config/code-factory/github-app.private-key.pem` [scripts/github-app-setup.sh:118] | the default path is used; `--apply` asks when neither is given [scripts/github-app-setup.sh:236] |
| `--app-id`, `--installation-id`, `--slug`, `--repo`, `--org`, `--name` | argv [scripts/github-app-setup.sh:82] | `NAME=code-factory` [scripts/github-app-setup.sh:40]; repo falls back to `git remote get-url origin` [scripts/github-app-setup.sh:102] | `--apply` prompts for the first five; `--check` without `--repo` loses the read-back (D-1); `--org` only changes which URLs the browser steps print |
| `--repo` normalisation | `norm_repo` strips `https://github.com/`, a trailing `.git`, and `git@github.com:` [scripts/github-app-setup.sh:66] | — | a URL form is accepted, measured in arm 6 (`--repo https://github.com/coding-hermes/code-factory.git` printed `reads coding-hermes/code-factory`) |
| `--yes` | parsed into `ASSUME_YES=1` [scripts/github-app-setup.sh:90] | `0` [scripts/github-app-setup.sh:43] | **no effect anywhere** — the variable has no reader (D-3) |
| `$HOME` | every path above derives from it [scripts/github-app-setup.sh:32] [scripts/github-app-setup.sh:118] [scripts/github-app-setup.sh:197] | the invoking user's home | an isolated `HOME` moves the pointer file, the key default and the timer test together, which is what made the arms in §3 hermetic |
| `PATH` | `command -v python3` [scripts/github-app-setup.sh:97]; `git` [scripts/github-app-setup.sh:72]; `stat` [scripts/github-app-setup.sh:179]; `crontab` [scripts/github-app-setup.sh:198] | inherited | no python3 → one FAIL and exit 1 (arm 17); no git → no default repo, hence D-1's hollow PASS, and no row says so |
| Refresh detection paths | `$HOME/.config/systemd/user/cf-github-app-refresh.timer` or `crontab -l \| grep github-app-refresh` [scripts/github-app-setup.sh:197] | neither exists on a fresh host | `WARN refresh`; the verdict is unchanged (D-2) |
| No config file of its own | — | — | the module reads no `config/` file, no `.env`, and no board; everything comes from argv, three environment variables and `$HOME` |

## 8. Evidence of record

- **Measured 2026-11-05** in the worktree `~/proj-wt-md-28e` at `dad2749`, Linux 7.0.0-38-generic, `python3` 3.14.4, OpenSSL 3.5.5. Every transcript in §3 is literal terminal output; the `HOME` in each arm is a scratch directory under `~/.hermes/cache/scratch/md32/probe13/`. No App was created, no request left the host: the API peer was a 90-line local stub answering the four endpoints of §2c, and its request log — quoted in Transcripts 2 and 3 — is the instrumentation that makes "did it read the repo?" answerable rather than assumed.
- **What the runs establish**: the module is real and fails closed on every missing hand-made piece; the success path genuinely mints a token and reads the repo with it, in that order; the read is the *last* row and the only one that proves the credential; nothing secret is printed (0 occurrences of the stub's token in any captured stdout); the pointer file is written atomically at 600, is re-read cleanly by both consumers, and is idempotent under a second `--apply`; the module refuses non-tty guessing, refuses a 644 key rather than chmod-ing someone else's file, and leaves the pointer file in place without a success claim when verification fails.
- **What these runs do not establish**: no arm reached `api.github.com`, so the 401 and 403 mint branches [scripts/github-app-token.py:383] [scripts/github-app-token.py:404], the "installation does not cover this repo" branch [scripts/github-app-token.py:526], and the `app_slug` 404 branch [scripts/github-app-token.py:499] are source-read only. The crontab half of the refresh test [scripts/github-app-setup.sh:198] was not exercised; the systemd half was, by planting the file. A real GitHub App's key was never used, because creating one is out of scope for a documentation run and the task forbade it.
- **Automated coverage that exists: none.** `tests/selftest.sh` (3657 lines) contains no reference to `github-app-setup`, `github-app-token`, or `GITHUB_APP` — the string does not occur anywhere under `tests/`, and the repository has no `.github/workflows` directory at all. This is a rule violation as well as a gap: the repo requires that `tests/selftest.sh` contain a fixture proving a check's failure path [AGENTS.md:28], and the entire App credential path has no fixture for either outcome. What §3 provides is a reproducible manual battery, not a gate; a row that closes on it depends on a human re-running it [docs/master/_facts.md:21] (fact: FACT-10).
- **The one claim that cost the most to make**: "the PASS line can be printed without a read" is not an inference from source. It was produced by staging the three scripts outside any git repository, writing a pointer file whose `GITHUB_APP_REPO` key named the repo, and watching the run exit 0 with the sentence `reads the target repo` while the stub logged two requests, neither of them a read (Transcript 3).

Defects found while filling this section (documented, **not** fixed — `scripts/` is out of scope for this task):

1. **D-1 — `--check` can certify a credential it never used, because the repo it validates against is only ever supplied out of band.** `--apply` records `GITHUB_APP_REPO` [scripts/github-app-setup.sh:268], and nothing reads that key: the minter's repo argument defaults to the *environment* variable of the same name [scripts/github-app-token.py:708] and the setup script neither exports it nor passes `--repo` unless the operator did [scripts/github-app-setup.sh:158]. The coverage and read rows are both guarded by `if args.repo:` [scripts/github-app-token.py:504] [scripts/github-app-token.py:539], so outside a git checkout with no `--repo` the run prints `GITHUB APP SETUP: PASS — … reads the target repo` after two requests (mint + unauthenticated `/apps/<slug>`). Measured, Transcript 3. Severity: the sentence is false, and it is the sentence an operator quotes when closing a provisioning row — the exact failure AGENTS.md rule 3 exists to prevent [AGENTS.md:31]. Smallest fix consistent with the file's own design: have `--check` pass `--repo` from the env file's `GITHUB_APP_REPO` when the argument is absent, or refuse to print PASS without a `repo_read` row.
2. **D-2 — the refresh row is a WARN, so a credential that stops working in one hour passes.** `PASS`/`FAIL` depends only on `rc`, which the refresh branch never touches [scripts/github-app-setup.sh:197-210]; measured: exit 0 with the WARN (arm 14). The row's remedy is also wrong: it names `github-app-refresh.sh --node <agent> --server <host>`, which mints and installs one token [scripts/github-app-refresh.sh:5-7], while the condition being warned about is the absence of a *timer*; the refresh script contains no timer or crontab code [scripts/github-app-refresh.sh:13-17] and the skill it points at (`skills/code-factory-bunker/SKILL.md`, 323 lines) contains no occurrence of "timer", "systemd" or "github-app" at all. An operator who follows the advice exactly will see the same WARN on the next run.
3. **D-3 — `--yes` is a parsed flag with no reader.** `ASSUME_YES=1` is set [scripts/github-app-setup.sh:90] and never consulted; `ask()` refuses on any non-tty regardless [scripts/github-app-setup.sh:216]. Consequence: there is no way to pre-consent, so an unattended provisioning step that reaches `--apply` without all five flags fails with three rows whose names are mangled (`--APP_ID`, `--INSTALLATION_ID`, `--KEY_FILE`) and look like different flags than the ones in the usage block.
4. **D-4 — `usage()` prints three lines of shell source.** The range is `sed -n '2,30p'` [scripts/github-app-setup.sh:63] while the comment block ends at line 27; measured output ends with `set -uo pipefail`, `HERE="$(cd "$(dirname "$0")" && pwd)"`, `. "$HERE/lib.sh"`. Cosmetic, but it is the first thing a new operator sees, and it makes `-h` output a partial source dump.
5. **D-5 — the verdict's count is a literal, not a tally.** `FAIL (1)` is hard-coded in the no-config arm [scripts/github-app-setup.sh:176]; every other failing arm prints `GITHUB APP SETUP: FAIL` with no number [scripts/github-app-setup.sh:208]; and the child's counts count a different population (arm 2 printed two parent FAIL rows above `GITHUB APP: FAIL (1)`). `lib.sh` already maintains the right number and this module never reads it [scripts/lib.sh:7].
6. **D-6 — piece names are not unique within a run.** `env_file` is emitted by the setup script (mode) and by the minter (parsability) in the same stream with opposite verdicts (arm 16); `permission:contents` appears twice when both the token and the App declaration are wrong (arm 8). A human reads the detail text; any log parser keyed on the piece name does not.
7. **D-7 — zero automated coverage on the first-install credential path.** No reference to `github-app-setup`, `github-app-token` or `GITHUB_APP` exists under `tests/`, and the repo has no `.github/workflows`. The rule that every check must have a fixture proving its failure path [AGENTS.md:28] is unmet for the module that decides whether a node can push at all.
