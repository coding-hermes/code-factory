# CF-158 — the CF-119 lock adjudicator calls an open fd a held lock

Review lane tick: `code-factory-review-2026-11-04-03-41-13`
Reviewed commit: `a012d02180c1ea53e979b65b545d9533f7d2da07` — "fix(board-lock): adjudicate
board/.lock as residue and ship the holder-proof classifier" (closes CF-119)
Reviewed tip: `7989ba3a7eb45a1adafc2bc5d5b4c0831e412d38` (= `origin/main` at review time). A sibling
landed a CF-156 closeout mid-tick, so the clone was fast-forwarded to `d3b06a8fed3010f7e1eaea84f12baba1d6c6b1ea`
and every arm below was re-run there before filing; `git diff --name-only 7989ba3..d3b06a8 -- scripts/
tests/ .gitignore` prints 0 files, so the reviewed code and the mutation result carry unchanged.
Transport: throwaway `git clone` of the canonical checkout at the reviewed tip into tick scratch
(`cf-review.XPTtul/cf-clone`); the registered workdir `/home/kara/code-factory` was left untouched
(attached `main`, parity 0/0, zero tracked edits, no operation markers).
Row filed: `CF-158` (pending). This document is the review receipt, not the repair.

## 1. Why this commit

The review window is 300 commits since 2026-10-27, of which 37 touch `scripts/`, `tests/` or
`.gitignore`. `a012d02` carries the largest claim relative to its evidence of any of them: it ships
a new classifier, a new gate arm, a new doctrine page, and a *universal* safety claim —

> `HELD` only on a proven live holder (a `/proc` fd scan excluding self, or a non-blocking exclusive
> `flock` probe failing `EWOULDBLOCK`); `RESIDUE` otherwise.

The other implementation commits of the window were sampled at the same depth and held up: `23c1c6d`
refuses an unset `CRIER_URL` at `scripts/node-create.sh:69` before the spawn at line 112, and `875bc72`
moves the install log to `$HOME/.hermes-install-$PORT.XXXXXXXX.log`
(`scripts/harness/install-hermes.sh:86`). `a012d02` did not.

## 2. Q1 — does it build?

`bash tests/selftest.sh` at the reviewed tip: `SELFTEST: PASS`, rc=0, **103 PASS rows**, 10.1 s wall,
loadavg 10.86. Section 33 prints its two named rows:

```
33. the board lock adjudicator proves a holder before calling a lock held (CF-119)
  PASS  unheld 0-byte lock -> RESIDUE, file untouched (RESIDUE consumers=0 commits_after_mtime=unknown)
  PASS  flock-held lock -> HELD (HELD holder=pid-...)
```

`gh run list --repo coding-hermes/code-factory --limit 5` → `[]` (this repo has no workflows; the
selftest is the CI-equivalent gate).

## 3. Q2 — does its test fail without it, and does the mechanism it ships hold up?

The section proves that *something* classifies a lock, but it cannot tell the two holder proofs apart,
and one of the two is wrong.

### 3.1 An open fd is not a held lock

`fd_holders()` (`scripts/board_lock.py:49`) treats "a `/proc/<pid>/fd` entry resolving to the path" as
proof of a live holder. Opening a file is not locking it. Arms run in the clone with the shipped
classifier (temp dir; the file is never mutated):

| arm | setup | classifier output |
|---|---|---|
| A1 | unheld 0-byte file | `RESIDUE consumers=0 commits_after_mtime=unknown` |
| A2 | process holds an fd only — `( exec 3< "$S/.lock"; sleep ) &`, **no flock at all** | **`HELD holder=pid-2711809`** |
| A3 | real exclusive `flock` holder | `HELD holder=pid-2711812` |
| A4 | unheld again after the holder exits | `RESIDUE consumers=0 commits_after_mtime=unknown` |
| A5 | absent path | `ABSENT` |
| A6 | lock size after every arm | `0` (never mutated — that part of the claim holds) |
| B1 | same file inside the clone (so the count resolves) | `RESIDUE consumers=0 commits_after_mtime=0` |
| B2 | reader-only, inside the clone | **`HELD holder=pid-2712037`** |

A2/B2 are the defect: any reader — a `tail -f`, an editor, another tool that merely opens the file —
makes the classifier tell every lane **wait**. That is the phantom ownership barrier CF-119 was filed
to remove, re-introduced by the instrument that was supposed to remove it.

### 3.2 A shared lock is not an ownership barrier either

| arm | setup | classifier output |
|---|---|---|
| D1 | holder takes `fcntl.flock(fd, LOCK_SH)` | **`HELD holder=pid-2747535`** |
| D2 | two shared holders alive at once | `r1=yes r2=yes` — a shared lock excludes nobody |

The exclusive probe (`flock_probe`, `scripts/board_lock.py:73`) returns `HELD` on `EWOULDBLOCK`, which a
*shared* lock also triggers. `HELD` therefore conflates three different states: an opener, a shared
reader, and an exclusive holder.

### 3.3 The gate is mutation-blind on exactly that branch

Replacing the fd branch with a constant in a copy of the tree —

```
sed -i 's/^    holders = fd_holders(lock)$/    holders = []  # MUTATION/' scripts/board_lock.py
bash tests/selftest.sh
```

— leaves `SELFTEST: PASS`, rc=0, and **both §33 rows green** (`HELD holder=flock-eagain` via the probe).
The section's `HELD` arm uses a real `flock`, which satisfies *either* proof, so deleting the entire
`/proc` scan costs nothing at the gate. The fixture asserts behaviour, but only the behaviour both
implementations share. (Tree restored with `git checkout -- scripts/board_lock.py`, porcelain 0.)

### 3.4 The consumer count cannot see a consumer

`consumer_count()` globs `scripts/boardctl*` only, while CF-119's own derivation grepped all of
`scripts/`. Measured in the clone:

| fixture | classifier output |
|---|---|
| flock user at `scripts/__scope_probe.sh` | `RESIDUE consumers=0 ...` |
| same content at `scripts/boardctl_scope_probe.sh` (control) | `RESIDUE consumers=1 ...` |

So `consumers=0` — the number the verdict presents as proof that "no shipped script opens it" — is a
statement about one filename prefix, not about the repository. A future board writer in
`scripts/write_board.py` would be invisible while the verdict reads `RESIDUE ... consumers=0`.

## 4. Q3 — does the doc describe the code?

Yes, faithfully — which is the problem. `docs/BOARD.md:57-59` says:

> `HELD holder=<pid>` — a live process holds an open fd on the path, or a non-blocking exclusive
> `flock` probe failed with `EWOULDBLOCK`. A held lock means wait.

The page's own premise, three lines earlier, is that "a present lock file is **not** proof of a held
lock". The classifier's `HELD` covers a process that merely opened the file, and the doctrine line
converts that false positive into an instruction to stand down. The drift is in the *definition*, not
in the doc's description of the implementation.

## 5. Row filed

`CF-158` (P3, complexity 2, pending) — "the CF-119 lock adjudicator reports HELD for any process that
merely OPENS the path (an open fd, and a SHARED flock, are not ownership), so the phantom stand-down
returns through the new instrument".

Acceptance criteria (abridged; the row carries the full text): reader-only → not `HELD`; shared lock →
not `HELD`; §33 goes RED when the surviving holder proof is removed (mutation stated as a
re-runnable command); the consumer count cannot say `consumers=0` while a shipped script holds a lock;
`docs/BOARD.md`'s legend corrected in the same change; `SELFTEST: PASS` and `boardctl validate`
`RESULT: OK`.

Not a duplicate: CF-119 (complete) filed the residue adjudication itself, and its AC-2 named "an fd
probe on `/proc/<pid>/fd`" as an acceptable holder proof — the defect is in that proof's definition,
so this row supersedes the definition rather than reopening the closure. A class census of the board
for `board_lock|board lock|HELD|holder|fd scan` returns no other row.

**Renumbered at filing time.** The row was drafted as `CF-157` and the board write was made under that
id; while this tick was committing, a sibling lane landed `7c51fbe`
("docs(readme): the lane census is the authority, not a hand-written enabled count (CF-157)") and
consumed the id for an unrelated README finding. The uncommitted draft was rolled back, `main` was
fast-forwarded to `7c51fbe` (`parity 0 0`), and the row re-filed as `CF-158` against the landed board.
A draft id is not a reservation.

### The row's probe (paste-runnable from the repo root, one physical line)

```sh
S=$(mktemp -d); : > "$S/.lock"; printf 'unheld='; python3 -B scripts/board_lock.py "$S/.lock"; ( exec 3< "$S/.lock"; sleep 3 ) & R=$!; sleep 0.4; printf 'reader_only='; python3 -B scripts/board_lock.py "$S/.lock"; kill $R 2>/dev/null; wait $R 2>/dev/null; ( flock -s 9; sleep 3 ) 9<"$S/.lock" & H=$!; sleep 0.5; printf 'shared_lock='; python3 -B scripts/board_lock.py "$S/.lock"; kill $H 2>/dev/null; wait $H 2>/dev/null; rm -rf "$S"
```

Output at the reviewed tip (rc=0), which is the refutation:

```
unheld=RESIDUE consumers=0 commits_after_mtime=unknown
reader_only=HELD holder=pid-2776007
shared_lock=HELD holder=pid-2776414
```

## 6. Gate note — an independent observation on CF-142

The gate at the reviewed tip passed twice in the clone, and once in the registered workdir it went RED
on an unrelated arm before passing on a re-run minutes later, with no tree change between the two runs:

| run | tree | output for the auth-stats arm | summary | loadavg |
|---|---|---|---|---|
| 1 (registered workdir) | d3b06a8 + this tick's board rows | `FAIL  auth stats 404 did not produce named FAIL (exit 1)` | `SELFTEST: FAIL (1)` | 10.86 → 8.0 |
| 2 (same workdir, minutes later) | unchanged | `PASS  auth stats 404 -> FAIL, exit 1` | `SELFTEST: PASS` | 7.41 → 8.09 |

That is the pending CF-142 in the *other* direction: the arm is nondeterministic in both directions, so
it blocks honest lanes as well as passing dishonest ones. Recorded as a note on CF-142 rather than a new
row; it is not evidence about the reviewed commit.

## 7. Legs not run, and why

- **Worker dispatch: none.** The review lane's deliverable is the row (filing-only); the repair is
  future work tracked by the pending row. Dispatching an implementation worker here would mix review
  evidence with a code change and split the row's closure.
- **CI:** `gh run list` → `[]` is this repo's documented healthy no-workflow state.
- **Not graded here:** whether the row's own remedy is reachable in one change — that belongs to
  whoever dispatches CF-158.
