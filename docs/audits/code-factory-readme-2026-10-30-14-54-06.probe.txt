ROOT=<scratch>
HOME_DIR=<fresh-home>

=== clone published origin/main ===
Cloning into '<scratch>/clone'...
RC=0

=== published sha ===
b433e0d6f714615b361b3a02848cf250c5a79133
RC=0

=== README commit date ===
b433e0d6f714615b361b3a02848cf250c5a79133 2026-10-30 04:21:08 +0100 Merge pull request #8 from coding-hermes/readme-audit-20261030-marker-fix
RC=0

=== Quick start bunker check ===
scripts/bunker-server-install.sh: line 14: BUNKER_SERVER: set BUNKER_SERVER to your bunker server name
RC=1

=== Quick start project-node placeholder literally ===
bash: -c: line 1: syntax error near unexpected token `newline'
bash: -c: line 1: `scripts/project-node.sh --check --project <project>'
RC=2

=== Own infrastructure setup and bunker check ===
bunker server: your-bunker-server
  PASS  bunker_client — <installed-bunker> bunker 0.2.0
  FAIL  bunker_config — missing (<fresh-home>/.config/bunker/config.yaml) — the client has no server to talk to
  FAIL  server_reachable — your-bunker-server did not answer: bunker: reading server "your-bunker-server"
  PASS  tool:python3 — <installed-python>
  PASS  tool:git — /usr/bin/git
  PASS  tool:curl — /usr/bin/curl
  PASS  tool:jq — /usr/bin/jq
  PASS  disk — 171.5 GB free (floor 5 GB)

RESULT: FAIL (2)
RC=1

=== Own infrastructure node-create literally ===
node-create — project=myrepo harness=hermes server=your-bunker-server
  ..    spawning node-myrepo-095906 (ttl 6h)
  FAIL  spawn — bunker: server "your-bunker-server" not found in config
RC=1

=== Contributing selftest ===
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
digest mismatch for file:///var/tmp/hermes-scratch/tmp.SbwnVHJPjO/src: want 0000000000000000000000000000000000000000000000000000000000000000 got 5891b5b522d5df086d0ff0b110fbd9d21bb4fc7163af34d08286a2e846f6be03
  PASS  wrong digest refused
4. no literal credential assignments
  PASS  none found
5. the board is valid JSONL
  PASS  15/15 rows parse
6. project board entrypoint is real and fails closed without dependency
  PASS  bash -n scripts/boardctl
  PASS  local help
  PASS  missing boardctl -> explicit FAIL, exit 127

SELFTEST: PASS
RC=0

=== Quality gate gitreins guard ===
[33m⚠ DEGRADED PASS: lint=no staged files, tests=no staged files — these gates did not run, so this run is not
  evidence the tree passes. Stage the files you want graded (git add), or
  set guards.allow_skips: true in .gitreins/config.yaml to accept skips
  on zero-work runs (gitreins init writes it for fresh repos).[0m
Tier 1: DEGRADED PASS (skips: lint=no staged files, tests=no staged files)  (test mode: full)
  ✓ secrets — clean (gitleaks + builtin cross-check); scanners: nice=nice -n 10
  ~ lint — skipped (no staged files)
  ~ tests — skipped (no staged files)
  guard log: <scratch>/clone/.gitreins/logs/guard-20261030T145907.139690Z.log

RC=2

=== file/path census ===
PRESENT docs/DESIGN.md
PRESENT specs/NODE.md
PRESENT specs/ENVELOPE.md
PRESENT specs/HARNESS.md
PRESENT scripts/bunker-server-install.sh
PRESENT scripts/project-node.sh
PRESENT scripts/node-create.sh
PRESENT scripts/verify-node.sh
PRESENT scripts/lib.sh
PRESENT scripts/boardctl
PRESENT tests/selftest.sh
PRESENT docs/BOARD.md
PRESENT docs/ACCEPTANCE-PLAN.md
PRESENT docs/OPERATIONS.md
PRESENT docs/THREAT-MODEL.md
PRESENT docs/SCHEDULER-ADMISSION.md
PRESENT scripts/load_lane_config.py
PRESENT scripts/add_family_lanes.py

=== clean clone status ===
