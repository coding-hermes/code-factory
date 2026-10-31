
=== quick-start bunker check with placeholder ===
$ BUNKER_SERVER=your-bunker-server scripts/bunker-server-install.sh --check
bunker server: your-bunker-server
  PASS  bunker_client — /usr/local/bin/bunker bunker 0.2.0
  FAIL  bunker_config — missing (/var/tmp/cf-readme-rerun-home-E9rfgi/.config/bunker/config.yaml) — the client has no server to talk to
  FAIL  server_reachable — your-bunker-server did not answer: bunker: reading server "your-bunker-server"
  PASS  tool:python3 — /usr/bin/python3
  PASS  tool:git — /usr/bin/git
  PASS  tool:curl — /usr/bin/curl
  PASS  tool:jq — /usr/bin/jq
  PASS  disk — 215.6 GB free (floor 5 GB)

RESULT: FAIL (2)
EXIT=1

=== quick-start project node check with placeholder ===
$ CRIER_URL=http://crier.example:8767 ./scripts/project-node.sh --check --project demo
node provisioning — project=demo harness=hermes host=karaHermes-mde-7840hs
[00] preflight
  PASS  arch — x86_64 (Linux 7.0.0-38-generic)
  PASS  disk — 215.6 GB free (floor 5 GB)
  PASS  mem — 45165 MB
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

HERMES: FAIL (3)
[30] bus
  FAIL  crier_identity — absent — stage a bundle and re-run; a node without an identity is invisible
[40] repo
  FAIL  repo — /var/tmp/cf-readme-rerun-home-E9rfgi/repo absent (pass --repo to clone)
[90] manifest
  ..    manifest is written only when every layer passes

NODE: FAIL (3)
EXIT=1

=== own-infrastructure bunker check ===
$ CRIER_URL=http://crier.example:8767 BUNKER_SERVER=your-bunker-server scripts/bunker-server-install.sh --check
bunker server: your-bunker-server
  PASS  bunker_client — /usr/local/bin/bunker bunker 0.2.0
  FAIL  bunker_config — missing (/var/tmp/cf-readme-rerun-home-E9rfgi/.config/bunker/config.yaml) — the client has no server to talk to
  FAIL  server_reachable — your-bunker-server did not answer: bunker: reading server "your-bunker-server"
  PASS  tool:python3 — /usr/bin/python3
  PASS  tool:git — /usr/bin/git
  PASS  tool:curl — /usr/bin/curl
  PASS  tool:jq — /usr/bin/jq
  PASS  disk — 215.3 GB free (floor 5 GB)

RESULT: FAIL (2)
EXIT=1

=== own-infrastructure node create ===
$ CRIER_URL=http://crier.example:8767 BUNKER_SERVER=your-bunker-server scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes
node-create — project=myrepo harness=hermes server=your-bunker-server
  ..    spawning node-myrepo-052146 (ttl 6h)
  FAIL  spawn — bunker: server "your-bunker-server" not found in config
EXIT=1

=== selftest ===
$  bash tests/selftest.sh
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
digest mismatch for file:///var/tmp/hermes-scratch/tmp.v65ZzolkSB/src: want 0000000000000000000000000000000000000000000000000000000000000000 got 5891b5b522d5df086d0ff0b110fbd9d21bb4fc7163af34d08286a2e846f6be03
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
EXIT=0

=== shell syntax ===
$  bash -n scripts/bunker-server-install.sh scripts/lib.sh scripts/node-create.sh scripts/project-node.sh scripts/verify-node.sh scripts/harness/install-claude-code.sh scripts/harness/install-hermes.sh scripts/harness/install-opencode.sh tests/selftest.sh
EXIT=0

=== static census ===
fences=6
linked_docs=present:docs/BOARD.md present:docs/ACCEPTANCE-PLAN.md present:docs/OPERATIONS.md present:docs/THREAT-MODEL.md present:docs/SCHEDULER-ADMISSION.md
doctrine=missing
installers=scripts/harness/install-claude-code.sh
scripts/harness/install-hermes.sh
scripts/harness/install-opencode.sh
