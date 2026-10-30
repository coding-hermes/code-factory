# code-factory README audit rerun — 2026-10-30 08:47:09

Target: fresh shallow clone of published `origin/main` at `b433e0d6f714615b361b3a02848cf250c5a79133`.
The probe used a fresh clone and fresh HOME. The README and board were not edited by this rerun.
The complete command transcript is in `/var/tmp/code-factory-readme-2026-10-30-08-47-09-rerun.out` during the probe; the exact decisive outputs are reproduced below.

## Commands tested

- `scripts/bunker-server-install.sh --check` with `BUNKER_SERVER` unset: exit 1; `scripts/bunker-server-install.sh: line 14: BUNKER_SERVER: set BUNKER_SERVER to your bunker server name`.
- `./scripts/project-node.sh --check --project <project>` literally: shell exit 2 before the project script, `syntax error near unexpected token newline`; angle-bracket placeholders require substitution and are not literal shell arguments.
- `bash tests/selftest.sh`: exit 0; `SELFTEST: PASS`; `15/15 rows parse`.
- `bash -n scripts/*.sh scripts/harness/*.sh tests/selftest.sh`: exit 0.
- The README infrastructure block with `BUNKER_SERVER=your-bunker-server` and `CRIER_URL=http://crier.example:8767`: bunker check exit 1 with `RESULT: FAIL (2)` because the placeholder server is not configured/reachable.
- `scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes` with the README placeholder variables: exit 1; `bunker: server "your-bunker-server" not found in config`; no agent was created.

## Static checks

- README fenced-code markers: 6, balanced.
- Linked docs exist: `docs/BOARD.md`, `docs/ACCEPTANCE-PLAN.md`, `docs/OPERATIONS.md`, `docs/THREAT-MODEL.md`, and `docs/SCHEDULER-ADMISSION.md`.
- Published harness installer inventory: `install-claude-code.sh`, `install-hermes.sh`, and `install-opencode.sh`; the README still describes six foreign-agent installers.
- `docs/traceability-doctrine.md` is absent from the published tree.
- `AGENTS.md` still contains the unresolved `CF-108` citation.
- The published README quick-start no longer contains the former unsupported `--agent` invocation; CF-014 is not reproduced on this tip.

## Findings and wording that overpromises

No new canonical row was filed. Existing published rows cover the measured defects: CF-009 (missing `BUNKER_SERVER` context), CF-010 (installer inventory overclaim), CF-011 (dead `CF-108` citation), CF-012 (missing repository doctrine), CF-013 (historical Hermes status figures presented as works without a repository-rerunnable live artifact), and CF-015 (two documented environment variables described as three). The local unpublished board also contains CF-027, which overlaps the clean-start/self-contained-path concern; it was not treated as published evidence or duplicated here.

The literal `<project>` quick-start line is not executable without replacing the placeholder. This is recorded as a command-boundary observation, not a new row, because the local unpublished CF-027 scope and the existing clean-start findings already own that remediation class.

Unverified: published release asset, rendered anonymous public README, live bunker node, Crier dispatch, node gateway round trip, and external deployment boundary.

ch:trace row=CF-009 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-08-47-09#readme test=scripts/bunker-server-install.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-08-47-09-rerun.md witness=none:placeholder-infrastructure-and-fresh-clone-only verdict=none:open-finding commit=8578236f937f22b60084f471e330de48647b9131 memory=none:exact-key-not-found
ch:trace row=CF-010 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-08-47-09#readme test=git-ls-tree::harness-installer-inventory doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-08-47-09-rerun.md witness=path@origin:scripts/harness verdict=none:open-finding commit=8578236f937f22b60084f471e330de48647b9131 memory=none:exact-key-not-found
ch:trace row=CF-011 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-08-47-09#readme test=jq::board-id-census doc=AGENTS.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-08-47-09-rerun.md witness=path@origin:AGENTS.md verdict=none:open-finding commit=8578236f937f22b60084f471e330de48647b9131 memory=none:exact-key-not-found
ch:trace row=CF-012 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-08-47-09#readme test=git-ls-tree::traceability-doctrine doc=docs/traceability-doctrine.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-08-47-09-rerun.md witness=none:repository-contract-file-absent verdict=none:open-finding commit=8578236f937f22b60084f471e330de48647b9131 memory=none:exact-key-not-found
ch:trace row=CF-013 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-08-47-09#readme test=scripts/harness/install-hermes.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-08-47-09-rerun.md witness=none:no-live-bunker-or-gateway-available verdict=none:open-finding commit=8578236f937f22b60084f471e330de48647b9131 memory=none:exact-key-not-found
ch:trace row=CF-015 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-08-47-09#readme test=grep::environment-variable-inventory doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-08-47-09-rerun.md witness=path@origin:README.md verdict=none:open-finding commit=8578236f937f22b60084f471e330de48647b9131 memory=none:exact-key-not-found

STATUS: PARTIAL
TIER: T4 -- executed the published README commands in a fresh clone and read the clone's files and exact probe output back; live bunker, Crier, gateway, release, and anonymous-render boundaries were unavailable
EVIDENCE: docs/audits/code-factory-readme-2026-10-30-08-47-09-rerun.md
