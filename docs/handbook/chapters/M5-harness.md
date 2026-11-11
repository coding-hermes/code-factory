# M5 — HARNESS

## 1. Identity

P5-B-39 snapshot reconciliation: the identity table and historical locator rows retain
older source-review editions, not the present target. At source commit
`fb11e92c1580b98e2e8d64cb9a81cdcb3ef64f02`, tests/harness-conformance.sh is 956 lines
(`wc -l`); that source inventory does not assert a fresh execution. §7's dated fixture
runs supersede only the blanket not-run claim, never the unrun live ladder. An old
record lacking an exact run revision is historical/unqualified, not silently rebound
to the current HEAD. §16 is target behavior and has no implied execution evidence.

| Field | Value |
|---|---|
| Module name | HARNESS |
| Path | `~/code-factory/scripts/harness/` — `install-hermes.sh`, `install-codex.sh`, `install-claude-code.sh`, `install-opencode.sh`, `install-deepseek.sh`, `install-dsh.sh`, `install-pi-agent.sh`, `install-aider.sh`, `install-goose.sh`, `harness-vars.sh`; **and** `~/code-factory/scripts/` — `harness_resolve.py`, `install-go.sh`, `install-gitreins.sh`, `project-node.sh` |
| Revision | `fbc19cbc807de729e25c358fa7e94207b912f010` (code-factory HEAD; `project-node.sh` layer 20 gained the CF-150 `gateway_auth` staging block and `node-create.sh` re-lined in `08a2c8a..fbc19cb`; every M5 file:line re-pinned) |
| Language / runtime | bash 5.3.9 + Python 3.14.9 (measured) |
| Owner lane | code-factory (node-side) |
| Status | **UNVERIFIED** — `harness-vars.sh` (318 lines), `harness_resolve.py` (400 lines), `install-hermes.sh` (388 lines, +13 for the CF-192 occupied-port auth gate), `install-gitreins.sh` (180 lines), `install-claude-code.sh` (settings surface), `install-codex.sh` (settings surface + partial body), `install-opencode.sh` (98 lines), `install-deepseek.sh` (101 lines), `install-pi-agent.sh` (113 lines), `install-aider.sh` (110 lines), `install-goose.sh` (111 lines) read; `install-claude-code.sh`/`install-codex.sh` full bodies not line-by-line; live conformance unrun; §7 separately records fixture runs. These are historical source/fixture records, not qualification of §16 (P5-B-39). |

## 2. Purpose, authority and position

M5 owns the **harness lifecycle** inside the Bunker: install, configure, update, start/stop/restart,
uninstall and runtime packaging — with the effective settings, credentials and readiness evidence
each operation needs. It may not decide *what* the run does — that is the directive — and, for the
MVP, it does not decide *which* harness runs either: the user-approved MVP fixes **Hermes** (with
the Oh My Hermes operating layer) for every lane, and harness **selection** belongs to the future
Task Router, placed after Node and before Harness. `harness_resolve.py` remains a standalone
selection facility with no production caller (F5-2), retained for that future mode — it is not the
runtime authority, and the MVP does not wire it merely to make the inventory look complete.

**What breaks if this module is absent.** The agent inside the node cannot code, and its commits
are not graded. A harness counts as supported only when the conformance battery's legs pass on a
real node (`_facts.md` FACT-08).

**What breaks if it lies.** An installer that reports PASS for a pinned version it did not verify
installs a wrong or tampered binary ("a version string is not evidence until it is measured",
`install-gitreins.sh:12-13`). A silent acceptance of a credential value lets two lanes on one node
contaminate each other (matrix §5).

**Required behavior (normative).** Approved target behavior governs this chapter; the source
inventory in §3 and the pin/verdict history are implementation coverage, not the requirement.

- **Full lifecycle ownership.** Installation, configuration, update/upgrade, start/stop/restart,
  uninstall and cleanup of harnesses on Bunker-hosted nodes are M5 operations, each with a named
  caller, input, output, state change, idempotency rule and recovery path. Effective settings —
  what the harness actually enforces after translating the factory request through environment,
  config and CLI — are an M5 readback duty: accepted or printed settings must not silently differ
  from enforced settings.
- **Exact harness identity.** The MVP harness is Hermes at the measured pin (`HERMES_PIN=0.19.0`,
  §5). The user's "Oh My Hermes" operating layer is **Oh My Hermes (omh)** — npm package
  `oh-my-hermes`, source repository `rlaope/oh-my-hermes`, pinned-matrix version 4.0.5
  (`specs/HARNESS-MATRIX.md:51`), a configuration/operating layer **over** Hermes, not a peer
  engine. Five same-named forks exist, so provenance is verified before the integrated release is
  named; the exact deployed build/pin is confirmed and re-pinned during implementation
  reconciliation. A matrix row is a supported option, not a deployment fact.
- **Per-Bunker execution context, mounts and persistence.** Every harness runs in a Bunker. Bunker
  supplies **image-backed fresh exec by default and opt-in persistent containers**; M5 documents the
  selected per-Bunker deployment profile: image/host/persistent context, the repository/worktree
  mount and its read/write scope, and where installed packages, dependencies, caches,
  configuration, sessions and evidence live. **A fresh image-backed exec starts from the image
  rootfs: installs made into a fresh rootfs do not survive the next exec.** Anything that must
  persist lives in a mounted home/cache/volume or in an opt-in persistent container — never in the
  rootfs of an image-backed exec — and the profile states which lifecycle boundary (restart,
  container replacement, upgrade, uninstall) preserves which class of state. Lifecycle recovery
  (draining active sessions, configuration migration, rollback, failed/partial-install repair,
  re-certification before admission) is specified per profile, not left to operator inference.
- **Policy access.** The harness's tool/subprocess permissions, sandbox mode, network access and
  resource controls are per-profile configuration with effective-value verification on the actual
  invocation surface; a workdir under `$HOME` is an input-validation rule, not proof a tool stays
  inside the project.
- **DuckBrain integration.** Every Bunker carries DuckBrain and exposes the **same logical
  project-memory view as the controller**; the harness's namespace/lane memory writes land in that
  shared view (CT-09/CT-15 boundaries). Per-harness ad-hoc memory outside the shared namespace is
  not a factory feature.
- **Optional Terminal Jail.** Terminal Jail is optional and **disabled by default**; operators
  explicitly enable and configure it. When enabled, M5's setup/configuration replaces the Hermes
  ordinary Bash/terminal execution path with the guarded executor and provides **no unguarded
  fallback** — covered execution paths refuse rather than run unwrapped when the wrapper, policy or
  required capability is unavailable. It is never auto-enabled, and Bunker baseline protection does
  not depend on it (M8 owns the safety-policy requirements).
- **Real harness activity versus accepted/published work.** A conformance leg, smoke turn or live
  session proves **real harness activity** — nothing more. **Accepted** (independent judgment) and
  **published** (landed tree) are distinct downstream facts with distinct owners (M3 grading,
  acceptance judgment, landing, board closure). Readiness evidence is likewise distinct from task
  acceptance; neither may stand in for the other in board or memory records.
- **Shared harness memory measurement (III.M5.S6 / I3).** Every named adapter is enumerated by
  `tests/harness-conformance.sh` and uses the one `scripts/harness/harness_memory.py` writer in the
  `memory` fixture. The writer requires an explicit non-default namespace and validates the same
  non-empty I3 fields (`namespace`, `run_id`, `lane`, `harness`, `harness_version`,
  `model_requested`, `model_served`, `provider_binding`, `commit`, `tick`); readback compares the
  canonical UTF-8 bytes, not merely parsed values. The fixture is repository-local evidence only:
  it does not contact DuckBrain or certify a live harness run. Because no in-repo adapter currently
  exports complete runtime provenance, each adapter gets an explicit `memory — UNSUPPORTED` row
  rather than an unlabelled skip. Live DuckBrain transport and runtime capture remain UNVERIFIED.

<a id="III.M5.S6"></a>
### III.M5.S6 — harness measurement

The node's harness measurement surface records what the adapter actually reports; it does not turn
an installer or fixture into a live run. The shared I3 memory seam is the same distinction: the
fixture proves writer validation and exact-byte readback for every in-repo conformance adapter, while
the unsupported rows preserve the missing runtime-exporter obligation. A future live adapter must
keep the explicit namespace and all-field validation and replace only the hermetic backend.


**Finding F5-2.** `harness_resolve.py` is **not** the runtime resolver. A repo-wide search finds it
referenced only by itself, `tests/selftest.sh` and `tests/test_harness_resolve.py` — no production
caller. The node's actual selection reads `node.json`'s `harness.cmd`/`harness.name`
(`node-bus-worker.py:412-414`, default `hermes`) and builds the harness argv directly
(`node-bus-worker.py:459-469`); the dispatcher invokes Hermes directly (`dispatcher.py:260`). The
resolver is a standalone selection facility, not the wired runtime authority.

**Finding F5-5 (B02).** A literal source search misses the production invocation — a
*computed-call-site* case. `project-node.sh:498` builds the installer path from a variable
(`inst="$HERE/harness/install-$HARNESS.sh"`), and `:508-510` invokes it with `--apply` (or
`--check`) under `NODE_GATEWAY_PORT`. A literal `grep -rn 'install-hermes'` cannot match that, but
the invocation is real and in-repo. `node-create.sh:29` stages the same computed path (in the
`staged=(…)` list, alongside the newly-staged `node_gateway_auth.py`). The installers are therefore
invoked by `project-node.sh` (a unit), which is itself operator-invoked — so the *chain* is
operator-initiated even though the installers are unit-invoked.

## 3. Submodule inventory

| Submodule | Unit | Classification | Evidence (invoking line) |
|---|---|---|---|
| S1 hermes | `install-hermes.sh` | **active (unit-invoked)** | invoked by `project-node.sh:498` (computed `install-$HARNESS.sh`) / `:508-510` (`--apply`/`--check`), and staged by `node-create.sh:29`; `project-node.sh` is itself operator-invoked (the provisioning entry, no cron/scheduler invokes it) — F5-5 |
| S2 foreign harnesses | `install-codex.sh`, `install-claude-code.sh`, `install-opencode.sh`, `install-deepseek.sh`, `install-dsh.sh`, `install-pi-agent.sh`, `install-aider.sh`, `install-goose.sh` | **active (unit-invoked)** | same computed dispatch `project-node.sh:498,508-510`; `install-claude-code.sh:36` sources `lib.sh`, the other seven source `harness-vars.sh` |
| S3 toolchain/gate/node | `install-go.sh`, **`install-node.sh`**, **`gomodcache.py`**, `install-gitreins.sh`, `project-node.sh` | **active (unit-invoked)** | gate pin at `install-gitreins.sh:19`; `project-node.sh` is the one provisioning entry that invokes other units (`project-node.sh:173` disk_floor, `project-node.sh:212` reclaim, `install-go.sh --apply` in the `go` kind branch, `install-node.sh --apply` in the `node` kind branch `:396-414`, `gomodcache.py check` in the `go:modcache` row `:488-505`, the harness adapter `:498/:508-510`, and the CF-150 `gateway_auth` staging block at `:448-497`) |
| S4 harness resolution | `harness_resolve.py` | **optional** | no production caller (`grep -rln harness_resolve scripts/` → self + tests only); F5-2 |
| S5 variable contract | `harness/harness-vars.sh` | **active** | sourced by `install-hermes.sh`, `install-opencode.sh:15`, `install-deepseek.sh`, `install-dsh.sh`, `install-pi-agent.sh`, `install-aider.sh:21`, `install-goose.sh:22`, `install-codex.sh:47` (conditional) |

<a id="M5.S2"></a>

**CF-240 — opencode and capability probes.** The adapter measures its binary version and reads
both help streams for its non-interactive surface. An explicit `--generation v2` request is
refused by name (CRIER-HARNESS-10); the shared binary name does not certify v2. The conformance
v2 check passes that request to the adapter. The Claude budget and Codex help probes also inspect
both streams. `tests/harness/opencode-install-test.sh` and `tests/harness/capability-stream-test.py`
are offline fixture evidence, not proof of an upstream installation or a live node.

**S2 no longer has a silent member.** `aider` and `goose` were named in `specs/HARNESS.md` with **no
adapter file**, which is the one state this module forbids: a harness the spec names and the
conformance battery cannot see produces no row at all, so nothing can go red (the S4-style silence,
not a refusal). Both now ship a real `--check`/`--contract` —
`scripts/harness/install-aider.sh:2-17` (documented method `pip install aider-chat` into a venv) and
`scripts/harness/install-goose.sh:2-17` (documented method: a standalone release binary) — and both
refuse `--apply` **by name** until someone measures a ladder and records it in `specs/HARNESS.md`
(`install-aider.sh:103-106`, `install-goose.sh:104-107`). What they are **not** is measured: neither
has a pin, an artefact digest or a measured non-interactive surface, so their conformance `smoke`
column stays `0` and the battery prints a `SKIP` naming what is missing rather than a green row.

**CF-226 — dsh is a real S2 member, not the `deepseek` binary row.** `install-dsh.sh` measures
npm `@deepseek-ai/dsh` / CLI `dsh` at the exact RC `0.2.1-rc.5`, under the user-space prefix
`$HOME/.local/harness/dsh`. Its `--check` is read-only, `--apply` verifies registry integrity and
shasum before download, reads `dsh --version` back, and is idempotent; `--pin-status` re-measures
the RC's registry bytes and names a newer RC before adoption. The adapter accepts the shared §5
CF_* contract, refuses credential values and ambient keys, and reports plugin failures by layer
(package → resolved → enabled → service → tool → permission). A real turn is required to claim
artifact/model evidence; without a credential the adapter prints an explicit `SKIP`/exit 3, never a
simulated PASS. dsh has no crier adapter: the written decision is to defer one, so the node's own
worker is the only current driver and the memory leg remains unwritten. The separate
`install-deepseek.sh` row still probes a binary named `deepseek` and may refuse its unmeasured
`--apply`; it must not be read as saying that dsh does not exist.

**Finding F5-4.** OUTLINE v2 lists M5 as 5 submodules (S1–S5); `docs/UNIT-MAP.yaml` lists 3
(S1–S3). The two structure maps still disagree; the 5-submodule reading is authoritative here.

## 4. Dependencies

**4a. Runtime dependencies**

| Dependency | Version constraint | Where | How absence is detected |
|---|---|---|---|
| python3 | hermes adapter requires **>=3.11,<3.14** (`install-hermes.sh:27-30`, `:108-115`); host python3 is 3.14.9, which the adapter **refuses** | node | `bad "python" "… requires python >=3.11,<3.14; found …"` (`:112`) |
| pinned harness version | per-installer exact pin (`HERMES_PIN=0.19.0`, `GITREINS_PIN=0.17.1`, `CF_CODEX_PIN=0.166.0`, `CLAUDE_CODE_PIN=2.1.318`, `DSH_PIN=0.2.1-rc.5`) | node venv or npm prefix | installed version read back vs pin; dsh's RC bytes are re-measured with `install-dsh.sh --pin-status` before promotion |
| go toolchain | pinned | `install-go.sh` digest-checked | digest mismatch → refuse |
| Node (claude-code) | **>= 22** (`install-claude-code.sh:43` `NODE_MIN_MAJOR=22`) | node | the pin's `engines` requirement |
| Node runtime (kind `node`, CF-003) | **exactly `v22.22.3`** (`install-node.sh` `NODE_PIN`), digest-pinned per arch (`linux-x64` `2e5d1356…`, `linux-arm64` `1c4a9933…`) | node, `$HOME/node-toolchain/<pin>` | `sha256sum` mismatch → `FAIL node_dist`, nothing extracted; a binary whose `--version` is not the pin → `FAIL node` naming what it printed |

**4b. Library contracts**

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `lib.sh` `fetch_verified` | this repo | pinned, digest-checked download, never `curl | sh` | see M0 |
| `harness-vars.sh` | this repo (S5) | CF_* validation: path-only credential, no ambient key, `$HOME`-scoped workdir | a contract loosening re-opens lane contamination |
| `harness-matrix.json` | this repo (`config/`) | `by_family`, `hosts`, `shims`, `default` (`load_matrix`, `:188-216`) | a malformed table → `harness_matrix_invalid` refusal |

**4c. Service contracts** — see §6.

## 5. Settings register

`harness-vars.sh` (S5) is the register for the CF_* set it enforces. `CFV_DECLARED`
(`:28-29`, 12 vars) and `CFV_REQUIRED` (`:31`, 6 vars) define the surface.

| Setting | Default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| `CF_MAX_TURNS` | 40 (`:276`) | integer 1..1000 (`:281`) | turn budget | 0 or >1000 refused; loosening lets a run spin unbounded |
| `CF_TIMEOUT_S` | 1800 (`:277`) | integer 1..86400 (`:287`) | wall-clock per turn | refusal outside range; `install-codex.sh` re-defaults to 300 (see §11) |
| `CF_MODEL` | unset (required in `--contract`) | no spaces (`:225`) | model id | a model id with spaces refused |
| `CF_PROVIDER` / `CF_NAMESPACE` / `CF_LANE` | unset | lowercase `[a-z0-9._-]` (`:226-231`) | lane/namespace naming | an uppercase or symbol name refused |
| `CF_RUN_ID` | unset | `[A-Za-z0-9._:-]` (`:236`) | correlation id | a non-id value refused |
| `CF_BASE_URL` | unset | http(s), **no userinfo** (`:216`, `:219`) | harness endpoint | a URL carrying `user:pass@` is refused (credential-in-URL) |
| `CF_API_KEY_FILE` | unset | a path, mode `[0-7]00` (`:203`) | credential delivery | a VALUE refused; missing/empty file refused; mode 644 refused (`:204`) |
| `CF_API_KEY` + `CFV_AMBIENT_KEYS` (`:33`) | unset | must be **empty** (`:176-185`) | ambient credential ban | a non-empty value refused |
| `CF_WORKDIR` | unset | exists, resolves inside `$HOME` (`:244-249`) | harness write boundary | outside `$HOME` refused |
| `CF_SKILLS_DIR` | unset | a path (`:258`) | skills root | warns (not fails) if the dir does not exist yet (`:260`) |
| `CF_HARNESS_OPTS` | unset | `key=value[,key=value]`, no secret (`:268-271`) | harness-specific options | a secret-shaped value refused |
| `--contract` mode | — | requires all 6 `CFV_REQUIRED` (`:31`, `:313-315`) | acceptance check | a missing required var refused (`dropped:$missing`) |

**Per-adapter installation registers (B12 — the shared CF_* table is not the
entire harness settings surface):**

| Setting | Default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| `NODE_GATEWAY_PORT` (hermes) | `10800` (`install-hermes.sh:23`) | a TCP port | the gateway port the adapter installs against | a wrong port installs against the wrong gateway |
| `HERMES_PIN` (hermes) | `0.19.0` (`:24`) | exact version | the pinned hermes build | a drift installs an unmeasured build |
| `HERMES_PYTHON_BIN` (hermes) | `python3` (`:26`) | a python path | the interpreter the pin runs under | a wrong interpreter breaks the >=3.11,<3.14 gate |
| `CF_CODEX_PIN` (codex) | `0.166.0` (`install-codex.sh:49`) | exact version | the codex pin | drift installs an unmeasured build |
| `SHA256` / `CF_CODEX_SHA256` (codex) | `a0bf572d…` (`:51`) / override at `:428` | a digest | artifact integrity | a wrong digest is refused by `fetch_verified` |
| `DISK_FLOOR_GB` (codex) | `1.0` (`:56`) | GiB | admission floor | a lower floor admits a too-small host |
| `DEFAULT_SANDBOX` (codex) | `workspace-write` (`:57`) | a sandbox mode | codex write boundary | a wider sandbox loosens containment |
| `TIMEOUT_S` (codex) | `CF_TIMEOUT_S` or **300** (`:60`) | seconds | per-turn wall | the codex adapter re-defaults the shared 1800 to 300 |
| `CLAUDE_CODE_PIN` (claude) | `2.1.318` (`install-claude-code.sh:39`) | exact version | the claude pin | drift installs an unmeasured build |
| `CLAUDE_CODE_SHASUM` (claude) | `c11067a3…` (`:40`) | a digest | artifact integrity | a wrong digest is refused |
| `NODE_MIN_MAJOR` (claude) | `22` (`:43`) | Node major | the Node floor | a lower Node violates the pin's `engines` |

**`install-go.sh` (S3) — the Go toolchain installer register (B12; "pinned" was NAME ONLY).** `install-go.sh:7-14` fixes the pin, digests, floor and probe; `:52-81` is the cold-cache module proof:

| Setting | Default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| `GO_PIN` | `go1.26.5` (`:7`) | exact version | the Go toolchain installed | drift installs an unmeasured toolchain |
| `GO_SHA256_LINUX_AMD64` / `_ARM64` | `5c2c3b16…` / `fe4789e9…` (`:8-9`) | a digest | artifact integrity per architecture | a wrong digest is refused by `fetch_verified` |
| `GO_DISK_FLOOR_GB` | **1** (`:10`) | GiB | install admission floor | a lower floor admits a too-small host |
| `GO_PROBE_MODULE` / `GO_PROBE_VERSION` | `rsc.io/quote` / `v1.5.2` (`:11-12`) | a module@version | the cold-cache module proof | a changed probe no longer proves a working toolchain |
| `MODE` | `--check` (`:13`, first positional) | `--check` / `--apply` | what the run does | any other arg → usage, exit 2 (`:18-20`) |
| `GO_INSTALL_ROOT` | `$HOME/go-toolchain` (`:14`) | a path | where the pinned toolchain lives | a wrong root installs/checks the wrong toolchain |
| module proof `timeout` | **30 s** (`:73`) | seconds | the `go mod download` proof ceiling | too short fails a slow-but-valid proxy |
| module proof GOPROXY | `$GOPROXY` or the toolchain's own `env GOPROXY` (`:53-57`) | a URL | which proxy resolves the probe | a misconfigured proxy fails the proof |
| `GO_DL_BASE` | `https://go.dev/dl` (`:138`, `url="${GO_DL_BASE:-https://go.dev/dl}/$archive"`) | a URL | the toolchain download mirror | a wrong mirror fails `fetch_verified` on every install |

**Resolver controls (B10).** `harness_resolve.py:327-372` exposes seven
selection/refusal controls; the shared CF_* table and the installer tables above are not the whole
module surface:

| Setting | Default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| `--explain` | none, **required** (`:328-332`) | a model id | which model to resolve | omitted → argparse exits 2 |
| `--lane` | None (`:333`) | a lane name | lane-scoped resolution | a wrong lane reads the wrong lane config |
| `--lane-class` | None, derived (`:335-339`) | `foreman` / `satellite` | overrides the lane-class derivation | a forced `foreman` on a satellite changes the refusal path (non-hermes foreman refused, `:284`) |
| `--directive-harness` | None (`:341-345`) | a harness name | pins the harness above everything (directive > lane > matrix) | forces a harness the matrix would refuse |
| `--lane-harness` | None (`:346-350`) | a harness name | pins the harness above the matrix | overrides the matrix for one lane |
| `--node-harnesses` | None (`:351-356`) | comma list | restricts the selection to installed harnesses | selection must be one of them, else refused |
| `--shims` | None (`:357-361`) | comma `family=name` / `harness:family=name` | shim bindings | a wrong binding routes a family to the wrong harness |
| `--matrix-file` | None (`:362-366`) | a path | the harness table (default `DEFAULT_MATRIX_FILE`) | a wrong file reads the wrong matrix |

**Node runtime and shared module cache (S3, CF-003):**

| Setting | Default | Range | Governs | What breaks if changed |
|---|---|---|---|---|
| `NODE_PIN` | **`v22.22.3`** (`install-node.sh:26`) | one released Node version | the runtime every `node`-kind node gets | the layer grades whatever version the archive yields; a different pin needs its digests re-pinned |
| `NODE_SHA256_LINUX_X64` / `_ARM64` | `2e5d1356…` / `1c4a9933…` | 64 hex per arch | archive integrity | a mismatch is `FAIL node_dist`; nothing is extracted |
| `--root` | `$HOME/node-toolchain` (`NODE_INSTALL_ROOT`) | an absolute path | where the pin is installed; **an explicit root makes `--check` a scoped question** (a PATH runtime cannot answer it) | a wrong root installs beside the runtime the layer grades |
| `--tarball` + `--sha256` | none | a local archive + its digest | the fixture seam; the digest is still verified | either alone is refused (`--tarball needs --sha256`) |
| `gomodcache.py --dir` | none (required) | a directory | which cache is seeded/sealed/checked | a wrong dir seals the wrong tree |
| `gomodcache.py seal` | — | — | removes **every** write bit and records bytes/entries | an unsealed cache drifts per node back toward 656 MB |
| `NODE_GOMODCACHE` | none | an absolute node path | whether layer 10 admits a shared cache | unset → `WARN go:modcache` (private cache), declared-but-unsealed → counted FAIL |

**Predicate correction (F0-6, owned here).** The credential-mode predicate is `[0-7]00`
(`harness-vars.sh:203`) — modes `000..700` pass — while the refusal message (`:204`) claims "a key
file must be 600". The ambient-key checks (`:176`, `:181`) test **non-emptiness**, not set-ness:
`CF_API_KEY=""` is accepted.

## 6. Contracts in and out

Canonical IDs come from the 31-entry Part IV §IV.2.4 registry. Legacy source tables
below remain coverage only; CT-17 qualification is the exact §16.4 union. M5-C2 is
a retained local service-start observation, not a new wire ID; CT-19 owns inference.
The external consumer is qualified through observable behavior, not an in-repo function.

| ID | Peer | Direction | Producer `file:function` | Consumer `file:function` | State |
|---|---|---|---|---|---|
| CT-17 | conformance battery | in | `tests/harness-conformance.sh` (the battery, per-leg rows) | **external** — the operator/board reads the leg verdicts as FACT-08 certification; no in-repo code consumer | **UNVERIFIED** — not run (needs a live node) |
| M5-C2 | gateway | out | `install-hermes.sh:352` `hermes serve` | **rumour — one side only** (the node gateway on `:10800`, a port/service, not a function) | **UNVERIFIED** — a port/service is not a `file:function`; the "works" state was inherited, not measured (B22) |
| M5-C3 | adapter caller — battery `leg_check`, layer 20, operator | out | `scripts/lib.sh:24` `verdict()` — one verdict line decided by row counts (`FAIL (n)` exit 1 / `UNVERIFIED` exit 3 / `PASS` exit 0); `warn()` (`lib.sh:8`) counts the rows it prints, so `FAILED` is not the only counter | `tests/harness-conformance.sh` `leg_check` (reads the `  FAIL` rows and the adapter's exit status), `scripts/project-node.sh:609-621` (layer 20 folds the adapter's FAIL rows into `NODE: FAIL (n)`), `tests/selftest.sh` §59 (asserts the line by name for three row counts) | **PASS** — measured 2026-11-07, §59 arms (a)–(f); the contract is `specs/HARNESS.md` "The verdict line", and the note-versus-`WARN` classification of individual rows (CF-384) is its "Which conditions are notes, and which are WARNs", held by `tests/harness/codex-install-test.sh` arms B5/B5b |

CT-17 is a boundary contract: the consumer (operator/board reading the verdicts) has no in-repo
`file:function`, so "producer named + consumer marked external" is the honest terminal state.

M5-C3 is the adapter's contract with whoever invoked it, and it is a row-count contract, not an
exit-code convention: `PASS` requires every row `PASS`, one `WARN` row makes it `UNVERIFIED` with
exit 3, and any `FAIL` row makes it `FAIL (n)` with exit 1. Before CF-141 the line was computed from
`$FAILED` alone, so `OPENCODE: PASS` was printed beside two `WARN` rows under a banner that already
said `UNVERIFIED adapter` — the adapter's own summary contradicted its own rows.

**Note versus `WARN` is part of this contract (CF-384).** Because a `WARN` row decides the verdict,
each row's class is a substantive decision made at the adapter call site, never a change to
`verdict()`: a row whose *absence* stops a run of the surface the adapter is measured on stays a
`WARN` (it moves the line), while a row reporting an environment FACT the adapter does not need is a
`..` note (it carries its text and moves nothing). `scripts/lib.sh` is untouched, so every other
adapter's `WARN` rows still produce `<LABEL>: UNVERIFIED` with exit 3. The codex adapter decided two
rows: `app_server` present is a note — crier@6422c851 runs exec mode and `grep -rn app-server` over it
returns nothing, so a sidecar existing cannot block a dispatched run (its absence stays a named
`FAIL`); and `auth` with an ambient `$HOME/.codex/auth.json` is a note — a credential exists and a turn
can authenticate — while `auth` with **neither** a key file nor a host login stays a `WARN`, because
an unattended turn genuinely cannot authenticate. The decision table is `specs/HARNESS.md` "Which
conditions are notes, and which are WARNs"; `tests/harness/codex-install-test.sh` arms B5 (pinned
binary + host login → `CODEX: PASS`, exit 0, both rows printed as notes, zero `WARN` rows) and B5b
(the same binary, no credential surface → `WARN auth` + `CODEX: UNVERIFIED`, exit 3) hold the
distinction in both directions, so the `PASS` is not reachable by deleting the warning mechanism.

## 7. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| shell parse | `for f in scripts/harness/*.sh; do bash -n "$f"; done` | exit 0 | 2026-11-06 | PASS (in 20/20 sweep) |
| adapter verdict vocabulary | `bash tests/selftest.sh` (section 59, arms a–c) | one stub adapter, three row counts: `WARN` → `STUB: UNVERIFIED` exit 3 (never `PASS`), `FAIL` → `STUB: FAIL (1)` exit 1, all-`PASS` → `STUB: PASS` exit 0 | 2026-11-07 | **PASS** (fixture) |
| aider/goose ship an adapter that refuses to install (CF-006, S2) | `bash tests/selftest.sh` (section 60) | in a scratch `$HOME`: each adapter's `--check` prints at least one named row and exactly one `<LABEL>: …` verdict line that equals what its own `PASS`/`WARN`/`FAIL` counts require; each `--apply` exits 1 with a `FAIL apply — refused` row naming the unmeasured ladder, that same derived verdict, and zero executable files placed | 2026-11-08 | **PASS** (fixture) |
| verdict on the real adapters | `bash tests/selftest.sh` (section 59, arms d–f) | `install-opencode.sh --check` on the row's PATH stub → `OPENCODE: UNVERIFIED` exit 3 with two `WARN` rows, while pre-fix `d4f2600` on the same stub prints `OPENCODE: PASS` exit 0 (red control); each of the six adapters' verdict line equals the one its own `FAIL`/`WARN` counts require; an unsupported interpreter ends `FAIL python — …` + `HERMES: FAIL (1)` exit 1 | 2026-11-07 | **PASS** (fixture) |
| codex note-versus-`WARN` classification (M5-C3, CF-384) | `bash tests/harness/codex-install-test.sh --hermetic` (arms B5, B5b) | pinned binary + host login → `CODEX: PASS` exit 0, `app_server` and `auth` printed as `..` notes with their text, zero `WARN` rows; the same binary with no credential surface → `WARN auth — no CF_API_KEY_FILE and no $HOME/.codex/auth.json` + `CODEX: UNVERIFIED` exit 3, no `FAIL` row (so the exit is the WARN, not a failure) | 2026-11-07 | **PASS** (fixture, 48 passed / 0 failed / 1 skipped) |
| occupied-port auth gate | `bash tests/selftest.sh` (section 55, arm E) | occupied `:10800` + no `dashboard.basic_auth` -> exit nonzero with the named `FAIL  port` row and no `PASS port`/`PASS status_probe`/`HERMES: PASS`; occupied + valid block keeps both PASS rows | 2026-11-07 | **PASS** (red pre-fix run in `docs/audits/code-factory-CF-192.probe.txt`) |
| python compile | `python3 -m py_compile scripts/harness_resolve.py` | exit 0 | 2026-11-06 | PASS |
| harness resolve unit | `python3 tests/test_harness_resolve.py` | pass | 2026-11-06 | **PASS** (28 tests, rc 0) |
| conformance legs | `bash tests/harness-conformance.sh --only codex` | codex `check`, vars, node fixture, smoke and explicit live-node status rows; node fixture must prove `project-node.sh --apply --harness codex` created a measured manifest and must keep tampered/absent/unmeasured red controls | 2026-11-10 | **PASS** (fixture: codex node created; live node **UNVERIFIED/SKIP**) |
| node pin fixture | `python3 tests/test_node_provisioning.py` (`InstallNode`) | `--check` red before install; `--apply` installs, `node --version` reads back `v22.22.3`; second `--apply` changes nothing; a wrong digest installs nothing; a binary printing `v22.22.2` fails the readback | 2026-11-07 | **PASS** (fixture archive; the real download is the digest-pinned `https://nodejs.org/dist/v22.22.3/…`, hashed after download when the pin was written) |
| owned-runtime precedence | `bash tests/selftest.sh` §58 | `PASS tool:node — $HOME/node-toolchain/current/bin/node (v22.22.3)` with the fixture home's own runtime, not the host's PATH node | 2026-11-07 | **PASS** (fixture) |
| sealed shared cache | `python3 tests/test_node_provisioning.py` (`GoModCache`) | sealed cache builds with `GOPROXY=off` and adds **0 bytes**; a cold cache cannot; an unseeded module is refused with `permission denied` | 2026-11-07 | **PASS** (`MEASURED shared GOMODCACHE 2097910 bytes; sealed rebuild added 0 bytes`) |

## 8. Metrics

**RED — none (absence-proved).** No harness installer or resolver emits counters or
gauges — `grep -nE 'prometheus|Counter|Gauge|Histogram|/metrics' scripts/harness/*.sh
scripts/harness_resolve.py scripts/install-gitreins.sh` → 0 matches. Install count, pin-drift count
and conformance pass rate are answerable only by reading the leg rows.

## 9. Log lines (verbatim)

**Scope (B09, measured).** `grep -rcE '\b(ok|bad|warn|note)\s+"' scripts/harness/` sums to **215** helper call sites across the six installer scripts plus `harness-vars.sh`; `install-gitreins.sh` and `install-go.sh` add further rows. The 4 rows below are the evidentiary refusal/pin/foreman rows; the generic per-row helper surface is not inventoried one-per-site — the uncovered count is a named RED on this field.

| Level | Line | Emitted when | Kind |
|---|---|---|---|
| — | `CONTRACT: REFUSED (%s)` (`harness-vars.sh:66`) | any CF_* refusal | evidentiary |
| — | `installed ${ver:-nothing} but the pin is $PIN (log $log)` (`install-gitreins.sh:105`) | installed version != pin | evidentiary |
| — | `FAIL harness_foreman_requires_hermes: lane=<L> harness=<H>` (`harness_resolve.py:284`, surfaced by `print(f"FAIL {exc}")` at `:388`) | a bound foreman lane selected non-hermes | evidentiary — `:388` is the print, `:389` is `return 2` (A) |
| — | `  PASS  %s — %s` / `  FAIL  %s — %s` (`lib.sh:6-7`) | every installer row | descriptive (see M0 F0-4) |
| — | `  FAIL  port — listening on :10800 (not started by this adapter; auth unverified — a public bind needs dashboard.basic_auth in ~/.hermes/config.yaml — <reason>)` (`install-hermes.sh:318`) | an occupied gateway port whose `~/.hermes/config.yaml` parses to no non-empty `dashboard.basic_auth` | evidentiary — counted, so the layer ends `HERMES: FAIL (n)` (CF-192) |

## 10. Failure modes, indications and recovery

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Version drift | `installed X but the pin is Y` | a clean install | re-run `--apply` at the pin |
| Auth gate skipped | **fixed (CF-192)** — an occupied `:10800` with no `dashboard.basic_auth` now emits one counted `FAIL  port — listening on :10800 (not started by this adapter; auth unverified — …)` row and the layer ends `HERMES: FAIL (n)`; before the fix the occupied-port branch printed `PASS port` / `PASS status_probe` / `HERMES: PASS` and exited 0 without ever evaluating the block | a gated install: the SAME port with a non-empty `dashboard.basic_auth` still prints `PASS port — listening on :10800` / `PASS status_probe — /api/status -> 200`, so a gateway a previous `--apply` started is not called a failure | write the block (`scripts/node_gateway_auth.py <config.yaml> <password-file>`, or layer 20's staging in `project-node.sh:448-497`) and re-run `--apply`; the port row turns PASS on the next run |
| Interpreter out of range | `hermes-agent … requires python >=3.11,<3.14` | a python absence | install a 3.11–3.13 interpreter |
| Node runtime absent or wrong | `FAIL tool:node — missing — kind node needs a Node runtime …` (check) / `FAIL node — <path> reports 'vX' — want v22.22.3` (a lying binary) | a graded pass `PASS tool:node — $HOME/node-toolchain/current/bin/node (v22.22.3)` | `project-node.sh --apply` runs `install-node.sh`, which refuses a digest mismatch instead of extracting; `install-node.sh --check --root <r>` answers the scoped question |
| Shared cache writable or grown | `FAIL modcache_seal — … writable path(s)` / `FAIL modcache_manifest — ±N bytes since seal` | `PASS modcache_seal — … read-only (no write bits, owner included)` | `gomodcache.py seal` on the prewarm host; a node never needs write access to a cache it does not own |
| Unsupported adapter claims support | `install-deepseek.sh` refuses `--apply` with "no measured deepseek install ladder"; `install-pi-agent.sh` refuses it only when `PI_FIXTURE_DIR` is unset (`:132-134`) | a certified adapter | treat `install-deepseek.sh` as check-only until a ladder is measured (F5-3); the pi adapter's fixture ladder is measured, but its live upstream install and live turn are not. Neither statement applies to the separate measured `dsh` package adapter |
| Worker seat not in registry | `deepseek-v4-flash@deepseek-foreman` absent | a valid seat | **OPEN** — CF-376 |

## 11. Limits and margins

- The resolver is fail-closed: an unknown harness, an uninstalled selection, or a non-hermes
  foreman all refuse with a named reason and exit 2 (`:46-56`, `:387-389`) — but it is only
  reachable when invoked directly (F5-2).
- **Adapter capability matrix (F5-3):** the installers are not uniform.
  - `install-hermes.sh` — installs and certifies at `HERMES_PIN` 0.19.0; python >=3.11,<3.14.
  - `install-codex.sh` — installs at `CF_CODEX_PIN` 0.166.0; sources `harness-vars.sh`
    **conditionally** (`:47`), re-implements its own validator and credential predicate (`600|400`),
    and re-defaults `CF_TIMEOUT_S` to 300 (M0 F0-5).
  - `install-claude-code.sh` — sources `../lib.sh` (`:36`), **not** `harness-vars.sh`; documents
    its own CF_* handling inline; adds `--turn` (`:60-115`), an npm `--prefix` install, Node >=22
    (the pin's `engines`), isolated `--setting-sources local`/`--bare`; its `CF_MAX_TURNS` is
    "passed as a CLI flag only if the pin's `--help` advertises it (2.1.318 does not); otherwise
    recorded as **not enforced**".
  - `install-opencode.sh` — **UNVERIFIED**, `--apply` refused (`:92-93`); sources
    `harness-vars.sh` (`:15`).
  - `install-deepseek.sh` — **`--apply` refused** (`:95-97`): "no measured deepseek install ladder";
    sources `harness-vars.sh`; this is the binary named `deepseek`, not DeepSeek's `dsh` harness.
  - `install-dsh.sh` — **measured RC ladder** (`DSH_PIN=0.2.1-rc.5`): npm integrity + shasum
    provenance, user-space prefix, `dsh --version` readback, idempotent apply, and per-layer
    diagnosis; `--pin-status` is the required RC re-measurement. Its crier adapter is explicitly
    deferred, so only the node worker drives it today.
  - `install-pi-agent.sh` — **fixture-backed `--apply`**, refused only without a fixture (`:132-134`:
    "refused — no measured upstream ladder; set PI_FIXTURE_DIR for the hermetic fixture-backed
    ladder"); with `PI_FIXTURE_DIR` set it publishes the pinned tree under
    `$HOME/.local/harness/oh-my-pi/18.16.0` and reads the package, bun and pi versions back
    (`:153`), so the live upstream install and the live turn stay **UNVERIFIED** while the fixture
    ladder is measured (CF-228); sources `harness-vars.sh` (`:10`).
  - `install-aider.sh` — **`--apply` refused** (`:103-106`): the aider ladder is unmeasured, and the
    documented method (`pip install aider-chat` into a venv) is printed as a `..` note beside a real
    `--check`; sources `harness-vars.sh` (`:21`). Closes CF-006's last silent row for aider.
  - `install-goose.sh` — **`--apply` refused** (`:104-107`): same shape, documented method a
    standalone release binary; sources `harness-vars.sh` (`:22`). Neither adapter downloads anything,
    so no network call exists in any mode.

## 12. Cross-references

- F2 PROVISIONING certifies what this module installs. CF-003 adds the two toolchain contracts that
  flow through this module: the `node` kind's pinned runtime (`install-node.sh`, graded by layer 10
  from the owned path) and the sealed shared `GOMODCACHE` (`gomodcache.py`, admitted by the
  `go:modcache` row). Neither is part of the harness binary; both are part of the node the harness
  runs on, which is why M5's S3 owns them.
- M0 SHARED CONTRACT supplies `fetch_verified` (S5 `harness-vars.sh` is owned here, not M0).
- M2 DISPATCH passes the CF_* set to the resolved harness at run time (via `node.json`, not the resolver).
- M3 REPOSITORY owns the hook behaviour; `install-gitreins.sh` (S3) is the installer.
- M8 SAFETY owns the safety-policy requirements for the optional Terminal Jail layer and the
  cleanup policy for caches/job dirs; **package uninstall is an M5 lifecycle operation**, not an
  M8 cleanup class. The future Task Router, not M5, owns harness selection.

## 13. Evidence of record

- Code read: `harness-vars.sh` (318), `harness_resolve.py` (400), `install-hermes.sh` (375),
  `install-gitreins.sh` (180), `install-codex.sh` (`:47-60, 425-430` + settings), `install-claude-code.sh`
  (`:34-115` + settings), `install-deepseek.sh` (101), `install-pi-agent.sh` (113), `install-opencode.sh` (98),
  `install-aider.sh` (110), `install-goose.sh` (111);
  `project-node.sh:448-510`.
- **CF-003 slice, read 2026-11-07:** `scripts/install-node.sh` (whole file — pin, per-arch digests,
  `--check`/`--apply`, owned `current` symlink, version readback, fixture seam),
  `scripts/gomodcache.py` (whole file — `init`/`seed`/`seal`/`unseal`/`check`/`measure`/`env`/`wire`),
  `scripts/project-node.sh:390-424` (node kind), `:488-505` (`go:modcache`), `tests/test_node_provisioning.py`
  (`InstallNode`, `GoModCache`), `tests/selftest.sh` §58.
- Board rows: CF-150, CF-192, CF-372 (complete), CF-376, CF-380, **CF-003**.
- **Findings:**
  - **F5-1** (carried) — `install-hermes.sh:108-115` refuses anything outside >=3.11,<3.14.
  - **F5-2** — `harness_resolve.py` has no production caller; runtime selection is
    `node-bus-worker.py:412-414,459-469` / `dispatcher.py:260`.
  - **F5-3 (superseded blanket refusal)** — deepseek remains apply-refusing;
    pi accepts only its explicit repository fixture ladder and refuses without
    PI_FIXTURE_DIR. §7 fixture evidence does not certify a live upstream pi install.
    The older statement that every pi apply refuses is retired (P5-B-39).
  - **F5-4** — UNIT-MAP (3) vs OUTLINE (5) submodule split.
  - **F5-5** (B02) — the "no production installer caller" claim was false:
    `project-node.sh:498` computes `install-$HARNESS.sh` and `:508-510` invokes it; the literal
    grep missed the computed path. The installers are unit-invoked (by the operator-invoked
    provisioning entry).
  - **F5-6** (CF-150) — `project-node.sh` layer 20 now stages `dashboard.basic_auth`
    **before** the harness adapter runs (`:448-497`, CF-150): the hermes adapter refuses a public
    bind unless `~/.hermes/config.yaml` parses to a non-empty `dashboard.basic_auth`, and no stage
    in the create path wrote that block, so the documented path could print every other row and
    still end `NODE: FAIL`. The block runs `node_gateway_auth.py` to write the block and a
    mode-600 password file, or (in `--check`) a shell-builtin presence scan; it refuses to overwrite
    a non-`basic_auth` dashboard block. `node-create.sh:29` stages `node_gateway_auth.py` alongside
    the harness adapter. This is M1's producer invoked from M5's layer — a cross-module dependency.
  - **F5-7** (new, CF-192) — the occupied-port branch used to certify a public bind without auth.
    When anything already listened on `:$PORT` (`install-hermes.sh:302`), the adapter printed
    `PASS port` / `PASS status_probe` and **never evaluated `dashboard.basic_auth`**, so `--apply`
    ended `HERMES: PASS` with exit 0 on a no-auth config — a `127.0.0.1` probe answers on an
    unauthenticated `0.0.0.0` gateway too, and the refusal lived only in the not-listening branch
    (`:351`). The branch now calls `check_public_bind_auth` (the same single parser, not a second
    one) and emits one counted `FAIL port — listening on :10800 (not started by this adapter; auth
    unverified — …)` row (`:318`) when the block is absent; an occupied port WITH a valid block keeps
    both PASS rows, so a gateway a previous `--apply` started is still certifiable. Witness:
    `tests/selftest.sh` section 55 arm E (red arm + auth-carrying green arm); red and fixed
    transcripts in `docs/audits/code-factory-CF-192.probe.txt`.
  - **F5-8** (new, CF-003) — S3 listed only `install-go.sh` as a toolchain and layer 10 graded a
    `node` runtime it never installed: `PASS tool:node` was reachable off an ambient PATH binary
    (so a node could certify a runtime it did not own, and a fresh node with none failed 11 Go tests
    that shell out to it). `install-node.sh` (pin `v22.22.3`, per-arch digest, version readback) and
    owned-path precedence close the mechanism half; the pinned archive was downloaded and hashed
    when the pin was written (31,059,464 bytes, `2e5d1356…`), and the fixture proves the ladder, not
    the download. The sealed-cache half is F1-8 (M1).

## 15. Normative Hermes lifecycle and conformance contract (P3-12, P3-15)

Hermes with the pinned Oh My Hermes operating layer is the MVP harness. A Bunker profile declares the image, persistent home/cache mounts, project worktree, network policy and resource limits. The harness installer receives `profile_id`, `harness_version`, `artifact_digest`, effective settings and credential references; it returns an operation id, state, measured versions, paths and readiness checks. A fresh image-backed execution does not retain rootfs changes; persistent state is mounted explicitly.

The lifecycle is `ABSENT → INSTALLING → INSTALLED → CONFIGURED → RUNNING → DRAINING → STOPPED → REMOVED`, with `DEGRADED` and `ROLLBACK_REQUIRED` recovery states. Each transition is idempotent by `(node_id, harness_version, operation_id)`. Upgrade drains active sessions, snapshots configuration, applies a migration, reads back the effective settings and re-certifies before admission. Failed or partial installation rolls back only owned artifacts and leaves the previous certified version available; uninstall preserves required evidence and revokes credentials.

The conformance result uses `schema_version: cf.harness-conformance.v1` with the complete fields and required leg union in §16.4, including local/remote memory and credential revocation. A missing live measurement is `UNVERIFIED`, not PASS. Terminal Jail remains optional and disabled by default; when enabled, covered execution refuses if the guarded executor or policy is unavailable and has no unguarded fallback. DuckBrain memory uses the shared logical namespace; harness activity does not equal acceptance or publication.

Required metrics cover lifecycle operations, pin/digest drift, install/upgrade/rollback outcomes, active-session drain, conformance age, leg failures and effective-setting divergence. M5 owns collection and readout; M8 owns baseline safety policy. Acceptance cases cover a wrong digest, a fresh-rootfs restart, a drained upgrade, a missing guarded executor, a revoked credential and a successful end-to-end Hermes turn.

## 16. P5 resident supervisor and qualification protocol

This section resolves P5-B-07/28/29/30. It specifies new Factory interfaces, not
undocumented commands of the upstream Hermes binary. M1 §17's release lock pins
both the Factory adapter and its tested native-Hermes mapping. Until that lock and
live conformance exist the runtime is UNVERIFIED and activation refuses.

### 16.1 Boot, invocation, status and cancellation

The Bunker init launches exactly
`$HOME/.local/libexec/cf-resident --protocol cf.supervisor.v1 --state $HOME/.node/execution`
as the Bunker UID, cwd HOME, umask 077, after the persistent HOME mount. No shell
expansion of request data occurs. A lifetime flock rejects a second supervisor.
Boot replays the journal, validates release/config/fence/binding, discovers outstanding
native runs, and only then starts the signed Crier admission receiver. Failed recovery
serves status with admission=false; it does not discard prior attempts.

The supervisor exposes a mode-0600 AF_UNIX socket `.node/execution/control.sock`.
Peer SO_PEERCRED must match the node UID. Each request is one UTF-8 JCS object plus
LF (maximum 1048576 bytes): `{schema_version:"cf.supervisor.v1",request_id:ID,
verb:submit/status/cancel/drain/resume,input:object}`. Submit input is the complete
CT-02 or CT-05 outer envelope; status input is `{execution_key:SHA|null}` (null lists
all); cancel is `{execution_key:SHA,control_id:ID,expected_state_version:PosInt,
reason:Text}`; drain is `{operation_id:ID,deadline_s:integer[1,600]}`; resume is
`{operation_id:ID,expected_generation:PosInt}`. Responses use Part IV ResponseBody.
Submit returns the durable handle and duplicate flag; status returns journal records
with execution_key, native_name, state, state_version, process_instance_id,
native_session_id (ID or null), result_ref (EvidenceRef or null). Socket command
receipt is not an execution verdict. Cancellation uses the M2 state CAS and exact
boot/start/session identity before TERM/KILL; PID reuse never authorizes signaling.

The launch adapter invocation is
`$HOME/.local/libexec/cf-hermes --protocol cf.native.v1 --execution-key <SHA>`.
It receives one `cf.native-input.v1` JCS object plus LF on stdin: schema_version,
role (`foreman` or `worker`), execution_key, brief (BriefInput), brief_digest,
workspace (Workspace), effective (EffectiveSettings), owner_fence (Fence).
The supervisor creates the worktree at the exact Workspace base object, rejects
symlink escape, sets cwd to its absolute realpath and connects stdin by pipe,
not a quoted `-q` shell argument. The native adapter verifies brief_digest before
calling its pinned upstream entry point. The foreman input contains the admitted
snapshot/seed and immutable task_scope; worker input is the exact CT-05 brief.

Adapter stdout is newline-delimited closed records, at most 1048576 bytes each,
with `schema_version:"cf.native-event.v1",execution_key:SHA,seq:PosInt,
type:started/progress/result,error:Error|null,data:object`. started data is
`{native_session_id:ID,process_instance_id:ID}`; progress data is
`{turns:UInt,tokens:UInt,elapsed_ms:UInt}`; result data is the CT-04 body for a
worker or CT-06R body for a foreman. Exactly one result is permitted, sequences
increase from one and IDs match stdin. Human output is captured as a separate
bounded artifact, never parsed as result JSON. stderr is redacted diagnostic text,
rotated at 10485760 bytes with SHA references. Missing/duplicate/conflicting result,
invalid framing or exit-before-result is UNKNOWN_RESULT. Exit 0 alone never passes.
The supervisor fsyncs streams and journal evidence before acknowledging a terminal
result. Native session discovery and gated startup follow M2 §15.2.

### 16.2 Effective settings and enforcement

The six unconditional CF variables are CF_MODEL, CF_PROVIDER, CF_WORKDIR,
CF_NAMESPACE, CF_RUN_ID and CF_LANE (source: `scripts/harness/harness-vars.sh:28-31`).
The target requires them from the authenticated directive, never ambient host state.
CF_MODEL is a nonempty registry model string <=256 bytes; provider/lane/namespace/run
are IDs. CF_RUN_ID maps to admission.run_id, not corr_id. CF_WORKDIR is the validated
Workspace absolute realpath. CF_BASE_URL is the registered HTTPS proxy endpoint;
CF_API_KEY_FILE is the assigned proxy capability file; both are mandatory in the
resident MVP even though optional for historical offline adapters. Its mode is
exactly 0600, owner=node UID, regular file, no symlink, nonempty, unexpired; 000,
0400 and 0700 are refused. The key is read inside the adapter, never argv or stdout.

Optional values: CF_SKILLS_DIR is the immutable seed generation's skills directory;
CF_MAX_TURNS defaults 40 and is integer 1..10000; CF_TIMEOUT_S defaults 1800 and is
integer 1..86400 seconds per model turn, not whole attempt; CF_HARNESS_OPTS defaults
empty and the MVP permits no nonempty options (`UNSUPPORTED_SETTING`). A later
release may enumerate options in its signed capability schema, never arbitrary flags.
The adapter environment is allowlisted: HOME, USER, LOGNAME, PATH (owned release
binaries plus /usr/bin:/bin), LANG=C.UTF-8, TZ=UTC, TMPDIR (private attempt scratch),
XDG_CONFIG_HOME/XDG_DATA_HOME/XDG_CACHE_HOME under persistent HOME and the declared
CF variables. Provider keys, proxies, inherited shell options and arbitrary PYTHONPATH
are cleared. Credentials are only assigned references/files.

EffectiveSettings is `{model:Text,provider:ID,base_url:HTTPSURL,credential_ref:ID,
namespace:ID,run_id:ID,lane:ID,skills_digest:SHA,max_turns:integer[1,10000],
turn_timeout_s:integer[1,86400],attempt_timeout_s:integer[1,86400],
cpu_millis:PosInt,memory_bytes:PosInt,max_output_bytes:PosInt,
network_policy_digest:SHA,release_lock_digest:SHA}`. Requested limits may only
narrow policy: effective value is the minimum for the same unit of requested and
pinned policy limits; attempt time is additionally bounded by remaining round wall
time. Worker-attempt slot budget is checked separately, never compared with seconds,
bytes or turn counts. A literal zero refuses. Supervisor enforces
attempt wall on monotonic elapsed time and cgroup v2 CPU/memory limits; adapter
enforces max turns and each model-call deadline. Output budget closes capture and
terminates with OUTPUT_LIMIT. Unsupported enforcement or inability to read back
settings is LIMIT_UNSUPPORTED, before release. CF_MAX_TURNS/CF_TIMEOUT_S map to
max_turns/turn_timeout_s; attempt_timeout_s is separate (default 1800 s). Readback
returns the entire effective object and digest, and requested values above policy
are reported as narrowed. Native settings differing from that object refuse with
EFFECTIVE_SETTING_MISMATCH; an exit-0 version string is not readback.

### 16.3 Lifecycle transactions

Lifecycle mutation is `cf.harness-operation.v1` with operation_id, idempotency_key,
node_id (IDs), action (`install`, `configure`, `start`, `stop`, `restart`, `upgrade`,
`rollback`, `remove`), expected_generation (UInt), release_lock_ref (EvidenceRef),
config_ref (EvidenceRef), force_cancel (boolean, default false). Authority checks
node scope; the journal commits intent, resulting state and response before ACK.
Same key/digest replays; changed digest conflicts. The release-owned artifact manifest
lists relative paths, modes and digests; deletion never uses unconstrained globbing.

| Operation / precondition | Transition and recovery |
|---|---|
| install / ABSENT | INSTALLING→INSTALLED after verified immutable version directory; failure restores ABSENT and preserves diagnostic evidence |
| configure / INSTALLED or STOPPED | CONFIGURED after schema-versioned config validation and atomic generation pointer; missing migration refuses |
| start / CONFIGURED or STOPPED | RUNNING only after supervisor readiness readback; failure DEGRADED, no new admission |
| stop / RUNNING or DEGRADED | DRAINING, reject new work, query all nonterminal execution records; wait <=300 s, then STOPPED only when none remain |
| restart / RUNNING, CONFIGURED or STOPPED | stop/drain if needed, then start same certified generation; no generation reset |
| upgrade / RUNNING, CONFIGURED or STOPPED | drain, snapshot config/store plus backup receipt, install inactive new release, migrate copy, validate; atomic pointer switch is commit point; certify before admission |
| rollback / failed pre-write upgrade | switch to retained prior snapshot and certify; after new-schema writes, ROLLBACK_REQUIRED forbids old binary and requires pinned reverse migration or isolated restore |
| remove / STOPPED | revoke only harness-owned capabilities, verify denial, delete only owned release paths; REMOVED retains node identity, board, sessions/evidence and pending memory |

Drain timeout without force_cancel returns DRAIN_TIMEOUT and DEGRADED with active
handles intact. An authorized force_cancel follows M2 cancellation and requires
quiescence before migration/removal; STOP_UNKNOWN blocks both. Runtime crash or failed
readiness takes RUNNING→DEGRADED and disables admission. Recovery replays native
journals, reads effective settings and recertifies before RUNNING. DEGRADED can stop,
repair/configure or resume the same generation; ROLLBACK_REQUIRED admits only recovery.
REMOVED→ABSENT requires a new install operation after retained-state discovery.
Node-wide forge/Crier/Bunker/memory identities belong to M1 and are not silently
revoked by harness removal. Revocation of proxy/session capabilities is recorded.

### 16.4 One conformance union (CT-17)

`cf.harness-conformance.v1` has schema_version, run_id, node_id, profile_id,
release_lock_digest, effective_digest, observed_at, expires_at, legs and support_state.
Each leg is `{name:Enum,mode:live/fixture,status:PASS/FAIL/UNVERIFIED,
evidence_refs:EvidenceRef[],observations:Text,error:Error|null}`. Required names are
`executable-identity`, `install-check`, `effective-settings`, `workspace-boundary`,
`network-policy`, `resource-limits`, `smoke-turn`, `result-delivery`, `cancellation`,
`restart-persistence`, `memory-local`, `memory-remote`, `credential-revocation`.
Memory-local includes write/read exact bytes after restart; memory-remote includes
cross-host read by another authenticated controller after sync. Fixture mode proves
wiring only and never substitutes for any required live leg. Optional `terminal-jail`
becomes required when enabled; failure never falls back to an unguarded executor.

support_state is SUPPORTED only when every required live leg PASSes; any FAIL yields
UNSUPPORTED, otherwise UNVERIFIED. Missing/duplicate leg names refuse the report.
Validity is at most 86400 s, bounded by credential expiry; any release/config/network/
mount/fence change invalidates it. M1 §17.4 owns readiness after temporary remote
outage, not a permanent waiver of the memory leg. All conformance/check warnings
reduce to UNVERIFIED; action-only advisory warnings may preserve action success but
cannot certify a check. Shared memory export currently lacking implementation therefore
blocks live support. Telemetry is M0 §16.1 with lifecycle/conformance events.

## RED field count: 4 (Metrics §8 — absence-proved; §7 conformance battery not run on a live node; M5-C2 contract state UNVERIFIED — a port/service is not a `file:function`; §9 inventory 4 of 215+ helper call sites — the descriptive per-measurement rows not tabulated one-per-site)

## FLIGHT DATA FILE - M5 HARNESS

```checklist
TITLE: M5 HARNESS
WHO: NODE OPERATOR
RESOLVE - resolve the pinned harness binary and args for the lane
√ BINARY - one binary, one arg set, no PATH drift
SMOKE - run the harness on a scratch brief
√ COMMIT - a commit lands carrying the co-author trailer
GRADE - run the gitreins guard on a staged change
√ VERDICT - PASS or FAIL with named criteria, never a silent skip
```
