# code-factory README audit — 2026-10-31 13:15 tick

Published-tip probe: `097c96930fa4b82e955a73af18c907bee76df6da` from `origin/main`.
The reader-facing commands were executed from a detached worktree of that exact tip with an isolated HOME. The README was edited only after the pre-edit probes; this artifact records the final post-edit probe and the persistent findings that remain open.

## Commands tested

| README path | Exact command | Result |
|---|---|---|
| Quick start | `scripts/bunker-server-install.sh --check` with `BUNKER_SERVER=your-bunker-server` | exit 1; `PASS bunker_client`, `FAIL bunker_config` (isolated config absent), `FAIL server_reachable`; final `RESULT: FAIL (2)` |
| Quick start | `./scripts/project-node.sh --check --project myproject` with `CRIER_URL=http://crier.example:8767` | exit 1; Crier reports `-> 000000`, Hermes port and inference key are absent, identity/repo are absent; final `NODE: FAIL (3)` |
| Quick start | `scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes` with `BUNKER_SERVER=your-bunker-server` | exit 1; `FAIL spawn — bunker: server "your-bunker-server" not found in config` |
| Status command | `scripts/harness/install-hermes.sh --check` | exit 1; installed local Hermes binary is found, but port `10800` and provider key are absent; final `HERMES: FAIL (2)` |
| Contributing | `bash tests/selftest.sh` | exit 0; final `SELFTEST: PASS`, 24/24 board rows parse |
| Repository docs check | `make docs-check` | exit 2; `make: *** No rule to make target 'docs-check'. Stop.` No README or repository contract promises this target; it remains an explicit unverified convenience probe, not a new finding. |

The exact raw command transcript is frozen in the adjacent stand-in evidence file `code-factory-readme-20261031-131544.probe.txt` for this run. The committed artifact preserves the commands and decisive output without machine-local paths.

## Findings and boundaries

1. Quick start is diagnostic, not a successful installation. The commands correctly require configuration and currently fail on an unconfigured host. The prose now says so explicitly rather than promising that every message names the missing value.
2. CF-037 remains open: `project-node.sh` renders an unreachable Crier URL as `-> 000000`; the README now names that limitation rather than hiding it.
3. CF-034 remains open: clone failures can append a deploy-key hint even when a missing `--ref` is the cause; the README now names the limitation and documents the `--ref` behavior below the status table.
4. The status table's historical measurements remain historical. The current local Hermes check was run and failed without a live gateway or provider key; no live witness is claimed.
5. Layout references were checked against the published tree. The named docs, specs, scripts, prompt files, and audit files exist.
6. Public-posture probes found no credential-shaped match. Absolute `/home/` strings exist in repository fixtures and audit history, including placeholders and historical evidence; they are not copied into the README correction.

## Traceability

ch:trace row=CF-034 spec=README.md#status wave=none:serial test=./scripts/project-node.sh::apply-public-nonmain-ref doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-20261031-131544.md witness=none:local-placeholder-repo-and-no-live-bunker verdict=none:open-finding commit=none:open memory=none:exact-key-not-found
ch:trace row=CF-037 spec=README.md#quick-start wave=none:serial test=./scripts/project-node.sh::check-unreachable-crier doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-20261031-131544.md witness=none:local-placeholder-crier-and-no-live-service verdict=none:open-finding commit=none:open memory=none:exact-key-not-found

STATUS: PARTIAL
TIER: T3 -- executed every safe README command block and the repository selftest from a clean published-tip worktree; no live bunker, Crier, gateway, or external user infrastructure was available
EVIDENCE: docs/audits/code-factory-readme-20261031-131544.md; exact commands and outputs are recorded above
