# code-factory README audit — 2026-10-30 14:54:06

Publication boundary: `origin/main` resolved to `b433e0d6f714615b361b3a02848cf250c5a79133` via `git ls-remote --symref origin HEAD`. The scheduler stand-in directory is not the product repository; this audit ran from a fresh archive of that published tip with an isolated temporary HOME. No README or source file was edited. The repository does not contain `docs/traceability-doctrine.md`; this audit therefore uses `spec=none:repo-contains-no-docs-traceability-doctrine` for the local contract boundary.

## Commands tested

All commands below were run from the fresh published-tip archive. Placeholder angle-bracket values were not passed literally because the shell would interpret them as redirection; safe representative values were used where required.

1. `env -u BUNKER_SERVER -u CRIER_URL bash scripts/bunker-server-install.sh --check`
   Exit 1. Output: `BUNKER_SERVER: set BUNKER_SERVER to your bunker server name`.

2. `env -u BUNKER_SERVER -u CRIER_URL bash scripts/project-node.sh --check --project demo`
   Exit 1. The command reached the supported parser and ended `NODE: FAIL (3)`, reporting absent Crier identity, absent node repository, and the other missing node prerequisites.

3. `bash tests/selftest.sh`
   Exit 0. Output ended `SELFTEST: PASS` and `PASS 15/15 rows parse`.

4. `env BUNKER_SERVER=your-bunker-server CRIER_URL=http://crier.example:8767 bash scripts/bunker-server-install.sh --check`
   Exit 1. Output ended `RESULT: FAIL (2)` because the placeholder bunker server was not configured/reachable. This is an infrastructure-boundary refusal, not evidence that the script syntax is broken.

5. `env BUNKER_SERVER=your-bunker-server CRIER_URL=http://crier.example:8767 bash scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes`
   Exit 1 at the safe provisioning boundary. Output: `bunker: server "your-bunker-server" not found in config`. No agent was retained.

6. `env HOME=<isolated-home> NODE_GATEWAY_PORT=10800 bash scripts/harness/install-hermes.sh --check`
   Exit 1. Output ended `HERMES: FAIL (2)` because port `10800` was empty and no provider key was configured; the local binary and version checks passed.

7. `bash -n scripts/*.sh scripts/harness/*.sh tests/selftest.sh`
   Exit 0.

8. `scripts/boardctl validate`
   Exit 0. Output: `RESULT: OK (1 warning(s))`; the warning is the pre-existing headerless-board topology. This audit did not repair that unrelated warning.

## README claims and wording that overpromise

No new canonical finding was filed. The current published board already owns every measured finding class:

- CF-009: Quick start invokes `bunker-server-install.sh --check` before introducing the required `BUNKER_SERVER`; the literal clean-environment command exits 1 before the host check.
- CF-010: The layout says there is one installer per named foreign agent, but the published tree contains only `install-claude-code.sh`, `install-hermes.sh`, and `install-opencode.sh`; codex, aider, goose, and pi-agent installers are absent.
- CF-011: `AGENTS.md` cites nonexistent board row `CF-108`; the published board has no such id.
- CF-012: `docs/traceability-doctrine.md` is absent from the published tree.
- CF-013: The status table calls the Hermes bunker/gateway path **works** and repeats historical `32 s`, `/api/status 200`, and `133 JSON-RPC methods`, but the fresh-HOME adapter check failed and no live bunker/gateway boundary was available for this sweep. The historical figures remain unverified, not disproven.
- CF-015: The infrastructure section says “Three environment variables” but names only `CRIER_URL` and `BUNKER_SERVER`; the node's inference credential is file-based and no third exported variable appears in the documented block.

The former unsupported `--agent` quick-start invocation is absent from the published tip, so the earlier CF-014 finding was not re-filed.

## Unverified boundaries

No release asset, anonymous rendered public README, live Crier dispatch, node gateway round trip, or external deployment boundary was exercised. Those are evidence limits, not additional failures. No README wording was changed by this lane.

ch:trace row=CF-009 spec=README.md#quick-start wave=code-factory-readme-2026-10-30-14-54-06#readme test=scripts/bunker-server-install.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-14-54-06.md witness=none:placeholder-infrastructure-and-fresh-archive-only verdict=none:existing-open-finding commit=b433e0d6f714615b361b3a02848cf250c5a79133 memory=none:namespace-read-failed
ch:trace row=CF-010 spec=README.md#layout wave=code-factory-readme-2026-10-30-14-54-06#readme test=git-ls-tree::harness-installer-inventory doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-14-54-06.md witness=path@origin:scripts/harness verdict=none:existing-open-finding commit=b433e0d6f714615b361b3a02848cf250c5a79133 memory=none:namespace-read-failed
ch:trace row=CF-011 spec=AGENTS.md#rules wave=code-factory-readme-2026-10-30-14-54-06#readme test=jq::board-id-census doc=AGENTS.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-14-54-06.md witness=path@origin:AGENTS.md verdict=none:existing-open-finding commit=b433e0d6f714615b361b3a02848cf250c5a79133 memory=none:namespace-read-failed
ch:trace row=CF-012 spec=none:repo-contains-no-docs-traceability-doctrine wave=code-factory-readme-2026-10-30-14-54-06#readme test=test::docs-traceability-doctrine-absent doc=docs/traceability-doctrine.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-14-54-06.md witness=none:published-tip-path-absent verdict=none:existing-open-finding commit=b433e0d6f714615b361b3a02848cf250c5a79133 memory=none:namespace-read-failed
ch:trace row=CF-013 spec=README.md#status wave=code-factory-readme-2026-10-30-14-54-06#readme test=scripts/harness/install-hermes.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-14-54-06.md witness=none:no-live-bunker-or-gateway-available verdict=none:existing-open-finding commit=b433e0d6f714615b361b3a02848cf250c5a79133 memory=none:namespace-read-failed
ch:trace row=CF-015 spec=README.md#running-it-against-your-own-infrastructure wave=code-factory-readme-2026-10-30-14-54-06#readme test=grep::environment-variable-inventory doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-14-54-06.md witness=path@origin:README.md verdict=none:existing-open-finding commit=b433e0d6f714615b361b3a02848cf250c5a79133 memory=none:namespace-read-failed

STATUS: PARTIAL
TIER: T4 -- executed every safe README command from a fresh published-tip archive, read outputs back, and validated the published board; live bunker/Crier/gateway/release-render boundaries were unavailable
EVIDENCE: docs/audits/code-factory-readme-2026-10-30-14-54-06.md
