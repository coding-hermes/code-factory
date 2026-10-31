# code-factory

The distributed coding workforce: **one Hermes foreman on the control host** designs and
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
scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes
```

On a host with no bunker server, no Crier and no repo, all three commands reach their checkers and
fail with the missing value named. That is the honest result on a fresh host, and every message
tells you which value to supply.

## Layout

```
docs/            DESIGN.md, PRD-code-factory.md, OPERATIONS.md, BOARD.md; audits/ holds tick evidence
specs/           NODE.md (what a node is), ENVELOPE.md (dispatch/result), HARNESS.md (adapters)
scripts/         node checks and provisioners: bunker-server-install.sh, project-node.sh,
                 node-create.sh, verify-node.sh, lib.sh
scripts/harness/ install-<harness>.sh — shipped: hermes, claude-code, opencode.
                 codex, aider, goose and pi-agent are documented in specs/HARNESS.md and ship
                 no installer yet (CF-006)
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
| Hermes in a bunker + HTTP gateway over tailnet | **works (historical measurement)** — observed on a live node on 2026-10-29: 32 s install, `/api/status` 200, 133 JSON-RPC methods. The recorded measurement is in `specs/HARNESS.md#adapters-and-their-measured-state` and the repo-local audit `docs/audits/code-factory-readme-2026-10-30-20-29-25.md#2-status-table-both-command-bearing-rows`; it is not reproducible from this repo alone. Current local evidence is only `scripts/harness/install-hermes.sh --check`, which reports the pinned version, port and inference-key state. `--apply` needs Python 3.11–3.13 — the pinned `hermes-agent==0.19.0` declares `Requires-Python >=3.11,<3.14`, so Python 3.14 stops at `FAIL install — pip failed` (CF-036). | Re-run the current local check: `scripts/harness/install-hermes.sh --check`. For the historical figures, read the committed artifact named in the state cell; no live endpoint or credential is claimed here. |
| Repo clone in a node | **works (historical local measurement)** for public HTTPS — `PASS repo_clone … @ 9402f6a` was measured on 2026-10-30 with `https://github.com/github/gitignore` and is recorded in `docs/audits/code-factory-readme-2026-10-30-20-29-25.md#2-status-table-both-command-bearing-rows`. A re-run derives the current HEAD, which may move. **Layer 40 is clone-only**: it establishes the pinned repository clone, not a build or build cache (CF-032). Private repos are **blocked** — a deploy key has no tested procedure yet. | Re-run with a temporary HOME and the same public fixture: `home=$(mktemp -d); HOME="$home" ./scripts/project-node.sh --apply --project myproject --repo https://github.com/github/gitignore --ref main; git -C "$home/repo" rev-parse HEAD`. The committed audit records the historical output and read-back command. |
| Node inference credential | **missing** — a turn dies at `No inference provider configured`; the node needs its own key, never an operator key | `scripts/harness/install-hermes.sh --check` -> `FAIL inference_key` |
| crier identity in a node | **missing** — no `~/.node/crier.json` yet | `./scripts/project-node.sh --check --project myproject` -> `FAIL crier_identity` |
| Scheduler → crier dispatch | **built, disarmed** — needs 2 env vars, 1 target row, `payload.text` (CF-001) | not armed, so nothing to run |
| Round trip through the node's own gateway | **not yet** — no checked-in command proves it; the one attempt used a bespoke poller rather than the node's gateway (CF-004) | no command exists to fail |

Two things the commands above do not show. `--ref` defaults to `main`, so a public repo whose
default branch is named differently fails the clone until you pass `--ref <branch>`. And a failed
clone always appends the `private repos need a deploy key` hint, even when the real cause is a
missing branch (CF-034).

See `.coding-hermes/board/tasks.jsonl` for the work items and their acceptance criteria.

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

The scheduler also carries disabled `code-factory-duckbrain-*` rows. They are not part of the
shipped family above and are not counted in the fourteen.

Evidence for the state of this README: `docs/audits/code-factory-readme-2026-10-30-20-29-25.md` for how the rows, layout and lane table were written, and `docs/audits/code-factory-readme-2026-10-30-23-28-00.md` for the latest command-by-command re-run (its transcript is the `.probe.txt` beside it).

ch:trace row=CF-014 spec=README.md#quick-start wave=code-factory-readme-2026-10-30-18-28-33#readme test=scripts/project-node.sh::check-project-demo doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-18-28-33.md witness=path@origin:README.md verdict=none:open-finding commit=none:open memory=/project/code-factory/readme-audit-2026-10-30-18-28-33
ch:trace row=CF-013 spec=README.md#status wave=code-factory-readme-2026-10-30-18-28-33#readme test=scripts/harness/install-hermes.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-18-28-33.md witness=none:no-live-bunker-or-gateway-available verdict=none:open-finding commit=none:open memory=/project/code-factory/readme-audit-2026-10-30-18-28-33
