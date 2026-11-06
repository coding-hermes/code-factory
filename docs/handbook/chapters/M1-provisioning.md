# M1 — PROVISIONING

## 1. Identity

| Field | Value |
|---|---|
| Module name | PROVISIONING |
| Path | `/home/kara/code-factory/scripts/` — `bunker-server-install.sh`, `disk_floor.py`, `bunker-provision.sh`, `bunker_config_gen.py`, `node-create.sh`, `bunker-crier-connect.sh`, `node_identity.py`, `node_gateway_auth.py`, `node_seed.py`, `node_seed_drift.py`, `node_env.py`, `verify-node.sh`, `node_freshness.py` |
| Revision | `943ef984dc093e5780605ac6e54cd043122126ef` (code-factory HEAD, 2026-11-06) |
| Language / runtime | bash 5.3.9 + Python 3.14.9 (measured) |
| Owner lane | code-factory (node-side) |
| Status | **UNVERIFIED (bodies)** — `bunker-provision.sh` `--check` probe, config loader (`:95-123`), CLI (`:561-609`), `destroy` (`:550-558`), `disk_floor.py` `resolve()` (`:115-141`), `verify-node.sh` (`:20-214`), `node_identity.py` (111 lines, full), `node_seed.py` (405 lines, apply/build/check state machine) read this round; `node_env.py` (589), `node_seed_drift.py` (558), `node_freshness.py` (732), `bunker_config_gen.py` (724) read at their **settings surface** (argparse + constants), bodies not line-by-line; `node_gateway_auth.py` unread |

## 2. Purpose, authority and position

Turns a bare host into a node: identity, bus membership, a seeded repo. It decides whether a
host qualifies (disk floor), what identity and credentials a node carries, and what seed
(prompts, skills, env) it starts with. It may not decide what the node *runs* — that is M2/M5.
Provisioning without seeding produces a node that cannot work, which is why the two are one
module (`docs/UNIT-MAP.yaml:9`).

**What breaks if this module is absent.** A bare host never becomes a node: no identity, no bus
membership, no seeded repo, so the scheduler has nothing to dispatch to and every lane sits in
the inbox until it expires.

**What breaks if it lies.** Two measured lies this round:
- `bunker-provision.sh` `--check` reports a credential "mode 600" while testing only file
  non-emptiness: `:214` probes `[ -s "$HOME/.node/auth/github.token" ]`, and `:233` prints
  `token file installed, mode 600 (value not read)`. A provisioner proceeds with an insecure
  credential (F1-1).
- `verify-node.sh` certifies `VERIFY: PASS` even when checkout freshness was **unmeasurable**
  (B05): the checkout leg prints WARN but does not set UNVERIFIED, unlike the seed leg (see §11).

## 3. Submodule inventory

| Submodule | Unit | Classification | Evidence (invoking line) |
|---|---|---|---|
| S1 qualify the host | `bunker-server-install.sh`, `disk_floor.py` | **active** | `disk_floor.py` is invoked by `project-node.sh:173` (`python3 "$HERE/disk_floor.py" … resolve …`), not by `bunker-provision.sh` (F1-4) |
| S2 create the container + config | `bunker-provision.sh`, `bunker_config_gen.py`, `node-create.sh`, `bunker-crier-connect.sh` | **operator-invoked** | `bunker-provision.sh` is the orchestrator (probe `:175-249`) but has **no in-repo invoker** — `grep -rn 'bunker-provision' scripts/` matches only `bunker_config_gen.py` docstrings; an operator runs it (glm 2) |
| S3 identity and bus membership | `node_identity.py`, `node_gateway_auth.py` | **active** | `node_gateway_auth.py` staged and run inside `bunker-provision.sh:483-495`; `node_identity.py` at `:518-533`; the standalone `node-create.sh` never calls it (CF-192) |
| S4 seed prompts/skills/env | `node_seed.py`, `node_seed_drift.py`, `node_env.py` | **active** | `node_seed.py build` at `bunker-provision.sh:454`; `node_env.py --check` at `:147` / `--apply` at `:426` |
| S5 prove the node works | `verify-node.sh`, `node_freshness.py` | **active** | `verify-node.sh` is the certification ladder (`:20-214`); `node_freshness.py` folded in at `:118-155` |

**S4 seed state machine (B06, written this round).** `node_seed.py` is three commands:

- `build` (`:114-164`) — on the control host: walks the manifest (`DEFAULT_MANIFEST`,
  `config/node-seed.txt`, `:43`), hashes every file (`sha256 per file`), writes the tarball and
  the digest record; `ok("seed_record", …)` at `:164`.
- `apply` (`:205-328`) — on the node, in order: (1) extract to a staging dir with path-traversal
  refusal (`:207-225`); (2) verify **every** recorded digest against the staged file — any
  mismatch or missing file aborts with `nothing installed`, return 1 (`:226-247`); (3) classify
  each `prompts/` and `skills/` file as **new / changed / removed / local-only** against the prior
  seed record (`:249-278`); (4) with `--force`, `rmtree` the destination and `copytree` wholesale
  (`:280-291`); without `--force`, copy only **new** files and *preserve* changed/removed/local-only
  files, reporting each (`:292-318`); (5) write the applied record `seed-applied.json`
  (`applied_at`, `applied_to`, `:320-327`).
- `check` (`:333-…`) — compare the node against the record.

The preserve-by-default semantics determine whether a provisioned node actually carries the
intended procedure: without `--force`, a node-local edit to `prompts/foreman.md` survives the
seed and is reported `preserved … (changed locally; --force to replace)` — a later `verify-node.sh`
seed leg will flag it as drift. The `--force` path deletes such local edits without reporting them
as data loss (B06).

## 4. Dependencies

**4a. Runtime dependencies**

| Dependency | Version constraint | Where | How absence is detected |
|---|---|---|---|
| bash | >= 4 | node + control host | undefined `lib.sh` helper aborts |
| python3 | 3.x | node + control host | `command -v python3` empty → FAIL row |
| `bunker` CLI | resolved via `have bunker` (PATH order, `lib.sh:13`; `bunker-provision.sh:181`) — **not** an absolute path | control host | `bad "bunker_cli" "no bunker client on PATH"` (`:182`) |
| crier bus | reachable | `http://<crier-host>:8767` | `reach:` FAIL row / non-200 |

**4b. Library contracts**

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `lib.sh` | this repo | `ok`/`bad`/`FAILED`/`have`/`require_disk`/`fetch_verified` | any rename breaks every provisioner script |
| `disk_floor.py` | this repo | `resolve()` precedence — cli `:127` > env `:129` > `[disk]` config `:130-140` > role default `:141` | floor resolution silently changes admission |

**4c. Service contracts** — see §6.

## 5. Settings register

**`disk_floor.py` (S1):**

| Setting | Default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| `ROLE_DEFAULTS` | `{"worker": 5, "builder": 10, "full": 20}` GiB (`disk_floor.py:36`) | 1..4096 GiB (`MIN_GIB`/`MAX_GIB`) | admission floor per role | a value outside the range is refused (`:68-71`) |
| `DEFAULT_ROLE` | `"worker"` (`:37`) | one of the role keys | which floor applies when no role is named | an **unknown explicit role is refused**, not defaulted (F1-2; raise at `:123-125`) |

**`bunker-provision.sh` (S2):**

| Setting | Default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| config keys | `PROJECT AGENT SERVER REPO REF HARNESS NAMESPACE NAMESPACES TTL CRIER_URL DUCKBRAIN_URL GIT_AUTHOR_* CONFIG_SET_* *_TOKEN_FILE …` (`:38-46` declares the full var surface; `:108-123` loads it) | KEY=VALUE lines only | provisioning inputs | an unknown key is refused (`:119`); a non-`KEY=VALUE` line is refused (`:103`) |
| `TTL` | **6h** (spawn fallback `${TTL:-6h}` at `:356`) | a Go duration | container spawn TTL | an absent/empty TTL falls back to 6h, not an error |
| mode | `check`/`apply`/`destroy` (`:561-609`) | one of three | what the run does | `--destroy` requires `--yes` and a non-empty `--agent`, else exit 2 (`:552-554` — `:550` is `destroy() {`) |

**`node_seed.py` (S4):**

| Setting | Default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| `--manifest` (build) | `config/node-seed.txt` (`:43`, `:374`) | a path | which files enter the seed | a wrong manifest seeds a different procedure |
| `--budget` (build) | **16 MiB** (`DEFAULT_BUDGET`, `:44`, `:377`) | bytes | seed tarball size ceiling | a larger budget admits a bloated seed |
| `--force` (apply) | false (`:387-390`) | flag | wholesale replace of `prompts/`+`skills/` | true deletes node-local edits via `rmtree` (`:290`) without data-loss reporting |
| `--home` (apply/check) | `~` (`:383`, `:393`) | a path | the node `.hermes` root | a wrong home installs/checks the wrong tree |

**`bunker_config_gen.py` (S2, settings surface):**

| Setting | Default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| `--harness` | `hermes` (`:107`, `:515`) | a harness name | the node's default harness | a wrong default changes every generated node config |
| `--ref` | `main` (`:106`, `:516`) | a git ref | the seeded branch | a wrong ref seeds the wrong tree |
| `--ttl` | `6h` (`:108`, `:517`) | a Go duration | config TTL | a wrong TTL expires containers early |
| `--force` / `--check` | off / off (`:523-524`) | flags | rewrite-a-differing-config / read-only drift check | `--check` is read-only; `--force` rewrites a differing config |

**Config-vs-CLI precedence (locator re-pinned this round).** `load_config` (`:95-123`) parses the file as data
(never sources it), then the CLI flags are re-applied on top — "the command line always wins"
(`:589`). Five flags were assigned during parsing and then overwritten by `load_config`, so they
are applied again after the config (`:604-608`) — a documented precedence bug fixed by re-ordering.

**Floor precedence (verified, F1-3).** `disk_floor.py:115-141` `resolve()` applies, in order:
`--disk-floor` (cli, `:127`) → `NODE_DISK_FLOOR` (env, `:129`) → `[disk]` config key
(`{role}_gib`, then `default`, `:130-140`) → `ROLE_DEFAULTS[role]` (`:141`).

## 6. Contracts in and out

| ID | Peer | Direction | Producer `file:function` | Consumer `file:function` | State |
|---|---|---|---|---|---|
| M1-C1 | crier | out | **none in-repo** — `bunker-crier-connect.sh` stages `$HOME/.node/crier.json` and probes the inbox via `node-bus-worker.py --check` (`:13`, `:33`, `:53`, `:114-118`); it does **not** issue a registration request or write `auth/crier.token` (sol B06). Registration is the node's own act (or `node_identity.py`/`node_gateway_auth.py`) | crier `internal/registry/handler.go:598` `HandleRegister` (POST `/agents`) and `:613` `HandleRegisterByID` (POST `/agents/{id}`) — round-4 cited only `HandleRegister` for the id-in-path route, which is wrong (kimi B08) | **UNVERIFIED** — the token/registration exchange was not re-run this round, and the in-repo producer half is not established |
| M1-C2 | bunker daemon | out | `lib.sh:75` `bunker_exec` | **rumour — one side only** (the external `bunker` binary) | works (short create/exec/cp calls) |

## 7. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| shell parse | `for f in scripts/bunker-*.sh scripts/node-create.sh scripts/verify-node.sh scripts/bunker-crier-connect.sh; do bash -n "$f"; done` | exit 0 | 2026-11-06 | PASS (in 20/20 sweep) |
| python compile | `python3 -m py_compile scripts/disk_floor.py scripts/node_identity.py scripts/node_gateway_auth.py scripts/node_seed.py scripts/node_seed_drift.py scripts/node_env.py scripts/node_freshness.py` | exit 0 | 2026-11-06 | PASS |
| disk floor unit | `python3 tests/test_disk_floor.py` | 12 tests pass | 2026-11-06 | **PASS** (rc 0) |
| certification ladder | `scripts/verify-node.sh --agent <id> --server <host>` on a live node | per-leg observation | not run this round | **UNVERIFIED** (needs a live node; legs documented in §11) |

## 8. Metrics

**RED — none (absence-proved this round).** No provisioner script exports counters, gauges or
histograms — `grep -nE 'prometheus|Counter|Gauge|Histogram|/metrics' scripts/bunker-provision.sh
scripts/disk_floor.py scripts/verify-node.sh scripts/node_*.py scripts/bunker_config_gen.py
scripts/node-create.sh scripts/bunker-crier-connect.sh scripts/bunker-server-install.sh` → 0 matches.
Provisioning rate, refusal rate and per-leg latency are answerable only by reading the log.

## 9. Log lines (verbatim)

| Level | Line | Emitted when | Kind |
|---|---|---|---|
| — | `  PASS  %s — %s` / `  FAIL  %s — %s` (`lib.sh:6-7`) | every provisioner row | descriptive (see M0 F0-4) |
| — | `  FAIL  reach:%s — %s` | an unreachable crier URL | evidentiary |
| — | `token file installed, mode 600 (value not read)` (`bunker-provision.sh:233`) | `--check` credential row | **descriptive** — claims mode 600 while `:214` probes only `[ -s … ]` (F1-1) |
| — | `RESULT: FAIL` (`verify-node.sh:53`) | the `agent_alive` leg fails early (before the terminal `VERIFY:` forms) | evidentiary — an early-branch failure that exits 1, distinct from `VERIFY: FAIL (N)` (B24) |
| — | `VERIFY: PASS` / `VERIFY: FAIL (N)` / `VERIFY: UNVERIFIED — …` (`verify-node.sh:205-214`) | ladder exit | evidentiary |

## 10. Failure modes, indications and recovery

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Missing `lib.sh` | undefined `ok`/`have`/`bad`, shell aborts nonzero | a real check failure | restore `scripts/lib.sh` |
| Credential mode not verified | `--check` passes on file non-emptiness, claims "mode 600" | a real 0600 stat | stage `stat -c '%a'`; open defect F1-1 |
| Unknown explicit role | `FAIL disk-floor: unknown role …`, exit 2 (`disk_floor.py:123-125`, `:169-171`) | an absent role (which defaults to worker) | pass a valid role or drop the flag (F1-2) |
| Standalone create path skips auth gate | `node-create.sh` completes without `node_gateway_auth.py` | the provisioner path (which wires it) | route through `bunker-provision.sh --apply` (CF-192) |
| Unreachable port | exit 3 `UNVERIFIED`, not FAIL (`verify-node.sh:75-84`) | a failed port (exit != 0) | read the port row (CF-224) |
| `--destroy` without `--yes` | `refusing to destroy without --yes (would remove agent $AGENT on $SERVER)`, exit 2 (`:552`) | an authorised destroy | pass `--yes` and a non-empty `--agent` (`:553` also refuses an unset AGENT) |

## 11. Limits and margins

- The probe is staged via `bunker cp` then `bunker exec` (`bunker-provision.sh:225-226`), not
  inlined — an inlined heredoc shipped literal backslashes and reported a fully-provisioned node
  as empty.
- Every `bunker exec` call in the probe runs under `timeout 45`/`timeout 60` (`:187`, `:225-226`).
- **Certification ladder** (`verify-node.sh`, the full leg set round-2/round-3 omitted):
  - `:50-54` `agent_alive` — `bunker exec … echo ALIVE $(hostname)` must return `ALIVE*`; on
    failure `:53` prints `RESULT: FAIL` and exits 1 **before** any terminal `VERIFY:` form.
  - `:57-87` `gateway_reachable` — `/api/status` → 200, plus `auth_required:true` (`:70-74`);
    `000` from the control host with an in-node 200 is `UNVERIFIED`, not `FAIL` (`:75-84`).
  - `:90-103` `unauth_refused` — `/api/system/stats` must return 401/302/403, never 200.
  - `:104-115` `artifact_digest` — sha256 of the staged artifact compared node-vs-host, only when
    `--artifact` is given.
  - `:118-155` `checkout_freshness` — `node_freshness.py` measures branch/HEAD/ancestor/lag; default
    maps PASS→PASS, drift/dirty→FAIL, unmeasurable→WARN; `--strict-freshness` promotes
    unmeasurable→FAIL. **Asymmetry (B05):** the checkout unmeasurable case prints `warn` at `:150`
    **without calling `unverified()`**, so the gate can still finish `VERIFY: PASS` (exit 0) with an
    unmeasured checkout. The seed leg (below) does call `unverified()` at `:194-198`, which is why a
    seed WARN yields `VERIFY: UNVERIFIED` (exit 3) but a checkout WARN does not — a false-green path
    when freshness is an acceptance condition and `--strict-freshness` was not passed.
  - `:157-202` `seed_drift` — `node_seed_drift.py` re-runs the seeder's own check; PASS→PASS,
    drift→FAIL, unmeasurable→WARN **which sets UNVERIFIED, not PASS** (`unverified "seed_drift: …"`
    at `:194-198`, CF-291); `--strict-seed` promotes unmeasurable→FAIL.
  - `:205-214` precedence — FAIL wins over UNVERIFIED; UNVERIFIED (with the leg name) is distinct
    from FAIL ("nothing is broken and nothing is proven — CF-224"), exit 3 vs exit 1 vs exit 0.

## 12. Cross-references

- F2 PROVISIONING AND CERTIFICATION is the primary flow this module owns.
- M0 SHARED CONTRACT supplies `require_disk`/`have`/`bunker_exec`.
- M3 REPOSITORY owns the seeded clone this module creates.
- M5 HARNESS owns the harness the provisioner certifies.

## 13. Evidence of record

- Code read: `bunker-provision.sh:38-46, 95-123, 147, 175-249, 354-358, 424-495, 518-533, 550-611`,
  `disk_floor.py:36-40, 115-141`, `verify-node.sh:20-214`, `node_identity.py` (full),
  `node_seed.py:43-44, 114-164, 205-333, 373-394`; settings surfaces of `node_env.py`,
  `node_seed_drift.py`, `node_freshness.py`, `bunker_config_gen.py`.
- `docs/UNIT-MAP.yaml:26-77` (M1 S1–S5).
- Board rows: CF-192 (auth gate), CF-224 (unreachable = UNVERIFIED), CF-379 (zero-file seed).
- **Findings:**
  - **F1-1** (carried) — `bunker-provision.sh:181` resolves `bunker` via `have` (PATH); `:233`
    claims "mode 600" while `:214` tests only `[ -s … ]`.
  - **F1-2** — unknown explicit role raises `FloorError` (`disk_floor.py:123-125`, exit 2); only an
    absent role defaults to worker.
  - **F1-3** — floor precedence read and confirmed (`:115-141`).
  - **F1-4** (carried) — round-3 said `disk_floor.py` is "invoked by bunker-provision.sh"; measured,
    the caller is `project-node.sh:173`. `node_seed.py`'s caller is `bunker-provision.sh:454`.
  - **F1-5** (new, B05) — the checkout leg's unmeasurable→WARN does **not** set UNVERIFIED, so
    `VERIFY: PASS` is reachable with an unmeasured checkout; the seed leg does set it. Asymmetric
    false-green path.

## RED field count: 3 (Status §1 — `node_env`/`node_seed_drift`/`node_freshness`/`bunker_config_gen` bodies not read line-by-line; §7 certification ladder not run on a live node; Metrics §8 — absence-proved)
