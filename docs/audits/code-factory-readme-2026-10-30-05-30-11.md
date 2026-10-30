# code-factory README audit — 2026-10-30 05:30:11

Target: published `origin/main` at `b433e0d6f714615b361b3a02848cf250c5a79133`.
Audit worktree: a clean detached worktree of the published tip before this audit. The README was not edited.
The scheduler-designated stand-in directory is not an independent checkout; the canonical repository was used.

## Commands tested

The README Quick start, infrastructure, harness, and repository-board paths were followed literally where safe. Placeholder provisioning stopped at its safe refusal boundary; no node was created and no live service was changed.

- `env -u BUNKER_SERVER bash scripts/bunker-server-install.sh --check` -> exit 1: `scripts/bunker-server-install.sh: line 14: BUNKER_SERVER: set BUNKER_SERVER to your bunker server name`.
- `env -u CRIER_URL bash scripts/project-node.sh --check --project demo` -> exit 1, `NODE: FAIL (3)`; it reported `CRIER_URL` unset, Hermes port `10800` empty, no crier identity, and no repo. The documented checker invocation is valid and reaches its layers.
- `bash tests/selftest.sh` -> exit 0, `SELFTEST: PASS`; the board check parsed `15/15` rows.
- `BUNKER_SERVER=your-bunker-server bash scripts/bunker-server-install.sh --check` -> exit 1, `RESULT: FAIL (2)`; the placeholder server was not declared or reachable in the local bunker config.
- `BUNKER_SERVER=your-bunker-server CRIER_URL=http://crier.example:8767 bash scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes` -> exit 1: `bunker: server "your-bunker-server" not found in config`; no node was created.
- `scripts/harness/install-claude-code.sh --check` -> exit 1, `CLAUDE-CODE: FAIL (1)`; binary absent.
- `scripts/harness/install-hermes.sh --check` -> exit 1, `HERMES: FAIL (1)`; the binary/version and provider-key checks passed, but port `10800` was empty.
- `scripts/harness/install-opencode.sh --check` -> exit 0, `OPENCODE: PASS`, with a warning that non-interactive mode could not be confirmed.
- `./scripts/boardctl --help` -> exit 0; the wrapper prints its usage and requires the external `boardctl` executable for real board operations.

## Findings and wording review

No new canonical board row was filed. Existing open rows cover every measured README defect found in this sweep:

- CF-009 covers the Quick start bunker check's unstated `BUNKER_SERVER` prerequisite; the exact clean invocation still aborts before checking.
- CF-010 covers the Layout claim that six foreign harness installers ship; the published tree contains only `install-claude-code.sh`, `install-hermes.sh`, and `install-opencode.sh`.
- CF-011 covers the dead `CF-108` citation in `AGENTS.md`; the published board IDs are CF-001 through CF-015 and do not include CF-108.
- CF-012 covers the missing `docs/traceability-doctrine.md`; `git ls-tree -r --name-only HEAD docs | grep -i trace` has no match.
- CF-013 covers the status-table Hermes **works** claim and its unreferenced historical figures; the fresh check still fails on empty port `10800`.
- CF-015 covers the sentence “Three environment variables” while the README names only `CRIER_URL` and `BUNKER_SERVER`; provider setup is file-based.
- CF-016 is absent from the published tip and was not re-filed: its underlying QA prompt-path premise is already recorded on an unpublished branch, so it remains explicitly unverified against the published board rather than duplicated.

The README's named documentation paths all exist at the published tip. The six fenced-code markers are balanced. The 14 lane rows match the README's stated lane count. No release binary, rendered public README, live bunker, crier dispatch, gateway round trip, or published release artifact was available; those surfaces remain unverified rather than being reported as failures.

## One recursive trace scan

The required published-tree recursive scan for every `ch:trace` marker was run as:
`grep -RIn --exclude-dir=.git 'ch:trace' .`
It found the existing marker in `README.md`; this audit artifact carries the complete markers below for the findings re-measured in this run.

ch:trace row=CF-009 spec=README.md#quick-start wave=code-factory-readme-2026-10-30-05-30-11#readme test=tests/selftest.sh::selftest doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-05-30-11.md witness=none:placeholder-infrastructure-and-local-checkout-only verdict=none:existing-finding-open commit=none:unfixed memory=none:duckbrain-exact-key-not-found
ch:trace row=CF-010 spec=README.md#layout wave=code-factory-readme-2026-10-30-05-30-11#readme test=tests/selftest.sh::selftest doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-05-30-11.md witness=path@origin:scripts/harness verdict=none:existing-finding-open commit=none:unfixed memory=none:duckbrain-exact-key-not-found
ch:trace row=CF-011 spec=AGENTS.md#rules wave=code-factory-readme-2026-10-30-05-30-11#readme test=tests/selftest.sh::selftest doc=AGENTS.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-05-30-11.md witness=path@origin:AGENTS.md verdict=none:existing-finding-open commit=none:unfixed memory=none:duckbrain-exact-key-not-found
ch:trace row=CF-012 spec=none:no-doctrine-exists wave=code-factory-readme-2026-10-30-05-30-11#readme test=tests/selftest.sh::selftest doc=docs/traceability-doctrine.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-05-30-11.md witness=none:no-doctrine-file-exists verdict=none:existing-finding-open commit=none:unfixed memory=none:duckbrain-exact-key-not-found
ch:trace row=CF-013 spec=README.md#status wave=code-factory-readme-2026-10-30-05-30-11#readme test=scripts/harness/install-hermes.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-05-30-11.md witness=none:no-live-bunker-or-gateway-available verdict=none:existing-finding-open commit=none:unfixed memory=none:duckbrain-exact-key-not-found
ch:trace row=CF-015 spec=README.md#running-it-against-your-own-infrastructure wave=code-factory-readme-2026-10-30-05-30-11#readme test=tests/selftest.sh::selftest doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-05-30-11.md witness=path@origin:README.md verdict=none:existing-finding-open commit=none:unfixed memory=none:duckbrain-exact-key-not-found

STATUS: PASS
TIER: T4 -- executed the published README commands in a clean published-tip worktree, ran the real repository selftest and board wrapper, and read the published files back
EVIDENCE: docs/audits/code-factory-readme-2026-10-30-05-30-11.md
