# code-factory README rerun — 2026-10-30

Published target: `origin/main` at `b433e0d6f714615b361b3a02848cf250c5a79133`.

The audit used a clean detached worktree at `/var/tmp/code-factory-readme-audit-final` and a scratch HOME. The README and board were not changed during the probe.

Commands run:

- `BUNKER_SERVER=your-bunker-server scripts/bunker-server-install.sh --check`: exit 1, `RESULT: FAIL (2)`; placeholder server configuration absent and server unreachable.
- `CRIER_URL=http://crier.example:8767 ./scripts/project-node.sh --check --project demo`: exit 1, `NODE: FAIL (3)`; placeholder Crier endpoint unreachable, Hermes binary/port/provider key absent, identity absent, and repo absent.
- `bash tests/selftest.sh`: exit 0, `SELFTEST: PASS`; 15/15 board rows parsed.
- `BUNKER_SERVER=your-bunker-server CRIER_URL=http://crier.example:8767 scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes`: exit 1; safe refusal because the placeholder server is not configured.
- `bash -n scripts/*.sh scripts/harness/*.sh tests/selftest.sh`: exit 0.

Static checks: six fenced blocks; all five README operational docs exist; three harness installer scripts are present; `docs/traceability-doctrine.md` is absent; README still overstates six foreign installers, current Hermes status, and three environment variables. Existing rows CF-009, CF-010, CF-011, CF-012, CF-013, and CF-015 remain open. CF-014 does not reproduce in published main because the unsupported `--agent` command is absent there; QA-CODE-FACTORY-1 is outside the published tip.

Unverified: release asset, rendered public README, live bunker/Crier/gateway, external deployment.

ch:trace row=CF-009 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-08-47-09#readme test=scripts/bunker-server-install.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-08-47-09.md witness=none:placeholder-infrastructure-and-local-clone-only verdict=none:open-finding commit=none:open memory=none:unresolved-namespace
ch:trace row=CF-010 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-08-47-09#readme test=find::harness-installer-inventory doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-08-47-09.md witness=path@origin:scripts/harness verdict=none:open-finding commit=none:open memory=none:unresolved-namespace
ch:trace row=CF-011 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-08-47-09#readme test=jq::board-id-census doc=AGENTS.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-08-47-09.md witness=path@origin:AGENTS.md verdict=none:open-finding commit=none:open memory=none:unresolved-namespace
ch:trace row=CF-012 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-08-47-09#readme test=git-ls-tree::traceability-doctrine doc=docs/traceability-doctrine.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-08-47-09.md witness=none:repository-contract-file-absent verdict=none:open-finding commit=none:open memory=none:unresolved-namespace
ch:trace row=CF-013 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-08-47-09#readme test=scripts/harness/install-hermes.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-08-47-09.md witness=none:no-live-bunker-or-gateway-available verdict=none:open-finding commit=none:open memory=none:unresolved-namespace
ch:trace row=CF-015 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-08-47-09#readme test=grep::environment-variable-inventory doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-08-47-09.md witness=path@origin:README.md verdict=none:open-finding commit=none:open memory=none:unresolved-namespace

STATUS: PARTIAL
TIER: T4 -- README commands executed in the clean published-tip worktree with scratch HOME; live bunker/Crier/gateway and public-render boundaries unavailable
EVIDENCE: /var/tmp/code-factory-current-probe.txt
