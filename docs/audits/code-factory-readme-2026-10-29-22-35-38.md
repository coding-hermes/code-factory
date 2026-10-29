# code-factory README audit — 2026-10-29 22:35:38

Target: published `origin/main` at `5cf79f6900a4ff37ecd64cbc518c18306eb03e13`.
The audit used a fresh `git archive origin/main` tree under `/var/tmp`, with a fresh HOME for the local probes. The README itself was not edited.

## Commands tested

The README's Quick start was followed in order. The `<project>` placeholder was safely replaced with `demo`; provisioning was not attempted because the README says production creation is blocked and its infrastructure values are placeholders.

- `env -u BUNKER_SERVER bash scripts/bunker-server-install.sh --check` -> exit 1 before checks: `scripts/bunker-server-install.sh: line 14: BUNKER_SERVER: set BUNKER_SERVER to your bunker server name`.
- `env -u CRIER_URL bash scripts/project-node.sh --check --project demo` -> exit 1; the checker ran and reported `NODE: FAIL (3)` (`CRIER_URL` unset, Hermes port 10800 empty, and no crier identity/repo).
- `bash tests/selftest.sh` -> exit 0, `SELFTEST: PASS` (14/14 board rows parsed; the published tree's selftest also covered the board entrypoint).
- `BUNKER_SERVER=your-bunker-server bash scripts/bunker-server-install.sh --check` -> exit 1, `RESULT: FAIL (2)`; the placeholder server was not declared/reachable in the fresh HOME.
- `scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes` was not run: it provisions a bunker node, and the README supplies placeholder infrastructure/repository values. This is recorded as an unverified side-effecting path, not as a pass or failure.

## Published README claims checked against source

The published README's referenced docs exist at the published tip: `docs/BOARD.md`, `docs/ACCEPTANCE-PLAN.md`, `docs/OPERATIONS.md`, `docs/THREAT-MODEL.md`, and `docs/SCHEDULER-ADMISSION.md`. The code-factory scheduler inventory returned 14 projects total and 13 satellites for the local scheduler database; the README's lane count matches that measured inventory.

### Finding CF-015 — README says three environment variables, but names only two and the scripts expose two

Location: `README.md:73-74`.

The text says: `Three environment variables and one harness are all it assumes:`. The following block exports only `CRIER_URL` and `BUNKER_SERVER`. Source inspection found those two environment reads in the relevant scripts; the Hermes provider credential is read from `~/.hermes/.env`, not a third environment variable. `docs/OPERATIONS.md` also describes `BUNKER_SERVER` for the control host and `CRIER_URL` for the node, with the provider key configured out of band in the file.

Fix: say `Two environment variables and one harness...`, or enumerate the third variable if a real third prerequisite exists. Keep the provider-key file requirement explicit without calling it an environment variable.

ch:trace row=CF-015 spec=README.md#running-it-against-your-own-infrastructure wave=code-factory-readme-2026-10-29-22-35-38#readme test=tests/selftest.sh::selftest doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-29-22-35-38.md witness=path@origin:README.md verdict=none:open-finding commit=396f13387a050643898e37f06a6403e02954b07c memory=none:not-written

## Existing findings re-measured, not re-filed

- CF-009 remains covered by the existing board row: the published Quick start still fails immediately when `BUNKER_SERVER` is unset, although the later operations docs explain the prerequisite.
- CF-010 remains covered: `scripts/harness/` has only `install-claude-code.sh`, `install-hermes.sh`, and `install-opencode.sh`, while the README names six foreign agents.
- CF-011 remains covered: `AGENTS.md` still cites nonexistent `CF-108`; the published board contains `CF-001` through `CF-014` and no `CF-108`.
- CF-012 remains covered: `docs/traceability-doctrine.md` is absent at the published tip.
- CF-013 remains covered: the README's Hermes status row still states a historical 32-second install, `/api/status` 200, and 133 JSON-RPC methods without a repo-local rerunnable evidence artifact; the fresh adapter check reported `HERMES: FAIL (2)` in the clean HOME because the port and provider key were absent.
- CF-014 is no longer live at the published tip: the Quick start now uses `scripts/project-node.sh --check --project <project>` and explicitly blocks production creation. It was not re-filed.

No fresh public release binary, live bunker node, crier dispatch, gateway round trip, or rendered public README was available to probe. Those are evidence limits, not additional failure claims.

ch:trace row=CF-015 spec=README.md#running-it-against-your-own-infrastructure wave=code-factory-readme-2026-10-29-22-35-38#readme test=tests/selftest.sh::selftest doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-29-22-35-38.md witness=none:no-live-bunker-or-release-boundary-available verdict=none:open-finding commit=396f13387a050643898e37f06a6403e02954b07c memory=none:not-written

STATUS: PASS
TIER: T4 -- executed the published README commands in a fresh archive/HOME, ran selftest, and compared docs/scripts/board against the published tip
EVIDENCE: docs/audits/code-factory-readme-2026-10-29-22-35-38.md
