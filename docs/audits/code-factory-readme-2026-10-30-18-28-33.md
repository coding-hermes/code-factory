# code-factory README audit — 2026-10-30 18:28 tick

Publication boundary: `origin/main` at `cc0a1e473d63065875242ceabcc15b1f218857e3`
(`git rev-parse origin/main` after `git fetch`). The scheduler-designated workdir
(`~/.hermes/stand-in/readme/code-factory`) holds tick artifacts only and no repository files, so
every probe ran from a fresh `git archive origin/main` extraction in a scratch directory with an
isolated `HOME`.

Scope: follow every command in `README.md` literally, record where it fails, then correct the
README so its status table and quick start stop promising what the code does not do. No script,
spec or board row was changed.

## Commands tested (published tip, before the README fix)

| command | rc | result |
|---|---|---|
| `scripts/bunker-server-install.sh --check` (no `BUNKER_SERVER`) | 1 | `scripts/bunker-server-install.sh: line 14: BUNKER_SERVER: set BUNKER_SERVER to your bunker server name` — dies before any check |
| `./scripts/project-node.sh --check --agent demo` (quick start step 2, literal shape) | 2 | `unknown arg: --agent` — the flag does not exist in `project-node.sh` |
| `scripts/project-node.sh --project crier --agent demo --repo git@example.invalid:org/repo.git --harness hermes` (quick start step 3) | 2 | `unknown arg: --agent` — never reaches repo or infrastructure validation |
| `./scripts/project-node.sh --check --project demo` (supported shape) | 1 | `NODE: FAIL (3)` — `crier_url` unset, `repo` absent, manifest written only when every layer passes. The checker runs and names each missing value |
| `BUNKER_SERVER=your-bunker-server scripts/bunker-server-install.sh --check` | 1 | `RESULT: FAIL (2)` — missing bunker config and unreachable placeholder server; the checker runs |
| `BUNKER_SERVER=your-bunker-server scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes` | 1 | `FAIL  spawn — bunker: server "your-bunker-server" not found in config`; argument parsing works, user infrastructure is absent |
| `scripts/harness/install-hermes.sh --check` | 1 | `HERMES: FAIL (2)` — `FAIL port — nothing on :10800`, `FAIL inference_key — no provider key`. `PASS version` names the measured version string |
| `bash tests/selftest.sh` | 0 | `SELFTEST: PASS` including `16/16 rows parse` |
| `bash -n scripts/*.sh scripts/harness/*.sh tests/selftest.sh` | 0 | clean |

Repository facts re-measured at the same tip:

- `scripts/harness/` contains exactly `install-claude-code.sh`, `install-hermes.sh`,
  `install-opencode.sh`.
- `scripts/node-create.sh` exists and is the control-host entry point; the README's Layout section
  does not list it even though its own quick start calls it.
- `test -e docs/traceability-doctrine.md` -> rc 1.
- board census: 16 rows, ids `CF-001`…`CF-015` plus `CF-030`; `CF-108` (cited by `AGENTS.md`) is
  absent.
- environment variables referenced by the scripts: `BUNKER_SERVER`, `CRIER_URL` only.
- `prompts/` holds 11 role files; `load_lane_config.py` configures 6 core lanes and
  `add_family_lanes.py` 8 family lanes (6 + 8 = the 14 lanes the scheduler reports enabled), and
  all three QA lanes load `qa.md`. The README's "`prompts/<lane>.md`" claim is false for the QA
  lanes.

## Findings

Existing rows already own every defect class observed; no new canonical row was filed.

- **CF-009** — quick start step 1 fails before checking when `BUNKER_SERVER` is unset. Fixed in
  the README by exporting the variable in the command.
- **CF-010** — Layout promised six harness installers, three shipped. Fixed: the shipped three are
  named and the rest are marked documented-only (work item `CF-006`).
- **CF-011** — `AGENTS.md` cites absent row `CF-108`. Still open; `AGENTS.md` is the owner's
  working agreement and this lane does not edit it.
- **CF-012** — no `docs/traceability-doctrine.md`. Still open; creating a repo contract is a
  design decision, not a README edit.
- **CF-013** — status table presented historical live figures as `works` with no re-runnable
  command. Fixed: each row now names the command that can contradict it, and the live-node figures
  are labelled as an observation with the re-check command beside them.
- **CF-014** — quick start used unsupported `project-node.sh --agent`. Fixed: the quick start now
  uses `--project` for the node-side check and `scripts/node-create.sh` for creation.
- **CF-015** — "Three environment variables" while two exist. Fixed: two variables, plus the
  file-based inference credential named explicitly.
- **CF-030** — lanes section mis-stated prompt naming and loader ownership. Fixed: prompts are role
  files, three QA lanes share `qa.md`, and both loader scripts are named with their split.
- **CF-031** (new) — the GitReins guard cannot pass a documentation-only commit: the lint gate
  skips with `no staged files` because its scope is Python-only, Tier 1 becomes `DEGRADED PASS`,
  and `guards.allow_skips: false` then refuses the commit. Measured on this very change: secrets
  clean, `tests (full)` PASS, `git log -1` unchanged after the attempt. This is a gate defect, not a
  README defect, and it blocks every docs and board-only commit in the repo.

Correction of a published claim: an earlier audit event for this same sweep (board event 16,
published with `b5f40c0`) recorded that "CF-014's old unsupported `--agent` premise remains absent
from the published README". Measurement refutes it — quick-start steps 2 and 3 pass `--agent <id>`
and `project-node.sh` rejects it with `unknown arg: --agent` (rc 2) at the very tip that event
names. This artifact and its event supersede that sentence; the rest of the earlier event's
command set was re-measured here rather than inherited.

Rows are left `pending` on the board: the fix is now re-runnable, but closing a row on the same
tick that wrote it is self-grading. The verification recipe is the command table above, re-run
against the tip that carries this artifact.

## Unverified scope

No release asset, anonymous rendered README, live bunker deployment, Crier dispatch, node gateway
round trip, scheduler dispatch or external deployment boundary was exercised. The production
counts in the status table (`32 s install`, `/api/status` 200, 133 JSON-RPC methods) are a
historical observation of a live node and cannot be reproduced from this repository alone; the
README now says so and gives the re-check command.

## Traceability

ch:trace row=CF-009 spec=README.md#quick-start wave=code-factory-readme-2026-10-30-18-28-33#readme test=scripts/bunker-server-install.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-18-28-33.md witness=path@origin:README.md verdict=none:open-finding commit=none:open memory=none:exact-key-not-found
ch:trace row=CF-010 spec=README.md#layout wave=code-factory-readme-2026-10-30-18-28-33#readme test=git-ls-tree::scripts-harness-inventory doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-18-28-33.md witness=path@origin:scripts/harness verdict=none:open-finding commit=none:open memory=none:exact-key-not-found
ch:trace row=CF-011 spec=AGENTS.md#rules wave=code-factory-readme-2026-10-30-18-28-33#readme test=jq::board-id-census doc=AGENTS.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-18-28-33.md witness=path@origin:AGENTS.md verdict=none:open-finding commit=none:open memory=none:exact-key-not-found
ch:trace row=CF-012 spec=none:doctrine-path-absent wave=code-factory-readme-2026-10-30-18-28-33#readme test=test::docs-traceability-doctrine-exists doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-18-28-33.md witness=none:published-tip-path-absent verdict=none:open-finding commit=none:open memory=none:exact-key-not-found
ch:trace row=CF-013 spec=README.md#status wave=code-factory-readme-2026-10-30-18-28-33#readme test=scripts/harness/install-hermes.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-18-28-33.md witness=none:no-live-bunker-or-gateway-available verdict=none:open-finding commit=none:open memory=none:exact-key-not-found
ch:trace row=CF-014 spec=README.md#quick-start wave=code-factory-readme-2026-10-30-18-28-33#readme test=scripts/project-node.sh::check-project-demo doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-18-28-33.md witness=path@origin:README.md verdict=none:open-finding commit=none:open memory=none:exact-key-not-found
ch:trace row=CF-015 spec=README.md#running-it-against-your-own-infrastructure wave=code-factory-readme-2026-10-30-18-28-33#readme test=grep::environment-variable-inventory doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-18-28-33.md witness=path@origin:README.md verdict=none:open-finding commit=none:open memory=none:exact-key-not-found
ch:trace row=CF-030 spec=README.md#the-lanes wave=code-factory-readme-2026-10-30-18-28-33#readme test=source-inventory::lane-prompt-and-loader-census doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-18-28-33.md witness=path@origin:prompts verdict=none:open-finding commit=none:open memory=none:exact-key-not-found
ch:trace row=CF-031 spec=.gitreins/config.yaml#guards wave=code-factory-readme-2026-10-30-18-28-33#readme test=gitreins-guard::docs-only-commit doc=tests/selftest.sh prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-18-28-33.md witness=path@origin:.gitreins/config.yaml verdict=none:open-finding commit=none:open memory=none:exact-key-not-found

STATUS: PASS
TIER: T4 -- executed every README shell block from a fresh archive of origin/main, read each rc and output back, then re-ran the corrected blocks against the fixed tree
EVIDENCE: docs/audits/code-factory-readme-2026-10-30-18-28-33.md plus the probe outputs f1.out-f4.out under /home/kara/.hermes/cache/scratch/cf-readme-182833-fixed
