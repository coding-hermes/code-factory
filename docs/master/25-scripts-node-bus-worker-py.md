# 25. scripts/node-bus-worker.py

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/node-bus-worker.py` — 1289 lines [scripts/node-bus-worker.py:1] |
| Repository | `code-factory` [scripts/node-bus-worker.py:1] |
| Revision | `e7cf075` — the `origin/main` tip every locator below was measured against; the file's own last-touching commit is `e149d1a` (2026-11-04, "feat(bus): the node consumes its own inbox — signer, brief digest, harness, reply with corr_id, ack") [scripts/node-bus-worker.py:1289] |
| Status | **RED — rows 1-9 of §3 measured on 2026-11-05; row 10 (the signed read returning 200 on a live bus) is UNKNOWN because no node key exists on this host** |

## 1. Purpose and why it matters

- What it is: the **node half** of the crier bus — `inbox in, harness, result out, ack` [scripts/node-bus-worker.py:2]. One poll is fetch → verify → run → reply → ack [scripts/node-bus-worker.py:5], and `--check` is the same identity ladder without any side effect [scripts/node-bus-worker.py:41-45].
- Why it matters: it is the only component on a node that can **produce a signed read**. The bus verifies two credentials on every agent-scoped read — the shared bearer and a per-agent ed25519 signature over `"<METHOD>\n<path>\n<unix-seconds>"` [scripts/node-bus-worker.py:11-25] — and crier refuses an unsigned read with 401 by design [docs/master/_facts.md:14] (fact: FACT-03). An unsigned probe therefore cannot tell "not registered" from "not signed", and `scripts/bunker-crier-connect.sh` says so in its own comment before falling back to one [scripts/bunker-crier-connect.sh:46-48]. The signed read is 200 (fact: FACT-04); that is the probe that means anything.
- The credential it holds: a PKCS#8 PEM ed25519 key read and used **in memory only**, signed by a stdlib-only RFC 8032 implementation, never printed and never created [scripts/node-bus-worker.py:26-29] [scripts/node-bus-worker.py:272-296]. A node without key material is a node that is not registered, and the refusal says so by path [scripts/node-bus-worker.py:496-503].
- What breaks if it is ABSENT: every delivery to that agent accumulates in its durable inbox and nothing retrieves, runs or acks it. Ack is the only terminal transition, and crier will not accept one without `lease_id` + `message_ids` from the lease owner [/home/kara/crier/internal/registry/handler.go:1812-1826]. Delivery still answers 201 (the message is stored), so **the bus cannot distinguish "node is working" from "nothing is consuming the inbox"** — the queue depth is the only symptom [/home/kara/crier/internal/registry/handler.go:502-506].
- Absence is **not** currently detected by provisioning: the node staged set is `project-node.sh install-go.sh lib.sh disk_floor.py reclaim_disk.py harness/install-$HARNESS.sh` and does not include this file [scripts/node-create.sh:23], while the connect script probes `$HOME/node-bus-worker.py` on the node [scripts/bunker-crier-connect.sh:53]. `docs/OPERATIONS.md:209` states "it is staged by provisioning" — that claim is contradicted by the staged set. The only mechanical checks that exist are the repo battery's five legs [tests/selftest.sh:2518-2587] and the connect probe, which greps this worker's own `PASS  inbox` / `FAIL  inbox` row [scripts/bunker-crier-connect.sh:56-60].
- What breaks if it LIES: nothing on the control plane re-derives its rows. `--check` prints `BUS WORKER: READY` when its **own** rows all pass [scripts/node-bus-worker.py:667-672]. Of the nine rows `check()` can print, only two touch the bus at all — `bus_health` and the signed `inbox` read — and one of the rest (`key_registry`) warns instead of failing, so READY is mostly a claim about the node's files, not about the bus. The single row that is externally witnessed is `inbox` — the signed read [scripts/node-bus-worker.py:569-592]. A runbook quoting a stale READY (`docs/LOOP-CODEX.md:19`) and a live one are byte-identical.
- Blast radius: one worker per agent id. The identity, the key and the clone are all `$HOME`-scoped and the worker refuses a `--workdir` outside `$HOME` [scripts/node-bus-worker.py:1263-1269]; the harness runs with `cwd` inside the clone and `HOME` re-exported [scripts/node-bus-worker.py:708-721]. Because one bunker serves one project (fact: FACT-02) and the foreman runs there, not on the control host (fact: FACT-01), the worker is the only path by which that project's lanes receive work.

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `python3` | 3.14.9 measured here; the file is stdlib-only and uses no version-gated syntax | On the node, invoked directly — the file is a `#!/usr/bin/env python3` script [scripts/node-bus-worker.py:1] | **Not detected by this module.** Its own `--check` never probes the interpreter that is already running it; absence surfaces as the spawner's `127`. The connect probe guards on the key, the token and the file before invoking it [scripts/bunker-crier-connect.sh:53] |
| ed25519 private key, PKCS#8 PEM | any key from `openssl genpkey -algorithm ED25519` | `$HOME/.node/agent.key`, or `--key` [scripts/node-bus-worker.py:340] | `load_seed` raises `FileNotFoundError` [scripts/node-bus-worker.py:221-222] → `FAIL  signing_key — <path> absent` and `failures += 1` [scripts/node-bus-worker.py:496-503]. `--once` refuses before any network call [scripts/node-bus-worker.py:1021-1030] |
| bearer token file | one line of text, mode 600 recommended | `$HOME/.node/auth/crier.token`, or `--token-file`, or `CRIER_AUTH_TOKEN` [scripts/node-bus-worker.py:341-343] [scripts/node-bus-worker.py:398-415] | `bearer()` returns `("", reason)` with the reason naming the file [scripts/node-bus-worker.py:400-415] → `FAIL  bus_bearer` [scripts/node-bus-worker.py:526-532] |
| `node.json` and/or `crier.json` | JSON objects | `$HOME/.node/node.json`, `$HOME/.node/crier.json`, or `--identity` / `--bus-identity` [scripts/node-bus-worker.py:338-339] | `_read` records one error string and returns `{}` [scripts/node-bus-worker.py:370-386]; both absent → `FAIL  identity — … are both absent` [scripts/node-bus-worker.py:456-458]; unparsable → `FAIL  identity — … is not readable JSON (…)` [scripts/node-bus-worker.py:378-382] |
| the clone (a git work tree) | any | `node.json.repo.path`, or `--workdir`, and must resolve inside `$HOME` [scripts/node-bus-worker.py:363-364] [scripts/node-bus-worker.py:1263-1269] | **Only partially.** The `--workdir` flag is checked [scripts/node-bus-worker.py:1263-1269] and a dispatch's `workdir` is checked against the clone [scripts/node-bus-worker.py:862-877], but the declared `repo.path` itself is never `isdir`-checked: a missing clone degrades to `git_field` returning `""` [scripts/node-bus-worker.py:741-752] and `run_harness` falling back to `ident.home` [scripts/node-bus-worker.py:708] |
| harness binary | any executable | `node.json.harness.cmd`, `--harness-cmd`, or `$HOME/hermes-venv/bin/hermes` [scripts/node-bus-worker.py:417-427] | `os.path.exists` → `FAIL  harness — <binary> absent`, `os.access(X_OK)` → `FAIL  harness — <binary> is not executable` [scripts/node-bus-worker.py:634-639] |
| harness gateway on `127.0.0.1:10800` | HTTP | same node | One GET of `/api/status` → `FAIL  gateway — … -> 000` [scripts/node-bus-worker.py:655-665] |
| `/bin/sh` | any | the node | `run_gate` runs `["/bin/sh", "-lc", command]` and returns `gate could not run: …` on `OSError` [scripts/node-bus-worker.py:755-772] — the row is `FAIL  gate`, not a refusal |
| `git` | any | on `PATH`, clone scoped | **Silently.** `git_field` swallows `OSError`/timeouts and any non-zero exit into `""` [scripts/node-bus-worker.py:741-752], so `branch`/`commit` are simply absent from the envelope [scripts/node-bus-worker.py:930-931] |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `argparse` [scripts/node-bus-worker.py:58] | stdlib | A mutually exclusive mode group `--check` / `--once` / `--loop` [scripts/node-bus-worker.py:1170-1179], and `parser.error(...)` for "no mode" — which exits **2** with the usage text [scripts/node-bus-worker.py:1245-1248] | The mode guard becomes an unhandled usage path; exit 2 is what the battery's `rc -ne 0` legs depend on [tests/selftest.sh:2547-2552] |
| `base64` [scripts/node-bus-worker.py:59] | stdlib | `b64decode` of a message `payload` into JSON bytes [scripts/node-bus-worker.py:1100-1101]; `b64decode(..., validate=True)` of the PEM body [scripts/node-bus-worker.py:236] | A dispatch payload that stops being base64 becomes `FAIL  payload — … is not base64 JSON (…); left unacked`, i.e. a permanently redelivered message [scripts/node-bus-worker.py:1102-1109] |
| `hashlib` [scripts/node-bus-worker.py:60] | stdlib | `sha256` for `brief.digest` [scripts/node-bus-worker.py:823] and `X-Agent-Body-SHA256` [scripts/node-bus-worker.py:286]; `sha512` inside the ed25519 implementation [scripts/node-bus-worker.py:171] [scripts/node-bus-worker.py:180] | The digest leg goes red for every dispatch, and every signature becomes unverifiable; both are fail-closed refusals, not silent passes |
| `json` [scripts/node-bus-worker.py:61] | stdlib | Identity files are dicts (a non-dict is `not a JSON object` [scripts/node-bus-worker.py:383-385]); `seen` cache is a dict [scripts/node-bus-worker.py:680-696]; envelope encode `separators=(",", ":")` [scripts/node-bus-worker.py:952] | Key renames in either identity file become silent empties (`.get(...) or ""` at [scripts/node-bus-worker.py:347-366]); a renamed `messages`/`lease_id` silently yields zero messages and an unacked batch [scripts/node-bus-worker.py:1083-1093] |
| `os` [scripts/node-bus-worker.py:62] | stdlib | `environ.get("CRIER_AUTH_TOKEN")` [scripts/node-bus-worker.py:412], `stat` modes [scripts/node-bus-worker.py:395-396] [scripts/node-bus-worker.py:505], `realpath` containment [scripts/node-bus-worker.py:430-436], atomic `replace` for the seen cache [scripts/node-bus-worker.py:689-696] | Mode enforcement (the 0o077 refusal [scripts/node-bus-worker.py:512-518]) and the `$HOME` containment rule disappear together with it |
| `re` [scripts/node-bus-worker.py:63] | stdlib | One PEM block pattern `-----BEGIN ([A-Z ]+)-----(.*?)-----END \1-----` with `re.S` [scripts/node-bus-worker.py:229] | A loosened pattern admits a non-PKCS#8 label; the label check refuses anything but `PRIVATE KEY` [scripts/node-bus-worker.py:232-234] |
| `shlex` [scripts/node-bus-worker.py:64] | stdlib | `shlex.split` of a string `harness.cmd` [scripts/node-bus-worker.py:422-423] — tokenised, then executed by argv, never by a shell [scripts/node-bus-worker.py:713-721] | Quoting in an operator's `harness.cmd` changes the argv it produces; a cmd designed for a shell silently loses its pipes and redirections |
| `socket` [scripts/node-bus-worker.py:65] | stdlib | `gethostname()` written into `host_identity` of every result and refusal [scripts/node-bus-worker.py:783] [scripts/node-bus-worker.py:926] | The envelope loses the only field that says **which** node ran the work |
| `subprocess` [scripts/node-bus-worker.py:66] | stdlib | `run(..., capture_output=True, text=True, timeout=…, stdin=DEVNULL)` for the harness [scripts/node-bus-worker.py:713-721], the gate [scripts/node-bus-worker.py:763-770], `git` [scripts/node-bus-worker.py:743-749] and `--version` [scripts/node-bus-worker.py:643-649] | A harness that demands a TTY fails instantly (`stdin` is `/dev/null`); a timeout is classified as `wall limit <n>s exceeded` [scripts/node-bus-worker.py:722-723] |
| `sys` [scripts/node-bus-worker.py:67] | stdlib | Argument refusals go to **stderr** with exit 2 [scripts/node-bus-worker.py:1251-1269]; `sys.exit(main(sys.argv[1:]))` [scripts/node-bus-worker.py:1289] | The battery greps `$out` from `2>&1` [tests/selftest.sh:2545], so only an operator reading the stream alone would notice |
| `time` [scripts/node-bus-worker.py:68] | stdlib | `int(time.time())` for `X-Agent-Ts` [scripts/node-bus-worker.py:282] — the bus allows ±30 s [/home/kara/crier/internal/registry/agentsig.go:41]; `gmtime` for `finished_at` [scripts/node-bus-worker.py:934] | A clock that drifts past 30 s turns every signed read into `401 … request timestamp outside allowed window (±30s)` [/home/kara/crier/internal/registry/agentsig.go:230-236] |
| `urllib.error`, `urllib.request` [scripts/node-bus-worker.py:69-70] | stdlib | `urlopen` for GET/POST; `HTTPError` is returned as `(code, body)` so a 401 is a measurement, not an exception [scripts/node-bus-worker.py:304-314]; any transport failure becomes **status 0** [scripts/node-bus-worker.py:315-317] | If 0 ever became a real status the `000` rows [scripts/node-bus-worker.py:546] and the `inbox_meaning[0]` entry [scripts/node-bus-worker.py:560] would mislabel an unreachable bus as a bus answer |

### 2c. Service contracts (both sides must be named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| crier `GET /health` | worker → bus | HTTP GET, **no** credentials | `{}`; the worker only reads the status | Route `/home/kara/crier/cmd/server/main.go:345`; public by middleware exemption `/home/kara/crier/internal/middleware/auth.go:139`. Worker call site [scripts/node-bus-worker.py:540] |
| crier `GET /agents/<id>/inbox/stats` | worker → bus | signed GET, 3-line transcript, plus `Authorization: Bearer` | `{queue_depth, leased_count, oldest_age_ms}` | Route `/home/kara/crier/cmd/server/main.go:115` → `Handler.HandleStats` `/home/kara/crier/internal/registry/handler.go:1860` → `requireAgent` → `verifyAgentSignatureForKey` `/home/kara/crier/internal/registry/agentsig.go:162`; response struct `/home/kara/crier/internal/registry/handler.go:502-506`. Worker call site [scripts/node-bus-worker.py:569-577] — the read that leases nothing, chosen so `--check` cannot hide a dispatch [scripts/node-bus-worker.py:43-44] |
| crier `GET /agents/<id>` | worker → bus | HTTP GET with `Authorization: Bearer` only — **no** signature | agent row including `public_key` (hex) | Route `/home/kara/crier/cmd/server/main.go:108` → `Handler.HandleGetAgent` `/home/kara/crier/internal/registry/handler.go:812-826`, which performs no authorization. Worker call site [scripts/node-bus-worker.py:595-605]; the comparison is `registered.lower() == signer.public_key_hex` [scripts/node-bus-worker.py:613] |
| crier `GET /agents/<id>/inbox?limit&lease_seconds&wait_seconds` | worker → bus | signed GET, 3-line transcript; timeout widened to `max(--timeout, wait+timeout)` for a long poll [scripts/node-bus-worker.py:1064] | `{messages, lease_id, queue_depth}` | Route `/home/kara/crier/cmd/server/main.go:113` → `Handler.HandleRetrieve` `/home/kara/crier/internal/registry/handler.go:1690` (self-only), query parse and 0..120 bound `/home/kara/crier/internal/registry/inboxnotify.go:40`; response written `/home/kara/crier/internal/registry/handler.go:1798-1803`. Worker call site [scripts/node-bus-worker.py:1056-1074] — and the worker's own bound matches the server's `0..120` [scripts/node-bus-worker.py:1254-1259] |
| crier `POST /agents/<reply_to>/inbox` | worker → bus | signed POST, **4-line** transcript (`X-Agent-Body-SHA256` set because a body is present) [scripts/node-bus-worker.py:284-287] | `{"payload": <result envelope>}` [scripts/node-bus-worker.py:952] | Route `/home/kara/crier/cmd/server/main.go:111` → `Handler.HandleDeliver` `/home/kara/crier/internal/registry/handler.go:990` → `deliver` `/home/kara/crier/internal/registry/handler.go:1093` → `authorizeServiceDelivery` `/home/kara/crier/internal/registry/service_auth.go:110`; success is `201 Created` with `id` `/home/kara/crier/internal/registry/dispatch.go:664-666` and `/home/kara/crier/internal/registry/handler.go:377-378`. Worker call site [scripts/node-bus-worker.py:951-973] |
| crier `POST /agents/<id>/inbox/ack` | worker → bus | signed POST, 4-line transcript | `{"lease_id": …, "message_ids": […]}` [scripts/node-bus-worker.py:977-979] | Route `/home/kara/crier/cmd/server/main.go:114` → `Handler.HandleAck` `/home/kara/crier/internal/registry/handler.go:1812`; request struct `/home/kara/crier/internal/registry/handler.go:496-500`; success `204 No Content` `/home/kara/crier/internal/registry/handler.go:1855`. Worker call site [scripts/node-bus-worker.py:976-992] |
| the harness binary (e.g. `hermes -z {prompt}`) | worker → child process | argv from `shlex.split`, no shell, `cwd` = the clone, `stdin` = `/dev/null`, full ambient env copied then `HOME` overridden [scripts/node-bus-worker.py:705-721] | prompt text substituted into the `{prompt}` token [scripts/node-bus-worker.py:427] | No crier side; the envelope it produces is `{env_version, dispatch_id, corr_id, status, host_identity, harness, exit_codes, gate_exit, branch, commit, artifacts, wall_s, finished_at}` [scripts/node-bus-worker.py:921-935] |

**Contract note the code states wrongly.** The `inbox_meaning` table says crier "checks the signer BEFORE it looks the agent up, so 401 is not proof the id is unknown" [scripts/node-bus-worker.py:556-558]. Crier resolves the target first and answers `404 agent not found` for an unknown id [/home/kara/crier/internal/registry/agentsig.go:196-205], and only then compares `X-Agent-ID` to the target (403) [/home/kara/crier/internal/registry/agentsig.go:210-213]. Missing headers are the one case refused before the lookup [/home/kara/crier/internal/registry/agentsig.go:190-194]. So a 401 with headers present does imply the agent row exists — the table's conclusion survives, its stated mechanism does not.

## 3. Verification

Run from a clean checkout of `e7cf075`, 2026-11-05, with no node identity on the host (`~/.node` exists and is empty). Every row that needs no live node was executed; the leg that needs one is row 10 and is marked, not guessed.

| # | Check | Command | Expected | Last run | Result |
|---|---|---|---|---|---|
| 1 | Mode guard | `python3 scripts/node-bus-worker.py` [scripts/node-bus-worker.py:1245-1248] | usage block, then `error: one of --check, --once, --loop N is required (--dry-run plans a --once)`, exit 2 | 2026-11-05 | **PASS** |
| 2 | `wait_seconds` bound | `python3 scripts/node-bus-worker.py --check --wait-seconds 200` [scripts/node-bus-worker.py:1254-1259] | `FAIL  wait_seconds — must be 0..120 (the bus answers 400 outside it)` on stderr, exit 2 | 2026-11-05 | **PASS** |
| 3 | `--loop` lower bound | `python3 scripts/node-bus-worker.py --loop 0` [scripts/node-bus-worker.py:1260-1262] | `FAIL  loop — must be at least 1`, exit 2 | 2026-11-05 | **PASS** |
| 4 | Workdir containment | `python3 scripts/node-bus-worker.py --once --workdir /etc` [scripts/node-bus-worker.py:1263-1269] | `FAIL  workdir — /etc is not inside $HOME (/home/kara); …`, exit 2 | 2026-11-05 | **PASS** |
| 5 | Every row fails by name on an empty HOME | `python3 scripts/node-bus-worker.py --check --home <empty tmp>` [scripts/node-bus-worker.py:444-672] | 7 named FAIL rows and `BUS WORKER: FAIL (7)`, exit 1 | 2026-11-05 | **PASS** |
| 6 | Fixture identity, unreachable bus | `--check --home <tmp with key+token+json>` aimed at `http://127.0.0.1:9` [scripts/node-bus-worker.py:534-548] | `PASS identity/project/signing_key/bus_bearer`, `FAIL bus_health … -> 000`, `FAIL inbox … -> 000`, `WARN key_registry`, `BUS WORKER: FAIL (4)`, exit 1 | 2026-11-05 | **PASS** |
| 7 | Signature is a real RFC 8032 signature over the exact transcript | `python3 /home/kara/.hermes/cache/scratch/md25b/interop.py` — `load_seed` on an `openssl genpkey -algorithm ED25519` key, then `openssl pkeyutl -verify -rawin` [scripts/node-bus-worker.py:169-190] [scripts/node-bus-worker.py:266-269] | `pub matches openssl raw key: True`; `Signature Verified Successfully` for the GET and the body-bound POST transcript; `Signature Verification Failure` for a mutated path | 2026-11-05 | **PASS** |
| 8 | `load_seed` refuses non-usable key material | same probe: encrypted PEM, RSA key, non-PEM file [scripts/node-bus-worker.py:221-258] | three named refusals — `the PEM is passphrase-encrypted; a node cannot answer a prompt`, `PKCS#8 algorithm is not ed25519 (OID 1.3.101.112)`, `not a PEM block` | 2026-11-05 | **PASS** |
| 9 | The repo's own battery, section 44 | `bash /home/kara/.hermes/cache/scratch/md25b/sec44.sh` (lines 2518-2587 of `tests/selftest.sh`, verbatim, with `say`/`HERE`/`fails` supplied) [tests/selftest.sh:2518-2587] | 5 × `PASS`, `fails=0` | 2026-11-05 | **PASS** |
| 10 | A **signed read returns 200** on a live bus | `python3 ~/node-bus-worker.py --check` on cf-node [scripts/node-bus-worker.py:569-592] | `PASS  inbox — GET /agents/cf-node/inbox/stats -> 200 (… queue_depth …, leased_count …)` and `BUS WORKER: READY` | 2026-11-05, recorded by the operator (fact: FACT-04) | **UNKNOWN here — not re-measured.** No `$HOME/.node/agent.key` and no bus on this host; rows 1-9 prove the signing half, not crier's acceptance. `docs/LOOP-CODEX.md:19` records the READY from the node |

Transcripts, verbatim — the only elision is the absolute scratch path in the identity rows, shortened to `…`, because they are scratch paths under `$TMPDIR` rather than evidence.

Row 1:
```
usage: node-bus-worker.py [-h] [--check | --once | --loop N] [--dry-run]
                          [--home HOME] [--identity IDENTITY]
                          [--bus-identity BUS_IDENTITY] [--key KEY]
                          [--token-file TOKEN_FILE] [--agent AGENT]
                          [--project PROJECT] [--crier CRIER]
                          [--workdir WORKDIR] [--harness-cmd HARNESS_CMD]
                          [--gateway-port GATEWAY_PORT] [--reply-to REPLY_TO]
                          [--limit LIMIT] [--lease-seconds LEASE_SECONDS]
                          [--wait-seconds WAIT_SECONDS] [--interval INTERVAL]
                          [--harness-wall HARNESS_WALL] [--timeout TIMEOUT]
node-bus-worker.py: error: one of --check, --once, --loop N is required (--dry-run plans a --once)
exit=2
```

Row 5 (`--check` with an empty HOME):
```
node-bus-worker --check — agent=? bus=?
  FAIL  identity — …/.node/node.json and …/.node/crier.json are both absent
  FAIL  signing_key — …/.node/agent.key absent — the bus verifies a per-agent ed25519 signature; this node holds no key, and a made-up key would authenticate nothing
  FAIL  bus_bearer — …/.node/auth/crier.token absent and CRIER_AUTH_TOKEN unset — a signed read still needs the shared bearer
  FAIL  bus_health — no bus url (crier.json url / node.json bus.base / --crier)
  FAIL  inbox — no agent id (crier.json agent / --agent)
  FAIL  harness — …/hermes-venv/bin/hermes absent
  FAIL  gateway — http://127.0.0.1:10800/api/status -> 000 (the harness gateway is not serving on this node)

BUS WORKER: FAIL (7)
exit=1
```

Row 6 (generated key at mode 600, token at mode 600, both identity files agreeing on `code-factory`, bus at a closed port):
```
node-bus-worker --check — agent=cf-node bus=http://127.0.0.1:9
  PASS  identity — …/.node/node.json mode 0o664 project=code-factory; …/.node/crier.json mode 0o664 project=code-factory
  PASS  project — code-factory (the two identity files agree)
  PASS  signing_key — …/.node/agent.key mode 0o600 — PKCS#8 ed25519, public 49d1da81009ab284f377a956bbdcc6c32e414a1110781d2bdf49d457b14df569
  PASS  bus_bearer — …/.node/auth/crier.token (mode 0o600)
  FAIL  bus_health — http://127.0.0.1:9/health -> 000 (the bus is not answering this node)
  FAIL  inbox — GET /agents/cf-node/inbox/stats -> 000 (the bus could not be reached from this node)
  WARN  key_registry — GET /agents/cf-node -> 000; key match unmeasured
  FAIL  harness — …/hermes-venv/bin/hermes absent
  FAIL  gateway — http://127.0.0.1:10800/api/status -> 000 (the harness gateway is not serving on this node)

BUS WORKER: FAIL (4)
exit=1
```

Row 7 and 8 (probe output, `W=/home/kara/.hermes/cache/scratch/md25b`):
```
genpkey: (0,)
pubout : (0,)
seed bytes: 32
pub matches openssl raw key: True
pub hex: 49d1da81009ab284f377a956bbdcc6c32e414a1110781d2bdf49d457b14df569
transcript repr: b'GET\n/agents/cf-node/inbox/stats\n1762350000'
sig bytes: 64
openssl verify (GET transcript): 0 Signature Verified Successfully
openssl verify (POST body-bound): 0 Signature Verified Successfully
openssl verify (mutated, must fail): 1 Signature Verification Failure
encrypted PEM refused: the PEM is passphrase-encrypted; a node cannot answer a prompt
RSA key refused: PKCS#8 algorithm is not ed25519 (OID 1.3.101.112)
non-PEM refused: not a PEM block
```
The public key the worker derives from the PEM is the same 32 bytes OpenSSL publishes for it, so the in-file RFC 8032 implementation agrees with a reference implementation on key derivation **and** on the signature — including the 4-line body-bound form used for reply and ack [scripts/node-bus-worker.py:266-269]. What this does not prove is that crier accepts it; that leg is row 10.

Row 9:
```
44. the node bus worker names the refusal it cannot proceed past (CF-215)
  PASS  scripts/node-bus-worker.py compiles
  PASS  project mismatch -> named FAIL, exit 1, no bus contact
  PASS  unreadable identity -> named FAIL, exit 1
  PASS  absent key -> named FAIL naming the file, exit 1, nothing invented, no bus contact
  PASS  unreachable bus -> named FAIL with 000, exit 1, no inbox read attempted
SECTION44 fails=0
```

## 4. Metrics emitted

**NONE.** The worker has no metrics endpoint, no counter, no structured log sink and no state file that a monitor could read. Its only outputs are: stdout rows in the house `  PASS  <name> — <value>` form [scripts/node-bus-worker.py:86-99], the six terminal lines `READY` / `IDLE` / `OK` / `FAIL (n)` / `FAIL` / `DRY RUN` [scripts/node-bus-worker.py:669-671] [scripts/node-bus-worker.py:1092] [scripts/node-bus-worker.py:1127] [scripts/node-bus-worker.py:1161-1164], and `$HOME/.node/bus-seen.json`, which holds up to 200 `key → result` entries and is an idempotency cache, not a statistic [scripts/node-bus-worker.py:76] [scripts/node-bus-worker.py:689-696].

The nearest real measurement lives on the **other** side of the wire: crier increments `deliveriesTotal` on accept [/home/kara/crier/internal/registry/dispatch.go:668] and logs `inbox deliver accepted` with `message_id` and `sender` [/home/kara/crier/internal/registry/dispatch.go:633-639]. A node's throughput is therefore inferred from the bus's accept counter and from `queue_depth` not draining — neither is emitted by this module. That is why §3 row 10 is the only honest liveness claim this document can make.

## 5. Log lines it can generate

Every line below is a literal from the source or from a run on 2026-11-05. "evidentiary" means the line is the measurement (a status code, a digest, a mode); "descriptive" means it narrates intent or a plan and proves nothing on its own.

| Level | Line (verbatim) | Emitted when | Kind |
|---|---|---|---|
| stdout | `node-bus-worker --check — agent=cf-node bus=http://127.0.0.1:9` [scripts/node-bus-worker.py:445] | first line of every `--check` | descriptive — names the two values it is about to test, measured |
| stdout | `  PASS  signing_key — …/.node/agent.key mode 0o600 — PKCS#8 ed25519, public 49d1da81009ab284f377a956bbdcc6c32e414a1110781d2bdf49d457b14df569` [scripts/node-bus-worker.py:520-524] | the key parses and is not group/other readable | evidentiary — mode and derived public key, measured |
| stdout | `  FAIL  signing_key — …/.node/agent.key absent — the bus verifies a per-agent ed25519 signature; this node holds no key, and a made-up key would authenticate nothing` [scripts/node-bus-worker.py:497-503] | no key file | evidentiary, measured |
| stdout | `  FAIL  signing_key — …/.node/agent.key is mode 0o644 — group/other can read a private key; chmod 600` [scripts/node-bus-worker.py:512-518] | key present, mode has any group/other bit | evidentiary, measured |
| stdout | `  FAIL  project — …/.node/node.json says 'other-project', …/.node/crier.json says 'code-factory'` [scripts/node-bus-worker.py:479-484] | the two identity files disagree | evidentiary, measured |
| stdout | `  PASS  bus_bearer — env CRIER_AUTH_TOKEN ***` [scripts/node-bus-worker.py:414] | token came from the environment instead of the file | evidentiary — it names the source and redacts the value, measured |
| stdout | `  FAIL  bus_bearer — …/.node/auth/crier.token absent and CRIER_AUTH_TOKEN unset — a signed read still needs the shared bearer` [scripts/node-bus-worker.py:415] [scripts/node-bus-worker.py:529] | neither token source exists | evidentiary, measured |
| stdout | `  FAIL  inbox — GET /agents/cf-node/inbox/stats -> 000 (the bus could not be reached from this node)` [scripts/node-bus-worker.py:591] | signed read did not reach the bus | evidentiary — the 000 is the transport verdict, measured |
| stdout | `  PASS  inbox — GET /agents/cf-node/inbox/stats -> 200 (signed read accepted; queue_depth ?, leased_count ?)` [scripts/node-bus-worker.py:584-589] | the bus accepted bearer **and** signature | **evidentiary — the only row in the file that proves the bus accepts this node's credential.** NOT observed on this host (§3 row 10) |
| stdout | `  WARN  key_registry — GET /agents/cf-node -> 000; key match unmeasured` [scripts/node-bus-worker.py:626-629] | the registry row could not be read, so key match is unknown | descriptive of a gap — it explicitly declines to claim |
| stdout | `  FAIL  gateway — http://127.0.0.1:10800/api/status -> 000 (the harness gateway is not serving on this node)` [scripts/node-bus-worker.py:661-664] | loopback gateway probe failed | evidentiary, measured |
| stdout | `BUS WORKER: FAIL (7)` / `BUS WORKER: READY` / `BUS WORKER: OK` / `BUS WORKER: IDLE` [scripts/node-bus-worker.py:669-671] [scripts/node-bus-worker.py:1092] [scripts/node-bus-worker.py:1162] | end of a check / of a poll / of a loop iteration | evidentiary for `FAIL (n)` (n is the count); `READY` is a self-report over rows that are six-sevenths local |
| stdout | `  PASS  brief_digest — cf-1 (corr ?) sha256(text) 3f9c… matches the brief (412 bytes)` [scripts/node-bus-worker.py:837-840] | dispatch carried a `brief.digest` and it matched | evidentiary — proves the text is the one the sender hashed |
| stdout | `  FAIL  brief_digest — cf-1 (corr ?) brief.digest 91ab… != sha256(text) 3f9c… — the brief was altered in flight; refused, not run` [scripts/node-bus-worker.py:825-829] | digest mismatch | evidentiary — refusal, and it is acked so it cannot loop |
| stdout | `  NOTE  harness output — <first 300 chars of stderr, else stdout>` [scripts/node-bus-worker.py:936-939] | the harness produced output | descriptive — deliberately **not** evidentiary: the envelope has no free-text field, so this line is the only copy and it never leaves the node |
| stdout | `  WOULD  reply — POST the result envelope to the scheduler inbox, then ack` [scripts/node-bus-worker.py:889-891] | `--dry-run` | descriptive — a plan, proving nothing ran |
| stderr | `FAIL  wait_seconds — must be 0..120 (the bus answers 400 outside it)` / `FAIL  loop — must be at least 1` / `FAIL  workdir — /etc is not inside $HOME (/home/kara); this worker never writes outside it` [scripts/node-bus-worker.py:1254-1269] | argument refusal, exit 2 | evidentiary, measured |

## 6. Failure modes

Direction is written from the worker's frame: **node → bus** (the worker's request is refused), **bus → node** (the bus's answer is hostile or the input is hostile), **node-internal** (no network involved), **node → operator** (the report itself is wrong).

| Failure | Presents as | Direction | Distinguished from | Recovery |
|---|---|---|---|---|
| No key material on the node | `FAIL  signing_key — <path> absent`, exit 1, no network call [scripts/node-bus-worker.py:1021-1030] | node-internal | A wrong-but-present key, which gets past this row and dies with `401 signature verification failed` at the inbox [/home/kara/crier/internal/registry/agentsig.go:299-301] | Install the key whose public half the registry holds. The worker will never generate one [scripts/node-bus-worker.py:26-29] |
| Key present but not the registered one | `FAIL  inbox … -> 401`, and `FAIL  key_registry — the node's public key ab12… is NOT the registered 9f31… — every signature would 401` when `/agents/<id>` is readable [scripts/node-bus-worker.py:619-623] | node → bus | 404, which means the id itself is unknown [/home/kara/crier/internal/registry/agentsig.go:196-205] | Re-register the public key, or install the file the registry already knows |
| Clock skew past ±30 s | `401 {"error":"request timestamp outside allowed window (±30s)"}`; the worker's row only says `401 … auth or per-agent signature refused` [scripts/node-bus-worker.py:556-558] | node → bus | Wrong key, which also 401s but with `signature verification failed` [/home/kara/crier/internal/registry/agentsig.go:299-301] | Fix NTP on the node; the row text cannot tell you this — read the bus body |
| Missing or wrong bearer | `401` before any signature work, body `{"error":"missing Authorization header"}` [/home/kara/crier/internal/middleware/auth.go:148-157] | node → bus | A signature refusal, which happens **after** the bearer gate and after the agent lookup | `--token-file` or `CRIER_AUTH_TOKEN`; both are tried in that order, file first [scripts/node-bus-worker.py:400-415] |
| Reply rejected after the harness ran | `FAIL  reply — POST /agents/scheduler/inbox -> 403/404 (…)`, the batch is deliberately **left unacked** and the warning says so: `WARN  ack — 1 message(s) left unacked — their result did not reach the bus, so redelivery is the safer outcome` [scripts/node-bus-worker.py:1132-1158] | node → bus | Ack failure, which is a separate row and happens only after a successful reply [scripts/node-bus-worker.py:988-991] | Fix the recipient (`--reply-to`, or the dispatch's `reply_to` [scripts/node-bus-worker.py:1134]); the message is redelivered and the seen-cache makes re-execution idempotent |
| Reply target is a protected service identity | `403 service delivery body sender must equal signed X-Agent-ID` [/home/kara/crier/internal/registry/service_auth.go:149-150] | node → bus | Trust-by-reach: with an empty `CR_SERVICE_DELIVERY_ALLOWLIST` the delivery path is unauthenticated and the same body is accepted [/home/kara/crier/internal/registry/service_auth.go:111-113] | **Live defect.** The worker's body is `{"payload": …}` with no `sender` field [scripts/node-bus-worker.py:952], so it can never satisfy that check. Either the worker names the sender, or the reply target must never be enrolled as a protected service identity |
| Dispatch altered in flight | `FAIL  brief_digest — … != sha256(text) … — refused, not run`; a `refused` envelope is posted and the message acked [scripts/node-bus-worker.py:820-842] | bus → node | An unmodified dispatch, which prints `sha256(text) … matches the brief` [scripts/node-bus-worker.py:837-840] | Investigate the sender. The refusal is by design and must not be retried blindly |
| Dispatch's gate runs arbitrary shell | No row of its own; the gate executes whatever `gate.cmd` says via `sh -lc` in the clone [scripts/node-bus-worker.py:763-770] | bus → node | The brief, which **is** hash-covered — `brief.digest` covers `text` only, not `gate`, `workdir`, `limits` or `reply_to` [scripts/node-bus-worker.py:823] | **Trust boundary, not a bug to patch blindly.** Anything able to deliver to this inbox can run shell as the node user; the digest does not cover it. Bound it at the bus, not here |
| Harness exceeds its wall limit | `FAIL  harness — <label> wall limit 1800s exceeded`, envelope `status:"failed"`, `wall_s` set [scripts/node-bus-worker.py:722-723] [scripts/node-bus-worker.py:896-901] | node-internal | A harness that could not start: `could not start the harness: …` [scripts/node-bus-worker.py:724-731] | The message is acked (result delivered), so the failure is the sender's to see. Raise `limits.wall_s` in the dispatch — accepted up to 86400 [scripts/node-bus-worker.py:943-948] |
| Harness output is the only diagnosis | `NOTE  harness output — …` on the worker's stdout, nothing in the envelope [scripts/node-bus-worker.py:936-939] | node → operator | A refusal, which carries `refused_by`/`refusal` text [scripts/node-bus-worker.py:776-793] | Read the node's stdout/cron log. A failed run explained only on the node is invisible to whoever reads the bus |
| Redelivery after a lost seen-cache | The same dispatch runs twice; `PASS idempotent — … was already executed` never appears [scripts/node-bus-worker.py:803-808] | bus → node | A genuine second dispatch, which carries a different key [scripts/node-bus-worker.py:699-702] | `$HOME/.node/bus-seen.json` is the only memory, capped at 200 entries [scripts/node-bus-worker.py:76]; do not delete it, and do not rely on it across a rebuild |
| Two workers on one agent id | Both lease and run; the later ack of the first lease answers `409` (`ErrLeaseConflict`) [/home/kara/crier/internal/registry/handler.go:1832-1846] | node → bus | A stale lease, which also 409s after expiry | One worker per agent id. `--loop` sleeps `--interval` between polls and does not coordinate with a sibling [scripts/node-bus-worker.py:1277-1285] |
| Bus unreachable | `FAIL  bus_health — … -> 000`, `FAIL  inbox … -> 000`, exit 1, nothing run [scripts/node-bus-worker.py:544-548] [scripts/node-bus-worker.py:304-317] | node → bus | A 401, which proves the bus **is** reachable and is refusing this credential | Only transport and DNS; status 0 is the worker's sentinel for "never got an HTTP answer" [scripts/node-bus-worker.py:305] |
| `READY` quoted long after it was true | A runbook or dashboard shows `BUS WORKER: READY` [docs/LOOP-CODEX.md:19] | node → operator | Nothing. The line has no timestamp and no nonce | Re-run `--check` before quoting it; only the `inbox` row depends on the bus at all [scripts/node-bus-worker.py:562-592] |
| Worker never staged onto the node | The connect probe silently skips its signed read (the `if` guard fails) and the operator sees an unsigned fallback [scripts/bunker-crier-connect.sh:50-55] | node → operator | A node whose key is missing, which the probe also skips on | Add the file to the staged set [scripts/node-create.sh:23] or correct `docs/OPERATIONS.md:209` |

## 7. Environment and settings it reads

| Flag | Default | Effect |
|---|---|---|
| `--check` | off | Measure and print; writes nothing, leases nothing [scripts/node-bus-worker.py:41-45] |
| `--once` | off | One poll: fetch → verify → run → reply → ack [scripts/node-bus-worker.py:5] |
| `--loop N` | unset | N polls, sleeping `--interval`; breaks early only when the key is missing or the identity is bad [scripts/node-bus-worker.py:1277-1285] |
| `--dry-run` | off | Implies `--once`, fetches with a **5-second** lease, prints `WOULD` rows, posts and acks nothing [scripts/node-bus-worker.py:1055] [scripts/node-bus-worker.py:1124-1130] |
| `--home` | `$HOME` [scripts/node-bus-worker.py:1187] | Root of every path below; must be a directory or exit 2 [scripts/node-bus-worker.py:1249-1253] |
| `--identity` | `$HOME/.node/node.json` [scripts/node-bus-worker.py:338] | The repo/harness declaration |
| `--bus-identity` | `$HOME/.node/crier.json` [scripts/node-bus-worker.py:339] | The agent/project/url declaration |
| `--key` | `$HOME/.node/agent.key` [scripts/node-bus-worker.py:340] | PKCS#8 PEM ed25519 private key; must not be group/other readable [scripts/node-bus-worker.py:505-518] |
| `--token-file` | `$HOME/.node/auth/crier.token` [scripts/node-bus-worker.py:341-343] | Shared bearer; tried **before** the environment |
| `--agent` | `""` [scripts/node-bus-worker.py:1204] | Overrides the agent id; precedence is `crier.json.agent` → `node.json.agent` → flag [scripts/node-bus-worker.py:347-349] |
| `--project` | `""` [scripts/node-bus-worker.py:1205] | Precedence `node.json.project` → `crier.json.project` → flag [scripts/node-bus-worker.py:350-355] |
| `--crier` | `""` [scripts/node-bus-worker.py:1206] | Bus base URL; precedence `crier.json.url` → `node.json.bus.base` → flag [scripts/node-bus-worker.py:356-361]; a trailing `/` is stripped [scripts/node-bus-worker.py:362] |
| `--workdir` | `""` [scripts/node-bus-worker.py:1207-1209] | Clone path; must resolve inside `$HOME` or exit 2 [scripts/node-bus-worker.py:1263-1269]; precedence over `node.json.repo.path` [scripts/node-bus-worker.py:363-364] |
| `--harness-cmd` | `""` → `$HOME/hermes-venv/bin/hermes -z {prompt}` [scripts/node-bus-worker.py:417-427] | String or JSON array; `shlex.split`, `{prompt}` substituted, executed without a shell |
| `--gateway-port` | `10800` [scripts/node-bus-worker.py:1215-1220] | Port of the loopback `/api/status` probe [scripts/node-bus-worker.py:656] |
| `--reply-to` | `scheduler` [scripts/node-bus-worker.py:1221-1225] | Result recipient when the dispatch names no `reply_to` [scripts/node-bus-worker.py:1134] |
| `--limit` | `10` [scripts/node-bus-worker.py:72] [scripts/node-bus-worker.py:1226] | `limit=` on the inbox read |
| `--lease-seconds` | `30` [scripts/node-bus-worker.py:73] [scripts/node-bus-worker.py:1227] | `lease_seconds=` on the inbox read (5 under `--dry-run`) |
| `--wait-seconds` | `0` [scripts/node-bus-worker.py:1228-1230] | Long-poll budget; refused outside 0..120, matching crier's own ceiling [/home/kara/crier/internal/registry/inboxnotify.go:40] |
| `--interval` | `15` [scripts/node-bus-worker.py:1231-1233] | Sleep between polls in `--loop` |
| `--harness-wall` | `1800` [scripts/node-bus-worker.py:75] [scripts/node-bus-worker.py:1234-1239] | Harness wall limit when the dispatch sets none; a dispatch may set `limits.wall_s` up to 86400 [scripts/node-bus-worker.py:943-948] |
| `--timeout` | `10` [scripts/node-bus-worker.py:74] [scripts/node-bus-worker.py:1240-1242] | Per-request timeout, and the `/health`, `/agents/<id>` and gateway probe timeout; the inbox read widens it for a long poll [scripts/node-bus-worker.py:1064] |

| Variable | Read at | Default | Effect if unset |
|---|---|---|---|
| `HOME` | [scripts/node-bus-worker.py:1187] (as the `--home` default) and [scripts/node-bus-worker.py:711] (re-exported to the harness) | none — the flag wins | `FAIL  home — (unset) is not a directory`, exit 2 [scripts/node-bus-worker.py:1249-1253]. Inside the harness, `HOME` is always the worker's `$HOME`, whatever the parent had |
| `CRIER_AUTH_TOKEN` | [scripts/node-bus-worker.py:412] | unset | Only consulted when the token **file** is absent [scripts/node-bus-worker.py:400-412]; unset and no file → `FAIL  bus_bearer`, and `--once` exits 1 before the network [scripts/node-bus-worker.py:1034-1037] |
| every other ambient variable | [scripts/node-bus-worker.py:710] — the whole environment is copied into the harness | inherited | The harness sees the node's full environment, including any provider key that happens to be exported there. Nothing strips it — see board row CF-229 AC3 (`.coding-hermes/board/tasks.jsonl`, id `CF-229`) |

| File | Mode | Direction | Note |
|---|---|---|---|
| `$HOME/.node/node.json` | read; mode printed, not enforced [scripts/node-bus-worker.py:461-464] | read | project, repo.path, harness.{name,cmd} |
| `$HOME/.node/crier.json` | read; mode printed, not enforced | read | agent, project, url |
| `$HOME/.node/agent.key` | read; **mode enforced** — any group/other bit is a FAIL [scripts/node-bus-worker.py:512-518] | read | Never written, never printed, never generated |
| `$HOME/.node/auth/crier.token` | read; mode printed in the PASS row [scripts/node-bus-worker.py:408-410], not enforced | read | The value never leaves `bearer()` except into a header [scripts/node-bus-worker.py:399] |
| `$HOME/.node/bus-seen.json` | written `0o600`, atomically via `.tmp` + `replace` [scripts/node-bus-worker.py:689-696] | write | 200-entry idempotency cache; a corrupt cache is treated as empty, not fatal [scripts/node-bus-worker.py:680-686] |

## 8. Evidence of record

- **Measured here, 2026-11-05**, on `e7cf075` with Python 3.14.9 and OpenSSL 3.5.5: §3 rows 1-9. Artifacts kept under `/home/kara/.hermes/cache/scratch/md25b/` — `interop.py` (rows 7-8), `sec44.sh` (row 9, extracted verbatim from [tests/selftest.sh:2518-2587]), and the fixture HOMEs used for rows 5-6. Re-running any of them needs no bus, no key of record and no network.
- **Recorded by the operator, not re-measured here**: the signed read returning 200 on cf-node (fact: FACT-04), and the four-rung credential ladder that makes an unsigned read 401 (fact: FACT-03). Both are cited as recorded evidence, which is why the module status stays RED rather than VERIFIED — row 10 is the leg that decides it and it was not run on this host.
- **The repo's own witness**: section 44 of [tests/selftest.sh:2518-2587], headed "the node bus worker names the refusal it cannot proceed past (CF-215)"; its five legs pass on the commit above. The board id is `CF-215` in `.coding-hermes/board/tasks.jsonl` (append-only, cited by id per fact: FACT-09).
- **Claims checked against crier, not trusted from its docs**: the route table [/home/kara/crier/cmd/server/main.go:104-118], the self-only authorization [/home/kara/crier/internal/registry/agentsig.go:162-311], the stats/ack/deliver wire shapes [/home/kara/crier/internal/registry/handler.go:496-506] [/home/kara/crier/internal/registry/handler.go:1798-1803] [/home/kara/crier/internal/registry/dispatch.go:664-666], and the 0..120 long-poll ceiling [/home/kara/crier/internal/registry/inboxnotify.go:40]. Crier's working tree at the time of reading was at `f2b051a2` with unrelated local modifications, so the locators are against that checkout, not a release tag.
- **Defects found while measuring** (each has a resolving locator above, and none is fixed by this document): the reply body omits `sender`, so a protected service recipient answers 403 (§6); `brief.digest` covers `text` only while `gate.cmd` is executed as shell (§6); the `inbox_meaning` comment's stated verification order contradicts crier (§2c); `EMPTY_SHA256` is defined and never used [scripts/node-bus-worker.py:78]; the harness inherits the node's whole environment [scripts/node-bus-worker.py:710]; `docs/OPERATIONS.md:209` claims provisioning stages this file while the staged set does not [scripts/node-create.sh:23]; and `scripts/bunker-crier-connect.sh:53` exports `CRIER_URL` at a worker that never reads it [scripts/node-bus-worker.py:356-361] [scripts/node-bus-worker.py:412].
