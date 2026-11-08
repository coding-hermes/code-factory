# Dogfood walk — tick code-factory-dogfood-2026-11-08-04-02-17

Target identity: `origin/main` **40db7d8cff851a64f8030ed62d835f344e886419**, pinned for the whole
walk. Canonical checkout `/home/kara/code-factory` was clean (`git status --porcelain -uall` = 0
lines) and at parity (`git rev-list --left-right --count HEAD...origin/main` = `0 0`) when the walk
started, but **two sibling lanes were running `tests/selftest.sh` in that same checkout** (a
`code-factory` lane publishing the CF-006 verdict bundle and a `code-factory-sync` lane at
`04-02-17`), so every arm below ran in a `git archive` copy of the pinned SHA at
`<scratch>/walk` — 1327 files, `README.md`/`AGENTS.md`/`tests/selftest.sh` present. The canonical
checkout was not written to.

Host: control host, `CRIER_URL` and `BUNKER_SERVER` unset in the walk environment (the documented
fresh-host scenario).

## 1. Quick start, walked literally

| Step | Command | rc | wall | first deciding row |
|---|---|---|---|---|
| 1 | `bash scripts/bunker-server-install.sh --check` | 1 | 0.01 s | `FAIL server_declared — BUNKER_SERVER unset — the client has no server to talk to` |
| 2 | `bash ./scripts/project-node.sh --check --project myproject` | 1 | **48.48 s** | `FAIL footprint:floor — 126606.8 MiB exceeds the 5 GiB floor (2472.8 %)` |
| 3 | `bash scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes` | 1 | 0.02 s | `FAIL crier_url — CRIER_URL unset or empty` |

All three reach a repo-convention `FAIL` row naming the missing value, and steps 1 and 3 no longer
abort in bash (`line 14:`/`line 70:`). **This is liveness confirmation of CF-145's fix, not a
finding** — CF-145's acceptance criteria 1 and 2 asked for exactly these two rows. Step 3 now names
`CRIER_URL` where CF-145 AC2 said `BUNKER_SERVER`; the substance (a named result row before any
checker, no shell abort, nonzero exit) holds, so no row is filed against the wording.

### 1a. Where step 2's 48 s goes

| Arm | wall | note |
|---|---|---|
| `--layers 00` | 29.85 s | the `footprint` row alone: `python3 scripts/node_hygiene.py footprint --root $HOME --floor-gib 5` → **31.97 s**, rc=1 |
| `--layers 10` | 0.08 s | |
| `--layers 20` | 0.07 s | |
| `--layers 30` | 0.02 s | |
| `--layers 40` | 0.02 s | |

`scripts/node_hygiene.py:43-49` measures five components, and the `harness` component is
`$HOME/.hermes` — **131 GB / 126718 MiB on this host**, against a 5 GiB admission floor.
`scripts/project-node.sh:242-246` states the opposite in its own comment:

> Bounded component set only (repo, toolchains, harness home, node state, declared module cache),
> **so the row stays cheap on a host with a large $HOME**.

The set is bounded in *count*, not in *size*: the one member that is unbounded dominates the
measurement, costs ~30 s of the 48 s first check, and then fails at 2475 % of the floor with no
remedy named. On a real node the same row is instant and clean (`footprint 0.0 MiB`, `PASS
footprint:floor` — see section 2), so this is a control-host arm only. Filed as **CF-387**.

## 2. Node create against a live host (the lane's agent-spend)

A node host was **available**: of the three configured bunker servers, two refused
(`dial tcp … connection refused`) and one answered `No agents found.` at an empty census. A real
Crier was listening on the control host (`/health` → 200). One spawn was spent, at the pinned tip:

```
BUNKER_SERVER=<empty-host> CRIER_URL=http://<control-host>:8767 \
  bash scripts/node-create.sh --project cf-dogfood \
       --repo https://github.com/github/gitignore --harness hermes --ttl 1h
```
rc=1, 155 s, 97 lines. Measured legs:

- **PASS** spawn `node-cf-dogfood-231753` · staged (12 files) · disk_floor · arch/role/disk/mem ·
  footprint `0.0 MiB` · footprint:room · footprint:floor `0.0 MiB of the 5 GiB floor` ·
  crier_url · `reach:<crier>/health — 200` · `reach:https://pypi.org/simple/ — 200` ·
  tool:python3/git/curl/tar/sha256sum · python:venv · `python — 3.13.5` ·
  `install — Hermes Agent v0.19.0 (2026.7.20)` · `binary — …/hermes-venv/bin/hermes` ·
  `repo_clone — … /repo @ 41862c8` · `freshness — branch=main head=41862c8 behind=0 ancestor=true`
- **WARN** `kinds — generic fallback`, `tool:rg — missing`, `tool:node — missing`
- **FAIL** `gateway_auth`, `binary` (pre-apply), `inference_key`, `gateway_start`, `crier_identity`
- Layers 30/40 outcomes are as `README.md:51-53` predicts for `inference_key` and `crier_identity`.

### 2a. The defect: layer 20's auth staging dies on a fresh node

```
  FAIL  gateway_auth — could not stage dashboard.basic_auth in
        /home/bunker-node-cf-dogfood-231753/.hermes/config.yaml (exit 1):
        FileNotFoundError: [Errno 2] No such file or directory:
        '/home/bunker-node-cf-dogfood-231753/.hermes/config.yaml.cf-tmp'
...
  FAIL  gateway_start — refused: a public bind needs dashboard.basic_auth in
        ~/.hermes/config.yaml — block absent (config unreadable)
```

`scripts/node_gateway_auth.py:64` creates the directory for the **password** file
(`os.makedirs(os.path.dirname(password_file) …)`) but nothing creates the directory for the
**config** file: `:79-83` builds `tmp = config + ".cf-tmp"` and opens it. On a freshly created node
`~/.hermes/` does not exist yet — the harness adapter that creates it runs *after* this step in
layer 20 — so the temp write raises `FileNotFoundError` and the staging never lands.

`README.md:50-51` promises the opposite: *"A freshly created node is expected to reach `PASS
gateway_start — /api/status -> 200` from the adapter."* That is unreachable on the documented
create path, and the row that added this mechanism (CF-150) closed on the criterion that
`--apply` in a fresh HOME must *not* print `refused: a public bind needs dashboard.basic_auth` —
which is the exact line measured above.

**Discriminating arm** (separates "broken writer" from "missing parent directory"). After the
adapter's install created `~/.hermes` on the same node, the same writer was re-run:

```
PASS  gateway_auth — added dashboard.basic_auth (user node) to …/.hermes/config.yaml
PASS  gateway_auth — password stored at …/.node/auth/gateway.pass, mode 600 (not printed)
auth_rc=0
```
So the writer is correct and the defect is its precondition/ordering. Filed as **CF-388**.

Distinct from, and must not be merged with: **CF-150** (complete — added the staging step),
**CF-292** (pending — the 8-line `basic_auth` window can false-PASS), **CF-193/CF-194**
(pending — the *gate's* YAML parsing and `HERMES_HOME` root, consumer side).

### 2b. Teardown is proven, not merely attempted

- `bunker info` on the agent: `Created At 20:18:16`, `Expires At 21:18:16` — **the documented
  `--ttl 1h` measured exactly 3600 s**, an arm no earlier record covers.
- `bunker destroy <agent> --server <host>` → rc=0, `home 431.4 MB`, `Removed local SSH key`.
- Post-destroy census lists **no** agent with this run's id.
- One *other* agent (`2764ae84`, created 20:21:19) appeared on the host inside this window and was
  neither created nor touched by this run — the host answered `No agents found.` at the start of
  the walk, so it belongs to a concurrent lane, not to this one.

## 3. Failure paths (walked because a stranger hits them first)

| Probe | Result | Classification |
|---|---|---|
| `bunker list` with no `--server` | rc=1, names the default server and `connection refused` | honest, no row |
| `bunker list --server <s>` × 3 | 1 empty + reachable, 2 offline | routing evidence for section 2 |
| `node-create.sh … --harness bogus` (CRIER_URL set) | rc=1, `FAIL staged_set — missing scripts/harness/install-bogus.sh` | **liveness of CF-125** (typo indistinguishable from documented-but-unmeasured) — no new row |
| `project-node.sh --check --project p --bogus-flag` | rc=2, `unknown arg: --bogus-flag` | honest, no row |
| step 1 run twice | rc 1/1, byte-identical output | idempotent (AGENTS.md rule 5) |

## 4. What a new user would have done next

On the control host: read step 2 as "run this here", wait 48 s, and be told their home is 2475 %
over a 5 GiB floor — a number about the wrong machine, with no next step. On the node: reach
`FAIL gateway_auth` with a Python traceback, then `gateway_start: block absent`, and conclude the
auth staging the README documents does not work — it does, one directory too late.

## 5. Boundary

No product code was changed by this walk. The only writes are this evidence file and the two board
rows. The canonical checkout was not written to; the walk copy is under the tick's scratch root.

## Addendum 2026-11-08b — REFIRE-B (records-only): this tick id was dispatched twice

REFIRE-B — the id `code-factory-dogfood-2026-11-08-04-02-17` fired a second time. The first fire is
recorded above and landed as `86d13c4` (2026-11-07T23:23:48-05:00). Per the duplicate-fire rule this
fire re-verified from scratch and **re-measured nothing and added no rows**.

| Leg | Command | Result |
|---|---|---|
| Published ref | `git fetch origin main; git rev-list --left-right --count HEAD...origin/main` | HEAD `2044c6f708f2404956ce651ecac39db0e27b82b7` = `origin/main`, parity `0 0` |
| Board size / dup ids | `git show HEAD:.coding-hermes/board/tasks.jsonl \| jq -r .id \| sort \| uniq -d \| wc -l` | 364 rows, **0** duplicate ids |
| This tick's rows | `jq -rc 'select(.id=="CF-387" or .id=="CF-388")'` on the committed board | CF-387 ×1 (pending), CF-388 ×1 (pending) |
| Anchors still live at HEAD | `grep -n` on the cited code | `node_hygiene.py:47 ("harness", ".hermes")`; `node_gateway_auth.py:64` makedirs(password dir) only, `:79 tmp = config + ".cf-tmp"` |
| CI | `gh run list --repo coding-hermes/code-factory --limit 3` | `[]` — the documented no-workflow state; gate is `tests/selftest.sh` + the GitReins guard |
| GitReins for this tick | `.gitreins/tasks.yaml` | task `CF-387` status `complete`; verdict bundle published in `949e116` (PASS at `86d13c4`) |

**Gap found and closed by this fire — the first fire's closeout dropped the board events.**
`git show --stat 86d13c4` is 2 files (`tasks.jsonl` + the audit file), so the two `task_created`
events `boardctl` had written at `04:23:28Z` (ids 542/543, 20 s before that commit) never landed:
`git show HEAD:.coding-hermes/board/events.jsonl | jq 'select(.task_id=="CF-387" or .task_id=="CF-388")'`
returned **zero** rows while both board rows were committed. A GitReins judge had since captured the
residue in `949e116`'s `worktree.patch` (10 lines) without it ever being committed. Producer and
disposition are established — the timestamps are this tick's own first fire, and the only live
repo-cwd writers at re-verification time were two sibling GitReins judges running `tests/selftest.sh`
(pids 135738, 147075, both on other lanes' worktrees) plus a `code-factory` lane tick at
`cf-tick-20261108-0416`; none of them owns this board path. The two events are landed in the same
commit as this addendum.

**Validator, no new class.** `bash scripts/boardctl validate` on the HEAD-reconstructed board:
`RESULT: OK (17 warning(s))`; the same command on the working tree carrying the two events:
`RESULT: OK (17 warning(s))`. All 17 are pre-existing classes (9 deferred rows with no
`defer_reason`, 2 free-form `guard_result`/`ci_result` on CF-034, 3 title/priority mismatches, the
legacy duplicate event id 336, headerless board).

**Install-leg census (fresh, read-only, no agent launched this fire).** One `curl -w` invocation over
all seven configured servers: `404` (bunkerd alive — its `/health` answer) on **bunker-las-02,
bunker-mvp, dedi-2**; `000` (down) on bunker-las-01, bunker-las-03, bunker-las-04, cube-las-00. The
first fire's spawn and teardown proof stands for its own run; this fire deliberately spent no spawn
because it produced no new product evidence.

**Rows stay live.** Product surfaces that moved between the first fire's pinned SHA `40db7d8` and
HEAD are `README.md`, `docs/handbook/chapters/M5-harness.md`, `scripts/harness/install-aider.sh`,
`scripts/harness/install-goose.sh`, `tests/harness-conformance.sh`, `tests/selftest.sh` — none of
them is a surface either row's acceptance criteria measures (`node_hygiene.py`,
`node_gateway_auth.py` and `project-node.sh` are unchanged), so CF-387 and CF-388 are neither stale
nor fixed at the published tip.

