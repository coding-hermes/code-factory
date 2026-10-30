README lane rerun — code-factory-readme-2026-10-30-08-47-09

Published target: origin/main b433e0d6f714615b361b3a02848cf250c5a79133. The previous audit branch remains unmerged at 7fa8667e343593f6097a5a896c54a392431fabdb; PR #11 is OPEN and MERGEABLE. No README correction is on origin/main.

Exact commands tested from a clean detached origin/main worktree with scratch HOME:
- BUNKER_SERVER=your-bunker-server scripts/bunker-server-install.sh --check -> rc=1, RESULT: FAIL (2); bunker config missing and placeholder server unreachable.
- CRIER_URL=http://crier.example:8767 ./scripts/project-node.sh --check --project demo -> rc=1, NODE: FAIL (3); placeholder Crier unreachable, Hermes binary/port/provider key/identity/repo absent.
- CRIER_URL=http://crier.example:8767 BUNKER_SERVER=your-bunker-server scripts/bunker-server-install.sh --check -> rc=1, RESULT: FAIL (2).
- CRIER_URL=http://crier.example:8767 BUNKER_SERVER=your-bunker-server scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes -> rc=1; placeholder bunker server not found.
- bash tests/selftest.sh -> rc=0, SELFTEST: PASS; 15/15 rows parse.
- bash -n scripts/*.sh scripts/harness/*.sh tests/selftest.sh -> rc=0.

The exact producer output is in the fresh probe captured during this rerun; the stable evidence is the committed audit artifact and its committed probe copy. Static census: six fenced blocks; five linked operational docs present; only three harness installers present; docs/traceability-doctrine.md absent. README still claims six foreign installers, a present-tense measured Hermes gateway, and three environment variables while exporting CRIER_URL and BUNKER_SERVER. These are existing finding classes CF-009, CF-010, CF-012, CF-013, and CF-015. CF-011 remains the AGENTS.md dead-row citation. CF-014 remains pending but its unsupported --agent text is absent from published main and does not reproduce. No new row was filed.

No live bunker, Crier, gateway, release asset, or rendered-public boundary was available. The unscoped DuckBrain result was not cited; the owning namespace and exact memory key could not be resolved.

ch:trace row=CF-009 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-08-47-09#readme test=scripts/bunker-server-install.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-08-47-09.md witness=none:placeholder-infrastructure-and-local-checkout-only verdict=none:open-finding commit=none:open memory=none:unresolved-namespace
ch:trace row=CF-010 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-08-47-09#readme test=git-ls-tree::scripts/harness doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-08-47-09.md witness=path@origin:scripts/harness verdict=none:open-finding commit=none:open memory=none:unresolved-namespace
ch:trace row=CF-011 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-08-47-09#readme test=jq::board-id-census doc=AGENTS.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-08-47-09.md witness=path@origin:AGENTS.md verdict=none:open-finding commit=none:open memory=none:unresolved-namespace
ch:trace row=CF-012 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-08-47-09#readme test=test::docs/traceability-doctrine.md doc=docs/traceability-doctrine.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-08-47-09.md witness=none:repository-contract-file-absent verdict=none:open-finding commit=none:open memory=none:unresolved-namespace
ch:trace row=CF-013 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-08-47-09#readme test=scripts/harness/install-hermes.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-08-47-09.md witness=none:no-live-bunker-or-gateway-available verdict=none:open-finding commit=none:open memory=none:unresolved-namespace
ch:trace row=CF-015 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-08-47-09#readme test=grep::environment-variable-inventory doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-08-47-09.md witness=path@origin:README.md verdict=none:open-finding commit=none:open memory=none:unresolved-namespace

STATUS: PARTIAL
TIER: T4 -- literal README commands executed in the published-tip worktree and committed evidence will be read back from the pushed audit branch; live runtime and public-render boundaries unavailable
EVIDENCE: docs/audits/code-factory-readme-2026-10-30-08-47-09.md