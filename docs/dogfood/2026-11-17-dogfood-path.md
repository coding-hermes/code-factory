# Dogfood 2026-11-17 — the documented path, walked literally

Run id `code-factory-dogfood-2026-11-17-10-10-24`. Tip
`0014b76ac0b5a33081068d743e52754b928b4e0c` (origin/main; `git rev-list --left-right --count
HEAD...origin/main` = `0 0`; `python3 scripts/ownership.py status` = clean, 0 dirty, 0 untracked).
Control host: Linux, `python3` 3.14.9, `python3.12` 3.12.13, `bunker` 0.3.0, server
`<bunker-server>` ONLINE with 0/8 agents.

Everything below was run from this checkout. Raw stdout/stderr per arm is in
`.coding-hermes/evidence/code-factory-dogfood-2026-11-17-10-10-24/` (`step1-*`, `step2.*`, `b1.*`,
`b2`–`b6.*`, `c1`–`c5.*`), beside the three probe scripts that produced them.

Host-identifying literals in this page and in that directory are elided the way `README.md` elides
them (`III.M6.S7`): the operator home reads `~`, the control host reads `<control-host>`, the bunker
server reads `<bunker-server>` with `<bunker-host>:<port>` for its address. Every row, count, wall
time and exit status is unchanged by that substitution; `INDEX.md` lists exactly what was replaced
in which file.


## 1. What was walked, and what it cost

| Step | Command (verbatim from `README.md`) | rc | Wall | Result |
|---|---|---|---|---|
| 1, no env | `scripts/bunker-server-install.sh --check` | 1 | 0.00 s | `FAIL server_declared — BUNKER_SERVER unset — the client has no server to talk to` |
| 1, placeholder env | same, `BUNKER_SERVER=your-bunker-server` | 1 | 0.03 s | 2 FAILs (`server_declared`, `server_reachable`), 6 PASSes |
| 1, real server | same, `BUNKER_SERVER=<bunker-server>` | **0** | **0.92 s** | `RESULT: PASS` + one `WARN residue` (see §2.1) |
| 2 | `./scripts/project-node.sh --check --project myproject` | 1 | 38.16 s | `HERMES: FAIL (1)`, `NODE: FAIL (5)` |
| 2 remedy | `HERMES_PYTHON_BIN=python3.12 ./scripts/project-node.sh --check …` | 1 | — | `HERMES: FAIL (3)`, `NODE: FAIL (7)` (see §2.2) |
| 3 | `scripts/node-create.sh --project myrepo --repo https://github.com/you/myrepo --harness hermes` | 1 | 0.36 s | spawned `node-myrepo-051414`, then `FAIL spawn — … bunker: server "your-bunker-server" not found in config` |

Step 3 was **not** run against a real server: that spawns a container on shared infrastructure, and
the row that owns its failure message (`CF-469`) shows a prior tick already drove it end to end.

Refusal paths a first-run user reaches, all clean and named (probe C):

- `node-create.sh --help` → rc 0, usage, no `CRIER_URL`/`BUNKER_SERVER` needed (the script header's
  claim holds).
- `node-create.sh --staged-files --harness hemes` → rc 1, `FAIL harness — 'hemes' is not an adapter:
  this tree ships aider, claude-code, codex, deepseek, dsh, goose, hermes, opencode, pi-agent`.
- `node-create.sh` with no arguments → rc 2, usage.
- `land-node-branch.sh --workdir /nonexistent/wt …` → rc 1, `FAIL workdir — not a git worktree`,
  `LAND: REFUSED`.
- `verify-node.sh` with no arguments → rc 2, usage; with `--agent` but no server → rc 2,
  `set BUNKER_SERVER or pass --server <name>`.
- `bunker-crier-connect.sh --check` with no flags → rc 2, `--server is required (the agent's bunker
  host)` (only the first missing flag is named; `--url`/`--agent` are not).

## 2. Where the docs and the behaviour disagree

### 2.1 A residue WARN that fires on zero residue — `CF-483`

`bunker-server-install.sh --check` prints, two lines apart:

```
  ..      Residue:  0 orphan users, 0 orphan homes, 0 orphan keys, 0 stale linger entries (0 registered agents)
  WARN  residue — orphan homes/keys reported by the server — set BUNKER_HOMES_DIR/BUNKER_KEYS_DIR and re-run with --reap-orphans
```

`scripts/bunker-server-install.sh:117` is `say "$st" | grep -qi 'orphan' && warn "residue" …`. The
server's status text always contains the word "orphan" because it labels the counts, so the row is
unconditional and never parses the numbers beside it: 0 orphans and 12 orphans print identically.
This is the only control-host surface that reports residue, and the remedy it names
(`BUNKER_HOMES_DIR` / `BUNKER_KEYS_DIR`) is server-side — both unset on this host.

**What a new user does next**: reads `RESULT: PASS`, assumes residue is fine, and never learns that
the row cannot fail. Filed as `CF-483` (P3, `III.M1.S1`).

### 2.2 The Quick start's own remedy overclaims the outcome — `CF-484`

`README.md:26-29` (added by `CF-473`, commit `5c79c29c`) says:

```
#    … the same check with an explicit interpreter passes:
#    HERMES_PYTHON_BIN=python3.12 ./scripts/project-node.sh --check --project myproject
```

Measured: the `python` row does flip to `PASS python — 3.12.13 (hermes-agent 0.19.0 requires
>=3.11,<3.14)`, and the check gets **worse**, not better — from `NODE: FAIL (5)` to
`NODE: FAIL (7)`, because an in-range interpreter lets the adapter reach three gates a 3.14 host
never reaches:

```
FAIL  binary — host-provided ~/.local/bin/hermes (not installed by this adapter — run --apply)
FAIL  version — 0.22.5+3032.g3f87b28 != pin 0.19.0
FAIL  port — nothing on :10800
```

`CF-473`'s AC-4 only graded that the remedy *text* appears in the Quick start (`grep -c
HERMES_PYTHON_BIN` ≥ 1), so the prose could assert any outcome and still close. Filed as
`CF-484` (P3, `III.M6`): the sentence must name the row that flips and the totals that remain.

### 2.3 `--json` is accepted and inert — annotation on `CF-057`

`scripts/bunker-server-install.sh:19,25` set `JSON=1` on `--json`; nothing else in the tree reads
the variable (`grep -n JSON` → usage text lines only; `scripts/lib.sh` has none).
`--check --json` prints the human rows byte-for-byte and ends `RESULT: PASS`. The header advertises
`--check [--json]` / `--reap-orphans [--json]`, so a caller that parses stdout as JSON gets a parse
error, not a named refusal. `CF-057` already owns "the header advertises flags the body does not
implement"; added the measurement there rather than minting a sibling row.

## 3. The right way to do this (what the docs should let a stranger do)

1. `export BUNKER_SERVER=<a name in ~/.config/bunker/config.yaml>` — the value must be a server the
   client already knows; the check refuses a name that is not, and that refusal is correct.
2. `scripts/bunker-server-install.sh --check` — expect `RESULT: PASS` in ~1 s. Treat its `residue`
   WARN as currently meaningless (2.1) and measure residue with `bunker status --server <s>`
   yourself until `CF-483` lands.
3. `./scripts/project-node.sh --check --project <p>` — this is a **node-side** check run on the
   control host: `footprint:floor`, `crier_identity` and `repo` failing is the honest answer, and
   `NODE: FAIL` is expected. `CF-387` owns the 38 s cost and the missing remedy on `footprint:floor`.
4. Do not read the `python` row's remedy as "the check passes" (2.2).
5. Step 3 needs a real `BUNKER_SERVER`; with a placeholder it spawns first and only then reports
   the missing server, retaining the spawn log path it prints.

## 4. Unverified this fire

- A live `node-create` (spawns an agent on shared infrastructure; `CF-469` carries the last live
  attempt, which dead-ended at a bare `400 Bad Request`).
- One probe arm — `node-create.sh` with neither `CRIER_URL` nor `BUNKER_SERVER` set, reading its
  exit status — was refused by the unattended command gate (a chained `bash -c` form). Not
  re-attempted in another form; the earlier arm with `CRIER_URL` unset printed
  `FAIL  crier_url — CRIER_URL unset or empty — export CRIER_URL=http://crier.example:8767` and its
  exit status is **not** claimed here.
