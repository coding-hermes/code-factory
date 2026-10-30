# code-factory README audit — 2026-10-30 08:47:09

Target: published `origin/main` at `b433e0d6f714615b361b3a02848cf250c5a79133`.
The audit used `/var/tmp/code-factory-readme-20261030-0847`, a clean detached worktree of the published tip. The README was not edited and no node was provisioned.

## Commands tested

The README Quick start and infrastructure examples were followed literally where safe. Placeholder provisioning was run only to its refusal boundary.

- `env -u BUNKER_SERVER scripts/bunker-server-install.sh --check` -> exit 1: `set BUNKER_SERVER to your bunker server name`.
- `env -u CRIER_URL scripts/project-node.sh --check --project demo` -> exit 1, `NODE: FAIL (3)`; the checker reported unset `CRIER_URL`, empty Hermes port `10800`, no provider key, no crier identity, and no repo in the fresh HOME.
- `bash tests/selftest.sh` -> exit 0, `SELFTEST: PASS`; the published board census was `15/15` rows.
- `BUNKER_SERVER=your-bunker-server scripts/bunker-server-install.sh --check` -> exit 1, `RESULT: FAIL (2)`; in the fresh HOME the bunker config was missing and the placeholder server was unreachable.
- `BUNKER_SERVER=your-bunker-server CRIER_URL=http://crier.example:8767 scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes` -> exit 1: `bunker: server "your-bunker-server" not found in config`; no agent was created.
- `scripts/harness/install-claude-code.sh --check` -> exit 1, `CLAUDE-CODE: FAIL (1)`; the binary was absent.
- `scripts/harness/install-hermes.sh --check` -> exit 1, `HERMES: FAIL (2)`; the binary/version checks passed, but port `10800` and the provider key were absent in the fresh HOME.
- `scripts/harness/install-opencode.sh --check` -> exit 1, `OPENCODE: FAIL (1)`; the binary was absent and non-interactive mode was not confirmed.

## Findings and wording review

No new canonical board row was filed. The published board has 15 rows (`CF-001` through `CF-015`); the measured defects remain covered by existing open rows:

- CF-009: Quick start runs the bunker check before documenting `BUNKER_SERVER`; the clean command aborts before checking, and the placeholder server fails the configured-server check.
- CF-010: the layout says one installer exists for six foreign agents, while the published tree contains only `install-claude-code.sh`, `install-hermes.sh`, and `install-opencode.sh`.
- CF-011: `AGENTS.md` still cites nonexistent board row `CF-108`; the published board has no such row.
- CF-012: `docs/traceability-doctrine.md` is absent at the published tip.
- CF-013: the status table still calls Hermes-in-bunker **works** with `32 s`, `/api/status 200`, and `133 JSON-RPC methods`, but the fresh Hermes check fails on the empty port and absent provider key; no repository-local rerunnable artifact proves those historical figures.
- CF-015: README says `Three environment variables and one harness`, but the block names only `CRIER_URL` and `BUNKER_SERVER`; the provider credential is file-based in `~/.hermes/.env`.

The README's referenced documentation paths exist at the published tip, and its six fenced-code markers are balanced. The lane table contains 14 rows, matching its stated 14-project family. No release binary, rendered public README, live crier dispatch, node gateway round trip, or published release artifact was available; those surfaces remain unverified rather than being reported as failures.

ch:trace row=CF-009 spec=README.md#quick-start wave=code-factory-readme-2026-10-30-08-47-09#readme test=tests/selftest.sh::selftest doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-08-47-09.md witness=none:placeholder-infrastructure-and-local-checkout-only verdict=none:open-finding commit=none:unfixed memory=none:unverified-memory-write
ch:trace row=CF-010 spec=README.md#layout wave=code-factory-readme-2026-10-30-08-47-09#readme test=tests/selftest.sh::selftest doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-08-47-09.md witness=path@origin:scripts/harness verdict=none:open-finding commit=none:unfixed memory=none:unverified-memory-write
ch:trace row=CF-011 spec=AGENTS.md#rules wave=code-factory-readme-2026-10-30-08-47-09#readme test=tests/selftest.sh::selftest doc=AGENTS.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-08-47-09.md witness=path@origin:AGENTS.md verdict=none:open-finding commit=none:unfixed memory=none:unverified-memory-write
ch:trace row=CF-012 spec=none:no-doctrine-exists wave=code-factory-readme-2026-10-30-08-47-09#readme test=tests/selftest.sh::selftest doc=docs/traceability-doctrine.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-08-47-09.md witness=none:no-doctrine-file-exists verdict=none:open-finding commit=none:unfixed memory=none:unverified-memory-write
ch:trace row=CF-013 spec=README.md#status wave=code-factory-readme-2026-10-30-08-47-09#readme test=scripts/harness/install-hermes.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-08-47-09.md witness=none:no-live-bunker-or-gateway-available verdict=none:open-finding commit=none:unfixed memory=none:unverified-memory-write
ch:trace row=CF-015 spec=README.md#running-it-against-your-own-infrastructure wave=code-factory-readme-2026-10-30-08-47-09#readme test=tests/selftest.sh::selftest doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-08-47-09.md witness=path@origin:README.md verdict=none:open-finding commit=none:unfixed memory=none:unverified-memory-write

STATUS: PASS
TIER: T4 -- executed the published README commands in a clean published-tip worktree with a fresh HOME, read the repository files back, and ran the repository selftest
EVIDENCE: docs/audits/code-factory-readme-2026-10-30-08-47-09.md
