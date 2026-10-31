# code-factory README probe transcript — tick 2026-10-30-23-28-00
# generated 2026-10-31T01:20:19Z; concatenation of runs A, B and C.

########## RUN A — README command matrix at published tip ##########
=== PROBE META ===
date: 2026-10-31T01:18:02Z
source repo: /home/kara/code-factory
published tip: refs/heads/main = e2fc9d735376746f70a017ce8f161eb3af1010d9
archive sha256 (tar of tree): cfa8a7e4f69a2e0b37dad8dfc1fbfb819adc6c0ad4b16dcfd24ef37561a1636a
isolated HOME: /home/kara/.hermes/cache/scratch/cf-readme-2328/home

=== ENV before ===
BUNKER_SERVER=<unset> CRIER_URL=<unset>

=== QS-1 unexported (README step 1 as written, no vars exported) ===
$ scripts/bunker-server-install.sh --check
scripts/bunker-server-install.sh: line 14: BUNKER_SERVER: set BUNKER_SERVER to your bunker server name
EXIT: 1

=== QS-1 with placeholder env ===
$ export CRIER_URL=http://crier.example:8767 BUNKER_SERVER=your-bunker-server; scripts/bunker-server-install.sh --check
bunker server: your-bunker-server
  PASS  bunker_client — /usr/local/bin/bunker bunker 0.2.0
  FAIL  bunker_config — missing (/home/kara/.hermes/cache/scratch/cf-readme-2328/home/.config/bunker/config.yaml) — the client has no server to talk to
  FAIL  server_reachable — your-bunker-server did not answer: bunker: reading server "your-bunker-server"
  PASS  tool:python3 — /usr/bin/python3
  PASS  tool:git — /usr/bin/git
  PASS  tool:curl — /usr/bin/curl
  PASS  tool:jq — /usr/bin/jq
  PASS  disk — 234.1 GB free (floor 5 GB)

RESULT: FAIL (2)
EXIT: 1

=== QS-2 project-node --check ===
$ ./scripts/project-node.sh --check --project myproject
node provisioning — project=myproject harness=hermes host=karaHermes-mde-7840hs
[00] preflight
  PASS  arch — x86_64 (Linux 7.0.0-38-generic)
  PASS  disk — 234.1 GB free (floor 5 GB)
  PASS  mem — 45375 MB
  FAIL  crier_url — CRIER_URL unset — the node has nothing to connect to (export CRIER_URL=http://crier.example:8767)
[10] base
  PASS  tool:python3 — /usr/bin/python3
  PASS  tool:git — /usr/bin/git
  PASS  tool:curl — /usr/bin/curl
  PASS  tool:tar — /usr/bin/tar
  PASS  tool:sha256sum — /usr/bin/sha256sum
  PASS  python:venv — importable
  PASS  tool:jq — /usr/bin/jq
  PASS  tool:rg — /usr/bin/rg
  PASS  tool:node — /usr/bin/node
[20] harness
harness: hermes (pin 0.19.0, port 10800)
  FAIL  binary — absent — run --apply
  FAIL  port — nothing on :10800
  FAIL  inference_key — no provider key — a turn dies at 'No inference provider configured'

HERMES: FAIL (3)
[30] bus
  FAIL  crier_identity — absent — stage a bundle and re-run; a node without an identity is invisible
[40] repo
  FAIL  repo — /home/kara/.hermes/cache/scratch/cf-readme-2328/home/repo absent (pass --repo to clone)
[90] manifest
  ..    manifest is written only when every layer passes

NODE: FAIL (3)
EXIT: 1

=== QS-3 node-create ===
$ scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes
scripts/node-create.sh: line 12: BUNKER_SERVER: set BUNKER_SERVER to your bunker server name
EXIT: 1

=== STATUS-73 install-hermes --check ===
$ scripts/harness/install-hermes.sh --check
harness: hermes (pin 0.19.0, port 10800)
  FAIL  binary — absent — run --apply
  FAIL  port — nothing on :10800
  FAIL  inference_key — no provider key — a turn dies at 'No inference provider configured'

HERMES: FAIL (3)
EXIT: 1

=== STATUS-74 project-node --apply --repo ===
$ ./scripts/project-node.sh --apply --project myproject --repo https://github.com/you/myrepo
node provisioning — project=myproject harness=hermes host=karaHermes-mde-7840hs
[00] preflight
  PASS  arch — x86_64 (Linux 7.0.0-38-generic)
  PASS  disk — 234.1 GB free (floor 5 GB)
  PASS  mem — 45347 MB
  FAIL  crier_url — CRIER_URL unset — the node has nothing to connect to (export CRIER_URL=http://crier.example:8767)
[10] base
  PASS  tool:python3 — /usr/bin/python3
  PASS  tool:git — /usr/bin/git
  PASS  tool:curl — /usr/bin/curl
  PASS  tool:tar — /usr/bin/tar
  PASS  tool:sha256sum — /usr/bin/sha256sum
  PASS  python:venv — importable
  PASS  tool:jq — /usr/bin/jq
  PASS  tool:rg — /usr/bin/rg
  PASS  tool:node — /usr/bin/node
[20] harness
harness: hermes (pin 0.19.0, port 10800)
  FAIL  binary — absent — run --apply
  FAIL  port — nothing on :10800
  FAIL  inference_key — no provider key — a turn dies at 'No inference provider configured'
apply
  FAIL  install — pip failed — /tmp/hermes-install.log
[30] bus
  FAIL  crier_identity — absent — stage a bundle and re-run; a node without an identity is invisible
[40] repo
  ..    cloning https://github.com/you/myrepo @ main
  FAIL  repo_clone — fatal: could not read Username for 'https://github.com': No such device or address (private repos need a deploy key)
[90] manifest
  ..    manifest is written only when every layer passes

NODE: FAIL (3)
EXIT: 1

=== STATUS-76 project-node --check (crier_identity) ===
$ ./scripts/project-node.sh --check --project myproject
node provisioning — project=myproject harness=hermes host=karaHermes-mde-7840hs
[00] preflight
  PASS  arch — x86_64 (Linux 7.0.0-38-generic)
  PASS  disk — 234.1 GB free (floor 5 GB)
  PASS  mem — 45457 MB
  FAIL  crier_url — CRIER_URL unset — the node has nothing to connect to (export CRIER_URL=http://crier.example:8767)
[10] base
  PASS  tool:python3 — /usr/bin/python3
  PASS  tool:git — /usr/bin/git
  PASS  tool:curl — /usr/bin/curl
  PASS  tool:tar — /usr/bin/tar
  PASS  tool:sha256sum — /usr/bin/sha256sum
  PASS  python:venv — importable
  PASS  tool:jq — /usr/bin/jq
  PASS  tool:rg — /usr/bin/rg
  PASS  tool:node — /usr/bin/node
[20] harness
harness: hermes (pin 0.19.0, port 10800)
  FAIL  binary — absent — run --apply
  FAIL  port — nothing on :10800
  FAIL  inference_key — no provider key — a turn dies at 'No inference provider configured'

HERMES: FAIL (3)
[30] bus
  FAIL  crier_identity — absent — stage a bundle and re-run; a node without an identity is invisible
[40] repo
  FAIL  repo — /home/kara/.hermes/cache/scratch/cf-readme-2328/home/repo absent (pass --repo to clone)
[90] manifest
  ..    manifest is written only when every layer passes

NODE: FAIL (3)
EXIT: 1

=== BOARDCTL help ===
$ scripts/boardctl --help
code-factory board interface
Usage: scripts/boardctl <boardctl-command> [flags]
Examples: list --json --all | validate | show CF-001 | create --id CF-009 --title ...
Requires the coding-hermes boardctl executable; see docs/BOARD.md.
EXIT: 0

=== SELFTEST ===
$ bash tests/selftest.sh
1. every script parses
  PASS  bash -n bunker-server-install.sh
  PASS  bash -n lib.sh
  PASS  bash -n node-create.sh
  PASS  bash -n project-node.sh
  PASS  bash -n verify-node.sh
  PASS  bash -n install-claude-code.sh
  PASS  bash -n install-hermes.sh
  PASS  bash -n install-opencode.sh
  PASS  bash -n selftest.sh
2. the node checker FAILS on an empty PATH
  PASS  empty PATH -> exit 1
  PASS  report contains FAIL rows
3. fetch_verified refuses a wrong digest
  PASS  correct digest accepted
digest mismatch for file:///tmp/tmp.FewrQyIIu8/src: want 0000000000000000000000000000000000000000000000000000000000000000 got 5891b5b522d5df086d0ff0b110fbd9d21bb4fc7163af34d08286a2e846f6be03
  PASS  wrong digest refused
4. no literal credential assignments
  PASS  none found
5. the board is valid JSONL
  PASS  21/21 rows parse
6. project board entrypoint is real and fails closed without dependency
  PASS  bash -n scripts/boardctl
  PASS  local help
  PASS  missing boardctl -> explicit FAIL, exit 127
7. every prompt file the README relies on exists
  PASS  every prompts/*.md named by README.md exists
  PASS  absent prompt refused (absent: prompts/ghost-lane.md)

SELFTEST: PASS
EXIT: 0

=== CENSUS: prompts files (README says eleven) ===
11
docs.md
dogfood.md
duckbrain.md
foreman.md
perf.md
pm.md
qa.md
readme.md
releng.md
review.md
sync.md

=== CENSUS: scripts/harness shipped installers (README: hermes, claude-code, opencode) ===
install-claude-code.sh
install-hermes.sh
install-opencode.sh

=== CENSUS: scripts/ entries (README layout lists 5 + boardctl) ===
scripts/add_family_lanes.py
scripts/boardctl
scripts/bunker-server-install.sh
scripts/clone_lane.py
scripts/configure_family.py
scripts/load_lane_config.py
scripts/node-create.sh
scripts/project-node.sh
scripts/verify-node.sh

=== CENSUS: build/install invocations inside shipped node scripts (README: no build step) ===
matches: 0

=== CENSUS: --ref handling in project-node.sh (README CF-034) ===
6:#   project-node.sh --check   [--project P] [--harness hermes] [--repo URL] [--ref main]
9:# Layers: 00 preflight, 10 base, 20 harness, 30 bus, 40 repo, 90 verify (verify is the
31:    --ref) REF="$2"; shift 2 ;;
36:[ -z "$MODE" ] && { echo "usage: $0 --check|--apply [--project P] [--harness H] [--repo URL] [--ref R]"; exit 2; }
42:# ---------------------------------------------------------------- 00 preflight
43:say "[00] preflight"
109:path, project, harness, port, repo, ref, host = sys.argv[1:8]
111:           "repo": {"origin": repo, "ref": ref, "path": "/home/" + __import__("os").environ.get("USER", "node") + "/repo"},

=== CENSUS: does project-node.sh accept --repo? ===
6:#   project-node.sh --check   [--project P] [--harness hermes] [--repo URL] [--ref main]
30:    --repo) REPO="$2"; shift 2 ;;
36:[ -z "$MODE" ] && { echo "usage: $0 --check|--apply [--project P] [--harness H] [--repo URL] [--ref R]"; exit 2; }
100:    bad "repo" "$RP absent (pass --repo to clone)"

=== CENSUS: deploy-key hint always appended? ===
97:      bad "repo_clone" "$(tail -1 /tmp/clone.log) (private repos need a deploy key)"

=== CENSUS: inference_key string in install-hermes.sh ===
45:  ok "inference_key" "a provider key is present in ~/.hermes/.env (value not read)"
47:  bad "inference_key" "no provider key — a turn dies at 'No inference provider configured'"

=== CENSUS: historical figures 32 s / 133 JSON-RPC / 9402f6a in repo docs ===
/home/kara/.hermes/cache/scratch/cf-readme-2328/src/README.md:73:| Hermes in a bunker + HTTP gateway over tailnet | **works** — observed on a live node in October 2026 (32 s install, `/api/status` 200, 133 JSON-RPC methods); not reproducible from this repo alone | `scripts/harness/install-hermes.sh --check` names the version, port and key it measured |
/home/kara/.hermes/cache/scratch/cf-readme-2328/src/README.md:74:| Repo clone in a node | **works** for public https — `PASS repo_clone … @ 9402f6a` on 2026-10-30; the cloned repo's own HEAD moves, so re-run to re-derive. **No build step yet**: layer 40 clones only, so the build cache `specs/NODE.md` asks for is not established (CF-032). Private repos are **blocked** — a deploy key has no tested procedure yet | `./scripts/project-node.sh --apply --project myproject --repo https://github.com/you/myrepo` |
/home/kara/.hermes/cache/scratch/cf-readme-2328/src/specs/HARNESS.md:20:| **hermes** | `python3 -m venv` + `pip install hermes-agent==0.19.0`; `hermes serve --host 0.0.0.0 --port P --skip-build` | **MEASURED working**: 32 s install, `/api/status` 200 over tailnet, 133 JSON-RPC methods, `session.create` + `prompt.submit`. Needs a provider key in `~/.hermes/.env`. |
/home/kara/.hermes/cache/scratch/cf-readme-2328/src/docs/audits/code-factory-readme-2026-10-30-01-33-38.md:25:- The README still reports Hermes as **works** with `32 s install`, `/api/status 200`, and `133 JSON-RPC methods`, but the fresh `install-hermes.sh --check` failed and no repository-local rerunnable artifact proves those historical figures. Existing row CF-013 covers this.
/home/kara/.hermes/cache/scratch/cf-readme-2328/src/docs/audits/code-factory-readme-2026-10-30-00-02-33.md:25:- CF-013 covers the status table's historical Hermes claim. The current adapter check cannot reproduce the live gateway measurement from a fresh HOME; the claimed 32-second install, `/api/status` 200, and 133 JSON-RPC methods remain historical measurements in `specs/HARNESS.md`, not a current repo-local run.
/home/kara/.hermes/cache/scratch/cf-readme-2328/src/docs/audits/code-factory-readme-2026-10-30-18-28-33.md:84:counts in the status table (`32 s install`, `/api/status` 200, 133 JSON-RPC methods) are a
/home/kara/.hermes/cache/scratch/cf-readme-2328/src/docs/audits/code-factory-readme-2026-10-30-14-54-06.md:41:- CF-013: The status table calls the Hermes bunker/gateway path **works** and repeats historical `32 s`, `/api/status 200`, and `133 JSON-RPC methods`, but the fresh-HOME adapter check failed and no live bunker/gateway boundary was available for this sweep. The historical figures remain unverified, not disproven.
/home/kara/.hermes/cache/scratch/cf-readme-2328/src/docs/audits/code-factory-readme-2026-10-29-21-37-19.md:63:README.md:54 says Hermes in a bunker plus HTTP gateway works with a 32-second install, /api/status 200, and 133 JSON-RPC methods, but no repo artifact re-runs those figures and the current Hermes check cannot reproduce the gateway claim. Corrective direction: attach dated evidence or change the state to not currently verified.
/home/kara/.hermes/cache/scratch/cf-readme-2328/src/docs/audits/code-factory-readme-2026-10-29-22-35-38.md:36:- CF-013 remains covered: the README's Hermes status row still states a historical 32-second install, `/api/status` 200, and 133 JSON-RPC methods without a repo-local rerunnable evidence artifact; the fresh adapter check reported `HERMES: FAIL (2)` in the clean HOME because the port and provider key were absent.
/home/kara/.hermes/cache/scratch/cf-readme-2328/src/docs/audits/code-factory-readme-2026-10-30-20-29-25.md:59:figures (32 s install, `/api/status` 200, 133 JSON-RPC methods) are a historical observation and
/home/kara/.hermes/cache/scratch/cf-readme-2328/src/docs/audits/code-factory-readme-2026-10-30-20-29-25.md:82:  PASS  repo_clone — <HOME>/repo @ 9402f6a
/home/kara/.hermes/cache/scratch/cf-readme-2328/src/docs/audits/code-factory-readme-2026-10-30-20-29-25.md:84:Read back from disk after the run: `git -C <HOME>/repo log --oneline -1` → `9402f6a Merge pull
/home/kara/.hermes/cache/scratch/cf-readme-2328/src/docs/audits/code-factory-readme-2026-10-30-14-54-06-lanes.md:93:- `CF-013` — status rows "works" (32 s install, `/api/status` 200, 133 JSON-RPC methods) still carry
/home/kara/.hermes/cache/scratch/cf-readme-2328/src/docs/OPERATIONS.md:73:`specs/HARNESS.md` records a test-node measurement: Hermes Agent 0.19.0 installed in about 32 seconds, 248 MB venv; a gateway on the configured port answered `/api/status` with 200 over tailnet, and exposed 133 JSON-RPC methods. That historical measurement does not prove this node is working now. Use the exact adapter check/apply from inside the node:

=== CENSUS: AGENTS.md CF-108 citation and board census ===
41:   test. A node gets one bundle file, mode 600, deleted after provisioning (`CF-108`).
board rows named CF-108: 0
board max CF id: "id":"CF-035"

=== CENSUS: docs/traceability-doctrine.md present at tip? ===
ABSENT

=== CENSUS: gitreins guard (docs-only, unstaged) ===
  set guards.allow_skips: true in .gitreins/config.yaml to accept skips 
  on zero-work runs (gitreins init writes it for fresh repos).[0m
Tier 1: DEGRADED PASS (skips: lint=no staged files, tests=no staged files)  (test mode: full)
  ✓ secrets — clean (gitleaks + builtin cross-check); scanners: nice=nice -n 10
  ~ lint — skipped (no staged files)
  ~ tests — skipped (no staged files)
  guard log: /home/kara/.hermes/cache/scratch/cf-readme-2328/src/.gitreins/logs/guard-20261031T011808.431435Z.log

EXIT: 0

=== DONE ===

########## RUN B — literal README block, real public clone readback, evidence-pointer check ##########
date: 2026-10-31T01:18:58Z
tip: e2fc9d735376746f70a017ce8f161eb3af1010d9
=== QS-3 node-create with README exports (literal block) ===
$ scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes
node-create — project=myrepo harness=hermes server=your-bunker-server
  ..    spawning node-myrepo-201858 (ttl 6h)
  FAIL  spawn — bunker: server "your-bunker-server" not found in config
EXIT: 1

=== QS-1 with README exports (literal block) ===
$ scripts/bunker-server-install.sh --check
bunker server: your-bunker-server
  PASS  bunker_client — /usr/local/bin/bunker bunker 0.2.0
  FAIL  bunker_config — missing (/home/kara/.hermes/cache/scratch/cf-readme-2328b/home/.config/bunker/config.yaml) — the client has no server to talk to
  FAIL  server_reachable — your-bunker-server did not answer: bunker: reading server "your-bunker-server"
  PASS  tool:python3 — /usr/bin/python3
  PASS  tool:git — /usr/bin/git
  PASS  tool:curl — /usr/bin/curl
  PASS  tool:jq — /usr/bin/jq
  PASS  disk — 234.1 GB free (floor 5 GB)

RESULT: FAIL (2)
EXIT: 1

=== QS-3 PREMISE: is scripts/node-create.sh line 12 a :? expansion (dies before any checker)? ===
#!/usr/bin/env bash
# node-create.sh — control host: create a node from a project + repo + harness triple.
#
#   ./node-create.sh --project crier --repo git@… --harness hermes [--agent <id>] [--ttl 6h]
#
# Spawns the agent if needed, stages the scripts into it, runs project-node.sh --apply inside,
# then runs verify-node.sh. Idempotent: an existing agent is reused, not respawned.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"

PROJECT="" REPO="" HARNESS="hermes" AGENT="" TTL="6h" SERVER="${BUNKER_SERVER:?set BUNKER_SERVER to your bunker server name}" PORT=10800

while [ $# -gt 0 ]; do
  case "$1" in
    --project) PROJECT="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --harness) HARNESS="$2"; shift 2 ;;
    --agent) AGENT="$2"; shift 2 ;;
    --ttl) TTL="$2"; shift 2 ;;

=== QS-3 PREMISE: bunker client detection in scripts/lib.sh ===
#!/usr/bin/env bash
# lib.sh — shared helpers for every script in this repo.
# Sourced, never executed. Requires bash.

say()  { printf '%s\n' "$*"; }
ok()   { printf '  PASS  %s — %s\n' "$1" "$2"; }
bad()  { printf '  FAIL  %s — %s\n' "$1" "$2"; FAILED=$((FAILED+1)); }
warn() { printf '  WARN  %s — %s\n' "$1" "$2"; }
note() { printf '  ..    %s\n' "$*"; }

FAILED=${FAILED:-0}

have() { command -v "$1" >/dev/null 2>&1 && command -v "$1" || true; }

# A pinned download that refuses a digest mismatch (CF-105). Never pipes to a shell.
fetch_verified() {
  local url="$1" dest="$2" want="$3"
  local tmp; tmp="$(mktemp)"
  curl -fsSL --max-time 120 -o "$tmp" "$url" || { rm -f "$tmp"; return 1; }
  local got; got=$(sha256sum "$tmp" | cut -d' ' -f1)

=== CLONE real public repo (README row 74 'works for public https') ===
$ ./scripts/project-node.sh --apply --project myproject --repo https://github.com/github/gitignore
node provisioning — project=myproject harness=hermes host=karaHermes-mde-7840hs
[00] preflight
  PASS  arch — x86_64 (Linux 7.0.0-38-generic)
  PASS  disk — 234.1 GB free (floor 5 GB)
  PASS  mem — 45546 MB
  FAIL  reach:http://crier.example:8767/health — -> 000000
  PASS  reach:https://pypi.org/simple/ — 200
[10] base
  PASS  tool:python3 — /usr/bin/python3
  PASS  tool:git — /usr/bin/git
  PASS  tool:curl — /usr/bin/curl
  PASS  tool:tar — /usr/bin/tar
  PASS  tool:sha256sum — /usr/bin/sha256sum
  PASS  python:venv — importable
  PASS  tool:jq — /usr/bin/jq
  PASS  tool:rg — /usr/bin/rg
  PASS  tool:node — /usr/bin/node
[20] harness
harness: hermes (pin 0.19.0, port 10800)
  FAIL  binary — absent — run --apply
  FAIL  port — nothing on :10800
  FAIL  inference_key — no provider key — a turn dies at 'No inference provider configured'
apply
  FAIL  install — pip failed — /tmp/hermes-install.log
[30] bus
  FAIL  crier_identity — absent — stage a bundle and re-run; a node without an identity is invisible
[40] repo
  ..    cloning https://github.com/github/gitignore @ main
  PASS  repo_clone — /home/kara/.hermes/cache/scratch/cf-readme-2328b/home/repo @ 6bb5af7
[90] manifest
  ..    manifest is written only when every layer passes

NODE: FAIL (2)
EXIT: 1

=== CLONE READBACK from isolated HOME (not from the script's own output) ===
path: /home/kara/.hermes/cache/scratch/cf-readme-2328b/home/repo
6bb5af7 Merge pull request #4802 from sonikaxel/patch-1
HEAD: 6bb5af7a1b050e5add3a71b6e6365c93498822ac
tracked files: 319
build artefacts present? (node_modules/dist/target/.venv): 0

=== README:74 evidence pointer — which audit carries the @9402f6a clone measurement? ===
/home/kara/.hermes/cache/scratch/cf-readme-2328b/src/docs/audits/code-factory-readme-2026-10-30-20-29-25.md
--- README self-cited evidence line ---
157:Evidence for the state of this README: `docs/audits/code-factory-readme-2026-10-30-18-28-33.md`.
--- does the self-cited audit mention the current text (Prompt column / eleven files / repo_clone)? ---
repo_clone:    0
9402f6a:       0
Prompt:        0
eleven:        0

=== DONE ===

=== PART 3 — repository checks (same archive, 2026-10-31T01:20:19Z) ===

=== bash -n sweep over every shipped shell script ===
EXIT: 0

=== make docs-check (no Makefile at the published tip) ===
make: *** No rule to make target 'docs-check'.  Stop.
EXIT: 2

=== interpreter on this probe host ===
Python 3.14.9
=== the pip failure behind 'FAIL install — pip failed' ===
ERROR: Ignored the following versions that require a different python version: 0.16.0 Requires-Python <3.14,>=3.11; 0.17.0 Requires-Python <3.14,>=3.11; 0.18.0 Requires-Python <3.14,>=3.11; 0.18.1 Requires-Python <3.14,>=3.11; 0.18.2 Requires-Python <3.14,>=3.11; 0.19.0 Requires-Python <3.14,>=3.11
ERROR: Could not find a version that satisfies the requirement hermes-agent==0.19.0 (from versions: 0.13.0, 0.14.0, 0.15.0, 0.15.1, 0.15.2)
ERROR: No matching distribution found for hermes-agent==0.19.0

=== no repo contract promises a docs-check target (grep over AGENTS.md, docs/, specs/, README.md, tests/) ===
matches: 0

=== CF-031 repro: gitreins guard with one staged .md and no .py ===
  on zero-work runs (gitreins init writes it for fresh repos).[0m
Tier 1: DEGRADED PASS (skips: lint=no staged files)  (test mode: full)
  ✓ secrets — clean (gitleaks + builtin cross-check); scanners: nice=nice -n 10
  ~ lint — skipped (no staged files)
  ✓ tests (full)
  guard log: /home/kara/.hermes/cache/scratch/cf-readme-2328b/src/.gitreins/logs/guard-20261031T012020.616687Z.log

EXIT: 2

=== END PART 3 ===
