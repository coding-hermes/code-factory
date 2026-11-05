# 32. scripts/node_seed_drift.py

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/node_seed_drift.py` — 554 lines [scripts/node_seed_drift.py:1] |
| Repository | `code-factory` |
| Revision | `d8c7796` (`origin/main`, 2026-11-05) — the tree every locator below was measured against |
| Status | **VERIFIED — 185 locator citations (114 distinct file:line pairs), all resolving; cites fact: FACT-01; every state driven on a real applied seed (clean PASS, content drift FAIL, deletion FAIL, absent record WARN/FAIL, corrupt record WARN, valid-JSON-without-`files` WARN, empty record PASS, missing instrument WARN) and the two verifiers measured against each other; six defects in §8** |

## 1. Purpose and why it matters

- What it is: a **wrapper around another script's verdict**, not a second implementation of it. It
  runs `scripts/node_seed.py check` "where the node is" and folds one row named `seed_drift` into
  the verifier [scripts/node_seed_drift.py:10-26]. The docstring is explicit that "the wrapper does
  not reimplement the digest comparison, it delegates to scripts/node_seed.py and parses its rows,
  so the two cannot drift apart" [scripts/node_seed_drift.py:24-26].
- **What it compares against**: one file, the record the seeder left behind —
  `$HOME/.hermes/seed-applied.json` [scripts/node_seed_drift.py:64], built as
  `os.path.join(home, RECORD_REL)` in local mode [scripts/node_seed_drift.py:287] and as
  `"$HOME/.hermes/seed-applied.json"` on the node [scripts/node_seed_drift.py:107]. The comparison
  itself is the seeder's: for every `record["files"][i]`, hash `$HOME/.hermes/<path>` and compare to
  the recorded sha256 [scripts/node_seed.py:227-236]. The record's other keys — `built_at`,
  `repo_root`, `manifest`, `total_bytes`, `applied_at`, `applied_to` — are read by neither side
  [scripts/node_seed.py:139-145] [scripts/node_seed.py:208-215].
- **What counts as drift**: exactly two things, both content-level — a file whose sha256 differs
  from the record, and a file the record names that is absent [scripts/node_seed.py:229-236]. Both
  are counted and both exit 1 [scripts/node_seed.py:238-240]. Measured: a mode change is **not**
  drift and an extra file is **not** drift (§3 rows 5 and 6) — the record is a whitelist of paths to
  hash, never a manifest of what must exist.
- Why it exists at all: the seeder could already refuse a drifted seed, "but nothing on the control
  host ever ran it, and provisioning deletes the node-side copy of the seeder after it applies", so
  a hand-edited prompt passed every arm `verify-node.sh` had [scripts/node_seed_drift.py:4-8]. The
  verifier now carries the leg as step 6 [scripts/verify-node.sh:148-161]. What the seed carries is
  what the node's foreman runs, and the foreman runs on the node, never on the control host
  (fact: FACT-01) — which is why the check has to execute over there.
- Two modes, one verdict: `--agent ID --server NAME` probes a real node through **one** `bunker
  exec` round trip [scripts/node_seed_drift.py:13-19]; `--home DIR` measures a local seed directory
  with "no bunker, no network, no database" [scripts/node_seed_drift.py:20-22]. Both funnel into the
  same finding constructors [scripts/node_seed_drift.py:190-278].
- **What breaks if it is absent**: the verifier's leg is guarded by `[ ! -r "$SEEDCHK" ]` and fails
  closed with `  FAIL  seed_drift — $SEEDCHK missing — the node's seed is unmeasured`
  [scripts/verify-node.sh:161-164], which increments `FAILED` [scripts/lib.sh:7] and produces
  `VERIFY: FAIL (1)`, exit 1 [scripts/verify-node.sh:191]. Measured, §3 row 15.
- **What breaks if it lies**: the direction is two-sided, and that is the whole story here.
  *Inside its own process* the tool cannot print `RESULT: PASS` without having counted files: PASS
  requires the child's exit 0 **and** a non-`None` count [scripts/node_seed_drift.py:334-335], and
  the count comes only from the seeder's own `N files present and matching` row
  [scripts/node_seed_drift.py:159] [scripts/node_seed_drift.py:172-175]; the remote path applies the
  same conjunction to `SEED_RC` [scripts/node_seed_drift.py:434-435]. *At the gate*, a WARN is not a
  failure: `warn` neither increments `FAILED` nor sets `UNVERIFIED` [scripts/lib.sh:8]
  [scripts/verify-node.sh:37], so a node whose seed record cannot be read produces
  `  WARN  seed_drift — …` and then **`VERIFY: PASS`, exit 0** [scripts/verify-node.sh:183]
  [scripts/verify-node.sh:197] — measured, §3 rows 22-24.
- **The green that is worse than a WARN**: a record whose `files` list is empty is a PASS. Measured
  end to end from the real seeder: `build` prints `  PASS  seed_manifest — 0 files declared` when
  every glob misses [scripts/node_seed.py:83-90] [scripts/node_seed.py:132], `apply` writes it, and
  the drift tool then reports `  PASS  seed_drift — …: 0 seeded files present and matching`
  [scripts/node_seed_drift.py:190-194] — a drift check that has measured nothing, and says so only
  in the numeral. §3 row 8, §8 defect 4.
- Blast radius of one run: one `bunker exec`, two temp files created on the node and removed inside
  that same exec [scripts/node_seed_drift.py:114-125]; nothing is written on the control host.

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `python3` (stdlib only) | the interpreter running the wrapper; the file states "stdlib only" [scripts/node_seed_drift.py:42] | control host | a syntax/import failure is the only signal; nothing probes it |
| `scripts/node_seed.py` — the sibling seeder | in-tree | **the same directory as the wrapper**, resolved from `os.path.realpath(__file__)` [scripts/node_seed_drift.py:478-479] [scripts/node_seed_drift.py:72] | **mode-dependent, and only one side names it.** Bunker mode: probed with `os.path.isfile` and refused as `  WARN  seed_drift — %s is missing — the check could not be staged`, exit 3 [scripts/node_seed_drift.py:372-375]. Local mode: **not probed** — the child fails and the WARN says `node_seed.py check printed no verdict (exit 2)` [scripts/node_seed_drift.py:344-346]. Measured both ways, §3 rows 13 and 14 |
| `bunker` client | resolved once at import, by `shutil.which("bunker") or "bunker"` [scripts/node_seed_drift.py:56] | `PATH` on the control host, bunker mode only | `FileNotFoundError` from `subprocess.run` is caught as `OSError` [scripts/node_seed_drift.py:87-88], then reported as `  WARN  seed_drift — bunker exec failed: FileNotFoundError: …`, exit 3 — measured, §3 row 17. The `or "bunker"` fallback means `which` failing does not raise; the failure surfaces at exec time |
| `sh`, `python3`, `mktemp`, `cat`, `rm` **on the node** | POSIX | inside the agent, under `sh -lc` [scripts/node_seed_drift.py:379] | each is used unguarded in the remote template [scripts/node_seed_drift.py:105-126]; a missing `python3` makes the RECORD probe fail and is then reported as `does not parse` (the wrong reason — §8 defect 3) |
| `/tmp` writable **on the node** | — | inside the agent | `mktemp /tmp/node-seed-check-XXXXXX` is unguarded [scripts/node_seed_drift.py:114-115]; an unwritable `/tmp` leaves `STAGED` empty, the heredoc lands nowhere, and the check exits non-zero with shell text [scripts/node_seed_drift.py:116-121] |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `__future__.annotations` | stdlib | postponed evaluation of `list` / `dict` / `tuple` annotations [scripts/node_seed_drift.py:45] | none at runtime |
| `argparse` | stdlib | parses the six flags, exits 2 on an unknown one, and `main` returns its own `EXIT_USAGE` for the five refusals it checks itself [scripts/node_seed_drift.py:481-525] | the wrapper's own exit 2 is what the gate folds into WARN [scripts/verify-node.sh:177-183], so a future flag rename degrades silently to "unmeasurable" |
| `json` | stdlib | `json.load` on the record; a malformed file raises `ValueError`, caught together with `OSError` as "not parseable" [scripts/node_seed_drift.py:309-314]; `json.dumps(…, sort_keys=True)` for `--json` [scripts/node_seed_drift.py:474] | a change in exception type would turn a corrupt record into a traceback instead of a WARN |
| `os` | stdlib | `expanduser` **is** the `~` contract (local mode reads `$HOME`) [scripts/node_seed_drift.py:286]; `path.join` builds the record path [scripts/node_seed_drift.py:287]; `path.isfile` separates absent from unreadable [scripts/node_seed_drift.py:304] | if `--home` stopped being expanded, `~` would become a literal directory name and the run would WARN `is not a directory` |
| `re` | stdlib | **the real contract with the seeder is textual.** Three anchored patterns consume exactly the seeder's row shapes — PASS [scripts/node_seed_drift.py:159], DRIFT [scripts/node_seed_drift.py:160-162], ABSENT [scripts/node_seed_drift.py:163] — against the seeder's printers [scripts/node_seed.py:46-51] | a reworded seeder row does not error: it matches nothing, `count` stays `None`, and the verdict degrades to WARN "no usable verdict" [scripts/node_seed_drift.py:338-346]. Measured with a `{}` record, §3 row 7 |
| `shutil` | stdlib | `which` once, at import, so `PATH` is sampled before `main` runs [scripts/node_seed_drift.py:56] | a `PATH` export made later in the process would not be seen |
| `subprocess` | stdlib | `run(capture_output=True, text=True, check=False, timeout=…)` [scripts/node_seed_drift.py:78-84]; `TimeoutExpired` becomes `-9` and `OSError` becomes `-1` [scripts/node_seed_drift.py:85-88] | if `check` flipped to True, a drift (exit 1) would raise instead of being read |
| `sys` | stdlib | `sys.executable` runs the sibling locally [scripts/node_seed_drift.py:318]; `sys.stderr` carries the human rows under `--json` [scripts/node_seed_drift.py:543] | a frozen or embedded interpreter would run a different seeder than the one on disk |
| `typing.Optional` | stdlib | annotation only [scripts/node_seed_drift.py:54] | none |

### 2c. Service contracts (both sides named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| `scripts/node_seed.py check` (control host) | wrapper → child process | `argv`, no shell: `[sys.executable, "-B", seed_script, "check", "--record", record, "--home", home]` [scripts/node_seed_drift.py:316-328] | the record path, and the home to hash under | [scripts/node_seed.py:221-242] — `check_seed`; its three row shapes are the only thing the wrapper reads |
| **the node**, through the `bunker` client | wrapper → node, **one** round trip | `bunker --server S exec AGENT -- sh -lc <script>` [scripts/node_seed_drift.py:379] | the **entire seeder source**, embedded in a quoted heredoc, plus the record path and `$HOME` | the node's `sh` and `python3`; no file of ours survives the call — both temp paths are removed inside the same script [scripts/node_seed_drift.py:116-125] |
| the seed record `$HOME/.hermes/seed-applied.json` | read-only, both modes | file path [scripts/node_seed_drift.py:64] [scripts/node_seed_drift.py:287] | JSON with `files[].path` and `files[].sha256` | written by the seeder's `apply` [scripts/node_seed.py:208-215]; consumed by `check` [scripts/node_seed.py:227-235]. Its producer records paths relative to the repo root [scripts/node_seed.py:119], and `apply` installs only `prompts/` and `skills/` [scripts/node_seed.py:198-206] |
| `verify-node.sh` (the gate) | gate → wrapper | subprocess with `--json`; stdout is the JSON document, **stderr** carries the rows [scripts/node_seed_drift.py:543-549] | agent, server, and `--strict-seed` when `STRICT_SEED=1` [scripts/verify-node.sh:166-168] | the gate greps `^  PASS/FAIL/WARN  seed_drift — ` and maps exit 0→`ok`, 1→`bad`, **anything else→WARN, or `bad` under strict** [scripts/verify-node.sh:170-186]. This mapping, not the tool's own `--strict-seed`, is what makes a strict gate refuse a corrupt record (§6) |
| the node's stdout stream | node → wrapper | the same `exec`'s stdout, parsed line by line | `HOME=`, `RECORD=0|1|2`, `SEED_RC=`, and the check's output between `SEED_BEGIN`/`SEED_END` | [scripts/node_seed_drift.py:104-127] emits them; [scripts/node_seed_drift.py:137-154] parses them. The markers are the whole framing protocol, and a node that prints them itself is believed (§6) |

## 3. Verification

The module has no `--selftest`; the repository suite drives it in section 48
[tests/selftest.sh:3149-3275] — eleven green assertions covering: parses, fixture built, fixture
applied, clean PASS, tampered FAIL, restored PASS, absent WARN, absent+strict FAIL, restored PASS,
one-exec bunker mode, bunker `--json` shape — but **not** a corrupt record, not an empty record, and
not a missing seeder. Those three are measured below for the first time.

All rows were run on 2026-11-05 in `~/proj-wt-md-32d` at `d8c7796`, against one fixture built by the
**real** seeder (`build` then `apply` of `prompts/foreman.md` and `skills/fake-skill.md`) plus a stub
`bunker` that executes the remote script locally with `HOME` pointed at the fixture (§8).

| # | Check | Command | Expected | Result |
|---|---|---|---|---|
| 1 | a matching seed | `node_seed_drift.py --home <fixture>` | PASS, exit 0, the count named | **PASS** — `2 seeded files present and matching` |
| 2 | one file edited by hand | same, after `echo >> prompts/foreman.md` | FAIL, exit 1, path and both digest prefixes | **PASS** — `prompts/foreman.md drifted (expected 5d1aa573dea0, measured 48077930b73a)` |
| 3 | one file deleted | same, after moving `skills/fake-skill.md` away | FAIL, exit 1, named absent | **PASS** — `skills/fake-skill.md absent on the node` |
| 4 | the file restored | same | PASS again | **PASS** — the red arm can go green |
| 5 | a prompt the record never named, added | `echo > .hermes/prompts/hand-added.md` | **not measured by design** — the record is a whitelist | **PASS** — an added prompt is invisible (§6) |
| 6 | mode changed `644`→`755` on a recorded file | `chmod 755 .hermes/prompts/foreman.md` | not measured by design | **PASS** — mode is not part of drift (§6) |
| 7 | record parses, has no `files` key | `echo '{}' > .hermes/seed-applied.json` | a named "cannot measure", never a PASS | **WARN, exit 3** — `node_seed.py check printed no verdict (exit 1)` |
| 8 | record is valid JSON with `files: []` | `echo '{"files": []}' > …` | should refuse an empty seed | **PASS, exit 0** — `0 seeded files present and matching` (**defect 4**) |
| 9 | record absent | `mv .hermes/seed-applied.json aside` | WARN, exit 3, path named | **PASS** — `WARN  seed_drift — no seed record at <path> — nothing on this seed's home is digest-recorded; pass --strict-seed to refuse it` |
| 10 | same, `--strict-seed` | `--home <fixture> --strict-seed` | FAIL, exit 1 | **PASS** — `(--strict-seed: an unknown seed is not a pass)` |
| 11 | record is truncated JSON | `printf '{"files": [{"path": ' > …` | WARN, exit 3 | **PASS** — `the seed record at <path> does not parse — nothing could be measured` |
| 12 | **same corrupt record, `--strict-seed`** | as row 11 plus the flag | FAIL, per the flag's own help text [scripts/node_seed_drift.py:491-495] | **FAILS** — still `WARN`, still exit 3; `finding_corrupt` accepts `strict` and never reads it [scripts/node_seed_drift.py:267-278] (**defect 1**) |
| 13 | the sibling seeder missing, local mode | a copy of the wrapper alone in an empty dir | a named "cannot measure" | **WARN, exit 3** — `node_seed.py check printed no verdict (exit 2)` |
| 14 | the sibling seeder missing, bunker mode | same copy, `--agent/--server` | WARN naming the missing file | **WARN, exit 3** — `<dir>/node_seed.py is missing — the check could not be staged` |
| 15 | the module itself absent, gate level | `verify-node.sh` from a `scripts/` copy without it | FAIL, exit 1 | **PASS** — `FAIL  seed_drift — … missing — the node's seed is unmeasured`, `VERIFY: FAIL (1)` |
| 16 | bunker mode, one round trip | stub client, `--agent cf-fixture --server fixture` | PASS, exactly one `exec`, no leftovers | **PASS** — one call carrying the whole seeder; `ls /tmp/node-seed-check-*` → no such file |
| 17 | bunker mode, no `bunker` on `PATH` | `env PATH=/usr/bin:/bin …` | a named "cannot measure", never PASS | **WARN, exit 3** — `bunker exec failed: FileNotFoundError: …` |
| 18 | `--json` on a clean seed | `--home <fixture> --json` | rows on stderr, one object on stdout | **PASS** — `status: PASS`, `record_present: true`, `file_count: 2` |
| 19 | usage: both modes / no mode / half a bunker pair / `--timeout 0` | four invocations | exit 2 each, message on stderr | **PASS** — all four exit 2 |

Transcript 1 (rows 1-3, local mode, the fixture's real record):

```
$ python3 -B scripts/node_seed_drift.py --home …/md32/node-home
node-seed-drift — home …/md32/node-home
  PASS  seed_drift — …/md32/node-home/.hermes/seed-applied.json: 2 seeded files present and matching
RESULT: PASS
EXIT=0
$ # after: echo "tampered by hand" >> node-home/.hermes/prompts/foreman.md
node-seed-drift — home …/md32/node-home
  FAIL  seed_drift — …/md32/node-home/.hermes/seed-applied.json: 1 seeded path(s) differ from the record: prompts/foreman.md drifted (expected 5d1aa573dea0, measured 48077930b73a)
RESULT: FAIL (1 seeded path(s) differ from the record)
EXIT=1
$ # after: mv node-home/.hermes/skills/fake-skill.md aside
node-seed-drift — home …/md32/node-home
  FAIL  seed_drift — …/md32/node-home/.hermes/seed-applied.json: 1 seeded path(s) differ from the record: skills/fake-skill.md absent on the node
RESULT: FAIL (1 seeded path(s) differ from the record)
EXIT=1
```

Transcript 2 (rows 7, 8, 11, 12 — the four record states, literal):

```
$ echo '{}' > .hermes/seed-applied.json
  WARN  seed_drift — node_seed.py check printed no verdict (exit 1) — the seed could not be measured; pass --strict-seed to refuse it
EXIT=3
$ echo '{"files": []}' > .hermes/seed-applied.json
  PASS  seed_drift — …/.hermes/seed-applied.json: 0 seeded files present and matching
EXIT=0
$ printf '{"files": [{"path": ' > .hermes/seed-applied.json
  WARN  seed_drift — the seed record at …/.hermes/seed-applied.json does not parse — nothing could be measured
EXIT=3
$ … --strict-seed                                   # the SAME corrupt record
  WARN  seed_drift — the seed record at …/.hermes/seed-applied.json does not parse — nothing could be measured
EXIT=3
```

Row 8's record came from the seeder, not from a hand-written stub:

```
$ python3 -B scripts/node_seed.py build --manifest glob.manifest --repo-root empty/src --out empty/empty.tar
  ..    manifest glob matched nothing: prompts/*.md
  ..    manifest glob matched nothing: skills/**/*.md
  PASS  seed_manifest — 0 files declared, 0 bytes (ceiling 16777216)
  PASS  seed_record — empty/empty.tar.json (0 files, sha256 per file)
$ … apply --tar empty/empty.tar --record empty/empty.tar.json --home empty/home
  PASS  seed_digest — all 0 files match the record
  PASS  seed_record — empty/home/.hermes/seed-applied.json written
$ … node_seed_drift.py --home empty/home
  PASS  seed_drift — empty/home/.hermes/seed-applied.json: 0 seeded files present and matching
RESULT: PASS
EXIT=0
```

Transcript 3 (rows 16, 17, 14 — bunker mode against the stub transport, literal):

```
$ PATH=…/bin:$PATH HOME=…/node-home python3 -B scripts/node_seed_drift.py --agent cf-fixture --server fixture
node-seed-drift — agent cf-fixture via fixture (home …/md32/node-home)
  PASS  seed_drift — …/md32/node-home/.hermes/seed-applied.json: 2 seeded files present and matching
RESULT: PASS
EXIT=0
# the only transport call, truncated to its first line:
--server fixture exec cf-fixture -- sh -lc set -u / echo "HOME=$HOME" …
$ ls /tmp/node-seed-check-*      # after the run
ls: cannot access '/tmp/node-seed-check-*': No such file or directory
$ env PATH=/usr/bin:/bin python3 -B scripts/node_seed_drift.py --agent cf-fixture --server fixture
node-seed-drift — agent cf-fixture via fixture (home (unresolved))
  WARN  seed_drift — bunker exec failed: FileNotFoundError: [Errno 2] No such file or directory: 'bunker' — the seed could not be measured; pass --strict-seed to refuse it
EXIT=3
$ # the wrapper copied alone, without its sibling seeder
  WARN  seed_drift — …/solo/node_seed.py is missing — the check could not be staged — the seed could not be measured; pass --strict-seed to refuse it
EXIT=3
```

Transcript 4 (rows 15, 18, 19, literal):

```
$ bash …/nosd/verify-node.sh --agent cf-fixture --server fixture     # node_seed_drift.py removed
  PASS  agent_alive — ALIVE stubnode
  PASS  node_ip — 127.0.0.1
  PASS  gateway_reachable — http://127.0.0.1:10800/api/status -> 200
  PASS  auth_gate — auth_required:true (a public bind must not be open)
  PASS  unauth_refused — /api/system/stats -> 401
  PASS  checkout_freshness — branch=main head=de6dc6a6b180 origin_main=de6dc6a6b180 ancestor=true behind=0
  FAIL  seed_drift — …/nosd/node_seed_drift.py missing — the node's seed is unmeasured

VERIFY: FAIL (1)
EXIT=1
$ … --home …/node-home --json
{ "absent": [], "agent": "", "drifted": [], "error": "", "exit_code": 0, "file_count": 2,
  "home": "…/node-home", "mode": "local", "reason": "", "record": "…/seed-applied.json",
  "record_present": true, "result": "RESULT: PASS", "server": "", "status": "PASS" }
$ … --home …/node-home --agent x --server y
--home and --agent/--server are exclusive
RESULT: FAIL (usage: --home and --agent/--server are exclusive)
EXIT=2
```

### 3a. The two verifiers, measured against each other

`verify-node.sh` was driven end to end with a stub `bunker` (answers `ALIVE`, answers
`hostname -I` with `127.0.0.1`, executes the remote command locally) and a real HTTP server on
`127.0.0.1:10800` answering `/api/status` 200 with `auth_required: true` and `/api/system/stats`
401 — so legs 1-5 are genuinely green [scripts/verify-node.sh:40-95] [scripts/verify-node.sh:109-146]
and only the seed leg varies.

| # | Seed state | Tool run directly | Through the gate, default | Through the gate, `--strict-seed` |
|---|---|---|---|---|
| 20 | clean | PASS, 0 | `PASS seed_drift`, **`VERIFY: PASS` 0** | `PASS seed_drift`, `VERIFY: PASS` 0 |
| 21 | one file edited | FAIL, 1 | `FAIL seed_drift`, `VERIFY: FAIL (1)` 1 | same, 1 |
| 22 | record absent | WARN, 3 | `WARN seed_drift`, **`VERIFY: PASS` 0** | `FAIL seed_drift`, `VERIFY: FAIL (1)` 1 |
| 23 | record corrupt | WARN, 3 | `WARN seed_drift`, **`VERIFY: PASS` 0** | `FAIL seed_drift`, `VERIFY: FAIL (1)` 1 |
| 24 | sibling seeder missing | WARN, 3 | `WARN seed_drift`, **`VERIFY: PASS` 0** | `FAIL seed_drift`, `VERIFY: FAIL (1)` 1 |

Transcript 5 (rows 20 and 23 — the fail-open, verbatim, seed row only):

```
$ bash scripts/verify-node.sh --agent cf-fixture          # clean seed
  PASS  checkout_freshness — branch=main head=de6dc6a6b180 origin_main=de6dc6a6b180 ancestor=true behind=0
  PASS  seed_drift — …/node-home/.hermes/seed-applied.json: 2 seeded files present and matching

VERIFY: PASS
EXIT=0
$ printf '{"files": [' > .hermes/seed-applied.json      # corrupt record
  WARN  seed_drift — node_seed.py check on the node gave no usable verdict (exit 1) — the seed could not be measured; pass --strict-seed to refuse it — the seed could not be measured; pass --strict-seed to refuse it

VERIFY: PASS
EXIT=0
$ … --strict-seed                                       # the SAME corrupt record
  FAIL  seed_drift — node_seed.py check on the node gave no usable verdict (exit 1) — the seed could not be measured; pass --strict-seed to refuse it (--strict-seed: unknown is not a pass)

VERIFY: FAIL (1)
EXIT=1
```

**Do the two sides agree on what drift means?** On the definition, yes, and by construction: the
gate never re-implements it, it folds the tool's exit code [scripts/verify-node.sh:170-186], and the
tool in turn folds the seeder's rows [scripts/node_seed_drift.py:166-187]. On the **mapping** they
agree for PASS (0→0) and drift (1→1). They disagree in two places:

1. **WARN is a pass at the gate.** The tool's exit 3 is explicitly "could not measure"
   [scripts/node_seed_drift.py:28-34], and a WARN leaves `FAILED` untouched [scripts/lib.sh:8], so
   `VERIFY: PASS` and exit 0 are reachable with the seed leg unresolved (rows 22-24, defect 2). The
   tool's own process never lies this way; the gate's summary line does.
2. **`--strict-seed` means two different things.** In the tool it converts *only* an absent record
   [scripts/node_seed_drift.py:229-240]; a corrupt record and a missing instrument stay WARN
   [scripts/node_seed_drift.py:253-278]. At the gate it converts **every** non-0/1 exit
   [scripts/verify-node.sh:177-183]. Measured: the same corrupt fixture is `WARN 3` when run
   directly with the flag and `FAIL` through the gate with the flag (row 23, defect 1).

## 4. Metrics emitted

**None.** The module writes no counter, no status file and no metric: local mode writes nothing at
all, and the node-side script creates two temp files and removes them in the same exec
[scripts/node_seed_drift.py:114-125], which was measured (no `/tmp/node-seed-check-*` survives,
§3 row 16). The gate then deletes both captured streams [scripts/verify-node.sh:187].

The only machine-readable output is the per-run JSON document `--json` prints
[scripts/node_seed_drift.py:465-474] — `mode`, `home`, `record`, `record_present`, `file_count`,
`drifted[]`, `absent[]`, `error`, `status`, `exit_code`, `reason`, `result`, `rows[]`. It is a
report, not a metric: nothing accumulates it, so the drift rate across nodes, the number of nodes
carrying no record at all, the number of seeded paths under management fleet-wide and the latency of
a check are all unanswerable from any store. `file_count` is the one quantity a monitor could scrape
today, one run at a time — and on the drift path it is `null`, because the count comes from a PASS
row that a drifting seed never prints [scripts/node_seed_drift.py:172-175]
[scripts/node_seed_drift.py:211-214]; that is why the FAIL row reads `%d seeded path(s) differ`
rather than `N of M` (measured, Transcript 1).

There is a second, subtler gap: `MAX_SHOWN = 20` truncates the FAIL row and points at `--json` for
the rest [scripts/node_seed_drift.py:68] [scripts/node_seed_drift.py:206-209], so on a seed with many
drifted paths even the report is a sample unless the consumer keeps the JSON — and the gate does
not: it greps the row and deletes the JSON [scripts/verify-node.sh:175] [scripts/verify-node.sh:187].

## 5. Log lines it can generate

Rows go to stdout, or to **stderr** when `--json` is set, in which case the JSON document is the only
thing on stdout [scripts/node_seed_drift.py:543-549]. There is no logging framework: the row prefix
is the severity. **Kind** is assigned as *evidentiary* where the line reports something a child
process or a transport actually returned and could have failed, and *descriptive* where it restates a
decision the wrapper already made.

| Level | Line (verbatim) | Emitted when | Kind |
|---|---|---|---|
| — | `node-seed-drift — agent %s via %s (home %s)` | bunker mode, before any row; `(unresolved)` when no `HOME` came back [scripts/node_seed_drift.py:455-461] | descriptive |
| — | `node-seed-drift — home %s` | local mode [scripts/node_seed_drift.py:462] | descriptive |
| PASS | `  PASS  seed_drift — %s: %d seeded files present and matching` | the seeder exited 0 **and** printed its PASS row [scripts/node_seed_drift.py:190-194] | evidentiary — the count is the seeder's own measurement |
| FAIL | `  FAIL  seed_drift — %s: %s differ from the record: %s` | the seeder exited 1 and named at least one drifted or absent path [scripts/node_seed_drift.py:215-219] | evidentiary — names the paths and both digest prefixes |
| FAIL | `  FAIL  seed_drift — no seed record at %s (--strict-seed: an unknown seed is not a pass)` | no record, with `--strict-seed` [scripts/node_seed_drift.py:235-238] | evidentiary of absence |
| WARN | `  WARN  seed_drift — no seed record at %s — nothing on this seed's home is digest-recorded; pass --strict-seed to refuse it` | no record, default [scripts/node_seed_drift.py:245-248] | evidentiary of absence; **does not stop `VERIFY: PASS`** |
| WARN | `  WARN  seed_drift — %s — the seed could not be measured; pass --strict-seed to refuse it` | the child gave no verdict, the home is not a directory, the transport failed, `HOME` never came back, or `SEED_RC` was missing [scripts/node_seed_drift.py:253-264] | evidentiary of a failed measurement |
| WARN | `  WARN  seed_drift — the seed record at %s does not parse — nothing could be measured` | the record is not JSON, or cannot be opened [scripts/node_seed_drift.py:267-278] | evidentiary |
| — | `RESULT: PASS` | the PASS finding [scripts/node_seed_drift.py:200] | descriptive — restates `exit_code` |
| — | `RESULT: FAIL (%s differ from the record)` | the drift finding [scripts/node_seed_drift.py:225] | descriptive |
| — | `RESULT: WARN (no seed record at %s)` | the default-absent finding [scripts/node_seed_drift.py:249] | descriptive |
| — | `RESULT: FAIL (no seed record at %s)` | the strict-absent finding [scripts/node_seed_drift.py:239] | descriptive |
| — | `RESULT: FAIL (usage: %s)` | any of the five usage refusals; the message itself goes to stderr first [scripts/node_seed_drift.py:509-512] | descriptive |
| — | `--home and --agent/--server are exclusive` | both modes given [scripts/node_seed_drift.py:518-519] | descriptive |
| — | `one mode is required: --home DIR or --agent ID --server NAME` | neither mode given [scripts/node_seed_drift.py:520-523] | descriptive |
| — | `bunker mode needs both --agent ID and --server NAME` | one half of a bunker pair [scripts/node_seed_drift.py:524-525] | descriptive |
| — | `--timeout must be >= 1, got %d` | `--timeout 0` or negative [scripts/node_seed_drift.py:514-515] | descriptive |
| node stream | `HOME=$HOME` | first line of the remote script; the only source of the node's home [scripts/node_seed_drift.py:106] | descriptive — consumed by `parse_remote` |
| node stream | `RECORD=0` / `RECORD=1` / `RECORD=2` | no record / record present / record failed the JSON probe [scripts/node_seed_drift.py:108-113] | descriptive — `RECORD=2` is unreachable, §8 defect 3 |
| node stream | `SEED_RC=$SEED_RC` | immediately after the staged check finishes [scripts/node_seed_drift.py:120-121] | evidentiary — the child's real exit status |
| node stream | `SEED_BEGIN` / `SEED_END` | framing the check's own output, captured to a temp file first [scripts/node_seed_drift.py:122-125] | descriptive — the framing protocol |
| — | `node_seed.py check printed no verdict (exit %d)` | the seeder exited with anything but 0-with-a-PASS-row or 1-with-a-drift-row, local mode [scripts/node_seed_drift.py:344-346] | evidentiary — carries the child's exit code |
| — | `node_seed.py check on the node gave no usable verdict (exit %d)` | same, bunker mode [scripts/node_seed_drift.py:445-447] | evidentiary |
| — | `bunker exec failed: %s` | the transport returned non-zero, or could not be started [scripts/node_seed_drift.py:382-386] | evidentiary |

The gate re-prints every one of these rows under its own prefix, and doubles the tail of a WARN row:
`  WARN  seed_drift — <row> — the seed could not be measured; pass --strict-seed to refuse it`
[scripts/verify-node.sh:183], where `<row>` already ends with that clause — measured, Transcript 5
(defect 5).

## 6. Failure modes

Direction is the fail-open / fail-closed sense: what the failure does to the verdict and the exit
status, first at the tool, then at the gate.

| Failure | Direction | Presents as | Distinguished from | Recovery |
|---|---|---|---|---|
| A seeded file's content changes | **fail-closed** | `FAIL … <path> drifted (expected <12>, measured <12>)`, exit 1 [scripts/node_seed_drift.py:204-226] | an absent file says `absent on the node` instead | re-apply the seed from the control host; the row names the path |
| A seeded file is deleted | **fail-closed** | `FAIL … <path> absent on the node`, exit 1 [scripts/node_seed_drift.py:163] | a manifest typo removes the path from the record entirely, which is the record-absent story | re-apply |
| **A file is added to `prompts/` or `skills/`** | **fail-open, silently** | nothing — PASS with the recorded count; only recorded paths are hashed [scripts/node_seed.py:227-236] | a drifted recorded file | re-applying replaces both directories wholesale [scripts/node_seed.py:198-206], which is the only thing that removes the ghost |
| **A recorded file's mode changes** | **fail-open, silently** | PASS | — | mode is never read; nothing can detect it |
| **The record's `files` list is empty** | **fail-open into a green** | `PASS seed_drift — …: 0 seeded files present and matching`, exit 0 (measured, §3 row 8) | a healthy seed names a count > 0 | a build whose globs matched nothing produces exactly this [scripts/node_seed.py:83-90] [scripts/node_seed.py:132]; `file_count == 0` is the only tell, and nothing refuses it |
| No record on the node | **fail-open at the gate, refuse-able on request** | `WARN … no seed record …`, exit 3, then **`VERIFY: PASS` 0**; `FAIL` 1 under `--strict-seed` (row 22) | a corrupt record names the record and says "does not parse" | a node still being provisioned is the legitimate case [scripts/node_seed_drift.py:28-34]; a gate that cares must pass `--strict-seed` |
| The record does not parse | **fail-open at the gate** | `WARN … does not parse …`, exit 3; the tool's own `--strict-seed` does **not** change it, the gate's does (rows 12 and 23) | a missing record says "no seed record at" | repair or re-apply the record; strictness has to live at the gate |
| The record parses but has no `files` key (a newer or foreign schema) | **fail-open at the gate, and misattributed** | `WARN … node_seed.py check printed no verdict (exit 1)` — it blames the seeder, not the record (measured, row 7) | the `does not parse` row, which is the honest one | treat any "no verdict" with a readable record as a schema problem; the wrapper never inspects the record's shape, only whether it parses [scripts/node_seed_drift.py:309-314] |
| **The sibling seeder is missing** | **fail-open at the gate; a green with no instrument** | bunker mode: `WARN … is missing — the check could not be staged`; local mode: `WARN … no verdict (exit 2)`; through the gate in default mode: **`VERIFY: PASS` 0** (rows 14 and 24) | the module itself missing, which the gate *does* fail [scripts/verify-node.sh:161-164] | restore `scripts/node_seed.py` — the gate has an existence check for the wrapper and none for its sibling [scripts/node_seed_drift.py:478-479] |
| The `bunker` client is absent, or the exec fails | **fail-closed to WARN** | `WARN … bunker exec failed: …`, exit 3 (measured, row 17) | a node that answers but has no record (`RECORD=0`) | install the client / reach the host; `(unresolved)` in the header is the tell |
| The node returns no `HOME` | **fail-closed to WARN** | `WARN … bunker exec returned no HOME (first line: …)`, exit 3 [scripts/node_seed_drift.py:394-399] | an empty stream | the exec stream was cut, or the shell is not POSIX |
| The node's answer carries no `RECORD` verdict | **fail-closed to WARN** | `WARN … the node's answer carried no RECORD verdict …` [scripts/node_seed_drift.py:410-420] | a stream truncated after `SEED_RC` | re-run; the framing is the protocol |
| The stream is cut after the check but before `SEED_RC` | **fail-closed to WARN** | `WARN … the node returned no SEED_RC verdict — the exec stream was cut` [scripts/node_seed_drift.py:423-428] | a check that ran and printed nothing | raise `--timeout` (default 180 s, while the exec stream dies at 300 [scripts/node_seed_drift.py:496-501]) |
| **A corrupt record, seen from the node** | **misattributed, then fail-open at the gate** | `WARN … check on the node gave no usable verdict (exit 1)`, not `does not parse` — the remote JSON guard is a no-op (§8 defect 3) | local mode's honest `does not parse` row | same recovery; do not trust the row's noun |
| The node prints `SEED_BEGIN` / a PASS row / `SEED_END` itself | **fail-open by construction** | `PASS seed_drift — …: N seeded files present and matching` for any N the node chooses [scripts/node_seed_drift.py:137-154] | nothing distinguishes it — the stream is the only witness | out of scope for this tool: a compromised node can always lie about its own files |
| The seeder source contains a line exactly `SEED_PY_STAGED_EOF` | **fails closed, loudly** | the heredoc ends early, the staged file is a prefix, `python3` reports a syntax error, `SEED_RC` 1 → `WARN … gave no usable verdict` | a genuine seeder bug | rename the sentinel [scripts/node_seed_drift.py:116-118]; the marker is a fixed literal |
| A drifted seed with more than 20 paths | fail-closed but **truncated** | the row ends `(+N more — see --json)` [scripts/node_seed_drift.py:206-209] | the full set, in the JSON | keep the `--json` output; the gate deletes it [scripts/verify-node.sh:187] |
| Usage error (no mode, both modes, half a bunker pair, bad timeout) | fail-closed to exit 2 | the message on stderr plus `RESULT: FAIL (usage: …)`, exit 2 (measured, row 19) | a drift, which is exit 1 | fix the invocation; **at the gate** exit 2 falls into the `*)` arm and becomes a WARN [scripts/verify-node.sh:177-183] |

## 7. Environment and settings it reads

| Variable | Default | Effect if unset |
|---|---|---|
| `PATH` | inherits the caller's | sampled **once at import** for the `bunker` client [scripts/node_seed_drift.py:56]; the `or "bunker"` fallback defers the failure to exec time [scripts/node_seed_drift.py:87-88] |
| `HOME` (local mode) | inherits the caller's | expanded by `os.path.expanduser` on `--home` [scripts/node_seed_drift.py:286]; an unset `HOME` makes `~` unresolvable and the run WARNs `is not a directory` [scripts/node_seed_drift.py:301-303] |
| `HOME` (the node's) | set by the node's login shell | echoed as `HOME=` and used to build the record path [scripts/node_seed_drift.py:106-107]; a shell that does not export it produces the `returned no HOME` WARN [scripts/node_seed_drift.py:394-399] |
| `sys.executable` | the interpreter running the wrapper | runs `node_seed.py check` in local mode [scripts/node_seed_drift.py:318] — the sibling is executed by the *wrapper's* interpreter, not by `python3` from `PATH` |
| `TMPDIR` | **not read** | the node's temp files are hardcoded under `/tmp` [scripts/node_seed_drift.py:114-115], so a node with a small `/tmp` fails this leg regardless of `TMPDIR` |
| `python3` on the node | any | two uses: the record probe [scripts/node_seed_drift.py:109] and the staged check [scripts/node_seed_drift.py:119] |
| `sh` on the node | any POSIX shell | the remote command is `sh -lc` [scripts/node_seed_drift.py:379], not `bash`; nothing in the template needs bash |

There is no configuration file and no environment variable of its own: `RECORD_REL`, `MAX_SHOWN` and
`SEED_SIBLING_NAME` are constants [scripts/node_seed_drift.py:64] [scripts/node_seed_drift.py:68]
[scripts/node_seed_drift.py:72]. The only tunables are flags:

| Flag | Default | Meaning |
|---|---|---|
| `--agent ID` / `--server NAME` | none | bunker mode; both are required together [scripts/node_seed_drift.py:524-525] |
| `--home DIR` | none | local mode; exclusive with the pair above [scripts/node_seed_drift.py:516-519] |
| `--strict-seed` | off | per its help text, "an unmeasurable or absent seed record is a FAIL, not a WARN" [scripts/node_seed_drift.py:491-495] — but only the *absent* case is implemented [scripts/node_seed_drift.py:229-278] |
| `--timeout` | `180` | seconds for the child / the exec; the help notes the bunker exec stream dies at 300 [scripts/node_seed_drift.py:496-501]; `< 1` is a usage error [scripts/node_seed_drift.py:514-515] |
| `--json` | off | one JSON object on stdout, rows moved to stderr [scripts/node_seed_drift.py:502-506] [scripts/node_seed_drift.py:543-549] |

## 8. Evidence of record

- **Measured 2026-11-05** in a fresh worktree of `d8c7796` (`~/proj-wt-md-32d`), Python 3.14, on the
  control host only. The fixture is a real seed, not a mock: `node_seed.py build` over
  `prompts/foreman.md` + `skills/fake-skill.md`, then `node_seed.py apply` into a fixture home
  [scripts/node_seed.py:109-218]. Every arm in §3 re-uses that one applied home, mutated and
  restored in place.
- **Bunker mode was measured; a node was not.** The `bunker` on `PATH` was a stub that records its
  argv and executes the remote command locally with `HOME` pointed at the fixture home — so the
  transport framing, the single round trip, `SEED_RC` propagation and the temp-file cleanup are
  real, while the network hop is not. No bunker host was touched.
- **The gate was measured live for legs 1-5**: a stub `bunker` answering `ALIVE` and
  `hostname -I → 127.0.0.1`, a real HTTP server on `127.0.0.1:10800` (`/api/status` 200 with
  `auth_required: true`, `/api/system/stats` 401), and a real local checkout with a fetchable origin
  so `checkout_freshness` passes on its own measurement [scripts/verify-node.sh:40-95]
  [scripts/verify-node.sh:109-146]. Transcript 5 is that run.
- **Existing suite coverage**: section 48 of `tests/selftest.sh` [tests/selftest.sh:3149-3275],
  eleven green assertions, including the bunker one-round-trip arm [tests/selftest.sh:3245-3272]. It
  does not cover a corrupt record, an empty record, or a missing seeder — the three arms that
  produced defects 1, 3 and 4.
- **§3 row 8's record was produced by the real builder**, not hand-written: a glob-only manifest that
  matched nothing produced `0 files declared`, `apply` accepted it, and the drift leg reported PASS.
  This is the shape the real manifest takes — `config/node-seed.txt` is glob-only [config/node-seed.txt:10-13].
- **Defects found while measuring** (nothing was fixed; this task touches one document):

| # | Defect | Evidence |
|---|---|---|
| 1 | **`--strict-seed` is half-implemented.** The flag advertises "an unmeasurable or absent seed record is a FAIL" [scripts/node_seed_drift.py:491-495], but only `finding_absent` reads it [scripts/node_seed_drift.py:229-240]; `finding_corrupt` takes `strict` and never uses it [scripts/node_seed_drift.py:267-278], and `finding_unmeasurable` has no such parameter at all [scripts/node_seed_drift.py:253-264]. Measured: a corrupt record with the flag → `WARN`, exit 3 (§3 row 12). The WARN rows also still say "pass --strict-seed to refuse it" when the caller already did | measured |
| 2 | **The gate passes a node whose seed it could not measure.** `warn` does not increment `FAILED` [scripts/lib.sh:8], so `VERIFY: PASS`, exit 0 is printed after `WARN seed_drift` [scripts/verify-node.sh:183] [scripts/verify-node.sh:197]. Measured for an absent record, a corrupt record and a missing seeder (§3 rows 22-24) — three states in which the node's seeded prompts are wholly unverified and the verifier says PASS | measured |
| 3 | **The node-side record guard is dead code.** `python3 - "$REC" -c 'import json,sys; json.load(open(sys.argv[1]))'` [scripts/node_seed_drift.py:109] puts `-c` *after* the script argument, so `-` runs stdin as the program (empty, since the exec stream forwards no stdin) and the rest becomes that program's argv: it exits 0 on any file. Measured: that exact argv form against a truncated record exits **0**, while `python3 -c '<same code>' <record>` exits 1. Consequence: `RECORD=2` [scripts/node_seed_drift.py:110-112] is unreachable, and a corrupt record on a node is reported as a seeder failure (`gave no usable verdict`) instead of `does not parse` | measured (row 7 vs row 11, plus the direct argv test) |
| 4 | **An empty seed is a green.** `{"files": []}` → `PASS seed_drift — …: 0 seeded files present and matching`, exit 0, and the gate folds it into `VERIFY: PASS`. Reachable from the real builder whenever the manifest's globs match nothing — which is what the glob-only `config/node-seed.txt` [config/node-seed.txt:10-13] does on a tree without `prompts/` or `skills/` [scripts/node_seed.py:83-90] [scripts/node_seed.py:132]. Nothing anywhere treats `file_count == 0` as "nothing was seeded" | measured end to end (Transcript 2) |
| 5 | **The gate doubles the strict hint in every WARN row.** [scripts/verify-node.sh:183] appends "— the seed could not be measured; pass --strict-seed to refuse it" to a detail the tool already ends with those exact words [scripts/node_seed_drift.py:255-257]. Measured, Transcript 5 | measured |
| 6 | **The seeder runs under the wrapper's interpreter locally, and under `python3` on the node.** Local mode passes `sys.executable` [scripts/node_seed_drift.py:318] while the node path calls `python3` [scripts/node_seed_drift.py:119], so a wrapper run in a venv measures with a different Python than the node does — harmless today, since the seeder is stdlib-only [scripts/node_seed.py:26-36], but a silent asymmetry | read-from-code |
