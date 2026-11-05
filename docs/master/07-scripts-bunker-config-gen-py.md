# 07. scripts/bunker_config_gen.py

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/bunker_config_gen.py` — 724 lines [scripts/bunker_config_gen.py:1] |
| Repository | `code-factory` [scripts/bunker_config_gen.py:64] |
| Revision | `6eea792` — the `origin/main` tip every locator below was measured against |
| Status | **VERIFIED — every row of §3 was run on 2026-11-05 against fixtures under `$TMPDIR` plus the live registry, and the shipped battery leg 46 is green (11/11). The one arm not exercised is `bunker-provision.sh --apply` against a real host; the parse path it shares with `--check` was measured** |

## 1. Purpose and why it matters

- What it is: one `bunker-provision` config per project, derived from the scheduler's sqlite
  `projects` table instead of typed by hand [scripts/bunker_config_gen.py:2-9]. The output is a flat
  `KEY=VALUE` file — the provisioner parses it as **data and never executes it**
  [scripts/bunker-provision.sh:9-10].
- Why it matters: that file decides *which clone* a bunker gets, *which agent id* it runs under,
  *which DuckBrain namespace* its memory lands in, and *which files* its credentials are read from
  [scripts/bunker-provision.sh:16-24]. Because one bunker serves one project and every lane of that
  project enters it (fact: FACT-02), the config is the whole blast radius of a provisioning mistake.
- What breaks if it is ABSENT: every project's config is hand-written, and the source names exactly
  the drift that follows — `a typo in a repo URL, the same agent name on two projects, a namespace
  that stopped matching the registry` [scripts/bunker_config_gen.py:5-7]. A hand-edited file also
  cannot be diffed against the registry, so a lane that is re-namespaced in sqlite keeps its old
  memory target forever.
- What breaks if it LIES: a config that names a path which does not exist, or a default that
  silently wins, makes every downstream measurement read the wrong inputs — the wrong clone
  provisioned, the wrong namespace written to, the wrong token file read. The module's answer is to
  refuse rather than guess: `Everything else is refused, never guessed` [scripts/bunker_config_gen.py:33-38],
  and a run that refused anything writes nothing [scripts/bunker_config_gen.py:37-38].
- The rule that matters most here: credentials travel as **file paths**, never as values
  (fact: FACT-05). This module is where that rule could be broken in the one file a node is
  provisioned from, and §3 rows 9-11 measure that it is not: the three credential keys hold paths,
  no token file is opened by the process, and sentinel secrets present in the environment never
  reach the bytes.
- What is *not* a credential: `REPO` is a clone target and may legitimately be a local path — the
  run says so with a WARN rather than refusing, because a local path cannot be cloned by a remote
  node [scripts/bunker_config_gen.py:632-638].

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `python3` | 3.14.4 measured here; the file is stdlib-only and declares no floor beyond `from __future__ import annotations` [scripts/bunker_config_gen.py:67] | control host, invoked directly (`#!/usr/bin/env python3`) [scripts/bunker_config_gen.py:1] | nothing in this module; the battery's first leg parses it with `ast` [tests/selftest.sh:2667-2671] |
| the scheduler sqlite DB | any file with a `projects` table carrying `name`, `repo_url`, `workdir`, `namespace_id`, `enabled` [scripts/bunker_config_gen.py:174-179] | `--db`, else `$SCHEDULER_DB`, else `~/.hermes/coding-hermes/scheduler.db` [scripts/bunker_config_gen.py:494] | `FAIL db — scheduler database not found: …` / `… is not a file: …` / `` … has no `projects` table `` [scripts/bunker_config_gen.py:165-176] |
| the output directory | creatable and writable | `--projects`, default `~/.config/code-factory` [scripts/bunker_config_gen.py:496-499] | `FAIL output_dir — … is not writable` [scripts/bunker_config_gen.py:478-487] [scripts/bunker_config_gen.py:696-701] |
| `scripts/bunker-provision.sh` (the consumer) | the copy in the same checkout | anywhere the operator runs it from | not detected by this module — the contract is measured by the battery instead [tests/selftest.sh:2747-2759] |

The database is opened read-only and never written: `sqlite3.connect(f"file:{path}?mode=ro", uri=True, timeout=15)`
[scripts/bunker_config_gen.py:170], and the docstring states the property the code keeps —
`stdlib + sqlite3 only. Never opens the database for writing.` [scripts/bunker_config_gen.py:64].

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `argparse` [scripts/bunker_config_gen.py:69] | stdlib | twelve options, `action="append"` for the two selectors, `store_true` for `--force` / `--check` / `--dry-run` [scripts/bunker_config_gen.py:490-528] | every flag is read through the namespace in `run`; a renamed option becomes an `AttributeError`, not a silent default |
| `hashlib` [scripts/bunker_config_gen.py:70] | stdlib | `sha256(...).hexdigest()[:12]` is the only identifier printed for a config [scripts/bunker_config_gen.py:146-147] | the 12-hex prefix in every `wrote` / `unchanged` / `match` row changes width; the battery greps the row, not the digest [tests/selftest.sh:2792] |
| `os` [scripts/bunker_config_gen.py:71] | stdlib | `path.expanduser`/`abspath` for `--db` and `--projects` [scripts/bunker_config_gen.py:150-151], `path.isdir` for every local repo target [scripts/bunker_config_gen.py:221] [scripts/bunker_config_gen.py:229], `makedirs`/`access` for the output dir [scripts/bunker_config_gen.py:483-487], `replace` for the atomic write [scripts/bunker_config_gen.py:374-378], `environ` for `SCHEDULER_DB` [scripts/bunker_config_gen.py:494] | a change in `expanduser` semantics changes which file `--db` resolves to while the header row still prints a plausible path |
| `re` [scripts/bunker_config_gen.py:72] | stdlib | three compiled patterns: the project slug `^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$` [scripts/bunker_config_gen.py:89], a URL scheme `^[A-Za-z][A-Za-z0-9+.-]*://` [scripts/bunker_config_gen.py:90], the agent alphabet `[^a-z0-9]+` [scripts/bunker_config_gen.py:273]; plus `parse_config`'s `^([A-Z_][A-Z0-9_]*)=(.*)$` [scripts/bunker_config_gen.py:351] | the slug check and the agent normalisation are what stand between a lane name and a valid bunker id; widening either widens what gets provisioned |
| `sqlite3` [scripts/bunker_config_gen.py:73] | stdlib | read-only URI connect with `timeout=15`, one `pragma table_info(projects)`, one `select … order by name` [scripts/bunker_config_gen.py:170-183] | a registry column rename is caught by the column check [scripts/bunker_config_gen.py:177-179]; a lock longer than 15 s becomes a named `Refused` |
| `sys` [scripts/bunker_config_gen.py:74] | stdlib | `stdout`/`stderr` for the row stream [scripts/bunker_config_gen.py:130-143], `exit(main())` [scripts/bunker_config_gen.py:723-724] | the `--dry-run` stdout/stderr split is what lets configs be redirected into files [scripts/bunker_config_gen.py:127-131] |
| `typing` [scripts/bunker_config_gen.py:75] | stdlib | `Optional` only [scripts/bunker_config_gen.py:490] | cosmetic; nothing at runtime reads the annotations |

### 2c. Service contract with the provisioner (both sides named)

| Element | Generator side | Provisioner side | Measured |
|---|---|---|---|
| file grammar | `KEY=VALUE` per line, sorted, two comment headers [scripts/bunker_config_gen.py:335-342] | `^([A-Z_][A-Z0-9_]*)=(.*)$` or it refuses the line [scripts/bunker-provision.sh:103-105] | the real script parses the generated file: `PASS  config — demo.conf — 13 lines, KEY=VALUE only` [tests/selftest.sh:2751-2759] |
| key set | 11 keys, `CONFIG_KEYS` [scripts/bunker_config_gen.py:92-104] | allowlist `PROJECT|AGENT|SERVER|REPO|REF|HARNESS|NAMESPACE|NAMESPACES|TTL|CRIER_URL|DUCKBRAIN_URL` plus the `*_FILE` and `CONFIG_SET_*` families; anything else is `unknown key` [scripts/bunker-provision.sh:109-120] | all 11 emitted keys are inside the allowlist — compared programmatically, zero missing; `PASS  config` above is the live consequence |
| `~` in a path | written unexpanded: `TOKEN_DIR` is built with `os.path.join("~", …)` and never passed through `expand()` [scripts/bunker_config_gen.py:111] [scripts/bunker_config_gen.py:317-329] | expanded at load for exactly the six `*_FILE` keys: `case "$val" in "~/"*) val="$HOME/${val#\~/}" ;; esac` [scripts/bunker-provision.sh:116-118] | measured — the provisioner resolved the emitted `~/.config/...` to `<HOME>/.config/code-factory/demo/github.token` in its own row (§3 row 24) |
| namespace | one `NAMESPACE` key [scripts/bunker_config_gen.py:325] | `NAMESPACE` is the single-namespace alias; `NAMESPACES` is a comma list and wins when present [scripts/bunker-provision.sh:62-67] [scripts/bunker-provision.sh:110] | the generator emits only the alias, so it cannot express a multi-namespace project (§6) |

## 3. Verification

Every row below was run on 2026-11-05 in this worktree at `6eea792`, Python 3.14.4, against
fixtures the driver built in `$TMPDIR` — a `projects` table with exactly the five columns the loader
requires [scripts/bunker_config_gen.py:174-179] and real directories for the local repo targets.
Row 19 is the exception: it reads the **live** registry read-only. Re-runnable commands are in §8.

| # | Check | Command | Expected | Result |
|---|---|---|---|---|
| 1 | first write | `bunker_config_gen.py --db <fixture> --projects <out> --server cf-node` | one `demo.conf`, exit 0 | **PASS** — `PASS  wrote — <out>/demo.conf — 11 keys, sha256 f1226cb7623c`, `BUNKER-CONFIG: PASS — 1 config (1 written, 0 unchanged), 0 refused` |
| 2 | second write, same inputs | same command | `unchanged`, no rewrite | **PASS** — `PASS  unchanged — … — byte-identical, sha256 f1226cb7623c`, exit 0; the digest matches row 1 |
| 3 | clean `--check` | same plus `--check` | `match`, exit 0 | **PASS** — `PASS  match — … — 11 keys agree, sha256 f1226cb7623c`, `BUNKER-CONFIG: PASS — 1 config checked, no drift` |
| 4 | one key edited by hand | `sed -i 's/TTL=6h/TTL=9h/'`, then `--check` | the drifted key named, exit 1 | **PASS** — `FAIL  drift — … — TTL: file '9h' ≠ registry '6h'`, `BUNKER-CONFIG: DRIFT (1 of 1 mismatched)`, exit 1 |
| 5 | same file, write mode, no `--force` | write without `--force` | refusal to overwrite, exit 1, file untouched | **PASS** — `FAIL  drift — … — TTL: file '9h' ≠ registry '6h' — pass --force to rewrite`, exit 1 |
| 6 | `--force` | write with `--force` | rewrite, exit 0 | **PASS** — `PASS  rewrote — … — 11 keys, sha256 f1226cb7623c`; the file is byte-identical to row 1 again |
| 7 | config absent under `--check` | `rm …/demo.conf`, then `--check` | named missing, exit 1 | **PASS** — `FAIL  missing — … — no config; run without --check` |
| 8 | `--dry-run` | same with `--dry-run` | configs on stdout, rows on stderr, nothing created | **PASS** — the config block is on stdout, every row on stderr, and the `--projects` directory does **not** exist afterwards (`os.path.isdir` → `False`) |
| 9 | **values vs paths** | classify all 11 values in the written file | the three credential keys are paths under `~/.config/code-factory/<project>/`, the rest are slugs/hosts/refs | **PASS** — `GITHUB_TOKEN_FILE=~/.config/code-factory/demo/github.token`, `DUCKBRAIN_TOKEN_FILE=…/duckbrain.token`, `S3_ENV_FILE=…/s3.env`; key count 11; no `_FILE` value is a URL; the leaves match `TOKEN_FILES` [scripts/bunker_config_gen.py:112-116] |
| 10 | **no credential file is opened** | `strace -f -e trace=openat,open,stat,newfstatat -o trace …` | zero syscalls naming a token path | **PASS** — 525 traced lines, 117 `openat`, **0** naming `code-factory`, `.token` or `s3.env`; the only config it opens is the target `demo.conf` itself |
| 11 | **secrets in the environment** | run with `GITHUB_TOKEN=… DUCKBRAIN_TOKEN=… AWS_SECRET_ACCESS_KEY=… CRIER_AUTH_TOKEN=…` sentinels | none of them in the file | **PASS** — all four `in file = False`; `ghp_`, `sk-`, `AKIA`, `BEGIN`, `password`, `secret` each 0 hits |
| 12 | no `--server` | omit it | `FAIL server`, exit 2 | **PASS** — `FAIL  server — SERVER unset — a config names no host to provision on`, `BUNKER-CONFIG: REFUSED (1)` |
| 13 | phantom local repo | `repo_url = local:<missing path>` | refused by name, nothing written | **PASS** — `FAIL  ghost — PHANTOM — repo_url names local:…/no-such-repo, and …/no-such-repo does not exist`, exit 2, out dir absent |
| 14 | empty `repo_url` | `repo_url = ''` | refused by name | **PASS** — `FAIL  emptyrepo — repo_url is absent or empty in the registry` |
| 15 | ambiguous group | two lanes in one clone with no common prefix | `AMBIGUOUS`, exit 2 | **PASS** — `FAIL  group[alpha-beta, gamma-alpha] — AMBIGUOUS — no lane name or family key is a prefix of every lane in the group (alpha-beta, gamma-alpha) — refusing to guess` |
| 16 | two projects, one agent id | `demo--alpha` and `demo-alpha` on different clones | refused by agent, exit 2 | **PASS** — `FAIL  agent — 'cf-demo-alpha' derived by demo--alpha and demo-alpha — refusing to guess`, `BUNKER-CONFIG: REFUSED (5) — nothing written` |
| 17 | unwritable output dir | `chmod 500 <out>` | refusal naming the directory, exit 2 | **PASS** — `FAIL  output_dir — the config directory <out> is not writable`, `BUNKER-CONFIG: REFUSED (1) — nothing written` |
| 18 | registry-level refusals | missing DB / DB with no `projects` table / scope matching nothing | three named refusals, exit 2 each | **PASS** — `FAIL  db — scheduler database not found: …`; `` FAIL  db — … has no `projects` table ``; `FAIL  scope — no registry row matches --project/--prefix` after `..    scope — 0 of 3 registry rows selected` |
| 19 | **live registry, read-only** | `--server cf-node --prefix code-factory --dry-run` against `~/.hermes/coding-hermes/scheduler.db` (880 rows) | refuses per row or predicts configs; the DB is untouched | **PASS** — `..    scope — 17 of 880 registry rows selected`, one config (`code-factory.conf`: `SERVER=cf-node`, `TTL=6h`, `REPO=/home/kara/code-factory`), `BUNKER-CONFIG: DRY-RUN — 1 config(s) predicted`, plus `WARN  suffix` (for `code-factory-duckbrain`, `code-factory-ops`) and `WARN  namespace — lanes disagree: code-factory (16 lanes), ops (1 lane) — using the project name code-factory` |
| 20 | selector semantics | `--project demo` / `--project demo-qa` on a 3-lane family | a selector also selects its satellites | **PASS** — `..    scope — 3 of 3 …` and `..    scope — 1 of 3 …`; both emit `PROJECT=demo`, because the family key names the project [scripts/bunker_config_gen.py:200-208] |
| 21 | scope changes `NAMESPACE` | one project, full scope vs `--project twin-qa` | the emitted namespace follows the *selected rows* | **PASS (and a finding)** — full scope: `NAMESPACE=twin` with `WARN  namespace — lanes disagree: other (1 lane), twin (1 lane) — using the project name twin`; scoped to `twin-qa`: `NAMESPACE=other`, same output path (§6 defect 2) |
| 22 | operator-added `NAMESPACES` | append `NAMESPACES=demo,other`, then `--check` | a provisioner-honoured key is treated as drift | **PASS (and a finding)** — `FAIL  drift — … — obsolete key NAMESPACES`; write mode appends `— pass --force to rewrite`, and `--force` would delete it (§6 defect 1) |
| 23 | the shipped battery leg | `tests/selftest.sh` section 46 [tests/selftest.sh:2659-2827] | 11 green assertions | **PASS** — `LEG46 FAILS=0`, including `PASS  bunker-provision.sh parses the generated config with no unknown key` [tests/selftest.sh:2747-2759] |
| 24 | **the provisioner reads the generated file** | `bunker-provision.sh --config <out>/demo.conf --check`, with a stub `bunker` on `PATH` and `HOME` pointed at a scratch dir | the config parses and its paths resolve under that `HOME` | **PASS** — `PASS  config — demo.conf — 13 lines, KEY=VALUE only`; `..    resolved repo=… ref=main harness=hermes namespaces=demo (primary demo) ttl=6h`; and the `~` prefix expanded: `FAIL  inputs — not readable: GITHUB_TOKEN_FILE(<HOME>/.config/code-factory/demo/github.token) …`. Exit 1 came from the fixture (no token files, and the stub does not list `cf-node`), never from the config |

Transcript 1 — rows 1-6, literal (paths elided as `…`):

```
$ python3 scripts/bunker_config_gen.py --db …/happy.db --projects …/out --server cf-node
bunker-config-gen — db=…/happy.db out=…/out harness=hermes ref=main
  ..    scope — 3 of 3 registry rows selected
  PASS  project — demo — 3 lanes, 2 enabled, repo target …/repo-demo
  WARN  local_repo — REPO is the local path …/repo-demo — a remote node cannot clone it; pass --repo-url to override
  PASS  agent — cf-demo — unique across the run
  ..    token files are named as paths under ~/.config/code-factory/<project>/; no value is read or written
  ..    CRIER_URL, DUCKBRAIN_URL and NODE_ENV_FILE are host facts — add them per environment, not here
  PASS  wrote — …/out/demo.conf — 11 keys, sha256 f1226cb7623c
BUNKER-CONFIG: PASS — 1 config (1 written, 0 unchanged), 0 refused
$ # second run
  PASS  unchanged — …/out/demo.conf — byte-identical, sha256 f1226cb7623c
BUNKER-CONFIG: PASS — 1 config (0 written, 1 unchanged), 0 refused
$ # after: sed -i 's/TTL=6h/TTL=9h/' …/out/demo.conf ; then --check
  FAIL  drift — …/out/demo.conf — TTL: file '9h' ≠ registry '6h'
BUNKER-CONFIG: DRIFT (1 of 1 mismatched)
$ # write mode without --force, exit 1; then --force
  FAIL  drift — …/out/demo.conf — TTL: file '9h' ≠ registry '6h' — pass --force to rewrite
  PASS  rewrote — …/out/demo.conf — 11 keys, sha256 f1226cb7623c
```

The generated file, verbatim (row 1):

```
# bunker-provision config — generated from the scheduler registry by
# scripts/bunker_config_gen.py. Regenerate it; do not hand-edit.
AGENT=cf-demo
DUCKBRAIN_TOKEN_FILE=~/.config/code-factory/demo/duckbrain.token
GITHUB_TOKEN_FILE=~/.config/code-factory/demo/github.token
HARNESS=hermes
NAMESPACE=demo
PROJECT=demo
REF=main
REPO=…/repo-demo
S3_ENV_FILE=~/.config/code-factory/demo/s3.env
SERVER=cf-node
TTL=6h
```

Transcript 2 — rows 13-16 and 22, literal:

```
  FAIL  emptyrepo — repo_url is absent or empty in the registry
  FAIL  ghost — PHANTOM — repo_url names local:…/no-such-repo, and …/no-such-repo does not exist
  FAIL  group[alpha-beta, gamma-alpha] — AMBIGUOUS — no lane name or family key is a prefix of every lane in the group (alpha-beta, gamma-alpha) — refusing to guess
  FAIL  agent — 'cf-demo-alpha' derived by demo--alpha and demo-alpha — refusing to guess
BUNKER-CONFIG: REFUSED (5) — nothing written
$ # the same config with one operator-added key:
  FAIL  drift — …/out/demo.conf — obsolete key NAMESPACES
```

## 4. Metrics emitted — none, and why

**None.** The module has no counters, no timers, no histogram, no `--json` document and no output
format a scraper could parse: it prints human rows (`  <STATUS>  <name> — <detail>`) and three
headline verdicts, then exits [scripts/bunker_config_gen.py:133-143]. There is nothing to graph
because a run is one short read of a sqlite table followed by file writes — every quantity it could
report is already in a row.

What exists instead, and why it is not a metric:

| Surface | Where | Why it is not a metric |
|---|---|---|
| exit code `0` / `1` / `2` (ok / drift / refused) [scripts/bunker_config_gen.py:118-120] | the process | it is the only machine-readable signal; a monitor must branch on it, not scrape text |
| a `sha256` prefix, 12 hex [scripts/bunker_config_gen.py:146-147] | every `wrote` / `rewrote` / `unchanged` / `match` row | an identity, not a measurement — no unit, no series |
| `N config(s)`, `(W written, U unchanged)`, `N of M registry rows selected` [scripts/bunker_config_gen.py:553-554] [scripts/bunker_config_gen.py:468-471] | one note row and the headlines | counts of the current run only — no history, no timestamps, no labels |

## 5. Log lines it can generate

Everything goes to stdout, except that `--dry-run` moves every row to stderr so the config bodies on
stdout can be redirected into files [scripts/bunker_config_gen.py:127-131]
[scripts/bunker_config_gen.py:533-534]. There is no logging framework: the printable status is the
severity. **Kind** is *evidentiary* where the line carries something measured (a path, a registry
value, a digest, a child's exit) and *descriptive* where it restates a decision the module had
already made.

| Level | Line (verbatim) | Emitted when | Kind |
|---|---|---|---|
| — | `  {status}  {name} — {detail}` | every row; two spaces either side of the status [scripts/bunker_config_gen.py:133-135] | descriptive of the format |
| — | `  ..    {text}` | every note [scripts/bunker_config_gen.py:138-139] | descriptive |
| — | `bunker-config-gen — db={expand(opts.db)} out={outdir} harness={opts.harness} ref={opts.ref}` | always, first line [scripts/bunker_config_gen.py:536-539] | descriptive — restates the resolved flags |
| FAIL | `  FAIL  server — SERVER unset — a config names no host to provision on` | `--server` empty [scripts/bunker_config_gen.py:541-543] | descriptive |
| — | `BUNKER-CONFIG: REFUSED (1)` | the three early refusals (server, DB, scope) [scripts/bunker_config_gen.py:543] [scripts/bunker_config_gen.py:551] [scripts/bunker_config_gen.py:557] | descriptive — restates exit 2 |
| FAIL | `  FAIL  db — {exc}` | the registry cannot be opened, is not a file, has no `projects`, or lacks a column [scripts/bunker_config_gen.py:162-195] | evidentiary — carries the sqlite error text |
| — | `  ..    scope — {len(scope)} of {len(rows)} registry rows selected` | after scoping [scripts/bunker_config_gen.py:554] | evidentiary — the counts are the query's |
| FAIL | `  FAIL  scope — no registry row matches --project/--prefix` | the selectors matched nothing [scripts/bunker_config_gen.py:555-557] | descriptive |
| FAIL | `  FAIL  {lane} — repo_url is absent or empty in the registry` | a row with no `repo_url` [scripts/bunker_config_gen.py:214-215] [scripts/bunker_config_gen.py:566-568] | evidentiary |
| FAIL | `  FAIL  {lane} — PHANTOM — repo_url names {spelling}, and {path} does not exist` | a `local:`/`file:` path that is not a directory [scripts/bunker_config_gen.py:221-224] | evidentiary — names both spellings |
| FAIL | `  FAIL  {lane} — PHANTOM — repo_url names {spelling}, and {path} is not a directory` | a bare path that is not a directory [scripts/bunker_config_gen.py:228-232] | evidentiary |
| — | `  ..    {N} repo target(s) is a remote URL — existence is not verifiable offline, so REPO is written as the registry spells it` | at least one `scheme://` target [scripts/bunker_config_gen.py:578-582] | descriptive — states the limit of the check |
| PASS | `  PASS  project — {project} — {N} lane(s), {E} enabled, repo target {key}` | one row per derived project [scripts/bunker_config_gen.py:614-619] | evidentiary — the counts are the rows', `key` is the resolved target |
| FAIL | `  FAIL  group[{label}] — {AMBIGUOUS …} — refusing to guess` | no name prefixes every lane in the group [scripts/bunker_config_gen.py:259-263] [scripts/bunker_config_gen.py:590-592] | evidentiary |
| FAIL | `  FAIL  {project} — not a safe slug ([a-z0-9-], no edge hyphen, <=63 chars)` | the derived name fails `SLUG_RE` or is longer than 63 [scripts/bunker_config_gen.py:594-600] | evidentiary |
| FAIL | `  FAIL  {project} — two repo targets derive this name ({a} and {b}) — refusing to guess` | two clones, one project name [scripts/bunker_config_gen.py:602-609] | evidentiary |
| WARN | `  WARN  suffix — {lanes} — lane name carries a word that is not one of the nine fleet suffixes` | a lane that is neither the project nor `<project>-<one of nine>` [scripts/bunker_config_gen.py:620-631] | evidentiary — the nine are [scripts/bunker_config_gen.py:78-88] |
| WARN | `  WARN  local_repo — REPO is the local path {key} — a remote node cannot clone it; pass --repo-url to override` | the resolved target is a local directory [scripts/bunker_config_gen.py:632-638] | evidentiary |
| WARN | `  WARN  repo_disagreement — {lane} belongs to {family} ({other}) by name but names {repo} — one config per clone (CF-091)` | a lane whose family key is another project with a different clone [scripts/bunker_config_gen.py:644-657] | evidentiary — see §6: the name-collision refusal fires first for this shape |
| WARN | `  WARN  namespace — registry namespace_id={only} ({N} lane(s)) differs from the project name {project} — using the registry value` | every lane agrees on a namespace that is not the project name [scripts/bunker_config_gen.py:290-296] | evidentiary |
| WARN | `  WARN  namespace — no namespace_id on {N} lane(s) — using {project}` | no lane declares one [scripts/bunker_config_gen.py:297-300] | evidentiary of absence |
| WARN | `  WARN  namespace — lanes disagree: {name} ({N} lane(s)), … — using the project name {project}; set one namespace in the registry before provisioning` | the lanes spell more than one namespace [scripts/bunker_config_gen.py:301-308] | evidentiary |
| FAIL | `  FAIL  agent — '{agent}' derived by {a} and {b} — refusing to guess` | the lossy normalisation collides [scripts/bunker_config_gen.py:659-672] | evidentiary |
| PASS | `  PASS  agent — {AGENT} — unique across the run` | one owner per agent id [scripts/bunker_config_gen.py:679-680] | evidentiary |
| — | `  ..    token files are named as paths under ~/.config/code-factory/<project>/; no value is read or written` | always, before any mode [scripts/bunker_config_gen.py:683-686] | descriptive — and measured true (§3 rows 9-11) |
| — | `  ..    CRIER_URL, DUCKBRAIN_URL and NODE_ENV_FILE are host facts — add them per environment, not here` | always [scripts/bunker_config_gen.py:687-690] | descriptive |
| — | `BUNKER-CONFIG: REFUSED ({len(refusals)}) — nothing written` | any per-row refusal [scripts/bunker_config_gen.py:692-694] | descriptive |
| FAIL | `  FAIL  output_dir — {exc}` | the directory cannot be created or is not writable [scripts/bunker_config_gen.py:696-701] | evidentiary |
| — | `  ..    dry-run — nothing written; rows on stderr, configs on stdout` | `--dry-run` [scripts/bunker_config_gen.py:703-704] | descriptive |
| — | `BUNKER-CONFIG: DRY-RUN — {N} config(s) predicted` | `--dry-run` [scripts/bunker_config_gen.py:706] | descriptive |
| FAIL | `  FAIL  missing — {path} — no config; run without --check` | `--check`, file absent [scripts/bunker_config_gen.py:388-390] | evidentiary |
| FAIL | `  FAIL  unreadable — {path} — {exc}` | the read fails in either mode [scripts/bunker_config_gen.py:395-397] [scripts/bunker_config_gen.py:436-439] | evidentiary |
| FAIL | `  FAIL  drift — {path} — {reasons}` | `--check` measured a difference [scripts/bunker_config_gen.py:400-404] | evidentiary |
| FAIL | `  FAIL  drift — {path} — {reasons} — pass --force to rewrite` | write mode refused to overwrite [scripts/bunker_config_gen.py:444-453] | evidentiary |
| PASS | `  PASS  match — {path} — {len(values)} keys agree, sha256 {digest}` | `--check`, everything agrees [scripts/bunker_config_gen.py:407-411] | evidentiary |
| PASS | `  PASS  unchanged — {path} — byte-identical, sha256 {digest}` | write mode, bytes already equal [scripts/bunker_config_gen.py:440-442] | evidentiary |
| PASS | `  PASS  wrote — {path} — {len(values)} keys, sha256 {digest}` / `  PASS  rewrote — …` | new file / `--force` rewrite [scripts/bunker_config_gen.py:462-463] | evidentiary |
| FAIL | `  FAIL  unwritable — {path} — {exc}` | the atomic write failed [scripts/bunker_config_gen.py:456-460] | evidentiary |
| — | `obsolete key {key}` / `missing key {key}` / `{key}: file '{have}' ≠ registry '{want}'` | the three shapes inside `{reasons}` [scripts/bunker_config_gen.py:358-371] | evidentiary — both values are shown |
| — | `byte difference only (comments or key order)` | bytes differ, no key does [scripts/bunker_config_gen.py:401-402] [scripts/bunker_config_gen.py:447-448] | descriptive |
| — | `BUNKER-CONFIG: DRIFT ({drifted} of {len(configs)} mismatched)` | any drift in either mode [scripts/bunker_config_gen.py:412-414] [scripts/bunker_config_gen.py:465-467] | descriptive |
| — | `BUNKER-CONFIG: PASS — {N} checked, no drift` | `--check` green [scripts/bunker_config_gen.py:415-417] | descriptive |
| — | `BUNKER-CONFIG: PASS — {N} ({written} written, {unchanged} unchanged), 0 refused` | write mode green [scripts/bunker_config_gen.py:468-471] | descriptive |
| FAIL | `  FAIL  refused — {exc}` | an uncaught `Refused` at the top level [scripts/bunker_config_gen.py:713-720] | evidentiary |

## 6. Failure modes

Direction is the fail-open / fail-closed sense: what the failure does to the verdict, the exit
status, and — the part that matters here — **which clone, agent, namespace and credential path the
downstream provisioner then acts on**.

| Failure | Direction | Presents as | Distinguished from | Recovery |
|---|---|---|---|---|
| `repo_url` absent or empty | **fail-closed** — the row is refused, and a run with any refusal writes nothing [scripts/bunker_config_gen.py:37-38] | `FAIL  <lane> — repo_url is absent or empty in the registry`, exit 2 | a `local:` path that is missing says `PHANTOM` instead | fix the registry row; nothing was written |
| a `local:` path that does not exist | **fail-closed** | `FAIL  <lane> — PHANTOM — …` (§3 row 13) | an empty `repo_url` | correct the row or mount the path |
| no single name prefixes the group | **fail-closed** | `FAIL  group[…] — AMBIGUOUS — …` | a collision between two *groups*, which names both clones | rename the lanes so one prefix exists |
| derived name is not a slug, or > 63 chars | **fail-closed** | `FAIL  <project> — not a safe slug …` [scripts/bunker_config_gen.py:594-600] | `AMBIGUOUS`, which is about prefixes, not characters | rename the lane |
| two clones derive one project name | **fail-closed** | `FAIL  <project> — two repo targets derive this name (…)` | two projects deriving one *agent* | merge or rename in the registry |
| two projects derive one `AGENT` | **fail-closed** | `FAIL  agent — 'cf-demo-alpha' derived by demo--alpha and demo-alpha` (§3 row 16) | the name collision, which names the clones instead of the id | rename one project |
| output directory uncreatable / unwritable | **fail-closed** | `FAIL  output_dir — …`, exit 2, nothing written | a single unwritable file, which is `FAIL unwritable` and the run continues | create the directory, or point `--projects` elsewhere |
| an existing config differs and `--force` is absent | **fail-closed at the file, not at the run** | `FAIL  drift … — pass --force to rewrite`, exit 1, the file is left exactly as it was | `--check` on the same file, which is the same comparison without the write arm | inspect the named keys, then `--force` |
| `--check` against a config that is absent | **fail-closed** | `FAIL  missing — … run without --check`, exit 1 | drift, which names keys | write once without `--check` first |
| **the lanes disagree on `namespace_id`** | **fail-open** — exit 0 and a config is written | `WARN  namespace — lanes disagree: … using the project name <project>; set one namespace in the registry before provisioning`, then `PASS  wrote` [scripts/bunker_config_gen.py:301-308] | the agreement case, silent when the namespace equals the project name [scripts/bunker_config_gen.py:291-292] | set one `namespace_id` in the registry; until then the config names the **project**, which may match no lane's declared memory |
| **the selected rows decide the namespace** | **fail-open, scope-dependent** | the same project emits `NAMESPACE=twin` over the full family and `NAMESPACE=other` when scoped to `--project twin-qa` (§3 row 21), both exit 0 | a namespace disagreement, which at least prints a WARN | always generate with the same scope; an existing file is protected by the drift gate only until someone passes `--force` |
| **the registry namespace differs from the project name** | fail-open, loudly | `WARN  namespace — registry namespace_id=solo-memory (1 lane) differs from the project name solo — using the registry value` [scripts/bunker_config_gen.py:293-296] | no namespace at all, which also WARNs | none — the registry is the fact and the row says so |
| **`REPO` resolves to a local path** | **fail-open with a loud row** | `WARN  local_repo — REPO is the local path …; pass --repo-url to override`, then the config is written with that path [scripts/bunker_config_gen.py:632-638] [scripts/bunker_config_gen.py:322] | a remote URL, written as spelled with a note that its existence is unverifiable [scripts/bunker_config_gen.py:578-582] | pass `--repo-url <clone URL>`; a remote node cannot clone a control-host path |
| **an operator adds `NAMESPACES=` by hand** | **fail-closed, and lossy toward the provisioner** | `FAIL  drift — … — obsolete key NAMESPACES`; with `--force` the key is deleted (§3 row 22) — although the provisioner honours `NAMESPACES` and prefers it over `NAMESPACE` [scripts/bunker-provision.sh:62-67] [scripts/bunker-provision.sh:109-110] | `NAMESPACE`, which the generator owns | express multi-namespace projects in the registry, or stop regenerating that file; today the generator cannot emit a namespace list [scripts/bunker_config_gen.py:325] |
| **a lane whose family key is another project but whose clone differs (CF-091)** | **fail-closed, by a different row than the one written for it** | `FAIL  <project> — two repo targets derive this name (… and …) — refusing to guess` (measured) — **not** the `WARN  repo_disagreement` row [scripts/bunker_config_gen.py:644-657], because the name-collision refusal [scripts/bunker_config_gen.py:602-609] fires first and neither group reaches `projects` | the intended `repo_disagreement` WARN, which needs two *different* derived names | fix the registry `repo_url`; the run refuses rather than averaging the two clones |
| a config written with CRLF | **benign** | `--check` reports `match` — the file is read with universal newlines, so the parsed values are clean [scripts/bunker_config_gen.py:392-394]; nothing rewrites it, so the CRLFs stay | a byte-only difference, which is reported as such | none |
| a consumer that does not expand `~` in a `*_FILE` value | **depends on the reader** — correct for this pair, wrong for a new one | the emitted value is the literal `~/.config/code-factory/<project>/<leaf>` [scripts/bunker_config_gen.py:111] [scripts/bunker_config_gen.py:328-329]; `bunker-provision.sh` expands exactly that prefix at load [scripts/bunker-provision.sh:116-118] (measured, §3 row 24) | an absolute path, which needs no expansion | any new consumer must expand `~/` itself or it will read a literal filename |

## 7. Environment and settings it reads

Exactly one environment variable is read; nothing else in the file touches `os.environ` or `getenv`
(searched).

| Variable | Default | Effect if unset |
|---|---|---|
| `SCHEDULER_DB` | `~/.hermes/coding-hermes/scheduler.db` [scripts/bunker_config_gen.py:109] [scripts/bunker_config_gen.py:494] | `--db` falls back to that default path; a missing file is `FAIL db — scheduler database not found: …`, exit 2 |
| `HOME` | the caller's | used only by `os.path.expanduser` for `--db` and `--projects` [scripts/bunker_config_gen.py:150-151]; the three token keys keep the literal `~` prefix and are **not** expanded here [scripts/bunker_config_gen.py:111] |

Flags [scripts/bunker_config_gen.py:490-528]:

| Flag | Default | Meaning |
|---|---|---|
| `--db PATH` | `$SCHEDULER_DB`, else the default above [scripts/bunker_config_gen.py:494] | the registry, opened read-only |
| `--projects DIR` | `~/.config/code-factory` [scripts/bunker_config_gen.py:496-499] | output directory for `<project>.conf`; created unless `--check`/`--dry-run` [scripts/bunker_config_gen.py:478-487] [scripts/bunker_config_gen.py:696-697] |
| `--project NAME` (repeatable) | none | selects the lane *and its satellites* — `name == wanted` or it starts with `wanted + "-"` [scripts/bunker_config_gen.py:200-208] |
| `--prefix NAME` (repeatable) | none | the same selector, for a fleet-wide prefix |
| `--server HOST` | `""` [scripts/bunker_config_gen.py:514] | **required in effect**: empty is refused, because a config with no host provisions nothing [scripts/bunker_config_gen.py:541-544] |
| `--harness NAME` | `hermes` [scripts/bunker_config_gen.py:107] [scripts/bunker_config_gen.py:515] | the node's harness id |
| `--ref NAME` | `main` [scripts/bunker_config_gen.py:106] [scripts/bunker_config_gen.py:516] | the clone ref |
| `--ttl VALUE` | `6h` [scripts/bunker_config_gen.py:108] [scripts/bunker_config_gen.py:517] | passed through verbatim; the provisioner's own default is the same 6h [scripts/bunker-provision.sh:179] |
| `--repo-url URL` | `""` [scripts/bunker_config_gen.py:518-522] | overrides `REPO` for every project in the run — the escape hatch for a registry full of `local:` paths |
| `--force` | off [scripts/bunker_config_gen.py:523] | rewrite a differing config instead of reporting drift |
| `--check` | off [scripts/bunker_config_gen.py:524] | read-only drift comparison |
| `--dry-run` | off [scripts/bunker_config_gen.py:525-527] | print the configs, write nothing, rows to stderr |

Every key the generator writes, its source and its default — this is the whole file:

| Key | Source | Default / derivation |
|---|---|---|
| `PROJECT` | derived from the group's lane names: the shortest candidate (lane names plus their family keys) that prefixes every lane [scripts/bunker_config_gen.py:244-268] [scripts/bunker_config_gen.py:319] | none — a group that yields no single name is `AMBIGUOUS`, exit 2 |
| `AGENT` | `cf-` + the project lowercased, every run of `[^a-z0-9]` collapsed to `-` [scripts/bunker_config_gen.py:105] [scripts/bunker_config_gen.py:271-274] | none; uniqueness across the run is measured and refused on collision [scripts/bunker_config_gen.py:659-672] |
| `SERVER` | `--server` [scripts/bunker_config_gen.py:321] | empty → refusal, never a written blank [scripts/bunker_config_gen.py:541-544] |
| `REPO` | `--repo-url` if given, else the group's resolved clone target [scripts/bunker_config_gen.py:322] | the registry's `repo_url`, resolved: a `local:`/`file:` path (must exist), a bare path (must be a directory), or a `scheme://` URL written as spelled [scripts/bunker_config_gen.py:211-233] |
| `REF` | `--ref` [scripts/bunker_config_gen.py:323] | `main` [scripts/bunker_config_gen.py:106] |
| `HARNESS` | `--harness` [scripts/bunker_config_gen.py:324] | `hermes` [scripts/bunker_config_gen.py:107] |
| `NAMESPACE` | the registry's `namespace_id` when every selected lane agrees, else the project name plus a WARN [scripts/bunker_config_gen.py:277-308] [scripts/bunker_config_gen.py:325] | the project name [scripts/bunker_config_gen.py:298-308] |
| `TTL` | `--ttl` [scripts/bunker_config_gen.py:326] | `6h` [scripts/bunker_config_gen.py:108] |
| `GITHUB_TOKEN_FILE` | `TOKEN_DIR/<project>/github.token` [scripts/bunker_config_gen.py:112-116] [scripts/bunker_config_gen.py:328-329] | `~/.config/code-factory/<project>/github.token` [scripts/bunker_config_gen.py:111] |
| `DUCKBRAIN_TOKEN_FILE` | `TOKEN_DIR/<project>/duckbrain.token` [scripts/bunker_config_gen.py:114] | `~/.config/code-factory/<project>/duckbrain.token` |
| `S3_ENV_FILE` | `TOKEN_DIR/<project>/s3.env` [scripts/bunker_config_gen.py:115] | `~/.config/code-factory/<project>/s3.env` |

Keys the provisioner accepts that this module deliberately does **not** emit: `CRIER_URL`,
`DUCKBRAIN_URL`, `NODE_ENV_FILE` — host facts, named in a note instead of guessed
[scripts/bunker_config_gen.py:687-690] — plus `NAMESPACES`, `GIT_AUTHOR_*`, `CRIER_*_FILE` and the
`CONFIG_SET_*` scalars, none of which can be derived from the registry
[scripts/bunker-provision.sh:17-24].

## 8. Evidence of record

- **Measured 2026-11-05** in worktree `~/proj-wt-md-07f` at `6eea792`, Python 3.14.4, on the control
  host only. No bunker host, agent or node was touched; the provisioner was run only in its
  read-only `--check` mode, once, against the generated file.
- **Fixtures** (built by the driver in `$TMPDIR`, thrown away with it): `happy.db` (a 3-lane family
  on one clone, one lane disabled, one namespace), `bad.db` (a phantom path, an empty `repo_url`, an
  ambiguous pair, two clones whose names normalise to one agent id), `ns.db` (one project whose
  namespace differs from its name, one whose lanes disagree), `rd.db` (the CF-091 shape), plus
  `notable.db` and three real directories for the local targets.
- **The live registry was read, not written**: `--server cf-node --prefix code-factory --dry-run`
  against `~/.hermes/coding-hermes/scheduler.db` (880 rows, 17 selected, one config predicted,
  §3 row 19). The connection is `mode=ro` [scripts/bunker_config_gen.py:170], and `--dry-run`
  creates no directory [scripts/bunker_config_gen.py:478-481].
- **Re-runnable commands.** The battery leg, extracted so it can run alone:
  `sed -n '2659,2827p' tests/selftest.sh` into a wrapper defining `HERE`, `say` and `fails`
  → `LEG46 FAILS=0` (11 assertions, §3 row 23). It already covers what a reader would otherwise
  have to trust: the dry run creates nothing, the config has 11 sorted keys, `bunker-provision.sh`
  parses it with no unknown key, phantom / agent-collision / ambiguous are refused with nothing
  written, a second run is byte-identical, and `--check` names the drifted key without writing
  [tests/selftest.sh:2659-2827].
- **What the battery does not cover, measured here instead**: no credential-value leak (rows 9-11 —
  value classification, `strace` with 0 token opens in 525 traced lines, sentinel environment
  secrets absent), the live registry (row 19), the namespace-disagreement WARN (row 21 and the
  `ns.db` fixture), the unwritable output directory (row 17), the registry-level refusals (row 18),
  and the two contract edges in §6 (`NAMESPACES` as an obsolete key, scope-dependent `NAMESPACE`).
- **The question this document exists to answer — is a value ever written where a path belongs?**
  **No, measured.** The three credential keys are paths with the documented leaves, the file
  contains no secret-shaped literal, four sentinel secrets exported into the environment never
  appear in the bytes, and the process never opens a token file. The one value-shaped key is `REPO`
  — a clone target, not a credential — and a local path there is announced with a WARN
  [scripts/bunker_config_gen.py:632-638].
- **Defects found while measuring** (nothing was fixed; this task touches one document):

| # | Defect | Evidence |
|---|---|---|
| 1 | **An operator-added `NAMESPACES` is reported as an obsolete key, and `--force` deletes it.** The provisioner honours `NAMESPACES` as a comma list and prefers it over `NAMESPACE` [scripts/bunker-provision.sh:62-67] [scripts/bunker-provision.sh:109-110], but the generator's key set is closed [scripts/bunker_config_gen.py:92-104], so `differences()` calls the key obsolete [scripts/bunker_config_gen.py:365-366] and write mode refuses, then removes it under `--force` [scripts/bunker_config_gen.py:444-463]. A multi-namespace project therefore cannot survive regeneration, and the generator cannot express one — it emits a single `NAMESPACE` [scripts/bunker_config_gen.py:325] | measured (§3 row 22) |
| 2 | **The emitted `NAMESPACE` is a function of the scope, not of the project.** The agreement is computed over the *selected* rows only [scripts/bunker_config_gen.py:277-308] [scripts/bunker_config_gen.py:553], so one project emits `NAMESPACE=twin` with a disagreement WARN over its full family and `NAMESPACE=other` with a different WARN when scoped to a satellite — exit 0 in both cases, same output path. A first run scoped to a satellite writes a namespace no other lane declares; afterwards only the drift gate stands in the way, and `--force` walks through it | measured (§3 row 21) |
| 3 | **The `repo_disagreement` WARN is unreachable for the CF-091 shape.** When a lane's family key names another project but its `repo_url` names a different clone, both groups derive the same name, so the collision refusal [scripts/bunker_config_gen.py:602-609] fires first and neither group reaches `projects`; the loop written to print the WARN [scripts/bunker_config_gen.py:644-657] never sees them. The measured run produced `FAIL  proj — two repo targets derive this name (…) — refusing to guess` and no `WARN  repo_disagreement` row. Direction is safe — it refuses — but the operator is told about a name collision rather than the registry disagreement the row was written for | measured |
| 4 | **`--check` cannot distinguish a CRLF config from a clean one.** The file is read with universal newlines [scripts/bunker_config_gen.py:392-394], so a `\r\n` copy parses to the same values and is reported as `PASS  match … 11 keys agree, sha256 f1226cb7623c`, exit 0, with the LF digest; write mode then sees `text == wanted` and never normalises the file [scripts/bunker_config_gen.py:440-442]. Benign for a machine-written file, but "byte-identical" in that row is a claim about the decoded text, not the bytes | measured |
