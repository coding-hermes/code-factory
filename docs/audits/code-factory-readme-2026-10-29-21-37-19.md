# code-factory README audit — 2026-10-29 21:37:19

Target: README.md at local commit 1c30c6f9db45b6bd8f9698b1c8d373ef0f98b751.
Published boundary: git ls-remote --symref origin HEAD returned refs/heads/main at d7faaf6aac31a9b9eb302a95887b68f83b8845d7. The local checkout was ahead/behind that boundary during probing; publication of this audit is verified separately by the board commit.

The README was not edited by this audit lane. Six canonical findings are recorded below. Each command was executed against the real /home/kara/code-factory checkout.

## Finding CF-009 — Quick start starts with an unstated prerequisite

Location: README.md:17-20.

Command: scripts/bunker-server-install.sh --check
Observed: scripts/bunker-server-install.sh: line 14: BUNKER_SERVER: set BUNKER_SERVER to your bunker server name
Exit: 1

The script expands BUNKER_SERVER before checking (scripts/bunker-server-install.sh:14), while the README exports it only later at lines 68-73. With BUNKER_SERVER=your-bunker-server, the checker reached its checks and returned RESULT: FAIL (2) because that placeholder was absent from local config and unreachable. Corrective direction: state the required variable before the first command and do not imply that the placeholder server name is usable.

ch:trace row=CF-009 spec=specs/NODE.md#layers wave=none:stand-in-tick-no-manifest test=tests/selftest.sh::selftest doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-29-21-37-19.md witness=none:local-checkout-and-local-config-only verdict=none:open-finding commit=none:unfixed memory=none:no-durable-record

## Finding CF-014 — Quick start invokes the wrong script and unsupported flag

Location: README.md:21-26.

The literal <id> placeholder is shell syntax, so the safe substitution probe was: ./scripts/project-node.sh --check --agent demo
Observed: unknown arg: --agent
Exit: 2

project-node.sh accepts --check and --project; it has no --agent option. It is the node-side provisioner, not the control-host creation path, and the following README command omits the required --check|--apply mode. Corrective direction: use a complete project-node.sh node-side check and use scripts/node-create.sh for control-host creation, with host context and placeholder substitution explained.

ch:trace row=CF-014 spec=specs/NODE.md#layers wave=none:stand-in-tick-no-manifest test=tests/selftest.sh::selftest doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-29-21-37-19.md witness=none:local-checkout-and-local-config-only verdict=none:open-finding commit=none:unfixed memory=none:no-durable-record

## Finding CF-010 — Layout claims six foreign adapters that are not shipped

Location: README.md:31-35.

Exact inventory from git ls-tree -r --name-only HEAD scripts/harness:
scripts/harness/install-claude-code.sh
scripts/harness/install-hermes.sh
scripts/harness/install-opencode.sh

The README lists opencode, claude-code, codex, aider, goose, and pi-agent as foreign-agent installers, but codex, aider, goose, and pi-agent are absent. The shipped Hermes adapter is omitted from the layout claim. Corrective direction: list only shipped installer files, identify Hermes separately, and label the four missing adapters planned/not shipped.

ch:trace row=CF-010 spec=specs/HARNESS.md#the-contract-every-adapter wave=none:stand-in-tick-no-manifest test=tests/selftest.sh::selftest doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-29-21-37-19.md witness=path@origin:scripts/harness/install-opencode.sh verdict=none:open-finding commit=none:unfixed memory=none:no-durable-record

## Finding CF-011 — AGENTS.md cites a nonexistent board row

Location: AGENTS.md:41.

The rule cites CF-108 for credential handling, but jq -r .id .coding-hermes/board/tasks.jsonl returns CF-001 through CF-008 before this audit and no CF-108. CF-002 owns node credential handling. Corrective direction: replace the dead citation with the owning row or create the intended work unit.

ch:trace row=CF-011 spec=AGENTS.md#rules wave=none:stand-in-tick-no-manifest test=tests/selftest.sh::selftest doc=AGENTS.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-29-21-37-19.md witness=path@origin:AGENTS.md verdict=none:open-finding commit=none:unfixed memory=none:no-durable-record

## Finding CF-012 — The owning repository lacks its required traceability doctrine

Probe: test -e docs/traceability-doctrine.md -> exit 1. git ls-tree -r --name-only HEAD docs | grep -i trace returned no result. README.md carries a traceability marker, but contributors have no repository-local doctrine defining its fields and closure rules. Corrective direction: add docs/traceability-doctrine.md or explicitly link the external fleet contract from a contributor-visible page.

ch:trace row=CF-012 spec=none:no-doctrine-exists wave=none:stand-in-tick-no-manifest test=tests/selftest.sh::selftest doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-29-21-37-19.md witness=none:no-doctrine-file-exists verdict=none:open-finding commit=none:unfixed memory=none:no-durable-record

## Finding CF-013 — Status table presents live claims without reproducible evidence

Commands run: scripts/harness/install-opencode.sh --check -> OPENCODE: PASS with a non-interactive warning; scripts/harness/install-claude-code.sh --check -> CLAUDE-CODE: FAIL (binary absent); scripts/harness/install-hermes.sh --check -> HERMES: FAIL (port 10800 empty); ./tests/selftest.sh -> SELFTEST: PASS; node-create with the README placeholder server -> server not found.

README.md:54 says Hermes in a bunker plus HTTP gateway works with a 32-second install, /api/status 200, and 133 JSON-RPC methods, but no repo artifact re-runs those figures and the current Hermes check cannot reproduce the gateway claim. Corrective direction: attach dated evidence or change the state to not currently verified.

ch:trace row=CF-013 spec=docs/PRD-code-factory.md#acceptance-for-the-first-milestone wave=none:stand-in-tick-no-manifest test=tests/selftest.sh::selftest doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-29-21-37-19.md witness=none:no-live-bunker-crier-or-node-available verdict=none:open-finding commit=none:unfixed memory=none:no-durable-record

## Unverified surfaces

No fresh public clone/install, live bunker node, crier dispatch, gateway round trip, release binary, or published rendered README was exercised. These are evidence limits, not additional failure claims.

STATUS: PASS
TIER: T4 -- executed README commands and local repository scripts, read artifacts back, and compared the published origin ref
EVIDENCE: docs/audits/code-factory-readme-2026-10-29-21-37-19.md
