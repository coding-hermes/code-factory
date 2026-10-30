# code-factory README audit — 2026-10-30 01:33:38

Target: published `origin/main` at `4cb40dc8bbda2a246a7a843b5ff3cc91feb2e744`.
The audit ran from a clean worktree at that published tip with a fresh HOME under `/var/tmp`. The README was not edited.

## Commands tested

The README's Quick start and infrastructure examples were followed literally where safe. Placeholder provisioning was executed only to its safe refusal boundary; no real node was created.

- `env -u BUNKER_SERVER bash scripts/bunker-server-install.sh --check` -> exit 1 before checks: `scripts/bunker-server-install.sh: line 14: BUNKER_SERVER: set BUNKER_SERVER to your bunker server name`.
- `env -u CRIER_URL bash scripts/project-node.sh --check --project demo` -> exit 1 with `NODE: FAIL (3)`: `CRIER_URL` unset, Hermes port `10800` empty, no inference key, no crier identity, and no repo in the fresh HOME.
- `bash tests/selftest.sh` -> exit 0, `SELFTEST: PASS`; the published board census was `15/15` rows.
- `BUNKER_SERVER=your-bunker-server bash scripts/bunker-server-install.sh --check` -> exit 1, `RESULT: FAIL (2)`; the placeholder server was absent from the fresh bunker config and unreachable.
- `BUNKER_SERVER=your-bunker-server CRIER_URL=http://crier.example:8767 bash scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes` -> exit 1: `bunker: server "your-bunker-server" not found in config` on the published branch's clean-home run. In the follow-up literal invocation from a fresh home, the script instead reached `FAIL spawn — scripts/node-create.sh: line 35: : command not found` and still returned 1; no agent was retained.
- `bash scripts/harness/install-claude-code.sh --check` -> exit 1, `CLAUDE-CODE: FAIL (1)`; the binary was absent.
- `bash scripts/harness/install-hermes.sh --check` -> exit 1, `HERMES: FAIL (3)`; the binary and port `10800` were absent and no provider key existed in the fresh HOME.
- `bash scripts/harness/install-opencode.sh --check` -> exit 1, `OPENCODE: FAIL (1)`; the binary was absent, with warnings that it was not under `$HOME` and non-interactive mode was not confirmed.

## Published README checks

- All five README links checked against the published tree exist: `docs/BOARD.md`, `docs/ACCEPTANCE-PLAN.md`, `docs/OPERATIONS.md`, `docs/THREAT-MODEL.md`, and `docs/SCHEDULER-ADMISSION.md`.
- The README has six balanced fenced-code markers.
- `git ls-tree -r --name-only HEAD scripts/harness` lists only `install-claude-code.sh`, `install-hermes.sh`, and `install-opencode.sh`. The README layout still names six foreign agents and says there is one installer per agent; codex, aider, goose, and pi-agent installers are absent. Existing row CF-010 covers this.
- The README still says `Three environment variables and one harness`, but its block exports only `CRIER_URL` and `BUNKER_SERVER`; the provider credential is file-based in `~/.hermes/.env`. Existing row CF-015 covers this.
- The README still reports Hermes as **works** with `32 s install`, `/api/status 200`, and `133 JSON-RPC methods`, but the fresh `install-hermes.sh --check` failed and no repository-local rerunnable artifact proves those historical figures. Existing row CF-013 covers this.
- The README Quick start still invokes `bunker-server-install.sh --check` before it explains `BUNKER_SERVER`; the exact clean-environment command fails before checking. Existing row CF-009 covers this.
- The published README no longer contains the former unsupported `--agent` invocation; CF-014 is not a live finding at the published tip. The current `project-node.sh --check --project <project>` command is supported and fails closed with measured `NODE: FAIL (3)` in the clean HOME.
- `AGENTS.md` still cites nonexistent board row `CF-108`; existing row CF-011 covers it. `docs/traceability-doctrine.md` is still absent; existing row CF-012 covers it. These are not duplicate findings.

No new canonical board row was filed. The measured defects are already covered by CF-009, CF-010, CF-011, CF-012, CF-013, and CF-015. No README wording was changed by this lane.

Unverified surfaces: no release binary, live bunker node, crier dispatch, node gateway round trip, or rendered public README was available. Those are evidence limits, not additional failure claims.

ch:trace row=CF-009 spec=README.md#quick-start wave=code-factory-readme-2026-10-30-01-33-38#readme test=tests/selftest.sh::selftest doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-01-33-38.md witness=none:placeholder-infrastructure-and-local-checkout-only verdict=none:open-finding commit=none:unmerged-audit memory=/project/code-factory/readme-audit-2026-10-30
ch:trace row=CF-010 spec=README.md#layout wave=code-factory-readme-2026-10-30-01-33-38#readme test=tests/selftest.sh::selftest doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-01-33-38.md witness=path@origin:scripts/harness verdict=none:open-finding commit=none:unmerged-audit memory=/project/code-factory/readme-audit-2026-10-30
ch:trace row=CF-011 spec=AGENTS.md#rules wave=code-factory-readme-2026-10-30-01-33-38#readme test=tests/selftest.sh::selftest doc=AGENTS.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-01-33-38.md witness=path@origin:AGENTS.md verdict=none:open-finding commit=none:unmerged-audit memory=/project/code-factory/readme-audit-2026-10-30
ch:trace row=CF-012 spec=none:no-doctrine-exists wave=code-factory-readme-2026-10-30-01-33-38#readme test=tests/selftest.sh::selftest doc=docs/traceability-doctrine.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-01-33-38.md witness=none:no-doctrine-file-exists verdict=none:open-finding commit=none:unmerged-audit memory=/project/code-factory/readme-audit-2026-10-30
ch:trace row=CF-013 spec=README.md#status wave=code-factory-readme-2026-10-30-01-33-38#readme test=scripts/harness/install-hermes.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-01-33-38.md witness=none:no-live-bunker-or-gateway-available verdict=none:open-finding commit=none:unmerged-audit memory=/project/code-factory/readme-audit-2026-10-30
ch:trace row=CF-015 spec=README.md#running-it-against-your-own-infrastructure wave=code-factory-readme-2026-10-30-01-33-38#readme test=tests/selftest.sh::selftest doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-01-33-38.md witness=path@origin:README.md verdict=none:open-finding commit=none:unmerged-audit memory=/project/code-factory/readme-audit-2026-10-30

STATUS: PASS
TIER: T4 -- executed the published README commands in a clean worktree with a fresh HOME, read local artifacts back, and compared the published origin tree
EVIDENCE: docs/audits/code-factory-readme-2026-10-30-01-33-38.md
