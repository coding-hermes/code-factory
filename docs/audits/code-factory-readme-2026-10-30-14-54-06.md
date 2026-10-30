# code-factory README audit — 2026-10-30 14:54:06

Target: canonical code-factory checkout (resolved by `git rev-parse --show-toplevel`), published `origin/main` at `b433e0d6f714615b361b3a02848cf250c5a79133`. This audit did not edit README.md. The scheduler stand-in was not treated as the repository.

## Commands tested

The exact README fenced commands were enumerated and executed from a fresh shallow clone with a fresh HOME where safe. The decisive producer output is preserved in the committed companion artifact `docs/audits/code-factory-readme-2026-10-30-14-54-06.probe.txt`; the durable audit preserves the stable command forms and relevant output.

- `scripts/bunker-server-install.sh --check` with `BUNKER_SERVER` unset: exit 1; `set BUNKER_SERVER to your bunker server name` before the checker ran.
- `./scripts/project-node.sh --check --project <project>` literally: shell exit 2; the angle-bracket placeholder is shell syntax, not a literal argument.
- `BUNKER_SERVER=your-bunker-server CRIER_URL=http://crier.example:8767 scripts/bunker-server-install.sh --check`: exit 1; `RESULT: FAIL (2)` because the placeholder server was not configured or reachable.
- `BUNKER_SERVER=your-bunker-server CRIER_URL=http://crier.example:8767 scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes`: exit 1; `bunker: server "your-bunker-server" not found in config`; no agent was created.
- `bash tests/selftest.sh`: exit 0; `SELFTEST: PASS`, with `15/15 rows parse` on the published clone.
- `gitreins guard` on the clean clone: exit 2; `DEGRADED PASS` with lint and tests skipped because no files were staged. This is not a product-gate pass.

## Surface checks

- Current README status and lane text were read from the canonical checkout and compared with `origin/main`.
- The README-referenced docs `docs/BOARD.md`, `docs/ACCEPTANCE-PLAN.md`, `docs/OPERATIONS.md`, `docs/THREAT-MODEL.md`, and `docs/SCHEDULER-ADMISSION.md` exist in the canonical current tree and published tree.
- The published harness inventory is three files: `install-claude-code.sh`, `install-hermes.sh`, and `install-opencode.sh`; the README still lists six foreign-agent installers.
- `docs/traceability-doctrine.md` is absent from the canonical checkout and `origin/main`.
- The published board rows CF-009, CF-010, CF-011, CF-012, CF-013, and CF-015 already own the measured README findings; this tick files no duplicate row. The local board contains concurrent/unpublished changes and was not staged or rewritten.
- The scheduler inventory query for `code-factory%` returned 14 enabled lanes in the local scheduler database, including the root and support/QA lanes. The README's lane table is therefore a local deployment claim, not a proof about every published installation.

## Findings and overpromising wording

No new canonical row was filed. Existing published findings remain live or unverified:

- CF-009: the first Quick start command requires `BUNKER_SERVER` before the README introduces it.
- CF-010: the layout promises installers for six foreign agents while only three installer files are shipped.
- CF-011: AGENTS.md cites the dead board id CF-108.
- CF-012: the repository-local traceability doctrine is absent.
- CF-013: the Hermes status row retains historical `32 s`, `/api/status 200`, and `133 JSON-RPC methods` without a current repository-rerunnable live artifact.
- CF-015: the infrastructure section says “Three environment variables” but documents only CRIER_URL and BUNKER_SERVER; the provider credential is file-based.

Additional command observations are not new rows: the literal placeholder `<project>` is not executable without substitution, and the clean-clone GitReins result is degraded because no files were staged. The documented live bunker, Crier dispatch, node gateway round trip, release asset, and anonymous rendered README boundaries were not available and are explicitly unverified.

ch:trace row=CF-009 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-14-54-06#readme test=scripts/bunker-server-install.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-14-54-06.md witness=none:placeholder-infrastructure-and-fresh-clone-only verdict=none:open-finding commit=none:open memory=none:exact-key-not-found
ch:trace row=CF-010 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-14-54-06#readme test=git-ls-tree::harness-installer-inventory doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-14-54-06.md witness=path@origin:scripts/harness verdict=none:open-finding commit=none:open memory=none:exact-key-not-found
ch:trace row=CF-011 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-14-54-06#readme test=jq::board-id-census doc=AGENTS.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-14-54-06.md witness=path@origin:AGENTS.md verdict=none:open-finding commit=none:open memory=none:exact-key-not-found
ch:trace row=CF-012 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-14-54-06#readme test=test::docs/traceability-doctrine.md doc=docs/traceability-doctrine.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-14-54-06.md witness=none:repository-contract-file-absent verdict=none:open-finding commit=none:open memory=none:exact-key-not-found
ch:trace row=CF-013 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-14-54-06#readme test=scripts/harness/install-hermes.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-14-54-06.md witness=none:no-live-bunker-or-gateway-available verdict=none:open-finding commit=none:open memory=none:exact-key-not-found
ch:trace row=CF-015 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-14-54-06#readme test=grep::environment-variable-inventory doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-14-54-06.md witness=path@origin:README.md verdict=none:open-finding commit=none:open memory=none:exact-key-not-found

STATUS: PARTIAL
TIER: T4 -- executed the documented README commands in a fresh clone and read back the clone files and exact probe transcript; live bunker, Crier, gateway, release, and anonymous-render boundaries were unavailable
EVIDENCE: docs/audits/code-factory-readme-2026-10-30-14-54-06.md; docs/audits/code-factory-readme-2026-10-30-14-54-06.probe.txt
