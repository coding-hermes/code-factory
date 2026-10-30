# code-factory README audit — 2026-10-30 13:40:04 rerun

Publication boundary: the local published-tip reference `origin/main` resolves to `b433e0d6f714615b361b3a02848cf250c5a79133`. The scheduler-designated directory `/home/kara/.hermes/stand-in/readme/code-factory` is not the product repository; the canonical checkout is `/home/kara/code-factory`. Safe probes ran from a fresh `git archive origin/main` extraction with an isolated HOME. No README or source file was edited.

## Commands tested

Each command below was executed against the fresh published-tip archive. The placeholder `<project>` was replaced with `demo` only because the literal angle brackets are shell redirection syntax; this is recorded as a command-boundary limitation, not silently treated as a literal command.

`env -u BUNKER_SERVER -u CRIER_URL bash scripts/bunker-server-install.sh --check`
Result: exit 1. Output: `set BUNKER_SERVER to your bunker server name`. The script stops before performing the advertised host check when the README's earlier Quick start omits the required variable.

`env -u BUNKER_SERVER -u CRIER_URL bash scripts/project-node.sh --check --project demo`
Result: exit 1. The checker ran and ended `NODE: FAIL (3)`. It reported `CRIER_URL unset`, Hermes port `10800` empty, no provider key, absent Crier identity, and an absent node repo. This is the supported current argument shape.

`bash tests/selftest.sh`
Result: exit 0. Output ended `SELFTEST: PASS`; `15/15 rows parse`.

`env BUNKER_SERVER=your-bunker-server CRIER_URL=http://crier.example:8767 bash scripts/bunker-server-install.sh --check`
Result: exit 1. The placeholder bunker server had no configuration in the isolated HOME and was unreachable; output ended `RESULT: FAIL (2)`.

`env BUNKER_SERVER=your-bunker-server CRIER_URL=http://crier.example:8767 bash scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes`
Result: exit 1 at the safe provisioning boundary. Output: `bunker: server "your-bunker-server" not found in config`. No agent was created or retained.

`env HOME=<isolated-home> NODE_GATEWAY_PORT=10800 bash scripts/harness/install-hermes.sh --check`
Result: exit 1. Output ended `HERMES: FAIL (2)`: the local binary/version checks passed, but port `10800` was empty and no provider key was configured.

`bash -n scripts/*.sh scripts/harness/*.sh tests/selftest.sh`
Result: exit 0.

## README claims checked

Existing findings remain live; no duplicate task row was filed.

CF-009: Quick start step 1 invokes `scripts/bunker-server-install.sh --check` before introducing `BUNKER_SERVER` in the later infrastructure section. The literal command exits 1 before the host check.

CF-010: Layout says an installer exists for six foreign agents, but the published tree contains only `install-claude-code.sh`, `install-hermes.sh`, and `install-opencode.sh`. The four absent foreign adapters remain an existing implementation finding.

CF-011: `AGENTS.md` cites `CF-108`, while the published board has no row with that id.

CF-012: `docs/traceability-doctrine.md` is absent from the published tree despite the fleet contract requiring that repository-local path.

CF-013: The status table says the Hermes bunker plus HTTP gateway **works** and gives historical `32 s`, `/api/status 200`, and `133 JSON-RPC methods`. The fresh-HOME Hermes check failed on the empty port and missing provider key. No live bunker/gateway round trip was available, so the historical figures remain unverified rather than disproven; the wording still promises more than this audit can re-run.

CF-014: The former unsupported `--agent` Quick start invocation is absent from the published tip. The current supported form is `--check --project`; no new defect or closure was asserted.

CF-015: The infrastructure section says “Three environment variables” but exports only `CRIER_URL` and `BUNKER_SERVER`; the provider credential is file-based. The wording remains inaccurate.

## Unverified boundaries

No release asset, rendered anonymous public README, live Crier dispatch, node gateway round trip, or external deployment boundary was exercised. These are evidence limits, not additional failures. The current published board already owns every measured finding class above, so this run records an audit event only.

ch:trace row=CF-009 spec=README.md#quick-start wave=code-factory-readme-2026-10-30-13-40-04#readme test=scripts/bunker-server-install.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-13-40-04-rerun.md witness=none:placeholder-infrastructure-and-fresh-archive-only verdict=none:open-finding commit=b433e0d6f714615b361b3a02848cf250c5a79133 memory=none:duckbrain-current-key-not-resolved
ch:trace row=CF-010 spec=README.md#layout wave=code-factory-readme-2026-10-30-13-40-04#readme test=git-ls-tree::harness-installer-inventory doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-13-40-04-rerun.md witness=path@origin:scripts/harness verdict=none:open-finding commit=b433e0d6f714615b361b3a02848cf250c5a79133 memory=none:duckbrain-current-key-not-resolved
ch:trace row=CF-011 spec=AGENTS.md#rules wave=code-factory-readme-2026-10-30-13-40-04#readme test=jq::board-id-census doc=AGENTS.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-13-40-04-rerun.md witness=path@origin:AGENTS.md verdict=none:open-finding commit=b433e0d6f714615b361b3a02848cf250c5a79133 memory=none:duckbrain-current-key-not-resolved
ch:trace row=CF-012 spec=docs/traceability-doctrine.md#required-path wave=code-factory-readme-2026-10-30-13-40-04#readme test=test::docs-traceability-doctrine-absent doc=docs/traceability-doctrine.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-13-40-04-rerun.md witness=none:published-tip-path-absent verdict=none:open-finding commit=b433e0d6f714615b361b3a02848cf250c5a79133 memory=none:duckbrain-current-key-not-resolved
ch:trace row=CF-013 spec=README.md#status wave=code-factory-readme-2026-10-30-13-40-04#readme test=scripts/harness/install-hermes.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-13-40-04-rerun.md witness=none:no-live-bunker-or-gateway-available verdict=none:open-finding commit=b433e0d6f714615b361b3a02848cf250c5a79133 memory=none:duckbrain-current-key-not-resolved
ch:trace row=CF-014 spec=README.md#quick-start wave=code-factory-readme-2026-10-30-13-40-04#readme test=test::unsupported-agent-argument-absent doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-13-40-04-rerun.md witness=path@origin:README.md verdict=none:not-reproduced commit=b433e0d6f714615b361b3a02848cf250c5a79133 memory=none:duckbrain-current-key-not-resolved
ch:trace row=CF-015 spec=README.md#running-it-against-your-own-infrastructure wave=code-factory-readme-2026-10-30-13-40-04#readme test=grep::environment-variable-inventory doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-13-40-04-rerun.md witness=path@origin:README.md verdict=none:open-finding commit=b433e0d6f714615b361b3a02848cf250c5a79133 memory=none:duckbrain-current-key-not-resolved

STATUS: PARTIAL
TIER: T4 -- executed the published README commands from a fresh archive, read their outputs back, and checked the published tree; live bunker/Crier/gateway/release-render boundaries were unavailable
EVIDENCE: docs/audits/code-factory-readme-2026-10-30-13-40-04-rerun.md