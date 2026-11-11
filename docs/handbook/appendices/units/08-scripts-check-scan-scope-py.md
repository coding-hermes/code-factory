# 08. scripts/check_scan_scope.py

| Field | Value |
|---|---|
| Path | `~/code-factory/scripts/check_scan_scope.py` — 118 lines [scripts/check_scan_scope.py:1] |
| Repository | `code-factory` [scripts/check_scan_scope.py:1] |
| Revision | `b9f56e6` — the `origin/main` tip every locator below was measured against; the file's own last-touching commit is `5fc2cbd` (2026-11-04, "style(scan-scope): wrap the audit-scope FAIL print for ruff format (CF-163)"), introduced by `5794a49` (CF-163 AC3) |
| Status | **VERIFIED — 155 locators, all resolve; facts cited** |

## 1. Purpose and why it matters

- What it is: a **posture-doc gate**, not a scanner. It never runs a scan, never shells out and never opens a socket: the only I/O is one optional directory listing plus `read_text` on the files it polices [scripts/check_scan_scope.py:41-70]. Its whole rule is one sentence — a line that names `gitleaks` must also name `--log-opts` **on that same line** [scripts/check_scan_scope.py:33-34] [scripts/check_scan_scope.py:64-68].
- The scope it declares, and only this scope: every file matching `docs/audits/code-factory-releng-*.md` (one non-recursive glob, rooted at the repo root) plus the single fixed path `docs/SECURITY-TRIAGE.md` [scripts/check_scan_scope.py:31-32] [scripts/check_scan_scope.py:41-47]. Nothing else in the tree is read — not `docs/master`, not `README.md`, not `docs/audits/*` under any other file name.
- How a path is judged in or out: `root.glob(AUDIT_GLOB)` decides membership by **file name at exactly one directory depth**, and `FIXED_FILES` are appended only when `candidate.exists()` is true [scripts/check_scan_scope.py:42-46]. There is no containment check, no realpath check and no `--exclude`: a path is in scope because its root-relative string matches, and every reported violation is printed as that same root-relative string [scripts/check_scan_scope.py:59] [scripts/check_scan_scope.py:103-105].
- Why a same-line rule at all: a green scan without a recorded revision range is not a posture claim, because the range is undefined at the claim site. This repo publishes an unrelated `master` lineage — 772 commits, none an ancestor of `main` — and the recorded `gitleaks detect --redact --log-opts="--all"` arm reports 547 findings in 64 commits, all 64 on `master` [docs/audits/code-factory-releng-2026-11-04-CF-163-AC3.md:77]. The same repository therefore reads green on `main` and red on `master`, and only the `--log-opts` value tells a reader which one a green covered [scripts/check_scan_scope.py:5-11].
- What breaks if this module is ABSENT: nothing in the delivery path invokes it. `git grep -l check_scan_scope` outside `.gitreins/` and `docs/master/` returns the script itself, three `.coding-hermes/board/events.jsonl` evidence lines, four doc mentions (`docs/ACCEPTANCE-PLAN.md:141`, `docs/audits/code-factory-releng-2026-11-04-CF-163-AC3.md:48`) and exactly one **caller** — the suite at `tests/selftest.sh:1609`. There is no `.github/` workflow (the directory does not exist) and no pre-commit hook that invokes it. The suite does notice a missing file (the invocation exits 2, so arm 1 of §34 reports FAIL [tests/selftest.sh:1610-1615]), but a doc can land on `main` with an unscoped `gitleaks` claim and only a later suite run will say so. That is not hypothetical: commit `a1c7bb2` added a board bookkeeping table whose two lines carry the literal `gitleaks` with no `--log-opts`, and the published tip went red on its own gate until it was repaired in `8995064` [.gitreins/history/2026-11-04/a257fbd6/commit.patch:85].
- What breaks if it LIES: it cannot tell a claim from the word. The test is `CLAIM in line` / `SCOPE_FLAG not in line` [scripts/check_scan_scope.py:65-67], so a sentence stating that the flag was *not* passed satisfies it (measured, §3 arm M), a claim spelled `Gitleaks` is invisible to it (measured, arm L), and any posture doc that is not named `code-factory-releng-*.md` under `docs/audits/` is out of scope by construction (measured, arms G, H, Y). A `RESULT: OK` therefore asserts one narrow thing — *the token appears on the same line as the claim* — and never that a scan ran at that scope. Putting it plainly: this module's green is a **shape** check on prose, and a reader who treats it as a scan attestation is over-reading it.
- Who consumes the verdict: `tests/selftest.sh` §34 asserts the real tree is green, that a fixture with the bad form exits 1 with the named row, and that the same fixture passes once the scope is named [tests/selftest.sh:1608-1639]. The governance row for that section names board `CF-163` AC3 [docs/ACCEPTANCE-PLAN.md:141]; the board row itself is `.coding-hermes/board/tasks.jsonl:138`, cited by id because the board is append-only [docs/master/_facts.md:20] (fact: FACT-09).

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `python3` | measured 3.14.4 here; the source is 3.7+ by construction (every annotation is a string under `from __future__ import annotations` [scripts/check_scan_scope.py:25], including the `list[str] \| None` and `tuple[...]` forms [scripts/check_scan_scope.py:50] [scripts/check_scan_scope.py:73]) | Any host that runs the suite or a foreman gate; invoked as `python3 -B` by the only caller [tests/selftest.sh:1609] | The invocation exits 127/2 and §34 arm 1 reports `  FAIL  posture docs scan-scope checker not green (exit N)` [tests/selftest.sh:1613] |
| A readable repo tree with `docs/` | n/a | The root argument, or the directory containing `scripts/` [scripts/check_scan_scope.py:88-91] | `root.is_dir()` false → `RESULT: FAIL (unreadable path)`, exit 2 [scripts/check_scan_scope.py:92-95] (measured, §3 rows 21-22) |
| No binary, no network, no database | — | — | Verified by reading the whole file: imports are `argparse`, `sys`, `pathlib` only [scripts/check_scan_scope.py:27-29], and `grep -nE 'os\.\|environ\|getenv\|subprocess\|socket\|urllib\|requests' scripts/check_scan_scope.py` returns nothing. The claim token is a string literal, so the tool being checked need not be installed [scripts/check_scan_scope.py:33-34] |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `__future__` [scripts/check_scan_scope.py:25] | stdlib | `annotations` only — annotations stay unevaluated strings | Nothing at runtime; the module still imports and runs |
| `argparse` [scripts/check_scan_scope.py:27] | stdlib | One optional positional, `nargs="?"`, `default=None`, no sub-commands and no flags [scripts/check_scan_scope.py:81-87]; a second positional is a usage error with exit 2 [scripts/check_scan_scope.py:87] | The `default=None` arm is what makes the root script-relative; a required positional would break every caller that passes no argument [tests/selftest.sh:1609] |
| `pathlib` [scripts/check_scan_scope.py:29] | stdlib | `Path.glob` for a **relative pattern containing a slash**, which matches at exactly that depth and never descends [scripts/check_scan_scope.py:42]; `Path.exists` for the fixed file [scripts/check_scan_scope.py:45]; `Path.read_text(encoding="utf-8", errors="replace")` [scripts/check_scan_scope.py:61]; `Path.relative_to` for the printed name [scripts/check_scan_scope.py:59]; `Path.resolve` (non-strict) for the root [scripts/check_scan_scope.py:89-91] | These five behaviours *are* the scope definition. `glob` not descending makes a nested doc invisible (measured, arm H); `*` not matching a leading dot makes a dot-prefixed doc invisible (arm Y); `glob` swallowing a directory's `EACCES` makes an unreadable `docs/audits` look empty (arm T, defect 1); `exists` following symlinks makes a dangling fixed-file link silently drop that surface (arm J), while the glob arm never checks existence and so fails closed on the same breakage (arm W) |
| `sys` [scripts/check_scan_scope.py:28] | stdlib | `sys.exit(main())` — the process status is `main`'s return value [scripts/check_scan_scope.py:117-118]; `0` clean, `1` violation, `2` unreadable [scripts/check_scan_scope.py:21-22] | Every caller grades on the status: §34 arm 1 needs 0 [tests/selftest.sh:1610], arm 2 needs 1 [tests/selftest.sh:1621], arm 3 needs 0 [tests/selftest.sh:1633]. A changed meaning of 2 would silently reclassify the unreadable arms |

### 2c. Service contracts (both sides must be named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| `tests/selftest.sh` §34 | caller → gate | argv (`<repo-root>`) + captured `2>&1` stdout + exit status [tests/selftest.sh:1609] | `python3 -B <root>/scripts/check_scan_scope.py <root>` → text rows | `main()` in the gate [scripts/check_scan_scope.py:73-114]; caller side is the top-level section body, no function [tests/selftest.sh:1608-1639]. The caller asserts the literal line `RESULT: OK` *and* rc 0 [tests/selftest.sh:1610], the regex `^  FAIL  audit-scope: .*:1 gitleaks claim names no --log-opts` *and* rc 1 [tests/selftest.sh:1621-1622] |
| The posture-doc corpus | gate → docs | file reads, one byte stream per file, `errors="replace"` [scripts/check_scan_scope.py:61] | `docs/audits/code-factory-releng-*.md` and `docs/SECURITY-TRIAGE.md`, line by line [scripts/check_scan_scope.py:31-32] [scripts/check_scan_scope.py:64] | The docs themselves carry the claims; six glob files and one fixed file match today, and their eight `gitleaks` lines all name `--log-opts` (§3 arm 1 reports 8 claims across them) |
| Operator / foreman CLI | operator → gate | argv + exit status | `python3 scripts/check_scan_scope.py [<repo-root>]` [scripts/check_scan_scope.py:18-19] | The module's own usage block [scripts/check_scan_scope.py:2-23]; the historical CF-163 evidence rows call it in exactly this form [docs/audits/code-factory-releng-2026-11-04-CF-163-AC3.md:58-59] |
| Governance | row → gate | none — a named link | board `CF-163` AC3 ↔ `tests/selftest.sh` §34 | [docs/ACCEPTANCE-PLAN.md:141] names the row and the script as the section's subject; the board row is appended at [.coding-hermes/board/tasks.jsonl:138] |

## 3. Verification

All rows below were executed on 2026-11-05 in a clean worktree of `b9f56e6` (`~/proj-wt-md-08e`) with Python 3.14.4, as user `kara` (not root, so permission arms are real). The transcript after the table is the literal stdout of one run of the fixture script; `$S` is `/…/scripts/check_scan_scope.py` and `$F` is the scratch fixture root `$TMPDIR/probes`, with the working directory set to `$F` so each argument is the relative name shown.

Fixture note, because the rows matter: every glob fixture is a **scratch** file named `docs/audits/code-factory-releng-2026-11-03.md` — the same *relative* name as a doc that exists in this repo — because the gate prints only root-relative names, and a purely invented name would make the quoted rows unresolvable to a reader following them. The file read was always the scratch copy under `$TMPDIR`; no repo doc was modified, and the real tree is green (§3 row 1, 8 claims).

| # | Check | Command (cwd, argument) | Expected | Last run | Result |
|---|---|---|---|---|---|
| 1 | Real tree, no argument, cwd `/` | `python3 $S` (cwd `/`) | `OK … 8 gitleaks claim(s) name their --log-opts`, rc 0 — proves the default root is script-relative, not cwd-relative [scripts/check_scan_scope.py:91] | 2026-11-05 | **PASS** |
| 2 | In scope, compliant claim | `$S A` | 1 claim, rc 0 | 2026-11-05 | **PASS** |
| 3 | In scope, bad form on line 1 | `$S B` | one row naming `…md:1`, `RESULT: FAIL (1 violation(s))`, rc 1 [scripts/check_scan_scope.py:102-108] | 2026-11-05 | **PASS** |
| 4 | Four violations over both surfaces | `$S O` | four rows, sorted by path then line — `docs/SECURITY-TRIAGE.md:1, :2` before `docs/audits/…:2, :4` (uppercase `S` sorts before lowercase `a`) [scripts/check_scan_scope.py:69] | 2026-11-05 | **PASS** |
| 5 | Fixed file is a directory | `$S I` | `unreadable ([Errno 21] Is a directory …)`, rc 2 [scripts/check_scan_scope.py:60-63] [scripts/check_scan_scope.py:98-101] | 2026-11-05 | **PASS** |
| 6 | Scandoc mode 000 | `$S S` | `unreadable ([Errno 13] Permission denied …)`, rc 2 — fail closed on a per-file read error | 2026-11-05 | **PASS** |
| 7 | Glob hit is a broken symlink | `$S W` | `unreadable ([Errno 2] No such file or directory …)`, rc 2 — the glob arm never pre-checks existence [scripts/check_scan_scope.py:42] | 2026-11-05 | **PASS** |
| 8 | `docs/audits` is mode 000 | `$S T` | **`no posture docs found`, rc 0** — `Path.glob` returns `[]` because it drops the directory's `EACCES`; `os.scandir` on the same path raises `[Errno 13] Permission denied` (verified side by side). Unreadable is indistinguishable from empty | 2026-11-05 | **FAIL (defect 1)** |
| 9 | Fixed file is a dangling symlink | `$S J` | `no posture docs found`, rc 0 — `exists()` is false, so the surface is dropped with no message [scripts/check_scan_scope.py:45] | 2026-11-05 | **FAIL (defect 2)** |
| 10 | Posture doc, wrong name | `$S G` (`docs/audits/other-posture.md`) | `no posture docs found`, rc 0 — out of scope by construction, and the message claims there are none | 2026-11-05 | **FAIL (defect 3)** |
| 11 | Posture doc, nested | `$S H` (`docs/audits/archive/…`) | `no posture docs found`, rc 0 — the glob does not descend | 2026-11-05 | **FAIL (defect 3)** |
| 12 | Posture doc, dot-prefixed | `$S Y` (`docs/audits/.code-factory-releng-hidden.md`) | `no posture docs found`, rc 0 — `*` does not match a leading dot | 2026-11-05 | **FAIL (defect 3)** |
| 13 | Empty root | `$S K` | `no posture docs found`, rc 0 — the documented "nothing to police is OK" arm [scripts/check_scan_scope.py:15-16] | 2026-11-05 | **PASS** (by design) |
| 14 | Claim spelled `Gitleaks` | `$S L` | `0 gitleaks claim(s) …`, rc 0 — the token test is case-sensitive, so only a line pairing `gitleaks` with `--log-opts` counts [scripts/check_scan_scope.py:65] | 2026-11-05 | **FAIL (defect 4)** |
| 15 | Prose mention of the flag | `$S M` | `1 gitleaks claim(s) …`, rc 0 — a sentence saying `--log-opts` was *not* passed still satisfies the same-line test | 2026-11-05 | **FAIL (defect 5)** |
| 16 | Invalid UTF-8 on a claim line | `$S N` | the violation is still reported, rc 1 — `errors="replace"` keeps the line readable [scripts/check_scan_scope.py:61] | 2026-11-05 | **PASS** |
| 17 | `docs/` symlinked outside the root | `$S E` | violation found, rc 1, row names the **in-root** path `docs/audits/…md:1` | 2026-11-05 | **FAIL (defect 6)** |
| 18 | One glob hit symlinked outside | `$S F` | same: rc 1, in-root name | 2026-11-05 | **FAIL (defect 6)** |
| 19 | Fixed file symlinked outside | `$S U` | same: rc 1, in-root name | 2026-11-05 | **FAIL (defect 6)** |
| 20 | Root argument is a symlink | `$S V-link` | rc 1 — `resolve()` makes the root the real directory, the relpaths stay root-relative [scripts/check_scan_scope.py:89] | 2026-11-05 | **PASS** |
| 21 | Root does not exist | `$S does-not-exist` | `… is not a readable directory`, `RESULT: FAIL (unreadable path)`, rc 2 — names the **resolved** path | 2026-11-05 | **PASS** |
| 22 | Root is a regular file | `$S not-a-dir` | same row, rc 2 | 2026-11-05 | **PASS** |
| 23 | Root one level too deep | `python3 scripts/check_scan_scope.py docs` (real tree) | `no posture docs found`, rc 0 — a plausible operator typo is a silent green (same class as the `disk_floor` `--config` defect) | 2026-11-05 | **FAIL (defect 7)** |
| 24 | Two positionals | `$S A B` | argparse usage error, rc 2, and **no `RESULT:` line** [scripts/check_scan_scope.py:81-87] | 2026-11-05 | **PASS** (with the note below) |
| 25 | In-repo red/green gate | `bash tests/selftest.sh` | §34 three arms: `PASS  posture docs name their scan scope`, `PASS  unscoped claim -> FAIL audit-scope`, `PASS  scoped claim -> OK`; whole suite `SELFTEST: PASS`, rc 0 | 2026-11-05 | **PASS** |

Row 24's note: because argparse exits before `main` prints anything, a wrapper that greps for `RESULT:` on an exit-2 invocation sees an empty string rather than a FAIL marker. §34 never passes two positionals, so nothing in the suite depends on the marker being present at rc 2 — but a future caller that does would misread it.

Setup — the fixture script, with only the absolute script path elided and a comment added to each deliberately non-compliant line so that this document stays inside its own rule (`$G` is the scratch name that mirrors the repo doc, `$X` the fixed path):

```
S=/…/scripts/check_scan_scope.py
F=$TMPDIR/probes
G=docs/audits/code-factory-releng-2026-11-03.md      # name copied from an existing repo doc
X=docs/SECURITY-TRIAGE.md                            # the one fixed file, by real path
SCOPED='| Secrets | `gitleaks detect -c .gitleaks.toml --redact --log-opts="--all"` | clean |'
UNSCOPED='| Secrets | `gitleaks detect -c .gitleaks.toml --redact` | clean |'   # bad form: no --log-opts

chmod -R u+rwX "$F" 2>/dev/null; rm -rf "$F"; mkdir -p "$F"
for d in A B E F G H L M N O S V W Y; do mkdir -p "$F/$d/docs/audits"; done
mkdir -p "$F/J/docs" "$F/K/docs" "$F/I/$X" "$F/H/docs/audits/archive" "$F/outside/audits" "$F/outside/files"
: > "$F/not-a-dir"; rm -rf "$F/E/docs/audits"

printf '%s\n' "$SCOPED"   > "$F/A/$G"
printf '%s\n' "$UNSCOPED" > "$F/B/$G"
ln -s "$F/outside/audits" "$F/E/docs/audits"
printf '%s\n' "$UNSCOPED" > "$F/outside/audits/code-factory-releng-2026-11-03.md"
printf '%s\n' "$UNSCOPED" > "$F/outside/files/real.md"
ln -s "$F/outside/files/real.md" "$F/F/$G"
printf '%s\n' "$UNSCOPED" > "$F/G/docs/audits/other-posture.md"
printf '%s\n' "$UNSCOPED" > "$F/H/docs/audits/archive/code-factory-releng-2026-11-03.md"
ln -s "$F/gone.md" "$F/J/$X"
printf '%s\n' '| Secrets | Gitleaks detected nothing | clean |' > "$F/L/$G"
printf '%s\n' 'A gitleaks run described in prose: we did not pass --log-opts here.' > "$F/M/$G"
printf '| Secrets | `gitleaks detect` \xff\xfe | clean |\n' > "$F/N/$G"        # bad form: no --log-opts
printf '%s\n' 'clean line' 'gitleaks one' 'gitleaks two --log-opts="--all"' 'gitleaks three' > "$F/O/$G"
printf '%s\n' 'gitleaks fixed one' 'gitleaks fixed two' > "$F/O/$X"   # bad form: no --log-opts
printf '%s\n' 'gitleaks detect' > "$F/S/$G"; chmod 000 "$F/S/$G"                   # bad form: no --log-opts
printf '%s\n' 'gitleaks detect' > "$F/V/$G"; ln -s "$F/V" "$F/V-link"             # bad form: no --log-opts
ln -s "$F/gone.md" "$F/W/$G"
printf '%s\n' '| Secrets | `gitleaks detect -c .gitleaks.toml --redact` | clean |' > "$F/Y/docs/audits/.code-factory-releng-hidden.md"   # bad form: no --log-opts
printf '%s\n' 'gitleaks detect' > "$F/outside/files/triage.md"                    # bad form: no --log-opts
mkdir -p "$F/U/docs"; ln -s "$F/outside/files/triage.md" "$F/U/$X"
mkdir -p "$F/T/docs/audits"; printf '%s\n' 'gitleaks detect' > "$F/T/$G"; chmod 000 "$F/T/docs/audits"   # bad form: no --log-opts
```

```
=== real tree, no argument, cwd=/
  OK  audit-scope: 8 gitleaks claim(s) name their --log-opts
RESULT: OK
rc=0

$ python3 $S A
  OK  audit-scope: 1 gitleaks claim(s) name their --log-opts
RESULT: OK
rc=0

$ python3 $S B
  FAIL  audit-scope: docs/audits/code-factory-releng-2026-11-03.md:1 gitleaks claim names no --log-opts
RESULT: FAIL (1 violation(s))
rc=1

$ python3 $S O
  FAIL  audit-scope: docs/SECURITY-TRIAGE.md:1 gitleaks claim names no --log-opts
  FAIL  audit-scope: docs/SECURITY-TRIAGE.md:2 gitleaks claim names no --log-opts
  FAIL  audit-scope: docs/audits/code-factory-releng-2026-11-03.md:2 gitleaks claim names no --log-opts
  FAIL  audit-scope: docs/audits/code-factory-releng-2026-11-03.md:4 gitleaks claim names no --log-opts
RESULT: FAIL (4 violation(s))
rc=1

$ python3 $S I
  FAIL  audit-scope: docs/SECURITY-TRIAGE.md unreadable ([Errno 21] Is a directory: '~/.hermes/cache/scratch/md20e-h/tmp/probes/I/docs/SECURITY-TRIAGE.md')
RESULT: FAIL (unreadable path)
rc=2

$ python3 $S S
  FAIL  audit-scope: docs/audits/code-factory-releng-2026-11-03.md unreadable ([Errno 13] Permission denied: '~/.hermes/cache/scratch/md20e-h/tmp/probes/S/docs/audits/code-factory-releng-2026-11-03.md')
RESULT: FAIL (unreadable path)
rc=2

$ python3 $S W
  FAIL  audit-scope: docs/audits/code-factory-releng-2026-11-03.md unreadable ([Errno 2] No such file or directory: '~/.hermes/cache/scratch/md20e-h/tmp/probes/W/docs/audits/code-factory-releng-2026-11-03.md')
RESULT: FAIL (unreadable path)
rc=2

$ python3 $S T
  OK  audit-scope: no posture docs found
RESULT: OK
rc=0

$ python3 $S J
  OK  audit-scope: no posture docs found
RESULT: OK
rc=0

$ python3 $S G
  OK  audit-scope: no posture docs found
RESULT: OK
rc=0

$ python3 $S H
  OK  audit-scope: no posture docs found
RESULT: OK
rc=0

$ python3 $S Y
  OK  audit-scope: no posture docs found
RESULT: OK
rc=0

$ python3 $S K
  OK  audit-scope: no posture docs found
RESULT: OK
rc=0

$ python3 $S L
  OK  audit-scope: 0 gitleaks claim(s) name their --log-opts
RESULT: OK
rc=0

$ python3 $S M
  OK  audit-scope: 1 gitleaks claim(s) name their --log-opts
RESULT: OK
rc=0

$ python3 $S N
  FAIL  audit-scope: docs/audits/code-factory-releng-2026-11-03.md:1 gitleaks claim names no --log-opts
RESULT: FAIL (1 violation(s))
rc=1

$ python3 $S E
  FAIL  audit-scope: docs/audits/code-factory-releng-2026-11-03.md:1 gitleaks claim names no --log-opts
RESULT: FAIL (1 violation(s))
rc=1

$ python3 $S F
  FAIL  audit-scope: docs/audits/code-factory-releng-2026-11-03.md:1 gitleaks claim names no --log-opts
RESULT: FAIL (1 violation(s))
rc=1

$ python3 $S U
  FAIL  audit-scope: docs/SECURITY-TRIAGE.md:1 gitleaks claim names no --log-opts
RESULT: FAIL (1 violation(s))
rc=1

$ python3 $S V-link
  FAIL  audit-scope: docs/audits/code-factory-releng-2026-11-03.md:1 gitleaks claim names no --log-opts
RESULT: FAIL (1 violation(s))
rc=1

$ python3 $S does-not-exist
  FAIL  audit-scope: ~/.hermes/cache/scratch/md20e-h/tmp/probes/does-not-exist is not a readable directory
RESULT: FAIL (unreadable path)
rc=2

$ python3 $S not-a-dir
  FAIL  audit-scope: ~/.hermes/cache/scratch/md20e-h/tmp/probes/not-a-dir is not a readable directory
RESULT: FAIL (unreadable path)
rc=2

=== cwd=docs one level too deep (real tree)
  OK  audit-scope: no posture docs found
RESULT: OK
rc=0

=== two positionals
usage: check_scan_scope.py [-h] [root]
check_scan_scope.py: error: unrecognized arguments: B
rc=2
```

What the real tree is measured to contain: six files match the glob and `docs/SECURITY-TRIAGE.md` is appended [scripts/check_scan_scope.py:41-47]; the eight claims are `docs/audits/code-factory-releng-2026-11-04-CF-161.md:25`, five in `docs/audits/code-factory-releng-2026-11-04-CF-163-AC3.md` (`:39`, `:48`, `:58`, `:77`, `:162`), and two in `docs/audits/code-factory-releng-2026-11-04-CF-163.md` (`:25`, `:66`). `docs/SECURITY-TRIAGE.md` is scanned and contributes zero claims, which is why the count is 8 and not more.

Self-application: the gate polices `docs/audits/`, not `docs/master/`, so nothing in this document is in its scope today. It is written to the same rule anyway — every line here that contains the token `gitleaks` also contains `--log-opts` — so widening `AUDIT_GLOB` would not redden the tree on this file. Checkable with `grep -n gitleaks docs/master/08-scripts-check-scan-scope-py.md | grep -v -- --log-opts`, which prints nothing.

## 4. Metrics emitted

**NONE.** There is no counter, histogram, gauge, exporter, span, duration or log level anywhere in the file: `grep -cE 'logging|logger|metric|counter|prometheus|histogram|span|time\.' scripts/check_scan_scope.py` returns `0`, and the complete output surface is nine `print` calls [scripts/check_scan_scope.py:93-113]. The one number the module does emit is the claim count in its success line [scripts/check_scan_scope.py:112] — `8` on this tree, `0` when a doc spelled the token differently (arm L) — and it is a prose-count, not a measurement of how many scans were run or how many findings exist.

Why none is appropriate: this is a single-shot CLI gate invoked once per suite run over seven files, so there is no rate, queue depth or latency worth instrumenting. The quantity an operator would actually want — how many `gitleaks` claims carrying `--log-opts` were ever checked, how many failed, how often the gate is skipped — is not recorded anywhere: the module writes no file, no store and no state [scripts/check_scan_scope.py:73-118], and the caller keeps only the two printed rows [tests/selftest.sh:1609-1638]. Dispatch rate, failure counts and liveness are therefore not measurable from this module's own output; they are reconstructable only by re-running it, which is the point of a re-runnable gate [docs/master/_facts.md:21] (fact: FACT-10).

## 5. Log lines it can generate

All nine `print` sites, verbatim from source; the module has no level, logger or destination, so every line goes to stdout and is captured by the caller's `2>&1` [tests/selftest.sh:1609].

| Level | Line (verbatim) | Emitted when | Kind |
|---|---|---|---|
| — | `  FAIL  audit-scope: {root} is not a readable directory` | `root.is_dir()` is false after `resolve()` — nonexistent root or a regular file [scripts/check_scan_scope.py:92-93] | **evidentiary** — names the resolved path that failed |
| — | `RESULT: FAIL (unreadable path)` | that case, and again for any `UnreadablePath` [scripts/check_scan_scope.py:94] [scripts/check_scan_scope.py:100] | **evidentiary** — the exit-2 marker; note it does **not** carry a count |
| — | `  FAIL  audit-scope: {relpath} unreadable ({exc})` | `read_text` raised `OSError` for a path that was already selected: `Is a directory`, `Permission denied`, or a broken symlink [scripts/check_scan_scope.py:60-63] [scripts/check_scan_scope.py:98-99] | **evidentiary** — carries the errno text and the absolute path from the exception |
| — | `  FAIL  audit-scope: {relpath}:{lineno} gitleaks claim names no --log-opts` | a line contains the claim token and not the scope token [scripts/check_scan_scope.py:64-68] [scripts/check_scan_scope.py:102-105] | **evidentiary** — one row per violation, `path:line` exactly as an editor would open it |
| — | `RESULT: FAIL ({len(violations)} violation(s))` | at least one violation [scripts/check_scan_scope.py:106-107] | **evidentiary** — the count is the number of rows printed above it (measured: 4 rows, `(4 violation(s))`, arm O) |
| — | `  OK  audit-scope: no posture docs found` | `scanned_files()` returned nothing [scripts/check_scan_scope.py:109-110] | **descriptive** — and ambiguous by measurement: it is printed for an empty root (arm K), a mis-named doc (G), a nested doc (H), a dot-prefixed doc (Y), a dangling fixed link (J) and an unreadable `docs/audits` (T). Only arm K is the intended case |
| — | `  OK  audit-scope: {claims} gitleaks claim(s) name their --log-opts` | at least one file was scanned, no violations [scripts/check_scan_scope.py:111-112] | **descriptive** — `{claims}` is the count of claim-token lines, so arm L's `0` means the token never matched, not that a claim was checked |
| — | `RESULT: OK` | clean run, exit 0 [scripts/check_scan_scope.py:113] | **evidentiary** for the file set it scanned, **descriptive** about scope — §34 grades on this exact string [tests/selftest.sh:1610] |
| — | `usage: check_scan_scope.py [-h] [root]` + `check_scan_scope.py: error: unrecognized arguments: B` | argparse rejected the argv before `main` ran [scripts/check_scan_scope.py:74-87] | **evidentiary** — stderr, exit 2, and no `RESULT:` line at all (arm 24) |

Consumer-side rows that quote it: `  PASS  posture docs name their scan scope`, `  PASS  unscoped claim -> FAIL audit-scope` and `  PASS  scoped claim -> OK` [tests/selftest.sh:1611] [tests/selftest.sh:1623] [tests/selftest.sh:1634], plus `  FAIL  posture docs scan-scope checker not green (exit $rc)` when the first arm breaks [tests/selftest.sh:1613].

## 6. Failure modes

Direction is the module's behaviour as measured, not a preference: **fail closed** means a non-zero exit stops the suite; **fail open** means the run reports `RESULT: OK` while a real violation or a missing surface goes unexamined.

| Failure | Presents as | Direction | Distinguished from | Recovery |
|---|---|---|---|---|
| A doc line names a `gitleaks` claim with no `--log-opts` on that line | `  FAIL  audit-scope: <relpath>:<lineno> …` + `RESULT: FAIL (n violation(s))`, exit 1 [scripts/check_scan_scope.py:102-108] | **fail closed** — the intended case, and the only case that exits 1 | The unreadable arms exit 2 with `RESULT: FAIL (unreadable path)`; a violation run never prints `unreadable` | add the scope to that line, or drop the claim |
| `docs/audits/` is unreadable (mode 000, ACL, or a mount that went away) | `  OK  audit-scope: no posture docs found`, exit 0 — `Path.glob` returns `[]` and drops the `EACCES`; `os.scandir` on the same directory raises `[Errno 13] Permission denied` | **fail open, silently** — and it contradicts the module's own contract that a scanned path which cannot be read exits 2 [scripts/check_scan_scope.py:21-22] | Nothing distinguishes it from an empty tree; only `ls -ld docs/audits` from the operator reveals it — **defect 1** | restore the mode; no in-module signal exists to act on |
| `docs/SECURITY-TRIAGE.md` is a dangling symlink | `  OK  audit-scope: no posture docs found`, exit 0 — `candidate.exists()` is false so the fixed path is never appended [scripts/check_scan_scope.py:44-46] | **fail open, silently** | A dangling **glob** hit is the opposite: it is selected, `read_text` fails `ENOENT`, exit 2 (arm W) — the two arms disagree on the same breakage — **defect 2** | repoint or delete the link; the glob arm's exit 2 is the shape the fixed arm should have |
| A posture doc exists but is not named `code-factory-releng-*.md` in `docs/audits/`, or is nested one level deeper, or is dot-prefixed | `  OK  audit-scope: no posture docs found`, exit 0 | **fail open** by construction — the scope is a name pattern at one depth [scripts/check_scan_scope.py:31] [scripts/check_scan_scope.py:42] | An in-scope doc with a violation prints a `path:line` row instead | rename the doc into the pattern, or widen the constant (a code change, not a setting) — **defect 3** |
| The claim is spelled `Gitleaks`, `GITLEAKS`, or the token split across a line break | `0 gitleaks claim(s) …`, exit 0 | **fail open** — `CLAIM in line` is a case-sensitive substring test, so a line naming `gitleaks` with `--log-opts` counts only in that exact casing [scripts/check_scan_scope.py:65] | A compliant claim is counted (`1 gitleaks claim(s) name their --log-opts`), so the count is the only hint, and `0` reads like "nothing to check" rather than "nothing matched" | write the token in lower case — **defect 4** |
| The claim line mentions the flag in prose, e.g. stating `--log-opts` was *not* passed | `1 gitleaks claim(s) …`, exit 0 | **fail open (false PASS)** — the test is presence of the `--log-opts` substring anywhere on a line that also names `gitleaks` [scripts/check_scan_scope.py:33-34] [scripts/check_scan_scope.py:67] | There is no distinguishing signal; a genuine scoped claim and a prose mention are identical to this module | human review of the claim line — **defect 5** |
| `docs/`, `docs/audits/` or the fixed file is a symlink to a tree outside the root | the violation is found and reported, but the row names the **in-root** path (`docs/audits/…md:1`) although the bytes came from outside the root [scripts/check_scan_scope.py:59] | **fail open on scope, fail closed on the violation** — the declared roots are silently widened, and the report cannot be used to tell where the file really lives | No message, no marker, no realpath in the output — **defect 6** | inspect the tree for symlinks; `find . -type l` before trusting a green or a red |
| The operator points the root one level off (`docs` instead of the repo root) | `  OK  audit-scope: no posture docs found`, exit 0 | **fail open** — a plausible typo becomes a green, the same class as the `disk_floor` `--config` defect | The green arm on the real tree reports `8 gitleaks claim(s) name their --log-opts`; `0` or a no-docs line is the tell | pass the repo root, or no argument at all (the default is script-relative [scripts/check_scan_scope.py:91]) — **defect 7** |
| The root does not exist, or is a regular file | `  FAIL  audit-scope: <resolved path> is not a readable directory` + `RESULT: FAIL (unreadable path)`, exit 2 [scripts/check_scan_scope.py:92-95] | **fail closed** | A violation run exits 1 and carries a count; this carries none | pass a directory |
| A selected file cannot be read (directory in its place, mode 000, broken symlink) | `  FAIL  audit-scope: <relpath> unreadable (<errno text>)`, exit 2 [scripts/check_scan_scope.py:60-63] | **fail closed** — correct, and the message names both the relpath and the absolute path from the exception | The root-level arm names a directory instead of a relpath | fix the mode or the link |
| The document is not valid UTF-8 | the claim is still found; `errors="replace"` substitutes and the line is tested as text [scripts/check_scan_scope.py:61] | **fail closed on the claim** — no crash, no skip | Nothing: a corrupt line and a clean line are tested identically, so byte corruption elsewhere in the doc is normalized without notice | repair the encoding |
| Two positionals are passed | argparse usage error on stderr, exit 2, and **no `RESULT:` line** [scripts/check_scan_scope.py:81-87] | **fail closed** by status, but the marker a wrapper greps for is absent | Every other exit path prints a `RESULT:` line | pass one root, or none |

## 7. Environment and settings it reads

There is exactly one setting, and it is argv — the module reads no environment variable, no config file and no credential (measured: `grep -nE 'os\.|environ|getenv' scripts/check_scan_scope.py` returns nothing; imports are `argparse`, `sys`, `pathlib` [scripts/check_scan_scope.py:27-29]).

| Setting | Where read | Default | Effect of missing |
|---|---|---|---|
| `root` positional | `parser.add_argument("root", nargs="?", default=None)` [scripts/check_scan_scope.py:81-86] | `None` → `Path(__file__).resolve().parent.parent`, i.e. the directory above `scripts/` [scripts/check_scan_scope.py:90-91] | The gate scans the tree it lives in, independent of cwd (measured from cwd `/`, arm 1) |
| Relative `root` | `Path(args.root).resolve()` [scripts/check_scan_scope.py:88-89] | resolved against the **caller's cwd** | A relative argument from the wrong directory is a silent green (arm 23) |
| `AUDIT_GLOB` | module constant `docs/audits/code-factory-releng-*.md` [scripts/check_scan_scope.py:31] | fixed in code | Not settable by flag, env or config; widening it is a source change plus a suite run |
| `FIXED_FILES` | module constant `("docs/SECURITY-TRIAGE.md",)` [scripts/check_scan_scope.py:32] | fixed in code | Same; a missing member is skipped silently [scripts/check_scan_scope.py:44-46] |
| `CLAIM` / `SCOPE_FLAG` | module constants `"gitleaks"` / `"--log-opts"` [scripts/check_scan_scope.py:33-34] | fixed in code | The rule's grammar is not configurable, which is what makes §34's regex assertions stable [tests/selftest.sh:1622] |
| `-h` / `--help` | argparse [scripts/check_scan_scope.py:74-80] | off | Prints the one-line description naming the rule and CF-163 AC3 |
| Exit status | `sys.exit(main())` [scripts/check_scan_scope.py:118] | — | `0` clean [scripts/check_scan_scope.py:114], `1` violations [scripts/check_scan_scope.py:108], `2` unreadable or bad argv [scripts/check_scan_scope.py:95] [scripts/check_scan_scope.py:101] |

No secret, token, path-to-credential, host or URL is read here, so the fleet rule that credentials travel as file paths at mode 600 [docs/master/_facts.md:16] has no surface on this module: the only paths it touches are the root and the files under it.

## 8. Evidence of record

- **Measured 2026-11-05** in a clean worktree of `b9f56e6` (`~/proj-wt-md-08e`), Python 3.14.4, user `kara`. The §3 transcript is one run of one script against a fixture tree under `$TMPDIR`, in the arm order printed; the exit codes quoted are the shell's `$?` after each invocation.
- **Gate of record**: `bash tests/selftest.sh` → `SELFTEST: PASS`, rc 0, 331 `  PASS` rows plus the closing marker (`grep -c '^  PASS'` on the log), and §34's three arms all PASS (`posture docs name their scan scope`, `unscoped claim -> FAIL audit-scope`, `scoped claim -> OK`) [tests/selftest.sh:1608-1639]. The suite's other `FAIL` lines in its log are the negative controls it is designed to print, not failures of the suite.
- **The gate's own red/green history**: CF-163 delivered the script in `5794a49`, and a later bookkeeping commit added two lines carrying the literal `gitleaks` with no `--log-opts`, which turned the published tip red on this very gate — `python3 scripts/check_scan_scope.py` reported the two sites and the repair in `8995064` restored `RESULT: OK` [.gitreins/history/2026-11-04/f09c06d5/commit.patch:11] [.gitreins/history/2026-11-04/a257fbd6/commit.patch:85]. That is the module doing its job on real material, and it is why the rule is asserted in the suite rather than trusted to reviewers.
- **Delivery provenance**: `5794a49` ("docs(posture): a gitleaks claim must name its scan scope (CF-163 AC3)" — that is, name its `--log-opts`) added the file; `5fc2cbd` is a ruff-format wrap of the violation `print` [scripts/check_scan_scope.py:102-105]. The board row is `CF-163` at [.coding-hermes/board/tasks.jsonl:138]; per the board's append-only rule [docs/master/_facts.md:20] (fact: FACT-09) rows are cited by id, and per rule 3 an evidence line must be a re-runnable command rather than a commit message [docs/master/_facts.md:21] (fact: FACT-10) — which is why §3 carries commands and exit codes, not assertions.
- **Assertion scope**, unit by unit:

| Unit | Assertion |
|---|---|
| Selection: glob membership, fixed-file append [scripts/check_scan_scope.py:41-47] | **measured** — arms 2, 3, 10, 11, 12, 19 |
| Line classification: claim token × scope token [scripts/check_scan_scope.py:64-68] | **measured** — arms 2, 3, 4, 14, 15, 16 |
| Unreadable-file boundary [scripts/check_scan_scope.py:58-63] | **measured** — arms 5, 6, 7 (exit 2 each) |
| Unreadable-**directory** boundary | **measured and absent** — arm 8 shows `glob` dropping `EACCES`; the module has no code path that could see it, so this is a coverage hole, not an untested branch (defect 1) |
| Root resolution (default, relative, symlink, non-directory) [scripts/check_scan_scope.py:88-95] | **measured** — arms 1, 20, 21, 22, 23, 24 |
| Symlink behaviour inside scope | **measured** — arms 7, 9, 17, 18, 19 (no realpath check exists; the four arms disagree with each other) |
| Sorting and count of the `RESULT:` line [scripts/check_scan_scope.py:69] [scripts/check_scan_scope.py:107] | **measured** — arm 4 prints four rows in path-then-line order and counts 4 |
| Behaviour on Python < 3.7 | **ASSUMED-untested** — no such interpreter exists on this host; the claim rests on `from __future__ import annotations` making every annotation a string [scripts/check_scan_scope.py:25] |
| Windows / case-insensitive filesystems | **not this module's surface** — no caller runs it there; the glob and `relative_to` semantics would differ and nothing here depends on them |

Defects measured while filling this section (filed, **not** fixed — `scripts/` is out of scope for this task):

1. **An unreadable directory is indistinguishable from an empty one.** `Path.glob` returns `[]` when `docs/audits` is mode 000 (verified next to `os.scandir`, which raises `[Errno 13] Permission denied`), so the gate prints `no posture docs found` and exits 0 — while its own docstring promises exit 2 when a scanned path is unreadable [scripts/check_scan_scope.py:21-22]. The whole glob surface can vanish without a signal.
2. **A dangling symlink at the fixed path silently removes that surface.** `candidate.exists()` is false, so `docs/SECURITY-TRIAGE.md` is never appended [scripts/check_scan_scope.py:44-46]; the same breakage on a glob hit exits 2 because the glob arm never pre-checks existence [scripts/check_scan_scope.py:42]. Two arms, two directions for one fault.
3. **The scope is a file-name pattern at one depth, and the message denies that docs exist.** A posture doc named `other-posture.md`, nested under `docs/audits/archive/`, or dot-prefixed is not scanned, and the run reports `no posture docs found` rather than `no doc matched the pattern` — the one message an operator would use to tell a clean tree from an unscoped one.
4. **The token test is case-sensitive.** `Gitleaks` is not a claim, so a doc can carry an unscoped claim — `gitleaks` present, `--log-opts` absent — and the gate reports `0 gitleaks claim(s)`; a count of zero that reads like a clean tree.
5. **Presence of the flag anywhere on the line satisfies the rule.** A sentence stating the flag was *not* passed passes (measured), so the gate grades the shape of prose, not the recorded command.
6. **Symlinks widen the declared scope silently, and the report cannot say so.** A `docs/` or `docs/audits/` symlink (or a symlinked file) outside the root is followed, and the violation row names the in-root path because `relative_to` is applied to the lexical path [scripts/check_scan_scope.py:59]. Nothing in the output distinguishes a finding inside the root from one read outside it.
7. **A root that is one level off is a silent green.** `docs` instead of the repo root yields `no posture docs found`, exit 0 — the same class as the `disk_floor` `--config` defect, and the reason the default (script-relative) is safer than an operator-supplied path.
8. **Exit 2 from argparse carries no `RESULT:` marker.** A wrapper that greps `RESULT:` sees an empty string on a usage error [scripts/check_scan_scope.py:81-87], while every path inside `main` prints one.
