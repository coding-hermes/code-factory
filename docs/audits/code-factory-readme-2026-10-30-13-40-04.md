# code-factory README audit — 2026-10-30 13:40:04

Target: published `origin/main` at `b433e0d6f714615b361b3a02848cf250c5a79133`.
The scheduler stand-in directory is not the product repository; the canonical checkout is `/home/kara/code-factory`. This audit used a fresh detached worktree of the published tip at `/var/tmp/cf-readme-audit-20261030-134004` and a fresh HOME under `/var/tmp/cf-readme-audit-20261030-134004/home`. The README was not edited.

## Commands tested

The README's command blocks were followed literally where safe. Placeholder provisioning was taken only to its refusal boundary; no node or credential was created.

- `env -u BUNKER_SERVER -u CRIER_URL HOME=/var/tmp/.../home scripts/bunker-server-install.sh --check` -> exit 1: `scripts/bunker-server-install.sh: line 14: BUNKER_SERVER: set BUNKER_SERVER to your bunker server name`.
- `scripts/project-node.sh --check --project <project>` cannot be sent literally through a shell because `<project>` is parsed as redirection syntax. With the safe substitution `--project demo`, `env -u CRIER_URL ... scripts/project-node.sh --check --project demo` -> exit 1, and reached the checker: `NODE: FAIL (3)` with `CRIER_URL` unset, Hermes port `10800` empty, no provider key, no crier identity, and no repo.
- `env -u BUNKER_SERVER -u CRIER_URL HOME=/var/tmp/.../home bash tests/selftest.sh` -> exit 0: `SELFTEST: PASS`, `15/15 rows parse`.
- `bash -n scripts/*.sh scripts/harness/*.sh tests/selftest.sh` -> exit 0.
- With the README's placeholder exports, `HOME=/var/tmp/.../home BUNKER_SERVER=your-bunker-server CRIER_URL=http://crier.example:8767 scripts/bunker-server-install.sh --check` -> exit 1: `RESULT: FAIL (2)` because the placeholder server was not declared/reachable.
- With the same placeholder exports, `scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes` -> exit 1 at the safe provisioning boundary: `bunker: server "your-bunker-server" not found in config`. No node was retained.
- `HOME=/var/tmp/.../home NODE_GATEWAY_PORT=10800 bash scripts/harness/install-hermes.sh --check` -> exit 1: `HERMES: FAIL (2)`; the local Hermes binary/version check passed, but port `10800` was empty and no provider key was configured.
- `scripts/boardctl validate` -> exit 0: `RESULT: OK (1 warning(s))`; the warning is the expected headerless-board topology. The published board has 15 task rows and 10 events.
- The five README-linked documents exist: `docs/BOARD.md`, `docs/ACCEPTANCE-PLAN.md`, `docs/OPERATIONS.md`, `docs/THREAT-MODEL.md`, and `docs/SCHEDULER-ADMISSION.md`.
- README fence census -> 6 fences, balanced. `git diff --check` -> exit 0.
- `curl -sS -L --max-time 20 https://api.github.com/repos/coding-hermes/code-factory/releases/latest` -> HTTP 404 (`Not Found`): no published release asset exists to probe. The authenticated public repository metadata reports default branch `main`, `private=false`, and `pushed_at=2026-10-30T14:39:18Z`.

## Existing findings re-measured; no duplicate rows filed

The current published board contains open rows `CF-009` through `CF-015`. Each measured README defect remains covered by an existing row, so this sweep appends an audit event and does not create a duplicate.

CF-009 — README Quick start runs `scripts/bunker-server-install.sh --check` before it explains the required `BUNKER_SERVER`. The literal command fails before the advertised check. The later infrastructure block also uses a placeholder server that fails at the safe configuration boundary.

CF-010 — The Layout says `install-<harness>.sh` exists for opencode, claude-code, codex, aider, goose, and pi-agent. The published tree contains only `install-claude-code.sh`, `install-hermes.sh`, and `install-opencode.sh`. The four absent adapters are already owned by the implementation row CF-006.

CF-011 — `AGENTS.md` still cites `CF-108`, while the published board has no `CF-108`. The source and acceptance documents use CF-108 as a PRD requirement, but the AGENTS citation presents it as a board row; this remains a dead board pointer.

CF-012 — `docs/traceability-doctrine.md` is absent from the published tree, although the repository contains `ch:trace` markers and the fleet contract names that path as the owning repository's authority.

CF-013 — The status table still presents Hermes in a bunker plus HTTP gateway as **works** with `32 s`, `/api/status 200`, and `133 JSON-RPC methods`. The current fresh-HOME `install-hermes.sh --check` failed on the empty port and missing provider key. The historical figures are recorded in `specs/HARNESS.md`, but no current repository-local artifact re-runs the live bunker/gateway boundary. The status wording promises more than this checkout proves.

CF-014 — Not reproduced on this published tip. The Quick start now uses the supported `scripts/project-node.sh --check --project <project>` form and explicitly blocks production creation. The literal angle-bracket placeholder still needs substitution before shell execution, but the former unsupported `--agent` invocation is absent; no new row or closure was asserted.

CF-015 — The infrastructure section says `Three environment variables and one harness`, but its block exports only `CRIER_URL` and `BUNKER_SERVER`. The provider credential is file-based in `~/.hermes/.env`, not a third environment variable. The wording remains inaccurate.

## Wording that overpromises

The status word **works** for the Hermes gateway row is stronger than the available evidence: the README gives historical measurements without a current re-runnable live artifact, while the fresh adapter check returned `HERMES: FAIL (2)`.

The Layout's “one per foreign agent” wording names four installer files that are not shipped.

“Three environment variables” names two exported variables and silently folds a file-based provider credential into the count.

The Quick start's `--project <project>` placeholder is not a literal shell command until the reader replaces the placeholder; the report records this as a command-boundary limitation, not as a new duplicate finding.

## Unverified boundary

No release asset was available, and no live bunker node, Crier dispatch, node gateway round trip, or anonymous rendered-page probe was available in this lane. These are evidence limits, not additional failures. The audit therefore does not claim that the historical Hermes measurements are false; it claims only that the published README does not provide current repository-local proof for them.

ch:trace row=CF-009 spec=README.md#quick-start wave=code-factory-readme-2026-10-30-13-40-04#readme test=scripts/bunker-server-install.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-13-40-04.md witness=none:placeholder-infrastructure-and-fresh-clone-only verdict=none:open-finding commit=b433e0d6f714615b361b3a02848cf250c5a79133 memory=/event/code-factory/decisions-2026-10-30-0228
ch:trace row=CF-010 spec=README.md#layout wave=code-factory-readme-2026-10-30-13-40-04#readme test=git-ls-tree::harness-installer-inventory doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-13-40-04.md witness=path@origin:scripts/harness verdict=none:open-finding commit=b433e0d6f714615b361b3a02848cf250c5a79133 memory=/event/code-factory/decisions-2026-10-30-0228
ch:trace row=CF-011 spec=AGENTS.md#rules wave=code-factory-readme-2026-10-30-13-40-04#readme test=jq::board-id-census doc=AGENTS.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-13-40-04.md witness=path@origin:AGENTS.md verdict=none:open-finding commit=b433e0d6f714615b361b3a02848cf250c5a79133 memory=/event/code-factory/decisions-2026-10-30-0228
ch:trace row=CF-012 spec=none:no-doctrine-exists wave=code-factory-readme-2026-10-30-13-40-04#readme test=test::docs-traceability-doctrine-absent doc=docs/traceability-doctrine.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-13-40-04.md witness=none:repository-contract-file-absent verdict=none:open-finding commit=b433e0d6f714615b361b3a02848cf250c5a79133 memory=/event/code-factory/decisions-2026-10-30-0228
ch:trace row=CF-013 spec=README.md#status wave=code-factory-readme-2026-10-30-13-40-04#readme test=scripts/harness/install-hermes.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-13-40-04.md witness=none:no-live-bunker-or-gateway-available verdict=none:open-finding commit=b433e0d6f714615b361b3a02848cf250c5a79133 memory=/event/code-factory/decisions-2026-10-30-0228
ch:trace row=CF-014 spec=README.md#quick-start wave=code-factory-readme-2026-10-30-13-40-04#readme test=test::unsupported-agent-argument-absent doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-13-40-04.md witness=path@origin:README.md verdict=none:not-reproduced commit=b433e0d6f714615b361b3a02848cf250c5a79133 memory=/event/code-factory/decisions-2026-10-30-0228
ch:trace row=CF-015 spec=README.md#running-it-against-your-own-infrastructure wave=code-factory-readme-2026-10-30-13-40-04#readme test=grep::environment-variable-inventory doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-13-40-04.md witness=path@origin:README.md verdict=none:open-finding commit=b433e0d6f714615b361b3a02848cf250c5a79133 memory=/event/code-factory/decisions-2026-10-30-0228

STATUS: PARTIAL
TIER: T4 -- ran the published README commands and local scripts in a fresh published-tip worktree, read the board and repository artifacts back, and queried the public repository boundary; live bunker/Crier/gateway/release-render boundaries were unavailable
EVIDENCE: docs/audits/code-factory-readme-2026-10-30-13-40-04.md
