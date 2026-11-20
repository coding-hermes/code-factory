# Dogfood — the `bunker-provision --check` path, walked as a new user

Tick: `code-factory-dogfood-2026-11-20-14-19-33`
Tip walked: `a6ef8941` on `main` (`git@github.com:coding-hermes/code-factory.git`)
Evidence: `.coding-hermes/evidence/code-factory-dogfood-2026-11-20-14-19-33/`
Board read: `python3 scripts/board_read.py --next 10` printed `source: origin/main`, 597 rows at tick start (601 after the four rows below were appended). The working copy was clean of board edits at the time of the read; a sibling lane moved `main` from `a8291e68` to `a6ef8941` mid-tick and the tree was re-read afterwards.

This is the second walk of this surface. The first (`docs/dogfood/2026-11-17-dogfood-path.md`) checked that the documented commands exist and run. This one asks the question the first did not: **does each documented verdict correspond to a value the command actually measured?** The answer is yes for five of the seven rows in the README's block, no for one, and the credential list beside it is wrong in a way that will bite a first-time reader.

## 1. The path walked

Following `README.md:124-162` (`## Quick start`, the `--check` subsection) literally, from a clean checkout, on a host with the client installed and no node for this project:

```
env -u CRIER_URL -u BUNKER_SERVER HOME=$(mktemp -d) \
  bash scripts/bunker-provision.sh --config config/bunker.example.conf --check
```

A throwaway `HOME` was used for every run in this report, so the walk could not read, create or destroy anything in the real home. `find "$HOME" -mindepth 1 | wc -l` after the run printed `0`, which is the measurement behind the README's read-only claim.

Observed (`01-check-real-client.txt`, lines 11-18), exit 1:

```
  PASS  config — bunker.example.conf — 53 lines, KEY=VALUE only
  FAIL  inputs — not readable: GITHUB_TOKEN_FILE(...) DUCKBRAIN_TOKEN_FILE(...) CRIER_AGENT_KEY_FILE(...) CRIER_AUTH_TOKEN_FILE(...) S3_ENV_FILE(...)
bunker-provision --check — project=code-factory agent=<agent-id> server=<bunker-server>
  ..    resolved repo=https://github.com/coding-hermes/code-factory.git ref=main harness=hermes namespaces=code-factory,coder (primary code-factory) ttl=30d crier=http://<control-host>:8767 duckbrain=http://<control-host>:3000
  FAIL  github_auth — GITHUB_TOKEN_FILE ~/.config/code-factory/github.token is unreadable
  PASS  bunker_cli — ~/.local/bin/bunker
  FAIL  server — <bunker-server> not listed by 'bunker list'
  FAIL  agent — <agent-id> absent — run --apply to create it
```

Row names, verdicts and order match the README's quoted block exactly. `wc -l config/bunker.example.conf` is `53`, as the first row says. So the README's own head sentence (`README.md:143-145`) holds. Two statements next to that block do not.

## 2. Where the docs and the behaviour disagree

### F-1 — the credential lists are wrong, and the completeness sentence is false (filed CF-506, P3)

Three lists, three different answers:

| locus | says |
| --- | --- |
| `README.md:136-137` (prose) | `GITHUB_TOKEN_FILE`, `DUCKBRAIN_TOKEN_FILE`, `S3_ENV_FILE` |
| `README.md:152` (quoted `inputs` row) | `GITHUB_TOKEN_FILE`, `CRIER_AGENT_KEY_FILE`, `S3_ENV_FILE` |
| `config/bunker.example.conf:32-40` | all five, adding `CRIER_AGENT_KEY_FILE` and `CRIER_AUTH_TOKEN_FILE` |
| the run above | all five, in the order the template declares them |

`README.md:161-162` then says "the `inputs` row names every credential path the template expects" — true of the tool, false of the transcript printed twelve lines above it. A first-time reader who provisions what the prose lists creates three files and meets `FAIL inputs` naming two paths the README never mentions.

The quoted block carries no `inputs` divergence in row names or verdicts, so the README's promise ("row names, verdicts and order ... verbatim") is kept while the detail inside the row is stale. That is why this survived: the checkable part matches.

### F-2 — the agent row can pass on nothing at all (filed CF-507, P3)

With a recorder stub placed first on `PATH` — a client that logs its arguments, exits 0 and prints nothing — the same command printed:

```
  PASS  agent — cf-dogfood-sentinel-nonexistent exists ()
```

Empty parentheses, green row. The run then continued into fourteen further rows (`repo`, `node_json`, `auth_github`, `harness`, …) that the real client never reaches, because it stops at `FAIL agent ... absent`. In the same stub run, `server` correctly failed (`FAIL server — ... not listed by 'bunker list'`), so the two rows disagree about the same silent client: one measures emptiness, one does not.

Today's 0.2.x client exits nonzero for an absent agent, so a normal first run is not misled. The defect is structural: the row checks an exit status and calls it an existence measurement — the thing `AGENTS.md` forbids ("nothing is installed until `--check` names the measured value"). A wrapper, an older client, or a future client that returns an empty array with rc 0 turns the gate green and `--apply` then provisions against an agent it never saw.

### F-3 — the repo scheme is never validated (filed CF-508, P4)

`grep -nE 'git@|https|scheme|ssh' scripts/bunker-provision.sh` finds no validation of `REPO`. With `REPO=git@github.com:github/gitignore.git` the run printed `PASS config` and `.. resolved repo=git@github.com:github/gitignore.git`, and no row anywhere named the scheme (`02-refusals.txt:20-30`). The credential path beside it builds an HTTPS credential store from `GITHUB_TOKEN_FILE`. So an SSH remote passes the gate and authenticates on the node with a key the provisioner never installs; the error lands after the agent exists, which is the one place `--check` exists to keep it away from.

### F-4 — a board field update by one lane was discarded with no error (filed CF-509, P2)

Not a documentation defect; found because the lane rules require a dirty checkout to be attributed before it is trusted. Three readings, eight minutes apart (`00-state-and-collision.txt`, `04-lost-update.txt`):

1. 10:23 local — the working copy of `.coding-hermes/board/tasks.jsonl` carried `CF-474` with `defer_review_by: 2026-11-27` and `updated_at: 2026-11-20T15:23:24Z`; the committed row had `null` and `2026-11-17T11:21:08Z`. `scripts/ownership.py status` reported `state: unowned-changes`, `lock: null`.
2. 10:31 — tree clean; `HEAD` moved `a8291e68 → a6ef8941` by a sibling lane; the committed `CF-474` line was back to `null` **and** `updated_at` back to its old `2026-11-17T11:21:08Z` value.
3. `git log -S2026-11-27 -- .coding-hermes/board/tasks.jsonl` prints nothing, and `git stash list` holds only a 2026-11-11 autostash of handbook chapters. The edit is in no commit and parked in no stash.

The `updated_at` reverting to its old value is the discriminating detail: a deliberate clear would have bumped it, while a rewrite from a snapshot taken before 10:23 reproduces the whole line. The casualty was a defer, so that row silently became pickable again. `docs/BOARD.md:21-25` says concurrent-write handling lives in `boardctl`; on a shared checkout the observed behaviour is read-modify-write from whatever snapshot the writer loaded. This row does not accuse a lane — the losing writer is unattributed — it asks the write path to be unable to lose an update.

## 3. Failure paths, since no node host was available

`bunker list` exits 1 with no output on this control host and `~/.node` does not exist, so lane step 3's "create a node for a real public repo" could not be done as written. What was walked instead, all with `REPO` pointing at a real public repo (`github/gitignore`) so the config is realistic:

| path | command | result |
| --- | --- | --- |
| malformed config | `conf` with one non-`KEY=VALUE` line | `FAIL config — …/bad.conf:2 is not KEY=VALUE — refusing to run it`, exit 1, and the recorder stub saw **0** bunker invocations — the documented "refused before a single bunker call" is measured, not asserted |
| destructive guard | `--destroy` without `--yes`, sentinel agent/server names | `refusing to destroy without --yes (would remove agent … on …)`, exit 2 |
| absent client | `bunker_cli` row, `PATH` emptied of the client | `FAIL bunker_cli — no bunker client on PATH`, exit 1; the run stops there, so the node-state rows never print |
| closed auth gate | `github_auth` row, no token file | `FAIL github_auth — … is unreadable`, and the run continues to report `BUNKER: FAIL (14)` |

The malformed-config refusal is the strongest thing in this surface: the exact quoted line, the exit status, and a zero side-effect count all reproduce.

## 4. Rows filed

| id | P | what |
| --- | --- | --- |
| CF-506 | P3 | README credential lists name three files; template and live `--check` name five |
| CF-507 | P3 | `--check` prints PASS for the agent row when the client answers nothing |
| CF-508 | P4 | `REPO` scheme unvalidated: SSH passes `--check`, fails on the node |
| CF-509 | P2 | a board field update by one lane was discarded, with no commit, stash or lock |

Each row carries `FAILIF:` and `PROOF:` so its acceptance criterion can fail. Nothing in this report is filed for taste: every row quotes a command and the output that contradicts a document.

## 5. What a new user would have done next

1. Copy `config/bunker.example.conf`, fill in `PROJECT`, `AGENT`, `SERVER`, `REPO`.
2. Create the three credential files the prose names. → `FAIL inputs` names five, two of them unknown. **First stop.** The row is honest and the fix is obvious once seen; the README is what sent them there.
3. Run `--check` again. Now the useful failures appear: `github_auth`, `server`, `agent`.
4. `bunker` is installed but no server answers `list` → the user looks for how to get a node. The README forward-references `docs/OPERATIONS.md:38` once, at `README.md:57`, far above the Quick start, and lists the file again in the layout table at `README.md:180`; the Quick start section itself never says what to do when `server`/`agent` fail.
5. Nothing in the walked path tells them which `--check` rows are fatal versus informational: the run ends with `BUNKER: FAIL (14)` and two `WARN` rows, and the README's block stops before those rows exist.

## 6. What this tick did not do

- No node was created, and no `--apply` was run: no node host, and the lane forbids spending on one.
- The `..` status word in the README's block (`README.md:154`) has no legend that this walk could find in the README or the handbook chapters. Not filed: absence of a legend was not measured against the handbook text, only searched for.
- CI health is reported in the tick summary, not here.

## 7. The tick's own judge leg, measured

`gitreins task complete CF-DOGFOOD-2026-11-20` was run on the committed tree (`ce17783a`, a docs-only diff: one report, four board rows, five evidence files). Tier 1 ran and passed. Tier 2 did not produce a verdict:

```
gitreins.evaluator: WARNING: jev pre-screen unavailable (empty-bundle) — tier-2 judge runs at full authority
gitreins.evaluator: WARNING: Context budget 9070642/10000000 input tokens (largest single prompt 136321) — compacting (compaction #1)
```

The run was killed by the caller's 1500s wall clock (`rc=124`); no `.gitreins/history/2026-11-20/<run>/verdict.json` exists for this task. The binding rung was the **input token budget** — 9.07M of 10.0M consumed before any criterion was graded — not the 800-iteration cap and not the output budget. That is the CF-426 shape again (one-criterion docs row, nothing graded, the cap named in the log instead of a merits verdict), so it was recorded as evidence on CF-426 (board event 947) rather than filed as a fifth row: five rows for one defect is churn, and CF-426 is already P1 and pending.

Consequence for a reader of this report: the seven-row, five-verdict findings above rest on the commands and outputs reproduced in `.coding-hermes/evidence/code-factory-dogfood-2026-11-20-14-19-33/`, not on a judge verdict. Tier 1's gate log is `.gitreins/logs/guard-20261120T161426.699914Z.log`.
