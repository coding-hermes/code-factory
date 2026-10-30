BASE=/var/tmp/code-factory-readme-160430.1mzwdS
HOME=/var/tmp/code-factory-readme-home-160430.P0e49x

=== git clone --depth 1 https://github.com/coding-hermes/code-factory.git /var/tmp/code-factory-readme-160430.1mzwdS/repo ===
Cloning into '/var/tmp/code-factory-readme-160430.1mzwdS/repo'...
rc=0

=== git rev-parse HEAD ===
3ebf9f06ce7baa03fc62844f7aecd71aac4c17b2
rc=0

=== env -u BUNKER_SERVER -u CRIER_URL scripts/bunker-server-install.sh --check ===
scripts/bunker-server-install.sh: line 14: BUNKER_SERVER: set BUNKER_SERVER to your bunker server name
rc=1

=== env -u BUNKER_SERVER -u CRIER_URL scripts/project-node.sh --check --project demo (substituted for <project>) ===
node provisioning — project=demo harness=hermes host=karaHermes-mde-7840hs
[00] preflight
  PASS  arch — x86_64 (Linux 7.0.0-38-generic)
  PASS  disk — 171.1 GB free (floor 5 GB)
  PASS  mem — 45836 MB
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
  PASS  binary — /home/kara/.local/bin/hermes
  PASS  version — Hermes Agent v0.22.5+3029.g6337f1f.dirty (2026.9.24) · stable · local 6337f1f22fe2
  FAIL  port — nothing on :10800
  FAIL  inference_key — no provider key — a turn dies at 'No inference provider configured'

HERMES: FAIL (2)
[30] bus
  FAIL  crier_identity — absent — stage a bundle and re-run; a node without an identity is invisible
[40] repo
  FAIL  repo — /var/tmp/code-factory-readme-home-160430.P0e49x/repo absent (pass --repo to clone)
[90] manifest
  ..    manifest is written only when every layer passes

NODE: FAIL (3)
rc=1

=== export CRIER_URL=http://crier.example:8767 ===
rc=0

=== export BUNKER_SERVER=your-bunker-server ===
rc=0

=== scripts/bunker-server-install.sh --check ===
bunker server: your-bunker-server
  PASS  bunker_client — /usr/local/bin/bunker bunker 0.2.0
  FAIL  bunker_config — missing (/var/tmp/code-factory-readme-home-160430.P0e49x/.config/bunker/config.yaml) — the client has no server to talk to
  FAIL  server_reachable — your-bunker-server did not answer: bunker: reading server "your-bunker-server"
  PASS  tool:python3 — /usr/bin/python3
  PASS  tool:git — /usr/bin/git
  PASS  tool:curl — /usr/bin/curl
  PASS  tool:jq — /usr/bin/jq
  PASS  disk — 171.1 GB free (floor 5 GB)

RESULT: FAIL (2)
rc=1

=== scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes ===
node-create — project=myrepo harness=hermes server=your-bunker-server
  ..    spawning node-myrepo-111402 (ttl 6h)
  FAIL  spawn — bunker: server "your-bunker-server" not found in config
rc=1

=== bash tests/selftest.sh ===
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
digest mismatch for file:///var/tmp/hermes-scratch/tmp.17zaYEE9UH/src: want 0000000000000000000000000000000000000000000000000000000000000000 got 5891b5b522d5df086d0ff0b110fbd9d21bb4fc7163af34d08286a2e846f6be03
  PASS  wrong digest refused
4. no literal credential assignments
  PASS  none found
5. the board is valid JSONL
  PASS  16/16 rows parse
6. project board entrypoint is real and fails closed without dependency
  PASS  bash -n scripts/boardctl
  PASS  local help
  PASS  missing boardctl -> explicit FAIL, exit 127

SELFTEST: PASS
rc=0

=== gitreins guard ===
⚠ DEGRADED PASS: lint=no staged files, tests=no staged files — these gates did not run, so this run is not
  evidence the tree passes. Stage the files you want graded (git add), or
  set guards.allow_skips: true in .gitreins/config.yaml to accept skips
  on zero-work runs (gitreins init writes it for fresh repos).
Tier 1: DEGRADED PASS (skips: lint=no staged files, tests=no staged files)  (test mode: full)
  ✓ secrets — clean (gitleaks + builtin cross-check); scanners: nice=nice -n 10
  ~ lint — skipped (no staged files)
  ~ tests — skipped (no staged files)
  guard log: /var/tmp/code-factory-readme-160430.1mzwdS/repo/.gitreins/logs/guard-20261030T161403.238632Z.log

rc=2

=== scripts/project-node.sh --apply --harness aider (README prose claim) ===
--project is required (a node belongs to exactly one project)
rc=2

=== scripts/harness/install-hermes.sh --check (README status claim) ===
harness: hermes (pin 0.19.0, port 10800)
  PASS  binary — /home/kara/.local/bin/hermes
  PASS  version — Hermes Agent v0.22.5+3029.g6337f1f.dirty (2026.9.24) · stable · local 6337f1f22fe2
  FAIL  port — nothing on :10800
  FAIL  inference_key — no provider key — a turn dies at 'No inference provider configured'

HERMES: FAIL (2)
rc=1

=== relative README link existence ===
FOUND docs/BOARD.md
FOUND docs/ACCEPTANCE-PLAN.md
FOUND docs/OPERATIONS.md
FOUND docs/THREAT-MODEL.md
FOUND docs/SCHEDULER-ADMISSION.md
FOUND docs/DESIGN.md
FOUND specs/NODE.md
FOUND scripts/boardctl

=== prompt and script inventory ===
prompts/docs.md
prompts/dogfood.md
prompts/duckbrain.md
prompts/foreman.md
prompts/perf.md
prompts/pm.md
prompts/qa.md
prompts/readme.md
prompts/releng.md
prompts/review.md
prompts/sync.md
scripts/harness/install-claude-code.sh
scripts/harness/install-hermes.sh
scripts/harness/install-opencode.sh

=== README fence census ===
17: OPEN
26: CLOSE
30: OPEN
39: CLOSE
76: OPEN
82: CLOSE
fences=6, inside_at_eof=0

=== git status after probes ===

PROBE_DIR=/var/tmp/code-factory-readme-160430.1mzwdS

=== published-tip focused row rechecks ===
CF-009 README first command and source prerequisite:
scripts/bunker-server-install.sh: line 14: BUNKER_SERVER: set BUNKER_SERVER to your bunker server name
rc=1
CF-010 harness inventory:
scripts/harness/install-claude-code.sh
scripts/harness/install-hermes.sh
scripts/harness/install-opencode.sh
rc=0
CF-011 cited board id census:
CF-108_present=4
CF-012 repository doctrine path:
docs_traceability_doctrine_rc=1
CF-013 status claim and Hermes check:
56:| Hermes in a bunker + HTTP gateway over tailnet | **works** — 32 s install, `/api/status` 200, 133 JSON-RPC methods |
harness: hermes (pin 0.19.0, port 10800)
  PASS  binary — /home/kara/.local/bin/hermes
  PASS  version — Hermes Agent v0.22.5+3029.g6337f1f.dirty (2026.9.24) · stable · local 6337f1f22fe2
  FAIL  port — nothing on :10800
  PASS  inference_key — a provider key is present in ~/.hermes/.env (value not read)

HERMES: FAIL (1)
rc=1
CF-015 README count and exported variables:
73:This repo carries no endpoints, hostnames or credentials. Three environment variables and one
77:export CRIER_URL=http://crier.example:8767     # your message bus
78:export BUNKER_SERVER=your-bunker-server        # your agent host
exported_names_in_infrastructure_block=2
CF-030 lane table/prompt/loader inventory:
14
lane_table_rows=0
prompts/docs.md
prompts/dogfood.md
prompts/duckbrain.md
prompts/foreman.md
prompts/perf.md
prompts/pm.md
prompts/qa.md
prompts/readme.md
prompts/releng.md
prompts/review.md
prompts/sync.md
prompt_file_count=11
scripts/load_lane_config.py:20:CFG = {
scripts/load_lane_config.py:31:for name, (ns, mode, prompt_name) in CFG.items():
scripts/add_family_lanes.py:50:LANES = [
scripts/add_family_lanes.py:52:    ("code-factory-docs", f"{H}/stand-in/docs/code-factory", "docs", "docs"),
scripts/add_family_lanes.py:53:    ("code-factory-docs-qa", f"{H}/stand-in/pm/code-factory-docs", "qa", "qa"),
scripts/add_family_lanes.py:55:    ("code-factory-readme-qa", f"{H}/stand-in/pm/code-factory-readme", "qa", "qa"),
scripts/add_family_lanes.py:62:    ("code-factory-releng-qa", f"{H}/stand-in/pm/code-factory-releng", "qa", "qa"),
scripts/add_family_lanes.py:68:for name, workdir, ns, prompt_name in LANES:
scripts/add_family_lanes.py:89:for name, workdir, ns, prompt_name in LANES:
README fence census:
fences=6 inside_at_eof=0
