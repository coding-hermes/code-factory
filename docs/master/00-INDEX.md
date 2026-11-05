# CODE FACTORY — MASTER DOCUMENT SKELETON

Generated mechanically. Every **RED** is a claim that has no evidence yet,
not a section that is merely unwritten. A section turns green by running a command, never by editing prose.

| # | Module | Repo | Status |
|---|---|---|---|
| 1 | [`scripts/add_family_lanes.py`](01-scripts-add-family-lanes-py.md) | code-factory | RED |
| 2 | [`scripts/board_drift.py`](02-scripts-board-drift-py.md) | code-factory | RED |
| 3 | [`scripts/board_lock.py`](03-scripts-board-lock-py.md) | code-factory | VERIFIED |
| 4 | [`scripts/bunker-crier-connect.sh`](04-scripts-bunker-crier-connect-sh.md) | code-factory | VERIFIED |
| 5 | [`scripts/bunker-provision.sh`](05-scripts-bunker-provision-sh.md) | code-factory | VERIFIED |
| 6 | [`scripts/bunker-server-install.sh`](06-scripts-bunker-server-install-sh.md) | code-factory | RED |
| 7 | [`scripts/bunker_config_gen.py`](07-scripts-bunker-config-gen-py.md) | code-factory | RED |
| 8 | [`scripts/check_scan_scope.py`](08-scripts-check-scan-scope-py.md) | code-factory | RED |
| 9 | [`scripts/clone_lane.py`](09-scripts-clone-lane-py.md) | code-factory | RED |
| 10 | [`scripts/configure_family.py`](10-scripts-configure-family-py.md) | code-factory | VERIFIED |
| 11 | [`scripts/disk_floor.py`](11-scripts-disk-floor-py.md) | code-factory | VERIFIED |
| 12 | [`scripts/github-app-refresh.sh`](12-scripts-github-app-refresh-sh.md) | code-factory | VERIFIED |
| 13 | [`scripts/github-app-setup.sh`](13-scripts-github-app-setup-sh.md) | code-factory | VERIFIED |
| 14 | [`scripts/github-app-token.py`](14-scripts-github-app-token-py.md) | code-factory | VERIFIED |
| 15 | [`scripts/harness/install-claude-code.sh`](15-scripts-harness-install-claude-code-sh.md) | code-factory | VERIFIED |
| 16 | [`scripts/harness/install-codex.sh`](16-scripts-harness-install-codex-sh.md) | code-factory | VERIFIED |
| 17 | [`scripts/harness/install-hermes.sh`](17-scripts-harness-install-hermes-sh.md) | code-factory | VERIFIED |
| 18 | [`scripts/harness/install-opencode.sh`](18-scripts-harness-install-opencode-sh.md) | code-factory | RED |
| 19 | [`scripts/install-gitreins.sh`](19-scripts-install-gitreins-sh.md) | code-factory | VERIFIED |
| 20 | [`scripts/land-node-branch.sh`](20-scripts-land-node-branch-sh.md) | code-factory | VERIFIED |
| 21 | [`scripts/lane_target.py`](21-scripts-lane-target-py.md) | code-factory | VERIFIED |
| 22 | [`scripts/lib.sh`](22-scripts-lib-sh.md) | code-factory | VERIFIED |
| 23 | [`scripts/load_lane_config.py`](23-scripts-load-lane-config-py.md) | code-factory | VERIFIED |
| 24 | [`scripts/master_doc_skeleton.py`](24-scripts-master-doc-skeleton-py.md) | code-factory | VERIFIED |
| 25 | [`scripts/node-bus-worker.py`](25-scripts-node-bus-worker-py.md) | code-factory | RED |
| 26 | [`scripts/node-create.sh`](26-scripts-node-create-sh.md) | code-factory | VERIFIED |
| 27 | [`scripts/node_env.py`](27-scripts-node-env-py.md) | code-factory | VERIFIED |
| 28 | [`scripts/node_freshness.py`](28-scripts-node-freshness-py.md) | code-factory | VERIFIED |
| 29 | [`scripts/node_gateway_auth.py`](29-scripts-node-gateway-auth-py.md) | code-factory | VERIFIED |
| 30 | [`scripts/node_identity.py`](30-scripts-node-identity-py.md) | code-factory | VERIFIED |
| 31 | [`scripts/node_seed.py`](31-scripts-node-seed-py.md) | code-factory | VERIFIED |
| 32 | [`scripts/node_seed_drift.py`](32-scripts-node-seed-drift-py.md) | code-factory | VERIFIED |
| 33 | [`scripts/project-node.sh`](33-scripts-project-node-sh.md) | code-factory | VERIFIED |
| 34 | [`scripts/reclaim_disk.py`](34-scripts-reclaim-disk-py.md) | code-factory | VERIFIED |
| 35 | [`scripts/repo_freshness.py`](35-scripts-repo-freshness-py.md) | code-factory | VERIFIED |
| 36 | [`scripts/verify-node.sh`](36-scripts-verify-node-sh.md) | code-factory | VERIFIED |
| 37 | [`specs/ENVELOPE.md`](37-specs-envelope-md.md) | code-factory | VERIFIED |
| 38 | [`specs/HARNESS-MATRIX.md`](38-specs-harness-matrix-md.md) | code-factory | FAILING |
| 39 | [`specs/HARNESS.md`](39-specs-harness-md.md) | code-factory | VERIFIED |
| 40 | [`specs/NODE.md`](40-specs-node-md.md) | code-factory | RED |
| 41 | [`specs/FLEET-MEMORY.md`](41-specs-fleet-memory-md.md) | code-factory | RED |
| 42 | [`specs/TRACE.md`](42-specs-trace-md.md) | code-factory | RED |
| 43 | [`specs/HARNESS-MEMORY.md`](43-specs-harness-memory-md.md) | code-factory | RED |
| 44 | [`scripts/master_doc_*.py`](44-doc-pipeline.md) | code-factory | VERIFIED |

## Counts

Regenerated from the module files by `scripts/gen_nasa_handbook.py`'s census — never hand-edited.

- Modules: **43** (33 VERIFIED, 10 not)
- Modules with a verification section: **33**
- Modules that emit metrics or state why not: **40** (the rest say `none` with a reason)
- Modules whose §2 names both sides of a service contract: see each §2c

