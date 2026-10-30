# code-factory README audit — 2026-10-30 08:47:09

Target: published `origin/main` at `b433e0d6f714615b361b3a02848cf250c5a79133`.
The scheduler stand-in is a board home under the home-repo; the product checkout is `/home/kara/code-factory`. The audit used a fresh detached clone of the published tip at `/var/tmp/code-factory-readme-20261030-0847-C9ZieR/repo`. The README was not changed or published by this audit.

## Commands tested

The exact README commands were run in the fresh clone with a fresh HOME. Placeholder provisioning was run only to its refusal boundary; no node was created and no credentials were supplied. Full command output is preserved in `docs/audits/code-factory-readme-2026-10-30-08-47-09.probe.txt`.

- `BUNKER_SERVER=your-bunker-server scripts/bunker-server-install.sh --check` -> exit 1, `RESULT: FAIL (2)`; the placeholder server had no fresh bunker config and was unreachable.
- `CRIER_URL=http://crier.example:8767 ./scripts/project-node.sh --check --project demo` -> exit 1, `NODE: FAIL (3)`; the checker reached its layers and reported the placeholder Crier endpoint unreachable, Hermes binary/port/provider key missing, crier identity missing, and the fresh node repo absent.
- `bash tests/selftest.sh` -> exit 0, `SELFTEST: PASS`; the published board census was `15/15` rows.
- `BUNKER_SERVER=your-bunker-server CRIER_URL=http://crier.example:8767 scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes` -> exit 1 at the safe boundary: `bunker: server "your-bunker-server" not found in config`; no agent was created.
- `bash -n scripts/*.sh scripts/harness/*.sh tests/selftest.sh` -> exit 0.

## Static checks

- All five README-linked operational docs (`docs/BOARD.md`, `docs/ACCEPTANCE-PLAN.md`, `docs/OPERATIONS.md`, `docs/THREAT-MODEL.md`, `docs/SCHEDULER-ADMISSION.md`) exist at the published tip.
- The README has six balanced fenced-code markers.
- The tracked harness installer inventory is exactly `install-claude-code.sh`, `install-hermes.sh`, and `install-opencode.sh`; the README still claims one installer for six foreign agents, so CF-010 remains live.
- The current Quick start uses the supported `project-node.sh --check --project <project>` form and does not contain the former unsupported `--agent` invocation.
- `docs/traceability-doctrine.md` is absent at the published tip; this remains covered by CF-012.
- `AGENTS.md` still cites `CF-108`, which is absent from the published board; this remains covered by CF-011.

## Findings and wording that still overpromises

No new canonical board row was filed. The current published board already owns every measured README defect:

- CF-009: Quick start step 1 requires `BUNKER_SERVER` before the README introduces it. The literal command fails before performing the advertised host check.
- CF-010: the README still overpromises one installer per six foreign agents, while only three installer scripts are shipped. The underlying CF-006 implementation work remains open.
- CF-011: `AGENTS.md` contains the dead `CF-108` citation.
- CF-012: repository-local `docs/traceability-doctrine.md` is absent.
- CF-013: the status table still presents the Hermes-in-bunker row as `works` with historical `32 s`, `/api/status 200`, and `133 JSON-RPC methods`, but this audit could not reproduce a live bunker/gateway boundary or find a current repository-local artifact for those figures. The wording is now qualified in the audit only; the README text remains unchanged.
- CF-014: no longer live; the former unsupported Quick start arguments are absent from the published README. It was not re-filed or closed by this audit because the board write is already dirty with concurrent changes and no independent closeout verdict was available.
- CF-015: the infrastructure section still says `Three environment variables and one harness` while documenting only `CRIER_URL` and `BUNKER_SERVER`; the provider credential is file-based rather than a third environment variable.

Unverified scope: no published release asset, rendered public README, live bunker node, crier dispatch, node gateway round trip, or external deployment boundary was available. Those are not reported as failures.

ch:trace row=CF-009 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-08-47-09#readme test=scripts/bunker-server-install.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-08-47-09.md witness=none:placeholder-infrastructure-and-local-clone-only verdict=none:open-finding commit=none:open memory=none:unresolved-namespace
ch:trace row=CF-010 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-08-47-09#readme test=find::harness-installer-inventory doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-08-47-09.md witness=path@origin:scripts/harness verdict=none:open-finding commit=none:open memory=none:unresolved-namespace
ch:trace row=CF-011 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-08-47-09#readme test=jq::board-id-census doc=AGENTS.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-08-47-09.md witness=path@origin:AGENTS.md verdict=none:open-finding commit=none:open memory=none:unresolved-namespace
ch:trace row=CF-012 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-08-47-09#readme test=git-ls-tree::traceability-doctrine doc=docs/traceability-doctrine.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-08-47-09.md witness=none:repository-contract-file-absent verdict=none:open-finding commit=none:open memory=none:unresolved-namespace
ch:trace row=CF-013 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-08-47-09#readme test=scripts/harness/install-hermes.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-08-47-09.md witness=none:no-live-bunker-or-gateway-available verdict=none:open-finding commit=none:open memory=none:unresolved-namespace
ch:trace row=CF-015 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-08-47-09#readme test=grep::environment-variable-inventory doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-08-47-09.md witness=path@origin:README.md verdict=none:open-finding commit=none:open memory=none:unresolved-namespace

STATUS: PARTIAL
TIER: T4 -- executed the published README commands in a fresh clone and read the clone's files and probe artifact back; live bunker, crier, gateway, and public-render boundaries were unavailable
EVIDENCE: docs/audits/code-factory-readme-2026-10-30-08-47-09.md; docs/audits/code-factory-readme-2026-10-30-08-47-09.probe.txt
