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
# 1. can this host run the factory at all?
scripts/bunker-server-install.sh --check

# 2. what does a node look like right now (inside an agent)?
./scripts/project-node.sh --check --agent <id>

# 3. make one
scripts/project-node.sh --project crier --agent <id> --repo git@… --harness hermes
```

## Layout

```
docs/            DESIGN.md, PRD-code-factory.md, ACCEPTANCE-PLAN.md, OPERATIONS.md, THREAT-MODEL.md
specs/           NODE.md (what a node is), ENVELOPE.md (dispatch/result), HARNESS.md (adapters)
scripts/         bunker-server-install.sh, project-node.sh, verify-node.sh, lib.sh, boardctl
scripts/harness/ install-<harness>.sh — one per foreign agent (opencode, claude-code, codex, aider, goose, pi-agent)
.coding-hermes/board/  tasks.jsonl (JSONL, git-tracked) + events.jsonl
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

| Piece | State |
|---|---|
| Hermes in a bunker + HTTP gateway over tailnet | **works** — 32 s install, `/api/status` 200, 133 JSON-RPC methods |
| Repo clone + build in a node | **works** for public https; private needs a deploy key |
| Node inference credential | **missing** — a turn dies at `No inference provider configured` |
| crier identity in a node | **missing** — no `~/.node/crier.json` yet |
| Scheduler → crier dispatch | **built, disarmed** — needs 2 env vars, 1 target row, `payload.text` |
| Round trip through the node's own gateway | **not yet** — MDP-1 used a bespoke poller |

See `.coding-hermes/board/tasks.jsonl` for the work items and their acceptance criteria. Use the
repository board interface (`scripts/boardctl`); the command contract and current validation results
are in [`docs/BOARD.md`](docs/BOARD.md). The PRD's falsifiable checks and real acceptance status are
tracked in [`docs/ACCEPTANCE-PLAN.md`](docs/ACCEPTANCE-PLAN.md); operating steps and known blockers are
in [`docs/OPERATIONS.md`](docs/OPERATIONS.md), and security assumptions/residual risks are in
[`docs/THREAT-MODEL.md`](docs/THREAT-MODEL.md). Scheduler lane admission roots and cadence pins are in
[`docs/SCHEDULER-ADMISSION.md`](docs/SCHEDULER-ADMISSION.md).

## Running it against your own infrastructure

This repo carries no endpoints, hostnames or credentials. Three environment variables and one
harness are all it assumes:

```bash
export CRIER_URL=http://crier.example:8767     # your message bus
export BUNKER_SERVER=your-bunker-server        # your agent host
scripts/bunker-server-install.sh --check       # does this control host qualify?
scripts/node-create.sh --project myrepo \
    --repo https://github.com/you/myrepo --harness hermes
```

A node needs a repo it is allowed to clone and an inference credential of its own — never an
operator key. `specs/HARNESS.md` records which harness ladders are measured and which are only
documented; an unmeasured adapter refuses `--apply` rather than pretending.

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

| Lane | Job | Admission |
|---|---|---|
| `code-factory` | foreman — one board row forward per tick | tasks |
| `code-factory-docs` | documentation truth | cooldown |
| `code-factory-readme` | stranger-facing README path | cooldown |
| `code-factory-releng` | release and public-posture checks | cooldown |
| `code-factory-perf` | measurements and regressions | cooldown |
| `code-factory-review` | review and evidence reconciliation | cooldown |
| `code-factory-qa` | re-run completed evidence, re-open what does not reproduce | cooldown |
| `code-factory-pm` | tighten requirements into falsifiable criteria | cooldown |
| `code-factory-dogfood` | walk the documented path as a user and report friction | cooldown |
| `code-factory-sync` | board/repo/doc drift | cooldown |
| `code-factory-duckbrain` | dated decision records | cooldown |
| `code-factory-docs-qa` | QA for the docs lane | cooldown |
| `code-factory-readme-qa` | QA for the README lane | cooldown |
| `code-factory-releng-qa` | QA for the release lane | cooldown |

The core lane rows are defined in `scripts/load_lane_config.py`; the added family rows are
listed in `scripts/add_family_lanes.py`. Each lane's prompt lives in `prompts/<lane>.md` and is
loaded with `scripts/load_lane_config.py` — the file is the source of truth, not the database row.

ch:trace row=CF-005 spec=docs/PRD-code-factory.md#requirements wave=code-factory-docs-2026-10-29-20-26-27#docs test=tests/selftest.sh::selftest doc=README.md prompt=prompts/docs.md evidence=docs/audits/code-factory-docs-2026-10-29-20-26-27.md witness=none:source-and-local-scheduler-db-only verdict=none:open-finding commit=none:open memory=none:unresolved-namespace

STATUS: PASS
TIER: T4 -- queried the real local scheduler SQLite project inventory and ran the repository selftest
EVIDENCE: sqlite3 /home/kara/.hermes/coding-hermes/scheduler.db inventory query; bash tests/selftest.sh
