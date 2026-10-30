=== quick start step 1 with README placeholder export ===
$ scripts/bunker-server-install.sh --check
bunker server: your-bunker-server
  PASS  bunker_client — /usr/local/bin/bunker bunker 0.2.0
  FAIL  bunker_config — missing (fresh HOME/.config/bunker/config.yaml) — the client has no server to talk to
  FAIL  server_reachable — your-bunker-server did not answer
  PASS  tool:python3 — /usr/bin/python3
  PASS  tool:git — /usr/bin/git
  PASS  tool:curl — /usr/bin/curl
  PASS  tool:jq — /usr/bin/jq
  PASS  disk — 186.1 GB free (floor 5 GB)

RESULT: FAIL (2)
EXIT=1

=== quick start step 2 with README placeholder export ===
$ ./scripts/project-node.sh --check --project demo
node provisioning — project=demo harness=hermes host=karaHermes-mde-7840hs
[00] preflight
  PASS  arch — x86_64
  PASS  disk — 186.1 GB free (floor 5 GB)
  PASS  mem — 46049 MB
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
  FAIL  inference_key — no provider key

HERMES: FAIL (3)
[30] bus
  FAIL  crier_identity — absent
[40] repo
  FAIL  repo — fresh HOME/repo absent
[90] manifest
  ..    manifest is written only when every layer passes

NODE: FAIL (3)
EXIT=1

=== contributing selftest ===
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
  PASS  wrong digest refused
4. no literal credential assignments
  PASS  none found
5. the board is valid JSONL
  PASS  15/15 rows parse

SELFTEST: PASS
EXIT=0

=== infrastructure node-create with README placeholder exports ===
$ scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes
node-create — project=myrepo harness=hermes server=your-bunker-server
  ..    spawning node-myrepo-041402 (ttl 6h)
  FAIL  spawn — bunker: server "your-bunker-server" not found in config
EXIT=1

=== static claims ===
referenced_docs=present:docs/BOARD.md present:docs/ACCEPTANCE-PLAN.md present:docs/OPERATIONS.md present:docs/THREAT-MODEL.md present:docs/SCHEDULER-ADMISSION.md
layout_installers=install-claude-code.sh install-hermes.sh install-opencode.sh
fence_count=6
