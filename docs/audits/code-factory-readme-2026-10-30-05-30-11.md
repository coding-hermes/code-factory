# code-factory README audit — 2026-10-30 05:30:11

Target: published `origin/main` at `b433e0d6f714615b361b3a02848cf250c5a79133`.
The audit ran in `/home/kara/worktrees/code-factory-readme-20261030-0530`, a clean worktree of that published tip. The README was not edited because the measured defects remain covered by open board rows CF-009, CF-010, CF-011, CF-012, CF-013, and CF-015. No new canonical row was filed.

## Commands tested literally

The README's Quick start, infrastructure example, selftest, and shipped harness checks were run. Placeholder provisioning was taken only to its safe refusal boundary; no real node was created.

- `env -u BUNKER_SERVER scripts/bunker-server-install.sh --check` -> exit 1 before checks: `scripts/bunker-server-install.sh: line 14: BUNKER_SERVER: set BUNKER_SERVER to your bunker server name`.
- `env -u CRIER_URL scripts/project-node.sh --check --project demo` -> exit 1, `NODE: FAIL (3)`; it reported `CRIER_URL` unset, Hermes port `10800` empty, no crier identity, and no repo. The documented command is valid and reaches the checker.
- `bash tests/selftest.sh` -> exit 0, `SELFTEST: PASS`; the published board census was `15/15` rows.
- `BUNKER_SERVER=your-bunker-server scripts/bunker-server-install.sh --check` -> exit 1, `RESULT: FAIL (2)`; the placeholder server was absent from the fresh bunker config and unreachable.
- `BUNKER_SERVER=your-bunker-server CRIER_URL=http://crier.example:8767 scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes` -> exit 1: `bunker: server "your-bunker-server" not found in config`; no agent was created.
- `scripts/harness/install-claude-code.sh --check` -> exit 1, `CLAUDE-CODE: FAIL (1)`; binary absent.
- `scripts/harness/install-hermes.sh --check` -> exit 1, `HERMES: FAIL (1)`; the Hermes binary/version and provider-key checks passed, but port `10800` was empty.
- `scripts/harness/install-opencode.sh --check` -> exit 0, `OPENCODE: PASS`, with a warning that non-interactive mode could not be confirmed.

## Findings and wording that overpromises

- CF-009 remains live: Quick start step 1 invokes `bunker-server-install.sh --check` before the README explains `BUNKER_SERVER`; a clean reader gets an immediate fatal error.
- CF-010 remains live: Layout names installers for six foreign agents, but the published tree contains only `install-claude-code.sh`, `install-hermes.sh`, and `install-opencode.sh`. The missing codex, aider, goose, and pi-agent installers are covered by CF-006.
- CF-011 remains live: `AGENTS.md` cites `CF-108`, but the published board has no such row; the credential requirement belongs to CF-002.
- CF-012 remains live: `docs/traceability-doctrine.md` is absent, although the repository carries `ch:trace` markers and the lane contract requires that path.
- CF-013 remains live: the status table calls Hermes in a bunker plus HTTP gateway **works** and gives `32 s`, `/api/status 200`, and `133 JSON-RPC methods`, but the fresh check failed because port `10800` was empty and no repository-local rerunnable artifact proves those historical figures.
- CF-015 remains live: README says `Three environment variables and one harness`, but the example exports only `CRIER_URL` and `BUNKER_SERVER`; the provider credential is file-based in `~/.hermes/.env`, not a third environment variable.
- The README's documented relative paths exist at the published tip and its fenced blocks are balanced. No release binary, rendered public README, live crier dispatch, node gateway round trip, or published release artifact was available; those surfaces remain unverified rather than being reported as failures.

ch:trace row=CF-009 spec=README.md#quick-start wave=code-factory-readme-2026-10-30-05-30-11#readme test=tests/selftest.sh::selftest doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-05-30-11.md witness=none:placeholder-infrastructure-and-local-checkout-only verdict=none:open-finding commit=none:unfixed memory=/project/code-factory/readme-audit-2026-10-30
ch:trace row=CF-010 spec=README.md#layout wave=code-factory-readme-2026-10-30-05-30-11#readme test=tests/selftest.sh::selftest doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-05-30-11.md witness=path@origin:scripts/harness verdict=none:open-finding commit=none:unfixed memory=/project/code-factory/readme-audit-2026-10-30
ch:trace row=CF-011 spec=AGENTS.md#rules wave=code-factory-readme-2026-10-30-05-30-11#readme test=tests/selftest.sh::selftest doc=AGENTS.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-05-30-11.md witness=path@origin:AGENTS.md verdict=none:open-finding commit=none:unfixed memory=/project/code-factory/readme-audit-2026-10-30
ch:trace row=CF-012 spec=none:no-doctrine-exists wave=code-factory-readme-2026-10-30-05-30-11#readme test=tests/selftest.sh::selftest doc=docs/traceability-doctrine.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-05-30-11.md witness=none:no-doctrine-file-exists verdict=none:open-finding commit=none:unfixed memory=/project/code-factory/readme-audit-2026-10-30
ch:trace row=CF-013 spec=README.md#status wave=code-factory-readme-2026-10-30-05-30-11#readme test=scripts/harness/install-hermes.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-05-30-11.md witness=none:no-live-bunker-or-gateway-available verdict=none:open-finding commit=none:unfixed memory=/project/code-factory/readme-audit-2026-10-30
ch:trace row=CF-015 spec=README.md#running-it-against-your-own-infrastructure wave=code-factory-readme-2026-10-30-05-30-11#readme test=tests/selftest.sh::selftest doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-05-30-11.md witness=path@origin:README.md verdict=none:open-finding commit=none:unfixed memory=/project/code-factory/readme-audit-2026-10-30

STATUS: PASS
TIER: T4 -- executed the published README commands in a clean published-tip worktree and read the repository files and command outputs back
EVIDENCE: docs/audits/code-factory-readme-2026-10-30-05-30-11.md
