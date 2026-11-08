---
name: code-factory-bunker
description: Provision, verify, or destroy one project's bunker node from a config file and CLI overrides, then put it on the crier bus.
---

# Bunker provisioning

Use this when a project needs its own bunker (one bunker per **project**, not per lane), when
a node's credentials or identity must be refreshed, or when a node must be checked before
work is dispatched to it. Everything here runs on the **control host** and reaches into the
bunker; nothing is installed on the node by hand.

## One project, one bunker

Every lane of a project enters through crier and lands in that project's single bunker: one
clone, one harness, one router, one memory namespace. No two projects share a bunker — the
bunker boundary is the isolation unit. If you want a second project, provision a second agent.

## The two scripts

Both live in `scripts/` and share `scripts/lib.sh`. Both take `--check` (read-only, every row
names the value it measured) and `--apply` (idempotent). Neither takes a secret as an argument.
`--check` stages its probe as a file (bunker's `exec` does not forward stdin) and deletes it again
in the same run, so a check leaves nothing in the node's home.

| script | does | refuses when |
|---|---|---|
`bunker-provision.sh` | config + agent lifecycle + clone + auth bundle + node identity + delegates crier connect | a check row FAILs and cannot be repaired; the config has a non-`KEY=VALUE` line |
`bunker-crier-connect.sh` | writes `$HOME/.node/crier.json` in the node, then proves the agent's own inbox with a **signed** read | the signed read is not a **200** — an unsigned answer is `UNVERIFIED` (exit 3), never `CONNECTED`; `401`/`403`/`404`/`000` are named distinctly |

`node-create.sh` / `project-node.sh` / `verify-node.sh` remain the plumbing underneath; the
provisioner calls `node-create.sh` rather than re-implementing staging and layer checks.

`bunker-crier-connect.sh` takes `--check`, `--apply` and `--stage`. `--stage` writes
`$HOME/.node/crier.json` (agent, project, url; mode 600) and stops there — the provisioner stages
the identity before the node's bus layer exists, then proves it with `--apply` after the clone.

## Config file

Data, never executed: every non-comment line must be `KEY=VALUE` with `KEY` matching
`[A-Z_][A-Z0-9_]*`. A stray shell line is a FAIL, so a config cannot become a script.

```conf
PROJECT=code-factory
AGENT=cf-node
SERVER=<bunker server>
REPO=git@github.com:<org>/<repo>.git
REF=main
HARNESS=hermes
NAMESPACES=code-factory,coder   # one or more; the first is primary
TTL=30d
GITHUB_TOKEN_FILE=~/.config/code-factory/github.token
DUCKBRAIN_TOKEN_FILE=~/.duckbrain/<role>.token
S3_ENV_FILE=~/.config/code-factory/s3.env
CRIER_URL=http://<control-host>:8767
DUCKBRAIN_URL=http://<control-host>:3000
NODE_ENV_FILE=~/.config/code-factory/code-factory.node.env
CONFIG_SET_MODEL_PROVIDER=cf-proxy
CONFIG_SET_MODEL_NAME=<model-id>
CONFIG_SET_GATEWAY_BIND=0.0.0.0
CONFIG_SET_GATEWAY_PORT=10800
CONFIG_SET_AGENT_MAX_ITERATIONS=40
```

`NODE_ENV_FILE` and the five `CONFIG_SET_*` keys declare the node's **environment**; any other
`CONFIG_SET_*` spelling is an unknown key and fails the parse, exactly like any other unknown key.
They are applied on the node before the harness layer starts a gateway — see
[Declared node environment](#declared-node-environment) and `config/node.env.example`.

The command line always wins over the file:

```bash
scripts/bunker-provision.sh --config ~/.config/code-factory/cf.conf --check
scripts/bunker-provision.sh --config ~/.config/code-factory/cf.conf --apply --agent cf-node-2
scripts/bunker-provision.sh --config ~/.config/code-factory/cf.conf --destroy --yes
```

Every key the config accepts has a flag that overrides it, applied **after** the file is parsed:

| flag | overrides | notes |
|---|---|---|
| `--project` | `PROJECT` | |
| `--agent` | `AGENT` | the agent the config names is reused; this renames the target, it never spawns a second one |
| `--server` | `SERVER` | |
| `--repo` | `REPO` | |
| `--ref` | `REF` | |
| `--harness` | `HARNESS` | |
| `--namespace` / `--namespaces` | `NAMESPACE` / `NAMESPACES` | the first entry stays primary |
| `--crier-url` | `CRIER_URL` | |
| `--duckbrain-url` | `DUCKBRAIN_URL` | |
| `--github-token-file` | `GITHUB_TOKEN_FILE` | a path, never a value; a leading `~/` is expanded here |
| `--duckbrain-token-file` | `DUCKBRAIN_TOKEN_FILE` | |
| `--crier-agent-key-file` | `CRIER_AGENT_KEY_FILE` | |
| `--crier-auth-token-file` | `CRIER_AUTH_TOKEN_FILE` | |
| `--s3-env-file` | `S3_ENV_FILE` | |
| `--node-env-file` | `NODE_ENV_FILE` | |
| `--config-set K=V` | the matching `CONFIG_SET_*` | repeatable |

`--check` echoes what it resolved in one row (`resolved repo=… ref=… harness=… namespaces=… ttl=… crier=… duckbrain=…`) and its `inputs` row names every credential file with its path, so a flag that silently lost to the file is visible instead of invisible.

## The commit gate lives on the node

A remote foreman commits on the bunker, so gitreins is installed **there**, not only on the
control host. `--apply` stages `scripts/install-gitreins.sh` into the agent and runs it after the
clone exists: a venv under `$HOME` (Debian marks the system interpreter externally managed, so
`pip install --user` is refused — PEP 668), the pin read back, a pre-commit hook written with the
**absolute** venv path (`DF-011`: a bare `gitreins` on PATH can be a different version), and the
git identity the node commits under. `--check` prints one row per piece and fails on any of them.
### Generating the config from the registry

Hand-writing one config per project is how the same repo URL ends up spelled two ways and how two
projects end up with one agent id. `scripts/bunker_config_gen.py` derives them from the scheduler's
`projects` table instead (stdlib + `sqlite3`, read-only):

```bash
scripts/bunker_config_gen.py --server <bunker-host> --prefix code-factory   # write <project>.conf
scripts/bunker_config_gen.py --server <s> --project code-factory --dry-run  # rows on stderr, configs on stdout
scripts/bunker_config_gen.py --server <s> --prefix code-factory --check     # exit 1, names each drifted key
scripts/bunker_config_gen.py --server <s> --prefix code-factory --force     # rewrite a differing file
```

**The clone is the project.** Lanes are grouped by resolved repo target (`local:<path>` → its real
path, anything else → the URL as written), so 17 lanes over one checkout are one config, one
bunker. Within a group the project is the shortest candidate that is a prefix of every other lane
name, candidates being the lane names plus their family keys (one recognized suffix removed) — the
fleet's `<project>-<suffix>` spelling, with the scheduler's nine suffixes (`-qa -pm -sync -dogfood
-releng -docs -readme -perf -review`) — so a family whose primary row is `<project>-foreman` still
derives `<project>`. A lane whose tail is not one of those is grouped when the prefix rule still
settles it and reported as a `WARN suffix` row, and a lane whose family key is another project but
whose `repo_url` names a different clone stays its own config with a `WARN repo_disagreement` row
(the CF-091 disagreement, named rather than merged).

`AGENT` is `cf-` plus the project, normalized to `[a-z0-9-]`; `NAMESPACE` is the registry's
`namespace_id` when the lanes agree and the project name otherwise (both values named in a `WARN`);
the three token keys are **paths** under `~/.config/code-factory/<project>/`.

It refuses, with a named `FAIL` row and exit 2, and writes nothing at all: an absent or empty
`repo_url`, a `local:` path that does not exist (`PHANTOM`), a group with no common name prefix
(`AMBIGUOUS`), a name that is not a safe slug, two projects deriving one `AGENT`, and a directory
it cannot write. A generated file is sorted by key and carries no timestamp, so a second run prints
`unchanged` per file; a file that differs is never rewritten without `--force`, and the row names
the keys that differ. `--check` is read-only and exits 1 with one `FAIL drift` row per key.

A `REPO` that came from a `local:` path is a path on the **control host**: a remote node cannot
clone it, and the run says so with a `WARN local_repo` row. Pass `--repo-url` with the URL the node
can reach.

## Credentials

A project may need more than one namespace (a lane that reads another project's memory, or
an app namespace beside the project one). List them: `NAMESPACES=code-factory,coder`. The primary
is the first entry, and `--check` prints one `duckbrain:<ns>` row per namespace, so a token that
reaches one and not another is visible instead of averaged away.

Two of those files are the **bus** credentials: the agent's ed25519 private key (the bus verifies a
per-agent signature before it even looks the agent up) and the shared bearer. Without both, the
node's inbox answers 401 to every read and no work can arrive. `CRIER_AUTH_TOKEN_FILE` may point
at the crier unit's EnvironmentFile — the `CR_AUTH_TOKEN=` value is extracted, so the secret is not
copied to a second path.

The config names **files**; the provisioner reads them into one bundle of mode 600, copies it
in, installs `$HOME/.node/auth/{github.token,duckbrain.token,s3.env}` at mode 600, points git
at a credential store built from the token, and deletes the bundle on both sides. No value is
ever printed, logged, or passed as an argument. `$HOME/.node/node.json` carries names only.

## Declared node environment

A node's environment — the variables in `~/.hermes/.env` and a handful of scalars in
`~/.hermes/config.yaml` — is declared, not hand-edited, so it can be reviewed, diffed and
re-applied. `scripts/node_env.py` runs **on the node**; the profile and the config keys are
named in the provisioner config on the control host.

```conf
NODE_ENV_FILE=~/.config/code-factory/code-factory.node.env   # the profile to stage
CONFIG_SET_MODEL_PROVIDER=cf-proxy                            # -> model.provider
CONFIG_SET_MODEL_NAME=<model-id>                              # -> model.name
CONFIG_SET_GATEWAY_BIND=0.0.0.0                               # -> gateway.bind
CONFIG_SET_GATEWAY_PORT=10800                                 # -> gateway.port
CONFIG_SET_AGENT_MAX_ITERATIONS=40                            # -> agent.max_iterations
```

**Profile grammar** (`config/node.env.example`): one declaration per line, comments with `#`,
nothing else. `ENV_<NAME>=<value>` writes a literal into `~/.hermes/.env`;
`ENV_<NAME>=@<path>` reads the value from a file on the node (a leading `~/` is the node's own
`$HOME`).

**Secrets.** A name matching `KEY|TOKEN|SECRET|PASS` must use the `@<path>` form. The profile is
committed, copied to the node and quoted in diffs, so a literal secret in it is a leaked
credential: `node_env.py` refuses that line by name and never echoes the value. Every row that
describes a secret-named key prints `***`.

**Only five config paths exist** — `model.provider`, `model.name`, `gateway.bind`,
`gateway.port`, `agent.max_iterations`, spelled as the `CONFIG_SET_*` keys above. Any other
dotted path is refused with the allowed set named; it does not get invented. Values are checked
(`gateway.port` 1–65535, `agent.max_iterations` 1–100000, non-empty strings elsewhere).

```bash
# on the node
scripts/node_env.py --env-file ~/node.env --config-set gateway.port=10800 --check   # diff, writes nothing
scripts/node_env.py --env-file ~/node.env --config-set gateway.port=10800 --apply   # atomic, mode 600
```

| mode | exit 0 | exit 1 | exit 2 |
|---|---|---|---|
| `--check` | the node matches the declaration | drift, one `DIFF` row per key | the declaration is refused: unreadable profile, a non-`ENV_` line, a literal secret, an unknown path, an out-of-range value |
| `--apply` | written, or already matching | — | the declaration is refused, or the write failed |

`--apply` is idempotent: it rewrites only the lines it owns, keeps every comment and unrelated
key, and a second run reports `already matches (no change)` and exits 0. A variable present in
`~/.hermes/.env` that the profile does not declare is reported as `WARN unmanaged:<NAME>` with
its value masked — visible so a re-provision's carry-forward is known, but never a drift and
never deleted, because `--apply` does not own it.

The provisioner runs the same file in `--check` locally against an empty `HOME` before it touches
a host, so a refused declaration is a named `FAIL env_profile` row rather than a surprise mid-apply.

## Order of operations on `--apply`

1. preflight — the config parses, the bunker client exists, the server is listed, the agent is reachable
2. agent — reused when present, spawned only when absent
3. auth bundle — one 600 file in, installed under `~/.node/auth`, deleted on both sides
4. crier identity staged — before the node's bus layer needs it
5. **node environment** — `node_env.py --apply`, before the harness layer starts a gateway
6. gateway auth — `dashboard.basic_auth` ensured, password generated on the node
7. node plumbing — `node-create.sh` (repo, harness, layers) now that every input is in place
8. identity — merge into `$HOME/.node/node.json`, preserving its schema
9. crier proof — `bunker-crier-connect.sh --apply`, which only reports CONNECTED on a **signed** 200 read of the agent's inbox
10. nothing else. Run `--check` yourself afterwards: `--apply` printing PASS is not evidence.

## Reading a failure

| row | meaning | fix |
|---|---|---|
`bunker_cli` FAIL | no `bunker` client on PATH | install it; a node cannot be reached without it |
`agent` FAIL | agent absent on that server | `--apply` (it will spawn one) |
`repo` FAIL | no clone at `$HOME/repo` | `--apply`; check `REF` matches the repo's default branch |
`node_json` FAIL | identity absent | `--apply` step 8 |
`auth_github` / `auth_duckbrain` FAIL | token file missing on the node | name the token file in the config, re-apply |
`harness` FAIL | harness binary absent | run the harness adapter (`scripts/harness/install-<h>.sh --apply`) |
`env_profile` FAIL | the declaration is refused — an unknown `CONFIG_SET_*` path, a literal secret, a non-`ENV_` line | fix the profile or the key; the row names the line and the allowed set |
`crier` 401/403 | auth or per-agent signature missing, or owner/guard refused. crier checks the signer **before** it looks the agent up (`internal/registry/agentsig.go`, `verifyAgentSignatureForKey`), so 401 is **not** evidence the id is unknown | present the agent's bearer + signature, or register the sender |`crier` 404 | the agent id is genuinely not registered | register it; do not invent a key |
`crier` 000 | bus unreachable | the URL, not the node, is the problem |
`duckbrain` FAIL | namespace unreachable with that key | check the token's namespace scope |

## The node's bus worker

`scripts/node-bus-worker.py` is the node side of the bus: the thing that consumes the inbox. It
runs **on the node**, is stdlib-only, and every write it makes is under `$HOME`.

```bash
# on the node
python3 ~/node-scripts/node-bus-worker.py --check          # measure, print rows, write nothing
python3 ~/node-scripts/node-bus-worker.py --once           # fetch -> verify -> run -> reply -> ack
python3 ~/node-scripts/node-bus-worker.py --loop 20 --interval 15
python3 ~/node-scripts/node-bus-worker.py --once --dry-run # fetch, print the plan, run/post/ack nothing
```

It needs four things the provisioner installs, and names the first missing one:

| on the node | what it is | created by |
|---|---|---|
`$HOME/.node/crier.json` | agent id, project, bus url (mode 600) | `bunker-crier-connect.sh --apply` |
`$HOME/.node/node.json` | project, `repo.path` (the clone), `harness.cmd` (mode 600) | provisioner step 8 |
`$HOME/.node/agent.key` | the agent's **own** PKCS#8 PEM ed25519 private key (mode 600) | key material held by whoever registered the agent — never generated here |
`$HOME/.node/auth/crier.token` | the bus bearer token (mode 600), or `CRIER_AUTH_TOKEN` | the auth bundle |

**The bus verifies two credentials, not one.** `CR_REQUIRE_AGENT_SIG=true` is the default, and a
signed read also carries the shared bearer. The signature is exactly what crier's
`internal/registry/agentsig.go` verifies: `X-Agent-ID`, `X-Agent-Ts` (unix seconds, ±30 s) and
`X-Agent-Sig` = hex(ed25519(`METHOD\n<path>\n<ts>`)) over the raw path with the query string
excluded, so a retrieve signature cannot be replayed on the ack. A body can opt into a fourth
transcript line (`\nsha256:<hex>`) via `X-Agent-Body-SHA256`; the worker sends it on every POST.

`--check` rows: `identity` (both files, modes, project), `project` (the two files agree),
`signing_key` (present, mode 600, parses as PKCS#8 ed25519 — it prints the **public** half only),
`bus_bearer`, `bus_health`, `inbox` (`/inbox/stats` — the signed read that leases nothing),
`key_registry` (the node's public key must be the one the bus has on file), `harness`,
`gateway`. Any FAIL exits 1.

Refusals, in the order they are decided — none of them runs anything:

| row | when | what it means |
|---|---|---|
`identity` | `node.json`/`crier.json` unreadable or not an object | nothing else can be measured |
`project` | the two identity files name different projects | one of them is stale; fix it, do not guess |
`signing_key` | the key file is absent, world-readable, encrypted, not PKCS#8 or not ed25519 | the node cannot sign; **do not invent a key and do not borrow another agent's** |
`bus_bearer` | neither the token file nor `CRIER_AUTH_TOKEN` supplies a token | a signature alone is still a 401 |
`bus_health` | `/health` answers `000` | the URL, or the route to it, is the problem |
`brief_digest` | `brief.digest` ≠ cf-brief-v1 (sha256 over the canonical object of `text` + `gate` + `repo` + `ref` + `workdir` + `vars`), OR a legacy text-only `sha256(text)` beside a `gate`, OR a `gate` with no digest | the brief — or its executable `gate.cmd` — was altered in flight and is unbound: refused, result posted, message acked |
`brief_project` | the dispatch names another project | the bus routed a directive to the wrong bunker |
`brief_workdir` | the dispatch names a workdir outside the clone | refused; this node writes only inside its clone and `$HOME` |

Order of operations in `--once` is the contract: verify the digest **before** running, post the
result to `reply_to` with the dispatch's `corr_id` preserved, and **ack last** — a crash between
execution and delivery leaves the message leased, so it comes back. A redelivered
`idempotency_key`/`dispatch_id` replays the recorded result instead of running the harness twice
(`$HOME/.node/bus-seen.json`, mode 600).

Reading a failure: `401` on the inbox is **not** proof the agent is unknown — crier checks the
signer before it looks the agent up. A `key_registry` FAIL is the other side of the same coin:
the node signs with a key the bus does not have, so every request 401s while the node looks
healthy. `--check` prints the public half precisely so that comparison is possible without
touching key material.
## Harness conformance: what actually works, per harness

`tests/harness-conformance.sh` is the battery behind `docs/HARNESS-CONFORMANCE.md`. It answers one
question per harness — hermes, claude-code, codex, opencode (`opencode` is the 1.x line),
`opencode-v2`, deepseek, pi-agent — with three legs:

```bash
tests/harness-conformance.sh                  # check + smoke; installs nothing
tests/harness-conformance.sh --write-doc      # regenerate docs/HARNESS-CONFORMANCE.md
tests/harness-conformance.sh --install        # also --apply each adapter in a throwaway $HOME
tests/harness-conformance.sh --only codex     # one harness
HERMES_PYTHON_BIN=python3.12 tests/harness-conformance.sh   # when python3 is >=3.14
```

- **check** runs the adapter's own `--check` and quotes the value it measured. An adapter that
  prints `PASS` with an empty value is rewritten to `FAIL` by the battery's single `emit()` — the
  check is not trusted just because it exited 0.
- **smoke** runs one real turn in a scratch directory and requires a file containing a token the
  battery chose; the bytes are re-read and hashed on the control host. This is the only leg that
  proves the harness *answers*, and it is the one that costs tokens.
- **apply** runs `--apply` in a throwaway `$HOME` (only with `--install`) and then re-runs `--check`
  in it, so a green install is always followed by the state it left behind.

**A SKIP is not support.** A row like `SKIP  codex:smoke — binary \`codex\` absent from PATH` names
exactly what would have to exist to test it; treat every SKIP as an untested harness. Today the
foreign adapters (`claude-code`, `opencode`) refuse `--apply` until someone records a ladder, and
`codex`/`deepseek`/`pi-agent` ship no adapter at all — the battery reports those as `FAIL no adapter
at …` rather than skipping them, because "named but unmeasurable" is a defect, not a verdict.

**What a green matrix proves:** each adapter, run as shipped, measured something and exited 0; each
smoke leg produced a real artifact whose bytes the control host verified; with `--install`, each
`--apply` reached exit 0 from a clean state and the post-apply `--check` agreed.
**What it does not prove:** a node (no bundle, no crier, no repo layer, no scheduler), the pinned
ladder on a clean node, autonomy under retries and timeouts, or anything about a harness that is a
SKIP. Do not quote the matrix as "the fleet supports six harnesses".

`tests/selftest.sh` §44 keeps the battery honest in fixture mode — absent credential ⇒ named SKIP,
missing adapter ⇒ FAIL, empty adapter value ⇒ FAIL — so a regression that turns SKIPs into PASSes
reds the suite.

## Rules that bite

- **One bunker per project.** Two projects in one bunker share a clone, a namespace and an
  identity; a lane of one can read the other's memory.
- **Never trust `--apply`'s own PASS.** Re-run `--check`; the rows are the evidence.
- **No root.** Everything lands under `$HOME`; if a step needs root, the step is wrong.
- **Delete the bundle.** A bundle left behind is a credential leak with a friendly name.
- **Destroy needs `--yes`.** It prints the exact agent and server it would remove.
- **Re-provision, never hand-edit.** A hand-edited node is a node that cannot be rebuilt.
