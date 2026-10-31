code-factory README audit probe
published tip: 097c96930fa4b82e955a73af18c907bee76df6da
probe mode: detached published-tip worktree; isolated HOME; post-edit re-run

=== quick-bunker ===
$ scripts/bunker-server-install.sh --check
rc=1
PASS bunker_client — bunker 0.2.0
FAIL bunker_config — isolated config absent
FAIL server_reachable — bunker: reading server "your-bunker-server"
RESULT: FAIL (2)

=== quick-node ===
$ ./scripts/project-node.sh --check --project myproject
rc=1
FAIL reach:http://crier.example:8767/health — -> 000000
PASS reach:https://pypi.org/simple/ — 200
FAIL port — nothing on :10800
FAIL inference_key — no provider key
FAIL crier_identity — absent
FAIL repo — repo absent
NODE: FAIL (3)

=== quick-create ===
$ scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes
rc=1
FAIL spawn — bunker: server "your-bunker-server" not found in config

=== hermes-check ===
$ scripts/harness/install-hermes.sh --check
rc=1
PASS binary — installed Hermes binary found
FAIL port — nothing on :10800
FAIL inference_key — no provider key
HERMES: FAIL (2)

=== selftest ===
$ bash tests/selftest.sh
rc=0
SELFTEST: PASS

=== docs-check ===
$ make docs-check
rc=2
make: *** No rule to make target 'docs-check'. Stop.

=== public-posture ===
$ git grep -n '/home/' HEAD
placeholder and historical fixture hits exist; no real personal path was copied into the public audit.
$ git grep -nE '(ghp_|github_pat_|sk-[A-Za-z0-9]{20,})' HEAD
no credential-shaped match in the published tree.
