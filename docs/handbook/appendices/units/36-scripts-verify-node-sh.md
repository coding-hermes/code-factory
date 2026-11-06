# 36. scripts/verify-node.sh

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/verify-node.sh` [scripts/verify-node.sh:2] |
| Repository | `code-factory` [scripts/verify-node.sh:2] |
| Revision | `e7cf075` — `git rev-parse HEAD` of the tree this document was measured against |
| Status | **VERIFIED — 8 sections, 366 locators (142 distinct), 21 measured checks in §3 — three live probes against `cf-node` (`VERIFY: FAIL (1)`, exit 1), `--check` measured as a non-flag (exit 2), and the PASS / FAIL / UNVERIFIED(exit 3) ladder pinned by 16 fixture arms** |

## 1. Purpose and why it matters

- What it is: the **control-host half** of the node ladder — "control host: is this node actually usable?" [scripts/verify-node.sh:2]. It runs where the operator sits, not on the node, and grades six things in the order they prove something: the agent answers [scripts/verify-node.sh:9], the gateway answers **from here** over the tailnet rather than from inside itself [scripts/verify-node.sh:10], the auth gate is closed [scripts/verify-node.sh:11], an optional artifact hashes the same on both sides [scripts/verify-node.sh:12], the checkout the node will work is the tree `origin/main` has (CF-244) [scripts/verify-node.sh:13], and the seed it carries is the digests its seed record still names (CF-250) [scripts/verify-node.sh:14].
- Why the boundary is the point: the foreman runs on the project's node and never on the control host [fact: FACT-01], so "usable" has to be measured from outside it. A bunker container has no address the control host can reach unless a transport is published, which is why the reachability verdict is decided where the gap is named [scripts/verify-node.sh:55] [scripts/verify-node.sh:57]. Its own header refuses the cheap substitute — "A version string is not evidence: step 2 must be a live HTTP answer from this host" [scripts/verify-node.sh:15].
- **The load-bearing distinction — three verdicts, not two.** A transport gap is `UNVERIFIED`, never `FAIL`: the node may be perfectly healthy behind a gap this host cannot see, and calling that FAIL "sends an operator to fix a node that works, PASS would be a lie" [scripts/verify-node.sh:57]. The verdict is its own exit code — `VERIFY: UNVERIFIED …` then `exit 3` [scripts/verify-node.sh:192] [scripts/verify-node.sh:193] [scripts/verify-node.sh:195] — and it names what it could not use. CF-224 was filed against the opposite behaviour: a `000` was once printed as `FAIL gateway_reachable — … -> 000000`, a code no HTTP server can return, for a node whose gateway was answering 200 [scripts/verify-node.sh:51] [scripts/verify-node.sh:57].
- **A 401 is never a failure signal here.** An unauthenticated request is *supposed* to be refused, so a measured 401/302/403 from this host is a `PASS` row [scripts/verify-node.sh:83], and a 401 observed only from inside the node (through the gap) is a `WARN` row with the run at exit 3 [scripts/verify-node.sh:88]. Nowhere in the file does 401 reach `bad` [scripts/lib.sh:7]. This is consistent with the bus's own design, where an unsigned read is a 401 by construction [fact: FACT-03] — a 401 is evidence the gate exists, not evidence the node is broken.
- What breaks if it is absent: `node-create.sh` loses its only outside-in proof and its `verify` row — its step 4 runs this file and maps `0` / `3` / anything else to `ok` / `warn` / `bad`+`incomplete` [scripts/node-create.sh:126] [scripts/node-create.sh:130] [scripts/node-create.sh:133] [scripts/node-create.sh:135]. Without step 5 and step 6 nobody measures the node's tree or seed at all: step 1–4 prove the agent answers, the gateway is up and the gate is closed, and "none of them looks at the tree" [scripts/verify-node.sh:110].
- What breaks if it lies: two opposite ways. A false FAIL trains an operator to ignore the last line, which is exactly the CF-224 defect [scripts/verify-node.sh:55]. A false PASS admits a node one commit behind `origin/main` or one carrying a hand-edited `prompts/foreman.md` — the states steps 5 and 6 were added to catch [scripts/verify-node.sh:109] [scripts/verify-node.sh:148]. Measured residual: `VERIFY: PASS` is still reachable while both of those legs are unmeasured, because an unmeasurable leg defaults to WARN (§6a).
- Scope it does **not** claim: no crier delivery, inference, task execution, result envelope or scheduler admission is proved here, and no crier code is touched by this file (the whole file is agent exec plus two HTTP GETs and two Python children) [docs/OPERATIONS.md:201] [scripts/verify-node.sh:41] [scripts/verify-node.sh:81].

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `bash` | not pinned; this host 5.3.9 | the shebang [scripts/verify-node.sh:1] | no probe inside the script; measured under this host's `/bin/sh`→dash, where the observed path behaved identically (§3) |
| `scripts/lib.sh` | same revision as this file | `$HERE/lib.sh`, sourced unguarded [scripts/verify-node.sh:18] | **nothing inside the script can report it** — measured with the file copied away from its `lib.sh`: every row became `say: command not found` / `ok: command not found`, and the run died at `FAILED: unbound variable` with exit 1 (§3) |
| `bunker` CLI | not pinned; `/home/kara/.local/bin/bunker` on this host | `PATH`; every agent probe and the two inside-the-node fallbacks [scripts/verify-node.sh:41] [scripts/verify-node.sh:48] [scripts/verify-node.sh:59] [scripts/verify-node.sh:98] [scripts/verify-node.sh:100] | `FAIL agent_alive — <bunker's own first line>` then `RESULT: FAIL`, exit 1 [scripts/verify-node.sh:44] — measured: `bunker: server "no-such-server-fx36" not found in config` (§3) |
| `curl` | not pinned | `PATH`; the two outbound probes [scripts/verify-node.sh:53] [scripts/verify-node.sh:81] | no probe: a missing `curl` yields an empty capture, `code=${code:-000}` turns it into `000` [scripts/verify-node.sh:53], and the run takes the UNVERIFIED branch [scripts/verify-node.sh:66] — a silent degradation, named in §6 |
| `python3` | not pinned (this host 3.14.9); the children are stdlib-only | `PATH`; both Python legs [scripts/verify-node.sh:127] [scripts/verify-node.sh:168] | the leg's non-zero exit lands in the `*)` branch and prints `WARN … could not be measured` [scripts/verify-node.sh:141] [scripts/verify-node.sh:183] — measured (§3, the clean-pass row) |
| `scripts/node_freshness.py` | same revision | `$HERE/node_freshness.py`, readable [scripts/verify-node.sh:122] | `FAIL checkout_freshness — <path> missing — the checkout's git state is unmeasured` [scripts/verify-node.sh:124] |
| `scripts/node_seed_drift.py` | same revision | `$HERE/node_seed_drift.py`, readable [scripts/verify-node.sh:161] | `FAIL seed_drift — <path> missing — the node's seed is unmeasured` [scripts/verify-node.sh:163] |
| `mktemp` | not pinned | `PATH`; five scratch files [scripts/verify-node.sh:99] [scripts/verify-node.sh:126] [scripts/verify-node.sh:165] | no probe: an unusable temp yields an empty scratch path, the child writes nowhere, and the leg reads `WARN … could not be measured` [scripts/verify-node.sh:141] |
| `sha256sum` | not pinned | `PATH` on both sides; artifact leg [scripts/verify-node.sh:98] [scripts/verify-node.sh:101] | no probe: an empty remote digest with a non-empty local one fails the equality test `[ -n "$remote" ]` [scripts/verify-node.sh:102] — measured row `node  vs host e3b0c44298fc` (§3) |
| `awk`, `grep`, `sed`, `head`, `paste`, `cut`, `basename` | not pinned | `PATH`; row parsing [scripts/verify-node.sh:48] [scripts/verify-node.sh:131] [scripts/verify-node.sh:134] [scripts/verify-node.sh:103] | no probe: an absent parser prints an empty detail and the row becomes `… — ` with a blank value, still the same verdict |
| a writable `/tmp` | kernel | the status body path is **hard-coded** [scripts/verify-node.sh:53] [scripts/verify-node.sh:63] | no probe: an unwritable `/tmp` leaves no body, `grep` finds nothing, and `FAIL auth_gate` is printed [scripts/verify-node.sh:65] |

### 2b. Library contracts

| Contract | Provider | Contract relied on | If it changes |
|---|---|---|---|
| row helpers | `scripts/lib.sh:5` | `say` prints a bare line, `ok` prints `  PASS  %s — %s`, `bad` prints `  FAIL  %s — %s` **and** increments `FAILED`, `warn` prints `  WARN  %s — %s` and increments nothing [scripts/lib.sh:6] [scripts/lib.sh:7] [scripts/lib.sh:8] | the final ladder reads `$FAILED` and `$UNVERIFIED` only [scripts/verify-node.sh:191] [scripts/verify-node.sh:192]; a `warn` that started counting would silently turn every transport gap into a FAIL |
| `FAILED` initialisation | `scripts/lib.sh:11` | `FAILED=${FAILED:-0}`, so a clean run starts at zero | the closing test is `[ "$FAILED" -gt 0 ]` under `set -u` [scripts/verify-node.sh:16] [scripts/verify-node.sh:191]; without the default the run aborts at the last line (measured, §3) |
| `shq` | `scripts/lib.sh:54` | single-quotes one data value for a remote shell | the artifact path is the only value passed through it [scripts/verify-node.sh:98]; `--port` is **not** (§6) |
| `node_freshness.py --agent --server --json` | `scripts/node_freshness.py:670` | rows on **stderr**, one JSON object on stdout [scripts/node_freshness.py:720] [scripts/node_freshness.py:727]; exit `0` fresh, `1` drift or dirty, `2` usage or unreachable [scripts/node_freshness.py:69] [scripts/node_freshness.py:238] | the parent greps the child's stderr: `  PASS  freshness — ` for the pass detail [scripts/verify-node.sh:131], any `^  FAIL  ` row for the fail detail [scripts/verify-node.sh:134], `^RESULT: ` for the unmeasurable detail [scripts/verify-node.sh:137]. A renamed pass row yields an empty PASS value; a renamed `RESULT:` line yields `unmeasurable` [scripts/verify-node.sh:139] |
| the pass row's shape | `scripts/node_freshness.py:366` | `  PASS  freshness — branch=… head=… origin_main=… ancestor=true behind=0` | measured on this worktree: `branch=wt/md-36b head=e7cf075ffff4 origin_main=e7cf075ffff4 ancestor=true behind=0` (§3) |
| the drift row's shape | `scripts/node_freshness.py:340` | `  FAIL  sync — behind=N (HEAD..<ref> <sha>): K differing path(s) — <paths>` | the parent flattens every FAIL row with `paste -sd '\|'` and cuts at 500 characters [scripts/verify-node.sh:134], so a wide drift is named but truncated (§3) |
| `node_seed_drift.py --agent --server [--strict-seed] --json` | `scripts/node_seed_drift.py:477` | exit `0` matched, `1` drifted (or absent under `--strict-seed`), `2` usage, `3` could not measure [scripts/node_seed_drift.py:28] [scripts/node_seed_drift.py:58]; `3` is deliberately **not** drift [scripts/node_seed_drift.py:31] | the parent folds `0`→PASS, `1`→FAIL, everything else→WARN unless `--strict-seed` [scripts/verify-node.sh:170] [scripts/verify-node.sh:171] [scripts/verify-node.sh:180] |
| the seed pass row | `scripts/node_seed_drift.py:191` | `  PASS  seed_drift — <record>: N seeded files present and matching` | the parent strips that exact prefix [scripts/verify-node.sh:172] — measured on the live node: `… /home/bunker-cf-node/.hermes/seed-applied.json: 13 seeded files present and matching` (§3) |
| the seed warn row | `scripts/node_seed_drift.py:255` | `  WARN  seed_drift — <detail> — the seed could not be measured; pass --strict-seed to refuse it` | the parent lifts that whole sentence as `detail` and appends **the same sentence again** [scripts/verify-node.sh:178] [scripts/verify-node.sh:183] — measured duplication (§3, §6) |

### 2c. Service contracts (both sides must be named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| bunker control plane → the node's shell | outbound, every probe | `bunker exec --server S AGENT -- bash -lc '<cmd>'` [scripts/verify-node.sh:41] [scripts/verify-node.sh:48] [scripts/verify-node.sh:59] [scripts/verify-node.sh:98] [scripts/verify-node.sh:100] | one remote command string per probe: `echo ALIVE $(hostname)`, `hostname -I`, a `curl -w '%{http_code}'`, `sha256sum`, `cat` [scripts/verify-node.sh:41] [scripts/verify-node.sh:48] [scripts/verify-node.sh:59] [scripts/verify-node.sh:98] [scripts/verify-node.sh:100] | the CLI's own config (`~/.bunker/config.yaml`, `active_server`, not tracked in this repo — this host resolves `bunker-las-03` from it); the same CLI contract is used by `node-create.sh` for staging and for the provisioner call [scripts/node-create.sh:110] [scripts/node-create.sh:121] |
| gateway route `GET /api/status` | outbound from **this** host, 8 s bound [scripts/verify-node.sh:50] [scripts/verify-node.sh:53] | plain HTTP to `http://<node-ip>:<port>/api/status` (no TLS, no credential) [scripts/verify-node.sh:50] | must answer `200` [scripts/verify-node.sh:61] and its JSON body must carry a true `auth_required` [scripts/verify-node.sh:63] | the route is served by the node's `hermes serve --host 0.0.0.0 --port "$PORT" --skip-build` [scripts/harness/install-hermes.sh:284], and the value read back is the consequence of `dashboard.basic_auth` in `$HOME/.hermes/config.yaml` — the adapter refuses a public bind without it [scripts/harness/install-hermes.sh:202] [scripts/harness/install-hermes.sh:301]. The handler itself ships inside the pinned `hermes-agent` package [scripts/harness/install-hermes.sh:17] and is not vendored in this tree, so only its effect is measured here; the adapter probes the same route from **inside** the node [scripts/harness/install-hermes.sh:238] |
| gateway route `GET /api/system/stats` | outbound from this host, 8 s bound, no credential [scripts/verify-node.sh:81] | plain HTTP [scripts/verify-node.sh:81] | must refuse with `401`, `302` or `403`; a `200` means the node is open to the tailnet [scripts/verify-node.sh:83] [scripts/verify-node.sh:84] | same gateway process and same basic-auth surface as above [scripts/harness/install-hermes.sh:284]; the refusal is the middleware inside the installed package, so the row records a measured code, not an inspected handler [scripts/verify-node.sh:93] |
| `scripts/node_freshness.py` | child process, one run | `python3 -B <script> --agent ID --server NAME --json`, stdout and stderr captured to two temp files [scripts/verify-node.sh:126] [scripts/verify-node.sh:127] | nine-key JSON on stdout, rows on stderr [scripts/node_freshness.py:640] | the child measures the node's checkout in **one** `bunker exec` round trip and compares against `origin/main` [scripts/node_freshness.py:426] [scripts/node_freshness.py:366] |
| `scripts/node_seed_drift.py` | child process, one run | `python3 -B <script> --agent ID --server NAME [--strict-seed] --json` [scripts/verify-node.sh:168] | exit code only — the parent never parses the JSON | the child stages `scripts/node_seed.py` onto the node, runs its `check` there and removes it in the same exec, because provisioning deletes the node-side seeder [scripts/verify-node.sh:152] [scripts/node_seed_drift.py:191] |
| `scripts/node-create.sh` (consumer) | this script is the child | direct invocation at step 4, then exit-code switch [scripts/node-create.sh:130] [scripts/node-create.sh:130] | exit `0` = round trip proven, `3` = UNVERIFIED and the node is **not** marked failed, anything else = `bad verify` + `incomplete` [scripts/node-create.sh:131] [scripts/node-create.sh:133] [scripts/node-create.sh:135] | the producer side of the same contract: `exit 0` / `exit 3` / `exit 1` at the end of this file [scripts/verify-node.sh:191] [scripts/verify-node.sh:195] [scripts/verify-node.sh:196] |

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| `--check` (as briefed) | `bash scripts/verify-node.sh --agent cf-node --server bunker-las-03 --check` [scripts/verify-node.sh:29] | the module has **no** `--check` mode; an unparsed flag must be refused by name, exit 2 | 2026-11-05 | **measured `unknown arg: --check`, exit 2** — verbatim below |
| Real control-host run | `bash scripts/verify-node.sh --agent cf-node --server bunker-las-03` | a live answer for each measurable leg; UNVERIFIED rows where this host has no transport; the verdict is the first of FAIL > UNVERIFIED > PASS [scripts/verify-node.sh:191] [scripts/verify-node.sh:192] | 2026-11-05 | **measured `VERIFY: FAIL (1)`, exit 1** — two WARN transport rows, one FAIL freshness row, one PASS seed row (verbatim below) |
| Real run, artifact present on both sides | `… --artifact /etc/hostname` | `PASS artifact_digest` naming a 12-hex prefix, and the same `VERIFY: FAIL (1)` from the freshness leg [scripts/verify-node.sh:103] | 2026-11-05 | **measured `PASS artifact_digest — hostname 96aa37a6e3ab on both sides`, exit 1** |
| Real run, artifact missing on the node | `… --artifact /nonexistent-fx36` | `FAIL artifact_digest` with an empty node digest and the empty-input digest `e3b0c44298fc` on the host side [scripts/verify-node.sh:102] [scripts/verify-node.sh:105] | 2026-11-05 | **measured `node  vs host e3b0c44298fc — bytes differ or file missing`, `VERIFY: FAIL (2)`, exit 1** |
| Real run, unknown server | `bash scripts/verify-node.sh --agent cf-node --server no-such-server-fx36` | step 1 refuses before anything else can be graded [scripts/verify-node.sh:44] | 2026-11-05 | **measured `FAIL agent_alive — bunker: server "no-such-server-fx36" not found in config`, then `RESULT: FAIL`, exit 1** |
| Ladder arm: transport gap, gateway alive inside | fixture `bunker`+`curl`: status `000`, inside `200`; stats `000`, inside `401` | `WARN gateway_reachable` + `WARN unauth_refused`, then `VERIFY: UNVERIFIED`, **exit 3** [scripts/verify-node.sh:70] [scripts/verify-node.sh:88] [scripts/verify-node.sh:195] | 2026-11-05 | **measured exit 3** (verbatim below) |
| Ladder arm: nothing answers anywhere | fixture: status `000`, inside `000` for both routes | still `VERIFY: UNVERIFIED`, exit 3 — a dead harness is not called FAIL [scripts/verify-node.sh:72] [scripts/verify-node.sh:193] | 2026-11-05 | **measured exit 3**, row `… the gateway does not answer inside the node either (000) — the harness is not up` |
| Ladder arm: real HTTP answer, not 200 | fixture: status and stats `502` | `FAIL gateway_reachable` + `FAIL unauth_refused`, **not** UNVERIFIED — a real answer is evidence [scripts/verify-node.sh:76] [scripts/verify-node.sh:93] | 2026-11-05 | **measured `VERIFY: FAIL (2)`, exit 1** |
| Ladder arm: gate open | fixture: status `200` with `auth_required:true`, stats `200` | `FAIL unauth_refused … the node is OPEN` [scripts/verify-node.sh:84] | 2026-11-05 | **measured `VERIFY: FAIL (1)`, exit 1** |
| Ladder arm: `auth_required` absent | fixture: status `200`, body `{"status":"ok"}` | `FAIL auth_gate` [scripts/verify-node.sh:65] | 2026-11-05 | **measured `VERIFY: FAIL (1)`, exit 1** |
| Ladder arm: clean pass | fixture: status `200` + `auth_required:true`, stats `401`, both Python legs unmeasurable | `VERIFY: PASS`, exit 0 — with two WARN legs [scripts/verify-node.sh:196] | 2026-11-05 | **measured exit 0** — the residual in §6 |
| `--strict-freshness` | the gap arm plus the flag | an unmeasurable checkout becomes a `FAIL`, so the verdict flips to `VERIFY: FAIL (1)` [scripts/verify-node.sh:139] | 2026-11-05 | **measured exit 1** |
| `--strict-seed` | a 200/401 arm plus the flag | `FAIL seed_drift` carrying `(--strict-seed: unknown is not a pass)` [scripts/verify-node.sh:181] | 2026-11-05 | **measured `VERIFY: FAIL (1)`, exit 1** |
| Both strict flags | the gap arm plus both flags | two FAIL rows, `VERIFY: FAIL (2)` — FAIL outranks UNVERIFIED [scripts/verify-node.sh:191] | 2026-11-05 | **measured exit 1** |
| No `--agent` | `bash scripts/verify-node.sh --server fx` | the usage line naming every flag, exit 2 [scripts/verify-node.sh:32] | 2026-11-05 | **measured exit 2** |
| No `--agent` and no `--server` | `bash scripts/verify-node.sh` | agent is checked first, so the usage line wins over the server message [scripts/verify-node.sh:32] [scripts/verify-node.sh:35] | 2026-11-05 | **measured usage line, exit 2** |
| `--server` omitted, `BUNKER_SERVER` unset | `env -u BUNKER_SERVER bash scripts/verify-node.sh --agent fx` | `set BUNKER_SERVER or pass --server <name>` on stderr, exit 2 [scripts/verify-node.sh:35] | 2026-11-05 | **measured exit 2** — not the `:?` abort `docs/OPERATIONS.md` still describes (§6b) |
| `--server` supplied, `BUNKER_SERVER` unset | `env -u BUNKER_SERVER … --server fx` | the flag alone is sufficient and step 1 runs [scripts/verify-node.sh:20] [scripts/verify-node.sh:24] | 2026-11-05 | **measured: rows printed, exit 3** — both real runs above also ran with the variable unset in this shell |
| Checkout leg's own pass row | `python3 scripts/node_freshness.py --workdir .` in this worktree | `PASS freshness — branch=… head=… origin_main=… ancestor=true behind=0`, exit 0 [scripts/node_freshness.py:366] | 2026-11-05 | **measured `RESULT: PASS`, exit 0** — the exact text step 5 greps [scripts/verify-node.sh:131] |
| `lib.sh` absent | the script copied to a directory with no `lib.sh` | nothing can print a row; the run must not report PASS [scripts/verify-node.sh:18] | 2026-11-05 | **measured: six `command not found` lines, then `FAILED: unbound variable`, exit 1** — no row, no PASS |
| Interpreter is `sh`, not `bash` | `sh scripts/verify-node.sh --agent cf-node --server no-such-server-fx36` | the shebang pins bash [scripts/verify-node.sh:1]; this host's `/bin/sh` is dash, which accepts `pipefail` here (measured), and the observed path was identical | 2026-11-05 | **measured: the same `FAIL agent_alive` + `RESULT: FAIL`, exit 1** — no bash-only construct is load-bearing on the path exercised here |

`--check` is not a flag of this module (verbatim, `EXIT=2`):

```
unknown arg: --check
```

The real run on this control host (verbatim, `EXIT=1`; `BUNKER_SERVER` unset in the shell, `--server` supplied):

```
verify node cf-node
  PASS  agent_alive — ALIVE bunker-las-03
  PASS  node_ip — 192.168.123.66
  WARN  gateway_reachable — no transport from this host to 192.168.123.66:10800 — the gateway answers 200 INSIDE the node, so this is unverified, not failed (CF-224: publish a port or define the transport)
  WARN  unauth_refused — unverified from here (no transport); inside the node it answers 401
  FAIL  checkout_freshness — sync — behind=26 (HEAD..origin/main e7cf075ffff4): 71 differing path(s) — .coding-hermes/board/events.jsonl, .coding-hermes/board/tasks.jsonl, .gitreins/history/2026-11-05/0e9f844d/commit.patch, .gitreins/history/2026-11-05/0e9f844d/summary.md, .gitreins/history/2026-11-05/0e9f844d/verdict.json, .gitreins/history/2026-11-05/3f14d5b8/verdict.json, .gitreins/history/2026-11-05/94c31d59/commit.patch, .gitreins/history/2026-11-05/94c31d59/summary.md, .gitreins/history/2026-11-05/94c31d59/verdict
  PASS  seed_drift — /home/bunker-cf-node/.hermes/seed-applied.json: 13 seeded files present and matching

VERIFY: FAIL (1)
```

That run is the ladder working, not a defect: the node answered inside itself (200 / 401), this host has no transport to `192.168.123.66:10800`, and the checkout is 26 commits behind `origin/main` — the FAIL outranks the UNVERIFIED exactly as coded [scripts/verify-node.sh:191] [scripts/verify-node.sh:192]. The `checkout_freshness` row is cut at 500 characters by the parent [scripts/verify-node.sh:134].

The pure UNVERIFIED arm (fixture peers: this host's `bunker` and `curl` replaced by stubs that answer the two fixed probes and nothing else; verbatim, `EXIT=3`):

```
verify node fx
  PASS  agent_alive — ALIVE fx-node
  PASS  node_ip — 127.0.0.1
  WARN  gateway_reachable — no transport from this host to 127.0.0.1:10800 — the gateway answers 200 INSIDE the node, so this is unverified, not failed (CF-224: publish a port or define the transport)
  WARN  unauth_refused — unverified from here (no transport); inside the node it answers 401
  WARN  checkout_freshness — FAIL (bunker exec failed: fx-bunker: unhandled remote command) — the checkout could not be measured; pass --strict-freshness to refuse it
  WARN  seed_drift — bunker exec failed: fx-bunker: unhandled remote command — the seed could not be measured; pass --strict-seed to refuse it — the seed could not be measured; pass --strict-seed to refuse it

VERIFY: UNVERIFIED — the node answered inside itself, but this host has no transport to it
        (distinct from FAIL on purpose: nothing is broken and nothing is proven — CF-224)
```

A real HTTP answer that is not `200` stays a FAIL (fixture, verbatim, `EXIT=1`):

```
  FAIL  gateway_reachable — http://127.0.0.1:10800/api/status -> 502 (is the harness running on 0.0.0.0:10800?)
  FAIL  unauth_refused — /api/system/stats -> 502 — auth refusal not verified

VERIFY: FAIL (2)
```

## 4. Metrics emitted

**NONE** — and the reason is structural, not an omission.

- No counter, histogram, timestamp, duration or gauge leaves the process. The only counter is in-process — `FAILED`, incremented by `bad()` [scripts/lib.sh:7] [scripts/lib.sh:11] — and it leaves exactly once, inside the closing line `VERIFY: FAIL ($FAILED)` [scripts/verify-node.sh:191]. `UNVERIFIED` is a 0/1 flag, not a count [scripts/verify-node.sh:37].
- The exit code is the only machine-readable signal that is stable across runs: `1` FAIL, `3` UNVERIFIED, `0` PASS, `2` refused usage [scripts/verify-node.sh:191] [scripts/verify-node.sh:195] [scripts/verify-node.sh:196] [scripts/verify-node.sh:29] [scripts/verify-node.sh:32]. A consumer that wants per-leg data must parse prose.
- The files it touches are state, not metrics: `/tmp/node-status.json`, the raw `/api/status` body, overwritten every run and read once [scripts/verify-node.sh:53] [scripts/verify-node.sh:63]; five `mktemp` scratch files, all removed before the verdict [scripts/verify-node.sh:99] [scripts/verify-node.sh:126] [scripts/verify-node.sh:145] [scripts/verify-node.sh:187].
- The only time bounds are refusal budgets, never reported as latencies: `--max-time 8` on each outbound probe and `--max-time 5` on each inside-the-node probe [scripts/verify-node.sh:53] [scripts/verify-node.sh:59] [scripts/verify-node.sh:81].
- Consequence: verification rate, per-leg failure distribution, mean time to verify and node availability over time cannot be answered from this module; they would have to be reconstructed from the closing line and the shell's own timing.

## 5. Log lines it can generate

| Level | Line (verbatim) | Emitted when | Kind |
|---|---|---|---|
| stdout | `verify node $AGENT` [scripts/verify-node.sh:38] | always, after the arguments parse | descriptive |
| stderr | `unknown arg: $1` [scripts/verify-node.sh:29] | an argument matches no case, before anything runs; exit 2 | descriptive |
| stderr | `usage: $0 --agent ID [--server NAME] [--port P] [--artifact PATH] [--strict-freshness] [--strict-seed]` [scripts/verify-node.sh:32] | no `--agent`; exit 2 | descriptive |
| stderr | `set BUNKER_SERVER or pass --server <name>` [scripts/verify-node.sh:35] | no server from flag or environment; exit 2 | descriptive |
| PASS | `  PASS  agent_alive — ALIVE <hostname>` [scripts/verify-node.sh:43] | the agent's first output line starts with `ALIVE` | evidentiary |
| FAIL | `  FAIL  agent_alive — <first line of the exec output>` [scripts/verify-node.sh:44] | the agent did not answer; the run stops here | evidentiary |
| — | `RESULT: FAIL` [scripts/verify-node.sh:44] | immediately after `agent_alive` fails — **not** `VERIFY:` (see §6) | evidentiary |
| PASS | `  PASS  node_ip — <ip>` [scripts/verify-node.sh:49] | `hostname -I` produced a first field | evidentiary |
| FAIL | `  FAIL  node_ip — could not read hostname -I` [scripts/verify-node.sh:49] | the same read produced nothing; the run continues with an empty host | evidentiary |
| PASS | `  PASS  gateway_reachable — <url> -> 200` [scripts/verify-node.sh:62] | `/api/status` answered 200 from this host | evidentiary |
| PASS | `  PASS  auth_gate — auth_required:true (a public bind must not be open)` [scripts/verify-node.sh:64] | that 200 body carries a boolean true `auth_required` | evidentiary |
| FAIL | `  FAIL  auth_gate — /api/status -> 200; auth_required:true not measured — check dashboard.basic_auth` [scripts/verify-node.sh:65] | the body does not carry it — a 200 alone is not a closed gate | evidentiary |
| WARN | `  WARN  gateway_reachable — no transport from this host to <ip>:<port> — the gateway answers 200 INSIDE the node, so this is unverified, not failed (CF-224: publish a port or define the transport)` [scripts/verify-node.sh:70] | `000` outside, `200` from inside — the node is healthy behind a gap | evidentiary |
| WARN | `  WARN  gateway_reachable — no transport to <ip>:<port>, and the gateway does not answer inside the node either (<code>) — the harness is not up` [scripts/verify-node.sh:73] | `000` outside and anything but `200` inside | evidentiary |
| FAIL | `  FAIL  gateway_reachable — <url> -> <code> (is the harness running on 0.0.0.0:<port>?)` [scripts/verify-node.sh:77] | a real HTTP answer that is not `200` | evidentiary |
| PASS | `  PASS  unauth_refused — /api/system/stats -> 401` [scripts/verify-node.sh:83] | the gate refused an unauthenticated request with 401, 302 or 403 | evidentiary |
| FAIL | `  FAIL  unauth_refused — /api/system/stats -> 200 — the node is OPEN to the tailnet` [scripts/verify-node.sh:84] | the gate answered the unauthenticated request | evidentiary |
| WARN | `  WARN  unauth_refused — unverified from here (no transport); inside the node it answers 401` [scripts/verify-node.sh:88] | `000` outside, a refusal code inside — the load-bearing WARN of this module | evidentiary |
| FAIL | `  FAIL  unauth_refused — /api/system/stats -> 200 INSIDE the node — the gateway is open` [scripts/verify-node.sh:89] | `000` outside but the node's own gateway serves stats unauthenticated | evidentiary |
| WARN | `  WARN  unauth_refused — unverified: no transport from here, and <code> inside the node` [scripts/verify-node.sh:90] | `000` outside and a non-refusal, non-200 code inside | evidentiary |
| FAIL | `  FAIL  unauth_refused — /api/system/stats -> <code> — auth refusal not verified` [scripts/verify-node.sh:93] | any other real code, e.g. `404` or `500` — uncertainty is not a pass [scripts/verify-node.sh:93] | evidentiary |
| PASS | `  PASS  artifact_digest — <basename> <sha12> on both sides` [scripts/verify-node.sh:103] | `--artifact` given and both digests match and are non-empty | evidentiary |
| FAIL | `  FAIL  artifact_digest — node <sha12> vs host <sha12> — bytes differ or file missing` [scripts/verify-node.sh:105] | digests differ, or the node's digest is empty | evidentiary |
| FAIL | `  FAIL  checkout_freshness — <path> missing — the checkout's git state is unmeasured` [scripts/verify-node.sh:124] | `scripts/node_freshness.py` is not readable | evidentiary |
| PASS | `  PASS  checkout_freshness — branch=… head=… origin_main=… ancestor=true behind=0` [scripts/verify-node.sh:131] | the child exited 0 and printed its `freshness` row | evidentiary |
| FAIL | `  FAIL  checkout_freshness — <child FAIL rows joined by ' \| '>` [scripts/verify-node.sh:134] | the child exited 1 — drift, dirty, no origin, not a checkout [scripts/node_freshness.py:362] | evidentiary |
| WARN | `  WARN  checkout_freshness — <child RESULT detail> — the checkout could not be measured; pass --strict-freshness to refuse it` [scripts/verify-node.sh:141] | the child exited anything but 0 or 1 (unreachable, usage, crash) | evidentiary |
| FAIL | `  FAIL  checkout_freshness — <detail> (--strict-freshness: unknown is not a pass)` [scripts/verify-node.sh:139] | the same case with `--strict-freshness` | evidentiary |
| PASS | `  PASS  seed_drift — <record>: N seeded files present and matching` [scripts/verify-node.sh:172] | the child exited 0 | evidentiary |
| FAIL | `  FAIL  seed_drift — <drifted paths with both digest prefixes>` [scripts/verify-node.sh:175] | the child exited 1 — a seeded file drifted or is absent | evidentiary |
| FAIL | `  FAIL  seed_drift — <detail> (--strict-seed: unknown is not a pass)` [scripts/verify-node.sh:181] | no record or unmeasurable, with `--strict-seed` | evidentiary |
| WARN | `  WARN  seed_drift — <detail> — the seed could not be measured; pass --strict-seed to refuse it` [scripts/verify-node.sh:183] | no record or unmeasurable, default mode | evidentiary |
| — | `VERIFY: PASS` [scripts/verify-node.sh:196] | last line, nothing failed and nothing was unverified; exit 0 | evidentiary |
| — | `VERIFY: FAIL ($FAILED)` [scripts/verify-node.sh:191] | last line, at least one FAIL row; exit 1 | evidentiary |
| — | `VERIFY: UNVERIFIED — the node answered inside itself, but this host has no transport to it` [scripts/verify-node.sh:193] | last line, no FAIL row and at least one transport gap; exit 3 | evidentiary |
| — | `        (distinct from FAIL on purpose: nothing is broken and nothing is proven — CF-224)` [scripts/verify-node.sh:194] | always the line after the UNVERIFIED verdict | descriptive |

## 6. Failure modes

Direction: **fail-closed** = the node is not blessed and the exit is non-zero, **fail-open** = the node is blessed, **no-row** = the run continues with nothing printed, **unverified** = exit 3, neither blessed nor condemned by design.

### 6a. Ladder behaviour

| Failure | Presents as | Direction | Distinguished from | Recovery |
|---|---|---|---|---|
| No `--agent` | the `usage:` line on stderr, exit 2 [scripts/verify-node.sh:32] | fail-closed | an unknown flag, which prints `unknown arg:` and also exits 2 [scripts/verify-node.sh:29] | pass `--agent ID` |
| No server anywhere | `set BUNKER_SERVER or pass --server <name>`, exit 2 [scripts/verify-node.sh:35] | fail-closed | a server name that does not exist, which fails at step 1 instead [scripts/verify-node.sh:44] | export `BUNKER_SERVER` or pass `--server` |
| Agent dead or unreachable | `FAIL agent_alive`, then `RESULT: FAIL`, exit 1, and **no `VERIFY:` line at all** [scripts/verify-node.sh:44] | fail-closed, but with a different closing vocabulary (§6c) | a live agent whose gateway is down, which still prints a `VERIFY:` line [scripts/verify-node.sh:77] | fix the agent; nothing else is graded |
| `hostname -I` unreadable | `FAIL node_ip` and the run continues with an empty host in every later URL [scripts/verify-node.sh:49] [scripts/verify-node.sh:50] | fail-closed by accumulation (FAILED is already ≥1), no-row for the address itself | a reachable node, which prints the address [scripts/verify-node.sh:49] | fix the agent's networking |
| Transport gap, gateway alive inside | two WARN rows, `VERIFY: UNVERIFIED`, exit 3 [scripts/verify-node.sh:70] [scripts/verify-node.sh:88] [scripts/verify-node.sh:195] | **unverified** — the whole point of CF-224 | a real non-200 answer, which is FAIL [scripts/verify-node.sh:77] | publish the port or define the transport; do not "fix" the node |
| Transport gap, nothing answers inside | `… the harness is not up`, still UNVERIFIED, exit 3 [scripts/verify-node.sh:73] | **unverified, and this is the softest edge in the file** — a harness that is provably not running is not called FAIL | the inside-200 case, which is a healthy node behind a gap [scripts/verify-node.sh:70] | start the harness inside the node, then re-run; a gate that only reads "not 1" treats this run as admission-worthy |
| Real HTTP code that is not 200 | `FAIL gateway_reachable — … -> 502` [scripts/verify-node.sh:77] | fail-closed | the `000` branches, which are unverified [scripts/verify-node.sh:66] | read the code: 5xx is the harness, 404 is a wrong port |
| Gate open to the tailnet | `FAIL unauth_refused — … 200 — the node is OPEN` [scripts/verify-node.sh:84] | fail-closed | a refusal code, which passes [scripts/verify-node.sh:83] | quarantine the node before anything else [docs/OPERATIONS.md:101] |
| `auth_required` absent from a 200 body | `FAIL auth_gate` [scripts/verify-node.sh:65] | fail-closed | a body that reports it true [scripts/verify-node.sh:64] | check `dashboard.basic_auth` in the node's config [scripts/harness/install-hermes.sh:202] |
| Refusal code the node only shows from inside | `WARN unauth_refused — unverified from here … it answers 401` [scripts/verify-node.sh:88] | **unverified** | `200` inside, which is FAIL [scripts/verify-node.sh:89] | no action on the node; the gap is the finding |
| Artifact differs or is missing on the node | `FAIL artifact_digest — node <sha> vs host <sha>` [scripts/verify-node.sh:105] | fail-closed (empty remote digest cannot match) [scripts/verify-node.sh:102] | an unreadable artifact, which lands in the same row because stderr is suppressed [scripts/verify-node.sh:98] | re-transfer the bytes and compare again |
| `node_freshness.py` missing | `FAIL checkout_freshness — <path> missing` [scripts/verify-node.sh:124] | fail-closed | an unmeasurable checkout, which is a WARN [scripts/verify-node.sh:141] | restore the file; it is part of the tree |
| Checkout drifted or dirty | `FAIL checkout_freshness` naming `sync — behind=N` and the differing paths [scripts/verify-node.sh:134] [scripts/node_freshness.py:340] | fail-closed | an unmeasurable checkout, which defaults to WARN | land the node's tree on `origin/main`; a dirty tree is a finding whose fix belongs upstream [scripts/node_freshness.py:285] |
| Checkout unmeasurable | `WARN checkout_freshness — … could not be measured` [scripts/verify-node.sh:141] | **fail-open by default**, fail-closed under `--strict-freshness` [scripts/verify-node.sh:139] | drift, which is FAIL | pass `--strict-freshness` in a gate that must refuse unknowns |
| Seed drifted | `FAIL seed_drift` naming each path with both digest prefixes [scripts/verify-node.sh:175] | fail-closed | no record yet, which is a WARN | re-seed the node |
| Seed unmeasurable or unrecorded | `WARN seed_drift — … could not be measured` (sentence printed twice) [scripts/verify-node.sh:183] | **fail-open by default**, fail-closed under `--strict-seed` [scripts/verify-node.sh:181] | drift, which is FAIL | pass `--strict-seed`, or apply the seed |
| Both legs unmeasurable, everything else green | `VERIFY: PASS`, exit 0, with two WARN rows [scripts/verify-node.sh:196] | **fail-open** — `PASS` while the newest two legs measured nothing (measured: §3 clean-pass row, and again with `--strict-seed` where it becomes FAIL) | the same run under `--strict-*`, which is FAIL | a gate must use the strict flags if "unmeasured" must not pass |
| A leg warns under `--strict-*` and another leg fails | `VERIFY: FAIL (n)` — FAIL outranks UNVERIFIED [scripts/verify-node.sh:191] | fail-closed | a pure gap, which is exit 3 [scripts/verify-node.sh:192] | fix the FAIL; the gap still needs a transport |

### 6b. Where `docs/OPERATIONS.md` contradicts this script

The runbook was written before the ladder changed: it is wrong in four rows — two of them the same claim — and stale in two.

| Runbook claim | What the script does now | Evidence |
|---|---|---|
| "`BUNKER_SERVER` must be set even when `--server NAME` is supplied — `scripts/verify-node.sh:17` expands `${BUNKER_SERVER:?…}` … so the flag cannot satisfy the guard … exits 1" [docs/OPERATIONS.md:129] | the assignment uses `${BUNKER_SERVER:-}` and the guard runs **after** parsing, so `--server` alone is sufficient; the message is `set BUNKER_SERVER or pass --server <name>` and the exit is **2**, not 1 [scripts/verify-node.sh:20] [scripts/verify-node.sh:24] [scripts/verify-node.sh:33] [scripts/verify-node.sh:35] | both real runs above ran with `BUNKER_SERVER` unset; the fixture arm reproduced the message and exit 2 |
| the same claim repeated in the command inventory [docs/OPERATIONS.md:201] | same as above [scripts/verify-node.sh:20] | same arms |
| "`verify-node.sh:53–58` accepts unauthenticated `/api/system/stats` only with 401, 302, or 403; every other code (including 000, 404, 500 and 200) is a named `FAIL unauth_refused`" [docs/OPERATIONS.md:84] | `000` is handled as its own branch: a refusal inside the node is a **WARN + UNVERIFIED**, `200` inside is FAIL, and only other real codes reach the plain FAIL [scripts/verify-node.sh:85] [scripts/verify-node.sh:88] [scripts/verify-node.sh:89] [scripts/verify-node.sh:93] | §3 gap arm: `WARN unauth_refused — unverified from here …` and exit 3 |
| "`verify-node.sh:43–49` requires the status body to report boolean `auth_required: true`" [docs/OPERATIONS.md:84] | the gate is graded at `:61–65` [scripts/verify-node.sh:61] [scripts/verify-node.sh:65], and only when `/api/status` answered 200 — during a transport gap no `auth_gate` row is printed at all | the real run above has no `auth_gate` row |
| "no auth exception for `verify-node.sh`" and a CF-077 warn table with no row for this file [docs/OPERATIONS.md:88] | the script has six `warn` sites: gateway gap, dead-inside, refusal-inside, other-inside, unmeasurable checkout, unmeasurable seed [scripts/verify-node.sh:70] [scripts/verify-node.sh:73] [scripts/verify-node.sh:88] [scripts/verify-node.sh:90] [scripts/verify-node.sh:141] [scripts/verify-node.sh:183] | every fixture arm shows at least one WARN row |
| step 3 of the dispatch section describes four probes and no exit code but "non-zero" [docs/OPERATIONS.md:129] | there are six legs and three outcomes: PASS 0, FAIL 1, UNVERIFIED 3 [scripts/verify-node.sh:191] [scripts/verify-node.sh:195] [scripts/verify-node.sh:196] | §3 |

One runbook sentence survives intact and is worth keeping: "A WARN is not approval to expose the gateway: neither auth leg can warn and pass" [docs/OPERATIONS.md:84] — the rows can warn, but a warning leg sets `UNVERIFIED`, so exit 0 becomes unreachable [scripts/verify-node.sh:92] [scripts/verify-node.sh:192].

### 6c. Defects found in this module

| Defect | Presents as | Direction | Evidence |
|---|---|---|---|
| `--port` is interpolated unescaped into a remote `bash -lc` string | the remote command text becomes `curl … 'http://127.0.0.1:10800';echo …;'/api/status'` — a quote in `--port` closes the quoted URL and starts a new command on the node [scripts/verify-node.sh:59] | **fail-open** (arbitrary command on the node from a control-host flag); the same class CF-159 fixed elsewhere, and the helper that exists for exactly this is `shq` [scripts/lib.sh:54] | measured with a tracing `bunker` stub: the exact remote text was captured verbatim (§8). `--port` is never validated and is also spliced into both URLs [scripts/verify-node.sh:50] [scripts/verify-node.sh:81]. Only `--artifact` goes through `shq` [scripts/verify-node.sh:98] |
| `/tmp/node-status.json` is a fixed, shared path | two concurrent verifies on one control host can grade `auth_gate` from the other run's body [scripts/verify-node.sh:53] [scripts/verify-node.sh:63] | **fail-open** — a stale body carrying `auth_required:true` passes a node that never sent it | measured: with the file pre-seeded and a peer that wrote nothing, the run printed `PASS auth_gate — auth_required:true` (§8). `mktemp` is used everywhere else in the file [scripts/verify-node.sh:99] |
| The early abort prints `RESULT: FAIL`, not `VERIFY: FAIL` | a parser watching for `^VERIFY:` sees nothing on an agent-dead run, though the exit is 1 [scripts/verify-node.sh:44] | fail-closed, but a **silent gap for the consumer** | measured: `  FAIL  agent_alive — …` then `RESULT: FAIL`, exit 1 |
| The seed WARN repeats its own sentence | `… the seed could not be measured; pass --strict-seed to refuse it — the seed could not be measured; pass --strict-seed to refuse it` [scripts/verify-node.sh:178] [scripts/verify-node.sh:183] | cosmetic, verdict unaffected | measured in five fixture arms |
| Under `--strict-seed` the FAIL still advises the flag that was just used | `… pass --strict-seed to refuse it (--strict-seed: unknown is not a pass)` [scripts/verify-node.sh:181] | cosmetic | measured (§3, the `--strict-seed` row) |
| A WARN row can begin its detail with the word `FAIL` | `WARN checkout_freshness — FAIL (bunker exec failed: …)` because the parent lifts the child's `RESULT:` line verbatim [scripts/verify-node.sh:137] [scripts/verify-node.sh:141] | cosmetic, but a `grep FAIL` census miscounts it | measured in the gap arm |
| A checkout leg that exits 2 because *the parent's own argv* is wrong reads as "could not be measured" | `WARN … could not be measured` instead of a usage error [scripts/verify-node.sh:136] [scripts/node_freshness.py:238] | hides a caller bug behind a WARN | read-from-code; the child returns `2` for a usage error and for unreachability alike [scripts/node_freshness.py:238] [scripts/node_freshness.py:699] |
| `lib.sh` absent removes every row | six `command not found` lines and `FAILED: unbound variable`, exit 1 [scripts/verify-node.sh:18] [scripts/verify-node.sh:191] | no-row (with a non-zero exit by accident) | measured (§3) |
| A missing `curl` silently becomes a transport gap | the probe yields `000`, so an absent client reads exactly like an unreachable node [scripts/verify-node.sh:53] [scripts/verify-node.sh:66] | **unverified** in the wrong direction — the control host's own defect is reported as the node's transport | read-from-code; nothing checks that `curl` exists |

## 7. Environment and settings it reads

| Variable | Default | Read at | Effect if unset |
|---|---|---|---|
| `BUNKER_SERVER` | empty — `${BUNKER_SERVER:-}` [scripts/verify-node.sh:20] | before the argument loop, as the default for `--server` [scripts/verify-node.sh:20] | with no `--server` either, the run refuses with `set BUNKER_SERVER or pass --server <name>` and exit 2 [scripts/verify-node.sh:35]. Measured: `--server` alone is sufficient |
| `--server` (argv) | inherited default above | overrides the variable in the loop [scripts/verify-node.sh:24] | a name the CLI does not know fails step 1 [scripts/verify-node.sh:44] |
| `--port` (argv) | `10800` [scripts/verify-node.sh:20] | spliced into both URLs and into the remote command text [scripts/verify-node.sh:50] [scripts/verify-node.sh:59] [scripts/verify-node.sh:81] | the default port is used; **no validation**, see §6c |
| `--artifact` (argv) | empty — leg skipped [scripts/verify-node.sh:20] | the artifact leg, quoted for the remote side with `shq` [scripts/verify-node.sh:97] [scripts/verify-node.sh:98] | the whole leg prints nothing |
| `--strict-freshness` | `0` [scripts/verify-node.sh:20] | the unmeasurable-checkout branch [scripts/verify-node.sh:138] | an unmeasurable checkout is a WARN, never a FAIL [scripts/verify-node.sh:141] |
| `--strict-seed` | `0` [scripts/verify-node.sh:20] | forwarded to the child as its own flag [scripts/verify-node.sh:166] [scripts/verify-node.sh:167] | an unmeasurable seed is a WARN [scripts/verify-node.sh:183] |
| `PATH` | inherited | `bunker`, `curl`, `python3`, `mktemp`, `sha256sum`, and every text helper [scripts/verify-node.sh:41] [scripts/verify-node.sh:53] [scripts/verify-node.sh:98] [scripts/verify-node.sh:127] | a missing `bunker` fails step 1; a missing `curl` becomes a fake transport gap; a missing `python3` warns on both Python legs (§6c) |
| `TMPDIR` | inherited | the five `mktemp` scratch files [scripts/verify-node.sh:99] [scripts/verify-node.sh:126] [scripts/verify-node.sh:165] | scratch lands in the system temp dir; **`/tmp` is hard-coded regardless** for the status body [scripts/verify-node.sh:53] |
| `HOME` | inherited | not read here, but both Python children resolve the node's home **from the agent** rather than templating it [scripts/node_freshness.py:28] | the children measure `repo` under the node's own `$HOME` [scripts/verify-node.sh:127] [scripts/verify-node.sh:168] |
| credentials | **none read** | the file passes no token, key or bearer anywhere; the bunker CLI carries its own agent trust from its config | nothing to leak in argv or in a log line — consistent with the repo rule that credentials travel as 600-mode files, never argv values [fact: FACT-05] |

Settings that live outside this file but decide its verdict: the node's `dashboard.basic_auth` block in `$HOME/.hermes/config.yaml`, which is what the gateway's `auth_required` reflects [scripts/harness/install-hermes.sh:202], and the gateway bind, which the adapter starts on `0.0.0.0` at the chosen port [scripts/harness/install-hermes.sh:284]. One bunker serves one project and every lane of it enters the same one [fact: FACT-02], so the single `--agent` id is the whole scope of this check.

## 8. Evidence of record

- Source read in full at `e7cf075`: 197 lines of `scripts/verify-node.sh`, 65 of `scripts/lib.sh`, and the two Python children it folds in. Every claim above resolves to one of those lines or to the peer file that owns the other side of the contract.
- Runs recorded in this document, all on 2026-11-05 from this control host: real `--agent cf-node --server bunker-las-03` → `VERIFY: FAIL (1)`, exit 1, with two UNVERIFIED WARN rows and a `behind=26` checkout; the same with `--artifact /etc/hostname` → `PASS artifact_digest — hostname 96aa37a6e3ab on both sides`, exit 1; with `--artifact /nonexistent-fx36` → `VERIFY: FAIL (2)`, exit 1; `--server no-such-server-fx36` → `RESULT: FAIL`, exit 1; `--check` → `unknown arg: --check`, exit 2; no `--agent` → usage, exit 2; no server → `set BUNKER_SERVER or pass --server <name>`, exit 2.
- Sixteen ladder arms ran against stub `bunker`/`curl` peers in `~/.hermes/cache/scratch/fx36/` (a tracing stub records the exact remote command text the node would run), plus `--check`, which is parsed before any peer is touched: PASS 0, FAIL 1, `auth_required`-absent FAIL, 502 FAIL, open-gate FAIL, gap-with-200-inside exit 3, gap-with-nothing-inside exit 3, both strict flags exit 1, `--strict-freshness` exit 1, `--strict-seed` exit 1, `--server`-only exit 3, `--port` with a quote exit 3, the stale-`/tmp/node-status.json` arm, and the three usage arms. The `/tmp/node-status.json` arm printed `PASS auth_gate — auth_required:true` for a run that fetched no body, which is the §6c race.
- The stub trace that proves the `--port` interpolation is on record: the node-side command text was captured verbatim as `curl -s -o /dev/null -w '%{http_code}' --max-time 5 'http://127.0.0.1:10800';echo FX36_INJECTED;'/api/status'` — the quote closes the URL literal. Remote execution of that text was deliberately **not** run: the harness refused the local demonstration, so the record covers the interpolation and stops there.
- `lib.sh` absence was measured by copying the script into a directory without it: `./verify-node.sh: line 18: …/lib.sh: No such file or directory`, six `command not found` lines, then `line 191: FAILED: unbound variable`, exit 1.
- Checkout leg proved green independently of the node: `python3 scripts/node_freshness.py --workdir .` in this worktree → `PASS freshness — branch=wt/md-36b head=e7cf075ffff4 origin_main=e7cf075ffff4 ancestor=true behind=0`, `RESULT: PASS`, exit 0 [scripts/node_freshness.py:366].
- The 401 rule is grounded in the bus contract as well as this file: an unsigned read is a 401 by design, so a 401 is evidence the gate exists [fact: FACT-03]; nothing in this file treats 401 as a failure [scripts/verify-node.sh:83] [scripts/verify-node.sh:88].
- One bunker, one project, one agent id — the reason a single `--agent` is the whole scope [fact: FACT-02]; and no credential is ever passed as a value by this file [fact: FACT-05].
- Evidence here is re-runnable by construction, not narrative: every §3 row is a command whose exit code is part of the record, which is the repo's standing rule for closing work [fact: FACT-10].
- Self-test surfaces that can go red on this module: the freshness section of `tests/selftest.sh` drives the checkout leg and the seed section drives the seed leg offline in three directions [tests/selftest.sh:2829] [tests/selftest.sh:3150]. This document's own gate: `python3 scripts/master_doc_check.py docs/master --only 36- --strict` → `MASTER-DOC: PASS`.
