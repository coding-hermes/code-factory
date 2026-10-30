# code-factory README audit evidence

Publication boundary: `origin/main` at `cc0a1e473d63065875242ceabcc15b1f218857e3`, resolved with `git ls-remote --symref origin HEAD` and fetched before probing. The scheduler-designated workdir was a stand-in without repository files; probes ran from a fresh archive of the published tip with an isolated HOME. No README or source file was edited.

## Commands tested

- `env HOME=<scratch> bash scripts/bunker-server-install.sh --check` -> rc 1; `BUNKER_SERVER` is required before the checker runs (`set BUNKER_SERVER to your bunker server name`). This reproduces the existing CF-009 finding.
- `env HOME=<scratch> BUNKER_SERVER=your-bunker-server bash scripts/bunker-server-install.sh --check` -> rc 1; `RESULT: FAIL (2)` for missing bunker config and unreachable placeholder server. This is the documented-block configuration failure, not a new syntax finding.
- `env HOME=<scratch> bash scripts/project-node.sh --check --project demo` -> rc 1; `NODE: FAIL (3)` for unset `CRIER_URL`, missing crier identity, and missing repo state. The published README uses this accepted command; the old unsupported `--agent` form is absent from the published tip, so CF-014 does not reproduce.
- `env HOME=<scratch> bash tests/selftest.sh` -> rc 0; `SELFTEST: PASS`, `16/16 rows parse`.
- `env HOME=<scratch> bash -n scripts/*.sh scripts/harness/*.sh tests/selftest.sh` -> rc 0.
- `env HOME=<scratch> CRIER_URL=http://crier.example:8767 BUNKER_SERVER=your-bunker-server bash scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes` -> rc 1; `spawn — bunker: server "your-bunker-server" not found in config`. The placeholder path reaches argument parsing and fails at missing user infrastructure; no node was created.
- `test -e docs/traceability-doctrine.md` -> rc 1; the repository-local doctrine path is absent. This reproduces CF-012.
- Harness inventory from the published tree -> only `install-claude-code.sh`, `install-hermes.sh`, and `install-opencode.sh`; codex, aider, goose, and pi-agent installers are absent. This reproduces CF-010.
- Board census from the published tree -> ids end at `CF-008` for the original CF family; `CF-108` is absent. This reproduces the AGENTS.md dead reference in CF-011.
- Lane prompt inventory -> 11 prompt files exist; source shows `load_lane_config.py` handles 6 lane rows and `add_family_lanes.py` handles the added family rows. This reproduces CF-030's prompt/loader wording drift.

## Findings and re-triage

The safe README command set produced no new finding class. Existing open rows CF-009, CF-010, CF-011, CF-012, CF-013, CF-015, and CF-030 cover the live published-tip defects. CF-014's old unsupported `--agent` premise is not present in the published README and should be re-triaged by its owner; this audit does not close the board row.

CF-009: the quick-start control-host check still fails before qualification when `BUNKER_SERVER` is unset.
ch:trace row=CF-009 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-18-28-33#readme test=scripts/bunker-server-install.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-18-28-33.md witness=none:placeholder-infrastructure-and-fresh-archive-only verdict=none:open-finding commit=none:open memory=/project/code-factory/readme-audit-2026-10-30-14-54-06

CF-010: the layout still names four harness installers that are not shipped.
ch:trace row=CF-010 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-18-28-33#readme test=git-ls-tree::harness-inventory doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-18-28-33.md witness=path@origin:scripts/harness verdict=none:open-finding commit=none:open memory=/project/code-factory/readme-audit-2026-10-30-14-54-06

CF-011: AGENTS.md still points at absent row CF-108.
ch:trace row=CF-011 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-18-28-33#readme test=jq::board-id-census doc=AGENTS.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-18-28-33.md witness=path@origin:AGENTS.md verdict=none:open-finding commit=none:open memory=/project/code-factory/readme-audit-2026-10-30-14-54-06

CF-012: `docs/traceability-doctrine.md` is still absent.
ch:trace row=CF-012 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-18-28-33#readme test=test::docs-traceability-doctrine-exists doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-18-28-33.md witness=none:published-tip-path-absent verdict=none:open-finding commit=none:open memory=/project/code-factory/readme-audit-2026-10-30-14-54-06

CF-013: the status table still presents historical Hermes figures as `works` without a repository-local rerunnable artifact or live witness.
ch:trace row=CF-013 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-18-28-33#readme test=scripts/harness/install-hermes.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-18-28-33.md witness=none:no-live-bunker-or-gateway-available verdict=none:open-finding commit=none:open memory=/project/code-factory/readme-audit-2026-10-30-14-54-06

CF-014: the prior `--agent` quick-start defect does not reproduce at this published tip; the row remains open for owner re-triage rather than being closed here.
ch:trace row=CF-014 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-18-28-33#readme test=scripts/project-node.sh::check-project-demo doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-18-28-33.md witness=path@origin:README.md verdict=none:open-finding commit=none:open memory=/project/code-factory/readme-audit-2026-10-30-14-54-06

CF-015: the own-infrastructure section still says three environment variables while documenting two; provider credentials are file-based.
ch:trace row=CF-015 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-18-28-33#readme test=grep::environment-variable-inventory doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-18-28-33.md witness=path@origin:README.md verdict=none:open-finding commit=none:open memory=/project/code-factory/readme-audit-2026-10-30-14-54-06

CF-030: the lanes section still misstates prompt naming, loader ownership, and the scheduler project count; the source inventory confirms the mismatch.
ch:trace row=CF-030 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-18-28-33#readme test=git-ls-tree::lane-prompt-and-loader-census doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-18-28-33.md witness=path@origin:prompts verdict=none:open-finding commit=none:open memory=/project/code-factory/readme-audit-2026-10-30-14-54-06

## Unverified scope

No release asset, anonymous rendered README, live bunker deployment, Crier dispatch, node gateway round trip, scheduler dispatch, or external deployment boundary was exercised. The checker and board source runs are T4 local/archive evidence, not live production proof. The canonical checkout had pre-existing shared dirty board changes and was 22 commits behind and 28 commits ahead of `origin/main`; this audit did not stage, rewrite, commit, or push those foreign changes.

STATUS: PARTIAL
TIER: T4 -- executed the published README's safe commands from a fresh archive and read the script outputs and repository files back
EVIDENCE: docs/audits/code-factory-readme-2026-10-30-18-28-33.md
