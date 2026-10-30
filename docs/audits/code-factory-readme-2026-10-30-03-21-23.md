# code-factory README audit — 2026-10-30 03:21:23

Target: published `origin/main` at `b433e0d6f714615b361b3a02848cf250c5a79133`.

The audit ran from a detached worktree of the published tip. The README was not edited.
The prior audit's covered findings were re-measured; one new README drift finding was identified.

## Commands tested literally

- `scripts/bunker-server-install.sh --check` -> exit 1 before checks: `scripts/bunker-server-install.sh: line 14: BUNKER_SERVER: set BUNKER_SERVER to your bunker server name`.
- `scripts/project-node.sh --check --project demo` -> exit 1 with `NODE: FAIL (3)`. The supported command reaches the node checker and reports unset `CRIER_URL`, empty Hermes port `10800`, absent crier identity, and absent repo.
- With the README's placeholder exports, `CRIER_URL=http://crier.example:8767 BUNKER_SERVER=your-bunker-server scripts/bunker-server-install.sh --check` -> exit 1, `RESULT: FAIL (2)` because the placeholder server is absent and unreachable.
- With the same placeholder exports, `scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes` -> exit 1, `FAIL spawn — bunker: server "your-bunker-server" not found in config`; no node was retained.
- `bash tests/selftest.sh` -> exit 0, `SELFTEST: PASS`, including `15/15 rows parse`.
- `scripts/harness/install-hermes.sh --check` -> exit 1, `HERMES: FAIL (1)` because port `10800` is empty; binary, version, and provider-key checks passed on this host.
- `scripts/harness/install-opencode.sh --check` -> exit 0, `OPENCODE: PASS`, with a warning that non-interactive mode was not confirmed.
- `scripts/harness/install-claude-code.sh --check` -> exit 1, `CLAUDE-CODE: FAIL (1)` because the binary is absent.
- `./scripts/boardctl validate` -> exit 0, `RESULT: OK (1 warning(s))`; `15/15` rows carry canonical keys. The warning is the pre-existing headerless-board condition.
- `python3 scripts/load_lane_config.py --help` -> exit 0 and printed all fourteen configured lane names, including `code-factory-docs-qa`, `code-factory-readme-qa`, and `code-factory-releng-qa`.
- `python3 scripts/add_family_lanes.py --help` -> exit 0 and printed those three QA lanes as existing.

## Existing findings re-verified

ch:trace row=CF-009 spec=README.md#quick-start wave=code-factory-readme-2026-10-30-03-21-23#readme test=scripts/bunker-server-install.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-03-21-23.md witness=none:placeholder-infrastructure-only verdict=none:open-finding commit=fffcd492a5d02c4b060a324592fe92140b112b9b memory=/project/code-factory/readme-audit-2026-10-30

The first Quick start command still requires `BUNKER_SERVER` before the README explains the export. CF-009 remains live; no duplicate row was filed.

ch:trace row=CF-010 spec=specs/HARNESS.md#the-contract-every-adapter wave=code-factory-readme-2026-10-30-03-21-23#readme test=git-ls-tree::scripts/harness doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-03-21-23.md witness=path@origin:scripts/harness verdict=none:open-finding commit=fffcd492a5d02c4b060a324592fe92140b112b9b memory=/project/code-factory/readme-audit-2026-10-30

The layout still lists six foreign agents while the published tree contains only `install-claude-code.sh`, `install-hermes.sh`, and `install-opencode.sh`. CF-010 remains live; no duplicate row was filed.

ch:trace row=CF-011 spec=AGENTS.md#rules wave=code-factory-readme-2026-10-30-03-21-23#readme test=jq::board-id-census doc=AGENTS.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-03-21-23.md witness=path@origin:AGENTS.md verdict=none:open-finding commit=fffcd492a5d02c4b060a324592fe92140b112b9b memory=/project/code-factory/readme-audit-2026-10-30

`AGENTS.md` still cites `CF-108`, while the published board contains only `CF-001` through `CF-015`. CF-011 remains live; no duplicate row was filed.

ch:trace row=CF-012 spec=none:no-doctrine-exists wave=code-factory-readme-2026-10-30-03-21-23#readme test=test::docs-traceability-doctrine-exists doc=docs/traceability-doctrine.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-03-21-23.md witness=none:no-doctrine-file-exists verdict=none:open-finding commit=fffcd492a5d02c4b060a324592fe92140b112b9b memory=/project/code-factory/readme-audit-2026-10-30

`docs/traceability-doctrine.md` is still absent from the published tree. CF-012 remains live; no duplicate row was filed.

ch:trace row=CF-013 spec=README.md#status wave=code-factory-readme-2026-10-30-03-21-23#readme test=scripts/harness/install-hermes.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-03-21-23.md witness=none:no-live-bunker-or-gateway-available verdict=none:open-finding commit=fffcd492a5d02c4b060a324592fe92140b112b9b memory=/project/code-factory/readme-audit-2026-10-30

The Hermes status row still says **works** with historical `32 s`, `/api/status 200`, and `133 JSON-RPC methods`, while the local re-runnable check is `HERMES: FAIL (1)` and no repository-local artifact proves those figures. CF-013 remains live; no duplicate row was filed.

ch:trace row=CF-015 spec=README.md#running-it-against-your-own-infrastructure wave=code-factory-readme-2026-10-30-03-21-23#readme test=grep::environment-variable-block doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-03-21-23.md witness=path@origin:README.md verdict=none:open-finding commit=fffcd492a5d02c4b060a324592fe92140b112b9b memory=/project/code-factory/readme-audit-2026-10-30

The infrastructure section still says “Three environment variables” but exports only `CRIER_URL` and `BUNKER_SERVER`; the provider credential is file-based. CF-015 remains live; no duplicate row was filed.

## New finding

ch:trace row=CF-016 spec=README.md#the-lanes wave=code-factory-readme-2026-10-30-03-21-23#readme test=python3::lane-prompt-path-census doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-03-21-23.md witness=path@origin:prompts verdict=none:open-finding commit=fffcd492a5d02c4b060a324592fe92140b112b9b memory=/project/code-factory/readme-audit-2026-10-30

README.md:130-131 says each lane's prompt lives in `prompts/<lane>.md` and is loaded from that path. The lane table names fourteen lanes, but the published tree has no exact prompt files for `code-factory-docs-qa`, `code-factory-readme-qa`, or `code-factory-releng-qa`; the files `prompts/docs-qa.md`, `prompts/readme-qa.md`, and `prompts/releng-qa.md` are also absent. The implementation maps these QA lanes to the shared `prompts/qa.md` through `scripts/load_lane_config.py`, so the README's literal per-lane path claim is false even though the loader works. Fix the wording to say that lane names map to prompt basenames in the loader, and identify the shared QA prompt, or add the three exact prompt files if distinct prompts are intended.

Board filing: `scripts/boardctl create --id CF-016 ... --evidence-run-id code-factory-readme-2026-10-30-03-21-23` -> created task `CF-016`; `scripts/boardctl show CF-016 --events` -> one `task_created` event; post-write `scripts/boardctl validate` -> `RESULT: OK (1 warning(s))`, `16/16` rows canonical, and `wc -l .coding-hermes/board/tasks.jsonl` -> `16`.

## Wording that promises more than the checked path proves

- The Quick start presents a command that aborts before checking when `BUNKER_SERVER` is unset.
- The layout claims one harness installer per listed foreign agent, but four listed installer files are absent.
- The status table calls historical Hermes measurements “works” without a re-runnable repository-local evidence pointer.
- The infrastructure section says three environment variables while showing two exports and a file-based provider prerequisite.
- The lanes section says every lane has a `prompts/<lane>.md` file, but three QA lane paths do not exist; the loader instead shares `prompts/qa.md`.

## Unverified surfaces

No release binary, live bunker node, crier dispatch, node gateway round trip, or rendered public README was available. These are evidence limits, not claims that those surfaces fail.

STATUS: PASS
TIER: T4 -- executed the published README commands, validated the real project board, and compared the published README with the published source tree
EVIDENCE: docs/audits/code-factory-readme-2026-10-30-03-21-23.md
