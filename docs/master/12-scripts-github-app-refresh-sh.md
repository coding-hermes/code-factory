# 12. scripts/github-app-refresh.sh

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/github-app-refresh.sh` — 146 lines [scripts/github-app-refresh.sh:1] |
| Repository | `code-factory` [scripts/github-app-refresh.sh:1] |
| Revision | `dad2749`; the file is byte-identical on `origin/main` (`6eea792`) — `git diff --stat HEAD origin/main -- scripts/github-app-refresh.sh` is empty — sha256 `b4d5d4d4d72c8cca467bbd1e4fa4ad0b102988be6f093a59c3435072a8b3e636` |
| Status | **VERIFIED — 104 distinct locators (213 citations), all resolve; node-side remote body read-from-code (no node touched), stated as such in §6 and §8** |
| Default token file | `$HOME/.config/code-factory/github.token` [scripts/github-app-refresh.sh:58] |
| Default env file | `$GITHUB_APP_ENV_FILE` or `$HOME/.config/code-factory/github-app.env` [scripts/github-app-refresh.sh:24] |
| Exit codes | `0` success, no-op or dry run · `1` a named refusal · `2` usage [scripts/github-app-refresh.sh:50-53] |

## 1. Purpose and why it matters

- **What it is:** the only thing in the tree that re-mints a GitHub App installation token. GitHub issues that token for exactly 3600 s, so "a node provisioned today and pushing tomorrow has a dead credential unless something re-mints it" [scripts/github-app-refresh.sh:13-17]. Nothing else in the repository refreshes a credential: `grep -rln 'github-app-refresh'` over `*.sh`, `*.md`, `*.py` returns this script, `scripts/github-app-setup.sh` (which only *checks* for a timer, [scripts/github-app-setup.sh:197-201]) and two documentation lines — an index row [docs/master/00-INDEX.md:19] and the lib-inventory row [docs/master/22-scripts-lib-sh.md:67].
- **Two modes, one rule.** Local mode refreshes this host's own file [scripts/github-app-refresh.sh:92-114]; node mode mints here and installs into a bunker node [scripts/github-app-refresh.sh:116-146]. The rule is that "the App PRIVATE KEY never leaves the control host. The node only ever holds a token that dies within the hour" [scripts/github-app-refresh.sh:9-11]. Credentials are carried as file paths at mode 600, never as argv values [docs/master/_facts.md:16] (fact: FACT-05) — and this script obeys that: the token reaches the node by `bunker cp` of a 0600 temp file [scripts/github-app-refresh.sh:124-128], never as an argument.
- **What breaks if it is ABSENT:** a node keeps a credential that expired 3600 s after provisioning. The provisioner measures GitHub auth exactly once, at install time — `github=$(... present|absent)` — and never again [scripts/bunker-provision.sh:214]. The foreman runs on that node, never on the control host [docs/master/_facts.md:12] (fact: FACT-01), and one bunker serves one project's every lane [docs/master/_facts.md:13] (fact: FACT-02), so an expired token does not stop *a push*: it stops the whole project's lanes, hours after the provisioning tick that looked green. The symptom is 401s that read like a permissions bug.
- **The absent-timer variant is the same failure with no bad exit code at all.** The usage block tells the operator to run this "from a user systemd timer ... every 20 minutes with `--min-age 2400`" and points at a doc block in `skills/code-factory-bunker/SKILL.md` [scripts/github-app-refresh.sh:15-17]. That block does not exist: `grep -c 'github-app-refresh' skills/code-factory-bunker/SKILL.md` = 0, no `.timer` or `.service` file is tracked anywhere in the repository (`git ls-files | grep -E '\.(timer|service)$'` → empty), and the only systemd-aware code that mentions the refresh is the setup check that *warns* when it finds none [scripts/github-app-setup.sh:197-201]. Nothing in this tree arms the timer; a host without one loses push rights 3600 s after provisioning while every script exits 0.
- **What breaks if it LIES:** the two rows an operator reads as proof of freshness are both derived from the local file's **mtime**, not from the API's `expires_at`. `life_left` computes `3600 - age` from `os.path.getmtime` [scripts/github-app-refresh.sh:72-76], and the minter's skip decision is `age < if_older` on the same mtime [scripts/github-app-token.py:582-589]. The minter *does* print the real `expires_at` [scripts/github-app-token.py:609-616] and **nothing stores or re-reads it** — so no component can cross-check a token's true expiry against the wall clock. Measured direction (§3 T10a): a file whose mtime is one hour in the future is reported as `~3600s left` and is never re-minted.
- **Second lie surface, measured (§3 T4):** the mode check prints `FAIL mode` and then the script *continues*, rewrites the credential store and exits 0 [scripts/github-app-refresh.sh:101-113]. A token written at mode 644 is reported as failed and installed anyway, and the timer sees success.

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `bash` | 5.3.9 measured here; the script needs nothing newer than `local`, arrays and `${2:-}` [scripts/github-app-refresh.sh:39-51] | Anywhere on `PATH` — the shebang is `#!/usr/bin/env bash` [scripts/github-app-refresh.sh:1] | Not detected by the script: a POSIX `sh` gets as far as the first `local` and then dies when `life_left` runs [scripts/github-app-refresh.sh:73] |
| `python3` | 3.14.4 measured here; only `os`, `sys`, `time` are used [scripts/github-app-refresh.sh:74] | On `PATH`, resolved once into `$PY` | **Named refusal, exit 1**: `FAIL python3 — python3 is required to sign the App JWT` [scripts/github-app-refresh.sh:59-60] |
| `scripts/github-app-token.py` | The sibling minter, in the same directory as this script | `$HERE/github-app-token.py`, tested with `-r` | **Named refusal, exit 1**: `FAIL minter — ... is missing` [scripts/github-app-refresh.sh:61] |
| A readable App env file | Pointers only, no secret: `GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION_ID`, `GITHUB_APP_PRIVATE_KEY_FILE` [scripts/github-app-token.py:20-26] | `$GITHUB_APP_ENV_FILE` or the default [scripts/github-app-refresh.sh:24], tested with `-f` | **Named refusal, exit 1**, naming the setup script: `run scripts/github-app-setup.sh --apply once` [scripts/github-app-refresh.sh:57] |
| `stat` with `-c` (GNU/coreutils) | coreutils 0.8.0 (uutils) measured here | `PATH`, local mode only | Not detected as an absence: a `stat` that rejects `-c` falls to `echo '?'`, which then prints `is mode ?, expected 600` and — because that line has no exit — exits 0 [scripts/github-app-refresh.sh:101-102] |
| `mktemp` | coreutils | `PATH`; honours `TMPDIR` | Not detected: the command substitution yields an empty name and the later `rm -f ""` is a no-op [scripts/github-app-refresh.sh:106] [scripts/github-app-refresh.sh:124] |
| `bunker` client | not in this tree; `/home/kara/.local/bin/bunker` on the control host here | `PATH`, **node mode only** — local mode never looks for it [scripts/github-app-refresh.sh:92] [scripts/github-app-refresh.sh:118] | **Named refusal, exit 1**: `FAIL bunker_cli — the bunker client is not on PATH` [scripts/github-app-refresh.sh:119], measured §3 T18 |
| Network to the GitHub API | — | Outbound HTTPS from the **minter**, not from this script: `grep -c curl scripts/github-app-refresh.sh` = 0; the only `--api-base` this file does is pass-through [scripts/github-app-refresh.sh:33] [scripts/github-app-refresh.sh:68] | The minter turns any transport failure into one FAIL row, which this script reports as `FAIL refresh` and exit 1 [scripts/github-app-refresh.sh:95] |

### 2b. Library contracts

| Import / call | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `. "$HERE/lib.sh"` [scripts/github-app-refresh.sh:22] | this repo: `scripts/lib.sh` | Four printers and one probe: `say` / `ok` / `bad` / `note` / `have` [scripts/lib.sh:5-13]. **`bad` prints a FAIL row and increments `FAILED` but never exits** [scripts/lib.sh:7], and `FAILED` must be pre-seeded or unset-expansion aborts the caller [scripts/lib.sh:11] | This script never reads `FAILED` — it relies on an explicit `exit` after each refusal. Nine of its ten `bad` calls carry one [scripts/github-app-refresh.sh:57-142]; **the tenth, the mode check, does not** [scripts/github-app-refresh.sh:102], which is why a mode violation is cosmetic (§3 T4, §6) |
| `"$PY" "$HERE/github-app-token.py" token --env-file F --if-older N --out P [--api-base U]` [scripts/github-app-refresh.sh:85] | sibling minter | Argument names exactly as spelled [scripts/github-app-token.py:15-16]; exit 0 on mint **or** on skip, 1 on a named refusal, 2 on usage [scripts/github-app-token.py:28-30]; the file appears at mode 600 written atomically by `write_private` [scripts/github-app-token.py:636-653] | The caller reads **stdout text**, not a status: it decides "a token was written" from the substring `GITHUB APP TOKEN: SKIP` [scripts/github-app-refresh.sh:87]. Any re-wording of that banner turns a skip into a reported refresh — measured §3 T21b: with the banner changed to `NOTHING-TO-DO`, an untouched 10-minute-old file was reported as `refreshed, ~3000s of life left` with its mtime unchanged |
| `$out` capture and re-print [scripts/github-app-refresh.sh:85-88] | sibling minter | The minter promises never to print the token, the JWT or the key [scripts/github-app-token.py:27-28]; this script re-prints the whole capture with a two-space indent [scripts/github-app-refresh.sh:85] [scripts/github-app-refresh.sh:88] | If the minter ever printed the token, this line would put it on the timer's stdout and into the journal, indented and unredacted |
| `stat -c %a` / `python3 -c 'os.path.getmtime'` [scripts/github-app-refresh.sh:74] [scripts/github-app-refresh.sh:101] | coreutils / CPython | The file's mtime is the token's birthday, because the minter writes it the moment the token is created [scripts/github-app-refresh.sh:70-71] | Any write path that rewrites the file without re-minting (a `touch`, a restore, a copy) resets the apparent age and pauses refreshing indefinitely — the direction is measured in §3 T10a/T10b |

### 2c. Service contracts (both sides must be named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| GitHub API | control host → api.github.com | HTTPS inside the minter, never in this file | App JWT → installation token + `expires_at`; the token goes straight to the file, never to stdout [scripts/github-app-token.py:636-653] | `mint()` / `cmd_out()` in the minter [scripts/github-app-token.py:570-621]; this side is only the argv at [scripts/github-app-refresh.sh:85] |
| `bunker` client (node mode) | control host → daemon → node | two CLI verbs, `cp` then `exec -- bash -lc '<script>'` [scripts/github-app-refresh.sh:128-139] | a 0600 temp file, then a fixed remote script that installs it and prints one line | **Not in this tree** (external CLI + daemon). Caller side: `scripts/github-app-refresh.sh`. The same remote layout is also produced by the provisioner [scripts/bunker-provision.sh:375-385], and the node-side reader is the provisioner's own presence check `[ -s "$HOME/.node/auth/github.token" ]` [scripts/bunker-provision.sh:214] |
| git credential store | script → node's `~/.git-credentials` | plain file rewrite + `git config --global credential.helper store` [scripts/github-app-refresh.sh:135-137] | one line, `https://x-access-token:<token>@github.com` (the format string is literal at [scripts/github-app-refresh.sh:107]; the value is read from the token file, never echoed) | node's `git` (external). On the **control host** the same file is rewritten **only if it already exists** and the helper is *not* set [scripts/github-app-refresh.sh:105-110] — the asymmetry is deliberate and stated at [scripts/github-app-refresh.sh:103-104] |
| The timer that invokes all of this | operator → this script | none in-tree | `--node A --server H --min-age 2400 [--quiet]`, or `--local` [scripts/github-app-refresh.sh:5-7] | **Absent from the repository**: no unit file is tracked, and the setup check only warns [scripts/github-app-setup.sh:197-201] |

## 3. Verification

Every row below was executed on 2026-11-05 from a scratch `HOME` (`/home/kara/.hermes/cache/scratch/md32/probe/home`) with `env -i`, a copied tree, and a **stub minter** in place of the real one — except R1-R3, which run the real minter against an env file that names a nonexistent key, so the failure path is reached before any network call and no token is ever minted. No GitHub App was contacted, no live token was produced, and no node was touched.

| # | Check | Command | Expected | Last run | Result |
|---|---|---|---|---|---|
| 1 | Syntax and shellcheck | `shellcheck -S style scripts/github-app-refresh.sh` [scripts/github-app-refresh.sh:20] | no error-level finding | 2026-11-05 | **PASS with 3 informational/warning findings**: SC1091 on the `lib.sh` source, SC2034 `MINT_ROWS appears unused` [scripts/github-app-refresh.sh:81-86], SC2016 on the single-quoted remote script [scripts/github-app-refresh.sh:129]; rc 1 |
| 2 | Absent env file | `bash refresh --local --env-file <absent>` [scripts/github-app-refresh.sh:57] | FAIL `env_file`, exit 1, nothing written | 2026-11-05 | **PASS** (T1) |
| 3 | Fresh local mint | `MOCK=ok bash refresh --local` [scripts/github-app-refresh.sh:92-113] | token file mode 600, credential store rewritten to one line at mode 600, exit 0 | 2026-11-05 | **PASS** (T2): token `600`, `.git-credentials` `600`, `wc -l` = 1 |
| 4 | Young-token no-op | `MOCK=skip bash refresh --local` [scripts/github-app-refresh.sh:96-100] | `(no-op)` row, exit 0, mtime unchanged | 2026-11-05 | **PASS** (T3) |
| 5 | **Mode violation is not fatal** | `MOCK=mode644 bash refresh --local --token-file <new>` [scripts/github-app-refresh.sh:101-113] | FAIL `mode`; what exit code? | 2026-11-05 | **DEFECT CONFIRMED**: `FAIL mode` printed, credential store still rewritten, **exit 0** (T4) |
| 6 | Mint failure keeps the old token | `MOCK=fail bash refresh --local` with an existing token file [scripts/github-app-refresh.sh:95] | FAIL `refresh`, exit 1, old bytes and mtime untouched | 2026-11-05 | **PASS** (T5): content `OLDTOKEN`, mtime identical |
| 7 | Real minter, key absent | `python3 scripts/github-app-token.py token --env-file <fake> --if-older 2400 --out <t>` [scripts/github-app-token.py:592-602] | FAIL `private_key_file`, `nothing written`, exit 1, file absent | 2026-11-05 | **PASS** (R1) |
| 8 | Real minter, young file | same, token file written 0 s ago [scripts/github-app-token.py:582-589] | `SKIP`, exit 0, **no key read at all** | 2026-11-05 | **PASS** (R2): skip precedes the key check |
| 9 | Real minter, file aged past the threshold | same, mtime `-2 hours` [scripts/github-app-token.py:584] | falls through to the key check, FAIL, file unchanged | 2026-11-05 | **PASS** (R3) |
| 10 | `--min-age` not numeric | `bash refresh --min-age abc` [scripts/github-app-refresh.sh:53] | message, exit 2 | 2026-11-05 | **PASS** (T6) |
| 11 | `--node` without `--server` | `bash refresh --node cf-node` [scripts/github-app-refresh.sh:63-65] | FAIL `server`, exit 2 | 2026-11-05 | **PASS** (T7) |
| 12 | Local dry run | `bash refresh --local --dry-run` [scripts/github-app-refresh.sh:94] | `dry run` note, exit 0, no file | 2026-11-05 | **PASS** (T8) |
| 13 | No credential store present | `bash refresh --local` in a `HOME` without `~/.git-credentials` [scripts/github-app-refresh.sh:105] | no new store created | 2026-11-05 | **PASS** (T9) |
| 14 | Clock skew, mtime +1 h | `touch -d '+1 hour'` then a skip run [scripts/github-app-refresh.sh:72-76] | reports the clamp | 2026-11-05 | **PASS (direction is the bad one)**: `~3600s left` for a file GitHub considers long dead (T10a) |
| 15 | Clock skew, mtime −600 s / −7200 s | `touch -d '10 minutes ago'` / `'2 hours ago'` [scripts/github-app-refresh.sh:74-75] | `3600-age` exactly | 2026-11-05 | **PASS**: `~3000s` and `~-3600s` (T10b/T10c — the negative is unreachable in production, see §6 note) |
| 16 | Node mode, no bunker | `env -i PATH=/usr/bin:/bin bash refresh --node cf-node --server b-01` [scripts/github-app-refresh.sh:118-119] | FAIL `bunker_cli`, exit 1 | 2026-11-05 | **PASS** (T18) |
| 17 | Node mode, unknown agent | stub `bunker info` → rc 1 [scripts/github-app-refresh.sh:120-122] | FAIL `agent`, exit 1, no mint | 2026-11-05 | **PASS** (T12) |
| 18 | Node mode, `cp` fails | stub `bunker cp` → rc 1 [scripts/github-app-refresh.sh:128-144] | FAIL `refresh ... keeps its remaining life`, exit 1, temp removed | 2026-11-05 | **PASS** (T13) |
| 19 | Node mode, remote `exec` fails | stub `bunker exec` → rc 1 [scripts/github-app-refresh.sh:129-143] | same FAIL row, exit 1, temp removed | 2026-11-05 | **PASS** (T14) |
| 20 | Node mode, happy path | stubs return rc 0 [scripts/github-app-refresh.sh:128-140] | PASS `refresh`, exit 0, `token mode 600` relayed | 2026-11-05 | **PASS** (T15) |
| 21 | Node dry run is not inert | `--node cf-node --server b-01 --dry-run` with `bunker info` failing [scripts/github-app-refresh.sh:120-125] | the dry-run note should survive a probe failure | 2026-11-05 | **DEFECT CONFIRMED**: exits 1 at `FAIL agent` **before** reaching the dry-run note (T12 vs T16) |
| 22 | No token on any stream | sentinel `ghs_SENTINELnotarealtoken0000` in the stub token file, every probe transcript grepped [scripts/github-app-refresh.sh:19] | zero hits | 2026-11-05 | **PASS**: 0 hits in `t1.log`, `t2.log`, `t3.log`; the sentinel appears only inside the token files themselves |
| 23 | Temp-file hygiene | `ls -A $TMPDIR` after all node-mode runs [scripts/github-app-refresh.sh:143-145] | empty | 2026-11-05 | **PASS**: empty |
| 24 | `--local` beats `--node` | `bash refresh --local --node cf-node --server b-01` [scripts/github-app-refresh.sh:92] | local arm runs, no bunker call | 2026-11-05 | **PASS** (T17) |

```
$ shellcheck -S style scripts/github-app-refresh.sh
In scripts/github-app-refresh.sh line 86:
  MINT_ROWS="$out"
  ^-------^ SC2034 (warning): MINT_ROWS appears unused.
In scripts/github-app-refresh.sh line 129:
   "$b" exec --server "$SERVER" "$NODE" -- bash -lc '
                                                    ^-- SC2016 (info): Expressions don't expand in single quotes
rc=1

$ MOCK=ok bash bin/github-app-refresh.sh --local                 # T2, fresh mint
github-app-refresh — local: .../home/.config/code-factory/github.token (min-age 2400s)
    PASS  token — .../github.token, mode 600, expires 2026-11-05T18:00:00Z
  GITHUB APP TOKEN: PASS — minted a 3600s token (value never printed)
  ..    refreshed .../home/.git-credentials (mode 600)
  PASS  refresh — .../github.token refreshed, ~3600s of life left (a fresh token is valid 3600s)
exit=0
token file mode: 600   creds mode: 600   creds line count: 1

$ MOCK=skip bash bin/github-app-refresh.sh --local              # T3, young token
  PASS  refresh — (no-op) .../github.token is still valid, ~3600s left; nothing rewritten
exit=0
token mtime unchanged by skip: yes

$ MOCK=mode644 bash bin/github-app-refresh.sh --local --token-file .../m644.token   # T4
    PASS  token — .../m644.token, mode 644, expires 2026-11-05T18:00:00Z
  GITHUB APP TOKEN: PASS — minted a 3600s token (value never printed)
  FAIL  mode — .../m644.token is mode 644, expected 600
  ..    refreshed .../home/.git-credentials (mode 600)
  PASS  refresh — .../m644.token refreshed, ~3600s of life left (a fresh token is valid 3600s)
exit=0
m644 mode: 644

$ MOCK=fail bash bin/github-app-refresh.sh --local              # T5, mint failure
  FAIL  private_key — /nonexistent/github-app.private-key.pem is absent
  GITHUB APP TOKEN: FAIL (1) — nothing written
  FAIL  refresh — could not mint into .../github.token — the existing token keeps its remaining life
exit=1
old token intact: OLDTOKEN        old token mtime unchanged: yes

$ python3 scripts/github-app-token.py token --env-file <fake> --if-older 2400 --out <t>   # R1
  FAIL  private_key_file — .../absent.pem does not exist — move the downloaded .pem there

GITHUB APP TOKEN: FAIL (1) — nothing written
exit=1   tok written: no

$ (token file written now, same command)                        # R2
  SKIP  token — .../tok is 0s old (< 2400s), still valid
GITHUB APP TOKEN: SKIP — nothing to do
exit=0   tok mode: 600   tok content: placeholder

$ touch -d '+1 hour' <token>; MOCK=skip bash ... --local        # T10a
  PASS  refresh — (no-op) .../github.token is still valid, ~3600s left; nothing rewritten
$ touch -d '2 hours ago' <token>; MOCK=skip bash ... --local    # T10c
  PASS  refresh — (no-op) .../github.token is still valid, ~-3600s left; nothing rewritten

$ MOCK=ok bash bin/github-app-refresh.sh --node cf-node --server b-01   # T15, stubbed client
github-app-refresh — node: cf-node on b-01 (min-age 2400s)
    PASS  token — /tmp/tmp.p61LoXa11B, mode 600, expires 2026-11-05T18:00:00Z
  GITHUB APP TOKEN: PASS — minted a 3600s token (value never printed)
  ..    token mode 600
  PASS  refresh — cf-node:/home/kara/.hermes/cache/scratch/md32/probe/home/.node/auth/github.token replaced (mode 600), git credential store repointed
exit=0   temp leftovers in TMPDIR: (none)

$ MOCK_BUNKER=execfail MOCK=ok bash ... --node cf-node --server b-01   # T14
  ..    exec: remote command failed
  FAIL  refresh — could not install the token into cf-node — its current token keeps its remaining life
exit=1

$ MOCK_BUNKER=noinfo MOCK=ok bash ... --node cf-node --server b-01 --dry-run   # T12/T21
  FAIL  agent — cf-node not found on b-01 (bunker info failed)
exit=1

$ MOCK=ok bash bin/github-app-refresh.sh --local --min-age abc  # T6
--min-age must be a number of seconds
exit=2
```

## 4. Metrics emitted

**NONE — and the reason is structural, not an omission.** The file has one output path: the four printers from `lib.sh` write to stdout [scripts/lib.sh:5-9]. There is no counter, no `--json`, no status file, no socket, no timer-heartbeat write, and no `curl` (`grep -c curl scripts/github-app-refresh.sh` = 0). The only numbers on stdout are the two derived ones — `~${left}s of life left` [scripts/github-app-refresh.sh:111-112] and the remote `token mode %s` [scripts/github-app-refresh.sh:138] — and neither is a metric: `left` is `3600 - mtime_age` computed at print time [scripts/github-app-refresh.sh:72-76], and the mode line is a one-shot readback. The machine-readable surface is therefore just the process exit code, `0` / `1` / `2` [scripts/github-app-refresh.sh:50-53], and §3 row 5 is the case where that surface disagrees with the printed rows: `FAIL mode` is emitted and `0` is returned. An operator asking "is refreshing healthy across the fleet?" has nothing to aggregate — only journal lines per host.

## 5. Log lines it can generate

Level is the row the line arrives as; `say` lines carry no prefix, `ok` prints `  PASS  <key> — <text>`, `bad` prints `  FAIL  <key> — <text>`, `note` prints `  ..    <text>` [scripts/lib.sh:5-9]. Lines the minter prints are relayed locally with a two-space indent [scripts/github-app-refresh.sh:85] and remotely with `  ..    ` [scripts/github-app-refresh.sh:139].

| Level | Line (verbatim) | Emitted when | Kind |
|---|---|---|---|
| say | `github-app-refresh — local: %s (min-age %ss)` [scripts/github-app-refresh.sh:93] | local arm starts; suppressed by `--quiet` [scripts/github-app-refresh.sh:55] | descriptive |
| say | `github-app-refresh — node: %s on %s (min-age %ss)` [scripts/github-app-refresh.sh:117] | node arm starts; suppressed by `--quiet` | descriptive |
| PASS | `  PASS  refresh — %s refreshed, ~%ss of life left (a fresh token is valid 3600s)` [scripts/github-app-refresh.sh:112] | local arm believes the minter wrote a token | **evidentiary for the write, not for the token**: the same row is printed when the minter wrote nothing but worded its skip differently (§3 T21b) |
| PASS | `  PASS  refresh — (no-op) %s is still valid, ~%ss left; nothing rewritten` [scripts/github-app-refresh.sh:98] | the minter's stdout contained `GITHUB APP TOKEN: SKIP` [scripts/github-app-refresh.sh:87] | **evidentiary**: only reachable when no write happened; measured with an unchanged mtime (§3 T3) |
| PASS | `  PASS  refresh — %s:%s replaced (mode 600), git credential store repointed` [scripts/github-app-refresh.sh:140] | `bunker cp` **and** the remote script both returned 0 | descriptive of intent: the `(mode 600)` is a hard-coded string in the message, not a readback; the readback is the separate `token mode` line |
| FAIL | `  FAIL  env_file — %s absent — run scripts/github-app-setup.sh --apply once` [scripts/github-app-refresh.sh:57] | env file missing | evidentiary |
| FAIL | `  FAIL  python3 — python3 is required to sign the App JWT` [scripts/github-app-refresh.sh:60] | no `python3` on `PATH` | evidentiary |
| FAIL | `  FAIL  minter — %s is missing` [scripts/github-app-refresh.sh:61] | `github-app-token.py` unreadable beside this script | evidentiary |
| FAIL | `  FAIL  server — --node needs --server (which bunker host the agent lives on)` [scripts/github-app-refresh.sh:64] | `--node` given alone; exit 2 | evidentiary |
| FAIL | `  FAIL  refresh — could not mint into %s — the existing token keeps its remaining life` [scripts/github-app-refresh.sh:95] | local mint returned nonzero | **evidentiary**: the old file's bytes and mtime were measured unchanged (§3 T5) |
| FAIL | `  FAIL  mode — %s is mode %s, expected 600` [scripts/github-app-refresh.sh:102] | the written token is not 0600 | **evidentiary, and not fatal**: the script continues and exits 0 (§3 T4) |
| FAIL | `  FAIL  bunker_cli — the bunker client is not on PATH` [scripts/github-app-refresh.sh:119] | node mode, no `bunker` | evidentiary |
| FAIL | `  FAIL  agent — %s not found on %s (bunker info failed)` [scripts/github-app-refresh.sh:121] | node mode, `bunker info` nonzero | evidentiary |
| FAIL | `  FAIL  refresh — could not mint — the node keeps its current token` [scripts/github-app-refresh.sh:126] | node mode, mint failed before upload | evidentiary |
| FAIL | `  FAIL  refresh — could not install the token into %s — its current token keeps its remaining life` [scripts/github-app-refresh.sh:142] | `cp` or the remote script failed; exit 1 | evidentiary |
| note | `  ..    dry run: no mint, no write` [scripts/github-app-refresh.sh:94] | `--local --dry-run` | descriptive |
| note | `  ..    dry run: would mint and install into %s:%s/.node/auth/github.token` [scripts/github-app-refresh.sh:125] | `--node … --dry-run` **after** the `bunker info` probe passed | descriptive; also the line that proves the dry run is not inert (§3 T21) |
| note | `  ..    refreshed %s (mode 600)` [scripts/github-app-refresh.sh:109] | a pre-existing `~/.git-credentials` was rewritten | evidentiary |
| say | `--min-age must be a number of seconds` [scripts/github-app-refresh.sh:53] | non-numeric `--min-age`; exit 2, no FAIL row | evidentiary |
| relay | `  SKIP  token — %s is %ds old (< %ds), still valid` [scripts/github-app-token.py:586] | minter decided the file is younger than `--min-age` | **evidentiary**: this exact substring is what the caller keys on [scripts/github-app-refresh.sh:87] |
| relay | `GITHUB APP TOKEN: PASS — minted a %ds token (value never printed)` [scripts/github-app-token.py:617] | a token was minted and written | evidentiary |
| relay | `GITHUB APP TOKEN: FAIL (1) — nothing written` [scripts/github-app-token.py:602] | mint refused; the refresh turns it into `FAIL refresh` + exit 1 | evidentiary |
| relay (node) | `token mode %s` [scripts/github-app-refresh.sh:138] | the node-side script ran `chmod 600` and then measured the file | **evidentiary for the node install**, and the only line that does so |

## 6. Failure modes

Direction vocabulary: **closed** = refuses, names the cause, exits nonzero and writes nothing; **open** = prints a FAIL or a PASS and still exits 0; **late-open** = the failure is invisible until the credential dies hours later elsewhere.

| Failure | Presents as | Distinguished from | Recovery | Direction |
|---|---|---|---|---|
| Env file absent or unreadable | `FAIL env_file — … absent — run scripts/github-app-setup.sh --apply once`, exit 1, nothing written [scripts/github-app-refresh.sh:57] | an App-level problem: this row appears before any key or network use | `scripts/github-app-setup.sh --apply` once, then re-run the tick | **closed** |
| Private key absent, world-readable, or not RSA | minter's own named rows (`FAIL private_key_file …`, `FAIL private_key …`) relayed under `FAIL refresh`, exit 1; old token keeps its remaining life [scripts/github-app-refresh.sh:95] [scripts/github-app-token.py:592-602] | a revoked App or a dead network, which reach the same exit code with a different minter row | fix the key path in the env file; nothing to clean up | **closed** |
| App revoked, installation removed, or the API answers 401 | one `FAIL refresh` row and exit 1; the timer retries every 20 minutes forever and the node's token dies at its own hour [scripts/github-app-refresh.sh:95] | nothing inside this script: **every** minter failure collapses into the same single row — the differentiating detail exists only in the minter's own stdout line above it | re-install the App and re-run `--local`, then the node tick | **closed, undiagnosed** |
| **Token written at a mode other than 600** | `FAIL mode — … is mode 644, expected 600` **followed by a credential-store rewrite and exit 0** [scripts/github-app-refresh.sh:101-113] | a mint failure, which exits 1 — the mode row is the only FAIL that does not | `chmod 600` the file by hand; nothing in the script will do it, and the timer reports success until the next real failure | **open** (measured, §3 T4) |
| Clock wrong, running behind (or a restored/touched token file) | new mtime looks younger than the token really is; the minter skips while `age < if_older` [scripts/github-app-token.py:582-584], `life_left` clamps the negative age to 0 [scripts/github-app-refresh.sh:74] and prints `~3600s left`; nothing re-mints | a genuine fresh mint: both print a PASS row, and only the file's own mtime differs | correct the clock, then `--min-age 1` once to force a mint | **late-open**: the token expires on GitHub's clock, and the first symptom is 401 at the next push |
| Clock wrong, running ahead | every tick sees an over-age file and mints; extra API calls only [scripts/github-app-token.py:584] | nothing — this direction is harmless | fix the clock | **closed by accident** |
| Node unreachable, or `bunker cp` / remote script nonzero | `FAIL refresh — could not install the token into <node> — its current token keeps its remaining life`, exit 1, temp file removed [scripts/github-app-refresh.sh:128-145] | a mint failure, which fails *before* any upload and says `could not mint` [scripts/github-app-refresh.sh:126] | re-run the tick; the node keeps working until its current token's hour is out | **closed**, with an hour of grace |
| No refresh timer armed on the host | nothing at all: no row, exit 0, work stops 3600 s after provisioning with 401s that read as permissions problems | a revoked App, by timing alone (revocation bites at the next tick, this bites exactly one hour after a green provisioning) | arm the timer the header describes [scripts/github-app-refresh.sh:15-17]; the setup check already warns when it is missing [scripts/github-app-setup.sh:197-201] | **late-open, silent** |
| `--token-file` not passed while the env file names another `GITHUB_APP_TOKEN_FILE` | the default path is written and the env-declared path is not (measured §3 T19); two token files, the refreshed one possibly unused [scripts/github-app-refresh.sh:58] | a skipped refresh: here the mtime moves on the wrong file | pass `--token-file` explicitly, or keep the env file's value equal to the default | **open** (measured) |
| Minter renames its `SKIP` banner | an untouched file is reported as `refreshed, ~Ns of life left` [scripts/github-app-refresh.sh:87] [scripts/github-app-refresh.sh:112] | a real refresh: identical row, and the mtime is the only tell | pin the banner with a test, or key on exit status + mtime instead of text | **open** (measured, §3 T21b) |
| `--node … --dry-run` on a host where the agent is unreachable | exit 1 at `FAIL agent` **before** the dry-run note, so the operator learns nothing about what would have happened [scripts/github-app-refresh.sh:120-125] | a working dry run, which returns 0 and prints the note | run the dry run against a reachable node | **closed but misleading** (measured, §3 T21) |
| Temp file left behind | none observed: every path removes it [scripts/github-app-refresh.sh:126] [scripts/github-app-refresh.sh:143] [scripts/github-app-refresh.sh:145] | — | — | **closed** (measured: `TMPDIR` empty after all runs) |

Two honesty notes on the table. (1) `~-3600s of life left` (T10c) is reachable only in the harness: a production run cannot reach the no-op branch with a file that old, because the minter only skips while `age < if_older` [scripts/github-app-token.py:584]. It is a cosmetic arithmetic gap, not a filed defect. (2) The **node-side** body — `umask 077`, the 0700 directories, the `chmod 600`, the credential rewrite and `git config --global credential.helper store` [scripts/github-app-refresh.sh:131-137] — was **not executed here**: no node was touched. Its *seam* was measured in both directions (T13/T14 fail, T15 pass), its body is read-from-code, and that is the residual gap in this section.

## 7. Environment and settings it reads

### 7a. Files

| Path | Read / Write | Mode | Where set | Notes |
|---|---|---|---|---|
| `$HERE/lib.sh` | read (sourced) | as shipped | [scripts/github-app-refresh.sh:22] | four printers, `have`, `FAILED` [scripts/lib.sh:5-13] |
| `$HERE/github-app-token.py` | read (executed) | `-r` only | [scripts/github-app-refresh.sh:61] | the only component that talks to GitHub |
| `$GITHUB_APP_ENV_FILE` → `$HOME/.config/code-factory/github-app.env` | read | must exist (`-f`); **this script checks no mode** — the setup script is what requires 600 [scripts/github-app-setup.sh:180-183] | [scripts/github-app-refresh.sh:24] | pointers, no secret [scripts/github-app-token.py:20-26] |
| `$TOKEN_FILE` → `$HOME/.config/code-factory/github.token` | **write** (by the minter) + read for mtime and non-emptiness | **600**, written atomically and `chmod`ed by `write_private` [scripts/github-app-token.py:636-653]; this script *checks* 600 and does not enforce it [scripts/github-app-refresh.sh:101-102] | [scripts/github-app-refresh.sh:58], overridable with `--token-file` | parent directory is created by the minter if missing [scripts/github-app-token.py:638-641] |
| `$GIT_CREDENTIALS` → `$HOME/.git-credentials` | rewritten **only if it already exists**; read for the token value | temp file created 600 [scripts/github-app-refresh.sh:106], then `mv` + `chmod 600` [scripts/github-app-refresh.sh:108] | [scripts/github-app-refresh.sh:29] [scripts/github-app-refresh.sh:105-110] | one line per refresh; a host that uses no store never gets one created (measured §3 T9) |
| a `mktemp` file under `$TMPDIR` | write, then delete | 600 by `chmod` and by `mktemp` [scripts/github-app-refresh.sh:106] [scripts/github-app-refresh.sh:124] | node mode only | removed on success and on every failure branch [scripts/github-app-refresh.sh:126] [scripts/github-app-refresh.sh:143] [scripts/github-app-refresh.sh:145] |
| node `$HOME/cf-github.token` → `$HOME/.node/auth/github.token` | write on the node | `umask 077`, `chmod 600` | remote script [scripts/github-app-refresh.sh:131-134] | read back and printed as `token mode %s` [scripts/github-app-refresh.sh:138] |
| node `$HOME/.node`, `$HOME/.node/auth` | created on the node | 700 | [scripts/github-app-refresh.sh:131] | `|| true` — a failing chmod there does not abort [scripts/github-app-refresh.sh:131] |
| node `$HOME/.git-credentials` | written on the node | 600 | [scripts/github-app-refresh.sh:135-136] | the same format string as the local path |
| node `~/.gitconfig` | written on the node (`git config --global`) | git's own | [scripts/github-app-refresh.sh:137] | points the store helper at the file above |

Nothing else is read or written: the file contains no other redirection, no config parse, and no `.netrc`, `.ssh` or key path of its own — the private key is read only by the minter, from the path the env file names [scripts/github-app-token.py:326-350].

### 7b. Environment variables and flags

| Variable | Default | Effect if unset |
|---|---|---|
| `GITHUB_APP_ENV_FILE` | `$HOME/.config/code-factory/github-app.env` [scripts/github-app-refresh.sh:24] | the default is used; if that is also absent the run refuses with exit 1 [scripts/github-app-refresh.sh:57] |
| `GITHUB_API_BASE` | empty [scripts/github-app-refresh.sh:33] | no `--api-base` is forwarded, so the minter uses github.com [scripts/github-app-refresh.sh:68] — this is the knob for a GitHub Enterprise host |
| `HOME` | required by the shell | both default paths become `/.config/...`; the env-file check fails first and exits 1 [scripts/github-app-refresh.sh:57] |
| `TMPDIR` | system default | `mktemp` chooses the temp location for the node-mode upload [scripts/github-app-refresh.sh:124] |
| `PATH` | — | `python3` and `bunker` are resolved through it [scripts/github-app-refresh.sh:59] [scripts/github-app-refresh.sh:118] |
| `GITHUB_APP_TOKEN_FILE` | **not read here** — measured §3 T19: an env-declared token path was ignored and the default was written | the default path always wins unless `--token-file` is passed [scripts/github-app-refresh.sh:58]; note the setup script *does* honour it [scripts/github-app-setup.sh:33] |

| Flag | Default | Meaning | Anchor |
|---|---|---|---|
| `--env-file P` | see above | App env file | [scripts/github-app-refresh.sh:39] |
| `--token-file P` | `$HOME/.config/code-factory/github.token` | local destination | [scripts/github-app-refresh.sh:40] |
| `--node A` / `--server H` | empty | node mode; `--node` alone is exit 2 | [scripts/github-app-refresh.sh:41-42] [scripts/github-app-refresh.sh:63-65] |
| `--min-age N` | `2400` | seconds a token may age before a re-mint; non-numeric is exit 2 | [scripts/github-app-refresh.sh:28] [scripts/github-app-refresh.sh:53] |
| `--git-credentials P` | `$HOME/.git-credentials` | the store rewritten when present | [scripts/github-app-refresh.sh:29] [scripts/github-app-refresh.sh:44] |
| `--api-base U` | `$GITHUB_API_BASE` | forwarded to the minter only | [scripts/github-app-refresh.sh:33] [scripts/github-app-refresh.sh:45] [scripts/github-app-refresh.sh:68] |
| `--local` | — | force the local arm; wins over `--node` (measured §3 T17) | [scripts/github-app-refresh.sh:46] [scripts/github-app-refresh.sh:92] |
| `--dry-run` | off | no mint, no write; **still probes the node first** in node mode | [scripts/github-app-refresh.sh:47] [scripts/github-app-refresh.sh:94] [scripts/github-app-refresh.sh:125] |
| `--quiet` | off | suppress the two `say` banner lines only | [scripts/github-app-refresh.sh:48] [scripts/github-app-refresh.sh:55] |
| `-h` / `--help` | — | prints lines 2-24 of the file itself, minus the `# ` prefix, exit 0 | [scripts/github-app-refresh.sh:35] |
| anything else | — | `unknown argument: …` then usage, exit 2 | [scripts/github-app-refresh.sh:50] |

## 8. Evidence of record

- **Revision under test:** `dad2749` (worktree `wt/md-28e`). `scripts/github-app-refresh.sh` is byte-identical to `origin/main` (`6eea792`), sha256 `b4d5d4d4d72c8cca467bbd1e4fa4ad0b102988be6f093a59c3435072a8b3e636`.
- **Method:** the script and `scripts/lib.sh` were copied byte-for-byte into `/home/kara/.hermes/cache/scratch/md32/probe/bin/`, with a **stub** `github-app-token.py` (sha256 `2a44897c4da0c3345527611d365a9b8a5eca1d9bc82c26c27666a8af1dc4fa40`) and a **stub** `bunker` (sha256 `3ebde3ef9e5f7e535b01408a799b0b11a7bafc1f8653c53347d847f5a03a9be1`) beside it. Every run used `env -i` with a scratch `HOME` and `TMPDIR` under the probe directory. R1-R3 are the **only** runs of the real minter, and each stops at the key check or at the mtime skip — no JWT is signed, no request is made, no token is minted.
- **Probe scripts and transcripts** (all under `/home/kara/.hermes/cache/scratch/md32/probe/`):
  - `run.sh` sha256 `1d6d35342ee8fb610d3e24f40ed3d770525829c316b16cbe2b75b9db764783e1` → `t1.log` sha256 `eb261a32105b698d6edf79e537653e9b5ba126afa80abde77fa7a3dc98eec222` (T1-T17)
  - `run2.sh` sha256 `4757404bd623504b43aa057f13c3cc77cc9ace606869843dab25e47864a9a0f9` → `t2.log` sha256 `76321750dfab21c5592bf14a83159629767a99d5d41295dc134028e8eba821a7` (T18-T20: no-bunker PATH, env-declared token path ignored, sentinel census)
  - `run3.sh` sha256 `0852d48c260eccabc5dd59bcd873883de13e5d47d262da057b3375981864e92e` → `t3.log` sha256 `ddaff0cdd7dc13f5b217b88588173aa3320f6871d5dd0df63044adee99970e44` (R1-R3: real minter, both terminal directions)
  - T21b (skip-banner coupling) was run inline: a stub whose only change is the banner text `GITHUB APP TOKEN: NOTHING-TO-DO — the file is young, no write`, against a token file aged 10 minutes. Output `PASS refresh — … refreshed, ~3000s of life left`, exit 0, and `stat` still showed the pre-run mtime.
- **Environment measured on:** bash 5.3.9, Python 3.14.4, `stat` from uutils coreutils 0.8.0, `shellcheck` at `/usr/bin/shellcheck`.
- **What was deliberately NOT touched:** no GitHub App, no network call, no live installation token (the only token-shaped bytes anywhere were the sentinel string `ghs_SENTINELnotarealtoken0000`, which the census found **zero** times in any transcript — only inside the two token files the stub wrote), no bunker node, no systemd unit, and no file on this host outside the probe directory. The repository worktree was not modified except for this document.
- **Board / fact ledger:** the environment facts this module leans on are `FACT-01` (the foreman runs on the node), `FACT-02` (one bunker serves one project's every lane) and `FACT-05` (credentials travel as file paths at mode 600, never as argv) [docs/master/_facts.md:12] [docs/master/_facts.md:13] [docs/master/_facts.md:16].
- **Coverage boundary:** local mode is verified end-to-end with the stub; the node-mode *seam* is verified in both directions (T13/T14/T15), but the node-side script body [scripts/github-app-refresh.sh:131-137] was not executed on a real node — it is read-from-code, and the `(mode 600)` in the outer PASS row is a hard-coded string, whereas the trustworthy readback is the relayed `token mode %s` line [scripts/github-app-refresh.sh:138].
