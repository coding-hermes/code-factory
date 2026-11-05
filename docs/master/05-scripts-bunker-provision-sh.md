# 05. scripts/bunker-provision.sh

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/bunker-provision.sh` [scripts/bunker-provision.sh:1] |
| Repository | `code-factory` [scripts/bunker-provision.sh:1] |
| Revision | `b3ed55c` — last commit touching this file, on `main` @ `55ddb92`; blob sha256 prefix `981f9972ce7c2c47` [scripts/bunker-provision.sh:1] |
| Status | **VERIFIED — 244 resolving locator references (154 distinct path:line pairs), re-run 2026-11-05, fact: FACT-05** |

## 1. Purpose and why it matters

- What it does: provisions exactly ONE project's bunker from a `KEY=VALUE` config file, with command-line overrides, in three modes — `--check`, `--apply`, `--destroy` [scripts/bunker-provision.sh:2-7].
- The config file is treated as DATA and is never sourced: a non-comment line must match `^([A-Z_][A-Z0-9_]*)=(.*)$` or the run is refused [scripts/bunker-provision.sh:9-10] [scripts/bunker-provision.sh:103-106]. A stray shell line therefore cannot execute [tests/selftest.sh:1971-1979].
- What breaks if this module is absent: nothing else in the repository turns a project + repo + harness triple into a working node, and the file's own header states the consequence of the hand path — a node's environment becomes "hand-edited state that cannot be diffed or re-applied" [scripts/bunker-provision.sh:26-29], and a node with a harness and no declared procedure is "a node whose foreman reports 'this run's tools are on the host'" [scripts/bunker-provision.sh:446-449].
- What breaks if it lies — three false reports are recorded in this file's own comments, each fixed: the inlined probe shipped literal backslashes and "reported a fully provisioned node as empty — a false negative that would have sent an operator to re-provision" [scripts/bunker-provision.sh:203-205]; a curl-only bus probe "reported a wired node as not connected" because a hardened bus checks the signature before the agent [scripts/bunker-provision.sh:262-264]; and four documented flags were "silently ignored whenever a config was also passed" [scripts/bunker-provision.sh:600-603].
- A lying run is not hypothetical and is measurable today: with `scripts/lib.sh` absent, every row printer degrades to `command not found`, the `FAILED` tally never increments, and the script exits **0** [scripts/bunker-provision.sh:36] [scripts/lib.sh:7] [scripts/bunker-provision.sh:304] — measured, §8.
- Idempotence is a stated contract: an existing agent is reused, an existing clone fast-forwarded, `node.json` rewritten only on a difference [scripts/bunker-provision.sh:31-33] [scripts/bunker-provision.sh:352-353] [scripts/bunker-provision.sh:514-515].

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `bash` (arrays, `printf -v`, process substitution) | no version check; the shebang is the contract [scripts/bunker-provision.sh:1] | the interpreter exec'd by the shebang | the kernel refusing exec; nothing inside the script checks it |
| `bunker` client | no version check; resolved once by `have bunker` [scripts/bunker-provision.sh:181-184] | `PATH` on the control host | `have` returns empty → `  FAIL  bunker_cli — no bunker client on PATH`, exit 1 [scripts/bunker-provision.sh:182] |
| `curl` | no version check [scripts/bunker-provision.sh:292] | `PATH` | the probe's `${code:-000}` substitutes `000`, which no accepted case matches, so the row is a named FAIL [scripts/bunker-provision.sh:292-296] |
| `python3` | no version check [scripts/bunker-provision.sh:147] | `PATH` on the control host AND on the node | control host: rc 127 lands in the catch-all → `  FAIL  env_profile — node_env.py --check exited 127 on the declaration` [scripts/bunker-provision.sh:152]; node: the seeder's exit drives `  FAIL  node_seed — apply exited <rc> on the node` [scripts/bunker-provision.sh:461-465] |
| `base64` | no version check [scripts/bunker-provision.sh:313] | `PATH` on the control host | the `agentkey_b64=` bundle line is missing, the node-side key never lands, and `--check` prints `  FAIL  crier_key — no $HOME/.node/agent.key` [scripts/bunker-provision.sh:237-238] |
| `timeout` (coreutils) | no version check [scripts/bunker-provision.sh:187] | `PATH` | the pipeline collapses, and because three call sites carry `|| true` the row degrades to a FAIL or an empty measurement rather than stopping the run [scripts/bunker-provision.sh:225-226] [scripts/bunker-provision.sh:268] |
| coreutils text tools (`sed`, `awk`, `grep`, `head`, `tail`, `tr`, `stat`, `mktemp`) | no version check [scripts/bunker-provision.sh:53] [scripts/bunker-provision.sh:220] [scripts/bunker-provision.sh:389] | `PATH` on both sides | each is unguarded; the affected row prints with an empty measured value and the `FAILED` tally is untouched — §6 |
| `git` | no version check; invoked inside the node probe [scripts/bunker-provision.sh:210-212] and for the clone itself, `git clone --depth 1 --branch "$REF"` [scripts/project-node.sh:702], which `node-create.sh` runs on the node [scripts/node-create.sh:121] | on the node | the probe prints `sha=` and `branch=` empty while `repo=present` still matches, so the row reads `clone present () branch , 0 dirty` [scripts/bunker-provision.sh:229] |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `. "$HERE/lib.sh"` (sourced, not a package) [scripts/bunker-provision.sh:36] | `scripts/lib.sh` | five printers — `say`, `ok`, `bad`, `warn`, `note` — plus `have` and `shq` [scripts/lib.sh:5-13] [scripts/lib.sh:54-57]; `bad()` is the ONLY thing that increments `FAILED` [scripts/lib.sh:7], and `FAILED` is initialised by the library, not by the caller [scripts/lib.sh:11] | the verdict and the exit status change meaning: a missing or renamed `bad` leaves `FAILED` at 0 and the script exits 0 on a failed run [scripts/bunker-provision.sh:304] |
| `python3 "$HERE/node_env.py" --check` [scripts/bunker-provision.sh:147] | `scripts/node_env.py` | a three-way exit contract: 0 and 1 both mean "the declaration parses" (1 = drift from an empty home), 2 is a refusal whose first `FAIL` line is quoted into the row, anything else is an unexpected exit [scripts/bunker-provision.sh:149-153] | a new exit code becomes `  FAIL  env_profile — node_env.py --check exited <rc> on the declaration`, and a shifted meaning of 1 would turn drift into a pass [scripts/bunker-provision.sh:150-152] |
| `python3 "$HERE/node_seed.py" build` / `apply` [scripts/bunker-provision.sh:454] [scripts/bunker-provision.sh:459-460] | `scripts/node_seed.py` | `build` writes `seed.tar` + `seed.tar.json` into the out dir and refuses a file outside the manifest, over budget, or digest-mismatched; `apply` exits 0 only when the node accepted the seed [scripts/bunker-provision.sh:446-450] | a build refusal prints `  FAIL  node_seed — build refused the declared seed` plus the first five log lines [scripts/bunker-provision.sh:471-473]; an apply refusal prints the node's exit code [scripts/bunker-provision.sh:464] |
| `python3 "$HERE/node_identity.py" <json> k=v ...` [scripts/bunker-provision.sh:521-522] | `scripts/node_identity.py` | MERGE semantics: the file's schema is owned elsewhere, so a wholesale rewrite would delete `node_id`/`repo`/`harness`/`bus` [scripts/bunker-provision.sh:514-515] | a schema change surfaces as `  FAIL  node_json — merge refused by the node (exit <rc>)` [scripts/bunker-provision.sh:528] |
| `python3 "$HERE/node_gateway_auth.py"` [scripts/bunker-provision.sh:486-487] | `scripts/node_gateway_auth.py` | exit 0 means `dashboard.basic_auth` is present in `config.yaml`; the password stays on the node [scripts/bunker-provision.sh:490-491] | the row becomes `  FAIL  gateway_auth — could not ensure dashboard.basic_auth (exit <rc>)` and `rc=1` [scripts/bunker-provision.sh:491] |
| `"$HERE/bunker-crier-connect.sh" --check` / `--stage` / `--apply` [scripts/bunker-provision.sh:268] [scripts/bunker-provision.sh:401] [scripts/bunker-provision.sh:539] | `scripts/bunker-crier-connect.sh` | the sentinel string `CRIER: CONNECTED` in stdout is the pass signal, and the first `PASS  inbox` / `FAIL ` line is quoted into the row [scripts/bunker-provision.sh:270-275] | a changed banner turns every connected node into `  FAIL  crier — ` with an empty detail, because the `*)` arm quotes whatever `FAIL ` line it finds [scripts/bunker-provision.sh:273-275] |
| `"$HERE/node-create.sh"` with `BUNKER_SERVER` and `CRIER_URL` in its environment [scripts/bunker-provision.sh:501-504] | `scripts/node-create.sh` | exit status only; a non-zero status is carried to `rc=1` and the run CONTINUES, because that script also owns the control-host round-trip check [scripts/bunker-provision.sh:507-511] | a new interpretation of exit 1 would either mask a real failure or turn a warning into `  FAIL  node_create` [scripts/bunker-provision.sh:510] |

### 2c. Service contracts (both sides must be named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| bunker server daemon on `$SERVER` | control host → daemon, and daemon → node on behalf of the control host [scripts/bunker-provision.sh:187] [scripts/bunker-provision.sh:369-390] | the `bunker` client's own transport; the client is resolved from `PATH` and never version-checked [scripts/bunker-provision.sh:181] | subcommands `list`, `info <agent>`, `spawn <agent> --ttl`, `cp <local> <agent>:<name>`, `exec <agent> -- bash -lc <text>`, `destroy <agent>`, each with `--server` [scripts/bunker-provision.sh:187] [scripts/bunker-provision.sh:194] [scripts/bunker-provision.sh:356] [scripts/bunker-provision.sh:368] [scripts/bunker-provision.sh:557] | the daemon is outside this repository; the client's assumed surface is pinned only by those calls, and `bunker list` is expected to print one line containing the server name [scripts/bunker-provision.sh:187-191] |
| crier bus (signer first, registry second) | node → bus [scripts/bunker-provision.sh:268-269] | HTTP through `node-bus-worker.py` on the node, with a per-agent ed25519 signature AND a shared bearer [scripts/bunker-provision.sh:237-240] (fact: FACT-03) | `GET /agents/<agent>/inbox/stats`, answered 200 only for a valid key+bearer (fact: FACT-04) | crier's `internal/registry/agentsig.go` on the bus side (fact: FACT-03); this script only delegates and reads the sentinel `CRIER: CONNECTED` [scripts/bunker-provision.sh:270-271] |
| DuckBrain HTTP service at `$DUCKBRAIN_URL` | control host → DuckBrain [scripts/bunker-provision.sh:291] | HTTP GET with the key handed to `curl` on STDIN via `-K -`, never in argv [scripts/bunker-provision.sh:289-292] (fact: FACT-05) | `GET /api/memories/key/x?namespace=<ns>`, one request per declared namespace; `200` and `404` are both accepted as "namespace answers", every other code is a FAIL [scripts/bunker-provision.sh:293-296] | the DuckBrain HTTP server is outside this repository; the accepted code set is the contract, and it was measured `404` for `namespace=code-factory` on 2026-11-05 (§8) |
| GitHub, as the HTTPS remote named by `REPO` | node → GitHub [scripts/bunker-provision.sh:385-387] | HTTPS credential store: `~/.git-credentials` at mode 600 plus `credential.helper = store --file=...` [scripts/bunker-provision.sh:384-388] (fact: FACT-05) | an `https://x-access-token:<token>@github.com` entry, written on the node, read by `git` during the clone [scripts/bunker-provision.sh:385] | the remote is whatever `REPO` names, and the clone is performed by `node-create.sh` [scripts/bunker-provision.sh:501-504]; an SSH remote is out of contract because no key is installed [config/bunker.example.conf:5-6] |
| Hermes gateway on the node, as the consumer of the declared environment | control host → node files, read by the gateway at start [scripts/bunker-provision.sh:406-409] | file writes inside the node: `~/.hermes/.env` and the five `CONFIG_SET_*` scalars in `~/.hermes/config.yaml` [scripts/bunker-provision.sh:26-28] | `--env-file` plus repeated `--config-set <dotted.key>=<value>`, applied by `node_env.py --apply` BEFORE the harness layer starts [scripts/bunker-provision.sh:417-432] | the gateway reads those files at start — the ordering requirement is stated at [scripts/bunker-provision.sh:406-409], and a profile applied afterwards "is a profile the run contradicts" [scripts/bunker-provision.sh:407-408] |

## 3. Verification

All commands below are read-only. The first measures a live node; the rest are the fail-closed fixtures. Run from the repository root.

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| Live preflight against a provisioned node | `bash scripts/bunker-provision.sh --config ~/.config/code-factory/code-factory.conf --check --agent cf-node --crier-url http://100.97.236.14:8767 --duckbrain-url http://100.97.236.14:3000` [scripts/bunker-provision.sh:178-304] | one row per measured surface (repo, `node.json`, four credentials, git store, gateway auth, gitreins, commit hook, harness), the bus row quoting `PASS  inbox`, then `BUNKER: FAIL (1)` because the three control-host token files named by the config are no longer on this host [scripts/bunker-provision.sh:163-174] | 2026-11-05T16:10Z | 16 `PASS` rows, 2 `WARN`, exit 1 — exactly the named `inputs` FAIL; verbatim output in §8 |
| Absent config is refused | `bash scripts/bunker-provision.sh --config /nonexistent.conf --check` [scripts/bunker-provision.sh:98] | `  FAIL  config — cannot read /nonexistent.conf`, exit 1 | 2026-11-05T16:12Z | PASS (as expected) |
| A shell line in the config is refused, never executed | `printf 'PROJECT=demo\nrm -rf /tmp/should-never-run\n' > /tmp/shell.conf; bash scripts/bunker-provision.sh --config /tmp/shell.conf --check` [scripts/bunker-provision.sh:103-106] | `  FAIL  config — /tmp/shell.conf:2 is not KEY=VALUE — refusing to run it`, exit 1, and the file is not created | 2026-11-05T16:12Z | PASS (as expected) |
| No bunker client on `PATH` | `env -i PATH=/usr/bin:/bin HOME="$HOME" bash scripts/bunker-provision.sh --check --project demo` [scripts/bunker-provision.sh:181-184] | `  FAIL  bunker_cli — no bunker client on PATH`, exit 1 | 2026-11-05T16:12Z | PASS (as expected) |
| A bad namespace slug is refused before any host is touched | `bash scripts/bunker-provision.sh --check --project demo --agent a --server s --namespaces 'bad slug!'` [scripts/bunker-provision.sh:76-82] | `  FAIL  namespaces — 'badslug!' is not a namespace slug (expected letters, digits, dot, dash, underscore)`, exit 1 — whitespace is stripped before validation [scripts/bunker-provision.sh:74] | 2026-11-05T16:12Z | PASS (as expected); the same assertion is mechanised in `tests/selftest.sh` §40 [tests/selftest.sh:2055-2060] |

## 4. Metrics emitted

**NONE.** No counter, histogram, exporter, timer or metrics endpoint exists in this file; the only machine-readable outputs are the process exit status [scripts/bunker-provision.sh:304] [scripts/bunker-provision.sh:547] and the in-process `FAILED` tally that the verdict line interpolates [scripts/lib.sh:7] [scripts/bunker-provision.sh:303] [scripts/bunker-provision.sh:546].

Consequences, stated so nobody hunts for a scrape target:

- Dispatch rate, provision latency and failure counts are not emitted. The only timing in the file is enforcement, not measurement — fixed `timeout` caps of 45s, 60s and 120s around individual calls [scripts/bunker-provision.sh:187] [scripts/bunker-provision.sh:226] [scripts/bunker-provision.sh:268].
- Node liveness is measured once, at run time, then discarded: `bunker info` decides `agent` [scripts/bunker-provision.sh:194-199] and the staged probe decides `repo`/`harness` [scripts/bunker-provision.sh:225-250]; neither is persisted as a number.
- What a monitoring lane can use is the exit status: 0 = every row measured and the apply's own `rc` clean, non-zero = at least one `FAIL` row, 2 = usage or a refused destroy [scripts/bunker-provision.sh:611] [scripts/bunker-provision.sh:552-553].
- The one persisted artefact is the node identity `node.json`, written with `provisioned_by` and `provisioned_at` [scripts/bunker-provision.sh:522] — a record that provisioning ran, not a metric.

## 5. Log lines it can generate

Everything below is printed to stdout by this script or by `scripts/lib.sh` on its behalf. There is no logger, no level filter, no destination and no retention: a line exists only in the terminal or in whatever captured it [scripts/lib.sh:5-9].

| Level | Line (verbatim) | Emitted when | Kind |
|---|---|---|---|
| PASS | `  PASS  <check> — <measured value>` (template `  PASS  %s — %s\n`; e.g. `  PASS  server — bunker-las-03 reachable`) | a measured row passed [scripts/lib.sh:6] [scripts/bunker-provision.sh:188] | evidentiary |
| FAIL | `  FAIL  <check> — <reason>` (template `  FAIL  %s — %s\n`; e.g. `  FAIL  bunker_cli — no bunker client on PATH`) | a measured row failed; this is the only arm that increments `FAILED` [scripts/lib.sh:7] [scripts/bunker-provision.sh:182] | evidentiary |
| WARN | `  WARN  <check> — <reason>` (e.g. `  WARN  crier — CRIER_URL unset — reachability unproven`) | a surface could not be proven and the run continues [scripts/lib.sh:8] [scripts/bunker-provision.sh:266] | descriptive |
| note | `  ..    <progress>` (template `  ..    %s\n`; e.g. `  ..    spawning cf-node (ttl 6h)`) | a step of a multi-step `--apply` [scripts/lib.sh:9] [scripts/bunker-provision.sh:355] | descriptive |
| info | `bunker-provision --check — project=code-factory agent=cf-node server=bunker-las-03` | first line of a `--check` run, before any measurement [scripts/bunker-provision.sh:178] | descriptive |
| info | `bunker-provision --apply — project=code-factory agent=cf-node server=bunker-las-03` | first line of an `--apply` run [scripts/bunker-provision.sh:336] | descriptive |
| info | `  ..    resolved repo=<path> ref=main harness=hermes namespaces=code-factory (primary code-factory) ttl=6h` | after namespace resolution, before the host is touched [scripts/bunker-provision.sh:179] | descriptive |
| info | `  PASS  config — code-factory.conf — 13 lines, KEY=VALUE only` | the config parsed; the count includes comment lines [scripts/bunker-provision.sh:122] | evidentiary |
| info | `  <file> mode <mode>` (template `  %s mode %s\n`; e.g. `  github.token mode 600`) | one line per installed credential file, printed from inside the node [scripts/bunker-provision.sh:389] | evidentiary |
| verdict | `BUNKER: PASS — every row above measured` | `--check` with no FAIL row [scripts/bunker-provision.sh:303] | evidentiary |
| verdict | `BUNKER: FAIL (<n>)` | `--check` with one or more FAIL rows; `<n>` is the tally [scripts/bunker-provision.sh:303] | evidentiary |
| verdict | `BUNKER APPLIED: <agent>` | `--apply` with `rc` 0 AND no FAIL row [scripts/bunker-provision.sh:546] | evidentiary |
| verdict | `BUNKER INCOMPLETE (<n>)` | `--apply` with any FAIL row or a carried `rc=1` [scripts/bunker-provision.sh:546] | evidentiary |
| refusal | `refusing to destroy without --yes (would remove agent <agent> on <server>)` | `--destroy` without `--yes`, exit 2 [scripts/bunker-provision.sh:552] | evidentiary |
| refusal | `refusing to destroy: AGENT unset` | `--destroy` with no agent, exit 2 [scripts/bunker-provision.sh:553] | evidentiary |
| refusal | `bunker client missing` | `--destroy` with no client on `PATH`, exit 1 [scripts/bunker-provision.sh:555] | evidentiary |
| usage | `unknown argument: <arg>` followed by the usage block | an unrecognised flag; exit 2 [scripts/bunker-provision.sh:585] | descriptive |
| pass-through | `bunker: reading server "<server>"` | printed by the bunker client itself and quoted into the `agent` row as that row's measured value [scripts/bunker-provision.sh:195] | descriptive |

Two lines are notable because they carry NO measured value and still count as evidence: `  FAIL  crier — ` (empty detail, when the bus probe produced no `FAIL ` line — e.g. a 120s timeout) [scripts/bunker-provision.sh:268-275], and `  ..    preflight rows were not all green; --apply repairs what it can`, which replaces the suppressed preflight output [scripts/bunker-provision.sh:617].

## 6. Failure modes

Direction: **local** = the failure is reported as something else on this host; **remote** = the failure lives on the node or a peer; **degraded** = the run continues with a weaker guarantee.

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| `scripts/lib.sh` absent or renamed (degraded, false green) | every printer becomes `command not found`; `FAILED` stays 0, so the final test passes and the process exits **0** [scripts/bunker-provision.sh:36] [scripts/lib.sh:7] [scripts/bunker-provision.sh:304] — measured, §8 | nothing inside the script distinguishes it; only the shell's own `No such file or directory` on line 36 does [scripts/bunker-provision.sh:36] | restore `lib.sh` next to the script; treat exit 0 with no `PASS`/`FAIL` rows as a library failure, never a pass |
| `bunker` client absent (local, fail-closed) | `  FAIL  bunker_cli — no bunker client on PATH`, exit 1 before any host call [scripts/bunker-provision.sh:181-184] | distinct from an unreachable host, which fails the next row instead [scripts/bunker-provision.sh:187-191] | install the client on the control host `PATH` |
| Host unreachable (local direction) | `--check`: `  FAIL  server — <server> not listed by 'bunker list'` after a 45s cap [scripts/bunker-provision.sh:187-191]. `--apply` NEVER consults that row: it goes to `bunker info`, then `spawn`, whose failure prints `  FAIL  agent — spawn failed: <last line of /tmp/cf-spawn.log>` [scripts/bunker-provision.sh:352-360] | a dead host and a server that does not exist produce the SAME row; a partition is reported as absence [scripts/bunker-provision.sh:190] | re-run `--check` once reachable; read `/tmp/cf-spawn.log` for the spawn arm [scripts/bunker-provision.sh:359] |
| Server name is a substring of any `bunker list` line (local, false green) | `--server s` passes: measured `  PASS  server — s reachable` while no server named `s` exists [scripts/bunker-provision.sh:187-188] | distinguished only by reading the client's own list output; the test is `grep -q -- "$SERVER"`, not an exact match [scripts/bunker-provision.sh:187] | always pass the full server id; a short or generic name can never fail this row |
| A credential file named by the config is missing (degraded) | `--check` names it: `  FAIL  inputs — not readable: <NAME>(<path>) ...`, one row covering all six files [scripts/bunker-provision.sh:163-174]. `--apply` continues: each unreadable file is skipped when the bundle is built [scripts/bunker-provision.sh:310-329], and an empty bundle only warns: `  WARN  auth — no token files named in config — the clone will run unauthenticated` [scripts/bunker-provision.sh:395] | the check's `inputs` row versus the apply's `auth` row — different ids, different severity, same cause [scripts/bunker-provision.sh:171-173] | provide the files at mode 600 on the control host; run `--check` first, which is why the preflight validates them before touching a host [scripts/bunker-provision.sh:159-161] |
| Preflight fails but `--apply` continues (degraded, evidence loss) | the preflight runs in a subshell with BOTH streams discarded, so its FAIL rows never reach the operator; one note replaces them: `  ..    preflight rows were not all green; --apply repairs what it can` [scripts/bunker-provision.sh:614-618] | nothing else distinguishes it — the apply's verdict counts only its own rows [scripts/bunker-provision.sh:615-616] | run `--check` separately and keep its output; that is the only place the preflight's rows exist |
| `CRIER_URL` unset (degraded) | `--apply`: `  FAIL  crier_url — CRIER_URL unset — a node must know its bus (set it in the config or --crier-url)` and the run CONTINUES, so the node still gets its identity [scripts/bunker-provision.sh:341-346] | `--check` warns instead: `  WARN  crier — CRIER_URL unset — reachability unproven` [scripts/bunker-provision.sh:265-266] | set `CRIER_URL` in the config or on the command line; the CLI wins (§7) |
| Bus probe times out, or the bus refuses (remote) | `  FAIL  crier — ` with an empty detail after a 120s cap, because the `*)` arm quotes the first `FAIL ` line and there is none [scripts/bunker-provision.sh:268-275] | a signed-read rejection carries its `FAIL` line; an empty detail means the probe never spoke — run `scripts/bunker-crier-connect.sh --check` directly [scripts/bunker-provision.sh:268-269] | re-run the connect script alone; a bus that checks the signature before the agent answers 401 to anything unsigned (fact: FACT-03) |
| DuckBrain token unreadable or URL unset (degraded) | one warn for BOTH causes: `  WARN  duckbrain — DUCKBRAIN_URL or token file unset — namespace unproven` [scripts/bunker-provision.sh:278-299] | a reachable service with a wrong key produces per-namespace FAILs carrying the code: `  FAIL  duckbrain:<ns> <url> namespace=<ns> -> 401` [scripts/bunker-provision.sh:293-296] | fix the named cause; only `200` and `404` are accepted [scripts/bunker-provision.sh:294] |
| `node-create.sh` reports FAIL (remote, carried) | `  FAIL  node_create — node-create.sh reported FAIL — see its rows; continuing with the identity`, `rc=1`, and the run still writes `node.json` [scripts/bunker-provision.sh:504-512] | the status is carried, so the final line is `BUNKER INCOMPLETE (n)` rather than a silent success [scripts/bunker-provision.sh:546-547] | read that script's rows; the identity write is intentional, not a masked failure [scripts/bunker-provision.sh:507-509] |
| Seed build refuses the declared seed (local) | `  FAIL  node_seed — build refused the declared seed — see the row above`, plus the first five lines of the build log indented with `    | ` [scripts/bunker-provision.sh:471-473] | distinct from a staging failure, which reads `could not stage the seed` [scripts/bunker-provision.sh:469] | fix the manifest or the file it names; the seed is a declared list with digests [scripts/bunker-provision.sh:446-450] |
| `--node-env-file` given a `~/...` path on the command line (local) | the tilde is NOT expanded for this flag, so the literal string is used: measured `  FAIL  inputs — not readable: NODE_ENV_FILE(~/nope.env)`; apply then refuses with `  FAIL  env_profile — NODE_ENV_FILE ~/nope.env is unreadable` [scripts/bunker-provision.sh:581] [scripts/bunker-provision.sh:414-415] | the five token-file flags DO expand it [scripts/bunker-provision.sh:576-580] [scripts/bunker-provision.sh:59] | pass an absolute path, or put `NODE_ENV_FILE` in the config, which expands `~/` at parse time [scripts/bunker-provision.sh:117] |
| `--destroy` without `--yes` or without `AGENT` (refused) | `refusing to destroy without --yes (would remove agent <agent> on <server>)` or `refusing to destroy: AGENT unset`, exit 2 [scripts/bunker-provision.sh:552-553] | distinct from a failed destroy: `  FAIL  destroy — bunker destroy failed`, exit 1 [scripts/bunker-provision.sh:557] | re-run deliberately with `--yes` and a named agent |
| Any unguarded command fails (degraded) | the script runs without `-e` — only `-uo pipefail` [scripts/bunker-provision.sh:34] — so a failed `cp`, `sed` or `stat` prints its own stderr and the run proceeds | nothing marks it as a row; the effect surfaces later as an empty measured value | read the stderr; a row rendering `clone present () branch , 0 dirty` is the tell [scripts/bunker-provision.sh:229] |

## 7. Environment and settings it reads

Every key the config parser accepts [scripts/bunker-provision.sh:109-120], every flag the parser understands [scripts/bunker-provision.sh:562-587], and the two process variables actually read (`HOME` at [scripts/bunker-provision.sh:35] and [scripts/bunker-provision.sh:117]; `PATH` through `have` [scripts/lib.sh:13]).

| Setting (config key / flag) | Default when unset | Effect if unset |
|---|---|---|
| `PROJECT` / `--project` | none | namespaces fall back to `PROJECT`, so an empty value gives `  FAIL  namespaces — no namespace declared and PROJECT is unset` [scripts/bunker-provision.sh:67-70]; `--apply` refuses with `  FAIL  project — PROJECT unset in config`, exit 1 [scripts/bunker-provision.sh:338] |
| `AGENT` / `--agent` | none | `--check`: `  FAIL  agent — AGENT unset`, exit 1 [scripts/bunker-provision.sh:193]; `--destroy`: refused, exit 2 [scripts/bunker-provision.sh:553] |
| `SERVER` / `--server` | none | `--check`: `  FAIL  server — SERVER unset — no host to provision on`, exit 1 [scripts/bunker-provision.sh:186]; `--apply`: `  FAIL  server — SERVER unset`, exit 1 [scripts/bunker-provision.sh:340] |
| `REPO` / `--repo` | none | `--apply` refuses with `  FAIL  repo — REPO unset in config`, exit 1; `--check` only prints the resolved value [scripts/bunker-provision.sh:339] [scripts/bunker-provision.sh:179] |
| `REF` / `--ref` | `main` | the clone uses `main` and the resolved line prints `ref=main` [scripts/bunker-provision.sh:501] [scripts/bunker-provision.sh:179] |
| `HARNESS` / `--harness` | `hermes` | `--apply` passes `hermes` to `node-create.sh`, which also gates the gateway-auth step on this value [scripts/bunker-provision.sh:481] [scripts/bunker-provision.sh:502] |
| `NAMESPACES` / `--namespaces` | `NAMESPACE`, then `PROJECT` | the list resolves in that order; a duplicate is collapsed with `  WARN  namespaces — '<ns>' declared twice — collapsed`, and an empty result is a FAIL [scripts/bunker-provision.sh:65-92] |
| `NAMESPACE` / `--namespace` | first entry of `NAMESPACES`, else `PROJECT` | becomes the primary namespace written to `node.json` as `namespace=` and the single-namespace alias [scripts/bunker-provision.sh:91] [scripts/bunker-provision.sh:522] |
| `TTL` (no flag) | `6h` in `--apply`, `default(6h)` in the resolved line | the spawn gets `--ttl 6h` and the row prints `  ..    spawning <agent> (ttl 6h)` [scripts/bunker-provision.sh:355-356] |
| `GIT_AUTHOR_NAME`, `GIT_AUTHOR_EMAIL`, `GIT_CO_AUTHOR` | none | parsed and accepted by the config parser [scripts/bunker-provision.sh:112-113], and the header states they are required for `--apply` because the node commits [scripts/bunker-provision.sh:18]. No line after parsing reads them [scripts/bunker-provision.sh:39] — the value reaches the node only through a path outside this script, so setting it here changes nothing that this file measures |
| `GITHUB_TOKEN_FILE` / `--github-token-file` | none | no GitHub token is bundled; the clone runs unauthenticated and the node gets no `~/.git-credentials` [scripts/bunker-provision.sh:310] [scripts/bunker-provision.sh:384-388] |
| `DUCKBRAIN_TOKEN_FILE` / `--duckbrain-token-file` | none | the DuckBrain probe warns `namespace unproven` even when the URL is set, because the guard requires both [scripts/bunker-provision.sh:278] [scripts/bunker-provision.sh:299] |
| `S3_ENV_FILE` / `--s3-env-file` | none | no `~/.node/auth/s3.env` is installed; the node-side script removes an empty file rather than leaving a zero-byte one [scripts/bunker-provision.sh:327-329] [scripts/bunker-provision.sh:377-378] |
| `CRIER_AGENT_KEY_FILE` / `--crier-agent-key-file` | none | no `~/.node/agent.key`; the bus answers 401 to every read, and `--check` prints `  FAIL  crier_key — no $HOME/.node/agent.key — the inbox answers 401 to every read` [scripts/bunker-provision.sh:237-238] |
| `CRIER_AUTH_TOKEN_FILE` / `--crier-auth-token-file` | none | no bearer; the row is `  FAIL  crier_bearer — no $HOME/.node/auth/crier.token — a signed read still needs the bearer` [scripts/bunker-provision.sh:239-240]. The file may be a plain token OR an EnvironmentFile, from which `CR_AUTH_TOKEN=` is extracted [scripts/bunker-provision.sh:316-325] |
| `CRIER_URL` / `--crier-url` | none | `--check` warns `reachability unproven` [scripts/bunker-provision.sh:266]; `--apply` records `  FAIL  crier_url` and still provisions [scripts/bunker-provision.sh:346] |
| `DUCKBRAIN_URL` / `--duckbrain-url` | none | the per-namespace probe is skipped and one warn covers URL and token together [scripts/bunker-provision.sh:278-299] |
| `NODE_ENV_FILE` / `--node-env-file` | none | no profile is staged; with no `CONFIG_SET_*` either, the row is `  WARN  env_profile — no NODE_ENV_FILE or CONFIG_SET_* — the node's environment is declared nowhere` [scripts/bunker-provision.sh:259] [scripts/bunker-provision.sh:443] |
| `CONFIG_SET_MODEL_PROVIDER` | none | omitted from the `--config-set` stream, so `model.provider` on the node is left as it is [scripts/bunker-provision.sh:129] |
| `CONFIG_SET_MODEL_NAME` | none | omitted, so `model.name` is untouched [scripts/bunker-provision.sh:130] |
| `CONFIG_SET_GATEWAY_BIND` | none | omitted, so `gateway.bind` is untouched [scripts/bunker-provision.sh:131] |
| `CONFIG_SET_GATEWAY_PORT` | none | omitted, so `gateway.port` is untouched [scripts/bunker-provision.sh:132] |
| `CONFIG_SET_AGENT_MAX_ITERATIONS` | none | omitted, so `agent.max_iterations` is untouched [scripts/bunker-provision.sh:133] |
| `--config` | none | no config is read; every value must come from a flag, and `--check --project demo` alone reaches `  FAIL  bunker_cli` or the next missing value [scripts/bunker-provision.sh:590] |
| `--config-set <dotted.key>=<value>` (repeatable) | none | each value is appended AFTER the config's own, so the command line's last value wins inside `node_env.py` [scripts/bunker-provision.sh:134] [scripts/bunker-provision.sh:582] |
| `--check` / `--apply` / `--destroy` | none | no mode exits 2 through `usage` [scripts/bunker-provision.sh:611] |
| `--yes` | 0 | `--destroy` refuses without it, exit 2 [scripts/bunker-provision.sh:552] |
| `-h` / `--help` | — | prints lines 2-30 of this file with the leading `# ` stripped, exit 0 [scripts/bunker-provision.sh:52-55] |

Precedence — the command line now WINS over the config file. Flags are parsed into `CLI_*` variables only [scripts/bunker-provision.sh:566-582], the config is loaded next [scripts/bunker-provision.sh:590], and the `CLI_*` values are then re-applied on top [scripts/bunker-provision.sh:591-609]. This is the 2026-11-05 correction to a defect where five flags — `--duckbrain-url`, `--github-token-file`, `--duckbrain-token-file`, `--crier-agent-key-file`, `--crier-auth-token-file` — were assigned during parsing and then overwritten by `load_config`, "so a documented flag was silently ignored whenever a config was also passed" [scripts/bunker-provision.sh:600-603]; `tests/selftest.sh` now fails any flag handler that assigns a non-`CLI_*` name [tests/selftest.sh:1988-1997]. Measured proof: the config this run used names `AGENT=cf-code-factory` [config/bunker.example.conf:9] while the command line carried `--agent cf-node`, and the header printed `agent=cf-node` [scripts/bunker-provision.sh:178].

The preflight validates the files it will read, before any host is touched: all six `*_FILE` values are tested for readability and the unreadable ones are named in a single `inputs` row [scripts/bunker-provision.sh:159-174]. That row is also the only proof that a `--flag` reached its variable, since the check reads the post-precedence values [scripts/bunker-provision.sh:159-161]. `~/` is expanded for the five token-file flags at parse time [scripts/bunker-provision.sh:576-580] and for every `*_FILE` key at config parse time [scripts/bunker-provision.sh:116-118]; `--node-env-file` is the one flag left unexpanded [scripts/bunker-provision.sh:581].

## 8. Evidence of record

- What a reviewer re-runs, and what it printed on 2026-11-05.

```
$ cd ~/proj-wt-md-05   # main @ 55ddb92, scripts/bunker-provision.sh blob b3ed55c, sha256 981f9972ce7c2c47
$ bash scripts/bunker-provision.sh --config ~/.config/code-factory/code-factory.conf --check \
    --agent cf-node --crier-url http://100.97.236.14:8767 --duckbrain-url http://100.97.236.14:3000
  PASS  config — code-factory.conf — 13 lines, KEY=VALUE only
  FAIL  inputs — not readable: GITHUB_TOKEN_FILE(/home/kara/.config/code-factory/code-factory/github.token) DUCKBRAIN_TOKEN_FILE(/home/kara/.config/code-factory/code-factory/duckbrain.token) S3_ENV_FILE(/home/kara/.config/code-factory/code-factory/s3.env)
bunker-provision --check — project=code-factory agent=cf-node server=bunker-las-03
  ..    resolved repo=/home/kara/code-factory ref=main harness=hermes namespaces=code-factory (primary code-factory) ttl=6h
  PASS  bunker_cli — /home/kara/.local/bin/bunker
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
```

- The same probe the script runs, issued by hand, to prove the DuckBrain contract accepts a missing key path as `404` rather than an error [scripts/bunker-provision.sh:289-296]:

```
$ code=$(printf 'header = "x-api-key: %s"\nurl = "%s"\n' \
    "$(head -c 4096 ~/.duckbrain/9router-foreman.token | tr -d '\r\n')" \
    "http://100.97.236.14:3000/api/memories/key/x?namespace=code-factory" \
  | curl -s -K - -o /dev/null -m 8 -w '%{http_code}'); echo "${code:-000}"
404
```

- Fail-closed fixtures, all re-runnable on any host with no bunker server; outputs verbatim:

```
$ bash scripts/bunker-provision.sh --config /nonexistent.conf --check
  FAIL  config — cannot read /nonexistent.conf
# exit 1

$ printf 'PROJECT=demo\nrm -rf /tmp/should-never-run\n' > /tmp/shell.conf
$ bash scripts/bunker-provision.sh --config /tmp/shell.conf --check
  FAIL  config — /tmp/shell.conf:2 is not KEY=VALUE — refusing to run it
# exit 1, and /tmp/should-never-run was never created

$ env -i PATH=/usr/bin:/bin HOME="$HOME" bash scripts/bunker-provision.sh --check --project demo
  PASS  inputs — every named credential and profile file is readable
bunker-provision --check — project=demo agent=<unset> server=<unset>
  ..    resolved repo=<unset> ref=main harness=hermes namespaces=demo (primary demo) ttl=default(6h)
  FAIL  bunker_cli — no bunker client on PATH
# exit 1

$ bash scripts/bunker-provision.sh --check --project demo --agent a --server s --namespaces 'bad slug!'
  FAIL  namespaces — 'badslug!' is not a namespace slug (expected letters, digits, dot, dash, underscore)
# exit 1
```

- The false green in §1 and §6 was measured, not inferred: a copy of the script placed in a directory with no `lib.sh` printed `line 36: .../lib.sh: No such file or directory`, then `ok: command not found` and `bad: command not found` on every row, and exited **0** [scripts/bunker-provision.sh:36] [scripts/lib.sh:7]. That is why a reviewer must never accept a bare exit 0 without a `BUNKER: PASS` or `BUNKER APPLIED` line beside it [scripts/bunker-provision.sh:303] [scripts/bunker-provision.sh:546].
- The substring server test was measured too: `--server s` printed `  PASS  server — s reachable` on a host whose only agent belongs to `bunker-las-03` [scripts/bunker-provision.sh:187-188].
- Standing mechanised checks: `tests/selftest.sh` §40 asserts the syntax, the absent-config refusal, the refusal to execute a shell line in the config, the empty-`PATH` FAIL, the `CLI_*`-only flag rule, the credential-file preflight row, that every documented config key parses, and the namespace-slug refusal [tests/selftest.sh:1960-2060].
- Status is VERIFIED on the strength of the run above plus 244 resolving locator references (154 distinct path:line pairs, every one of them resolving against this revision); the residual risks are named in §6 instead of smoothed over — the two systemic ones being the missing-library exit 0 and the substring server match.
