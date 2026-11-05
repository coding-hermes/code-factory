# 21. scripts/lane_target.py

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/lane_target.py` |
| Repository | `code-factory` |
| Revision | `b9f56e6` |
| Status | **VERIFIED** |

## 1. Purpose and why it matters

`lane_target.py` is the module that converts a lane's `workdir` string into a claimed location and a
verdict. It is **not** a name-to-directory resolver: it reads no config, no registry and no scheduler
row, and it never looks a lane name up. `parse()` classifies by syntax alone and rejects anything it
cannot classify (`scripts/lane_target.py:138`, `scripts/lane_target.py:217`). `scan()` requires the
row to already carry a `workdir` value and marks a row without one invalid rather than searching for
a directory (`scripts/lane_target.py:420`). So "how is a target resolved" has exactly one answer:
the caller supplies the path, and this module decides whether that path is a syntactically valid,
sufficiently verified project checkout.

- **What breaks without it:** nothing on the repo side refuses a `repo_url` or `workdir` that is not
  a checkout, so the scheduler happily runs a lane in a directory that is not its project. The defect
  the module exists for is named in its own source: a workdir inside `$HOME` whose git top level *is*
  `$HOME` — the stand-in locator that made several satellites read the operator's home meta-repo
  board (`scripts/lane_target.py:21`, `scripts/lane_target.py:270`). Measured on the live fleet:
  257 of 880 `repo_url` values are not a git repository at all, 38 name a path that does not exist,
  and 1 resolves to the home meta-repo top level (section 3, run B).
- **What breaks if it lies:** `verify` decides "ok" from six existence/shape probes only — `exists`,
  `git_toplevel`, `not_home_repo`, `toplevel_matches_target`, `has_remote`, `attached_branch`
  (`scripts/lane_target.py:262`, `scripts/lane_target.py:295`). None of them compares *which* repo it
  is. A lane pointed at an unrelated checkout verifies green exactly like the intended one as soon as
  it carries any remote; measured, one scratch repo with an `origin` and a different scratch repo
  with a different `origin` both exit 0 (section 3, runs S2 and T2), and `repo-url` passes either
  (run U). The only cross-lane identity comparison in the file is the intra-family `repo_url`
  agreement check (`scripts/lane_target.py:569`), and it has a name-shaped blind spot proved in
  section 6.
- **Can a resolution be wrong without saying so?** Yes, in three distinct ways, all measured here:
  (a) two valid roots, one family, but the primary's own name ends in a recognized satellite suffix,
  so the pair is never compared — fixture exits 0 (section 3, run G); (b) a satellite whose primary
  row is absent is compared against an arbitrary sibling and the message still calls it "primary"
  (`scripts/lane_target.py:582`); (c) `plan` resolves an agent's home from whatever `bunker` answers
  on `$PATH`, with no host identity check (`scripts/lane_target.py:370`), and a local-exec stub made
  it emit a control-host path as an agent path (section 3, run V).

## 2. Dependencies and library contracts

### 2a. Runtime dependencies

| Dependency | Version | Where it must exist | Absence detected by |
|---|---|---|---|
| `python3` | measured on 3.14.4; all annotations are deferred by `from __future__ import annotations` (`scripts/lane_target.py:34`), and the runtime imports are stdlib | `$PATH` | the interpreter is the caller's |
| `git` | any | resolved **once** at import through `shutil.which("git")`, falling back to the literal `"git"` (`scripts/lane_target.py:223`) | `FileNotFoundError` from the probe reaches `main` and exits 2 (`scripts/lane_target.py:720`) |
| `bunker` CLI | any | `$PATH`, only for `verify --exec-bunker` and for site resolution in `plan` (`scripts/lane_target.py:334`) | `FileNotFoundError` is caught inside `verify_bunker` and recorded as a failed `agent_reachable` check (`scripts/lane_target.py:363`) |
| projects file | — | the path passed to `scan` (JSONL) or `repo-url --row` (JSON object/array, `-` = stdin) (`scripts/lane_target.py:406`, `scripts/lane_target.py:514`) | per-row error for malformed JSONL in `scan` (`scripts/lane_target.py:415`); whole-call `FAIL repo_url — …` exit 2 for malformed JSON in `repo-url` (`scripts/lane_target.py:524`) |

### 2b. Library contracts

| Import | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `subprocess.run(..., timeout=30, check=False)` | stdlib | git is expected to *return nonzero*, never to raise; the 30 s cap is the only bound (`scripts/lane_target.py:227`) | `TimeoutExpired` is caught per row in `repo_urls` (`scripts/lane_target.py:550`) but **not** in `verify`, where it escapes `main`'s three handlers as a traceback with exit 1 (`scripts/lane_target.py:714`) |
| `os.path.expanduser` | stdlib | `~` expands from `$HOME`; used for the target (`scripts/lane_target.py:129`), for the default home in `verify_local` (`scripts/lane_target.py:259`) and for repo-url normalization (`scripts/lane_target.py:475`) | a wrong `$HOME` silently changes which directory `~` means; `not_home_repo` then compares against the same wrong value |
| `shutil.which("git")` | stdlib | resolved at import, so a later `$PATH` change does not take effect (`scripts/lane_target.py:223`) | the probe keeps using the first git found, or the literal `git` |
| `dataclasses.asdict` | stdlib | the `Target` field set *is* the JSON output contract of `parse` and `plan` (`scripts/lane_target.py:63`, `scripts/lane_target.py:661`, `scripts/lane_target.py:710`) | adding or removing a field changes the emitted JSON without a version marker |
| `json.loads` | stdlib | `plan` assumes every non-empty line of the file is a JSON object (`scripts/lane_target.py:704`) | `JSONDecodeError` is not caught: traceback, exit 1 (measured, section 3 run R) |
| `argparse` | stdlib | subcommands `parse`, `verify`, `scan`, `repo-url`, `plan`, all required (`scripts/lane_target.py:605`) | usage errors exit 2 with argparse's own text, not the module's `FAIL lane-target:` line |
| `re` | stdlib | host/user/port/scp grammars (`scripts/lane_target.py:51`) | a looser or stricter host grammar changes which targets classify |

### 2c. Service contracts (both sides must be named)

| Peer | Direction | Transport | Payload | Other side (file:function) |
|---|---|---|---|---|
| `git` | out | `subprocess` argv `git -C <root> …` | `rev-parse --show-toplevel`, `remote`, `remote get-url <name>`, `rev-parse --abbrev-ref HEAD`, `rev-parse --verify HEAD` | `scripts/lane_target.py:226` (`_git`), `scripts/lane_target.py:236` (`_local_checkout`) |
| `bunker` CLI | out | `subprocess` argv `bunker [--server S] exec <agent> -- sh -lc '…'` | `HOME=` and `PATH_EXISTS=0|1` read back from stdout | `scripts/lane_target.py:334` (`verify_bunker`) |
| scheduler project export | in | file (JSONL for `scan`, JSON for `repo-url --row`) | rows keyed `name`/`id` carrying `workdir` or `repo_url`; `repo-url` also needs `name` for family grouping | `scripts/lane_target.py:419`, `scripts/lane_target.py:534` |
| `scripts/configure_family.py` | in | in-process import | calls `lane_target.parse(workdir)` and catches `lane_target.TargetError` | `scripts/configure_family.py:149` |
| `scripts/node_freshness.py` | in (documented) | docstring reference to `lane_target.py --exec-bunker` | freshness is stated in terms of this module's target model | `scripts/node_freshness.py:5` |

## 3. Verification

All commands were run read-only against the fleet export and against scratch fixtures; none of them
wrote to this repository.

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| Unit contract suite | `PYTHONDONTWRITEBYTECODE=1 python3 -B tests/test_lane_target.py` | 40 tests pass | 2026-11-05 | `Ran 40 tests in 1.526s` / `OK`, exit 0 |
| Fleet `repo_url` sweep (read-only DB export, 880 rows) | `python3 -B scripts/lane_target.py repo-url --row fleet-projects.json` | per-row PASS/FAIL, summary, exit 2 | 2026-11-05 | `repo_url: 378 rejected, 502 accepted`, exit 2, 2.2 s |
| Fleet `workdir` sweep (880 rows) | `python3 -B scripts/lane_target.py scan fleet-workdirs.jsonl` | `bad`/`ok` counts, exit 4 | 2026-11-05 | `"bad": 805`, `"ok": false`, exit 4, 2.5 s |
| Unrecognized lane (no `workdir`) | `scan unknown.jsonl` (row `{"name":"ghost-lane"}`) | row invalid, exit 4 | 2026-11-05 | `"error": "target is null"`, exit 4 |
| Unrecognized lane (bare name as path) | `parse code-factory` | exit 2, classify message | 2026-11-05 | exit 2 |
| Relative path | `parse local:work/project` | exit 2, relative-path message | 2026-11-05 | exit 2 |
| Suffix-named primary + its satellite, two roots | `repo-url --row ambiguous-only.json` | **must reject** to be safe | 2026-11-05 | `0 rejected, 2 accepted`, exit 0 — **missed** |
| Control: same shape without a suffix in the name | `repo-url --row control.json` | reject, naming the primary | 2026-11-05 | `1 rejected, 1 accepted`, exit 4 |
| Satellite with no primary row | `repo-url --row noprimary.json` | reject | 2026-11-05 | exit 4, message names a `proj` row that does not exist |
| Remote without opt-in | `verify builder@node-01:/srv/cf` | exit 3 | 2026-11-05 | exit 3 |
| Remote with opt-in | `verify ssh://builder@node-01:2222/srv/cf --allow-remote` | `remote-structural-only`, ok | 2026-11-05 | exit 0 |
| Plain directory | `verify <scratch>/plain` | `git_toplevel` false, exit 4 | 2026-11-05 | exit 4 |
| Subdirectory of a real checkout | `verify <scratch>/repo-a/sub` | `toplevel_matches_target` false, exit 4 | 2026-11-05 | exit 4 |
| Home meta-repo guard | `verify <scratch>/repo-a --home <scratch>/repo-a` | `not_home_repo` false, exit 4 | 2026-11-05 | exit 4 |
| Unrelated checkout with its own remote | `verify <scratch>/repo-c` (own bare `origin`) | should distinguish it from the intended repo | 2026-11-05 | all six checks true, exit 0 — indistinguishable |
| Unrelated checkout through `repo-url` | `repo-url <scratch>/repo-c` | should distinguish it | 2026-11-05 | `PASS`, exit 0 — identity is not checked |
| `scan --exec-bunker` on a `bunker://` row | `scan bunker.jsonl --exec-bunker` | exec probe, or a failure naming the agent | 2026-11-05 | refused as remote, exit 4 — the flag is ignored |
| `plan` on malformed JSONL | `plan bad.jsonl --agent x --path /srv/cf` | a documented exit code | 2026-11-05 | traceback, exit 1 |

Verbatim summary lines (run B, real fleet, 880 rows):

```
repo_url: 378 rejected, 502 accepted
EXIT=2
```

Verbatim fixture outputs behind the two claims above (run G, and its control run H):

```
PASS repo_url '<scratch>/repo-a' — root '<scratch>/repo-a' HEAD b79b7a8526d6c8fc614f701d7c72f471eefbf34f [notes-docs]
PASS repo_url '<scratch>/repo-b' — root '<scratch>/repo-b' HEAD b79b7a8526d6c8fc614f701d7c72f471eefbf34f [notes-docs-qa]
repo_url: 0 rejected, 2 accepted
EXIT=0
```

```
FAIL repo_url '<scratch>/repo-b' — repo_url diverges from primary 'notes': '<scratch>/repo-b' != '<scratch>/repo-a' [notes-qa]
repo_url: 1 rejected, 1 accepted
EXIT=4
```

The only difference between those two runs is the primary's name (`notes-docs`, which ends in a
recognized suffix, versus `notes`, which does not). Same rows, same two repositories, opposite
verdicts — `family_key` at `scripts/lane_target.py:450` decides, and it decides wrongly for any lane
whose own name ends in a suffix.

## 4. Metrics emitted

**None.** The module emits no counters, timings or telemetry, and pulls in no logging framework: the
only machine-readable output is JSON on stdout — `asdict(Target)` from `parse`
(`scripts/lane_target.py:661`) and `plan` (`scripts/lane_target.py:710`), plus the verify and scan
dicts (`scripts/lane_target.py:672`, `scripts/lane_target.py:676`). The two counts that exist are
printed text, not metrics: `repo_url: N rejected, M accepted` (`scripts/lane_target.py:598`) and the
`bad` field of the scan result (`scripts/lane_target.py:430`). Consequence: every fleet-wide figure
in section 3 had to be derived by the caller counting `PASS`/`FAIL` lines, which is exactly how the
881-printed-lines-for-880-rows defect in section 6 stayed invisible.

## 5. Log lines it can generate

| Level | Line (verbatim) | Emitted when | Kind |
|---|---|---|---|
| stderr | `FAIL lane-target: {exc}` | any `TargetError` (exit 2) or `PermissionError` (exit 3) at top level, and any `FileNotFoundError` (exit 2) — `scripts/lane_target.py:715`, `scripts/lane_target.py:718`, `scripts/lane_target.py:721` | descriptive; the exit code is the evidence |
| stdout | `PASS repo_url {raw!r} — {message}{label}` | one per row whose target parses and whose root check passes; `message` is `root '<path>' HEAD <sha>` for a local target — `scripts/lane_target.py:544` | descriptive; the run's exit code and the printed HEAD are the evidence |
| stdout | `FAIL repo_url {raw!r} — {exc}{label}` | one per rejected row; the `[name]` suffix appears only when the row carries a name — `scripts/lane_target.py:561` | descriptive; the exit code carries severity |
| stdout | `FAIL repo_url {raw!r} — repo_url diverges from primary {primary!r}: {normalized!r} != {reference!r} [{name}]` | a family member whose normalized `repo_url` differs from the family reference — `scripts/lane_target.py:593` | evidentiary: names both lanes and both roots, so the claim can be checked by hand |
| stdout | `repo_url: {rejected} rejected, {len(rows) - rejected} accepted` | always, once per `repo-url` call — `scripts/lane_target.py:598` | evidentiary (counts); a diverging row is counted once but printed twice |
| stdout | `FAIL repo_url — {exc}` then `repo_url: 1 rejected, 0 accepted` | the `--row` document cannot be loaded or is not a project object/array — `scripts/lane_target.py:524`, `scripts/lane_target.py:525` | evidentiary; no per-row detail because there are no rows |
| stderr | argparse usage text (`usage: …`, `error: …`) | a missing or unknown subcommand/flag — `scripts/lane_target.py:604` | descriptive; exit 2 comes from argparse, not from this module |
| not printed | `HOME=%s`, `PATH_EXISTS=1`, `PATH_EXISTS=0` | shell literals the module *sends* to the bunker agent and parses back; they appear in the agent's stdout, never in this module's own output — `scripts/lane_target.py:343`, `scripts/lane_target.py:372`, `scripts/lane_target.py:376` | descriptive when the agent prints them; evidentiary only to `verify_bunker` |

## 6. Failure modes

"Direction" is which way the module errs: **closed** = refuses and exits nonzero, **open** = accepts
and exits 0 while the target is not what the caller meant.

| Failure | Presents as | Distinguished from | Direction | Recovery |
|---|---|---|---|---|
| Row carries no `workdir` (a lane name that resolves to nothing) | `"error": "target is null"`, row `ok: false`, `bad` incremented, exit 4 — `scripts/lane_target.py:141`, `scripts/lane_target.py:426` | a row whose target parses but is not a checkout: that row carries a `checks` list instead of an `error` | closed | supply the path; this module will not invent one |
| `workdir` is a bare lane name, e.g. `code-factory` | `FAIL lane-target: cannot classify target 'code-factory': use an absolute path, ~/path, local:<path>, user@host:/path, <scheme>://[user@]host[:port]/path, or bunker://<agent>/path`, exit 2 — `scripts/lane_target.py:217` | a relative path, which classifies only when written `local:work/project` and then fails `local target must be absolute or ~-relative …` — `scripts/lane_target.py:131` | closed | write an absolute, `~`, `local:`, `user@host:` or `scheme://` target |
| Two spellings name different checkouts of the same lane | nothing — both `PASS`; families are compared only on `repo_url` (`scripts/lane_target.py:569`), never on `workdir` | the `repo_url` divergence line (`scripts/lane_target.py:593`), which fires only when a `repo_url` pair disagrees | open | compare `workdir` yourself; this check does not |
| Primary's own name ends in a satellite suffix (`notes-docs`, `9router-releng`, `boardctl-review`, …) | `repo_url: 0 rejected, 2 accepted`, exit 0, with two different valid roots — measured run G | the control with a non-suffixed primary name, which exits 4 (run H) | **open** | rename the lane, or check the pair by hand: `family_key` strips the suffix from a primary too (`scripts/lane_target.py:450`) |
| Satellite present, primary row absent | `repo_url diverges from primary 'proj'` — for a `proj` row that does not exist; the reference is `min(members, key=name)` — `scripts/lane_target.py:582` | a genuine divergence, which names a primary that *is* in the file | open (the message misattributes the reference) | add the primary row; until then the verdict is against an arbitrary sibling |
| Lane points at an unrelated valid checkout | `verify` ok, exit 0; `repo-url` `PASS … HEAD <sha>`, exit 0 — measured runs S2, T2, U | the home-meta-repo and subdirectory checks, which do fail (`scripts/lane_target.py:271`, `scripts/lane_target.py:276`) | **open** | no repo-identity check exists; assert the remote URL yourself |
| Workdir is `$HOME` itself, or resolves to the home meta-repo top level | `not_home_repo` false, `ok: false`, exit 4 — `scripts/lane_target.py:271` | a normal checkout, whose `not_home_repo` value is the resolved realpath | closed | point the lane at the project root, not at a directory that inherits the home repo |
| Workdir is a subdirectory inside a checkout | `toplevel_matches_target` false, exit 4 — `scripts/lane_target.py:276` | a real root, where the value equals `os.path.realpath(path)` | closed | use the checkout root |
| Remote target verified without opt-in | `target ssh://… is remote; local verification is impossible. Re-run with --allow-remote …`, exit 3 — `scripts/lane_target.py:303` | a local target, which is verified and can exit 4 | closed | pass `--allow-remote` **knowing** it means structural only |
| Remote target accepted as proof of existence | `"verified": "remote-structural-only"`, `"ok": true`, exit 0, with the note `reachability and existence are NOT checked here` — `scripts/lane_target.py:316`, `scripts/lane_target.py:318` | `verify --exec-bunker`, which does probe (`scripts/lane_target.py:322`) | open by design | use `--exec-bunker` for bunker targets; nothing equivalent exists for ssh/sftp/ftp |
| `scan --exec-bunker` used on a `bunker://` row | the row is refused as remote with the exit-3 message above, exit 4 — the flag is parsed at `scripts/lane_target.py:620` and never passed to `verify` at `scripts/lane_target.py:423` | `verify --exec-bunker`, which does pass it (`scripts/lane_target.py:669`) | open in the other direction: the operator believes a probe ran | use `verify --exec-bunker`, or pass `--allow-remote` and read `remote-structural-only` honestly |
| `plan` resolves the agent home from whatever `bunker` is on `$PATH` | measured: a local-exec stub answered `HOME=/home/kara` from the control host and `plan` emitted `bunker://cf-worker/home/kara/repo`, exit 0; no host identity is read (`scripts/lane_target.py:370`) | an unreachable agent, where `agent_home` stays empty and the module refuses with `cannot resolve the home of agent …` (`scripts/lane_target.py:695`) | **open** | pass `--path` explicitly, or check the planned paths against the agent before writing them |
| `plan` reads a line that is not JSON | `json.decoder.JSONDecodeError` traceback, exit 1 — `scripts/lane_target.py:704` | `scan`, which records `invalid JSON` per row and continues (`scripts/lane_target.py:415`) | loud but undocumented: exit 1 is not one of 0/2/3/4 | fix the input; do not treat exit 1 as a verdict |
| `git` hangs past 30 s during `verify` | `subprocess.TimeoutExpired` traceback, exit 1 — `scripts/lane_target.py:227` | `repo-url`, which catches it per row and exits 4 (`scripts/lane_target.py:550`) | loud, but inconsistent across subcommands | rerun; treat exit 1 as "no verdict", not "target bad" |
| `repo-url` has a diverging row | that row prints `PASS` **and** `FAIL` (measured: 881 row lines for 880 rows) — `scripts/lane_target.py:544` then `scripts/lane_target.py:593` | a row rejected outright, which prints only `FAIL` | misleading counts for any consumer that greps `PASS` | count the summary line, never the `PASS` lines |

## 7. Environment and settings it reads

- Subcommands and flags, all from `scripts/lane_target.py:605` onward:
  - `parse <target>` — no flags (`scripts/lane_target.py:607`).
  - `verify <target> [--allow-remote] [--exec-bunker] [--bunker-server S] [--home PATH]`
    (`scripts/lane_target.py:610`).
  - `scan <file> [--allow-remote] [--exec-bunker] [--bunker-server S] [--home PATH]` — `--exec-bunker`
    and `--bunker-server` are accepted and unused (`scripts/lane_target.py:617`, `scripts/lane_target.py:675`).
  - `repo-url <target> | --row FILE|-, [--allow-remote]`, mutually exclusive and one required
    (`scripts/lane_target.py:624`).
  - `plan <file> --agent ID [--server S] [--suffix PATH] [--path PATH] [--prefix NAME]`, with
    `--suffix` defaulting to `/repo` (`scripts/lane_target.py:646`).
- **Environment variables: none are read directly.** There is no `os.environ` or `os.getenv` in the
  file. Two are consumed indirectly: `$HOME` through `os.path.expanduser` (`scripts/lane_target.py:129`,
  `scripts/lane_target.py:259`) and `$PATH` through `shutil.which("git")` at import
  (`scripts/lane_target.py:223`) and through `subprocess` resolving `bunker` (`scripts/lane_target.py:334`).
- **No config file is read.** A projects file is always an argument; the module never locates one.
- Exit codes: `0` ok, `2` unparseable/invalid input, `3` remote verification not permitted, `4` local
  target failed verification (`scripts/lane_target.py:28`), with the precedence for mixed `repo-url`
  rows fixed as 2, then 3, then 4 (`scripts/lane_target.py:599`). Argparse adds its own `2` for usage
  errors, and the two uncaught-exception paths in section 6 exit `1`.
- The recognized satellite suffixes that drive family grouping are hard-coded in the module
  (`scripts/lane_target.py:437`) and must stay in key-set parity with the scheduler table in
  `docs/SCHEDULER-ADMISSION.md:72`; a suffix added on one side only changes verdicts silently.

## 8. Evidence of record

All figures above come from re-runnable commands run on 2026-11-05 at revision `b9f56e6`; per
`fact: FACT-10`, no claim here rests on a commit message.

```bash
# Fleet, read-only: the scheduler DB is opened immutable, never written
sqlite3 -json "file:$HOME/.hermes/coding-hermes/scheduler.db?mode=ro&immutable=1" \
  "select name,repo_url,workdir from projects" > fleet-projects.json      # 880 rows
python3 -B scripts/lane_target.py repo-url --row fleet-projects.json      # exit 2
python3 -B scripts/lane_target.py scan fleet-workdirs.jsonl               # exit 4, bad 805 / ok 75
```

- Fleet `repo-url` result: `repo_url: 378 rejected, 502 accepted`, exit 2, wall time 2.2 s. Rejection
  classes by count of `FAIL` lines: 257 `fatal: not a git repository`, 78 `unsupported scheme`,
  38 `path does not exist or is not a directory`, 3 `local target must be absolute or ~-relative`,
  1 `not a git root (git: top level is …)`, 1 `repo_url diverges from primary`.
  Line accounting: 503 `PASS` + 378 `FAIL` = 881 printed row lines for 880 rows, because the one
  diverging row prints both — see section 6.
- Fleet `scan` result: `"bad": 805`, `"ok": false`, exit 4; per-row causes 790 `git_toplevel`,
  10 `exists`, 4 `has_remote`, 1 `toplevel_matches_target`. Only 75 of 880 configured `workdir`
  values pass the stricter local check (exists + git root + a remote + an attached branch), against
  502 of 880 `repo_url` values that pass the looser root-only check — so no single number describes
  the fleet's addressing hygiene, and nothing else in this repository measures the `workdir` side.
- Fixtures live under `~/.hermes/cache/scratch/lt21/`: `repo-a` (with a bare `origin`), `repo-b`,
  `repo-c`, `plain/`, `unknown.jsonl`, `ambiguous-only.json`, `control.json`, `noprimary.json`,
  `bunker.jsonl`, `bad.jsonl`. They are scratch, rebuilt by the commands above, and are not part of
  the repository.
- The `plan`-home result in section 6 depends on a **local-exec stub `bunker`** placed earlier on
  `$PATH` by unrelated scratch work (`~/.hermes/cache/scratch/md32/bin/bunker`, which `exec`s the
  command on the control host). That is the point of the row: the probe reads `HOME=` without ever
  checking which host answered, so any `bunker` that runs locally produces a confidently wrong plan.
  The real CLI exists at `/usr/local/bin/bunker`; no live agent was contacted for this document, so
  bunker-path existence against a real agent is **not** verified here.
- Not verified here: behaviour against a real ssh/sftp/ftp peer (structural only, by design) and the
  `--prefix` filter in `plan` (no name-prefixed file was exercised). Neither is claimed above.
- Cross-check on the family blind spot: over the live export, 174 suffix-named lane / own-satellite
  pairs are never compared by `family_key`, and 173 of them carry different normalized `repo_url`
  values; none of those 173 has two roots that both pass `check_repo_url` today, so the blind spot is
  latent fleet-wide but reachable, as run G shows.
- Checker of record: `python3 scripts/master_doc_check.py docs/master --only 21- --strict` — run
  before the commit that adds this file; the commit carries its output.
