# M1 — PROVISIONING

## 1. Identity

P5-B-39 reconciliation: the following identity/locator table is historical source
coverage at its stated revision, not a current-HEAD assertion. The P5 source snapshot
`fb11e92c1580b98e2e8d64cb9a81cdcb3ef64f02` contains a 510-line verify-node.sh
(`wc -l`), including the later usage fix in `fe63289e58b554d46afce69ea25bbced35d329e1`.
The 241-line identity review and 504-line ladder review are superseded inventories;
no fresh live ladder run is claimed. Their old line locators remain dated source
references, not executable target definitions. §§15–17 specify the current target.

| Field | Value |
|---|---|
| Module name | PROVISIONING |
| Path | `~/code-factory/scripts/` — `bunker-server-install.sh`, `disk_floor.py`, `bunker-provision.sh`, `bunker_config_gen.py`, `node-create.sh`, `bunker-crier-connect.sh`, `node_identity.py`, `node_gateway_auth.py`, `node_seed.py`, `node_seed_drift.py`, `node_env.py`, `verify-node.sh`, `node_freshness.py` |
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

M1's canonical edges are CT-22 (enrollment/registration) and CT-23 (Bunker
provisioning/exec). Part IV §IV.2.4 retires M1-C1/M1-C2 to coverage-import aliases.
The following citations describe legacy source coverage, not target qualification.

| ID | Peer | Direction | Producer `file:function` | Consumer `file:function` | State |
|---|---|---|---|---|---|
| CT-22 | crier | out | **Normative target:** the authority/controller consumes the single-use tuple-bound `enrollment-grant.v1` reference, creates `registration_id` and issues the Crier identity plus the CT-21 `credential.install` `credential_ref` with class `crier`; the node then emits the CT-22 outer `cf2a.v1` / body `register.v1` request at `POST /v1/factory/registrations` and proves a verified signed bus read before scheduling. **Implementation coverage:** no in-repo producer was measured — `bunker-crier-connect.sh` only stages `$HOME/.node/crier.json` and probes the inbox via `node-bus-worker.py --check` (`:13`, `:33`, `:53`, `:114-118`); it does **not** issue the registration request or write `auth/crier.token` (B06). **Neither `node_identity.py` (`:50-107`, merges/replaces local JSON) nor `node_gateway_auth.py` (`:70-162`, writes dashboard basic-auth + a password file) registers an agent** (B03); this measured absence is tracked as CF-276 and is not a gap in the target contract. | crier `internal/registry/handler.go:598` `HandleRegister` (legacy implementation coverage) and `:613` `HandleRegisterByID` (legacy implementation coverage) — target contract is CT-22 `register.v1` at `/v1/factory/registrations` | **UNVERIFIED** — the token/registration exchange was not re-run; the implementation producer is absent from the measured in-repo surface, while the normative actor and wire are specified above |
| CT-23 | bunker daemon | out | `lib.sh:107` `bunker_exec` | external public CLI/protocol | UNVERIFIED — legacy short-call observations lack a version-bound target qualification record |

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

**Cold-bootstrap specification proof (P5G-04).** Run from the repository root;
the first command prints `0` (and grep exits 1 for no match), the second prints the
CT-22 and A5 actor/registration rows, the third prints the IV register fixture and
the M1 CT-22 row, and the fourth prints A5 including both failure states and resume
identity. Line numbers in the output are navigation aids, not asserted values.

```bash
forbidden='named spec'; forbidden="$forbidden gap"; grep -c "$forbidden" docs/handbook/chapters/M1-provisioning.md
grep -nE 'authority/controller.*CT-22.*register[.]v1' docs/handbook/chapters/M1-provisioning.md
grep -nE 'cf2a[.]v1.*register[.]v1' docs/handbook/parts/IV-contract-register.md docs/handbook/chapters/M1-provisioning.md
grep -F '| A5 | Bus membership:' docs/handbook/chapters/M1-provisioning.md | grep -E 'ENROLLMENT_FAILED|DEGRADED|operation_id|manifest_digest'
```

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
| Missing `lib.sh` | named missing-library refusal before checks execute | a measured check failure | restore the repository-owned scripts/lib.sh, then rerun check; the old undefined-helper diagnostic is superseded (P5-B-40) |
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
| A5 | Bus membership: Crier identity + registration/token exchange, verified signed read | **Normative actor/data:** Part I §1.9.11 governs first registration: the authority consumes the tuple-bound single-use `enrollment-grant.v1`, creates `registration_id` and issues the Crier identity plus the CT-21 `credential.install` `credential_ref` with class `crier`; the node then performs CT-22 `register.v1` (outer `cf2a.v1`, target `POST /v1/factory/registrations`) and proves a verified signed bus read before it is schedulable. **Implementation coverage:** `bunker-crier-connect.sh` only stages `$HOME/.node/crier.json` and probes the inbox; no in-repo registration producer was measured (CF-276), as recorded in the CT-22 coverage row. | M2 dispatch | enrollment failure sets `ENROLLMENT_FAILED`; a failed or unproven signed bus read sets `DEGRADED` and the node is **NOT** schedulable; stage-6 private clone and other dependents do not run. Resume the last completed stage under §17.2 with the same `operation_id`, `generation` and `manifest_digest`. |
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

**R4 — Distinct credential classes (required).** Five classes with separate authorities/producers, scopes,
delivery, renewal and revocation, never interchangeable: (1) forge/GitHub (app installation,
scoped tokens, deploy keys — clone/fetch vs push vs merge permissions documented separately; a
read-only deploy-key proof does not establish publication capability); (2) Crier bus
(the authority/controller issues the Crier identity and class-`crier` credential reference at enrollment;
the node performs CT-22 `register.v1` and the signed-read proof); (3) Bunker-control;
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

The specified, not yet release-qualified, MVP profile is a user-space, image-backed Bunker with a persistent mounted node home. The profile supports a pinned Hermes/Oh My Hermes build, a project checkout containing the embedded board, Crier membership, node-scoped proxy access and local Git-backed DuckBrain. Kubernetes, Compose, homelab and standalone modes are not universal guarantees; each is unsupported unless it supplies the same readback and conformance rows.

| Stage | Durable input and output | Required refusal / recovery |
|---|---|---|
| admission | declared profile, role, disk floor, footprint; `profile_id` and `generation` | unknown profile, insufficient measured headroom or unreadable host state refuses before spawn |
| create | `node_id`, `project_id`, repository identity `{forge, host, owner, repo, ref}` and credential references, never credentials in the identity | duplicate `(project_id,node_id,generation)` is idempotent; conflicting generation is a compare-and-swap refusal |
| enrollment | controller principal, Bunker principal, tuple-bound single-use bootstrap reference, trust key/certificate fingerprint, Crier registration id and endpoint | §1.9.11 consumes the grant, allocates one node identity, installs class-`crier`, then proves the signed read; missing trust, wrong project/profile/generation, expired identity or registration refusal leaves `ENROLLMENT_FAILED` with no durable identity; failed read leaves `DEGRADED` and unschedulable |
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

## 16. Deployment profile summary (P4-DEPLOY-01, refined by §17)

The target profile is `bunker.user-image.v1`, a rootless execution profile requiring
capability and release qualification under §17.3. It is not a universal Bunker mode. The profile manifest is the
source of truth and is immutable for one provisioning generation:

| Field | Required value or rule |
|---|---|
| `profile_id` | `bunker.user-image.v1` |
| `artifact` | an OCI image or equivalent user-space archive named by digest, plus the Hermes artifact URL, version `0.19.0`, and SHA-256; a tag or version without a digest is refused |
| `host` | Linux user namespace, `uidmap`, `fuse-overlayfs`, `slirp4netns`, `git`, Python `>=3.11,<3.14`, and the pinned Bunker CLI/protocol; capability probes must pass before create |
| `runtime` | rootless image-backed container or equivalent user-space Bunker, no privileged mode, no host root, and no ambient provider credential |
| `mounts` | whole persistent HOME and a separate read-only module cache; §17.4 specifies every retained path, owner, mode and replacement/removal rule |
| `network` | §17.4 phase-specific authority/Crier/forge/proxy/memory/DNS allowlist plus bootstrap-only signed artifact mirror; effective routes are read back |
| `identity` | one `node_id`, `project_id`, profile generation and Bunker principal; repository identity `{forge, host, owner, repo, ref}` is separate from every `credential_ref` |
| `credentials` | five references (forge, Crier, Bunker control, inference proxy, DuckBrain); references identify owner, scope, mode, expiry and revocation generation, never secret values |
| `persistence` | the node home and evidence mount persist across restart; image-layer changes do not; the readiness report records the actual persistence result |

Bootstrap uses the complete `cf.provision.v1` request and ordered stages in §17.2.
Trust, enrollment and a verified bus read precede credential-dependent private clone.
Effective mounts, network, repository, board, credential scope, harness, inference and
local/remote memory are measured before certification; liveness alone is insufficient.

The result uses `schema_version: cf.provision-result.v1` and §17.2's complete
state/version fields, including DECLARED and ENROLLMENT_FAILED. UNVERIFIED belongs
to check outcomes, not the provisioning state enum. Same-key replay, resume and
N→N+1 upgrade/replace are distinct operations with the §17.2 CAS preconditions.

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

## 17. P5 executable provisioning profile

This section resolves P5-B-03/06/13–19. Types and canonical serialization are Part IV
§IV.2; authority, certificates, broker-only write credentials and journal durability
are Part I §§1.9.1–1.9.3a. These protocols specify required behavior, not installed
capabilities. Any earlier stage list is a summary of the ordered stages below.

### 17.1 First trust, registration and credential exchange

The offline operator CA is Ed25519 (RFC 8032); public keys are 32-byte raw values,
base64url without padding; private keys never leave their originating custodian.
Certificates are X.509 DER carried as base64, with the SAN and usages in Part I
§1.9.3. The operator provisions a read-only trust bundle containing CA certificate,
authority DNS name, server SPKI SHA-256 and permitted project into the fresh Bunker
through the authenticated Bunker-control channel. A failed chain/DNS/SPKI check
refuses before any enrollment secret is sent; trust-on-first-use is forbidden.
The Bunker generates its own key and PKCS#10 CSR. The initial Bunker-control credential
is operator-owned, not obtained through the bus it is creating.

The authority issues one enrollment grant, signed offline, as the single-use
`credential_ref` `enrollment-grant.v1` bound to exactly
`(project_id, profile_id, generation, operation_id)` and the Bunker's
`public_key`. Its authority-side record is `{schema_version:"enrollment-grant.v1",
grant_id:ID, registration_id:ID, project_id:ID, profile_id:ID, generation:PosInt,
operation_id:ID, public_key:Base64url32, nonce:Base64url32, issued_at:Time,
expires_at:Time, issuer_key_id:ID}` plus `signature:Base64url64`; it carries no
inline secret material. Lifetime is at most 600 s. The signature covers UTF-8
`CF2A-ENROLL-1\n` followed by JCS of the object excluding signature. The nonce uses
32 cryptographically random bytes. `registration_id` is controller-allocated before
first exchange, not `registration_generation`. The reference is delivered in a
mode-0600 file, removed after successful consumption, and is never argv, JSON, log or
worker environment. The Bunker does not supply `node_id`; Crier allocates it.

`POST /v1/enroll` is the sole client-certificate exception: TLS 1.3 authenticates
the pinned authority server; grant signature and proof of possession authenticate
the client. Body is `authority.v1` with idempotency_key, grant, csr_der and
public_key. The request has X-Request-Id, X-Correlation-Id, X-Nonce (fresh 32 bytes),
X-Created-At, X-Key-Id and X-Signature. Signature bytes are Ed25519 over the UTF-8
string `CF2A-REQUEST-1\n<METHOD>\n<path>\n<request_id>\n<corr_id>\n<created_at>\n<nonce>\n<sha256(JCS(body))>`
with no final LF, signed by the Bunker key. No query is permitted on enrollment;
other signed routes sort percent-encoded query pairs bytewise and include them in
path. The authority rejects more than 30 s clock skew (`CLOCK_SKEW`), an expired
or revoked grant (`GRANT_EXPIRED`/`UNAUTHORIZED`), reused nonce with different digest
(`REPLAY_CONFLICT`) or wrong key/scope (`UNAUTHORIZED`). Nonce/digest/receipt retention
is at least 24 h after credential expiry. An identical nonce/digest returns the saved
receipt and performs no issue operation. A fresh nonce with the same idempotency key
and body digest also returns the original receipt.

The authority atomically consumes the grant and records certificate serial,
registration_id, agent/project binding and registration_generation=1 using the
Part I journal. Renewal requires the current certificate and expected_generation;
it increments registration_generation once. First registration never asks a caller
for an unallocated generation. Changed grant/key under the same registration_id is
`REGISTRATION_CONFLICT`. Response data is `{registration_id, registration_generation,
certificate_der, expires_at, credential_refs:CredentialRef[], authority_seq}`;
this certificate is public, not a bearer secret. A crash after issue returns the
same certificate/refs. The node then uses mTLS plus the Crier-signed request to
`POST /v1/factory/registrations` with `register.v1` (Part IV). The legacy
`/factory/v1/registrations` spelling is an alias only at the migration adapter. This adapter is not a
claim that legacy POST /agents already implements this wire. Crier checks the live
authority binding, persists the registration, and returns registration metadata and
a scoped bus credential reference before any inbox read.

CredentialRef is `{id:ID,class:forge/crier/bunker/proxy/memory,subject:ID,
project_id:ID,operations:ID[],generation:PosInt,expires_at:Time,issuer:ID}`.
A local installer resolves it only through the protected AF_UNIX broker protocol in Part I
§1.9.10. The node-broker socket is not in the worker mount namespace; SO_PEERCRED and the
enrolled principal's assigned ref list authorize the request. The response is a sealed file
descriptor (SCM_RIGHTS), not JSON secret bytes. Cross-host transfer uses one assigned
`secret-transfer.v1` per consumer and registration generation; fanout never shares a
descriptor. The installer copies it into an O_EXCL temporary file under the service-owned
credential staging directory, chmods 0600, fsyncs and renames; parent directories are 0700,
owner UID is the exact service consumer UID, no symlink is accepted. Readback returns
fingerprint, effective scope, expiry and mode, never contents. Revocation at the authority
and a negative probe at the resource are required before a replacement becomes ready.
The controller transfers only read-only forge credentials to the node; protected
writes use broker capabilities (Part I §1.9.7). Proxy credentials cannot expose
upstream provider keys. Every installed class has separate issuer and revocation id.

Crier read proof is signed
`GET /v1/factory/deliveries/<delivery_id>?request_id=<id>&idempotency_key=<key>`
(or the collection form with agent/state plus the same signed-read parameters)
under the single `CF2A-CRIER-1` profile in M10 §16. The former unversioned
`GET /agents/<agent_id>/inbox/stats` example and `CF2A-REQUEST-1` Crier variant are
retired: `CF2A-REQUEST-1` remains the authority enrollment profile only. The Crier
response binds request/response principals, registration generation, request
ID/idempotency nonce, exact body digest and lease/custody receipt. Duplicate GET
nonce replays its saved observation, not a fresh read. The route map is normative:
`/factory/v1/registrations` is the legacy adapter alias for
`POST /v1/factory/registrations`; `/agents` and `/agents/*/inbox/*` are legacy-only
and return `410 ROUTE_RETIRED` for target clients.
Revocation is authority `POST /v1/revocations`, then readback of the exact ref/serial
and a negative probe at the resource boundary. `401 CAPABILITY_REVOKED` or certificate
refusal is proof; deletion of a file is not. Renewal starts at half lifetime (12 h
for the maximum 24 h certificate). The new serial is verified by readback, overlaps
the old serial for exactly 60 seconds for in-flight reads, and the old serial is then
revoked; mutations use only the new generation. Admission stops at expiry. All enrollment,
renewal, denial and failure records use M0 §16.1 telemetry without nonce/key values.
A grant signed by an unknown operator, duplicate first request, changed CSR retry,
clock-skew failure, lost response and revoked read are mandatory conformance cases.

### 17.2 Ordered stages, complete request and resume

Only this dependency order is executable: (1) validate request/release lock and disk;
(2) reserve host capacity and create Bunker with persistent mounts; (3) install trust
and enroll; (4) install Crier credential and prove signed bus read; (5) install
read-only forge/proxy/memory references; (6) clone exact repository object and embedded
board; (7) install seed and Hermes/omh from the release lock; (8) measure inference,
local/remote memory and effective isolation; (9) activate readiness/binding. A private
clone never precedes its credential, and clone failure leaves a bus-visible degraded
node. Each stage records input digest, start intent, result and artifact refs in the
operation journal. Dependents do not run after failure. No automatic destroy erases
diagnostics.

The `cf.provision.v1` request has these exact required members (closed object):
operation_id, request_id, project_id, node_id (ID); profile_id literal
`bunker.user-image.v1`; generation (PosInt); expected_generation (UInt);
operation (`create`, `resume`, `upgrade`, `replace`, `remove`); manifest_digest (SHA);
repository `{forge:github/gitlab,host:DNS,owner:ID,repo:ID,ref:GitRef,commit:GitOID}`;
credential_refs (one ref per required class); idempotency_key (ID); manifest (below).
No field is null. A create compares expected_generation=0 and installs generation=1;
upgrade/replace compares N and installs N+1 with a new operation/key after drain/fence.
remove compares current N without allocating a new runtime. Reusing a key with changed
input is `IDEMPOTENCY_KEY_REUSED`, not an upgrade. Resume references the same
operation_id, generation and manifest digest with a distinct request/idempotency key;
it returns current progress and resumes only unfinished idempotent stages after discovery.
An exact retry replays the original receipt; GET operation reads subsequent progress.

Manifest fields are `release_lock_ref:EvidenceRef`, `role:worker/builder/full`,
`disk_floor_gib:integer[1,4096]`, `ttl_s:integer[60,604800]`, `namespace:ID`,
`endpoints:{authority,crier,forge,proxy,memory,artifact_mirror,dns}` (Endpoint each),
`mount_root:AbsolutePath`, `seed_ref:EvidenceRef`, `network_phase:bootstrap/runtime`.
Endpoint is `{host:DNS,port:integer[1,65535],tls_spki:SHA}`; DNS uses port 53 and
an empty tls_spki string only. The minimal request contains all fields; optional
settings are absent and supplied by the following defaults: worker floor=5 GiB,
builder=10, full=20, ttl_s=21600, network_phase=bootstrap. The request is materialized
with these values before hashing, so omitted/defaulted requests have identical intent.

The target CLI accepts `--request FILE` (UTF-8 JSON), `--config FILE` and repeatable
`--set KEY=JSON`; it never sources config. The complete KEY set is the top-level request
member names above plus `role`, `disk_floor_gib`, `ttl_s`, `namespace`, `endpoints`,
`mount_root`, `seed_ref`, `release_lock_ref` for manifest members. A config line is
ASCII KEY, `=`, one JSON value; blank lines and lines beginning `#` are ignored;
inline comments, duplicate keys, shell expansion, unknown keys, unquoted strings and
empty RHS are refused. Precedence is explicit CLI sets > request JSON > config >
role defaults; conflicting duplicate CLI sets refuse. The sole ambient exception is
NODE_DISK_FLOOR, between CLI/request and config; all other CF/provision environment
values are ignored. A missing required member is `INVALID_FIELD` before spawn.
This is a target adapter grammar, not an assertion about existing shell flags.
A complete create example is specified in Part IV §IV.3 using declared fixture refs;
it cannot certify a real installation.

The durable state enum is DECLARED, ADMITTED, CREATED, ENROLLED, PROVISIONED,
CONNECTED, VERIFIED, ENROLLMENT_FAILED, DEGRADED, REPLACEMENT_REQUIRED, REMOVED.
UNVERIFIED is a check outcome, never a provisioning state. The forward sequence in
§15 applies; any nonterminal stage may enter DEGRADED (enrollment failure uses
ENROLLMENT_FAILED), then resume the last completed stage after dependency readback.
VERIFIED→DEGRADED on drift/expiry; VERIFIED→REPLACEMENT_REQUIRED on lost state;
REMOVED is terminal. Results include operation_id, generation, state, completed_stages
(ordered unique stage numbers 1..9), artifact_digests (SHA[]), readiness_report_ref
(EvidenceRef or null), failure_ref (EvidenceRef or null), state_version (PosInt).
Mutation effects and result are journaled/fsynced before acknowledgement.

### 17.3 Release lock and owner decision B-RELEASE

No complete qualified release lock is evidenced by this issue. Therefore the profile
is SPECIFIED, NOT QUALIFIED, and apply/admission refuses `RELEASE_LOCK_UNAPPROVED`.
Hermes 0.19.0 and omh 4.0.5 are proposed compatibility targets, not proof of a complete
reproducible deployment. This resolves the former false claim of a qualified profile
without inventing a download or digest. Decision slot B-RELEASE (shared with A-RELEASE):
options are qualify the existing pins as one integrated bundle, or select and qualify
a newer complete bundle. Default is neither; release owner supplies a signed lock and
live certification before installation. It cannot be waived by a caller-supplied hash.

The release owner publishes immutable `cf.release-lock.v1` with release_id, platform
(`linux/amd64` or `linux/arm64`), artifacts (nonempty ordered entries), protocol_versions
(sorted unique strings), config_versions (sorted unique strings), qualification_ref
(EvidenceRef), issuer_key_id and signature. Each artifact has name, exact version,
HTTPS URL, full SHA-256, byte size, media_type, install_path, dependency_names and
owned_paths. Required names are image/archive, Bunker client, Bunker daemon, Python,
Hermes, omh, omh-config, Node, Go, GitReins, Boardctl, DuckBrain, supervisor and all
transitive wheels/npm archives/OS libraries; a lock with unresolved dependencies,
floating tags, ellipses or an absent architecture refuses. The signature is Ed25519
on `CF2A-RELEASE-1\n` plus JCS excluding signature; the offline operator trust bundle
pins the release signer. omh-config is content-addressed configuration including exact
plugins and enablement; a package version is not integrated configuration. The target
protocol compatibility set is Part I §1.9.8 plus the schemas in Part IV §IV.2.

Existing full source pins, not qualification evidence, are:

| Artifact | Source URL | SHA-256 |
|---|---|---|
| Node v22.22.3 linux-x64 | https://nodejs.org/dist/v22.22.3/node-v22.22.3-linux-x64.tar.xz | `2e5d13569282d016861fae7c8f935e741693c269101a5bebcf761a5376d1f99f` |
| Node v22.22.3 linux-arm64 | https://nodejs.org/dist/v22.22.3/node-v22.22.3-linux-arm64.tar.xz | `1c4a9933a5e45bc88f54f70b5f91232c127ec49f1a5989d23fb85824c7adf9b7` |
| Go 1.26.5 linux-amd64 | https://go.dev/dl/go1.26.5.linux-amd64.tar.gz | `5c2c3b16caefa1d968a94c1daca04a7ca301a496d9b086e17ad77bb81393f053` |
| Go 1.26.5 linux-arm64 | https://go.dev/dl/go1.26.5.linux-arm64.tar.gz | `fe4789e92b1f33358680864bbe8704289e7bb5fc207d80623c308935bd696d49` |

Sources: `scripts/install-node.sh:26-28`, `scripts/install-go.sh:7-9` at the source
revision of this change. These values are copied from source, not re-downloaded here.

### 17.4 Network, mounts, storage transactions and certification

Bootstrap permits only the manifest endpoints, including artifact_mirror and memory,
over their pinned transports, plus the declared DNS resolver. Artifacts and dependency
archives come from the signed mirror; redirects outside its allowlist refuse. Go cold
cache proof uses a mirrored module/sum database or a preloaded signed cache with
GOPROXY=off; no arbitrary internet exception exists. Before runtime admission the
provisioner disables artifact-mirror egress, reads back the firewall policy and records
its digest. Runtime permits authority, Crier, forge read endpoint, proxy, memory and
DNS. Broker mutation endpoint is served by authority's declared endpoint. Each failed
or unexpected connection invalidates network readiness. [M5 §16; Part I §1.6.]

The persistent-HOME requirement is implemented as separate, non-overlapping volumes, not
one worker-writable root containing the enforcement records. `/var/lib/factory/control`
(owner `factory-control`, mode 0700) holds supervisor journals, launch/budget records,
retention state, policy and service credentials; only the supervisor mounts it read-write.
`/var/lib/factory/foreman` (owner `factory-foreman`, mode 0700) holds the foreman HOME,
Hermes sessions, configuration and board work; the worker sees none of it.
`/var/lib/factory/worker` (owner `factory-worker`, mode 0700) holds the worker HOME,
`repo`, `worktrees` and attempt scratch. `/var/lib/factory/memory` and
`/var/lib/factory/evidence` are distinct durable mounts: the local memory writer and
evidence broker own their protected roots, while the foreman and worker reach them only
through their scoped writer sockets. `/var/lib/factory/node-broker` (owner
`factory-node-broker`, mode 0700) stages sealed credentials and is not mounted by either
harness. Release/toolchain and shared-cache mounts are read-only. Restart preserves every
volume and its ownership; no mount masks another and no path is a symlink.

Replacement copies journal/evidence/pending-memory snapshots under a new identity and
revokes old auth; it never copies reusable write credentials. Uninstall preserves evidence,
session history and pending memory under retention holds; only the signed owned_paths list
is deletable after M3 backup receipt readback. Control, retention and credential records are
never offered for ordinary worker deletion or modification. The effective UID, mount
read/write modes, socket visibility, descriptor seals and negative access probes are part
of readiness evidence; a directory-permission assertion without those probes is not proof.

`node.json` schema is `cf.node.v1`: schema_version, revision (PosInt), node_id,
project_id, generation, agent, namespace (ID), repo (Repository), harness
`{name:"hermes",release_lock_ref:EvidenceRef}`, identities
`{service_uid:UInt,foreman_uid:UInt,worker_uid:UInt,node_broker_uid:UInt}`,
profile_digest:SHA, bus `{base:HTTPSURL,
registration_id:ID,registration_generation:PosInt}`, duckbrain
`{namespaces:ID[],root:AbsolutePath}`, created_by/provisioned_by (ID),
created_at/provisioned_at (Time), freshness `{commit:GitOID,observed_at:Time}`.
No secret and no unregistered field is allowed. Both writers take the same
`.node/node.lock` exclusive flock, reread revision, compare expected_revision,
merge only their §3-owned fields, increment revision, fsync temporary file, rename,
fsync parent and release. Conflict is `IDENTITY_CONFLICT`; malformed input preserves
the old file and refuses. Atomic rename without the shared lock/CAS is insufficient.

Seed is `cf.seed.v1` with seed_id, generation, release_lock_ref, entries
`[{path:relative-path,mode:0644/0755,size:UInt,digest:SHA}]`, issuer_key_id, signature.
Entries sort bytewise by path, are unique, restricted to prompts/skills/config, and
forbid absolute paths, `..`, symlinks, hardlinks, device nodes and duplicate tar entries.
Total expanded bytes are at most 16777216. Archive SHA-256 is in the signed release lock;
seed signature uses `CF2A-SEED-1\n` plus JCS excluding signature. Applied record is
`{schema_version:"cf.seed-applied.v1",seed_id,generation,manifest_digest,
installed_tree_digest,applied_at,operation_id}`. Extraction/verification occurs in a
new immutable generation directory. A single atomic current symlink switches the whole
seed after fsync; prompts/skills/config consumers resolve through that pointer.
Force-reseed requires an explicit operation and retained old-generation snapshot;
crash before pointer switch uses old tree, afterward uses new tree and repairs the
applied-record projection from the journal. Mixed multi-directory copies never count
as applied. Local edits are detected, preserved as evidence and refuse forced switch
without recorded operator authorization.

Readiness check names are profile, disk, mounts, network, identity, repo, board,
Crier, harness, inference, memory-local and memory-remote. Each is
`{name,status:PASS/FAIL/UNVERIFIED,observed_at:Time,evidence_ref:EvidenceRef,error:Error|null}`.
Initial VERIFIED requires all live legs PASS and certificate/fence validity; a
report expires after 86400 s or earlier credential expiry. Admission rechecks live
fence/binding and observation age <=30 s for repo/board/authority. Artifact/config
change, credential revocation, mount/network drift or corrupted local memory immediately
invalidates it. A remote-memory outage after certification permits already admitted
work with local Git durability and pending-sync; new admission requires remote freshness
<=300 s. Beyond 300 s the node is DEGRADED, new admission stops, and existing work
may finish locally but cannot settle until controller-readable evidence exists.
Unknown/corrupt local memory stops work immediately. There is no false VERIFIED from
an unavailable initial remote leg. Recovery performs fresh readbacks and creates a new
report; historical reports remain immutable. [Part I §1.9.9; Part II F3.]

### 17.5 Signed configuration resolution and enforced containment (P6-07/08/09)

Provisioning consumes only the accepted `factory.v1` generation and the signed artifacts
it names. `manifest.release_lock_ref` must equal the EvidenceRef in
`artifacts[policy.release_lock_ref]`; the supervisor and Hermes artifact references must
equal `execution.artifact_ref` and `execution.harness_artifact_ref`; the signed profile
must match `profiles[profile].signed_profile_ref`. The provisioner downloads each object
from the declared artifact mirror, recomputes its digest, verifies the release-owner
signature and recursively validates the adapter capability registry before writing the
operation's `DECLARED` record. An unsigned, missing, mismatched or incomplete object is
`ARTIFACT_UNQUALIFIED`; a caller-provided replacement path or hash is not accepted.
The composed and deliberately unready examples are Part V §§V.7/V.11, not alternate
provisioning schemas.

The resolved profile records four distinct Linux identities. Numeric UIDs are allocated
once by the manager from the signed profile and persisted in `cf.node.v1.identities` as
`service_uid`, `foreman_uid`, `worker_uid` and `node_broker_uid`; names below are canonical account
labels. `factory-control` runs only the supervisor, retention owner and launcher.
`factory-foreman` runs the fenced foreman and its harness. `factory-worker` runs ordinary
worker attempts. `factory-node-broker` runs secret transfer and sealed staging. No two
roles share a UID, supplementary group, writable HOME or capability set. Every role has
`no_new_privileges`, no host devices, no host PID/network namespace and no added Linux
capabilities; cgroup v2 CPU, memory and PID limits are service-owned.

|| Interface | Visible to | Access contract |
||---|---|---|
|| `$HOME/.local/state/factory/supervisor/control.sock` | supervisor and `factory-control`; `factory-foreman` for launch only | `supervisor.v1` HTTP-shaped `PUT /v1/launches/{launch_id}`, query/reconciliation and role-guarded service operations for the live fence only; mode 0600 and peer-UID verification; worker mount has no socket |
|| `/run/factory/<project>/worker-result.sock` | supervisor and `factory-worker` | one-way native-event/result writes for the current execution key; no submit, cancel, resume or other-attempt read |
|| `/run/factory/node-broker/secrets.sock` | node broker and authorized service installer | `secret-resolve.v1` plus SCM_RIGHTS; absent from foreman/worker mounts |
|| `/var/lib/factory/control` | `factory-control` | read-write service journal and policy root; all other roles have no mount |
|| `/var/lib/factory/foreman` | `factory-foreman` | read-write foreman HOME; read-only release mounts; no worker mount |
|| `/var/lib/factory/worker` | `factory-worker` | read-write worker HOME/worktree only; control, peer worktrees and policy are absent |
|| `/var/lib/factory/memory` | local memory writer | writer socket mediates foreman/worker append; neither can edit Git refs or resolution records directly |

The foreman's mediated launch carries its fenced capability in an inherited sealed
descriptor, not an environment variable. The supervisor checks SO_PEERCRED, the live
`owner_fence`, registration generation, role and exact `supervisor.v1` launch body before accepting.
A worker cannot use that descriptor: it is close-on-exec outside the foreman launcher,
the worker mount excludes `control.sock`, and the supervisor rejects `factory-worker` for
every launch or administrative operation. Worker native results use the separate one-way channel and are
accepted only for the preassigned execution key and process incarnation.

Readiness executes negative probes as the ordinary worker: open the control root; alter a
launch, budget or retention record; resolve another scope's credential; connect to the
supervisor or node-broker socket; submit/cancel/resume an execution; write the signed
policy; and access a peer worktree. Every attempt must fail with `EACCES`,
`SOCKET_NOT_PRESENT` or `CAPABILITY_SCOPE_DENIED` and produce no mutation. Positive probes
prove that the fenced foreman can submit CT-05 and append local pending memory while the
worker can return its own result and write only its worktree. The probe receipt includes
UIDs, mount table, socket modes, cgroup values and policy digest. Terminal Jail remains
optional/off; these kernel/service boundaries are the baseline and cannot be bypassed by
a cooperative harness.
