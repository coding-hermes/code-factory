# 34. scripts/reclaim_disk.py

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/reclaim_disk.py` — 169 lines, two subcommands (`targets`, `run`), no third-party import [scripts/reclaim_disk.py:1] [scripts/reclaim_disk.py:131-137] |
| Repository | `code-factory` |
| Revision | `d8c7796` — the `origin/main` tip every locator below was measured against (worktree `~/proj-wt-md-34d`, 2026-11-05); the file's own last-touching commit is `27df6ac` (2026-11-03, "feat(node): reap caches, job dirs and stale clones before disk-floor refusal — a node below its floor refused admission without reclaiming anything, so a full host could never recover. Addresses CF-007 (AC3)") |
| Status | **VERIFIED — 266 locators, all resolve; every removal root enumerated from source and measured on scratch trees; ten defects recorded in §6** |

## 1. Purpose and why it matters

- What it is: the node's only deleter. Its own one-line charter is `Reap only fixed user-space caches and expired node job/clone directories.` [scripts/reclaim_disk.py:2], and the whole surface is three module constants — `BUILD_CACHES` (five fixed cache paths) [scripts/reclaim_disk.py:14-20], `AGED_PARENTS` (`.node/jobs`, `.node/clones`) [scripts/reclaim_disk.py:21], and `PROTECTED` (four names that must survive) [scripts/reclaim_disk.py:22].
- **Exactly what it removes, and under which conditions** — this is the question a deleter has to answer before anything else:
  - `.cache/pip`, `.cache/uv`, `.cache/pre-commit`, `.cache/go-build`, `.npm/_cacache` — **removed whole, with no age gate, no size threshold and no "keep the newest" rule**. `target()` is called with `aged` defaulting to false [scripts/reclaim_disk.py:82] [scripts/reclaim_disk.py:102-103], and the age test at [scripts/reclaim_disk.py:90] is skipped entirely when `aged` is false, so control falls straight through to `remove(path)` [scripts/reclaim_disk.py:94]. Measured: a cache payload written at the moment of the run is deleted (§3, check 3).
  - Every **immediate child** of `.node/jobs` and `.node/clones`, and only the immediate children — `parent.iterdir()` at [scripts/reclaim_disk.py:110], reaped only when `(now - mtime)/3600 > job_ttl_hours` [scripts/reclaim_disk.py:90-92], TTL defaulting to 24 h [scripts/reclaim_disk.py:42] [scripts/reclaim_disk.py:135]. The age is the **directory's own mtime**, so a stale clone whose directory was touched a minute ago survives with all its bytes, and an expired directory's fresh contents die with it (§3, check 4 for both directions).
  - Nothing else. `.cache` itself is never a target, only the five named entries, so `~/.cache/other` and `~/Documents` are outside the surface — measured, both survived a run in which they existed beside five reaped caches (§3, check 3) — and `~/.cache/huggingface`, `~/.cargo`, `node_modules` and `~/.local/share` are outside it by construction, because none of them appears in `BUILD_CACHES` [scripts/reclaim_disk.py:14-20].
- **Is there a dry-run?** Yes, and it is real: `run --dry-run` sets `dry_run` [scripts/reclaim_disk.py:136], which suppresses both `path.unlink()` [scripts/reclaim_disk.py:78-79] and `path.rmdir()` [scripts/reclaim_disk.py:74-75] while keeping the full traversal and byte accounting. Measured: on a nine-target scratch tree the preview printed the same `reclaimed_bytes` (28672) as the real run and every file survived (§3, check 2). The spec requires it [specs/NODE.md:123]. What does **not** exist is any wire from automation into it: the ladder's only invocation passes `run --root "$HOME" --json` and nothing else [scripts/project-node.sh:212], so rehearsal is an operator action; the ladder's own non-destructive preview is `--check`, which prints one note naming what `--apply` would reap instead of the set [scripts/project-node.sh:199-200]. So the deletion set is printable, and on a real node nothing prints it before deleting.
- What breaks if it is **absent**: the disk-floor refusal has no recovery path. `project-node.sh --apply` below the floor looks for the file, and without it prints `  FAIL  disk_floor — reclaimer missing or unreadable: <path>` and `NODE: FAIL (1)`, refusing admission without ever trying to make room [scripts/project-node.sh:206-211]. The staging list that ships to a node includes it by name [scripts/node-create.sh:23], and the packager refuses any set whose entry point references a file that is not staged [scripts/node-create.sh:30-47], so dropping it from the list fails loudly rather than silently.
- What breaks if it **lies**: the number is not decorative — it lands in the ladder's PASS row. `reclaimed_mib` from the JSON is parsed and printed as `  PASS  disk — <free> GB free after reclaim (freed <freed> MiB; floor <n> GB)` [scripts/project-node.sh:218-225], and the JSON is read from the **last** stdout line [scripts/project-node.sh:218], so both the aggregate and the layout of stdout are consumed. An over-reported figure becomes the evidence that admission was legitimate. §6 D-5 and D-6 are two ways it can over-report.
- Why it matters more than its 169 lines: the project rule is that disk is shared and that reaping is routine — "Refuse to install below the floor and say the number; reap build caches and job dirs before you fill the host" [AGENTS.md:49] (rule 12). A deleter that runs on every sub-floor `--apply` and that automation cannot rehearse is a routine data-loss surface, which is why §6 exists.
- What it is *not*: not an installer, not a scheduler, no daemon, no configuration file, no environment variable (§7). It mutates and reports; it never re-measures free space — that is the ladder's job after it returns [scripts/project-node.sh:223-230].

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `python3` | measured here 3.14.4; the syntax needs nothing newer than 3.7 (f-strings, subparsers, `from __future__ import annotations`) [scripts/reclaim_disk.py:4] [scripts/reclaim_disk.py:131] | on `PATH` — the only caller invokes it by name, unqualified [scripts/project-node.sh:212] | **by the caller, as a failed reap**: `python3` missing makes the command fail to start, `$?` non-zero, and the ladder prints `  FAIL  disk_floor — reclaim failed: <merged output>` and stops [scripts/project-node.sh:212-216]. The module itself cannot report its own interpreter missing. |
| Python standard library: `argparse`, `json`, `math`, `os`, `pathlib`, `sys`, `time` [scripts/reclaim_disk.py:6-12] | the interpreter's own | in the interpreter | import failure at startup; nothing checks it before use |
| No third-party package, no network, no database, no container | — | — | Verified by reading the whole file: the only imports are the seven standard-library modules above; there is no `subprocess`, no `socket`, no `urllib` [scripts/reclaim_disk.py:6-12] |
| Filesystem permissions the target tree grants the caller | — | must be writable to unlink; the reclaimer runs as the owning user under `$HOME`, never as root — the project forbids root entirely [scripts/project-node.sh:212] [AGENTS.md:37] | **partially**: an `EACCES` on one subtree aborts the run with exit 2 and one stderr line, after earlier deletions, and prints no per-entry rows and no JSON (§3, check 11; §6 D-4) |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `argparse` subparsers with `required=True` [scripts/reclaim_disk.py:131] | stdlib | A missing subcommand is a usage error with exit 2, printed by argparse itself as `reclaim_disk.py: error: the following arguments are required: command` (§3, check 10) | A caller that omits the subcommand gets usage text on stderr, not this module's `reclaim:` line; nothing in the tree invokes it that way [scripts/project-node.sh:212] |
| `type=float` on `--job-ttl-hours` [scripts/reclaim_disk.py:135] | stdlib | `float()` accepts `nan`, `inf` and negatives, which is exactly why the value is re-validated downstream | The validation at [scripts/reclaim_disk.py:46-47] exists to close this hole; measured: `-1`, `nan`, `inf` all exit 2 (§3, check 10) |
| `math.isfinite` [scripts/reclaim_disk.py:46] | stdlib | rejects `nan`/`inf` so the TTL comparison at [scripts/reclaim_disk.py:90] cannot be a silent false | If the guard were dropped, `nan` would make every comparison false and the module would reap **all** job and clone directories regardless of age |
| `os.path.realpath` [scripts/reclaim_disk.py:27] [scripts/reclaim_disk.py:43] | stdlib | resolves every symlink in the path, so containment is judged on the real path, and `root` itself is canonicalised before any comparison | The root is normalised once at [scripts/reclaim_disk.py:43]; `safety_reason` re-resolves each candidate [scripts/reclaim_disk.py:27] and requires `root in real.parents` [scripts/reclaim_disk.py:33] |
| `pathlib.Path` — `is_symlink`, `iterdir`, `stat`, `unlink`, `rmdir`, `relative_to`, `exists` [scripts/reclaim_disk.py:29-38] [scripts/reclaim_disk.py:54] [scripts/reclaim_disk.py:67-79] [scripts/reclaim_disk.py:110] | stdlib | `iterdir` order is filesystem order, so children are `sorted()` before recursion [scripts/reclaim_disk.py:70] [scripts/reclaim_disk.py:110]; `stat()` follows symlinks, which is safe only because symlinks are filtered first [scripts/reclaim_disk.py:29-31] | The order matters for the record list only: `entries` is append-ordered, so an unsorted walk would make two runs' JSON differ in order while agreeing in bytes |
| `json.dumps(result)` [scripts/reclaim_disk.py:164] | stdlib | the result holds `str`, `int`, `float` and a list of dicts of the same [scripts/reclaim_disk.py:52-60] [scripts/reclaim_disk.py:120-126], so it serialises without a default hook | The consumer parses the **last stdout line** [scripts/project-node.sh:218]; any additional stdout line after the JSON, or a non-serialisable value in an entry, breaks the ladder's parse and produces `  FAIL  disk_floor — reclaimer returned no reclaimed size` [scripts/project-node.sh:218-222] |
| `time.time()` [scripts/reclaim_disk.py:49] and `st_mtime` [scripts/reclaim_disk.py:90] | stdlib / kernel | one wall-clock sample per run, compared to mtime in hours; no monotonic clock, no file-cache invalidation | A clock step moves every age at once; a future mtime yields a negative age, which reads as fresh and keeps the directory |

### 2c. Service contracts (both sides named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| `scripts/project-node.sh` | ladder → reclaimer | `execve` of `python3 <dir>/reclaim_disk.py run --root "$HOME" --json`; stdout and stderr both captured (`2>&1`); exit status decides [scripts/project-node.sh:212-216] | argv as above; no environment contract, because the module reads no variable (§7) | `project-node.sh` layer `00 preflight`, the `--apply` branch only [scripts/project-node.sh:198-231]. On exit 0 it echoes every line except the last [scripts/project-node.sh:217] and parses the last line as JSON for `reclaimed_mib` [scripts/project-node.sh:218] |
| `scripts/project-node.sh` — post-condition | ladder, after the reap | in-process `free_gb`/`awk` re-measure of the same `$HOME` | the free-space figure in GB compared to the floor [scripts/project-node.sh:223-230] | The reclaimer never re-measures, so the ladder is the only side that can say whether the reap achieved admission. Both outcomes are named: `PASS disk — … after reclaim (freed <n> MiB; …)` or `FAIL disk — … < floor … (freed <n> MiB)` then `NODE: FAIL (disk admission)` [scripts/project-node.sh:225-229] |
| `scripts/node-create.sh` | packager → node | file staging: the script is copied into the node's `scripts/` beside `project-node.sh`, `lib.sh` and `disk_floor.py` [scripts/node-create.sh:23] | the file's own bytes | The staged-set assertion in the packager requires it by name — `staged_files` walks the entry point for `$HERE/` references and refuses a reference it has not staged [scripts/node-create.sh:30-47], and the list itself must exist on disk [scripts/node-create.sh:26]. A reclaimer that is not staged makes every sub-floor `--apply` on that node fail at [scripts/project-node.sh:207-210] |
| `specs/NODE.md` §"Disk floor" | normative contract, both sides in this repo | prose | "…are removed whole; immediate job directories under `.node/jobs` and stale clones under `.node/clones` are removed only when their mtime exceeds the TTL (default 24 hours, configurable with `--job-ttl-hours`). Targets are fixed, resolved inside the real root, and symlinks are never followed. The repo and node identity/configuration files are never targets. The reclaimer refuses `/` and non-directory roots, supports `--dry-run`, and reports reclaimed bytes." [specs/NODE.md:116-123] | The implementation matches each clause, with one wording gap: the spec says "mtime exceeds the TTL" while the code keeps `age <= TTL` and reaps strictly beyond it [scripts/reclaim_disk.py:90-92], so a directory at exactly 24.000 h is reaped — measured (§3, check 8) |
| `tests/test_reclaim.py` | suite → module, **as a library** | `import reclaim_disk` from `sys.path` [tests/test_reclaim.py:15-16], plus a subprocess for the CLI surface [tests/test_reclaim.py:35-40] | the module's public constants `BUILD_CACHES`, `AGED_PARENTS`, `PROTECTED` and the `reclaim(root, job_ttl_hours=…)` signature [tests/test_reclaim.py:43] [tests/test_reclaim.py:51] [tests/test_reclaim.py:94] [tests/test_reclaim.py:149] | This is the only in-tree importer, so renaming a constant or changing the signature is a test break, not a silent drift. Run by the repo's gate [tests/selftest.sh:1005-1009] |
| `tests/selftest.sh` leg 20 | gate → CLI rows | `bash`, one fixture `$HOME`, `env -i` with a fixture `PATH` [tests/selftest.sh:939-951] | the human rows, grepped by **prefix**: `^  reap  .cache/pip —` and `^  FAIL  disk —` [tests/selftest.sh:952-953] | The row format is therefore a contract: changing the two spaces after `reap`, the em dash, or the order of composition changes what the gate can see. The leg also deletes the file to prove the missing-reclaimer branch [tests/selftest.sh:995-1003] |

## 3. Verification

Measured 2026-11-05 from a clean worktree of `d8c7796` (`~/proj-wt-md-34d`), Linux x86_64, Python 3.14.4. Every command below was executed; **each root is a scratch tree under `$TMPDIR`** (`/home/kara/.hermes/cache/scratch/md25b/md34/…`), never a real cache, and no real `$HOME` path was passed to the module.

| # | Check | Command | Expected | Last run | Result |
|---|---|---|---|---|---|
| 1 | The declared surface | `python3 -B scripts/reclaim_disk.py targets` [scripts/reclaim_disk.py:139-141] | seven lines: five fixed caches and two `<directory>` parents | 2026-11-05 | **exit 0**, exactly the seven lines of transcript 1 — this is the locator list the rest of the document is checked against |
| 2 | Dry-run is non-destructive and byte-identical to the real run | `run --root <scratch> --dry-run --json` on a tree with nine targets plus four things that must survive [scripts/reclaim_disk.py:136] [scripts/reclaim_disk.py:74-79] | every file still present, `reclaimed_bytes` equal to the later real run's | 2026-11-05 | **as specified** — all six probe files `SURVIVED`, `reclaimed_bytes` 28672, exit 0 (transcript 2) |
| 3 | The real run removes exactly the seven roots and nothing else | `run --root <scratch> --json` on the same tree; the tree carried `.cache/pip`, `.cache/uv`, `.cache/pre-commit`, `.cache/go-build`, `.npm/_cacache`, `.node/jobs/{old,fresh}`, `.node/clones/{stale,live}`, plus `.cache/other/keep.txt` and `Documents/notes.txt` (both fresh) and `repo`, `.node/node.json`, `.node/crier.json`, `.node/floor.toml` all backdated 200 h | five caches gone with **fresh** mtimes; `jobs/old` and `clones/stale` (48 h, 72 h) gone; `jobs/fresh`, `clones/live` kept; `.cache/other`, `Documents` untouched, and `repo` plus the three identity files untouched despite 200 h | 2026-11-05 | **as specified** — 15-row assertion table in transcript 3: five caches `REMOVED`, `jobs/old` `REMOVED`, `jobs/fresh` `SURVIVED`, `clones/stale` `REMOVED`, `clones/live` `SURVIVED`, and all five non-targets `SURVIVED` |
| 4 | The age gate is the directory's mtime, in both directions | `run` on one clone dir with dir mtime = now and payload mtime −100 h, then on the mirror image | keep / reap respectively | 2026-11-05 | **as specified** — `keep  .node/clones/oldcontent — fresh (0.0h <= TTL 24h)` then `reap  .node/clones/newcontent … (expired)` (transcript 4) |
| 5 | Idempotence: a second run is a no-op | the same `run` twice [scripts/reclaim_disk.py:86-87] | second run all `absent`, `reclaimed_bytes` 0, exit 0 | 2026-11-05 | **as specified** — six `skip … — absent`, `note reclaim — nothing to reclaim`, exit 0 (transcript 5) |
| 6 | Symlinks are never followed, at the target or in a parent component | `.cache/pip` → an outside dir; `.node/jobs/old` → the same dir (transcript 6) [scripts/reclaim_disk.py:29-31] | `skipped:symlink` for both, outside bytes intact, links still links | 2026-11-05 | **as specified** — two `skip … — symlink not followed` rows, `outside/payload = untouched`, both entries still `lrwxrwxrwx` |
| 7 | A symlink *inside* a cache: partial deletion that never completes | `.cache/go-build/{f2,aa/f1}` plus `aa/link` → outside [scripts/reclaim_disk.py:70-76] | files unlinked, directory kept, `action` `kept` with non-zero bytes | 2026-11-05 | **BROKEN — defect D-3**: the two files were removed (8192 bytes counted as reclaimed) and `aa/link` plus the whole `.cache/go-build` survived; a **second run reports `nothing to reclaim`**, so the directory is stranded forever (transcript 7) |
| 8 | The TTL boundary, to the hour | `run` with job dirs at 23.9 h, 24.0 h and 24.1 h (transcript 8) [scripts/reclaim_disk.py:90] | keep at 23.9 h, reap beyond | 2026-11-05 | **as specified** — `keep  .node/jobs/a_23h9 — fresh (23.9h <= TTL 24h)`, `reap  .node/jobs/b_24h0`, `reap  .node/jobs/c_24h1`; survivors table confirms 23.9 h `SURVIVED`, both others `REMOVED` |
| 9 | `--job-ttl-hours 0` reaps a directory touched this second | `run --root <scratch> --job-ttl-hours 0` [scripts/reclaim_disk.py:135] | reap | 2026-11-05 | **as specified**, and it is the over-reap arm of D-8: `reap  .node/jobs/justnow … (expired)` on a directory created moments earlier |
| 10 | Every validation refusal exits 2 with a named message | `run --root /`, `--root <a regular file>`, `--root <absent>`, `run --job-ttl-hours` at `-1`, `nan`, `inf`, `run` with no `--root`, bare invocation (transcript 9) [scripts/reclaim_disk.py:44-47] [scripts/reclaim_disk.py:134] | exit 2, one-line message | 2026-11-05 | **as specified** — three roots and three TTLs all `exit 2`; the two failure classes share one message each, so the message does not name which root was wrong |
| 11 | An unremovable subtree mid-run | `.cache/uv/locked` at mode 500 under a tree that also holds `.cache/pip`, `.cache/go-build` (transcript 10) [scripts/reclaim_disk.py:70-75] | — | 2026-11-05 | **BROKEN — defect D-4**: `reclaim: [Errno 13] Permission denied: '…/.cache/uv/locked/sub'` and exit 2 with **no JSON and no per-entry rows**; `.cache/pip` had already been deleted, `.cache/go-build` was never reached, and the ladder turns this into `FAIL disk_floor — reclaim failed: …` [scripts/project-node.sh:212-216] |
| 12 | The two units disagree | 10 MiB in `.cache/pip`, `run --dry-run --json` (transcript 11) [scripts/reclaim_disk.py:159] [scripts/reclaim_disk.py:123] | one number | 2026-11-05 | **BROKEN — defect D-5**: the printed row says `10.5 MB`, the JSON says `"reclaimed_mib": 10.0` — decimal MB for the human, binary MiB for the machine, 4.86 % apart |
| 13 | `safety_reason` on a path outside the root | library call `safety_reason(<root>, /etc/hostname)` under a 5 s timeout [scripts/reclaim_disk.py:29-34] | `skipped:outside-root` | 2026-11-05 | **BROKEN — defect D-1**: never returned; the timeout fired (`EXIT=124`, transcript 16). The containment test at [scripts/reclaim_disk.py:33-34] sits **behind** an unbounded parent walk at [scripts/reclaim_disk.py:29-32]. `safety_reason(root, root)` does return `skipped:outside-root`, so the guard's only reachable case is the degenerate one |
| 14 | The module's own suite | `PYTHONDONTWRITEBYTECODE=1 python3 -B tests/test_reclaim.py` [tests/test_reclaim.py:1-154] | 9 tests OK | 2026-11-05 | **PASS** — `Ran 9 tests in 0.387s / OK`, exit 0 (transcript 12) |
| 15 | The ladder leg that consumes it, verbatim | lines 938-1009 of `tests/selftest.sh` executed from a four-line preamble (`HERE`, `say`, `fails`) in scratch [tests/selftest.sh:937-1009] | five PASS rows, `fails=0` | 2026-11-05 | **PASS** — `pip cache reaped before one final disk FAIL; admission still refuses` · `check preserves pip bytes, counts one disk failure and continues preflight` · `re-measure admits a recovered node without a stale FAIL row` · `missing reclaimer fails closed with one counted row` · `reclaim targets, TTL, symlink safety, protected files, dry-run and idempotence`; `LEG fails=0` (transcript 13) |
| 16 | This document's own gate | `python3 scripts/master_doc_check.py docs/master --only 34- --strict` | `MASTER-DOC: PASS` | 2026-11-05 | **PASS** — `1 module(s): 1 VERIFIED, 0 error(s), 0 warning(s), 10 fact(s) in the ledger`, exit 0 (transcript 14) |
| 17 | A cache target that exists as a regular file | `run` on a tree whose `.cache/uv` is a regular file of 8 bytes [scripts/reclaim_disk.py:82-89] | refused as a shape error, never unlinked | 2026-11-05 | **as specified, and permanent**: `skip  .cache/uv — not a directory`, `nothing to reclaim`, exit 0, the file still 8 bytes (transcript 15). Nothing ever removes it and nothing reports it as a problem |

What the suite does **not** cover, stated so the green is not over-read: it never exercises an `OSError` mid-run (D-4), a non-directory cache target (check 17), a path outside the root (D-1), or the unit split (D-5). Its dry-run test compares byte totals only [tests/test_reclaim.py:132-144], which is why it passes despite D-3 and D-5.

Transcript 1 — check 1, the declared surface:

```
$ python3 -B scripts/reclaim_disk.py targets; echo "EXIT=$?"
.cache/pip
.cache/uv
.cache/pre-commit
.cache/go-build
.npm/_cacache
.node/jobs/<directory>
.node/clones/<directory>
EXIT=0
```

The `<directory>` in the last two lines is literal output, not a placeholder in this document — the subcommand prints `p + "/<directory>"` [scripts/reclaim_disk.py:140].

Transcript 2 — check 2, the dry-run on a nine-target scratch tree, with the survival probe immediately after:

```
$ python3 -B scripts/reclaim_disk.py run --root "$R" --dry-run --json; echo "EXIT=$?"
  reap  .cache/pip — 0.0 MB would free from …/md34/e2/.cache/pip (dry-run)
  reap  .cache/uv — 0.0 MB would free from …/md34/e2/.cache/uv (dry-run)
  reap  .cache/pre-commit — 0.0 MB would free from …/md34/e2/.cache/pre-commit (dry-run)
  reap  .cache/go-build — 0.0 MB would free from …/md34/e2/.cache/go-build (dry-run)
  reap  .npm/_cacache — 0.0 MB would free from …/md34/e2/.npm/_cacache (dry-run)
  keep  .node/jobs/fresh — fresh (0.0h <= TTL 24h)
  reap  .node/jobs/old — 0.0 MB would free from …/md34/e2/.node/jobs/old (dry-run)
  keep  .node/clones/live — fresh (0.0h <= TTL 24h)
  reap  .node/clones/stale — 0.0 MB would free from …/md34/e2/.node/clones/stale (dry-run)
{"root": "…/md34/e2", "reclaimed_bytes": 28672, "reclaimed_mib": 0.027, "job_ttl_hours": 24, "entries": […]}
EXIT=0
--- after dry-run: cache files still present? ---
  SURVIVED .cache/pip/payload
  SURVIVED .cache/uv/payload
  SURVIVED .cache/go-build/payload
  SURVIVED .npm/_cacache/payload
  SURVIVED .node/jobs/old/payload
  SURVIVED .node/clones/stale/payload
```

The `…/md34/e2/` prefix is an elision of `/home/kara/.hermes/cache/scratch/md25b/md34/e2/` in this and the following transcripts; the `entries` array is elided in transcript 2 and printed whole in transcript 3. Every other character is as printed.

Transcript 3 — check 3, the real run on the same tree, and what survived:

```
$ python3 -B scripts/reclaim_disk.py run --root "$R" --json; echo "EXIT=$?"
  reap  .cache/pip — 0.0 MB freed from …/md34/e2/.cache/pip (build cache)
  reap  .cache/uv — 0.0 MB freed from …/md34/e2/.cache/uv (build cache)
  reap  .cache/pre-commit — 0.0 MB freed from …/md34/e2/.cache/pre-commit (build cache)
  reap  .cache/go-build — 0.0 MB freed from …/md34/e2/.cache/go-build (build cache)
  reap  .npm/_cacache — 0.0 MB freed from …/md34/e2/.npm/_cacache (build cache)
  keep  .node/jobs/fresh — fresh (0.0h <= TTL 24h)
  reap  .node/jobs/old — 0.0 MB freed from …/md34/e2/.node/jobs/old (expired)
  keep  .node/clones/live — fresh (0.0h <= TTL 24h)
  reap  .node/clones/stale — 0.0 MB freed from …/md34/e2/.node/clones/stale (expired)
{"root": "…/md34/e2", "reclaimed_bytes": 28672, "reclaimed_mib": 0.027, "job_ttl_hours": 24, "entries": [{"name": ".cache/pip", "path": "…/md34/e2/.cache/pip", "bytes": 4096, "action": "reaped", "reason": "build cache"}, {"name": ".cache/uv", "path": "…/md34/e2/.cache/uv", "bytes": 4096, "action": "reaped", "reason": "build cache"}, {"name": ".cache/pre-commit", "path": "…/md34/e2/.cache/pre-commit", "bytes": 4096, "action": "reaped", "reason": "build cache"}, {"name": ".cache/go-build", "path": "…/md34/e2/.cache/go-build", "bytes": 4096, "action": "reaped", "reason": "build cache"}, {"name": ".npm/_cacache", "path": "…/md34/e2/.npm/_cacache", "bytes": 4096, "action": "reaped", "reason": "build cache"}, {"name": ".node/jobs/fresh", "path": "…/md34/e2/.node/jobs/fresh", "bytes": 0, "action": "kept", "reason": "fresh (0.0h <= TTL 24h)"}, {"name": ".node/jobs/old", "path": "…/md34/e2/.node/jobs/old", "bytes": 4096, "action": "reaped", "reason": "expired"}, {"name": ".node/clones/live", "path": "…/md34/e2/.node/clones/live", "bytes": 0, "action": "kept", "reason": "fresh (0.0h <= TTL 24h)"}, {"name": ".node/clones/stale", "path": "…/md34/e2/.node/clones/stale", "bytes": 4096, "action": "reaped", "reason": "expired"}]}
EXIT=0
--- survivors after real run ---
.
./.cache
./.cache/other
./.cache/other/keep.txt
./Documents
./Documents/notes.txt
./.node
./.node/clones
./.node/clones/live
./.node/clones/live/payload
./.node/crier.json
./.node/floor.toml
./.node/jobs
./.node/jobs/fresh
./.node/jobs/fresh/payload
./.node/node.json
./.npm
./repo
./repo/payload
--- assertion table ---
  REMOVED   .cache/pip
  REMOVED   .cache/uv
  REMOVED   .cache/pre-commit
  REMOVED   .cache/go-build
  REMOVED   .npm/_cacache
  REMOVED   .node/jobs/old
  SURVIVED  .node/jobs/fresh
  REMOVED   .node/clones/stale
  SURVIVED  .node/clones/live
  SURVIVED  .cache/other
  SURVIVED  repo
  SURVIVED  .node/node.json
  SURVIVED  .node/crier.json
  SURVIVED  .node/floor.toml
  SURVIVED  Documents
```

The five caches each had a single 4096-byte payload whose mtime was **the moment of the run**, and they were still reaped — that is the "no age gate" finding, measured. The identity files and `repo` were backdated 200 h and still survived, which is `PROTECTED` doing its job [scripts/reclaim_disk.py:35-38].

Transcript 4 — check 4, both directions of the mtime rule:

```
--- dir mtime = now, payload mtime = -100h ---
  dir=2026-11-05 11:56:19.262344467 -0500
  payload=2026-11-01 07:56:19.000000000 -0500
  keep  .node/clones/oldcontent — fresh (0.0h <= TTL 24h)
--- and the mirror: dir -100h, payload now ---
  reap  .node/clones/newcontent — 0.0 MB freed from …/md34/e15/.node/clones/newcontent (expired)
```

Transcript 5 — check 5, the second run:

```
$ python3 -B scripts/reclaim_disk.py run --root "$R"; echo "EXIT=$?"
  skip  .cache/pip — absent
  skip  .cache/uv — absent
  skip  .cache/pre-commit — absent
  skip  .cache/go-build — absent
  skip  .npm/_cacache — absent
  keep  .node/jobs/fresh — fresh (0.0h <= TTL 24h)
  keep  .node/clones/live — fresh (0.0h <= TTL 24h)
  note reclaim — nothing to reclaim
EXIT=0
```

Note the shape: an `absent` target prints the verb `skip` with the reason `absent` [scripts/reclaim_disk.py:148-153] [scripts/reclaim_disk.py:86-87], so a healthy node's second run is seven `skip`/`keep` rows and one note — indistinguishable at a glance from a run whose every safety guard fired.

Transcript 6 — check 6, symlinked target and symlinked job directory:

```
$ python3 -B scripts/reclaim_disk.py run --root "$R"; echo "EXIT=$?"
  skip  .cache/pip — symlink not followed
  skip  .cache/uv — absent
  skip  .cache/pre-commit — absent
  skip  .cache/go-build — absent
  skip  .npm/_cacache — absent
  skip  .node/jobs/old — symlink not followed
  skip  .node/clones — absent
  note reclaim — nothing to reclaim
EXIT=0
  outside/payload = untouched
  lrwxrwxrwx 1 kara kara 51 Nov  5 11:55 …/e4/.cache/pip -> …/md34/outside
  lrwxrwxrwx 1 kara kara 51 Nov  5 11:55 …/e4/.node/jobs/old -> …/md34/outside
```

`symlink not followed` is not in the module's vocabulary — the stored reason is `skipped:symlink` and the printer rewrites exactly that one string [scripts/reclaim_disk.py:155-156].

Transcript 7 — check 7, the partial deletion (D-3), then a second run:

```
$ python3 -B scripts/reclaim_disk.py run --root "$R" --json; echo "EXIT=$?"
  skip  .cache/pip — absent
  skip  .cache/uv — absent
  skip  .cache/pre-commit — absent
  skip  .cache/go-build/aa/link — symlink not followed
  keep  .cache/go-build — 0.0 MB freed from …/md34/e5/.cache/go-build (build cache)
  skip  .npm/_cacache — absent
  skip  .node/jobs — absent
  skip  .node/clones — absent
… "reclaimed_bytes": 8192 …
EXIT=0
--- what is left under .cache/go-build ---
  …/e5/.cache/go-build
  …/e5/.cache/go-build/aa
  …/e5/.cache/go-build/aa/link
--- second run (does it ever finish the job?) ---
  skip  .cache/go-build/aa/link — symlink not followed
  keep  .cache/go-build — build cache
  note reclaim — nothing to reclaim
```

Three things happen at once and only one of them is right: the two regular files are gone (correct), the directory survives because `complete` is false [scripts/reclaim_disk.py:74-76] [scripts/reclaim_disk.py:98] (safe but permanent — nothing ever retries, see the second run), and the row still says `freed … from …/go-build`, attributing bytes to a path that still exists. Note also that a **child** became its own row, so `entries` is not one row per root: `remove()` records any child its safety guard rejects [scripts/reclaim_disk.py:63-66] and the printer prints every entry [scripts/reclaim_disk.py:147-160].

Transcript 8 — check 8, the TTL boundary:

```
$ python3 -B scripts/reclaim_disk.py run --root "$R"; echo "EXIT=$?"
  skip  .cache/pip — absent
  …
  keep  .node/jobs/a_23h9 — fresh (23.9h <= TTL 24h)
  reap  .node/jobs/b_24h0 — 0.0 MB freed from …/md34/e6/.node/jobs/b_24h0 (expired)
  reap  .node/jobs/c_24h1 — 0.0 MB freed from …/md34/e6/.node/jobs/c_24h1 (expired)
  skip  .node/clones — absent
EXIT=0
  SURVIVED .node/jobs/a_23h9 (23.9h)
  REMOVED  .node/jobs/b_24h0
  REMOVED  .node/jobs/c_24h1
$ python3 -B scripts/reclaim_disk.py run --root "$R" --job-ttl-hours 0; echo "EXIT=$?"
  …
  reap  .node/jobs/justnow — 0.0 MB freed from …/md34/e6b/.node/jobs/justnow (expired)
```

Transcript 9 — check 10, the refusals:

```
$ python3 -B scripts/reclaim_disk.py run --root /; echo "EXIT=$?"
reclaim: root must be a directory other than /
EXIT=2
$ python3 -B scripts/reclaim_disk.py run --root /etc/hostname; echo "EXIT=$?"
reclaim: root must be a directory other than /
EXIT=2
$ python3 -B scripts/reclaim_disk.py run --root …/e8/absent; echo "EXIT=$?"
reclaim: root must be a directory other than /
EXIT=2
$ python3 -B scripts/reclaim_disk.py run --root "$R" --job-ttl-hours nan; echo "EXIT=$?"
reclaim: job TTL must be finite and nonnegative
EXIT=2
  (identical for -1 and for inf)
$ python3 -B scripts/reclaim_disk.py run
reclaim_disk.py run: error: the following arguments are required: --root
EXIT=2
$ python3 -B scripts/reclaim_disk.py
usage: reclaim_disk.py [-h] {targets,run} ...
reclaim_disk.py: error: the following arguments are required: command
```

`/etc/hostname` — a **regular file** — produces the same sentence as `/` and as a missing path, so the message names the rule but never the offending value [scripts/reclaim_disk.py:44-45].

Transcript 10 — check 11, the mid-run abort:

```
$ chmod 500 "$R/.cache/uv/locked"
$ python3 -B scripts/reclaim_disk.py run --root "$R" --json; echo "EXIT=$?"
reclaim: [Errno 13] Permission denied: '…/md34/e11/.cache/uv/locked/sub'
EXIT=2
--- state after the abort ---
  REMOVED  .cache/pip
  SURVIVED .cache/uv
  REMOVED  .cache/uv/locked/sub/payload
  SURVIVED .cache/go-build
  (`.npm/_cacache` did not exist in this tree)
```

Transcript 11 — check 12, one quantity in two units:

```
$ python3 -B scripts/reclaim_disk.py run --root "$R" --dry-run --json | sed -n '1p;$p'
  reap  .cache/pip — 10.5 MB would free from …/md34/e12/.cache/pip (dry-run)
{"root": "…/md34/e12", "reclaimed_bytes": 10485760, "reclaimed_mib": 10.0, "job_ttl_hours": 24, "entries": […]}
```

Transcript 12 — check 14, the module's own suite:

```
$ PYTHONDONTWRITEBYTECODE=1 python3 -B tests/test_reclaim.py
test_all_targets (__main__.Reclaim.test_all_targets) ... ok
test_dry_run_reports_same_bytes_without_removal (__main__.Reclaim.test_dry_run_reports_same_bytes_without_removal) ... ok
test_idempotence_and_json (__main__.Reclaim.test_idempotence_and_json) ... ok
test_invalid_roots_and_ttl (__main__.Reclaim.test_invalid_roots_and_ttl) ... ok
test_jobs_and_clones_ttl (__main__.Reclaim.test_jobs_and_clones_ttl) ... ok
test_protected_paths_survive_even_when_old (__main__.Reclaim.test_protected_paths_survive_even_when_old) ... ok
test_symlink_parent_and_nested_symlink (__main__.Reclaim.test_symlink_parent_and_nested_symlink) ... ok
test_symlinks_and_outside_survive (__main__.Reclaim.test_symlinks_and_outside_survive) ... ok
test_targets (__main__.Reclaim.test_targets) ... ok

----------------------------------------------------------------------
Ran 9 tests in 0.387s

OK
EXIT=0
```

Transcript 13 — check 15, the ladder leg's own lines, executed from scratch:

```
$ bash leg20.sh
20. reclaim runs before disk refusal, while check never reaps
  PASS  pip cache reaped before one final disk FAIL; admission still refuses
  PASS  check preserves pip bytes, counts one disk failure and continues preflight
  PASS  re-measure admits a recovered node without a stale FAIL row
  PASS  missing reclaimer fails closed with one counted row
  PASS  reclaim targets, TTL, symlink safety, protected files, dry-run and idempotence
LEG fails=0
EXIT=0
```

This is the leg's shipped lines 938-1009 verbatim plus a four-line preamble (`set -u`, `HERE`, `say`, `fails=0`) so it can run outside the full 3657-line suite; nothing in the copied lines was edited. The last row is the real `tests/test_reclaim.py` invoked by the gate [tests/selftest.sh:1005-1009].

Transcript 14 — check 16, this document's gate:

```
$ python3 scripts/master_doc_check.py docs/master --only 34- --strict; echo "EXIT=$?"
34-scripts-reclaim-disk-py.md                  VERIFIED   ok

1 module(s): 1 VERIFIED, 0 error(s), 0 warning(s), 10 fact(s) in the ledger
MASTER-DOC: PASS
EXIT=0
```

Transcript 15 — check 17, a cache entry that is a regular file:

```
$ echo notadir > "$R/.cache/uv"
$ python3 -B scripts/reclaim_disk.py run --root "$R"; echo "EXIT=$?"
  skip  .cache/pip — absent
  skip  .cache/uv — not a directory
  skip  .cache/pre-commit — absent
  skip  .cache/go-build — absent
  skip  .npm/_cacache — absent
  skip  .node/jobs — absent
  skip  .node/clones — absent
  note reclaim — nothing to reclaim
EXIT=0
$ ls -l "$R/.cache/uv"
-rw-rw-r-- 1 kara kara 8 Nov  5 11:55 …/md34/e7/.cache/uv
```

Transcript 16 — check 13, the walk that never terminates:

```
$ timeout 5 python3 -B - <<'PY'
import importlib.util, sys, pathlib
spec = importlib.util.spec_from_file_location("rd", sys.argv[1])
rd = importlib.util.module_from_spec(spec); spec.loader.exec_module(rd)
root = pathlib.Path(sys.argv[2]).resolve() / "e9"
print("root      =", root)
print("calling safety_reason(root, /etc/hostname) …", flush=True)
print("returned:", rd.safety_reason(root, pathlib.Path("/etc/hostname")))
PY
root      = /home/kara/.hermes/cache/scratch/md25b/md34/e9
calling safety_reason(root, /etc/hostname) …
EXIT=124 (124 = the 5 s timeout fired: the call never returned)
```

A control call in the same interpreter, `safety_reason(root, root)`, printed `skipped:outside-root` and returned immediately — so the guard exists and is correct, and the walk in front of it is what never finishes.

## 4. Metrics emitted

**NONE continuously, and none anywhere an aggregator can read.** The module is a one-shot CLI with no daemon, no log destination, no counter and no timing arithmetic; it samples the clock exactly once [scripts/reclaim_disk.py:49] and prints. What it does emit is a one-shot JSON document on stdout when `--json` is passed [scripts/reclaim_disk.py:163-164]:

| Field | Type | Meaning | Consumer |
|---|---|---|---|
| `root` | string | the canonicalised root actually walked, after `realpath` [scripts/reclaim_disk.py:43] [scripts/reclaim_disk.py:121] | the ladder discards it |
| `reclaimed_bytes` | int | the sum of `bytes` over **all** entries, which is bytes unlinked — not bytes of targets that disappeared [scripts/reclaim_disk.py:119] | nobody in-tree; it is the number a human would read |
| `reclaimed_mib` | float | `round(total / 1048576, 3)` [scripts/reclaim_disk.py:123] | **the ladder**, parsed from the last stdout line and printed in its disk PASS row [scripts/project-node.sh:218-225] |
| `job_ttl_hours` | float | the TTL as supplied, echoed back [scripts/reclaim_disk.py:124] | nobody in-tree; it is the only record of which window a run used |
| `entries` | list of 5-key dicts | one row per target and per safety-rejected child, with `name` (root-relative), `path` (absolute), `bytes`, `action` (`reaped`/`kept`/`skipped`/`absent`), `reason` [scripts/reclaim_disk.py:51-60] | nobody in-tree |

Why none is appropriate: the interesting events here are "a reap happened", "the reap freed N", and "admission was refused after the reap" — and the third is the ladder's row, not this module's. The module has no rate, no queue and no latency to instrument, and its durable record is the operator's terminal plus the ladder's PASS/FAIL row. Two consequences are worth stating because the number *is* consumed: `reclaimed_mib` is a MiB figure while the printed rows use decimal MB [scripts/reclaim_disk.py:159] (§6 D-5), and it counts bytes from targets that survived (§6 D-6), so the ladder's `freed N MiB` is an upper bound on space actually recovered.

## 5. Log lines it can generate

Every line is a `print` to stdout except the `reclaim:` line, which goes to **stderr** and carries whichever message the refusal produced [scripts/reclaim_disk.py:144-146]. There is no level, no logger, no timestamp and no destination other than the invoking terminal or the ladder's captured buffer [scripts/project-node.sh:212]. The row shape is `  {action}  {name} — {reason}` with two spaces after the action [scripts/reclaim_disk.py:160]; in the table `<root>` substitutes for the absolute scratch root printed in full in §3, and every other character is as measured. Tag = **evidentiary** when the line appears in a transcript in §3, **descriptive** when it is a literal string in the source that no recorded run reached.

| Level | Line (verbatim) | Emitted when | Kind |
|---|---|---|---|
| stdout | `  reap  .cache/pip — 0.0 MB freed from <root>/.cache/pip (build cache)` | a `BUILD_CACHES` entry exists, is a real directory, and every child was removed [scripts/reclaim_disk.py:94-100] [scripts/reclaim_disk.py:102-103] | evidentiary |
| stdout | `  reap  .cache/pip — 0.0 MB would free from <root>/.cache/pip (dry-run)` | the same, under `--dry-run`; the reason is the literal `dry-run` [scripts/reclaim_disk.py:99] and the verb becomes `would free` [scripts/reclaim_disk.py:158] | evidentiary |
| stdout | `  reap  .node/jobs/old — 0.0 MB freed from <root>/.node/jobs/old (expired)` | an aged child whose mtime is older than the TTL [scripts/reclaim_disk.py:90-92] [scripts/reclaim_disk.py:99] | evidentiary |
| stdout | `  reap  .node/clones/newcontent — 0.0 MB freed from <root>/.node/clones/newcontent (expired)` | the same for clones; the two parents share one branch [scripts/reclaim_disk.py:104-111] | evidentiary |
| stdout | `  keep  .node/jobs/fresh — fresh (0.0h <= TTL 24h)` | `aged` is true and `(now − mtime)/3600 <= ttl`; both numbers are interpolated, the age to one decimal [scripts/reclaim_disk.py:90-92] | evidentiary |
| stdout | `  keep  .cache/go-build — 0.0 MB freed from <root>/.cache/go-build (build cache)` | the directory survived because a child was refused, yet the bytes that *were* unlinked are still reported against it [scripts/reclaim_disk.py:96-100] | evidentiary |
| stdout | `  skip  .cache/uv — absent` | the target does not exist; action `absent`, reason `absent`, printed as `skip` [scripts/reclaim_disk.py:86-87] [scripts/reclaim_disk.py:148-153] | evidentiary |
| stdout | `  skip  .cache/uv — not a directory` | the target exists and is not a directory, so it is never unlinked — this is the branch that makes a stray cache *file* immortal [scripts/reclaim_disk.py:88-89] | evidentiary |
| stdout | `  skip  .node/jobs — not a directory` | the whole aged parent exists as a regular file or other non-directory [scripts/reclaim_disk.py:112-118] | evidentiary |
| stdout | `  skip  .cache/pip — symlink not followed` | any component of the candidate, or the candidate itself, is a symlink [scripts/reclaim_disk.py:29-31]; the stored reason `skipped:symlink` is rewritten for display [scripts/reclaim_disk.py:155-156] | evidentiary |
| stdout | `  skip  .cache/go-build/aa/link — symlink not followed` | a symlink **inside** a directory being removed becomes its own row, because `remove()` records children it refuses [scripts/reclaim_disk.py:63-66] | evidentiary |
| stdout | `  skip  .cache/pip — skipped:protected` | a candidate resolves onto `repo`, `.node/node.json`, `.node/crier.json` or `.node/floor.toml` [scripts/reclaim_disk.py:22] [scripts/reclaim_disk.py:35-38]; the string is not rewritten by the printer, so it prints raw | descriptive — no fixed target and no `AGED_PARENTS` child can be a protected name, so no run in §3 could reach it |
| stdout | `  skip  .cache/pip — skipped:outside-root` | `real == root or root not in real.parents` [scripts/reclaim_disk.py:33-34] | descriptive, and **unreachable** for a genuinely outside path: D-1 makes the walk hang before this test runs |
| stdout | `  note reclaim — nothing to reclaim` | `reclaimed_bytes` is falsy — including a run that skipped everything, so "nothing to reclaim" also means "everything was refused" [scripts/reclaim_disk.py:161-162] | evidentiary |
| stdout | the `targets` list: `.cache/pip`, `.cache/uv`, `.cache/pre-commit`, `.cache/go-build`, `.npm/_cacache`, `.node/jobs/<directory>`, `.node/clones/<directory>` | the `targets` subcommand, one per line, `<directory>` literal [scripts/reclaim_disk.py:139-141] | evidentiary |
| stdout | `{"root": …, "reclaimed_bytes": …, "reclaimed_mib": …, "job_ttl_hours": …, "entries": […]}` | `--json`, after all rows; the ladder parses this last line [scripts/reclaim_disk.py:163-164] [scripts/project-node.sh:218] | evidentiary |
| stderr | `reclaim: root must be a directory other than /` | `/`, a regular file, or an absent path as `--root` [scripts/reclaim_disk.py:44-45] [scripts/reclaim_disk.py:145] | evidentiary |
| stderr | `reclaim: job TTL must be finite and nonnegative` | `--job-ttl-hours` is `nan`, `inf` or negative [scripts/reclaim_disk.py:46-47] [scripts/reclaim_disk.py:145] | evidentiary |
| stderr | `reclaim: [Errno 13] Permission denied: '<path>'` | any `OSError` escaping the walk — the message is `str(exc)` of whatever the filesystem raised [scripts/reclaim_disk.py:144-146] [scripts/reclaim_disk.py:77-79] | evidentiary |
| stderr | `reclaim_disk.py run: error: the following arguments are required: --root` | argparse, not this module [scripts/reclaim_disk.py:134] | evidentiary |
| stderr | `reclaim_disk.py: error: the following arguments are required: command` | argparse, bare invocation [scripts/reclaim_disk.py:131] | evidentiary |

The row vocabulary is denser than the outcome vocabulary, and that is the point of the table: `skip` carries four distinct meanings (`absent`, `not a directory`, `symlink not followed`, and the raw `skipped:*` reasons) and `keep` carries two (`fresh`, and a failed partial removal), so the word on the left of the dash never tells an operator whether anything happened.

## 6. Failure modes

Direction is the module's measured behaviour. **fail closed** = the run stops or exits non-zero; **fail open** = the deletion or the claim proceeds on weaker evidence than the operator would assume; **degraded** = the run continues with a wrong or missing row; **no direction** = the run neither stops nor continues.

| Failure | Presents as | Direction | Distinguished from | Recovery |
|---|---|---|---|---|
| **D-1** a candidate path that is not a lexical descendant of the root | `safety_reason` never returns: the parent walk climbs to `/` and `Path('/').parent == Path('/')`, so `while current != root` spins forever [scripts/reclaim_disk.py:29-32]. Measured: 5 s timeout, `EXIT=124` (transcript 16) | **no direction — it hangs.** No row, no exit, no refusal: a caller that waits waits forever | The containment test it is reached *after* would have returned `skipped:outside-root` [scripts/reclaim_disk.py:33-34]; `safety_reason(root, root)` does return that, which is the only reachable path to the string | Not reachable from the CLI today — every candidate is built as `root_path / name` or as a child of one [scripts/reclaim_disk.py:103] [scripts/reclaim_disk.py:111] [scripts/reclaim_disk.py:70] — so this is a library-level hang for any future importer, and it is why the outside-root guard is dead code. Fix: bound the walk (`while root not in current.parents and current != current.parent`) or run the containment test first |
| **D-2** a build cache in active use | the entire cache is deleted, with no age test and no size test [scripts/reclaim_disk.py:82] [scripts/reclaim_disk.py:102-103]. Measured: a payload with mtime = the moment of the run was reaped (§3, check 3) | **fail open on safety**: the run does exactly what it says, on data that is not stale, and any concurrent `pip`, `uv`, `pre-commit`, `go build` or `npm` is broken mid-flight | A job or clone directory of the same age is *kept* by the TTL branch [scripts/reclaim_disk.py:90-92], so the two halves of the surface disagree about what "in use" means | none: the cache is rebuilt by re-downloading. An operator who wants less can pass a root that excludes `.cache`, but then `.node` reaping is lost too |
| **D-3** a symlink anywhere inside a cache directory | the directory is emptied of regular files but survives, `action` is `kept` with non-zero `bytes`, and the row still says `freed … from <dir>` [scripts/reclaim_disk.py:70-76] [scripts/reclaim_disk.py:96-100]. Measured: 8192 bytes gone, `.cache/go-build/aa/link` and the directory left, second run `nothing to reclaim` (check 7) | **degraded, permanently**: partial deletion reported as progress, and because the same symlink blocks every retry, the remaining tree is never reaped by any later run | A fully-reaped cache records `reaped` and its directory is gone [scripts/reclaim_disk.py:74-75]; here the directory still exists | manual `rm -rf` of the offending symlink, then re-run. Nothing in the module escalates or names the blocker as the reason the directory survived |
| **D-4** an `OSError` on one subtree (EACCES, EBUSY on a mount point, EROFS) | one stderr line and exit 2 with **no JSON and no per-entry rows**, because the exception escapes `reclaim()` before the print loop [scripts/reclaim_disk.py:144-146] [scripts/reclaim_disk.py:147]. Measured: `.cache/pip` already deleted, `.cache/go-build` never reached, `.cache/uv` half-emptied (check 11) | **fail closed with the accounting lost**: the deletions that did happen are unreported, so the operator sees a failure and cannot see what it cost. The ladder renders it as `  FAIL  disk_floor — reclaim failed: <message>` and stops with `NODE: FAIL (1)` [scripts/project-node.sh:212-216] | A *validation* refusal prints a `reclaim:` sentence and also exits 2 [scripts/reclaim_disk.py:44-47], so exit 2 alone does not distinguish "nothing was attempted" from "half the host was already reaped" | re-run after fixing the permission; the second run starts from the partially-reaped state and reports `absent` for what it already removed |
| **D-5** the number the operator reads is not the number the ladder reads | the printed row says `10.5 MB`, the JSON on the same run says `"reclaimed_mib": 10.0` [scripts/reclaim_disk.py:159] [scripts/reclaim_disk.py:123]. Measured (check 12) | **fail open on reporting**: two units, one label each, 4.86 % apart, and the ladder prints the MiB figure with the `MiB` label [scripts/project-node.sh:225] while the human rows use the decimal one | Only visible side by side: neither line is wrong on its own | read `reclaimed_bytes` and convert, or fix the printer to `1048576` |
| **D-6** bytes from a target that survived | `reclaimed_bytes` sums every entry's `bytes`, including a `kept` entry whose files were unlinked but whose directory remains [scripts/reclaim_disk.py:96-100] [scripts/reclaim_disk.py:119]. Measured: 8192 with `action: kept` (check 7) | **fail open on reporting**: the figure means "bytes unlinked", the ladder's row means "disk recovered", and on a tree full of nested symlinks the gap is the whole difference | A normal run's total equals the sum of its `reaped` rows exactly, which is why the suite's byte assertions never see it [tests/test_reclaim.py:46] | interpret `reclaimed_mib` as an upper bound, or filter `entries` for `action == "reaped"` |
| **D-7** any directory that is not `/` as `--root` | the run reaps whatever `.cache/pip` and `.node/jobs` exist under it [scripts/reclaim_disk.py:44-45] | **fail open on scope**: the only root validation is "is a directory and is not `/`" [scripts/reclaim_disk.py:43-45]; there is no requirement that it be a home, a node home, or that it be owned by the caller | A missing or non-directory root is refused [scripts/reclaim_disk.py:44-45]; a wrong-but-valid directory is not | the only caller passes `"$HOME"` [scripts/project-node.sh:212]; anything else is an operator choice the module will honour |
| **D-8** a TTL an operator sets too low | `--job-ttl-hours 0` reaps a job directory created seconds earlier; the only floor is `>= 0` [scripts/reclaim_disk.py:46-47] [scripts/reclaim_disk.py:135]. Measured (check 8, second half) | **fail open on safety by configuration**: the knob is documented and unbounded downward, so a "reap more aggressively" incident is one flag away | `24` is the default in two places [scripts/reclaim_disk.py:42] [scripts/reclaim_disk.py:135], so nothing reaches 0 accidentally | pass the default, or a value matched to the slowest job the node runs |
| The node has no reclaimer at all | `  FAIL  disk_floor — reclaimer missing or unreadable: <path>` then `NODE: FAIL (1)`, before any reaping is attempted [scripts/project-node.sh:207-211] | **fail closed**, and the refusal is correct: admission is denied rather than granted on an unmeasured disk | A reclaimer that runs and fails prints `reclaim failed: …` instead [scripts/project-node.sh:213] | restage the file beside `project-node.sh` [scripts/node-create.sh:23]; the packager refuses a staged set whose entry point references an unstaged file [scripts/node-create.sh:30-47] |
| The reap frees less than the floor needs | `  FAIL  disk — <free> GB free after reclaim < floor <n> GB at <home> (freed <n> MiB)` then `NODE: FAIL (disk admission)` [scripts/project-node.sh:226-229] | **fail closed**, after the deletion has already happened — the host loses its caches and still refuses | A reap that succeeds prints `PASS disk — … after reclaim (freed <n> MiB; …)` [scripts/project-node.sh:225] | free space by other means, or lower the floor; the module has no second tier (no `~/.cargo`, no `node_modules`, no image cache) to escalate to |
| Disk was already above the floor | the reclaimer is never invoked: `--apply` PASSes the free-space test first [scripts/project-node.sh:202-205] | **fail closed in the safe direction** — the deletion only runs on pressure | `--check` never reaps at all and only notes what `--apply` would do [scripts/project-node.sh:199-200] | none needed |
| Two runs at once (two `--apply` on one node) | the loser sees `absent` for caches already removed and `fresh` for job dirs it still owns; exit 0, `reclaimed_bytes` lower [scripts/reclaim_disk.py:86-87] | **degraded but harmless**: no error, no double-removal, and the byte figure is split between the two runs | `reclaimed_bytes == 0` with rows present is the fingerprint (check 5) | none: idempotence is measured (check 5) and asserted [tests/test_reclaim.py:118-130] |
| A target that exists as a regular file | `  skip  .cache/uv — not a directory`, forever [scripts/reclaim_disk.py:88-89]. Measured (check 17) | **degraded**: a wrongly-shaped cache path is never removed, never reported as an error, and never counts toward the total | `absent` means nothing there; `not a directory` means something is there and is untouchable | remove it by hand; the module will not |

## 7. Environment and settings it reads

**Environment variables: none.** `grep -n 'environ\|getenv\|expanduser\|HOME' scripts/reclaim_disk.py` returns nothing, and the module never expands `~` — the root arrives as an absolute-or-relative argv value and is canonicalised with `realpath` [scripts/reclaim_disk.py:43]. There is no config file, no `$XDG_CACHE_HOME`, no `$HOME` fallback. Everything it deletes is a literal relative path joined onto `--root`.

Flags and arguments:

| Setting | Where read | Default | Effect of missing |
|---|---|---|---|
| subcommand, one of `targets` / `run`, **required** | `add_subparsers(dest="command", required=True)` [scripts/reclaim_disk.py:131] | none — a bare invocation is a usage error, exit 2 | argparse prints `the following arguments are required: command` and exits 2 |
| `targets` | [scripts/reclaim_disk.py:132] | — | prints the fixed list and exits 0 without touching the disk [scripts/reclaim_disk.py:139-141] |
| `run --root <dir>` | [scripts/reclaim_disk.py:134] | **none — required**; the ladder supplies `"$HOME"` [scripts/project-node.sh:212] | argparse refuses with exit 2; there is no implicit home, which is what stops a bare `run` from reaping the wrong tree |
| `run --job-ttl-hours <float>` | [scripts/reclaim_disk.py:135] | `24` in two places — the flag and the function signature [scripts/reclaim_disk.py:42] | 24 h. Must be finite and `>= 0` [scripts/reclaim_disk.py:46-47] |
| `run --dry-run` | [scripts/reclaim_disk.py:136] | off | the run mutates. On, it walks and counts but neither unlinks [scripts/reclaim_disk.py:78-79] nor `rmdir`s [scripts/reclaim_disk.py:74-75]; measured byte-identical to the real run (check 2) |
| `run --json` | [scripts/reclaim_disk.py:137] | off | the JSON line is not printed and only the ladder's `reclaimed_mib` consumer breaks [scripts/project-node.sh:218] |

**Every path it deletes from**, with its age condition — the complete list, seven roots:

| # | Root, relative to `--root` | Granularity | Age condition | Source |
|---|---|---|---|---|
| 1 | `.cache/pip` | whole subtree, recursively | **none** — `aged` is false, so the TTL branch is skipped | [scripts/reclaim_disk.py:15] [scripts/reclaim_disk.py:102-103] |
| 2 | `.cache/uv` | whole subtree | **none** | [scripts/reclaim_disk.py:16] |
| 3 | `.cache/pre-commit` | whole subtree | **none** | [scripts/reclaim_disk.py:17] |
| 4 | `.cache/go-build` | whole subtree | **none** | [scripts/reclaim_disk.py:18] |
| 5 | `.npm/_cacache` | whole subtree | **none** | [scripts/reclaim_disk.py:19] |
| 6 | `.node/jobs/<child>` | each **immediate child** only; a grandchild is never a target | `(now − child.mtime)/3600 > ttl` | [scripts/reclaim_disk.py:21] [scripts/reclaim_disk.py:110-111] |
| 7 | `.node/clones/<child>` | each immediate child only | `(now − child.mtime)/3600 > ttl` | [scripts/reclaim_disk.py:21] [scripts/reclaim_disk.py:110-111] |

Age thresholds, precisely: one threshold, `--job-ttl-hours`, default 24 [scripts/reclaim_disk.py:42] [scripts/reclaim_disk.py:135], compared as `age <= ttl → keep` and therefore `age > ttl → reap` [scripts/reclaim_disk.py:90-92]. It applies **only** to roots 6 and 7, to the directory's own mtime, and to nothing inside a reaped cache. There is no size threshold anywhere: the smallest cache is reaped as eagerly as the largest, and the walk never stops early once enough space has been freed, so a sub-floor `--apply` always takes all seven.

Never touched, and why: `PROTECTED` is `repo`, `.node/node.json`, `.node/crier.json`, `.node/floor.toml` [scripts/reclaim_disk.py:22], refused by exact match or as an ancestor of the resolved path [scripts/reclaim_disk.py:35-38]; `.cache` itself and every unnamed entry in it (`.cache/other`, `.cache/huggingface`, …) are outside `BUILD_CACHES` [scripts/reclaim_disk.py:14-20]; everything outside `.npm/_cacache` under `.npm` is unnamed. Measured: `.cache/other/keep.txt` and `Documents/notes.txt` were untouched, and `repo/`, `.node/node.json`, `.node/crier.json` and `.node/floor.toml` survived a run in which they were 200 h old (check 3).

Also never read: no lock file, no PID file, no state, no `mtime` bookkeeping of its own — so there is no record between runs of what it deleted, and nothing to reconcile after a crash.

## 8. Evidence of record

- **Measured 2026-11-05**, clean worktree of `d8c7796` (`~/proj-wt-md-34d`), Linux x86_64, Python 3.14.4: every transcript in §3 is literal terminal output from this session, in the order listed, and every root was a scratch tree under `$TMPDIR` — no real cache and no real `$HOME` was ever passed to the module. Checks 1-6, 8-10 and 14-17 pass as specified; checks 7, 11, 12 and 13 are the measurements that produced D-3, D-4, D-5 and D-1.
- **The removal set was established from source, not from the spec**: the seven roots are the three module constants read directly [scripts/reclaim_disk.py:14-22] and then confirmed by a `targets` invocation whose output is transcript 1 — so this document's list and the module's own list are the same list, checked against each other.
- **The dry-run is the load-bearing safety property and it is measured, not asserted**: the same nine-target tree reported 28672 bytes in preview and 28672 bytes when really reaped, and in the preview every one of the six probe files still existed (§3, check 2). That is the only reason a deleter of this shape is reviewable at all; the corresponding process gap — nothing in automation calls it, because the ladder passes only `run --root "$HOME" --json` [scripts/project-node.sh:212] — is recorded in §1 and §6.
- **The suite that covers this file**: `tests/test_reclaim.py`, 154 lines, 9 tests, run green here (transcript 12) and wired into the repo's gate [tests/selftest.sh:1005-1009]. Its assertions are byte totals, target existence, symlink survival, protected survival, exit codes, idempotence and dry-run parity [tests/test_reclaim.py:42-150]; it does not assert the **row text**, which the shell leg does by prefix [tests/selftest.sh:952-953], and it does not touch the four defects D-1/D-3/D-4/D-5.
- **The ladder integration is measured end to end**: the shipped leg's own lines, run from scratch, print five PASS rows and `fails=0` (transcript 13), including the ordering claim — `reap` before the single `FAIL disk —`, admission still refused, and `--check` leaving the pip bytes intact.
- **The evidence discipline this document follows** — a row closes only with a re-runnable command in its evidence, never with a summary or a commit message — is the project's own rule [docs/master/_facts.md:21] (fact: FACT-10), and the project's disk rule that makes this module routine rather than exotic is rule 12 of AGENTS.md [AGENTS.md:49].
- **Not measured, and said so**: the full `tests/selftest.sh` run (3657 lines, other legs unrelated to this module) was not executed in this session; the module's own leg was executed instead, verbatim, from a four-line preamble (transcript 13). `D-2`'s concurrent-use arm was not driven by a real `pip` process — the finding is the absence of an age test in source [scripts/reclaim_disk.py:102-103] plus the measured deletion of a just-written payload, not a demonstrated corrupted install.

Defects measured while filling this section (documented, **not** fixed — `scripts/` is out of scope for this task):

1. **D-1 — `safety_reason` can spin forever, and its outside-root guard is dead.** The parent walk [scripts/reclaim_disk.py:29-32] has no termination condition other than reaching `root`; for any path that is not a lexical descendant, `Path('/').parent` is `Path('/')` and the loop never ends. Measured: a library call with `/etc/hostname` did not return within 5 s (`EXIT=124`, check 13), while `safety_reason(root, root)` returns `skipped:outside-root` — so the only reachable case of the guard at [scripts/reclaim_disk.py:33-34] is the one where the path *is* the root. Not reachable through the CLI today because candidates are always constructed under the root [scripts/reclaim_disk.py:103] [scripts/reclaim_disk.py:111], but the module exposes `reclaim()` and `safety_reason()` as importable API and `tests/test_reclaim.py` already imports it [tests/test_reclaim.py:16].
2. **D-2 — build caches have no age gate and no size threshold.** `target()` is called without `aged` for every cache [scripts/reclaim_disk.py:102-103], so the TTL branch [scripts/reclaim_disk.py:90-92] is bypassed and `remove()` runs unconditionally [scripts/reclaim_disk.py:94]. Measured: five caches whose payloads were written at the moment of the run were all reaped (check 3). The spec says these are "removed whole" [specs/NODE.md:117-118], so the code matches the spec — the defect is that the contract has no notion of a cache in use, while the jobs branch does.
3. **D-3 — one symlink inside a cache strands the whole directory.** `remove()` returns `complete = False` when any child is refused [scripts/reclaim_disk.py:70-76], so `rmdir` is skipped [scripts/reclaim_disk.py:74-75] and the entry is recorded as `kept` [scripts/reclaim_disk.py:98] — but the regular files beside the symlink have already been unlinked. Measured: 8192 bytes gone, `.cache/go-build/aa/link` and the directory left, and a second run reported `nothing to reclaim` (check 7). The directory can never be reaped by this module again, and the row that reports the partial deletion still reads `freed … from <dir>`.
4. **D-4 — an `OSError` aborts the run with all accounting lost.** Any filesystem error escapes `reclaim()` and is caught in `main` [scripts/reclaim_disk.py:144-146] **before** the print loop and the JSON [scripts/reclaim_disk.py:147-164], so a run that already deleted several caches reports only `reclaim: [Errno 13] Permission denied: …` and exit 2. Measured with a mode-500 subtree: `.cache/pip` removed, `.cache/uv` half-emptied, `.cache/go-build` never reached, no rows, no JSON (check 11). The ladder's only recourse is `bad "disk_floor" "reclaim failed: $RECLAIM"` [scripts/project-node.sh:213], which folds stdout and stderr into one FAIL.
5. **D-5 — decimal MB in the rows, binary MiB in the JSON.** The printer divides by `1000000` and labels the result `MB` [scripts/reclaim_disk.py:159]; the JSON divides by `1048576` and labels it `reclaimed_mib` [scripts/reclaim_disk.py:123]. Measured: 10 485 760 bytes printed as `10.5 MB` and serialised as `10.0` (check 12), a 4.86 % divergence on the one number the ladder shows the operator [scripts/project-node.sh:225].
6. **D-6 — `reclaimed_bytes` counts bytes unlinked, not targets reclaimed.** The total sums every entry's `bytes` [scripts/reclaim_disk.py:119], including a `kept` directory whose contents were partly deleted [scripts/reclaim_disk.py:96-100]. Measured: `reclaimed_bytes` 8192 with `action: kept` and the directory still present (check 7). The ladder prints this figure as `freed <n> MiB` in a PASS row [scripts/project-node.sh:225], so an inflated figure is the evidence that admission was legitimate.
7. **D-7 — `--root` is validated only as "a directory that is not `/`".** [scripts/reclaim_disk.py:43-45]. Any directory — another user's home, a shared mount, a scratch tree — will have its `.cache/pip` and its `.node/jobs/*` reaped if permissions allow. The only guard is the caller's discipline [scripts/project-node.sh:212]. Not demonstrated against a real foreign home, by design: the finding is the absent check, and running it against someone's home is the harm.
8. **D-8 — the TTL has no floor but zero.** `--job-ttl-hours 0` is accepted [scripts/reclaim_disk.py:46-47] and reaps every job and clone directory regardless of age — measured on a directory created seconds earlier (check 8). Combined with D-2 there is no configuration in which this module preserves fresh state.
9. **D-9 — `skip` conflates four outcomes and `keep` conflates two.** Four distinct reasons print as `skip` (`absent`, `not a directory`, `symlink not followed`, and the raw `skipped:*`) and two print as `keep` (`fresh (…)`, and a directory that could not be fully emptied) [scripts/reclaim_disk.py:148-160]. A first run against a populated tree and a second run against the same tree both fill the screen with `skip` rows, and the two states — "already done" and "refused" — are only separable by reading the text after the dash.
10. **D-10 — nothing rehearses the deletion set in automation, and nothing records what was deleted.** `--dry-run` exists [scripts/reclaim_disk.py:136] and is measured non-destructive (check 2), but the ladder's single invocation passes only `run --root "$HOME" --json` [scripts/project-node.sh:212] and `--check` prints one prose note instead of the set [scripts/project-node.sh:200]. The module keeps no state of its own (§7), so after an unattended sub-floor `--apply` the only record of what was removed is the captured stdout the ladder echoes at [scripts/project-node.sh:217] — which is discarded when the run fails under D-4.
