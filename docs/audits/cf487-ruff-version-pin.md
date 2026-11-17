# CF-487 — the section 51 python lint arm now pins the ruff it grades

**Verdict: the version race is closed at the arm, and it is closed by two independent levers, not
by retuning a message.** `tests/selftest.sh` §51 resolves its checker to an absolute path whose
`--version` must equal the pin (`ruff 0.15.22`), and it names the rule set it grades
(`E4,E7,E9,F`) instead of inheriting whatever defaults the binary of the day carries. Both full-gate
runs — this shell's `PATH` and the *other* ruff (0.17.5) first on `PATH` — end `SELFTEST: PASS` on
the same tree, and a red control proves the pinned checker still reports a genuine `I001` on an
unsorted import block.

- Measured in the `wt/CF-487` worktree off `1c54dfa7` (`git log --oneline -1` at session start). The
  only tracked change in the measured tree is this row's diff to `tests/selftest.sh` plus this file,
  so "the commit that carries this file" IS the tree every number below was taken on: re-check with
  `git log --oneline -1 -- docs/audits/cf487-ruff-version-pin.md`.
- Host-home paths are written as `~` throughout. The CF-050 publish gate (`tests/selftest.sh` §61)
  refuses a staged file carrying an absolute `/home/<name>/` path, so every quoted suite row below
  is transcribed with that substitution (`~/.local/bin/ruff` for the absolute path the arm actually
  prints). Nothing else in the quotes is edited.
- Scratch paths are written as `$TMPDIR`; each fixture below is a `mktemp -d` file, and the arm's
  own fixtures live in the section's own `mktemp -d`.

---

## 1. The race, measured before the change

Two `ruff` binaries are reachable on this host, and the arm used to invoke a **bare** name three
times (`command -v ruff`, then `ruff check …`), so the launching shell's `PATH` picked the grader:

```
$ ~/.local/bin/ruff --version
ruff 0.15.22
$ ~/.hermes/installs/b0e47ae07995f891/environments/24f1df2ad984420181cb6be1707f6a03/venv/bin/ruff --version
ruff 0.17.5
```

The pinned binary measured here: `~/.local/bin/ruff`, 27,832,160 bytes, mode `-rwxr-xr-x`, sha256
prefix `64aae5e444938e33`.

Same tree, same 87 tracked `*.py` files (`git ls-files '*.py' | wc -l` -> `87`), two verdicts:

```
$ ~/.local/bin/ruff check $(git ls-files '*.py'); echo EXIT=$?
All checks passed!
EXIT=0

$ ~/.hermes/installs/b0e47ae07995f891/environments/24f1df2ad984420181cb6be1707f6a03/venv/bin/ruff check $(git ls-files '*.py'); echo EXIT=$?
I001 [*] Import block is un-sorted or un-formatted
  --> docs/audits/cf089-census-standin.py:7:1
…
Found 670 errors.
[*] 157 fixable with `--fix` (238 unsafe fixes available with `--fix --unsafe-fixes`).
EXIT=1
```

The cause is a rule-set change, not a tree change: 0.17.5's **default** select is far wider than
0.15.22's. `ruff check --show-settings` on the same file lists 59 enabled rules for 0.15.22 and 407
for 0.17.5 (`I`, `UP`, `EXE`, `PLW`, `ISC`, `RUF`, `FURB`, `SIM`, `C4`, …). Findings on this measured
tree under 0.17.5's defaults, by rule
(`ruff check --output-format=concise $(git ls-files '*.py')`, 670 rows over 85 of the 87 files):

| rule | n | | rule | n |
|---|---|---|---|---|
| `UP031` | 306 | | `I001` | 25 |
| `EXE001` | 70 | | `FURB167` | 21 |
| `PLW1510` | 62 | | `SIM115` | 10 |
| `UP045` | 55 | | `RUF059` | 8 |
| `ISC004` | 31 | | `UP006` | 7 |
| `RUF100` | 25 | | `C408` | 6 |

So the section-51 tracked-surface arm was a coin flip on the launcher. Under the cron-spawned
shell's `PATH` the venv ruff wins and the suite can never print `SELFTEST: PASS`; the pre-fix arm,
run from a `PATH` with 0.17.5 first, was captured verbatim as:

```
51. the python lint lane can go red on one unused import, and green once it is removed (CF-254)
  PASS  one unused import -> exit 1 naming F401
  PASS  same file once the import is removed -> exit 0
  FAIL  tracked python surface is red: a python-staging commit is refused
ISOLATED fails=1
```

Both complaints in the row are visible in those three rows: the tree reds on a tool difference, and
**no row names the tool**, so the `FAIL` cannot be attributed. (This reproduces `docs/audits/cf-PERF-021-cold-cache-attribution.md` §5 — that audit found the same race and left it unrepaired.)

## 2. What changed (one file, one block)

`tests/selftest.sh` §51 (`say "51. …"` to `# END python-lint`), only inside that block:

1. **The binary is pinned and version-asserted.** `ruff_pin="0.15.22"`; the arm tries
   `$RUFF_BIN` (when set), then `$HOME/.local/bin/ruff`, then whatever `have ruff` resolves, and
   accepts the first one whose `--version` prints `ruff 0.15.22`. A `RUFF_BIN` override that is not
   the pin is **refused, never silently swapped for the host pin**.
2. **The rule set is named.** `ruff_rules="E4,E7,E9,F"` is passed to every fixture and to the
   tracked-surface check, so a checker whose *defaults* widen cannot move the verdict. On 0.15.22
   this is exactly its default set — the arm grades the same rules it graded before.
3. **Every row names the tool.** `PASS pinned checker: ruff 0.15.22 at <abs path> (pin 0.15.22,
   rules E4,E7,E9,F)` heads the block, and every `PASS`/`FAIL` row carries the version.
4. **The tracked-surface `FAIL` names the file too.** That check now runs `--output-format=concise`
   so the row reads `tracked python surface is red under ruff <ver> at <path>: <n> finding(s), first
   <file>:<line>:<col>: <CODE> <message>` before dumping the full output.
5. **A red control for the class the race actually moved.** The isort family is not in the pinned
   defaults, so the control asks for it: `--select I001` on a fixture whose imports are unsorted.

## 3. The four measurements the row asks for

### M1 — the tool the arm grades

```
$ ~/.local/bin/ruff --version
ruff 0.15.22
```

and the arm's own first row proves it resolved that file, not a name
(`  PASS  pinned checker: ruff 0.15.22 at ~/.local/bin/ruff (pin 0.15.22, rules E4,E7,E9,F)`).

### M2 — the arm PASSes on this tree

Full gate, this shell's `PATH` (wall 224 s, `rc=0`; log kept outside the repo at
`~/.hermes/cache/scratch/cf487/suite-default.log`, 600 `  PASS` rows / 61 fixture `  FAIL` rows):

```
$ bash tests/selftest.sh > "$TMPDIR/suite-default.log" 2>&1; echo RC=$?
RC=0
$ grep -A5 '^51\. the python lint' "$TMPDIR/suite-default.log"
51. the python lint lane can go red on one unused import, and green once it is removed (CF-254)
  PASS  pinned checker: ruff 0.15.22 at ~/.local/bin/ruff (pin 0.15.22, rules E4,E7,E9,F)
  PASS  one unused import -> exit 1 naming F401 (ruff 0.15.22, rules E4,E7,E9,F)
  PASS  same file once the import is removed -> exit 0 (ruff 0.15.22, rules E4,E7,E9,F)
  PASS  unsorted import block -> exit 1; quoted: I001 [*] Import block is un-sorted or un-formatted (ruff 0.15.22, --select I001)
  PASS  tracked python surface clean: 87 files graded (ruff 0.15.22, rules E4,E7,E9,F)
$ tail -2 "$TMPDIR/suite-default.log"
SELFTEST: PASS
EXIT=0
```

### M3 — the same commit with the previously-first ruff first on PATH

The other binary is prefixed onto `PATH`, so a bare `ruff` would resolve to 0.17.5 (verified in the
same command), and the gate is re-run whole:

```
$ R2DIR=~/.hermes/installs/b0e47ae07995f891/environments/24f1df2ad984420181cb6be1707f6a03/venv/bin
$ PATH="$R2DIR:$PATH" command -v ruff
~/.hermes/installs/b0e47ae07995f891/environments/24f1df2ad984420181cb6be1707f6a03/venv/bin/ruff
$ PATH="$R2DIR:$PATH" ruff --version
ruff 0.17.5
$ PATH="$R2DIR:$PATH" bash tests/selftest.sh > "$TMPDIR/suite-0175first.log" 2>&1; echo RC=$?
RC=0
$ grep -A5 '^51\. the python lint' "$TMPDIR/suite-0175first.log"
51. the python lint lane can go red on one unused import, and green once it is removed (CF-254)
  PASS  pinned checker: ruff 0.15.22 at ~/.local/bin/ruff (pin 0.15.22, rules E4,E7,E9,F)
  PASS  one unused import -> exit 1 naming F401 (ruff 0.15.22, rules E4,E7,E9,F)
  PASS  same file once the import is removed -> exit 0 (ruff 0.15.22, rules E4,E7,E9,F)
  PASS  unsorted import block -> exit 1; quoted: I001 [*] Import block is un-sorted or un-formatted (ruff 0.15.22, --select I001)
  PASS  tracked python surface clean: 87 files graded (ruff 0.15.22, rules E4,E7,E9,F)
$ tail -2 "$TMPDIR/suite-0175first.log"
SELFTEST: PASS
EXIT=0
```

Wall 203 s, `rc=0`, the same 600/61 row counts. The two runs are byte-identical over §51's six
lines: the race is gone, not hidden.

### M4 — the red control still FAILs, quoted

Fixture (imports used, so nothing here is a `F401` — only import *order* is wrong):

```
$ printf 'from urllib.parse import urlparse, parse_qs\nimport json\nimport os\n\nprint(json.dumps({"a": os.getcwd(), "u": str(urlparse("x")), "q": parse_qs("y")}))\n' > "$TMPDIR/unsorted.py"
$ ~/.local/bin/ruff check --select I001 "$TMPDIR/unsorted.py"; echo EXIT=$?
I001 [*] Import block is un-sorted or un-formatted
 --> $TMPDIR/unsorted.py:1:1
  |
1 | / from urllib.parse import urlparse, parse_qs
2 | | import json
3 | | import os
  | |_________^
  |
help: Organize imports

Found 1 error.
[*] 1 fixable with the `--fix` option.
EXIT=1
```

The same fixture under the pinned **defaults** passes, which is why the control names the rule
instead of assuming it:

```
$ ~/.local/bin/ruff check "$TMPDIR/unsorted.py"; echo EXIT=$?
All checks passed!
EXIT=0
```

The arm prints the same finding as its own `PASS` row (the single concise line, quoted):
`  PASS  unsorted import block -> exit 1; quoted: I001 [*] Import block is un-sorted or un-formatted
(ruff 0.15.22, --select I001)`.

## 4. The FAIL rows are attributable to a tool

Both refusal arms were run against the arm in isolation (`RUFF_BIN` mis-set), and each names what it
found instead of red-ing on the tree:

```
$ RUFF_BIN=~/.hermes/installs/b0e47ae07995f891/environments/24f1df2ad984420181cb6be1707f6a03/venv/bin/ruff bash "$TMPDIR/section51-probe.sh"
51. the python lint lane can go red on one unused import, and green once it is removed (CF-254)
  FAIL  no checker at the pinned ruff 0.15.22 to grade with, so the lint lane cannot be attributed to a tool; tried: ~/.hermes/installs/b0e47ae07995f891/environments/24f1df2ad984420181cb6be1707f6a03/venv/bin/ruff(ruff 0.17.5)

$ RUFF_BIN=/nonexistent/ruff bash "$TMPDIR/section51-probe.sh"
51. the python lint lane can go red on one unused import, and green once it is removed (CF-254)
  FAIL  no checker at the pinned ruff 0.15.22 to grade with, so the lint lane cannot be attributed to a tool; tried: /nonexistent/ruff(absent-or-not-executable)
```

## 5. Wall clock and exit codes

| run | `PATH` | wall | `  PASS` rows | fixture `  FAIL` rows | exit | verdict |
|---|---|---|---|---|---|---|
| default | this shell's | 224 s | 600 | 61 | 0 | `SELFTEST: PASS` |
| 0.17.5 first | pinned dirs prefixed | 203 s | 600 | 61 | 0 | `SELFTEST: PASS` |
| pre-fix arm (isolated) | 0.17.5 first | <1 s | — | — | 1 | `fails=1` (the `FAIL` quoted in §1) |
| `RUFF_BIN` = 0.17.5 (isolated) | `RUFF_BIN` | <1 s | — | — | 1 | attributable `FAIL`, §4 |

Load windows (`cat /proc/loadavg`, first field): 27.42 before run 1, 29.99 before run 2 — both runs
were measured on a loaded host, which is why the walls are compared only to each other.

## 6. Re-run recipe (from the repo root of the commit that carries this file)

```
# 1. the tool and its version
~/.local/bin/ruff --version                       # ruff 0.15.22

# 2. the arm, in place: the whole gate
bash tests/selftest.sh > "$TMPDIR/suite-default.log" 2>&1; echo RC=$?
grep -A5 '^51\. the python lint' "$TMPDIR/suite-default.log"; tail -2 "$TMPDIR/suite-default.log"

# 3. the same gate with the OTHER ruff first on PATH
R2DIR=~/.hermes/installs/b0e47ae07995f891/environments/24f1df2ad984420181cb6be1707f6a03/venv/bin
PATH="$R2DIR:$PATH" ruff --version                # ruff 0.17.5
PATH="$R2DIR:$PATH" bash tests/selftest.sh > "$TMPDIR/suite-0175first.log" 2>&1; echo RC=$?
grep -A5 '^51\. the python lint' "$TMPDIR/suite-0175first.log"; tail -2 "$TMPDIR/suite-0175first.log"

# 4. the red control
printf 'from urllib.parse import urlparse, parse_qs\nimport json\nimport os\n\nprint(json.dumps({"a": os.getcwd(), "u": str(urlparse("x")), "q": parse_qs("y")}))\n' > "$TMPDIR/unsorted.py"
~/.local/bin/ruff check --select I001 "$TMPDIR/unsorted.py"; echo EXIT=$?   # EXIT=1, I001
~/.local/bin/ruff check "$TMPDIR/unsorted.py"; echo EXIT=$?                 # EXIT=0, defaults do not grade it
```

The pre-fix arm can be re-measured without a checkout: take the base commit's suite
(`git show 1c54dfa7:tests/selftest.sh`), eval only the §51 block against the same helpers, and run
it with 0.17.5 first on `PATH` — it prints the three-row `FAIL` quoted in §1. (The probe used here
lived outside the repo, at `~/.hermes/cache/scratch/cf487/section51-probe.sh`; it sources
`scripts/lib.sh`, sets `fails=0`, and `eval`s `sed -n '/^say "51\./,/^# END python-lint$/p' <suite>`.)

## 7. What this does NOT close

- **The tracked surface is graded with the pinned rule set, not with 0.17.5's widened defaults.**
  0.17.5 reports 670 findings on this tree (25 `I001` across 25 files, 306 `UP031`, …). Adopting
  that set is a separate row: 25 tracked files need their imports sorted before the gate could hold
  there, and a widened set is a policy change, not a fix for a launcher-dependent verdict. The `I001`
  control in §3 (M4) is what keeps this arm from being blind to the class in the meantime.
- **The pin is a host fact.** It names `~/.local/bin/ruff` 0.15.22 because that is the tool this
  repo's host carries; there is no repo-pinned ruff artifact to resolve to. A host without that
  binary now gets an *attributable* `FAIL` (§4) instead of a green or an unattributable red — which
  is the honest answer, not a portable pin.
- **`docs/audits/cf094-lint-skip-arms.sh`** (a recorded probe, not a gate) still calls a bare
  `ruff format --check`. Left alone: it documents a guard behaviour as measured, and rewriting a
  historical transcript would falsify it.
- **The guard's own python lint lane** runs its own `ruff`; this arm pins only the checker §51
  grades with. If the lane's binary and this pin ever disagree, the suite will report the pinned
  verdict, and the difference is a separate measurement.
