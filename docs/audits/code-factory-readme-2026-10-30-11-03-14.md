# code-factory README audit — 2026-10-30 11:03:14

Target checkout: current feature worktree `200af57` baseline; published comparison: `origin/main` `b433e0d6f714615b361b3a02848cf250c5a79133`. The README was not edited. Commands were run literally where safe with a fresh HOME. The full producer transcript is `docs/audits/code-factory-readme-2026-10-30-11-03-14-commands.txt`.

## Commands tested

- `env -u BUNKER_SERVER HOME=<fresh> bash scripts/bunker-server-install.sh --check` -> exact fatal line `BUNKER_SERVER: set BUNKER_SERVER to your bunker server name`; RC=1.
- `env -u BUNKER_SERVER -u CRIER_URL HOME=<fresh> bash scripts/project-node.sh --check --project <project>` -> `HERMES: FAIL (1)`, `NODE: FAIL (5)`; RC=1. The command is supported and fails closed on missing CRIER_URL, blocked CF-002 inference integration, missing crier identity/base, and absent repo.
- `env HOME=<fresh> bash tests/selftest.sh` -> `SELFTEST: PASS`; 11 node-contract tests, 7 local mutation controls, 10 build-contract tests, 16 inference-contract tests, and 26/26 board rows parsed; RC=0.
- `env HOME=<fresh> BUNKER_SERVER=your-bunker-server bash scripts/bunker-server-install.sh --check` -> `RESULT: FAIL (2)` for missing config and unreachable placeholder server; RC=1.
- `env HOME=<fresh> BUNKER_SERVER=your-bunker-server CRIER_URL=http://crier.example:8767 bash scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes` -> spawn refused because the placeholder server was not in config; RC=1; no agent created.
- `env HOME=<fresh> bash scripts/harness/install-hermes.sh --check` -> `HERMES: FAIL (1)` because CF-002 host inference proxy/node identity is blocked; RC=1.
- `env HOME=<fresh> bash scripts/harness/install-opencode.sh --check` -> `OPENCODE: PASS`, with warnings about location and non-interactive confirmation; RC=0.
- `env HOME=<fresh> bash scripts/harness/install-claude-code.sh --check` -> `CLAUDE-CODE: FAIL (1)` because the binary is absent; RC=1.

## Findings and wording review

No new canonical board row was filed. Existing rows cover the measured defects:

- CF-009 covers the quick-start prerequisite ordering: the exact first command exits 1 before checks when BUNKER_SERVER is unset. The second command is supported but fails closed with `NODE: FAIL (5)` in the clean HOME.
- CF-010 covers the layout claim that one installer exists per named foreign agent. `git ls-tree -r --name-only HEAD scripts/harness` lists only `install-claude-code.sh`, `install-hermes.sh`, and `install-opencode.sh`; codex, aider, goose, and pi-agent installers are absent.
- CF-011 covers AGENTS.md citing nonexistent CF-108.
- CF-012 covers the missing repository-local `docs/traceability-doctrine.md`; `test -e docs/traceability-doctrine.md` returns false.
- CF-013 covers historical Hermes status claims. The current Hermes check fails closed on the CF-002 inference boundary, so the old 32-second install, `/api/status` 200, and 133 JSON-RPC method measurements are not current local evidence.
- CF-015 covers the sentence “Three environment variables and one harness” while the README block visibly exports only CRIER_URL and BUNKER_SERVER; the script read-site inventory contains additional variables but no third exported variable in that documented block.

The README has six balanced fence markers. Its five relative documentation links exist in the current tree. No release binary, live bunker, crier dispatch, node gateway round trip, or rendered public README was available; those surfaces remain unverified rather than being reported as failures. The README was not edited by this lane.

ch:trace row=CF-009 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-11-03-14#readme test=probe_readme_code_factory_20261030_110314.sh::quickstart-bunker-check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-11-03-14-commands.txt witness=none:placeholder-infrastructure-and-local-checkout-only verdict=none:open-finding commit=none:open memory=none:unresolved-namespace
ch:trace row=CF-010 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-11-03-14#readme test=probe_readme_code_factory_20261030_110314.sh::tracked-harness-files doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-11-03-14-commands.txt witness=path@origin:scripts/harness verdict=none:open-finding commit=none:open memory=none:unresolved-namespace
ch:trace row=CF-011 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-11-03-14#readme test=probe_readme_code_factory_20261030_110314.sh::source-checks doc=AGENTS.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-11-03-14-commands.txt witness=path@origin:AGENTS.md verdict=none:open-finding commit=none:open memory=none:unresolved-namespace
ch:trace row=CF-012 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-11-03-14#readme test=probe_readme_code_factory_20261030_110314.sh::source-checks doc=docs/traceability-doctrine.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-11-03-14-commands.txt witness=none:repository-contract-absent verdict=none:open-finding commit=none:open memory=none:unresolved-namespace
ch:trace row=CF-013 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-11-03-14#readme test=probe_readme_code_factory_20261030_110314.sh::hermes-check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-11-03-14-commands.txt witness=none:no-live-bunker-or-gateway-available verdict=none:open-finding commit=none:open memory=none:unresolved-namespace
ch:trace row=CF-015 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-11-03-14#readme test=probe_readme_code_factory_20261030_110314.sh::env-read-sites doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-11-03-14-commands.txt witness=path@origin:README.md verdict=none:open-finding commit=none:open memory=none:unresolved-namespace

STATUS: PARTIAL
TIER: T3 -- ran the documented repository commands and real executable checks; no live bunker, crier, gateway, release asset, or rendered public page was available
EVIDENCE: docs/audits/code-factory-readme-2026-10-30-11-03-14-commands.txt
