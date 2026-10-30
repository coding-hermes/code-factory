# code-factory README audit — 2026-10-30 16:04:30

Target: fresh published-tip checkout at `origin/main` SHA `3ebf9f06ce7baa03fc62844f7aecd71aac4c17b2`. The scheduler stand-in was not a repository and was not used as the audit target. The canonical checkout had unrelated dirty board/audit state, so this audit used a detached worktree at the published tip.

## Commands tested

The complete safe README command matrix was executed from a fresh shallow clone with an isolated HOME and PATH. Exact producer output is preserved in `docs/audits/code-factory-readme-2026-10-30-16-04-30.probe.txt`.

- `scripts/bunker-server-install.sh --check` with `BUNKER_SERVER` and `CRIER_URL` unset: exit 1 before checks; `BUNKER_SERVER: set BUNKER_SERVER to your bunker server name`.
- `scripts/project-node.sh --check --project <project>` was tested with the safe substitution `demo`: exit 1 after running the node checks; it reported `NODE: FAIL (3)` because `CRIER_URL` was unset, the Hermes gateway was absent, the provider key and Crier identity were absent, and the fresh HOME had no repo. The README command shape is supported, but it is not a successful cold start.
- The infrastructure block with `BUNKER_SERVER=your-bunker-server`, `CRIER_URL=http://crier.example:8767`, `scripts/bunker-server-install.sh --check`: exit 1, `RESULT: FAIL (2)` because the placeholder server was not configured/reachable.
- `scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes`: exit 1, `FAIL spawn — bunker: server "your-bunker-server" not found in config`; no node was created.
- `bash tests/selftest.sh`: exit 0, `SELFTEST: PASS`, `16/16 rows parse`.
- `gitreins guard` on the clean clone: exit 2, `DEGRADED PASS`; lint and tests were skipped because no files were staged. This is not a full gate pass.
- `scripts/project-node.sh --apply --harness aider` without `--project`: exit 2, `--project is required`; the README only states the adapter refusal in prose, so the exact refusal needs the required project argument before it can be probed.
- `scripts/harness/install-hermes.sh --check`: exit 1, `HERMES: FAIL (2)` because port 10800 and the provider key were absent.

## Reader-facing surface checks

- All five README relative links exist at the published tip: `docs/BOARD.md`, `docs/ACCEPTANCE-PLAN.md`, `docs/OPERATIONS.md`, `docs/THREAT-MODEL.md`, and `docs/SCHEDULER-ADMISSION.md`.
- The README has six fenced blocks, an even fence count, and ends outside a code block.
- The shipped harness inventory is three files: `install-claude-code.sh`, `install-hermes.sh`, and `install-opencode.sh`; the README still names six foreign-agent installers.
- The repository has 11 prompt files, not one `prompts/<lane>.md` file per table lane. The README's lane loader sentence is also contradictory: `load_lane_config.py` owns the core config entries while `add_family_lanes.py` owns the added family rows. Existing row CF-030 covers this lane-section finding.
- `docs/traceability-doctrine.md` is absent at the published tip; existing row CF-012 covers the repository-contract gap.
- Existing published findings CF-009, CF-010, CF-011, CF-012, CF-013, CF-015, and CF-030 were re-measured or remain the canonical owners. No new finding was filed in this sweep.

## Findings and overpromising wording

- CF-009 remains live: Quick start step 1 requires `BUNKER_SERVER` before the README introduces it.
- CF-010 remains live: Layout claims six foreign-agent installers while only three installer files are shipped.
- CF-011 remains live: AGENTS.md cites the unresolved board id CF-108.
- CF-012 remains live: the repository-local traceability doctrine is absent.
- CF-013 remains live/unverified: the status table's Hermes row still presents historical `32 s`, `/api/status 200`, and `133 JSON-RPC methods` as `works`, but the current adapter check fails and no live bunker/gateway boundary was available.
- CF-015 remains live: infrastructure prose says “Three environment variables” while the block exports only `CRIER_URL` and `BUNKER_SERVER`.
- CF-030 remains the canonical lane-family finding; this sweep confirms the published README still contains the prompt-path, loader, and count mismatch.

The live bunker, Crier dispatch, node gateway round trip, release asset, and anonymous rendered README boundaries were unavailable. The clean-clone GitReins result was degraded because the clone had no staged files; it was not treated as product evidence.

ch:trace row=CF-009 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-16-04-30#readme test=scripts/bunker-server-install.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-16-04-30.probe.txt witness=none:placeholder-infrastructure-and-fresh-clone-only verdict=none:open-finding commit=none:open memory=none:exact-key-not-found
ch:trace row=CF-010 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-16-04-30#readme test=git-ls-tree::harness-installer-inventory doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-16-04-30.probe.txt witness=path@origin:scripts/harness verdict=none:open-finding commit=none:open memory=none:exact-key-not-found
ch:trace row=CF-011 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-16-04-30#readme test=jq::board-id-census doc=AGENTS.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-16-04-30.probe.txt witness=path@origin:AGENTS.md verdict=none:open-finding commit=none:open memory=none:exact-key-not-found
ch:trace row=CF-012 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-16-04-30#readme test=test::docs/traceability-doctrine.md doc=docs/traceability-doctrine.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-16-04-30.probe.txt witness=none:repository-contract-file-absent verdict=none:open-finding commit=none:open memory=none:exact-key-not-found
ch:trace row=CF-013 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-16-04-30#readme test=scripts/harness/install-hermes.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-16-04-30.probe.txt witness=none:no-live-bunker-or-gateway-available verdict=none:open-finding commit=none:open memory=none:exact-key-not-found
ch:trace row=CF-015 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-16-04-30#readme test=grep::environment-variable-inventory doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-16-04-30.probe.txt witness=path@origin:README.md verdict=none:open-finding commit=none:open memory=none:exact-key-not-found
ch:trace row=CF-030 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-16-04-30#readme test=git-ls-tree::lane-prompt-and-loader-census doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-16-04-30.probe.txt witness=path@origin:prompts verdict=none:open-finding commit=none:open memory=none:exact-key-not-found

STATUS: PARTIAL
TIER: T4 -- executed the documented README commands in a fresh clone and read back the clone files and exact probe transcript; live bunker, Crier, gateway, release, and anonymous-render boundaries were unavailable
EVIDENCE: docs/audits/code-factory-readme-2026-10-30-16-04-30.probe.txt
