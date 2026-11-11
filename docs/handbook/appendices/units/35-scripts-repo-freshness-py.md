# 35. scripts/repo_freshness.py

| Field | Value |
|---|---|
| Path | `~/code-factory/scripts/repo_freshness.py` — 662 lines [scripts/repo_freshness.py:1] |
| Repository | `code-factory` |
| Revision | `d8c7796` — the `origin/main` tip every locator below was measured against; the file's own last-touching commit is `5634d58` (2026-11-04, "feat(scripts): measure lane workdir staleness and refuse to dispatch past a bound (CF-212)") |
| Status | **VERIFIED — 151 locator citations (104 distinct file:line pairs across 7 files), all resolve; cites fact: FACT-01, FACT-09, FACT-10; the fetch/is-it-fresh question answered by measurement (§3 rows 4-6); eleven defects recorded in §8, the first of which is that this module produces none of the `checkout_freshness` rows it was credited with** |

## 1. Purpose and why it matters

- What it is: a **read-only measurement** of how far each lane workdir has drifted from its
  remote. Per workdir it resolves the checkout [scripts/repo_freshness.py:291-321], resolves the
  comparison ref [scripts/repo_freshness.py:200-280], fetches the backing remote **before**
  counting [scripts/repo_freshness.py:339-343], counts `git rev-list --left-right --count
  HEAD...<ref>` [scripts/repo_freshness.py:355-357], splits that into `ahead` and `lag`
  [scripts/repo_freshness.py:365-373] and prints one `PASS`/`WARN`/`FAIL` row
  [scripts/repo_freshness.py:506-534]. It writes nothing anywhere: no pull, no checkout, no ref
  beyond the fetch — the module is a probe, and the thing it protects is a dispatcher's decision,
  not a tree.
- Workdirs are enumerated from the scheduler's sqlite `projects` table with `enabled = 1`
  [scripts/repo_freshness.py:428-430], never from a hand-written list, so a lane added to the fleet
  is covered on the next run. Lanes that share one workdir are collapsed to one row that names
  every lane [scripts/repo_freshness.py:437-455] [scripts/repo_freshness.py:464-467].
  `--workdir PATH` bypasses the database entirely and never opens it
  [scripts/repo_freshness.py:606-616].
- Why it matters (what breaks if it is ABSENT): the scheduler dispatches control-host lanes into
  local workdirs that nothing refreshes, so a lane can work a tree months behind its remote
  [scripts/repo_freshness.py:4-9]. The board row that commissioned this script is still `pending`
  [.coding-hermes/board/tasks.jsonl:187], and its acceptance criterion 2 — "a refresh runs
  automatically before a lane dispatches" — has no implementation in this repo at all. Absence is
  therefore **cheap today**: nothing calls the script, so removing it changes no verdict anywhere
  (measured: the only in-tree reference that invokes it is the suite at [tests/selftest.sh:2095]).
  The other probe measures the node's checkout, not these trees — the foreman runs on the node
  (fact: FACT-01), so the control host's workdirs have no other measurer.
- Why it matters (what breaks if it LIES): the summary line is computed from the row counters, not
  from the measurement, and it prints `FRESHNESS: PASS` whenever **no row is `FAIL`**
  [scripts/repo_freshness.py:526-531]. Measured three ways on 2026-11-05: a single workdir with an
  empty path printed `FRESHNESS: PASS (0 measured, max lag 0)` and exited 0 (§3 row 11); a checkout
  whose `git` binary did not exist printed `PASS (0 measured, max lag 0)` and exited 0 (§3 row 12);
  and the real fleet printed `PASS (6 measured, max lag 0)` with **47 of 53 workdirs unmeasurable**
  (§3 row 9). A consumer that reads the last line — which is the line a dispatcher would read —
  is told the fleet is fresh when the probe measured almost nothing.
- The `FAIL`-to-exit-code conversion is opt-in: without `--gate` a stale workdir still exits 0
  [scripts/repo_freshness.py:45-46] [scripts/repo_freshness.py:532-534], and even **with**
  `--gate` a `WARN` row does not fail the run [scripts/repo_freshness.py:500-503]. Measured: an
  unreachable remote with `lag 0` under `--gate` printed `FRESHNESS: PASS` and exited 0 (§3 row 7).
  Only `--strict` converts the unmeasurable rows [scripts/repo_freshness.py:498-503].
- Scope, stated against the task's premise: this module does **not** produce the
  `FAIL checkout_freshness — sync — behind=26` line. That leg invokes a different script
  [scripts/verify-node.sh:122], and its `behind=` row is emitted by
  [scripts/node_freshness.py:343]. Every citation of this module elsewhere in the repo is a
  *comment* citing its doctrine [scripts/verify-node.sh:119] [scripts/node_freshness.py:7]. The
  quantity is the same — `behind` there is `git rev-list --count HEAD..<ref>`
  [scripts/node_freshness.py:445], `lag` here is the right-hand half of
  `git rev-list --left-right --count HEAD...<ref>` [scripts/repo_freshness.py:373] — but the
  producer is not this file. See §8 defect 1.

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `python3` | 3.14.4 measured here; the code needs only dataclasses, f-strings and `from __future__ import annotations` [scripts/repo_freshness.py:51] | control host, `PATH` | the shebang only [scripts/repo_freshness.py:1]; no version probe |
| `git` CLI | 2.53.0 measured here; needs `rev-parse --is-bare-repository` [scripts/repo_freshness.py:299], `rev-parse --show-toplevel` [scripts/repo_freshness.py:307], `rev-parse --absolute-git-dir` [scripts/repo_freshness.py:345], `fetch --quiet --no-tags` [scripts/repo_freshness.py:340] and `rev-list --left-right --count` [scripts/repo_freshness.py:355] | resolved once at import, `shutil.which("git") or "git"` [scripts/repo_freshness.py:66] | **misattributed**: with `git` off `PATH` every workdir reports `not a git workdir (…): FileNotFoundError: … 'git'` and the run still exits 0 with `FRESHNESS: PASS` — measured, §3 row 12 |
| `sqlite3` (stdlib module) | 3.46.1 measured | control host | import error at [scripts/repo_freshness.py:57] — a traceback, not a row |
| the scheduler database | 16.7 GB, 880 `projects` rows, 74 enabled, measured 2026-11-05 | `$CF_SCHEDULER_DB` or `~/.hermes/coding-hermes/scheduler.db` [scripts/repo_freshness.py:67-68] | named refusal, exit 2: `  FAIL  scheduler-db — scheduler database not found: …` [scripts/repo_freshness.py:414] [scripts/repo_freshness.py:632-635] |
| the `projects` table with `name`, `workdir` and `enabled` | measured: all three present, plus 70 other columns | inside that database | named refusals for a missing table or a missing column [scripts/repo_freshness.py:422-427] |
| one git remote per workdir | per workdir | inside each probed checkout | `WARN` row naming the absence, never a crash [scripts/repo_freshness.py:206-214] |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `argparse` | stdlib | `--workdir` is `action="append"` with `default=None` [scripts/repo_freshness.py:546-552]; `--no-fetch` is `dest="fetch", action="store_false"` so the default is `True` [scripts/repo_freshness.py:574-579] | a `default=[]` on `--workdir` would make `if opts.workdir:` true on a bare run and silently probe nothing |
| `sqlite3` | stdlib | `connect("file:{path}?mode=ro", uri=True)` — read-only, so a probe cannot write the scheduler's state [scripts/repo_freshness.py:418]; `timeout=15` seconds | a read-write connection would let a probe take a write lock on a 16.7 GB live database |
| `subprocess` | stdlib | `run(capture_output=True, text=True, timeout=…, check=False)`, with `TimeoutExpired` and `OSError` converted into results rather than exceptions [scripts/repo_freshness.py:116-132] | losing the timeout handler would hang a probe on a credential dialog or a dead remote; the 60 s default is the only bound [scripts/repo_freshness.py:591] |
| `concurrent.futures` | stdlib | `ThreadPoolExecutor(max_workers=jobs)` over the target list [scripts/repo_freshness.py:469-475], capped at `min(opts.jobs, len(targets))` | unbounded fan-out would run one `git fetch` per workdir at once; today the cap is 8 [scripts/repo_freshness.py:588] |
| `dataclasses` | stdlib | `Probe` carries both the measurement and the decided row [scripts/repo_freshness.py:151-190]; `as_dict` is the `--json` schema [scripts/repo_freshness.py:171-190] | renaming a field renames a JSON key consumers would parse |
| `datetime` | stdlib | `datetime.fromtimestamp(epoch, timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")` [scripts/repo_freshness.py:147-148] | the fetch timestamp is printed and emitted as UTC; a naive `fromtimestamp` would print local time without saying so |
| `os` | stdlib | `expanduser` on every path the user supplies [scripts/repo_freshness.py:291] [scripts/repo_freshness.py:412] [scripts/repo_freshness.py:618]; `stat().st_mtime` on `FETCH_HEAD` [scripts/repo_freshness.py:349] | `mtime` is the only clock this module has for "when did we last ask the remote" |
| `shutil` | stdlib | `which("git")` at import [scripts/repo_freshness.py:66] | a `PATH` set after import is invisible to the probe |
| `json` | stdlib | `json.dumps(payload, indent=2)` to **stdout** [scripts/repo_freshness.py:653] | nothing parses it in-tree; there is no writer (§4) |
| `sys` | stdlib | `sys.exit(main())` [scripts/repo_freshness.py:662] | the only exit path |
| `time` | stdlib | `time.time() - fetch_ts`, floored at 0 [scripts/repo_freshness.py:350] | a clock jump backwards is absorbed by the floor and prints as `0s` |

### 2c. Service contracts (both sides named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| **the workdir's git remote** — on this checkout, `origin` = `git@github.com:coding-hermes/code-factory.git`, `gh` = `https://github.com/coding-hermes/code-factory.git`, `worker` = the same as `origin` (measured, `git remote -v`) | probe → git server, one ref-only fetch per workdir | `git -C <root> fetch --quiet --no-tags <remote>` [scripts/repo_freshness.py:340], with the remote taken as the **first path component of the comparison ref** [scripts/repo_freshness.py:338] | no refspec: the remote's default fetch refspec, so `refs/remotes/<remote>/*` is what moves | the git server (GitHub over SSH/HTTPS) plus the local `.git` it writes. The comparison is made against `<remote>/<branch>`, never against the URL [scripts/repo_freshness.py:355-357] — so a failed fetch means the count is against the last refs that landed |
| the same, when the branch has an upstream | probe → git server | `@{u}` first, then `<remote>/<branch>`, then `<remote>/HEAD` for a detached HEAD [scripts/repo_freshness.py:245-273] | the ref name only | the checkout's own `branch.<name>.remote` / `.merge` config [scripts/repo_freshness.py:258-264]. When that upstream is a **local** branch the first path component is a branch name, and `git fetch main` is attempted — measured, it fails with `fatal: 'main' does not appear to be a git repository` (§8 defect 5) |
| **the scheduler's sqlite `projects` table** | probe ← database, read-only | `sqlite3.connect("file:…?mode=ro", uri=True)` [scripts/repo_freshness.py:418] | `select name, workdir from projects where enabled = 1 order by name` [scripts/repo_freshness.py:428-430] | the writer is the scheduler daemon, a different repo: `coding-hermes/scheduler`, `internal/database/projects.go`, `CreateProject` — which also refuses a second **enabled** project on the same workdir (case-insensitive). Nothing in code-factory writes this table; verified by grep, so the read side is the only side in this repo |
| **the operator / dispatcher** | probe → caller | stdout rows and the exit code [scripts/repo_freshness.py:506-534]; `--json` on stdout [scripts/repo_freshness.py:640-656] | one row per workdir, one summary line, one `FRESHNESS:` verdict | no in-tree caller. The documented invocation is the header's `scripts/repo_freshness.py --gate \|\| exit 1` [scripts/repo_freshness.py:37]; the only executed caller is the suite [tests/selftest.sh:2140]. The dispatcher this was written for does not exist yet (§8 defect 2) |

## 3. Verification

Both the module's own fixture and live runs. The repository suite pins the behaviour that matters —
the bound is policy, `--no-fetch` makes no network call, a failed fetch is named, `--strict`
escalates, an absent database fails closed [tests/selftest.sh:2089-2229] — and all thirteen of its
legs pass (§3 row 13, transcript 5). Everything else below was run against a scratch tree this task
owns, plus this checkout.

| # | Check | Command | Expected | Last run | Result |
|---|---|---|---|---|---|
| 1 | live checkout, no network | `python3 -B scripts/repo_freshness.py --workdir ~/code-factory --no-fetch` | `PASS`, exit 0 | 2026-11-05 | **PASS** — `PASS  code-factory — lag 0, ahead 2, main vs gh/main, last fetch 58s ago` |
| 2 | live checkout, fetch on | the same without `--no-fetch` | the fetch moves the refs, so `ahead` changes | 2026-11-05 | **PASS** — `ahead 2` became `ahead 0` and `last fetch 0s ago`; the row changed because the fetch moved `gh/main`, not because anything else did |
| 3 | gate on the live checkout | `--workdir ~/code-factory --no-fetch --gate --max-fetch-age 60` | exit 0 while fresh | 2026-11-05 | **PASS** — exit 0 |
| 4 | **does the fetch change the number?** | scratch: clone, then advance the remote by 3 commits without telling the clone, then run `--no-fetch` and then the default | `--no-fetch` must report the stale world, the default must report 3 | 2026-11-05 | **PASS — and this is the module's whole value.** `--no-fetch` → `PASS … lag 0` (the ref was 3 commits stale); default → `FAIL … lag 3 > bound 0`. Transcript 2 |
| 5 | remote unreachable, `lag > bound` | move the bare remote away, run the default | `FAIL` naming both the lag and the fetch error | 2026-11-05 | **PASS** — `FAIL  stale — lag 2 > bound 0 …; fetch failed: fatal: '…/origin.git' does not appear to be a git repository`, exit 0 without `--gate` |
| 6 | remote unreachable, `lag == 0` | the same on a clone that matches its last-known ref | must not claim freshness | 2026-11-05 | **FAIL (design)** — `WARN  fresh — lag 0, ahead 0 … ; fetch failed: …` and then `FRESHNESS: PASS`, exit 0. The WARN names it; the verdict does not (§8 defect 3) |
| 7 | the same under `--gate` | `--gate` on that WARN row | non-zero, because freshness is unproven | 2026-11-05 | **FAIL (design)** — `FRESHNESS: PASS (1 measured, max lag 0)`, exit 0 |
| 8 | `--strict` on the same | `--strict` | escalates | 2026-11-05 | **PASS** — `FAIL  fresh — strict: … fetch failed: …`, and the suite measures `7 FAIL, exit 1` on its six WARN rows [tests/selftest.sh:2199-2205] |
| 9 | the real fleet, no network | `python3 -B scripts/repo_freshness.py --no-fetch --jobs 8` | rows for every enabled project's workdir | 2026-11-05 | **PASS as a measurement, FAIL as a verdict** — 74 enabled projects → 53 unique workdirs, **6 measured, 47 unmeasurable**, `FRESHNESS: PASS (6 measured, max lag 0)`, exit 0. Transcript 3 |
| 10 | DB enumeration and dedupe | suite fixture, 10 rows / 9 enabled / 8 workdirs | `9 enabled projects, 8 unique workdirs`, disabled row skipped, `[2 lanes: …]` | 2026-11-05 | **PASS** [tests/selftest.sh:2164-2170] |
| 11 | empty workdir path | `--workdir "  "` | a row, and not a `PASS` verdict | 2026-11-05 | **FAIL (design)** — `WARN  . — project row has an empty workdir`, `FRESHNESS: PASS (0 measured, max lag 0)`, exit 0 |
| 12 | `git` absent from `PATH` | `env PATH=/nonexistent /usr/bin/python3 -B … --workdir ~/code-factory` | a named dependency failure | 2026-11-05 | **FAIL (design)** — `WARN  code-factory — not a git workdir (…): FileNotFoundError: … 'git'`, `PASS (0 measured)`, exit 0 |
| 13 | the repository suite, this module's section | lines 2089-2229 extracted verbatim and run standalone | every leg `PASS` | 2026-11-05 | **PASS** — 13 legs, `fails=0`, exit 0. Transcript 5 |
| 14 | bad argument | `--bound -1` | a named refusal, exit 2 | 2026-11-05 | **PASS on the exit code, misattributed on the row** — `  FAIL  scheduler-db — --bound must be >= 0, got -1`, exit 2 (§8 defect 7) |
| 15 | a branch whose upstream is a local branch | scratch: `branch --set-upstream-to=main` on a lane branch | a comparison against a remote | 2026-11-05 | **FAIL (design)** — `WARN  w — … fetch failed: fatal: 'main' does not appear to be a git repository`, compared `local-copy vs main`, exit 0 (§8 defect 5) |
| 16 | inherited `GIT_DIR` | `GIT_DIR=<other repo>/.git` while probing repo `a` | repo `a` is what is measured | 2026-11-05 | **FAIL (design)** — the row is named `a` and carries repo `b`'s state (`no git remote configured`), exit 0 (§8 defect 8) |
| 17 | a real dispatch refusal | — | a dispatcher refuses the tick | never | **not run** — no dispatcher invokes the script anywhere in this repo (§8 defect 2) |

Transcript 1 (rows 1-3), literal:

```
$ python3 -B scripts/repo_freshness.py --workdir ~/code-factory --no-fetch
repo-freshness — 1 explicit workdir, bound 0, fetch off
  PASS  code-factory — lag 0, ahead 2, main vs gh/main, last fetch 58s ago (2026-11-05T16:53:51Z)
repo-freshness: 1 workdir, 1 measured (1 fresh, 0 failed), 0 unmeasurable, 0 fetch errors (bound 0, fetch off, max lag 0, report)
FRESHNESS: PASS (1 measured, max lag 0)
EXIT=0
$ python3 -B scripts/repo_freshness.py --workdir ~/code-factory
repo-freshness — 1 explicit workdir, bound 0, fetch on
  PASS  code-factory — lag 0, ahead 0, main vs gh/main, last fetch 0s ago (2026-11-05T16:54:54Z)
repo-freshness: 1 workdir, 1 measured (1 fresh, 0 failed), 0 unmeasurable, 0 fetch errors (bound 0, fetch on, max lag 0, report)
FRESHNESS: PASS (1 measured, max lag 0)
EXIT=0
```

Transcript 2 (row 4) — the decisive one. The remote advanced three commits; the clone's
`origin/main` still pointed at the old tip, so `--no-fetch` measures a world that no longer exists:

```
local origin/main before any fetch: 4881ca5
remote main actually at:            86fcb15

$ python3 -B scripts/repo_freshness.py --workdir $T/w --no-fetch --jobs 1
repo-freshness — 1 explicit workdir, bound 0, fetch off
  PASS  w — lag 0, ahead 0, main vs origin/main, last fetch never (no FETCH_HEAD)
repo-freshness: 1 workdir, 1 measured (1 fresh, 0 failed), 0 unmeasurable, 0 fetch errors (bound 0, fetch off, max lag 0, report)
FRESHNESS: PASS (1 measured, max lag 0)
EXIT=0

$ python3 -B scripts/repo_freshness.py --workdir $T/w --jobs 1
repo-freshness — 1 explicit workdir, bound 0, fetch on
  FAIL  w — lag 3 > bound 0 (main vs origin/main), ahead 0, last fetch 0s ago (2026-11-05T16:55:48Z)
repo-freshness: 1 workdir, 1 measured (0 fresh, 1 failed), 0 unmeasurable, 0 fetch errors (bound 0, fetch on, max lag 3, report)
FRESHNESS: FAIL (1 of 1 workdirs, max lag 3)
EXIT=0

local origin/main after the fetch:  86fcb15
git rev-list --count HEAD..origin/main : 3
```

Transcript 3 (row 9), the fleet as it actually is — 74 enabled projects, 53 unique workdirs, and a
`PASS` verdict over six of them:

```
$ python3 -B scripts/repo_freshness.py --no-fetch --jobs 8
repo-freshness — db ~/.hermes/coding-hermes/scheduler.db, 74 enabled projects, 53 unique workdirs, bound 0, fetch off
  WARN  bunker-docs — not a git workdir (~/.hermes/stand-in/docs/bunker): fatal: not a git repository (or any of the parent directories): .git
  PASS  bunker-foreman — lag 0, ahead 0, main vs origin/main, last fetch 21m ago (2026-11-05T16:34:30Z)
  PASS  code-factory — lag 0, ahead 0, main vs gh/main, last fetch 33s ago (2026-11-05T16:54:54Z) [16 lanes: code-factory, code-factory-docs, code-factory-dogfood, code-factory-duckbrain, code-factory-duckbrain-dogfood, code-factory-duckbrain-pm, code-factory-duckbrain-qa, code-factory-duckbrain-releng, code-factory-duckbrain-sync, code-factory-ops, code-factory-perf, code-factory-pm, code-factory-readme, code-factory-releng, code-factory-review, code-factory-sync]
  …
repo-freshness: 53 workdirs, 6 measured (6 fresh, 0 failed), 47 unmeasurable, 0 fetch errors (bound 0, fetch off, max lag 0, report)
FRESHNESS: PASS (6 measured, max lag 0)
EXIT=0
```

Transcript 4 (rows 5-8, 11, 12, 14-16), literal rows and exit codes:

```
$ python3 -B … --workdir $T/stale            # remote moved away, lag 2
  FAIL  stale — lag 2 > bound 0 (trunk vs origin/trunk), ahead 0, last fetch 0s ago (2026-11-05T16:55:06Z); fetch failed: fatal: '$T/origin.git' does not appear to be a git repository
EXIT=0
$ python3 -B … --workdir $T/fresh            # remote moved away, lag 0
  WARN  fresh — lag 0, ahead 0, trunk vs origin/trunk, last fetch 0s ago (2026-11-05T16:55:06Z); fetch failed: fatal: '$T/origin.git' does not appear to be a git repository
FRESHNESS: PASS (1 measured, max lag 0)
EXIT=0
$ python3 -B … --workdir $T/fresh --strict
  FAIL  fresh — strict: lag 0, ahead 0, trunk vs origin/trunk, last fetch 0s ago (2026-11-05T16:55:06Z); fetch failed: fatal: '$T/origin.git' does not appear to be a git repository
EXIT=0
$ python3 -B … --workdir "  "
  WARN  . — project row has an empty workdir
FRESHNESS: PASS (0 measured, max lag 0)
EXIT=0
$ env PATH=/nonexistent /usr/bin/python3 -B … --workdir ~/code-factory
  WARN  code-factory — not a git workdir (~/code-factory): FileNotFoundError: [Errno 2] No such file or directory: 'git'
FRESHNESS: PASS (0 measured, max lag 0)
EXIT=0
$ python3 -B … --bound -1
  FAIL  scheduler-db — --bound must be >= 0, got -1
FRESHNESS: FAIL (config: --bound must be >= 0, got -1)
EXIT=2
$ python3 -B … --workdir $T/w                # branch tracks the LOCAL branch 'main'
  WARN  w — lag 0, ahead 0, local-copy vs main, last fetch 0s ago (2026-11-05T16:55:17Z); fetch failed: fatal: 'main' does not appear to be a git repository
FRESHNESS: PASS (1 measured, max lag 0)
EXIT=0
$ GIT_DIR=$T/b/.git python3 -B … --workdir $T/a
  WARN  a — no git remote configured ($T/a tracks nothing); lag is unknowable
FRESHNESS: PASS (0 measured, max lag 0)
EXIT=0
```

Transcript 5 (row 13), the repository suite's own legs for this module, extracted verbatim:

```
41. repo freshness probe measures lag per workdir and refuses beyond the bound (CF-212)
  PASS  scripts/repo_freshness.py parses (python3 -B, stdlib only)
  PASS  workdir behind 2 commits -> one FAIL naming lag 2, --gate exit 1
  PASS  a non-main default branch (trunk) is measured against origin/trunk
  PASS  detached HEAD, no remote, non-git, bare, missing and non-directory workdirs -> 6 named WARN rows, no crash
  PASS  workdirs enumerated from the DB: 9 enabled projects, 8 unique workdirs, disabled project skipped
  PASS  the same workdir clears --bound 5 (bound is policy, not a constant), exit 0
  PASS  one workdir probes on its own (--workdir) and refuses, exit 1
  PASS  --no-fetch measured lag 2 with the remote absent: no network call, exit 0 without --gate
  PASS  with the remote absent a fetch names the failure instead of inventing freshness
  PASS  --strict escalates the 6 unmeasurable rows: 7 FAIL, exit 1
  PASS  --json is parseable, lists 8 workdirs, and two runs agree (idempotent)
  PASS  an absent scheduler DB is a named FAIL, exit 2
RESULT: fails=0
EXIT=0
```

## 4. Metrics emitted

**None.** The module writes no counter, no status file, no metric and no log to disk: the only
outputs are stdout rows [scripts/repo_freshness.py:506-534] and the optional `--json` object, which
is printed and then forgotten [scripts/repo_freshness.py:640-656]. There is no file write anywhere
in the module. `FETCH_HEAD` is read, never written by this code, and it belongs to git — it is
also repo-global rather than per-remote, so the "last fetch" column can be another tool's fetch
(§8 defect 6).

Consequences, stated as what cannot be answered: how stale the fleet was yesterday, which workdirs
have been persistently behind, how long a fetch takes, and whether the bound has ever fired in
production — all four are unanswerable, because nothing is persisted and nothing consumes the rows.
The only durable evidence a run leaves is the operator's terminal. A countable version would need
one row per workdir carrying `lag`, `fetch_age_s` and the exit code into a store; the JSON already
has the fields [scripts/repo_freshness.py:171-190], and no writer exists.

## 5. Log lines it can generate

All output is stdout; there is no logging framework, so the `  PASS`/`  WARN`/`  FAIL` prefix is the
only severity. **Kind** is assigned as: *evidentiary* = the line reports the result of a git command
that actually ran and could have failed; *descriptive* = narration, or an aggregate restatement of
values the module already decided, with nothing measured behind it.

| Level | Line (verbatim) | Emitted when | Kind |
|---|---|---|---|
| stdout | `repo-freshness — {n} explicit workdir{s}, bound {bound}, fetch {on\|off}` | `--workdir` mode, before any probe [scripts/repo_freshness.py:612-616] | descriptive |
| stdout | `repo-freshness — db {path}, {p} enabled projects, {w} unique workdirs, bound {bound}, fetch {on\|off}` | database mode [scripts/repo_freshness.py:626-631] | descriptive |
| stdout | `  {status}  {name} — {value}` | one per workdir, after every probe [scripts/repo_freshness.py:509] | evidentiary — the value is a measurement or a named defect |
| stdout | `lag {lag}, ahead {ahead}, {branch} vs {target_ref}, {fetch_text}` | the measurement part of a `PASS`/`WARN` row [scripts/repo_freshness.py:381] | evidentiary — from `rev-list` and `FETCH_HEAD` |
| stdout | `lag {lag} > bound {bound} ({branch} vs {target_ref}), ahead {ahead}, {fetch_text}` | `lag > --bound` [scripts/repo_freshness.py:386-389] | evidentiary |
| stdout | `; fetch failed: {error}` | a fetch returned non-zero, appended to whichever row the workdir earned [scripts/repo_freshness.py:390-391] [scripts/repo_freshness.py:397] | evidentiary — the command's first error line, truncated to 200 chars [scripts/repo_freshness.py:93-98] |
| stdout | `; detached HEAD cannot be pushed or fast-forwarded` | attached branch absent and the lag is within bound [scripts/repo_freshness.py:399-403] | descriptive — a policy statement about the state |
| stdout | `last fetch {age} ago ({iso_utc})` | `FETCH_HEAD` exists [scripts/repo_freshness.py:377-380] | evidentiary of an `mtime`, not of the remote |
| stdout | `last fetch never (no FETCH_HEAD)` | the file is absent [scripts/repo_freshness.py:375-376] | evidentiary |
| stdout | `last fetch {age}s > max {max}s ({iso_utc}), lag {lag}` | `--max-fetch-age` exceeded [scripts/repo_freshness.py:494-497] | evidentiary |
| stdout | `strict: {value}` | `--strict` escalated a `WARN` [scripts/repo_freshness.py:500-503] | descriptive |
| stdout | `repo-freshness: {n} workdirs, {m} measured ({p} fresh, {f} failed), {w} unmeasurable, {e} fetch errors (bound {b}, fetch {on\|off}, max lag {L}, {gate\|report})` | end of every run [scripts/repo_freshness.py:519-524] | descriptive — counters over rows |
| stdout | `FRESHNESS: FAIL ({n} of {N} workdirs, max lag {L})` | at least one `FAIL` [scripts/repo_freshness.py:526-529] | descriptive |
| stdout | `FRESHNESS: PASS ({m} measured, max lag {L})` | **no** `FAIL` row — including when `m` is 0 [scripts/repo_freshness.py:530-531] | descriptive, and measured false as a freshness claim (§3 rows 6, 9, 11, 12) |
| stdout | `  FAIL  scheduler-db — {config_error}` | an argument or database error, whatever the argument was [scripts/repo_freshness.py:632-633] | evidentiary of the error, misattributed to the database |
| stdout | `FRESHNESS: FAIL (config: {error})` | the same [scripts/repo_freshness.py:634] | descriptive |
| stdout | `project row has an empty workdir` | the row's workdir is blank [scripts/repo_freshness.py:289] | evidentiary |
| stdout | `workdir does not exist: {path}` | `os.path.exists` false [scripts/repo_freshness.py:293] | evidentiary |
| stdout | `workdir is not a directory: {path}` | a file was passed [scripts/repo_freshness.py:295] | evidentiary |
| stdout | `bare repository at {path}: a lane cannot dispatch from a tree with no worktree` | `--is-bare-repository` is true [scripts/repo_freshness.py:299-305] | evidentiary |
| stdout | `not a git workdir ({path}): {error}` | `--show-toplevel` failed — **also** what a missing `git` binary looks like [scripts/repo_freshness.py:307-313] | evidentiary, misattributed when `git` is absent |
| stdout | `repository has no commits yet at {root}: {error}` | unborn HEAD [scripts/repo_freshness.py:315-321] | evidentiary |
| stdout | `no git remote configured ({root} tracks nothing); lag is unknowable` | `git remote` is empty [scripts/repo_freshness.py:206-214] | evidentiary |
| stdout | `branch {branch!r} has no upstream and no {remote}/{branch} exists (remotes: …)` | no `@{u}` and no same-named remote branch [scripts/repo_freshness.py:274-279] | evidentiary |
| stdout | `detached HEAD at {branch} and no {remote}/HEAD to compare against (remotes: …)` | detached with no remote default branch [scripts/repo_freshness.py:237-242] | evidentiary |
| stdout | `cannot count commits between HEAD and {target}: {error}` | `rev-list` failed [scripts/repo_freshness.py:358-364] | evidentiary |
| stdout | `unexpected rev-list output {text!r} for HEAD...{target}` | `rev-list` printed anything but two integers [scripts/repo_freshness.py:366-372] | evidentiary |
| stdout | `[{n} lanes: {names}]` | more than one enabled project shares the workdir [scripts/repo_freshness.py:465-467] | descriptive |

## 6. Failure modes

Direction is the fail-open / fail-closed sense: what the failure does to the verdict and the exit
code.

| Failure | Direction | Presents as | Distinguished from | Recovery |
|---|---|---|---|---|
| The remote is unreachable and `lag > bound` | **fail-closed, but on a stale number** | `FAIL … lag N > bound 0 …; fetch failed: …`, exit 1 only with `--gate` (§3 row 5) | a reachable remote prints no `fetch failed:` clause | the row names the fetch error; re-run when the remote answers, because `N` is the last refs' count and the remote may already be further ahead |
| The remote is unreachable and `lag <= bound` | **fail-open** | `WARN … ; fetch failed: …`, then `FRESHNESS: PASS`, exit 0 — even under `--gate` (§3 rows 6-7) | `--strict` turns it into `FAIL` (§3 row 8) | run with `--strict` if a gate must refuse on "unproven"; otherwise treat `PASS` as "nothing known to be stale" |
| **Nothing was measurable at all** | **fail-open, worst case** | `FRESHNESS: PASS (0 measured, max lag 0)`, exit 0 — an empty workdir, or no `git` on `PATH` (§3 rows 11-12) | a real fleet run still prints `0 failed` but names its measured count | read the `{m} measured` figure, not the verdict; a gate needs `--strict` |
| The fleet's workdirs are mostly not git repos | **fail-open by scale** | 47 `WARN not a git workdir` rows and a `PASS` verdict over 6 (§3 row 9) | a genuine non-git workdir and a stand-in directory look identical on the row | fix the workdirs (the stand-in tree is not a checkout) or accept that this probe covers six trees, not 53 |
| `git` is not on `PATH` | **fail-open and misattributed** | `not a git workdir (…): FileNotFoundError … 'git'`, `PASS (0 measured)`, exit 0 (§3 row 12) | a real non-git directory prints `fatal: not a git repository …` instead | install `git` or fix `PATH`; the tell is the exception class in the row |
| A branch's upstream is a local branch | **fail-open** | the row compares against the local branch (`local-copy vs main`) and the fetch fails on `'main' does not appear to be a git repository` (§3 row 15) | a remote-tracking comparison prints `<remote>/<branch>` | set a real upstream; the row never says the comparison is local |
| `GIT_DIR` (or any git variable) is exported in the caller's environment | **misattributed measurement** | the row is named for the workdir and carries another repository's state (§3 row 16) | the path in the message is right and the state is wrong — nothing on the row reveals it | unset the git environment for the probe; `git_env()` copies `os.environ` wholesale [scripts/repo_freshness.py:103] |
| A workdir is missing, a file, bare, non-git, unborn, detached or remote-less | fail-safe by design | one named `WARN` row each, no crash, exit 0 [scripts/repo_freshness.py:288-321] | a stale workdir is `FAIL`, not `WARN` | act on the row; `--strict` if "unknown" must refuse |
| The scheduler database is absent or unreadable | fail-closed | `  FAIL  scheduler-db — scheduler database not found: …`, exit 2 [scripts/repo_freshness.py:413-420] | `--workdir` mode never opens the database, so it succeeds in the same environment | fix the path or `$CF_SCHEDULER_DB`; nothing was measured |
| A bad argument (`--bound -1`, `--jobs 0`) | fail-closed, mislabelled | `  FAIL  scheduler-db — --bound must be >= 0, got -1`, exit 2 [scripts/repo_freshness.py:632-635] | a real database failure names the path | none needed; the row's *name* is wrong, not its verdict |
| One `git` command exceeds `--timeout` (default 60 s) | fail-safe per workdir | the command becomes a timeout result [scripts/repo_freshness.py:128-129] and the workdir earns `not a git workdir` or `cannot count commits … timeout after 60s` | a slow remote that answers inside the bound prints a normal row | raise `--timeout`; a 53-workdir run at `--jobs 8` can spend eight timeouts at once |
| The fetch succeeds but the comparison ref does not exist | fail-safe | `branch … has no upstream and no <remote>/<branch> exists …`, `WARN`, not a crash [scripts/repo_freshness.py:274-279] | a `lag 0` row means the ref resolved | the row names the missing ref and the remotes it looked at |

## 7. Environment and settings it reads

| Variable | Default | Effect if unset |
|---|---|---|
| `CF_SCHEDULER_DB` | `~/.hermes/coding-hermes/scheduler.db` [scripts/repo_freshness.py:67-68] | the default is used; a wrong default is `FAIL scheduler-db`, exit 2 [scripts/repo_freshness.py:414] |
| `GIT_TERMINAL_PROMPT` | **forced to `0`** [scripts/repo_freshness.py:106] | not unset by the probe — it is overwritten, so a probe can never block on a credential prompt |
| `GIT_SSH_COMMAND` | the caller's value, else `ssh -o BatchMode=yes -o ConnectTimeout=10` [scripts/repo_freshness.py:107-108] | the fallback is used: a dead host fails in ~10 s instead of hanging |
| `LC_ALL`, `LANG` | forced to `C` [scripts/repo_freshness.py:109-110] | git messages are parsed in a fixed locale, so `first_err()` text is stable |
| `PATH` | inherited | decides whether `git` exists at all [scripts/repo_freshness.py:66]; a missing `git` degrades every row to `not a git workdir` and the verdict to `PASS` |
| `HOME` | inherited | `~` in `--workdir` and `--db` is expanded by `os.path.expanduser` [scripts/repo_freshness.py:291] [scripts/repo_freshness.py:412] |
| `GIT_DIR`, `GIT_WORK_TREE`, `GIT_INDEX_FILE` | inherited, **not defended** [scripts/repo_freshness.py:103] | an exported value silently redirects every measurement to another repository (§3 row 16) |
| `TMPDIR` | not read | nothing is written to a temporary path; the module creates no files |

Settings that are flags rather than variables, with the defaults on the line that declares them:
`--bound` `0` — any commit behind is stale [scripts/repo_freshness.py:558-563]; `--gate` off
[scripts/repo_freshness.py:564-568]; `--strict` off [scripts/repo_freshness.py:569-573]; `--fetch`
on, and `--no-fetch` turns it off [scripts/repo_freshness.py:574-579]; `--max-fetch-age` `None`
(off) [scripts/repo_freshness.py:580-586]; `--jobs` `8` [scripts/repo_freshness.py:587-589];
`--timeout` `60` s per git command [scripts/repo_freshness.py:590-592]; `--include-disabled` off
[scripts/repo_freshness.py:553-557]. Exit codes: `0` ok, `1` gate failed, `2` config error
[scripts/repo_freshness.py:70-72].

## 8. Evidence of record

- **Measured 2026-11-05** in a worktree of `d8c7796` (`~/proj-wt-md-35d`) against Python 3.14.4,
  git 2.53.0 and sqlite 3.46.1. The two live runs (rows 1-3) touched this checkout only; every
  destructive leg used a scratch tree under `~/.hermes/cache/scratch` with a bare repository this
  task created, and `GIT_CONFIG_GLOBAL=/dev/null`. Per fact: FACT-10, each row above is a
  re-runnable command with its own transcript, not a commit message.
- **The question the task asked, answered.** (a) `behind` in the `checkout_freshness` row is
  `git rev-list --count HEAD..<ref>` against a **remote-tracking ref** [scripts/node_freshness.py:445],
  and this module's `lag` is the same count read from the right-hand side of
  `rev-list --left-right --count HEAD...<ref>` [scripts/repo_freshness.py:373] — measured equal on
  the same tree (§3 transcript 2: `lag 3`, `rev-list --count` 3). (b) **Yes, it fetches before
  comparing**, by default, once per workdir, of the remote that backs the comparison ref
  [scripts/repo_freshness.py:336-343] — and the fetch is what makes the number mean anything:
  without it the same tree reported `lag 0` while sitting three commits behind (§3 row 4).
  (c) **When the remote is unreachable** it keeps counting from the refs it already has and names
  the failure on the row (`; fetch failed: …`); the verdict stays `WARN` if the stale count is
  within the bound and `FAIL` if it is not. The `WARN` case still prints `FRESHNESS: PASS` and
  exits 0, with or without `--gate`.
- **The premise corrected.** `verify-node.sh`'s `checkout_freshness` leg runs
  [scripts/verify-node.sh:122] — `node_freshness.py`, not this file — and the
  `FAIL … sync — behind=26` shape is that script's row [scripts/node_freshness.py:343]. This module
  has no production caller: grep over `*.sh`, `*.py`, `*.md`, `*.yaml` and `*.toml` finds it invoked
  only by [tests/selftest.sh:2095], and it appears elsewhere only in prose
  [scripts/verify-node.sh:119] [scripts/node_freshness.py:7] [docs/ACCEPTANCE-PLAN.md:148]. The
  commissioning row is still `pending` [.coding-hermes/board/tasks.jsonl:187]. So the output is
  **not** load-bearing in any live verdict today, and a live `behind=26` is evidence about
  `node_freshness.py`, not about this module.
- **The scale it actually covers.** On the live database: 74 enabled projects, 53 unique workdirs,
  6 measured, 47 unmeasurable, `PASS`, exit 0 (§3 row 9). The 47 are stand-in directories under
  `~/.hermes/stand-in/` that are not git checkouts at all, so the probe the board row asked for
  ("the 74 /home/kara workdirs and the 45 stand-in workdirs") covers six trees in practice.
- **Defects found while measuring** (out of scope for this task; nothing was fixed):

| # | Defect | Evidence |
|---|---|---|
| 1 | **This module is credited with output it does not produce.** The `checkout_freshness` verdict comes from a different script, and nothing in the repo or the fleet config invokes `repo_freshness.py`. A reader who trusts the attribution concludes a dispatcher is protected by a gate that no dispatcher runs | [scripts/verify-node.sh:122] [scripts/node_freshness.py:343] [tests/selftest.sh:2095]. **Not yet filed** |
| 2 | **CF-212's criteria 2 and 3 are unmet while the row is still open.** Nothing refreshes a workdir before a dispatch, and nothing refuses one; this script only measures. Criterion 4 is met (DB enumeration), criterion 1 is met for a probe | [.coding-hermes/board/tasks.jsonl:187] [scripts/repo_freshness.py:37]. **Not yet filed** |
| 3 | **`FRESHNESS: PASS` is printed when no workdir was measured, and `--gate` ignores `WARN`.** Measured: 0-measured runs exit 0; an unreachable remote with `lag 0` exits 0 under `--gate`; the real fleet passes on 6 of 53 | §3 rows 6, 7, 9, 11, 12. **Not yet filed** |
| 4 | **A stale-ref measurement is indistinguishable from a live one.** `--no-fetch` prints the identical `PASS … lag 0 …` row with no in-row marker that no fetch happened — the header carries `fetch off`, the row does not. A consumer parsing rows sees freshness | §3 transcript 2. **Not yet filed** |
| 5 | **A local-branch upstream makes the probe fetch a branch name as if it were a remote**, and then compares against that local branch — not a remote freshness measurement at all, reported as `WARN` then `PASS` | `remote = target.split("/")[0]` [scripts/repo_freshness.py:338]; §3 row 15. **Not yet filed** |
| 6 | **"last fetch" is `FETCH_HEAD`'s mtime, which is repo-global, not per-remote.** Any fetch by any tool in that repository resets it, so `--max-fetch-age` can be satisfied by a fetch that did not touch this workdir's comparison ref. Measured: the live checkout's `last fetch` moved from `58s` to `0s` between two consecutive runs | [scripts/repo_freshness.py:345-353]; §3 rows 1-2. **Not yet filed** |
| 7 | **Every configuration error is labelled `scheduler-db`**, including pure argument errors — `--bound -1` prints `  FAIL  scheduler-db — --bound must be >= 0` | [scripts/repo_freshness.py:632-633]; §3 row 14. **Not yet filed** |
| 8 | **The caller's git environment is inherited unfiltered.** `GIT_DIR` exported redirects every probe to another repository while the row keeps the named workdir's path | `dict(os.environ)` [scripts/repo_freshness.py:103]; §3 row 16. **Not yet filed** |
| 9 | **A missing `git` binary is reported as `not a git workdir`.** The dependency is never probed, so the operator is told the tree is unmeasurable when the tool is absent | [scripts/repo_freshness.py:307-313]; §3 row 12. **Not yet filed** |
| 10 | **`--json` is a dead output.** Nothing consumes it: no caller, no writer, no scheduler read path | [scripts/repo_freshness.py:653]; §4. **Not yet filed** |
| 11 | **The index still says RED.** [docs/master/00-INDEX.md:42] records this module as `RED`; this document is `VERIFIED`. The index row is outside this task's one-file scope and must be updated with it | [docs/master/00-INDEX.md:42]. **Not yet filed** |
