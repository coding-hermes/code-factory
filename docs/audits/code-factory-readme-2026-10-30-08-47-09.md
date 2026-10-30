README lane rerun report — code-factory-readme-2026-10-30-08-47-09

Published target: origin/main at b433e0d6f714615b361b3a02848cf250c5a79133. The prior rerun branch remains unmerged: origin/readme-audit-20261030-0847-rerun at 54003754ab52b375006e995cc78c4ab8ea9ee7b0; PR #11 is OPEN and mergeable. No README correction is present on origin/main.

Literal command matrix from a clean detached published-tip worktree with scratch HOME:
- README quick-start bunker check with BUNKER_SERVER=your-bunker-server: rc=1, RESULT: FAIL (2); missing bunker config and unreachable placeholder server.
- README quick-start project-node check with CRIER_URL=http://crier.example:8767: rc=1, NODE: FAIL (3); placeholder Crier unreachable, Hermes binary/port/provider key/identity/repo absent.
- README own-infrastructure bunker check with both documented placeholders: rc=1, RESULT: FAIL (2).
- README own-infrastructure node-create command with both documented placeholders: rc=1; bunker server not found in config.
- bash tests/selftest.sh: rc=0, SELFTEST: PASS; 15/15 board rows parse.
- bash -n scripts/*.sh scripts/harness/*.sh tests/selftest.sh: rc=0; shell syntax clean.

Static inventory: README has 6 fenced blocks; all five linked operational docs exist; scripts/harness contains only install-claude-code.sh, install-hermes.sh, and install-opencode.sh; docs/traceability-doctrine.md is absent. The status table still claims a measured working Hermes gateway, while the available local check cannot re-derive it. README still says three environment variables although it exports CRIER_URL and BUNKER_SERVER.

Re-triage: CF-009, CF-010, CF-011, CF-012, CF-013, CF-014, and CF-015 are all still pending on origin/main. CF-014 does not reproduce in published README because the unsupported --agent text is absent; do not close the row from this lane. The current sweep found no new finding class and filed no row. No live bunker, Crier, gateway, release asset, or rendered-public boundary was available.

ch:trace row=CF-009 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-08-47-09#readme test=scripts/bunker-server-install.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-08-47-09.md witness=none:placeholder-infrastructure-and-local-checkout-only verdict=none:open-finding commit=none:open memory=none:unresolved-namespace
ch:trace row=CF-010 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-08-47-09#readme test=git-ls-tree::scripts/harness doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-08-47-09.md witness=path@origin:scripts/harness verdict=none:open-finding commit=none:open memory=none:unresolved-namespace
ch:trace row=CF-011 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-08-47-09#readme test=jq::board-id-census doc=AGENTS.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-08-47-09.md witness=path@origin:AGENTS.md verdict=none:open-finding commit=none:open memory=none:unresolved-namespace
ch:trace row=CF-012 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-08-47-09#readme test=test::docs/traceability-doctrine.md doc=docs/traceability-doctrine.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-08-47-09.md witness=none:repository-contract-file-absent verdict=none:open-finding commit=none:open memory=none:unresolved-namespace
ch:trace row=CF-013 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-08-47-09#readme test=scripts/harness/install-hermes.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-08-47-09.md witness=none:no-live-bunker-or-gateway-available verdict=none:open-finding commit=none:open memory=none:unresolved-namespace
ch:trace row=CF-015 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-08-47-09#readme test=grep::environment-variable-inventory doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-08-47-09.md witness=path@origin:README.md verdict=none:open-finding commit=none:open memory=none:unresolved-namespace

STATUS: PARTIAL
TIER: T4 -- literal README commands executed and durable evidence is being prepared from the published-tip worktree; live bunker/Crier/gateway and public-render boundaries unavailable
EVIDENCE: docs/audits/code-factory-readme-2026-10-30-08-47-09.md