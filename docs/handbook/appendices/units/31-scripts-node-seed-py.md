# 31. scripts/node_seed.py

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/node_seed.py` — 276 lines, stdlib only [scripts/node_seed.py:1] |
| Repository | `code-factory` |
| Revision | `d8c7796` — the `origin/main` tip every locator below was measured against; the file's own last-touching commit is `b3ed55c` (2026-11-04, "feat(seed): a node receives its procedure and skills, digest-recorded, or nothing (CF-220)") |
| Status | **VERIFIED — 177 locator citations (107 distinct file:line pairs across 6 files), all resolve; cites fact: FACT-01, FACT-02; 22 measured arms in §3; ten defects recorded in §8** |

## 1. Purpose and why it matters

- What it is: the **seeder for a node's procedure**. Three verbs and three audiences: `build` on
  the control host turns a declared manifest into a tarball plus a per-file sha256 record
  [scripts/node_seed.py:10-12]; `apply` on the node verifies every digest *before* installing
  anything, then writes what was applied and when [scripts/node_seed.py:13-15]; `check` compares
  the node on disk against a record and names the path that differs [scripts/node_seed.py:16-17].
  Exit codes are fixed as `0 done, 1 refused/drifted, 2 usage` [scripts/node_seed.py:23], and the
  three are the only exits the code produces [scripts/node_seed.py:266-272].
- Why it matters: the foreman runs on the node, never on the control host (fact: FACT-01), and one
  bunker serves one project so every lane of that project enters it (fact: FACT-02). A node with a
  harness and no procedure is the failure this closes: the docstring says the node "had a harness
  with nothing to run" [scripts/node_seed.py:4-6].

### 1a. What a node is seeded WITH — the inventory, by source

- The manifest is `config/node-seed.txt`, a 13-line file whose four lines of declarations are
  `prompts/*.md`, `skills/**/*.md`, `skills/**/*.sh`, `skills/**/*.py`
  [config/node-seed.txt:10-13]. Every line is relative to the repo root; a file not named there is
  not seeded [config/node-seed.txt:3-5]. The exclusion is *not* a filter: backup tarballs, wave
  logs, the user's full skill library and everything under `.coding-hermes/` are absent because
  they are not declared [config/node-seed.txt:7-8] [scripts/node_seed.py:19-21].
- **Measured payload: 13 files, 41,211 bytes** — 11 prompt files from `prompts/` and 2 skill files
  from `skills/`, both named `SKILL.md` (`code-factory-bunker`, `code-factory-foreman`). The two
  skills are 26,260 of the 41,211 bytes (63.7%); `prompts/foreman.md` is 3,413 bytes. The full
  per-file list with digests is §8.

| Declared glob | Matched today | What it contributes |
|---|---|---|
| `prompts/*.md` [config/node-seed.txt:10] | 11 files | docs, dogfood, duckbrain, foreman, perf, pm, qa, readme, releng, review, sync |
| `skills/**/*.md` [config/node-seed.txt:11] | 2 files | `skills/code-factory-bunker/SKILL.md`, `skills/code-factory-foreman/SKILL.md` |
| `skills/**/*.sh` [config/node-seed.txt:12] | **0** | today's skills ship no script; an empty glob is a note, not a refusal [scripts/node_seed.py:86-90] |
| `skills/**/*.py` [config/node-seed.txt:13] | **0** | same |

- **No config is seeded.** `config/node-seed.txt` is the declaration, not a payload: it is not named
  in itself, so the node receives no copy of the list it was built from. What lands is
  `$HOME/.hermes/prompts/`, `$HOME/.hermes/skills/` and one record file
  [scripts/node_seed.py:198-205] [scripts/node_seed.py:211], measured as a 14-entry tree (§3 row 2).
- The destination is fixed by two joins against `--home` [scripts/node_seed.py:164-166]; nothing in
  this repository reads `~/.hermes/prompts` or `~/.hermes/skills` back. The only in-repo readers are
  this script's own `check` and `scripts/node_seed_drift.py`, and both compare digests rather than
  consume the procedure [scripts/node_seed_drift.py:166].

### 1b. Overwrite or preserve: the seed wins, silently and in one direction

- `apply` replaces the two trees **as directories**: an existing `$HOME/.hermes/prompts` or
  `skills` is `rmtree`d and then `copytree`d from staging [scripts/node_seed.py:203-205]. There is
  no per-file merge, no timestamp comparison, no backup, and no candidate for a conflict.
- Measured (row 5): a prompt edited on the node and two hand-written files were present before a
  re-apply; after it the edit was gone (digest back to the recorded `82c020b6f316`), both
  hand-written files were **deleted**, and the run printed four `PASS` rows and nothing else. The
  seed wins unconditionally — including over a node's deliberate local tuning.
- The only warning is *before* the overwrite, and only if someone runs `check` first: `check`
  reported `prompts/foreman.md drifted` with exit 1 (row 5). After the
  re-apply the record is rewritten [scripts/node_seed.py:208-215], so the fact that anything was
  overwritten leaves no trace in the artifact that survives.
- The same directory replacement is what stops a deleted source file from becoming a ghost: a seed
  of one file over a tree of two left only the one, and `check` against the new record was green
  (row 20). That is the intended half of the same mechanism.

### 1c. What a partial seed leaves behind

- **Digest failure is clean.** A record whose first digest disagrees with the archive installs
  nothing: the loop counts mismatches and returns before the install block
  [scripts/node_seed.py:180-193]. Measured, the only thing left under the scratch HOME was an empty
  `.hermes/` directory, created before the staging step [scripts/node_seed.py:166] (row 6). Same for
  a declared file absent from the archive (row 7).
- **A mid-install failure is not clean, and it is half.** `prompts/` and `skills/` are two separate
  transactions in a fixed order [scripts/node_seed.py:198-206], and the completion marker is written
  *after* both [scripts/node_seed.py:211]. Measured two shapes:
  - `$HOME/.hermes/skills` existing as a regular file: `prompts/` was replaced (11 files, the stale
    one gone), `skills/` was never installed, no record was written, and the run died with a
    `FileExistsError` traceback and exit 1 (row 8).
  - a re-apply against a `.hermes` that cannot be relinked (mode 500): `prompts/` was **emptied** —
    its files deleted, the directory itself un-removable — while `skills/` survived untouched and
    the *previous* `seed-applied.json` survived still claiming 13 files. Exit 1, traceback, no row
    (row 9).
- That second shape is the one that matters: **the presence of a record does not prove this run
  completed**, because a failed run leaves the last successful run's marker in place. A node in that
  state looks provisioned to `ls` (a record exists, a skills tree exists) and is in fact holding two
  of thirteen files. `check` does catch it when it is run — `11 of 13 seeded files differ` (row 9) —
  but nothing in `apply` emits that verdict, and the caller prints no rows at all (§8 defect 8).
- The staging directory is the one thing that never leaks: it is created inside `$HOME`
  [scripts/node_seed.py:170] and removed in a `finally` [scripts/node_seed.py:217-218]. Measured 0
  residue after every failure above, tracebacks included.

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `python3`, **stdlib only** | measured on 3.14.4; no third-party import appears in the file [scripts/node_seed.py:26-36] | control host for `build`/`check`, the node for `apply` [scripts/bunker-provision.sh:460] | not probed. On the node an absent `python3` surfaces as the caller's `bad node_seed "apply exited 127 on the node — rows above"` [scripts/bunker-provision.sh:464] |
| the manifest | `config/node-seed.txt`, 13 lines | resolved against `--repo-root` [scripts/node_seed.py:81] | fail-closed twice over: the caller will not run without the file [scripts/bunker-provision.sh:451], and a literal entry missing at build time raises `REFUSED: manifest entry missing: <entry>` on stderr with exit 1 [scripts/node_seed.py:93-94] |
| a writable `$HOME` on the node | any free space; the payload is 41,211 bytes | `$HOME/.hermes` [scripts/node_seed.py:166] and a staging dir *inside* `$HOME` [scripts/node_seed.py:170] | uncaught `PermissionError`/`OSError` traceback, exit 1 — no row |
| `tarfile` extract filter | CPython's default; measured `data` on 3.14.4 | the interpreter running `apply` [scripts/node_seed.py:178] | see §2b: the seeder passes no `filter=` of its own |

### 2b. Library contracts

Eleven imports, all stdlib [scripts/node_seed.py:26-36]. Each row names the property this code
actually leans on, because most of them are one default away from a different behaviour.

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `__future__.annotations` | stdlib | `list[str]` and `dict` annotations need no runtime evaluation [scripts/node_seed.py:26] | the file stops parsing before Python 3.7 |
| `argparse` | stdlib | three required subparsers; misuse exits **2** with a usage line [scripts/node_seed.py:246-247] [scripts/node_seed.py:265] | measured: no subcommand → exit 2; `bogus` → exit 2 (row 18) |
| `glob` (`recursive=True`) | stdlib | `**` matches zero **or more** directories, which is why `skills/**/*.md` matches a `SKILL.md` one level down [scripts/node_seed.py:77-83] | without recursion the manifest's skill lines match nothing and the seed silently ships 11 files instead of 13 — the empty-glob path is a note, not a refusal [scripts/node_seed.py:89-90] |
| `hashlib` | stdlib | `sha256`, read in 64 KiB chunks, hex digest of 64 chars [scripts/node_seed.py:58-63] | the comparison at [scripts/node_seed.py:188] becomes meaningless; the record's `sha256` field is also read by `node_seed_drift.py` |
| `json` | stdlib | `dump(indent=2, sort_keys=True)` for both the record and the applied record; `load` of a record this script wrote [scripts/node_seed.py:147-149] [scripts/node_seed.py:157-159] | a non-JSON record is an uncaught traceback, exit 1 (row 18) |
| `os` | stdlib | `path.realpath` as the traversal test [scripts/node_seed.py:174-175], `path.relpath` for record paths [scripts/node_seed.py:119], `os.walk` for the install count [scripts/node_seed.py:206] | realpath is what makes symlinked repo paths and symlinked staging paths compare correctly; a plain `abspath` would accept a linking escape |
| `shutil` | stdlib | `rmtree` on the destination, `copytree(src, dst)` which **requires dst to be absent** [scripts/node_seed.py:203-205]; `rmtree(..., ignore_errors=True)` in the cleanup [scripts/node_seed.py:218] | measured: a *file* where a directory is expected kills the run after `prompts/` was already replaced (row 8) — the two statements are not atomic |
| `sys` | stdlib | `sys.exit(main(...))` carries the verb's return code [scripts/node_seed.py:276] | the caller reads only the exit code and a `PASS` count [scripts/bunker-provision.sh:462-464] |
| `tarfile` | stdlib | `w:gz` to build, `r:gz` + `extractall(staging)` to unpack [scripts/node_seed.py:135-137] [scripts/node_seed.py:172-178] | **no `filter=` is passed**, so the extraction policy is whatever the interpreter defaults to. Measured on 3.14.4 the `data` filter refused an absolute symlink with `tarfile.AbsoluteLinkError` and exit 1 (row 13); the seeder's own traversal test compares `realpath` *before* extraction, so it cannot see a link that does not exist yet [scripts/node_seed.py:172-177] |
| `tempfile` | stdlib | `mkdtemp(prefix="node-seed-", dir=home)` — deliberately inside `$HOME`, not the system temp [scripts/node_seed.py:170] | a full or read-only `$HOME` fails before any verification |
| `time` | stdlib | `strftime("%Y-%m-%dT%H:%M:%SZ", gmtime())` for `built_at` and `applied_at` [scripts/node_seed.py:140] [scripts/node_seed.py:209] | timestamps are UTC independent of `TZ`; a local-time rewrite would silently move the record's only clock |

### 2c. Service contracts (both sides named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| `build` → the caller's staging dir | control host, local process | `python3 node_seed.py build --manifest … --repo-root … --out …` [scripts/bunker-provision.sh:454-455] | the repo root, the manifest path, an output path; returns the tarball and `<out>.json` | this script's `build` [scripts/node_seed.py:109-154]. The caller discards stdout into `build.log` and reads only the exit code [scripts/bunker-provision.sh:455] [scripts/bunker-provision.sh:472-473] |
| the caller → the node | control host → node, three `bunker cp` | tarball, record and the script itself, each copied to `$HOME` on the node [scripts/bunker-provision.sh:458-459] | `seed.tar`, `seed.tar.json`, `node_seed.py` | nothing verifies these three transfers; the next row's digests are the only check, and they cover the *tarball's contents*, not the tarball |
| `apply` on the node | node-local | `python3 $HOME/node_seed.py apply --tar $HOME/seed.tar --record $HOME/seed.tar.json --home $HOME` [scripts/bunker-provision.sh:460] | the two paths and the home to install into | this script's `apply` [scripts/node_seed.py:162-218]. The caller keeps stdout, counts `  PASS  ` rows for its success line [scripts/bunker-provision.sh:462], and on failure prints only the exit code [scripts/bunker-provision.sh:464] |
| the node's `~/.hermes/seed-applied.json` → `check` | node-local, record → verifier | `python3 node_seed.py check --record $HOME/.hermes/seed-applied.json --home $HOME` | record path + home | this script's `check` [scripts/node_seed.py:221-242]. The record is written here [scripts/node_seed.py:211] and is the same path `node_seed_drift.py` defaults to [scripts/node_seed_drift.py:64] |
| `verify-node.sh` → `node_seed_drift.py` → `check` | control host → node, one `bunker exec` | `node_seed_drift.py --agent … --server …`; the wrapper stages the seeder and runs `check` on the node [scripts/node_seed_drift.py:320-329] | agent, server, `--strict-seed` | **`check`'s row text is a machine contract**: the wrapper parses `  PASS  seed_check — N files present and matching` and the `FAIL` rows into `count`, `drifted`, `absent` [scripts/node_seed_drift.py:166] [scripts/node_seed_drift.py:340-345]. Changing the wording silently degrades the drift leg to "unmeasurable" |
| that leg → `verify-node.sh`'s verdict | in-process | exit code 0/1/other | PASS, drift, unmeasurable | 0 → `ok seed_drift`; 1 → `bad seed_drift`; anything else → `warn`, or `bad` under `--strict-seed` [scripts/verify-node.sh:171] [scripts/verify-node.sh:177-183]. "Cannot measure" is not a failure by default |
| any network peer | **none** | — | — | no socket, no HTTP, no crier and no board access anywhere in the file; the only inputs are argv and the files those name [scripts/node_seed.py:245-272] |

## 3. Verification

Twenty-two arms, all run 2026-11-05 in a fresh worktree of `d8c7796` with Python 3.14.4, every one
against scratch directories under `/home/kara/.hermes/cache/scratch/md31`. **No node was touched**
and no repository file was modified by any probe (`git status --short` empty after the suite run).
Rows 1-10 and 20-21 build from the real manifest and the real archive; rows 11-16 differ only in
the archive, the record or the node tree they hand to the same code; rows 17-19 are the refusal
and edge-case arms.

| # | Check | Command | Expected | Result |
|---|---|---|---|---|
| 1 | build the declared seed | `python3 -B scripts/node_seed.py build --manifest config/node-seed.txt --repo-root . --out seed.tar` | 13 files, under the ceiling, exit 0 | **PASS** — `13 files declared, 41211 bytes (ceiling 16777216)`, exit 0 |
| 2 | apply into an empty HOME | `… apply --tar seed.tar --record seed.tar.json --home home1` | digest row, two install rows, a record, exit 0 | **PASS** — 11 prompts + 2 skills on disk, `seed-applied.json` written, exit 0 |
| 3 | check after apply | `… check --record seed.tar.json --home home1` | `13 files present and matching`, exit 0 | **PASS** |
| 4 | idempotence: apply a second time | same command as row 2, same HOME | identical tree, identical record body, exit 0 | **PASS** — 14 entries on disk both times, record body byte-identical, `check` green after |
| 5 | a locally modified target, then a re-apply | append a line to `home1/.hermes/prompts/foreman.md`, add two hand-written files, `check`, then re-apply | `check` names the drifted file; the re-apply decides the winner | **PASS** — `FAIL seed_check — prompts/foreman.md drifted (c0f9b08d7aec != 82c020b6f316)` exit 1; after the re-apply the digest is `82c020b6f316` again, both hand-written files deleted, `grep -c` of the edit `0`, `check` green |
| 6 | a record whose digest disagrees | rewrite one sha256 to zeros in a copy of the record, apply to a fresh HOME | refuse the whole seed, install nothing, exit 1 | **PASS** — `prompts/docs.md digest 5d093e26d190 != recorded 000000000000`, `1 file(s) failed the digest check — nothing installed`, exit 1, only an empty `.hermes/` left, 0 staging residue |
| 7 | an archive missing one declared file | rebuild the tarball without `prompts/qa.md` | refuse, install nothing | **PASS** — `prompts/qa.md missing from the archive`, exit 1, nothing installed |
| 8 | a mid-install failure: `skills` is a file | `printf x > home3/.hermes/skills`, then apply | a loud failure, and the tree says what landed | **PASS (as a defect, §8.4)** — `FileExistsError: …/home3/.hermes/skills` traceback, exit 1, prompts replaced (11, stale one gone), no record |
| 9 | a mid-install failure on a re-apply | apply once, `chmod 500 .hermes`, apply again | refuse; state after is what matters | **PASS (as a defect, §8.4)** — `PermissionError: …/home4/.hermes/prompts` traceback, exit 1, prompts emptied (0 files), skills intact (2), the *old* record still claims 13 |
| 10 | re-apply over a tree with extra files | add `prompts/local-only.md` and a whole extra skill, then apply | the extra files should not survive a declared seed | **PASS** — both deleted; the replaced directory is the mechanism [scripts/node_seed.py:203-205] |
| 11 | a `../` member in the archive | hand-built tarball with `../escaped.txt` | named refusal, no write outside staging | **PASS** — `FAIL seed_extract — refusing path traversal in archive: ../escaped.txt`, exit 1, nothing escaped |
| 12 | an absolute member | hand-built tarball with `/tmp/md31-absolute-escaped.txt` | same refusal | **PASS** — `refusing path traversal in archive: /tmp/…`, exit 1, no file created |
| 13 | an absolute symlink member + a file through it | hand-built tarball: `link` → absolute path, then `link/through.txt` | no write outside staging | **PASS, but not by this code** — `tarfile.AbsoluteLinkError: 'link' is a link to an absolute path`, exit 1. The refusal comes from CPython's default `data` filter; `extractall` is called with no `filter=` [scripts/node_seed.py:178] (§8.5) |
| 14 | an extra member that the record does not declare | record files + `prompts/smuggled.md` in the tarball | the record should bound what installs | **FAILS** — exit 0, `smuggled.md` installed (§8.1) |
| 15 | extra files already on the node | add `prompts/extra-runbook.md` and `skills/extra/SKILL.md`, then `check` | drift should be reported | **FAILS** — `PASS seed_check — 13 files present and matching`, exit 0, with 12 prompts and 3 skills on disk (§8.2) |
| 16 | the node rewrites its own digest | edit `prompts/foreman.md`, then rewrite that entry in `~/.hermes/seed-applied.json`, then `check` against it | the record should not be self-certifying | **FAILS** — `check` reported the drift (exit 1) before the rewrite and `PASS` (exit 0) after (§8.2) |
| 17 | a declared path outside `prompts/` and `skills/` | mini repo: manifest `prompts/a.md` + `config/note.txt` | build and apply should agree on the set | **FAILS** — build exit 0 (2 files), apply exit 0 (`all 2 files match the record`), `config/note.txt` never installed, `check` then fails on it forever (§8.3) |
| 18 | usage and missing inputs | no subcommand; `bogus`; a missing `--tar`; a missing `--record` | 2 for usage, a clean refusal for a missing input | **PARTIAL** — exit 2, exit 2, then two uncaught tracebacks (`FileNotFoundError`) with exit 1 (§8.6) |
| 19 | budget and backup rules | `--budget 100`; a manifest declaring `backups/board.tar.gz` with the file present, then absent; a manifest declaring a directory | four refusals | **PASS with one vacuous arm** — `exceeds the declared ceiling of 100` exit 1; `is a backup artefact and may not be seeded` exit 1 (file present); `REFUSED: manifest entry missing` exit 1 (file absent — this is what the suite's arm actually exercises); `is a directory — declare files, not trees` exit 1 (§8.7) |
| 20 | a seed of a subset leaves no ghost | seed `one.md`+`two.md`, then a manifest of `one.md` only | `two.md` must not survive | **PASS** — after `one`: only `one.md`; `check` against the one-file record green |
| 21 | the repository suite | `bash tests/selftest.sh` | `SELFTEST: PASS` | **PASS** — exit 0, six `node_seed` arms green (transcript 6) |
| 22 | a real node | `bunker exec … node_seed.py check --record $HOME/.hermes/seed-applied.json` | 13 files matching | **not re-run here**; the committed artifact records cf-node with `13 files present and matching` and one red arm on a one-line tamper [docs/audits/code-factory-cf220-2026-11-05.md:47-59] |

Transcript 1 (rows 1-3), literal:

```
$ python3 -B scripts/node_seed.py build --manifest config/node-seed.txt --repo-root . --out seed.tar
  ..    manifest glob matched nothing: skills/**/*.sh
  ..    manifest glob matched nothing: skills/**/*.py
  PASS  seed_manifest — 13 files declared, 41211 bytes (ceiling 16777216)
  PASS  seed_record — …/seed.tar.json (13 files, sha256 per file)
  ..    5d093e26d190  prompts/docs.md
  …
  ..    b9aac5166404  skills/code-factory-foreman/SKILL.md
EXIT=0
$ python3 -B scripts/node_seed.py apply --tar seed.tar --record seed.tar.json --home home1
  PASS  seed_digest — all 13 files match the record
  PASS  seed_install — prompts/ installed (11 files)
  PASS  seed_install — skills/ installed (2 files)
  PASS  seed_record — …/home1/.hermes/seed-applied.json written
EXIT=0
$ python3 -B scripts/node_seed.py check --record seed.tar.json --home home1
  PASS  seed_check — 13 files present and matching
EXIT=0
```

Transcript 2 (rows 4-5) — idempotence, then the local edit and the re-apply:

```
$ … apply … --home home1              # run 2, after run 1
  PASS  seed_digest — all 13 files match the record
  PASS  seed_install — prompts/ installed (11 files)
  PASS  seed_install — skills/ installed (2 files)
  PASS  seed_record — …/.hermes/seed-applied.json written
EXIT=0
files on disk=14, record files=13
record paths absent from disk: none
$ … check … --home home1
  PASS  seed_check — 13 files present and matching
CHECK_EXIT=0
$ sha256sum home1/.hermes/prompts/foreman.md     # after the local edit
c0f9b08d7aec
$ … check --record seed.tar.json --home home1
  FAIL  seed_check — prompts/foreman.md drifted (c0f9b08d7aec != 82c020b6f316)
  FAIL  seed_check — 1 of 13 seeded files differ from the record
EXIT=1
$ … apply --tar seed.tar --record seed.tar.json --home home1
  PASS  seed_digest — all 13 files match the record
  PASS  seed_install — prompts/ installed (11 files)
  PASS  seed_install — skills/ installed (2 files)
  PASS  seed_record — …/.hermes/seed-applied.json written
EXIT=0
$ sha256sum home1/.hermes/prompts/foreman.md     # after the re-apply
82c020b6f316
DELETED  …/home1/.hermes/prompts/local-only.md
DELETED  …/home1/.hermes/skills/local-skill/SKILL.md
0                                                # grep -c 'LOCAL EDIT'
$ … check …                                    # green again
  PASS  seed_check — 13 files present and matching
EXIT=0
```

Transcript 3 (rows 6-7) — refuse before installing:

```
$ … apply --tar seed.tar --record bad.json --home home2
  FAIL  seed_digest — prompts/docs.md digest 5d093e26d190 != recorded 000000000000
  FAIL  seed_apply — 1 file(s) failed the digest check — nothing installed
EXIT=1
--- tree left behind ---
…/home2
…/home2/.hermes
staging residue: 0
$ … apply --tar nogap.tar --record seed.tar.json --home home-gap       # prompts/qa.md absent
  FAIL  seed_digest — prompts/qa.md missing from the archive
  FAIL  seed_apply — 1 file(s) failed the digest check — nothing installed
EXIT=1
```

Transcript 4 (rows 8-9) — the two half-seeds, and what `check` makes of them:

```
$ … apply … --home home3                    # home3/.hermes/skills is a regular file
  File "…/shutil.py", line 552, in _copytree
    os.makedirs(dst, exist_ok=dirs_exist_ok)
FileExistsError: [Errno 17] File exists: '…/home3/.hermes/skills'
EXIT=1
prompts files: 11  (stale.md present: no)
skills is a file: yes
seed-applied.json present: no
staging residue: 0
$ … check --record seed.tar.json --home home3
  FAIL  seed_check — skills/code-factory-bunker/SKILL.md absent on the node
  FAIL  seed_check — skills/code-factory-foreman/SKILL.md absent on the node
  FAIL  seed_check — 2 of 13 seeded files differ from the record
EXIT=1

$ chmod 500 home4/.hermes; … apply … --home home4
  File "…/shutil.py", line 753, in _rmtree_safe_fd_step
    os.rmdir(name, dir_fd=dirfd)
PermissionError: [Errno 13] Permission denied: '…/home4/.hermes/prompts'
EXIT=1
prompts files: 0
skills  files: 2
seed-applied.json present: yes  (stale: says 13 files)
$ … check --record seed.tar.json --home home4
  FAIL  seed_check — 11 of 13 seeded files differ from the record
EXIT=1
```

Transcript 5 (rows 11-14) — the archive boundary:

```
$ … apply --tar traversal.tar …              # member ../escaped.txt
  FAIL  seed_extract — refusing path traversal in archive: ../escaped.txt
EXIT=1     escaped: no
$ … apply --tar absolute.tar …               # member /tmp/md31-absolute-escaped.txt
  FAIL  seed_extract — refusing path traversal in archive: /tmp/md31-absolute-escaped.txt
EXIT=1     escaped: no
$ … apply --tar symlink.tar …                # link -> absolute path, then link/through.txt
  File "…/tarfile.py", line …, in _get_filtered_attrs
    raise AbsoluteLinkError(member)
tarfile.AbsoluteLinkError: 'link' is a link to an absolute path
EXIT=1     escaped: no
$ … apply --tar extra.tar …                  # record files + prompts/smuggled.md
  PASS  seed_install — skills/ installed (2 files)
  PASS  seed_record — …/.hermes/seed-applied.json written
EXIT=0
smuggled.md installed: YES
```

Transcript 6 (row 21), the repository suite's own legs for this module, verbatim:

```
node_seed — the declared seed, its digests, and what it refuses
  PASS  build writes a record with a sha256 per declared file, exit 0
  PASS  apply installs prompts and skills and a green check follows (exit 0, 0)
  PASS  a tampered file fails the check and is named (exit 1)
  PASS  a digest mismatch refuses the whole seed and installs nothing (exit 1)
  PASS  a seed over the size budget is refused (exit 1)
  PASS  a backup artefact declared as seedable is refused (exit 1)
…
SELFTEST: PASS
```

The suite is a fixture of the same three verbs against a synthetic manifest
[tests/selftest.sh:3067-3147]: the mismatch arm rewrites one digest and demands an empty HOME
[tests/selftest.sh:3126], and the backup arm writes a manifest naming `backups/board.tar.gz` and
asserts only that the exit is non-zero [tests/selftest.sh:3139-3145] — which the missing-entry
refusal satisfies even when the guard it names never runs (§8.7).

## 4. Metrics emitted

**None.** The script emits no counter, no status line a machine could diff over time, and no exit
ledger. What it leaves is two JSON documents, both written once per invocation:

- the build record: `built_at`, `repo_root`, `manifest`, `total_bytes`, and `files[]` of
  `{path, sha256, bytes}` [scripts/node_seed.py:139-149];
- the applied record: the same body plus `applied_at` and `applied_to`
  [scripts/node_seed.py:208-214], written to `$HOME/.hermes/seed-applied.json`
  [scripts/node_seed.py:211]. Measured: 2,279 bytes for the 13-file seed; the live cf-node copy is
  2,251 bytes and reports `applied_at`, `applied_to` and 13 files
  [docs/audits/code-factory-cf220-2026-11-05.md:33-37].

So exactly three questions are answerable from a store: **what** a node was seeded with, **when**
(`applied_at`), and **whether it still matches** (the count and path from `check`). These are not:

| Question | Answerable? | Why |
|---|---|---|
| How often does a node get seeded? | no | `apply` keeps no history; `applied_at` is overwritten by the next run [scripts/node_seed.py:209-214] |
| How long does a seed take? | no | no start timestamp, no duration field |
| Did the last seed complete? | **not from the record** | the marker is written after both trees [scripts/node_seed.py:211], but a failed re-apply leaves the previous marker in place — measured as a record claiming 13 files over a node holding 2 (§3 row 9) |
| How much of the budget was used? | at build time only | `total_bytes` is recorded [scripts/node_seed.py:143] and `check` never re-reads sizes; the ceiling is a constant [scripts/node_seed.py:39] |
| Is this tarball the one that was built? | no | two builds of the same tree are not byte-identical (gzip mtime); the per-file digests are (§3 row 4 companion, measured: 13/13 digests equal, archive sha256 differs) |

One derived figure is worth stating because it is the seed's whole scale: **41,211 bytes of
16,777,216 — 0.25% of the declared ceiling**, 407× headroom, with one skill file (20,375 bytes)
half the payload. If the manifest grows to the ceiling, `build` refuses at that point and says the
arithmetic [scripts/node_seed.py:128-130].

## 5. Log lines it can generate

Every line is a `print` from one of four helpers — `say` (bare), `ok` (`  PASS  `), `bad`
(`  FAIL  `), `note` (`  ..    `) [scripts/node_seed.py:42-55]. There is no logging framework, so
the prefix **is** the severity and there is no timestamp, no stream discipline and no level filter.
**Kind** is assigned as: *evidentiary* = the line reports a measurement the process just took (a
digest it recomputed, a count it walked, an exit code it read); *descriptive* = narration or a
restatement of a decision already made, with nothing measured behind it.

| Level | Line (verbatim) | Emitted when | Kind |
|---|---|---|---|
| stdout `..` | `  ..    manifest glob matched nothing: %s` | a declared glob expanded to zero paths [scripts/node_seed.py:89] | evidentiary — a measurement of the tree; measured twice per build today (`skills/**/*.sh`, `skills/**/*.py`) |
| stdout `PASS` | `  PASS  seed_manifest — %s files declared, %s bytes (ceiling %s)` | every file was hashed and the total is within budget [scripts/node_seed.py:132] | evidentiary — the numbers are the hashed set |
| stdout `FAIL` | `  FAIL  seed_manifest — %s is a directory — declare files, not trees` | a declared entry is a directory [scripts/node_seed.py:117] | evidentiary |
| stdout `FAIL` | `  FAIL  seed_manifest — %s is a backup artefact and may not be seeded` | a declared path starts `backups/` or ends `.tar.gz` [scripts/node_seed.py:120-121] | evidentiary — but only reachable when the file exists (§8.7) |
| stdout `FAIL` | `  FAIL  seed_budget — %d bytes exceeds the declared ceiling of %d` | the summed size is over `--budget` [scripts/node_seed.py:129] | evidentiary |
| stdout `PASS` | `  PASS  seed_record — %s (%d files, sha256 per file)` | the tarball and the record were written [scripts/node_seed.py:151] | descriptive — states an intention; the write itself is unwitnessed until `check` reads it back |
| stdout `..` | `  ..    %s  %s` | once per declared file, `digest[:12]` and path [scripts/node_seed.py:153] | evidentiary — the short digest is the value just computed |
| stderr | `REFUSED: manifest entry missing: %s` | a literal manifest path does not exist [scripts/node_seed.py:94] | evidentiary — a `SystemExit` string, not a row: no `FAIL` prefix, and the only line this script sends to stderr by design |
| stdout `PASS` | `  PASS  seed_digest — all %d files match the record` | every staged file re-hashed and equal [scripts/node_seed.py:194] | evidentiary — the strongest row in the file: it is the gate that permits the install |
| stdout `FAIL` | `  FAIL  seed_digest — %s missing from the archive` | a record path is not in the tarball [scripts/node_seed.py:184] | evidentiary — names the path |
| stdout `FAIL` | `  FAIL  seed_digest — %s digest %s != recorded %s` | a staged file hashes differently [scripts/node_seed.py:189] | evidentiary — names both digests |
| stdout `FAIL` | `  FAIL  seed_apply — %d file(s) failed the digest check — nothing installed` | one or more of the two rows above [scripts/node_seed.py:192] | evidentiary — the count is the mismatch counter |
| stdout `FAIL` | `  FAIL  seed_extract — refusing path traversal in archive: %s` | a member resolves outside staging [scripts/node_seed.py:176] | evidentiary — names the member |
| stdout `PASS` | `  PASS  seed_install — %s/ installed (%d files)` | the tree was copied and then walked [scripts/node_seed.py:206] | evidentiary of the **copy**, not of identity: it counts files, it does not re-hash them |
| stdout `PASS` | `  PASS  seed_record — %s written` | the applied record was dumped [scripts/node_seed.py:215] | descriptive — the file is written immediately after this claim, not before it |
| stdout `PASS` | `  PASS  seed_check — %d files present and matching` | zero drift [scripts/node_seed.py:241] | evidentiary — and a **machine contract**: `node_seed_drift.py` parses this shape [scripts/node_seed_drift.py:166] |
| stdout `FAIL` | `  FAIL  seed_check — %s absent on the node` | a recorded path is missing [scripts/node_seed.py:230] | evidentiary — names the path |
| stdout `FAIL` | `  FAIL  seed_check — %s drifted (%s != %s)` | a recorded path hashes differently [scripts/node_seed.py:235] | evidentiary — the line the live node produced on a one-line tamper [docs/audits/code-factory-cf220-2026-11-05.md:53] |
| stdout `FAIL` | `  FAIL  seed_check — %d of %d seeded files differ from the record` | the drift counter is non-zero [scripts/node_seed.py:239] | evidentiary — the count, over the record's own length |
| stderr | `FileExistsError: [Errno 17] File exists: '<home>/.hermes/skills'` | `copytree` met a non-directory after `prompts/` was already replaced [scripts/node_seed.py:205] | **not a row** — an uncaught exception; the only signal that the install was half (§8.4) |
| stderr | `PermissionError: [Errno 13] Permission denied: '<home>/.hermes/prompts'` | the destination could not be re-linked [scripts/node_seed.py:204] | **not a row** — same shape, and the prompt tree is already emptied when it prints |
| stderr | `FileNotFoundError: [Errno 2] No such file or directory: '<tar-or-record>'` | a required input path does not exist [scripts/node_seed.py:157-159] [scripts/node_seed.py:172] | **not a row** — an uncaught traceback, exit 1 (§8.6) |

The shape to remember: **every line that says a tree is installed is a copy count, and every line
that says a tree is correct is a digest comparison.** The one place the two are confused is
`seed_install`, which prints a count as a `PASS` — measured green on a tree that also contained a
smuggled file (§3 row 14).

## 6. Failure modes

Direction is the fail-open / fail-closed sense: what the failure does to the node that is left
behind, and to whoever reads the node later.

| Failure | Direction | Presents as | Distinguished from | Recovery |
|---|---|---|---|---|
| A literal manifest entry is missing | **fail-closed**, before any hashing | `REFUSED: manifest entry missing: <entry>` on **stderr**, exit 1, no tarball [scripts/node_seed.py:93-94] | an empty glob is the opposite direction — a `..` note and a smaller seed [scripts/node_seed.py:89] | fix the manifest or the tree; nothing was written |
| A declared glob matches nothing | **fail-open, by design** | `  ..    manifest glob matched nothing: <glob>`, then `PASS` with the remaining files [scripts/node_seed.py:132] | a manifest typo in a glob shrinks the seed silently — today two globs are empty and the seed is complete anyway | nothing to do today; a seed that *loses* files this way is invisible until `check` names 11 of 11 |
| A digest disagrees, or a file is absent from the archive | **fail-closed, before install** | `FAIL seed_digest` rows, `FAIL seed_apply`, exit 1, nothing installed [scripts/node_seed.py:180-193] | a *mid-install* failure prints a traceback instead (rows below) | rebuild the archive from the same tree; the node was not touched beyond an empty `.hermes/` |
| The archive carries a member the record does not declare | **fail-open** | nothing: exit 0, four `PASS` rows, the extra file installed [scripts/node_seed.py:198-205] | a traversal member is refused loudly [scripts/node_seed.py:175-176] | treat the record as a manifest of *intent*, not a boundary; the tarball's integrity rests on the transport (§8.1) |
| `prompts/` installs and `skills/` does not (e.g. a file at `.hermes/skills`) | **half, loudly** | `FileExistsError` traceback, exit 1, prompts replaced, no record [scripts/node_seed.py:203-206] | the caller prints `bad node_seed "apply exited 1 on the node — rows above"` and **the rows are not there** (§8.8) | remove the obstacle and re-apply; the operation is idempotent (§3 row 4) |
| A re-apply fails after `rmtree` started | **half, silently preserved from the last run** | `PermissionError` traceback, exit 1, prompts deleted and not restored, **the old record still claims 13 files** [scripts/node_seed.py:204] [scripts/node_seed.py:211] | a first-run failure leaves no record at all, which is honest | fix permissions, re-apply, then `check`; do not read a record as proof of the run that left it |
| A local modification meets a re-apply | **fail-open to "the seed is the truth"** | four `PASS` rows; the edit is gone and hand-written files are deleted, with no row that says so [scripts/node_seed.py:203-205] | `check` before the apply reports the drift and exits 1 [scripts/node_seed.py:234-240] | run `check` first; a node that must keep local edits cannot (there is no merge and no exclusion list) |
| Extra files on the node | **fail-open** | `PASS seed_check — 13 files present and matching` with 12 prompts and 3 skills present; measured | a changed *recorded* file fails and is named | compare directory listings, not only `check`; nothing in the module counts unexpected files (§8.2) |
| The node's record is rewritten | **fail-open, and it defeats the whole check** | `PASS` over a hand-edited prompt, exit 0; measured by rewriting one `sha256` in `seed-applied.json` | an untouched record fails on the same edit | the record must come from the control host (the build record) or be signed; today the node holds its own reference (§8.2) |
| A declared path outside `prompts/` and `skills/` | **fail-silent, then permanently red** | apply exit 0 and `all 2 files match the record`, the file never installed; `check` then fails forever on `config/note.txt absent on the node` [scripts/node_seed.py:198-201] [scripts/node_seed.py:230] | a genuinely missing file also fails `check` — the difference is that no apply can ever fix this one | declare only `prompts/` and `skills/` paths until the installer grows more roots (§8.3) |
| An absolute symlink member in the archive | **fail-closed on the interpreter measured here** | `tarfile.AbsoluteLinkError`, exit 1, nothing escaped [scripts/node_seed.py:178] | a `../` or absolute member is refused by this script's own pre-check, with a `FAIL` row | the defence is CPython's default `data` filter, not this file: a node whose `python3` predates that default has no symlink check here at all (§8.5) |
| The seed exceeds the budget | **fail-closed, at build** | `FAIL seed_budget — N bytes exceeds the declared ceiling of M`, exit 1, no tarball [scripts/node_seed.py:128-130] | the caller reports `bad node_seed "build refused the declared seed — see the row above"` and prints the last five log lines [scripts/bunker-provision.sh:472-473] | raise `--budget` deliberately, or trim the manifest; the node never saw an archive |
| The manifest file itself is absent | **fail-closed, at the caller** | `WARN node_seed "config/node-seed.txt is absent — nothing declares what a node receives"`, and provisioning continues [scripts/bunker-provision.sh:477] | a build failure is a `bad` row, not a `warn` | restore the manifest; a node created in the meantime is unseeded and only `verify-node.sh`'s drift leg would say so |
| `apply` fails on the node | **fail-loud but evidence lost** | the caller prints `bad node_seed "apply exited N on the node — rows above"`; the captured output is never echoed, and the tarball, record and seeder are removed from the node in the same block [scripts/bunker-provision.sh:464] [scripts/bunker-provision.sh:466-467] | the `PASS` arm counts rows out of the same captured string [scripts/bunker-provision.sh:462] | re-run the apply from the control host with the record kept; the node's half state stays until then (§8.8) |

## 7. Environment and settings it reads

**No environment variable is read.** `os` is imported for paths only; the module has no
`os.environ` access, and both defaults are module constants [scripts/node_seed.py:38-39]. Every
input is argv or a file argv names, which is why the same command behaves identically under `env -i`.

| Input | Default | Effect |
|---|---|---|
| `--home` (apply, check) | `"~"`, passed through `os.path.expanduser` [scripts/node_seed.py:259] [scripts/node_seed.py:164] | decides `$HOME/.hermes` — the install root and the record's home [scripts/node_seed.py:165-166]. `check` never creates it: measured, a HOME that was never seeded is left non-existent and every recorded path is reported absent |
| `$HOME`'s writability and free space | — | the staging tree is created **inside** it, not in the system temp (prefix `node-seed-`) [scripts/node_seed.py:170], so a full home fails before verification and a read-only home fails at install [scripts/node_seed.py:204-205] |
| `TZ` | not read | `built_at` and `applied_at` are `gmtime` [scripts/node_seed.py:140] [scripts/node_seed.py:209], so the record's clock is UTC regardless |
| `umask` | inherits the caller's | decides the modes that land: measured 775 for the directories and 664 for the record under `umask 002`; the tar members carry the source files' own 664 [scripts/node_seed.py:135-137] |
| `--manifest` (build) | `config/node-seed.txt` [scripts/node_seed.py:38] [scripts/node_seed.py:250] | resolved against `--repo-root`, never against the cwd alone [scripts/node_seed.py:81] |
| `--repo-root` (build) | empty → `os.getcwd()` [scripts/node_seed.py:110] | the root every manifest entry is joined to, and the base `relpath` is taken from, so record paths are repo-relative by construction [scripts/node_seed.py:119] |
| `--out` (build) | **required** [scripts/node_seed.py:252] | the tarball; the record is always `<out>.json` [scripts/node_seed.py:146]. Parent directories are created [scripts/node_seed.py:134] |
| `--budget` (build) | `16 * 1024 * 1024` = 16,777,216 [scripts/node_seed.py:39] [scripts/node_seed.py:253] | the summed size of the declared files, not the archive size — 41,211 declared today |
| `--exclude-backups` (build) | `store_true` **with `default=True`** [scripts/node_seed.py:254] | the backup rule is therefore always on and the flag cannot turn it off: measured, `--help` shows the bare flag and no negation exists, so it is inert (§8.7) |
| `--tar`, `--record` (apply) | **required** [scripts/node_seed.py:257-258] | a missing path is an uncaught traceback, exit 1, not a usage error (§8.6) |
| `--record` (check) | **required** [scripts/node_seed.py:262] | the reference: the build record from the control host, or the node's own `seed-applied.json` [scripts/node_seed.py:211] — the two are interchangeable in shape and different in trust (§8.2) |

## 8. Evidence of record

- **Measured 2026-11-05** in a fresh worktree of `d8c7796` (`~/proj-wt-md-31d`), Python 3.14.4, with
  every probe pointed at a scratch directory under `/home/kara/.hermes/cache/scratch/md31`. No
  `bunker` call was made and no node was touched; the repository was left clean by the suite run.
  The live-node statements below are quoted from the committed artifact, not re-measured here.
- **The declared seed, as built**: 13 files, 41,211 bytes, `manifest=config/node-seed.txt`,
  `repo_root` the worktree, `built_at` UTC. Per-file, with the first 12 hex of each sha256:

| # | Path | Bytes | sha256[:12] |
|---|---|---|---|
| 1 | `prompts/docs.md` | 846 | `5d093e26d190` |
| 2 | `prompts/dogfood.md` | 1,422 | `2236c575ac71` |
| 3 | `prompts/duckbrain.md` | 1,410 | `587bffe05592` |
| 4 | `prompts/foreman.md` | 3,413 | `82c020b6f316` |
| 5 | `prompts/perf.md` | 814 | `f83b103e1fad` |
| 6 | `prompts/pm.md` | 1,390 | `ae322007c93c` |
| 7 | `prompts/qa.md` | 1,388 | `eda4198ebb76` |
| 8 | `prompts/readme.md` | 893 | `fd42e2a2cb30` |
| 9 | `prompts/releng.md` | 908 | `f64998f18f2e` |
| 10 | `prompts/review.md` | 1,105 | `ec60bbf8e414` |
| 11 | `prompts/sync.md` | 1,362 | `d27390d20377` |
| 12 | `skills/code-factory-bunker/SKILL.md` | 20,375 | `f95b3880feec` |
| 13 | `skills/code-factory-foreman/SKILL.md` | 5,885 | `b9aac5166404` |

- **The live node corroborates the shape**: cf-node carries a 2,251-byte `seed-applied.json`
  reporting `applied_at`, `applied_to` and 13 files, and `find ~/.hermes/prompts ~/.hermes/skills
  -type f` counts 14 — the 13 seeded files plus the record
  [docs/audits/code-factory-cf220-2026-11-05.md:22-38]. The drift arm on the same node produced the
  red rows quoted in §5 and returned green after a restore
  [docs/audits/code-factory-cf220-2026-11-05.md:47-59].
- **A build is not reproducible byte-for-byte.** Two builds one second apart produced 13/13 equal
  per-file digests and a different archive sha256 (`f62adc8e…` vs `55663d70…`), because `w:gz`
  stamps the archive. Any future attempt to pin a seed by tarball digest will fail; the per-file
  record is the only stable identity.
- **Defects found while measuring** (out of scope for this task; nothing was fixed):

| # | Defect | Evidence |
|---|---|---|
| 1 | **The install boundary is the staging tree, not the record.** `apply` copies whole directories, so any member of the tarball under `prompts/` or `skills/` installs even though the record never names it, and the digest loop only walks `record["files"]` [scripts/node_seed.py:181] [scripts/node_seed.py:198-205]. The docstring's "the exclusion is by construction" [scripts/node_seed.py:19-21] holds for *inclusion* at build time, not for *installation* | measured: a 14th member `prompts/smuggled.md` installed, exit 0 (§3 row 14). **Not filed** |
| 2 | **`check` cannot see extra files, and its reference is the node's own writable record.** It iterates `record["files"]` and nothing else [scripts/node_seed.py:227]; the record it is normally given is the one `apply` wrote on the node [scripts/node_seed.py:211], unsigned and mode 664 in the measured umask | measured: 12 prompts + 3 skills → `PASS`; and rewriting one `sha256` in `seed-applied.json` turned an edited `foreman.md` green (§3 rows 15-16). **Not filed** |
| 3 | **A declared path outside `prompts/` and `skills/` is verified and then dropped.** The install loop's two hardcoded roots [scripts/node_seed.py:198] make any other record path uninstallable, yet apply still exits 0 while `check` fails on it forever | measured with `config/note.txt`: build 0, apply 0 (`all 2 files match the record`), `check` exit 1, unfixable by any apply (§3 row 17). **Not filed** |
| 4 | **A half-install is reachable and leaves either no marker or a stale one.** The two trees are separate transactions and the record is written last [scripts/node_seed.py:198-215]; the failure is an uncaught exception rather than a row | measured twice: prompts replaced with no record; prompts emptied with the previous record still claiming 13 files (§3 rows 8-9). **Not filed** |
| 5 | **Symlink-escape defence is the interpreter's, not the code's.** `extractall(staging)` passes no `filter=` [scripts/node_seed.py:178], and the pre-check compares `realpath` before members exist [scripts/node_seed.py:172-177] | measured on 3.14.4: `tarfile.AbsoluteLinkError`, exit 1; no measurement on an interpreter whose default filter is permissive, where the same archive is a pivot (§3 row 13). **Not filed** |
| 6 | **Missing inputs are tracebacks, not usage errors.** `--tar` and `--record` are required, but a path that does not exist bypasses argparse and dies in `open`/`tarfile` [scripts/node_seed.py:157-159] | measured: `FileNotFoundError` traceback, exit 1, for both verbs (§3 row 18). Exit 1 collides with "refused/drifted" [scripts/node_seed.py:23]. **Not filed** |
| 7 | **`--exclude-backups` is inert (`store_true` with `default=True`), and the suite's arm for it cannot fail.** The rule fires only when the declared backup exists; when it does not, the missing-entry refusal supplies the same non-zero exit, which is all the arm asserts | measured both ways: `is a backup artefact and may not be seeded` (present) vs `REFUSED: manifest entry missing` (absent); the suite builds the absent case [tests/selftest.sh:3139-3145], and `--help` offers no way to disable the flag [scripts/node_seed.py:254] (§3 row 19). **Not filed** |
| 8 | **The caller loses the node's rows and deletes its evidence on failure.** `seed_out` is captured [scripts/bunker-provision.sh:460] and only counted on success [scripts/bunker-provision.sh:462]; the failure row says "rows above" while printing none [scripts/bunker-provision.sh:464], and the tarball, record and seeder are removed in the same block [scripts/bunker-provision.sh:466-467] | read from the caller plus measured exit codes; the half-seed rows in §3 rows 8-9 are exactly the output that would be discarded. **Not filed** |
| 9 | **The applied record carries the control host's absolute paths onto the node** — `repo_root` and `manifest` are copied from the build record verbatim [scripts/node_seed.py:208] [scripts/node_seed.py:142] | measured: `repo_root=/home/kara/proj-wt-md-31d` inside a record written under a scratch HOME (§3 row 2). Cosmetic, but it means the record describes a host the node cannot see. **Not filed** |
| 10 | **`seed_install` reports a copy count as a correctness verdict.** The count walks the installed tree and re-hashes nothing [scripts/node_seed.py:206], so it prints `PASS` for a tree containing a file the record never declared | measured (§3 row 14), and it is the row an operator reads as "the seed is good". **Not filed** |
