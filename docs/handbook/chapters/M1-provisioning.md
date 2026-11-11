# M1 — PROVISIONING

## 1. Identity

| Field | Value |
|---|---|
| Module name | PROVISIONING |
| Path | `/home/kara/code-factory/scripts/` — `bunker-server-install.sh`, `disk_floor.py`, `bunker-provision.sh`, `bunker_config_gen.py`, `node-create.sh`, `bunker-crier-connect.sh`, `node_identity.py`, `node_gateway_auth.py`, `node_seed.py`, `node_seed_drift.py`, `node_env.py`, `verify-node.sh`, `node_freshness.py` |
| Revision | `fbc19cbc807de729e25c358fa7e94207b912f010` (code-factory HEAD; `scripts/verify-node.sh` changed in `47d68b4..08a2c8a` — commit `f1d5cfb`, CF-270 — so every §9/§10/§11 ladder locator is re-pinned against the 241-line file; `scripts/node-create.sh` changed in `08a2c8a..fbc19cb` — commit `85a7271`, CF-150 — staging `node_gateway_auth.py` as the eighth staged file, already reflected in §3 S3 and §11) |
| Language / runtime | bash 5.3.9 + Python 3.14.9 (measured) |
| Owner lane | code-factory (node-side) |
| Status | **UNVERIFIED (bodies)** — `bunker-provision.sh` `--check` probe, config loader (`:95-123`), CLI (`:561-609`), `destroy` (`:550-558`), `disk_floor.py` `resolve()` (`:115-141`), `verify-node.sh` (`:20-241`, 241 lines at HEAD — re-pinned after the CF-270 port fix), `node_identity.py` (111 lines, full), `node_seed.py` (405 lines, apply/build/check state machine) read; `node_env.py` (589), `node_seed_drift.py` (558), `node_freshness.py` (732), `bunker_config_gen.py` (724) read at their **settings surface** (argparse + constants), bodies not line-by-line; `node_gateway_auth.py` docstring read (B03 — it writes dashboard basic-auth, not a registration); body not line-by-line |

## 2. Purpose, authority and position

Turns a bare host into a node: identity, bus membership, a seeded repo. It decides whether a
host qualifies (disk floor), what identity and credentials a node carries, and what seed
(prompts, skills, env) it starts with. It may not decide what the node *runs* — that is M2/M5.
Provisioning without seeding produces a node that cannot work, which is why the two are one
module (`docs/UNIT-MAP.yaml:9`).

**What breaks if this module is absent.** A bare host never becomes a node: no identity, no bus
membership, no seeded repo, so the scheduler has nothing to dispatch to and every lane sits in
the inbox until it expires.

**What breaks if it lies.** The certification boundary is explicit: a printed `--apply` PASS is
not readiness, and a required leg that was not measured remains UNVERIFIED. The current
provisioner evidence is offline fixture evidence only; no live bunker certification is claimed.
The remaining known finding is that `verify-node.sh` can certify `VERIFY: PASS` when checkout
freshness is unmeasurable unless strict freshness is requested (B05; see §11).

**CF-214 control-host provisioner.** `scripts/bunker-provision.sh --config <file> --check` parses
the config as data, reports measured rows, and leaves no staged probe behind. `--apply` reuses an
existing agent, transfers one mode-600 credential bundle as a file, installs credentials under
`$HOME/.node/auth` at mode 600, deletes the bundle on both sides, stages the node identity and
plumbing, and delegates the bus proof. `--destroy` requires `--yes` and names the exact agent and
server before removal. Command-line values override the config for the documented target and
credential-file inputs.

`scripts/bunker-crier-connect.sh --check|--apply` measures the exact
`<crier>/agents/<agent>/inbox` route. It reports `CONNECTED` only for HTTP 200; 401, 403, 404 and
000 are named distinctly. If available, the node-side signed-read result is additional evidence,
not a replacement for the route measurement. `tests/selftest.sh` section 40 proves these behaviors
with network-free fixtures, including absent config, a shell line in config, missing bunker client,
destroy without `--yes`, command-line precedence, credential residue/leakage, and Crier status
classification. The fleet skill copy is outside this repository and is expected at
`~/.hermes/skills/coding-hermes/code-factory-bunker/SKILL.md`.

- `verify-node.sh` certifies `VERIFY: PASS` even when checkout freshness was **unmeasurable**
  (B05): the checkout leg prints WARN but does not set UNVERIFIED, unlike the seed leg (see §11).

## 3. Submodule inventory

| Submodule | Unit | Classification | Evidence (invoking line) |
|---|---|---|---|
| S1 qualify the host — disk floor | `disk_floor.py` | **active** | `disk_floor.py` is invoked by `project-node.sh:173` (`python3 "$HERE/disk_floor.py" … resolve …`), not by `bunker-provision.sh` (F1-4). `node_hygiene.py footprint` is invoked by `project-node.sh` layer 00 (the row that admits the measured node footprint against that floor) and `node_hygiene.py reap` by `bunker-server-install.sh` when `BUNKER_HOMES_DIR`/`BUNKER_KEYS_DIR` are named (CF-003) |
| S1 qualify the host — bunker server | `bunker-server-install.sh` | **operator-invoked (optional)** | no invoker — `grep -rn 'bunker-server-install' scripts/ tests/` matches only its own docstring and `tests/selftest.sh:1754`; a test arm is not a lane/cron/timer/unit (B7: the row previously classified both units **active** on `disk_floor.py`'s caller alone) |
| S2 create the container + config | `bunker-provision.sh`, `bunker_config_gen.py`, `node-create.sh`, `bunker-crier-connect.sh`, `deploy_key.py` | **operator-invoked** | `bunker-provision.sh` is the orchestrator (probe `:175-249`) but has **no in-repo invoker** — `grep -rn 'bunker-provision' scripts/` matches `bunker-provision.sh` itself (`:2,5,6,7,178,336,522`) and `bunker_config_gen.py` (`:2,4,337,492`, docstring/description text naming the config it generates); an operator runs it (finding 2). `deploy_key.py install` is invoked by `node-create.sh --deploy-key` inside the new agent (CF-003) |
| S3 identity and bus membership | `node_identity.py`, `node_gateway_auth.py` | **active** | `node_gateway_auth.py` staged and run inside `bunker-provision.sh:516-528`; `node_identity.py` at `:551-566` — step 7, **after** the `node-create.sh` → `project-node.sh` ladder in step 6, so its keys land last; `project-node.sh` layer 20 runs `node_gateway_auth.py` only, and an earlier reading that attributed the `node_identity.py` call to that layer is corrected here (CF-289 — the source carries no such call). Both writers of `$HOME/.node/node.json` now merge instead of replace; see the S3 merge contract below |
| S4 seed prompts/skills/env | `node_seed.py`, `node_seed_drift.py`, `node_env.py` | **active** | `node_seed.py build` at `bunker-provision.sh:454`; `node_env.py --check` at `:147` / `--apply` at `:426` |
| S5 prove the node works | `verify-node.sh`, `node_freshness.py` | **active** | `verify-node.sh` is the certification ladder (`:20-241`, 241 lines at HEAD); `node_freshness.py` folded in at `:150-177` |

**S2 staged set (CF-087).** `node-create.sh --staged-files` prints the manifest of files the node
receives, and that manifest is validated before an agent is spawned: a reference the runtime
follows but the set does not carry is a named `FAIL  staged_set — <file> references unstaged <ref>`,
not a node that dies on its first line. The validator reads every spelling of a `HERE` reference
(`$HERE/x`, `${HERE}/x`, and either quote style around it) in **every** staged member — the entry
point, `lib.sh`, the `.py` bodies, the selected adapter, `deploy_key.py` — not only
`project-node.sh` and `harness/install-$HARNESS.sh`: at 23114f4 the matcher was
`\$HERE/([a-zA-Z0-9_./$-]+)`, so `${HERE}/unstaged.py` passed (exit 0, full manifest) and a
reference appended to `lib.sh` was never read at all. Each reference is resolved the way the
referring script resolves it — a reference inside `harness/<file>` is relative to `scripts/harness/`
(`../lib.sh` → `lib.sh`), `$HARNESS` is the selected harness, a directory or a path that leaves
`scripts/` is not a member candidate — and the staged set is **derived**: the transitive closure of
those references from `project-node.sh` and `lib.sh`, plus the two members no reference reaches —
`deploy_key.py` (run by `--deploy-key`, which lives in `node-create.sh`) and
`harness/harness-vars.sh` (the harness contract every adapter sources, so a foreign adapter that
does not name it still gets it) — asserted equal to the declared manifest in both directions. A
member the entry point needs therefore cannot be missing
from the list, and a listed member nothing references cannot ride along. Verification:
`bash tests/node-create-staged-set.sh all` (arms `spellings`, `members`, `derive`; each mutates a
private copy of `scripts/` in a temporary directory and reads the mutated copy's `--staged-files`),
wired into `bash tests/selftest.sh` §16.

**S3 identity-file contract (CF-289).** `$HOME/.node/node.json` has two writers and one shape, and
**both merge** — neither may replace the document:

- `project-node.sh` layer 90 (`:998-1113`) owns `node_id`, `project`, `repo{origin,ref,path}`,
  `harness`, `bus.base`, `freshness`, `created_by` and `created_at`. It reads the document that is
  already there, sets only those keys, merges `bus` one level down (a sibling key an identity writer
  put under `bus` survives, and `bus.base` is the `CRIER_BASE`/`CRIER_URL` the create path exported
  rather than the documented placeholder), and writes the union back atomically at mode 600 — the
  same write discipline `node_identity.py` uses.
- `node_identity.py` (`set_path`/`main`, `:26-107`) owns the identity keys a provisioner supplies —
  `agent`, `namespace`, `duckbrain.namespaces[]`, `provisioned_by`, `provisioned_at` — and merges
  them into whatever layer 90 wrote.

The failure this fixes: the pre-CF-289 layer 90 dumped a fresh dict through `open(path, "w")`, so an
`--apply` after the identity step deleted every key it did not know about and still exited 0. The
fixture measures exactly that on the pre-fix script (exit 0, mode still 600, `agent`, `namespace`,
`duckbrain` and `provisioned_by` gone), and the keys are consumed, not decorative:
`node-bus-worker.py:420-431` takes the agent and the bus URL out of `node.json`. An existing document
that is not a readable JSON object is now a named `FAIL manifest — … is not a readable JSON object
(…); left untouched`, and the ladder does not rewrite it: it cannot tell which keys matter, so it
refuses instead of guessing.

**S4 seed state machine (B06).** `node_seed.py` is three commands:

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
seed leg will flag it as drift. The `--force` path **does** report the affected paths before
deleting: `node_seed.py:280-288` prints `changed <path>`, `removed <path>` and
`local-only <path> (removed by --force)` for every new/changed/removed/local-only file, then
`rmtree` at `:290`. An earlier citation that the `--force` path "deletes without reporting them as data loss" was **false** (B02): force is destructive and names the affected paths; whether that constitutes a sufficiently
explicit warning/confirmation is a separate question.

## 4. Dependencies

**4a. Runtime dependencies**

| Dependency | Version constraint | Where | How absence is detected |
|---|---|---|---|
| bash | >= 4 | node + control host | undefined `lib.sh` helper aborts |
| python3 | 3.x | node + control host | `command -v python3` empty → FAIL row |
| `bunker` CLI | resolved via `have bunker` (PATH order, `lib.sh:41-45`; `bunker-provision.sh:181`) — **not** an absolute path | control host | `bad "bunker_cli" "no bunker client on PATH"` (`:182`) |
| crier bus | reachable | `http://<crier-host>:8767` | `reach:` FAIL row / non-200 |

**Node bootstrap library (CF-298).** Before argument parsing or any provisioning layer,
`project-node.sh` initializes its own `FAILED` counter and checks that the adjacent `lib.sh`
is a readable regular file. If it is absent or unreadable, it prints `FAIL  lib.sh` with
its path and exits 1; a source failure is also a named refusal. This does not depend on
`set -u`. `bash tests/test_cf298_missing_lib.sh` exercises both nounset variants using
isolated script copies without the library; it does not certify a live node.

ch:trace row=CF-298 spec=docs/handbook/chapters/M1-provisioning.md test=tests/test_cf298_missing_lib.sh evidence=tests/test_cf298_missing_lib.sh witness=none:fixture-only verdict=none:pending commit=none:pending memory=none:pending

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
| `ROLE_DEFAULTS` | `{"worker": 5, "builder": 10, "full": 20}` GiB (`disk_floor.py:40`) | 1..4096 GiB (`MIN_GIB`/`MAX_GIB`) | admission floor per role | a value outside the range is refused (`:85-91`); role-table parity is gated by `tests/selftest.sh` section 65 |
| `DEFAULT_ROLE` | `"worker"` (`:41`) | one of the role keys | which floor applies when no role is named | an **unknown explicit role is refused**, not defaulted (F1-2; raise at `:123-125`) |

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
| `--budget` (build) | **16 MiB** (`DEFAULT_BUDGET`, `:44`, `:377`) | bytes | **aggregate uncompressed source-file byte ceiling** — `node_seed.py:130-140` sums `os.path.getsize(path)` per manifest file and compares the *total* against `args.budget` **before** the archive is created (`:147-150`); compression, tar headers and filesystem overhead are **not** bounded by this check (B05) | a larger budget admits a bloated seed; a budget under the raw source total is refused (`seed_budget` FAIL, return 1, `:135-140`) |
| `--force` (apply) | false (`:387-390`) | flag | wholesale replace of `prompts/`+`skills/` | true deletes node-local edits via `rmtree` (`:290`) after reporting each affected path (`:280-288`) — destructive, names what it removes |
| `--home` (apply/check) | `~` (`:383`, `:393`) | a path | the node `.hermes` root | a wrong home installs/checks the wrong tree |

**`bunker_config_gen.py` (S2, settings surface):**

| Setting | Default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| `--harness` | `hermes` (`:107`, `:515`) | a harness name | the node's default harness | a wrong default changes every generated node config |
| `--ref` | `main` (`:106`, `:516`) | a git ref | the seeded branch | a wrong ref seeds the wrong tree |
| `--ttl` | `6h` (`:108`, `:517`) | a Go duration | config TTL | a wrong TTL expires containers early |
| `--force` / `--check` | off / off (`:523-524`) | flags | rewrite-a-differing-config / read-only drift check | `--check` is read-only; `--force` rewrites a differing config |

**`node_env.py` (S4, settings surface — B07).** The env-file writer's controls:

| Setting | Default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| `--env-file` | none (required with `--config-set`) | a path | which declared profile is read | absent + no `--config-set` → `Refusal` "nothing declared" (`node_env.py:484-485`) |
| `--config-set` | none, **repeatable** (`:474-481`) | `KEY=VALUE` | additional overrides applied after the file | a malformed set is refused at parse (`:476`) |
| mode | **required** — `--check` or `--apply` (`:482-483`) | one of two | whether the run mutates | no mode → `Refusal` "one of --check or --apply is required" |
| `HOME` | required (`:491-494`) | env | where the paths resolve | unset → `Refusal` "HOME is unset" |
| target paths | `$HOME/.hermes/.env` + `$HOME/.hermes/config.yaml` (`:495-496`) | fixed | what is rewritten | a wrong HOME rewrites the wrong tree |
| unmanaged variables | carried forward (`:548-556`) | per-variable | variables present in the node's `.env` but not declared | each unmanaged var emits `WARN unmanaged:<name>` and `note "{n} unmanaged var(s) would carry forward on a re-provision"` — preserved, not dropped |

**`node_freshness.py` (S5, settings surface — B07).**

| Setting | Default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| `--path` | `repo` (`:677-682`) | a remote path (relative to agent home) | which checkout is measured | a wrong path measures a different tree |
| `--timeout` | **180 s** (`:684-689`) | int >= 1 | per-command bunker exec timeout | `< 1` is refused: `--timeout must be >= 1, got N` → `RESULT: FAIL (usage…)`, `EXIT_USAGE` (`:701-702`); the help notes the bunker exec stream dies at 300 |

**`node-create.sh` (S2, create path — CF-003):**

| Setting | Default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| `--deploy-key FILE` | none | an SSH private key, owner-only mode | injects the per-repo credential at spawn | a readable key is refused (`FAIL deploy_key — … mode 0644`) **before any agent is spawned**; unset means the node clones with whatever identity it has |
| `--gomodcache PATH` | none | an **absolute path on the node** | points the node at a sealed shared module cache | a relative path is refused (`FAIL gomodcache`); unset leaves a private cache and layer 10 prints the WARN |
| `--ref R` | `main` (or `NODE_REF`) | a git ref | the branch or tag cloned | unchanged by CF-003 |

**`deploy_key.py` (S2):**

| Setting | Default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| subcommand | — | `install` / `check` / `show` | mutating install / read-only proof / fingerprint listing | `check` never writes; `show` prints sha256 prefixes, never key material |
| key file mode | — | `0600` or `0400` accepted | who can read the key | `0644` is `FAIL key_mode` and **nothing is installed** |
| key body | — | a private OpenSSH/PEM header | accepted material | a public key (`ssh-*`, `ecdsa-*`) is `FAIL key_file` |
| remote form | — | `git@host:path` or `ssh://[user@]host[:port]/path` | what a deploy key can authenticate | HTTPS/local forms are `FAIL repo` naming why |
| `--replace` | off | flag | rotation of a key already registered for that repo | a different key without it is refused, so a rotation is never silent |

**`node_hygiene.py` (S1):**

| Setting | Default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| `footprint --working-room-mib` | **2048** (`WORKING_ROOM_MIB`) | MiB | headroom added to the measured components before admission | a shortfall is `FAIL footprint:room` naming the bytes short |
| `footprint --floor-gib` | none (measured only) | GiB | whether the total is admitted against the resolved floor | without it the layer notes the total is measured but not admitted |
| `footprint --modcache` | none → `not-declared` | path | whether the shared cache counts toward the footprint | an undeclared cache is named, never a silent zero |
| `reap --min-age-minutes` | **60** | minutes | grace before an orphan is removed | a younger entry is kept (an agent being created is not an orphan) |
| `reap --registry` | none — **required** | id list or `bunker list` output | which ids are live | absent/unreadable → `FAIL reap_registry`, nothing removed |

**Config-vs-CLI precedence (locator re-pinned).** `load_config` (`:96-123`) parses the file as data
(never sources it), then the CLI flags are re-applied on top — "the command line always wins"
(`:589`). Six flags were assigned during parsing and then overwritten by `load_config`, so they
are applied again after the config (`:604-609`) — a documented precedence bug fixed by re-ordering.
(The code's own comment at `:601` still says "five"; the re-apply block is **six** assignments:
`DUCKBRAIN_URL`, `GITHUB_TOKEN_FILE`, `DUCKBRAIN_TOKEN_FILE`, `CRIER_AGENT_KEY_FILE`,
`CRIER_AUTH_TOKEN_FILE`, `S3_ENV_FILE`.)

**Floor precedence (verified, F1-3).** `disk_floor.py:115-141` `resolve()` applies, in order:
`--disk-floor` (cli, `:127`) → `NODE_DISK_FLOOR` (env, `:129`) → `[disk]` config key
(`{role}_gib`, then `default`, `:130-140`) → `ROLE_DEFAULTS[role]` (`:141`).

### Disk floor

**Layer 40 build-cache boundary (CF-040).** Layer 40 establishes only the project-repository
clone and its checkout-freshness measurement. It does not create, seed, wire, or measure a build
cache for artifacts produced from that checkout. Build-cache bytes are therefore excluded from the
provisioning footprint and disk-floor budget; this is a documented no-cache boundary, not a
measurement of a zero-byte cache. The sealed Go **module** cache remains a separate layer-10
capability: its measured bytes are module-cache bytes and must not be described as a layer-40 build
cache. Any future build cache requires a separately measured implementation and acceptance row
before it may be named in the specification, handbook, footprint, or floor.

ch:trace row=CF-040 spec=docs/handbook/chapters/M1-provisioning.md#disk-floor wave=none:serial test=none:worker-doc-boundary doc=docs/handbook/chapters/M1-provisioning.md evidence=docs/handbook/chapters/M1-provisioning.md witness=none:documentation-boundary-only verdict=none:foreman-judge commit=none:worker-commit memory=none:foreman-closeout

## 6. Contracts in and out

Neither of M1's two edges is a canonical CT id (OUTLINE Part IV, CT-01..CT-18): node→crier
**registration** (POST `/agents`) and the `bunker` daemon are host-level operations, not
cross-system contracts with a peer chapter describing the same interface from the opposite end.
Both are listed below with local ids; the state is UNVERIFIED where the wire was not measured.

| ID | Peer | Direction | Producer `file:function` | Consumer `file:function` | State |
|---|---|---|---|---|---|
| M1-C1 | crier | out | **none in-repo** — `bunker-crier-connect.sh` stages `$HOME/.node/crier.json` and probes the inbox via `node-bus-worker.py --check` (`:13`, `:33`, `:53`, `:114-118`); it does **not** issue a registration request or write `auth/crier.token` (B06). **Neither `node_identity.py` (`:50-107`, merges/replaces local JSON) nor `node_gateway_auth.py` (`:70-162`, writes dashboard basic-auth + a password file) registers an agent** (B03): the actual key-generation/registration producer is not established in any code read | crier `internal/registry/handler.go:598` `HandleRegister` (POST `/agents`) and `:613` `HandleRegisterByID` (POST `/agents/{id}`) — an earlier citation listed only `HandleRegister` for the id-in-path route (B08) | **UNVERIFIED** — the token/registration exchange was not re-run, and the in-repo producer half is not established |
| M1-C2 | bunker daemon | out | `lib.sh:75` `bunker_exec` | **rumour — one side only** (the external `bunker` binary) | works (short create/exec/cp calls) |

## 7. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| shell parse | `for f in scripts/bunker-*.sh scripts/node-create.sh scripts/verify-node.sh scripts/bunker-crier-connect.sh scripts/install-node.sh; do bash -n "$f"; done` | exit 0 | 2026-11-07 | PASS |
| python compile | `python3 -m py_compile scripts/disk_floor.py scripts/node_identity.py scripts/node_gateway_auth.py scripts/node_seed.py scripts/node_seed_drift.py scripts/node_env.py scripts/node_freshness.py scripts/deploy_key.py scripts/gomodcache.py scripts/node_hygiene.py` | exit 0 | 2026-11-07 | PASS |
| disk floor unit | `python3 tests/test_disk_floor.py` | 12 tests pass | 2026-11-06 | **PASS** (rc 0) |
| credential / runtime / cache / footprint / reap battery | `python3 tests/test_node_provisioning.py` | 23 tests: 0644 key refused, HTTPS remote refused, public key refused, rotation gated, per-host config merge, node pin read back, wrong digest installs nothing, lying binary fails, sealed cache builds with `GOPROXY=off` and refuses to grow, footprint components exact, orphan reap spares live ids and symlinks | 2026-11-07 | **PASS** (rc 0; `MEASURED shared GOMODCACHE 2097910 bytes; sealed rebuild added 0 bytes`) |
| layer wiring (10/40/00) | `bash tests/selftest.sh` §58 | `PASS tool:node — $HOME/node-toolchain/current/bin/node (v22.22.3)`, `PASS repo_key` + `PASS repo_key:config`, a 0644 key → `FAIL repo_key` **and** `FAIL repo_clone — not attempted`, `PASS footprint` / `PASS footprint:floor` | 2026-11-07 | **PASS** (fixtures only) |
| **F2 legs (CREATED vs VERIFIED)** | `node-create.sh --project P --repo git@gitlab… --deploy-key K` then `verify-node.sh --agent A --server S` | the clone succeeds under the per-repo key, the repo's suite runs (node-dependent tests included), the sealed Go module cache adds 0 bytes, `VERIFY: PASS` | not run | **UNVERIFIED** — needs the real read-only deploy key and a fresh bunker node; this repo proves the mechanism, not the grant |
| gateway auth staged before the adapter | `bash tests/selftest.sh` §55 (`project-node.sh --apply --project <p> --layers 20` in a fixture home) | `PASS gateway_auth — dashboard.basic_auth present …; password in …/.node/auth/gateway.pass (mode 600, value not printed)` and the adapter's `PASS gateway_start — /api/status -> 200`; the same adapter still refuses without the block | 2026-11-07 | **PASS** (fixture only — no live node run) |
| verify-node transport (CF-224) | `bash tests/selftest.sh` §62 | the pre-fix `bf16c05` verifier has no `--transport` (`unknown arg`, exit 2) and certifies a loopback-only node `VERIFY: PASS`; this tree refuses the same fixture `VERIFY: UNVERIFIED`, PASSes `node-address`/`published-port`/`tunnel` runs with the transport named in the row, names a dead published port (`no published port for cf-fixture:10800`) without printing `000`, and grades `--transport bunker-exec` `VERIFY: FAIL (2)` | 2026-11-08 | **PASS** (offline fixtures only — no bunker, no network; `docs/audits/cf-224-verify-transport-2026-11-08.md`) |
| verify-node usage (CF-063) | `bash -n scripts/verify-node.sh`; `bash tests/selftest.sh` CF-063 arm | `scripts/verify-node.sh` parses `-h`/`--help` before environment, port, transport and bunker validation; bare invocation and `--help` print the usage line and exit 2, while an operational invocation without `BUNKER_SERVER` names that missing requirement | 2026-11-10 | **PASS** (offline fixture only; no live bunker contacted) |
| staged-set validator (CF-087) | `bash tests/node-create-staged-set.sh all` | four spellings of one unstaged reference in the entry point, one arm per staged member (`lib.sh`, `disk_floor.py`, `install-node.sh`), a needed member dropped from the declared set and an unreferenced member added both exit nonzero with a named `staged_set` row, and the printed set is closed under every reference its own members carry: `STAGED_SET: PASS` | 2026-11-09 | **PASS** (offline probe, 1.1 s; the pre-fix `node-create.sh` from 23114f4 scores `STAGED_SET: FAIL (5)`) |
| spawn/staging failure diagnostics (CF-056) | `bash tests/selftest.sh` §16 (`tests/selftest.sh::cf056-spawn-staging-failure`) | a staging failure names the failed artifact and emits no later `PASS provision`; a spawn failure names a unique per-run log containing the agent id and its final diagnostic | 2026-11-10 | **PASS** (offline fixture only — no live bunker evidence) |
| identity-file union (CF-289) | `bash tests/selftest.sh` §47 — the `CF-289-node-json-union` arms; preconditions `bash -n scripts/project-node.sh`, `python3 -m py_compile scripts/node_identity.py` | `PASS CF-289-node-json-union — identity-then-apply leaves agent/namespace/duckbrain/provisioned_by AND the ladder's keys (mode 600, exit 0)` plus the red control `PASS pre-fix 23114f4 exits 0 while deleting agent/namespace/duckbrain/provisioned_by — this arm discriminates` | 2026-11-09 | **PASS** (offline fixture only — the identity step and the ladder both run on a fixture home; no live node run) |
| certification ladder | `scripts/verify-node.sh --agent <id> --server <host>` on a live node | per-leg observation | not run | **UNVERIFIED** (needs a live node; legs documented in §11) |

## 8. Metrics

**RED — none (absence-proved).** No provisioner script exports counters, gauges or
histograms — `grep -nE 'prometheus|Counter|Gauge|Histogram|/metrics' scripts/bunker-provision.sh
scripts/disk_floor.py scripts/verify-node.sh scripts/node_*.py scripts/bunker_config_gen.py
scripts/node-create.sh scripts/bunker-crier-connect.sh scripts/bunker-server-install.sh` → 0 matches.
Provisioning rate, refusal rate and per-leg latency are answerable only by reading the log.

## 9. Log lines (verbatim)

**Scope (B09, measured).** `grep -cE '\b(ok|bad|warn|note|say)\s+"' scripts/bunker-provision.sh scripts/verify-node.sh` = **108 + 33** helper call sites. The 5 rows below are the evidentiary refusal/lie-case rows (F1-1, CF-224); the generic per-row helper surface is not inventoried one-per-site — the uncovered count is a named RED on this field.

| Level | Line | Emitted when | Kind |
|---|---|---|---|
| — | `  PASS  %s — %s` / `  FAIL  %s — %s` (`lib.sh:6-7`) | every provisioner row | descriptive (see M0 F0-4) |
| — | `  FAIL  reach:%s — %s` | an unreachable crier URL | evidentiary |
| — | `installed under \$HOME/.node/auth at mode 600: <file>=600` (`bunker-provision.sh:417`) | `--apply` credential row | evidentiary — the node reports each installed file mode; any non-600 mode is a FAIL (CF-214) |
| — | `RESULT: FAIL` (`verify-node.sh:76`) | the `agent_alive` leg fails early (before the terminal `VERIFY:` forms) | evidentiary — an early-branch failure that exits 1, distinct from `VERIFY: FAIL (N)` (B24) |
| — | `VERIFY: PASS` / `VERIFY: FAIL (N)` / `VERIFY: UNVERIFIED — …` (`verify-node.sh:233-241`) | ladder exit | evidentiary |

## 10. Failure modes, indications and recovery

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Missing `lib.sh` | undefined `ok`/`have`/`bad`, shell aborts nonzero | a real check failure | restore `scripts/lib.sh` |
| Credential mode mismatch or bundle residue | `FAIL auth — installed but not mode 600: <file>=<mode>` or `FAIL auth_bundle — could not delete …` | a measured 0600 install with both copies deleted | fix the node permissions or cleanup path; re-run `--apply` (CF-214) |
| Unknown explicit role | `FAIL disk-floor: unknown role …`, exit 2 (`disk_floor.py:123-125`, `:169-171`) | an absent role (which defaults to worker) | pass a valid role or drop the flag (F1-2) |
| Gateway auth block absent at layer 20 | `FAIL gateway_start — refused: a public bind needs dashboard.basic_auth in ~/.hermes/config.yaml — block absent` from the adapter | a staged block — `project-node.sh` layer 20 runs `node_gateway_auth.py` before the adapter and prints `PASS gateway_auth — dashboard.basic_auth present …` (CF-150) | re-run `project-node.sh --apply`; a `dashboard` block that carries no **direct-child** `basic_auth:` stays a counted FAIL (producer exit 2, file left byte-identical) and needs a human. The structural rule (CF-292, tightened in round 2) is the indentation the consumer gate parses: the block is the run of indented, blank and comment lines after `dashboard:`, ending at the first column-0 key, and `basic_auth:` counts only at the block's **child indent** — so a `basic_auth:` under a sibling top-level key is *not* protection (it used to be certified by an eight-line window), a `basic_auth:` under one of dashboard's own child keys (`dashboard.child.basic_auth`) is *not* protection either (the first CF-292 fix still accepted any indented line), and a direct one passes however deep it sits (permanently pinned by `tests/test_node_gateway_auth.py`) |
| Unreachable port, or no transport to it | exit 3 `VERIFY: UNVERIFIED` naming the transport it could not use — `no published port for cf-node:10800`, `no tunnel endpoint …`, `no route from this host to …` (`verify-node.sh:217-228`) | a measured **non-200** through a working transport (FAIL, `:229`), and a probe that never left the node (`--transport bunker-exec`, a counted FAIL at `:198-201`) | read the `transport` row and declare a path the control host can take: `--transport published-port` or `--transport tunnel`, each with `--transport-address HOST:PORT` (CF-224) |
| `--destroy` without `--yes` | `refusing to destroy without --yes (would remove agent $AGENT on $SERVER)`, exit 2 (`:552`) | an authorised destroy | pass `--yes` and a non-empty `--agent` (`:553` also refuses an unset AGENT) |
| Deploy key readable by group/other | `FAIL repo_key — … mode 0644 — group/other can read it (chmod 600)` and, with no clone yet, `FAIL repo_clone — not attempted — the declared deploy key is unusable (see repo_key)` | a working key (`PASS repo_key — … mode 600`) | `chmod 600` the key and re-run; `node-create.sh --deploy-key` refuses it before spawning anything |
| Shared module cache writable or drifted | `FAIL modcache_seal — N writable path(s)` / `FAIL modcache_manifest — ±N bytes since seal` | a sealed cache (`PASS modcache_seal — … read-only (no write bits, owner included)`) | `gomodcache.py seal` on the prewarm host; a node must never write the shared cache |
| Footprint above the floor or the working room | `FAIL footprint:room — X required (Y + 2048 MiB working room) > Z free — short S` / `FAIL footprint:floor — … exceeds the N GiB floor` | a footprint with headroom (`PASS footprint:room — … headroom …`) | reap (`node_hygiene.py reap`, `reclaim_disk.py run`) or move the node; admission refuses before the host fills |
| `node.json` present but not a JSON object | `FAIL manifest — <path> is not a readable JSON object (…); left untouched` and `NODE: FAIL (1)` | a first run with no file at all (layer 90 writes a fresh document) | inspect or restore the file; the ladder refuses rather than replacing a document whose keys it cannot read (CF-289) |
| Orphan homes/keys on the server | `FAIL orphans — N orphan(s) would be reaped (… live kept, … inside grace): <paths>` (check), `PASS orphans — reaped N …` (apply) | `PASS orphans — none — … live entries kept` | `bunker-server-install.sh --reap-orphans` with `BUNKER_HOMES_DIR`/`BUNKER_KEYS_DIR` named |

## 11. Limits and margins

- The probe is staged via `bunker cp` then `bunker exec` (`bunker-provision.sh:225-226`), not
  inlined — an inlined heredoc shipped literal backslashes and reported a fully-provisioned node
  as empty.
- Every `bunker exec` call in the probe runs under `timeout 45`/`timeout 60` (`:187`, `:225-226`).
- **Layer 20 stages the block its adapter gates on (CF-150), in this order.** `project-node.sh`
  creates `$HOME/.node/auth` mode 700, runs
  `python3 "$HERE/node_gateway_auth.py" "$HOME/.hermes/config.yaml" "$HOME/.node/auth/gateway.pass"`
  — the password is generated on the node, written at mode 600, never printed and never in argv —
  and only then invokes `harness/install-$HARNESS.sh --apply`, whose `gateway_start` row is the
  gate. An existing **direct-child** `basic_auth` block is left untouched (a re-run changes nothing); a
  `dashboard` block that carries no direct-child `basic_auth:` is a counted FAIL row and is not
  overwritten — the producer reads the block structurally (the run of indented, blank and comment lines
  after `dashboard:`, ending at the first column-0 key) and accepts `basic_auth:` only at the block's
  child indent, so a `basic_auth:` belonging to a sibling top-level key does not pass, nor does one under
  a child key of `dashboard` (`dashboard.child.basic_auth`, which the adapter's parse reads at depth 1
  and refuses), while a direct one passes however deep it sits (CF-292, round 2;
  `tests/test_node_gateway_auth.py`).
  `--check` reports the block read-only (`project-node.sh:587-601`) and FAILs when it is absent, naming
  the refused bind — but with a **looser shell rule** than the producer: it accepts any indented
  `basic_auth:` inside the `dashboard:` run, so it prints `ok gateway_auth` for the child-key shape
  (`dashboard.child.basic_auth`) that the producer now refuses and the adapter refuses. That row is
  labelled "presence only — the adapter's gate is the authority", so nothing is authorised by it, but it
  is the same over-claim class CF-292 is closing and it is filed as a finding rather than fixed here
  (`scripts/project-node.sh` is outside this change's fence).
- **Certification ladder** (`verify-node.sh`, **504 lines** at this tree — the CF-224 transport legs inserted the transport validation and the named-transport rows below step 1 and shifted every prior locator; the earlier `241 lines` pin was `08a2c8a` after the CF-270 `--port` fix, and all locators are re-pinned here):
  - `:53-68` **port validation (CF-270)** — `--port` is validated **before any use**: a digit test (`:53-56`, `case "$PORT" in ''|*[!0-9]*)`), a 5-digit length cap (`:59`, `[ "${#PORT}" -le 5 ]`), then two `verify-node: --port must be digits 1-65535 (got: …)` → exit 2 refusals (`:60-63`; and `:65-68`), with a base-10 re-expansion `PORT=$((10#$PORT))` at `:64` between them. A non-digit `--port` is refused here and no longer interpolates into the remote `bash -lc` shell.
  - `:73-121` **transport validation (NEW legs, CF-224)** — `--transport` is one of `node-address` (default), `published-port`, `tunnel`, `bunker-exec` (`:75-81`, anything else prints the accepted set and exits 2); `published-port`/`tunnel` **require** `--transport-address HOST:PORT` (`:84-88`), split into `T_HOST`/`T_PORT` (`:89-93`), and the port carries the same digit/1-65535 rule as `--port` (`:100-115`); an address with a transport that does not use one is refused (`:117-120`). `NODE_TRANSPORT`/`NODE_TRANSPORT_ADDRESS` (read at `:30-31`) are the spawn-path form; flags win.
  - `:135-141` `agent_alive` — `bunker exec … echo ALIVE $(hostname)` must return `ALIVE*`; on
    failure `:140` prints `RESULT: FAIL` and exits 1 **before** any terminal `VERIFY:` form.
  - `:163-192` **transport rows (NEW leg, CF-224)** — the transport in force is printed as its own
    `PASS transport — <name> <host>:<port> …` row before the probe, so a run cannot be read as a LAN
    check when it was not one: `node-address` prints the `hostname -I` address (`:180-182`) and
    **refuses** a loopback one (`:173-178` — a probe to `127.0.0.1` from here measures the control
    host), the two declared transports print their endpoint from the flags (`:185-188`), and
    `bunker-exec` states up front that the probe will not leave the node (`:189-190`).
  - `:194-237` `gateway_reachable` — the probe always runs on the control host, in this shell's own
    process tree. `--transport bunker-exec` is a counted **FAIL** naming the loopback code it
    measured (`:198-201`), never a PASS. A 200 prints `$url -> 200 (transport: <name>)` plus the
    `auth_required:true` gate (`:209-212`); `000` from a working transport is a named WARN that also
    sets UNVERIFIED — `no published port for cf-node:10800`, `no tunnel endpoint …`, `no route from
    this host to …` (`:217-228`) — and a **non-200** answer stays a FAIL (`:229`). No row prints a
    bare `000` any more (CF-224 criterion 4).
  - `:239-266` `unauth_refused` — `/api/system/stats` must return 401/302/403, never 200; a `000`
    with no transport is a WARN that sets UNVERIFIED and names the transport (`:247-259`).
  - `:267-279` `artifact_digest` — sha256 of the staged artifact compared node-vs-host, only when
    `--artifact` is given.
  - `:280-318` `checkout_freshness` — `node_freshness.py` measures branch/HEAD/ancestor/lag; default
    maps PASS→PASS, drift/dirty→FAIL, unmeasurable→WARN; `--strict-freshness` promotes
    unmeasurable→FAIL. **Asymmetry (B05):** the checkout unmeasurable case prints `warn` at `:312`
    **without calling `unverified()`**, so the gate can still finish `VERIFY: PASS` (exit 0) with an
    unmeasured checkout. The seed leg (below) does call `unverified()`, which is why a
    seed WARN yields `VERIFY: UNVERIFIED` (exit 3) but a checkout WARN does not — a false-green path
    when freshness is an acceptance condition and `--strict-freshness` was not passed.
  - `:319-387` `seed_drift` — `node_seed_drift.py` re-runs the seeder's own check; PASS→PASS,
    drift→FAIL, unmeasurable→WARN **which sets UNVERIFIED, not PASS** (`unverified "seed_drift: …"`
    at `:381`, CF-291); `--strict-seed` promotes unmeasurable→FAIL.
  - `:388-494` `harness_identity` — the manifest's harness name/version re-measured on the node
    (CF-006); an unmeasured version is WARN + UNVERIFIED.
  - `:495-504` precedence — `VERIFY: FAIL (N)` at `:496` (exit 1), `VERIFY: UNVERIFIED — …` at
    `:500` (exit 3), `VERIFY: PASS` at `:504` (exit 0). FAIL wins over UNVERIFIED; UNVERIFIED (with
    the leg name) is distinct from FAIL ("nothing is broken and nothing is proven — CF-224").

## 12. Cross-references

- F2 PROVISIONING AND CERTIFICATION is the primary flow this module owns. The CF-003 legs sit on
  it: the per-repo deploy key is a **precondition** of the repo leg (layer 40), the Node runtime and
  the sealed module cache are **provisioning** of layer 10, and the footprint row is the **admission**
  half of layer 00. CREATED still means `node-create.sh` returned `NODE CREATED`; VERIFIED still means
  `verify-node.sh` returned `VERIFY: PASS` — the new legs do not blur that line, and a fixture run
  (§58) is explicitly not a certification.
- M0 SHARED CONTRACT supplies `require_disk`/`have`/`bunker_exec`.
- M3 REPOSITORY owns the seeded clone this module creates.
- M5 HARNESS owns the harness the provisioner certifies.

## 13. Evidence of record

- Code read: `bunker-provision.sh:38-46, 95-123, 147, 175-249, 354-358, 424-495, 518-533, 550-611`,
  `disk_floor.py:40-44, 136-167`, `verify-node.sh:20-241`, `node_identity.py` (full),
  `node_seed.py:43-44, 114-164, 205-333, 373-394`; settings surfaces of `node_env.py`,
  `node_seed_drift.py`, `node_freshness.py`, `bunker_config_gen.py`.
- **CF-003 slice, read and re-measured 2026-11-07:** `scripts/deploy_key.py` (whole file),
  `scripts/install-node.sh` (whole file), `scripts/gomodcache.py` (whole file),
  `scripts/node_hygiene.py` (whole file), `scripts/node-create.sh` (staged set `:31-40`, key
  preflight `:95-113`, injection `:160-185`, provision env `:190`), `scripts/project-node.sh`
  (layer 00 footprint `:242-260`, layer 10 node `:390-424`, layer 10 `go:modcache` `:488-505`,
  layer 40 `repo_key` `:853-889`, `core.sshCommand` `:916-925`), `scripts/bunker-server-install.sh`
  (`:60-89`), `tests/test_node_provisioning.py`, `tests/selftest.sh` §58.
- `docs/UNIT-MAP.yaml:26-77` (M1 S1–S5).
- **CF-289 slice, read and re-measured 2026-11-09:** `scripts/project-node.sh` layer 90
  (`:998-1113`, whole block), `scripts/node_identity.py` (whole file), `scripts/bunker-provision.sh`
  (`:547-568`, the identity step and its ordering after step 6), `scripts/node-bus-worker.py`
  (`:411-431`, the `node.json` consumers), `tests/selftest.sh` §47 (`CF-289-node-json-union` arms).
  The pre-fix control is the same fixture run against `git show 23114f4:scripts/project-node.sh`,
  which exits 0 and leaves `mode 600` while dropping every identity key — measured on a fixture
  home, never on a live node.
- Board rows: CF-192 (auth gate), CF-224 (unreachable = UNVERIFIED), CF-379 (zero-file seed),
  **CF-003** (deploy key + node runtime + shared module cache + footprint + orphan reap).
- **Findings:**
  - **F1-6** (new, CF-003) — the layer-40 error text already said
    `repository access failed; private repos need a deploy key`, but **no stage injected one**:
    `node-create.sh` staged eight files and copied no credential, and the control host only reached
    the private GitLab through an `insteadOf` rewrite. The message named a remedy the system did not
    implement. `--deploy-key` + `deploy_key.py` close the mechanism; the live clone remains
    UNVERIFIED in this repo.
  - **F1-7** (new, CF-003) — layer 10 graded `have node`, an ambient PATH binary, and never
    provisioned a runtime, so a node could print `PASS tool:node` for a binary it did not own (and a
    fresh node with no `node` failed 11 Go tests that shell out to it). `install-node.sh` +
    owned-path precedence fix both halves; the spec said `node: node --version read back` and was
    silent about provisioning, now stated.
  - **F1-8** (new, CF-003) — `specs/NODE.md` counted **656 MB of module cache per node** with no
    mechanism behind the number. `gomodcache.py` makes it shared and sealed, and the fixture measures
    the property: 2,097,910 bytes seeded once, **0 bytes added** by a sealed rebuild with
    `GOPROXY=off`.
  - **F1-1** (resolved by CF-214) — the provisioner now measures the node-reported mode for
    each installed auth file, fails on a non-600 result, and proves the staged bundle is deleted;
    the offline fixture covers both red arms. No live node was used for this result.
  - **F1-9** (CF-214 boundary) — the fleet skill copy is installed outside this repository; this
    chapter and the repo skill name the same commands, while the selftest treats an absent fleet
    copy as a note on clean hosts.
  - **F1-2** — unknown explicit role raises `FloorError` (`disk_floor.py:123-125`, exit 2); only an
    absent role defaults to worker.
  - **F1-3** — floor precedence read and confirmed (`:115-141`).
  - **F1-4** (carried) — an earlier citation said `disk_floor.py` is "invoked by bunker-provision.sh"; measured,
    the caller is `project-node.sh:173`. `node_seed.py`'s caller is `bunker-provision.sh:454`.
  - **F1-5** (new, B05) — the checkout leg's unmeasurable→WARN does **not** set UNVERIFIED, so
    `VERIFY: PASS` is reachable with an unmeasured checkout; the seed leg does set it. Asymmetric
    false-green path.

## 14. Wave-2 redline — review requirements (target behavior vs implementation coverage)

Per the CF2A-01 review handoff (§1.7, §2): **approved target behavior governs this chapter**; the
source locators, grep counts and test ladders in §§1–13 are implementation coverage evidence, not
authority. The normative provisioning specification — required behavior and its stable contracts —
must let a reader build the intended system independently of the current script layout
(handoff §1.7; review notes M1, user-directed change 1). Resolved architecture applied throughout:
the project foreman runs inside its Bunker; Crier is the launch/return boundary; the scheduler on
the control host records the returned response (handoff §1.1); DuckBrain is installed/integrated in
**every** Bunker and must expose the same logical project-memory data/view as the controller
(handoff §1.2); Terminal Jail is optional, **disabled by default**, and Bunker supplies baseline
protection independently of it (handoff §1.3–§1.4); Hermes is the fixed MVP harness with the exact
Hermes/Oh My Hermes build pinned, and Task Router is future/non-MVP, placed after Node and before
Harness (handoff §1.5).

**R1 — Two separate onboarding flows, each with caller and next consumer (required).**

*Flow A — new-host/Bunker onboarding* (creates a schedulable node):

| # | Step | Caller / location | Next consumer | Failure behavior |
|---|---|---|---|---|
| A1 | Admission: disk floor + footprint vs role floor | operator/orchestrator, control host (`disk_floor.py` via `project-node.sh` layer 00) | all later steps | refuse before the host fills; nothing created |
| A2 | Bunker server prep (homes/keys, orphan reap) | operator, control host (`bunker-server-install.sh`) | A3 | server-level refusal, nothing spawned |
| A3 | Agent create + per-Bunker config generate/readback | operator via `bunker-provision.sh --apply` / `node-create.sh` | A4 | partial artifacts named; destroy/retry contract below |
| A4 | Credentials issued and installed — all five classes (R4) | control host + node, per class issuer | A5–A9 | a class that fails to install blocks its dependent legs only |
| A5 | Bus membership: Crier identity + registration/token exchange, verified signed read | **producer currently unestablished — a named spec gap**; consumer `bunker-crier-connect.sh` staging + inbox probe | M2 dispatch | an unverified bus membership is not schedulable |
| A6 | Repo + **embedded board** checkout (the board ships inside the project repo, M4) | provisioner (M1 owns the checkout; M3 manages it afterwards) | M3/M4 | seed drift gates readiness |
| A7 | Harness install: **exact Hermes/Oh My Hermes build pin** + tools/settings | provisioner via M5 installers | M5 lifecycle | version readback required, not name-only |
| A8 | Inference access: node-scoped proxy credential + endpoint/model policy + **end-to-end inference proof** | M1 provisions; M12 owns the proxy credential chain | M5 run path | config-present-without-a-successful-request is not readiness |
| A9 | DuckBrain integration in the Bunker, same logical memory view as controller | provisioner + memory sync owner | M1–M12 memory projections | local Git-backed namespace is durable during HTTP outage; pending-sync, conflict and freshness states are read back; unsupported multi-host topology is refused |
| A10 | Readiness: certification ladder **plus effective-behavior validation** (R5); machine-readable readiness report | `verify-node.sh` | **M9 admission** — only a verified node is schedulable | CREATED ≠ CONFIGURED ≠ CONNECTED ≠ VERIFIED |

*Flow B — new-project onboarding* (introduces an application/repo to the factory): caller is the
operator on the control host; steps: scheduler project/lane row creation (`clone_lane.py` copies a
**scheduler row** with `enabled=0` — it is scheduler configuration, not a git operation, F3-2) →
actual repository checkout as a separate provisioning action (Flow A's repo leg / M1) → per-project
board init in the project repo (M4 `boardctl init`) → per-project hook/gate policy (M3
`install-gitreins.sh` + project `.gitleaks.toml`) → forge identity/credential mapping (M7). Next
consumer: **M9 admission** reads the board; **M2 dispatch** when the lanes activate. Both flows
must state who triggers each step, which component runs it, and the success/failure transitions —
an abbreviated wildcard config surface does not satisfy the contract (review notes M1, observations).

**R2 — Stable request, artifact, readiness and partial-failure contracts (required).** Request:
the complete supported config/CLI/environment interface with validation, defaults and precedence
(CLI > config file > role defaults — the documented precedence, §5), and a minimal full example
for a fresh node. Artifacts: stable schemas and postconditions — node identity, repository
location/ref, credential ownership/permissions, bus identity/token state, seed manifest/digest/
applied record, and a machine-readable readiness report with an explicit required-check list and
an unavailable-result policy. Partial failure: how failures propagate, what partial artifacts
remain, what is safely retryable (idempotent re-run vs forced reseed), what cleanup/teardown
destroys, and what evidence is required before the node becomes schedulable. Who records
successful/failed provisioning, writes durable memory and closes any board item must be assigned
to an owning orchestrator via a result/evidence contract — not invented as direct module writes
(review notes M1, change 10 and observation).

**R3 — Full Bunker provisioning list (required).** Provisioning must cover, as one normative
list: compatible Bunker CLI/daemon/profile/capabilities; the chosen execution context
(host-user / fresh image-backed / persistent container / detached unit — matched versions and
effective capabilities, not assumed containment); the **exact pinned Hermes/Oh My Hermes build**;
tools and settings; the project repo **with its embedded board**; the Crier identity; authenticated
inference access; and DuckBrain on every Bunker (review notes M1 + handoff §1.2, §3-M1). The
harness installation chain connects to M5 through a precise integration contract; Task Router is
future and outside this list.

**R4 — Distinct credential classes (required).** Five classes with separate producers, scopes,
delivery, renewal and revocation, never interchangeable: (1) forge/GitHub (app installation,
scoped tokens, deploy keys — clone/fetch vs push vs merge permissions documented separately; a
read-only deploy-key proof does not establish publication capability); (2) Crier bus
(key generation, registration, token exchange — producer to be named); (3) Bunker-control;
(4) proxy/model access (node-scoped, preserving the control-host provider-secret boundary —
provider keys are **not** copied to workers); (5) memory/DuckBrain. Each needs issuer, secure
installation, expiry, renewal, revocation and error reporting (review notes M1, changes 4/8;
handoff §3-M1).

**R5 — Deployment-specific safe defaults, per-Bunker configuration with readback, and
effective-behavior validation before readiness (required).** No universal Bunker execution mode is
selected (handoff §1.8): the chapter must publish safe defaults/guidelines per deployment profile
and support per-Bunker Factory configuration with setup **and readback** (a written config is not
a read-back config). Before a node is declared ready, provisioning must validate **effective**
host/isolation/resource/network/storage settings and real cross-host memory, inference and repo
use — install success alone is insufficient (handoff §3-M1). This subsumes the snapshot's measured
false-green paths (F1-1 credential-mode claim, F1-5 unmeasurable-checkout PASS): the target
behavior is that no readiness verdict may rest on an unverified or unmeasured leg.

**R6 — Provisioning metrics (required).** Attempts/outcomes, stage failures and refusals by
reason, readiness results and useful step durations — each with meaning/type/unit, bounded
dimensions, an identified emitter and readout (review notes M1, change 11). §8's absence-proved
RED is current coverage only.

## 15. Normative provisioning, enrollment and readiness contract (P3-12, P3-15, P3-23)

The qualified MVP profile is a user-space, image-backed Bunker with a persistent mounted node home. The profile supports a pinned Hermes/Oh My Hermes build, a project checkout containing the embedded board, Crier membership, node-scoped proxy access and local Git-backed DuckBrain. Kubernetes, Compose, homelab and standalone modes are not universal guarantees; each is unsupported unless it supplies the same readback and conformance rows.

| Stage | Durable input and output | Required refusal / recovery |
|---|---|---|
| admission | declared profile, role, disk floor, footprint; `profile_id` and `generation` | unknown profile, insufficient measured headroom or unreadable host state refuses before spawn |
| create | `node_id`, `project_id`, repository identity `{forge, host, owner, repo, ref}` and credential references, never credentials in the identity | duplicate `(project_id,node_id,generation)` is idempotent; conflicting generation is a compare-and-swap refusal |
| enrollment | controller principal, Bunker principal, trust key/certificate fingerprint, Crier registration id and endpoint | missing trust, wrong project scope, expired identity or failed signed read leaves the node `ENROLLMENT_FAILED` and unschedulable |
| provision | pinned artifacts and per-class credential references; seed manifest and digest | each artifact is digest-checked; partial installation records completed stages and retries only idempotent stages |
| readiness | effective readback for profile, repo, Crier, harness, proxy inference and memory; machine-readable report | any unavailable or unmeasured required leg is `UNVERIFIED`, never READY; readiness is not inferred from file presence |
| replace/remove | old generation fenced, new generation read back, revocations retained | replacement cannot inherit revoked credentials; removal preserves audit evidence and destroys only owned state |

Five credential classes remain separate: forge, Crier bus, Bunker control, inference proxy and DuckBrain memory. Each class has an issuer, scope, mode-600 file reference, expiry metadata, renewal owner, revocation operation and readback result. The controller never copies a provider key into a Bunker. `agent:self` does not grant daemon administration; every operation is checked against `(principal, project_id, bunker_id, resource, generation)` at the resource boundary.

The normative state sequence is `DECLARED → ADMITTED → CREATED → ENROLLED → PROVISIONED → CONNECTED → VERIFIED`, with `DEGRADED`, `REPLACEMENT_REQUIRED` and `REMOVED` terminal or recovery states. Only `VERIFIED` may be admitted by M9. The readiness report carries `report_version`, `node_id`, `project_id`, `generation`, per-check status and observation timestamp. A controller restart reloads the last durable state and resumes by generation; a Bunker loss fences the old identity before replacement. Acceptance cases cover an invalid credential mode, a stale certificate, a private repository with the wrong credential, an unavailable memory service with local persistence intact, and a successful restart with all identities unchanged.

The target metrics are stage attempts, refusal reasons, artifact digest failures, enrollment/readiness outcomes, effective-generation lag and step duration, with `project_id`, `profile_id` and `generation` as bounded labels. The manager owns collection and readout; a printed PASS row is not readiness evidence.

## RED field count: 4 (Status §1 — `node_env`/`node_seed_drift`/`node_freshness`/`bunker_config_gen` bodies not read line-by-line; §7 certification ladder not run on a live node; Metrics §8 — absence-proved; §9 inventory 5 of 141 helper call sites — the descriptive rows not tabulated one-per-site)

## FLIGHT DATA FILE - M1 PROVISIONING

```checklist
TITLE: M1 PROVISIONING
WHO: CONTROL HOST
CHECK - ./scripts/bunker-provision.sh --config <conf> --check
√ ROWS - node/agent/repo/auth rows PASS; a lone FAIL inputs is a replay gap, not a node defect
APPLY - ./scripts/bunker-provision.sh --apply
√ RESOLVED - one resolved line names project, agent, server, repo, ref, harness, namespace, TTL
BUS - bunker-crier-connect.sh --stage, then --apply, then re-probe the inbox
√ 200 - signed read accepted, queue depth printed
ROSTER - read fleet_agents.json and fleet-repo-scope.json
√ MEMBER - the agent is in both stores before any dispatch
```

## 16. Pass-4 qualified deployment profile (P4-DEPLOY-01)

The supported profile is `bunker.user-image.v1`, a capability-qualified, rootless
execution profile. It is not a universal Bunker mode. The profile manifest is the
source of truth and is immutable for one provisioning generation:

| Field | Required value or rule |
|---|---|
| `profile_id` | `bunker.user-image.v1` |
| `artifact` | an OCI image or equivalent user-space archive named by digest, plus the Hermes artifact URL, version `0.19.0`, and SHA-256; a tag or version without a digest is refused |
| `host` | Linux user namespace, `uidmap`, `fuse-overlayfs`, `slirp4netns`, `git`, Python `>=3.11,<3.14`, and the pinned Bunker CLI/protocol; capability probes must pass before create |
| `runtime` | rootless image-backed container or equivalent user-space Bunker, no privileged mode, no host root, and no ambient provider credential |
| `mounts` | `$HOME/.node` (0700), `$HOME/repo` (project checkout with embedded board), `$HOME/.cache/hermes`, sealed shared module cache, and `$HOME/.local/share/code-factory/evidence`; each path is absolute, owned by the node user, and recorded in the manifest |
| `network` | Crier endpoint, forge endpoint and proxy endpoint are explicit HTTPS/TLS or declared tailnet endpoints; egress is denied except to those endpoints and DNS; the effective routes are read back |
| `identity` | one `node_id`, `project_id`, profile generation and Bunker principal; repository identity `{forge, host, owner, repo, ref}` is separate from every `credential_ref` |
| `credentials` | five references (forge, Crier, Bunker control, inference proxy, DuckBrain); references identify owner, scope, mode, expiry and revocation generation, never secret values |
| `persistence` | the node home and evidence mount persist across restart; image-layer changes do not; the readiness report records the actual persistence result |

Bootstrap is an operation `schema: cf.provision.v1` with `operation_id`,
`request_id`, `project_id`, `node_id`, `profile_id`, `generation`, `manifest_digest`,
`repository`, `credential_refs` and `idempotency_key`. The controller performs disk
admission and capability probes, creates the user-space Bunker, mounts only declared
paths, installs each digest-checked artifact, creates the project checkout and its
embedded board, enrolls the Bunker and stages all credential classes. It then reads
back the effective image digest, runtime capabilities, mount ownership/modes, network
routes, repository commit, board identity, credential scope/expiry (without values),
Hermes version and a successful Crier, inference and DuckBrain operation. A written
configuration or HTTP liveness response alone is not readiness.

The result is `schema: cf.provision-result.v1` with `operation_id`, `generation`,
`state`, `completed_stages`, `artifact_digests`, `readiness_report_ref` and
`failure_ref`. States are `ADMITTED`, `CREATED`, `ENROLLED`, `PROVISIONED`,
`CONNECTED`, `VERIFIED`, `DEGRADED`, `REPLACEMENT_REQUIRED` and `REMOVED`; an
unavailable required check is `UNVERIFIED` and blocks M9 admission. Repeating the
same request and manifest digest returns the recorded result. A changed digest or
generation is `GENERATION_CONFLICT` and cannot mutate the old Bunker.

Upgrade drains Crier retrieval, refuses new admission, snapshots the manifest and
credential generations, installs the new digest in a replacement generation, runs the
same effective readback, then switches the registration only after `VERIFIED`. A
failed upgrade keeps the previous generation or enters `REPLACEMENT_REQUIRED`; it
never reports the new generation as ready. Replacement first fences the old Bunker,
revokes its credentials, preserves evidence and then provisions the new generation.
Removal verifies that no active lease remains, revokes all five credential classes,
archives the readiness and operation records, and deletes only owned mounts. These
procedures are specified target behavior; the live profile and cross-host operations
remain `UNVERIFIED` until their stated readbacks are run.
