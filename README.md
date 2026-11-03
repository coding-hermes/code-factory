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
| Hermes in a bunker + HTTP gateway over tailnet | **works (historical measurement)** — observed on a live node on 2026-10-29: 32 s install, `/api/status` 200, 133 JSON-RPC methods. The recorded measurement is in `specs/HARNESS.md#adapters-and-their-measured-state` and the repo-local audit `docs/audits/code-factory-readme-2026-10-30-20-29-25.md#2-status-table-both-command-bearing-rows`; it is not reproducible from this repo alone. Current local evidence is only `scripts/harness/install-hermes.sh --check`. On this host's default `python3` (3.14) that command prints exactly one gate row — `FAIL python` — and never reaches the binary or port arms; the binary, port and `inference_key` rows print only on an interpreter inside the pin's range (`HERMES_PYTHON_BIN=python3.12` prints four when no `hermes` binary is installed — that is the recorded arm — and five on a host where `~/.local/bin/hermes` exists, because a `version` row is added; re-measured on this host on 2026-11-03: rows python, binary, version, port, `inference_key`, `HERMES: FAIL (1)`, rc 1). Both arms, with the measured gate-row counts (1 vs 4), the binary/port rows they carry (0/1) and both exit codes, are in `docs/audits/cf092-install-check-arms.txt`; the `inference_key` pair is also in `docs/audits/code-factory-CF-064.probe.txt` (CF-064, CF-092). `--apply` needs Python `>=3.11,<3.14` — the pinned `hermes-agent==0.19.0` declares that range, and the installer now refuses Python 3.14 before pip with the detected version. The exact selftest/check output is recorded in `docs/audits/code-factory-CF-036.md` (CF-036). | Re-run the current local check with an interpreter inside the pin's range — `HERMES_PYTHON_BIN=python3.12 scripts/harness/install-hermes.sh --check` — which prints four gate rows when no `hermes` binary is installed (python, binary, port, `inference_key`) and five on a host where `~/.local/bin/hermes` exists (adds `version`). The unqualified `scripts/harness/install-hermes.sh --check` is the same command on the default `python3`, and there it prints one row: `FAIL python`. For the historical figures, read the committed artifact named in the state cell; no live endpoint or credential is claimed here. |
| Repo clone in a node | **works (historical local measurement)** for public HTTPS — `PASS repo_clone … @ 9402f6a` was measured on 2026-10-30 with `https://github.com/github/gitignore` and is recorded in `docs/audits/code-factory-readme-2026-10-30-20-29-25.md#2-status-table-both-command-bearing-rows`. A re-run derives the current HEAD, which may move. Layer 40 clones only; no build step is shipped. Private repos are **blocked** — a deploy key has no tested procedure yet. | Re-run with a temporary HOME and the same public fixture: `home=$(mktemp -d); CRIER_URL=http://crier.example:8767 HOME="$home" ./scripts/project-node.sh --apply --project myproject --repo https://github.com/github/gitignore --ref main`. The node check is the last command on that line, so the line's exit status is the check's: `NODE: FAIL` exits nonzero. Read the clone back in a second command, not the same line: `git -C "$home/repo" rev-parse HEAD`. The committed audit records the historical output. |
| Node inference credential | **missing** — a turn dies at `No inference provider configured`; the node needs its own key, never an operator key | `scripts/harness/install-hermes.sh --check` -> `FAIL inference_key`. That row prints only on an interpreter inside the pin's range; the default `python3` here is 3.14 and stops at `FAIL python` first, so name one explicitly: `HERMES_PYTHON_BIN=python3.12 scripts/harness/install-hermes.sh --check` -> `FAIL inference_key`. Both arms are transcripted in `docs/audits/code-factory-CF-064.probe.txt` (CF-064). |
| crier identity in a node | **missing** — no `~/.node/crier.json` yet | `./scripts/project-node.sh --check --project myproject` -> `FAIL crier_identity` |
| Scheduler → crier dispatch | **built, disarmed** — needs 2 env vars, 1 target row, `payload.text` (CF-001) | not armed, so nothing to run |
| Round trip through the node's own gateway | **not yet** — no checked-in command proves it; the one attempt used a bespoke poller rather than the node's gateway (CF-004) | no command exists to fail |

`--ref` defaults to `main`, so a public repo whose default branch is named differently needs
`--ref <branch>`. A missing ref reports that ref and the `--ref` flag; a repository-access failure
retains the deploy-key hint for private repositories (CF-034).

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

On the reference deployment that prints nineteen rows: the fourteen above, all `enabled=true`, plus
five `code-factory-duckbrain-*` satellites whose rows this repo does not create (they are not part
of the shipped family and are not counted in the fourteen) and whose `enabled` state and admission
mode live only in that scheduler. It also prints `code-factory-duckbrain admission=tasks` against
the `cooldown` the loader writes — the drift the command exists to expose.

Evidence for the state of this README: the clone figure is covered by the published audit `docs/audits/code-factory-readme-2026-10-30-20-29-25.md`; the prompt column and the eleven-file/layout census are covered by the published audit `docs/audits/code-factory-readme-2026-10-30-23-28-00.md` (whose command transcript is the `.probe.txt` beside it).

ch:trace row=CF-038 spec=README.md#evidence wave=none:serial test=bash-tests/selftest.sh doc=README.md evidence=docs/audits/code-factory-readme-2026-10-30-23-28-00.md witness=path@origin:README.md verdict=none:foreman-judges-after-merge commit=none:self-referential-hash memory=none:not-written

ch:trace row=CF-014 spec=README.md#quick-start wave=code-factory-readme-2026-10-30-18-28-33#readme test=scripts/project-node.sh::check-project-demo doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-18-28-33.md witness=path@origin:README.md verdict=none:open-finding commit=none:open memory=/project/code-factory/readme-audit-2026-10-30-18-28-33
ch:trace row=CF-013 spec=README.md#status wave=code-factory-readme-2026-10-30-18-28-33#readme test=scripts/harness/install-hermes.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-18-28-33.md witness=none:no-live-bunker-or-gateway-available verdict=none:open-finding commit=none:open memory=/project/code-factory/readme-audit-2026-10-30-18-28-33
ch:trace row=CF-065 spec=README.md#the-lanes wave=none:serial test=tests/selftest.sh::selftest doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-11-03-15-41-00-cf065.probe.txt witness=path@origin:README.md verdict=none:judged-after-commit commit=none:self-referential-hash memory=none:no-lane-role-token
ch:trace row=CF-064 spec=README.md#status wave=code-factory-readme-2026-11-03-16-51-21#readme test=scripts/harness/install-hermes.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-CF-064.probe.txt witness=cmd:exit-1/inference_key-rows-0-vs-1 verdict=none:judged-after-commit commit=none:self-referential-hash memory=none:no-lane-role-token

