# 14. scripts/github-app-token.py

| Field | Value |
|---|---|
| Path | `~/code-factory/scripts/github-app-token.py` — 768 lines, four subcommands (`check`, `token`, `manifest`, `jwt`), standard library only [scripts/github-app-token.py:1] [scripts/github-app-token.py:699-734] |
| Repository | `code-factory` |
| Revision | `6eea792` — the `origin/main` tip every locator below was measured against (worktree `~/proj-wt-md-14f`, 2026-11-05); the file's own last-touching commit is `e693942` (2026-11-04, "feat(github): the App first-install path — an onboarding check that verifies, a 1h token minter, a refresh for long-lived nodes") |
| Status | **VERIFIED — 24 measured checks, every locator resolves; no live GitHub credential was minted: all API behaviour was measured against a local stub reached through `--api-base`; eleven defects recorded in §6, the first of which kills the invocation the module documents for itself** |

## 1. Purpose and why it matters

- What it is: the fleet's GitHub credential minter. Its charter is one line — `github-app-token.py — mint a GitHub App installation token, or refuse naming the missing piece.` [scripts/github-app-token.py:2] — and it does exactly those two things: it either prints a PASS for every hand-made piece of the App, or it names the piece that is wrong. There is no third outcome and no repair path: it never writes the env file, never changes a key's mode, never installs a permission [scripts/github-app-token.py:276-323] [scripts/github-app-token.py:326-359].
- **The credential chain it implements, and why each link is shaped the way it is:**
  - The **App private key** stays on the control host. It is read from a path named in the env file [scripts/github-app-token.py:328], must be mode 0600 exactly [scripts/github-app-token.py:346-351], is refused if passphrase-protected [scripts/github-app-token.py:160-163], and is refused below 2048 bits [scripts/github-app-token.py:196-199]. The refresh driver states the rule it serves — "the App PRIVATE KEY never leaves the control host. The node only ever holds a token that dies within the hour" [scripts/github-app-refresh.sh:8-11].
  - The **JWT** is RS256 over the standard library, signed here and nowhere else: header `{"alg":"RS256","typ":"JWT"}` [scripts/github-app-token.py:223], claims `iat = now − 60`, `exp = now + 540`, `iss` as a **string** app id [scripts/github-app-token.py:224]. Both JSON objects are serialised with `separators=(",",":")` so the signing input's bytes are exact [scripts/github-app-token.py:226-229], and both segments are unpadded base64url [scripts/github-app-token.py:203-204]. Signing is RSASSA-PKCS1-v1_5 with SHA-256: a hand-built DigestInfo prefix [scripts/github-app-token.py:212], EMSA-PKCS1 padding [scripts/github-app-token.py:216], and one `pow(em, d, n)` [scripts/github-app-token.py:217]. No `cryptography`, no `jwt`, no `curl | sh` — the docstring says so [scripts/github-app-token.py:6-7] and the import list confirms it [scripts/github-app-token.py:33-43].
  - The **10-minute ceiling is why 60 + 540**: GitHub rejects an App JWT whose `exp` is more than ten minutes out, so `JWT_LIFETIME = 540` and a 60-second backdate give a 600-second window of which ~9 minutes are always in the future [scripts/github-app-token.py:48-51]. The backdate is also the clock-skew absorber: `iat` only lands in the future once the local clock is more than 59 s fast, and at that point GitHub answers 401 and this program's message says `or the clock is off` [scripts/github-app-token.py:383-392].
  - The **installation token** is the only credential a node ever holds: one `POST` to `/app/installations/<id>/access_tokens` carrying the JWT [scripts/github-app-token.py:370-372], answered with `token`, `expires_at` and `permissions` [scripts/github-app-token.py:373-382]. Its life is one hour, asserted in two places in the tree [scripts/github-app-token.py:4] [scripts/github-app-refresh.sh:13] — GitHub's clock, not this program's, which is why `--if-older` exists [scripts/github-app-token.py:15-17].
- **The output channel, stated precisely, because it is the part a caller depends on:** `token` writes a **file** and prints a **summary**. The file is resolved in one order — `--out`, else `GITHUB_APP_TOKEN_FILE`, else `~/.config/code-factory/github.token` [scripts/github-app-token.py:578-580] [scripts/github-app-token.py:46]. It contains the token and a newline and nothing else, at mode 0600, written atomically: the temp file is opened with `0o600` before any byte is written, then `os.replace`d onto the destination and `chmod`ed again [scripts/github-app-token.py:636-653]. Stdout gets one row naming path, mode and `expires_at` — **never the value** [scripts/github-app-token.py:607-615] [scripts/github-app-token.py:616-619]. Measured: 40 bytes, one line, trailing newline, `mode 600`, and the file's content equals the stub's token exactly while no captured stdout or stderr contains it (§3 check 12). That is the project rule applied to a minted credential — "Credentials never travel as arguments and never appear in a log" [AGENTS.md:40] (fact: FACT-05).
- What breaks if this module is **absent**: both consumers fail closed by name before doing anything. The refresh driver refuses with `  FAIL  minter — <path> is missing` [scripts/github-app-refresh.sh:61], and the onboarding script refuses at startup [scripts/github-app-setup.sh:99-100]. Nothing else can mint, because the signing lives only here ("Verification lives in scripts/github-app-token.py so there is exactly one implementation of it" [scripts/github-app-setup.sh:25-27]). The consequence is not "no push today" but "no push one hour after any node was provisioned" [scripts/github-app-refresh.sh:2-3].
- What breaks if it **lies**: its PASS row is the only evidence in the fleet that a node's git credential works, and it is promoted verbatim into an onboarding verdict — `ok "verification" "every hand-made piece measured green by github-app-token.py"` [scripts/github-app-setup.sh:189-193]. A PASS that was not measured therefore becomes the claim that a node can push. CF-319 closes the former D-4 path: the summary is emitted only after a named repository read passes, while an absent target is a named FAIL.
- What it is **not**: no daemon, no timer, no scheduler, no state of its own. `--if-older` is an mtime test on the destination file, not a cache [scripts/github-app-token.py:582-590]. It never revokes anything — `api()` is called with `POST` once and `GET` three times and never with `DELETE` [scripts/github-app-token.py:371] [scripts/github-app-token.py:480] [scripts/github-app-token.py:506] [scripts/github-app-token.py:539], so each mint leaves a live credential to expire on GitHub's clock (D-3). It cannot repair the App; it can only name the piece a human must fix, which is the whole design.

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `python3` | measured here 3.14.4; the syntax needs nothing newer than 3.4 (`int.from_bytes`, `os.replace`, `Request(method=)`) [scripts/github-app-token.py:133] [scripts/github-app-token.py:217] [scripts/github-app-token.py:646] [scripts/github-app-token.py:250] | on `PATH` — the refresh driver resolves it with `command -v python3` and refuses by name if absent [scripts/github-app-refresh.sh:59-60]; the onboarding script does the same [scripts/github-app-setup.sh:97-98] | by the caller, as a named `FAIL python3`; the module cannot report its own interpreter missing |
| Python standard library: `argparse`, `base64`, `calendar`, `hashlib`, `json`, `os`, `stat`, `sys`, `time`, `urllib.error`, `urllib.request` [scripts/github-app-token.py:33-43] | the interpreter's own | in the interpreter | import failure at startup; nothing checks it before use |
| Network egress to `https://api.github.com` on 443, one TCP connection per API call, 20 s timeout each [scripts/github-app-token.py:47] [scripts/github-app-token.py:52] | — | reachable from the host that runs the minter | **partially**: an unreachable base is reported as `  FAIL  token_mint — 0 — no answer` because `URLError`/`OSError` is mapped to status 0 [scripts/github-app-token.py:257-258] [scripts/github-app-token.py:410-414], measured (§3 check 9) |
| A readable env file at mode-agnostic permissions [scripts/github-app-token.py:279-293] | — | `~/.config/code-factory/github-app.env` by default [scripts/github-app-token.py:45] | `FAIL env_file — <path> is absent — run scripts/github-app-setup.sh --apply once the App exists` [scripts/github-app-token.py:280-287] |
| An RSA private key file at **exactly** 0600, unencrypted, ≥2048 bits [scripts/github-app-token.py:346-351] [scripts/github-app-token.py:160-163] [scripts/github-app-token.py:196-199] | — | anywhere; named by `GITHUB_APP_PRIVATE_KEY_FILE` [scripts/github-app-token.py:328] | four distinct `FAIL private_key_file` sentences, each measured (§3 checks 5-6) |
| A writable destination directory for the token [scripts/github-app-token.py:639-646] | — | the parent of `--out`; created with `makedirs` if missing | **not detected**: an uncreatable parent raises an uncaught `FileNotFoundError` and prints a traceback instead of a named FAIL (§3 check 14, D-5) |
| No third-party package, no database, no container, no shell-out | — | — | Verified by reading the whole file: the imports are the eleven standard-library modules above and there is no `subprocess`, no `socket`, no `ctypes`, no `requests` [scripts/github-app-token.py:33-43] |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `argparse` subparsers, `dest="cmd"` [scripts/github-app-token.py:700-701] | stdlib | an unknown subcommand is rejected by argparse itself with `invalid choice`, exit 2 — so the `usage_error` branch is never reached (§3 check 17, D-7) | the back-compat shim in `main` splices a subcommand name into `argv` before parsing [scripts/github-app-token.py:736-746]; it prepends `check`/`token`/`manifest`/`jwt` but does **not** remove the flag it was triggered by, so `--check` and `--manifest` become unrecognised arguments (D-1) |
| `base64.urlsafe_b64encode(...).rstrip(b"=")` [scripts/github-app-token.py:203-204] | stdlib | JWT segments are base64url **without** padding; the alphabet swap is what makes a signature containing `+` or `/` survive as a path-safe token | a padded segment is legal base64 but not legal JWT, so every mint would 401 — nothing in the tree asserts the segment alphabet |
| `hashlib.sha256` plus a literal DigestInfo prefix [scripts/github-app-token.py:210-212] | stdlib + RFC 8017 §9.2 | the 19-byte prefix `3031300d060960864801650304020105000420` is SHA-256's DER `DigestInfo` header, and the padding length is computed from `k = (n.bit_length()+7)//8` [scripts/github-app-token.py:213-216] | a wrong prefix still produces a syntactically valid signature that GitHub rejects as 401, i.e. the failure would be indistinguishable from a bad key (D-8's message problem). Measured correct: the 2048-bit signature verifies against the key's public exponent (§3 check 11) |
| `json.dumps(..., separators=(",", ":"))` [scripts/github-app-token.py:226-228] | stdlib | compact, insertion-ordered output — `header` and `claims` are two-key/three-key dicts, so the bytes are deterministic | if a claim were added the signing input would change with it but stay valid; nothing re-serialises either object downstream, so the only effect is a different JWT |
| `calendar.timegm(time.strptime(exp, "%Y-%m-%dT%H:%M:%SZ"))` [scripts/github-app-token.py:629] | stdlib | `expires_at` is parsed as **naive UTC** and converted with `timegm`, never `mktime`, so the printed TTL is right in any `TZ` | `_ttl` catches `ValueError` only [scripts/github-app-token.py:631]; a non-string `expires_at` raises `TypeError` through the PASS printer *after* the token was written (D-6, §3 check 16) |
| `os.open(tmp, O_WRONLY|O_CREAT|O_TRUNC, 0o600)` then `os.replace` then `os.chmod` [scripts/github-app-token.py:642-653] | stdlib | the destination is never world-readable, not even for the write; `replace` is atomic within a filesystem; `replace` also unlinks a symlink rather than following it | measured: umask 022 still yields 0600; a pre-existing 0644 file becomes 0600; a symlinked destination is replaced by a regular file and the link's target is untouched (§3 check 13) |
| `stat.S_IMODE(os.stat(path).st_mode)` [scripts/github-app-token.py:343] | stdlib | compares the permission bits only, against `0o600` **exactly** | a stricter `0400` key is refused with `is mode 0400; a private key must be 0600` (D-9, §3 check 5) — the check enforces a literal mode, not a policy |
| `urllib.error.HTTPError` vs `(URLError, OSError)` [scripts/github-app-token.py:255-258] | stdlib | an HTTP status yields `(code, parsed_body)`; a transport failure yields `(0, None)`, and `0` is a value the caller must treat as a failure | `0` is not distinguishable from a real status by type, so it lands in the generic branch and prints `0 — no answer` [scripts/github-app-token.py:410-414]; DNS failure and connection-refused produce the same row (§3 check 9) |
| `urllib.request.Request(..., method=method)` [scripts/github-app-token.py:250] | stdlib | `POST` with `data=None` sends no body and no `Content-Type`; the mint endpoint accepts that | measured: the stub saw no `Content-Type` and no body on the mint (§3 transcript 10) |

### 2c. Service contracts (both sides named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| GitHub REST, `POST /app/installations/{id}/access_tokens` | minter → GitHub | HTTPS, `Bearer <JWT>`, `Accept: application/vnd.github+json`, `X-GitHub-Api-Version: 2022-11-28`, `User-Agent: code-factory-github-app` [scripts/github-app-token.py:238-250] | no request body; response `201` (also accepts `200`) with `token`, `expires_at`, `permissions` [scripts/github-app-token.py:373-382] | GitHub's App-authentication endpoint; the only remote side this program cannot inspect. Status semantics are hard-coded: `401` key/clock, `404` installation-not-ours, `403` forbidden/suspended [scripts/github-app-token.py:383-409] |
| GitHub REST, `GET /installation/repositories?per_page=100` | minter → GitHub, **as the installation** | HTTPS, `Bearer <installation token>` | response `repositories[].full_name`; the minter compares `OWNER/NAME` against that list [scripts/github-app-token.py:506-537] | used only under `--repo`; the token is the one just minted, so this call also proves the mint was usable |
| GitHub REST, `GET /repos/{owner}/{name}` | minter → GitHub, as the installation | HTTPS, `Bearer <installation token>` | status only: `200` PASS, `401`/`403` named failure, anything else reported raw [scripts/github-app-token.py:539-559] | this is the read that makes the PASS sentence true, and the only call that proves the permission set is sufficient in practice |
| GitHub REST, `GET /apps/{slug}` | minter → GitHub, **unauthenticated** | HTTPS, no `Authorization` header [scripts/github-app-token.py:480] | response `permissions` map, compared against `contents: write` [scripts/github-app-token.py:482-497] | measured: this is the one request that carries no credential at all (§3 check 11) — it reads the App's *declared* permissions, which is what distinguishes "the token was narrowed" from "the App was declared wrong" |
| `scripts/github-app-refresh.sh` | driver → minter | `execve` of `python3 <minter> token --env-file F --if-older N [--api-base U] --out D`, stdout+stderr captured into one buffer [scripts/github-app-refresh.sh:67-68] [scripts/github-app-refresh.sh:85] | argv as above; the written file is the hand-off | the driver classifies the run by **substring**: `case "$out" in *"GITHUB APP TOKEN: SKIP"*)` [scripts/github-app-refresh.sh:86-87], so the literal `GITHUB APP TOKEN: SKIP` line is a contract, not decoration |
| `scripts/github-app-setup.sh` | onboarding → minter | `execve` of `python3 <minter> check --env-file F --api-base U [--repo R] [--slug S]` [scripts/github-app-setup.sh:156-161] | argv as above; exit status becomes the onboarding verdict | `run_minter_check` is the only proof in `--check` mode that the hand-made pieces work [scripts/github-app-setup.sh:189-193] |
| This document's stub | measurement only | HTTPS replaced by `http://127.0.0.1:18771` through `--api-base` [scripts/github-app-token.py:113-118] | a JSONL request log recording method, path and the `Authorization` header | the flag exists for exactly this ("tests point this at a local server" [scripts/github-app-token.py:116-117]); it is how §3 measured every status branch without holding a real credential |

## 3. Verification

Measured 2026-11-05 from a clean worktree of `6eea792` (`~/proj-wt-md-14f`), Linux x86_64, Python 3.14.4, against a local stub on `127.0.0.1:18771` reached with `--api-base`. **No request left the host and no real GitHub credential exists**: the App id, installation id and key are all scratch values, the key is an RSA-2048 generated for this document, and the token in every transcript is the stub's literal `ghs_SCRATCHFAKE…`.

| # | Check | Command | Expected | Last run | Result |
|---|---|---|---|---|---|
| 1 | The declared surface | `python3 scripts/github-app-token.py` (bare) [scripts/github-app-token.py:749-751] | four subcommands and exit 2 | 2026-11-05 | **as specified** — `{check,token,manifest,jwt}` and `EXIT=2` (transcript 1) |
| 2 | A host with nothing configured is refused by name | `check --env-file <absent> --api-base <stub>` [scripts/github-app-token.py:279-287] | one `FAIL env_file`, exit 1, nothing minted | 2026-11-05 | **as specified** — the FAIL names the setup script to run and the reason it cannot be automated (transcript 2) |
| 3 | Each missing or malformed pointer is its own named row | `check` with app id unset / installation id unset / both non-numeric / a non-KEY=VALUE line [scripts/github-app-token.py:295-322] [scripts/github-app-token.py:88-104] | one FAIL per piece, all pieces named in one run | 2026-11-05 | **as specified** — `FAIL (1)`, `FAIL (1)`, `FAIL (2)`, and `line is not KEY=VALUE: 'this line is not key value'`; the non-numeric values are echoed truncated to 20 chars (transcript 3) |
| 4 | Quoted values in the env file are parsed as data | `check` on a file whose three values are single- and double-quoted [scripts/github-app-token.py:101-103] | identical rows to the unquoted file | 2026-11-05 | **as specified** — the same five rows in the same order as the unquoted fixture, differing only in the key path the two fixtures name, `EXIT=0` |
| 5 | Every key-file defect has a distinct sentence | key unset, key absent, key at 0644, key at 0400, not-PEM, passphrase-protected, 1024-bit [scripts/github-app-token.py:328-359] [scripts/github-app-token.py:160-163] [scripts/github-app-token.py:196-199] | seven different FAILs, no mint attempted | 2026-11-05 | **as specified**, with one policy finding: `0400` is refused because the test is `mode != 0o600` (D-9). No network call was made in any of the seven (transcript 4) |
| 6 | Both PEM encodings parse | `check` on a PKCS#1 key (`BEGIN RSA PRIVATE KEY`) and a PKCS#8 key (`BEGIN PRIVATE KEY`, what OpenSSL 3 writes) [scripts/github-app-token.py:179-191] | `parses as RSA 2048-bit` for both, same public numbers | 2026-11-05 | **as specified** — both keys sign and both verify; the PKCS#8 unwrap path is exercised, not assumed (transcript 5) |
| 7 | The happy path measures all eight pieces | `check --repo coding-hermes/code-factory --slug good-app` [scripts/github-app-token.py:417-567] | eight PASS rows, exit 0 | 2026-11-05 | **as specified** — key, mint, three permissions, slug, coverage, repo read (transcript 6) |
| 8 | Every mint status branch is named | installation ids routed by the stub to `401`, `404`, `403`, `201`-without-token, `200`-with-token [scripts/github-app-token.py:373-414] | one named FAIL each, and the 200 arm accepted | 2026-11-05 | **as specified** — four distinct sentences plus a PASS on `200`; the 401 sentence names two causes and cannot separate them (transcript 7) |
| 9 | A dead endpoint fails closed with a status | `--api-base http://127.0.0.1:18772` (closed port) and `http://no-such-host.invalid` [scripts/github-app-token.py:257-258] | `FAIL token_mint — 0 — no answer`, exit 1 | 2026-11-05 | **as specified** — both arms identical, so "connection refused" and "DNS does not resolve" are one row (transcript 8) |
| 10 | The PASS summary names the measured repository read | `check` with `--repo` or a pointer-file `GITHUB_APP_REPO` [scripts/github-app-token.py:504-575] | `repo_read` and a summary naming the repo and status | 2026-11-13 | **FIXED — CF-319 Arms A/B show 403 fails and 200 passes; the no-repo arm emits `FAIL repo_read` and exits 1** |
| 11 | What the JWT actually contains, and that the signature is real | a captured mint request from the stub's log, decoded segment 1 and 2, signature verified with the key's public exponent only [scripts/github-app-token.py:221-231] | `alg RS256`, `typ JWT`, `iss` a string, `exp − iat = 600`, three segments, signature verifies | 2026-11-05 | **as specified** — `EM verifies = True`; the fixed-instant call gives `{"exp": 1700000540, "iat": 1699999940, "iss": "999"}` exactly. The signature itself was never printed (transcript 10) |
| 12 | The output channel: file, mode, shape, and no leak | `token --out <path>` under `umask 022`, then `stat`, then `wc -l`, then a grep of every captured stdout/stderr for the token value [scripts/github-app-token.py:606-619] [scripts/github-app-token.py:636-653] | mode 600 despite umask, one line, value present in the file, value absent from all output | 2026-11-05 | **as specified** — `mode 600  size 40`, `lines=1 trailing_newline=True value_matches_stub=1`, and the leak scan over 42 captured files found zero occurrences (transcript 11) |
| 13 | Write mechanics: over an old file, over a symlink, and on failure | `write_private` called directly [scripts/github-app-token.py:636-653] | 0644 becomes 0600; a symlink is replaced and its target untouched; a failed write leaves no temp | 2026-11-05 | **as specified** — `mode after = 0o600`, `is symlink = False`, `outside = original (unchanged)`, `leftovers = ['token']` (the directory that caused the failure) (transcript 12) |
| 14 | The destination's parent cannot be created | `token --out /proc/self/nope/token` [scripts/github-app-token.py:639-640] | a named FAIL and exit 1 | 2026-11-05 | **BROKEN — defect D-5**: a raw `FileNotFoundError` traceback and exit 1, after the token was minted and thrown away (transcript 13) |
| 15 | `--if-older` skips, and `0` disables it | `token --if-older 2400` twice, then `--if-older 0` [scripts/github-app-token.py:582-590] | `SKIP` with the age, then a fresh mint | 2026-11-05 | **as specified** — `is 0s old (< 2400s), still valid` then `GITHUB APP TOKEN: SKIP — nothing to do`, exit 0; `--if-older 0` writes (transcript 14) |
| 16 | `_ttl`'s fallbacks | library call with a malformed, an absent and a non-string `expires_at` [scripts/github-app-token.py:623-633] | 3600 for the first two | 2026-11-05 | **partly broken — defect D-6**: `malformed = 3600`, `absent = 3600`, but `bad type = TypeError`, which escapes `cmd_out` *after* the file was written |
| 17 | Usage surface: `--check`, `--manifest`, `--help`, unknown command, bad int | the four documented spellings and two argument errors [scripts/github-app-token.py:736-746] | the documented spellings work | 2026-11-05 | **BROKEN — defects D-1 and D-10**: `--check` and `--manifest` both exit 2 with `unrecognized arguments`; `--help` prints the *check* subparser's help only; `bogus` gives argparse's `invalid choice` (transcript 15) |
| 18 | The env-file parser's real grammar | library call on `export K=V`, unbalanced quotes, `K=a=b`, comments [scripts/github-app-token.py:88-104] | `export`-prefixed lines refused or understood | 2026-11-05 | **BROKEN — defect D-2**: `export A=1` parses to the key `export A`, so a shell-style env file yields `GITHUB_APP_ID is unset`; unbalanced quotes keep the leading quote (transcripts 16 and 3) |
| 19 | Defaults resolve through `$HOME` | `env HOME=<scratch> token` with no `--out` and no `GITHUB_APP_TOKEN_FILE` [scripts/github-app-token.py:578-580] [scripts/github-app-token.py:45-46] | writes `<HOME>/.config/code-factory/github.token` at 600 | 2026-11-05 | **as specified** — the row names `fakehome/.config/code-factory/github.token`, and `find` shows both files at `600` (transcript 17) |
| 20 | Env vars supply the same values as flags | `GITHUB_APP_ENV_FILE`, `GITHUB_API_BASE`, `GITHUB_APP_REPO` set in the environment [scripts/github-app-token.py:110] [scripts/github-app-token.py:115] [scripts/github-app-token.py:708] | same rows as the flag form | 2026-11-05 | **as specified** — the `GITHUB_APP_REPO` run produced the coverage and repo-read rows without `--repo` |
| 21 | The manifest subcommand emits a pastable manifest | `manifest` [scripts/github-app-token.py:656-673] | JSON with the three default permissions | 2026-11-05 | **as specified** — `contents: write`, `pull_requests: write`, `metadata: read`, `hook_attributes.active = false` (transcript 18) |
| 22 | The selftest aid prints claims, never the JWT | `jwt` and `jwt --jwt-out <path>` [scripts/github-app-token.py:676-696] | one JSON line with `claims`, `segments`, `length`; a 600-mode file if asked | 2026-11-05 | **as specified** — `{"claims": {"exp": …, "iat": …, "iss": "123456"}, "length": 447, "segments": 3}`; the optional file is `mode 600 size 448` (transcript 19) |
| 23 | Nothing in the repository's gate touches this file | `tests/test_github_app_check.py` through `tests/selftest.sh` | at least one leg | 2026-11-13 | **FIXED — CF-319's three local-stub arms run from the selftest and write the audit transcript** |
| 24 | This document's own gate | `python3 scripts/master_doc_check.py docs/master --only 14- --strict` | `MASTER-DOC: PASS` | 2026-11-05 | **PASS** — `1 module(s): 1 VERIFIED, 0 error(s), 0 warning(s), 10 fact(s) in the ledger`, exit 0 (transcript 20) |

Transcript 1 — check 1, the bare invocation:

```
$ python3 scripts/github-app-token.py; echo "EXIT=$?"
usage: github-app-token.py [-h] {check,token,manifest,jwt} ...

github-app-token.py — mint a GitHub App installation token, or refuse naming
the missing piece.

positional arguments:
  {check,token,manifest,jwt}
    check               verify every hand-made piece; write nothing
    token               mint and write the token at mode 600
    manifest            print the App manifest JSON
    jwt                 print JWT CLAIMS only (selftest aid)

options:
  -h, --help            show this help message and exit
EXIT=2
```

Transcript 2 — check 2, a host with no env file:

```
$ python3 scripts/github-app-token.py check --env-file …/env/nosuch.env --api-base http://127.0.0.1:18771; echo "EXIT=$?"
  FAIL  env_file — ~/.hermes/cache/scratch/md14f/env/nosuch.env is absent — run scripts/github-app-setup.sh --apply once the App exists (creating it is a browser step a human must do)

GITHUB APP: FAIL (1) — nothing was minted; every piece above must be created before a token can exist
EXIT=1
```

Transcript 3 — check 3, the pointer defects, and check 18's end-to-end arm:

```
$ … check --env-file …/noappid.env
  FAIL  app_id — GITHUB_APP_ID is unset — copy the App id from the App's settings page (App settings -> About -> App ID)

GITHUB APP: FAIL (1) — nothing was minted; every piece above must be created before a token can exist
EXIT=1
$ … check --env-file …/nonnum.env
  FAIL  app_id — GITHUB_APP_ID='abc123' is not numeric
  FAIL  installation_id — GITHUB_APP_INSTALLATION_ID='xyz-9' is not numeric

GITHUB APP: FAIL (2) — nothing was minted; every piece above must be created before a token can exist
EXIT=1
$ … check --env-file …/badline.env
  FAIL  env_file — …/badline.env is unreadable as KEY=VALUE data (line is not KEY=VALUE: 'this line is not key value')

GITHUB APP: FAIL (1) — nothing was minted; every piece above must be created before a token can exist
EXIT=1
$ … check --env-file …/export.env      # the shape many people would write by hand
  FAIL  app_id — GITHUB_APP_ID is unset — copy the App id from the App's settings page (App settings -> About -> App ID)
  FAIL  installation_id — GITHUB_APP_INSTALLATION_ID is unset — the id in the URL after installing the App on the org (Settings -> Installations -> Configure)

GITHUB APP: FAIL (2) — nothing was minted; every piece above must be created before a token can exist
EXIT=1
```

Transcript 4 — check 5, seven key-file refusals (each one a different sentence):

```
  FAIL  private_key_file — GITHUB_APP_PRIVATE_KEY_FILE is unset — download the .pem from the App's settings page (Private keys -> Generate a private key); the download is the only copy GitHub will ever offer
  FAIL  private_key_file — …/nosuch.pem does not exist — move the downloaded .pem there
  FAIL  private_key_file — …/key644.pem is mode 0644; a private key must be 0600 (chmod 600 …/key644.pem)
  FAIL  private_key_file — …/key400.pem is mode 0400; a private key must be 0600 (chmod 600 …/key400.pem)
  FAIL  private_key_file — …/notpem.pem does not parse as an RSA private key (not a PEM file)
  FAIL  private_key_file — …/locked.pem does not parse as an RSA private key (the key is passphrase-protected; an unattended mint cannot unlock it)
  FAIL  private_key_file — …/small.pem does not parse as an RSA private key (key is 1024 bits; GitHub Apps require at least 2048)
```

Transcript 5 — check 6, both PEM encodings:

```
  PASS  private_key_file — …/app.pem, mode 600, parses as RSA 2048-bit
```

`app.pem` is `-----BEGIN PRIVATE KEY-----` (PKCS#8, OpenSSL 3's default) and `app1.pem` is `-----BEGIN RSA PRIVATE KEY-----` (PKCS#1); both produce the identical row, and both keys' signatures verify. The 1024-bit arm in transcript 4 is the size gate firing before any signing.

Transcript 6 — check 7, the full pass:

```
$ python3 scripts/github-app-token.py check --env-file …/happy.env --api-base http://127.0.0.1:18771 --repo coding-hermes/code-factory --slug good-app; echo "EXIT=$?"
  PASS  private_key_file — …/app1.pem, mode 600, parses as RSA 2048-bit
  PASS  token_mint — installation 424242 answered 201; token expires 2026-11-05T18:00:00Z (permissions read back, never the token)
  PASS  permission:contents — write (need write — clone and push commits; a push is a contents write)
  PASS  permission:metadata — read (need read — mandatory for every App; resolves the repo and the installation)
  PASS  permission:pull_requests — write (need write — open the PR a protected main requires (CF-163))
  PASS  app_slug — /apps/good-app -> 200 (declared permissions: contents:write,metadata:read,pull_requests:write)
  PASS  installation_covers — installation grants coding-hermes/code-factory (of 2 repositories)
  PASS  repo_read — GET /repos/coding-hermes/code-factory with a fresh token -> 200

GITHUB APP: PASS — every piece measured, a fresh token reads coding-hermes/code-factory -> 200
EXIT=0
```

Transcript 7 — check 8, the status branches:

```
$ … check --env-file …/inst-401401.env
  FAIL  token_mint — 401 — the JWT was rejected: App id 123456 does not own the key at GITHUB_APP_PRIVATE_KEY_FILE, or the clock is off
$ … check --env-file …/inst-404404.env
  FAIL  installation_id — 404 for installation 404404 — it does not belong to App 123456, or the App is not installed yet (open the install URL and click Install)
$ … check --env-file …/inst-403403.env
  FAIL  token_mint — 403 — This installation has been suspended
$ … check --env-file …/inst-201201.env
  FAIL  token_mint — 201 answered without a token field
$ … check --env-file …/inst-202202.env
  PASS  token_mint — installation 202202 answered 200; token expires 2026-11-05T18:00:00Z (permissions read back, never the token)
  (…three PASS permission rows…)
GITHUB APP: PASS — every piece measured, a fresh token reads coding-hermes/code-factory -> 200
EXIT=0
```

Every one of the first four ends with `GITHUB APP: FAIL (1) — no token was minted`; the 403 sentence is GitHub's own `message` field, truncated to 120 characters by `_message` [scripts/github-app-token.py:269-272].

Transcript 8 — check 9, no answer at all:

```
$ … check --env-file …/happy.env --api-base http://127.0.0.1:18772; echo "EXIT=$?"
  PASS  private_key_file — …/app1.pem, mode 600, parses as RSA 2048-bit
  FAIL  token_mint — 0 — no answer

GITHUB APP: FAIL (1) — no token was minted
EXIT=1
$ … check --env-file …/happy.env --api-base http://no-such-host.invalid
  … identical two rows and identical FAIL line …
```

Transcript 9 — check 10, the summary that outruns the measurement:

```
$ … check --env-file …/happy.env          # deliberately no --repo
  PASS  private_key_file — …/app1.pem, mode 600, parses as RSA 2048-bit
  PASS  token_mint — installation 424242 answered 201; …
  PASS  permission:contents — write …
  PASS  permission:metadata — read …
  PASS  permission:pull_requests — write …
  PASS  app_slug — /apps/good-app -> 200 (declared permissions: contents:write,metadata:read,pull_requests:write)

GITHUB APP: PASS — every piece measured, a fresh token reads coding-hermes/code-factory -> 200
EXIT=0
```

Ten repositories could have been unreadable; the sentence is a literal [scripts/github-app-token.py:566].

Transcript 10 — check 11, the JWT in flight, decoded, with the signature verified through the public exponent:

```
== what the module sent to the mint endpoint ==
path            = /app/installations/424242/access_tokens
scheme          = Bearer
segments        = 3
jwt length      = 447 chars (segment lengths 36,67,342)
header          = {"alg": "RS256", "typ": "JWT"}
claims          = {"exp": 1793901848, "iat": 1793901248, "iss": "123456"}
accept          = application/vnd.github+json
api version     = 2022-11-28
user agent      = code-factory-github-app
exp-iat         = 600 s
iss is str(app) = True (str)
== signature check with the public exponent only ==
sig bytes       = 256
EM prefix       = 0001
EM verifies     = True
== make_jwt at a fixed instant, no clock involved ==
claims(now=1700000000) = {"exp": 1700000540, "iat": 1699999940, "iss": "999"}
segments = 3  header = {"alg": "RS256", "typ": "JWT"}
== clock-skew arithmetic ==
  local clock   +0s: GitHub sees iat = now-60, exp = now+540
  local clock  +59s: GitHub sees iat = now-1, exp = now+599
  local clock  +61s: GitHub sees iat = now+1, exp = now+601
  local clock +600s: GitHub sees iat = now+540, exp = now+1140
```

The 447-character length is `36 + 1 + 67 + 1 + 342`, i.e. three unpadded base64url segments. The signature was never printed: the probe decodes segments 1 and 2 and rebuilds the expected `EM` block from the digest, comparing it to `pow(sig, e, n)` — `EM verifies = True` is the proof that the hand-rolled RS256 is correct, and `sig bytes = 256` is the only thing said about the signature.

Transcript 11 — check 12, the output channel and the leak scan:

```
$ umask 022; python3 scripts/github-app-token.py token --env-file …/happy.env --api-base http://127.0.0.1:18771 --out …/env/token.out
  PASS  token — written to …/env/token.out, mode 600, expires 2026-11-05T18:00:00Z
GITHUB APP TOKEN: PASS — minted a 292s token (value never printed)
EXIT=0
$ stat -c 'mode %a  size %s' …/env/token.out
mode 600  size 40
$ wc -l < …/env/token.out                    -> 1
$ python3 -c '…endswith(b"\n")…'             -> True
$ grep -c '^ghs_' …/env/token.out         -> 1            # shape only: the value is not reproduced
$ grep -rl 'ghs_' out/                       -> (no output)
LEAK-SCAN done, files scanned=42
```

`292s` is not a constant: it is `expires_at` minus now, from the stub's fixed timestamp [scripts/github-app-token.py:623-633] — the same file re-run later printed `8s`, and the default-path run printed `183s`. The 40 bytes are 39 characters of token plus `\n`. The two `grep` lines are the one place in this document where a transcript was *narrowed* rather than copied: the pattern is cut to the `ghs_` prefix so that no token-shaped string of any kind appears here, which is why `grep -rl 'ghs_'` is used instead of the exact value that was actually searched for.

Transcript 12 — check 13, write mechanics:

```
== fresh write, umask 022 ==
file mode   = 0o600
dir mode    = 0o755
no temp left= []
== write over an existing world-readable file ==
mode after  = 0o600
== write where the destination is a symlink to an outside file ==
is symlink  = False
outside     = original (unchanged)
p3 mode     = 0o600
== write that fails after the temp exists ==
raised      = IsADirectoryError 21
leftovers   = ['token']
```

The parent directory is created `0755` — the file is 0600 but the directory holding it is not tightened [scripts/github-app-token.py:639-640]. A leftover `<path>.tmp.<pid>` containing a token is only reachable via `SIGKILL`, which no handler covers [scripts/github-app-token.py:647-652].

Transcript 13 — check 14, the destination that cannot be created:

```
$ python3 scripts/github-app-token.py token --env-file …/happy.env --api-base http://127.0.0.1:18771 --out /proc/self/nope/token; echo "EXIT=$?"
Traceback (most recent call last):
  File "…/scripts/github-app-token.py", line 766, in <module>
    sys.exit(main(sys.argv[1:]))
  File "…/scripts/github-app-token.py", line 755, in main
    return cmd_out(args)
  File "…/scripts/github-app-token.py", line 606, in cmd_out
    write_private(out, token + "\n")
  File "…/scripts/github-app-token.py", line 640, in write_private
    os.makedirs(d, exist_ok=True)
FileNotFoundError: [Errno 2] No such file or directory: '/proc/self/nope'
EXIT=1
```

Transcript 14 — check 15, `--if-older`:

```
$ … token --out …/env/token.out --if-older 2400
  SKIP  token — …/env/token.out is 0s old (< 2400s), still valid
GITHUB APP TOKEN: SKIP — nothing to do
EXIT=0
$ … token --out …/env/token.out --if-older 0
  PASS  token — written to …/env/token.out, mode 600, expires 2026-11-05T18:00:00Z
GITHUB APP TOKEN: PASS — minted a 292s token (value never printed)
EXIT=0
$ … token --env-file …/nokey.env --if-older 2400 --out …/env/token.out
  SKIP  token — …/env/token.out is 0s old (< 2400s), still valid
GITHUB APP TOKEN: SKIP — nothing to do
EXIT=0
```

The third run is defect D-2: the env file has **no** `GITHUB_APP_PRIVATE_KEY_FILE`, and the SKIP still reports a healthy token, because the mtime test runs before any validation [scripts/github-app-token.py:582-590].

Transcript 15 — check 17, the documented spellings:

```
$ python3 scripts/github-app-token.py --check
usage: github-app-token.py [-h] {check,token,manifest,jwt} ...
github-app-token.py: error: unrecognized arguments: --check
EXIT=2
$ python3 scripts/github-app-token.py --check --repo coding-hermes/code-factory
github-app-token.py: error: unrecognized arguments: --check
EXIT=2
$ python3 scripts/github-app-token.py --manifest
github-app-token.py: error: unrecognized arguments: --manifest
EXIT=2
$ python3 scripts/github-app-token.py --help
usage: github-app-token.py check [-h] [--env-file ENV_FILE]
                                 [--api-base API_BASE] [--repo REPO]
                                 [--slug SLUG]
options:
  -h, --help           show this help message and exit
  --env-file ENV_FILE  env file naming the App (default ~/.config/code-factory/github-app.env)
  --api-base API_BASE  API base URL (default https://api.github.com; tests point this at a local server)
  --repo REPO          OWNER/NAME the installation must cover and a token must read
  --slug SLUG          App slug, verified against /apps/<slug>
EXIT=0
$ python3 scripts/github-app-token.py bogus
github-app-token.py: error: argument cmd: invalid choice: 'bogus' (choose from check, token, manifest, jwt)
EXIT=2
$ python3 scripts/github-app-token.py token --if-older abc
github-app-token.py token: error: argument --if-older: invalid int value: 'abc'
EXIT=2
```

`--out` is the one documented one-flag spelling that does work, because the shim rewrites `--out` into `token --out` and `--out` is a real flag of that subparser [scripts/github-app-token.py:738-740].

Transcript 16 — check 18, the env-file grammar:

```
{"A": "plain", "B": "double", "C": "single", "D": "spaced", "E": "a=b", "F": "\"unbalanced"}
export line -> {'export A': '1'}
comments only = {}
```

Transcript 17 — check 19, `$HOME` defaults:

```
$ env HOME=<scratch>/fakehome python3 scripts/github-app-token.py token --api-base http://127.0.0.1:18771
  PASS  token — written to <scratch>/fakehome/.config/code-factory/github.token, mode 600, expires 2026-11-05T18:00:00Z
GITHUB APP TOKEN: PASS — minted a 8s token (value never printed)
EXIT=0
--- files under the fake home:
600 fakehome/.config/code-factory/github-app.env
600 fakehome/.config/code-factory/github.token
```

Transcript 18 — check 21, the manifest:

```
{
  "name": "code-factory",
  "url": "https://github.com/coding-hermes",
  "description": "code-factory node credentials: 1h installation tokens, no PAT",
  "public": false,
  "request_oauth_on_install": false,
  "default_permissions": {
    "contents": "write",
    "pull_requests": "write",
    "metadata": "read"
  },
  "default_events": [],
  "redirect_url": "https://github.com/code-factory",
  "hook_attributes": {
    "active": false
  }
}
```

The `default_permissions` block is generated from the same `REQUIRED_PERMISSIONS` table the checker uses [scripts/github-app-token.py:56-63] [scripts/github-app-token.py:664], so the manifest and the check cannot drift. `redirect_url` falls back to `https://github.com/<name>` because the manifest schema requires one [scripts/github-app-token.py:665-669].

Transcript 19 — check 22, the selftest aid:

```
$ python3 scripts/github-app-token.py jwt --env-file …/happy.env
{"claims": {"exp": 1793902008, "iat": 1793901408, "iss": "123456"}, "length": 447, "segments": 3}
EXIT=0
$ python3 scripts/github-app-token.py jwt --env-file …/happy.env --jwt-out …/env/scratch.jwt
{"claims": {…same…}, "length": 447, "segments": 3}
EXIT=0
--- jwt file mode:
mode 600 size 448
```

Transcript 20 — check 24, this document's gate:

```
$ python3 scripts/master_doc_check.py docs/master --only 14- --strict; echo "EXIT=$?"
14-scripts-github-app-token-py.md              VERIFIED   ok

1 module(s): 1 VERIFIED, 0 error(s), 0 warning(s), 10 fact(s) in the ledger
MASTER-DOC: PASS
EXIT=0
```

What this verification does **not** cover, said plainly so the green is not over-read: no request reached GitHub, so the 10-minute `exp` ceiling [scripts/github-app-token.py:48-49], the one-hour token lifetime [scripts/github-app-token.py:4] and the exact 401/404 bodies are the code's and GitHub's documented assertions rather than measurements here; and no real App key was used, so "a revoked App answers 401" is inferred from the 401 branch [scripts/github-app-token.py:383-392] and from the fact that the key is the only thing GitHub can check, not from a revoked App.

## 4. Metrics emitted

**NONE — there is no counter, no timer, no destination and no machine-readable document on the two paths that matter.** `check` and `token` print human rows and a verdict line, with no `--json` flag anywhere in the arg set [scripts/github-app-token.py:702-734]; the only JSON the program can emit is `jwt`'s diagnostic object [scripts/github-app-token.py:690-695] and `manifest`'s static document [scripts/github-app-token.py:672], neither of which reports anything about a run. Nothing measures latency, mint count, failure count or token age, and no file, socket or syslog line is written besides the token itself. This matters for the fleet rather than as a stylistic point: the refresh timer's only signal is an exit code plus a substring match on stdout [scripts/github-app-refresh.sh:85-87], so a week of failed refreshes is invisible until a push fails.

The complete observable surface, which is what an external net would have to scrape:

| Signal | Values | Where it comes from |
|---|---|---|
| exit status | `0` every row measured and green (or a deliberate SKIP); `1` a named FAIL; `2` a usage error [scripts/github-app-token.py:30] | the process, measured on every case in §3 |
| verdict line | `GITHUB APP: PASS — …` / `GITHUB APP: FAIL (n) …` / `GITHUB APP TOKEN: PASS — …` / `GITHUB APP TOKEN: SKIP — nothing to do` [scripts/github-app-token.py:566] [scripts/github-app-token.py:563] [scripts/github-app-token.py:616-619] [scripts/github-app-token.py:589] | one line, stdout, last but one or last |
| row count and row names | the piece names `env_file`, `app_id`, `installation_id`, `private_key_file`, `token_mint`, `permission:<name>`, `app_slug`, `installation_covers`, `repo_read` [scripts/github-app-token.py:295-559] | one line per piece, stdout |
| the token's age | the destination file's mtime, which is why `--if-older` reads mtime rather than storing anything [scripts/github-app-token.py:583-584] | the filesystem; the refresh driver derives "seconds of life left" from it with `3600 − age` [scripts/github-app-refresh.sh:70-75] |
| the token's own expiry | `expires_at`, echoed into the PASS rows [scripts/github-app-token.py:607-615] [scripts/github-app-token.py:459-464] | the API's answer, parsed for the printed TTL [scripts/github-app-token.py:623-633] |

The token file's mtime is load-bearing in a way that is easy to miss: it is the only durable state the credential system has. `--if-older` trusts it [scripts/github-app-token.py:582-584], the refresh driver computes remaining life from it [scripts/github-app-refresh.sh:70-75], and a `touch` on that file therefore silently extends a dead token's apparent validity for the whole window.

## 5. Log lines it can generate

Every line is a `print` to stdout except `github-app-token: <msg>`, which goes to stderr and is only reachable through `usage_error` [scripts/github-app-token.py:82-84] — a branch argparse makes unreachable (D-7, transcript 15). There is no level, no logger, no timestamp and no destination other than the invoking terminal or the caller's captured buffer [scripts/github-app-refresh.sh:85]. Row shape is `  {WORD}  {piece} — {detail}` with two spaces after the word [scripts/github-app-token.py:70-79]; `<path>` substitutes for the absolute scratch path printed in full in §3. Tag = **evidentiary** when the exact line appears in a §3 transcript, **descriptive** when it is a literal in the source that no recorded run reached.

| Level | Line (verbatim) | Emitted when | Kind |
|---|---|---|---|
| stdout | `  PASS  private_key_file — <path>, mode 600, parses as RSA 2048-bit` | the key exists, is exactly 0600, and parses [scripts/github-app-token.py:442-449] | evidentiary |
| stdout | `  PASS  token_mint — installation 424242 answered 201; token expires 2026-11-05T18:00:00Z (permissions read back, never the token)` | the exchange answered 201 or 200 with a `token` field [scripts/github-app-token.py:460-464] | evidentiary |
| stdout | `  PASS  permission:contents — write (need write — clone and push commits; a push is a contents write)` | the mint response's `permissions` grants the required level [scripts/github-app-token.py:467-476] [scripts/github-app-token.py:57] | evidentiary |
| stdout | `  PASS  permission:metadata — read (need read — mandatory for every App; resolves the repo and the installation)` | same, for the mandatory read permission [scripts/github-app-token.py:59-62] | evidentiary |
| stdout | `  PASS  permission:pull_requests — write (need write — open the PR a protected main requires (CF-163))` | same, for PR creation [scripts/github-app-token.py:58] | evidentiary |
| stdout | `  PASS  app_slug — /apps/good-app -> 200 (declared permissions: contents:write,metadata:read,pull_requests:write)` | `--slug` (or `GITHUB_APP_SLUG`) was given and `/apps/<slug>` answered 200 [scripts/github-app-token.py:478-491] | evidentiary |
| stdout | `  PASS  installation_covers — installation grants coding-hermes/code-factory (of 2 repositories)` | `--repo` is in the installation's repository list [scripts/github-app-token.py:520-524] | evidentiary |
| stdout | `  PASS  repo_read — GET /repos/coding-hermes/code-factory with a fresh token -> 200` | the freshly minted token read the repo [scripts/github-app-token.py:542-546] | evidentiary |
| stdout | `  PASS  token — written to <path>, mode 600, expires 2026-11-05T18:00:00Z` | the token file was written; the mode is re-stat'ed, not assumed [scripts/github-app-token.py:607-615] | evidentiary |
| stdout | `  SKIP  token — <path> is 0s old (< 2400s), still valid` | `--if-older` and the destination is younger [scripts/github-app-token.py:585-588] | evidentiary |
| stdout | `  FAIL  env_file — <path> is absent — run scripts/github-app-setup.sh --apply once the App exists (creating it is a browser step a human must do)` | no env file [scripts/github-app-token.py:280-287] | evidentiary |
| stdout | `  FAIL  env_file — <path> is unreadable as KEY=VALUE data (line is not KEY=VALUE: 'this line is not key value')` | the env file has a line without `=` [scripts/github-app-token.py:290-293] [scripts/github-app-token.py:96-97] | evidentiary |
| stdout | `  FAIL  app_id — GITHUB_APP_ID is unset — copy the App id from the App's settings page (App settings -> About -> App ID)` | the pointer is missing, including the `export K=V` case [scripts/github-app-token.py:296-303] | evidentiary |
| stdout | `  FAIL  app_id — GITHUB_APP_ID='abc123' is not numeric` | the pointer is non-numeric; the value is echoed to 20 chars [scripts/github-app-token.py:304-305] | evidentiary |
| stdout | `  FAIL  installation_id — 404 for installation 404404 — it does not belong to App 123456, or the App is not installed yet (open the install URL and click Install)` | the exchange answered 404 [scripts/github-app-token.py:393-403] | evidentiary |
| stdout | `  FAIL  token_mint — 401 — the JWT was rejected: App id 123456 does not own the key at GITHUB_APP_PRIVATE_KEY_FILE, or the clock is off` | the exchange answered 401 — revoked key, rotated key, wrong app id, or clock skew [scripts/github-app-token.py:383-392] | evidentiary |
| stdout | `  FAIL  token_mint — 403 — This installation has been suspended` | the exchange answered 403; GitHub's `message` is interpolated [scripts/github-app-token.py:404-409] | evidentiary |
| stdout | `  FAIL  token_mint — 201 answered without a token field` | a success status with no `token` key [scripts/github-app-token.py:374-380] | evidentiary |
| stdout | `  FAIL  token_mint — 0 — no answer` | transport failure — refused connection, DNS, timeout [scripts/github-app-token.py:410-414] [scripts/github-app-token.py:257-258] | evidentiary |
| stdout | `  FAIL  private_key_file — <path> is mode 0400; a private key must be 0600 (chmod 600 <path>)` | the mode is anything but 0600 [scripts/github-app-token.py:346-351] | evidentiary |
| stdout | `  FAIL  private_key_file — <path> does not parse as an RSA private key (the key is passphrase-protected; an unattended mint cannot unlock it)` | the PEM contains `ENCRYPTED` [scripts/github-app-token.py:160-163] | evidentiary |
| stdout | `  FAIL  private_key_file — <path> does not parse as an RSA private key (key is 1024 bits; GitHub Apps require at least 2048)` | the modulus is under 2048 bits [scripts/github-app-token.py:196-199] | evidentiary |
| stdout | `  FAIL  installation_covers — installation does not cover coding-hermes/third-repo (it covers: coding-hermes/code-factory, coding-hermes/other-repo) — add the repo on the App's installation settings page` | `--repo` is absent from the installation's list; the list is printed [scripts/github-app-token.py:525-531] | evidentiary |
| stdout | `  FAIL  repo_read — GET /repos/coding-hermes/forbidden -> 403 — the installation cannot read the repo: either it does not cover it, or contents is not granted` | the read answered 401/403 — the signature of a revoked or narrowed credential [scripts/github-app-token.py:547-553] | evidentiary |
| stdout | `  FAIL  repo_read — GET /repos/coding-hermes/third-repo -> 404 — Not Found` | the read answered anything else; the body's `message` is used [scripts/github-app-token.py:554-559] | evidentiary |
| stdout | `  FAIL  permission:contents — the App itself declares contents='read'; fix the App, not the token` | `--slug` was given and the App's declared permission is not write [scripts/github-app-token.py:492-497] | evidentiary |
| stdout | `  FAIL  app_slug — /apps/nosuch-app -> 404 (no public App with that slug)` | `/apps/<slug>` answered non-200 [scripts/github-app-token.py:498-502] | evidentiary |
| stdout | `GITHUB APP: PASS — every piece measured, a fresh token reads coding-hermes/code-factory -> 200` | end of a clean `check` [scripts/github-app-token.py:566] | evidentiary |
| stdout | `GITHUB APP: FAIL (2) — nothing was minted; every piece above must be created before a token can exist` | `check` aborted on pointer failures before any key was read [scripts/github-app-token.py:429-434] | evidentiary |
| stdout | `GITHUB APP: FAIL (1)` | `check` failed after the key stage (key, mint, permission, slug, coverage or read) [scripts/github-app-token.py:438-441] [scripts/github-app-token.py:561-564] | evidentiary |
| stdout | `GITHUB APP: FAIL (1) — no token was minted` | the exchange itself failed [scripts/github-app-token.py:452-456] | evidentiary |
| stdout | `GITHUB APP TOKEN: PASS — minted a 292s token (value never printed)` | the file was written; the number is `expires_at − now`, not a constant [scripts/github-app-token.py:616-619] [scripts/github-app-token.py:623-633] | evidentiary |
| stdout | `GITHUB APP TOKEN: SKIP — nothing to do` | `--if-older` short-circuit; this literal is what the refresh driver greps for [scripts/github-app-token.py:589] [scripts/github-app-refresh.sh:86-87] | evidentiary |
| stdout | `GITHUB APP TOKEN: FAIL (1) — nothing written` | key or mint failure on the `token` path [scripts/github-app-token.py:596] [scripts/github-app-token.py:602] | evidentiary |
| stdout | `GITHUB APP TOKEN: FAIL (2) — nothing written` | pointer failures on the `token` path; the count is `len(problems)` [scripts/github-app-token.py:574-577] | descriptive — every pointer-defect case in §3 was run through `check`, not `token` |
| stdout | `  WARN  %s — %s` | never: `warn()` is defined and never called [scripts/github-app-token.py:78-79] | descriptive, and dead code (D-7) |
| stderr | `github-app-token: %s` | `usage_error`, which argparse pre-empts for every unknown subcommand [scripts/github-app-token.py:82-84] [scripts/github-app-token.py:760] | descriptive, and unreachable (D-7) |
| stderr | `github-app-token.py: error: unrecognized arguments: --check` | the back-compat shim leaves the flag in `argv` [scripts/github-app-token.py:736-746] | evidentiary |
| stderr | `github-app-token.py: error: argument cmd: invalid choice: 'bogus' (choose from check, token, manifest, jwt)` | argparse, not this module [scripts/github-app-token.py:700-701] | evidentiary |
| stderr | `FileNotFoundError: [Errno 2] No such file or directory: '/proc/self/nope'` | the destination's parent cannot be created; nothing catches it [scripts/github-app-token.py:639-640] | evidentiary (D-5) |

The vocabulary is worth reading as a whole: the same word `PASS` covers a key that parses, a token that was minted, a permission that was granted and a repo that was read, and the only place the difference between "measured" and "not measured" shows is whether the row exists at all — which is exactly how D-4 stays invisible.

## 6. Failure modes

Direction is the module's measured behaviour. **fail closed** = the run stops or exits non-zero with a named row; **fail open** = the run proceeds, or claims success, on weaker evidence than the operator would assume; **degraded** = the run continues, or stops, with a wrong or missing row. The first ten rows are the App's own failure modes, which is what the WHY of this document asked for; the `D-n` rows are defects in the code that produced them.

| Failure | Presents as | Direction | Distinguished from | Recovery |
|---|---|---|---|---|
| **The App is deleted or its private key is revoked or rotated** | `  FAIL  token_mint — 401 — the JWT was rejected: App id 123456 does not own the key at GITHUB_APP_PRIVATE_KEY_FILE, or the clock is off` [scripts/github-app-token.py:383-392]. Measured on the 401 arm (§3 check 8) | **fail closed** — no token, exit 1, nothing written | **It cannot be distinguished**: a revoked key, a wrong app id and a clock more than 59 s fast all produce this one sentence, because the only evidence is GitHub's status code [scripts/github-app-token.py:384-391] | download a fresh `.pem` from the App's settings page and repoint `GITHUB_APP_PRIVATE_KEY_FILE` [scripts/github-app-token.py:331-334]; if the App itself is gone, the whole install flow must be repeated [scripts/github-app-setup.sh:20-24] |
| **The installation id is wrong, or the App was never installed** | `  FAIL  installation_id — 404 for installation 404404 — it does not belong to App 123456, or the App is not installed yet (open the install URL and click Install)` [scripts/github-app-token.py:393-403]. Measured (§3 check 8) | **fail closed** | Two causes, one sentence: a digit typo and an uninstalled App are the same 404. A *suspended* installation is different — 403, and GitHub's own message is printed (§3 check 8) | read the id out of the URL after installing (`Settings -> Installations -> Configure`) [scripts/github-app-token.py:311-314] |
| **The installation was suspended, or the App lost a permission** | `  FAIL  token_mint — 403 — This installation has been suspended` [scripts/github-app-token.py:404-409]; or a *granted* permission below `REQUIRED_PERMISSIONS` on a mint that succeeded: `  FAIL  permission:contents — granted 'read', need 'write' — …` [scripts/github-app-token.py:471-476] | **fail closed** on both arms | The permission arm proves the token was minted and *narrow*; the 403 arm proves nothing was minted at all. Only the row name separates them | raise the permission in App settings **and** accept the installation prompt — the prompt is a separate act, which the message says [scripts/github-app-token.py:473-476] |
| **The box's clock is fast** | the same 401 as a revoked key: `… or the clock is off` [scripts/github-app-token.py:390-391]. Arithmetic measured: `iat` is 60 s in the past, so skew beyond +59 s puts `iat` in the future and `exp` beyond the 600 s ceiling (§3 check 11, transcript 10) | **fail closed at mint**, and **fail open on diagnosis** — the operator is told two possibilities and given no way to choose | Nothing in the output mentions the host's own clock offset: `iat`/`exp` are never printed by `check`, only by `jwt` [scripts/github-app-token.py:676-696] | run `jwt` and compare `iat` against a trusted clock, then fix NTP. The 60 s backdate means skew up to 59 s is absorbed silently [scripts/github-app-token.py:50] |
| **The node's token is revoked mid-hour (App uninstalled)** | `  FAIL  repo_read — GET /repos/coding-hermes/forbidden -> 403 — the installation cannot read the repo: either it does not cover it, or contents is not granted` [scripts/github-app-token.py:547-553]. Measured on the 403 arm (§3 check 7) | **fail closed**: `GITHUB APP: FAIL (2)` and exit 1 | A 404 on the same call means the repo does not exist or the installation does not cover it; a 401/403 means the credential or the permission is wrong [scripts/github-app-token.py:554-559] | re-run after fixing the installation; the minter cannot re-authorise anything |
| **The network or DNS is down** | `  FAIL  token_mint — 0 — no answer` [scripts/github-app-token.py:410-414]. Measured for a closed port and for a non-resolving name (§3 check 9) | **fail closed**, which is right for a credential: a stale token is better than a false PASS | `0` is a status no HTTP server can return, so it is the only "no answer" signal; but it is also what a 20 s timeout produces [scripts/github-app-token.py:52] [scripts/github-app-token.py:252] | retry; nothing is consumed by a failure |
| **The key is not exactly 0600** | `  FAIL  private_key_file — <path> is mode 0400; a private key must be 0600 (chmod 600 <path>)` [scripts/github-app-token.py:346-351]. Measured at 0644 and 0400 (§3 check 5) | **fail closed** — including against a *stricter* mode | A mode of 0644 is a real hazard; 0400 is not, and is refused identically (D-9) | `chmod 600` — the message prints the exact command |
| **The key is passphrase-protected** | `  FAIL  private_key_file — <path> does not parse as an RSA private key (the key is passphrase-protected; an unattended mint cannot unlock it)` [scripts/github-app-token.py:160-163] | **fail closed**, correctly: a prompt on a timer is a hang | A non-PEM file says `not a PEM file`; an encrypted one names the passphrase | generate an unencrypted key for the App; the download is the only copy GitHub offers [scripts/github-app-token.py:332-334] |
| **The token is minted but cannot be stored** | a Python traceback ending `FileNotFoundError: [Errno 2] No such file or directory: …` and exit 1 [scripts/github-app-token.py:639-640]. Measured (§3 check 14) | **degraded and fail open on containment**: nothing is written, so no stale file is left — but the run *did* create a live installation token server-side and threw it away, and it reports the failure as a crash rather than a named FAIL | A named `FAIL token` would say which destination; this says nothing about the credential | fix the destination; the orphaned token dies within the hour [scripts/github-app-token.py:4] |
| **A refresh is skipped while the App is broken** | `  SKIP  token — <path> is 0s old (< 2400s), still valid` and `GITHUB APP TOKEN: SKIP — nothing to do`, exit 0, with `GITHUB_APP_PRIVATE_KEY_FILE` unset entirely [scripts/github-app-token.py:582-590]. Measured (§3 check 15, third run) | **fail open on diagnosis**: the mtime test precedes every validation, so the program reports a healthy credential for an App it never looked at | A real refresh prints `GITHUB APP TOKEN: PASS — minted a Ns token`; a SKIP is the only silent path | none within the window; the next refresh past `--if-older` will FAIL loudly (D-2) |
| **D-1 — the documented one-flag spelling does not exist** | `python3 scripts/github-app-token.py --check` → `error: unrecognized arguments: --check`, exit 2; likewise `--manifest`. Measured (§3 check 17) | **fail closed as a usage error**, but the interface the module documents for itself [scripts/github-app-token.py:10] is dead | `check` (the subcommand) works and is what both consumers call [scripts/github-app-setup.sh:157]; `--out` works because the shim's rewrite happens to be correct for it [scripts/github-app-token.py:738-740] | use the subcommand form; the docstring block [scripts/github-app-token.py:9-17] should be corrected, or the shim should drop the flag it consumed |
| **D-2 — a shell-style env file is silently mis-parsed** | `export GITHUB_APP_ID=123456` yields the key `export GITHUB_APP_ID`, so the run reports `FAIL app_id — GITHUB_APP_ID is unset` on a file that plainly sets it [scripts/github-app-token.py:97-103]. Measured (§3 checks 3 and 18) | **fail closed with a misleading row**: it blames a missing value, not an unparsed line | A file with a line that has no `=` at all *is* refused by name (`line is not KEY=VALUE`) [scripts/github-app-token.py:96-97], so only the `export` shape slips through | write the file as bare `KEY=VALUE`; `github-app-setup.sh` does [scripts/github-app-setup.sh:263-272] |
| **D-3 — the "read-only" check creates credentials** | the docstring says `Read-only: mints a token in memory, writes nothing` [scripts/github-app-token.py:14], but `check` issues the same `POST` as `token` [scripts/github-app-token.py:370-372], and nothing in the file ever revokes it — no `DELETE` call exists | **fail open on the claim**: each `--check` leaves a live installation token on GitHub's side for up to an hour, unseen and unrecorded, so repeated runs leave a trail of them | A truly read-only check would be `GET /apps/<slug>` alone [scripts/github-app-token.py:480], which this program already knows how to do | none needed operationally (the tokens expire), but the docstring overstates the guarantee; a revocation call would close it |
| **D-4 — the PASS sentence is a constant** | **FIXED (CF-319):** the summary is emitted only after `repo_read` passes and names `<owner>/<name> -> 200`; an absent target emits `FAIL repo_read` and exits 1 [scripts/github-app-token.py:504-575] | **fail closed on reporting** | Arms A/B/C in `tests/test_github_app_check.py` and the committed audit transcript prove 403 failure, 200 success, and no-repo refusal | read the rows, not the summary; or make the summary conditional |
| **D-5 — an unwritable destination is a traceback, not a FAIL** | `FileNotFoundError` traceback, exit 1, no row, no verdict line [scripts/github-app-token.py:639-640]. Measured (§3 check 14) | **degraded**: exit 1 is correct, the reporting is not — the operator gets a stack trace and no piece name, and a token was created and discarded | Every other failure in this program has a named `FAIL`; this is the only traceback | read the traceback's path and create the directory |
| **D-6 — `_ttl` can raise after the token is written** | a non-string `expires_at` raises `TypeError: strptime() argument 0 must be str` from the PASS printer [scripts/github-app-token.py:629-633], *after* `write_private` succeeded [scripts/github-app-token.py:606]; the process exits non-zero with a valid token on disk. Measured (§3 check 16) | **fail open on outcome, fail closed on report**: the file is right and the exit code says failure — the inverse of a silent success | A malformed string `expires_at` does not raise: it falls back to 3600 [scripts/github-app-token.py:630-633] | trusted input from GitHub today; the catch should be `(ValueError, TypeError)` |
| **D-7 — two branches are dead** | `warn()` is defined and never called [scripts/github-app-token.py:78-79]; `usage_error()` is unreachable because argparse rejects unknown subcommands first [scripts/github-app-token.py:760] [scripts/github-app-token.py:700-701]. Measured: `bogus` → argparse's `invalid choice` (§3 check 17) | no direction — neither branch can run, so no behaviour depends on them | The `WARN` row shape appears in no transcript and no consumer greps for it | delete them, or wire `warn` to the one place it would help: a token file whose mtime is older than 3600 s at SKIP time |
| **D-8 — one sentence, two causes, no way to choose** | the 401 row names "does not own the key … or the clock is off" [scripts/github-app-token.py:389-391], and the operator's next action differs entirely between them (fetch a new key vs fix NTP) | **fail open on diagnosis** | `jwt` prints `iat`/`exp`, which is the only in-tree way to separate the two [scripts/github-app-token.py:690-695] | run `jwt`; compare against a trusted clock |
| **D-9 — a stricter key mode is refused** | mode 0400 → `is mode 0400; a private key must be 0600 (chmod 600 <path>)` [scripts/github-app-token.py:346-351]. Measured (§3 check 5) | **fail closed against a safe configuration**: the test is `mode != 0o600`, i.e. equality with one literal, not "no group or other bits" | 0644 and 0400 produce different sentences but the same refusal; nothing accepts 0400 | `chmod 600` — which *widens* the file to owner-write so the program will look at it |
| **D-10 — `--help` shows one subcommand's help, and `--org` does nothing** | `usage: github-app-token.py check [-h] …` for `--help` and `-h` [scripts/github-app-token.py:736-746]; `manifest --org X` is parsed and never read [scripts/github-app-token.py:728] [scripts/github-app-token.py:658-672]. Measured (§3 check 17) | **fail open on documentation**: a user asking for help is shown a third of the interface and told nothing about `token`, `manifest` or `jwt` | A bare invocation prints the full parser help and exits 2 (§3 transcript 1) | run the program with no arguments to see all four |
| **D-11 — no gate runs this file** | `grep -c 'github-app' tests/selftest.sh` over 3657 lines returns `0` | **fail open on integration**: the repo's rule that "every check must be able to fail" and must have a fixture [AGENTS.md:28-30] is unmet for the one module that mints the fleet's credential, which is how D-1 and D-4 survived review | Every other script in `scripts/` has at least one leg; this one has none | add a leg that runs `check` against a stub `--api-base` and asserts both the FAIL and the PASS rows — the stub in §2c is enough |

## 7. Environment and settings it reads

**Three variables come from the process environment**, all of them overridable by a flag, and none of them a secret:

| Variable | Read at | Default | Effect if unset |
|---|---|---|---|
| `GITHUB_APP_ENV_FILE` | [scripts/github-app-token.py:110] | `~/.config/code-factory/github-app.env` [scripts/github-app-token.py:45] | the default env file is used; if that is absent too, `FAIL env_file` naming the path |
| `GITHUB_API_BASE` | [scripts/github-app-token.py:115] | `https://api.github.com` [scripts/github-app-token.py:47] | real GitHub. Measured override: this is the only reason §3 could run at all |
| `GITHUB_APP_REPO` | [scripts/github-app-token.py:708] | empty — no coverage or read check | the run skips both repo rows and still prints the D-4 sentence |

**Five variables come from the env file**, which the docstring describes as "pointers, never secrets" [scripts/github-app-token.py:19-20]:

| Key | Read at | Required | Effect of absence |
|---|---|---|---|
| `GITHUB_APP_ID` | [scripts/github-app-token.py:295] | yes | `FAIL app_id`; also must be all digits [scripts/github-app-token.py:304-305]. It becomes the JWT's `iss` as a string [scripts/github-app-token.py:224] |
| `GITHUB_APP_INSTALLATION_ID` | [scripts/github-app-token.py:307] | yes | `FAIL installation_id`; must be all digits [scripts/github-app-token.py:316-322]; interpolated into the URL path [scripts/github-app-token.py:371] |
| `GITHUB_APP_PRIVATE_KEY_FILE` | [scripts/github-app-token.py:328] | yes | `FAIL private_key_file`, with the sentence that says the download is the only copy |
| `GITHUB_APP_TOKEN_FILE` | [scripts/github-app-token.py:579] | no | `~/.config/code-factory/github.token` [scripts/github-app-token.py:46] |
| `GITHUB_APP_SLUG` | [scripts/github-app-token.py:478] | no | no `/apps/<slug>` check; `--slug` wins if both are present |

`$HOME` is expanded for three paths — the env file, the key file and the token file [scripts/github-app-token.py:279] [scripts/github-app-token.py:336] [scripts/github-app-token.py:578] — so a `HOME` override relocates all of them, which is how §3 check 19 proved the defaults without touching the real ones. There is no config file beyond this env file, no dotfile, no flag file, and **no secret in any of them**: the token is never an input, and the private key is named by path rather than embedded [scripts/github-app-token.py:19-25].

Flags, with precedence over the variables above:

| Setting | Subcommand | Default | Effect of missing |
|---|---|---|---|
| `--env-file` | `check`, `token`, `jwt` | `GITHUB_APP_ENV_FILE` then `~/.config/code-factory/github-app.env` [scripts/github-app-token.py:107-112] | as above |
| `--api-base` | `check`, `token`, `jwt` | `GITHUB_API_BASE` then `https://api.github.com` [scripts/github-app-token.py:113-118] | real GitHub |
| `--repo OWNER/NAME` | `check` | `GITHUB_APP_REPO`, else empty [scripts/github-app-token.py:706-710] | coverage and read checks are skipped; the PASS sentence is still printed (D-4) |
| `--slug` | `check` | `GITHUB_APP_SLUG`, else empty [scripts/github-app-token.py:711-713] | no declared-permission check |
| `--out PATH` | `token` | `GITHUB_APP_TOKEN_FILE` then `~/.config/code-factory/github.token` [scripts/github-app-token.py:716-718] [scripts/github-app-token.py:578-580] | the default path; parent directories are created, mode 0755 (transcript 12) |
| `--if-older SECONDS` | `token` | `0`, i.e. always mint [scripts/github-app-token.py:719-724] | a mint on every invocation; the refresh timer passes 2400 [scripts/github-app-refresh.sh:67] |
| `--name`, `--url`, `--org`, `--redirect-url` | `manifest` | `code-factory`, `https://github.com/coding-hermes`, empty, empty [scripts/github-app-token.py:726-729] | `redirect_url` falls back to `https://github.com/<name>` [scripts/github-app-token.py:669]; `--org` changes nothing (D-10) |
| `--jwt-out PATH` | `jwt` | empty — print claims only [scripts/github-app-token.py:732-734] | no JWT file is written; the printed object never contains the JWT [scripts/github-app-token.py:690-695] |

`--org` is accepted and never used: it is parsed [scripts/github-app-token.py:728] and the manifest body never reads `args.org` [scripts/github-app-token.py:658-672], so passing it changes nothing — a flag that silently does nothing, the same class of defect the repo's gate now fails flag handlers for elsewhere [tests/selftest.sh:1988-1997].

What is written, and only this: the token file (mode 0600, one line, atomic) [scripts/github-app-token.py:636-653], and on `jwt --jwt-out` a JWT file at 0600 [scripts/github-app-token.py:688-689], which is a live 10-minute credential and is why that flag is labelled "selftest only" [scripts/github-app-token.py:733]. Nothing is read twice, nothing is cached, and no state survives the process apart from those files' mtimes.

## 8. Evidence of record

- **Measured 2026-11-05**, clean worktree of `6eea792` (`~/proj-wt-md-14f`), Linux x86_64, Python 3.14.4: every transcript in §3 is literal terminal output from this session. **No live GitHub call was made and no live credential was minted** — as the task required, a `--check`/argument path plus code reading is the evidence: the App id `123456`, installation `424242` and the RSA keys are scratch values generated for this document, and every API row was produced against a local stub reached through `--api-base`, the flag that exists for that purpose [scripts/github-app-token.py:116-117].
- **The JWT was verified, not assumed.** The mint request the stub received was decoded segment by segment, and the signature was checked with the key's public exponent only — `EM verifies = True` (§3 transcript 10). That is the strongest statement this document can make about RS256 correctness without a live API, and it also fixes the claim's boundary: it proves this program signs correctly, not that GitHub accepts it.
- **No secret appears in this document, and none was printed to the terminal.** Three gates: the module prints no token by design [scripts/github-app-token.py:27-28]; every captured stdout/stderr was grepped for the stub's token value and returned nothing (transcript 11); and the JWT probe prints the header, the claims and a length, never the third segment. The 447 in transcript 10 is the *length*; the 448 in transcript 19 is a file *size*. The token is quoted by **shape only**: `ghs_` plus 36 characters, one line, mode 600.
- **The output channel is proven at the filesystem, not from the docstring**: `mode 600` under `umask 022`, one line with a trailing newline, content equal to the API's token, and zero occurrences in 42 captured output files (§3 check 12). The atomic-write properties — old file normalised to 0600, symlink replaced rather than followed, temp cleaned on failure — were measured by calling `write_private` directly (§3 check 13), which is the only way to reach those branches without an unlucky filesystem.
- **Every status branch the App can return was driven**, by routing installation ids to 401/404/403/201-no-token/200 at the stub [scripts/github-app-token.py:373-414], plus `0` for transport failure. That is why §6 can state the direction of each failure rather than describing it, and why D-8 (one 401 sentence for two causes) is a finding rather than a guess.
- **The repository's own gate does not cover this file**: `grep -c 'github-app' tests/selftest.sh` over its 3657 lines returns `0` (D-11), against the rule that every check must have a fixture that can fail [AGENTS.md:28-30]. The module is the only thing in the tree that can mint a push credential, and the only thing in the tree whose entire job is to refuse by name. The absence of a leg is why D-1 (the documented `--check` spelling exits 2) survived in code that is otherwise carefully self-checking.
- **The claims discipline this document follows** — a row closes only with a re-runnable command in its evidence, never a commit message or a summary — is the project's own rule [docs/master/_facts.md:21] (fact: FACT-10), and the credential rule that makes §1's "file, mode 600, never an argument" the right shape is rule 8 of AGENTS.md [AGENTS.md:40-41] (fact: FACT-05).
- **Not measured, and said so**: no request left the host, so the 10-minute `exp` ceiling [scripts/github-app-token.py:48-49], the one-hour token lifetime [scripts/github-app-token.py:4] [scripts/github-app-refresh.sh:13] and GitHub's exact 401/404 bodies are the code's and GitHub's assertions; no revoked App was created, so that row's causes come from the 401 branch plus the fact that the key is the only thing GitHub can check; and no concurrent refresh was run against a live destination, so the `SIGKILL`-leaves-a-temp-token path [scripts/github-app-token.py:641-652] is read from code.

Defects measured while filling this section (documented, **not** fixed — `scripts/` is out of scope for this task):

1. **D-1 — the documented `--check` and `--manifest` spellings are dead.** The back-compat shim [scripts/github-app-token.py:736-746] prepends the subcommand name but leaves the flag in `argv`, so `--check` becomes `check --check` and argparse rejects it: `error: unrecognized arguments: --check`, exit 2 (§3 transcript 15). The docstring advertises exactly that spelling [scripts/github-app-token.py:10] [scripts/github-app-token.py:15]. `--out` survives only because `--out` is a real flag of the subcommand it gets rewritten into [scripts/github-app-token.py:738-740]. Both consumers call the subcommand form, so nothing in automation is broken — but the interface a human reads first is.
2. **D-2 — `--if-older` short-circuits before any validation.** The mtime test [scripts/github-app-token.py:582-590] precedes `load_inputs`' verdict [scripts/github-app-token.py:592-597], so a host with no key file and no app id prints `SKIP … still valid` and exits 0 (§3 transcript 14, third run). A refresh that reports work it did not do is indistinguishable from a refresh that had nothing to do.
3. **D-3 — `check` is described as read-only and is not.** `Read-only: mints a token in memory, writes nothing` [scripts/github-app-token.py:14] is true of the local filesystem and false of GitHub: the exchange is a `POST` that creates an installation token [scripts/github-app-token.py:370-372] which nothing revokes — the file issues no `DELETE` at all. Each `--check` leaves a credential live for up to an hour.
4. **D-4 — FIXED by CF-319.** The summary now follows a passing `repo_read` row, names the repository and `200`, and no repository target produces a named failure; see the local-stub arms and committed transcript.
5. **D-5 — an unwritable destination crashes.** `os.makedirs` at [scripts/github-app-token.py:639-640] is outside any handler, and `main` catches only `KeyboardInterrupt` [scripts/github-app-token.py:764-768], so the failure surfaces as a traceback with no named row, after the token was minted and discarded (§3 transcript 13).
6. **D-6 — `_ttl` raises `TypeError` after the file is written.** The `except ValueError` at [scripts/github-app-token.py:631] does not cover a non-string `expires_at`; `strptime` raises `TypeError`, which escapes from the PASS printer [scripts/github-app-token.py:607-615] that runs *after* `write_private` [scripts/github-app-token.py:606] — exit non-zero with a valid token on disk.
7. **D-7 — `warn()` and `usage_error()` are dead.** `warn` is defined and never called [scripts/github-app-token.py:78-79]; `usage_error` is only reachable from the `unknown command` branch [scripts/github-app-token.py:760], which argparse pre-empts with `invalid choice` [scripts/github-app-token.py:700-701] (measured, transcript 15). So the module's only `WARN` shape and its only stderr line cannot be produced.
8. **D-8 — one 401 sentence for two unrelated causes.** Revoked key, wrong app id and clock skew more than 59 s fast all print `the JWT was rejected: App id N does not own the key at GITHUB_APP_PRIVATE_KEY_FILE, or the clock is off` [scripts/github-app-token.py:384-391]. The operator's next action differs entirely between them, and the only in-tree way to choose is `jwt`'s claims output [scripts/github-app-token.py:690-695].
9. **D-9 — a stricter key mode is refused.** The test is `mode != 0o600` [scripts/github-app-token.py:346-351], so `0400` — strictly safer than `0600` — is a FAIL that tells the operator to widen the file (§3 check 5).
10. **D-10 — `--help` shows one subcommand's help, and `--org` does nothing.** `--help`/`-h` are rewritten into `check --help` by the same shim as D-1 [scripts/github-app-token.py:736-746], so the top-level surface is only visible from a bare invocation (transcript 1); and `manifest --org` is parsed [scripts/github-app-token.py:728] but never read [scripts/github-app-token.py:658-672].
11. **D-11 — no gate runs this file.** `tests/selftest.sh`, 3657 lines, contains zero `github-app` references. The repository's rule is that every check must be able to fail and must have a fixture [AGENTS.md:28-30]; the module with the fleet's only credential-minting authority has none, which is the mechanism by which D-1 and D-4 reached `main`.
