# code-factory

The distributed coding workforce: **one Hermes foreman on each project's bunker** designs and
organises work; **one bunker node per project** executes it; **crier** carries the work;
**the scheduler** decides whose turn it is.

This repo is the factory itself — the specs that define a node, the board that tracks the
build, and the scripts that make a node real.

## What a node is

One bunker agent, one repo, one harness, one bus identity, one round-trip proof.
`docs/DESIGN.md` is the authority; `specs/NODE.md` is the contract.

## Quick start

```bash
# once, on the control host — your bus and your agent host
export CRIER_URL=http://crier.example:8767
export BUNKER_SERVER=your-bunker-server

# 1. can this control host run the factory at all? (needs the bunker client)
scripts/bunker-server-install.sh --check

# 2. what does a node look like right now? (run inside the node)
./scripts/project-node.sh --check --project myproject

# 3. make one, from the control host
#    (a repo whose default branch is not main: add --ref <branch-or-tag> here — node-create.sh
#    forwards it, and it is the same flag the node's own check tells you to pass)
scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes
```

On a host with no bunker server, no Crier and no repo, all three commands reach their checkers and
fail with the missing value named. That is the honest result on a fresh host, and every message
tells you which value to supply.

**What step 3 writes for you.** A gateway on `0.0.0.0` needs `dashboard.basic_auth` in the node's
`~/.hermes/config.yaml`, and the create path stages it instead of leaving it to you:
`scripts/node-create.sh` copies `node_gateway_auth.py` into the node (it is one of the files
`--staged-files` prints), and `project-node.sh` layer 20 runs it before the harness adapter —

```bash
python3 "$HERE/node_gateway_auth.py" "$HOME/.hermes/config.yaml" "$HOME/.node/auth/gateway.pass"
```

— with `$HERE` = `~/node-scripts` on the node and `$HOME/.node/auth` created mode 700 first. The
password is generated on the node, kept in that file at mode 600, and never printed or passed in
argv; an existing `basic_auth` block is left untouched, so a re-run changes nothing. The writer also
creates the config's own directory when it is absent — `~/.hermes`, mode 700 — because a freshly
created node has none: the harness adapter that owns `~/.hermes` runs *later* in the same layer. So
layer 20 stages the block before that adapter's gate runs, and `gateway_auth` reaches PASS on a HOME
where `~/.hermes` does not exist at all; `tests/selftest.sh` §55 drives exactly that state, and
carries the pre-fix writer as its control. What that leaves is a specific set of rows rather than a
finished node: with the block in place the adapter's `gateway_start` row is gated on the gateway
answering rather than on auth, a node is still not expected to reach `NODE: PASS` (`inference_key`
fails until the node has its own provider key, and layer 30 fails until a crier identity is
staged), and with no block in the config the adapter still refuses the public bind by name and
unchanged — `FAIL gateway_start — refused: a public bind needs dashboard.basic_auth in
~/.hermes/config.yaml`. That gate is not weakened; `tests/selftest.sh` §55 drives both of its states.
No created node has been measured live by this repository: the §55 arms run against a stub harness.

## Provisioning a node from a config file

One project, one bunker. Every lane of a project enters through crier and lands in that project's
single agent — one clone, one harness, one memory namespace. Two projects never share an agent:
the bunker boundary is the isolation unit, so a second project gets a second agent and a second
config file.

`config/bunker.example.conf` is the template. Copy it, edit the values, and leave the token
entries as **paths** — the file names credentials, it never holds them.

```bash
# read-only: every row names the value it measured, and nothing is written
scripts/bunker-provision.sh --config ~/.config/code-factory/cf.conf --check

# idempotent: reuses an existing agent and leaves an existing clone at its commit
# (no fetch, no reset); node.json is rewritten with a fresh provisioned_at
scripts/bunker-provision.sh --config ~/.config/code-factory/cf.conf --apply

# crier identity, on its own failure surface: writes $HOME/.node/crier.json in the node,
# then probes <crier>/agents/<agent>/inbox — only a 200 prints CONNECTED
scripts/bunker-crier-connect.sh --agent cf-node --server "$BUNKER_SERVER" \
    --url "$CRIER_URL" --project code-factory --check

# refuses without --yes, and names the agent and server it would remove
scripts/bunker-provision.sh --config ~/.config/code-factory/cf.conf --destroy --yes
```

The command line wins over the file — `--agent cf-node-2` overrides `AGENT=cf-node` — so one
template can drive several nodes without editing. The config is data, not a script: every
non-comment line must be `KEY=VALUE`, and a line that is not one is refused before a single bunker
call (`scripts/bunker-provision.sh:39-62`):

```
FAIL  config — .../bad.conf:2 is not KEY=VALUE — refusing to run it
```

Credentials travel as files only. The config names `GITHUB_TOKEN_FILE`, `DUCKBRAIN_TOKEN_FILE` and
`S3_ENV_FILE`; the provisioner reads them into one mode-600 bundle, copies it into the node,
installs `$HOME/.node/auth/{github.token,duckbrain.token,s3.env}` at mode 600, points git at a
credential store built from the token, and deletes both copies. No value is printed, logged or
passed as an argument, and `$HOME/.node/node.json` carries names only
(`scripts/bunker-provision.sh:172-214`).

`--check` against the template, on a host that has the client but no such node:

```
PASS  config — bunker.example.conf — 25 lines, KEY=VALUE only
bunker-provision --check — project=code-factory agent=cf-node server=bunker-node-01
  PASS  bunker_cli — /home/kara/.local/bin/bunker
  FAIL  server — bunker-node-01 not listed by 'bunker list'
  FAIL  agent — cf-node absent — run --apply to create it
```

`--apply` printing PASS is not evidence; `--check` is. Against the reference deployment on
2026-11-05 the same command printed `PASS  repo — clone present (af67c3b branch main, 0 dirty)`,
four FAILs (`node_json`, `auth_github`, `auth_duckbrain`, `harness`) and a `crier` row reading
`401 (identity not accepted)`: the node existed and was reachable, and its identity, credentials
and harness were still missing. Every row and the fix it implies is tabulated in
`skills/code-factory-bunker/SKILL.md`.

`TTL` is forwarded to `node-create.sh` only when an agent is actually spawned — a re-run against
an existing agent never renews it. `WORKDIR` was removed from the surface entirely: nothing consumed
it, and a key that cannot change behaviour does not belong in a template. The environment a node
runs with (`.env` values, model, bind, port) is declared in `config/node.env.example` and applied
by `scripts/node_env.py` before the harness layer starts.

## Layout

```
docs/            DESIGN.md, PRD-code-factory.md, OPERATIONS.md, BOARD.md; audits/ holds tick evidence
specs/           NODE.md (what a node is), ENVELOPE.md (dispatch/result), HARNESS.md (adapters)
scripts/         node checks and provisioners: bunker-server-install.sh, bunker-provision.sh,
                 bunker-crier-connect.sh, bunker_config_gen.py (writes one provision config per
                 project from the scheduler registry), project-node.sh, node-create.sh,
                 verify-node.sh, lib.sh
scripts/ (CF-003) deploy_key.py (per-repo read-only deploy key + one generated ssh_config),
                 install-node.sh (digest-pinned Node runtime for kind `node`),
                 gomodcache.py (sealed shared Go module cache), node_hygiene.py (footprint
                 admission + orphan home/key reaper)
scripts/harness/ install-<harness>.sh — one per harness. Shipping an install ladder: hermes,
                 claude-code, codex, dsh (DeepSeek's own harness, `@deepseek-ai/dsh` at an RC
                 pin — install-dsh.sh also reports a plugin-layer failure per layer and re-measures
                 the RC pin with --pin-status). Check-only (`--apply` refuses by name until a
                 ladder is measured): opencode, deepseek, pi-agent, aider, goose — `deepseek`
                 here probes a binary of that name, NOT DeepSeek's harness (that is `dsh`); the
                 last two are documented methods (pip venv / release binary) with no measured
                 ladder, so their adapters print rows and refuse to install anything.
                 The node manifest records the harness version and binary an adapter measured;
                 verify-node.sh re-measures it (specs/HARNESS.md "A node records the harness it
                 measured")
scripts/ (lanes) load_lane_config.py, add_family_lanes.py, clone_lane.py, configure_family.py —
                 configure this repo's lane family in the scheduler; see "The lanes" below
scripts/boardctl the board entrypoint (docs/BOARD.md); fails closed when the fleet boardctl is
                 not on PATH
.coding-hermes/board/  tasks.jsonl (JSONL, git-tracked) + events.jsonl
prompts/         one role file per job; lanes share them (see "The lanes")
tests/           selftest.sh — proves the checkers FAIL when they should
```

## Laws (measured, not assumed)

1. **No root.** Agents have no passwordless sudo and no apt. Everything installs into `$HOME`.
2. **Nothing is "installed" until `--check` flips to PASS** and names the value it measured.
3. **A version string is not evidence.** Verification is a round trip whose artifact digest is
   recomputed on the control host.
4. **Credentials never travel as arguments.** One bundle file, mode 600, deleted after use.
5. **The bus carries messages, not open requests.** A job's lifetime lives on the node.
6. **Bus before workspace.** A node that can receive a command but has no repo is diagnosable;
   a node with a repo and no bus is invisible.

## Status

Each row names the command that can contradict it. A row with no command says what is missing
instead of implying it works.

| Piece | State | Command that can contradict it |
|---|---|---|
| Hermes in a bunker + HTTP gateway over tailnet | **works (historical measurement)** — observed on a live node on 2026-10-29: 32 s install, `/api/status` 200, 133 JSON-RPC methods. The recorded measurement is in `specs/HARNESS.md#adapters-and-their-measured-state` and the repo-local audit `docs/audits/code-factory-readme-2026-10-30-20-29-25.md#2-status-table-both-command-bearing-rows`; it is not reproducible from this repo alone. Current local evidence is only `scripts/harness/install-hermes.sh --check`. On this host's default `python3` (3.14) that command prints exactly one gate row — `FAIL python` — and never reaches the binary or port arms; the binary, port and `inference_key` rows print only on an interpreter inside the pin's range (`HERMES_PYTHON_BIN=python3.12` prints four when no `hermes` binary is installed — that is the recorded arm — and five when a binary is found, because a `version` row is added. The 2026-11-03 host-provided `hermes` result was historical, not certification of the pinned venv install: CF-183 now FAILs host-provided binaries and compares the measured version against the pin). Both arms, with the measured gate-row counts (1 vs 4), the binary/port rows they carry (0/1) and both exit codes, are in `docs/audits/cf092-install-check-arms.txt`; the `inference_key` pair is also in `docs/audits/code-factory-CF-064.probe.txt` (CF-064, CF-092). `--apply` needs Python `>=3.11,<3.14` — the pinned `hermes-agent==0.19.0` declares that range, and the installer now refuses Python 3.14 before pip with the detected version. The exact selftest/check output is recorded in `docs/audits/code-factory-CF-036.md` (CF-036). | Re-run the current local check with an interpreter inside the pin's range — `HERMES_PYTHON_BIN=python3.12 scripts/harness/install-hermes.sh --check` — which prints four gate rows when no `hermes` binary is installed (python, binary, port, `inference_key`) and five when a binary is found (adds `version`). Only `$HOME/hermes-venv/bin/hermes` passes the binary row; a PATH-provided binary is reported as host-provided, not certified. The version row compares the measured value against `HERMES_PIN` (default `0.19.0`); a mismatch FAILs and prints both values. `--apply` installs the pin when the venv binary is missing or mismatched, even if `hermes` exists on PATH. The unqualified `scripts/harness/install-hermes.sh --check` is the same command on the default `python3`, and there it prints one row: `FAIL python`. For the historical figures, read the committed artifact named in the state cell; no live endpoint or credential is claimed here. |
| Repo clone in a node | **works (historical local measurement)** for public HTTPS — `PASS repo_clone … @ 9402f6a` was measured on 2026-10-30 with `https://github.com/github/gitignore` and is recorded in `docs/audits/code-factory-readme-2026-10-30-20-29-25.md#2-status-table-both-command-bearing-rows`. A re-run derives the current HEAD, which may move. Layer 40 clones only; no build step is shipped. Private repos now have a tested **procedure** — CF-003 shipped `scripts/deploy_key.py` (0600 per-repo key + one generated `ssh_config`) and `scripts/node-create.sh --deploy-key <file>` (validated before any agent is spawned, copied as a file, never argv), with `tests/test_node_provisioning.py` and `tests/selftest.sh` §58 proving the mechanism against fixtures and printing the single clone command. That is not a live result: no node has cloned the private GitLab with a real read-only key, so the clone itself stays **unverified** until a live run records it. | Re-run with a temporary HOME and the same public fixture: `home=$(mktemp -d); CRIER_URL=http://crier.example:8767 HOME="$home" ./scripts/project-node.sh --apply --project myproject --repo https://github.com/github/gitignore --ref main`. For a private repo, the documented path is `scripts/node-create.sh --project P --repo git@<gitlab>:<group>/<repo>.git --deploy-key <file>`; `scripts/deploy_key.py check --home <node home> --repo <url>` prints the one clone command and the key/config rows without printing key material. The node check is the last command on that line, so the line's exit status is the check's: `NODE: FAIL` exits nonzero. Read the clone back in a second command, not the same line: `git -C "$home/repo" rev-parse HEAD`. The committed audit records the historical output. |
| Node inference credential | **missing** — a turn dies at `No inference provider configured`; the node needs its own key, never an operator key | This is a NODE state, not measurable from the control host: the `inference_key` gate is emitted by `scripts/harness/install-hermes.sh --check` and reads `$HOME/.hermes/.env` of whichever environment runs it. The node-scoped contradiction is that gate failing inside the node — `scripts/node-create.sh` stages the adapter into `~/node-scripts/harness/`, and the node's `~/node-scripts/project-node.sh --check --project <p>` echoes the adapter's rows through its layer 20, so an unkeyed node prints `FAIL inference_key` for its own missing key. Run on the control host, the same gate measures this host's own key, not a node's — control-host evidence only: `HERMES_PYTHON_BIN=python3.12 scripts/harness/install-hermes.sh --check` on this keyed host prints `PASS inference_key` (five gate rows, `HERMES: FAIL (1)` on `port`, rc 1), so a PASS there cannot witness the node's missing key. The adapter row prints only on an interpreter inside the pin's range — the default `python3` here is 3.14 and stops at `FAIL python` first. Both control-host arms are transcripted in `docs/audits/code-factory-CF-064.probe.txt` (CF-064). |
| crier identity in a node | **missing** — no `~/.node/crier.json` yet | `./scripts/project-node.sh --check --project myproject` -> `FAIL crier_identity` |
| Scheduler → crier dispatch | **built, disarmed** — needs 2 env vars, 1 target row, `payload.text` (CF-001) | not armed, so nothing to run |
| Round trip through the node's own gateway | **not yet** — no checked-in command proves it; the one attempt used a bespoke poller rather than the node's gateway (CF-004) | no command exists to fail |

`--ref` defaults to `main`, so a public repo whose default branch is named differently needs
`--ref <branch>` on the step 3 create command; `scripts/node-create.sh` forwards it and the node
clones that branch or tag (`scripts/project-node.sh` accepts the same flag directly). A missing ref
reports that ref and the `--ref` flag; a repository-access failure retains the deploy-key hint for
private repositories (CF-034). `--agent ID` reuses an agent that must **already exist** on the
server: the create path proves it with `bunker info` before any success row or staging, prints a
named `FAIL agent` naming the id and the remedy otherwise, and never spawns an agent you named.

See `.coding-hermes/board/tasks.jsonl` for the work items and their acceptance criteria. The
ordered path from this table to one landed result — P0 through P3, each with a command as its exit
test — is `docs/MVP-PLAN.md`; P0's exit test is the `bunker-provision.sh --check` above going green.

## Running it against your own infrastructure

This repo carries no endpoints, hostnames or credentials. Two environment variables, the `bunker`
client and one harness are all it assumes:

```bash
export CRIER_URL=http://crier.example:8767     # your message bus
export BUNKER_SERVER=your-bunker-server        # your agent host
scripts/bunker-server-install.sh --check       # does this control host qualify?
scripts/node-create.sh --project myrepo \
    --repo https://github.com/you/myrepo --harness hermes
```

A node needs a repo it is allowed to clone and an inference credential of its own — never an
operator key. The credential is a file on the node, not a third environment variable.
`specs/HARNESS.md` records which harness ladders are measured and which are only documented; an
unmeasured adapter refuses `--apply` rather than pretending.

## Contributing

- `tests/selftest.sh` must pass, and any new check needs a fixture proving it can FAIL.
- A spec change and the script change it implies belong in the same commit.
- Board rows: append only, `.coding-hermes/board/tasks.jsonl`.
- No secrets, no endpoints, no personal data — this repo is public.

MIT licensed. `AGENTS.md` is the working agreement for agents in this repo.

## Quality gate — GitReins

Commits run through `gitreins guard`: secrets (gitleaks + the builtin scanner), lint, and this
repo's own `tests/selftest.sh` as the test gate. `guards.allow_skips` is **false** on purpose — a
guard run that skips its gates reports `DEGRADED PASS` and that is not evidence. Stage what you
want graded.

## The lanes

Fourteen scheduler projects make up this repo's lane family: the root foreman, ten operating
lanes, and three QA lanes. The 13 satellite projects are nested under `code-factory` (the
scheduler's `projects.parent`); the root foreman has no parent. The list below is the shipped
lane family; verify the live namespace, admission mode, and workdir with the scheduler's
project inventory before relying on a current deployment count.

| Lane | Job | Prompt | Admission |
|---|---|---|---|
| `code-factory` | foreman — one board row forward per tick | `prompts/foreman.md` | tasks |
| `code-factory-docs` | documentation truth | `prompts/docs.md` | cooldown |
| `code-factory-readme` | stranger-facing README path | `prompts/readme.md` | cooldown |
| `code-factory-releng` | release and public-posture checks | `prompts/releng.md` | cooldown |
| `code-factory-perf` | measurements and regressions | `prompts/perf.md` | cooldown |
| `code-factory-review` | review and evidence reconciliation | `prompts/review.md` | cooldown |
| `code-factory-qa` | re-run completed evidence, re-open what does not reproduce | `prompts/qa.md` | cooldown |
| `code-factory-pm` | tighten requirements into falsifiable criteria | `prompts/pm.md` | cooldown |
| `code-factory-dogfood` | walk the documented path as a user and report friction | `prompts/dogfood.md` | cooldown |
| `code-factory-sync` | board/repo/doc drift | `prompts/sync.md` | cooldown |
| `code-factory-duckbrain` | dated decision records | `prompts/duckbrain.md` | cooldown |
| `code-factory-docs-qa` | QA for the docs lane | `prompts/qa.md` | cooldown |
| `code-factory-readme-qa` | QA for the README lane | `prompts/qa.md` | cooldown |
| `code-factory-releng-qa` | QA for the release lane | `prompts/qa.md` | cooldown |

The six core lane rows are configured by `scripts/load_lane_config.py`; the eight added family rows
(workdir, parent, admission mode) by `scripts/add_family_lanes.py`. Prompts are role files, not
lane files: `prompts/` ships eleven files for fourteen lanes, and every QA-job lane (the three QA
satellites and `code-factory-qa` itself) loads the same `prompts/qa.md`. The loader copies the
prompt text into the scheduler's project row at setup, so edit the file in `prompts/` and re-run
the loader; the database row is only a copy of it. `tests/selftest.sh` refuses a README that names
a prompt file the tree does not ship.

The table above is the family these two loaders configure, and its admission column is the value
the loaders write at setup. A live scheduler can differ in both directions: a row can be flipped
after setup, and rows this repo does not configure can exist. Read the state, do not infer it:

```bash
(
BASE=http://127.0.0.1:9090
tmpd=$(mktemp -d) || { echo 'census: cannot create temporary directory' >&2; exit 1; }
trap 'rm -rf "$tmpd"' EXIT
census_page() {
  status=$(curl -sS --connect-timeout 5 --max-time 15 -o "$tmpd/page.json" \
    -w '%{http_code}' "$BASE/api/v1/projects?$1") || {
    echo "census: fetch failed at offset=$2" >&2; exit 1;
  }
  case "$status" in
    2??) ;;
    *) echo "census: HTTP $status at offset=$2; refusing to count" >&2; exit 1 ;;
  esac
  jq -e '.projects | type == "array"' "$tmpd/page.json" >/dev/null 2>&1 || {
    echo "census: missing or invalid .projects array at offset=$2" >&2; exit 1;
  }
}
census_page 'limit=1' 0
total=$(jq -r '.total // empty' "$tmpd/page.json")
[ -n "$total" ] || { echo 'census: the scheduler answered without a total; refusing to count' >&2; exit 1; }
[[ "$total" =~ ^[0-9]+$ ]] || { echo "census: invalid total '$total'; refusing to count" >&2; exit 1; }
total=$((10#$total))
off=0; received=0; : > "$tmpd/rows.jsonl"
while [ "$off" -lt "$total" ]; do
  census_page "limit=500&offset=$off" "$off"
  n=$(jq '.projects | length' "$tmpd/page.json") || { echo "census: cannot count offset=$off" >&2; exit 1; }
  received=$((received + n))
  jq -c '.projects[]' "$tmpd/page.json" >> "$tmpd/rows.jsonl" || { echo "census: cannot collect offset=$off" >&2; exit 1; }
  off=$((off + 500))
done
[ "$received" -eq "$total" ] || {
  echo "census: rows received=$received != total reported=$total; refusing to count" >&2; exit 1;
}
jq -r 'select(.name|startswith("code-factory"))
       | "\(.name) enabled=\(.enabled) admission=\(.admission_mode) parent=\(.parent // "-")"' \
  "$tmpd/rows.jsonl" > "$tmpd/lanes.txt" || { echo 'census: cannot format rows' >&2; exit 1; }
wc -l < "$tmpd/lanes.txt"; cat "$tmpd/lanes.txt"
)
```

The inventory endpoint pages: it caps a page at 500 rows and answers `{projects,total,limit,offset}`, and
a whole fleet is larger than one page. Read `total` first and walk the pages, as above — a single
`limit=500` request inspects only its own page, so a family whose rows sort past the page boundary
prints an empty or short census without any error. The recipe above refuses failed fetches,
non-2xx responses, missing or invalid `.projects` arrays, and an unfiltered row count that differs
from the first reported `total`; it prints no family census until all pages pass.

That command is the authority, not this paragraph. On the reference deployment, on 2026-11-04, it
printed nineteen rows: the fourteen above plus five `code-factory-duckbrain-*` satellites whose rows
this repo does not create (they are not part of the shipped family and are not counted in the
fourteen) and whose `enabled` state and admission mode live only in that scheduler. Of the fourteen,
thirteen carried `enabled=true` and `code-factory-qa` carried `enabled=false` — the scheduler had
disabled that lane on its own failure rate, which is the kind of drift a census catches and a
hand-written count does not. The same run printed `code-factory-duckbrain admission=tasks` against
the `cooldown` the loader writes — the drift the command exists to expose.

Evidence for the state of this README: the clone figure is covered by the published audit `docs/audits/code-factory-readme-2026-10-30-20-29-25.md`; the prompt column and the eleven-file/layout census are covered by the published audit `docs/audits/code-factory-readme-2026-10-30-23-28-00.md` (whose command transcript is the `.probe.txt` beside it).

ch:trace row=CF-038 spec=README.md#evidence wave=none:serial test=bash-tests/selftest.sh doc=README.md evidence=docs/audits/code-factory-readme-2026-10-30-23-28-00.md witness=path@origin:README.md verdict=none:foreman-judges-after-merge commit=none:self-referential-hash memory=none:not-written

ch:trace row=CF-014 spec=README.md#quick-start wave=code-factory-readme-2026-10-30-18-28-33#readme test=scripts/project-node.sh::check-project-demo doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-18-28-33.md witness=path@origin:README.md verdict=none:open-finding commit=none:open memory=/project/code-factory/readme-audit-2026-10-30-18-28-33
ch:trace row=CF-013 spec=README.md#status wave=code-factory-readme-2026-10-30-18-28-33#readme test=scripts/harness/install-hermes.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-18-28-33.md witness=none:no-live-bunker-or-gateway-available verdict=none:open-finding commit=none:open memory=/project/code-factory/readme-audit-2026-10-30-18-28-33
ch:trace row=CF-065 spec=README.md#the-lanes wave=none:serial test=tests/selftest.sh::selftest doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-11-03-15-41-00-cf065.probe.txt witness=path@origin:README.md verdict=none:judged-after-commit commit=none:self-referential-hash memory=none:no-lane-role-token
ch:trace row=CF-064 spec=README.md#status wave=code-factory-readme-2026-11-03-16-51-21#readme test=scripts/harness/install-hermes.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-CF-064.probe.txt witness=cmd:exit-1/inference_key-rows-0-vs-1 verdict=none:judged-after-commit commit=none:self-referential-hash memory=none:no-lane-role-token

ch:trace row=CF-151 spec=README.md#status test=tests/selftest.sh::selftest doc=README.md evidence=none:worker-transcript witness=cmd:exit-0/selftest-section-37 verdict=none:judged-after-commit commit=none:self-referential-hash memory=none:not-written
