# code-factory README audit supplement — lane section and independent command re-run

Tick `code-factory-readme-2026-10-30-14-54-06`, second pass. Publication boundary: `origin/main`
at `b433e0d6f714615b361b3a02848cf250c5a79133`.

The scheduler-designated lane directory is a stand-in without repository files, so every probe ran
from a fresh `git archive` of that published tip (49 files) in a scratch directory with an isolated
temporary `HOME`. No README or source file was edited.

## Why this supplement exists

The first pass of this tick (commit `8473503`, branch `readme-audit-20261030-145406`) re-measured the
README's commands but was never merged into `origin/main`, and it did not examine the README's
"The lanes" section. This supplement re-runs the commands independently and adds the lane census.
It does not restate the first pass's figures; every number below was produced by this pass.

## Commands re-run

| # | command | exit | measured output |
|---|---|---|---|
| 1 | `env -i PATH=… HOME=<isolated> bash scripts/bunker-server-install.sh --check` | 1 | `scripts/bunker-server-install.sh: line 14: BUNKER_SERVER: set BUNKER_SERVER to your bunker server name` |
| 2 | `env -i PATH=… HOME=<isolated> bash scripts/project-node.sh --check --project demo` | 1 | `HERMES: FAIL (3)` then `NODE: FAIL (3)`; rows: `crier_url`, `harness hermes` (binary absent, port 10800 empty, no inference key), `crier_identity`, `repo` |
| 3 | `env -i PATH=… HOME=<isolated> bash tests/selftest.sh` | 0 | `SELFTEST: PASS`, board census `15/15 rows parse` |
| 4 | `env -i … BUNKER_SERVER=your-bunker-server CRIER_URL=http://crier.example:8767 bash scripts/bunker-server-install.sh --check` | 1 | `RESULT: FAIL (2)` — placeholder server not configured/reachable |
| 5 | `env -i … BUNKER_SERVER=your-bunker-server CRIER_URL=http://crier.example:8767 bash scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes` | 1 | `FAIL  spawn — bunker: server "your-bunker-server" not found in config`; no agent retained |
| 6 | `env -i … bash scripts/project-node.sh --apply --harness aider --project demo` | 1 | `[20] FAIL  harness:aider — no adapter at scripts/harness/install-aider.sh`; `NODE: FAIL (4)` |
| 7 | `bash -n scripts/*.sh scripts/harness/*.sh tests/*.sh` | 0 | every script parses |
| 8 | `env -i PATH=… HOME=<isolated> bash scripts/boardctl validate` | 127 | `FAIL boardctl: coding-hermes boardctl executable not found on PATH` |

Reading of the table:

- Rows 1, 2, 4 and 5 reproduce existing rows `CF-009`, `CF-014` (the published quick start now uses
  the supported `--check --project` shape; the failure is the infrastructure boundary, not the
  argument parser), `CF-009` again for the placeholder export block, and `CF-015`/`CF-014` context.
  No new row is filed for them.
- Row 3 is the repository's own gate and it is green from a clean archive.
- Row 6 **confirms a README claim rather than contradicting one**: `README.md:85-86` says an
  unmeasured adapter refuses `--apply` rather than pretending, and the checker fails closed at the
  harness layer before any install is attempted. This is the one behavioural promise in the status
  block that a stranger can reproduce today.
- Row 8 is a documented dependency, not a defect: `docs/BOARD.md:24-26` states the board executable
  must be installed and on `PATH` and that absence fails closed with exit 127. The README points at
  that document, so the wording is honest.

## The lanes section is not reproducible from the repository

`README.md:104-131` describes the lane family. Three measured contradictions, none of which any
committed document or test currently resolves:

Census A — prompt paths. `git ls-tree -r --name-only origin/main -- prompts` lists exactly 11 files:
`docs.md dogfood.md duckbrain.md foreman.md perf.md pm.md qa.md readme.md releng.md review.md
sync.md`. The table above it names 14 lanes. **No prompt file is named after its lane**: the root
lane `code-factory` uses `prompts/foreman.md`, `code-factory-docs` uses `prompts/docs.md`, and the
three QA lanes share `prompts/qa.md`. The sentence "each lane's prompt lives in `prompts/<lane>.md`"
therefore resolves for 0 of 14 lanes as written.

Census B — loader attribution. The same sentence says every lane's prompt "is loaded with
`scripts/load_lane_config.py`". That script's `CFG` dict holds 6 lanes: `code-factory`,
`code-factory-qa`, `code-factory-pm`, `code-factory-dogfood`, `code-factory-sync`,
`code-factory-duckbrain`. The other 8 — `docs`, `docs-qa`, `readme`, `readme-qa`, `releng`,
`releng-qa`, `perf`, `review` — are loaded by the `LANES` table in `scripts/add_family_lanes.py`,
which the preceding sentence (`README.md:129-130`) already says. The section contradicts itself one
line apart.

Census C — project count. `README.md:106` says "Fourteen scheduler projects make up this repo's lane
family". The scheduler inventory answers:

```
select count(*), sum(enabled), sum(parent='code-factory')
  from projects where name like 'code-factory%';
rows=19 | enabled=14 | children=18
```

The five extra rows are disabled lanes `code-factory-duckbrain-{dogfood,pm,qa,releng,sync}`. The
closing hedge ("verify the live namespace, admission mode, and workdir with the scheduler's project
inventory before relying on a current deployment count") tells a reader to check, then gives them a
count the check will contradict. Either the split is stated (14 enabled / 5 disabled) or the
disabled rows are removed.

Canonical finding: `CF-030`.

## Already-owned findings re-checked, not re-filed

- `CF-009` — quick-start step 1 exits 1 before checking because `BUNKER_SERVER` is required by
  `scripts/bunker-server-install.sh:14` and only documented later. Live (row 1 above).
- `CF-010` — layout names one installer per foreign agent, tree ships three. Live. **Scope note for
  the fixer:** `AGENTS.md:86-89` makes a stronger version of the same claim ("The other adapters
  ship a real `--check` … their `--apply` refuses") for four adapters that have no file at all.
  Whatever commit closes CF-010 should correct `AGENTS.md:86-89` in the same change, or a second
  false statement survives the fix.
- `CF-011` — `AGENTS.md:41` cites row `CF-108`. Still live (the board ends at `CF-015` at this tip).
- `CF-012` — `docs/traceability-doctrine.md` absent from the published tree. Still live.
- `CF-013` — status rows "works" (32 s install, `/api/status` 200, 133 JSON-RPC methods) still carry
  no rerunnable pointer; this pass had no bunker or gateway boundary, so they remain unverified, not
  disproven.
- `CF-015` — "Three environment variables" while the block exports two. Still live.
- `CF-016` — check for duplicates: branch `readme-audit-20261030-0321` carries `CF-016` for the three
  missing QA prompt paths. It is **unmerged**, and it does not cover the root/docs prompt naming, the
  loader attribution, or the 19-row inventory. `CF-030` extends it; if `CF-016` lands first, CF-030's
  criteria subsume it and the foreman may close one with the other's commit.

## Evidence boundary of this lane

The newest audit committed at `origin/main` is `docs/audits/code-factory-readme-2026-10-30-01-33-38.md`.
Later sweeps live only on unmerged branches (`…-0530-11`, `…-134004`, and this tick's `…-145406`),
and a DuckBrain record at `/project/code-factory/readme-audit-2026-10-30-0530-11` cites
`docs/audits/code-factory-readme-2026-10-30-05-30-11.md`, which the published tip does not contain.
The citation was true on a branch and false on the published tip. This merge is the first of those
sweeps to reach `main`; the others still need the same treatment or an explicit withdrawal.

## Unverified boundaries

No release asset, live bunker node, crier dispatch, node gateway round trip, or anonymously rendered
public README was exercised. Those are evidence limits, not failure claims.

ch:trace row=CF-030 spec=README.md#the-lanes wave=code-factory-readme-2026-10-30-14-54-06#readme test=git-ls-tree::lane-prompt-and-loader-census doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-14-54-06-lanes.md witness=path@origin:prompts verdict=none:open-finding commit=none:readme-defects-unfixed memory=/project/code-factory/readme-audit-2026-10-30-145406-lanes

STATUS: PASS
TIER: T4 -- executed every safe README command from a fresh archive of the published tip with an isolated HOME, read the outputs back, and censused the published tree and the live scheduler inventory
EVIDENCE: docs/audits/code-factory-readme-2026-10-30-14-54-06-lanes.md; bash tests/selftest.sh (SELFTEST: PASS, 15/15); scripts/bunker-server-install.sh --check; scripts/project-node.sh --check --project demo; scripts/project-node.sh --apply --harness aider; scripts/node-create.sh placeholders; git ls-tree origin/main -- prompts scripts; scheduler inventory query (rows=19 enabled=14 children=18)
