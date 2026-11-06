# 02. scripts/board_drift.py

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/board_drift.py` — 209 lines [scripts/board_drift.py:1] |
| Repository | `code-factory` |
| Revision | `dad2749` (2026-11-05) — the tree every locator below resolves against and every measured row in §3 was taken in |
| Status | **VERIFIED — 169 locator citations (91 distinct file:line pairs), all resolving, on every claim below; cites fact: FACT-09 and fact: FACT-10; 29 state arms measured on 2026-11-05 including the whole exit ladder and every fail-open direction; six defects in §8** |

## 1. Purpose and why it matters

- What it is: a **read-only, offline census** of one checkout's board against its published copy
  [scripts/board_drift.py:2]. One verb, `check` [scripts/board_drift.py:191-192]; no `--apply`, no
  repair path, no daemon. It opens no file for writing — a grep for `open(`/`write`/`unlink`/
  `mkdir`/`rename` in the file returns nothing, and the only side effects are stdout and an exit
  code [scripts/board_drift.py:28], [scripts/board_drift.py:209].
- **What it compares — not the repo tree, and not the remote.** Two files and only two,
  `tasks.jsonl` and `events.jsonl` under `.coding-hermes/board/` [scripts/board_drift.py:12-13].
  The left side is the workdir's working-tree bytes [scripts/board_drift.py:99],
  [scripts/board_drift.py:58]. The right side — "published" — is one of:
  1. the same two paths **in a git object**, `git -C <repo> show <ref>:<path>`
     [scripts/board_drift.py:111], with `--ref` defaulting to `origin/main`
     [scripts/board_drift.py:196] and `--repo` defaulting to the workdir
     [scripts/board_drift.py:98]; or
  2. a **flat directory** of the same two names when `--published-dir` is given
     [scripts/board_drift.py:104-106].

  Nothing else is read: no scheduler, no DuckDB, no bus, no network. It never fetches, so
  "published" means *whatever the local ref says* — the documented contract is "local refs must
  already be current; the check never fetches" [docs/BOARD.md:72-73].
- **What counts as drift.** Six independent legs; each failing row increments one counter
  [scripts/board_drift.py:26-28], and the verdict is that counter
  [scripts/board_drift.py:30-32]:

  | Leg | What must hold | Where |
  |---|---|---|
  | readability | all four file reads (2 workdir + 2 published) succeed | [scripts/board_drift.py:54-63] |
  | resolution | both `git show` calls exit 0, when not `--published-dir` | [scripts/board_drift.py:107-115] |
  | non-empty | `tasks.jsonl` has ≥1 line on **each** side; the workdir side is refused *before* the published side is even resolved | [scripts/board_drift.py:100-102], [scripts/board_drift.py:69-70] |
  | byte parity | both files are exactly equal, bytes for bytes | [scripts/board_drift.py:116-133] |
  | census | per-`id` status equality; no id only in the published copy; no id only in the workdir; equal line counts; the union of those three is empty | [scripts/board_drift.py:134-162] |
  | ancestry | the workdir's `HEAD` is an ancestor of the ref, all three probes run **in the workdir** | [scripts/board_drift.py:165-185] |

  Byte parity is the strict leg and the census is the explanatory one: a file that differs only in
  key order or line endings is drift with a **zero**-divergence census (§3 rows 5-6), while a
  status flip is drift on three rows at once (§3 row 2).
- **What it does *not* count as drift**, and this is the scope that matters:
  - `events.jsonl` is never parsed — it is hashed and compared, nothing more
    [scripts/board_drift.py:116-133]. A board whose events file is corrupt passes as long as both
    copies are corrupt in the same bytes (§3 row 15, defect 1).
  - Of the ten row fields AGENTS.md requires [AGENTS.md:56-57] it reads two, `id` and `status`
    [scripts/board_drift.py:81-92]. `title`, `priority`, `reasoning`, `acceptance_criteria` are
    invisible except through byte parity — and byte parity cannot say *which* field moved.
  - "Append only. Never rewrite the file wholesale; after any write, assert the line count"
    [AGENTS.md:55] is enforced only as line-count parity plus byte equality
    [scripts/board_drift.py:156-161]. A rewrite that preserves both is indistinguishable from an
    append, and the tool has no notion of "append" at all.
  - Nothing about *content* of a row beyond its status is checked against AGENTS.md — a row that
    reaches `complete` without a re-runnable command (fact: FACT-10) is a shape this tool cannot
    see.
- **The exit ladder is two rungs, and one of them is overloaded.** `int(bool(self.failed))`
  [scripts/board_drift.py:32] through `sys.exit(main())` [scripts/board_drift.py:209] means 0 or 1
  and nothing else. Every exception — including an argparse usage error — is caught at the top
  [scripts/board_drift.py:202-204] and re-emitted as a FAIL row plus exit 1
  [scripts/board_drift.py:205]; `Parser.error` is deliberately overridden to **raise** instead of
  exiting 2 [scripts/board_drift.py:17-19]. So a typo'd flag and a genuinely divergent board both
  print `RESULT: DRIFT (1 failed)` and exit 1 (§3a). Only the row text separates them.
- **What breaks if this module is absent**: nothing mechanically, and that is the finding. No
  script, lane, cron or Makefile target invokes it; the only in-tree caller is the test suite
  [tests/selftest.sh:1213] (measured: `grep -rn board_drift scripts tests specs config Makefile`
  returns that one line). What is lost is the only re-runnable instrument behind the publish-drift
  census [docs/BOARD.md:70-83] — the command an operator is told to run before editing a checkout's
  board. Without it, "this checkout's board is the published board" is a claim with no probe, and
  the board is the fleet's memory of what is done (fact: FACT-09).
- **What breaks if it lies**: a board and a repo diverge silently. The dangerous directions are
  named in §6 and all but one are closed: unreadable sides are FAILs
  [scripts/board_drift.py:59-62] and never a green (§3 row 17: seven FAILs with neither side
  readable); an unresolvable ref is a FAIL [scripts/board_drift.py:46-50]; a zero-row board is a
  FAIL on both sides [scripts/board_drift.py:69-70], [scripts/board_drift.py:101-102]. The two
  directions still open are a **stale local ref** (the tool cannot tell that `origin/main` itself
  is behind the remote, by design [docs/BOARD.md:72-73]) and a **corrupt but identical**
  `events.jsonl` (§3 row 15).
- Who runs it: a human or an agent about to write the board, per its documented placement
  [docs/BOARD.md:72-77]. There is no schedule behind it, so a drift that nobody looks for survives
  every tick (§6, last row).

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `python3` (stdlib only) | the interpreter that runs the file; the imports are `argparse`, `hashlib`, `json`, `pathlib`, `subprocess`, `sys` [scripts/board_drift.py:4-9] | the host running the census | an `ImportError` is a traceback — the module guards its own inputs but not its imports [scripts/board_drift.py:202] |
| `git` | any version with `show`, `rev-parse`, `merge-base --is-ancestor` [scripts/board_drift.py:111], [scripts/board_drift.py:167], [scripts/board_drift.py:169], [scripts/board_drift.py:172] | `PATH` — resolved by name, not by absolute path [scripts/board_drift.py:37] | `OSError` from `subprocess.run` is caught as `ValueError` [scripts/board_drift.py:44-45] and printed as `FAIL published ref — … [Errno 2] No such file or directory: 'git'`, exit 1 (§3 row 21) |
| `<workdir>/.coding-hermes/board/{tasks,events}.jsonl` | — | built from the constant `BOARD` [scripts/board_drift.py:12] under the resolved workdir [scripts/board_drift.py:97-99] | `FAIL workdir files — <name>: [Errno N] …` per file [scripts/board_drift.py:58-62] |
| a local ref holding the board | must exist in `--repo` for the bytes leg and in `--workdir` for the ancestry leg | the two checkouts, which need not be the same one [scripts/board_drift.py:98], [scripts/board_drift.py:165-172] | `FAIL published ref — git show …: exit 128; …` and `FAIL HEAD ancestry — …` (§3 rows 20, 22) |
| a 30 s per-call bound on git | hardcoded [scripts/board_drift.py:40] | — | `subprocess.TimeoutExpired` is caught with `OSError` [scripts/board_drift.py:44-45] and reported as a `ValueError` FAIL row |

There is no third-party package, no virtualenv assumption, no data store and no service.

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `argparse` | stdlib | a required subparser makes `check` the only verb, so `board_drift.py` with no argument is an error rather than a default run [scripts/board_drift.py:191-192]. `Parser.error` is overridden to `raise ValueError(message)` [scripts/board_drift.py:17-19], which is the *only* reason a usage error becomes a FAIL row instead of `SystemExit(2)` | a bad flag would exit 2 with usage text on stderr and **no `RESULT:` line** — every caller that greps `RESULT:` would read an empty verdict, and §3a's exit ladder would gain a third rung |
| `hashlib` | stdlib | `sha256` over the exact bytes read from each side, hex-digested and printed [scripts/board_drift.py:121-123]. The digest is **evidence, not the comparison** — the comparison is `==` on the raw bytes [scripts/board_drift.py:124-132] | the printed digests would stop matching `sha256sum .coding-hermes/board/*.jsonl`, which is the one cross-check an operator has on the report; the verdict itself would not move |
| `json` | stdlib | one `json.loads` per line, decoded as UTF-8 first [scripts/board_drift.py:74]; `ValueError`/`UnicodeError`/`RecursionError` are caught together [scripts/board_drift.py:73-77] and the line is skipped with a FAIL; the record must be a `dict` [scripts/board_drift.py:78-80] and only `id` and `status` are read from it [scripts/board_drift.py:81-91] | a stricter or lazier parser changes which lines are "invalid"; nothing else in the tool touches the decoded record, so no other row moves |
| `pathlib` | stdlib | `Path(...).expanduser().resolve()` for both sides [scripts/board_drift.py:97-98], [scripts/board_drift.py:105]; `BOARD / name` forms the in-repo path used in the `git show` argument [scripts/board_drift.py:111]; `Path(__file__).resolve().parent.parent` is the default workdir [scripts/board_drift.py:193-194] | `~` and relative paths would resolve differently; the default workdir would stop being the repo the script lives in (it is *not* the cwd — measured, §7) |
| `subprocess` | stdlib | `run(..., stdout=PIPE, stderr=PIPE, timeout=30, check=False)` [scripts/board_drift.py:36-43]; a non-zero exit is **data**, turned into a `ValueError` carrying the first line of stderr [scripts/board_drift.py:46-50] | if `check` flipped to `True`, every drift and every bad ref would raise out of `git()` and the report would lose its per-leg rows; if `stderr` stopped being captured, the FAIL rows would say `not an ancestor` for every git error (that string is already the empty-stderr fallback, §8 defect 3) |
| `sys` | stdlib | `sys.exit(main())` [scripts/board_drift.py:209] — the process status *is* `Report.finish()` | any other exit path would reintroduce an exit code the ladder does not document |

### 2c. Service contracts (both sides must be named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| the board, workdir side | reader → filesystem | `Path.read_bytes()` [scripts/board_drift.py:58] | the raw bytes of `tasks.jsonl` and `events.jsonl` | written by whatever holds the board: the `boardctl` CLI (`scripts/boardctl` is an `exec` of the external binary, [scripts/boardctl:21]) or a hand edit under the rules at [AGENTS.md:54-62]. **The tool never calls the writer and the writer never calls the tool** — the only shared contract is the file shape, and only two of the fields are read (fact: FACT-09) |
| the board, published side | reader → git object store | `git -C <repo> show <ref>:<path>`, stdout captured [scripts/board_drift.py:109-115] | the two board paths at one ref | git itself; the ref must already have been fetched — nothing here fetches [docs/BOARD.md:72-73] |
| `--published-dir` | reader → filesystem | `Path.read_bytes()` on a **flat** directory [scripts/board_drift.py:104-106] | `tasks.jsonl` and `events.jsonl` at the directory root, *not* under `.coding-hermes/board/` | any copy of a board, e.g. a second checkout or a fixture; this is the mode the suite drives [tests/selftest.sh:1213] |
| `git` CLI | outbound, 1-3 execs per run | argv, `-C <repo|workdir>` [scripts/board_drift.py:37] | `show <ref>:<path>`, `rev-parse HEAD`, `rev-parse --verify <ref>^{commit}`, `merge-base --is-ancestor HEAD <ref>` | the local repository; no remote, no credential, no network call |
| `tests/selftest.sh` arm 29 | driver → module | subprocess, stdout text matched with `grep -Fq` [tests/selftest.sh:1213-1218] | `--workdir <fixture>` plus `--published-dir <published>` [tests/selftest.sh:1213-1214] | the suite asserts the exit code, one expected row, the expected `RESULT:` line and the absence of a traceback [tests/selftest.sh:1215-1218], over seven fixtures [tests/selftest.sh:1201-1211]. It matches **text**, so a reworded row silently stops being asserted |

## 3. Verification

There is no `--selftest`. The repository suite drives the module in section 29
[tests/selftest.sh:1155-1237] over seven arms — `red`, `green`, `zero`, `missing`, `malformed`,
`nonobject`, `event-drift` — asserting a specific row plus the verdict line plus no traceback
[tests/selftest.sh:1205-1218], and additionally requiring the red arm to name both a flipped and a
deleted id [tests/selftest.sh:1219-1223]. That is real coverage of the happy path and four failure
paths; what it does not cover is the git-backed legs, the ancestry ladder, usage errors, and the
directions in §6 that stay open.

The table below was run on **2026-11-05** in `~/proj-wt-md-28e` at `dad2749`, Python 3.14.4, git
2.53.0, against throwaway fixtures in the scratch dir: a three-row `tasks.jsonl`
(`CF-001 complete`, `CF-002 pending`, `CF-003 in_progress`) and a two-line `events.jsonl`, copied
into each arm and mutated in place. Every command is re-runnable; `py()` below is
`python3 -B scripts/board_drift.py`.

| # | Check | Command | Expected | Result |
|---|---|---|---|---|
| 1 | identical bytes, `--published-dir` | `py check --workdir green --published-dir published` | `RESULT: OK`, exit 0 | **PASS** — `RESULT: OK` 0, 13 PASS rows |
| 2 | one status flipped `pending`→`complete` | same, arm `status` | FAIL, exit 1 | **PASS** — `RESULT: DRIFT (3 failed)`: parity, `board status`, `board rows` |
| 3 | one row deleted | same, arm `missing` | FAIL naming the id | **PASS** — `FAIL board missing ids — CF-003`, `2 vs 3 rows`, exit 1 |
| 4 | one row added | same, arm `extra` | FAIL naming the id | **PASS** — `FAIL board extra ids — CF-999`, `4 vs 3 rows`, exit 1 |
| 5 | same statuses, keys reordered | same, arm `byteonly` | parity FAIL, census PASS | **PASS** — `RESULT: DRIFT (2 failed)`, `PASS board rows — 3 vs 3 rows; 0 divergent ids: none` |
| 6 | CRLF line ending only | same, arm `crlf` | parity FAIL, census PASS | **PASS** — `RESULT: DRIFT (1 failed)` |
| 7 | workdir `tasks.jsonl` zero bytes | same, arm `zero` | refused before the published side resolves | **PASS** — `FAIL board rows — tasks.jsonl has 0 rows` printed *before* the `published files` rows, `RESULT: DRIFT (4 failed)` |
| 8 | **both** sides zero rows | same, arms `zero-w`/`zero-p` | FAIL on both sides | **PASS, with defect 2** — two `FAIL board rows` rows and then a `PASS board rows — 0 vs 0 rows` |
| 9 | duplicate id | same, arm `dup` | line-named FAIL | **PASS** — `FAIL workdir tasks.jsonl line 4 — duplicate id CF-002` |
| 10 | `status: "done"` | same, bad-status arm | line-named FAIL | **PASS** — `FAIL workdir tasks.jsonl line 2 — CF-002: missing or invalid status` |
| 11 | line 2 is `{` | same, arm `malformed` | `invalid JSON` naming line 2 | **PASS** — `FAIL workdir tasks.jsonl line 2 — invalid JSON: Expecting property name enclosed in double quotes: line 1 column 2 (char 1)` |
| 12 | line 2 is `null` | same, arm `nonobject` | `expected JSON object` | **PASS** — `FAIL workdir tasks.jsonl line 2 — expected JSON object` |
| 13 | `id` is a number | same, arm `idtype` | invalid id, not a crash | **PASS** — `FAIL workdir tasks.jsonl line 1 — missing or invalid id` |
| 14 | UTF-8 BOM on line 1 | same, arm `bom` | invalid JSON, not a silent pass | **PASS** — `FAIL workdir tasks.jsonl line 1 — invalid JSON: Unexpected UTF-8 BOM (decode using utf-8-sig): line 1 column 1 (char 0)` |
| 15 | **identical corrupt `events.jsonl` on both sides** | same, `events.jsonl` replaced with `\x00\x01 not events\n` on both | a drift check should refuse unparseable events | **FAILS — `RESULT: OK`, exit 0** (defect 1) |
| 16 | workdir `events.jsonl` missing | same, arm `missing` (event) | named FAIL | **PASS** — `FAIL workdir files — events.jsonl: [Errno 2] …`, exit 1 |
| 17 | **neither side readable** | `py check --workdir <empty> --published-dir <empty>` | never a green | **PASS** — seven FAILs: 4 `files`, 2 `byte parity … unavailable board file`, 1 `census unavailable`, `RESULT: DRIFT (7 failed)` |
| 18 | `tasks.jsonl` mode 000 | same, arm `perm` | named permission FAIL | **PASS** — `FAIL workdir files — tasks.jsonl: [Errno 13] Permission denied: …` |
| 19 | `tasks.jsonl` is a directory | same, arm `dirfile` | named FAIL, no traceback | **PASS** — `FAIL workdir files — tasks.jsonl: [Errno 21] Is a directory: …` |
| 20 | unknown ref | `py check --workdir . --ref nosuchref` | FAIL, exit 1 | **PASS** — `FAIL published ref — git show nosuchref:…: exit 128; fatal: invalid object name 'nosuchref'.`, `RESULT: DRIFT (6 failed)` |
| 21 | no `git` on `PATH` | `env PATH=/nonexistent python3 -B … check --workdir .` | FAIL, never a green | **PASS** — `FAIL published ref — … [Errno 2] No such file or directory: 'git'`, `FAIL HEAD ancestry — …`, `RESULT: DRIFT (6 failed)` |
| 22 | workdir is not a git repo, `--repo` has the ref | `py check --workdir <bare> --repo <repo> --ref main` | published bytes resolve; ancestry does not | **PASS, misattributed** — the bytes legs PASS and `FAIL HEAD ancestry — git rev-parse HEAD: exit 128; fatal: not a git repository`; the same run with `--no-head` is `RESULT: DRIFT (3 failed)` and no ancestry row (defect 5) |
| 23 | `--ref` is a sha, not a branch | `py check --workdir . --ref 6c56b49` | `RESULT: OK` | **PASS** — `PASS published ref — 6c56b49:.coding-hermes/board/tasks.jsonl resolved`, exit 0 |
| 24 | board identical, `HEAD` one commit **ahead** of the ref | `py check --workdir . --ref published` after an unrelated commit | DRIFT, ancestry only | **PASS** — `FAIL HEAD ancestry — HEAD=6c56b4… published=d808138…; … exit 1; not an ancestor`, `RESULT: DRIFT (1 failed)` |
| 25 | board identical, workdir **behind** the ref | checkout the base commit, `--ref main` | OK | **PASS** — `PASS HEAD ancestry — … exit 0`, `RESULT: OK` |
| 26 | `--no-head` / `--published-dir` suppress the ancestry leg | arms C3/C4 | no `HEAD` rows at all | **PASS** — both print `RESULT: OK` on a tree whose `HEAD` is ahead |
| 27 | unknown flag / no subcommand | `py check --workdir . --nope`; `py` | exit 1, one `input` row, no traceback | **PASS** — `FAIL input — ValueError: unrecognized arguments: --nope` then `RESULT: DRIFT (1 failed)`; `py` gives `FAIL input — ValueError: the following arguments are required: command` |
| 28 | workdir does not exist | `py check --workdir /nonexistent/x` | FAIL on every leg | **PASS** — 8 FAILs, `RESULT: DRIFT (8 failed)` |
| 29 | the real checkout | `py check --workdir .` (default `--ref origin/main`) | a verdict, not a crash | **DRIFT (4 failed)** at `dad2749`: `tasks.jsonl` differs, `events.jsonl` identical, ids `CF-302…CF-311` present only in the published copy (`275 vs 285 rows`), and `HEAD dad2749` is not an ancestor of `origin/main 6eea792` |

Transcript 1 — rows 1 and 2, the green and the status flip, literal (the fixture's absolute paths
elided to `…/`):

```
$ python3 -B scripts/board_drift.py check --workdir …/green --published-dir …/published
PASS  workdir files — tasks.jsonl: 146 bytes
PASS  workdir files — events.jsonl: 98 bytes
PASS  published files — tasks.jsonl: 146 bytes
PASS  published files — events.jsonl: 98 bytes
PASS  sha256 workdir tasks.jsonl — dd8731ee56f981d7496a8f3bfaf9323f7aec4fc9a11ef6f987918659193efb2b
PASS  sha256 published tasks.jsonl — dd8731ee56f981d7496a8f3bfaf9323f7aec4fc9a11ef6f987918659193efb2b
PASS  byte parity tasks.jsonl — identical
PASS  sha256 workdir events.jsonl — 6bb0ef9f02617788e85d7a04e22abd74be115a475f0ae55a4d66e30720a70c39
PASS  sha256 published events.jsonl — 6bb0ef9f02617788e85d7a04e22abd74be115a475f0ae55a4d66e30720a70c39
PASS  byte parity events.jsonl — identical
PASS  board missing ids — none
PASS  board extra ids — none
PASS  board rows — 3 vs 3 rows; 0 divergent ids: none
RESULT: OK
EXIT=0
$ # CF-002 flipped pending -> complete in the workdir copy only
# … the four `files` rows and four `sha256` rows are unchanged and trimmed here
FAIL  byte parity tasks.jsonl — bytes differ
FAIL  board status — CF-002: workdir=complete published=pending
PASS  board missing ids — none
PASS  board extra ids — none
FAIL  board rows — 3 vs 3 rows; 1 divergent ids: CF-002
RESULT: DRIFT (3 failed)
EXIT=1
```

Transcript 2 — rows 24 and 12, the ancestry-only failure and the usage path, literal:

```
$ python3 -B scripts/board_drift.py check --workdir . --ref published
# … ten PASS rows trimmed here (2 `files`, 2 `published ref`, 4 `sha256`, `missing ids`, `extra ids`)
PASS  byte parity tasks.jsonl — identical
PASS  byte parity events.jsonl — identical
PASS  board rows — 2 vs 2 rows; 0 divergent ids: none
PASS  HEAD — git rev-parse HEAD: 6c56b4981318878972d22655de4c8c2eb50a8fc9
FAIL  HEAD ancestry — HEAD=6c56b4981318878972d22655de4c8c2eb50a8fc9 published=d808138271a0764f800513ba416a60c83816664f; git merge-base --is-ancestor HEAD published: exit 1; not an ancestor
RESULT: DRIFT (1 failed)
EXIT=1
$ python3 -B scripts/board_drift.py check --workdir . --nope
FAIL  input — ValueError: unrecognized arguments: --nope
RESULT: DRIFT (1 failed)
EXIT=1
$ python3 -B scripts/board_drift.py
FAIL  input — ValueError: the following arguments are required: command
RESULT: DRIFT (1 failed)
EXIT=1
```

Transcript 3 — rows 7 and 17, the two "nothing to compare" states, literal:

```
$ python3 -B scripts/board_drift.py check --workdir …/zero --published-dir …/published
PASS  workdir files — tasks.jsonl: 0 bytes
PASS  workdir files — events.jsonl: 98 bytes
FAIL  board rows — tasks.jsonl has 0 rows
PASS  published files — tasks.jsonl: 146 bytes
PASS  published files — events.jsonl: 98 bytes
# … four PASS `sha256` rows trimmed here, then both parity rows FAIL
FAIL  board missing ids — CF-001,CF-002,CF-003
PASS  board extra ids — none
FAIL  board rows — 0 vs 3 rows; 3 divergent ids: CF-001,CF-002,CF-003
RESULT: DRIFT (4 failed)
EXIT=1
$ python3 -B scripts/board_drift.py check --workdir …/empty-w --published-dir …/empty-p
FAIL  workdir files — tasks.jsonl: [Errno 2] No such file or directory: '…/.coding-hermes/board/tasks.jsonl'
FAIL  workdir files — events.jsonl: [Errno 2] No such file or directory: '…/.coding-hermes/board/events.jsonl'
FAIL  published files — tasks.jsonl: [Errno 2] No such file or directory: '…/tasks.jsonl'
FAIL  published files — events.jsonl: [Errno 2] No such file or directory: '…/events.jsonl'
FAIL  byte parity tasks.jsonl — unavailable board file
FAIL  byte parity events.jsonl — unavailable board file
FAIL  board rows — census unavailable: missing tasks.jsonl
RESULT: DRIFT (7 failed)
EXIT=1
```

### 3a. The exit ladder, measured

| State | Rows that carry the verdict | Verdict line | Exit |
|---|---|---|---|
| every leg passes | all `PASS` | `RESULT: OK` | 0 |
| one leg fails (row 24, ancestry only) | 1 `FAIL` | `RESULT: DRIFT (1 failed)` | 1 |
| several legs fail (row 28) | 8 `FAIL` | `RESULT: DRIFT (8 failed)` | 1 |
| bad flag, missing subcommand, bad path | `FAIL input — <ExcType>: <msg>` | `RESULT: DRIFT (1 failed)` | 1 |
| `--help` | argparse usage text, **no** `RESULT:` line | — | 0 |

The counter is a count of **rows**, not of distinct checks [scripts/board_drift.py:27]: one broken
file can produce two rows (`workdir files` and `byte parity`), so `(N failed)` is a weight, never a
number of independent defects.

## 4. Metrics emitted

**None.** The module writes no counter, no status file, no JSON document and no log sink; there is
no `open(..., 'w')`, no `os.environ`/`getenv`, no `logging` and no `fetch` anywhere in the file
(measured: `grep -c 'os\.\|environ\|getenv\|fetch\|logging' scripts/board_drift.py` → `0`). Its
output is a single stream of rows for a human [scripts/board_drift.py:28] terminated by one verdict
line [scripts/board_drift.py:31].

The numbers it does print are **per-run readings, not metrics**: a byte length per file
[scripts/board_drift.py:62], a sha256 per file per side [scripts/board_drift.py:121-123], and two row
counts plus a divergence count [scripts/board_drift.py:160-161]. Nothing accumulates them — no
in-tree consumer parses the values (the suite greps for the *presence* of a row, not its number
[tests/selftest.sh:1216-1217]) — so the drift rate across checkouts, how many checkouts are
divergent right now, the age of the oldest divergence and the time a run takes are all unanswerable
from any store. The exit code cannot stand in: it has two values and, per §3a, a usage error and a
genuine drift both produce 1, so a monitor would have to parse `RESULT:` from stdout to tell them
apart. This is why the board's own "current measured state" block is still typed by hand
[docs/BOARD.md:110-115].

## 5. Log lines it can generate

There is no logging framework and no severity enum: the first token of every row is `PASS` or
`FAIL`, followed by **two spaces**, the check name, then ` — ` and the value
[scripts/board_drift.py:28]. All rows go to **stdout**; nothing is written to stderr, and there is no
`--json` or quiet mode. **Kind** is *evidentiary* where the line reports something a child process,
the filesystem or a byte comparison actually returned and could have failed, and *descriptive* where
it restates a decision the tool already made.

| Check name | Line (verbatim shape, from source) | Emitted when | Kind |
|---|---|---|---|
| `workdir files` / `published files` | `PASS  {side} files — {name}: {n} bytes` [scripts/board_drift.py:62] | a board file was read | evidentiary — the byte length is the read |
| same | `FAIL  {side} files — {name}: {exc}` [scripts/board_drift.py:60] | the read raised `OSError`/`ValueError` (absent, EACCES, EISDIR) | evidentiary |
| `published ref` | `PASS  published ref — {ref}:{BOARD}/{name} resolved` [scripts/board_drift.py:115] | `git show` exited 0 | evidentiary |
| same | `FAIL  published ref — git show {ref}:{path}: exit {n}; {stderr first line}` [scripts/board_drift.py:46-50] | the ref or the path does not resolve, or git is absent/timed out | evidentiary |
| `sha256 workdir {name}` / `sha256 published {name}` | `PASS  sha256 {side} {name} — {64 hex}` [scripts/board_drift.py:119-123] | that side was readable | evidentiary — a computed digest an operator can re-derive with `sha256sum` |
| `byte parity {name}` | `PASS  byte parity {name} — identical` [scripts/board_drift.py:128-133] | both sides present and equal | evidentiary |
| same | `FAIL  byte parity {name} — bytes differ` [scripts/board_drift.py:128-133] | both present, unequal | evidentiary |
| same | `FAIL  byte parity {name} — unavailable board file` [scripts/board_drift.py:132] | one side missing | evidentiary of absence |
| `{side} tasks.jsonl line {n}` | `FAIL  workdir tasks.jsonl line 2 — invalid JSON: …` [scripts/board_drift.py:76] | a line does not parse, decode, or nests too deep | evidentiary |
| same | `FAIL  {side} tasks.jsonl line {n} — expected JSON object` [scripts/board_drift.py:79] | the line parses to something that is not a dict | evidentiary |
| same | `FAIL  {side} tasks.jsonl line {n} — missing or invalid id` [scripts/board_drift.py:84] | `id` absent, empty, or not a string | evidentiary |
| same | `FAIL  {side} tasks.jsonl line {n} — duplicate id {id}` [scripts/board_drift.py:87] | the id was already seen in this file | evidentiary |
| same | `FAIL  {side} tasks.jsonl line {n} — {id}: missing or invalid status` [scripts/board_drift.py:90] | `status` is not one of the four [scripts/board_drift.py:14] | evidentiary |
| `board status` | `FAIL  board status — {id}: workdir={a} published={b}` [scripts/board_drift.py:149-153] | an id present on both sides carries different statuses | evidentiary |
| `board missing ids` | `PASS  board missing ids — none` / `FAIL  board missing ids — CF-003,CF-004` [scripts/board_drift.py:154] | ids in the **published** copy that are absent from the workdir | evidentiary — direction is workdir-relative |
| `board extra ids` | `PASS  board extra ids — none` / `FAIL  board extra ids — CF-999` [scripts/board_drift.py:155] | ids in the **workdir** that the published copy lacks | evidentiary |
| `board rows` | `PASS  board rows — {w} vs {p} rows; {n} divergent ids: {csv\|none}` [scripts/board_drift.py:157-162] | both censuses were built | evidentiary — the two line counts |
| same | `FAIL  board rows — tasks.jsonl has 0 rows` [scripts/board_drift.py:102] | the workdir board is empty; refused before the published side is resolved | evidentiary |
| same | `FAIL  board rows — published tasks.jsonl has 0 rows` [scripts/board_drift.py:70] | the published board is empty | evidentiary |
| same | `FAIL  board rows — census unavailable: missing tasks.jsonl` [scripts/board_drift.py:164] | either side's `tasks.jsonl` could not be read | evidentiary of absence |
| `HEAD` | `PASS  HEAD — git rev-parse HEAD: {40 hex}` [scripts/board_drift.py:168] | the ancestry leg ran and `rev-parse` succeeded | evidentiary |
| `HEAD ancestry` | `PASS  HEAD ancestry — git merge-base --is-ancestor HEAD {ref}: exit 0; HEAD={a} {ref}={b}` [scripts/board_drift.py:178-183] | `HEAD` is an ancestor of the ref | evidentiary |
| same | `FAIL  HEAD ancestry — HEAD={a} {ref}={b}; {exc}` [scripts/board_drift.py:174-176] | not an ancestor, or the ref/HEAD did not resolve | evidentiary |
| `input` | `FAIL  input — {ExcType}: {msg}` [scripts/board_drift.py:204] | any exception escaped `check` — a bad flag, a missing subcommand, an unresolvable path | descriptive — it restates an exception the tool caught itself |
| verdict | `RESULT: OK` [scripts/board_drift.py:31] | zero failing rows | descriptive — restates the exit code |
| verdict | `RESULT: DRIFT ({n} failed)` [scripts/board_drift.py:31] | one or more failing rows | descriptive |

Two properties an operator needs: the verdict line is the **last** thing printed on every path
including the exception path [scripts/board_drift.py:202-205], so `tail -1` is a safe read; and the
same check name can appear several times in one run (`board rows` appears up to three times, §3 row
8), so `grep -c` counts rows, not checks.

## 6. Failure modes

Direction is the fail-open / fail-closed sense: what the failure does to the verdict and the exit
status. "Fail-open" means something unmeasured can still print `RESULT: OK`.

| Failure | Direction | Presents as | Distinguished from | Recovery |
|---|---|---|---|---|
| A workdir board file is missing, unreadable, or is a directory | **fail-closed** | `FAIL workdir files — <name>: [Errno N] …` plus `FAIL byte parity … unavailable board file` [scripts/board_drift.py:58-62] | a file that exists but differs: that is `bytes differ` with both `files` rows PASS | restore the file; the row names the errno and the absolute path |
| The published ref or path does not resolve | **fail-closed** | `FAIL published ref — git show …: exit 128; fatal: …` [scripts/board_drift.py:46-50] | a ref that resolves but carries a different board: parity rows say `bytes differ` | fetch the ref, or pass `--ref`/`--repo` for the copy you actually mean |
| `git` is absent or the call times out | **fail-closed to the same rows** | `FAIL published ref — … [Errno 2] No such file or directory: 'git'`, `FAIL HEAD ancestry — git rev-parse HEAD: …` (row 21) | a ref that merely does not exist says `exit 128; fatal: invalid object name` | install git / raise the wall-clock budget (the 30 s bound is hardcoded [scripts/board_drift.py:40]) |
| The workdir board is empty | **fail-closed, and early** | `FAIL board rows — tasks.jsonl has 0 rows` printed **before** any published row [scripts/board_drift.py:100-102] | an empty published board, which is refused separately at [scripts/board_drift.py:69-70] | restore the board; a zero-row board is never a parity result |
| **Both** boards are empty | fail-closed, but **self-contradictory** | two `FAIL board rows` rows and then `PASS board rows — 0 vs 0 rows; 0 divergent ids: none` (§3 row 8, defect 2) | a single empty side, which prints one FAIL | ignore the PASS; it is the same check name reporting the census of two empty files |
| A line is not JSON, not an object, has a bad/duplicate id, or a bad status | **fail-closed, per line** | `FAIL <side> tasks.jsonl line N — <reason>` [scripts/board_drift.py:73-91] | a row deleted cleanly (no line row, just `missing ids`) | fix the line; the report names the side, the line number and the id |
| A row's status differs | **fail-closed** | `FAIL board status — <id>: workdir=A published=B` [scripts/board_drift.py:148-153] | a row present on one side only (missing/extra id) | reconcile the row against the published copy; note the tool will not tell you which side is *right* |
| Bytes differ while every id and status match (key order, spacing, CRLF) | **fail-closed on parity, green on census** | `FAIL byte parity <file> — bytes differ` with `PASS board rows — … 0 divergent ids: none` (§3 rows 5-6) and exit 1 | a status change, which always also moves `board status` | rewrite the file from the published copy, or accept that a cosmetic rewrite is drift by definition |
| `HEAD` has commits the ref does not (board may still be identical) | **fail-closed** | `FAIL HEAD ancestry — … exit 1; not an ancestor`, `RESULT: DRIFT (1 failed)` (row 24) | a board that also differs: that adds parity and census rows | push the workdir commits; `--no-head` hides the leg deliberately (row 26) |
| The workdir is **behind** the ref with an identical board | **passes** — correctly | `PASS HEAD ancestry — … exit 0`, `RESULT: OK` (row 25) | an ahead workdir, which fails ancestry | nothing to do; being behind without board divergence is not drift |
| **The local ref is stale** (nobody fetched) | **fail-open, and the main one** | `RESULT: OK` against a ref that itself lags the remote — the tool never fetches [docs/BOARD.md:72-73] | nothing in the output distinguishes a fresh ref from a stale one | fetch first; the tool has no way to know, so freshness is the caller's precondition |
| **A corrupt `events.jsonl` that both sides share** | **fail-open into a green** | `PASS byte parity events.jsonl — identical`, `RESULT: OK`, exit 0 (§3 row 15, defect 1) | a corruption on one side only, which is `bytes differ` | none from this tool: events are hashed, never parsed [scripts/board_drift.py:116-133] |
| A row field other than `id`/`status` is wrong on both sides | **fail-open into a green for the census**, caught by parity if the copies differ | `PASS board rows`, `RESULT: OK` when the bytes match | a divergent copy, which fails parity | out of scope by construction: only two fields are read [scripts/board_drift.py:81-91] |
| `--no-head` is passed, or `--published-dir` is used | **fail-open by flag, deliberately** | no `HEAD`/`HEAD ancestry` rows at all [scripts/board_drift.py:165] (row 26) | a run that prints `FAIL HEAD ancestry` | know which mode you are in: an unpublished commit is invisible under either flag |
| A row is filtered out as invalid, then counted as "divergent" | **fail-closed, mislabelled** | `FAIL board rows — 3 vs 3 rows; 1 divergent ids: CF-001` where `CF-001` was never parsed (§3 rows 13-14) | a true status divergence, which has its own `board status` row | read the line-number row, not the summary; the summary's `divergent` = union of divergent, missing and extra [scripts/board_drift.py:156-157] |
| `--workdir` is not a git repo while `--repo` is | **fail-closed, misattributed** | `FAIL HEAD ancestry — git rev-parse HEAD: exit 128; fatal: not a git repository`, though the ref exists in `--repo` (row 22, defect 5) | a ref that does not exist, whose message names the ref | pass `--no-head` when the ref lives only in `--repo` [docs/BOARD.md:85-99] |
| Usage error: bad flag, no subcommand, `--help` | **fail-closed, exit 1** (0 for `--help`) | `FAIL input — ValueError: …` then `RESULT: DRIFT (1 failed)` (row 27) | real drift, which has at least one leg row and no `input` row | fix the invocation; **there is no exit 2**, so a wrapper script keying on `$?` cannot separate the two |
| Nobody runs it | **fail-open at fleet level** | nothing at all — no scheduled caller exists (only [tests/selftest.sh:1213]) | a lane that owns a different check | the census is manual by design [docs/BOARD.md:72-77]; schedule it if the board's freshness has to be enforced |

## 7. Environment and settings it reads

There is no configuration file and no environment variable of its own: `BOARD`, `FILES` and
`STATUSES` are constants [scripts/board_drift.py:12-14], and a grep for `os.environ`/`getenv`
returns no match (measured, §4). The only inherited environment that changes behaviour is `PATH`
(git is resolved by name [scripts/board_drift.py:37]) and `HOME`, used implicitly through
`expanduser` when an argument starts with `~` [scripts/board_drift.py:97-98],
[scripts/board_drift.py:105].

| Flag | Default | Meaning / effect if unset |
|---|---|---|
| `--workdir PATH` | `Path(__file__).resolve().parent.parent` [scripts/board_drift.py:193-194] — the repo the script lives in, **not** the cwd | the left side of every comparison, and the repo the ancestry leg runs in [scripts/board_drift.py:97], [scripts/board_drift.py:167-172]. Measured: the same run from `/tmp` reads the script's own repo, not `/tmp` |
| `--ref REF` | `origin/main` [scripts/board_drift.py:196] | the published revision; must already exist locally — nothing fetches [docs/BOARD.md:72-73]. A checkout whose default branch is `main` without a remote-tracking ref fails on both the bytes and the ancestry legs (§3 row 20 shape) |
| `--repo PATH` | the workdir [scripts/board_drift.py:98] | **only** the repository the published bytes are read from [scripts/board_drift.py:111]; it does not move the ancestry leg, which always uses `--workdir` (defect 5) |
| `--published-dir DIR` | unset | read the published board from a flat directory instead of git [scripts/board_drift.py:104-106] and skip the ancestry leg entirely, with or without `--no-head` [scripts/board_drift.py:165] |
| `--no-head` | off [scripts/board_drift.py:199] | suppress the `HEAD` and `HEAD ancestry` rows [scripts/board_drift.py:165] — the only way to silence an unpublished-commit failure without touching the repo |
| `--help` | — | argparse usage text, exit 0, no `RESULT:` line |

Time bound: 30 s per git call [scripts/board_drift.py:40]. No other timeout, no retry, no backoff,
no locking — two concurrent runs cannot interfere because neither writes anything.

## 8. Evidence of record

- **Measured 2026-11-05** in a worktree of `dad2749` (`~/proj-wt-md-28e`), Python 3.14.4, git 2.53.0,
  on the control host only. Every arm in §3 re-uses throwaway fixture directories under the scratch
  path and mutates them in place; the git arms use a locally-created repository with a `published`
  branch, so the ancestry ladder was exercised without touching any real board. No bunker, no
  network, no remote.
- **The fixture is a hand-built board, not the real one**: three rows with only `id`/`status`, and a
  two-line events file. That is deliberate — the tool reads only those two fields
  [scripts/board_drift.py:81-91], so a richer fixture would prove nothing extra about it. Row 29 is
  the real board, and it was measured read-only in the worktree.
- **Existing suite coverage**: section 29 [tests/selftest.sh:1155-1237] — seven arms (red, green,
  zero, missing, malformed, nonobject, event-drift) asserting an exact row, the verdict line and no
  traceback [tests/selftest.sh:1205-1218], with the red arm additionally required to name both a
  flipped and a deleted id [tests/selftest.sh:1219-1223]. It does not cover the git-backed bytes
  leg, the ancestry ladder, usage errors, or rows 8, 15 and 22 above.
- **Contradictions found and recorded, not fixed** (this task touches one document; the code was left
  byte-identical, verified by `git status --porcelain scripts/board_drift.py` returning nothing):

| # | Defect | Evidence |
|---|---|---|
| 1 | **`events.jsonl` is never parsed.** It is read, hashed and compared [scripts/board_drift.py:116-133], but `parse_tasks` is called only for `tasks.jsonl` [scripts/board_drift.py:135-137]. A board whose events file is unparseable passes as long as both copies carry the same bytes: measured `RESULT: OK`, exit 0, with `\x00\x01 not events\n` on both sides (§3 row 15). Every other consumer of the board would choke on that file | measured |
| 2 | **A doubly-empty board prints a PASS row for a check it just failed.** `FAIL board rows — tasks.jsonl has 0 rows` [scripts/board_drift.py:102], `FAIL board rows — published tasks.jsonl has 0 rows` [scripts/board_drift.py:70], then `PASS board rows — 0 vs 0 rows; 0 divergent ids: none` [scripts/board_drift.py:157-162] — three rows under one check name, two verdicts (§3 row 8). A `grep '^PASS  board rows'` on that run succeeds | measured |
| 3 | **`not an ancestor` is the fallback reason for any git failure with empty stderr** [scripts/board_drift.py:49]. The message is used by every `git()` caller, so a permissions error, a missing object or a killed process whose stderr is empty is reported as an ancestry verdict | read-from-code |
| 4 | **A usage error is indistinguishable from drift.** `Parser.error` raises [scripts/board_drift.py:17-19], the top-level handler turns it into `FAIL input` and exit 1 [scripts/board_drift.py:202-205], and there is no exit 2 anywhere. Measured for an unknown flag and a missing subcommand (§3 row 27); a wrapper keying on `$?` sees `1` either way | measured |
| 5 | **`--repo` does not move the ancestry leg.** The published bytes come from `--repo` [scripts/board_drift.py:98], [scripts/board_drift.py:111] while `rev-parse`/`merge-base` run in `--workdir` [scripts/board_drift.py:167-172]; a workdir with no git therefore fails `HEAD ancestry` even when `--repo` holds the ref (§3 row 22). Documented as a flag contract [docs/BOARD.md:85-99] rather than corrected | measured |
| 6 | **The row-count summary calls absent ids "divergent".** `all_ids` is the union of divergent, missing and extra [scripts/board_drift.py:156-157], so a row that failed to parse is reported as `1 divergent ids: CF-001` with no `board status` row to match (§3 rows 13-14) | measured |

Facts cited: `fact: FACT-09` (the board is `.coding-hermes/board/tasks.jsonl`, append-only, one JSON
object per line) and `fact: FACT-10` (a row closes only with a re-runnable command in its evidence) —
the two claims that make a board/published divergence expensive and this census the right shape of
answer. The module enforces the first only as byte-and-line-count parity and cannot see the second at
all (§1).
