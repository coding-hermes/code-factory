# code-factory README audit — 2026-10-30 00:02:33

Target: published `origin/main` at `3d9f81c15b6bce7ad34c584b06ac98dee7e31cd4`.
The audit used a detached worktree of the published tip and a fresh HOME. The README was not edited.

## Commands tested

The README quick start and infrastructure examples were followed literally where safe. Placeholder provisioning was executed only far enough to observe its refusal; no real node was created.

- `env -u BUNKER_SERVER bash scripts/bunker-server-install.sh --check` -> exit 1 before any checks: `scripts/bunker-server-install.sh: line 14: BUNKER_SERVER: set BUNKER_SERVER to your bunker server name`.
- `env -u CRIER_URL bash scripts/project-node.sh --check --project demo` -> exit 1, `NODE: FAIL (3)`; `CRIER_URL` was unset, Hermes port `10800` was empty, no inference key was configured, no crier identity existed, and the fresh HOME had no repo. The command itself is valid and reaches the node checker.
- `bash tests/selftest.sh` -> exit 0, `SELFTEST: PASS`.
- `scripts/bunker-server-install.sh --check` after exporting the README's `CRIER_URL` and `BUNKER_SERVER` -> exit 1, `RESULT: FAIL (2)`; the fresh HOME still had no bunker config and the placeholder server was unreachable.
- `scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes` -> exit 1 at the safe provisioning boundary: `bunker: server "your-bunker-server" not found in config`. No agent was created.
- `bash scripts/harness/install-claude-code.sh --check` -> exit 1, `CLAUDE-CODE: FAIL (1)`; binary absent.
- `bash scripts/harness/install-hermes.sh --check` -> exit 1, `HERMES: FAIL (2)`; port `10800` empty and provider key absent.
- `bash scripts/harness/install-opencode.sh --check` -> exit 0, `OPENCODE: PASS`, with warnings that the binary is not under `$HOME` and non-interactive mode was not confirmed.

## Findings and wording review

No new canonical board finding was filed. Existing rows already cover the live README defects found again:

- CF-009 covers the missing/late bunker-server prerequisite. The current published quick start now includes the valid project-node command, but the first command still runs against a placeholder server and fails in a clean environment.
- CF-010 covers the layout's claim that every named foreign harness has an installer. The tracked published inventory contains only `install-claude-code.sh`, `install-hermes.sh`, and `install-opencode.sh`.
- CF-013 covers the status table's historical Hermes claim. The current adapter check cannot reproduce the live gateway measurement from a fresh HOME; the claimed 32-second install, `/api/status` 200, and 133 JSON-RPC methods remain historical measurements in `specs/HARNESS.md`, not a current repo-local run.
- CF-015 covers the wording `Three environment variables and one harness` while the block names only `CRIER_URL` and `BUNKER_SERVER`; no additional variable was found in the README's documented path.

The README's five relative documentation links and the `skills/code-factory-foreman/SKILL.md` path exist at the published tip. The README has six balanced fences. No release binary, live bunker, crier dispatch, gateway round trip, or rendered public page was available, so those surfaces remain unverified rather than being reported as failures.

ch:trace row=CF-009 spec=README.md#quick-start wave=code-factory-readme-2026-10-30-00-02-33#readme test=tests/selftest.sh::selftest doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-00-02-33.md witness=none:placeholder-infrastructure-and-local-checkout-only verdict=none:open-finding commit=none:open memory=none:exact-key-not-found
ch:trace row=CF-010 spec=README.md#layout wave=code-factory-readme-2026-10-30-00-02-33#readme test=tests/selftest.sh::selftest doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-00-02-33.md witness=path@origin:scripts/harness verdict=none:open-finding commit=none:open memory=none:exact-key-not-found
ch:trace row=CF-013 spec=README.md#status wave=code-factory-readme-2026-10-30-00-02-33#readme test=scripts/harness/install-hermes.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-00-02-33.md witness=none:no-live-bunker-or-gateway-available verdict=none:open-finding commit=none:open memory=none:exact-key-not-found
ch:trace row=CF-015 spec=README.md#running-it-against-your-own-infrastructure wave=code-factory-readme-2026-10-30-00-02-33#readme test=tests/selftest.sh::selftest doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-00-02-33.md witness=path@origin:README.md verdict=none:open-finding commit=none:open memory=none:exact-key-not-found

STATUS: PASS
TIER: T4 -- executed the published README commands in a detached published-tip worktree, read local artifacts back, and checked the real origin tree
EVIDENCE: docs/audits/code-factory-readme-2026-10-30-00-02-33.md
