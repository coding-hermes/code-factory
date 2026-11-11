# 03. scripts/board_lock.py

| Field | Value |
|---|---|
| Path | `~/code-factory/scripts/board_lock.py` |
| Repository | `code-factory` |
| Revision | `373f71a` — the tree every locator below resolves against. The source itself last changed in `a012d02` (2026-11-03) and is byte-identical at HEAD. |
| Status | **VERIFIED — 89 locators, all resolve; facts cited** |

The module prints exactly one verdict line and exits 0 (`scripts/board_lock.py:26`). There is no
state, no daemon, no socket: it is an adjudicator over one file's present-or-held question.

## 1. Purpose and why it matters

`.coding-hermes/board/.lock` is real, is 0 bytes, and cannot clean itself up: `.gitignore:20`
ignores it, so no checkout, reset or clone ever removes it (measured 2026-11-05: 0 bytes, mtime
`2026-11-03 07:40:02`). It sits beside a board that is append-only (`fact: FACT-09`). No file in the
tree declares itself its writer, and the only consumer check the module can make — a bytes scan for
`flock|fcntl` under `scripts/boardctl*` (`scripts/board_lock.py:97`, pattern at
`scripts/board_lock.py:46`) — measures 0 (`consumers=0`, 2026-11-05).

- **If this module is absent**, every lane has to re-derive by hand whether that file is a barrier.
  The two hand answers are both wrong in expensive ways: treating it as an ownership barrier stalls
  appends to the only board the project has (`fact: FACT-09`), and deleting it destroys the one piece
  of evidence a later tick would want. The module makes the derivation one re-runnable command,
  which is the same standard the board applies to closing a row (`fact: FACT-10`).
- **If this module lies**, the lie is copied verbatim into a tick's evidence block, because the
  verdict line *is* the evidence. Three lies are reachable and were each reproduced on 2026-11-05:
  `HELD` on a process that merely opened the file read-only (probe A, false barrier — board work
  stops with no writer present); `RESIDUE` when the lock probe could not run at all (probe H, false
  licence to write — two writers); `ABSENT` on a dangling symlink (probe K, a lane concludes the
  barrier is gone). The classifier's own header also carries a claim that is now false — see §6.

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `python3` | not declared in-tree. Read-from-code, the syntax floors at 3.7: every `X[int]` subscript sits inside an annotation deferred by `from __future__ import annotations` (`scripts/board_lock.py:33`). Measured on 3.14.9. | resolved through `#!/usr/bin/env python3` (`scripts/board_lock.py:1`), i.e. on `PATH` | the shell, before the module runs: `env -i PATH=/nonexistent scripts/board_lock.py` → `env: 'python3': No such file or directory` and `rc=127` (measured 2026-11-05) |
| `fcntl` | the interpreter's own, Linux-only stdlib module | interpreter stdlib, imported unconditionally (`scripts/board_lock.py:37`) | `ImportError` at import, before `main()`: no verdict line, non-zero exit. Read-from-code (lines 37, 86, 91); not reproduced on this Linux host |
| `/proc` (procfs) | kernel-provided | mounted at `/proc` (`scripts/board_lock.py:54`) | `Path("/proc").iterdir()` is **outside** the guard — the `try` covers only the inner `listdir` (`scripts/board_lock.py:58`). A host without `/proc` therefore raises `FileNotFoundError`, prints no verdict and exits non-zero. Read-from-code; not reproduced (this host has `/proc`) |
| `git` | measured `git version 2.53.0` | on `PATH`, invoked by name (`scripts/board_lock.py:129`) | degraded, not fatal: `OSError` is caught (`scripts/board_lock.py:142`) and the verdict says `commits_after_mtime=unknown`. Measured with `PATH=/nonexistent` (probe I) |
| `scripts/boardctl*` | in-tree, not versioned | `REPO_ROOT/scripts/boardctl*` (`scripts/board_lock.py:100`), `REPO_ROOT` derived from `__file__` (`scripts/board_lock.py:44`) | absent tree just measures 0: `_matching_lines` swallows `OSError` (`scripts/board_lock.py:114`), so `consumers=0` is also what a missing tree prints |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `__future__.annotations` | CPython | every annotation is a string, so `list[int]` / `tuple[str, str]` / `set[int]` cost nothing at runtime (`scripts/board_lock.py:33`, annotations at `scripts/board_lock.py:49`, `scripts/board_lock.py:73`, `scripts/board_lock.py:53`) | on an interpreter without PEP 563 the subscripts evaluate at def time and the module fails to import below 3.9 |
| `argparse` | CPython | one positional, `nargs="?"` (`scripts/board_lock.py:167`), `default=str(DEFAULT_LOCK)` (`scripts/board_lock.py:168`), `help="lock path (default: %(default)s)"` (`scripts/board_lock.py:169`); `parse_args` exits 2 on an unknown or extra argument (`scripts/board_lock.py:171`, measured: two positionals → exit 2, stderr first line `usage: board_lock.py [-h] [path]`) | a default that stops being printed drops the path from `--help`; a parser that stopped exiting 2 would let a typo silently classify the default path |
| `errno` | CPython | `EWOULDBLOCK` and `EAGAIN` are present and are the two numbers a contended `flock` reports (`scripts/board_lock.py:88`) | a platform where `EWOULDBLOCK` is absent raises `AttributeError` inside the `except` at `scripts/board_lock.py:87`, converting `HELD` into a traceback |
| `fcntl` | CPython/glibc | `flock(fd, LOCK_EX \| LOCK_NB)` raises `OSError` with `EWOULDBLOCK` when another process holds it (`scripts/board_lock.py:86`), and `LOCK_UN` releases (`scripts/board_lock.py:91`) | if `LOCK_NB` were ignored the probe would block instead of answering; the module has no timeout on this call |
| `os` | CPython | `os.open(path, O_RDONLY)` (`scripts/board_lock.py:81`), `os.readlink` (`scripts/board_lock.py:64`), `os.listdir` (`scripts/board_lock.py:59`), `os.realpath` (`scripts/board_lock.py:51`), `os.stat(...).st_mtime` (`scripts/board_lock.py:126`), `os.getpid` (`scripts/board_lock.py:52`), `os.close` (`scripts/board_lock.py:94`) | `realpath` is what makes two spellings of the path compare equal (`scripts/board_lock.py:67`); if it stopped resolving, a holder reached through a symlink stops being found and the verdict falls through to the flock probe |
| `pathlib.Path` | CPython | `Path(__file__).resolve().parent.parent` as the repo root (`scripts/board_lock.py:44`), `.exists()` (`scripts/board_lock.py:150`), `.expanduser()` (`scripts/board_lock.py:172`), `/proc` iteration (`scripts/board_lock.py:54`) | `exists()` follows symlinks: a dangling link reads as `ABSENT` (measured, probe K). If `Path(__file__)` stopped resolving, `DEFAULT_LOCK` and `consumer_count()` would point at the wrong checkout |
| `re` | CPython | a bytes pattern `flock\|fcntl` (`scripts/board_lock.py:46`) applied line-by-line to bytes read from disk (`scripts/board_lock.py:113`) | a text-mode change would type-error against the bytes pattern and every file would count 0 through the `OSError` guard |
| `subprocess` | CPython | `run(..., capture_output=True, timeout=30, check=False)` (`scripts/board_lock.py:127`); `TimeoutExpired` is a `SubprocessError`, so the 30 s bound is the module's only bounded wait and a timeout lands in the `unknown` branch (`scripts/board_lock.py:142`) | a call that raised uncaught would break the one-line-and-exit-0 contract at `scripts/board_lock.py:26` |
| `sys` | CPython | `sys.exit(main())` propagates the return code (`scripts/board_lock.py:177`) | `main()` returns 0 unconditionally (`scripts/board_lock.py:173`), so this only matters if that changes |

### 2c. Service contracts (both sides must be named)

There is no network peer: no socket, no HTTP client, no bus. The only out-of-process peer is a local
CLI, and it is listed with both sides.

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| `git` CLI | outbound, local exec, synchronous, one call per RESIDUE verdict | `argv` via `subprocess.run`, stdout captured (`scripts/board_lock.py:127`) | request: `git -C <lock dir> log --since=@<mtime> --format=%H -- .` (`scripts/board_lock.py:129`); response: one commit hash per line, empty stdout on no match, non-zero exit on "not a repository" (`scripts/board_lock.py:144`) | `git log --since=@<epoch>` with a pathspec of `.`; the count is `len(stdout.splitlines())` (`scripts/board_lock.py:146`) |
| the file's writer | inbound, one-way, filesystem | file creation at `.coding-hermes/board/.lock` | a present, empty file | **RED — requires the writer's identity.** No file in this tree declares it: the lock is ignored (`.gitignore:20`), untracked, and `scripts/boardctl` contains 0 `flock`/`fcntl` lines (measured). The module's header asserts there is no consumer (`scripts/board_lock.py:4`); that assertion is a claim, not a measurement of the writer. |

## 3. Verification

Every row below was executed on 2026-11-05. The module under test is `scripts/board_lock.py` as it
stands in `373f71a`, byte-identical to the registered checkout's copy (`git diff 373f71a..HEAD --
scripts/board_lock.py` prints nothing); the live rows ran in the registered checkout
`~/code-factory`, which is the tree that owns the real lock file.

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| live verdict, default path | `python3 scripts/board_lock.py` | `RESIDUE consumers=0 commits_after_mtime=<n>`, exit 0. Measured `298` at 16:12Z and `299` on a re-run minutes later, a sibling commit landing between them; the number rises with every board commit, so assert the shape, never the value. | 2026-11-05 | PASS — `RESIDUE consumers=0 commits_after_mtime=298`, then `…=299`, exit 0 both times |
| absent path | `python3 scripts/board_lock.py /tmp/not-a-lock-$$` | `ABSENT`, exit 0 | 2026-11-05 | PASS — `ABSENT`, exit 0 |
| exactly one line, exit 0 | `test "$(python3 scripts/board_lock.py \| wc -l)" = 1 && echo ONE-LINE` | `ONE-LINE`, exit 0 | 2026-11-05 | PASS — `ONE-LINE` |
| non-mutation (the module's central claim, `scripts/board_lock.py:21`) | `b=$(stat -c '%s %Y %i' .coding-hermes/board/.lock; sha256sum .coding-hermes/board/.lock); python3 scripts/board_lock.py >/dev/null; a=$(stat -c '%s %Y %i' .coding-hermes/board/.lock; sha256sum .coding-hermes/board/.lock); [ "$a" = "$b" ] && echo UNCHANGED` | `UNCHANGED` | 2026-11-05 | PASS — `UNCHANGED` (size, mtime, inode and sha256 identical across the probe) |
| `HELD` by open fd | open the lock in a background process, then classify it | `HELD holder=pid-<that pid>`, exit 0 | 2026-11-05 | PASS — `HELD holder=pid-551254` |
| `HELD` by flock alone | hold `flock(LOCK_EX)` from a process whose `/proc/<pid>/fd` path does not resolve to the lock (write the file, `ln` it, open the link) | `HELD holder=flock-eagain`, exit 0 — this is the only way to reach the second branch | 2026-11-05 | PASS — `HELD holder=flock-eagain` |
| git unavailable degrades, does not fail | `env PATH=/nonexistent python3 scripts/board_lock.py <existing lock>` | `… commits_after_mtime=unknown`, exit 0 | 2026-11-05 | PASS |
| a check that can fail: the probe cannot run | `chmod 000` the lock, then classify it | honest answer: the flock probe returned `error`/`open-failed` (`scripts/board_lock.py:83`) and the verdict must **not** read `RESIDUE`. Observed: it does read `RESIDUE`. | 2026-11-05 | **FAIL — known defect, §6** |
| doc-truth: the header's ignore claim | `git check-ignore -v .coding-hermes/board/.lock` | the header says "no ignore rule" (`scripts/board_lock.py:4`); reality must agree | 2026-11-05 | **FAIL — `.gitignore:20` ignores it, so the header line is stale** |

The two FAIL rows are the reason this module's evidence is worth having: the run is cheap, the
verdict is one line, and it disagrees with the source in two places that a reader can now see.

## 4. Metrics emitted

**none** — the module imports no metrics client, increments no counter and exposes no endpoint; its
whole output is the single stdout line at `scripts/board_lock.py:172`. That is acceptable *for this
module* because it is a single-shot adjudicator that a tick calls once and pastes into board
evidence, not a service anything scrapes; the verdict string already carries the two numbers that
matter (`consumers=<n>`, `commits_after_mtime=<n|unknown>`, `scripts/board_lock.py:158`).

It is also a finding: those two numbers have no label, no timestamp and no retention, so nobody can
see `consumers` or `commits_after_mtime` drift over time without re-running the tool by hand on the
same box. A scrapeable series would need a counter per verdict class and a gauge for each count —
neither exists in this revision.

## 5. Log lines it can generate

No logging framework is imported: there is no `import logging` in the file (`scripts/board_lock.py:35`
through `scripts/board_lock.py:42` cover every import). Every operator-visible line is `print` to
stdout, or argparse's own stderr.

| Level | Line (verbatim) | Emitted when | Kind |
|---|---|---|---|
| stdout | `ABSENT` (`scripts/board_lock.py:151`) | `lock.exists()` is false, which includes a dangling symlink (`scripts/board_lock.py:150`) | evidentiary — proves the path did not exist at that instant; cite it with the command, never as proof it never existed |
| stdout | `HELD holder=pid-{holders[0]}` (`scripts/board_lock.py:154`) | at least one other process holds an open fd resolving to the path (`scripts/board_lock.py:67`) | evidentiary and **over-broad**: an open fd is not a lock, so a `cat` produces this line (measured) |
| stdout | `HELD holder={detail}` where `detail` is `flock-eagain` (`scripts/board_lock.py:157`, literal at `scripts/board_lock.py:89`) | the exclusive non-blocking `flock` failed with `EWOULDBLOCK`/`EAGAIN` (`scripts/board_lock.py:88`) | evidentiary — the strongest of the three, because only a real lock produces it |
| stdout | `RESIDUE consumers={n} commits_after_mtime={n\|unknown}` (`scripts/board_lock.py:158`) | the path exists and neither holder branch fired — **including when the flock probe could not run** | evidentiary for the two counts, not for "no holder": the negative is only as strong as the probe that produced it |
| stderr | `usage: board_lock.py [-h] [path]` then `board_lock.py: error: unrecognized arguments: b` | more than one positional argument (measured with `a b`: exit 2) | descriptive — an invocation error, not a verdict |
| stdout | `usage: board_lock.py [-h] [path]` … `positional arguments:` … `lock path (default: /<repo>/.coding-hermes/board/.lock)` | `-h` (measured 2026-11-05; goes to **stdout**, exit 0) | descriptive — and it is the only place the resolved default is shown |
| stderr | a Python traceback, no verdict line | the interpreter or `/proc` is missing (§2a) | neither — this is the contract at `scripts/board_lock.py:26` being broken |

The probe's own `error` verdicts — `open-failed` (`scripts/board_lock.py:83`) and `errno-<n>`
(`scripts/board_lock.py:90`) — are computed and then discarded by `adjudicate()`, which tests only
for `held` (`scripts/board_lock.py:156`). They never reach an operator. That is the §6 defect in one
sentence.

## 6. Failure modes

| Failure | Presents as | Distinguished from | Direction | Recovery |
|---|---|---|---|---|
| a process merely has the lock open read-only (`cat`, an editor, a `tail`) | `HELD holder=pid-<n>` | real holder: run with `flock`-only visibility, or check the verdict's holder with `lsof -p <n>`; a read-only fd is not `LOCK_EX` | **fail closed** — board work stops though nothing holds the lock | re-run after the reader exits; the file is never to be deleted |
| the lock exists but cannot be opened (mode 000, EACCES, EPERM) | `RESIDUE consumers=… commits_after_mtime=…` — the `error` verdict from `scripts/board_lock.py:83` is dropped at `scripts/board_lock.py:156` | a true residue: re-run after `chmod`, or prove the holder directly | **fail open** — the most dangerous direction, because it licenses a second writer while a holder may exist | restore readability (`stat -c '%a'`), re-run, and treat the earlier RESIDUE as void |
| other `flock` errors (`ENOLCK`, `EBADF`, `EINTR`) | same silent `RESIDUE`, detail discarded (`scripts/board_lock.py:90`) | as above | **fail open** | re-run; if it repeats, the adjudicator cannot answer and no verdict may be cited |
| `git` missing, slow (>30 s) or the lock's directory is not a repository | `commits_after_mtime=unknown` (`scripts/board_lock.py:143`, `scripts/board_lock.py:145`) | a repository with genuinely zero later commits prints `0` | **fail degraded, honestly** — the holder verdict is unaffected because it never touches git | run from inside the repository, or pass the absolute path so `git -C <lock dir>` resolves |
| `/proc` not mounted, or a non-Linux host without `fcntl` | traceback, no verdict, non-zero exit | a verdict of any kind | **fail closed**, but it breaks the one-line contract at `scripts/board_lock.py:26` | run it on the Linux host that owns the board; a caller must treat a missing verdict as "cannot answer", never as `RESIDUE` |
| a directory or a dangling symlink is passed | `RESIDUE …` for a directory (measured), `ABSENT` for the dangling link (measured) | — | **fail open** — there is no validation of the argument beyond `expanduser` (`scripts/board_lock.py:172`) | pass the file path; nothing in the module rejects a bad one |
| `scripts/boardctl` produces no match in this revision | `consumers=0`, which is indistinguishable from "no consumer anywhere" | the glob is bounded by `scripts/boardctl*` (`scripts/board_lock.py:100`), so a consumer under `tests/` or another directory still prints 0 | **fail open toward a false negative** | treat `consumers=0` as scoped evidence ("no consumer under `scripts/boardctl*`"), never as "no consumer" |
| the header's premise goes stale | `RESIDUE` verdict is right, the header at `scripts/board_lock.py:4` is wrong: it says the lock has "no ignore rule" while `.gitignore:20` ignores it | — | **lies about its own premise, not its answer** | the header must be corrected; the verdict does not depend on it |

## 7. Environment and settings it reads

| Setting | Kind | Default | Read at | Validation |
|---|---|---|---|---|
| lock path | positional argument `path` | `<repo root>/.coding-hermes/board/.lock`, where the root is `Path(__file__).resolve().parent.parent` | `scripts/board_lock.py:168` (default), `scripts/board_lock.py:172` (parsed) | none beyond `Path(...).expanduser()`; a directory or a dangling symlink is accepted and silently classified |
| repository root | derived, not settable | computed from the script's own location (`scripts/board_lock.py:44`), so `DEFAULT_LOCK` and `consumer_count()` follow the checkout the script was loaded from, **not** the current directory | `scripts/board_lock.py:45`, `scripts/board_lock.py:100` | none; a copied or symlinked script silently changes the repository it inspects (measured: `python3 -h` from this worktree prints `default: ~/proj-wt-md-03/.coding-hermes/board/.lock`, and the same copy run from `/tmp` answers `ABSENT` because that path does not exist) |
| `PATH` | inherited environment | the caller's | `scripts/board_lock.py:129` — `git` is resolved by name | none; a stripped `PATH` yields `commits_after_mtime=unknown` rather than an error |
| environment variables | — | — | **none read**: `os.environ` / `getenv` appear nowhere in the file (measured: `grep -n 'os.environ\|getenv\|environ' scripts/board_lock.py` → no match, rc 1) | n/a |
| config file | — | — | **none**: no file is opened for configuration; the only files touched are the lock itself and `scripts/boardctl*` for the consumer count | n/a |
| `--help` / `-h` | flag, argparse-provided | — | `scripts/board_lock.py:162` | prints the resolved default path, which is the only way to see which checkout the run will inspect |

The 30 s `git` timeout (`scripts/board_lock.py:139`) is the module's only time bound; the `flock`
probe at `scripts/board_lock.py:86` is non-blocking by construction, so it needs none.

## 8. Evidence of record

A reviewer can reproduce every claim above on 2026-11-05 at revision `373f71a` with:

- `python3 scripts/board_lock.py` from the registered checkout → `RESIDUE consumers=0
  commits_after_mtime=298`, exit 0, and `…=299` on a re-run minutes later. The count rises with every
  board commit — that is the board moving, not the tool (`scripts/board_lock.py:146`) — so any
  quotation of it dates the run as much as the number.
- `git check-ignore -v .coding-hermes/board/.lock` → `.gitignore:20` and the same path: the file is
  ignored, untracked, and therefore permanent. This is the measurement that makes §1's "absent"
  argument concrete.
- the two-process probes for `HELD holder=pid-…` and `HELD holder=flock-eagain` — each is one
  background process holding either an open fd or an exclusive `flock`, then one call to
  `scripts/board_lock.py`.
- `chmod 000` on a scratch lock, then a call → `RESIDUE`, which is the `error` branch being dropped
  at `scripts/board_lock.py:156`; this is the defect recorded as a FAIL in §3.
- `PATH=/nonexistent python3 scripts/board_lock.py <lock>` → `commits_after_mtime=unknown`, proving
  the degradation is honest rather than a fabricated `0` (`scripts/board_lock.py:142`).

Facts cited: `fact: FACT-09` (the board is `.coding-hermes/board/tasks.jsonl`, append-only) and
`fact: FACT-10` (a row closes only with a re-runnable command in its evidence) — the two claims that
make a stale barrier expensive and this adjudicator the right shape of answer.
