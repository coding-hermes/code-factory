# README lane — 2026-11-17T02:40-05:00 (tick `code-factory-readme-2026-11-17-02-40-53`)

Workdir `~/code-factory` (`$HOME` elided — see §2 on the S7 publish rule), tip
**2e732112c52ec0de47ad8f921ae19b09e44b36d7** (`origin/main`,
after an ff-only merge from `7c35513d`). Lane prompt: `prompts/readme.md`. Method: run every command
the README publishes, literally, and record where it fails.

## 1. What was run, and what it printed

| # | Documented command | Exit | Verdict |
|---|---|---|---|
| 1 | `scripts/bunker-server-install.sh --check` | 1 | **honest** — one row, `FAIL server_declared — BUNKER_SERVER unset`, exactly what README:38-40 promises for a host with no server |
| 2 | `./scripts/project-node.sh --check --project myproject` | 1 | **honest** — `NODE: FAIL (5)`, every row names its value; the `python` row names `HERMES_PYTHON_BIN=python3.12` as the README claims. Wall time **157.83 s** (see §4) |
| 3 | `scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes` | 1 | **honest** — `FAIL crier_url — CRIER_URL unset or empty — export CRIER_URL=…` (README:19 exports it first) |
| 4a | `scripts/bunker-provision.sh --config ~/.config/code-factory/cf.conf --check` | 1 | **honest** — `FAIL config — cannot read …` (that path is a copy the reader makes, per README:74) |
| 4b | same, against the shipped template | 1 | **contradicted the README** → fixed as CF-467 (§2) |
| 5 | `scripts/bunker-crier-connect.sh --agent cf-node --server "$BUNKER_SERVER" --url "$CRIER_URL" --project code-factory --check` | 2 | **honest but unlabelled** — `--server is required (the agent's bunker host)`; the provisioning block never says `BUNKER_SERVER`/`CRIER_URL` must be exported first, only the Quick start does |
| 6 | `scripts/bunker-provision.sh --config … --destroy` (no `--yes`) | 2 | **honest** — `refusing to destroy without --yes (would remove agent <agent-id> on <bunker-server>)` |
| 7a | `scripts/harness/install-hermes.sh --check` (default `python3`, 3.14.9) | 1 | **honest** — exactly one gate row, `FAIL python`, as README:189-193 states |
| 7b | `HERMES_PYTHON_BIN=python3.12 scripts/harness/install-hermes.sh --check` | 1 | **honest** — five gate rows (`python` PASS, `binary` FAIL host-provided, `version` FAIL `0.22.5+3032.g3f87b28 != pin 0.19.0`, `port` FAIL, `inference_key` PASS), matching the README's "five when a binary is found" |
| 8 | the `## The lanes` census recipe, extracted verbatim from README:282-319 | 0 | **honest** — 11 rows, 0.81 s, all pagination guards satisfied |
| 9 | `scripts/boardctl` with nothing on `PATH` | 0 | `FAIL boardctl: coding-hermes boardctl executable not found on PATH` — the documented fail-closed row, but **the exit status is 0**, not nonzero (row not yet filed; see §5) |
| 10 | every layout path README:135-171 names | — | all 13 named files/specs exist (`docs/DESIGN.md`, `PRD-code-factory.md`, `OPERATIONS.md`, `BOARD.md`, `MVP-PLAN.md`, `ACCEPTANCE-PLAN.md`, `specs/{NODE,ENVELOPE,HARNESS}.md`, `config/{bunker.example.conf,node.env.example}`, `scripts/boardctl`, `AGENTS.md`) |

## 2. CF-467 — the `--check` transcript described a template that no longer exists

Measured at the tip, verbatim, `bash scripts/bunker-provision.sh --config config/bunker.example.conf --check`
(exit 1):

```
  PASS  config — bunker.example.conf — 53 lines, KEY=VALUE only
  FAIL  inputs — not readable: GITHUB_TOKEN_FILE(~/.config/code-factory/github.token) CRIER_AGENT_KEY_FILE(~/.config/code-factory/<project>/agent.key) S3_ENV_FILE(~/.config/code-factory/s3.env)
bunker-provision --check — project=code-factory agent=<agent-id> server=<bunker-server>
  ..    resolved repo=https://github.com/coding-hermes/code-factory.git ref=main harness=hermes namespaces=code-factory,coder (primary code-factory) ttl=30d crier=http://<control-host>:8767 duckbrain=http://<control-host>:3000
  FAIL  github_auth — GITHUB_TOKEN_FILE ~/.config/code-factory/github.token is unreadable
  PASS  bunker_cli — ~/.local/bin/bunker
  FAIL  server — <bunker-server> not listed by 'bunker list'
  FAIL  agent — <agent-id> absent — run --apply to create it
```

- Quoted count before the fix: `25 lines`. `wc -l config/bunker.example.conf` = **53**.
- Two rows the old block omitted entirely: `FAIL inputs …` (before the banner) and `FAIL github_auth …`.
- The old banner read `agent=cf-node server=bunker-node-01`; the shipped template carries the
  placeholders `agent=<agent-id> server=<bunker-server>`, so the old block had been recorded against
  an *edited* copy while the sentence above it said "against the template".

Fix: README's block is now that run, and the prose says which two detail paths are elided to `~`
(the S7 publish rule forbids an absolute host-home path in a published page —
`docs/handbook/chapters/M6-documentation.md:300-301`).

**AC proof** (re-runnable):

```
$ grep -o 'bunker.example.conf — [0-9]* lines' README.md
bunker.example.conf — 53 lines
$ wc -l config/bunker.example.conf
53 config/bunker.example.conf
```

Row sequence, README block (left) vs the captured run (right), `diff -y` exit 0 — all eight rows
present, same order, same verdicts:

```
PASS config                       PASS config
FAIL inputs                       FAIL inputs
bunker-provision --check          bunker-provision --check
.. resolved                       .. resolved
FAIL github_auth                  FAIL github_auth
PASS bunker_cli                   PASS bunker_cli
FAIL server                       FAIL server
FAIL agent                        FAIL agent
```

## 3. CF-468 — the prompt-file count was stale, and the count was ungated

`ls prompts/*.md | wc -l` = **12** (docs, dogfood, duckbrain, foreman, perf, pm, qa, readme, releng,
review, sync, **unblock**). The README stated **eleven** twice (README:271 and README:345 before this
commit). The twelfth file is real product surface — `prompts/unblock.md` (`e07d031d`, *"prompts: the
unblocking procedure — classify before you receipt"*), which lane prompts reference directly.

`tests/selftest.sh:626-643` only asserts that every `prompts/*.md` the README *names* exists; it never
counts the directory, which is why the number drifted with nothing to catch it.

**AC proof**:

```
$ ls prompts/*.md | wc -l
12
$ grep -n 'twelve files for fourteen lanes' README.md
282:lane files: `prompts/` ships twelve files for fourteen lanes, and every QA-job lane (the three QA
```

The second site (README:356) now states the count *with its measuring command* rather than asserting
that a 2026-10-30 audit covered a number it did not.

## 4. Wording that promised more than the code does — measured, not fixed

- **Quick start step 2 costs 157.83 s** on this control host (`/usr/bin/time`, cwd `~/code-factory`).
  The README presents it as step 2 of a "Quick start" and gives no duration. CF-387 measured 48 s and
  owns the cause (layer 00's footprint walk over `$HOME/.hermes`); this run is a 3.3x further
  measurement of the same row, not a new defect.
- **Step 2 writes to the control host's `$HOME`.** After the run, `$HOME/.node` exists; the README's
  Quick start says nothing about it. CF-472 owns it.
- **The provisioning block assumes exports it does not name.** `bunker-crier-connect.sh … --server
  "$BUNKER_SERVER"` fails with `--server is required` (exit 2) unless the reader carried the exports
  down from the Quick start. The README's own "Running it against your own infrastructure" section
  repeats the two exports; the provisioning section does not.
- **`prompts/` is not the only count with no gate.** `## The lanes` says "Fourteen scheduler projects",
  and the two loaders do define 14 (`scripts/load_lane_config.py:23-28`, six core;
  `scripts/add_family_lanes.py:107-119`, eight family). The *live* namespace at this tip holds 11:
  `code-factory-docs, -dogfood, -foreman, -ops, -perf, -pm, -qa(enabled=false), -readme, -releng,
  -review, -sync`. Nine of the table's fourteen are live; five are not (`code-factory` itself,
  `-duckbrain`, `-docs-qa`, `-readme-qa`, `-releng-qa`); and two live rows are in no table row
  (`-foreman`, `-ops`). `code-factory-qa` and `code-factory-ops` also carry `parent=` empty while the
  README says 13 satellites are nested. The README already disclaims exactly this ("A live scheduler
  can differ in both directions … Read the state, do not infer it"), so the table is honest about its
  own scope; only the dated *snapshot* paragraph needed the reading it already carries.

## 5. Residue found and disposed of (not this lane's work, not committed)

The checkout arrived with five unstaged paths — `docs/handbook/{OUTLINE.md, chapters/M3-repository.md,
chapters/M6-documentation.md, appendices/units/36-scripts-verify-node-sh.md}` and
`tests/test_lane_target.py` — whose content *reverted* the landed CF-470/Cf-050 publication gate and
re-published two private IPv4 literals (`192.168.123.66:10800`, `192.168.1.20`) on a **public** repo.

Attribution: all five files carried mtimes inside one 3.2 ms window (`2026-11-16 17:17:13.8225…
13.826`), and each file's sha256 was **exactly** a historical pre-fix blob:

| path | matches blob at |
|---|---|
| `docs/handbook/chapters/M6-documentation.md` | `d0e6acfd` (spine-grades-its-own-tree fix) |
| `tests/test_lane_target.py` | `cb0f2217` (F13 release manifest) |
| `docs/handbook/appendices/units/36-scripts-verify-node-sh.md` | `014ddca5` (CF-050 publish gate) |

No process had a cwd in the checkout (`ownership.py` → `unowned-changes`, `lock: null`; the
`live_writer_census.sh` pass printed an empty foreign-session set and no live `git commit`, guard,
judge or `task complete` child). A sequential same-second rewrite of five tracked files to five
different historical blobs is a **red-control generator writing pre-fix material into the live tree
instead of a fixture directory** — the "a gate that writes the tree it grades" class
(`references/gate-hermeticity.md`). Disposition: `git diff` preserved to
`<scratch>/unowned-prefix-residue.patch` (sha256 `e2aa5f980d8ab7754981d43ab6469e2a51b244a17be30268577c733227bab4f6`,
138 lines), then `git checkout --` on the five paths. Nothing was committed: publishing it would have
removed a leak gate and republished a private address. **The mechanism is unfiled** — see §6.

## 6. Open items this tick did not close

1. **The red-control generator that rewrites the live tree** (§5). No row names it. It will recur on
   any tick that runs that gate, and the next lane may commit the revert instead of reverting it.
2. **`scripts/boardctl` exits 0 on its documented fail-closed path** (§1 #9): it prints
   `FAIL boardctl: … not found on PATH` and returns 0, so a caller that checks the status is told the
   board command succeeded.
3. **The provisioning block never names its two required exports** (§4).
4. CF-387 (step-2 cost) now measures 157.83 s, not 48 s.
5. CF-472 (`$HOME/.node` written by step 2) reproduced.

ch:trace row=CF-467 spec=README.md#provisioning-a-node-from-a-config-file wave=none:serial test=none:doc-only doc=README.md prompt=~/.hermes/skills/coding-hermes/coding-hermes-foreman-code-factory/SKILL.md evidence=docs/audits/code-factory-readme-2026-11-17-02-40-53.md witness=cmd:bash-scripts/bunker-provision.sh--check-exit-1/53-lines==wc-l verdict=none:open-finding commit=none:self-referential-hash memory=none:not-written

ch:trace row=CF-468 spec=README.md#the-lanes wave=none:serial test=none:doc-only doc=README.md prompt=~/.hermes/skills/coding-hermes/coding-hermes-foreman-code-factory/SKILL.md evidence=docs/audits/code-factory-readme-2026-11-17-02-40-53.md witness=cmd:ls-prompts/*.md|wc-l==12 verdict=none:open-finding commit=none:self-referential-hash memory=none:not-written
