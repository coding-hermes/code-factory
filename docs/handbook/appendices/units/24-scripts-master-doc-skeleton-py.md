# 24. scripts/master_doc_skeleton.py

| Field | Value |
|---|---|
| Path | `~/code-factory/scripts/master_doc_skeleton.py` — 242 lines [scripts/master_doc_skeleton.py:1] [scripts/master_doc_skeleton.py:242] |
| Repository | `code-factory`, one of the four trees the file names in its own `REPOS` table [scripts/master_doc_skeleton.py:16-24] |
| Revision | `dad2749` — the tree every locator below was measured against; `sha256 01e7499d…` byte-identical to the `6eea792` checkout the generator reads as its own source [scripts/master_doc_skeleton.py:17]. Last commit touching the file: `0978d58` ("fix(lint): clear the F401 red … Addresses CF-254.") |
| Status | **VERIFIED — 124 locators (62 distinct file:line pairs), all resolving; every mechanism below was run, including a regeneration diffed against `docs/master`; the template's eight headings still match the gate and all 40 shipped documents, its membership does not (§8)** |

## 1. Purpose and why it matters

- What it is: the generator of the forty documents this one belongs to. It walks four repositories [scripts/master_doc_skeleton.py:16-24] plus one hand-added host path [scripts/master_doc_skeleton.py:25] [scripts/master_doc_skeleton.py:211], takes the **first 40** components it finds [scripts/master_doc_skeleton.py:212], and writes each as a numbered file built by `section()` [scripts/master_doc_skeleton.py:94-193] into a hardcoded output directory [scripts/master_doc_skeleton.py:15], finishing with `00-INDEX.md` [scripts/master_doc_skeleton.py:233]. Its docstring states the whole design rule: *"Nothing here is prose. Every field is either derived mechanically from the source or marked RED because no evidence exists yet."* [scripts/master_doc_skeleton.py:2-8].
- What it really is: an eight-heading **contract** plus five fixed table shapes. `section()` emits the headings in a fixed order — Purpose, Dependencies, Verification, Metrics emitted, Log lines it can generate, Failure modes, Environment, Evidence of record [scripts/master_doc_skeleton.py:111-192] — and the gate grades against a hand-copied list of those same eight strings [scripts/master_doc_check.py:21-30]. The checker's comment says the list must be *derived from the template* [scripts/master_doc_check.py:18-20], but the checker never opens the template: the word `skeleton` appears in it only inside that comment. The coupling is by transcription today and by nothing at all tomorrow (§6, row 9); §3 row 4 proves it currently holds.
- What breaks if this module is ABSENT: nothing produces `docs/master/00-INDEX.md` or the numbered module files — across `scripts/*.py` the string `00-INDEX` occurs only at [scripts/master_doc_skeleton.py:224] and [scripts/master_doc_skeleton.py:233]. The fill runner then globs an empty directory [scripts/master_doc_fill.py:404], and the gate honours that silence: zero files selected is still `MASTER-DOC: PASS` [scripts/master_doc_check.py:122-124] [scripts/master_doc_check.py:140-143]. Direction: absence is *silent at the gate*, which is why this section exists.
- What breaks if it LIES: the document set's central claim — that a RED field is a claim without evidence, not an unwritten section [scripts/master_doc_skeleton.py:201-206] — becomes decoration. Two lies are already shipped and measured. First, the index it writes declares `- Modules with a verification command: **0**` [docs/master/00-INDEX.md:52] while the same file marks 19 rows `VERIFIED` [docs/master/00-INDEX.md:10]; the counter is a literal [scripts/master_doc_skeleton.py:227-229] and no program recomputes it (the only writer of that file is this one). Second, the generator's own template for this module claims `**RED: none identified mechanically**` for runtime dependencies (§2a of a fresh generation) although the module cannot produce a revision without `git` [scripts/master_doc_skeleton.py:32-43] — a false negative produced by a regex that cannot see a call split across lines [scripts/master_doc_skeleton.py:88-90].
- Why the doctrine matters here: *"A section turns green by running a command, never by editing prose"* [scripts/master_doc_skeleton.py:202] is the document-side form of the rule the board already enforces for rows — a row closes only with a re-runnable command in its evidence, never a commit message [docs/master/_facts.md:20] (fact: FACT-10). The generator preaches it and then writes three counters that no command can move [scripts/master_doc_skeleton.py:227-229]. That gap, not the prose, is the finding.

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `python3` | 3.14.4 measured here; the file is stdlib-only and has no `from __future__`, so the floor is the first release with `subprocess.run(capture_output=...)` — 3.7 [scripts/master_doc_skeleton.py:10-13] [scripts/master_doc_skeleton.py:34-40] | The control host, in whatever interpreter runs the script — there is no wrapper, no Makefile target and no selftest arm that invokes it (§3 row 15) | Nothing: an interpreter that cannot parse the file is the only failure, and it is loud |
| `git` | 2.53.0 measured | Any machine holding the four trees in `REPOS` [scripts/master_doc_skeleton.py:16-24]; invoked once per module as `git -C <repo> rev-parse --short HEAD` [scripts/master_doc_skeleton.py:34-40] | `rev()` catches every exception and returns `"unknown"` [scripts/master_doc_skeleton.py:41-43]. **Measured**: with `PATH` emptied, every one of the 40 documents carries a Revision row reading `unknown`, exit 0, 0 bytes on stderr (§3 row 8) |
| writable `OUT` | — | `~/code-factory/docs/master`, absolute and unoverridable [scripts/master_doc_skeleton.py:15]; created if missing [scripts/master_doc_skeleton.py:197] | Loud, and early: `mkdir` runs before the first module is examined, and an existing *file* at that path raises `FileExistsError` with nothing written (§3 row 11) |
| no network client, no database, no HTTP library | — | — | The only child process is `git` [scripts/master_doc_skeleton.py:34]; no `urllib`, `http`, `socket` or `sqlite` token exists in the file [scripts/master_doc_skeleton.py:10-13] |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `json` [scripts/master_doc_skeleton.py:10] | stdlib | `json.dumps` of one summary object as the entire stdout payload [scripts/master_doc_skeleton.py:234-238] | Nothing in the repo parses it: `red_fields` occurs at exactly one place in the tree, the line that writes it [scripts/master_doc_skeleton.py:236]; a shape change is invisible to every consumer because there is none |
| `re` [scripts/master_doc_skeleton.py:11] | stdlib | `SKIP` compiled once [scripts/master_doc_skeleton.py:27-29] and applied to every path [scripts/master_doc_skeleton.py:51]; four `findall` derivations for deps, variables, log strings and child commands [scripts/master_doc_skeleton.py:71-90]; one `sub` for the filename slug [scripts/master_doc_skeleton.py:216-219] | A widened `SKIP` silently changes which files exist as modules; it excludes `.git`, `node_modules`, `venv`, `.venv`, `vendor`, `dist`, `build`, `__pycache__`, `.gitreins` and `docs/master` [scripts/master_doc_skeleton.py:27-29] — but **not** `.worktrees`, which is why crier's first component is a worktree copy of itself (§3 row 13) |
| `subprocess` [scripts/master_doc_skeleton.py:12] | stdlib | One call, `capture_output=True, text=True, errors="replace", timeout=20`, no `check` [scripts/master_doc_skeleton.py:34-40] | `check` is absent by design and the exception is swallowed [scripts/master_doc_skeleton.py:42]; raising the timeout only lengthens a stall that already degrades to `unknown`, it never reports one |
| `pathlib.Path` [scripts/master_doc_skeleton.py:13] | stdlib | `root.rglob("*")` traversal [scripts/master_doc_skeleton.py:50], `relative_to(...).as_posix()` for the displayed path [scripts/master_doc_skeleton.py:53] [scripts/master_doc_skeleton.py:96-100], `read_text(errors="replace")` [scripts/master_doc_skeleton.py:70], `write_text(encoding="utf-8")` [scripts/master_doc_skeleton.py:220] [scripts/master_doc_skeleton.py:233], `mkdir(parents=True, exist_ok=True)` [scripts/master_doc_skeleton.py:197] | `rglob` over a missing directory yields nothing rather than raising, so a renamed repository shrinks the set in silence (§6, row 5); `write_text` is a single truncate-and-write, not a temp-file-plus-rename, so an interrupted run leaves a half document with no marker (§6, row 6) |

### 2c. Service contracts (both sides must be named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| `git` | outbound, once per module | argv + pipes [scripts/master_doc_skeleton.py:34-40] | `-C <repo> rev-parse --short HEAD`; only stdout is read, and only emptiness is tested [scripts/master_doc_skeleton.py:41] | the `git` binary on `PATH`; no in-repo peer, no version pin |
| the output directory | outbound write, no reply | filesystem [scripts/master_doc_skeleton.py:220] [scripts/master_doc_skeleton.py:233] | a numbered Markdown document and a 40-row index | `scripts/master_doc_fill.py:404` reads the same glob, `scripts/master_doc_check.py:122` grades it — both sides are in this repo |

## 3. Verification

Run 2026-11-05 in worktree `proj-wt-md-28e` at `dad2749`, Python 3.14.4, git 2.53.0. The generator has **no output flag** [scripts/master_doc_skeleton.py:15], so every run below used a copy of the file whose single `OUT` constant was repointed at `$TMPDIR`; nothing else in the copy differs. `$W` is `~/.hermes/cache/scratch/md32/md24`, `$S` is `scripts/master_doc_skeleton.py`.

| # | Check | Command | Expected | Last run | Result |
|---|---|---|---|---|---|
| 1 | The gate itself | `python3 scripts/master_doc_check.py docs/master --only 24- --strict` [scripts/master_doc_check.py:110-144] | `MASTER-DOC: PASS`, exit 0 | 2026-11-05 | **PASS** |
| 2 | The generator runs | `python3 run_skeleton.py` (`OUT` → `$W/A`) | exit 0, one JSON line, nothing on stderr | 2026-11-05 | **PASS** — `{"modules": 40, "out": "…/A", "red_fields": 160}`, stderr 0 bytes, 0.79 s real |
| 3 | Determinism | two runs into `A/` and `B/`, then `diff -r A B` | byte-identical | 2026-11-05 | **PASS** — 41 files, no difference; every collection is sorted [scripts/master_doc_skeleton.py:50] [scripts/master_doc_skeleton.py:71-90] |
| 4 | Template still matches the gate **and** the shipped set | probe: headings of a fresh generation vs `REQUIRED_SECTIONS` vs all 40 documents [scripts/master_doc_check.py:21-30] | same eight headings, same order, everywhere | 2026-11-05 | **PASS** — `TEMPLATE-MATCH: PASS`, 8/8 headings, 40/40 documents |
| 5 | Template vs shipped **membership** | `diff` of the generated index against the shipped one [docs/master/00-INDEX.md:8] | same 40 modules at the same numbers | 2026-11-05 | **FAIL** — 21 of 40 numbers moved, 4 spec modules dropped, 4 scripts entered (table in §8) |
| 6 | What it does to a document that already exists | sentinel text at the exact generated filename, then run | preserved, if it skips | 2026-11-05 | **FAIL** — sentinel destroyed, no backup, no warning: `fn.write_text(...)` is unconditional [scripts/master_doc_skeleton.py:220] |
| 7 | What it does to the file it no longer generates | sentinel at the old number `24-…`, then run | removed or reported | 2026-11-05 | **FAIL** — untouched; the run leaves two files for the same module (`24-…` stale, `28-…` fresh). Nothing in the file deletes or reports: no `unlink`, no `rmtree`, no `rename` |
| 8 | `git` absent | `PATH=$W/emptybin python3 run_skeleton.py` | a named failure | 2026-11-05 | **FAIL-OPEN** — every `Revision` row becomes `unknown`, exit 0, stderr 0 bytes [scripts/master_doc_skeleton.py:41-43] |
| 9 | One `REPOS` path missing | `REPOS` reduced to code-factory plus a nonexistent `/nonexistent/crier` | fewer modules, named | 2026-11-05 | **FAIL-OPEN** — summary still `"modules": 40`, exit 0, stderr 0 bytes; the loss is unobservable because the count is taken *after* truncation [scripts/master_doc_skeleton.py:212] [scripts/master_doc_skeleton.py:226] |
| 10 | An unreadable source file mid-run | `chmod 000` one fixture `scripts/locked.py` | abort before writing anything | 2026-11-05 | **PARTIAL** — `PermissionError` traceback, exit 1, documents 01 and 02 already written, `00-INDEX.md` absent (written last, [scripts/master_doc_skeleton.py:233]) |
| 11 | `OUT` is a regular file | `mkdir` onto an existing file | crash before any write | 2026-11-05 | **PASS** — `FileExistsError`, nothing written [scripts/master_doc_skeleton.py:197] |
| 12 | argv is ignored | `sys.argv = [prog, "--help"]`, then `main()` | writes anyway | 2026-11-05 | **CONFIRMED** — 41 files written, exit 0; no `argparse`, `sys` or `argv` token in the file |
| 13 | The real truncation cost | enumerate `modules_for()` over the four `REPOS` | 40 chosen, from the whole tree | 2026-11-05 | 1363 discovered — code-factory 51, coding-herms-scheduler 302, crier 1006, crier-fleet 4 — **1323 dropped**, and all 40 survivors are code-factory, so no other repository appears at all |
| 14 | Lint and format | `ruff check` / `ruff format --check` on `$S` | clean | 2026-11-05 | **PASS** — `All checks passed!`, `1 file already formatted` |
| 15 | Is the generator itself tested? | `grep -n master_doc_skeleton tests/selftest.sh` | a section that can go red | 2026-11-05 | **FAIL** — one comment line [tests/selftest.sh:3500]; the fill runner has section 52 [tests/selftest.sh:3536], the generator that creates its input has none |

```
$ python3 scripts/master_doc_check.py docs/master --only 24- --strict
24-scripts-master-doc-skeleton-py.md           VERIFIED   ok

1 module(s): 1 VERIFIED, 0 error(s), 0 warning(s), 10 fact(s) in the ledger
MASTER-DOC: PASS

$ python3 $W/probe_template.py $W/A docs/master .
  PASS  template emits 8 ## sections (want 8): Purpose and why it matters | Dependencies and library contracts |
        Verification | Metrics emitted | Log lines it can generate | Failure modes |
        Environment and settings it reads | Evidence of record
  PASS  template headings equal the checker's REQUIRED_SECTIONS, in the same order
  PASS  checker requires 8 sections
  PASS  40 shipped documents carry the template's 8 headings in order

TEMPLATE-MATCH: PASS
```

## 4. Metrics emitted

The only number this module ever states is the one-line summary at the end of a run: `{"modules": 40, "out": "<dir>", "red_fields": 160}` [scripts/master_doc_skeleton.py:234-238]. It is not a measurement of the document set:

- `modules` is `len(entries)` taken **after** the slice to 40 [scripts/master_doc_skeleton.py:212] [scripts/master_doc_skeleton.py:226], so it prints 40 whether the tree holds 41 components or 1363 — measured on both a healthy run and a run with a repository deleted (§3 rows 2 and 9).
- `red_fields` is arithmetic, not a count: `len(entries) * 4` [scripts/master_doc_skeleton.py:236]. It printed 160 for 40 modules and 12 for a 3-module fixture; it would stay 4-per-module even if every field were filled.
- The index's `## Counts` block is three literal zeros plus one real number [docs/master/00-INDEX.md:51-56] against the generator's literals [scripts/master_doc_skeleton.py:227-229]. The shipped artifact proves the failure: line 52 says `0` modules have a verification command while line 10 of the same file marks a row `VERIFIED`.
- Nothing counts what was dropped, how many repositories contributed, how long the run took, or how many documents were overwritten. There is no timing, no per-module line, no exit-code distinction [scripts/master_doc_skeleton.py:241-242].

Direction: every number here is *generative* (what the run intended to write), never *observational* (what the tree contained). That is why §6's silent failures are undetectable from the output.

## 5. Log lines it can generate

Exactly one line is printed on a healthy run — there is no `logging` import and no `sys.stderr` write anywhere in the file. The template it produces also contains a log table for each module, and the rows in it are labelled for you: `descriptive (**unverified as evidence**)` [scripts/master_doc_skeleton.py:170].

| Level | Line (verbatim) | Emitted when | Kind |
|---|---|---|---|
| stdout | `{"modules": 40, "out": "~/.hermes/cache/scratch/md32/md24/A", "red_fields": 160}` | last statement of every successful `main()` [scripts/master_doc_skeleton.py:234-238]; the `out` field is whatever `OUT` is [scripts/master_doc_skeleton.py:15] | **evidentiary** — the only machine-readable statement of what was written, and the only way to see that the run happened at all |
| stderr | `PermissionError: [Errno 13] Permission denied: '…/fx2/scripts/locked.py'` | a source file cannot be read at [scripts/master_doc_skeleton.py:70]; the whole run aborts | **evidentiary** — names the exact file; the documents already written stay written (§3 row 10) |
| stderr | `FileExistsError: [Errno 17] File exists: '…/out_is_file'` | `OUT` exists as a file, at [scripts/master_doc_skeleton.py:197] | **evidentiary** — fires before anything is written |
| stdout (template) | a row whose middle column holds the placeholder token at [scripts/master_doc_skeleton.py:170], and whose last column is `descriptive (**unverified as evidence**)` | for every quoted string of 12–90 characters that follows `log`/`print`/`echo`/`info`/`warn`/`error` in a scanned module [scripts/master_doc_skeleton.py:80-87] [scripts/master_doc_skeleton.py:165-171] | **descriptive** — the template's own words: a captured string is not evidence that the line is ever emitted |

There is no progress line and no per-module line, so a run that replaces 19 filled documents looks exactly like one that writes 40 fresh ones: a single JSON line and exit 0. The absence of a "wrote N, overwrote M, dropped K" line is the single largest observability gap in this component.

## 6. Failure modes

Direction means *which way the error goes*: fail-open (a wrong answer presented as a right one), fail-closed (a refusal), or loud-but-partial (a crash after some writes).

| Failure | Presents as | Distinguished from | Direction | Recovery |
|---|---|---|---|---|
| The tree grows past 40 components | nothing; the run is green | a tree with fewer components, because `modules` still prints 40 [scripts/master_doc_skeleton.py:226] | **fail-open** — 1323 of 1363 components are dropped with no line, no warning and no exit code [scripts/master_doc_skeleton.py:212] | raise the cap or make it a named setting; until then read `00-INDEX.md` and notice which repositories are missing |
| A component is added earlier in the sort order | every following document is renumbered | a stable set, where re-running is a no-op | **fail-open** — filenames are `"%02d-%s.md" % (i, slug)` [scripts/master_doc_skeleton.py:216-219], so one new script changed what 21 of the 40 numbers point at (§8) | never trust the number as an identity; the title is the identity, and only the title |
| A document at an unchanged number gets regenerated | the filled document is replaced by a RED skeleton | a skip, which does not exist | **destructive** — `fn.write_text(...)` with no existence test, no backup, no diff [scripts/master_doc_skeleton.py:220]; measured on a sentinel (§3 row 6) | run it only against a scratch `OUT`; there is no flag, so edit a copy [scripts/master_doc_skeleton.py:15] |
| A document is left at a number the tool no longer generates | two files describe one module; the old one never changes again | a complete regeneration, which would leave one | **silent duplication** — nothing deletes, nothing reports: no `unlink`/`rmtree`/`rename` in the file | delete the orphans by title, not by number |
| `git` is missing, or `rev-parse` is slow or failing | the Revision row reads `unknown` on every document | a real short hash — the two are distinguishable only by knowing `unknown` cannot be a hash | **fail-open** — 20 s timeout, every exception swallowed [scripts/master_doc_skeleton.py:40-43]; exit stays 0 | read the Revision row before trusting any locator in a document |
| A directory in `REPOS` is renamed or unmounted | that repository contributes nothing | a repository with no matching file types | **fail-open** — `rglob` on a missing directory yields nothing and raises nothing [scripts/master_doc_skeleton.py:50]; the summary cannot show it [scripts/master_doc_skeleton.py:226] | assert the four repositories exist and that each contributed before writing |
| A source file is unreadable or the disk fills mid-run | traceback, exit 1, documents numbered before the failure already on disk, `00-INDEX.md` missing | a clean abort, which would leave nothing | **loud but partial** — writes are per file and unordered with respect to the index, which is written last [scripts/master_doc_skeleton.py:233]; `write_text` is not atomic [scripts/master_doc_skeleton.py:220] | re-run after fixing; then check the highest number present, since a truncated file has no marker |
| A call is written across several lines | the template asserts *none identified mechanically* — the cell reads `**RED: none identified mechanically**` — for a module that does have a dependency | a module with genuinely none | **under-claim** — the regex requires the quoted token on the same logical run as `subprocess.run(` [scripts/master_doc_skeleton.py:88-90], so *this* module's `git` call is not detected (§2a) | the RED is honest as a placeholder but false as a statement; never read it as "no dependency" |
| A module mentions an upper-case prefix token | the template lists it as an environment variable [scripts/master_doc_skeleton.py:189] | a module that really reads `os.environ` | **over-claim** — the detector matches the filter's own literals, so this file's generated §7 lists five variables it never reads [scripts/master_doc_skeleton.py:74-79] | grep the module for `environ`/`getenv` before believing §7 |
| The eight headings are edited in the template | the gate keeps passing, because it only checks that its own eight strings are present [scripts/master_doc_check.py:57-61] | a gate that reads the template | **fail-open across components** — the two lists are transcriptions [scripts/master_doc_check.py:21-30] and the checker never opens `scripts/master_doc_skeleton.py` [scripts/master_doc_check.py:18-20] | the probe in §3 row 4 is the only thing that compares them; run it after any template edit |

## 7. Environment and settings it reads

**No environment variable is read.** Measured: `grep -n 'environ\|getenv' scripts/master_doc_skeleton.py` returns nothing, and the file imports neither `os` nor `sys` [scripts/master_doc_skeleton.py:10-13]. What it does have is four hardcoded settings, none overridable by any means:

| Setting | Value | Consequence if wrong |
|---|---|---|
| `OUT` [scripts/master_doc_skeleton.py:15] | `~/code-factory/docs/master` | writes into the shipped document set; the only way to redirect it is to edit the line (§3 preamble) |
| `REPOS` [scripts/master_doc_skeleton.py:16-24] | four absolute paths, one of them misspelt in its display name (`coding-herms-scheduler`) | a moved tree silently contributes zero components (§6) |
| `PROXY` [scripts/master_doc_skeleton.py:25] | `~/.hermes/scripts/cf-inference-proxy.py`, appended after every repository component [scripts/master_doc_skeleton.py:211] | it is **never reached** while 40 or more components exist, because the slice happens after the append [scripts/master_doc_skeleton.py:212]; measured: `cf-inference-proxy` appears 0 times in a fresh `00-INDEX.md` |
| `SKIP` [scripts/master_doc_skeleton.py:27-29] | ten excluded directory names, no `.worktrees` | worktree copies of a repository are counted as components — measured: crier's first component is `go:.worktrees/crfeat036-worker-20261015/internal/a2a/card.go` |

The one table in a generated document that looks like this section is unreliable by construction: the detector collects every upper-case token of four characters or more that starts with `CF_`, `HERMES_`, `CRIER_`, `DISPATCH_`, `API_` or `GITREINS_` [scripts/master_doc_skeleton.py:74-79] and prints one row per hit [scripts/master_doc_skeleton.py:185-191]. Because those six prefixes are themselves literals in the file, this module's own generated §7 lists `API_`, `CRIER_`, `DISPATCH_`, `GITREINS_` and `HERMES_` as variables — five rows, all false, each with `unknown` as its default. The detector finds the filter, not the environment.

## 8. Evidence of record

All runs 2026-11-05, worktree `proj-wt-md-28e` at `dad2749`, `$W=~/.hermes/cache/scratch/md32/md24`, generator copied to `$W/run_skeleton.py` with only `OUT` repointed (line 15) — the file itself is byte-identical to the shipped one (`cmp` clean).

1. **Generation**: `python3 run_skeleton.py` → `{"modules": 40, "out": "…/A", "red_fields": 160}`, exit 0, stderr 0 bytes, 0.79 s. 41 files (40 documents + index). Ran a second time into `B/`; `diff -r A B` empty (§3 row 3).
2. **Template vs gate vs shipped set**: `python3 $W/probe_template.py $W/A docs/master .` → `TEMPLATE-MATCH: PASS`. The eight headings, in order, are identical in the fresh generation, in `REQUIRED_SECTIONS` [scripts/master_doc_check.py:21-30] and in all 40 shipped documents. **The template shape has not drifted.**
3. **Template vs shipped membership — the drift that did happen**: 21 of 40 numbers moved, and the movement is not cosmetic:

| Effect | Count | Detail |
|---|---|---|
| Modules at the same number but a different name | 21 | from number 20 on; e.g. `20` was `scripts/land-node-branch.sh`, is now `scripts/install-go.sh` |
| Modules that moved number | 17 | `scripts/master_doc_skeleton.py` itself: **24 → 28** |
| Shipped modules that fall out of the set entirely | 4 | `specs/ENVELOPE.md`, `specs/HARNESS-MATRIX.md`, `specs/HARNESS.md`, `specs/NODE.md` |
| Modules that enter | 4 | `scripts/install-go.sh`, `scripts/master_doc_check.py`, `scripts/master_doc_fill.py`, `scripts/master_doc_panel.py` |
| Filenames that a regeneration would overwrite | 19 | documents 01–19, all filled, replaced by RED skeletons [scripts/master_doc_skeleton.py:220] |
| Filenames that would be orphaned | 21 | every shipped module the run no longer generates, including this one at `24-…`; a second, RED, `28-scripts-master-doc-skeleton-py.md` would appear beside it |

   The cause is mechanical and permanent: components are collected per repository in sorted order [scripts/master_doc_skeleton.py:50] [scripts/master_doc_skeleton.py:208-210] and numbered by position [scripts/master_doc_skeleton.py:213], so the document number is a function of the tree, not of the module. Four new scripts in code-factory pushed the four spec documents past the 40-entry cut [scripts/master_doc_skeleton.py:212].
4. **Overwrite and orphan probes**: sentinel text destroyed at the exact generated name; sentinel at `24-…` untouched, leaving both `24-scripts-master-doc-skeleton-py.md` and `28-scripts-master-doc-skeleton-py.md` in one output directory (§3 rows 6–7).
5. **Failure directions**: `PATH` emptied → every `Revision` row `unknown`, exit 0; a deleted `REPOS` entry → still `"modules": 40`, exit 0; `chmod 000` → `PermissionError`, 2 of 3 documents written, no index; `OUT` as a file → `FileExistsError`, nothing written (§3 rows 8–11).
6. **Truncation measured, not inferred**: 1363 components across the four trees, 40 written, 1323 dropped, all four surviving repositories = code-factory (§3 row 13).
7. **Not verified, and why it stays out of the text above**: whether the numbering shift has ever silently overwritten a filled document in a real run. No `.git` history, no backup and no log records a regeneration, and nothing in the repo writes a receipt for one — so the claim cannot be settled from this host, and it appears here as a measurement of *behaviour*, not as an accusation of *history*.
