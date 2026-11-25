# 05. scripts/bunker-provision.sh

| Field | Value |
|---|---|
| Path | `~/code-factory/scripts/bunker-provision.sh` [scripts/bunker-provision.sh:1] |
| Repository | `code-factory` [scripts/bunker-provision.sh:1] |
| Revision | `965fad01` — CF-537 (chat-gateway merge), the last commit touching this file, on `main`; blob `4d1fde78`, sha256 prefix `92d196f4d6965a07` [scripts/bunker-provision.sh:1]. The row was filed against the CF-366 close commit `d7f07455` (blob `301f7410`); CF-537 landed mid-tick and this unit is derived at the current blob, which contains CF-366 |
| Status | **VERIFIED — 367 locator references (256 distinct path:line pairs, counted as every bracketed path:line token in this file), re-run 2026-11-25, fact: FACT-05** |

## 1. Purpose and why it matters

- What it does: provisions exactly ONE project's bunker from a `KEY=VALUE` config file, with command-line overrides, in three modes — `--check`, `--apply`, `--destroy` [scripts/bunker-provision.sh:2-7].
- The config file is treated as DATA and is never sourced: a non-comment line must match `^([A-Z_][A-Z0-9_]*)=(.*)$` or the run is refused [scripts/bunker-provision.sh:9-10] [scripts/bunker-provision.sh:150-153]. A stray shell line therefore cannot execute [tests/selftest.sh:3336-3344].
- What breaks if this module is absent: nothing else in the repository turns a project + repo + harness triple into a working node, and the file's own header states the consequence of the hand path — a node's environment becomes "hand-edited state that cannot be diffed or re-applied" [scripts/bunker-provision.sh:32-35], and a node with a harness and no declared procedure is "a node whose foreman reports 'this run's tools are on the host'" [scripts/bunker-provision.sh:655-658].
- What breaks if it lies — four false reports are recorded in this file's own comments, each fixed: the inlined probe shipped literal backslashes and "reported a fully provisioned node as empty — a false negative that would have sent an operator to re-provision" [scripts/bunker-provision.sh:332-334]; a curl-only bus probe "reported a wired node as not connected" because a hardened bus checks the signature before the agent [scripts/bunker-provision.sh:419-421]; five documented flags were "silently ignored whenever a config was also passed" [scripts/bunker-provision.sh:1069-1071]; and a quoted `~/` in a path flag "silently reads as the literal string and the leg is skipped" (CF-262) [scripts/bunker-provision.sh:102-105].
- A lying run is not hypothetical, and its direction was measured rather than assumed: with `scripts/lib.sh` ABSENT the script refuses before parsing arguments — `  FAIL  lib.sh — missing or unreadable: <path>`, exit **1** [scripts/bunker-provision.sh:66-69], and a library that exists but fails to source is refused the same way [scripts/bunker-provision.sh:70-73] — measured, §8. The residual risk of a library is therefore **rows, not exit status**: the library is what names every row and what increments `FAILED`, so the same run against a PRESENT library whose `bad` does not increment prints its FAIL rows, then `BUNKER: PASS — every row above measured`, and exits **0** [scripts/lib.sh:7] [scripts/bunker-provision.sh:466-467] — also measured, §8; drop only the `FAILED` initialisation and the first `bad()` call aborts under `set -u` with `FAILED: unbound variable`, exit **1** [scripts/lib.sh:11] [scripts/bunker-provision.sh:63] — measured, §8.
- Idempotence is a stated contract: an existing agent is reused, an existing clone fast-forwarded, `node.json` rewritten only on a difference [scripts/bunker-provision.sh:49-51] [scripts/bunker-provision.sh:518-519] [scripts/bunker-provision.sh:765-766].
- Since CF-537 (`965fad01`, M13 §4): `--check` grades the sibling `<project>.gateways.json` of the provision config read-only — parseable, §3-shaped, token-free — and `--apply` merges its `platforms` + `gateways` blocks into the node's `~/.hermes/config.yaml` at provision and at every re-sync, byte-idempotently [scripts/bunker-provision.sh:397-417] [scripts/bunker-provision.sh:708-749]. No artifact is a scheduler-only lane: one note, node config untouched (M13 R3) [scripts/bunker-provision.sh:407] [scripts/bunker-provision.sh:723].

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `bash` (arrays, `printf -v`, process substitution) | no version check; the shebang is the contract [scripts/bunker-provision.sh:1] | the interpreter exec'd by the shebang | the kernel refusing exec; nothing inside the script checks it |
| `bunker` client | no version check; resolved once by `have bunker` [scripts/bunker-provision.sh:295-298] | `PATH` on the control host | `have` returns empty → `  FAIL  bunker_cli — no bunker client on PATH`, exit 1 [scripts/bunker-provision.sh:296] |
| `curl` | no version check [scripts/bunker-provision.sh:455] [scripts/bunker-provision.sh:834] | `PATH` | the probe's `${code:-000}` substitutes `000`, which no accepted case matches, so the row is a named FAIL [scripts/bunker-provision.sh:455-459]; the destroy bus probe degrades the same way [scripts/bunker-provision.sh:838] |
| `python3` | no version check [scripts/bunker-provision.sh:194] | `PATH` on the control host AND on the node | control host: rc 127 lands in the catch-all → `  FAIL  env_profile — node_env.py --check exited 127 on the declaration` [scripts/bunker-provision.sh:199]; node: the seeder's exit drives `  FAIL  node_seed — apply exited <rc> on the node` [scripts/bunker-provision.sh:670-674]; app mode also calls `github-app-token.py check`/`token` on the control host [scripts/bunker-provision.sh:274] [scripts/bunker-provision.sh:535] |
| `base64` | no version check [scripts/bunker-provision.sh:476] | `PATH` on the control host | the `agentkey_b64=` bundle line is missing, the node-side key never lands, and `--check` prints `  FAIL  crier_key — no $HOME/.node/agent.key` [scripts/bunker-provision.sh:372-373] |
| `timeout` (coreutils) | no version check [scripts/bunker-provision.sh:301] | `PATH` | the pipeline collapses, and because three probe call sites carry `|| true` the row degrades to a FAIL or an empty measurement rather than stopping the run [scripts/bunker-provision.sh:355-356] [scripts/bunker-provision.sh:425] |
| coreutils text tools (`sed`, `awk`, `grep`, `head`, `tail`, `tr`, `stat`, `mktemp`) | no version check [scripts/bunker-provision.sh:98] [scripts/bunker-provision.sh:350] [scripts/bunker-provision.sh:573] | `PATH` on both sides | each is unguarded; the affected row prints with an empty measured value and the `FAILED` tally is untouched — §6 |
| `git` | no version check; invoked inside the node probe [scripts/bunker-provision.sh:340-342] and for the clone itself, `git clone --depth 1 --branch "$REF"` [scripts/project-node.sh:1066], which `node-create.sh` runs on the node [scripts/node-create.sh:465-466] | on the node | the probe prints `sha=` and `branch=` empty while `repo=present` still matches, so the row reads `clone present () branch , 0 dirty` [scripts/bunker-provision.sh:364] |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `. "$HERE/lib.sh"` (sourced, not a package; a missing or unsourced library is refused before argument parsing) [scripts/bunker-provision.sh:66-73] | `scripts/lib.sh` | five printers — `say`, `ok`, `bad`, `warn`, `note` [scripts/lib.sh:5-9] — plus `have` [scripts/lib.sh:41-45] and `shq` [scripts/lib.sh:99-102]; `bad()` is the ONLY thing that increments `FAILED` [scripts/lib.sh:7], `warn()` counts `WARNED` [scripts/lib.sh:8] (a tally this script never reads), `have` prints the resolved path and exits non-zero on absence (CF-281) [scripts/lib.sh:41-45], and `FAILED` is initialised by the library, not by the caller [scripts/lib.sh:11] | three measured directions, and they are not the same one: an ABSENT `lib.sh` is a named refusal — `  FAIL  lib.sh — missing or unreadable: <path>`, exit **1** [scripts/bunker-provision.sh:66-69] — while a PRESENT library whose `bad` prints but does not increment `FAILED` prints every FAIL row and then still reaches `BUNKER: PASS — every row above measured` with exit **0** [scripts/lib.sh:7] [scripts/bunker-provision.sh:466-467]; drop only the `FAILED` initialisation and the first `bad()` call aborts under `set -u` with `FAILED: unbound variable`, exit **1** [scripts/lib.sh:11] [scripts/bunker-provision.sh:63] — all three measured, §8 |
| `python3 "$HERE/node_env.py" --check` [scripts/bunker-provision.sh:194] | `scripts/node_env.py` | a three-way exit contract: 0 and 1 both mean "the declaration parses" (1 = drift from an empty home), 2 is a refusal whose first `FAIL` line is quoted into the row, anything else is an unexpected exit [scripts/bunker-provision.sh:196-200] | a new exit code becomes `  FAIL  env_profile — node_env.py --check exited <rc> on the declaration`, and a shifted meaning of 1 would turn drift into a pass [scripts/bunker-provision.sh:197-199] |
| `python3 "$HERE/node_seed.py" build` / `apply` [scripts/bunker-provision.sh:663] [scripts/bunker-provision.sh:668-669] | `scripts/node_seed.py` | `build` writes `seed.tar` + `seed.tar.json` into the out dir and refuses a file outside the manifest, over budget, or digest-mismatched; `apply` exits 0 only when the node accepted the seed [scripts/bunker-provision.sh:655-659] | a build refusal prints `  FAIL  node_seed — build refused the declared seed` plus the first five log lines [scripts/bunker-provision.sh:680-682]; an apply refusal prints the node's exit code [scripts/bunker-provision.sh:673] |
| `python3 "$HERE/node_identity.py" <json> k=v ...` [scripts/bunker-provision.sh:772-773] | `scripts/node_identity.py` | MERGE semantics: the file's schema is owned elsewhere, so a wholesale rewrite would delete `node_id`/`repo`/`harness`/`bus` [scripts/bunker-provision.sh:765-766] | a schema change surfaces as `  FAIL  node_json — merge refused by the node (exit <rc>)` [scripts/bunker-provision.sh:779] |
| `python3 "$HERE/node_gateway_auth.py"` [scripts/bunker-provision.sh:695-696] | `scripts/node_gateway_auth.py` | exit 0 means `dashboard.basic_auth` is present in `config.yaml`; the password stays on the node [scripts/bunker-provision.sh:699-700] | the row becomes `  FAIL  gateway_auth — could not ensure dashboard.basic_auth (exit <rc>)` and `rc=1` [scripts/bunker-provision.sh:700] |
| `python3 "$HERE/node_gateways_merge.py" --validate` / `--apply` [scripts/bunker-provision.sh:409] [scripts/bunker-provision.sh:727] [scripts/bunker-provision.sh:733] | `scripts/node_gateways_merge.py` | `--validate` grades the sibling artifact read-only (parseable, M13 §3 shape, token-free R2) and prints `gateway_platforms=`; the node-side `--apply` merges the `platforms` + `gateways` blocks into `~/.hermes/config.yaml` byte-idempotently, validates again inside the node, and prints `gateway_unresolved=` when a `token_env` has no value (M13 §5: warning, not fatal) [scripts/bunker-provision.sh:708-716] | a refused artifact before staging is `  FAIL  gateways — artifact refused before anything was staged` and `rc=1` [scripts/bunker-provision.sh:727-729]; a non-zero merge exit is `  FAIL  gateways — the merge exited <rc> on the node` with config.yaml left consistent (writes are atomic) [scripts/bunker-provision.sh:735-736] |
| `"$HERE/bunker-crier-connect.sh" --check` / `--stage` / `--apply` [scripts/bunker-provision.sh:425] [scripts/bunker-provision.sh:610] [scripts/bunker-provision.sh:790] | `scripts/bunker-crier-connect.sh` | the sentinel string `CRIER: CONNECTED` in stdout is the pass signal; the row then quotes the connect script's `PASS  signed_read —` line when one was printed, and warns `host inbox route answered 200, unsigned; signed read was not measured (node-side probe skipped)` when the banner arrived without it [scripts/bunker-provision.sh:427-435] | a changed banner turns every connected node into `  FAIL  crier — ` with an empty detail, because the `*)` arm quotes whatever `FAIL ` line it finds [scripts/bunker-provision.sh:436-438] |
| `"$HERE/node-create.sh"` with `BUNKER_SERVER` and `CRIER_URL` in its environment [scripts/bunker-provision.sh:752-755] | `scripts/node-create.sh` | exit status only; a non-zero status is carried to `rc=1` and the run CONTINUES, because that script also owns the control-host round-trip check [scripts/bunker-provision.sh:758-762] | a new interpretation of exit 1 would either mask a real failure or turn a warning into `  FAIL  node_create` [scripts/bunker-provision.sh:761] |

### 2c. Service contracts (both sides must be named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| bunker server daemon on `$SERVER` | control host → daemon, and daemon → node on behalf of the control host [scripts/bunker-provision.sh:301] [scripts/bunker-provision.sh:355-356] | the `bunker` client's own transport; the client is resolved from `PATH` and never version-checked [scripts/bunker-provision.sh:295] | subcommands `list`, `info <agent>`, `spawn <agent> --ttl`, `cp <local> <agent>:<name>`, `exec <agent> -- bash -lc <text>`, `destroy <agent>`, each with `--server` [scripts/bunker-provision.sh:301] [scripts/bunker-provision.sh:317] [scripts/bunker-provision.sh:522] [scripts/bunker-provision.sh:355] [scripts/bunker-provision.sh:356] [scripts/bunker-provision.sh:941] | the daemon is outside this repository; the client's assumed surface is pinned only by those calls, and `bunker list` is expected to print one line containing the server name [scripts/bunker-provision.sh:301-305] |
| crier bus (signer first, registry second) | node → bus [scripts/bunker-provision.sh:425-426]; control host → bus for the CF-366 revoke [scripts/bunker-provision.sh:843] | HTTP through `node-bus-worker.py` on the node, with a per-agent ed25519 signature AND a shared bearer [scripts/bunker-provision.sh:372-375] (fact: FACT-03); the revoke is a `DELETE /agents/<agent>` with a Bearer admin token handed to `curl` on STDIN, never in argv [scripts/bunker-provision.sh:828-839] (fact: FACT-05) | `GET /agents/<agent>/inbox/stats`, answered 200 only for a valid key+bearer (fact: FACT-04); the revoke is proven only by a follow-up `GET` expecting 404 [scripts/bunker-provision.sh:846-853] | crier's `internal/registry/agentsig.go` on the bus side (fact: FACT-03); this script only delegates and reads the sentinel `CRIER: CONNECTED` [scripts/bunker-provision.sh:427-428] |
| DuckBrain HTTP service at `$DUCKBRAIN_URL` | control host → DuckBrain [scripts/bunker-provision.sh:454] | HTTP GET with the key handed to `curl` on STDIN via `-K -`, never in argv [scripts/bunker-provision.sh:452-455] (fact: FACT-05) | `GET /api/memories/key/x?namespace=<ns>`, one request per declared namespace; `200` and `404` are both accepted as "namespace answers", every other code is a FAIL [scripts/bunker-provision.sh:456-459] | the DuckBrain HTTP server is outside this repository; the accepted code set is the contract, and it was measured `404` for `namespace=code-factory` on 2026-11-05 (§8) |
| GitHub, as the HTTPS remote named by `REPO` | node → GitHub [scripts/bunker-provision.sh:569-571] | HTTPS credential store: `~/.git-credentials` at mode 600 plus `credential.helper = store --file=...` [scripts/bunker-provision.sh:568-572] (fact: FACT-05) | an `https://x-access-token:<token>@github.com` entry, written on the node, read by `git` during the clone [scripts/bunker-provision.sh:569]; in `app` mode the credential is a 3600s installation token minted on the control host by `github-app-token.py` before the bundle is built, and the App key never leaves the control host [scripts/bunker-provision.sh:532-540] | the remote is whatever `REPO` names, and the clone is performed by `node-create.sh` [scripts/bunker-provision.sh:752-755]; an SSH remote is out of contract because no key is installed [config/bunker.example.conf:5-6] |
| Hermes gateway on the node, as the consumer of the declared environment | control host → node files, read by the gateway at start [scripts/bunker-provision.sh:615-618] | file writes inside the node: `~/.hermes/.env` and the five `CONFIG_SET_*` scalars in `~/.hermes/config.yaml` [scripts/bunker-provision.sh:32-34] | `--env-file` plus repeated `--config-set <dotted.key>=<value>`, applied by `node_env.py --apply` BEFORE the harness layer starts [scripts/bunker-provision.sh:626-641] | the gateway reads those files at start — the ordering requirement is stated at [scripts/bunker-provision.sh:615-618], and a profile applied afterwards "is a profile the run contradicts" [scripts/bunker-provision.sh:616-617] |

## 3. Verification

All commands below are read-only. The first measures a live node; the rest are the fail-closed fixtures. Run from the repository root.

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| Live preflight against a provisioned node | `bash scripts/bunker-provision.sh --config ~/.config/code-factory/code-factory.conf --check --agent cf-node --crier-url http://<crier-host>:8767 --duckbrain-url http://<duckbrain-host>:3000` [scripts/bunker-provision.sh:240-468] | one row per measured surface (repo, `node.json`, four credentials, git store, gateway auth, gitreins, commit hook, harness), the bus row quoting the signed-read line, then `BUNKER: FAIL (1)` because the three control-host token files named by the config are no longer on this host [scripts/bunker-provision.sh:244-259] | 2026-11-05T16:10Z, at blob `b3ed55c` — **not re-run this re-derivation: no live node authorized** | 16 `PASS` rows, 2 `WARN`, exit 1 at that revision; the current script adds a `github_auth` row [scripts/bunker-provision.sh:285-292] and the `inputs` row names the readable files [scripts/bunker-provision.sh:256]; verbatim output in §8 |
| Absent config is refused | `bash scripts/bunker-provision.sh --config /nonexistent.conf --check` [scripts/bunker-provision.sh:145] | `  FAIL  config — cannot read /nonexistent.conf`, exit 1 | 2026-11-25 | PASS (as expected); verbatim output in §8 |
| A shell line in the config is refused, never executed | `printf 'PROJECT=demo\nrm -rf /tmp/should-never-run\n' > /tmp/shell.conf; bash scripts/bunker-provision.sh --config /tmp/shell.conf --check` [scripts/bunker-provision.sh:150-153] | `  FAIL  config — /tmp/shell.conf:2 is not KEY=VALUE — refusing to run it`, exit 1, and the file is not created | 2026-11-25 | PASS (as expected); verbatim output in §8 |
| No bunker client on `PATH` | `env -i PATH=/usr/bin:/bin HOME="$HOME" bash scripts/bunker-provision.sh --check --project demo` [scripts/bunker-provision.sh:295-298] | `  FAIL  bunker_cli — no bunker client on PATH`, exit 1 | 2026-11-25 | PASS (as expected); verbatim output in §8 |
| A bad namespace slug is refused before any host is touched | `bash scripts/bunker-provision.sh --check --project demo --agent a --server s --namespaces 'bad slug!'` [scripts/bunker-provision.sh:123-129] | `  FAIL  namespaces — 'badslug!' is not a namespace slug (expected letters, digits, dot, dash, underscore)`, exit 1 — whitespace is stripped before validation [scripts/bunker-provision.sh:121] | 2026-11-25 | PASS (as expected); the same assertion is mechanised in `tests/selftest.sh` §40 [tests/selftest.sh:3721-3725] |

The first row's four credential rows are **presence** rows, not permission rows: the probe tests `[ -s <path> ]` (exists and non-empty) and never a mode [scripts/bunker-provision.sh:344-349], so `auth_github`, `auth_duckbrain`, `crier_key` and `crier_bearer` passing says nothing about 600 — the `mode 600` in their printed text is wording, and the only mode measurement in the file happens inside `--apply` (§5) [scripts/bunker-provision.sh:368-376] [scripts/bunker-provision.sh:573].

## 4. Metrics emitted

**NONE.** No counter, histogram, exporter, timer or metrics endpoint exists in this file; the only machine-readable outputs are the process exit status [scripts/bunker-provision.sh:467] [scripts/bunker-provision.sh:804] and the in-process `FAILED` tally that the verdict line interpolates [scripts/lib.sh:7] [scripts/bunker-provision.sh:466] [scripts/bunker-provision.sh:803].

Consequences, stated so nobody hunts for a scrape target:

- Dispatch rate, provision latency and failure counts are not emitted. The only timing in the file is enforcement, not measurement — fixed `timeout` caps of 45s, 60s and 120s around individual calls [scripts/bunker-provision.sh:301] [scripts/bunker-provision.sh:317] [scripts/bunker-provision.sh:355-356] [scripts/bunker-provision.sh:425] [scripts/bunker-provision.sh:941].
- Node liveness is measured once, at run time, then discarded: `bunker info` decides `agent` [scripts/bunker-provision.sh:317-328] and the staged probe decides `repo`/`harness` [scripts/bunker-provision.sh:331-385]; neither is persisted as a number.
- What a monitoring lane can use is the exit status: 0 = every row measured and the apply's own `rc` clean, non-zero = at least one `FAIL` row, 2 = usage or a refused destroy [scripts/bunker-provision.sh:1079] [scripts/bunker-provision.sh:923-924]. A destroy adds its own: 0 on `BUNKER DESTROYED` [scripts/bunker-provision.sh:1021] or a proven never-existed [scripts/bunker-provision.sh:1014-1016], 1 on `BUNKER DESTROY INCOMPLETE` [scripts/bunker-provision.sh:1017-1019] or an unwritable residue log [scripts/bunker-provision.sh:1012].
- The one persisted artefact is the node identity `node.json`, written with `provisioned_by` and `provisioned_at` [scripts/bunker-provision.sh:773] — a record that provisioning ran, not a metric.

## 5. Log lines it can generate

Everything below is printed to stdout by this script or by `scripts/lib.sh` on its behalf. There is no logger, no level filter, no destination and no retention: a line exists only in the terminal or in whatever captured it [scripts/lib.sh:5-9].

| Level | Line (verbatim) | Emitted when | Kind |
|---|---|---|---|
| PASS | `  PASS  <check> — <measured value>` (template `  PASS  %s — %s\n`; e.g. `  PASS  server — bunker-las-03 reachable`) | a measured row passed [scripts/lib.sh:6] [scripts/bunker-provision.sh:302] | evidentiary |
| FAIL | `  FAIL  <check> — <reason>` (template `  FAIL  %s — %s\n`; e.g. `  FAIL  bunker_cli — no bunker client on PATH`) | a measured row failed; this is the only arm that increments `FAILED` [scripts/lib.sh:7] [scripts/bunker-provision.sh:296] | evidentiary |
| WARN | `  WARN  <check> — <reason>` (e.g. `  WARN  crier — CRIER_URL unset — reachability unproven`) | a surface could not be proven and the run continues [scripts/lib.sh:8] [scripts/bunker-provision.sh:423] | descriptive |
| note | `  ..    <progress>` (template `  ..    %s\n`; e.g. `  ..    spawning cf-node (ttl 6h)`) | a step of a multi-step `--apply` [scripts/lib.sh:9] [scripts/bunker-provision.sh:521] | descriptive |
| info | `bunker-provision --check — project=code-factory agent=cf-node server=bunker-las-03` | first line of a `--check` run, before any measurement [scripts/bunker-provision.sh:263] | descriptive |
| info | `bunker-provision --apply — project=code-factory agent=cf-node server=bunker-las-03` | first line of an `--apply` run [scripts/bunker-provision.sh:502] | descriptive |
| info | `  ..    resolved repo=<path> ref=main harness=hermes namespaces=code-factory (primary code-factory) ttl=6h crier=<url> duckbrain=<url>` | after namespace resolution, before the host is touched [scripts/bunker-provision.sh:264] | descriptive |
| info | `  PASS  config — code-factory.conf — 13 lines, KEY=VALUE only` | the config parsed; the count includes comment lines [scripts/bunker-provision.sh:169] | evidentiary |
| info | `  <file> mode <mode>` (template `  %s mode %s\n`; e.g. `  github.token mode 600`) | `--apply` only, after the auth bundle is installed: one line per entry under `~/.node/auth/`, stat'ed inside the node — `~/.node/agent.key` and `~/.git-credentials` sit outside that glob and get no line [scripts/bunker-provision.sh:573] | evidentiary |
| verdict | `BUNKER: PASS — every row above measured` | `--check` with no FAIL row [scripts/bunker-provision.sh:466] | evidentiary |
| verdict | `BUNKER: FAIL (<n>)` | `--check` with one or more FAIL rows; `<n>` is the tally [scripts/bunker-provision.sh:466] | evidentiary |
| verdict | `BUNKER APPLIED: <agent>` | `--apply` with `rc` 0 AND no FAIL row [scripts/bunker-provision.sh:803] | evidentiary |
| verdict | `BUNKER INCOMPLETE (<n>)` | `--apply` with any FAIL row or a carried `rc=1` [scripts/bunker-provision.sh:803] | evidentiary |
| refusal | `refusing to destroy without --yes (would remove agent <agent> on <server>)` | `--destroy` without `--yes`, exit 2 [scripts/bunker-provision.sh:923] | evidentiary |
| refusal | `refusing to destroy: AGENT unset` | `--destroy` with no agent, exit 2 [scripts/bunker-provision.sh:924] | evidentiary |
| refusal | `bunker client missing` | `--destroy` with no client on `PATH`, exit 1 [scripts/bunker-provision.sh:926] | evidentiary |
| refusal | `  FAIL  lib.sh — missing or unreadable: <path>` / `  FAIL  lib.sh — could not source: <path>` | the library is absent or fails to source, exit 1, before any argument is parsed [scripts/bunker-provision.sh:66-73] | evidentiary |
| usage | `unknown argument: <arg>` followed by the usage block | an unrecognised flag; exit 2 [scripts/bunker-provision.sh:1051] | descriptive |
| pass-through | `bunker: reading server "<server>"` | printed by the bunker client itself and quoted into the `agent` row as that row's measured value [scripts/bunker-provision.sh:320] | descriptive |
| info | `  ..    arming GitHub App refresh timer` | `--apply` in `app` mode, after the auth bundle [scripts/bunker-provision.sh:223] | descriptive |
| PASS | `  PASS  github_app_refresh — refresh timer enabled for <agent> (20-minute cadence)` | the systemd user timer installed and enabled [scripts/bunker-provision.sh:229] | evidentiary |
| WARN | `  WARN  github_app_refresh — timer installation or enable failed; add this cron entry: <line>` | the fallback when the timer cannot be armed [scripts/bunker-provision.sh:234] | descriptive |
| PASS | `  PASS  auth — installed under $HOME/.node/auth at mode 600: <name>=<mode> ...` | `--apply`: every mode the node reported was 600 [scripts/bunker-provision.sh:585] | evidentiary |
| PASS | `  PASS  auth_bundle — staged bundle deleted on the node; the local copy is removed too` | the bundle's deletion was proven, not `|| true`-ed [scripts/bunker-provision.sh:590] | evidentiary |
| PASS | `  PASS  manifest — creation record written: <path> (paths only, never credential values — destroy reads it to revoke and to enumerate residue)` | a fully green `--apply` wrote the CF-366 creation manifest [scripts/bunker-provision.sh:917] | evidentiary |
| PASS | `  PASS  crier_revoke — revoked: DELETE <bus>/agents/<agent> -> 204, probe -> 404` | destroy: the DELETE succeeded and the follow-up probe proves the registration gone [scripts/bunker-provision.sh:849] | evidentiary |
| PASS | `  PASS  crier_revoke — already gone: DELETE -> 404, probe -> 404 (idempotent)` | destroy: nothing left to revoke [scripts/bunker-provision.sh:851] | evidentiary |
| PASS | `  PASS  never_existed — <agent> never existed: bunker destroy reported not found and the registry probe -> 404 on <bus>` | destroy: both sides agree the agent never existed; exit 0 [scripts/bunker-provision.sh:979] | evidentiary |
| FAIL | `  FAIL  crier_revoke — crier registration: no CR_PERMISSIONS_ADMIN_TOKEN armed — <agent> still answers GET <code> on <bus>` | destroy: the registration is live and no admin token is armed; the agent is added to the residue record [scripts/bunker-provision.sh:968-969] | evidentiary |
| FAIL | `  FAIL  crier_revoke — crier registration: DELETE <bus>/agents/<agent> -> <code> with CR_PERMISSIONS_ADMIN_TOKEN armed — revocation refused` | destroy: the bus refused the DELETE [scripts/bunker-provision.sh:858] | evidentiary |
| FAIL | `  FAIL  crier_revoke — crier registration: DELETE -> <del> but probe -> <probe> — revocation not proven` | destroy: the DELETE's answer and the probe disagree [scripts/bunker-provision.sh:855] | evidentiary |
| PASS | `  PASS  residue — recorded <n> unreclaimed item(s) -> <path>` | destroy: the residue record was appended [scripts/bunker-provision.sh:883] | evidentiary |
| verdict | `BUNKER DESTROYED: <agent>` | destroy with every row green; exit 0 [scripts/bunker-provision.sh:1021] | evidentiary |
| verdict | `BUNKER DESTROY INCOMPLETE (<n>) — the failing row names the credential that did not revoke` | destroy with a FAIL row; exit 1 [scripts/bunker-provision.sh:1018] | evidentiary |
| WARN | `  WARN  crier — host inbox route answered 200, unsigned; signed read was not measured (node-side probe skipped)` | the connect script's banner arrived without a signed-read row [scripts/bunker-provision.sh:434] | descriptive |
| note | `gateways — no <project>.gateways.json beside the config — scheduler-only lane, node config untouched (M13 R3)` | no sibling artifact beside the config [scripts/bunker-provision.sh:407] [scripts/bunker-provision.sh:723] | descriptive |
| PASS | `  PASS  gateways — artifact valid (M13 §3, R2: tokens by reference) — platforms: <names> — merges at --apply` | `--check`: the sibling artifact graded read-only [scripts/bunker-provision.sh:413] | evidentiary |
| FAIL | `  FAIL  gateways — <reason>` | the artifact is malformed, mis-shaped, or carries token bytes [scripts/bunker-provision.sh:415] [scripts/bunker-provision.sh:727-729] | evidentiary |
| WARN | `  WARN  gateway_token_env — GATEWAY_TOKEN_REF_UNRESOLVED — <refs> has no value in the node environment (M13 §5: warning, not fatal — the gateway starts disabled and the lane runs scheduler-only until the variable lands)` | the merge succeeded but a `token_env` is unresolved [scripts/bunker-provision.sh:739] | descriptive |
| PASS | `  PASS  gateways — platforms merged into the node's ~/.hermes/config.yaml (tokens by reference, M13 R2)` | `--apply`: the merge succeeded [scripts/bunker-provision.sh:741] | evidentiary |

Two lines are notable because they carry NO measured value and still count as evidence: `  FAIL  crier — ` (empty detail, when the bus probe produced no `FAIL ` line — e.g. a 120s timeout) [scripts/bunker-provision.sh:436-437], and `  ..    preflight rows were not all green; --apply repairs what it can`, which replaces the suppressed preflight output [scripts/bunker-provision.sh:1086].

One claim in that table is about `--apply` and must not be read as a `--check` result: `--check` measures **no file mode at all**. Its credential rows are the staged probe's `[ -s <path> ]` tests — exists and non-empty — and nothing else [scripts/bunker-provision.sh:344-349], so the `mode 600` wording inside `  PASS  auth_github — token file installed, mode 600 (value not read)` and `  PASS  crier_key — agent key installed at 600` is a literal string in the `printf`, not a measurement [scripts/bunker-provision.sh:368] [scripts/bunker-provision.sh:372]; likewise `mode 600 store` on the git-credential row is the contract the apply writes, not something the probe reads [scripts/bunker-provision.sh:376] [scripts/bunker-provision.sh:570]. The only `stat` in the file is the `--apply` line above, and it covers `~/.node/auth/*` only [scripts/bunker-provision.sh:573]. A mode regression on the node is therefore invisible to every check row.

## 6. Failure modes

Direction: **local** = the failure is reported as something else on this host; **remote** = the failure lives on the node or a peer; **degraded** = the run continues with a weaker guarantee.

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| `scripts/lib.sh` absent or renamed (local, fail-closed) | `  FAIL  lib.sh — missing or unreadable: <path>` and exit **1** before any argument is parsed [scripts/bunker-provision.sh:66-69]; a library that exists but fails to source gets `  FAIL  lib.sh — could not source: <path>`, also exit 1 [scripts/bunker-provision.sh:70-73] — measured, §8 | distinct from a genuinely missing bunker client, which fails later with `  FAIL  bunker_cli — no bunker client on PATH` [scripts/bunker-provision.sh:296] | restore `lib.sh` next to the script; before CF-261 this shape printed five `command not found` diagnostics and died at the `bunker_cli` guard — the refusal now names the cause |
| `lib.sh` present but `bad()` does not increment `FAILED`, or `FAILED` is never initialised (degraded, false green) | every row runs and every failure is printed, but nothing is counted: in the measured run ten FAIL rows printed and the verdict still read `BUNKER: PASS — every row above measured`, exit **0** [scripts/lib.sh:7] [scripts/bunker-provision.sh:466-467] — measured, §8. If only the init line is gone, the run aborts instead: `FAILED: unbound variable`, exit **1** — the first `bad()` call prints its row and then dies on the increment [scripts/lib.sh:7] [scripts/lib.sh:11] [scripts/bunker-provision.sh:63] — measured, §8 | a missing library cannot produce this — it is refused by name before parsing (row above) — so exit 0 is only reachable with a library that is present and wrong | never trust exit 0 from this script on its own: require `BUNKER: PASS` AND zero FAIL rows, because `FAILED` is the only counter and `lib.sh:7` is the line that feeds it |
| `bunker` client absent (local, fail-closed) | `  FAIL  bunker_cli — no bunker client on PATH`, exit 1 before any host call [scripts/bunker-provision.sh:295-298] | distinct from an unreachable host, which fails the next row instead [scripts/bunker-provision.sh:301-305] | install the client on the control host `PATH` |
| Host unreachable (local direction) | `--check`: `  FAIL  server — <server> not listed by 'bunker list'` after a 45s cap [scripts/bunker-provision.sh:301-305]. `--apply` NEVER consults that row: it goes to `bunker info`, then `spawn`, whose failure prints `  FAIL  agent — spawn failed: <last line of /tmp/cf-spawn.log>` [scripts/bunker-provision.sh:518-526] | a dead host and a server that does not exist produce the SAME row; a partition is reported as absence [scripts/bunker-provision.sh:304] | re-run `--check` once reachable; read `/tmp/cf-spawn.log` for the spawn arm [scripts/bunker-provision.sh:525] |
| Server name is a substring of any `bunker list` line (local, false green) | `--server s` passes: measured `  PASS  server — s reachable` while no server named `s` exists [scripts/bunker-provision.sh:301-302] — re-measured 2026-11-25 against a stub client whose only server was `stub-server` (§8) | distinguished only by reading the client's own list output; the test is `grep -q -- "$SERVER"`, not an exact match [scripts/bunker-provision.sh:301]. The `agent` row no longer shares this defect: CF-507 made it a whole-token match over `[A-Za-z0-9._-]` [scripts/bunker-provision.sh:317-328] | always pass the full server id; a short or generic name can never fail this row |
| A credential file named by the config is missing (degraded) | `--check` names it: `  FAIL  inputs — not readable: <NAME>(<path>) ...`, one row covering all six files [scripts/bunker-provision.sh:244-259]. `--apply` continues: each unreadable file is skipped when the bundle is built [scripts/bunker-provision.sh:473-492], and an empty bundle only warns: `  WARN  auth — no token files named in config — the clone will run unauthenticated` [scripts/bunker-provision.sh:596] | the check's `inputs` row versus the apply's `auth` row — different ids, different severity, same cause [scripts/bunker-provision.sh:256-258] [scripts/bunker-provision.sh:578-586] | provide the files at mode 600 on the control host; run `--check` first, which is why the preflight validates them before touching a host [scripts/bunker-provision.sh:241-243] |
| Preflight fails but `--apply` continues (degraded, evidence loss) | the preflight runs in a subshell with BOTH streams discarded, so its FAIL rows never reach the operator; one note replaces them: `  ..    preflight rows were not all green; --apply repairs what it can` [scripts/bunker-provision.sh:1083-1087] | nothing else distinguishes it — the apply's verdict counts only its own rows [scripts/bunker-provision.sh:1084-1085] | run `--check` separately and keep its output; that is the only place the preflight's rows exist |
| `CRIER_URL` unset (degraded) | `--apply`: `  FAIL  crier_url — CRIER_URL unset — a node must know its bus (set it in the config or --crier-url)` and the run CONTINUES, so the node still gets its identity [scripts/bunker-provision.sh:507-512] | `--check` warns instead: `  WARN  crier — CRIER_URL unset — reachability unproven` [scripts/bunker-provision.sh:422-423] | set `CRIER_URL` in the config or on the command line; the CLI wins (§7) |
| Bus probe times out, or the bus refuses (remote) | `  FAIL  crier — ` with an empty detail after a 120s cap, because the `*)` arm quotes the first `FAIL ` line and there is none [scripts/bunker-provision.sh:436-437] | a signed-read rejection carries its `FAIL` line; an empty detail means the probe never spoke — run `scripts/bunker-crier-connect.sh --check` directly [scripts/bunker-provision.sh:425-426] | re-run the connect script alone; a bus that checks the signature before the agent answers 401 to anything unsigned (fact: FACT-03) |
| DuckBrain token unreadable or URL unset (degraded) | one warn for BOTH causes: `  WARN  duckbrain — DUCKBRAIN_URL or token file unset — namespace unproven` [scripts/bunker-provision.sh:441-462] | a reachable service with a wrong key produces per-namespace FAILs carrying the code: `  FAIL  duckbrain:<ns> <url> namespace=<ns> -> 401` [scripts/bunker-provision.sh:456-459] | fix the named cause; only `200` and `404` are accepted [scripts/bunker-provision.sh:457] |
| `node-create.sh` reports FAIL (remote, carried) | `  FAIL  node_create — node-create.sh reported FAIL — see its rows; continuing with the identity`, `rc=1`, and the run still writes `node.json` [scripts/bunker-provision.sh:755-763] | the status is carried, so the final line is `BUNKER INCOMPLETE (n)` rather than a silent success [scripts/bunker-provision.sh:803-804] | read that script's rows; the identity write is intentional, not a masked failure [scripts/bunker-provision.sh:758-760] |
| Seed build refuses the declared seed (local) | `  FAIL  node_seed — build refused the declared seed — see the row above`, plus the first five lines of the build log indented with `    | ` [scripts/bunker-provision.sh:680-682] | distinct from a staging failure, which reads `could not stage the seed` [scripts/bunker-provision.sh:678] | fix the manifest or the file it names; the seed is a declared list with digests [scripts/bunker-provision.sh:655-659] |
| `--node-env-file` given a `~/...` path on the command line (FIXED, CF-262) | every path-valued flag is now routed through `expand_tilde` [scripts/bunker-provision.sh:106] — `--config` [scripts/bunker-provision.sh:1028], `--node-env-file` [scripts/bunker-provision.sh:1047] and the token files [scripts/bunker-provision.sh:1041-1046] — so the profile is read from the expanded path; the flag's own comment records the defect: a quoted `~/` "silently reads as the literal string and the leg is skipped" [scripts/bunker-provision.sh:102-105] | the config parser expands `~/` for every `*_FILE` key at parse time [scripts/bunker-provision.sh:163-165] | none needed; before the fix the literal string was used and the apply refused with `  FAIL  env_profile — NODE_ENV_FILE ~/nope.env is unreadable` |
| `--destroy` without `--yes` or without `AGENT` (refused) | `refusing to destroy without --yes (would remove agent <agent> on <server>)` or `refusing to destroy: AGENT unset`, exit 2 [scripts/bunker-provision.sh:923-924] — measured, §8 | distinct from a failed destroy: `  FAIL  destroy — bunker destroy failed: <last line>`, exit 1 [scripts/bunker-provision.sh:947-948] | re-run deliberately with `--yes` and a named agent |
| crier revocation fails or cannot be proven (remote, CF-366) | the bus-identity block spans [scripts/bunker-provision.sh:951-991]; one of: `  FAIL  crier_revoke — crier registration: no CR_PERMISSIONS_ADMIN_TOKEN armed — <agent> still answers GET <code> on <bus>` [scripts/bunker-provision.sh:968], `DELETE ... -> <code> with CR_PERMISSIONS_ADMIN_TOKEN armed — revocation refused` [scripts/bunker-provision.sh:858], `DELETE -> <del> but probe -> <probe> — revocation not proven` [scripts/bunker-provision.sh:855] | an unarmed token with the registration still answering adds `crier_registration:<agent>` to the residue record [scripts/bunker-provision.sh:969] [scripts/bunker-provision.sh:973]; a 404 probe after the DELETE is the only accepted proof of revocation [scripts/bunker-provision.sh:846-853] | arm `CR_PERMISSIONS_ADMIN_TOKEN` (or `CR_PERMISSIONS_ADMIN_TOKEN_FILE`) and re-run; the residue log names what was left behind [scripts/bunker-provision.sh:879-883] |
| residue record cannot be written (local) | the residue block spans [scripts/bunker-provision.sh:993-1012]; `  FAIL  residue — cannot create <dir> for the residue log` or `  FAIL  residue — could not append to <path>`, exit 1 [scripts/bunker-provision.sh:871-881] [scripts/bunker-provision.sh:1012] | the destroy itself already happened; only the durable record failed | create the directory or fix permissions and re-run `--destroy` — the revocation probe is idempotent [scripts/bunker-provision.sh:851] |
| no creation manifest (degraded, pre-CF-366 agent or failed apply) | `  WARN  manifest — no readable creation manifest at <path> — residue enumeration is limited to what this destroy revokes` [scripts/bunker-provision.sh:937] | with a manifest, residue also names the declared namespaces and every credential file the run staged [scripts/bunker-provision.sh:996-1009] | re-run `--apply` green to mint a manifest [scripts/bunker-provision.sh:800-802], or accept the narrower enumeration |
| gateways artifact refused or merge fails (local/remote, CF-537) | `--check`: `  FAIL  gateways — <reason>` before any host touch [scripts/bunker-provision.sh:415]. `--apply`: `  FAIL  gateways — artifact refused before anything was staged: <reason>` [scripts/bunker-provision.sh:727-729], `  FAIL  gateways — could not stage the gateways artifact or the merge tool` [scripts/bunker-provision.sh:743], or `  FAIL  gateways — the merge exited <rc> on the node — rows above; config.yaml left consistent (writes are atomic)` [scripts/bunker-provision.sh:735-736] | an unresolved `token_env` is NOT this failure: the merge succeeds and the row is a `  WARN  gateway_token_env` (M13 §5) [scripts/bunker-provision.sh:739] | fix the artifact (regenerate with `bunker_config_gen.py --gateways`, never hand-edit) and re-run; the merge is byte-idempotent [scripts/bunker-provision.sh:708-712] |
| Any unguarded command fails (degraded) | the script runs without `-e` — only `-uo pipefail` [scripts/bunker-provision.sh:63] — so a failed `cp`, `sed` or `stat` prints its own stderr and the run proceeds | nothing marks it as a row; the effect surfaces later as an empty measured value | read the stderr; a row rendering `clone present () branch , 0 dirty` is the tell [scripts/bunker-provision.sh:364] |

## 7. Environment and settings it reads

Every key the config parser accepts [scripts/bunker-provision.sh:156-167], every flag the parser understands [scripts/bunker-provision.sh:1026-1053], and the process variables actually read (`HOME` at [scripts/bunker-provision.sh:91-92] and [scripts/bunker-provision.sh:164]; `PATH` through `have` [scripts/lib.sh:41-45]; `BUNKER_MANIFEST_DIR` / `CF_RESIDUE_LOG` / `CR_PERMISSIONS_ADMIN_TOKEN(_FILE)` below).

| Setting (config key / flag) | Default when unset | Effect if unset |
|---|---|---|
| `PROJECT` / `--project` | none | namespaces fall back to `PROJECT`, so an empty value gives `  FAIL  namespaces — no namespace declared and PROJECT is unset` [scripts/bunker-provision.sh:114-117]; `--apply` refuses with `  FAIL  project — PROJECT unset in config`, exit 1 [scripts/bunker-provision.sh:504] |
| `AGENT` / `--agent` | none | `--check`: `  FAIL  agent — AGENT unset`, exit 1 [scripts/bunker-provision.sh:307]; `--destroy`: refused, exit 2 [scripts/bunker-provision.sh:924] |
| `SERVER` / `--server` | none | `--check`: `  FAIL  server — SERVER unset — no host to provision on`, exit 1 [scripts/bunker-provision.sh:300]; `--apply`: `  FAIL  server — SERVER unset`, exit 1 [scripts/bunker-provision.sh:506] |
| `REPO` / `--repo` | none | `--apply` refuses with `  FAIL  repo — REPO unset in config`, exit 1; `--check` only prints the resolved value [scripts/bunker-provision.sh:505] [scripts/bunker-provision.sh:264] |
| `REF` / `--ref` | `main` | the clone uses `main` and the resolved line prints `ref=main` [scripts/bunker-provision.sh:752] [scripts/bunker-provision.sh:264] |
| `HARNESS` / `--harness` | `hermes` | `--apply` passes `hermes` to `node-create.sh`, which also gates the gateway-auth step on this value [scripts/bunker-provision.sh:690] [scripts/bunker-provision.sh:753] |
| `NAMESPACES` / `--namespaces` | `NAMESPACE`, then `PROJECT` | the list resolves in that order; a duplicate is collapsed with `  WARN  namespaces — '<ns>' declared twice — collapsed`, and an empty result is a FAIL [scripts/bunker-provision.sh:112-139] |
| `NAMESPACE` / `--namespace` | first entry of `NAMESPACES`, else `PROJECT` | becomes the primary namespace written to `node.json` as `namespace=` and the single-namespace alias [scripts/bunker-provision.sh:138] [scripts/bunker-provision.sh:773] |
| `TTL` (no flag) | `6h` in `--apply`, `default(6h)` in the resolved line | the spawn gets `--ttl 6h` and the row prints `  ..    spawning <agent> (ttl 6h)` [scripts/bunker-provision.sh:521-522] |
| `GIT_AUTHOR_NAME`, `GIT_AUTHOR_EMAIL`, `GIT_CO_AUTHOR` | none | parsed and accepted by the config parser [scripts/bunker-provision.sh:159-160], and the header states they are required for `--apply` because the node commits [scripts/bunker-provision.sh:24]. No line after parsing reads them [scripts/bunker-provision.sh:76] — the value reaches the node only through a path outside this script, so setting it here changes nothing that this file measures |
| `GITHUB_TOKEN_FILE` / `--github-token-file` | none | no GitHub token is bundled; the clone runs unauthenticated and the node gets no `~/.git-credentials` [scripts/bunker-provision.sh:473] [scripts/bunker-provision.sh:568-572] |
| `DUCKBRAIN_TOKEN_FILE` / `--duckbrain-token-file` | none | the DuckBrain probe warns `namespace unproven` even when the URL is set, because the guard requires both [scripts/bunker-provision.sh:441] [scripts/bunker-provision.sh:462] |
| `S3_ENV_FILE` / `--s3-env-file` | none | no `~/.node/auth/s3.env` is installed; the node-side script removes an empty file rather than leaving a zero-byte one [scripts/bunker-provision.sh:490-492] [scripts/bunker-provision.sh:561-562] |
| `CRIER_AGENT_KEY_FILE` / `--crier-agent-key-file` | none | no `~/.node/agent.key`; the bus answers 401 to every read, and `--check` prints `  FAIL  crier_key — no $HOME/.node/agent.key — the inbox answers 401 to every read` [scripts/bunker-provision.sh:372-373] |
| `CRIER_AUTH_TOKEN_FILE` / `--crier-auth-token-file` | none | no bearer; the row is `  FAIL  crier_bearer — no $HOME/.node/auth/crier.token — a signed read still needs the bearer` [scripts/bunker-provision.sh:374-375]. The file may be a plain token OR an EnvironmentFile, from which `CR_AUTH_TOKEN=` is extracted [scripts/bunker-provision.sh:479-488] |
| `CRIER_URL` / `--crier-url` | none | `--check` warns `reachability unproven` [scripts/bunker-provision.sh:423]; `--apply` records `  FAIL  crier_url` and still provisions [scripts/bunker-provision.sh:512] |
| `DUCKBRAIN_URL` / `--duckbrain-url` | none | the per-namespace probe is skipped and one warn covers URL and token together [scripts/bunker-provision.sh:441-462] |
| `NODE_ENV_FILE` / `--node-env-file` | none | no profile is staged; with no `CONFIG_SET_*` either, the row is `  WARN  env_profile — no NODE_ENV_FILE or CONFIG_SET_* — the node's environment is declared nowhere` [scripts/bunker-provision.sh:394] [scripts/bunker-provision.sh:652] |
| `CONFIG_SET_MODEL_PROVIDER` | none | omitted from the `--config-set` stream, so `model.provider` on the node is left as it is [scripts/bunker-provision.sh:176] |
| `CONFIG_SET_MODEL_NAME` | none | omitted, so `model.name` is untouched [scripts/bunker-provision.sh:177] |
| `CONFIG_SET_GATEWAY_BIND` | none | omitted, so `gateway.bind` is untouched [scripts/bunker-provision.sh:178] |
| `CONFIG_SET_GATEWAY_PORT` | none | omitted, so `gateway.port` is untouched [scripts/bunker-provision.sh:179] |
| `CONFIG_SET_AGENT_MAX_ITERATIONS` | none | omitted, so `agent.max_iterations` is untouched [scripts/bunker-provision.sh:180] |
| `--config <path>` | none | the flag only stores the path, tilde-expanded [scripts/bunker-provision.sh:1028]; the file IS read, once, after the flags are parsed and before any mode runs [scripts/bunker-provision.sh:1056]. Unreadable → `  FAIL  config — cannot read <path>` and exit 1 [scripts/bunker-provision.sh:145]; a non-`KEY=VALUE` line → refusal at that line number, exit 1 [scripts/bunker-provision.sh:150-153]. With the flag unset no config is read at all, so every value must come from a flag — `--check --project demo` alone then reaches `  FAIL  bunker_cli` or the next missing value |
| `--config-set <dotted.key>=<value>` (repeatable) | none | each value is appended AFTER the config's own, so the command line's last value wins inside `node_env.py` [scripts/bunker-provision.sh:181] [scripts/bunker-provision.sh:1048] |
| `--check` / `--apply` / `--destroy` | none | no mode exits 2 through `usage` [scripts/bunker-provision.sh:1079] |
| `--yes` | 0 | `--destroy` refuses without it, exit 2 [scripts/bunker-provision.sh:923] |
| `-h` / `--help` | — | prints lines 2-44 of this file with the leading `# ` stripped, exit 0 [scripts/bunker-provision.sh:97-100] |
| `GITHUB_AUTH_MODE` / `--github-auth-mode` | `token` | `app` mints a 3600s installation token from `GITHUB_APP_ENV_FILE` before the auth bundle is built [scripts/bunker-provision.sh:532-540]; any other value is refused: `  FAIL  github_auth_mode — GITHUB_AUTH_MODE='<v>' is not app|token` [scripts/bunker-provision.sh:215-218] |
| `GITHUB_APP_ENV_FILE` / `--github-app-env-file` | `~/.config/code-factory/github-app.env` | mode `app` with an unreadable file refuses: `  FAIL  github_app — GITHUB_APP_ENV_FILE <path> is unreadable` [scripts/bunker-provision.sh:533] |
| `BUNKER_MANIFEST_DIR` (env only) | `~/.config/code-factory/bunker-manifests` | the creation manifest and the default residue log live under it [scripts/bunker-provision.sh:91-92]; `--destroy` reads `<agent>.manifest.json` from it [scripts/bunker-provision.sh:814] [scripts/bunker-provision.sh:931] |
| `CF_RESIDUE_LOG` (env only) | `<manifest dir>/residue.jsonl` | the one JSONL residue record per destroy is appended here [scripts/bunker-provision.sh:879-881] |
| `CR_PERMISSIONS_ADMIN_TOKEN` / `CR_PERMISSIONS_ADMIN_TOKEN_FILE` (env only) | none | the bearer the bus `DELETE` needs, env first then the token file [scripts/bunker-provision.sh:820-826]; without it a still-registered agent is a `  FAIL  crier_revoke` row plus a residue entry, never a claimed revocation [scripts/bunker-provision.sh:967-969] |
| `<project>.gateways.json` (sibling artifact, not a config key) | none | the byte-deterministic sibling of the provision config emitted by `bunker_config_gen.py --gateways` (CF-531); `--check` grades it read-only and `--apply` merges it into the node's `~/.hermes/config.yaml` (M13 §4) [scripts/bunker-provision.sh:397-417] [scripts/bunker-provision.sh:708-749]; absent = scheduler-only lane, one note, node config untouched (R3) [scripts/bunker-provision.sh:407] |

Precedence — the command line now WINS over the config file. Flags are parsed into `CLI_*` variables only [scripts/bunker-provision.sh:1028-1048], the config is loaded next [scripts/bunker-provision.sh:1056], and the `CLI_*` values are then re-applied on top [scripts/bunker-provision.sh:1057-1077]. This is the 2026-11-05 correction to a defect where five flags — `--duckbrain-url`, `--github-token-file`, `--duckbrain-token-file`, `--crier-agent-key-file`, `--crier-auth-token-file` — were assigned during parsing and then overwritten by `load_config`, "so a documented flag was silently ignored whenever a config was also passed" [scripts/bunker-provision.sh:1069-1071] (`CLI_S3_ENV_FILE` is re-applied the same way [scripts/bunker-provision.sh:1077]); `tests/selftest.sh` now fails any flag handler that assigns a non-`CLI_*` name [tests/selftest.sh:3561-3568]. Measured proof (2026-11-05 run): the operator config used for that run — not in this repository — names `AGENT=cf-code-factory` while the command line carried `--agent cf-node`, and the header printed `agent=cf-node` [scripts/bunker-provision.sh:263] (§8 transcript). The example config shipped here names `AGENT=<agent-id>` [config/bunker.example.conf:9], so the precedence proof is the transcript, not the example.

The preflight validates the files it will read, before any host is touched: all six `*_FILE` values are tested for readability and the unreadable ones are named in a single `inputs` row [scripts/bunker-provision.sh:241-259]. That row is also the only proof that a `--flag` reached its variable, since the check reads the post-precedence values [scripts/bunker-provision.sh:241-243]. `~/` is expanded for the five token-file flags at parse time [scripts/bunker-provision.sh:1042-1046] and for every `*_FILE` key at config parse time [scripts/bunker-provision.sh:163-165]; `--node-env-file` and `--config` expand it too since CF-262 — every path-valued flag is routed through `expand_tilde` [scripts/bunker-provision.sh:106] [scripts/bunker-provision.sh:1028] [scripts/bunker-provision.sh:1047].

## 8. Evidence of record

- What a reviewer re-runs. The host-local fixtures were re-run 2026-11-25 against blob `301f7410` (`main` @ `c417a3ff`); the live-node transcript is the 2026-11-05 run at blob `b3ed55c`, kept as dated evidence because no live node was authorized for this re-derivation.
- Two endpoints below appear as `<crier-host>:8767` and `<duckbrain-host>:3000`: the real addresses
  live in the operator's own config (`CRIER_URL`/`DUCKBRAIN_URL` in the provisioner's `KEY=VALUE`
  config, or the `--crier-url`/`--duckbrain-url` flags), and are not published here because this
  repository is public (CF-378).

```
$ cd ~/proj-wt-md-05   # 2026-11-05: main @ 55ddb92, scripts/bunker-provision.sh blob b3ed55c, sha256 981f9972ce7c2c47
# (current blob: 301f7410, sha256 prefix 2ea19642dab32123 — this transcript predates CF-214/CF-238/CF-261/CF-262/CF-366/CF-507)
$ bash scripts/bunker-provision.sh --config ~/.config/code-factory/code-factory.conf --check \
    --agent cf-node --crier-url http://<crier-host>:8767 --duckbrain-url http://<duckbrain-host>:3000
  PASS  config — code-factory.conf — 13 lines, KEY=VALUE only
  FAIL  inputs — not readable: GITHUB_TOKEN_FILE(~/.config/code-factory/code-factory/github.token) DUCKBRAIN_TOKEN_FILE(~/.config/code-factory/code-factory/duckbrain.token) S3_ENV_FILE(~/.config/code-factory/code-factory/s3.env)
bunker-provision --check — project=code-factory agent=cf-node server=bunker-las-03
  ..    resolved repo=~/code-factory ref=main harness=hermes namespaces=code-factory (primary code-factory) ttl=6h
  PASS  bunker_cli — ~/.local/bin/bunker
  PASS  server — bunker-las-03 reachable
  PASS  agent — cf-node exists (bunker: reading server "bunker-las-03")
  PASS  repo — clone present (2889c52 branch main, 0 dirty)
  PASS  node_json — identity written
  PASS  auth_github — token file installed, mode 600 (value not read)
  PASS  auth_duckbrain — token file installed (value not read)
  PASS  crier_key — agent key installed at 600 (the bus verifies its signature)
  PASS  crier_bearer — bus bearer installed at 600
  PASS  git_credential — $HOME/.git-credentials present, mode 600 store
  PASS  gateway_auth — dashboard.basic_auth present — a public bind is legal
  PASS  gitreins — version 0.17.1
  PASS  commit_hook — pre-commit installed in the clone
  PASS  harness — hermes binary present
  WARN  env_profile — no NODE_ENV_FILE or CONFIG_SET_* — the node's environment is declared nowhere
  PASS  crier — signed read accepted: PASS  inbox — signed read accepted on the node:   PASS  inbox — GET /agents/cf-node/inbox/stats -> 200 (signed read accepted; queue_depth 0, leased_count 0)
  WARN  duckbrain — DUCKBRAIN_URL or token file unset — namespace unproven

BUNKER: FAIL (1)
# exit 1 — the single failure is the `inputs` row, naming three control-host token files
# consumed and deleted after the node was provisioned; every node-side surface measured PASS.
# The `mode 600` wording in the auth_github / crier_key / git_credential rows is the script's
# own text, not a measurement: --check tests `-s` (exists, non-empty) and never stats a mode.
```

- The same probe the script runs, issued by hand, to prove the DuckBrain contract accepts a missing key path as `404` rather than an error [scripts/bunker-provision.sh:452-459]:

```
$ code=$(printf 'header = "x-api-key: %s"\nurl = "%s"\n' \
    "$(head -c 4096 ~/.duckbrain/9router-foreman.token | tr -d '\r\n')" \
    "http://<duckbrain-host>:3000/api/memories/key/x?namespace=code-factory" \
  | curl -s -K - -o /dev/null -m 8 -w '%{http_code}'); echo "${code:-000}"
404
```

- Fail-closed fixtures, all re-runnable on any host with no bunker server; re-run 2026-11-25, outputs verbatim:

```
$ bash scripts/bunker-provision.sh --config /nonexistent.conf --check
  FAIL  config — cannot read /nonexistent.conf
# exit 1

$ printf 'PROJECT=demo\nrm -rf /tmp/cf539-should-never-run\n' > /tmp/cf539-shell.conf
$ bash scripts/bunker-provision.sh --config /tmp/cf539-shell.conf --check
  FAIL  config — /tmp/cf539-shell.conf:2 is not KEY=VALUE — refusing to run it
# exit 1, and /tmp/should-never-run was never created

$ env -i PATH=/usr/bin:/bin HOME="$HOME" bash scripts/bunker-provision.sh --check --project demo
  PASS  inputs — readable: none declared
bunker-provision --check — project=demo agent=<unset> server=<unset>
  ..    resolved repo=<unset> ref=main harness=hermes namespaces=demo (primary demo) ttl=default(6h) crier=unset duckbrain=unset
  WARN  github_auth — mode=token with no GITHUB_TOKEN_FILE — clone may be unauthenticated
  FAIL  bunker_cli — no bunker client on PATH
# exit 1

$ bash scripts/bunker-provision.sh --check --project demo --agent a --server s --namespaces 'bad slug!'
  PASS  inputs — readable: none declared
  FAIL  namespaces — 'badslug!' is not a namespace slug (expected letters, digits, dot, dash, underscore)
# exit 1
```

- The destroy refusals fire before any host call, measured 2026-11-25:

```
$ bash scripts/bunker-provision.sh --destroy --agent probe-agent --server probe-server
refusing to destroy without --yes (would remove agent probe-agent on probe-server)
# exit 2

$ bash scripts/bunker-provision.sh --destroy --yes --server probe-server
refusing to destroy: AGENT unset
# exit 2
```

- The missing-library direction, re-measured 2026-11-25 by copying only `bunker-provision.sh` into a directory with no `lib.sh`: CF-261 made it a named refusal that fires before argument parsing, so even `-h` refuses:

```
$ bash ./bunker-provision.sh --check --project demo
  FAIL  lib.sh — missing or unreadable: <dir>/lib.sh
# exit 1

$ bash ./bunker-provision.sh -h
  FAIL  lib.sh — missing or unreadable: <dir>/lib.sh
# exit 1 — before CF-261 this shape printed five `command not found` diagnostics and died at the
# `bunker_cli` guard, and `-h` still printed usage; the refusal now precedes both
```

- The false green is real, but it belongs to a different shape and was re-measured 2026-11-25: a `lib.sh` whose printers are byte-identical to the real ones except that `bad()` does not increment `FAILED` [scripts/lib.sh:7], plus a stub `bunker` client on a private `PATH` (answers `list`/`info`, prints nothing for `exec`). The run prints ten FAIL rows and still ends green:

```
  PASS  inputs — readable: none declared
bunker-provision --check — project=demo agent=stub-agent server=stub-server
  ..    resolved repo=<unset> ref=main harness=hermes namespaces=demo (primary demo) ttl=default(6h) crier=unset duckbrain=unset
  WARN  github_auth — mode=token with no GITHUB_TOKEN_FILE — clone may be unauthenticated
  PASS  bunker_cli — <stub>/bin/bunker
  PASS  server — stub-server reachable
  PASS  agent — stub-agent exists (stub-agent exists (uptime 1h))
  FAIL  repo — no clone at $HOME/repo — run --apply
  FAIL  node_json — $HOME/.node/node.json absent
  FAIL  auth_github — no $HOME/.node/auth/github.token
  FAIL  auth_duckbrain — no $HOME/.node/auth/duckbrain.token
  FAIL  crier_key — no $HOME/.node/agent.key — the inbox answers 401 to every read
  FAIL  crier_bearer — no $HOME/.node/auth/crier.token — a signed read still needs the bearer
  FAIL  git_credential — no $HOME/.git-credentials — the clone cannot authenticate
  FAIL  gateway_auth — no dashboard.basic_auth — the gateway will refuse to bind (CF-150)
  FAIL  commit_hook — no pre-commit hook — the gate is not armed
  FAIL  harness — no  binary on the node
  WARN  env_profile — no NODE_ENV_FILE or CONFIG_SET_* — the node's environment is declared nowhere
  WARN  crier — CRIER_URL unset — reachability unproven
  WARN  duckbrain — DUCKBRAIN_URL or token file unset — namespace unproven

BUNKER: PASS — every row above measured
# exit 0 — ten printed FAIL rows, none of them counted
```

  `FAILED=0` is the only thing the verdict tests [scripts/lib.sh:7] [scripts/bunker-provision.sh:466-467], so a library that stops counting turns a run full of printed failures green. Drop only the `FAILED=${FAILED:-0}` initialisation and the run instead aborts under `set -u`: `FAILED: unbound variable`, exit **1** — the first `bad()` call prints its row and then dies on the increment [scripts/lib.sh:7] [scripts/lib.sh:11] [scripts/bunker-provision.sh:63] (measured 2026-11-25; an earlier revision of this unit said exit 127 — the abort is a `set -u` unbound-variable exit, status 1). That is why exit 0 is only evidence when the count is non-zero — the rows alone do not save you, the tally does.
- The substring server test was re-measured 2026-11-25 with the same stub client: `--server s` printed `  PASS  server — s reachable` while the stub's only server was `stub-server` [scripts/bunker-provision.sh:301-302]. The `agent` row is fixed (CF-507): the same stub run shows `  PASS  agent — stub-agent exists (...)` only because the id appears as a whole token in the client's output [scripts/bunker-provision.sh:317-328].
- The CF-366 revocation and residue behaviour is fixture-tested, not live-measured: `tests/test_cf366_destroy_revocation.sh` drives a stub bus and a stub bunker client through the revoked / already-gone / never-existed / unarmed-token / refused-DELETE / unproven-DELETE arms and prints `CF-366 PASS`, re-run 2026-11-25 (exit 0); it is wired into the suite at [tests/selftest.sh:163-166]. A live-bus revocation is **not measured** — no bus was authorized for this re-derivation.
- Re-derived twice in one tick: the first derivation (committed `0c0d38ff`) named blob `301f7410` (the CF-366 blob); CF-537 (`965fad01`) landed while the first judge run was in flight and moved every locator after `:394`. This revision is derived at blob `4d1fde78`: the remap is again pure equal-block mapping (the CF-537 diff is two pure insertions, +22 at `:394` and +42 at `:683`), the destroy/refusal fixtures above were re-run at `965fad01` with identical outputs, and the CF-537 merge step is covered in §1, §2b, §5, §6 and §7.
- Standing mechanised checks: `tests/selftest.sh` §40 asserts the syntax, the absent-config refusal, the refusal to execute a shell line in the config, the empty-`PATH` FAIL, the `CLI_*`-only flag rule, the credential-file preflight row, that every documented config key parses, and the namespace-slug refusal [tests/selftest.sh:3326-4052].
- Status is VERIFIED on the strength of the runs above plus 367 locator references (256 distinct path:line pairs — counted as every bracketed `path:line` token in this file, a rule any reader can re-run with grep; every one re-pointed at the line whose content the sentence names at this revision); the residual risks are named in §6 instead of smoothed over — the three systemic ones being the present-but-non-incrementing `bad()` false green, the mode that `--check` never measures, and the substring server match — and the CF-366 revocation path is fixture-tested only, not live-measured.
