# code-factory README audit — 2026-10-30 23:28

Publication boundary: `origin/main` resolved by `git ls-remote --symref origin HEAD` to
`e2fc9d735376746f70a017ce8f161eb3af1010d9`. The scheduler workdir
(`~/.hermes/stand-in/readme/code-factory`) holds tick artifacts only and no repository files, so
every probe ran from `git archive` of that published tip extracted into
`/home/kara/.hermes/cache/scratch/cf-readme-2328{,b}/src` with an isolated `HOME`. No source file
was edited by the probes; the two README corrections in this commit are described below.

Frozen transcript: `docs/audits/code-factory-readme-2026-10-30-23-28-00.probe.txt`
(sha256 `d7bfba4cf326f76dd806cada6ac833718616c2f854d9ab9df685bdca8890f671`), three runs:

- A — every README shell block and every status-table command, plus static censuses;
- B — the same blocks with the README's own exported placeholders, a real public clone read back
  off disk, and the evidence-pointer check;
- C — repository checks (`bash -n`, `make docs-check`, interpreter, pip log, `gitreins guard`).

One blemish, disclosed rather than hidden: the `=== gitreins guard (docs-only, unstaged) ===`
section at the end of run A prints `EXIT: 0` because that line reads `$?` of the `tail` in its
pipeline. The authoritative guard exits are the two in run C: `EXIT: 2` unstaged and `EXIT: 2`
with one staged `.md`. Do not quote run A's number.

## Commands tested

Quick start as written (README lines 17–30), with the block's own exports:

| Command | Result |
|---|---|
| `scripts/bunker-server-install.sh --check` | exit 1, `RESULT: FAIL (2)` — client present, `~/.config/bunker/config.yaml` missing, placeholder server unreachable |
| `./scripts/project-node.sh --check --project myproject` | exit 1, `NODE: FAIL (3)` — `crier_url` unset, nothing on `:10800`, `inference_key` missing, `crier_identity` absent, no repo |
| `scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes` | exit 1, `FAIL spawn — bunker: server "your-bunker-server" not found in config` |

The sentence at README:32–34 ("all three commands reach their checkers and fail with the missing
value named") **holds when the exports above are run first** — all three reach a checker and each
failure names the value. It does not hold if a reader drops the two `export` lines: commands 1 and 3
then die inside the script at `${BUNKER_SERVER:?}` (`line 14:` / `line 12:`) and print no checker
rows. The block does export them, so this is a reading hazard, not a false claim; no row filed.

Status-table commands (README lines 71–78), executed literally:

| Row | Command | Result |
|---|---|---|
| Hermes in a bunker + gateway | `scripts/harness/install-hermes.sh --check` | exit 1, `HERMES: FAIL (3)` — names pin 0.19.0, port 10800, and `FAIL inference_key`; it cannot corroborate the row's 32 s / `/api/status` / 133-method figures |
| Repo clone | `./scripts/project-node.sh --apply --project myproject --repo https://github.com/you/myrepo` | exit 1, `NODE: FAIL (3)`; `FAIL repo_clone — fatal: could not read Username for 'https://github.com' … (private repos need a deploy key)` |
| Node inference credential | `scripts/harness/install-hermes.sh --check` | exit 1, prints exactly `FAIL inference_key` as the row promises |
| crier identity | `./scripts/project-node.sh --check --project myproject` | exit 1, prints exactly `FAIL crier_identity` as the row promises |
| Scheduler → crier dispatch | (row says "nothing to run") | consistent: no command exists, the row says so |
| Round trip through the node gateway | (row says no command exists) | consistent |

Repo-clone row re-measured with a real public repository, not the placeholder:

- `./scripts/project-node.sh --apply --project myproject --repo https://github.com/github/gitignore`
  → `PASS repo_clone — <HOME>/repo @ 6bb5af7`.
- Read back **from the isolated HOME, not from the script's stdout**:
  `git -C <HOME>/repo rev-parse HEAD` → `6bb5af7a1b050e5add3a71b6e6365c93498822ac`, 319 tracked
  files, and `ls -d node_modules dist target .venv` → 0 hits. So "works for public https" is true at
  this tip and "No build step yet" is true of the artefact that landed on disk (CF-032 holds).

## Findings

### Filed this tick

**CF-036 — the Hermes adapter cannot install on a python 3.14 host, and says only "pip failed".**
`scripts/harness/install-hermes.sh:17,54` pins `PIP install hermes-agent==${PIN}` with
`PIN=0.19.0`. On this probe host `python3 --version` → `Python 3.14.9`, and the run's own log
(`/tmp/hermes-install.log`) says:

```
ERROR: Ignored the following versions that require a different python version: … 0.19.0 Requires-Python <3.14,>=3.11
ERROR: Could not find a version that satisfies the requirement hermes-agent==0.19.0 (from versions: 0.13.0, 0.14.0, 0.15.0, 0.15.1, 0.15.2)
ERROR: No matching distribution found for hermes-agent==0.19.0
```

The script's own header records the measurement that produced the pin: `python 3.12.3`. What a
stranger sees is `FAIL install — pip failed — /tmp/hermes-install.log` and nothing naming the
interpreter. That breaks README:32–34's promise for this leg, and it means the status row's "works
(32 s install)" is unreachable on a stock 3.14 host. Distinct from CF-013, which is about the
historical gateway figures; this one is about the install leg failing for a stated, fixable reason.

**CF-037 — `project-node.sh` prints `-> 000000` for an unreachable URL.**
`scripts/project-node.sh:54`:

```sh
c=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "$u" 2>/dev/null || echo 000)
[ "$c" = 200 ] && ok "reach:$u" "200" || bad "reach:$u" "-> $c"
```

`curl -w '%{http_code}'` already writes `000` when the connection fails, and the `|| echo 000`
appends a second one, so the captured value is `000000`. Measured verbatim in run B:
`FAIL reach:http://crier.example:8767/health — -> 000000`. This is the command the README's status
table cites, and a reader cannot tell an unreachable host from a formatting bug.

**CF-038 — the README's evidence pointer cites an audit that predates the text it vouches for.**
README:157 said `Evidence for the state of this README: docs/audits/code-factory-readme-2026-10-30-18-28-33.md`.
Counts against that file, from run B: `repo_clone` 0, `9402f6a` 0, `Prompt` 0, `eleven` 0 — it
cannot support the clone figure, the prompt column, or the eleven-files paragraph, all of which the
20-29-25 tick wrote. Fixed in this commit: README:157 now names the audit that measured the rows as
written and this sweep. Closed against that commit and the transcript below.

### Re-measured, still live, no duplicate filed

| Row | Evidence at this tip |
|---|---|
| CF-009 | step 1 with no exports still dies at `bunker-server-install.sh: line 14: BUNKER_SERVER: set BUNKER_SERVER …`; with the README's exports it reaches `RESULT: FAIL (2)` |
| CF-010 | `scripts/harness/` is exactly `install-claude-code.sh`, `install-hermes.sh`, `install-opencode.sh`; README:43–45 states that accurately |
| CF-011 | `AGENTS.md:41` cites `CF-108`; board census has 0 rows named CF-108 and its highest id is CF-035 |
| CF-012 | `git cat-file -e origin/main:docs/traceability-doctrine.md` → absent |
| CF-013 | row 73 still presents `32 s`, `/api/status` 200, `133 JSON-RPC methods` as the present state of a "works" row; the cited command measures a local adapter, not a gateway |
| CF-014 | `project-node.sh` accepts `--project/--harness/--repo/--ref`; the old `--agent` form is gone from the README |
| CF-015 | README:89 says two environment variables and `docs/OPERATIONS.md:24,38` agrees; the credential is described as a file |
| CF-030 | prompts census 11 files for 14 lanes; six CFG lanes in `load_lane_config.py`, eight family rows in `add_family_lanes.py`; README:146–155 states exactly that |
| CF-031 | run C: guard with one staged `.md` and no `.py` → `Tier 1: DEGRADED PASS (skips: lint=no staged files)`, `EXIT: 2` |
| CF-032 | 0 build/install invocations across `scripts/*.sh`; clone lands with no `node_modules|dist|target|.venv` |
| CF-033 | `grep -c 'repo https://…' README.md` → 0; the command now reaches a git-level outcome |
| CF-034 | the placeholder URL fails with `(private repos need a deploy key)` although the cause is a non-existent repo; `--ref` still defaults to `main` (line 31) and is undocumented in the README |
| CF-035 | layout now lists `scripts/boardctl`, the four lane scripts and `prompts/`; census of `scripts/` matches |

### Lanes census against the live scheduler

`select count(*), sum(enabled) from projects where name like 'code-factory%'` →
`19 | 14`; 18 rows carry `parent=code-factory`, the root row has none; the five disabled rows are
`code-factory-duckbrain-{dogfood,pm,qa,releng,sync}`. Admission is `tasks` on the root and `cooldown`
on every satellite, exactly as the README table states. README:123–127 and 154 are accurate at this
reading. Not a witness of deployment health — a read of the scheduler store on this host.

## Corrections made in this commit

1. README:73 (status table, Hermes row) now states that `--apply` needs python 3.11–3.13 because the
   `0.19.0` pin declares `Requires-Python >=3.11,<3.14`, and cites CF-036. Nothing else in the row
   changed; the historical figures keep their "observed on a live node in October 2026" framing and
   remain CF-013's.
2. README:157 now points at the audit that measured the rows as written plus this sweep (CF-038).

Nothing else in the README overpromises in a way that is not already on the board. The three
"missing"/"not yet" rows state what is missing and cite a command that fails as described.

## Reconciliation with branch-only work

An earlier phase of this same tick left two unpublished commits on a branch
(`47ed0e3 docs(readme): record 2026-10-30 23:28 published-tip audit`, `1eb8826 docs(readme): record
missing docs-check finding`) plus an uncommitted row `CF-036` titled "Repository has no runnable
docs-check target". That row is **not** carried forward: `grep -rn 'docs-check'` over `AGENTS.md`,
`docs/`, `specs/`, `README.md`, `tests/` returns 0 matches (run C), no Makefile exists at the tip,
and nothing in the repository contract promises a `make docs-check` target — the shipped docs check
is `tests/selftest.sh` check 7 ("every prompt file the README relies on exists"). Filing a row for a
target nobody promised would manufacture work. The branch-only artifacts are left in git history, not
rewritten; this commit's CF-036 is a different, measured defect, and the two must not be conflated.

## Not exercised

No live bunker node, Crier service, node gateway round trip, scheduler dispatch, release asset, or
anonymously rendered forge page. `--apply` was run only against a throwaway `HOME`; it wrote
`<HOME>/repo` and a `hermes-venv` that failed at pip, and no operator credential was read or
printed.

ch:trace row=CF-009 spec=README.md#quick-start wave=code-factory-readme-2026-10-30-23-28-00#readme test=scripts/bunker-server-install.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-23-28-00.probe.txt witness=none:placeholder-bunker-config-and-isolated-home verdict=none:open-finding commit=none:open memory=/project/code-factory/readme-audit-2026-10-30-23-28-00
ch:trace row=CF-011 spec=AGENTS.md#rules wave=code-factory-readme-2026-10-30-23-28-00#readme test=jq::cf-108-census doc=AGENTS.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-23-28-00.probe.txt witness=path@origin:AGENTS.md verdict=none:open-finding commit=none:open memory=/project/code-factory/readme-audit-2026-10-30-23-28-00
ch:trace row=CF-012 spec=none:repository-contract-absent wave=code-factory-readme-2026-10-30-23-28-00#readme test=git-cat-file::traceability-doctrine doc=docs/traceability-doctrine.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-23-28-00.probe.txt witness=none:published-tip-path-absent verdict=none:open-finding commit=none:open memory=/project/code-factory/readme-audit-2026-10-30-23-28-00
ch:trace row=CF-013 spec=README.md#status wave=code-factory-readme-2026-10-30-23-28-00#readme test=scripts/harness/install-hermes.sh::check doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-23-28-00.probe.txt witness=none:no-live-bunker-or-gateway-available verdict=none:open-finding commit=none:open memory=/project/code-factory/readme-audit-2026-10-30-23-28-00
ch:trace row=CF-030 spec=README.md#the-lanes wave=code-factory-readme-2026-10-30-23-28-00#readme test=git-ls-tree::lane-prompt-loader-census doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-23-28-00.probe.txt witness=path@origin:prompts verdict=none:open-finding commit=none:open memory=/project/code-factory/readme-audit-2026-10-30-23-28-00
ch:trace row=CF-031 spec=.gitreins/config.yaml#guards wave=code-factory-readme-2026-10-30-23-28-00#readme test=gitreins::guard-staged-md-no-py doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-23-28-00.probe.txt witness=path@origin:.gitreins/config.yaml verdict=none:open-finding commit=none:open memory=/project/code-factory/readme-audit-2026-10-30-23-28-00
ch:trace row=CF-032 spec=specs/NODE.md#layers wave=code-factory-readme-2026-10-30-23-28-00#readme test=grep::node-build-invocations doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-23-28-00.probe.txt witness=path@origin:scripts/project-node.sh verdict=none:open-finding commit=none:open memory=/project/code-factory/readme-audit-2026-10-30-23-28-00
ch:trace row=CF-034 spec=README.md#status wave=code-factory-readme-2026-10-30-23-28-00#readme test=scripts/project-node.sh::clone-hint doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-23-28-00.probe.txt witness=none:no-real-branch-mismatch-repo-in-probe verdict=none:open-finding commit=none:open memory=/project/code-factory/readme-audit-2026-10-30-23-28-00
ch:trace row=CF-036 spec=scripts/harness/install-hermes.sh#pin wave=code-factory-readme-2026-10-30-23-28-00#readme test=scripts/harness/install-hermes.sh::apply-python-314 doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-23-28-00.probe.txt witness=none:no-3-14-capable-release-of-the-pin verdict=none:open-finding commit=none:open memory=/project/code-factory/readme-audit-2026-10-30-23-28-00
ch:trace row=CF-037 spec=scripts/project-node.sh#preflight-reach wave=code-factory-readme-2026-10-30-23-28-00#readme test=scripts/project-node.sh::reach-unreachable doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-23-28-00.probe.txt witness=none:probe-ran-in-isolated-home verdict=none:open-finding commit=none:open memory=/project/code-factory/readme-audit-2026-10-30-23-28-00

ch:trace row=CF-038 spec=README.md#the-lanes wave=code-factory-readme-2026-10-30-23-28-00#readme test=grep::evidence-pointer-census doc=README.md prompt=prompts/readme.md evidence=docs/audits/code-factory-readme-2026-10-30-23-28-00.probe.txt witness=path@origin:README.md verdict=none:author-closed-pending-readme-qa commit=415b59e598e2762d8a4b4a16f62889f3528c289f memory=/project/code-factory/readme-audit-2026-10-30-23-28-00
STATUS: PASS
TIER: T4 — every documented command executed from a fresh archive of the published tip, the public clone read back off disk rather than from the script's own output, and the lane table compared with the live scheduler store; no live bunker, gateway or Crier boundary was available
EVIDENCE: docs/audits/code-factory-readme-2026-10-30-23-28-00.probe.txt (sha256 d7bfba4cf326f76dd806cada6ac833718616c2f854d9ab9df685bdca8890f671)
