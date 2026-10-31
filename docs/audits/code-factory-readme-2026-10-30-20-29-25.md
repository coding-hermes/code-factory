# code-factory README audit — 2026-10-30 20:29

Frozen transcript. Do not edit after filing: board rows cite this path as their evidence artifact.

Publication boundary: the audited text is `README.md` at origin/main
`56244a6415328d50a06c3300c75cd19e0b584d30`. Every command below was executed from a fresh
`git archive` of that tip with an isolated `HOME`, except the two post-fix runs, which were
executed from a copy of the edited worktree (`readme-audit-20261030-2029`). No secret, endpoint or
personal datum appears in this file.

## 1. Quick start, run top to bottom as written

Environment: `CRIER_URL=http://crier.example:8767`, `BUNKER_SERVER=your-bunker-server` (the two
exports the README now places before the commands), isolated `HOME`, no bunker config.

`scripts/bunker-server-install.sh --check`
```
bunker server: your-bunker-server
  PASS  bunker_client — /home/kara/.local/bin/bunker bunker 0.2.0
  FAIL  bunker_config — missing (.../.config/bunker/config.yaml) — the client has no server to talk to
  FAIL  server_reachable — your-bunker-server did not answer: bunker: reading server "your-bunker-server"
RESULT: FAIL (2)          rc=1
```

`./scripts/project-node.sh --check --project myproject`
```
[20] harness  harness: hermes (pin 0.19.0, port 10800)
  PASS  version — Hermes Agent v0.22.5+3029.g6337f1f.dirty (2026.9.24)
  FAIL  port — nothing on :10800
  FAIL  inference_key — no provider key — a turn dies at 'No inference provider configured'
HERMES: FAIL (2)
  FAIL  crier_identity — absent — stage a bundle and re-run; a node without an identity is invisible
  FAIL  repo — .../repo absent (pass --repo to clone)
NODE: FAIL (3)            rc=1
```

`scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes`
```
node-create — project=myrepo harness=hermes server=your-bunker-server
  ..    spawning node-myrepo-181005 (ttl 6h)
  FAIL  spawn — bunker: server "your-bunker-server" not found in config        rc=1
```

Verdict: the README's claim that all three commands reach their checkers on a fresh host and fail
naming the missing value is TRUE. Each of the three reached its checker; each named a real value.

## 2. Status table, both command-bearing rows

`scripts/harness/install-hermes.sh --check` (row 1's contradicting command)
```
harness: hermes (pin 0.19.0, port 10800)
  PASS  binary — /home/kara/.local/bin/hermes
  PASS  version — Hermes Agent v0.22.5+3029.g6337f1f.dirty (2026.9.24)
  FAIL  port — nothing on :10800
  FAIL  inference_key — no provider key
HERMES: FAIL (2)          rc=1
```
The row says the command "names the version, port and key it measured". It does. The row's other
figures (32 s install, `/api/status` 200, 133 JSON-RPC methods) are a historical observation and
are not re-derivable from this repo; the row says so, which is why CF-013 stays open rather than
closed.

Row 2, command **as previously written** — `./scripts/project-node.sh --apply --project myproject --repo https://…`
(the literal ellipsis):
```
[40] repo   ..    cloning https://… @ main
  FAIL  repo_clone — fatal: unable to access 'https://…/': URL using bad/illegal format or missing URL
```
The command the table offered could not be run at all. Fixed in this change (CF-033).

Row 2, command **as now written** — `--repo https://github.com/you/myrepo`:
```
[40] repo   ..    cloning https://github.com/you/myrepo @ main
  FAIL  repo_clone — fatal: could not read Username for 'https://github.com': No such device or address
                      (private repos need a deploy key)
```
Runnable, and it fails honestly instead of failing to parse.

Row 2, "works for public https", measured with a real public repo:
```
[40] repo   ..    cloning https://github.com/github/gitignore @ main
  PASS  repo_clone — <HOME>/repo @ 9402f6a
```
Read back from disk after the run: `git -C <HOME>/repo log --oneline -1` → `9402f6a Merge pull
request #4775 from manry-hub/patch-1`. A second repo (`octocat/Hello-World`, default branch
`master`) cloned with `--ref master` → `PASS repo_clone … @ 7fd1a60`.

The clone half of the row is true. The **build** half is not: `specs/NODE.md` layer 40 says it
establishes "the repo cloned at a pinned ref, build cache present", and `scripts/project-node.sh`
layer 40 clones and returns — it never builds. Census of build invocations across every shipped
shell script at the tip (`npm ci`, `pnpm`, `yarn`, `go build`, `make`, `cargo build`, `uv sync`,
`pip install`) returns 0 for all five. Filed as CF-032; the row now says "Repo clone in a node" and
states the build cache is not established.

Ref behaviour observed while measuring: with a public repo whose default branch is `master`, the
default `--ref main` fails, and the failure text blames a private repo and a deploy key. Filed as
CF-034.

## 3. Repository tests

`bash tests/selftest.sh` at the audited tip: `SELFTEST: PASS`, `17/17 rows parse`, `PASS bash -n` on
every tracked script, `PASS wrong digest refused`, `PASS missing boardctl -> explicit FAIL, exit 127`.

After this change (new check 7, the README↔prompts census):
```
7. every prompt file the README relies on exists
  PASS  every prompts/*.md named by README.md exists
  PASS  absent prompt refused (absent: prompts/ghost-lane.md)
SELFTEST: PASS
```
Proof the new check can fail — with `prompts/docs.md` moved aside:
```
7. every prompt file the README relies on exists
  FAIL  README names a prompt file that is not shipped: absent: prompts/docs.md
SELFTEST: FAIL (1)        rc=1
```
Restored, `SELFTEST: PASS` again, rc=0.

## 4. Lanes section against the live scheduler

`sqlite3 ~/.hermes/coding-hermes/scheduler.db "select name,parent,admission_mode,enabled from
projects where name like 'code-factory%' order by name"` → 19 rows, 14 enabled, 18 with
`parent='code-factory'`, 5 disabled rows all named `code-factory-duckbrain-*`. The four
`*_qa` lanes and every operating lane carry `cooldown`; only `code-factory` carries `tasks`. The
README states exactly that (fourteen lanes, thirteen satellites, the disabled duckbrain rows).
Verified twice: live DB, and the two loaders.

README table ↔ loaders census (14 rows parsed from the table, 14 lanes declared by
`scripts/load_lane_config.py` (6) and `scripts/add_family_lanes.py` (8)): prompt file and admission
mode match for all 14, and no loader lane is absent from the table → `RESULT: MATCH`.

## 5. What this audit did not touch

No live bunker node, no crier dispatch, no scheduler round trip, no release asset, no rendered
GitHub README page. Those stay unverified here and are not called failures.

## 6. Findings filed or moved by this tick

| Row | Finding | State |
|---|---|---|
| CF-032 | Status row promised "clone + build"; no shipped script builds; `specs/NODE.md` layer 40 asks for a build cache | filed, open (code) |
| CF-033 | Row 2's command was a literal `https://…` and could not run | filed and fixed in README |
| CF-034 | Every clone failure appends "private repos need a deploy key", including a missing `--ref` branch; `--ref` was undocumented | filed; README half fixed, message fix open |
| CF-035 | Layout listed 5 of 11 `scripts/` entries and omitted `scripts/boardctl`, the two lane loaders and `prompts/` | filed and fixed in README |
| CF-009 | Quick start step 1 required an unexported `BUNKER_SERVER` | verified fixed, closed |
| CF-010 | Layout promised four harness installers that do not ship | verified fixed, closed |
| CF-014 | Quick start used unsupported `project-node.sh` arguments | verified fixed, closed |
| CF-015 | "Three environment variables" vs two | verified fixed, closed |
| CF-030 | Lanes section mis-stated prompts, loaders and count | fixed, including the missing census test (AC3) — closed |
| CF-011, CF-012, CF-013, CF-031 | AGENTS.md citation, missing traceability doctrine, historical "works" figures, DEGRADED-PASS guard | unchanged, still open |

STATUS: PASS
TIER: T4 — every documented command was executed against the real tree from a fresh archive and its
output read back, including a real public `git clone` landing on disk and a live scheduler-DB census
EVIDENCE: docs/audits/code-factory-readme-2026-10-30-20-29-25.md (this file); `bash tests/selftest.sh`;
`scripts/bunker-server-install.sh --check`; `./scripts/project-node.sh --check --project myproject`;
`./scripts/project-node.sh --apply --project myproject --repo https://github.com/github/gitignore`;
`scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes`
