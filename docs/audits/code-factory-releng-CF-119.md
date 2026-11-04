# CF-119 — the board lock adjudicated: ignore rule, shipped classifier, two proven arms

Worker brief: serial worker on a fresh clone of `origin/main`
Measured at: this checkout = `dae4e7a0` (origin/main at clone time), 2026-11-04T03:1x Z
Row: CF-119 (`P3`, complexity 2) — filed by releng tick `code-factory-releng-2026-11-03-20-24-59`

## 1. The defect as measured before the fix

`.coding-hermes/board/.lock` is a 0-byte file every lane stood down on, though nothing
enforced it. The filing measured, and this clone reproduces at the base tip `dae4e7a`:

- no ignore rule: `git check-ignore -q .coding-hermes/board/.lock` exited 1 — the committed
  `.gitignore` at `dae4e7a` carries only `.node/`, `*.log`, `.env*`, `key*`, `*.key` and
  `.gitreins/*` entries, no `.coding-hermes` entry;
- no shipped consumer: `git grep -lI 'flock\|fcntl' dae4e7a -- scripts/` prints nothing
  (0 files), and `grep -rn 'flock\|fcntl' scripts/boardctl*` returns nothing;
- no holder: the filing's `fuser -v` on the registered workdir (`~/code-factory`) printed
  nothing;
- and it never excluded a writer: 63 board commits landed after the lock's mtime at filing
  time. Re-running the same derivation live during this tick gave 112, then 114 minutes
  later as sibling commits landed — the count moves because the file stops nothing.

## 2. What changed

- `.gitignore` — one appended line, `.coding-hermes/board/.lock`.
- `scripts/board_lock.py` (new) — the shipped adjudicator. Prints exactly one verdict line
  and exits 0; never creates, truncates or deletes the lock. `HELD` only on a proven live
  holder: an open fd found by scanning `/proc/[0-9]*/fd/*` excluding the classifier's own
  pid (`fd_holders`, `scripts/board_lock.py:49`) or a non-blocking exclusive `flock` probe
  failing with `EWOULDBLOCK` (`flock_probe`, `scripts/board_lock.py:73`); otherwise
  `RESIDUE consumers=<n> commits_after_mtime=<n|unknown>`; `ABSENT` for a missing path.
- `tests/selftest.sh` — section 31 (after section 30, the previous highest), two named
  `PASS` rows: an unheld 0-byte lock in a temp dir must print `RESIDUE` with the file left
  untouched (size re-checked after the run), and a lock held by a live process that took an
  exclusive `flock` must print `HELD`; the holder is reaped before the arm ends.
- `docs/BOARD.md` — new "Board lock adjudication" subsection (a present lock file is not
  proof of a held lock; run the adjudicator; `HELD` means wait, `RESIDUE` means proceed and
  do not delete), plus the arm census the new section invalidates (31 numbered sections
  plus lettered arms 4b and 7b — 33 arms).
- `docs/audits/code-factory-releng-CF-119.md` — this receipt.

## 3. Acceptance commands and their real output

Run on this tree immediately before committing:

```
$ git check-ignore -q .coding-hermes/board/.lock; echo "ignore_rc=$?"
ignore_rc=0

$ python3 scripts/board_lock.py ; echo "adj_rc=$?"
ABSENT
adj_rc=0
```

`ABSENT` is the honest verdict for a fresh clone: the file was never committed
(`git ls-tree HEAD .coding-hermes/board/` lists only `tasks.jsonl` and `events.jsonl`).

Fixture arms (the exact commands `tests/selftest.sh` section 31 runs; captured in a
standalone probe first):

```
$ python3 -B scripts/board_lock.py "$T/board/.lock"        # unheld 0-byte fixture
RESIDUE consumers=0 commits_after_mtime=unknown            # temp dir: no git repo -> unknown
residue_arm_rc=0

$ python3 -B scripts/board_lock.py "$T/board/.lock"        # live flock holder pid 2146939
HELD holder=pid-2146939                                    # matches the real holder pid
held_arm_rc=0
```

`commits_after_mtime=unknown` in the fixture is deliberate: the fixture lock lives in a
temp dir outside any repository, and the classifier prints `unknown` rather than inventing
a number. The selftest row asserts the verdict token, not the counts.

Live adjudication of the registered workdir's actual lock (read-only):

```
$ python3 -B scripts/board_lock.py /home/kara/code-factory/.coding-hermes/board/.lock
RESIDUE consumers=0 commits_after_mtime=114
rc=0
```

```
$ ~/.local/bin/ruff check .
All checks passed!
$ ~/.local/bin/ruff format --check .
14 files already formatted
```

(13 files were clean before; the 14th is `scripts/board_lock.py`.)

```
$ for f in $(git ls-files '*.sh') scripts/boardctl; do bash -n "$f" || echo "SH_FAIL $f"; done
(no output, exit 0)

$ bash tests/selftest.sh
...
31. the board lock adjudicator proves a holder before calling a lock held (CF-119)
  PASS  unheld 0-byte lock -> RESIDUE, file untouched (RESIDUE consumers=0 commits_after_mtime=unknown)
  PASS  flock-held lock -> HELD (HELD holder=pid-2206003)

SELFTEST: PASS
selftest_rc=0
```

(loadavg 13.9 before the run; sections 1–30 unchanged and green. Supplementary:
`scripts/boardctl validate` prints `RESULT: OK (3 warning(s))` on this clone.)

## 4. Verdict per acceptance criterion

- AC1 — satisfied via the ignore-rule leg (`ignore_rc=0`) plus the shipped adjudicator that
  makes holding the exact path authoritative: a proven holder now decides the verdict, by
  file and line `scripts/board_lock.py:49` (`fd_holders`) and `scripts/board_lock.py:73`
  (`flock_probe`), with the wait/proceed doctrine in `docs/BOARD.md` ("Board lock
  adjudication"). The registered workdir's file itself is deliberately left in place: its
  removal is the documented handoff CF-049's own verification tick owns (AC5).
- AC2 — the adjudicator is shipped (`scripts/board_lock.py`); `HELD` requires a live holder
  proven by fd probe on `/proc/<pid>/fd` or `flock` `EWOULDBLOCK`; `RESIDUE` names the
  consumer-grep count and the commits-after-mtime count.
- AC3 — both arms demonstrated: unheld 0-byte lock → `RESIDUE`; flock-held path → `HELD`
  (selftest section 31, both rows `PASS`; standalone capture above).
- AC4 — `bash tests/selftest.sh` prints `SELFTEST: PASS` (rc 0) with the new arm visible as
  the two named `PASS` rows quoted in section 3.
- AC5 — not re-litigated: no lock was deleted or created anywhere (the classifier cannot
  mutate the path, and this tick never touched the registered workdir); CF-049's criteria
  remain a separate verification tick's work.

## 5. Observations this tick did not act on

- `docs/BOARD.md`'s "Current measured state" block was already stale before this change:
  it types 116 task rows / 168 events while this clone's board carries 127 / 193 (and
  `tests/selftest.sh` prints `PASS 127/127 rows parse`). The block self-qualifies
  ("measure it instead of quoting an older snapshot") and stays owned by the census
  reconciliation family; this tick only restated the arm census its own change invalidates.
- The registered workdir has moved past this clone's base tip (`d7efb7a` there vs
  `dae4e7a` cloned here) while this tick ran, and its commits-after-mtime count grew
  112 → 114 between two runs minutes apart. Consistent with the filing: the lock has never
  excluded a writer.

ch:trace row=CF-119 spec=docs/traceability-doctrine.md#marker-fields wave=none:serial test=tests/selftest.sh::section-31 doc=docs/BOARD.md prompt=none:worker-brief evidence=docs/audits/code-factory-releng-CF-119.md witness=none:local-gate verdict=none:open commit=none:open memory=none:foreman-closeout-pending

## Landing note (releng tick code-factory-releng-2026-11-04-02-59-07)

The worker's implementation commit `424e5402` was produced on a clone at `dae4e7a`. By the
time it was landed, sibling lanes had published sections 31 (CF-127) and 32 (CF-145) in
`tests/selftest.sh`, so this arm was renumbered to **section 33** during the landing merge and
re-verified at the landed commit. Every receipt above was produced at `424e5402`; the arm's
content is unchanged apart from its number. `docs/BOARD.md`'s census numbers were NOT edited:
they are owned by CF-154 (warning counts) and CF-155 (stale section count).
