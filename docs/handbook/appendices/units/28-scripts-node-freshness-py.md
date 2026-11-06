# 28. scripts/node_freshness.py

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/node_freshness.py` — 732 lines [scripts/node_freshness.py:1] |
| Repository | `code-factory` [scripts/node_freshness.py:2] |
| Revision | `b9f56e6` — the tree every locator below was measured against, and unchanged for this file; the branch is now rebased onto `930a407`, the current `origin/main` tip, where `scripts/node_freshness.py` is byte-identical. The file's own last-touching commit is `8db72b3` ("feat: prove a node checkout matches origin/main and name the drift — CF-244") |
| Status | **VERIFIED — 250 locators, all resolve (161 distinct file:line pairs); facts cited and the checker green** |

## 1. Purpose and why it matters

- What it is: the only thing in this repo that measures the **git state of a node's checkout**. Four arms, each a row with its measured value — `branch` (an attached branch, or the detached/unborn state named), `worktree` (`git status --porcelain`, every path printed), `ancestor` (`git merge-base --is-ancestor HEAD origin/main`), `sync` (`git rev-list --count HEAD..origin/main` plus the differing paths) [scripts/node_freshness.py:13-20]. Three exits: `0` PASS, `1` drift or dirty, `2` usage or unreachable — "an unmeasurable node is not a PASS" [scripts/node_freshness.py:48-50].
- Why it exists: nothing else looked at the tree. `lane_target.py --exec-bunker` proves the agent answers and the path exists, `verify-node.sh` proves the transport and the auth gate, and `repo_freshness.py` measures local lane workdirs from the scheduler database only — so "a node could sit one commit behind origin/main — or carry a local edit that silently blocks its own fast-forward pull — while every layer printed PASS (measured on cf-node, 2026-11-05: HEAD 7f22d02, origin/main 04fc398, porcelain clean, and an earlier `.gitignore` edit had blocked the pull)" [scripts/node_freshness.py:4-11].
- Why the node's tree is the thing that matters: the Hermes foreman runs **on** the node, never on the control host [docs/master/_facts.md:12] (fact: FACT-01), and one bunker serves one project with every lane of that project entering it [docs/master/_facts.md:13] (fact: FACT-02). A node one commit behind does not run a slightly stale helper — it runs last week's foreman, and it runs it for the whole project.
- What breaks if this module is ABSENT: nothing silently passes. `verify-node.sh` step 5 refuses to fold a missing child and prints `  FAIL  checkout_freshness — <path> missing — the checkout's git state is unmeasured` [scripts/verify-node.sh:122-124]; provisioning falls back to an inline heredoc that reimplements the same four arms with "the same row texts and the same exit codes" [scripts/project-node.sh:491-497] [scripts/project-node.sh:527-528]. So absence is not silence — it is a **second implementation** of the same measurement, which can drift from this one and which nothing compares.
- What breaks if it LIES: both callers trust the exit code and the row text, never an independent re-derivation. `verify-node.sh` maps `0`→PASS, `1`→FAIL, anything else→WARN (FAIL under `--strict-freshness`) [scripts/verify-node.sh:129-143] and lifts its detail by grepping two fixed shapes [scripts/verify-node.sh:131] [scripts/verify-node.sh:134]; layer 40 of `project-node.sh` grades the same child PASS / WARN-for-dirty / FAIL [scripts/project-node.sh:743-753]. A false `behind=0` is therefore a green `VERIFY:` and a green `NODE:` with no second opinion anywhere in the stack — which is why §6 spends its rows on the direction of each failure.

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `python3` | 3.14.4 measured here; the file is stdlib-only and uses `from __future__ import annotations`, so 3.7 is the effective floor — nothing below 3.14.4 was exercised [scripts/node_freshness.py:52] | The control host, and on the node only when provisioning's rung 1 runs the clone's own copy [scripts/project-node.sh:492] | The callers invoke `python3 -B`; an interpreter that cannot run the file makes the leg exit non-zero and land in the `*)` arm [scripts/verify-node.sh:127] [scripts/verify-node.sh:136-143] |
| `git` | 2.53.0 measured here | The measured checkout, resolved as `shutil.which("git") or "git"` [scripts/node_freshness.py:66] | **Measured**: with `PATH` stripped of `git`, every arm collapses into `  FAIL  checkout — <path> is not a git checkout (FileNotFoundError: [Errno 2] No such file or directory: 'git')` and exits 1 [scripts/node_freshness.py:134-135] [scripts/node_freshness.py:256-261] — fail-closed, but it blames the checkout (§6, defect 2) |
| `bunker` | not versioned; `shutil.which("bunker") or "bunker"` [scripts/node_freshness.py:67] | Only in `--agent/--server` mode, on the control host | `run()` turns the spawn failure into a result [scripts/node_freshness.py:134-135], which becomes `  FAIL  unreachable — bunker exec failed: …` and exit 2 [scripts/node_freshness.py:568-571] |
| `sh` + `timeout` on the node | POSIX `sh`; `timeout` optional | Inside the `bunker exec` for the remote battery [scripts/node_freshness.py:565] | `timeout` is probed with `command -v` and the fetch runs unguarded without it — the 300 s exec stream is then the only bound [scripts/node_freshness.py:502-506] |
| No network client, no database, no HTTP library | — | — | The only network I/O is the `git fetch` the module shells out to [scripts/node_freshness.py:426] [scripts/node_freshness.py:503]; the only store it opens is a git repository |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `argparse` [scripts/node_freshness.py:57] | stdlib | Five options, `--path` defaulting to `repo` [scripts/node_freshness.py:674-693]; own refusals go through `usage_error` [scripts/node_freshness.py:696-699] | argparse's *own* errors also exit 2, the same code as "unreachable" — indistinguishable to a `case` on `$?` [scripts/verify-node.sh:129-143] |
| `dataclasses` [scripts/node_freshness.py:63] | stdlib | Two plain records: `Measurement` (what was measured) and `Finding` (the judgement) [scripts/node_freshness.py:164-205] | `field(default_factory=list)` is what keeps `dirty_files`/`differing_files`/`rows` per-instance instead of shared across runs [scripts/node_freshness.py:182-186] |
| `json` [scripts/node_freshness.py:58] | stdlib | `json.dumps(..., indent=2)` as the whole `--json` payload [scripts/node_freshness.py:727] | `project-node.sh` re-parses this object field by field [scripts/project-node.sh:632-676], so a renamed key silently blanks the provisioning row |
| `os` [scripts/node_freshness.py:59] | stdlib | `environ` copy for the git environment [scripts/node_freshness.py:109]; `path.expanduser` on `--workdir` [scripts/node_freshness.py:379]; `path.exists`/`isdir` as the existence arms [scripts/node_freshness.py:385-392] | Dropping `expanduser` makes every `~/repo` argument read as "does not exist" [scripts/node_freshness.py:240-247] |
| `shutil` [scripts/node_freshness.py:60] | stdlib | `which` for the two binaries, with a bare-name fallback [scripts/node_freshness.py:66-67] | The fallback means a missing binary surfaces as `OSError` from `subprocess`, not as a resolution error (§6, defect 2) |
| `subprocess` [scripts/node_freshness.py:61] | stdlib | `run(..., capture_output=True, text=True, timeout=..., env=git_env(), check=False)` [scripts/node_freshness.py:122-131]; `TimeoutExpired`→`Res(-9, …)`, `OSError`→`Res(-1, …)` [scripts/node_freshness.py:132-135] | A timeout and a missing binary are *results* by construction [scripts/node_freshness.py:83]; with `check=True` every non-zero git exit would raise instead of becoming a row |
| `sys` [scripts/node_freshness.py:62] | stdlib | `stderr` for rows and `stdout` for the JSON object [scripts/node_freshness.py:720-727]; `sys.exit(main())` [scripts/node_freshness.py:731-732] | The split stream is the contract `verify-node.sh` depends on (`2>` rows, `>` JSON) [scripts/verify-node.sh:126-127] |
| `typing` [scripts/node_freshness.py:64] | stdlib | `Optional` only, for `ancestor`/`behind`/`argv` — the three values that are legitimately "not measured" rather than 0 or false [scripts/node_freshness.py:183-184] | Turning `behind` into `int = 0` would make "could not count" indistinguishable from "in sync" — the exact failure this module exists to prevent |

### 2c. Service contracts (both sides must be named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| `scripts/verify-node.sh` step 5 | caller → probe | `python3 -B <probe> --agent ID --server NAME --json`, stdout and stderr captured to two temp files [scripts/verify-node.sh:126-127] | 22-key JSON on stdout, rows on stderr [scripts/node_freshness.py:640-667] | `checkout_freshness` fold: greps `  PASS  freshness — ` [scripts/verify-node.sh:131], flattens `^  FAIL  ` rows and cuts at 500 characters [scripts/verify-node.sh:134], reads `^RESULT: ` for the unmeasurable detail [scripts/verify-node.sh:137] |
| `scripts/project-node.sh` layer 40 (rung 1) | caller → probe | `python3 <clone>/scripts/node_freshness.py --workdir <repo> --json` [scripts/project-node.sh:491-492] | the same JSON, plus the row text on stderr | `freshness_measure` then `freshness_fields` [scripts/project-node.sh:632], graded PASS / WARN / FAIL [scripts/project-node.sh:743-753], recorded to `$STATE/freshness.json` [scripts/project-node.sh:735] and nested into `node.json` as `freshness{status,ladder,behind,…}` [scripts/project-node.sh:781-811] |
| The node itself, through `bunker exec` | probe → node | one `bunker exec <agent> -- sh -lc <script>` round trip [scripts/node_freshness.py:565] | the `REMOTE_BATTERY` shell program [scripts/node_freshness.py:475-526]: `HOME=`, `REPO=`, `EXISTS=`, `CD=`, `IS_GIT=`, `BRANCH=`, `HEAD_SHA=`, `REMOTES=`, a `DIRTY_BEGIN`/`DIRTY_END` block, `FETCH_RC=`, `CMP_REF=`, `ORIGIN_MAIN=`, `ANCESTOR_RC=`, `BEHIND=`, a `DIFF_BEGIN`/`DIFF_END` block | `parse_battery` [scripts/node_freshness.py:529-549], which accepts only keys that are `isupper()` so remote git chatter cannot be read as a measurement [scripts/node_freshness.py:546-548]. The node's side is its own `git` |
| `tests/selftest.sh` §47 | test → probe | subprocess, real local `origin` fixtures, plus a stub `bunker` on `PATH` [tests/selftest.sh:2920-2923] | exit codes, row text, JSON fields, and the `bunker` invocation count | 13 legs incl. the green, drill, dirty, detached, no-origin, one-exec and `--json` arms [tests/selftest.sh:2871-2952]; the section ends at [tests/selftest.sh:3065] |

## 3. Verification

Run 2026-11-05 in the worktree `proj-wt-md-28e` at `b9f56e6`, Python 3.14.4, git 2.53.0. Every fixture is a real local `origin.git` under `$TMPDIR/md25b/nf28b`; the node fixture is a **stub `bunker`** that executes the battery against a fixture `$NODE_HOME` — **no live node was contacted** (the prohibition is honoured; the live `behind=26` instance is cited, not re-measured, in §8). `$S` is `scripts/node_freshness.py`, `$W` is `/home/kara/.hermes/cache/scratch/md25b/nf28b`.

| # | Check | Command | Expected | Last run | Result |
|---|---|---|---|---|---|
| 1 | The gate itself | `python3 scripts/master_doc_check.py docs/master --only 28- --strict` [scripts/master_doc_check.py:110-144] | `MASTER-DOC: PASS`, exit 0 | 2026-11-05 | **PASS** |
| 2 | The suite's own legs (§47, 13 of them) | section extracted verbatim, `tests/selftest.sh:2829-3065`, run standalone with the suite's `say`/`fails` stubs | every line `  PASS  …`, `FAILS=0` | 2026-11-05 | **PASS** |
| 3 | Four usage refusals | no mode / both modes / `--agent` alone / `--timeout 0` [scripts/node_freshness.py:701-712] | named line + `RESULT: FAIL (usage: …)`, exit 2 | 2026-11-05 | **PASS** |
| 4 | In-sync clone | `--workdir $W/node` | `RESULT: PASS`, exit 0, `behind=0` | 2026-11-05 | **PASS** |
| 5 | Origin advances 2 commits | same, after a push | `behind=2`, the 2 differing paths named, exit 1 | 2026-11-05 | **PASS** |
| 6 | What `behind` counts | `git rev-list --count HEAD..origin/main` vs `origin/main..HEAD` on the same tree | `2` and `0` — only the ref-side commits count | 2026-11-05 | **PASS** |
| 7 | Uncommitted edit | append to `a.txt` | `1 uncommitted path(s): a.txt … the fix belongs upstream`, exit 1 | 2026-11-05 | **PASS** |
| 8 | Diverged (local commit) | commit on `main`, never pushed | `ancestor` FAIL, `sync` still `behind=0`, exit 1 | 2026-11-05 | **PASS** |
| 9 | Detached HEAD | `git checkout --detach` | `detached HEAD at <sha>`, exit 1 | 2026-11-05 | **PASS** |
| 10 | No `origin` remote | `git remote remove origin` | `no 'origin' remote (remotes: none)`, exit 1, no crash | 2026-11-05 | **PASS** |
| 11 | Origin unreachable, `behind=0` | `remote set-url origin /nonexistent/origin.git` | `FAIL fetch — git fetch origin failed: … the comparison ref may be stale`, exit 1 | 2026-11-05 | **PASS** (fail-closed) |
| 12 | Origin unreachable, `behind>0` | same, with refs already 2 behind | **no fetch row**; `behind=2` from stale refs, exit 1 | 2026-11-05 | **PASS with defect 3** |
| 13 | Local mode reaches the network | `origin` set to `ssh://git@192.0.2.1/x.git` | a fetch is attempted (10 s = `ConnectTimeout=10`), its failure invisible because `behind>0` | 2026-11-05 | **measured — contradicts the docstring, defect 4** |
| 14 | Node unreachable | stub `bunker` exits 255 | `FAIL unreachable — bunker exec failed: ssh: … Connection timed out`, exit **2** | 2026-11-05 | **PASS** |
| 15 | Node answers nothing | stub exits 0 with no output | `FAIL unreachable — bunker exec returned no HOME (first line: (empty))`, exit **2** | 2026-11-05 | **PASS** |
| 16 | Node has no checkout | fixture home without `repo` | `FAIL checkout — … does not exist on agent cf-node`, exit 1 | 2026-11-05 | **PASS** |
| 17 | Node checkout dirty and behind | edit on the node fixture | both the `worktree` and `sync` rows FAIL, exit 1 | 2026-11-05 | **PASS** |
| 18 | One exec round trip | stub `bunker` log, 7 invocations across 7 bunker runs | exactly one `exec cf-node -- sh -lc` per run, home resolved from `echo $HOME` | 2026-11-05 | **PASS** |
| 19 | `--json` split | `--workdir … --json` | 22 keys on stdout, rows on stderr, `behind`/`ancestor` typed | 2026-11-05 | **PASS** |
| 20 | Usage error under `--json` | `--timeout 0 --json` | stdout carries **prose**, not JSON; the consumer's parse fails | 2026-11-05 | **FAIL — defect 1** |
| 21 | `--workdir` names a file | `--workdir $W/node/a.txt` | the row says "does not exist" although the path exists | 2026-11-05 | **FAIL — defect 2** |
| 22 | `--workdir ''` | empty string | `one mode is required` — the empty-path branch is unreachable | 2026-11-05 | **PASS** (dead branch, defect 5) |
| 23 | 55 differing paths | one commit touching 55 files | 50 named + `(+5 more, see --json)`, row 531 characters | 2026-11-05 | **PASS** |

```
$ python3 scripts/master_doc_check.py docs/master --only 28- --strict
28-scripts-node-freshness-py.md                VERIFIED   ok

1 module(s): 1 VERIFIED, 0 error(s), 0 warning(s), 10 fact(s) in the ledger
MASTER-DOC: PASS

$ bash sec47.sh          # tests/selftest.sh:2829-3065, extracted verbatim
47. a node checkout freshness check can go RED: drift and a local edit are named (CF-244)
  PASS  scripts/node_freshness.py parses (python3 -B, stdlib only)
  PASS  a clone in sync with its origin -> RESULT: PASS, exit 0 (the fixture can go green)
  PASS  origin advances -> exit 1, RESULT names the lag and the differing file b.txt
  PASS  an uncommitted edit -> exit 1, the path is named and called upstream's problem
  PASS  a detached HEAD -> exit 1, the branch state is named
  PASS  a checkout with no origin -> exit 1, the reason is named (no crash)
  PASS  bunker mode: one exec round trip, home resolved from the agent, RESULT: PASS
  PASS  bunker mode --json: status FAIL, behind 1, differing_files [b.txt] (provisioning stores this)
  PASS  provisioning runs the clone's own probe after the clone -> PASS freshness, NODE: PASS
  PASS  a dirty checkout at provision time -> WARN naming a.txt, no FAIL row, NODE: PASS
  PASS  a drifted checkout at provision time -> FAIL naming behind=1, NODE: FAIL (1), exit 1
  PASS  --apply records freshness{status:PASS, ladder:PASS, behind:0} in node.json, exit 0
  PASS  a dirty checkout is recorded (status FAIL, ladder WARN, dirty_files [a.txt]) and the ladder still passes, exit 0
FAILS=0

$ python3 $S --workdir $W/node              # 2 commits behind origin
node-freshness — workdir /home/kara/.hermes/cache/scratch/md25b/nf28b/node
  PASS  branch — branch=main
  PASS  worktree — 0 uncommitted paths
  PASS  ancestor — HEAD b4452d3cb2a6 is an ancestor of origin/main 8065ebdd8b75
  FAIL  sync — behind=2 (HEAD..origin/main 8065ebdd8b75): 2 differing path(s) — c1.txt, c2.txt
RESULT: FAIL (behind 2 commit(s) vs origin/main)
[rc=1]

$ printf 'HEAD..origin/main = '; git -C $W/node rev-list --count HEAD..origin/main
HEAD..origin/main = 2
$ printf 'origin/main..HEAD = '; git -C $W/node rev-list --count origin/main..HEAD
origin/main..HEAD = 0
$ git -C $W/node log --format='%h %s' HEAD..origin/main
8065ebd c2
f0a2e4a c1

$ python3 $S --workdir $W/node              # 55 paths in one commit
  FAIL  sync — behind=1 (HEAD..origin/main ed42e5c1aea5): 55 differing path(s) — p1.txt, p10.txt, … p54.txt (+5 more, see --json)
[rc=1]   row length 531

$ python3 $S --workdir $W/node              # origin = /nonexistent/origin.git, refs 0 behind
  PASS  sync — behind=0 (HEAD..origin/main 8065ebdd8b75)
  FAIL  fetch — git fetch origin failed: fatal: '/nonexistent/origin.git' does not appear to be a git repository — the comparison ref may be stale
RESULT: FAIL (origin unreachable (lag counted from stale refs))
[rc=1]

$ python3 $S --workdir $W/node              # same, but refs already 2 behind — NO fetch row
  PASS  ancestor — HEAD b4452d3cb2a6 is an ancestor of origin/main 8065ebdd8b75
  FAIL  sync — behind=2 (HEAD..origin/main 8065ebdd8b75): 2 differing path(s) — c1.txt, c2.txt
RESULT: FAIL (behind 2 commit(s) vs origin/main)
[rc=1]

$ python3 $S --agent cf-node --server bunker-las-03    # stub bunker exits 255
node-freshness — agent cf-node via bunker-las-03, checkout repo (home (unresolved))
  FAIL  unreachable — bunker exec failed: ssh: connect to host bunker-las-03 port 22: Connection timed out
RESULT: FAIL (bunker exec failed: ssh: connect to host bunker-las-03 port 22: Connection timed out)
[rc=2]

$ python3 $S --agent cf-node --server bunker-las-03    # stub exits 0, prints nothing
node-freshness — agent cf-node via bunker-las-03, checkout repo (home (unresolved))
  FAIL  unreachable — bunker exec returned no HOME (first line: (empty))
RESULT: FAIL (bunker exec returned no HOME (first line: (empty)))
[rc=2]

$ python3 $S --workdir $W/node/a.txt        # the path EXISTS; the row says otherwise
  FAIL  checkout — /home/kara/.hermes/cache/scratch/md25b/nf28b/node/a.txt does not exist — there is no tree to measure
RESULT: FAIL (no checkout at /home/kara/.hermes/cache/scratch/md25b/nf28b/node/a.txt)
[rc=1]

$ python3 $S --workdir $W/node --timeout 0 --json
--- stdout:
RESULT: FAIL (usage: --timeout must be >= 1, got 0)
--- stderr:
--timeout must be >= 1, got 0
json.decoder.JSONDecodeError: Expecting value: line 1 column 1 (char 0)     # the consumer

$ env PATH=<a PATH with python3 and no git> python3 $S --workdir $W/node
  FAIL  checkout — /home/kara/.hermes/cache/scratch/md25b/nf28b/node is not a git checkout (FileNotFoundError: [Errno 2] No such file or directory: 'git') — a node cannot work a tree it cannot fast-forward
RESULT: FAIL (/home/kara/.hermes/cache/scratch/md25b/nf28b/node is not a git checkout)
[rc=1]

$ start=$(date +%s); python3 $S --workdir $W/node ; end=$(date +%s); echo $((end-start))s
# origin = ssh://git@192.0.2.1/x.git (unroutable), refs 1 behind -> the fetch still runs
  FAIL  sync — behind=1 (HEAD..origin/main ed42e5c1aea5): …
[elapsed=10s]
```

The `behind` count is the arm this document is about, so the direction proof is spelled out: `git rev-list --count HEAD..origin/main` counts commits reachable from the comparison ref and **not** from `HEAD` [scripts/node_freshness.py:445] — 2 in the fixture, while `origin/main..HEAD` is 0. A node carrying commits of its own therefore shows `behind=0` and is caught by the `ancestor` arm instead [scripts/node_freshness.py:315-321], which is why `behind` alone is never the verdict (§6).

## 4. Metrics emitted

**NONE** — no counter, gauge, histogram, timer, exporter or span exists on this path: `grep -cE 'logging|logger|metric|prometheus|statsd'` returns `0`, `grep -c 'import time'` returns `0`, and the complete output surface is six `print` calls — the two usage lines [scripts/node_freshness.py:697-698], the header [scripts/node_freshness.py:721], the row printer [scripts/node_freshness.py:723], the verdict [scripts/node_freshness.py:724] and the JSON object [scripts/node_freshness.py:727]. There is no log level, destination, retention or scrape endpoint anywhere in the file.

The one number it produces is `behind`, and it is a **measurement, not a metric**: printed into the `sync` row [scripts/node_freshness.py:343], carried in the JSON as `"behind"` [scripts/node_freshness.py:658], and persisted only because a caller chooses to store the object — layer 40 writes `$STATE/freshness.json` [scripts/project-node.sh:735] and nests it into `node.json` as `freshness{status,ladder,behind,…}` [scripts/project-node.sh:781-811]. Nothing aggregates it, so "how far behind do nodes drift, and for how long" is unanswerable from any store; it is answerable only by re-running the probe against each node, one node at a time. That is the right scope for a one-shot probe run once per verification and once per provision, and it is the reason no instrumentation belongs in this file rather than an oversight to fix here.

## 5. Log lines it can generate

Every line is one of three things: the header [scripts/node_freshness.py:631-637], a row printed as `  {status}  {check} — {value}` [scripts/node_freshness.py:723], or the verdict `RESULT: {result}` [scripts/node_freshness.py:724]. Under `--json` the rows go to stderr and the object to stdout; without it everything goes to stdout [scripts/node_freshness.py:720-727].

| Level | Line (verbatim) | Emitted when | Kind |
|---|---|---|---|
| header | `node-freshness — workdir /home/kara/repo` | local mode, first line, always [scripts/node_freshness.py:637] | descriptive — names the mode and the path the operator actually passed |
| header | `node-freshness — agent cf-node via bunker-las-03, checkout /home/bunker-cf-node/repo (home /home/bunker-cf-node)` | bunker mode; the home is the one the agent printed [scripts/node_freshness.py:633-636] | descriptive — `(unresolved)` means the exec never answered [scripts/node_freshness.py:576-584] |
| PASS | `  PASS  branch — branch=main` | `HEAD` is an attached branch [scripts/node_freshness.py:269-270] | evidentiary |
| FAIL | `  FAIL  branch — detached HEAD at 7f22d029bc99 — no attached branch to fast-forward` | a detached HEAD [scripts/node_freshness.py:272-275] | evidentiary |
| FAIL | `  FAIL  branch — unborn HEAD (no commits) — no attached branch to fast-forward` | a repo with no commits yet [scripts/node_freshness.py:272-275] | evidentiary |
| FAIL | `  FAIL  worktree — 1 uncommitted path(s): a.txt — a local edit on the node blocks its fast-forward; the fix belongs upstream` | any porcelain entry [scripts/node_freshness.py:281-287] | evidentiary — the arm that closes the "local edit blocked the pull" incident [scripts/node_freshness.py:8-11] |
| PASS | `  PASS  worktree — 0 uncommitted paths` | an empty porcelain [scripts/node_freshness.py:289] | evidentiary |
| FAIL | `  FAIL  origin — no 'origin' remote (remotes: none) — cannot compare against origin/main` | no `origin` remote; the run stops after the branch and worktree rows [scripts/node_freshness.py:292-300] | evidentiary |
| PASS | `  PASS  ancestor — HEAD b4452d3cb2a6 is an ancestor of origin/main 8065ebdd8b75` | `merge-base --is-ancestor` exited 0 [scripts/node_freshness.py:307-313] | evidentiary |
| FAIL | `  FAIL  ancestor — HEAD a8c6a69f1dc2 is NOT an ancestor of origin/main 8065ebdd8b75 — the checkout has diverged` | exited 1 [scripts/node_freshness.py:314-321] | evidentiary — the only arm that catches a node carrying its own commits |
| FAIL | `  FAIL  ancestor — ancestry of HEAD against origin/main could not be measured (fatal: Not a valid object name HEAD)` | any other exit [scripts/node_freshness.py:322-329] | evidentiary |
| FAIL | `  FAIL  sync — behind=2 (HEAD..origin/main 8065ebdd8b75): 2 differing path(s) — c1.txt, c2.txt` | `behind > 0` [scripts/node_freshness.py:339-345] | evidentiary — the shape the live `behind=26` row took (§8) |
| FAIL | `  FAIL  sync — behind=1 (HEAD..origin/main ed42e5c1aea5): 55 differing path(s) — p1.txt, … (+5 more, see --json)` | more than `MAX_SHOWN` (50) paths [scripts/node_freshness.py:212-219] [scripts/node_freshness.py:79] | evidentiary — the marker is honest here and lost in the caller's 500-character cut [scripts/verify-node.sh:134] |
| PASS | `  PASS  sync — behind=0 (HEAD..origin/main 8065ebdd8b75)` | `behind == 0` [scripts/node_freshness.py:347-348] | evidentiary — a 0 here is *counted*, never assumed; when the count cannot be made the row is the FAIL below |
| FAIL | `  FAIL  sync — lag against origin/main could not be counted (no origin/main and no origin/HEAD on the checkout)` | `behind is None` [scripts/node_freshness.py:332-338] | evidentiary |
| FAIL | `  FAIL  fetch — git fetch origin failed: fatal: '/nonexistent/origin.git' does not appear to be a git repository — the comparison ref may be stale` | the fetch failed **and** `behind == 0` [scripts/node_freshness.py:350-359] | evidentiary — the arm that stops "0 because we could not look" from reading as fresh |
| PASS | `  PASS  freshness — branch=main head=b4452d3cb2a6 origin_main=b4452d3cb2a6 ancestor=true behind=0` | no arm failed [scripts/node_freshness.py:364-369] | evidentiary — the exact text `verify-node.sh` greps for its PASS detail [scripts/verify-node.sh:131] |
| FAIL | `  FAIL  unreachable — bunker exec failed: ssh: connect to host bunker-las-03 port 22: Connection timed out` | the exec did not exit 0, or no binary [scripts/node_freshness.py:568-571] | evidentiary — the only row of an exit-2 run, and the first line of the `RESULT:` the caller shows [scripts/verify-node.sh:137] |
| FAIL | `  FAIL  unreachable — bunker exec returned no HOME (first line: (empty))` | the exec answered 0 but printed no `HOME=` — a cut stream [scripts/node_freshness.py:576-584] | evidentiary — "nothing about the checkout is known" is stated, not guessed [scripts/node_freshness.py:577-578] |
| FAIL | `  FAIL  checkout — /home/bunker-cf-node/repo does not exist on agent cf-node — there is no tree to measure` | `EXISTS=0` from the battery [scripts/node_freshness.py:586-589] [scripts/node_freshness.py:240-247] | evidentiary |
| FAIL | `  FAIL  checkout — /home/kara/repo is not a git checkout (fatal: not a git repository (or any of the parent directories): .git) — a node cannot work a tree it cannot fast-forward` | `rev-parse --show-toplevel` failed, or a bare repo [scripts/node_freshness.py:255-261] [scripts/node_freshness.py:394-401] | evidentiary — also the shape a missing `git` binary takes (§6, defect 2) |
| verdict | `RESULT: PASS` | exit 0 [scripts/node_freshness.py:208-209] [scripts/node_freshness.py:724] | evidentiary |
| verdict | `RESULT: FAIL (behind 2 commit(s) vs origin/main)` | exit 1; the parenthesised reason is the arm reasons joined with `; ` [scripts/node_freshness.py:205] [scripts/node_freshness.py:361-362] | evidentiary |
| verdict | `RESULT: FAIL (bunker exec failed: …)` | exit 2 [scripts/node_freshness.py:238] | evidentiary |
| usage | `one mode is required: --workdir PATH or --agent ID --server NAME` | neither mode given [scripts/node_freshness.py:707-710] | descriptive — printed to stderr, followed by `RESULT: FAIL (usage: …)` on **stdout** [scripts/node_freshness.py:696-699] |
| usage | `--workdir and --agent/--server are exclusive` | both modes [scripts/node_freshness.py:705-706] | descriptive |
| usage | `bunker mode needs both --agent ID and --server NAME` | one half of bunker mode [scripts/node_freshness.py:711-712] | descriptive |
| usage | `--timeout must be >= 1, got 0` | `--timeout 0` [scripts/node_freshness.py:701-702] | descriptive |

## 6. Failure modes

Direction is stated for each row: **fail closed** means the run ends non-zero and no caller can read it as fresh; **fail open** means it can. The unreachable-node question is answered at the top because it is the one that matters: **no path in this file reports `behind=0` when it could not look** — every unmeasurable arm produces a FAIL row and a non-zero exit — but the *label* and the *cause* are not always right, and that is where the defects are.

| Failure | Presents as | Direction | Distinguished from | Recovery |
|---|---|---|---|---|
| The node does not answer (`bunker exec` non-zero, ssh timeout) | `  FAIL  unreachable — bunker exec failed: …`, a single row, exit 2 [scripts/node_freshness.py:568-571] | **fail closed** — the kind is `unreachable` and the JSON says `behind: null` [scripts/node_freshness.py:236-238] | A usage error is also exit 2 [scripts/node_freshness.py:696-699]; `verify-node.sh` cannot tell them apart and WARNs on both by default [scripts/verify-node.sh:136-143] | restore reachability and re-run; `--strict-freshness` makes the unknown a FAIL [scripts/verify-node.sh:138-139] |
| The node answers with an empty or truncated stream | `  FAIL  unreachable — bunker exec returned no HOME (first line: (empty))`, exit 2 [scripts/node_freshness.py:576-584] | **fail closed** — no `HOME` means nothing about the checkout is claimed [scripts/node_freshness.py:577-582] | A node that *does* answer but has no checkout prints a `checkout` row and exits 1 [scripts/node_freshness.py:586-589] | re-run; if it repeats, the exec stream is being cut (300 s) [scripts/node_freshness.py:34-36] |
| The node has no checkout at the path | `  FAIL  checkout — <path> does not exist on agent <id> — there is no tree to measure`, exit 1 [scripts/node_freshness.py:240-254] | **fail closed** | An unprovisioned node is exactly this, and `--strict-freshness` is irrelevant to it | provision, or pass `--path` [scripts/node_freshness.py:677-682] |
| The path exists but is a file, not a directory | `  FAIL  checkout — <path> does not exist — there is no tree to measure`, exit 1 — **and the row is wrong**: the path exists [scripts/node_freshness.py:389-392] | **fail closed, mislabelled** — `classify` prints the literal words "does not exist" for every `exists=False` and never prints `m.error` [scripts/node_freshness.py:243-247] | Nothing distinguishes it; an operator chasing "does not exist" on an existing path loses time | fix the argument; the wording is defect 2 in §8 |
| The checkout is not a git work tree (or is bare) | `  FAIL  checkout — <path> is not a git checkout (<git's own first line>) — a node cannot work a tree it cannot fast-forward`, exit 1 [scripts/node_freshness.py:255-264] | **fail closed** | A bare repo is asked first so it is not misread as "not git" [scripts/node_freshness.py:394-401]; **a missing `git` binary lands here too**, measured: `(FileNotFoundError: … 'git')` | install git, or fix the user the exec runs as |
| `HEAD` is detached or unborn | `  FAIL  branch — detached HEAD at <sha> — no attached branch to fast-forward`, exit 1 [scripts/node_freshness.py:269-276] | **fail closed** | Unborn prints `unborn HEAD (no commits)` in the same row [scripts/node_freshness.py:272-274] | `git checkout main` on the node |
| An uncommitted path exists | `  FAIL  worktree — N uncommitted path(s): … the fix belongs upstream`, exit 1 [scripts/node_freshness.py:280-289] | **fail closed at the probe, graded two ways upstream**: `verify-node.sh` FAILs it [scripts/verify-node.sh:133-134], layer 40 WARNs it because a node may be mid-task [scripts/project-node.sh:747-749] | Drift is the `sync` row; dirty and behind are independent arms and both are reported [scripts/node_freshness.py:222-229] | land the edit upstream; the probe never repairs the node's tree |
| No `origin` remote | `  FAIL  origin — no 'origin' remote (remotes: …) — cannot compare against origin/main`, exit 1, rows stop there [scripts/node_freshness.py:292-300] | **fail closed** — no comparison is claimed rather than guessed | A missing comparison ref *with* an origin is a different set of rows (`ancestor` and `sync` unmeasurable) [scripts/node_freshness.py:322-338] | add the remote |
| `HEAD` has diverged (own commits, not on the ref) | `  FAIL  ancestor — HEAD … is NOT an ancestor of … — the checkout has diverged`, exit 1, while `sync` still prints `behind=0` [scripts/node_freshness.py:314-321] [scripts/node_freshness.py:347-348] | **fail closed, but `behind=0` is printed on a diverged node** — anything that reads only the count reads fresh | The `ancestor` row is the only tell | rebase or reset the node onto the ref; find out who committed there |
| Origin unreachable **and** `behind == 0` | `  PASS  sync — behind=0` **plus** `  FAIL  fetch — … the comparison ref may be stale`, exit 1, kind `drift` [scripts/node_freshness.py:350-359] | **fail closed** — this is the arm that prevents "0 because we could not look" | A genuinely fresh node has no `fetch` row at all | fix reachability; the count is only as fresh as the last fetch [scripts/node_freshness.py:350-353] |
| Origin unreachable **and** `behind > 0` | Only `  FAIL  sync — behind=N …`, exit 1 — **the fetch failure is not named at all**, because that row is gated on `behind == 0` [scripts/node_freshness.py:350] | **fail closed but understated** — N is a floor computed from stale refs, the real lag may be larger, and the reason never reaches the operator | Count the rows: a `fetch` row is absent whenever the checkout is also behind | fix reachability, then re-run for a true count; defect 3 in §8 |
| `behind` cannot be counted at all (`rev-list` failed on the node) | `  FAIL  sync — lag against origin/main could not be counted (…)`, exit 1 [scripts/node_freshness.py:332-338] | **fail closed** — `behind` stays `None`, never `0` [scripts/node_freshness.py:184] [scripts/node_freshness.py:621-623] | An empty `BEHIND=` from the battery is unmeasurable, not zero [scripts/node_freshness.py:621-623] | treat as unreachable-adjacent; read the parenthesised git error |
| The comparison ref cannot be resolved | `  FAIL  ancestor — ancestry … could not be measured (no origin/main and no origin/HEAD on the checkout)` plus the matching `sync` row, exit 1 [scripts/node_freshness.py:430-434] [scripts/node_freshness.py:454-469] | **fail closed** | `origin/HEAD` is only a fallback, and the row names which ref was used [scripts/node_freshness.py:302-304] | `git remote set-head origin -a` on the node |
| A repo whose default branch is not `main` but which still carries a stale `origin/main` | Measured against `origin/main`, not `origin/HEAD`, and reported PASS with no note [scripts/node_freshness.py:456-458] | **fail open in that narrow case** — `origin/main` wins whenever it merely resolves, so the fallback's own promise that the ref used is printed never fires [scripts/node_freshness.py:38-41] | The ` (… is this repo's default branch)` suffix appears only for the fallback [scripts/node_freshness.py:303] | delete the stale `main` ref on the node, or extend the probe; read-from-code, not measured |
| `--json` is used and the *arguments* are wrong | `RESULT: FAIL (usage: …)` on **stdout**, the message on stderr, no JSON object, exit 2 [scripts/node_freshness.py:696-699] | **fail closed for a human, fail open for a parser** — a provisioner doing `json.load(stdout)` raises instead of reading a verdict; measured `JSONDecodeError` | Every other exit path emits the object, including exit 2 for an unreachable node [scripts/node_freshness.py:726-727] | parse the exit code first; defect 1 in §8 |
| A wide drift (>50 paths) reaches `verify-node.sh` | The probe truncates honestly with ` (+N more, see --json)` [scripts/node_freshness.py:212-219]; the parent cuts the joined FAIL rows at 500 characters [scripts/verify-node.sh:134] | **fail closed but truncated** — measured: the 55-path row is 531 characters, so the marker itself is cut and the list looks complete | A narrower drift keeps its marker | read `--json`'s `differing_files`, which is complete [scripts/node_freshness.py:659] |

## 7. Environment and settings it reads

| Setting | Where read | Default | Validation / refusal rule |
|---|---|---|---|
| `--workdir PATH` | `parse_args` [scripts/node_freshness.py:674] | none | Selects local mode via `bool(opts.workdir)` [scripts/node_freshness.py:703]; an **empty string selects nothing** and falls into the "one mode is required" refusal [scripts/node_freshness.py:707-710], so the "empty workdir path" branch below is unreachable from the CLI [scripts/node_freshness.py:381-384] |
| `--agent ID` / `--server NAME` | `parse_args` [scripts/node_freshness.py:675-676] | none | Exclusive with `--workdir` [scripts/node_freshness.py:705-706]; both halves required [scripts/node_freshness.py:711-712] |
| `--path REMOTE_PATH` | `parse_args` [scripts/node_freshness.py:677-682] | `repo` | Absolute paths are used as-is; `~/…` and bare relative paths are rebased on the **node's own** `$HOME`, printed by the battery [scripts/node_freshness.py:480-486] |
| `--timeout SECONDS` | `parse_args` [scripts/node_freshness.py:683-688] | `180` | `< 1` is refused with exit 2 [scripts/node_freshness.py:701-702]; it bounds each local git call [scripts/node_freshness.py:139-140] and the whole `bunker exec` [scripts/node_freshness.py:564-567], while the exec stream itself dies at 300 s [scripts/node_freshness.py:34-36] |
| `--json` | `parse_args` [scripts/node_freshness.py:689-693] | off | Rows move to stderr and one object to stdout [scripts/node_freshness.py:720-727] |
| `GIT_TERMINAL_PROMPT` | forced to `0` [scripts/node_freshness.py:112] | `0`, never inherited | "a probe must not hang on a credential dialog" [scripts/node_freshness.py:108] |
| `GIT_SSH_COMMAND` | inherited if set, else `ssh -o BatchMode=yes -o ConnectTimeout=10` [scripts/node_freshness.py:113-114] | the BatchMode form | This is the 10 s ceiling measured in §3 row 13; the probe carries no credential of its own, which is the fleet's credentials-as-files rule [docs/master/_facts.md:16] (fact: FACT-05) |
| `LC_ALL`, `LANG` | forced to `C` [scripts/node_freshness.py:115-116] | `C` | Keeps git's porcelain and error text parseable and comparable across hosts |
| `HOME` (control host) | `os.path.expanduser` on `--workdir` only [scripts/node_freshness.py:379] | the process `$HOME` | Used for `~/…` expansion; **never** used to build a node path — the node's home comes from the node [scripts/node_freshness.py:27-30] [scripts/node_freshness.py:574] |
| `HOME` (on the node) | `echo "HOME=$HOME"` as the battery's first act [scripts/node_freshness.py:480] | whatever the agent's shell reports | Absence is `unreachable`, exit 2 [scripts/node_freshness.py:576-584]; the home is never templated as `/home/bunker-<id>` [scripts/node_freshness.py:28-30] |
| `timeout` on the node | `command -v timeout` [scripts/node_freshness.py:502] | 120 s on the fetch when present | Without it the fetch runs unbounded inside the 300 s exec stream [scripts/node_freshness.py:503-506] |
| `CMP_REF`, `MAX_SHOWN` | module constants [scripts/node_freshness.py:75] [scripts/node_freshness.py:79] | `origin/main`, `50` | Not settable at runtime; the fallback to `origin/HEAD` is named in the row [scripts/node_freshness.py:302-304] |

There is no configuration file, no dotfile and no environment variable of its own: the five options above plus the ambient git and ssh environment are the whole input surface.

## 8. Evidence of record

- **Measured 2026-11-05**, in the worktree `proj-wt-md-28e` at `b9f56e6`, Python 3.14.4, git 2.53.0, entirely under `$TMPDIR/md25b/nf28b` with real local `origin.git` fixtures and a **stub `bunker`**. No live node was contacted and none was modified — the prohibition is honoured, and the live instance of this row is cited from the record rather than re-measured (next bullet).
- **The live `behind=26` row is this file's row.** Its shape is produced at [scripts/node_freshness.py:343] and was captured in the verify-node transcript as `  FAIL  checkout_freshness — sync — behind=26 (HEAD..origin/main e7cf075ffff4): 71 differing path(s) — …` [docs/master/36-scripts-verify-node-sh.md:103]. It is a historical observation, not the node's state today: the newer board row records the node at `origin/main` with the drift superseded ("cf-node checkout drift (superseded: node sits at origin/main as of 2026-11-05 …)") [.coding-hermes/board/tasks.jsonl:222]. Both are cited as records; neither was re-run here.
- **Suite coverage**: §47 of `tests/selftest.sh` is this module's gate. It compiles the file [tests/selftest.sh:2834-2839], builds a real local origin and clones before and after a push so one fixture must pass and one must fail [tests/selftest.sh:2847-2857], then asserts: the in-sync clone is `RESULT: PASS` exit 0 with `ancestor=true behind=0` [tests/selftest.sh:2871-2878]; an advanced origin is exit 1 naming `behind=1` and `b.txt` [tests/selftest.sh:2881-2889]; an uncommitted edit is exit 1 naming `a.txt` and "upstream" [tests/selftest.sh:2890-2900]; a detached HEAD is named [tests/selftest.sh:2902-2907]; a missing origin is refused without a crash [tests/selftest.sh:2909-2915]; bunker mode is **one** exec with the home resolved from the agent [tests/selftest.sh:2917-2943]; `--json` carries `status`/`behind`/`differing_files`/`branch` [tests/selftest.sh:2945-2952]; and layer 40 grades a clean clone PASS, a dirty one WARN and a drifted one FAIL, with `freshness{status,ladder,behind}` recorded in `node.json` [tests/selftest.sh:2967-3060]. Extracted verbatim and run standalone: 13 legs `  PASS  …`, `FAILS=0` (§3).
- **Contract coverage from the callers**: `verify-node.sh` folds the verdict into `VERIFY:` with PASS→ok, 1→bad, anything else→WARN unless `--strict-freshness` [scripts/verify-node.sh:129-143]; `project-node.sh` layer 40 runs the same probe against the clone after cloning, grades `ok`/`warn`/`bad` and records the object [scripts/project-node.sh:735-762]. One inconsistency falls out of that comparison and is not a defect in this file: an **unreachable** node (exit 2) is a WARN in `verify-node.sh` [scripts/verify-node.sh:140-142] but a hard `bad` in layer 40, whose WARN branch requires a non-empty dirty set [scripts/project-node.sh:747-751]. The same measurement is therefore graded more harshly by the provisioner than by the verify gate, and the §47 provisioning fixtures exercise only rung 2 (the inline fallback, which never returns exit 2), so the exit-2 path through layer 40 is untested.
- **Defects measured while filling this section** (`scripts/` is out of scope for this task; nothing here was fixed, and none is filed on the board yet):

  1. **A usage error under `--json` writes prose to stdout.** `usage_error` prints the verdict with a bare `print` [scripts/node_freshness.py:698] instead of the object every other path emits [scripts/node_freshness.py:726-727]. Measured: `--timeout 0 --json` leaves `RESULT: FAIL (usage: --timeout must be >= 1, got 0)` on stdout and a `JSONDecodeError` in the consumer (§3 row 20). `verify-node.sh` is immune because it does not read the JSON file on a non-zero exit [scripts/verify-node.sh:136-143]; a provisioner storing the object [scripts/project-node.sh:492] is not.
  2. **"does not exist" is printed for paths that exist.** The `exists=False` arm hard-codes the phrase and never prints `m.error` [scripts/node_freshness.py:243-247], so the distinct `is not a directory` refusal [scripts/node_freshness.py:389-392] and a missing `git` binary (measured: `FileNotFoundError: … 'git'` inside the `not-git` arm [scripts/node_freshness.py:255-261]) both surface with the wrong diagnosis. Direction is safe — every one exits 1 — but the operator is told to look for a missing directory when the real cause is a mode bit or a `PATH`.
  3. **A fetch failure is hidden exactly when the node is also behind.** The `fetch` row is gated on `behind == 0` [scripts/node_freshness.py:350], so on an unreachable origin with stale refs the run reports `behind=N` and nothing else (§3 row 12). N is a lower bound: the real lag is unknown. Measured, and the fix is one condition — name the fetch error on every failed fetch, not only on the convenient one.
  4. **`--workdir` mode does reach the network, against its own documentation.** The docstring says this mode uses "No bunker, no network, no database" [scripts/node_freshness.py:24-25] and the spec repeats it [specs/NODE.md:169], but `probe_local` runs `git fetch --quiet --no-tags origin` whenever an `origin` remote exists [scripts/node_freshness.py:426]. Measured: with `origin` pointed at the unroutable `ssh://git@192.0.2.1/x.git`, a `--workdir` run stalled for exactly 10 s (the `ConnectTimeout` from [scripts/node_freshness.py:114]) before failing the fetch. The behaviour is *safer* than the docstring — a stale ref gets caught — so the prose is what is wrong.
  5. **`--workdir ''` is read as "no mode", not as an empty path.** `local = bool(opts.workdir)` [scripts/node_freshness.py:703] makes the empty string indistinguishable from absent, so the dedicated `empty workdir path` refusal [scripts/node_freshness.py:381-384] is dead code reachable only by calling `probe_local` directly. Cosmetic; measured in §3 row 22.
  6. **The `origin/HEAD` fallback almost never fires.** `resolve_comparison_ref` returns `origin/main` whenever it merely resolves [scripts/node_freshness.py:456-458], so a repo whose default branch is `trunk` but which still carries a stale `origin/main` ref is measured against the stale ref and can print `PASS` — and the ` (… is this repo's default branch)` note that exists to prevent a mislabelled comparison [scripts/node_freshness.py:303] never appears. Read-from-code; not measured, and the narrow condition is why it is listed last.

- **Per-unit assertion — what is measured and what is not:**

| Unit | Assertion |
|---|---|
| `main` argument surface [scripts/node_freshness.py:670-712] | **measured** — all four refusals, exit 2 each; `-h` exits 0; `--workdir ''`, both modes, and one half of bunker mode each named |
| `probe_local` existence arms [scripts/node_freshness.py:376-407] | **measured** — missing path, a file, a non-git directory, a bare repo, an unborn HEAD |
| `probe_local` git arms [scripts/node_freshness.py:409-451] | **measured** — in sync, behind 2, diverged, detached, dirty, no-origin, unreachable origin with and without lag, and a `git`-less `PATH` |
| `resolve_comparison_ref` fallback [scripts/node_freshness.py:454-469] | **read-from-code** — the `origin/HEAD` branch was not exercised; no fixture had a non-`main` default with a stale `origin/main` (defect 6) |
| `classify` arms [scripts/node_freshness.py:222-370] | **measured** — every row text in §5, except the `fetch` row paired with a non-zero lag, which was measured as *absent* (defect 3) |
| `probe_bunker` [scripts/node_freshness.py:552-625] | **measured with a stub `bunker`** — one exec per run (7 runs, 7 invocations), home resolved from `HOME=`, dirty and differing blocks parsed, exit 255 and empty stream both `unreachable`/exit 2, missing checkout exit 1 |
| `parse_battery` [scripts/node_freshness.py:529-549] | **measured** — the `KEY=value` lines and both `BEGIN/END` blocks survive a real `sh -lc` round trip; non-uppercase keys were not injected, so the guard at [scripts/node_freshness.py:546-548] is read-from-code |
| A real `bunker` against a real node | **not measured here** — deliberately: a live node must not be contacted by this document. The live instance is cited from the record [docs/master/36-scripts-verify-node-sh.md:103] |
| Windows / non-POSIX paths, and a node whose `sh` is not POSIX | **not measured** — the battery is POSIX shell [scripts/node_freshness.py:475-526] and a Linux bunker is assumed [scripts/node_freshness.py:2] |
